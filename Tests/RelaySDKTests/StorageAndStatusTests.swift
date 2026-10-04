import XCTest
@testable import RelaySDK

final class KeychainStorageTests: XCTestCase {
    /// Runs against the real Keychain with an isolated service name; skipped when the
    /// host environment has no usable Keychain (e.g. sandbox-less CI runners).
    func testKeychainStoreRoundTrip() throws {
        let store = RelayKeychainStore(service: "relaysdk.tests.\(UUID().uuidString)")
        let key = "unit.test.key"
        do {
            try store.set("secret-1", forKey: key)
        } catch let error as RelayError {
            if case .keychain = error { throw XCTSkip("Keychain unavailable in this environment: \(error.failureReason ?? "")") }
            throw error
        }
        defer { try? store.removeValue(forKey: key) }

        XCTAssertEqual(try store.string(forKey: key), "secret-1")
        try store.set("secret-2", forKey: key)
        XCTAssertEqual(try store.string(forKey: key), "secret-2", "update path must overwrite")
        try store.removeValue(forKey: key)
        XCTAssertNil(try store.data(forKey: key))
        XCTAssertNoThrow(try store.removeValue(forKey: key), "removing a missing key is not an error")
    }

    func testReportStorePersistsIdAndTokenSecurely() async throws {
        let secure = RelayInMemorySecureStore()
        let (client, _) = try Fixtures.makeClient(steps: [.response(Fixtures.json(Fixtures.submitSuccess))], store: secure)

        let report = try await client.submit(type: .bug, title: "T", message: "M")
        let stored = try await client.storedReports()

        XCTAssertEqual(stored.count, 1)
        XCTAssertEqual(stored.first?.id, report.id)
        XCTAssertEqual(stored.first?.feedbackToken, "tok_secret")
        XCTAssertEqual(stored.first?.type, .bug)
        XCTAssertEqual(stored.first?.lastKnownStatus, .new)

        let raw = try XCTUnwrap(secure.data(forKey: RelayReportStore.reportsKey))
        XCTAssertTrue(String(decoding: raw, as: UTF8.self).contains("tok_secret"), "token lives in the secure store only")
        XCTAssertNil(UserDefaults.standard.string(forKey: RelayReportStore.reportsKey))
        XCTAssertNil(UserDefaults.standard.string(forKey: RelayReportStore.installationKey))
    }

    func testFetchThreadUsesStoredTokenAndUpdatesStatus() async throws {
        let (client, http) = try Fixtures.makeClient(steps: [
            .response(Fixtures.json(Fixtures.submitSuccess)),
            .response(Fixtures.json(Fixtures.threadSuccess))
        ])
        let report = try await client.submit(type: .issue, message: "M")
        let thread = try await client.fetchThread(id: report.id)

        XCTAssertEqual(http.requests.last?.headers["X-Feedback-Token"], "tok_secret")
        XCTAssertEqual(thread.status, .reviewing)

        let stored = try await client.storedReports()
        XCTAssertEqual(stored.first?.lastKnownStatus, .reviewing)
        XCTAssertEqual(stored.first?.replies.count, 1)
        XCTAssertNotNil(stored.first?.lastSyncedAt)
    }

    func testFetchThreadWithoutStoredTokenThrows() async throws {
        let (client, http) = try Fixtures.makeClient(steps: [])
        await XCTAssertThrowsRelayError(.missingFeedbackToken(id: "ghost")) { _ = try await client.fetchThread(id: "ghost") }
        XCTAssertEqual(http.callCount, 0)
    }

    func testInstallationIdIsRandomAndPersistent() async throws {
        let secure = RelayInMemorySecureStore()
        let storeA = RelayReportStore(store: secure)
        let storeB = RelayReportStore(store: secure)
        let idA = try await storeA.installationId()
        let idB = try await storeB.installationId()
        XCTAssertEqual(idA, idB)
        XCTAssertTrue(idA.hasPrefix("install_"))
        XCTAssertNotNil(UUID(uuidString: String(idA.dropFirst("install_".count))))

        let other = try await RelayReportStore(store: RelayInMemorySecureStore()).installationId()
        XCTAssertNotEqual(idA, other)
    }

    func testLegacyInstallationIdIsMigrated() async throws {
        let secure = RelayInMemorySecureStore()
        let legacy = UUID().uuidString.lowercased()
        try secure.set(legacy, forKey: RelayReportStore.installationKey)

        let migrated = try await RelayReportStore(store: secure).installationId()

        XCTAssertEqual(migrated, "install_\(legacy)")
        XCTAssertEqual(try secure.string(forKey: RelayReportStore.installationKey), migrated)
    }

    func testRemoveAndRemoveAll() async throws {
        let store = RelayReportStore(store: RelayInMemorySecureStore())
        for i in 0..<3 {
            try await store.save(RelayStoredReport(
                id: "fbk_\(i)", feedbackToken: "t\(i)", type: .feedback, title: nil, message: "m",
                createdAt: Date(timeIntervalSince1970: Double(i)), lastKnownStatus: .new
            ))
        }
        var all = try await store.allReports()
        XCTAssertEqual(all.map(\.id), ["fbk_2", "fbk_1", "fbk_0"], "newest first")

        try await store.remove(id: "fbk_1")
        all = try await store.allReports()
        XCTAssertEqual(all.map(\.id), ["fbk_2", "fbk_0"])

        try await store.removeAll()
        all = try await store.allReports()
        XCTAssertTrue(all.isEmpty)
        let installation = try await store.installationId()
        XCTAssertFalse(installation.isEmpty, "installation id survives removeAll")
    }
}

