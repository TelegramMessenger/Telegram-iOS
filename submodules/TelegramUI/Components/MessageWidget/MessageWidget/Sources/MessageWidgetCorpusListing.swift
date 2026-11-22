import Foundation

/// widget-sandbox's corpus as the DEBUG corpus sender posts it: every `.html` under every folder of `root` but
/// `attacks`, sorted by its path relative to `root` (`htmlbubbles-ported/06-trip-lisbon/04-tom.html`).
public enum MessageWidgetCorpusListing {
    public struct Item: Equatable {
        public let path: String
        public let label: String
        public let source: String
    }

    public static func items(in root: URL) -> [Item] {
        guard let walk = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
            return []
        }
        let prefix = root.standardizedFileURL.resolvingSymlinksInPath().path + "/"
        var items: [Item] = []
        for case let url as URL in walk where url.pathExtension == "html" {
            let path = String(url.standardizedFileURL.resolvingSymlinksInPath().path.dropFirst(prefix.count))
            if path.hasPrefix("attacks/") {
                continue
            }
            guard let source = try? String(contentsOf: url, encoding: .utf8) else {
                continue
            }
            items.append(Item(path: path, label: "widget-sandbox " + path, source: source))
        }
        return items.sorted { $0.path < $1.path }
    }
}
