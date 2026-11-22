import Foundation
import QuartzCore

/// Debug-only trace of a physics deceleration, for diagnosing a difference between the `.stepped` and
/// `.keyframe` drivers that neither the deterministic harness nor a synthetic gesture reproduces.
///
/// **Inert unless `isEnabled` is set**, which the demo does (`ViewController`, excluded from the Bazel
/// `CoreList` library) and the app does from Debug Settings ▸ "Chat: CoreList scroll trace"
/// (`CoreListScrollTrace`). Every call site is guarded, so with it off the app pays one static Bool read per
/// event and nothing else.
///
/// The load-bearing entry is `noteBaseDrift`. During a `.keyframe` flight `contentHost.bounds.origin.y`
/// is NOT a position — it is the additive animation's base, deliberately parked at the trajectory's
/// `finalOffset` for the whole flight. Anything else writing it mid-flight rebases the animation, which
/// would subtract roughly the flight's remaining travel: invisible in `.stepped`, and worse the faster
/// the flick. This records whether that actually happens.
final class FlightTrace {
    static let shared = FlightTrace()
    /// Set by the demo, and by the app's Debug Settings switch. `false` in the shipping app.
    static var isEnabled = false
    /// Also handed every line as it is logged: the app forwards them to its own log (`CoreListScrollTrace.sink`).
    static var sink: ((String) -> Void)?

    /// Buffered lines are written out once this many have collected, so a long session loses none.
    private static let flushLineCount = 2000
    /// The file is moved aside to `flight-trace.1.txt` (replacing the previous one) past this size.
    private static let maximumFileSize = 8 * 1024 * 1024

    private var lines: [String] = []
    private var t0: CFTimeInterval = CACurrentMediaTime()
    private let lock = NSLock()

    private init() {}

    func begin(_ header: String) {
        guard Self.isEnabled else { return }
        lock.lock(); defer { lock.unlock() }
        t0 = CACurrentMediaTime()
        let line = String(format: "%.3f ===== %@ =====", t0, header)
        lines.append(line)
        Self.sink?(line)
    }

    /// Each line carries the media time (seconds, the clock touch timestamps and `CACurrentMediaTime` share), so
    /// lines from different flights and from the host interleave on one timeline, then the time since the
    /// last `begin`.
    func log(_ message: @autoclosure () -> String) {
        guard Self.isEnabled else { return }
        let now = CACurrentMediaTime()
        let line = String(format: "%.3f %7.3fms %@", now, (now - t0) * 1000, message())
        Self.sink?(line)
        lock.lock()
        lines.append(line)
        let isFull = lines.count >= Self.flushLineCount
        lock.unlock()
        if isFull {
            flush()
        }
    }

    /// Append the buffered trace to `Documents/flight-trace.txt` and clear it. Called at the end of every
    /// flight and every gesture, so a device run can be pulled with `devicectl` without a console.
    @discardableResult
    func flush() -> URL? {
        guard Self.isEnabled else { return nil }
        lock.lock()
        let body = lines.joined(separator: "\n") + "\n"
        lines.removeAll(keepingCapacity: true)
        lock.unlock()
        guard body.count > 1,
              let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        else { return nil }
        let url = dir.appendingPathComponent("flight-trace.txt")
        if let size = (try? FileManager.default.attributesOfItem(atPath: url.path))?[.size] as? Int, size > Self.maximumFileSize {
            let previous = dir.appendingPathComponent("flight-trace.1.txt")
            try? FileManager.default.removeItem(at: previous)
            try? FileManager.default.moveItem(at: url, to: previous)
        }
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(Data(body.utf8))
            try? handle.close()
        } else {
            try? Data(body.utf8).write(to: url)
        }
        NSLog("[FlightTrace] %@", body)                     // also to the unified log, if a console is up
        return url
    }

    /// The functions that called the caller of this, as symbol names (mangled; `xcrun swift-demangle` reads
    /// them), for a line that has to say what moved the list. Only built while tracing.
    static func callers(_ count: Int) -> String {
        let symbols = Thread.callStackSymbols.dropFirst(2).prefix(count).map { frame -> String in
            let parts = frame.split(separator: " ", omittingEmptySubsequences: true)
            return parts.count > 3 ? String(parts[3]) : frame
        }
        return symbols.joined(separator: " < ")
    }
}

/// The chat's scroll trace (Debug Settings ▸ "Chat: CoreList scroll trace"): `FlightTrace` switched on in the app,
/// plus the lines a host adds about what it asked the list to do. Written to `Documents/flight-trace.txt` in the app's
/// own container. Every call is a no-op while it is off.
public enum CoreListScrollTrace {
    public static var isEnabled: Bool {
        get { FlightTrace.isEnabled }
        set { FlightTrace.isEnabled = newValue }
    }

    public static func log(_ message: @autoclosure () -> String) {
        guard FlightTrace.isEnabled else { return }
        FlightTrace.shared.log(message())
    }

    public static func flush() {
        FlightTrace.shared.flush()
    }

    /// Receives every line as it is logged, besides the file (the app hands them to its own log).
    public static var sink: ((String) -> Void)? {
        get { FlightTrace.sink }
        set { FlightTrace.sink = newValue }
    }

    /// The `count` functions above the caller of this one (see `FlightTrace.callers`).
    public static func callers(_ count: Int = 6) -> String {
        guard FlightTrace.isEnabled else { return "" }
        return FlightTrace.callers(count + 1).components(separatedBy: " < ").dropFirst().joined(separator: " < ")
    }
}
