import Foundation
import UIKit
import Display
import TelegramCore
import TelegramUIPreferences

public final class PresentationThemeGradientColors {
    public let topColor: UIColor
    public let bottomColor: UIColor
    
    public init(topColor: UIColor, bottomColor: UIColor) {
        self.topColor = topColor
        self.bottomColor = bottomColor
    }
    
    public var colors: (UIColor, UIColor) {
        return (self.topColor, self.bottomColor)
    }
    
    public func withUpdated(topColor: UIColor? = nil, bottomColor: UIColor? = nil) -> PresentationThemeGradientColors {
        return PresentationThemeGradientColors(topColor: topColor ?? self.topColor, bottomColor: bottomColor ?? self.bottomColor)
    }
}

public final class PresentationThemeIntro {
    public let statusBarStyle: PresentationThemeStatusBarStyle
    public let primaryTextColor: UIColor
    public let accentTextColor: UIColor
    public let disabledTextColor: UIColor
    public let startButtonColor: UIColor
    public let dotColor: UIColor
    
    public init(statusBarStyle: PresentationThemeStatusBarStyle, primaryTextColor: UIColor, accentTextColor: UIColor, disabledTextColor: UIColor, startButtonColor: UIColor, dotColor: UIColor) {
        self.statusBarStyle = statusBarStyle
        self.primaryTextColor = primaryTextColor
        self.accentTextColor = accentTextColor
        self.disabledTextColor = disabledTextColor
        self.startButtonColor = startButtonColor
        self.dotColor = dotColor
    }
    
    public func withUpdated(statusBarStyle: PresentationThemeStatusBarStyle? = nil, primaryTextColor: UIColor? = nil, accentTextColor: UIColor? = nil, disabledTextColor: UIColor? = nil, startButtonColor: UIColor? = nil, dotColor: UIColor? = nil) -> PresentationThemeIntro {
        return PresentationThemeIntro(statusBarStyle: statusBarStyle ?? self.statusBarStyle, primaryTextColor: primaryTextColor ?? self.primaryTextColor, accentTextColor: accentTextColor ?? self.accentTextColor, disabledTextColor: disabledTextColor ?? self.disabledTextColor, startButtonColor: startButtonColor ?? self.startButtonColor, dotColor: dotColor ?? self.dotColor)
    }
}

public final class PresentationThemePasscode {
    public let backgroundColors: PresentationThemeGradientColors
    public let buttonColor: UIColor
    
    public init(backgroundColors: PresentationThemeGradientColors, buttonColor: UIColor) {
        self.backgroundColors = backgroundColors
        self.buttonColor = buttonColor
    }
    
    public func withUpdated(backgroundColors: PresentationThemeGradientColors? = nil, buttonColor: UIColor? = nil) -> PresentationThemePasscode {
        return PresentationThemePasscode(backgroundColors: backgroundColors ?? self.backgroundColors, buttonColor: buttonColor ?? self.buttonColor)
    }
}

public final class PresentationThemeRootTabBar {
    public let backgroundColor: UIColor
    public let separatorColor: UIColor
    public let iconColor: UIColor
    public let selectedIconColor: UIColor
    public let textColor: UIColor
    public let selectedTextColor: UIColor
    public let badgeBackgroundColor: UIColor
    public let badgeStrokeColor: UIColor
    public let badgeTextColor: UIColor
    
    public init(backgroundColor: UIColor, separatorColor: UIColor, iconColor: UIColor, selectedIconColor: UIColor, textColor: UIColor, selectedTextColor: UIColor, badgeBackgroundColor: UIColor, badgeStrokeColor: UIColor, badgeTextColor: UIColor) {
        self.backgroundColor = backgroundColor
        self.separatorColor = separatorColor
        self.iconColor = iconColor
        self.selectedIconColor = selectedIconColor
        self.textColor = textColor
        self.selectedTextColor = selectedTextColor
        self.badgeBackgroundColor = badgeBackgroundColor
        self.badgeStrokeColor = badgeStrokeColor
        self.badgeTextColor = badgeTextColor
    }
    
    public func withUpdated(backgroundColor: UIColor? = nil, separatorColor: UIColor? = nil, iconColor: UIColor? = nil, selectedIconColor: UIColor? = nil, textColor: UIColor? = nil, selectedTextColor: UIColor? = nil, badgeBackgroundColor: UIColor? = nil, badgeStrokeColor: UIColor? = nil, badgeTextColor: UIColor? = nil) -> PresentationThemeRootTabBar {
        return PresentationThemeRootTabBar(backgroundColor: backgroundColor ?? self.backgroundColor, separatorColor: separatorColor ?? self.separatorColor, iconColor: iconColor ?? self.iconColor, selectedIconColor: selectedIconColor ?? self.selectedIconColor, textColor: textColor ?? self.textColor, selectedTextColor: selectedTextColor ?? self.selectedTextColor, badgeBackgroundColor: badgeBackgroundColor ?? self.badgeBackgroundColor, badgeStrokeColor: badgeStrokeColor ?? self.badgeStrokeColor, badgeTextColor: badgeTextColor ?? self.badgeTextColor)
    }
}

public enum PresentationThemeStatusBarStyle: Int32 {
    case black = 0
    case white = 1
    
    init(_ style: StatusBarStyle) {
        switch style {
            case .White:
                self = .white
            default:
                self = .black
        }
    }
    
    public var style: StatusBarStyle {
        switch self {
            case .black:
                return .Black
            case .white:
                return .White
        }
    }
}

public final class PresentationThemeRootNavigationBar {
    public let buttonColor: UIColor
    public let disabledButtonColor: UIColor
    public let primaryTextColor: UIColor
    public let secondaryTextColor: UIColor
    public let controlColor: UIColor
    public let accentTextColor: UIColor
    public let blurredBackgroundColor: UIColor
    public let opaqueBackgroundColor: UIColor
    public let separatorColor: UIColor
    public let badgeBackgroundColor: UIColor
    public let badgeStrokeColor: UIColor
    public let badgeTextColor: UIColor
    public let segmentedBackgroundColor: UIColor
    public let segmentedForegroundColor: UIColor
    public let segmentedTextColor: UIColor
    public let segmentedDividerColor: UIColor
    public let clearButtonBackgroundColor: UIColor
    public let clearButtonForegroundColor: UIColor
    
    public init(buttonColor: UIColor, disabledButtonColor: UIColor, primaryTextColor: UIColor, secondaryTextColor: UIColor, controlColor: UIColor, accentTextColor: UIColor, blurredBackgroundColor: UIColor, opaqueBackgroundColor: UIColor, separatorColor: UIColor, badgeBackgroundColor: UIColor, badgeStrokeColor: UIColor, badgeTextColor: UIColor, segmentedBackgroundColor: UIColor, segmentedForegroundColor: UIColor, segmentedTextColor: UIColor, segmentedDividerColor: UIColor, clearButtonBackgroundColor: UIColor, clearButtonForegroundColor: UIColor) {
        self.buttonColor = buttonColor
        self.disabledButtonColor = disabledButtonColor
        self.primaryTextColor = primaryTextColor
        self.secondaryTextColor = secondaryTextColor
        self.controlColor = controlColor
        self.accentTextColor = accentTextColor
        self.blurredBackgroundColor = blurredBackgroundColor
        self.opaqueBackgroundColor = opaqueBackgroundColor
        self.separatorColor = separatorColor
        self.badgeBackgroundColor = badgeBackgroundColor
        self.badgeStrokeColor = badgeStrokeColor
        self.badgeTextColor = badgeTextColor
        self.segmentedBackgroundColor = segmentedBackgroundColor
        self.segmentedForegroundColor = segmentedForegroundColor
        self.segmentedTextColor = segmentedTextColor
        self.segmentedDividerColor = segmentedDividerColor
        self.clearButtonBackgroundColor = clearButtonBackgroundColor
        self.clearButtonForegroundColor = clearButtonForegroundColor
    }
    
    public func withUpdated(buttonColor: UIColor? = nil, disabledButtonColor: UIColor? = nil, primaryTextColor: UIColor? = nil, secondaryTextColor: UIColor? = nil, controlColor: UIColor? = nil, accentTextColor: UIColor? = nil, blurredBackgroundColor: UIColor? = nil, opaqueBackgroundColor: UIColor? = nil, separatorColor: UIColor? = nil, badgeBackgroundColor: UIColor? = nil, badgeStrokeColor: UIColor? = nil, badgeTextColor: UIColor? = nil, segmentedBackgroundColor: UIColor? = nil, segmentedForegroundColor: UIColor? = nil, segmentedTextColor: UIColor? = nil, segmentedDividerColor: UIColor? = nil, clearButtonBackgroundColor: UIColor? = nil, clearButtonForegroundColor: UIColor? = nil) -> PresentationThemeRootNavigationBar {
        let resolvedClearButtonBackgroundColor = clearButtonBackgroundColor ?? self.clearButtonBackgroundColor
        let resolvedClearButtonForegroundColor = clearButtonForegroundColor ?? self.clearButtonForegroundColor
        return PresentationThemeRootNavigationBar(buttonColor: buttonColor ?? self.buttonColor, disabledButtonColor: disabledButtonColor ?? self.disabledButtonColor, primaryTextColor: primaryTextColor ?? self.primaryTextColor, secondaryTextColor: secondaryTextColor ?? self.secondaryTextColor, controlColor: controlColor ?? self.controlColor, accentTextColor: accentTextColor ?? self.accentTextColor, blurredBackgroundColor: blurredBackgroundColor ?? self.blurredBackgroundColor, opaqueBackgroundColor: opaqueBackgroundColor ?? self.opaqueBackgroundColor, separatorColor: separatorColor ?? self.separatorColor, badgeBackgroundColor: badgeBackgroundColor ?? self.badgeBackgroundColor, badgeStrokeColor: badgeStrokeColor ?? self.badgeStrokeColor, badgeTextColor: badgeTextColor ?? self.badgeTextColor, segmentedBackgroundColor: segmentedBackgroundColor ?? self.segmentedBackgroundColor, segmentedForegroundColor: segmentedForegroundColor ?? self.segmentedForegroundColor, segmentedTextColor: segmentedTextColor ?? self.segmentedTextColor, segmentedDividerColor: segmentedDividerColor ?? self.segmentedDividerColor, clearButtonBackgroundColor: resolvedClearButtonBackgroundColor, clearButtonForegroundColor: resolvedClearButtonForegroundColor)
    }
}

public final class PresentationThemeNavigationSearchBar {
    public let backgroundColor: UIColor
    public let accentColor: UIColor
    public let inputFillColor: UIColor
    public let inputTextColor: UIColor
    public let inputPlaceholderTextColor: UIColor
    public let inputIconColor: UIColor
    public let inputClearButtonColor: UIColor
    public let separatorColor: UIColor
    
    public init(backgroundColor: UIColor, accentColor: UIColor, inputFillColor: UIColor, inputTextColor: UIColor, inputPlaceholderTextColor: UIColor, inputIconColor: UIColor, inputClearButtonColor: UIColor, separatorColor: UIColor) {
        self.backgroundColor = backgroundColor
        self.accentColor = accentColor
        self.inputFillColor = inputFillColor
        self.inputTextColor = inputTextColor
        self.inputPlaceholderTextColor = inputPlaceholderTextColor
        self.inputIconColor = inputIconColor
        self.inputClearButtonColor = inputClearButtonColor
        self.separatorColor = separatorColor
    }
    
    public func withUpdated(backgroundColor: UIColor? = nil, accentColor: UIColor? = nil, inputFillColor: UIColor? = nil, inputTextColor: UIColor? = nil, inputPlaceholderTextColor: UIColor? = nil, inputIconColor: UIColor? = nil, inputClearButtonColor: UIColor? = nil, separatorColor: UIColor? = nil) -> PresentationThemeNavigationSearchBar {
        return PresentationThemeNavigationSearchBar(backgroundColor: backgroundColor ?? self.backgroundColor, accentColor: accentColor ?? self.accentColor, inputFillColor: inputFillColor ?? self.inputFillColor, inputTextColor: inputTextColor ?? self.inputTextColor, inputPlaceholderTextColor: inputPlaceholderTextColor ?? self.inputPlaceholderTextColor, inputIconColor: inputIconColor ?? self.inputIconColor, inputClearButtonColor: inputClearButtonColor ?? self.inputClearButtonColor, separatorColor: separatorColor ?? self.separatorColor)
    }
}

public final class PresentationThemeRootController {
    public let statusBarStyle: PresentationThemeStatusBarStyle
    public let tabBar: PresentationThemeRootTabBar
    public let navigationBar: PresentationThemeRootNavigationBar
    public let navigationSearchBar: PresentationThemeNavigationSearchBar
    public let keyboardColor: PresentationThemeKeyboardColor
    
