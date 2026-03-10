import SwiftUI

public extension Shaky {
    enum Tag: Hashable {
        case Network
        case Timing
        case Performance
        case Security
        case Custom(String)
        
        var name: String {
            switch self {
            case .Network: return "Network"
            case .Timing: return "Timing"
            case .Performance: return "Performance"
            case .Security: return "Security"
            case let .Custom(name): return name
            }
        }
    }
    
    enum Level: String, CaseIterable {
        case None
        case Debug
        case Warning
        case Critical
        
        var color: Color {
            switch self {
            case .None: return Color.blue
            case .Debug: return Color.green
            case .Warning: return Color.orange
            case .Critical: return Color.red
            }
        }
    }
}

public struct Shaky {
    public static let shared = Shaky()
    public static let shakyLogger = ShakyLogger()
    fileprivate static var loggers: [Logger] = [shakyLogger]

    public static func log(value: String, level: Level = .None, tag: Tag? = nil) {
        Task { @MainActor in
            for logger in loggers {
                logger.log(value: value, level: level, tag: tag)
            }
        }
    }

    public static func add(logger: Logger) {
        Shaky.loggers.append(logger)
    }
}

public protocol Logger {
    func log(value: String, level: Shaky.Level, tag: Shaky.Tag?)
}

public struct ConsoleLogger: Logger {
    public init() {}
    public func log(value: String, level: Shaky.Level, tag: Shaky.Tag?) {
        print(value)
    }
}

public struct Log: Hashable {
    var value: String
    var level: Shaky.Level
    var tag: Shaky.Tag?
    var timestamp: Date

    public enum DisplayComponent {
        case value
        case level
        case tag
        case timestamp

        public static let full: Set<DisplayComponent> = [.value, .level, .tag, .timestamp]
        public static let reduced: Set<DisplayComponent> = [.timestamp, .value]
    }


    public func toString(components: Set<DisplayComponent> = DisplayComponent.full) -> String {
        var parts: [String] = []

        if components.contains(.level) {
            parts.append("[\(level.rawValue)]")
        }
        if components.contains(.value) {
            parts.append("\(value)")
        }
        if components.contains(.timestamp) {
            parts.append("[\(timestamp)]")
        }
        if components.contains(.tag), let tag = tag {
            parts.append("[\(tag.name)]")
        }

        return parts.joined(separator: " ")
    }
}

public class ShakyLogger: Logger, ObservableObject {
    @Published private var logs: [Log] = []
    @Published fileprivate var levelFilter: [Shaky.Level] = []
    @Published fileprivate var tagFilter: [Shaky.Tag] = []
    fileprivate var availableTags: [Shaky.Tag] {
        Array(Set(logs.compactMap { $0.tag }))
            .sorted(by: { lhs, rhs in
                lhs.name < rhs.name
            })
            .sorted { lhs, rhs in
                tagFilter.contains(lhs)
            }
    }
    
    /// Full, unfiltered logs — use for export so users always get complete logs.
    fileprivate var allLogs: [Log] { logs }

    fileprivate var filteredLogs: [Log] {
        let levelFiltered = logs.filter { log in
            guard !levelFilter.isEmpty else { return true }
            return levelFilter.contains(log.level)
        }

        let tagFiltered = levelFiltered.filter { log in
            guard !tagFilter.isEmpty else { return true }
            guard let tag = log.tag else { return false }
            return tagFilter.contains(tag)
        }

        return tagFiltered
    }
    
    public func log(value: String, level: Shaky.Level, tag: Shaky.Tag?) {
        logs.insert(
            Log(
                value: value,
                level: level,
                tag: tag,
                timestamp: Date()
            ),
            at: 0
        )
    }
}

public struct ShakyLoggerSheet: View {
    @ObservedObject var logger: ShakyLogger = Shaky.shakyLogger
    
