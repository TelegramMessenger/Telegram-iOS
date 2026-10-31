import Foundation

/// widget-sandbox's stress kit as a tag ships it (`packages/stress`, vendored at `third-party/widget-sandbox/stress`):
/// `manifest.json`'s run order and timings, and each widget's file under `widgets/`.
public struct MessageWidgetStressKit {
    public struct Entry: Equatable {
        /// `<load>/<value>`, e.g. `shadow-moving/16`.
        public let id: String
        /// Relative to the kit's root, e.g. `widgets/shadow-moving/000016.html`.
        public let file: String
        public let load: String
        public let level: Int
        public let value: Double
    }

    public enum LoadError: Error {
        case unreadable(String)
    }

    /// manifest.json's `version`.
    public let version: Int
    /// manifest.json's `run`: the warm-up and the measuring window (ms) and the reference width (points).
    public let warmupMs: Double
    public let measureMs: Double
    public let width: Double
    /// In the manifest's order: a load's levels together, from the lightest.
    public let entries: [Entry]
    public let root: URL

    /// The kit at `root` (the directory holding manifest.json and widgets/).
    public init(root: URL) throws {
        guard let data = try? Data(contentsOf: root.appendingPathComponent("manifest.json")),
              let manifest = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let widgets = manifest["widgets"] as? [[String: Any]] else {
            throw LoadError.unreadable("manifest.json")
        }
        let run = manifest["run"] as? [String: Any]
        self.root = root
        self.version = (manifest["version"] as? Int) ?? 0
        self.warmupMs = (run?["warmupMs"] as? NSNumber)?.doubleValue ?? 2000.0
        self.measureMs = (run?["measureMs"] as? NSNumber)?.doubleValue ?? 10000.0
        self.width = (run?["width"] as? NSNumber)?.doubleValue ?? 390.0
        self.entries = try widgets.map { widget in
            guard let id = widget["id"] as? String, let file = widget["file"] as? String, let load = widget["load"] as? String else {
                throw LoadError.unreadable("a widget without id, file or load")
            }
            return Entry(id: id, file: file, load: load, level: (widget["level"] as? Int) ?? 0, value: (widget["value"] as? NSNumber)?.doubleValue ?? 0.0)
        }
    }

    public func source(of entry: Entry) throws -> String {
        guard let source = try? String(contentsOf: self.root.appendingPathComponent(entry.file), encoding: .utf8) else {
            throw LoadError.unreadable(entry.file)
        }
        return source
    }
}
