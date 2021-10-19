import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi


extension TelegramTheme {
    convenience init(apiTheme: Api.Theme) {
        switch apiTheme {
            case let .theme(flags, id, accessHash, slug, title, document, settings, emoticon, installCount):
                self.init(id: id, accessHash: accessHash, slug: slug, emoticon: emoticon, title: title, file: document.flatMap(telegramMediaFileFromApiDocument), settings: settings?.compactMap(TelegramThemeSettings.init(apiThemeSettings:)), isCreator: (flags & 1 << 0) != 0, isDefault: (flags & 1 << 1) != 0, installCount: installCount)
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
            case let .themeSettings(flags, baseTheme, accentColor, outboxAccentColor, messageColors, wallpaper):
                self.init(baseTheme: TelegramBaseTheme(apiBaseTheme: baseTheme), accentColor: UInt32(bitPattern: accentColor), outgoingAccentColor: outboxAccentColor.flatMap { UInt32(bitPattern: $0) }, messageColors: messageColors?.map(UInt32.init(bitPattern:)) ?? [], animateMessageColors: (flags & 1 << 2) != 0, wallpaper: wallpaper.flatMap(TelegramWallpaper.init(apiWallpaper:)))
        }
    }
    
    var apiInputThemeSettings: Api.InputThemeSettings {
        var flags: Int32 = 0
        if !self.messageColors.isEmpty {
            flags |= 1 << 0
        }
        
        if self.animateMessageColors {
            flags |= 1 << 2
        }
        
        if let _ = self.outgoingAccentColor {
            flags |= 1 << 3
        }
        
        var inputWallpaper: Api.InputWallPaper?
        var inputWallpaperSettings: Api.WallPaperSettings?
        if let wallpaper = self.wallpaper, let inputWallpaperAndSettings = wallpaper.apiInputWallpaperAndSettings {
            inputWallpaper = inputWallpaperAndSettings.0
            inputWallpaperSettings = inputWallpaperAndSettings.1
            flags |= 1 << 1
        }
        
        return .inputThemeSettings(flags: flags, baseTheme: self.baseTheme.apiBaseTheme, accentColor: Int32(bitPattern: self.accentColor), outboxAccentColor: self.outgoingAccentColor.flatMap { Int32(bitPattern: $0) }, messageColors: self.messageColors.isEmpty ? nil : self.messageColors.map(Int32.init(bitPattern:)), wallpaper: inputWallpaper, wallpaperSettings: inputWallpaperSettings)
    }
}
