import Foundation
import UIKit
import Display
import TelegramUIPreferences
import TelegramPresentationData

/// The legacy composer's typography and the geometry tuned against it, as pure functions of the chat's
/// Text Size (Settings ▸ Appearance). One place, so the placeholder, the typed text, the typing attributes,
/// the empty-field minimum height and the vertical text insets cannot disagree.
///
/// History: the panel used to read `fontSize.baseDisplaySize` at fourteen sites, eight of which — inherited
/// from upstream — carried an always-true `if "".isEmpty { baseFontSize = 17.0 }` pin. The pinned sites were
/// the placeholder font, the minimum height, the insets and the initial rendering config; the per-keystroke
/// re-decoration was not pinned. So typed text scaled on the first keystroke while the placeholder stayed at
/// 17pt, and an empty field opened at the 17pt minimum (31) and animated to the scaled height once the text
/// node loaded. `ChatTextInputFontMetricsTests` pins the minimum height to what the empty field measures.

/// The base font size the composer types, decorates and measures with. Floored at `chatTextInputMinFontSize`.
public func chatTextInputBaseFontSize(for fontSize: PresentationFontSize) -> CGFloat {
    return max(chatTextInputMinFontSize, fontSize.baseDisplaySize)
}

/// The empty field's height: one line of the typing font plus the vertical insets, never below the 17pt
/// value of 31. These are the settled heights the legacy text view measures for the seven steps (14–16pt
/// measure below 31 and take the floor), so the field does not animate after its text node loads.
/// Switched on the step, not on a `CGFloat`, so a new step fails to compile here instead of silently
/// taking 31 and reintroducing the jump.
public func chatTextInputFieldMinHeight(for fontSize: PresentationFontSize) -> CGFloat {
    switch fontSize {
    case .extraSmall, .small, .medium, .regular:
        return 31.0
    case .large:
        return 33.0
    case .extraLarge:
        return 38.0
    case .extraLargeX2:
        return 42.0
    }
}

/// The text container's top/bottom insets for a step (left/right are the caller's: they depend on the
/// accessory buttons, not on the font). Below 17pt the line box is shorter than the 17pt field, and these
/// nudge the text toward the field's optical centre.
public func chatTextInputFieldVerticalInsets(for fontSize: PresentationFontSize) -> UIEdgeInsets {
    let top: CGFloat
    let bottom: CGFloat
    switch fontSize {
    case .extraSmall:
        top = 2.0
        bottom = 1.0
    case .small:
        top = 1.0
        bottom = 1.0
    case .medium:
        top = 0.5
        bottom = 0.0
    case .regular, .large, .extraLarge, .extraLargeX2:
        top = 0.0
        bottom = 0.0
    }
    return UIEdgeInsets(top: 4.5 + top, left: 0.0, bottom: 5.5 + bottom, right: 0.0)
}
