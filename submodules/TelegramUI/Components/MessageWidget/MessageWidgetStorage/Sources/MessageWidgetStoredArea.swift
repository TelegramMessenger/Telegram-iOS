import Foundation
import TelegramCore
import MessageWidget

/// A widget's `local` area as its message's derived data keeps it, under `derivedDataKey` (SDK v1 §2.8; the user's
/// decision of 2026-10-20: no separate table): keys and values alternating, in insertion order — one flat array,
/// because Postbox's Codable adapter has no nested containers (an array of arrays traps when it is decoded). An area
/// with no entries is written as one, never removed, because Postbox's attribute merge restores a
/// DerivedDataMessageAttribute an update leaves out.
public struct MessageWidgetStoredArea: Codable, Equatable {
    /// Not `"widget"`: earlier development builds cached widget sources under that key, in another shape, and a decode of
    /// that would trap in Postbox's Codable adapter.
    public static let derivedDataKey = "widgetStorage"

    /// key, value, key, value, …
    public var keysAndValues: [String]

    public init(keysAndValues: [String]) {
        self.keysAndValues = keysAndValues
    }

    public init(_ entries: [MessageWidgetStorage.Entry]) {
        self.keysAndValues = entries.flatMap { [$0.key, $0.value] }
    }

    public var storageEntries: [MessageWidgetStorage.Entry] {
        return stride(from: 0, to: self.keysAndValues.count - 1, by: 2).map { i in
            MessageWidgetStorage.Entry(key: self.keysAndValues[i], value: self.keysAndValues[i + 1])
        }
    }

    /// The area a message's attributes hold; empty when none is stored or it does not decode.
    public static func decode(from attributes: [EngineMessage.Attribute]) -> [MessageWidgetStorage.Entry] {
        for attribute in attributes {
            if let attribute = attribute as? DerivedDataMessageAttribute {
                return attribute.data[MessageWidgetStoredArea.derivedDataKey]?.get(MessageWidgetStoredArea.self)?.storageEntries ?? []
            }
        }
        return []
    }
}

/// The messages of an account whose derived data holds a widget area, so "Clear cache" can empty exactly those (SDK v1
/// §5.4; Postbox has no index of messages by derived-data key).
struct MessageWidgetStorageIndex: Codable, Equatable {
    var messageIds: [EngineMessage.Id]
}
