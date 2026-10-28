import Foundation
import UIKit
import Display
import TelegramCore

// Bubble mode off: chats lose their wallpaper and sit on the plain list background, white or black.
public func bubblelessChatWallpaper(theme: PresentationTheme) -> TelegramWallpaper {
    return .color(theme.list.plainBackgroundColor.rgb)
}

/// Bubble mode off: your own messages' bubbles in soft tints of the theme's colors, which sit well on the plain page
/// (the themes' own colors are made for wallpapers). Gray stays gray.
public func bubblelessOutgoingBubbleColors(_ colors: [UIColor], dark: Bool) -> [UIColor] {
    return colors.map { color in
        let hsb = color.hsb
        if hsb.s < 0.06 {
            return color
        }
        if dark {
            return UIColor(hue: hsb.h, saturation: min(0.45, max(0.2, hsb.s)), brightness: 0.3, alpha: 1.0)
        } else {
            return UIColor(hue: hsb.h, saturation: min(0.22, max(0.1, hsb.s)), brightness: 0.99, alpha: 1.0)
        }
    }
}

// Bubble mode off: outgoing bubbles are light green until the theme gets accent or bubble colors of its own.
public func bubblelessDefaultOutgoingBubbleColors(dark: Bool) -> [UInt32] {
    return dark ? [0x2b5435] : [0xe1ffc7]
}

// Bubble mode off: date plates, service messages, sticker timestamps and inline buttons sit on the plain page,
// so they turn into quiet gray pills instead of white text on a wallpaper tint.
public func bubblelessPresentationTheme(_ theme: PresentationTheme) -> PresentationTheme {
    let dark = theme.overallDarkAppearance
    let fill = dark ? UIColor(rgb: 0xffffff, alpha: 0.1) : UIColor(rgb: 0x000000, alpha: 0.05)
    let floatingFill = dark ? UIColor(rgb: 0x1c1c1e, alpha: 0.9) : UIColor(rgb: 0xf2f2f7, alpha: 0.9)
    let textColor = dark ? UIColor(rgb: 0x98989f) : UIColor(rgb: 0x8e8e93)

    let components = theme.chat.serviceMessage.components
    let serviceMessage = theme.chat.serviceMessage.withUpdated(components: components.withUpdated(
        withDefaultWallpaper: components.withDefaultWallpaper.withUpdated(fill: fill, primaryText: textColor, dateFillStatic: fill, dateFillFloating: floatingFill),
        withCustomWallpaper: components.withCustomWallpaper.withUpdated(fill: fill, primaryText: textColor, dateFillStatic: fill, dateFillFloating: floatingFill)
    ), dateTextColor: PresentationThemeVariableColor(color: textColor))

    let buttonFill = PresentationThemeVariableColor(color: fill)
    // Button titles read like the text around them rather than like links.
    let buttonText = PresentationThemeVariableColor(color: theme.list.itemPrimaryTextColor)

    // Incoming messages keep a bubble only as the outline of a block (a poll, a checklist…); its stroke is the
    // incoming bubble's, and the fill stays the page so nothing else changes where it shows.
    let pageColor = theme.list.plainBackgroundColor
    let cardHighlightColor = dark ? UIColor(rgb: 0x1c1c1e) : UIColor(rgb: 0xf2f2f7)
    let blockStrokeColor = dark ? UIColor(rgb: 0x3a3a3c) : UIColor(rgb: 0xdcdce1)
    // Bubbles stand on the page as they do without a wallpaper: without the stroke and the shadow bubbles get over a
    // wallpaper.
    let outgoingBubble = theme.chat.message.outgoing.bubble
    let softOutgoingComponents = outgoingBubble.withoutWallpaper.withUpdated(fill: bubblelessOutgoingBubbleColors(outgoingBubble.withoutWallpaper.fill, dark: dark), stroke: .clear)
    let softOutgoingBubble = outgoingBubble.withUpdated(withWallpaper: softOutgoingComponents, withoutWallpaper: softOutgoingComponents)

    let incomingBubble = theme.chat.message.incoming.bubble
    let cardComponents = incomingBubble.withoutWallpaper.withUpdated(fill: [pageColor], highlightedFill: cardHighlightColor, stroke: blockStrokeColor)
    let cardBubble = incomingBubble.withUpdated(withWallpaper: cardComponents, withoutWallpaper: cardComponents)

    let message = theme.chat.message.withUpdated(
        incoming: theme.chat.message.incoming.withUpdated(bubble: cardBubble, actionButtonsFillColor: buttonFill, actionButtonsTextColor: buttonText),
        outgoing: theme.chat.message.outgoing.withUpdated(bubble: softOutgoingBubble, actionButtonsFillColor: buttonFill, actionButtonsTextColor: buttonText),
        // The share button stands on the plain page, so its glyph follows the text color rather than the white made
        // for a wallpaper.
        shareButtonForegroundColor: PresentationThemeVariableColor(color: theme.list.itemPrimaryTextColor)
    )
    // The soft bubbles take the text colors the other side's messages have, and an accent of their own color: a deep
    // shade of the theme's bubble color in a light theme, a light one in a dark theme. A gray bubble keeps the theme's
    // accent.
    let result = neutralizedOutgoingColors(theme.withUpdated(chat: theme.chat.withUpdated(message: message, serviceMessage: serviceMessage)))
    let bubbleColors = outgoingBubble.withoutWallpaper.fill
    let bubbleColor = bubbleColors[bubbleColors.count / 2]
    let hsb = bubbleColor.hsb
    guard hsb.s > 0.06 else {
        return result
    }
    let accent: UIColor
    if dark {
        accent = UIColor(hue: hsb.h, saturation: min(0.55, max(0.35, hsb.s)), brightness: 0.95, alpha: 1.0)
    } else {
        accent = UIColor(hue: hsb.h, saturation: min(0.95, max(0.7, hsb.s + 0.2)), brightness: min(0.62, hsb.b * 0.7), alpha: 1.0)
    }
    let outgoing = result.chat.message.outgoing.withUpdated(linkTextColor: accent, linkHighlightColor: accent.withAlphaComponent(0.3), accentTextColor: accent, accentControlColor: accent, mediaActiveControlColor: accent, mediaInactiveControlColor: accent.withAlphaComponent(0.4), fileTitleColor: accent)
    return result.withUpdated(chat: result.chat.withUpdated(message: result.chat.message.withUpdated(outgoing: outgoing)))
}