    public init(statusBarStyle: PresentationThemeStatusBarStyle, tabBar: PresentationThemeRootTabBar, navigationBar: PresentationThemeRootNavigationBar, navigationSearchBar: PresentationThemeNavigationSearchBar, keyboardColor: PresentationThemeKeyboardColor) {
        self.statusBarStyle = statusBarStyle
        self.tabBar = tabBar
        self.navigationBar = navigationBar
        self.navigationSearchBar = navigationSearchBar
        self.keyboardColor = keyboardColor
    }
    
    public func withUpdated(statusBarStyle: PresentationThemeStatusBarStyle? = nil, tabBar: PresentationThemeRootTabBar? = nil, navigationBar: PresentationThemeRootNavigationBar? = nil, navigationSearchBar: PresentationThemeNavigationSearchBar? = nil, keyboardColor: PresentationThemeKeyboardColor? = nil) -> PresentationThemeRootController {
        return PresentationThemeRootController(statusBarStyle: statusBarStyle ?? self.statusBarStyle, tabBar: tabBar ?? self.tabBar, navigationBar: navigationBar ?? self.navigationBar, navigationSearchBar: navigationSearchBar ?? self.navigationSearchBar, keyboardColor: keyboardColor ?? self.keyboardColor)
    }
}

public enum PresentationThemeActionSheetBackgroundType: Int32 {
    case light
    case dark
}

public final class PresentationThemeActionSheet {
    public let dimColor: UIColor
    public let backgroundType: PresentationThemeActionSheetBackgroundType
    public let opaqueItemBackgroundColor: UIColor
    public let itemBackgroundColor: UIColor
    public let opaqueItemHighlightedBackgroundColor: UIColor
    public let itemHighlightedBackgroundColor: UIColor
    public let opaqueItemSeparatorColor: UIColor
    public let standardActionTextColor: UIColor
    public let destructiveActionTextColor: UIColor
    public let disabledActionTextColor: UIColor
    public let primaryTextColor: UIColor
    public let secondaryTextColor: UIColor
    public let controlAccentColor: UIColor
    public let inputBackgroundColor: UIColor
    public let inputHollowBackgroundColor: UIColor
    public let inputBorderColor: UIColor
    public let inputPlaceholderColor: UIColor
    public let inputTextColor: UIColor
    public let inputClearButtonColor: UIColor
    public let checkContentColor: UIColor
    
    init(dimColor: UIColor, backgroundType: PresentationThemeActionSheetBackgroundType, opaqueItemBackgroundColor: UIColor, itemBackgroundColor: UIColor, opaqueItemHighlightedBackgroundColor: UIColor, itemHighlightedBackgroundColor: UIColor, opaqueItemSeparatorColor: UIColor, standardActionTextColor: UIColor, destructiveActionTextColor: UIColor, disabledActionTextColor: UIColor, primaryTextColor: UIColor, secondaryTextColor: UIColor, controlAccentColor: UIColor, inputBackgroundColor: UIColor, inputHollowBackgroundColor: UIColor, inputBorderColor: UIColor, inputPlaceholderColor: UIColor, inputTextColor: UIColor, inputClearButtonColor: UIColor, checkContentColor: UIColor) {
        self.dimColor = dimColor
        self.backgroundType = backgroundType
        self.opaqueItemBackgroundColor = opaqueItemBackgroundColor
        self.itemBackgroundColor = itemBackgroundColor
        self.opaqueItemHighlightedBackgroundColor = opaqueItemHighlightedBackgroundColor
        self.itemHighlightedBackgroundColor = itemHighlightedBackgroundColor
        self.opaqueItemSeparatorColor = opaqueItemSeparatorColor
        self.standardActionTextColor = standardActionTextColor
        self.destructiveActionTextColor = destructiveActionTextColor
        self.disabledActionTextColor = disabledActionTextColor
        self.primaryTextColor = primaryTextColor
        self.secondaryTextColor = secondaryTextColor
        self.controlAccentColor = controlAccentColor
        self.inputBackgroundColor = inputBackgroundColor
        self.inputHollowBackgroundColor = inputHollowBackgroundColor
        self.inputBorderColor = inputBorderColor
        self.inputPlaceholderColor = inputPlaceholderColor
        self.inputTextColor = inputTextColor
        self.inputClearButtonColor = inputClearButtonColor
        self.checkContentColor = checkContentColor
    }
    
    public func withUpdated(dimColor: UIColor? = nil, backgroundType: PresentationThemeActionSheetBackgroundType? = nil, opaqueItemBackgroundColor: UIColor? = nil, itemBackgroundColor: UIColor? = nil, opaqueItemHighlightedBackgroundColor: UIColor? = nil, itemHighlightedBackgroundColor: UIColor? = nil, opaqueItemSeparatorColor: UIColor? = nil, standardActionTextColor: UIColor? = nil, destructiveActionTextColor: UIColor? = nil, disabledActionTextColor: UIColor? = nil, primaryTextColor: UIColor? = nil, secondaryTextColor: UIColor? = nil, controlAccentColor: UIColor? = nil, inputBackgroundColor: UIColor? = nil, inputHollowBackgroundColor: UIColor? = nil, inputBorderColor: UIColor? = nil, inputPlaceholderColor: UIColor? = nil, inputTextColor: UIColor? = nil, inputClearButtonColor: UIColor? = nil, checkContentColor: UIColor? = nil) -> PresentationThemeActionSheet {
        return PresentationThemeActionSheet(dimColor: dimColor ?? self.dimColor, backgroundType: backgroundType ?? self.backgroundType, opaqueItemBackgroundColor: opaqueItemBackgroundColor ?? self.opaqueItemBackgroundColor, itemBackgroundColor: itemBackgroundColor ?? self.itemBackgroundColor, opaqueItemHighlightedBackgroundColor: opaqueItemHighlightedBackgroundColor ?? self.opaqueItemHighlightedBackgroundColor, itemHighlightedBackgroundColor: itemHighlightedBackgroundColor ?? self.itemHighlightedBackgroundColor, opaqueItemSeparatorColor: opaqueItemSeparatorColor ?? self.opaqueItemSeparatorColor, standardActionTextColor: standardActionTextColor ?? self.standardActionTextColor, destructiveActionTextColor: destructiveActionTextColor ?? self.destructiveActionTextColor, disabledActionTextColor: disabledActionTextColor ?? self.disabledActionTextColor, primaryTextColor: primaryTextColor ?? self.primaryTextColor, secondaryTextColor: secondaryTextColor ?? self.secondaryTextColor, controlAccentColor: controlAccentColor ?? self.controlAccentColor, inputBackgroundColor: inputBackgroundColor ?? self.inputBackgroundColor, inputHollowBackgroundColor: inputHollowBackgroundColor ?? self.inputHollowBackgroundColor, inputBorderColor: inputBorderColor ?? self.inputBorderColor, inputPlaceholderColor: inputPlaceholderColor ?? self.inputPlaceholderColor, inputTextColor: inputTextColor ?? self.inputTextColor, inputClearButtonColor: inputClearButtonColor ?? self.inputClearButtonColor, checkContentColor: checkContentColor ?? self.checkContentColor)
    }
}

public final class PresentationThemeContextMenu {
    public let dimColor: UIColor
    public let backgroundColor: UIColor
    public let itemSeparatorColor: UIColor
    public let sectionSeparatorColor: UIColor
    public let itemBackgroundColor: UIColor
    public let itemHighlightedBackgroundColor: UIColor
    public let primaryColor: UIColor
    public let secondaryColor: UIColor
    public let destructiveColor: UIColor
    public let badgeFillColor: UIColor
    public let badgeForegroundColor: UIColor
    public let badgeInactiveFillColor: UIColor
    public let badgeInactiveForegroundColor: UIColor
    public let extractedContentTintColor: UIColor
    
    init(dimColor: UIColor, backgroundColor: UIColor, itemSeparatorColor: UIColor, sectionSeparatorColor: UIColor, itemBackgroundColor: UIColor, itemHighlightedBackgroundColor: UIColor, primaryColor: UIColor, secondaryColor: UIColor, destructiveColor: UIColor, badgeFillColor: UIColor, badgeForegroundColor: UIColor, badgeInactiveFillColor: UIColor, badgeInactiveForegroundColor: UIColor, extractedContentTintColor: UIColor) {
        self.dimColor = dimColor
        self.backgroundColor = backgroundColor
        self.itemSeparatorColor = itemSeparatorColor
        self.sectionSeparatorColor = sectionSeparatorColor
        self.itemBackgroundColor = itemBackgroundColor
        self.itemHighlightedBackgroundColor = itemHighlightedBackgroundColor
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor
        self.destructiveColor = destructiveColor
        self.badgeFillColor = badgeFillColor
        self.badgeForegroundColor = badgeForegroundColor
        self.badgeInactiveFillColor = badgeInactiveFillColor
        self.badgeInactiveForegroundColor = badgeInactiveForegroundColor
        self.extractedContentTintColor = extractedContentTintColor
    }
    
    public func withUpdated(dimColor: UIColor? = nil, backgroundColor: UIColor? = nil, itemSeparatorColor: UIColor? = nil, sectionSeparatorColor: UIColor? = nil, itemBackgroundColor: UIColor? = nil, itemHighlightedBackgroundColor: UIColor? = nil, primaryColor: UIColor? = nil, secondaryColor: UIColor? = nil, destructiveColor: UIColor? = nil) -> PresentationThemeContextMenu {
        return PresentationThemeContextMenu(dimColor: dimColor ?? self.dimColor, backgroundColor: backgroundColor ?? self.backgroundColor, itemSeparatorColor: itemSeparatorColor ?? self.itemSeparatorColor, sectionSeparatorColor: sectionSeparatorColor ?? self.sectionSeparatorColor, itemBackgroundColor: itemBackgroundColor ?? self.itemBackgroundColor, itemHighlightedBackgroundColor: itemHighlightedBackgroundColor ?? self.itemHighlightedBackgroundColor, primaryColor: primaryColor ?? self.primaryColor, secondaryColor: secondaryColor ?? self.secondaryColor, destructiveColor: destructiveColor ?? self.destructiveColor, badgeFillColor: self.badgeFillColor, badgeForegroundColor: self.badgeForegroundColor, badgeInactiveFillColor: self.badgeInactiveFillColor, badgeInactiveForegroundColor: self.badgeInactiveForegroundColor, extractedContentTintColor: self.extractedContentTintColor)
    }
}

public final class PresentationThemeSwitch {
    public let frameColor: UIColor
    public let handleColor: UIColor
    public let contentColor: UIColor
    public let positiveColor: UIColor
    public let negativeColor: UIColor
    
    public init(frameColor: UIColor, handleColor: UIColor, contentColor: UIColor, positiveColor: UIColor, negativeColor: UIColor) {
        self.frameColor = frameColor
        self.handleColor = handleColor
        self.contentColor = contentColor
        self.positiveColor = positiveColor
        self.negativeColor = negativeColor
    }
    
    public func withUpdated(frameColor: UIColor? = nil, handleColor: UIColor? = nil, contentColor: UIColor? = nil, positiveColor: UIColor? = nil, negativeColor: UIColor? = nil) -> PresentationThemeSwitch {
        return PresentationThemeSwitch(frameColor: frameColor ?? self.frameColor, handleColor: handleColor ?? self.handleColor, contentColor: contentColor ?? self.contentColor, positiveColor: positiveColor ?? self.positiveColor, negativeColor: negativeColor ?? self.negativeColor)
    }
}

public final class PresentationThemeFillForeground {
    public let fillColor: UIColor
    public let foregroundColor: UIColor
    
    init(fillColor: UIColor, foregroundColor: UIColor) {
        self.fillColor = fillColor
        self.foregroundColor = foregroundColor
    }
    
    public func withUpdated(fillColor: UIColor? = nil, foregroundColor: UIColor? = nil) -> PresentationThemeFillForeground {
        return PresentationThemeFillForeground(fillColor: fillColor ?? self.fillColor, foregroundColor: foregroundColor ?? self.foregroundColor)
    }
}

public final class PresentationThemeItemDisclosureActions {
    public let neutral1: PresentationThemeFillForeground
    public let neutral2: PresentationThemeFillForeground
    public let destructive: PresentationThemeFillForeground
    public let constructive: PresentationThemeFillForeground
    public let accent: PresentationThemeFillForeground
    public let warning: PresentationThemeFillForeground
    public let inactive: PresentationThemeFillForeground
    
    public init(neutral1: PresentationThemeFillForeground, neutral2: PresentationThemeFillForeground, destructive: PresentationThemeFillForeground, constructive: PresentationThemeFillForeground, accent: PresentationThemeFillForeground, warning: PresentationThemeFillForeground, inactive: PresentationThemeFillForeground) {
        self.neutral1 = neutral1
        self.neutral2 = neutral2
        self.destructive = destructive
        self.constructive = constructive
        self.accent = accent
        self.warning = warning
        self.inactive = inactive
    }
    
