import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi

import SyncCore

extension WallpaperSettings {
    init(apiWallpaperSettings: Api.WallPaperSettings) {
        switch apiWallpaperSettings {
            case let .wallPaperSettings(flags, backgroundColor, secondBackgroundColor, intensity, rotation):
                self = WallpaperSettings(blur: (flags & 1 << 1) != 0, motion: (flags & 1 << 2) != 0, color: backgroundColor.flatMap { UInt32(bitPattern: $0) }, bottomColor: secondBackgroundColor.flatMap { UInt32(bitPattern: $0) }, intensity: intensity, rotation: rotation)
        }
    }
}

func apiWallpaperSettings(_ wallpaperSettings: WallpaperSettings) -> Api.WallPaperSettings {
    var flags: Int32 = 0
    if let _ = wallpaperSettings.color {
        flags |= (1 << 0)
    }
    if wallpaperSettings.blur {
        flags |= (1 << 1)
    }
    if wallpaperSettings.motion {
        flags |= (1 << 2)
    }
    if let _ = wallpaperSettings.intensity {
        flags |= (1 << 3)
    }
    if let _ = wallpaperSettings.bottomColor {
        flags |= (1 << 4)
    }
    return .wallPaperSettings(flags: flags, backgroundColor: wallpaperSettings.color.flatMap { Int32(bitPattern: $0) }, secondBackgroundColor: wallpaperSettings.bottomColor.flatMap { Int32(bitPattern: $0) }, intensity: wallpaperSettings.intensity, rotation: wallpaperSettings.rotation ?? 0)
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
                    //assertionFailure()
                    self = .color(0xffffff)
                }
            case let .wallPaperNoFile(flags, settings):
                if let settings = settings, case let .wallPaperSettings(flags, backgroundColor, secondBackgroundColor, intensity, rotation) = settings {
                    if let color = backgroundColor, let bottomColor = secondBackgroundColor {
                        self = .gradient(UInt32(bitPattern: color), UInt32(bitPattern: bottomColor), WallpaperSettings(rotation: rotation))
                    } else if let color = backgroundColor {
                        self = .color(UInt32(bitPattern: color))
                    } else {
                        self = .color(0xffffff)
                    }
                } else {
                    self = .color(0xffffff)
                }
               
        }
    }
    
    var apiInputWallpaperAndSettings: (Api.InputWallPaper?, Api.WallPaperSettings)? {
        switch self {
            case .builtin:
                return nil
            case let .file(file):
                return (.inputWallPaperSlug(slug: file.slug), apiWallpaperSettings(file.settings))
            case let .color(color):
                return (.inputWallPaperNoFile, apiWallpaperSettings(WallpaperSettings(color: color)))
            case let .gradient(topColor, bottomColor, settings):
                return (.inputWallPaperNoFile, apiWallpaperSettings(WallpaperSettings(color: topColor, bottomColor: bottomColor, rotation: settings.rotation)))
            default:
                return nil
        }
    }
}
