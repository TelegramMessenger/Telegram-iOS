import Foundation
import QuartzCore

/// Debug-only trace of a physics deceleration, for diagnosing a difference between the `.stepped` and
/// `.keyframe` drivers that neither the deterministic harness nor a synthetic gesture reproduces.
///
/// **Inert unless `isEnabled` is set**, which only the demo does (`ViewController`, excluded from the
/// Bazel `CoreList` library). Every call site is guarded, so the shipping app pays one static Bool read
/// per event and nothing else.
///
/// The load-bearing entry is `noteBaseDrift`. During a `.keyframe` flight `contentHost.bounds.origin.y`
/// is NOT a position — it is the additive animation's base, deliberately parked at the trajectory's
/// `finalOffset` for the whole flight. Anything else writing it mid-flight rebases the animation, which
/// would subtract roughly the flight's remaining travel: invisible in `.stepped`, and worse the faster
/// the flick. This records whether that actually happens.
final class FlightTrace {
    static let shared = FlightTrace()
    /// Set by the demo only. `false` in the shipping app.
    static var isEnabled = false

    private var lines: [String] = []
    private var t0: CFTimeInterval = CACurrentMediaTime()
    private let lock = NSLock()

    private init() {}

    func begin(_ header: String) {
        guard Self.isEnabled else { return }
        lock.lock(); defer { lock.unlock() }
        t0 = CACurrentMediaTime()
        lines.append("===== \(header) =====")
    }

    func log(_ message: @autoclosure () -> String) {
        guard Self.isEnabled else { return }
        lock.lock(); defer { lock.unlock() }
        guard lines.count < 4000 else { return }            // bounded: a long flight is ~400 ticks
        lines.append(String(format: "%7.3fms %@", (CACurrentMediaTime() - t0) * 1000, message()))
    }

    /// Append the buffered trace to `Documents/flight-trace.txt` and clear it. Called at the end of every
    /// flight, so a device run can be pulled with `devicectl` without a console.
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
}