    public func withUpdated(neutral1: PresentationThemeFillForeground? = nil, neutral2: PresentationThemeFillForeground? = nil, destructive: PresentationThemeFillForeground? = nil, constructive: PresentationThemeFillForeground? = nil, accent: PresentationThemeFillForeground? = nil, warning: PresentationThemeFillForeground? = nil, inactive: PresentationThemeFillForeground? = nil) -> PresentationThemeItemDisclosureActions {
        return PresentationThemeItemDisclosureActions(neutral1: neutral1 ?? self.neutral1, neutral2: neutral2 ?? self.neutral2, destructive: destructive ?? self.destructive, constructive: constructive ?? self.constructive, accent: accent ?? self.accent, warning: warning ?? self.warning, inactive: inactive ?? self.inactive)
    }
}

public final class PresentationThemeItemBarChart {
    public let color1: UIColor
    public let color2: UIColor
    public let color3: UIColor
    
    public init(color1: UIColor, color2: UIColor, color3: UIColor) {
        self.color1 = color1
        self.color2 = color2
        self.color3 = color3
    }
    
    public func withUpdated(color1: UIColor? = nil, color2: UIColor? = nil, color3: UIColor? = nil) -> PresentationThemeItemBarChart {
        return PresentationThemeItemBarChart(color1: color1 ?? self.color1, color2: color2 ?? self.color2, color3: color3 ?? self.color3)
    }
}

public final class PresentationThemeFillStrokeForeground {
    public let fillColor: UIColor
    public let strokeColor: UIColor
    public let foregroundColor: UIColor
    
    init(fillColor: UIColor, strokeColor: UIColor, foregroundColor: UIColor) {
        self.fillColor = fillColor
        self.strokeColor = strokeColor
        self.foregroundColor = foregroundColor
    }
    
    public func withUpdated(fillColor: UIColor? = nil, strokeColor: UIColor? = nil, foregroundColor: UIColor? = nil) -> PresentationThemeFillStrokeForeground {
        return PresentationThemeFillStrokeForeground(fillColor: fillColor ?? self.fillColor, strokeColor: strokeColor ?? self.strokeColor, foregroundColor: foregroundColor ?? self.foregroundColor)
    }
}

public final class PresentationInputFieldTheme {
    public let backgroundColor: UIColor
    public let strokeColor: UIColor
    public let placeholderColor: UIColor
    public let primaryColor: UIColor
    public let controlColor: UIColor
    
    public init(backgroundColor: UIColor, strokeColor: UIColor, placeholderColor: UIColor, primaryColor: UIColor, controlColor: UIColor) {
        self.backgroundColor = backgroundColor
        self.strokeColor = strokeColor
        self.placeholderColor = placeholderColor
        self.primaryColor = primaryColor
        self.controlColor = controlColor
    }
    
    public func withUpdated(backgroundColor: UIColor? = nil, strokeColor: UIColor? = nil, placeholderColor: UIColor? = nil, primaryColor: UIColor? = nil, controlColor: UIColor? = nil) -> PresentationInputFieldTheme {
        return PresentationInputFieldTheme(backgroundColor: backgroundColor ?? self.backgroundColor, strokeColor: strokeColor ?? self.strokeColor, placeholderColor: placeholderColor ?? self.placeholderColor, primaryColor: primaryColor ?? self.primaryColor, controlColor: controlColor ?? self.controlColor)
    }
}

public final class PresentationThemeList {
    public final class PaymentOption {
        public let inactiveFillColor: UIColor
        public let inactiveForegroundColor: UIColor
        public let activeFillColor: UIColor
        public let activeForegroundColor: UIColor

        public init(
            inactiveFillColor: UIColor,
            inactiveForegroundColor: UIColor,
            activeFillColor: UIColor,
            activeForegroundColor: UIColor
        ) {
            self.inactiveFillColor = inactiveFillColor
            self.inactiveForegroundColor = inactiveForegroundColor
            self.activeFillColor = activeFillColor
            self.activeForegroundColor = activeForegroundColor
        }
    }

    public let blocksBackgroundColor: UIColor
    public let plainBackgroundColor: UIColor
    public let itemPrimaryTextColor: UIColor
    public let itemSecondaryTextColor: UIColor
    public let itemDisabledTextColor: UIColor
    public let itemAccentColor: UIColor
    public let itemHighlightedColor: UIColor
    public let itemDestructiveColor: UIColor
    public let itemPlaceholderTextColor: UIColor
    public let itemBlocksBackgroundColor: UIColor
    public let itemHighlightedBackgroundColor: UIColor
    public let itemBlocksSeparatorColor: UIColor
    public let itemPlainSeparatorColor: UIColor
    public let disclosureArrowColor: UIColor
    public let sectionHeaderTextColor: UIColor
    public let freeTextColor: UIColor
    public let freeTextErrorColor: UIColor
    public let freeTextSuccessColor: UIColor
    public let freeMonoIconColor: UIColor
    public let itemSwitchColors: PresentationThemeSwitch
    public let itemDisclosureActions: PresentationThemeItemDisclosureActions
    public let itemCheckColors: PresentationThemeFillStrokeForeground
    public let controlSecondaryColor: UIColor
    public let freeInputField: PresentationInputFieldTheme
    public let freePlainInputField: PresentationInputFieldTheme
    public let mediaPlaceholderColor: UIColor
    public let scrollIndicatorColor: UIColor
    public let pageIndicatorInactiveColor: UIColor
    public let inputClearButtonColor: UIColor
    public let itemBarChart: PresentationThemeItemBarChart
    public let itemInputField: PresentationInputFieldTheme
    public let paymentOption: PaymentOption
    
    public init(
        blocksBackgroundColor: UIColor,
        plainBackgroundColor: UIColor,
        itemPrimaryTextColor: UIColor,
        itemSecondaryTextColor: UIColor,
        itemDisabledTextColor: UIColor,
        itemAccentColor: UIColor,
        itemHighlightedColor: UIColor,
        itemDestructiveColor: UIColor,
        itemPlaceholderTextColor: UIColor,
        itemBlocksBackgroundColor: UIColor,
        itemHighlightedBackgroundColor: UIColor,
        itemBlocksSeparatorColor: UIColor,
        itemPlainSeparatorColor: UIColor,
        disclosureArrowColor: UIColor,
        sectionHeaderTextColor: UIColor,
        freeTextColor: UIColor,
        freeTextErrorColor: UIColor,
        freeTextSuccessColor: UIColor,
        freeMonoIconColor: UIColor,
        itemSwitchColors: PresentationThemeSwitch,
        itemDisclosureActions: PresentationThemeItemDisclosureActions,
        itemCheckColors: PresentationThemeFillStrokeForeground,
        controlSecondaryColor: UIColor,
        freeInputField: PresentationInputFieldTheme,
        freePlainInputField: PresentationInputFieldTheme,
        mediaPlaceholderColor: UIColor,
        scrollIndicatorColor: UIColor,
        pageIndicatorInactiveColor: UIColor,
        inputClearButtonColor: UIColor,
        itemBarChart: PresentationThemeItemBarChart,
        itemInputField: PresentationInputFieldTheme,
        paymentOption: PaymentOption
    ) {
        self.blocksBackgroundColor = blocksBackgroundColor
        self.plainBackgroundColor = plainBackgroundColor
        self.itemPrimaryTextColor = itemPrimaryTextColor
        self.itemSecondaryTextColor = itemSecondaryTextColor
        self.itemDisabledTextColor = itemDisabledTextColor
        self.itemAccentColor = itemAccentColor
        self.itemHighlightedColor = itemHighlightedColor
        self.itemDestructiveColor = itemDestructiveColor
        self.itemPlaceholderTextColor = itemPlaceholderTextColor
        self.itemBlocksBackgroundColor = itemBlocksBackgroundColor
        self.itemHighlightedBackgroundColor = itemHighlightedBackgroundColor
        self.itemBlocksSeparatorColor = itemBlocksSeparatorColor
        self.itemPlainSeparatorColor = itemPlainSeparatorColor
        self.disclosureArrowColor = disclosureArrowColor
        self.sectionHeaderTextColor = sectionHeaderTextColor
        self.freeTextColor = freeTextColor
        self.freeTextErrorColor = freeTextErrorColor
        self.freeTextSuccessColor = freeTextSuccessColor
        self.freeMonoIconColor = freeMonoIconColor
        self.itemSwitchColors = itemSwitchColors
        self.itemDisclosureActions = itemDisclosureActions
        self.itemCheckColors = itemCheckColors
        self.controlSecondaryColor = controlSecondaryColor
        self.freeInputField = freeInputField
        self.freePlainInputField = freePlainInputField
        self.mediaPlaceholderColor = mediaPlaceholderColor
        self.scrollIndicatorColor = scrollIndicatorColor
        self.pageIndicatorInactiveColor = pageIndicatorInactiveColor
        self.inputClearButtonColor = inputClearButtonColor
        self.itemBarChart = itemBarChart
        self.itemInputField = itemInputField
        self.paymentOption = paymentOption
    }
    
    public func withUpdated(blocksBackgroundColor: UIColor? = nil, plainBackgroundColor: UIColor? = nil, itemPrimaryTextColor: UIColor? = nil, itemSecondaryTextColor: UIColor? = nil, itemDisabledTextColor: UIColor? = nil, itemAccentColor: UIColor? = nil, itemHighlightedColor: UIColor? = nil, itemDestructiveColor: UIColor? = nil, itemPlaceholderTextColor: UIColor? = nil, itemBlocksBackgroundColor: UIColor? = nil, itemHighlightedBackgroundColor: UIColor? = nil, itemBlocksSeparatorColor: UIColor? = nil, itemPlainSeparatorColor: UIColor? = nil, disclosureArrowColor: UIColor? = nil, sectionHeaderTextColor: UIColor? = nil, freeTextColor: UIColor? = nil, freeTextErrorColor: UIColor? = nil, freeTextSuccessColor: UIColor? = nil, freeMonoIconColor: UIColor? = nil, itemSwitchColors: PresentationThemeSwitch? = nil, itemDisclosureActions: PresentationThemeItemDisclosureActions? = nil, itemCheckColors: PresentationThemeFillStrokeForeground? = nil, controlSecondaryColor: UIColor? = nil, freeInputField: PresentationInputFieldTheme? = nil, freePlainInputField: PresentationInputFieldTheme? = nil, mediaPlaceholderColor: UIColor? = nil, scrollIndicatorColor: UIColor? = nil, pageIndicatorInactiveColor: UIColor? = nil, inputClearButtonColor: UIColor? = nil, itemBarChart: PresentationThemeItemBarChart? = nil, itemInputField: PresentationInputFieldTheme? = nil, paymentOption: PaymentOption? = nil) -> PresentationThemeList {
        return PresentationThemeList(blocksBackgroundColor: blocksBackgroundColor ?? self.blocksBackgroundColor, plainBackgroundColor: plainBackgroundColor ?? self.plainBackgroundColor, itemPrimaryTextColor: itemPrimaryTextColor ?? self.itemPrimaryTextColor, itemSecondaryTextColor: itemSecondaryTextColor ?? self.itemSecondaryTextColor, itemDisabledTextColor: itemDisabledTextColor ?? self.itemDisabledTextColor, itemAccentColor: itemAccentColor ?? self.itemAccentColor, itemHighlightedColor: itemHighlightedColor ?? self.itemHighlightedColor, itemDestructiveColor: itemDestructiveColor ?? self.itemDestructiveColor, itemPlaceholderTextColor: itemPlaceholderTextColor ?? self.itemPlaceholderTextColor, itemBlocksBackgroundColor: itemBlocksBackgroundColor ?? self.itemBlocksBackgroundColor, itemHighlightedBackgroundColor: itemHighlightedBackgroundColor ?? self.itemHighlightedBackgroundColor, itemBlocksSeparatorColor: itemBlocksSeparatorColor ?? self.itemBlocksSeparatorColor, itemPlainSeparatorColor: itemPlainSeparatorColor ?? self.itemPlainSeparatorColor, disclosureArrowColor: disclosureArrowColor ?? self.disclosureArrowColor, sectionHeaderTextColor: sectionHeaderTextColor ?? self.sectionHeaderTextColor, freeTextColor: freeTextColor ?? self.freeTextColor, freeTextErrorColor: freeTextErrorColor ?? self.freeTextErrorColor, freeTextSuccessColor: freeTextSuccessColor ?? self.freeTextSuccessColor, freeMonoIconColor: freeMonoIconColor ?? self.freeMonoIconColor, itemSwitchColors: itemSwitchColors ?? self.itemSwitchColors, itemDisclosureActions: itemDisclosureActions ?? self.itemDisclosureActions, itemCheckColors: itemCheckColors ?? self.itemCheckColors, controlSecondaryColor: controlSecondaryColor ?? self.controlSecondaryColor, freeInputField: freeInputField ?? self.freeInputField, freePlainInputField: freePlainInputField ?? self.freePlainInputField, mediaPlaceholderColor: mediaPlaceholderColor ?? self.mediaPlaceholderColor, scrollIndicatorColor: scrollIndicatorColor ?? self.scrollIndicatorColor, pageIndicatorInactiveColor: pageIndicatorInactiveColor ?? self.pageIndicatorInactiveColor, inputClearButtonColor: inputClearButtonColor ?? self.inputClearButtonColor, itemBarChart: itemBarChart ?? self.itemBarChart, itemInputField: itemInputField ?? self.itemInputField, paymentOption: paymentOption ?? self.paymentOption)
    }
}

