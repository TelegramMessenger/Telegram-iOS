import Foundation
import UIKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import MessageWidget

/// SDK v1 §2.3, §2.4 and §5.1 (V2b plan, Task 7; v0.1.1 plan, Task 5): the widget's theme from the chat's, for the
/// bubble the widget sits in: the incoming one, or the outgoing one for a widget the user sent or forwarded. Every key of
/// §2.3 is filled (the ones with no bubble counterpart from the closest colour), as lowercase #rrggbb: a colour with
/// alpha is composited over the bubble, and the bubble itself over white (light) or black (dark); a gradient bubble is
/// the average of its colours. The button is the bubble's own filled control (`polls.bar`, with `barIconForeground` as
/// its text, which a theme leaves clear to knock it out to the bubble), so its label stays legible on both sides; §2.4
/// accepts that a widget overriding only its button's background keeps that text colour. The text tokens (§2.4, v0.1.1) are the chat's message
/// text: the Text Size setting's font size, a line height of 1.3, and the text bubble's insets (`textInsets`, the
/// layout's `text.bubbleInsets`) as the padding, so a widget with no CSS of its own sets its text as a message does.
public func messageWidgetTheme(theme: PresentationTheme, wallpaper: TelegramWallpaper, incoming: Bool, fontSize: PresentationFontSize, textInsets: UIEdgeInsets) -> MessageWidgetInstance.Theme {
    let message = incoming ? theme.chat.message.incoming : theme.chat.message.outgoing
    let base: UIColor = theme.overallDarkAppearance ? .black : .white
    let fill = messageWidgetAverage(bubbleColorComponents(theme: theme, incoming: incoming, wallpaper: !wallpaper.isEmpty).fill) ?? base
    let background = messageWidgetComposite(fill, alpha: 1.0, over: base)
    let hex: (UIColor) -> String = { color in
        messageWidgetHex(messageWidgetComposite(color, alpha: 1.0, over: background))
    }
    let backgroundHex = messageWidgetHex(background)
    let params: [String: String] = [
        "bg_color": backgroundHex,
        "text_color": hex(message.primaryTextColor),
        "hint_color": hex(message.secondaryTextColor),
        "link_color": hex(message.linkTextColor),
        "button_color": hex(message.polls.bar),
        "button_text_color": hex(message.polls.barIconForeground),
        "secondary_bg_color": messageWidgetHex(messageWidgetComposite(message.accentControlColor, alpha: 0.1, over: background)),
        "accent_text_color": hex(message.accentTextColor),
        "subtitle_text_color": hex(message.secondaryTextColor),
        "destructive_text_color": hex(theme.list.itemDestructiveColor),
        "section_bg_color": backgroundHex,
        "section_header_text_color": hex(message.secondaryTextColor),
        "section_separator_color": messageWidgetHex(messageWidgetComposite(message.secondaryTextColor, alpha: 0.25, over: background)),
        "header_bg_color": backgroundHex,
        "bottom_bar_bg_color": backgroundHex,
    ]
    return MessageWidgetInstance.Theme(
        colorScheme: theme.overallDarkAppearance ? .dark : .light,
        params: params,
        button: MessageWidgetInstance.Theme.ButtonTokens(bg: params["button_color"], text: params["button_text_color"]),
        text: MessageWidgetInstance.Theme.TextTokens(
            fontSize: Double(fontSize.baseDisplaySize),
            lineHeight: 1.3,
            // The text bubble's top and bottom insets are 6 pt shifted by a screen pixel, in opposite directions.
            padding: messageWidgetPx((textInsets.top + textInsets.bottom) / 2.0) + " " + messageWidgetPx(textInsets.left)
        )
    )
}

/// A length in CSS px, to three decimals at most.
func messageWidgetPx(_ value: CGFloat) -> String {
    let rounded = (Double(value) * 1000.0).rounded() / 1000.0
    return (rounded == rounded.rounded() ? String(Int(rounded)) : String(rounded)) + "px"
}

/// The colours' mean, channel by channel (alpha too); nil for none.
func messageWidgetAverage(_ colors: [UIColor]) -> UIColor? {
    guard !colors.isEmpty else {
        return nil
    }
    var sum: (CGFloat, CGFloat, CGFloat, CGFloat) = (0.0, 0.0, 0.0, 0.0)
    for color in colors {
        var r: CGFloat = 0.0, g: CGFloat = 0.0, b: CGFloat = 0.0, a: CGFloat = 0.0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        sum = (sum.0 + r, sum.1 + g, sum.2 + b, sum.3 + a)
    }
    let count = CGFloat(colors.count)
    return UIColor(red: sum.0 / count, green: sum.1 / count, blue: sum.2 / count, alpha: sum.3 / count)
}

/// `color` at its own alpha times `alpha`, over the opaque `base`: an opaque colour.
func messageWidgetComposite(_ color: UIColor, alpha: CGFloat, over base: UIColor) -> UIColor {
    var r: CGFloat = 0.0, g: CGFloat = 0.0, b: CGFloat = 0.0, a: CGFloat = 0.0
    var br: CGFloat = 0.0, bg: CGFloat = 0.0, bb: CGFloat = 0.0, ba: CGFloat = 0.0
    color.getRed(&r, green: &g, blue: &b, alpha: &a)
    base.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
    let t = max(0.0, min(1.0, a * alpha))
    return UIColor(red: r * t + br * (1.0 - t), green: g * t + bg * (1.0 - t), blue: b * t + bb * (1.0 - t), alpha: 1.0)
}

/// `#rrggbb`, lowercase, each channel rounded and clamped to 0…255.
func messageWidgetHex(_ color: UIColor) -> String {
    var r: CGFloat = 0.0, g: CGFloat = 0.0, b: CGFloat = 0.0, a: CGFloat = 0.0
    color.getRed(&r, green: &g, blue: &b, alpha: &a)
    let channel: (CGFloat) -> Int = { value in
        return Int((max(0.0, min(1.0, value)) * 255.0).rounded())
    }
    return String(format: "#%02x%02x%02x", channel(r), channel(g), channel(b))
}
