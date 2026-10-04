import Foundation

/// Languages bundled with the SDK's ready-made UI.
public enum RelayLanguage: String, Sendable, CaseIterable {
    case english = "en"
    case persian = "fa"

    /// Whether this language is written right-to-left.
    public var isRightToLeft: Bool { self == .persian }

    /// Picks the best bundled language for the given locale. Unsupported languages fall back to English.
    public static func best(for locale: Locale = .current) -> RelayLanguage {
        resolve(locale.identifier)
    }

    /// Picks the SDK language from the app's active localization. Only the first identifier is
    /// considered: if that language is unsupported, the UI intentionally falls back to English.
    public static func best(preferredLanguages: [String]) -> RelayLanguage {
        guard let activeLanguage = preferredLanguages.first else { return .english }
        return resolve(activeLanguage)
    }

    /// Detects the language selected for the host app, not merely the device region.
    /// An explicit language passed to `Relay.configure` still takes precedence.
    public static func best(for bundle: Bundle, fallback locale: Locale = .current) -> RelayLanguage {
        if let activeLocalization = bundle.preferredLocalizations.first {
            return resolve(activeLocalization)
        }
        if let preferredLanguage = Locale.preferredLanguages.first {
            return resolve(preferredLanguage)
        }
        return best(for: locale)
    }

    private static func resolve(_ identifier: String) -> RelayLanguage {
        let code = Locale(identifier: identifier).language.languageCode?.identifier.lowercased()
        return code == RelayLanguage.persian.rawValue ? .persian : .english
    }
}

/// Keys for every user-facing string used by the SDK.
public enum RelayStringKey: String, Sendable, CaseIterable {
    case formTitle, myMessages, send, sending, cancel, done, close, retry, refresh
    case typeLabel, titleLabel, titlePlaceholder, messageLabel, messagePlaceholder
    case typeFeedback, typeBug, typeFeatureRequest, typeIssue
    case statusPending, statusInReview, statusPlanned, statusInProgress, statusCompleted, statusRejected, statusUnknown
    case sentTitle, sentBody, sendFeedback, developerReply, noReplies, noMessages, noMessagesHint, lastUpdated
    case errorTitle
    case errorNotConfigured, errorInvalidKey, errorEmptyMessage, errorInvalidRequest, errorInvalidResponse
    case errorServer, errorUnauthorized, errorNotFound, errorRateLimited, errorNetwork, errorCancelled
    case errorKeychain, errorMissingToken, errorRetrySuggestion, errorConfigureSuggestion
    case a11yTypePicker, a11yTitleField, a11yMessageField, a11ySendButton, a11yFeedbackButton, a11yStatusBadge, a11yReplyCount
}

/// Bundled, dependency-free string table (English + Persian).
public struct RelayStrings: Sendable {
    public let language: RelayLanguage

    public init(language: RelayLanguage) {
        self.language = language
    }

    /// Strings for the current global configuration (or system locale when not configured).
    public static var current: RelayStrings {
        RelayStrings(language: Relay.configurationIfAvailable?.language ?? RelayLanguage.best())
    }

    /// Returns the localized text for a key.
    public func text(_ key: RelayStringKey) -> String {
        switch language {
        case .english: return RelayStrings.english[key] ?? key.rawValue
        case .persian: return RelayStrings.persian[key] ?? RelayStrings.english[key] ?? key.rawValue
        }
    }

    public func text(for type: RelayFeedbackType) -> String {
        switch type {
        case .feedback: return text(.typeFeedback)
        case .bug: return text(.typeBug)
        case .featureRequest: return text(.typeFeatureRequest)
        case .issue: return text(.typeIssue)
        }
    }

    public func text(for status: RelayDisplayStatus) -> String {
        switch status {
        case .pending: return text(.statusPending)
        case .inReview: return text(.statusInReview)
        case .planned: return text(.statusPlanned)
        case .inProgress: return text(.statusInProgress)
        case .completed: return text(.statusCompleted)
        case .rejected: return text(.statusRejected)
        case .unknown: return text(.statusUnknown)
        }
    }