public final class PresentationThemeArchiveAvatarColors {
    public let backgroundColors: PresentationThemeGradientColors
    public let foregroundColor: UIColor
    
    public init(backgroundColors: PresentationThemeGradientColors, foregroundColor: UIColor) {
        self.backgroundColors = backgroundColors
        self.foregroundColor = foregroundColor
    }
    
    public func withUpdated(backgroundColors: PresentationThemeGradientColors? = nil, foregroundColor: UIColor? = nil) -> PresentationThemeArchiveAvatarColors {
        return PresentationThemeArchiveAvatarColors(backgroundColors: backgroundColors ?? self.backgroundColors, foregroundColor: foregroundColor ?? self.foregroundColor)
    }
}

public final class PresentationThemeChatList {
    public let backgroundColor: UIColor
    public let itemSeparatorColor: UIColor
    public let itemBackgroundColor: UIColor
    public let pinnedItemBackgroundColor: UIColor
    public let itemHighlightedBackgroundColor: UIColor
    public let itemSelectedBackgroundColor: UIColor
    public let titleColor: UIColor
    public let secretTitleColor: UIColor
    public let dateTextColor: UIColor
    public let authorNameColor: UIColor
    public let messageTextColor: UIColor
    public let messageHighlightedTextColor: UIColor
    public let messageDraftTextColor: UIColor
    public let checkmarkColor: UIColor
    public let pendingIndicatorColor: UIColor
    public let failedFillColor: UIColor
    public let failedForegroundColor: UIColor
    public let muteIconColor: UIColor
    public let unreadBadgeActiveBackgroundColor: UIColor
    public let unreadBadgeActiveTextColor: UIColor
    public let unreadBadgeInactiveBackgroundColor: UIColor
    public let unreadBadgeInactiveTextColor: UIColor
    public let reactionBadgeActiveBackgroundColor: UIColor
    public let pinnedBadgeColor: UIColor
    public let pinnedSearchBarColor: UIColor
    public let regularSearchBarColor: UIColor
    public let sectionHeaderFillColor: UIColor
    public let sectionHeaderTextColor: UIColor
    public let verifiedIconFillColor: UIColor
    public let verifiedIconForegroundColor: UIColor
    public let secretIconColor: UIColor
    public let pinnedArchiveAvatarColor: PresentationThemeArchiveAvatarColors
    public let unpinnedArchiveAvatarColor: PresentationThemeArchiveAvatarColors
    public let onlineDotColor: UIColor
    
    init(
        backgroundColor: UIColor,
        itemSeparatorColor: UIColor,
        itemBackgroundColor: UIColor,
        pinnedItemBackgroundColor: UIColor,
        itemHighlightedBackgroundColor: UIColor,
        itemSelectedBackgroundColor: UIColor,
        titleColor: UIColor,
        secretTitleColor: UIColor,
        dateTextColor: UIColor,
        authorNameColor: UIColor,
        messageTextColor: UIColor,
        messageHighlightedTextColor: UIColor,
        messageDraftTextColor: UIColor,
        checkmarkColor: UIColor,
        pendingIndicatorColor: UIColor,
        failedFillColor: UIColor,
        failedForegroundColor: UIColor,
        muteIconColor: UIColor,
        unreadBadgeActiveBackgroundColor: UIColor,
        unreadBadgeActiveTextColor: UIColor,
        unreadBadgeInactiveBackgroundColor: UIColor,
        unreadBadgeInactiveTextColor: UIColor,
        reactionBadgeActiveBackgroundColor: UIColor,
        pinnedBadgeColor: UIColor,
        pinnedSearchBarColor: UIColor,
        regularSearchBarColor: UIColor,
        sectionHeaderFillColor: UIColor,
        sectionHeaderTextColor: UIColor,
        verifiedIconFillColor: UIColor,
        verifiedIconForegroundColor: UIColor,
        secretIconColor: UIColor,
        pinnedArchiveAvatarColor: PresentationThemeArchiveAvatarColors,
        unpinnedArchiveAvatarColor: PresentationThemeArchiveAvatarColors,
        onlineDotColor: UIColor
    ) {
        self.backgroundColor = backgroundColor
        self.itemSeparatorColor = itemSeparatorColor
        self.itemBackgroundColor = itemBackgroundColor
        self.pinnedItemBackgroundColor = pinnedItemBackgroundColor
        self.itemHighlightedBackgroundColor = itemHighlightedBackgroundColor
        self.itemSelectedBackgroundColor = itemSelectedBackgroundColor
        self.titleColor = titleColor
        self.secretTitleColor = secretTitleColor
        self.dateTextColor = dateTextColor
        self.authorNameColor = authorNameColor
        self.messageTextColor = messageTextColor
        self.messageHighlightedTextColor = messageHighlightedTextColor
        self.messageDraftTextColor = messageDraftTextColor
        self.checkmarkColor = checkmarkColor
        self.pendingIndicatorColor = pendingIndicatorColor
        self.failedFillColor = failedFillColor
        self.failedForegroundColor = failedForegroundColor
        self.muteIconColor = muteIconColor
        self.unreadBadgeActiveBackgroundColor = unreadBadgeActiveBackgroundColor
        self.unreadBadgeActiveTextColor = unreadBadgeActiveTextColor
        self.unreadBadgeInactiveBackgroundColor = unreadBadgeInactiveBackgroundColor
        self.unreadBadgeInactiveTextColor = unreadBadgeInactiveTextColor
        self.reactionBadgeActiveBackgroundColor = reactionBadgeActiveBackgroundColor
        self.pinnedBadgeColor = pinnedBadgeColor
        self.pinnedSearchBarColor = pinnedSearchBarColor
        self.regularSearchBarColor = regularSearchBarColor
        self.sectionHeaderFillColor = sectionHeaderFillColor
        self.sectionHeaderTextColor = sectionHeaderTextColor
        self.verifiedIconFillColor = verifiedIconFillColor
        self.verifiedIconForegroundColor = verifiedIconForegroundColor
        self.secretIconColor = secretIconColor
        self.pinnedArchiveAvatarColor = pinnedArchiveAvatarColor
        self.unpinnedArchiveAvatarColor = unpinnedArchiveAvatarColor
        self.onlineDotColor = onlineDotColor
    }
    
    public func withUpdated(
        backgroundColor: UIColor? = nil,
        itemSeparatorColor: UIColor? = nil,
        itemBackgroundColor: UIColor? = nil,
        pinnedItemBackgroundColor: UIColor? = nil,
        itemHighlightedBackgroundColor: UIColor? = nil,
        itemSelectedBackgroundColor: UIColor? = nil,
        titleColor: UIColor? = nil,
        secretTitleColor: UIColor? = nil,
        dateTextColor: UIColor? = nil,
        authorNameColor: UIColor? = nil,
        messageTextColor: UIColor? = nil,
        messageHighlightedTextColor: UIColor? = nil,
        messageDraftTextColor: UIColor? = nil,
        checkmarkColor: UIColor? = nil,
        pendingIndicatorColor: UIColor? = nil,
        failedFillColor: UIColor? = nil,
        failedForegroundColor: UIColor? = nil,
        muteIconColor: UIColor? = nil,
        unreadBadgeActiveBackgroundColor: UIColor? = nil,
        unreadBadgeActiveTextColor: UIColor? = nil,
        unreadBadgeInactiveBackgroundColor: UIColor? = nil,
        unreadBadgeInactiveTextColor: UIColor? = nil,
        reactionBadgeActiveBackgroundColor: UIColor? = nil,
        pinnedBadgeColor: UIColor? = nil,
        pinnedSearchBarColor: UIColor? = nil,
        regularSearchBarColor: UIColor? = nil,
        sectionHeaderFillColor: UIColor? = nil,
        sectionHeaderTextColor: UIColor? = nil,
        verifiedIconFillColor: UIColor? = nil,
        verifiedIconForegroundColor: UIColor? = nil,
        secretIconColor: UIColor? = nil,
        pinnedArchiveAvatarColor: PresentationThemeArchiveAvatarColors? = nil,
        unpinnedArchiveAvatarColor: PresentationThemeArchiveAvatarColors? = nil,
        onlineDotColor: UIColor? = nil
    ) -> PresentationThemeChatList {
        return PresentationThemeChatList(
            backgroundColor: backgroundColor ?? self.backgroundColor,
            itemSeparatorColor: itemSeparatorColor ?? self.itemSeparatorColor,
            itemBackgroundColor: itemBackgroundColor ?? self.itemBackgroundColor,
            pinnedItemBackgroundColor: pinnedItemBackgroundColor ?? self.pinnedItemBackgroundColor,
            itemHighlightedBackgroundColor: itemHighlightedBackgroundColor ?? self.itemHighlightedBackgroundColor,
            itemSelectedBackgroundColor: itemSelectedBackgroundColor ?? self.itemSelectedBackgroundColor,
            titleColor: titleColor ?? self.titleColor,
            secretTitleColor: secretTitleColor ?? self.secretTitleColor,
            dateTextColor: dateTextColor ?? self.dateTextColor,
            authorNameColor: authorNameColor ?? self.authorNameColor,
            messageTextColor: messageTextColor ?? self.messageTextColor,
            messageHighlightedTextColor: messageHighlightedTextColor ?? self.messageHighlightedTextColor,
            messageDraftTextColor: messageDraftTextColor ?? self.messageDraftTextColor,
            checkmarkColor: checkmarkColor ?? self.checkmarkColor,
            pendingIndicatorColor: pendingIndicatorColor ?? self.pendingIndicatorColor,
            failedFillColor: failedFillColor ?? self.failedFillColor,
            failedForegroundColor: failedForegroundColor ?? self.failedForegroundColor,
            muteIconColor: muteIconColor ?? self.muteIconColor,
            unreadBadgeActiveBackgroundColor: unreadBadgeActiveBackgroundColor ?? self.unreadBadgeActiveBackgroundColor,
            unreadBadgeActiveTextColor: unreadBadgeActiveTextColor ?? self.unreadBadgeActiveTextColor,
            unreadBadgeInactiveBackgroundColor: unreadBadgeInactiveBackgroundColor ?? self.unreadBadgeInactiveBackgroundColor,
            unreadBadgeInactiveTextColor: unreadBadgeInactiveTextColor ?? self.unreadBadgeInactiveTextColor,
            reactionBadgeActiveBackgroundColor: reactionBadgeActiveBackgroundColor ?? self.reactionBadgeActiveBackgroundColor,
            pinnedBadgeColor: pinnedBadgeColor ?? self.pinnedBadgeColor,
            pinnedSearchBarColor: pinnedSearchBarColor ?? self.pinnedSearchBarColor,
            regularSearchBarColor: regularSearchBarColor ?? self.regularSearchBarColor,
            sectionHeaderFillColor: sectionHeaderFillColor ?? self.sectionHeaderFillColor,
            sectionHeaderTextColor: sectionHeaderTextColor ?? self.sectionHeaderTextColor,
            verifiedIconFillColor: verifiedIconFillColor ?? self.verifiedIconFillColor,
            verifiedIconForegroundColor: verifiedIconForegroundColor ?? self.verifiedIconForegroundColor,
            secretIconColor: secretIconColor ?? self.secretIconColor,
            pinnedArchiveAvatarColor: pinnedArchiveAvatarColor ?? self.pinnedArchiveAvatarColor,
            unpinnedArchiveAvatarColor: unpinnedArchiveAvatarColor ?? self.unpinnedArchiveAvatarColor,
            onlineDotColor: onlineDotColor ?? self.onlineDotColor
        )
    }
}

public struct PresentationThemeBubbleShadow {
    public var color: UIColor
    public var radius: CGFloat
    public var verticalOffset: CGFloat
    