final class StatusMappingTests: XCTestCase {
    func testServerStatusesMapToDisplayStatuses() {
        XCTAssertEqual(RelayFeedbackStatus.new.display, .pending)
        XCTAssertEqual(RelayFeedbackStatus.reviewing.display, .inReview)
        XCTAssertEqual(RelayFeedbackStatus.planned.display, .planned)
        XCTAssertEqual(RelayFeedbackStatus.inProgress.display, .inProgress)
        XCTAssertEqual(RelayFeedbackStatus.resolved.display, .completed)
        XCTAssertEqual(RelayFeedbackStatus.closed.display, .completed)
        XCTAssertEqual(RelayFeedbackStatus.rejected.display, .rejected)
        XCTAssertEqual(RelayFeedbackStatus.unknown.display, .unknown)
    }

    func testRawValuesMatchAPI() {
        XCTAssertEqual(RelayFeedbackStatus.inProgress.rawValue, "in_progress")
        XCTAssertEqual(RelayFeedbackType.featureRequest.rawValue, "feature_request")
        XCTAssertEqual(RelayFeedbackType.allCases.map(\.rawValue), ["feedback", "bug", "feature_request", "issue"])
    }

    func testDisplayStatusesAreLocalized() {
        let en = RelayStrings(language: .english)
        let fa = RelayStrings(language: .persian)
        XCTAssertEqual(en.text(for: .pending), "Pending")
        XCTAssertEqual(en.text(for: .inReview), "In Review")
        XCTAssertEqual(en.text(for: .completed), "Completed")
        XCTAssertEqual(fa.text(for: .pending), "در انتظار")
        XCTAssertEqual(fa.text(for: .completed), "انجام‌شده")
        for key in RelayStringKey.allCases {
            XCTAssertNotNil(RelayStrings.english[key], "missing English string for \(key)")
            XCTAssertNotNil(RelayStrings.persian[key], "missing Persian string for \(key)")
        }
    }

    func testLanguageDetection() {
        XCTAssertEqual(RelayLanguage.best(for: Locale(identifier: "fa_IR")), .persian)
        XCTAssertEqual(RelayLanguage.best(for: Locale(identifier: "en_US")), .english)
        XCTAssertEqual(RelayLanguage.best(preferredLanguages: ["fa-IR"]), .persian)
        XCTAssertEqual(RelayLanguage.best(preferredLanguages: ["de-DE"]), .english)
        XCTAssertEqual(RelayLanguage.best(preferredLanguages: ["tr-TR", "fa-IR"]), .english)
        XCTAssertEqual(RelayLanguage.best(preferredLanguages: []), .english)
        XCTAssertEqual(RelayLanguage.best(for: Locale(identifier: "de_DE")), .english)
        XCTAssertTrue(RelayLanguage.persian.isRightToLeft)
        XCTAssertFalse(RelayLanguage.english.isRightToLeft)
    }
}

final class RelayFacadeTests: XCTestCase {
    override func tearDown() {
        Relay.reset()
        super.tearDown()
    }

    func testUnconfiguredFacadeThrows() async {
        Relay.reset()
        XCTAssertFalse(Relay.isConfigured)
        await XCTAssertThrowsRelayError(.notConfigured) { _ = try await Relay.submit(type: .bug, message: "x") }
    }

    func testInvalidKeyIsReported() async {
        XCTAssertFalse(Relay.configure(projectKey: "sk_live_secret", baseURL: Fixtures.baseURL, secureStore: RelayInMemorySecureStore()))
        await XCTAssertThrowsRelayError(.invalidProjectKey) { _ = try await Relay.submit(type: .bug, message: "x") }
    }

    func testConfiguredFacadeSubmitsAndFetches() async throws {
        let http = MockHTTPClient(steps: [
            .response(Fixtures.json(Fixtures.submitSuccess)),
            .response(Fixtures.json(Fixtures.threadSuccess))
        ])
        XCTAssertTrue(Relay.configure(
            projectKey: "pk_live_demo",
            baseURL: Fixtures.baseURL,
            timeout: 12,
            language: .persian,
            theme: RelayTheme(formTitle: "نظر شما"),
            httpClient: http,
            secureStore: RelayInMemorySecureStore()
        ))
        XCTAssertTrue(Relay.isConfigured)
        XCTAssertEqual(Relay.theme.formTitle, "نظر شما")
        XCTAssertEqual(Relay.configurationIfAvailable?.timeout, 12)
        XCTAssertEqual(RelayStrings.current.language, .persian)

        let report = try await Relay.submit(type: .featureRequest, title: "Dark mode", message: "Please add dark mode")
        let thread = try await Relay.fetchThread(id: report.id)
        XCTAssertEqual(thread.replies.count, 1)
        XCTAssertEqual(http.requests.first?.timeout, 12)
        let stored = try await Relay.storedReports()
        XCTAssertEqual(stored.count, 1)
        try await Relay.clearStoredReports()
        let cleared = try await Relay.storedReports()
        XCTAssertTrue(cleared.isEmpty)
    }
}
