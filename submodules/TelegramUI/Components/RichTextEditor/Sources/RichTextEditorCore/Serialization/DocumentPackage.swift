import Foundation

/// A `.rtdoc` document package: a folder containing `document.json` and an `assets/` directory
/// keyed by `MediaBlock.mediaID` (filename). UIKit-free; media bytes are opaque `Data`.
public struct DocumentPackage: Equatable {
    public var document: Document
    public var assets: [String: Data]

    public init(document: Document, assets: [String: Data] = [:]) {
        self.document = document
        self.assets = assets
    }

    public func write(to url: URL) throws {
        let fm = FileManager.default
        let assetsDir = url.appendingPathComponent("assets")
        try fm.createDirectory(at: assetsDir, withIntermediateDirectories: true)
        try DocumentCodec.encode(document)
            .write(to: url.appendingPathComponent("document.json"), options: .atomic)
        for (name, data) in assets {
            try data.write(to: assetsDir.appendingPathComponent(name), options: .atomic)
        }
    }

    public static func read(from url: URL) throws -> DocumentPackage {
        let fm = FileManager.default
        let document = try DocumentCodec.decode(
            Data(contentsOf: url.appendingPathComponent("document.json")))
        var assets: [String: Data] = [:]
        let assetsDir = url.appendingPathComponent("assets")
        if let names = try? fm.contentsOfDirectory(atPath: assetsDir.path) {
            for name in names {
                assets[name] = try Data(contentsOf: assetsDir.appendingPathComponent(name))
            }
        }
        return DocumentPackage(document: document, assets: assets)
    }
}
