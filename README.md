# RelaySDK

A dependency-free Swift Package for collecting in-app feedback with the **Relay** service.
iOS 17+, Swift Concurrency, Keychain-backed storage, ready-made SwiftUI screens in English and Persian (RTL/LTR).

```
Base URL:  https://relay-wishkit.reza-rzny.workers.dev
Auth:      X-Project-Key: pk_live_...   (publishable key only)
```

## Features

- `POST /v1/feedback` and `GET /v1/feedback/{id}` fully typed
- Typed `RelayError` conforming to `LocalizedError` (English + Persian messages)
- Complete decoding of `{ success, data, error }` envelopes
- ISO-8601 dates with **and without** fractional seconds
- Bounded exponential backoff for transport errors, HTTP `429` and `5xx` only
- Configurable timeout, injectable transport (`RelayHTTPClient`) and secure store (`RelaySecureStore`)
- Networking off the main actor; UI state isolated to `@MainActor`
- Random, persistent installation identifier
- `feedback_id` + `feedback_token` stored in the **Keychain** (never `UserDefaults`)
- Automatic app/device context (version, build, OS, device type, locale, SDK version) – can be disabled
- `RelayFeedbackView`, `RelayFeedbackButton`, `RelayMyMessagesView` with Dynamic Type, accessibility labels, theming
- No secrets in the SDK, no user content in logs

## Installation (Swift Package Manager)

**Xcode:** File ▸ Add Package Dependencies… ▸ enter the repository URL ▸ add `RelaySDK` to your app target.

**Package.swift:**

```swift
dependencies: [
    .package(url: "https://github.com/Reza-rezzz/RelaySDK.git", from: "1.0.0")
],
targets: [
    .target(name: "MyApp", dependencies: ["RelaySDK"])
]
```

## Setup

Configure once at launch (for example in your `App` initializer):

```swift
import RelaySDK

@main
struct MyApp: App {
    init() {
        Relay.configure(
            projectKey: "pk_live_...",
            baseURL: URL(string: "https://relay-wishkit.reza-rzny.workers.dev")!
        )
    }
    var body: some Scene { WindowGroup { ContentView() } }
}
```

All options:

```swift
Relay.configure(
    projectKey: "pk_live_...",
    baseURL: URL(string: "https://relay-wishkit.reza-rzny.workers.dev")!,
    timeout: 20,                                  // seconds, default 30
    retryPolicy: RelayRetryPolicy(maxRetries: 2), // default 3 retries (0.5s, 1s, 2s + jitter)
    collectsDeviceContext: true,                  // false → no app/device metadata is sent
    language: .persian,                           // nil → follows system language (en/fa)
    theme: RelayTheme(accentColor: .orange, formTitle: "نظر شما")
)
```

`configure` returns `false` (and later calls throw `RelayError.invalidProjectKey`) if the key does not start with `pk_`.

## Showing the ready-made form

```swift
// A button that presents the form in a sheet
RelayFeedbackButton()
RelayFeedbackButton(initialType: .bug) { Label("Report a bug", systemImage: "ladybug") }

// Or present it yourself
.sheet(isPresented: $showFeedback) {
    RelayFeedbackView()
}

// Optional callback
RelayFeedbackView(initialType: .featureRequest) { report in
    print("Sent report", report.id)   // id only – never log user content
}
```

The form includes: type picker (feedback / bug / feature request / issue), optional title, message,
sending state, a human-readable error with retry, and a success screen.

### "My Messages"

```swift
.sheet(isPresented: $showMessages) { RelayMyMessagesView() }
// or inside an existing NavigationStack:
NavigationLink("My Messages") { RelayMyMessagesView(embedded: true) }
```

Shows every report sent from this device, its normalized status and developer replies.
Pull to refresh or tap the refresh button; swipe to delete locally.

### Theming and language

```swift
RelayFeedbackView()
    .relayTheme(RelayTheme(accentColor: .purple, formTitle: "Tell us more"))
    .relayLanguage(.persian)   // forces RTL layout + Persian strings
```

