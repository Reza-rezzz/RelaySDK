import Foundation
import Security

/// Key/value storage for secrets. The default implementation is the system Keychain.
///
/// Inject ``RelayInMemorySecureStore`` in tests.
public protocol RelaySecureStore: Sendable {
    func data(forKey key: String) throws -> Data?
    func set(_ data: Data, forKey key: String) throws
    func removeValue(forKey key: String) throws
}

public extension RelaySecureStore {
    func string(forKey key: String) throws -> String? {
        try data(forKey: key).flatMap { String(data: $0, encoding: .utf8) }
    }

    func set(_ string: String, forKey key: String) throws {
        try set(Data(string.utf8), forKey: key)
    }
}

/// Keychain-backed store (generic passwords, `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`).
public struct RelayKeychainStore: RelaySecureStore {
    public let service: String
    public let accessGroup: String?

    /// - Parameters:
    ///   - service: Keychain service name. Defaults to a bundle-scoped identifier.
    ///   - accessGroup: Optional shared access group.
    public init(service: String = RelayKeychainStore.defaultService, accessGroup: String? = nil) {
        self.service = service
        self.accessGroup = accessGroup
    }

    public static var defaultService: String {
        let bundle = Bundle.main.bundleIdentifier ?? "relay.sdk"
        return "\(bundle).relaysdk"
    }

    private func baseQuery(for key: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        if let accessGroup { query[kSecAttrAccessGroup as String] = accessGroup }
        return query
    }

    public func data(forKey key: String) throws -> Data? {
        var query = baseQuery(for: key)
        query[kSecReturnData as String] = kCFBooleanTrue
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess: return result as? Data
        case errSecItemNotFound: return nil
        default: throw RelayError.keychain(status)
        }
    }

    public func set(_ data: Data, forKey key: String) throws {
        let query = baseQuery(for: key)
        let attributes: [String: Any] = [kSecValueData as String: data]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else { throw RelayError.keychain(updateStatus) }

        var insert = query
        insert[kSecValueData as String] = data
        insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let addStatus = SecItemAdd(insert as CFDictionary, nil)
        guard addStatus == errSecSuccess else { throw RelayError.keychain(addStatus) }
    }

    public func removeValue(forKey key: String) throws {
        let status = SecItemDelete(baseQuery(for: key) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw RelayError.keychain(status) }
    }
}

/// Thread-safe in-memory store for tests and previews.
public final class RelayInMemorySecureStore: RelaySecureStore, @unchecked Sendable {
    private var storage: [String: Data] = [:]
    private let lock = NSLock()

    public init() {}

    public func data(forKey key: String) throws -> Data? {
        lock.lock(); defer { lock.unlock() }
        return storage[key]
    }

    public func set(_ data: Data, forKey key: String) throws {
        lock.lock(); defer { lock.unlock() }
        storage[key] = data
    }

    public func removeValue(forKey key: String) throws {
        lock.lock(); defer { lock.unlock() }
        storage.removeValue(forKey: key)
    }

    /// Number of stored entries (test helper).
    public var count: Int {
        lock.lock(); defer { lock.unlock() }
        return storage.count
    }
}