    static let english: [RelayStringKey: String] = [
        .formTitle: "Send Feedback",
        .myMessages: "My Messages",
        .send: "Send",
        .sending: "Sending…",
        .cancel: "Cancel",
        .done: "Done",
        .close: "Close",
        .retry: "Try Again",
        .refresh: "Refresh",
        .typeLabel: "Type",
        .titleLabel: "Title (optional)",
        .titlePlaceholder: "Short summary",
        .messageLabel: "Message",
        .messagePlaceholder: "Tell us what happened or what you'd like to see…",
        .typeFeedback: "Feedback",
        .typeBug: "Bug",
        .typeFeatureRequest: "Feature Request",
        .typeIssue: "Issue",
        .statusPending: "Pending",
        .statusInReview: "In Review",
        .statusPlanned: "Planned",
        .statusInProgress: "In Progress",
        .statusCompleted: "Completed",
        .statusRejected: "Rejected",
        .statusUnknown: "Unknown",
        .sentTitle: "Thank you!",
        .sentBody: "Your message has been sent. You can follow its status in “My Messages”.",
        .sendFeedback: "Send Feedback",
        .developerReply: "Developer reply",
        .noReplies: "No reply yet",
        .noMessages: "No messages yet",
        .noMessagesHint: "Reports you send will appear here along with their status and replies.",
        .lastUpdated: "Updated",
        .errorTitle: "Something went wrong",
        .errorNotConfigured: "Relay is not configured. Call Relay.configure(projectKey:baseURL:) first.",
        .errorInvalidKey: "The project key is invalid. Only publishable keys (pk_…) are allowed.",
        .errorEmptyMessage: "Please write a message before sending.",
        .errorInvalidRequest: "The request could not be created.",
        .errorInvalidResponse: "The server returned an unexpected response.",
        .errorServer: "The server returned an error ({code}).",
        .errorUnauthorized: "Not authorized. Please check the project key.",
        .errorNotFound: "This report could not be found.",
        .errorRateLimited: "Too many requests. Please wait a moment and try again.",
        .errorNetwork: "No connection. Please check your internet and try again.",
        .errorCancelled: "The request was cancelled.",
        .errorKeychain: "Secure storage is unavailable on this device.",
        .errorMissingToken: "No access token is stored for this report.",
        .errorRetrySuggestion: "Please try again in a moment.",
        .errorConfigureSuggestion: "Configure the SDK at app launch.",
        .a11yTypePicker: "Report type",
        .a11yTitleField: "Optional title",
        .a11yMessageField: "Message text",
        .a11ySendButton: "Send report",
        .a11yFeedbackButton: "Open feedback form",
        .a11yStatusBadge: "Status",
        .a11yReplyCount: "replies"
    ]

    static let persian: [RelayStringKey: String] = [
        .formTitle: "ارسال بازخورد",
        .myMessages: "پیام‌های من",
        .send: "ارسال",
        .sending: "در حال ارسال…",
        .cancel: "انصراف",
        .done: "تمام",
        .close: "بستن",
        .retry: "تلاش دوباره",
        .refresh: "به‌روزرسانی",
        .typeLabel: "نوع",
        .titleLabel: "عنوان (اختیاری)",
        .titlePlaceholder: "خلاصهٔ کوتاه",
        .messageLabel: "پیام",
        .messagePlaceholder: "بگویید چه اتفاقی افتاد یا چه چیزی دوست دارید ببینید…",
        .typeFeedback: "بازخورد",
        .typeBug: "باگ",
        .typeFeatureRequest: "درخواست قابلیت",
        .typeIssue: "مشکل",
        .statusPending: "در انتظار",
        .statusInReview: "در حال بررسی",
        .statusPlanned: "برنامه‌ریزی‌شده",
        .statusInProgress: "در حال انجام",
        .statusCompleted: "انجام‌شده",
        .statusRejected: "رد شده",
        .statusUnknown: "نامشخص",
        .sentTitle: "متشکریم!",
        .sentBody: "پیام شما ارسال شد. می‌توانید وضعیت آن را در «پیام‌های من» دنبال کنید.",
        .sendFeedback: "ارسال بازخورد",
        .developerReply: "پاسخ توسعه‌دهنده",
        .noReplies: "هنوز پاسخی ثبت نشده",
        .noMessages: "هنوز پیامی ندارید",
        .noMessagesHint: "گزارش‌هایی که ارسال می‌کنید همراه با وضعیت و پاسخ‌ها اینجا نمایش داده می‌شوند.",
        .lastUpdated: "به‌روزرسانی",
        .errorTitle: "مشکلی پیش آمد",
        .errorNotConfigured: "Relay پیکربندی نشده است. ابتدا Relay.configure را فراخوانی کنید.",
        .errorInvalidKey: "کلید پروژه نامعتبر است. فقط کلید عمومی (pk_…) مجاز است.",
        .errorEmptyMessage: "لطفاً قبل از ارسال، پیام خود را بنویسید.",
        .errorInvalidRequest: "امکان ساخت درخواست وجود ندارد.",
        .errorInvalidResponse: "پاسخ سرور غیرمنتظره بود.",
        .errorServer: "سرور با خطا پاسخ داد ({code}).",
        .errorUnauthorized: "دسترسی مجاز نیست. لطفاً کلید پروژه را بررسی کنید.",
        .errorNotFound: "این گزارش پیدا نشد.",
        .errorRateLimited: "درخواست‌های زیادی ارسال شده است. لطفاً کمی بعد دوباره تلاش کنید.",
        .errorNetwork: "اتصال برقرار نیست. لطفاً اینترنت خود را بررسی کنید و دوباره تلاش کنید.",
        .errorCancelled: "درخواست لغو شد.",
        .errorKeychain: "ذخیره‌سازی امن در این دستگاه در دسترس نیست.",
        .errorMissingToken: "برای این گزارش توکن دسترسی ذخیره نشده است.",
        .errorRetrySuggestion: "لطفاً چند لحظه بعد دوباره تلاش کنید.",
        .errorConfigureSuggestion: "SDK را هنگام اجرای برنامه پیکربندی کنید.",
        .a11yTypePicker: "نوع گزارش",
        .a11yTitleField: "عنوان اختیاری",
        .a11yMessageField: "متن پیام",
        .a11ySendButton: "ارسال گزارش",
        .a11yFeedbackButton: "باز کردن فرم بازخورد",
        .a11yStatusBadge: "وضعیت",
        .a11yReplyCount: "پاسخ"
    ]
}
