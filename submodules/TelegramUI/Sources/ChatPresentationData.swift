import Foundation
import UIKit
import Display
import TelegramCore
import SyncCore
import TelegramPresentationData
import TelegramUIPreferences

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
    let largeEmoji: Bool
    let chatBubbleCorners: PresentationChatBubbleCorners
    let animatedEmojiScale: CGFloat
    let isPreview: Bool
    
    let messageFont: UIFont
    let messageEmojiFont: UIFont
    let messageBoldFont: UIFont
    let messageItalicFont: UIFont
    let messageBoldItalicFont: UIFont
    let messageFixedFont: UIFont
    let messageBlockQuoteFont: UIFont
    
    init(theme: ChatPresentationThemeData, fontSize: PresentationFontSize, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat, nameDisplayOrder: PresentationPersonNameOrder, disableAnimations: Bool, largeEmoji: Bool, chatBubbleCorners: PresentationChatBubbleCorners, animatedEmojiScale: CGFloat = 1.0, isPreview: Bool = false) {
        self.theme = theme
        self.fontSize = fontSize
        self.strings = strings
        self.dateTimeFormat = dateTimeFormat
        self.nameDisplayOrder = nameDisplayOrder
        self.disableAnimations = disableAnimations
        self.chatBubbleCorners = chatBubbleCorners
        self.largeEmoji = largeEmoji
        self.isPreview = isPreview
        
        let baseFontSize = fontSize.baseDisplaySize
        self.messageFont = Font.regular(baseFontSize)
        self.messageEmojiFont = Font.regular(53.0)
        self.messageBoldFont = Font.bold(baseFontSize)
        self.messageItalicFont = Font.italic(baseFontSize)
        self.messageBoldItalicFont = Font.semiboldItalic(baseFontSize)
        self.messageFixedFont = Font.monospace(baseFontSize)
        self.messageBlockQuoteFont = Font.regular(baseFontSize - 1.0)
        
        self.animatedEmojiScale = animatedEmojiScale
    }
}