## Direct API

```swift
let report = try await Relay.submit(
    type: .bug,
    title: "Login problem",
    message: "The login button does not work."
)
// report.id, report.status, report.createdAt, report.feedbackToken (already stored in Keychain)

let thread = try await Relay.fetchThread(id: report.id)
// thread.status.display → .pending / .inReview / .planned / .inProgress / .completed / .rejected
for reply in thread.replies { print(reply.createdAt) }

let mine = try await Relay.storedReports()      // local list with cached status + replies
try await Relay.refreshAllThreads()             // sync all of them
let installation = try await Relay.installationId()
```

Multiple configurations / tests:

```swift
let config = try RelayConfiguration(projectKey: "pk_test_…", baseURL: url, httpClient: MyMockClient(), secureStore: RelayInMemorySecureStore())
let client = RelayClient(configuration: config)
```

### Status mapping

| Server               | `RelayDisplayStatus` | EN          | FA              |
|----------------------|----------------------|-------------|-----------------|
| `new`                | `.pending`           | Pending     | در انتظار        |
| `reviewing`          | `.inReview`          | In Review   | در حال بررسی     |
| `planned`            | `.planned`           | Planned     | برنامه‌ریزی‌شده   |
| `in_progress`        | `.inProgress`        | In Progress | در حال انجام     |
| `resolved`, `closed` | `.completed`         | Completed   | انجام‌شده        |
| `rejected`           | `.rejected`          | Rejected    | رد شده          |

### Errors

`RelayError` cases: `notConfigured`, `invalidProjectKey`, `emptyMessage`, `invalidRequest`, `invalidResponse`,
`decoding`, `server(statusCode:code:message:)`, `unauthorized`, `notFound`, `rateLimited(retryAfter:)`,
`network`, `cancelled`, `keychain(OSStatus)`, `missingFeedbackToken(id:)`.
Every case provides `errorDescription`, most provide `recoverySuggestion`; `isRetryable` tells you whether the SDK already retried.

## Security notes

- **Only publishable keys** (`pk_…`) are accepted. Never embed a secret key in the app; the SDK refuses `sk_…` keys.
- `feedback_id` / `feedback_token` pairs and the installation id are stored in the Keychain
  with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`. Nothing is written to `UserDefaults`.
- The SDK never prints tokens, request bodies or user messages. Errors only carry status codes and coding paths.
- An ephemeral `URLSession` is used (no cookies, no cache, no persisted credentials).
- Device context contains no identifiers beyond the random installation id; disable it with `collectsDeviceContext: false`.
- Use a shared Keychain access group via `RelayKeychainStore(accessGroup:)` if you need app-extension access.

## Testing

```bash
swift test
```

The test target covers request encoding, response decoding, fractional/non-fractional ISO-8601 dates,
error decoding, retry behaviour (with an injected sleeper), Keychain storage, status mapping and the facade.
All network tests run against `MockHTTPClient` – no internet required.
On CI machines without a usable Keychain the single real-Keychain test is skipped automatically.

## Example app

See `Example/RelayExampleApp.swift` – a minimal SwiftUI app showing configuration, the button, the sheet,
"My Messages" and direct API usage. Create an iOS App project in Xcode, add the package, and replace the
generated `App` file with it.

## Package layout

```
Package.swift
Sources/RelaySDK/
  Relay.swift                     Facade + shared state
  RelayConfiguration.swift        Options + publishable-key validation
  RelayClient.swift               Requests, retry, decoding
  Models/                         Types, statuses, envelope, errors
  Networking/                     HTTP abstraction, JSON/ISO-8601, retry policy
  Storage/                        Keychain + report store (actor)
  Context/                        Device/app metadata
  UI/                             SwiftUI form, button, My Messages, theme
  Localization/                   English + Persian strings
Tests/RelaySDKTests/
Example/
```

## License

MIT
