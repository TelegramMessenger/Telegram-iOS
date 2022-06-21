import Foundation
import UIKit
import Display
import TelegramCore
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
    public let theme: ChatPresentationThemeData
    public let fontSize: PresentationFontSize
    public let strings: PresentationStrings
    public let dateTimeFormat: PresentationDateTimeFormat
    public let nameDisplayOrder: PresentationPersonNameOrder
    public let disableAnimations: Bool
    public let largeEmoji: Bool
    public let chatBubbleCorners: PresentationChatBubbleCorners
    public let animatedEmojiScale: CGFloat
    public let isPreview: Bool
    
    public let messageFont: UIFont
    public let messageEmojiFont: UIFont
    public let messageBoldFont: UIFont
    public let messageItalicFont: UIFont
    public let messageBoldItalicFont: UIFont
    public let messageFixedFont: UIFont
    public let messageBlockQuoteFont: UIFont
    
    public init(theme: ChatPresentationThemeData, fontSize: PresentationFontSize, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat, nameDisplayOrder: PresentationPersonNameOrder, disableAnimations: Bool, largeEmoji: Bool, chatBubbleCorners: PresentationChatBubbleCorners, animatedEmojiScale: CGFloat = 1.0, isPreview: Bool = false) {
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

extension ChatPresentationData {
    public convenience init(presentationData: PresentationData) {
        self.init(theme: ChatPresentationThemeData(theme: presentationData.theme, wallpaper: presentationData.chatWallpaper), fontSize: presentationData.chatFontSize, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat, nameDisplayOrder: presentationData.nameDisplayOrder, disableAnimations: true, largeEmoji: presentationData.largeEmoji, chatBubbleCorners: presentationData.chatBubbleCorners)
    }
}
