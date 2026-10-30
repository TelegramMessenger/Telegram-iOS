import Foundation
import UIKit
import Display
import TelegramCore

/// Bubble mode off: the page chats sit on, the plain list background softened a little: F9F9FB instead of white,
/// 141415 instead of black. A theme with a page of another color keeps it.
public func bubblelessPageColor(_ theme: PresentationTheme) -> UIColor {
    let color = theme.list.plainBackgroundColor
    switch color.rgb {
    case 0xffffff:
        return UIColor(rgb: 0xf9f9fb)
    case 0x000000:
        return UIColor(rgb: 0x141415)
    default:
        return color
    }
}

// Bubble mode off: chats lose their wallpaper and sit on the plain page (`bubblelessPageColor`).
public func bubblelessChatWallpaper(theme: PresentationTheme) -> TelegramWallpaper {
    return .color(bubblelessPageColor(theme).rgb)
}

/// Bubble mode off: your own messages' bubbles in soft tints of the theme's colors, which sit well on the plain page
/// (the themes' own colors are made for wallpapers). Gray stays gray, but a light gray as pale as the page is taken down
/// to a cool EBEBF0, which stands apart from it.
public func bubblelessOutgoingBubbleColors(_ colors: [UIColor], dark: Bool) -> [UIColor] {
    return colors.map { color in
        let hsb = color.hsb
        if hsb.s < 0.06 {
            if !dark && hsb.b > 0.94 {
                return UIColor(rgb: 0xebebf0)
            }
            return color
        }
        if dark {
            return UIColor(hue: hsb.h, saturation: min(0.45, max(0.2, hsb.s)), brightness: 0.3, alpha: 1.0)
        } else {
            return UIColor(hue: hsb.h, saturation: min(0.28, max(0.14, hsb.s)), brightness: 0.98, alpha: 1.0)
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
    let pageColor = bubblelessPageColor(theme)
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

    // A dark theme's idle waveform is a dim accent meant for a gray bubble, which reads as barely visible navy on the
    // black page: it takes a neutral gray instead.
    let incomingInactiveControlColor: UIColor? = dark ? UIColor(rgb: 0x48484a) : nil
    let message = theme.chat.message.withUpdated(
        incoming: theme.chat.message.incoming.withUpdated(bubble: cardBubble, mediaInactiveControlColor: incomingInactiveControlColor, actionButtonsFillColor: buttonFill, actionButtonsTextColor: buttonText),
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
        var result = result
        if dark {
            // A gray bubble is lighter than the page, so the idle part of a waveform on it takes a lighter gray.
            let outgoing = result.chat.message.outgoing.withUpdated(mediaInactiveControlColor: UIColor(rgb: 0x636366))
            result = result.withUpdated(chat: result.chat.withUpdated(message: result.chat.message.withUpdated(outgoing: outgoing)))
        }
        // Gray bubbles with the system blue, the standard look: messages have no color of their own.
        if isBubblelessSystemBlue(theme.list.itemAccentColor) {
            result = bubblelessMonochromeMessages(result)
        }
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

/// The system blue a theme comes with (and a picked accent that is that blue), as opposed to an accent of another color.
private func isBubblelessSystemBlue(_ color: UIColor) -> Bool {
    let hsb = color.hsb
    return hsb.h > 0.55 && hsb.h < 0.65 && hsb.s > 0.6 && hsb.b > 0.8
}

/// Gray bubbles with the system blue: the blue in messages, incoming and outgoing, gives way to the text color, black in
/// a light theme and white in a dark one. That is links (underlined then, as links the color of the text are), controls
/// such as play buttons, file icons and waveforms, file names, polls, read checks, reactions and text selection.
private func bubblelessMonochromeMessages(_ theme: PresentationTheme) -> PresentationTheme {
    let dark = theme.overallDarkAppearance
    func monochrome(_ colors: PresentationThemePartedColors) -> PresentationThemePartedColors {
        let ink = colors.primaryTextColor
        func reactions(_ components: PresentationThemeBubbleColorComponents) -> PresentationThemeBubbleColorComponents {
            return components.withUpdated(
                reactionInactiveBackground: ink.withAlphaComponent(dark ? 0.12 : 0.06),
                reactionInactiveForeground: ink,
                reactionActiveBackground: ink,
                reactionActiveForeground: .clear
            )
        }
        return colors.withUpdated(
            bubble: colors.bubble.withUpdated(withWallpaper: reactions(colors.bubble.withWallpaper), withoutWallpaper: reactions(colors.bubble.withoutWallpaper)),
            linkTextColor: ink,
            linkHighlightColor: ink.withAlphaComponent(0.1),
            accentTextColor: ink,
            accentControlColor: ink,
            mediaActiveControlColor: ink,
            fileTitleColor: ink,
            polls: colors.polls.withUpdated(radioProgress: ink, highlight: ink.withAlphaComponent(0.08), bar: ink, barIconForeground: dark ? .black : .white),
            textSelectionColor: ink.withAlphaComponent(0.15),
            textSelectionKnobColor: ink
        )
    }
    let message = theme.chat.message
    let incoming = monochrome(message.incoming)
    let outgoing = monochrome(message.outgoing)
    return theme.withUpdated(chat: theme.chat.withUpdated(message: message.withUpdated(incoming: incoming, outgoing: outgoing, infoLinkTextColor: incoming.primaryTextColor, outgoingCheckColor: outgoing.primaryTextColor)))
}
