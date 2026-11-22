import Foundation

/// Canonical JSON encoding for a `Document`: sorted keys (stable diffs), pretty-printed.
public enum DocumentCodec {
    public static func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys, .prettyPrinted]
        return e
    }

    public static func decoder() -> JSONDecoder {
        JSONDecoder()
    }

    public static func encode(_ document: Document) throws -> Data {
        try encoder().encode(document)
    }

    public static func decode(_ data: Data) throws -> Document {
        try decoder().decode(Document.self, from: data)
    }
}