    public init(color: UIColor, radius: CGFloat, verticalOffset: CGFloat) {
        self.color = color
        self.radius = radius
        self.verticalOffset = verticalOffset
    }
}

public final class PresentationThemeBubbleColorComponents {
    public let fill: [UIColor]
    public let highlightedFill: UIColor
    public let stroke: UIColor
    public let shadow: PresentationThemeBubbleShadow?
    public let reactionInactiveBackground: UIColor
    public let reactionInactiveForeground: UIColor
    public let reactionActiveBackground: UIColor
    public let reactionActiveForeground: UIColor
    
    public init(
        fill: [UIColor],
        highlightedFill: UIColor,
        stroke: UIColor,
        shadow: PresentationThemeBubbleShadow?,
        reactionInactiveBackground: UIColor,
        reactionInactiveForeground: UIColor,
        reactionActiveBackground: UIColor,
        reactionActiveForeground: UIColor
    ) {
        self.fill = fill
        self.highlightedFill = highlightedFill
        self.stroke = stroke
        self.shadow = shadow
        self.reactionInactiveBackground = reactionInactiveBackground
        self.reactionInactiveForeground = reactionInactiveForeground
        self.reactionActiveBackground = reactionActiveBackground
        self.reactionActiveForeground = reactionActiveForeground
    }
    
    public func withUpdated(
        fill: [UIColor]? = nil,
        highlightedFill: UIColor? = nil,
        stroke: UIColor? = nil,
        reactionInactiveBackground: UIColor? = nil,
        reactionInactiveForeground: UIColor? = nil,
        reactionActiveBackground: UIColor? = nil,
        reactionActiveForeground: UIColor? = nil
    ) -> PresentationThemeBubbleColorComponents {
        return PresentationThemeBubbleColorComponents(
            fill: fill ?? self.fill,
            highlightedFill: highlightedFill ?? self.highlightedFill,
            stroke: stroke ?? self.stroke,
            shadow: self.shadow,
            reactionInactiveBackground: reactionInactiveBackground ?? self.reactionInactiveBackground,
            reactionInactiveForeground: reactionInactiveForeground ?? self.reactionInactiveForeground,
            reactionActiveBackground: reactionActiveBackground ?? self.reactionActiveBackground,
            reactionActiveForeground: reactionActiveForeground ?? self.reactionActiveForeground
        )
    }
}

public final class PresentationThemeBubbleColor {
    public let withWallpaper: PresentationThemeBubbleColorComponents
    public let withoutWallpaper: PresentationThemeBubbleColorComponents
    
    public init(withWallpaper: PresentationThemeBubbleColorComponents, withoutWallpaper: PresentationThemeBubbleColorComponents) {
        self.withWallpaper = withWallpaper
        self.withoutWallpaper = withoutWallpaper
    }
    
    public func withUpdated(withWallpaper: PresentationThemeBubbleColorComponents? = nil, withoutWallpaper: PresentationThemeBubbleColorComponents? = nil) -> PresentationThemeBubbleColor {
        return PresentationThemeBubbleColor(withWallpaper: withWallpaper ?? self.withWallpaper, withoutWallpaper: withoutWallpaper ?? self.withoutWallpaper)
    }
}

public final class PresentationThemeVariableColor {
    public let withWallpaper: UIColor
    public let withoutWallpaper: UIColor
    
    public init(withWallpaper: UIColor, withoutWallpaper: UIColor) {
        self.withWallpaper = withWallpaper
        self.withoutWallpaper = withoutWallpaper
    }
    
    public init(color: UIColor) {
        self.withWallpaper = color
        self.withoutWallpaper = color
    }
    
    public func withUpdated(withWallpaper: UIColor? = nil, withoutWallpaper: UIColor? = nil) -> PresentationThemeVariableColor {
        return PresentationThemeVariableColor(withWallpaper: withWallpaper ?? self.withWallpaper, withoutWallpaper: withoutWallpaper ?? self.withoutWallpaper)
    }
}

public func bubbleColorComponents(theme: PresentationTheme, incoming: Bool, wallpaper: Bool) -> PresentationThemeBubbleColorComponents {
    if incoming {
        if wallpaper {
            return theme.chat.message.incoming.bubble.withWallpaper
        } else {
            return theme.chat.message.incoming.bubble.withoutWallpaper
        }
    } else {
        if wallpaper {
            return theme.chat.message.outgoing.bubble.withWallpaper
        } else {
            return theme.chat.message.outgoing.bubble.withoutWallpaper
        }
    }
}

public func bubbleVariableColor(variableColor: PresentationThemeVariableColor, wallpaper: TelegramWallpaper) -> UIColor {
    switch wallpaper {
        case .color(0xffffff):
            return variableColor.withoutWallpaper
        default:
            return variableColor.withWallpaper
    }
}

public final class PresentationThemeChatBubblePolls {
    public let radioButton: UIColor
    public let radioProgress: UIColor
    public let highlight: UIColor
    public let separator: UIColor
    public let bar: UIColor
    public let barIconForeground: UIColor
    public let barPositive: UIColor
    public let barNegative: UIColor
    
    public init(radioButton: UIColor, radioProgress: UIColor, highlight: UIColor, separator: UIColor, bar: UIColor, barIconForeground: UIColor, barPositive: UIColor, barNegative: UIColor) {
        self.radioButton = radioButton
        self.radioProgress = radioProgress
        self.highlight = highlight
        self.separator = separator
        self.bar = bar
        self.barIconForeground = barIconForeground
        self.barPositive = barPositive
        self.barNegative = barNegative
    }
    
    public func withUpdated(radioButton: UIColor? = nil, radioProgress: UIColor? = nil, highlight: UIColor? = nil, separator: UIColor? = nil, bar: UIColor? = nil, barIconForeground: UIColor? = nil, barPositive: UIColor? = nil, barNegative: UIColor? = nil) -> PresentationThemeChatBubblePolls {
        return PresentationThemeChatBubblePolls(radioButton: radioButton ?? self.radioButton, radioProgress: radioProgress ?? self.radioProgress, highlight: highlight ?? self.highlight, separator: separator ?? self.separator, bar: bar ?? self.bar, barIconForeground: barIconForeground ?? self.barIconForeground, barPositive: barPositive ?? self.barPositive, barNegative: barNegative ?? self.barNegative)
    }
}

public final class PresentationThemePartedColors {
    public let bubble: PresentationThemeBubbleColor
    public let primaryTextColor: UIColor
    public let secondaryTextColor: UIColor
    public let linkTextColor: UIColor
    public let linkHighlightColor: UIColor
    public let scamColor: UIColor
    public let textHighlightColor: UIColor
    public let accentTextColor: UIColor
    public let accentControlColor: UIColor
    public let accentControlDisabledColor: UIColor
    public let mediaActiveControlColor: UIColor
    public let mediaInactiveControlColor: UIColor
    public let mediaControlInnerBackgroundColor: UIColor
    public let pendingActivityColor: UIColor
    public let fileTitleColor: UIColor
    public let fileDescriptionColor: UIColor
    public let fileDurationColor: UIColor
    public let mediaPlaceholderColor: UIColor
    public let polls: PresentationThemeChatBubblePolls
    public let actionButtonsFillColor: PresentationThemeVariableColor
    public let actionButtonsStrokeColor: PresentationThemeVariableColor
    public let actionButtonsTextColor: PresentationThemeVariableColor
    public let textSelectionColor: UIColor
    public let textSelectionKnobColor: UIColor
    
    public init(bubble: PresentationThemeBubbleColor, primaryTextColor: UIColor, secondaryTextColor: UIColor, linkTextColor: UIColor, linkHighlightColor: UIColor, scamColor: UIColor, textHighlightColor: UIColor, accentTextColor: UIColor, accentControlColor: UIColor, accentControlDisabledColor: UIColor, mediaActiveControlColor: UIColor, mediaInactiveControlColor: UIColor, mediaControlInnerBackgroundColor: UIColor, pendingActivityColor: UIColor, fileTitleColor: UIColor, fileDescriptionColor: UIColor, fileDurationColor: UIColor, mediaPlaceholderColor: UIColor, polls: PresentationThemeChatBubblePolls, actionButtonsFillColor: PresentationThemeVariableColor, actionButtonsStrokeColor: PresentationThemeVariableColor, actionButtonsTextColor: PresentationThemeVariableColor, textSelectionColor: UIColor, textSelectionKnobColor: UIColor) {
        self.bubble = bubble
        self.primaryTextColor = primaryTextColor
        self.secondaryTextColor = secondaryTextColor
        self.linkTextColor = linkTextColor
        self.linkHighlightColor = linkHighlightColor
        self.scamColor = scamColor
        self.textHighlightColor = textHighlightColor
        self.accentTextColor = accentTextColor
        self.accentControlColor = accentControlColor
        self.accentControlDisabledColor = accentControlDisabledColor
        self.mediaActiveControlColor = mediaActiveControlColor
        self.mediaInactiveControlColor = mediaInactiveControlColor
        self.mediaControlInnerBackgroundColor = mediaControlInnerBackgroundColor
        self.pendingActivityColor = pendingActivityColor
        self.fileTitleColor = fileTitleColor
        self.fileDescriptionColor = fileDescriptionColor
        self.fileDurationColor = fileDurationColor
        self.mediaPlaceholderColor = mediaPlaceholderColor
        self.polls = polls
        self.actionButtonsFillColor = actionButtonsFillColor
        self.actionButtonsStrokeColor = actionButtonsStrokeColor
        self.actionButtonsTextColor = actionButtonsTextColor
        self.textSelectionColor = textSelectionColor
        self.textSelectionKnobColor = textSelectionKnobColor
    }
    
    public func withUpdated(bubble: PresentationThemeBubbleColor? = nil, primaryTextColor: UIColor? = nil, secondaryTextColor: UIColor? = nil, linkTextColor: UIColor? = nil, linkHighlightColor: UIColor? = nil, scamColor: UIColor? = nil, textHighlightColor: UIColor? = nil, accentTextColor: UIColor? = nil, accentControlColor: UIColor? = nil, accentControlDisabledColor: UIColor? = nil, mediaActiveControlColor: UIColor? = nil, mediaInactiveControlColor: UIColor? = nil, mediaControlInnerBackgroundColor: UIColor? = nil, pendingActivityColor: UIColor? = nil, fileTitleColor: UIColor? = nil, fileDescriptionColor: UIColor? = nil, fileDurationColor: UIColor? = nil, mediaPlaceholderColor: UIColor? = nil, polls: PresentationThemeChatBubblePolls? = nil, actionButtonsFillColor: PresentationThemeVariableColor? = nil, actionButtonsStrokeColor: PresentationThemeVariableColor? = nil, actionButtonsTextColor: PresentationThemeVariableColor? = nil, textSelectionColor: UIColor? = nil, textSelectionKnobColor: UIColor? = nil) -> PresentationThemePartedColors {
        return PresentationThemePartedColors(bubble: bubble ?? self.bubble, primaryTextColor: primaryTextColor ?? self.primaryTextColor, secondaryTextColor: secondaryTextColor ?? self.secondaryTextColor, linkTextColor: linkTextColor ?? self.linkTextColor, linkHighlightColor: linkHighlightColor ?? self.linkHighlightColor, scamColor: scamColor ?? self.scamColor, textHighlightColor: textHighlightColor ?? self.textHighlightColor, accentTextColor: accentTextColor ?? self.accentTextColor, accentControlColor: accentControlColor ?? self.accentControlColor, accentControlDisabledColor: accentControlDisabledColor ?? self.accentControlDisabledColor, mediaActiveControlColor: mediaActiveControlColor ?? self.mediaActiveControlColor, mediaInactiveControlColor: mediaInactiveControlColor ?? self.mediaInactiveControlColor, mediaControlInnerBackgroundColor: mediaControlInnerBackgroundColor ?? self.mediaControlInnerBackgroundColor, pendingActivityColor: pendingActivityColor ?? self.pendingActivityColor, fileTitleColor: fileTitleColor ?? self.fileTitleColor, fileDescriptionColor: fileDescriptionColor ?? self.fileDescriptionColor, fileDurationColor: fileDurationColor ?? self.fileDurationColor, mediaPlaceholderColor: mediaPlaceholderColor ?? self.mediaPlaceholderColor, polls: polls ?? self.polls, actionButtonsFillColor: actionButtonsFillColor ?? self.actionButtonsFillColor, actionButtonsStrokeColor: actionButtonsStrokeColor ?? self.actionButtonsStrokeColor, actionButtonsTextColor: actionButtonsTextColor ?? self.actionButtonsTextColor, textSelectionColor: textSelectionColor ?? self.textSelectionColor, textSelectionKnobColor: textSelectionKnobColor ?? self.textSelectionKnobColor)
    }
}

