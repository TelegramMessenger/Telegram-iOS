import Foundation
import UIKit
import Display
import TelegramUIPreferences
import PresentationStrings

public extension PresentationFontSize {
    init(systemFontSize: CGFloat) {
        var closestIndex = 0
        let allSizes = PresentationFontSize.allCases
        for i in 0 ..< allSizes.count {
            if abs(allSizes[i].baseDisplaySize - systemFontSize) < abs(allSizes[closestIndex].baseDisplaySize - systemFontSize) {
                closestIndex = i
            }
        }
        self = allSizes[closestIndex]
    }
}

public extension PresentationFontSize {
    var baseDisplaySize: CGFloat {
        switch self {
        case .extraSmall:
            return 14.0
        case .small:
            return 15.0
        case .medium:
            return 16.0
        case .regular:
            return 17.0
        case .large:
            return 19.0
        case .extraLarge:
            return 23.0
        case .extraLargeX2:
            return 26.0
        }
    }
}

public extension ToolbarTheme {
    convenience init(rootControllerTheme: PresentationTheme) {
        let theme = rootControllerTheme.rootController.tabBar
        self.init(barBackgroundColor: theme.backgroundColor, barSeparatorColor: theme.separatorColor, barTextColor: theme.textColor, barSelectedTextColor: theme.selectedTextColor)
    }
}

public extension NavigationBarTheme {
    convenience init(rootControllerTheme: PresentationTheme, hideBadge: Bool = false, edgeEffectColor: UIColor? = nil, glassStyle: NavigationBar.GlassStyle = .default) {
        let theme = rootControllerTheme.rootController.navigationBar
        let buttonColor = rootControllerTheme.chat.inputPanel.panelControlColor
        let badgeTextColor: UIColor = rootControllerTheme.overallDarkAppearance ? .black : rootControllerTheme.list.itemCheckColors.foregroundColor
        self.init(overallDarkAppearance: rootControllerTheme.overallDarkAppearance, buttonColor: buttonColor, disabledButtonColor: buttonColor.withMultipliedAlpha(0.5), primaryTextColor: theme.primaryTextColor, badgeBackgroundColor: hideBadge ? .clear : buttonColor, badgeTextColor: hideBadge ? .clear : badgeTextColor, edgeEffectColor: edgeEffectColor ?? rootControllerTheme.list.plainBackgroundColor, accentButtonColor: rootControllerTheme.list.itemCheckColors.fillColor, accentDisabledButtonColor: rootControllerTheme.chat.inputPanel.panelControlDisabledColor, accentForegroundColor: rootControllerTheme.list.itemCheckColors.foregroundColor, glassStyle: glassStyle)
    }
}

public extension NavigationBarStrings {
    convenience init(presentationStrings: PresentationStrings) {
        self.init(back: presentationStrings.Common_Back, close: presentationStrings.Common_Close, more: presentationStrings.Common_More)
    }
}

public extension NavigationBarPresentationData {
    convenience init(presentationData: PresentationData, glassStyle: NavigationBar.GlassStyle = .default) {
        self.init(theme: NavigationBarTheme(rootControllerTheme: presentationData.theme, glassStyle: glassStyle), strings: NavigationBarStrings(presentationStrings: presentationData.strings))
    }

    /// `hideBackground`: no backdrop (a clear edge effect).
    convenience init(presentationData: PresentationData, hideBackground: Bool, hideBadge: Bool, glassStyle: NavigationBar.GlassStyle = .default, edgeEffectColor: UIColor? = nil) {
        self.init(theme: NavigationBarTheme(rootControllerTheme: presentationData.theme, hideBadge: hideBadge, edgeEffectColor: hideBackground ? .clear : edgeEffectColor, glassStyle: glassStyle), strings: NavigationBarStrings(presentationStrings: presentationData.strings))
    }

    convenience init(presentationTheme: PresentationTheme, presentationStrings: PresentationStrings, glassStyle: NavigationBar.GlassStyle = .default) {
        self.init(theme: NavigationBarTheme(rootControllerTheme: presentationTheme, glassStyle: glassStyle), strings: NavigationBarStrings(presentationStrings: presentationStrings))
    }
}

public extension ActionSheetControllerTheme {
    convenience init(presentationData: PresentationData) {
        let presentationTheme = presentationData.theme
        
        let actionSheet = presentationTheme.actionSheet
        self.init(dimColor: actionSheet.dimColor, backgroundType: actionSheet.backgroundType == .light ? .light : .dark, itemBackgroundColor: actionSheet.itemBackgroundColor, itemHighlightedBackgroundColor: actionSheet.itemHighlightedBackgroundColor, standardActionTextColor: actionSheet.standardActionTextColor, destructiveActionTextColor: actionSheet.destructiveActionTextColor, disabledActionTextColor: actionSheet.disabledActionTextColor, primaryTextColor: actionSheet.primaryTextColor, secondaryTextColor: actionSheet.secondaryTextColor, controlAccentColor: actionSheet.controlAccentColor, controlColor: presentationTheme.list.disclosureArrowColor, switchFrameColor: presentationTheme.list.itemSwitchColors.frameColor, switchContentColor: presentationTheme.list.itemSwitchColors.contentColor, switchHandleColor: presentationTheme.list.itemSwitchColors.handleColor, baseFontSize: presentationData.listsFontSize.baseDisplaySize)
    }
    
