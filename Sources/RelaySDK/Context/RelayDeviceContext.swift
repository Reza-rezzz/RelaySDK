import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Non-identifying device and app metadata attached to every report.
///
/// Collection can be disabled with ``RelayConfiguration/collectsDeviceContext``.
public struct RelayDeviceContext: Codable, Sendable, Equatable {
    public var platform: String
    public var appVersion: String
    public var build: String
    public var os: String
    public var osVersion: String
    public var deviceType: String
    public var locale: String
    public var language: String
    public var sdkVersion: String

    enum CodingKeys: String, CodingKey {
        case platform, os, locale, language, build
        case appVersion = "app_version"
        case osVersion = "os_version"
        case deviceType = "device_type"
        case sdkVersion = "sdk_version"
    }

    public init(
        platform: String,
        appVersion: String,
        build: String,
        os: String,
        osVersion: String,
        deviceType: String,
        locale: String,
        language: String,
        sdkVersion: String = RelaySDKInfo.versionString
    ) {
        self.platform = platform
        self.appVersion = appVersion
        self.build = build
        self.os = os
        self.osVersion = osVersion
        self.deviceType = deviceType
        self.locale = locale
        self.language = language
        self.sdkVersion = sdkVersion
    }

    /// Collects the current context. Safe to call from any thread.
    public static func current(bundle: Bundle = .main, locale: Locale = .current) -> RelayDeviceContext {
        let info = bundle.infoDictionary ?? [:]
        let appVersion = info["CFBundleShortVersionString"] as? String ?? "unknown"
        let build = info["CFBundleVersion"] as? String ?? "unknown"
        let language = locale.language.languageCode?.identifier ?? "en"
        let localeId = locale.identifier

        #if canImport(UIKit) && !os(watchOS)
        let osv = ProcessInfo.processInfo.operatingSystemVersion
        let osVersion = "\(osv.majorVersion).\(osv.minorVersion)" + (osv.patchVersion > 0 ? ".\(osv.patchVersion)" : "")
        let deviceType: String = {
            #if targetEnvironment(macCatalyst)
            return "mac"
            #else
            if ProcessInfo.processInfo.isiOSAppOnMac { return "mac" }
            return Self.deviceType(fromModelIdentifier: Self.modelIdentifier())
            #endif
        }()
        #if os(visionOS)
        let osName = "visionOS"
        #elseif os(tvOS)
        let osName = "tvOS"
        #else
        let osName = "iOS"
        #endif
        return RelayDeviceContext(
            platform: "ios",
            appVersion: appVersion,
            build: build,
            os: osName,
            osVersion: osVersion,
            deviceType: deviceType,
            locale: localeId,
            language: language
        )
        #else
        let osv = ProcessInfo.processInfo.operatingSystemVersion
        return RelayDeviceContext(
            platform: "macos",
            appVersion: appVersion,
            build: build,
            os: "macOS",
            osVersion: "\(osv.majorVersion).\(osv.minorVersion)",
            deviceType: "mac",
            locale: localeId,
            language: language
        )
        #endif
    }

    /// Hardware model identifier (e.g. `iPhone15,2`, `iPad13,1`). Thread-safe; no UIKit main-actor access.
    static func modelIdentifier() -> String {
        if let simulator = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"], !simulator.isEmpty {
            return simulator
        }
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafeBytes(of: &systemInfo.machine) { buffer in
            String(decoding: buffer.prefix { $0 != 0 }, as: UTF8.self)
        }
    }

    /// Maps a model identifier to a coarse device type.
    static func deviceType(fromModelIdentifier id: String) -> String {
        let lower = id.lowercased()
        if lower.hasPrefix("iphone") { return "phone" }
        if lower.hasPrefix("ipad") { return "tablet" }
        if lower.hasPrefix("ipod") { return "phone" }
        if lower.hasPrefix("appletv") { return "tv" }
        if lower.hasPrefix("realitydevice") { return "vision" }
        if lower.hasPrefix("mac") || lower.hasPrefix("x86_64") || lower.hasPrefix("arm64") { return "mac" }
        return "unknown"
    }
}

/// Static information about the SDK itself.
public enum RelaySDKInfo {
    /// Semantic version of this SDK.
    public static let version = "1.2.1"
    /// Value sent as `sdk_version` in the context payload.
    public static let versionString = "sugkit-swift-1.2.1"
}