public final class PresentationThemeChatMessage {
    public let incoming: PresentationThemePartedColors
    public let outgoing: PresentationThemePartedColors
    public let freeform: PresentationThemeBubbleColor
    public let infoPrimaryTextColor: UIColor
    public let infoLinkTextColor: UIColor
    public let outgoingCheckColor: UIColor
    public let mediaDateAndStatusFillColor: UIColor
    public let mediaDateAndStatusTextColor: UIColor
    public let shareButtonFillColor: PresentationThemeVariableColor
    public let shareButtonStrokeColor: PresentationThemeVariableColor
    public let shareButtonForegroundColor: PresentationThemeVariableColor
    public let mediaOverlayControlColors: PresentationThemeFillForeground
    public let selectionControlColors: PresentationThemeFillStrokeForeground
    public let deliveryFailedColors: PresentationThemeFillForeground
    public let mediaHighlightOverlayColor: UIColor
    public let stickerPlaceholderColor: PresentationThemeVariableColor
    public let stickerPlaceholderShimmerColor: PresentationThemeVariableColor
    
    public init(incoming: PresentationThemePartedColors, outgoing: PresentationThemePartedColors, freeform: PresentationThemeBubbleColor, infoPrimaryTextColor: UIColor, infoLinkTextColor: UIColor, outgoingCheckColor: UIColor, mediaDateAndStatusFillColor: UIColor, mediaDateAndStatusTextColor: UIColor, shareButtonFillColor: PresentationThemeVariableColor, shareButtonStrokeColor: PresentationThemeVariableColor, shareButtonForegroundColor: PresentationThemeVariableColor, mediaOverlayControlColors: PresentationThemeFillForeground, selectionControlColors: PresentationThemeFillStrokeForeground, deliveryFailedColors: PresentationThemeFillForeground, mediaHighlightOverlayColor: UIColor, stickerPlaceholderColor: PresentationThemeVariableColor, stickerPlaceholderShimmerColor: PresentationThemeVariableColor) {
        self.incoming = incoming
        self.outgoing = outgoing
        self.freeform = freeform
        self.infoPrimaryTextColor = infoPrimaryTextColor
        self.infoLinkTextColor = infoLinkTextColor
        self.outgoingCheckColor = outgoingCheckColor
        self.mediaDateAndStatusFillColor = mediaDateAndStatusFillColor
        self.mediaDateAndStatusTextColor = mediaDateAndStatusTextColor
        self.shareButtonFillColor = shareButtonFillColor
        self.shareButtonStrokeColor = shareButtonStrokeColor
        self.shareButtonForegroundColor = shareButtonForegroundColor
        self.mediaOverlayControlColors = mediaOverlayControlColors
        self.selectionControlColors = selectionControlColors
        self.deliveryFailedColors = deliveryFailedColors
        self.mediaHighlightOverlayColor = mediaHighlightOverlayColor
        self.stickerPlaceholderColor = stickerPlaceholderColor
        self.stickerPlaceholderShimmerColor = stickerPlaceholderShimmerColor
    }
    
    public func withUpdated(incoming: PresentationThemePartedColors? = nil, outgoing: PresentationThemePartedColors? = nil, freeform: PresentationThemeBubbleColor? = nil, infoPrimaryTextColor: UIColor? = nil, infoLinkTextColor: UIColor? = nil, outgoingCheckColor: UIColor? = nil, mediaDateAndStatusFillColor: UIColor? = nil, mediaDateAndStatusTextColor: UIColor? = nil, shareButtonFillColor: PresentationThemeVariableColor? = nil, shareButtonStrokeColor: PresentationThemeVariableColor? = nil, shareButtonForegroundColor: PresentationThemeVariableColor? = nil, mediaOverlayControlColors: PresentationThemeFillForeground? = nil, selectionControlColors: PresentationThemeFillStrokeForeground? = nil, deliveryFailedColors: PresentationThemeFillForeground? = nil, mediaHighlightOverlayColor: UIColor? = nil, stickerPlaceholderColor: PresentationThemeVariableColor? = nil, stickerPlaceholderShimmerColor: PresentationThemeVariableColor? = nil) -> PresentationThemeChatMessage {
        return PresentationThemeChatMessage(incoming: incoming ?? self.incoming, outgoing: outgoing ?? self.outgoing, freeform: freeform ?? self.freeform, infoPrimaryTextColor: infoPrimaryTextColor ?? self.infoPrimaryTextColor, infoLinkTextColor: infoLinkTextColor ?? self.infoLinkTextColor, outgoingCheckColor: outgoingCheckColor ?? self.outgoingCheckColor, mediaDateAndStatusFillColor: mediaDateAndStatusFillColor ?? self.mediaDateAndStatusFillColor, mediaDateAndStatusTextColor: mediaDateAndStatusTextColor ?? self.mediaDateAndStatusTextColor, shareButtonFillColor: shareButtonFillColor ?? self.shareButtonFillColor, shareButtonStrokeColor: shareButtonStrokeColor ?? self.shareButtonStrokeColor, shareButtonForegroundColor: shareButtonForegroundColor ?? self.shareButtonForegroundColor, mediaOverlayControlColors: mediaOverlayControlColors ?? self.mediaOverlayControlColors, selectionControlColors: selectionControlColors ?? self.selectionControlColors, deliveryFailedColors: deliveryFailedColors ?? self.deliveryFailedColors, mediaHighlightOverlayColor: mediaHighlightOverlayColor ?? self.mediaHighlightOverlayColor, stickerPlaceholderColor: stickerPlaceholderColor ?? self.stickerPlaceholderColor, stickerPlaceholderShimmerColor: stickerPlaceholderShimmerColor ?? self.stickerPlaceholderShimmerColor)
    }
}

public final class PresentationThemeServiceMessageColorComponents {
    public let fill: UIColor
    public let primaryText: UIColor
    public let linkHighlight: UIColor
    public let scam: UIColor
    
    public let dateFillStatic: UIColor
    public let dateFillFloating: UIColor
    
    public init(fill: UIColor, primaryText: UIColor, linkHighlight: UIColor, scam: UIColor, dateFillStatic: UIColor, dateFillFloating: UIColor) {
        self.fill = fill
        self.primaryText = primaryText
        self.linkHighlight = linkHighlight
        self.scam = scam
        self.dateFillStatic = dateFillStatic
        self.dateFillFloating = dateFillFloating
    }
    
    public func withUpdated(fill: UIColor? = nil, primaryText: UIColor? = nil, linkHighlight: UIColor? = nil, scam: UIColor? = nil, dateFillStatic: UIColor? = nil, dateFillFloating: UIColor? = nil) -> PresentationThemeServiceMessageColorComponents {
        return PresentationThemeServiceMessageColorComponents(fill: fill ?? self.fill, primaryText: primaryText ?? self.primaryText, linkHighlight: linkHighlight ?? self.linkHighlight, scam: scam ?? self.scam, dateFillStatic: dateFillStatic ?? self.dateFillStatic, dateFillFloating: dateFillFloating ?? self.dateFillFloating)
    }
}

public func serviceMessageColorComponents(theme: PresentationTheme, wallpaper: TelegramWallpaper) -> PresentationThemeServiceMessageColorComponents {
    return serviceMessageColorComponents(chatTheme: theme.chat, wallpaper: wallpaper)
}

public func serviceMessageColorHasDefaultWallpaper(_ wallpaper: TelegramWallpaper) -> Bool {
    switch wallpaper {
        case .color(0xffffff):
            return true
        default:
            return false
    }
}

public func serviceMessageColorComponents(chatTheme: PresentationThemeChat, wallpaper: TelegramWallpaper) -> PresentationThemeServiceMessageColorComponents {
    return serviceMessageColorHasDefaultWallpaper(wallpaper) ? chatTheme.serviceMessage.components.withDefaultWallpaper : chatTheme.serviceMessage.components.withCustomWallpaper
}

public final class PresentationThemeServiceMessageColor {
    public let withDefaultWallpaper: PresentationThemeServiceMessageColorComponents
    public let withCustomWallpaper: PresentationThemeServiceMessageColorComponents
    
    public init(withDefaultWallpaper: PresentationThemeServiceMessageColorComponents, withCustomWallpaper: PresentationThemeServiceMessageColorComponents) {
        self.withDefaultWallpaper = withDefaultWallpaper
        self.withCustomWallpaper = withCustomWallpaper
    }
    
    public func withUpdated(withDefaultWallpaper: PresentationThemeServiceMessageColorComponents? = nil, withCustomWallpaper: PresentationThemeServiceMessageColorComponents? = nil) -> PresentationThemeServiceMessageColor {
        return PresentationThemeServiceMessageColor(withDefaultWallpaper: withDefaultWallpaper ?? self.withDefaultWallpaper, withCustomWallpaper: withCustomWallpaper ?? self.withCustomWallpaper)
    }
}

public final class PresentationThemeServiceMessage {
    public let components: PresentationThemeServiceMessageColor
    public let unreadBarFillColor: UIColor
    public let unreadBarStrokeColor: UIColor
    public let unreadBarTextColor: UIColor
    public let dateTextColor: PresentationThemeVariableColor
    
    public init(components: PresentationThemeServiceMessageColor, unreadBarFillColor: UIColor, unreadBarStrokeColor: UIColor, unreadBarTextColor: UIColor, dateTextColor: PresentationThemeVariableColor) {
        self.components = components
        self.unreadBarFillColor = unreadBarFillColor
        self.unreadBarStrokeColor = unreadBarStrokeColor
        self.unreadBarTextColor = unreadBarTextColor
        self.dateTextColor = dateTextColor
    }
    
    public func withUpdated(components: PresentationThemeServiceMessageColor? = nil, unreadBarFillColor: UIColor? = nil, unreadBarStrokeColor: UIColor? = nil, unreadBarTextColor: UIColor? = nil, dateTextColor: PresentationThemeVariableColor? = nil) -> PresentationThemeServiceMessage {
        return PresentationThemeServiceMessage(components: components ?? self.components, unreadBarFillColor: unreadBarFillColor ?? self.unreadBarFillColor, unreadBarStrokeColor: unreadBarStrokeColor ?? self.unreadBarStrokeColor, unreadBarTextColor: unreadBarTextColor ?? self.unreadBarTextColor, dateTextColor: dateTextColor ?? self.dateTextColor)
    }
}

public enum PresentationThemeKeyboardColor: Int32 {
    case light = 0
    case dark = 1
    
