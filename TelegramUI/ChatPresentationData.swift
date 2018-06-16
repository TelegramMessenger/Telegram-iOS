import Foundation
import UIKit
import TelegramCore

extension PresentationFontSize {
    var baseDisplaySize: CGFloat {
        switch self {
            case .extraSmall:
                return 13.0
            case .small:
                return 15.0
            case .regular:
                return 17.0
            case .large:
                return 19.0
            case .extraLarge:
                return 21.0
        }
    }
}

public final class ChatPresentationData {
    let theme: PresentationTheme
    let fontSize: PresentationFontSize
    let strings: PresentationStrings
    let wallpaper: TelegramWallpaper
    let timeFormat: PresentationTimeFormat
    
    let messageFont: UIFont
    let messageBoldFont: UIFont
    let messageItalicFont: UIFont
    let messageFixedFont: UIFont
    
    init(theme: PresentationTheme, fontSize: PresentationFontSize, strings: PresentationStrings, wallpaper: TelegramWallpaper, timeFormat: PresentationTimeFormat) {
        self.theme = theme
        self.fontSize = fontSize
        self.strings = strings
        self.wallpaper = wallpaper
        self.timeFormat = timeFormat
        
        let baseFontSize = fontSize.baseDisplaySize
        self.messageFont = UIFont.systemFont(ofSize: baseFontSize)
        self.messageBoldFont = UIFont.boldSystemFont(ofSize: baseFontSize)
        self.messageItalicFont = UIFont.italicSystemFont(ofSize: baseFontSize)
        self.messageFixedFont = UIFont(name: "Menlo-Regular", size: baseFontSize - 1.0) ?? UIFont.systemFont(ofSize: baseFontSize)
    }
}
