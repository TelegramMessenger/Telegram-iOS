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
    convenience init(rootControllerTheme: PresentationTheme, enableBackgroundBlur: Bool = true, hideBackground: Bool = false, hideBadge: Bool = false, hideSeparator: Bool = false, edgeEffectColor: UIColor? = nil, style: NavigationBar.Style = .legacy, glassStyle: NavigationBar.GlassStyle = .default) {
        let theme = rootControllerTheme.rootController.navigationBar
        
        let buttonColor: UIColor
        let disabledButtonColor: UIColor
        let badgeBackgroundColor: UIColor
        let badgeTextColor: UIColor
        var edgeEffectColor = edgeEffectColor
        if case .glass = style {
            buttonColor = rootControllerTheme.chat.inputPanel.panelControlColor
            disabledButtonColor = buttonColor.withMultipliedAlpha(0.5)
            badgeBackgroundColor = rootControllerTheme.chat.inputPanel.panelControlColor
            badgeTextColor = rootControllerTheme.overallDarkAppearance ? .black : rootControllerTheme.list.itemCheckColors.foregroundColor
            if edgeEffectColor == nil {
                edgeEffectColor = rootControllerTheme.list.plainBackgroundColor
            }
        } else {
            buttonColor = theme.buttonColor
            disabledButtonColor = theme.disabledButtonColor
            badgeBackgroundColor = theme.badgeBackgroundColor
            badgeTextColor = theme.badgeTextColor
        }
        
        self.init(overallDarkAppearance: rootControllerTheme.overallDarkAppearance, buttonColor: buttonColor, disabledButtonColor: disabledButtonColor, primaryTextColor: theme.primaryTextColor, backgroundColor: hideBackground ? .clear : theme.blurredBackgroundColor, opaqueBackgroundColor: hideBackground ? .clear : theme.opaqueBackgroundColor, enableBackgroundBlur: enableBackgroundBlur, separatorColor: hideBackground || hideSeparator ? .clear : theme.separatorColor, badgeBackgroundColor: hideBadge ? .clear : badgeBackgroundColor, badgeStrokeColor: .clear, badgeTextColor: hideBadge ? .clear : badgeTextColor, edgeEffectColor: edgeEffectColor, style: style, glassStyle: glassStyle)
    }
}

public extension NavigationBarStrings {
    convenience init(presentationStrings: PresentationStrings) {
        self.init(back: presentationStrings.Common_Back, close: presentationStrings.Common_Close)
    }
}

public extension NavigationBarPresentationData {
    convenience init(presentationData: PresentationData, style: NavigationBar.Style = .legacy, glassStyle: NavigationBar.GlassStyle = .default) {
        self.init(theme: NavigationBarTheme(rootControllerTheme: presentationData.theme, style: style, glassStyle: glassStyle), strings: NavigationBarStrings(presentationStrings: presentationData.strings))
    }
    
    convenience init(presentationData: PresentationData, hideBackground: Bool, hideBadge: Bool, hideSeparator: Bool = false, style: NavigationBar.Style = .legacy, glassStyle: NavigationBar.GlassStyle = .default, edgeEffectColor: UIColor? = nil) {
        self.init(theme: NavigationBarTheme(rootControllerTheme: presentationData.theme, hideBackground: hideBackground, hideBadge: hideBadge, hideSeparator: hideSeparator, edgeEffectColor: hideBackground ? .clear : edgeEffectColor, style: style, glassStyle: glassStyle), strings: NavigationBarStrings(presentationStrings: presentationData.strings))
    }
    
    convenience init(presentationTheme: PresentationTheme, presentationStrings: PresentationStrings, style: NavigationBar.Style = .legacy, glassStyle: NavigationBar.GlassStyle = .default) {
        self.init(theme: NavigationBarTheme(rootControllerTheme: presentationTheme, style: style, glassStyle: glassStyle), strings: NavigationBarStrings(presentationStrings: presentationStrings))
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
        self.init(statusBar: navigationStatusBar, navigationBar: NavigationBarTheme(rootControllerTheme: presentationTheme), emptyAreaColor: presentationTheme.chatList.backgroundColor)
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
