import Foundation
import Observation

/// UI state for the feedback form. Lives on the main actor; networking happens on the client.
@MainActor
@Observable
public final class RelayFeedbackViewModel {
    /// Submission lifecycle.
    public enum Phase: Equatable, Sendable {
        case idle
        case sending
        case sent(RelayReport)
        case failed(RelayError)
    }

    public var type: RelayFeedbackType
    public var title: String = ""
    public var message: String = ""
    public private(set) var phase: Phase = .idle

    private var task: Task<Void, Never>?

    public init(type: RelayFeedbackType = .feedback) {
        self.type = type
    }

    /// Whether the form can be submitted.
    public var canSend: Bool {
        !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && phase != .sending
    }

    public var isSending: Bool { phase == .sending }

    public var error: RelayError? {
        if case let .failed(error) = phase { return error }
        return nil
    }

    public var sentReport: RelayReport? {
        if case let .sent(report) = phase { return report }
        return nil
    }

    /// Submits the form using the shared ``Relay`` client.
    public func send() {
        guard canSend else { return }
        phase = .sending
        let pendingType = self.type
        let pendingTitle = self.title
        let pendingMessage = self.message
        task = Task { [weak self] in
            let result: Result<RelayReport, RelayError>
            do {
                let client = try Relay.client()
                let report = try await client.submit(type: pendingType, title: pendingTitle, message: pendingMessage)
                result = .success(report)
            } catch let error as RelayError {
                result = .failure(error)
            } catch {
                result = .failure(.network(String(describing: Swift.type(of: error))))
            }
            guard let self, !Task.isCancelled else { return }
            switch result {
            case let .success(report): self.phase = .sent(report)
            case let .failure(error): self.phase = .failed(error)
            }
        }
    }

    /// Clears an error so the user can edit and retry.
    public func dismissError() {
        if case .failed = phase { phase = .idle }
    }

    /// Resets the whole form.
    public func reset() {
        task?.cancel()
        task = nil
        title = ""
        message = ""
        phase = .idle
    }
}

/// UI state for the "My Messages" screen.
@MainActor
@Observable
public final class RelayMessagesViewModel {
    public private(set) var reports: [RelayStoredReport] = []
    public private(set) var isLoading = false
    public private(set) var error: RelayError?

    public init() {}

    /// Loads cached reports, then refreshes them from the server.
    public func load(refresh: Bool = true) async {
        error = nil
        do {
            let client = try Relay.client()
            reports = try await client.storedReports()
            guard refresh, !reports.isEmpty else { return }
            isLoading = true
            defer { isLoading = false }
            reports = try await client.refreshAllThreads()
        } catch let relayError as RelayError {
            error = relayError
        } catch {
            self.error = .network(String(describing: Swift.type(of: error)))
        }
    }

    /// Refreshes a single thread.
    public func refresh(id: String) async {
        do {
            let client = try Relay.client()
            _ = try await client.fetchThread(id: id)
            reports = try await client.storedReports()
        } catch let relayError as RelayError {
            error = relayError
        } catch {
            self.error = .network(String(describing: Swift.type(of: error)))
        }
    }

    /// Deletes a stored report locally.
    public func delete(id: String) async {
        do {
            let client = try Relay.client()
            try await client.reportStore.remove(id: id)
            reports = try await client.storedReports()
        } catch let relayError as RelayError {
            error = relayError
        } catch {
            self.error = .keychain(-1)
        }
    }
}
