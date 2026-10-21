import Foundation
import UIKit
import TelegramCore
import TelegramPresentationData
import MessageWidget

/// SDK v1 §2.3, §2.4 and §5.1 (V2b plan, Task 7): the widget's theme from the chat's, for the incoming bubble the widget
/// sits in. Every key of §2.3 is filled (the ones with no bubble counterpart from the closest colour), as lowercase
/// #rrggbb: a colour with alpha is composited over the bubble, and the bubble itself over white (light) or black (dark).
/// The button tokens are the client's solid button, the button colour with its text colour; §2.4 accepts that a widget
/// overriding only its button's background keeps that text colour.
public func messageWidgetTheme(theme: PresentationTheme, wallpaper: TelegramWallpaper) -> MessageWidgetInstance.Theme {
    let incoming = theme.chat.message.incoming
    let base: UIColor = theme.overallDarkAppearance ? .black : .white
    let fill = bubbleColorComponents(theme: theme, incoming: true, wallpaper: !wallpaper.isEmpty).fill.first ?? base
    let background = messageWidgetComposite(fill, alpha: 1.0, over: base)
    let hex: (UIColor) -> String = { color in
        messageWidgetHex(messageWidgetComposite(color, alpha: 1.0, over: background))
    }
    let backgroundHex = messageWidgetHex(background)
    let params: [String: String] = [
        "bg_color": backgroundHex,
        "text_color": hex(incoming.primaryTextColor),
        "hint_color": hex(incoming.secondaryTextColor),
        "link_color": hex(incoming.linkTextColor),
        "button_color": hex(incoming.accentControlColor),
        "button_text_color": hex(theme.list.itemCheckColors.foregroundColor),
        "secondary_bg_color": messageWidgetHex(messageWidgetComposite(incoming.accentControlColor, alpha: 0.1, over: background)),
        "accent_text_color": hex(incoming.accentTextColor),
        "subtitle_text_color": hex(incoming.secondaryTextColor),
        "destructive_text_color": hex(theme.list.itemDestructiveColor),
        "section_bg_color": backgroundHex,
        "section_header_text_color": hex(incoming.secondaryTextColor),
        "section_separator_color": messageWidgetHex(messageWidgetComposite(incoming.secondaryTextColor, alpha: 0.25, over: background)),
        "header_bg_color": backgroundHex,
        "bottom_bar_bg_color": backgroundHex,
    ]
    return MessageWidgetInstance.Theme(
        colorScheme: theme.overallDarkAppearance ? .dark : .light,
        params: params,
        button: MessageWidgetInstance.Theme.ButtonTokens(bg: params["button_color"], text: params["button_text_color"])
    )
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
