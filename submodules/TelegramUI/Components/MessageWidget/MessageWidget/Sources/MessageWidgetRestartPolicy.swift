import Foundation

/// SDK v1 §5.7 (V2b plan, Task 5): a stopped widget is built again the next time its bubble is shown; after
/// `maximumStopsInARow` stops in a row it stays stopped until the app restarts (this lives in memory) or the message
/// is edited with new HTML (a new source, a new key). A run that ends without a stop starts the count over. Main
/// thread only.
public final class MessageWidgetRestartPolicy {
    public struct Key: Hashable {
        public let owner: AnyHashable
        public let source: String

        public init(owner: AnyHashable, source: String) {
            self.owner = owner
            self.source = source
        }
    }

    public static let shared = MessageWidgetRestartPolicy()
    public static let maximumStopsInARow = 2

    private var stops: [Key: Int] = [:]

    public init() {
    }

    public func allowsBoot(_ key: Key) -> Bool {
        return self.stopsInARow(key) < MessageWidgetRestartPolicy.maximumStopsInARow
    }

    public func noteStopped(_ key: Key) {
        self.stops[key, default: 0] += 1
    }

    public func noteEndedWithoutStop(_ key: Key) {
        self.stops[key] = nil
    }

    func stopsInARow(_ key: Key) -> Int {
        return self.stops[key] ?? 0
    }
}
