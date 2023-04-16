import SwiftUI

public extension Shaky {
    enum Tag: String {
        case Network
        case Timing
        case Performance
        case Security
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
        loggers.forEach { logger in
            logger.log(value: value, level: level, tag: tag)
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

public class ShakyLogger: Logger, ObservableObject {
    public struct Log: Hashable {
        var value: String
        var level: Shaky.Level
        var tag: Shaky.Tag?
        var timestamp: Date
    }
    
    @Published private var logs: [Log] = []
    @Published fileprivate var levelFilter: [Shaky.Level] = []
    
    fileprivate var filteredLogs: [Log] {
        if levelFilter != [] {
            return logs.filter { levelFilter.contains($0.level) }
        } else { return logs }
    }
    
    public func log(value: String, level: Shaky.Level, tag: Shaky.Tag?) {
        logs.append(
            Log(
                value: value,
                level: level,
                tag: tag,
                timestamp: Date()
            )
        )
    }
}

public struct ShakyLoggerSheet: View {
    @ObservedObject var logger: ShakyLogger
    
    public init(logger: ShakyLogger) {
        self.logger = logger
    }
    
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
    
    public var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal) {
                HStack {
                    ForEach(Shaky.Level.allCases, id: \.self) { level in
                        Button {
                            if logger.levelFilter.contains(level) {
                                logger.levelFilter.removeAll { $0 == level }
                            } else {
                                logger.levelFilter.append(level)
                            }
                        } label: {
                            Text(level.rawValue)
                                .padding(4)
                                .padding(.horizontal, 8)
                                .background(logger.levelFilter.contains(level) ? level.color.opacity(0.4) : level.color.opacity(0.1))
                                .cornerRadius(100)
                        }
                        .foregroundColor(.primary)
                    }
                }
            }
            .padding([.top, .horizontal], 24)
            
            Form {
                ForEach(logger.filteredLogs, id: \.self) { log in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "circle.fill")
                                .foregroundColor(log.level.color)
                                .font(.system(size: 8))
                            Text(log.value)
                            
                            Spacer()
                            
                            VStack {
                                Text(dateFormatter.string(from: log.timestamp))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text(timeFormatter.string(from: log.timestamp))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if let tag = log.tag {
                            Text("#\(tag.rawValue)")
                                .font(.system(size: 8))
                                .padding(4)
                                .padding(.horizontal, 6)
                                .background(Color.secondary.opacity(0.3))
                                .cornerRadius(100)
                        }
                    }
                }
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
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
    func shaky(with logger: ShakyLogger) -> some View {
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
