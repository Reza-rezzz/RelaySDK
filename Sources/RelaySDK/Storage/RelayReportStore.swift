import Foundation

/// Persists the installation identifier and every submitted report (id + feedback token)
/// inside a ``RelaySecureStore``. Nothing is written to `UserDefaults`.
public actor RelayReportStore {
    public static let installationKey = "relay.installation_id"
    public static let reportsKey = "relay.reports.v1"

    private let store: RelaySecureStore
    private var cache: [RelayStoredReport]?

    public init(store: RelaySecureStore) {
        self.store = store
    }

    // MARK: Installation ID

    /// Returns the persistent random installation identifier, creating it on first use.
    public func installationId() throws -> String {
        if let existing = try store.string(forKey: Self.installationKey), !existing.isEmpty {
            return existing
        }
        let fresh = UUID().uuidString.lowercased()
        try store.set(fresh, forKey: Self.installationKey)
        return fresh
    }

    // MARK: Reports

    /// All stored reports, newest first.
    public func allReports() throws -> [RelayStoredReport] {
        if let cache { return cache }
        guard let data = try store.data(forKey: Self.reportsKey) else {
            cache = []
            return []
        }
        let decoded = (try? RelayJSON.makeDecoder().decode([RelayStoredReport].self, from: data)) ?? []
        let sorted = decoded.sorted { $0.createdAt > $1.createdAt }
        cache = sorted
        return sorted
    }

    /// Returns a single stored report.
    public func report(id: String) throws -> RelayStoredReport? {
        try allReports().first { $0.id == id }
    }

    /// Inserts or replaces a report.
    public func save(_ report: RelayStoredReport) throws {
        var reports = try allReports().filter { $0.id != report.id }
        reports.insert(report, at: 0)
        try persist(reports)
    }

    /// Applies a thread update to the stored report, if present.
    public func apply(_ thread: RelayThread) throws {
        var reports = try allReports()
        guard let index = reports.firstIndex(where: { $0.id == thread.id }) else { return }
        reports[index].lastKnownStatus = thread.status
        reports[index].replies = thread.replies
        reports[index].lastSyncedAt = Date()
        try persist(reports)
    }

    /// Removes a report and its token.
    public func remove(id: String) throws {
        try persist(try allReports().filter { $0.id != id })
    }

    /// Removes every stored report and token (keeps the installation id).
    public func removeAll() throws {
        try store.removeValue(forKey: Self.reportsKey)
        cache = []
    }

    private func persist(_ reports: [RelayStoredReport]) throws {
        let sorted = reports.sorted { $0.createdAt > $1.createdAt }
        let data = try RelayJSON.makeEncoder().encode(sorted)
        try store.set(data, forKey: Self.reportsKey)
        cache = sorted
    }
}