    convenience init(presentationTheme: PresentationTheme, fontSize: PresentationFontSize) {
        let actionSheet = presentationTheme.actionSheet
        self.init(dimColor: actionSheet.dimColor, backgroundType: actionSheet.backgroundType == .light ? .light : .dark, itemBackgroundColor: actionSheet.itemBackgroundColor, itemHighlightedBackgroundColor: actionSheet.itemHighlightedBackgroundColor, standardActionTextColor: actionSheet.standardActionTextColor, destructiveActionTextColor: actionSheet.destructiveActionTextColor, disabledActionTextColor: actionSheet.disabledActionTextColor, primaryTextColor: actionSheet.primaryTextColor, secondaryTextColor: actionSheet.secondaryTextColor, controlAccentColor: actionSheet.controlAccentColor, controlColor: presentationTheme.list.disclosureArrowColor, switchFrameColor: presentationTheme.list.itemSwitchColors.frameColor, switchContentColor: presentationTheme.list.itemSwitchColors.contentColor, switchHandleColor: presentationTheme.list.itemSwitchColors.handleColor, baseFontSize: fontSize.baseDisplaySize)
    }
}

public extension ActionSheetController {
    convenience init(presentationData: PresentationData, allowInputInset: Bool = false) {
        self.init(theme: ActionSheetControllerTheme(presentationData: presentationData), allowInputInset: allowInputInset)
    }
}

public extension AlertControllerTheme {
    convenience init(presentationTheme: PresentationTheme, fontSize: PresentationFontSize) {
        let actionSheet = presentationTheme.actionSheet
        self.init(backgroundType: actionSheet.backgroundType == .light ? .light : .dark, backgroundColor: actionSheet.itemBackgroundColor, separatorColor: actionSheet.itemHighlightedBackgroundColor, highlightedItemColor: actionSheet.itemHighlightedBackgroundColor, primaryColor: actionSheet.primaryTextColor, secondaryColor: actionSheet.secondaryTextColor, accentColor: actionSheet.controlAccentColor, contrastColor: presentationTheme.list.itemCheckColors.foregroundColor, destructiveColor: actionSheet.destructiveActionTextColor, disabledColor: actionSheet.disabledActionTextColor, controlBorderColor: presentationTheme.list.itemCheckColors.strokeColor, baseFontSize: fontSize.baseDisplaySize)
    }
    
    convenience init(presentationData: PresentationData) {
        let presentationTheme = presentationData.theme
        let actionSheet = presentationTheme.actionSheet
        self.init(backgroundType: actionSheet.backgroundType == .light ? .light : .dark, backgroundColor: actionSheet.itemBackgroundColor, separatorColor: actionSheet.itemHighlightedBackgroundColor, highlightedItemColor: actionSheet.itemHighlightedBackgroundColor, primaryColor: actionSheet.primaryTextColor, secondaryColor: actionSheet.secondaryTextColor, accentColor: actionSheet.controlAccentColor, contrastColor: presentationData.theme.list.itemCheckColors.foregroundColor, destructiveColor: actionSheet.destructiveActionTextColor, disabledColor: actionSheet.disabledActionTextColor, controlBorderColor: presentationData.theme.list.itemCheckColors.strokeColor, baseFontSize: presentationData.listsFontSize.baseDisplaySize)
    }
}

public extension NavigationControllerTheme {
    convenience init(presentationTheme: PresentationTheme) {
        let navigationStatusBar: NavigationStatusBarStyle
        switch presentationTheme.rootController.statusBarStyle {
        case .black:
            navigationStatusBar = .black
        case .white:
            navigationStatusBar = .white
        }
        self.init(statusBar: navigationStatusBar, navigationBar: NavigationBarTheme(rootControllerTheme: presentationTheme), emptyAreaColor: presentationTheme.chatList.backgroundColor, separatorColor: presentationTheme.rootController.navigationBar.separatorColor, opaqueBackgroundColor: presentationTheme.rootController.navigationBar.opaqueBackgroundColor)
    }
}

public extension PresentationThemeBubbleColorComponents {
    var hasSingleFillColor: Bool {
        if self.fill.count == 1 {
            return true
        }
        for i in 0 ..< self.fill.count - 1 {
            if self.fill[i].argb != self.fill[i + 1].argb {
                return false
            }
        }
        return true
    }
}
