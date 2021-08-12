import Postbox
import SwiftSignalKit

public struct WallpapersState: PreferencesEntry, Equatable {
    public var wallpapers: [TelegramWallpaper]

    public static var `default`: WallpapersState {
        return WallpapersState(wallpapers: [])
    }

    public init(wallpapers: [TelegramWallpaper]) {
        self.wallpapers = wallpapers
    }

    public init(decoder: PostboxDecoder) {
        self.wallpapers = decoder.decodeObjectArrayWithDecoderForKey("wallpapers")
    }

    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObjectArray(self.wallpapers, forKey: "wallpapers")
    }

    public func isEqual(to: PreferencesEntry) -> Bool {
        return self == (to as? WallpapersState)
    }
}

public extension WallpapersState {
    static func update(transaction: AccountManagerModifier<TelegramAccountManagerTypes>, _ f: (WallpapersState) -> WallpapersState) {
        transaction.updateSharedData(SharedDataKeys.wallapersState, { current in
            let item = (transaction.getSharedData(SharedDataKeys.wallapersState) as? WallpapersState) ?? WallpapersState(wallpapers: [])
            return f(item)
        })
    }
}