    var dateFormatter: DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .none
        return dateFormatter
    }
    
    var timeFormatter: DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .none
        dateFormatter.timeStyle = .medium
        return dateFormatter
    }

    private func share(logs: String) {
        DispatchQueue.main.async {
            let tempDir = FileManager.default.temporaryDirectory
            let fileURL = tempDir.appendingPathComponent("log.txt")

            do {
                try logs.write(to: fileURL, atomically: true, encoding: .utf8)
                let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
                if let topController = UIApplication.shared.windows.first?.rootViewController {
                    var presentedVC = topController
                    while let nextVC = presentedVC.presentedViewController {
                        presentedVC = nextVC
                    }
                    if let popoverController = activityVC.popoverPresentationController {
                        popoverController.sourceView = presentedVC.view
                        popoverController.sourceRect = CGRect(x: presentedVC.view.bounds.midX, y: presentedVC.view.bounds.midY, width: 0, height: 0)
                        popoverController.permittedArrowDirections = []
                    }
                    presentedVC.present(activityVC, animated: true, completion: nil)
                }
            } catch {
                print("Failed to write log to file: \(error)")
            }
        }
    }

    private var isEmptyState: Bool {
        logger.filteredLogs.isEmpty
    }

    private var hasNoLogsAtAll: Bool {
        logger.allLogs.isEmpty
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header: title + export
            headerView

            // Filters: levels + tags
            filterSection

            // Content: list or empty state
            if isEmptyState {
                emptyStateView
            } else {
                logListView
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
        .edgesIgnoringSafeArea(.all)
    }

    private var headerView: some View {
        HStack {
            Text("Logs")
                .font(.headline)
                .foregroundColor(.primary)

            Spacer()

            Button {
                let shareText = logger.allLogs.toString()
                share(logs: shareText)
            } label: {
                Label("Export logs", systemImage: "square.and.arrow.up")
                    .font(.subheadline)
            }
            .buttonStyle(ExportButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private var filterSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Shaky.Level.allCases, id: \.self) { level in
                        levelFilterChip(level)
                    }
                }
                .padding(.horizontal, 20)
            }

            if !logger.availableTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(logger.availableTags, id: \.self) { tag in
                            tagFilterChip(tag)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .padding(.bottom, 16)
    }

    private func levelFilterChip(_ level: Shaky.Level) -> some View {
        let isActive = logger.levelFilter.contains(level)
        return Button {
            if isActive {
                logger.levelFilter.removeAll { $0 == level }
            } else {
                logger.levelFilter.append(level)
            }
        } label: {
            Text(level.rawValue)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isActive ? level.color.opacity(0.35) : level.color.opacity(0.12))
                )
                .foregroundColor(isActive ? .primary : .secondary)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func tagFilterChip(_ tag: Shaky.Tag) -> some View {
        let isActive = logger.tagFilter.contains(tag)
        return Button {
            if isActive {
                logger.tagFilter.removeAll { $0 == tag }
            } else {
                logger.tagFilter.append(tag)
            }
        } label: {
            Text("#\(tag.name)")
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isActive ? Color.secondary.opacity(0.35) : Color.secondary.opacity(0.12))
                )
                .foregroundColor(isActive ? .primary : .secondary)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 48)

            Image(systemName: hasNoLogsAtAll ? "doc.text" : "line.3.horizontal.decrease.circle")
                .font(.system(size: 44))
                .foregroundColor(Color(UIColor.tertiaryLabel))

            Text(hasNoLogsAtAll ? "No logs yet" : "No matches")
                .font(.headline)
                .foregroundColor(.primary)

            Text(hasNoLogsAtAll
                ? "Logs will appear here when you use Shaky.log() in your app."
                : "Try adjusting your level or tag filters.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer(minLength: 48)
        }
        .frame(maxWidth: .infinity)
    }

    private var logListView: some View {
        listContent
    }

    @ViewBuilder
    private var listContent: some View {
        let list = List {
            ForEach(logger.filteredLogs, id: \.self) { log in
                logRow(log)
            }
        }
        .listStyle(.plain)

        if #available(iOS 16.0, *) {
            list.scrollContentBackground(.hidden)
        } else {
            list
        }
    }

    private func logRow(_ log: Log) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(log.level.color)
                .frame(width: 8, height: 8)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(log.value)
                        .font(.subheadline)
                        .foregroundColor(.primary)

                    if let tag = log.tag {
                        Text(tag.name)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(Color.secondary.opacity(0.2))
                            )
                            .foregroundColor(.secondary)
                    }
                }

                Text(timeFormatter.string(from: log.timestamp))
                    .font(.caption2)
                    .foregroundColor(Color(UIColor.tertiaryLabel))
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
}

private struct ExportButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentColor.opacity(configuration.isPressed ? 0.2 : 0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.accentColor.opacity(0.4), lineWidth: 1)
            )
    }
}

struct ShakySheet: ViewModifier {
    @State var isPresenting: Bool = false
    var shakyLogger: ShakyLogger
    
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresenting) { ShakyLoggerSheet(logger: shakyLogger) }
            .onShake { isPresenting = true }
    }
}

public extension View {
    func shaky(with logger: ShakyLogger = Shaky.shakyLogger) -> some View {
        modifier(ShakySheet(shakyLogger: logger))
    }
}


// The notification we'll send when a shake gesture happens.
extension UIDevice {
    static let deviceDidShakeNotification = Notification.Name(rawValue: "deviceDidShakeNotification")
}

//  Override the default behavior of shake gestures to send our notification instead.
extension UIWindow {
     open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            NotificationCenter.default.post(name: UIDevice.deviceDidShakeNotification, object: nil)
        }
     }
}

// A view modifier that detects shaking and calls a function of our choosing.
struct DeviceShakeViewModifier: ViewModifier {
    let action: () -> Void

    func body(content: Content) -> some View {
        content
            .onAppear()
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.deviceDidShakeNotification)) { _ in
                action()
            }
    }
}

// A View extension to make the modifier easier to use.
extension View {
    func onShake(perform action: @escaping () -> Void) -> some View {
        self.modifier(DeviceShakeViewModifier(action: action))
    }
}

extension [Log] {
    func toString() -> String {
        self.map { $0.toString() }.joined(separator: "\n")
    }
}

#if DEBUG
struct ShakyLoggerSheet_Previews: PreviewProvider {
    static var previews: some View {
        let logger = ShakyLogger()
        return ShakyLoggerSheet(logger: logger)
            .onAppear {
                logger.log(value: "User tapped refresh", level: .Debug, tag: .Network)
                logger.log(value: "Cache miss", level: .Warning, tag: .Performance)
                logger.log(value: "Unauthorized", level: .Critical, tag: .Security)
                logger.log(value: "Plain message with defaults", level: .None, tag: nil)
            }
    }
}
#endif
