import Foundation
import TelegramCore

// The theme choice of the mode the app is in: with bubbles, the stored `theme` and `automaticThemeSwitchSetting`
// themselves; without, the bubble-free choices in `chatBubbleSettings`. Accent colours, message colours and wallpapers
// stay keyed by theme and shared between the modes, and so does the auto-night trigger.
public extension PresentationThemeSettings {
    var currentModeTheme: PresentationThemeReference {
        get {
            if self.chatBubbleSettings.bubbleMode {
                return self.theme
            }
            if let bubblelessTheme = self.chatBubbleSettings.bubblelessTheme {
                return bubblelessTheme
            }
            switch self.theme {
                case .builtin(.night), .builtin(.nightAccent):
                    return .builtin(.neutralNight)
                default:
                    return .builtin(.neutral)
            }
        }
        set {
            if self.chatBubbleSettings.bubbleMode {
                self.theme = newValue
            } else {
                self.chatBubbleSettings.bubblelessTheme = newValue
            }
        }
    }
    
    var currentModeAutomaticThemeSwitchSetting: AutomaticThemeSwitchSetting {
        get {
            if self.chatBubbleSettings.bubbleMode {
                return self.automaticThemeSwitchSetting
            }
            var setting = self.automaticThemeSwitchSetting
            setting.theme = self.chatBubbleSettings.bubblelessAutomaticTheme ?? .builtin(.neutralNight)
            return setting
        }
        set {
            if self.chatBubbleSettings.bubbleMode {
                self.automaticThemeSwitchSetting = newValue
            } else {
                self.automaticThemeSwitchSetting.force = newValue.force
                self.automaticThemeSwitchSetting.trigger = newValue.trigger
                self.chatBubbleSettings.bubblelessAutomaticTheme = newValue.theme
            }
        }
    }
}

public extension PresentationThemeSettings {
    /// The accent colours after cloud theme `themeIndex`, built on the builtin `baseTheme`, is applied. With bubbles the
    /// builtin's slot is marked with the cloud theme, so the builtin's card and colours follow it. Without bubbles they
    /// are left alone: the mode's own choice already names the cloud theme, and the slots are shared with the bubbles
    /// mode, whose look a marker would change (Night would lose its blue at night).
    func accentColors(afterApplyingCloudTheme themeIndex: Int64, basedOn baseTheme: PresentationThemeReference) -> [Int64: PresentationThemeAccentColor] {
        var accentColors = self.themeSpecificAccentColors
        if self.chatBubbleSettings.bubbleMode {
            accentColors[baseTheme.index] = PresentationThemeAccentColor(themeIndex: themeIndex)
        }
        return accentColors
    }
}

extension PresentationThemeReference {
    // What goes into the keys older builds read ("t", "theme_v2"): they force-unwrap the builtin raw value and crash at
    // launch on one they do not know, so Neutral is stored there as the theme it is built on.
    var legacyStorable: PresentationThemeReference {
        switch self {
            case .builtin(.neutral):
                return .builtin(.dayClassic)
            case .builtin(.neutralNight):
                return .builtin(.night)
            default:
                return self
        }
    }
}

// Appearance's rules without bubbles. With bubbles, Appearance keeps its own inline code.

/// The theme for night after a pick: Appearance's rule with bubbles, plus Neutral's pairing. Neutral picks Neutral
/// Night; Classic or Day resets a night theme that only suits a light one (a chat theme, Classic, Day or a Neutral) to
/// Night.
public func bubblelessAutomaticTheme(afterSelecting selected: PresentationThemeReference, current: PresentationThemeReference) -> PresentationThemeReference {
    if case let .cloud(info) = selected, info.theme.settings?.contains(where: { $0.baseTheme == .night || $0.baseTheme == .tinted }) ?? false {
        return selected
    } else if case let .builtin(theme) = selected {
        if theme == .neutral {
            return .builtin(.neutralNight)
        } else if [.day, .dayClassic].contains(theme) {
            if current.emoticon != nil || [.builtin(.dayClassic), .builtin(.day), .builtin(.neutral), .builtin(.neutralNight)].contains(current.generalThemeReference) {
                return .builtin(.night)
            }
            return current
        } else {
            return selected
        }
    }
    return current
}

/// The carousel's cards: Neutral first, then Classic and the chat themes.
public func bubblelessCarouselThemes(chatThemes: [PresentationThemeReference]) -> [PresentationThemeReference] {
    return [.builtin(.neutral), .builtin(.dayClassic)] + chatThemes
}

/// The selected card. During auto-night a chat theme keeps its card, as with bubbles, and so does Neutral with Neutral
/// Night: they are one card for both halves.
public func bubblelessCarouselSelection(settings: PresentationThemeSettings, autoNightModeTriggered: Bool) -> PresentationThemeReference {
    let theme = settings.currentModeTheme
    if autoNightModeTriggered {
        let automaticTheme = settings.currentModeAutomaticThemeSwitchSetting.theme
        if let _ = theme.emoticon {
            return theme
        } else if theme == .builtin(.neutral) && automaticTheme == .builtin(.neutralNight) {
            return theme
        } else {
            return automaticTheme
        }
    } else {
        return theme
    }
}
