import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi


extension WallpaperSettings {
    init(apiWallpaperSettings: Api.WallPaperSettings) {
        switch apiWallpaperSettings {
        case let .wallPaperSettings(flags, backgroundColor, secondBackgroundColor, thirdBackgroundColor, fourthBackgroundColor, intensity, rotation):
            var colors: [UInt32] = []
            if let backgroundColor = backgroundColor {
                colors.append(UInt32(bitPattern: backgroundColor))
            }
            if let secondBackgroundColor = secondBackgroundColor {
                colors.append(UInt32(bitPattern: secondBackgroundColor))
            }
            if let thirdBackgroundColor = thirdBackgroundColor {
                colors.append(UInt32(bitPattern: thirdBackgroundColor))
            }
            if let fourthBackgroundColor = fourthBackgroundColor {
                colors.append(UInt32(bitPattern: fourthBackgroundColor))
            }
            self = WallpaperSettings(blur: (flags & 1 << 1) != 0, motion: (flags & 1 << 2) != 0, colors: colors, intensity: intensity, rotation: rotation)
        }
    }
}

func apiWallpaperSettings(_ wallpaperSettings: WallpaperSettings) -> Api.WallPaperSettings {
    var flags: Int32 = 0
    var backgroundColor: Int32?
    if wallpaperSettings.colors.count >= 1 {
        flags |= (1 << 0)
        backgroundColor = Int32(bitPattern: wallpaperSettings.colors[0])
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
    var secondBackgroundColor: Int32?
    if wallpaperSettings.colors.count >= 2 {
        flags |= (1 << 4)
        secondBackgroundColor = Int32(bitPattern: wallpaperSettings.colors[1])
    }
    var thirdBackgroundColor: Int32?
    if wallpaperSettings.colors.count >= 3 {
        flags |= (1 << 5)
        thirdBackgroundColor = Int32(bitPattern: wallpaperSettings.colors[2])
    }
    var fourthBackgroundColor: Int32?
    if wallpaperSettings.colors.count >= 4 {
        flags |= (1 << 6)
        fourthBackgroundColor = Int32(bitPattern: wallpaperSettings.colors[3])
    }
    return .wallPaperSettings(flags: flags, backgroundColor: backgroundColor, secondBackgroundColor: secondBackgroundColor, thirdBackgroundColor: thirdBackgroundColor, fourthBackgroundColor: fourthBackgroundColor, intensity: wallpaperSettings.intensity, rotation: wallpaperSettings.rotation ?? 0)
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
                    self = .file(TelegramWallpaper.File(id: id, accessHash: accessHash, isCreator: (flags & 1 << 0) != 0, isDefault: (flags & 1 << 1) != 0, isPattern: (flags & 1 << 3) != 0, isDark: (flags & 1 << 4) != 0, slug: slug, file: file, settings: wallpaperSettings))
                } else {
                    //assertionFailure()
                    self = .color(0xffffff)
                }
            case let .wallPaperNoFile(id, _, settings):
                if let settings = settings, case let .wallPaperSettings(_, backgroundColor, secondBackgroundColor, thirdBackgroundColor, fourthBackgroundColor, _, rotation) = settings {
                    let colors: [UInt32] = ([backgroundColor, secondBackgroundColor, thirdBackgroundColor, fourthBackgroundColor] as [Int32?]).compactMap({ color -> UInt32? in
                        return color.flatMap(UInt32.init(bitPattern:))
                    })
                    if colors.count > 1 {
                        self = .gradient(TelegramWallpaper.Gradient(id: id, colors: colors, settings: WallpaperSettings(rotation: rotation)))
                    } else if colors.count == 1 {
                        self = .color(UInt32(bitPattern: colors[0]))
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
            return (.inputWallPaperNoFile(id: 0), apiWallpaperSettings(WallpaperSettings(colors: [color])))
        case let .gradient(gradient):
            return (.inputWallPaperNoFile(id: gradient.id ?? 0), apiWallpaperSettings(WallpaperSettings(colors: gradient.colors, rotation: gradient.settings.rotation)))
        default:
            return nil
        }
    }
}