    public var keyboardAppearance: UIKeyboardAppearance {
        switch self {
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

public final class PresentationThemeChatInputPanelMediaRecordingControl {
    public let buttonColor: UIColor
    public let micLevelColor: UIColor
    public let activeIconColor: UIColor
    
    init(buttonColor: UIColor, micLevelColor: UIColor, activeIconColor: UIColor) {
        self.buttonColor = buttonColor
        self.micLevelColor = micLevelColor
        self.activeIconColor = activeIconColor
    }
    
    public func withUpdated(buttonColor: UIColor? = nil, micLevelColor: UIColor? = nil, activeIconColor: UIColor? = nil) -> PresentationThemeChatInputPanelMediaRecordingControl {
        return PresentationThemeChatInputPanelMediaRecordingControl(buttonColor: buttonColor ?? self.buttonColor, micLevelColor: micLevelColor ?? self.micLevelColor, activeIconColor: activeIconColor ?? self.activeIconColor)
    }
}

public final class PresentationThemeChatInputPanel {
    public let panelBackgroundColor: UIColor
    public let panelBackgroundColorNoWallpaper: UIColor
    public let panelSeparatorColor: UIColor
    public let panelControlAccentColor: UIColor
    public let panelControlColor: UIColor
    public let panelControlDisabledColor: UIColor
    public let panelControlDestructiveColor: UIColor
    public let inputBackgroundColor: UIColor
    public let inputStrokeColor: UIColor
    public let inputPlaceholderColor: UIColor
    public let inputTextColor: UIColor
    public let inputControlColor: UIColor
    public let actionControlFillColor: UIColor
    public let actionControlForegroundColor: UIColor
    public let primaryTextColor: UIColor
    public let secondaryTextColor: UIColor
    public let mediaRecordingDotColor: UIColor
    public let mediaRecordingControl: PresentationThemeChatInputPanelMediaRecordingControl
    
    public init(panelBackgroundColor: UIColor, panelBackgroundColorNoWallpaper: UIColor, panelSeparatorColor: UIColor, panelControlAccentColor: UIColor, panelControlColor: UIColor, panelControlDisabledColor: UIColor, panelControlDestructiveColor: UIColor, inputBackgroundColor: UIColor, inputStrokeColor: UIColor, inputPlaceholderColor: UIColor, inputTextColor: UIColor, inputControlColor: UIColor, actionControlFillColor: UIColor, actionControlForegroundColor: UIColor, primaryTextColor: UIColor, secondaryTextColor: UIColor, mediaRecordingDotColor: UIColor, mediaRecordingControl: PresentationThemeChatInputPanelMediaRecordingControl) {
        self.panelBackgroundColor = panelBackgroundColor
        self.panelBackgroundColorNoWallpaper = panelBackgroundColorNoWallpaper
        self.panelSeparatorColor = panelSeparatorColor
        self.panelControlAccentColor = panelControlAccentColor
        self.panelControlColor = panelControlColor
        self.panelControlDisabledColor = panelControlDisabledColor
        self.panelControlDestructiveColor = panelControlDestructiveColor
        self.inputBackgroundColor = inputBackgroundColor
        self.inputStrokeColor = inputStrokeColor
        self.inputPlaceholderColor = inputPlaceholderColor
        self.inputTextColor = inputTextColor
        self.inputControlColor = inputControlColor
        self.actionControlFillColor = actionControlFillColor
        self.actionControlForegroundColor = actionControlForegroundColor
        self.primaryTextColor = primaryTextColor
        self.secondaryTextColor = secondaryTextColor
        self.mediaRecordingDotColor = mediaRecordingDotColor
        self.mediaRecordingControl = mediaRecordingControl
    }
    
    public func withUpdated(panelBackgroundColor: UIColor? = nil, panelBackgroundColorNoWallpaper: UIColor? = nil, panelSeparatorColor: UIColor? = nil, panelControlAccentColor: UIColor? = nil, panelControlColor: UIColor? = nil, panelControlDisabledColor: UIColor? = nil, panelControlDestructiveColor: UIColor? = nil, inputBackgroundColor: UIColor? = nil, inputStrokeColor: UIColor? = nil, inputPlaceholderColor: UIColor? = nil, inputTextColor: UIColor? = nil, inputControlColor: UIColor? = nil, actionControlFillColor: UIColor? = nil, actionControlForegroundColor: UIColor? = nil, primaryTextColor: UIColor? = nil, secondaryTextColor: UIColor? = nil, mediaRecordingDotColor: UIColor? = nil, mediaRecordingControl: PresentationThemeChatInputPanelMediaRecordingControl? = nil) -> PresentationThemeChatInputPanel {
        return PresentationThemeChatInputPanel(panelBackgroundColor: panelBackgroundColor ?? self.panelBackgroundColor, panelBackgroundColorNoWallpaper: panelBackgroundColorNoWallpaper ?? self.panelBackgroundColorNoWallpaper, panelSeparatorColor: panelSeparatorColor ?? self.panelSeparatorColor, panelControlAccentColor: panelControlAccentColor ?? self.panelControlAccentColor, panelControlColor: panelControlColor ?? self.panelControlColor, panelControlDisabledColor: panelControlDisabledColor ?? self.panelControlDisabledColor, panelControlDestructiveColor: panelControlDestructiveColor ?? self.panelControlDestructiveColor, inputBackgroundColor: inputBackgroundColor ?? self.inputBackgroundColor, inputStrokeColor: inputStrokeColor ?? self.inputStrokeColor, inputPlaceholderColor: inputPlaceholderColor ?? self.inputPlaceholderColor, inputTextColor: inputTextColor ?? self.inputTextColor, inputControlColor: inputControlColor ?? self.inputControlColor, actionControlFillColor: actionControlFillColor ?? self.actionControlFillColor, actionControlForegroundColor: actionControlForegroundColor ?? self.actionControlForegroundColor, primaryTextColor: primaryTextColor ?? self.primaryTextColor, secondaryTextColor: secondaryTextColor ?? self.secondaryTextColor, mediaRecordingDotColor: mediaRecordingDotColor ?? self.mediaRecordingDotColor, mediaRecordingControl: mediaRecordingControl ?? self.mediaRecordingControl)
    }
}

public final class PresentationThemeInputMediaPanel {
    public let panelSeparatorColor: UIColor
    public let panelIconColor: UIColor
    public let panelHighlightedIconBackgroundColor: UIColor
    public let stickersBackgroundColor: UIColor
    public let stickersSectionTextColor: UIColor
    public let stickersSearchBackgroundColor: UIColor
    public let stickersSearchPlaceholderColor: UIColor
    public let stickersSearchPrimaryColor: UIColor
    public let stickersSearchControlColor: UIColor
    public let gifsBackgroundColor: UIColor
    
    public init(panelSeparatorColor: UIColor, panelIconColor: UIColor, panelHighlightedIconBackgroundColor: UIColor, stickersBackgroundColor: UIColor, stickersSectionTextColor: UIColor, stickersSearchBackgroundColor: UIColor, stickersSearchPlaceholderColor: UIColor, stickersSearchPrimaryColor: UIColor, stickersSearchControlColor: UIColor, gifsBackgroundColor: UIColor) {
        self.panelSeparatorColor = panelSeparatorColor
        self.panelIconColor = panelIconColor
        self.panelHighlightedIconBackgroundColor = panelHighlightedIconBackgroundColor
        self.stickersBackgroundColor = stickersBackgroundColor
        self.stickersSectionTextColor = stickersSectionTextColor
        self.stickersSearchBackgroundColor = stickersSearchBackgroundColor
        self.stickersSearchPlaceholderColor = stickersSearchPlaceholderColor
        self.stickersSearchPrimaryColor = stickersSearchPrimaryColor
        self.stickersSearchControlColor = stickersSearchControlColor
        self.gifsBackgroundColor = gifsBackgroundColor
    }
    
    public func withUpdated(panelSeparatorColor: UIColor? = nil, panelIconColor: UIColor? = nil, panelHighlightedIconBackgroundColor: UIColor? = nil, stickersBackgroundColor: UIColor? = nil, stickersSectionTextColor: UIColor? = nil, stickersSearchBackgroundColor: UIColor? = nil, stickersSearchPlaceholderColor: UIColor? = nil, stickersSearchPrimaryColor: UIColor? = nil, stickersSearchControlColor: UIColor? = nil, gifsBackgroundColor: UIColor? = nil) -> PresentationThemeInputMediaPanel {
        return PresentationThemeInputMediaPanel(panelSeparatorColor: panelSeparatorColor ?? self.panelSeparatorColor, panelIconColor: panelIconColor ?? self.panelIconColor, panelHighlightedIconBackgroundColor: panelHighlightedIconBackgroundColor ?? self.panelHighlightedIconBackgroundColor, stickersBackgroundColor: stickersBackgroundColor ?? self.stickersBackgroundColor, stickersSectionTextColor: stickersSectionTextColor ?? self.stickersSectionTextColor, stickersSearchBackgroundColor: stickersSearchBackgroundColor ?? self.stickersSearchBackgroundColor, stickersSearchPlaceholderColor: stickersSearchPlaceholderColor ?? self.stickersSearchPlaceholderColor, stickersSearchPrimaryColor: stickersSearchPrimaryColor ?? self.stickersSearchPrimaryColor, stickersSearchControlColor: stickersSearchControlColor ?? self.stickersSearchControlColor, gifsBackgroundColor: gifsBackgroundColor ?? self.gifsBackgroundColor)
    }
}

public final class PresentationThemeInputButtonPanel {
    public let panelSeparatorColor: UIColor
    public let panelBackgroundColor: UIColor
    public let buttonFillColor: UIColor
    public let buttonStrokeColor: UIColor
    public let buttonHighlightedFillColor: UIColor
    public let buttonHighlightedStrokeColor: UIColor
    public let buttonTextColor: UIColor
    
    public init(panelSeparatorColor: UIColor, panelBackgroundColor: UIColor, buttonFillColor: UIColor, buttonStrokeColor: UIColor, buttonHighlightedFillColor: UIColor, buttonHighlightedStrokeColor: UIColor, buttonTextColor: UIColor) {
        self.panelSeparatorColor = panelSeparatorColor
        self.panelBackgroundColor = panelBackgroundColor
        self.buttonFillColor = buttonFillColor
        self.buttonStrokeColor = buttonStrokeColor
        self.buttonHighlightedFillColor = buttonHighlightedFillColor
        self.buttonHighlightedStrokeColor = buttonHighlightedStrokeColor
        self.buttonTextColor = buttonTextColor
    }
    
    public func withUpdated(panelSeparatorColor: UIColor? = nil, panelBackgroundColor: UIColor? = nil, buttonFillColor: UIColor? = nil, buttonStrokeColor: UIColor? = nil, buttonHighlightedFillColor: UIColor? = nil, buttonHighlightedStrokeColor: UIColor? = nil, buttonTextColor: UIColor? = nil) -> PresentationThemeInputButtonPanel {
        return PresentationThemeInputButtonPanel(panelSeparatorColor: panelSeparatorColor ?? self.panelSeparatorColor, panelBackgroundColor: panelBackgroundColor ?? self.panelBackgroundColor, buttonFillColor: buttonFillColor ?? self.buttonFillColor, buttonStrokeColor: buttonStrokeColor ?? self.buttonStrokeColor, buttonHighlightedFillColor: buttonHighlightedFillColor ?? self.buttonHighlightedFillColor, buttonHighlightedStrokeColor: buttonHighlightedStrokeColor ?? self.buttonHighlightedStrokeColor, buttonTextColor: buttonTextColor ?? self.buttonTextColor)
    }
}

public final class PresentationThemeChatHistoryNavigation {
    public let fillColor: UIColor
    public let strokeColor: UIColor
    public let foregroundColor: UIColor
    public let badgeBackgroundColor: UIColor
    public let badgeStrokeColor: UIColor
    public let badgeTextColor: UIColor
    
    public init(fillColor: UIColor, strokeColor: UIColor, foregroundColor: UIColor, badgeBackgroundColor: UIColor, badgeStrokeColor: UIColor, badgeTextColor: UIColor) {
        self.fillColor = fillColor
        self.strokeColor = strokeColor
        self.foregroundColor = foregroundColor
        self.badgeBackgroundColor = badgeBackgroundColor
        self.badgeStrokeColor = badgeStrokeColor
        self.badgeTextColor = badgeTextColor
    }
    
    public func withUpdated(fillColor: UIColor? = nil, strokeColor: UIColor? = nil, foregroundColor: UIColor? = nil, badgeBackgroundColor: UIColor? = nil, badgeStrokeColor: UIColor? = nil, badgeTextColor: UIColor? = nil) -> PresentationThemeChatHistoryNavigation {
        return PresentationThemeChatHistoryNavigation(fillColor: fillColor ?? self.fillColor, strokeColor: strokeColor ?? self.strokeColor, foregroundColor: foregroundColor ?? self.foregroundColor, badgeBackgroundColor: badgeBackgroundColor ?? self.badgeBackgroundColor, badgeStrokeColor: badgeStrokeColor ?? self.badgeStrokeColor, badgeTextColor: badgeTextColor ?? self.badgeTextColor)
    }
}

public final class PresentationThemeChat {
    public let defaultWallpaper: TelegramWallpaper
    public let animateMessageColors: Bool
    public let message: PresentationThemeChatMessage
    public let serviceMessage: PresentationThemeServiceMessage
    public let inputPanel: PresentationThemeChatInputPanel
    public let inputMediaPanel: PresentationThemeInputMediaPanel
    public let inputButtonPanel: PresentationThemeInputButtonPanel
    public let historyNavigation: PresentationThemeChatHistoryNavigation
    
    public init(defaultWallpaper: TelegramWallpaper, animateMessageColors: Bool, message: PresentationThemeChatMessage, serviceMessage: PresentationThemeServiceMessage, inputPanel: PresentationThemeChatInputPanel, inputMediaPanel: PresentationThemeInputMediaPanel, inputButtonPanel: PresentationThemeInputButtonPanel, historyNavigation: PresentationThemeChatHistoryNavigation) {
        self.defaultWallpaper = defaultWallpaper
        self.animateMessageColors = animateMessageColors
        self.message = message
        self.serviceMessage = serviceMessage
        self.inputPanel = inputPanel
        self.inputMediaPanel = inputMediaPanel
        self.inputButtonPanel = inputButtonPanel
        self.historyNavigation = historyNavigation
    }
    
    public func withUpdated(defaultWallpaper: TelegramWallpaper? = nil, animateMessageColors: Bool? = nil, message: PresentationThemeChatMessage? = nil, serviceMessage: PresentationThemeServiceMessage? = nil, inputPanel: PresentationThemeChatInputPanel? = nil, inputMediaPanel: PresentationThemeInputMediaPanel? = nil, inputButtonPanel: PresentationThemeInputButtonPanel? = nil, historyNavigation: PresentationThemeChatHistoryNavigation? = nil) -> PresentationThemeChat {
        return PresentationThemeChat(defaultWallpaper: defaultWallpaper ?? self.defaultWallpaper, animateMessageColors: animateMessageColors ?? self.animateMessageColors, message: message ?? self.message, serviceMessage: serviceMessage ?? self.serviceMessage, inputPanel: inputPanel ?? self.inputPanel, inputMediaPanel: inputMediaPanel ?? self.inputMediaPanel, inputButtonPanel: inputButtonPanel ?? self.inputButtonPanel, historyNavigation: historyNavigation ?? self.historyNavigation)
    }
}

public enum PresentationThemeExpandedNotificationBackgroundType: Int32 {
    case light
    case dark
}

public final class PresentationThemeExpandedNotificationNavigationBar {
    public let backgroundColor: UIColor
    public let primaryTextColor: UIColor
    public let controlColor: UIColor
    public let separatorColor: UIColor
    
    init(backgroundColor: UIColor, primaryTextColor: UIColor, controlColor: UIColor, separatorColor: UIColor) {
        self.backgroundColor = backgroundColor
        self.primaryTextColor = primaryTextColor
        self.controlColor = controlColor
        self.separatorColor = separatorColor
    }
    
    public func withUpdated(backgroundColor: UIColor? = nil, primaryTextColor: UIColor? = nil, controlColor: UIColor? = nil, separatorColor: UIColor? = nil) -> PresentationThemeExpandedNotificationNavigationBar {
        return PresentationThemeExpandedNotificationNavigationBar(backgroundColor: backgroundColor ?? self.backgroundColor, primaryTextColor: primaryTextColor ?? self.primaryTextColor, controlColor: controlColor ?? self.controlColor, separatorColor: separatorColor ?? self.separatorColor)
    }
}

public final class PresentationThemeExpandedNotification {
    public let backgroundType: PresentationThemeExpandedNotificationBackgroundType
    public let navigationBar: PresentationThemeExpandedNotificationNavigationBar
    
    public init(backgroundType: PresentationThemeExpandedNotificationBackgroundType, navigationBar: PresentationThemeExpandedNotificationNavigationBar) {
        self.backgroundType = backgroundType
        self.navigationBar = navigationBar
    }
    
    public func withUpdated(backgroundType: PresentationThemeExpandedNotificationBackgroundType? = nil, navigationBar: PresentationThemeExpandedNotificationNavigationBar? = nil) -> PresentationThemeExpandedNotification {
        return PresentationThemeExpandedNotification(backgroundType: backgroundType ?? self.backgroundType, navigationBar: navigationBar ?? self.navigationBar)
    }
}

public final class PresentationThemeInAppNotification {
    public let fillColor: UIColor
    public let primaryTextColor: UIColor
    
    public let expandedNotification: PresentationThemeExpandedNotification
    
    public init(fillColor: UIColor, primaryTextColor: UIColor, expandedNotification: PresentationThemeExpandedNotification) {
        self.fillColor = fillColor
        self.primaryTextColor = primaryTextColor
        self.expandedNotification = expandedNotification
    }
    
    public func withUpdated(fillColor: UIColor? = nil, primaryTextColor: UIColor? = nil, expandedNotification: PresentationThemeExpandedNotification? = nil) -> PresentationThemeInAppNotification {
        return PresentationThemeInAppNotification(fillColor: fillColor ?? self.fillColor, primaryTextColor: primaryTextColor ?? self.primaryTextColor, expandedNotification: expandedNotification ?? self.expandedNotification)
    }
}

public final class PresentationThemeChart {
    public let labelsColor: UIColor
    public let helperLinesColor: UIColor
    public let strongLinesColor: UIColor
    public let barStrongLinesColor: UIColor
    public let detailsTextColor: UIColor
    public let detailsArrowColor: UIColor
    public let detailsViewColor: UIColor
    public let rangeViewFrameColor: UIColor
    public let rangeViewMarkerColor: UIColor
    
    public init(labelsColor: UIColor, helperLinesColor: UIColor, strongLinesColor: UIColor, barStrongLinesColor: UIColor, detailsTextColor: UIColor, detailsArrowColor: UIColor, detailsViewColor: UIColor, rangeViewFrameColor: UIColor, rangeViewMarkerColor: UIColor) {
        self.labelsColor = labelsColor
        self.helperLinesColor = helperLinesColor
        self.strongLinesColor = strongLinesColor
        self.barStrongLinesColor = barStrongLinesColor
        self.detailsTextColor = detailsTextColor
        self.detailsArrowColor = detailsArrowColor
        self.detailsViewColor = detailsViewColor
        self.rangeViewFrameColor = rangeViewFrameColor
        self.rangeViewMarkerColor = rangeViewMarkerColor
    }
    
    public func withUpdated(labelsColor: UIColor? = nil, helperLinesColor: UIColor? = nil, strongLinesColor: UIColor? = nil, barStrongLinesColor: UIColor? = nil, detailsTextColor: UIColor? = nil, detailsArrowColor: UIColor? = nil, detailsViewColor: UIColor? = nil, rangeViewFrameColor: UIColor? = nil, rangeViewMarkerColor: UIColor? = nil) -> PresentationThemeChart {
        return PresentationThemeChart(labelsColor: labelsColor ?? self.labelsColor, helperLinesColor: helperLinesColor ?? self.helperLinesColor, strongLinesColor: strongLinesColor ?? self.strongLinesColor, barStrongLinesColor: barStrongLinesColor ?? self.barStrongLinesColor, detailsTextColor: detailsTextColor ?? self.detailsTextColor, detailsArrowColor: detailsArrowColor ?? self.detailsArrowColor, detailsViewColor: detailsViewColor ?? self.detailsViewColor, rangeViewFrameColor: rangeViewFrameColor ?? self.rangeViewFrameColor, rangeViewMarkerColor: rangeViewMarkerColor ?? self.rangeViewMarkerColor)
    }
}

public enum PresentationThemeBuiltinName {
    case dayClassic
    case day
    case night
    case nightAccent
    
    public var reference: PresentationBuiltinThemeReference {
        switch self {
            case .dayClassic:
                return .dayClassic
            case .day:
                return .day
            case .night:
                return .night
            case .nightAccent:
                return .nightAccent
        }
    }
}

public enum PresentationThemeName: Equatable {
    case builtin(PresentationThemeBuiltinName)
    case custom(String)
    
    public static func ==(lhs: PresentationThemeName, rhs: PresentationThemeName) -> Bool {
        switch lhs {
            case let .builtin(name):
                if case .builtin(name) = rhs {
                    return true
                } else {
                    return false
                }
            case let .custom(name):
                if case .custom(name) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
    
    public var string: String {
        switch self {
            case let .builtin(name):
                switch name {
                    case .day:
                        return "Day"
                    case .dayClassic:
                        return "Classic"
                    case .night:
                        return "Night"
                    case .nightAccent:
                        return "Tinted Night"
                }
            case let .custom(name):
                return name
        }
    }
}

public extension PresentationThemeReference {
    var name: PresentationThemeName {
        switch self {
            case let .builtin(theme):
                switch theme {
                    case .day:
                        return .builtin(.day)
                    case .dayClassic:
                        return .builtin(.dayClassic)
                    case .night:
                        return .builtin(.night)
                    case .nightAccent:
                        return .builtin(.nightAccent)
                }
            case let .cloud(info):
                return .custom(info.theme.title)
            default:
                return .custom("")
        }
    }
}

public final class PresentationTheme: Equatable {
    public let name: PresentationThemeName
    public let index: Int64
    public let referenceTheme: PresentationBuiltinThemeReference
    public let overallDarkAppearance: Bool
    public let intro: PresentationThemeIntro
    public let passcode: PresentationThemePasscode
    public let rootController: PresentationThemeRootController
    public let list: PresentationThemeList
    public let chatList: PresentationThemeChatList
    public let chat: PresentationThemeChat
    public let actionSheet: PresentationThemeActionSheet
    public let contextMenu: PresentationThemeContextMenu
    public let inAppNotification: PresentationThemeInAppNotification
    public let chart: PresentationThemeChart
    public let preview: Bool
    public var forceSync: Bool = false
    
    public let resourceCache: PresentationsResourceCache = PresentationsResourceCache()
    
    public init(name: PresentationThemeName, index: Int64, referenceTheme: PresentationBuiltinThemeReference, overallDarkAppearance: Bool, intro: PresentationThemeIntro, passcode: PresentationThemePasscode, rootController: PresentationThemeRootController, list: PresentationThemeList, chatList: PresentationThemeChatList, chat: PresentationThemeChat, actionSheet: PresentationThemeActionSheet, contextMenu: PresentationThemeContextMenu, inAppNotification: PresentationThemeInAppNotification, chart: PresentationThemeChart, preview: Bool = false) {
        var overallDarkAppearance = overallDarkAppearance
        if [.night, .tinted].contains(referenceTheme.baseTheme) {
            overallDarkAppearance = true
        }
        
        self.name = name
        self.index = index
        self.referenceTheme = referenceTheme
        self.overallDarkAppearance = overallDarkAppearance
        self.intro = intro
        self.passcode = passcode
        self.rootController = rootController
        self.list = list
        self.chatList = chatList
        self.chat = chat
        self.actionSheet = actionSheet
        self.contextMenu = contextMenu
        self.inAppNotification = inAppNotification
        self.chart = chart
        self.preview = preview
    }
    
    public func image(_ key: Int32, _ generate: (PresentationTheme) -> UIImage?) -> UIImage? {
        return self.resourceCache.image(key, self, generate)
    }
    
    public func image(_ key: PresentationResourceParameterKey, _ generate: (PresentationTheme) -> UIImage?) -> UIImage? {
        return self.resourceCache.parameterImage(key, self, generate)
    }
    
    public func object(_ key: Int32, _ generate: (PresentationTheme) -> AnyObject?) -> AnyObject? {
        return self.resourceCache.object(key, self, generate)
    }
    
    public func object(_ key: PresentationResourceParameterKey, _ generate: (PresentationTheme) -> AnyObject?) -> AnyObject? {
        return self.resourceCache.parameterObject(key, self, generate)
    }
    
    public static func ==(lhs: PresentationTheme, rhs: PresentationTheme) -> Bool {
        return lhs === rhs
    }
    
    public func withUpdated(name: String?, defaultWallpaper: TelegramWallpaper?) -> PresentationTheme {
        var defaultWallpaper = defaultWallpaper
        if let wallpaper = defaultWallpaper {
            switch wallpaper {
                case .image:
                    defaultWallpaper = nil
                default:
                    break
            }
        }
        return PresentationTheme(name: name.flatMap(PresentationThemeName.custom) ?? .custom(self.name.string), index: self.index, referenceTheme: self.referenceTheme, overallDarkAppearance: self.overallDarkAppearance, intro: self.intro, passcode: self.passcode, rootController: self.rootController, list: self.list, chatList: self.chatList, chat: self.chat.withUpdated(defaultWallpaper: defaultWallpaper), actionSheet: self.actionSheet, contextMenu: self.contextMenu, inAppNotification: self.inAppNotification, chart: self.chart, preview: self.preview)
    }
    
    public func withUpdated(referenceTheme: PresentationBuiltinThemeReference) -> PresentationTheme {
        return PresentationTheme(name: self.name, index: self.index, referenceTheme: referenceTheme, overallDarkAppearance: self.overallDarkAppearance, intro: self.intro, passcode: self.passcode, rootController: self.rootController, list: self.list, chatList: self.chatList, chat: self.chat, actionSheet: self.actionSheet, contextMenu: self.contextMenu, inAppNotification: self.inAppNotification, chart: self.chart, preview: self.preview)
    }
    
    public func withUpdated(preview: Bool) -> PresentationTheme {
        return PresentationTheme(name: self.name, index: self.index, referenceTheme: self.referenceTheme, overallDarkAppearance: self.overallDarkAppearance, intro: self.intro, passcode: self.passcode, rootController: self.rootController, list: self.list, chatList: self.chatList, chat: self.chat, actionSheet: self.actionSheet, contextMenu: self.contextMenu, inAppNotification: self.inAppNotification, chart: self.chart, preview: preview)
    }
    
    public func withInvertedBlocksBackground() -> PresentationTheme {
        let list = self.list.withUpdated(blocksBackgroundColor: self.list.itemBlocksBackgroundColor, itemBlocksBackgroundColor: self.list.blocksBackgroundColor)
        
        return PresentationTheme(name: self.name, index: self.index, referenceTheme: self.referenceTheme, overallDarkAppearance: self.overallDarkAppearance, intro: self.intro, passcode: self.passcode, rootController: self.rootController, list: list, chatList: self.chatList, chat: self.chat, actionSheet: self.actionSheet, contextMenu: self.contextMenu, inAppNotification: self.inAppNotification, chart: self.chart, preview: self.preview)
    }
}
