import Foundation
import TelegramCore

/// A message's locally derived data (`DerivedDataMessageAttribute`) holds independent keys — `"code"` (syntax
/// highlighting), `"mps"` (playback position), `"widget"` (message widget sources) — so every writer changes only
/// its own key, through `engine.messages.updateLocallyDerivedData`: `current` with `key` set to `entry`, or removed
/// when `entry` is nil, and every other key as it was. (`storeLocallyDerivedData` replaces the whole dictionary.)
public func derivedDataSetting(_ current: [String: EngineCodableEntry], key: String, to entry: EngineCodableEntry?) -> [String: EngineCodableEntry] {
    var updated = current
    updated[key] = entry
    return updated
}
