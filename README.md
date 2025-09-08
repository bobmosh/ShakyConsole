## ShakyConsole

A lightweight, in-app logging console for SwiftUI that you can summon by shaking the device. Filter by level and tag, browse recent events, and share logs as a text file. Plug in your own loggers to forward events to the system console, your backend, or any destination you like.

### Features
- **Shake to open**: Present a log viewer anywhere in your app with a device shake
- **Filters**: Toggle by **level** and **tag** to focus on what matters
- **Share logs**: Export the current view as a `.txt` file via the system share sheet
- **Pluggable loggers**: Conform to `Logger` to forward logs to other systems
- **SwiftUI-first**: Provide `View` modifiers and a ready-to-use `Sheet`

### Requirements
- **Swift**: 5.8+
- **Platforms**: iOS 14+. The included shake-to-open UI uses UIKit; macOS is not currently supported for that part. You can still present `ShakyLoggerSheet` manually on other platforms if you conditionally compile the UIKit-dependent code.

### Installation (Swift Package Manager)
Add the package to your project:

- In Xcode: File → Add Packages… and enter your repository URL (for example: `https://github.com/<owner>/ShakyConsole.git`).
- Or add it to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/<owner>/ShakyConsole.git", from: "0.1.0")
]

targets: [
    .target(
        name: "YourApp",
        dependencies: ["ShakyConsole"]
    )
]
```

### Quick start
1) Import and enable the shake-to-open console on your root view:

```swift
import SwiftUI
import ShakyConsole

@main
struct YourApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .shaky(with: Shaky.shakyLogger) // Shake device to open the console
        }
    }
}
```

2) Start logging anywhere in your code:

```swift
Shaky.log(value: "User tapped refresh", level: .Debug, tag: .Network)
Shaky.log(value: "Cache miss", level: .Warning, tag: .Performance)
Shaky.log(value: "Unauthorized", level: .Critical, tag: .Security)
Shaky.log(value: "Plain message with defaults")
```

3) (Optional) Also log to the Xcode console:

```swift
Shaky.add(logger: ConsoleLogger())
```

### Logging API
- **Levels** (`Shaky.Level`): `.None`, `.Debug`, `.Warning`, `.Critical`
- **Tags** (`Shaky.Tag`): `.Network`, `.Timing`, `.Performance`, `.Security`, `.Custom(String)`

Core API:

```swift
Shaky.log(value: String, level: Shaky.Level = .None, tag: Shaky.Tag? = nil)
Shaky.add(logger: Logger)
```

The built-in `ShakyLogger` captures events for the UI console, and is exposed at `Shaky.shakyLogger`.

### Showing the console
- **Shake to open (iOS)**: Attach the modifier to any view to present the built-in sheet when the device is shaken.

```swift
SomeView()
    .shaky(with: Shaky.shakyLogger)
```

- **Manual presentation**: Present the sheet yourself (useful on platforms without shake detection or behind a dedicated button):

```swift
@State private var showingLogs = false

var body: some View {
    Button("Show Logs") { showingLogs = true }
        .sheet(isPresented: $showingLogs) {
            ShakyLoggerSheet(logger: Shaky.shakyLogger)
        }
}
```

### Sharing and formatting
- Tap the share button in the console to export the currently filtered logs as `.txt`.
- Each log can be rendered as a string internally via `Log.toString(components:)`, which supports values, level, tag, and timestamp.

### Custom loggers
Forward logs to other destinations by conforming to `Logger` and registering your logger:

```swift
struct RemoteLogger: Logger {
    func log(value: String, level: Shaky.Level, tag: Shaky.Tag?) {
        // Send to your backend, OSLog, analytics, etc.
    }
}

Shaky.add(logger: RemoteLogger())
```

Built-in helpers:
- `ConsoleLogger`: Prints values to the Xcode console
- `ShakyLogger`: Stores entries for the on-device UI console

### Simulator tips
- Trigger a shake in the iOS Simulator via Hardware → Shake Gesture (⌃⌘Z).

### Example app
See `Examples/Examples` for a minimal SwiftUI app that demonstrates:
- Registering a logger (`ConsoleLogger`)
- Sending logs with different levels and tags
- Presenting the console via `.shaky(with:)`

### Notes
- The bundled shake detector uses UIKit (`UIWindow` motion events) and the system share sheet (`UIActivityViewController`), which are iOS-only.
- Log dispatch to registered loggers occurs on the main actor to keep UI state consistent.

### Contributing
Issues and pull requests are welcome! Please include clear steps to reproduce when filing a bug.

### License
See `LICENSE` for details.
