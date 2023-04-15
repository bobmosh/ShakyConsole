import SwiftUI

public extension Shaky {
    enum Tag: String {
        case Network
        case Timing
        case Performance
        case Security
    }
    
    enum Level {
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

public class ShakyLogger: Logger {
    public struct Log: Hashable {
        var value: String
        var level: Shaky.Level
        var tag: Shaky.Tag?
        var timestamp: Date
    }
    
    fileprivate var logs: [Log] = []
    
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
    var logger: ShakyLogger
    
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
        Form {
            ForEach(logger.logs, id: \.self) { log in
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
