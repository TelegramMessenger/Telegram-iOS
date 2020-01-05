import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi

import SyncCore

extension TelegramTheme {
    convenience init?(apiTheme: Api.Theme) {
        switch apiTheme {
            case let .theme(flags, id, accessHash, slug, title, document, settings, installCount):
                self.init(id: id, accessHash: accessHash, slug: slug, title: title, file: document.flatMap(telegramMediaFileFromApiDocument), settings: settings.flatMap(TelegramThemeSettings.init(apiThemeSettings:)), isCreator: (flags & 1 << 0) != 0, isDefault: (flags & 1 << 1) != 0, installCount: installCount)
            default:
                return nil
        }
    }
}

extension TelegramBaseTheme {
    init(apiBaseTheme: Api.BaseTheme) {
        switch apiBaseTheme {
            case .baseThemeClassic:
                self = .classic
            case .baseThemeDay:
                self = .day
            case .baseThemeNight:
                self = .night
            case .baseThemeTinted:
                self = .tinted
            case .baseThemeArctic:
                self = .day
        }
    }
    
    var apiBaseTheme: Api.BaseTheme {
        switch self {
            case .classic:
                return .baseThemeClassic
            case .day:
                return .baseThemeDay
            case .night:
                return .baseThemeNight
            case .tinted:
                return .baseThemeTinted
        }
    }
}

extension TelegramThemeSettings {
    convenience init?(apiThemeSettings: Api.ThemeSettings) {
        switch apiThemeSettings {
            case let .themeSettings(flags, baseTheme, accentColor, messageTopColor, messageBottomColor, wallpaper):
                var messageColors: (UInt32, UInt32)?
                if let messageTopColor = messageTopColor, let messageBottomColor = messageBottomColor {
                    messageColors = (UInt32(bitPattern: messageTopColor), UInt32(bitPattern: messageBottomColor))
                }
                self.init(baseTheme: TelegramBaseTheme(apiBaseTheme: baseTheme) ?? .classic, accentColor: UInt32(bitPattern: accentColor), messageColors: messageColors, wallpaper: wallpaper.flatMap(TelegramWallpaper.init(apiWallpaper:)))
            default:
                return nil
        }
    }
    
    var apiInputThemeSettings: Api.InputThemeSettings {
        var flags: Int32 = 0
        if let _ = self.messageColors {
            flags |= 1 << 0
        }
        
        var inputWallpaper: Api.InputWallPaper?
        var inputWallpaperSettings: Api.WallPaperSettings?
        if let wallpaper = self.wallpaper, let inputWallpaperAndSettings = wallpaper.apiInputWallpaperAndSettings {
            inputWallpaper = inputWallpaperAndSettings.0
            inputWallpaperSettings = inputWallpaperAndSettings.1
            flags |= 1 << 1
        }
        
        var messageTopColor: Int32?
        var messageBottomColor: Int32?
        if let color = self.messageColors?.0 {
            messageTopColor = Int32(bitPattern: color)
        }
        if let color = self.messageColors?.1 {
            messageBottomColor = Int32(bitPattern: color)
        }
        
        return .inputThemeSettings(flags: flags, baseTheme: self.baseTheme.apiBaseTheme, accentColor: Int32(bitPattern: self.accentColor), messageTopColor: messageTopColor, messageBottomColor: messageBottomColor, wallpaper: inputWallpaper, wallpaperSettings: inputWallpaperSettings)
    }
}
