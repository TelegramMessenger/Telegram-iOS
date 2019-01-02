import Foundation
import UIKit
import TelegramCore

extension PresentationFontSize {
    var baseDisplaySize: CGFloat {
        switch self {
            case .extraSmall:
                return 14.0
            case .small:
                return 15.0
            case .medium:
                return 16.0
            case .regular:
                return 17.0
            case .large:
                return 19.0
            case .extraLarge:
                return 23.0
            case .extraLargeX2:
                return 26.0
        }
    }
}

extension TelegramWallpaper {
    var isEmpty: Bool {
        switch self {
            case .builtin, .image, .file:
                return false
            case .color:
                return true
        }
    }
    var isBuiltin: Bool {
        switch self {
            case .builtin:
                return true
            default:
                return false
        }
    }
}

public final class ChatPresentationThemeData: Equatable {
    public let theme: PresentationTheme
    public let wallpaper: TelegramWallpaper
    
    public init(theme: PresentationTheme, wallpaper: TelegramWallpaper) {
        self.theme = theme
        self.wallpaper = wallpaper
    }
    
    public static func ==(lhs: ChatPresentationThemeData, rhs: ChatPresentationThemeData) -> Bool {
        return lhs.theme === rhs.theme && lhs.wallpaper == rhs.wallpaper
    }
}

public final class ChatPresentationData {
    let theme: ChatPresentationThemeData
    let fontSize: PresentationFontSize
    let strings: PresentationStrings
    let dateTimeFormat: PresentationDateTimeFormat
    let nameDisplayOrder: PresentationPersonNameOrder
    let disableAnimations: Bool
    
    let messageFont: UIFont
    let messageBoldFont: UIFont
    let messageItalicFont: UIFont
    let messageFixedFont: UIFont
    
    init(theme: ChatPresentationThemeData, fontSize: PresentationFontSize, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat, nameDisplayOrder: PresentationPersonNameOrder, disableAnimations: Bool) {
        self.theme = theme
        self.fontSize = fontSize
        self.strings = strings
        self.dateTimeFormat = dateTimeFormat
        self.nameDisplayOrder = nameDisplayOrder
        self.disableAnimations = disableAnimations
        
        let baseFontSize = fontSize.baseDisplaySize
        self.messageFont = UIFont.systemFont(ofSize: baseFontSize)
        self.messageBoldFont = UIFont.boldSystemFont(ofSize: baseFontSize)
        self.messageItalicFont = UIFont.italicSystemFont(ofSize: baseFontSize)
        self.messageFixedFont = UIFont(name: "Menlo-Regular", size: baseFontSize - 1.0) ?? UIFont.systemFont(ofSize: baseFontSize)
    }
}
