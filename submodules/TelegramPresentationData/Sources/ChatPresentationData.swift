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
    
    public func withTheme(_ theme: PresentationTheme) -> ChatPresentationThemeData {
        return ChatPresentationThemeData(theme: theme, wallpaper: self.wallpaper)
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
    /// Message text in New York, when it is picked in Text Size (both modes, every message); nil keeps the fonts above.
    /// Built here: layouts read this object from several threads, so it is not lazy.
    public let messageTextFonts: ChatMessageTextFonts?

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
        self.messageTextFonts = ChatPresentationData.messageTextFonts(serif: chatBubbleCorners.serifMessageText, baseFontSize: baseFontSize)

        self.animatedEmojiScale = animatedEmojiScale
    }

    public static func messageTextFonts(serif: Bool, baseFontSize: CGFloat) -> ChatMessageTextFonts? {
        if !serif {
            return nil
        }
        return ChatMessageTextFonts.newYork(baseFontSize: baseFontSize)
    }

    /// The body font message text is drawn in (New York when picked), which every bubble-free measurement of an incoming
    /// message's first line reads.
    public var bubblelessIncomingBodyFont: UIFont {
        return self.messageTextFonts?.regular ?? self.messageFont
    }

    /// The fonts message text is drawn in, for the text node and for whatever measures that text the same way: New York
    /// when picked, its quotes and code-block titles in the system family (`blockFonts`); otherwise the system fonts.
    public static func messageBodyFonts(messageTextFonts: ChatMessageTextFonts?, systemTextFonts: ChatMessageTextFonts) -> (body: ChatMessageTextFonts, blockFonts: ChatMessageTextFonts?) {
        if let messageTextFonts {
            return (messageTextFonts, systemTextFonts)
        }
        return (systemTextFonts, nil)
    }

    public var messageBodyFonts: (body: ChatMessageTextFonts, blockFonts: ChatMessageTextFonts?) {
        return ChatPresentationData.messageBodyFonts(messageTextFonts: self.messageTextFonts, systemTextFonts: self.systemTextFonts)
    }

    /// The system family of message text, for the spans that keep it under a New York body (quotes, code-block titles).
    public var systemTextFonts: ChatMessageTextFonts {
        return ChatMessageTextFonts(regular: self.messageFont, bold: self.messageBoldFont, italic: self.messageItalicFont, boldItalic: self.messageBoldItalicFont)
    }
    
    public func withTheme(_ theme: ChatPresentationThemeData) -> ChatPresentationData {
        return ChatPresentationData(
            theme: self.theme,
            fontSize: self.fontSize,
            strings: self.strings,
            dateTimeFormat: self.dateTimeFormat,
            nameDisplayOrder: self.nameDisplayOrder,
            disableAnimations: self.disableAnimations,
            largeEmoji: self.largeEmoji,
            chatBubbleCorners: self.chatBubbleCorners,
            animatedEmojiScale: self.animatedEmojiScale,
            isPreview: self.isPreview
        )
    }
}

extension ChatPresentationData {
    public convenience init(presentationData: PresentationData) {
        self.init(theme: ChatPresentationThemeData(theme: presentationData.theme, wallpaper: presentationData.chatWallpaper), fontSize: presentationData.chatFontSize, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat, nameDisplayOrder: presentationData.nameDisplayOrder, disableAnimations: true, largeEmoji: presentationData.largeEmoji, chatBubbleCorners: presentationData.chatBubbleCorners)
    }
}
