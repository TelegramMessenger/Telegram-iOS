import Foundation
#if os(macOS)
import PostboxMac
import SwiftSignalKitMac
import TelegramApiMac
#else
import Postbox
import SwiftSignalKit
import TelegramApi
#endif

import SyncCore

extension WallpaperSettings {
    init(apiWallpaperSettings: Api.WallPaperSettings) {
        switch apiWallpaperSettings {
            case let .wallPaperSettings(flags, backgroundColor, intensity):
                self = WallpaperSettings(blur: (flags & 1 << 1) != 0, motion: (flags & 1 << 2) != 0, color: backgroundColor, intensity: intensity)
        }
    }
}

func apiWallpaperSettings(_ wallpaperSettings: WallpaperSettings) -> Api.WallPaperSettings {
    var flags: Int32 = 0
    if wallpaperSettings.blur {
        flags |= (1 << 1)
    }
    if wallpaperSettings.motion {
        flags |= (1 << 2)
    }
    return .wallPaperSettings(flags: flags, backgroundColor: wallpaperSettings.color, intensity: wallpaperSettings.intensity)
}

extension TelegramWallpaper {
    init(apiWallpaper: Api.WallPaper) {
        switch apiWallpaper {
            case let .wallPaper(id, flags, accessHash, slug, document, settings):
                if let file = telegramMediaFileFromApiDocument(document) {
                    let wallpaperSettings: WallpaperSettings
                    if let settings = settings {
                        wallpaperSettings = WallpaperSettings(apiWallpaperSettings: settings)
                    } else {
                        wallpaperSettings = WallpaperSettings()
                    }
                    self = .file(id: id, accessHash: accessHash, isCreator: (flags & 1 << 0) != 0, isDefault: (flags & 1 << 1) != 0, isPattern: (flags & 1 << 3) != 0, isDark: (flags & 1 << 4) != 0, slug: slug, file: file, settings: wallpaperSettings)
                } else {
                    assertionFailure()
                    self = .color(0xffffff)
                }
        }
    }
}
