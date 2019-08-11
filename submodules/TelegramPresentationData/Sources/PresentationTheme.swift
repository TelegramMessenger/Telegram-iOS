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
}

public final class PresentationThemeIntro {
    public let startButtonColor: UIColor
    public let dotColor: UIColor
    
    public init(startButtonColor: UIColor, dotColor: UIColor) {
        self.startButtonColor = startButtonColor
        self.dotColor = dotColor
    }
}

public final class PresentationThemePasscode {
    public let backgroundColors: PresentationThemeGradientColors
    public let buttonColor: UIColor
    
    public init(backgroundColors: PresentationThemeGradientColors, buttonColor: UIColor) {
        self.backgroundColors = backgroundColors
        self.buttonColor = buttonColor
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
    public let backgroundColor: UIColor
    public let separatorColor: UIColor
    public let badgeBackgroundColor: UIColor
    public let badgeStrokeColor: UIColor
    public let badgeTextColor: UIColor
    
    public init(buttonColor: UIColor, disabledButtonColor: UIColor, primaryTextColor: UIColor, secondaryTextColor: UIColor, controlColor: UIColor, accentTextColor: UIColor, backgroundColor: UIColor, separatorColor: UIColor, badgeBackgroundColor: UIColor, badgeStrokeColor: UIColor, badgeTextColor: UIColor) {
        self.buttonColor = buttonColor
        self.disabledButtonColor = disabledButtonColor
        self.primaryTextColor = primaryTextColor
        self.secondaryTextColor = secondaryTextColor
        self.controlColor = controlColor
        self.accentTextColor = accentTextColor
        self.backgroundColor = backgroundColor
        self.separatorColor = separatorColor
        self.badgeBackgroundColor = badgeBackgroundColor
        self.badgeStrokeColor = badgeStrokeColor
        self.badgeTextColor = badgeTextColor
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
}

public final class PresentationThemeRootController {
    public let statusBarStyle: PresentationThemeStatusBarStyle
    public let tabBar: PresentationThemeRootTabBar
    public let navigationBar: PresentationThemeRootNavigationBar
    public let navigationSearchBar: PresentationThemeNavigationSearchBar
    
    public init(statusBarStyle: PresentationThemeStatusBarStyle, tabBar: PresentationThemeRootTabBar, navigationBar: PresentationThemeRootNavigationBar, navigationSearchBar: PresentationThemeNavigationSearchBar) {
        self.statusBarStyle = statusBarStyle
        self.tabBar = tabBar
        self.navigationBar = navigationBar
        self.navigationSearchBar = navigationSearchBar
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
}

public final class PresentationThemeFillForeground {
    public let fillColor: UIColor
    public let foregroundColor: UIColor
    
    init(fillColor: UIColor, foregroundColor: UIColor) {
        self.fillColor = fillColor
        self.foregroundColor = foregroundColor
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
}

public final class PresentationThemeList {
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
    public let mediaPlaceholderColor: UIColor
    public let scrollIndicatorColor: UIColor
    public let pageIndicatorInactiveColor: UIColor
    public let inputClearButtonColor: UIColor
    
    public init(blocksBackgroundColor: UIColor, plainBackgroundColor: UIColor, itemPrimaryTextColor: UIColor, itemSecondaryTextColor: UIColor, itemDisabledTextColor: UIColor, itemAccentColor: UIColor, itemHighlightedColor: UIColor, itemDestructiveColor: UIColor, itemPlaceholderTextColor: UIColor, itemBlocksBackgroundColor: UIColor, itemHighlightedBackgroundColor: UIColor, itemBlocksSeparatorColor: UIColor, itemPlainSeparatorColor: UIColor, disclosureArrowColor: UIColor, sectionHeaderTextColor: UIColor, freeTextColor: UIColor, freeTextErrorColor: UIColor, freeTextSuccessColor: UIColor, freeMonoIconColor: UIColor, itemSwitchColors: PresentationThemeSwitch, itemDisclosureActions: PresentationThemeItemDisclosureActions, itemCheckColors: PresentationThemeFillStrokeForeground, controlSecondaryColor: UIColor, freeInputField: PresentationInputFieldTheme, mediaPlaceholderColor: UIColor, scrollIndicatorColor: UIColor, pageIndicatorInactiveColor: UIColor, inputClearButtonColor: UIColor) {
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
        self.mediaPlaceholderColor = mediaPlaceholderColor
        self.scrollIndicatorColor = scrollIndicatorColor
        self.pageIndicatorInactiveColor = pageIndicatorInactiveColor
        self.inputClearButtonColor = inputClearButtonColor
    }
}

public final class PresentationThemeArchiveAvatarColors {
    public let backgroundColors: PresentationThemeGradientColors
    public let foregroundColor: UIColor
    
    public init(backgroundColors: PresentationThemeGradientColors, foregroundColor: UIColor) {
        self.backgroundColors = backgroundColors
        self.foregroundColor = foregroundColor
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
    public let pinnedBadgeColor: UIColor
    public let pinnedSearchBarColor: UIColor
    public let regularSearchBarColor: UIColor
    public let sectionHeaderFillColor: UIColor
    public let sectionHeaderTextColor: UIColor
    public let searchBarKeyboardColor: PresentationThemeKeyboardColor
    public let verifiedIconFillColor: UIColor
    public let verifiedIconForegroundColor: UIColor
    public let secretIconColor: UIColor
    public let pinnedArchiveAvatarColor: PresentationThemeArchiveAvatarColors
    public let unpinnedArchiveAvatarColor: PresentationThemeArchiveAvatarColors
    public let onlineDotColor: UIColor
    
    init(backgroundColor: UIColor, itemSeparatorColor: UIColor, itemBackgroundColor: UIColor, pinnedItemBackgroundColor: UIColor, itemHighlightedBackgroundColor: UIColor, itemSelectedBackgroundColor: UIColor, titleColor: UIColor, secretTitleColor: UIColor, dateTextColor: UIColor, authorNameColor: UIColor, messageTextColor: UIColor, messageDraftTextColor: UIColor, checkmarkColor: UIColor, pendingIndicatorColor: UIColor, failedFillColor: UIColor, failedForegroundColor: UIColor, muteIconColor: UIColor, unreadBadgeActiveBackgroundColor: UIColor, unreadBadgeActiveTextColor: UIColor, unreadBadgeInactiveBackgroundColor: UIColor, unreadBadgeInactiveTextColor: UIColor, pinnedBadgeColor: UIColor, pinnedSearchBarColor: UIColor, regularSearchBarColor: UIColor, sectionHeaderFillColor: UIColor, sectionHeaderTextColor: UIColor, searchBarKeyboardColor: PresentationThemeKeyboardColor, verifiedIconFillColor: UIColor, verifiedIconForegroundColor: UIColor, secretIconColor: UIColor, pinnedArchiveAvatarColor: PresentationThemeArchiveAvatarColors, unpinnedArchiveAvatarColor: PresentationThemeArchiveAvatarColors, onlineDotColor: UIColor) {
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
        self.pinnedBadgeColor = pinnedBadgeColor
        self.pinnedSearchBarColor = pinnedSearchBarColor
        self.regularSearchBarColor = regularSearchBarColor
        self.sectionHeaderFillColor = sectionHeaderFillColor
        self.sectionHeaderTextColor = sectionHeaderTextColor
        self.searchBarKeyboardColor = searchBarKeyboardColor
        self.verifiedIconFillColor = verifiedIconFillColor
        self.verifiedIconForegroundColor = verifiedIconForegroundColor
        self.secretIconColor = secretIconColor
        self.pinnedArchiveAvatarColor = pinnedArchiveAvatarColor
        self.unpinnedArchiveAvatarColor = unpinnedArchiveAvatarColor
        self.onlineDotColor = onlineDotColor
    }
}

public final class PresentationThemeBubbleColorComponents {
    public let fill: UIColor
    public let highlightedFill: UIColor
    public let stroke: UIColor
    
    public init(fill: UIColor, highlightedFill: UIColor, stroke: UIColor) {
        self.fill = fill
        self.highlightedFill = highlightedFill
        self.stroke = stroke
    }
}

public final class PresentationThemeBubbleColor {
    public let withWallpaper: PresentationThemeBubbleColorComponents
    public let withoutWallpaper: PresentationThemeBubbleColorComponents
    
    public init(withWallpaper: PresentationThemeBubbleColorComponents, withoutWallpaper: PresentationThemeBubbleColorComponents) {
        self.withWallpaper = withWallpaper
        self.withoutWallpaper = withoutWallpaper
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
    
    public init(radioButton: UIColor, radioProgress: UIColor, highlight: UIColor, separator: UIColor, bar: UIColor) {
        self.radioButton = radioButton
        self.radioProgress = radioProgress
        self.highlight = highlight
        self.separator = separator
        self.bar = bar
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
    public let mediaActiveControlColor: UIColor
    public let mediaInactiveControlColor: UIColor
    public let pendingActivityColor: UIColor
    public let fileTitleColor: UIColor
    public let fileDescriptionColor: UIColor
    public let fileDurationColor: UIColor
    public let mediaPlaceholderColor: UIColor
    public let polls: PresentationThemeChatBubblePolls
    public let actionButtonsFillColor: PresentationThemeVariableColor
    public let actionButtonsStrokeColor: PresentationThemeVariableColor
    public let actionButtonsTextColor: PresentationThemeVariableColor
    
    public init(bubble: PresentationThemeBubbleColor, primaryTextColor: UIColor, secondaryTextColor: UIColor, linkTextColor: UIColor, linkHighlightColor: UIColor, scamColor: UIColor, textHighlightColor: UIColor, accentTextColor: UIColor, accentControlColor: UIColor, mediaActiveControlColor: UIColor, mediaInactiveControlColor: UIColor, pendingActivityColor: UIColor, fileTitleColor: UIColor, fileDescriptionColor: UIColor, fileDurationColor: UIColor, mediaPlaceholderColor: UIColor, polls: PresentationThemeChatBubblePolls, actionButtonsFillColor: PresentationThemeVariableColor, actionButtonsStrokeColor: PresentationThemeVariableColor, actionButtonsTextColor: PresentationThemeVariableColor) {
        self.bubble = bubble
        self.primaryTextColor = primaryTextColor
        self.secondaryTextColor = secondaryTextColor
        self.linkTextColor = linkTextColor
        self.linkHighlightColor = linkHighlightColor
        self.scamColor = scamColor
        self.textHighlightColor = textHighlightColor
        self.accentTextColor = accentTextColor
        self.accentControlColor = accentControlColor
        self.mediaActiveControlColor = mediaActiveControlColor
        self.mediaInactiveControlColor = mediaInactiveControlColor
        self.pendingActivityColor = pendingActivityColor
        self.fileTitleColor = fileTitleColor
        self.fileDescriptionColor = fileDescriptionColor
        self.fileDurationColor = fileDurationColor
        self.mediaPlaceholderColor = mediaPlaceholderColor
        self.polls = polls
        self.actionButtonsFillColor = actionButtonsFillColor
        self.actionButtonsStrokeColor = actionButtonsStrokeColor
        self.actionButtonsTextColor = actionButtonsTextColor
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
    
    public init(incoming: PresentationThemePartedColors, outgoing: PresentationThemePartedColors, freeform: PresentationThemeBubbleColor, infoPrimaryTextColor: UIColor, infoLinkTextColor: UIColor, outgoingCheckColor: UIColor, mediaDateAndStatusFillColor: UIColor, mediaDateAndStatusTextColor: UIColor, shareButtonFillColor: PresentationThemeVariableColor, shareButtonStrokeColor: PresentationThemeVariableColor, shareButtonForegroundColor: PresentationThemeVariableColor, mediaOverlayControlColors: PresentationThemeFillForeground, selectionControlColors: PresentationThemeFillStrokeForeground, deliveryFailedColors: PresentationThemeFillForeground, mediaHighlightOverlayColor: UIColor) {
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
}

public func serviceMessageColorComponents(theme: PresentationTheme, wallpaper: TelegramWallpaper) -> PresentationThemeServiceMessageColorComponents {
    return serviceMessageColorComponents(chatTheme: theme.chat, wallpaper: wallpaper)
}

public func serviceMessageColorComponents(chatTheme: PresentationThemeChat, wallpaper: TelegramWallpaper) -> PresentationThemeServiceMessageColorComponents {
    switch wallpaper {
        case .color(0xffffff):
            return chatTheme.serviceMessage.components.withDefaultWallpaper
        default:
            return chatTheme.serviceMessage.components.withCustomWallpaper
    }
}

public final class PresentationThemeServiceMessageColor {
    public let withDefaultWallpaper: PresentationThemeServiceMessageColorComponents
    public let withCustomWallpaper: PresentationThemeServiceMessageColorComponents
    
    public init(withDefaultWallpaper: PresentationThemeServiceMessageColorComponents, withCustomWallpaper: PresentationThemeServiceMessageColorComponents) {
        self.withDefaultWallpaper = withDefaultWallpaper
        self.withCustomWallpaper = withCustomWallpaper
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
}

public enum PresentationThemeKeyboardColor: Int32 {
    case light = 0
    case dark = 1
    
    public var keyboardAppearance: UIKeyboardAppearance {
        switch self {
        case .light:
            return .default
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
}

public final class PresentationThemeChatInputPanel {
    public let panelBackgroundColor: UIColor
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
    public let keyboardColor: PresentationThemeKeyboardColor
    public let mediaRecordingControl: PresentationThemeChatInputPanelMediaRecordingControl
    
    public init(panelBackgroundColor: UIColor, panelSeparatorColor: UIColor, panelControlAccentColor: UIColor, panelControlColor: UIColor, panelControlDisabledColor: UIColor, panelControlDestructiveColor: UIColor, inputBackgroundColor: UIColor, inputStrokeColor: UIColor, inputPlaceholderColor: UIColor, inputTextColor: UIColor, inputControlColor: UIColor, actionControlFillColor: UIColor, actionControlForegroundColor: UIColor, primaryTextColor: UIColor, secondaryTextColor: UIColor, mediaRecordingDotColor: UIColor, keyboardColor: PresentationThemeKeyboardColor, mediaRecordingControl: PresentationThemeChatInputPanelMediaRecordingControl) {
        self.panelBackgroundColor = panelBackgroundColor
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
        self.keyboardColor = keyboardColor
        self.mediaRecordingControl = mediaRecordingControl
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
}

public final class PresentationThemeChat {
    public let defaultWallpaper: TelegramWallpaper
    public let message: PresentationThemeChatMessage
    public let serviceMessage: PresentationThemeServiceMessage
    public let inputPanel: PresentationThemeChatInputPanel
    public let inputMediaPanel: PresentationThemeInputMediaPanel
    public let inputButtonPanel: PresentationThemeInputButtonPanel
    public let historyNavigation: PresentationThemeChatHistoryNavigation
    
    public init(defaultWallpaper: TelegramWallpaper, message: PresentationThemeChatMessage, serviceMessage: PresentationThemeServiceMessage, inputPanel: PresentationThemeChatInputPanel, inputMediaPanel: PresentationThemeInputMediaPanel, inputButtonPanel: PresentationThemeInputButtonPanel, historyNavigation: PresentationThemeChatHistoryNavigation) {
        self.defaultWallpaper = defaultWallpaper
        self.message = message
        self.serviceMessage = serviceMessage
        self.inputPanel = inputPanel
        self.inputMediaPanel = inputMediaPanel
        self.inputButtonPanel = inputButtonPanel
        self.historyNavigation = historyNavigation
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
}

public final class PresentationThemeExpandedNotification {
    public let backgroundType: PresentationThemeExpandedNotificationBackgroundType
    public let navigationBar: PresentationThemeExpandedNotificationNavigationBar
    
    public init(backgroundType: PresentationThemeExpandedNotificationBackgroundType, navigationBar: PresentationThemeExpandedNotificationNavigationBar) {
        self.backgroundType = backgroundType
        self.navigationBar = navigationBar
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
                        return "Night"
                }
            case let .custom(name):
                return name
        }
    }
}

public final class PresentationTheme: Equatable {
    public let name: PresentationThemeName
    public let author: String?
    public let overallDarkAppearance: Bool
    public let intro: PresentationThemeIntro
    public let passcode: PresentationThemePasscode
    public let rootController: PresentationThemeRootController
    public let list: PresentationThemeList
    public let chatList: PresentationThemeChatList
    public let chat: PresentationThemeChat
    public let actionSheet: PresentationThemeActionSheet
    public let inAppNotification: PresentationThemeInAppNotification
    public let preview: Bool
    
    public let resourceCache: PresentationsResourceCache = PresentationsResourceCache()
    
    public init(name: PresentationThemeName, author: String?, overallDarkAppearance: Bool, intro: PresentationThemeIntro, passcode: PresentationThemePasscode, rootController: PresentationThemeRootController, list: PresentationThemeList, chatList: PresentationThemeChatList, chat: PresentationThemeChat, actionSheet: PresentationThemeActionSheet, inAppNotification: PresentationThemeInAppNotification, preview: Bool = false) {
        self.name = name
        self.author = author
        self.overallDarkAppearance = overallDarkAppearance
        self.intro = intro
        self.passcode = passcode
        self.rootController = rootController
        self.list = list
        self.chatList = chatList
        self.chat = chat
        self.actionSheet = actionSheet
        self.inAppNotification = inAppNotification
        self.preview = preview
    }
    
    public func image(_ key: Int32, _ generate: (PresentationTheme) -> UIImage?) -> UIImage? {
        return self.resourceCache.image(key, self, generate)
    }
    
    public func object(_ key: Int32, _ generate: (PresentationTheme) -> AnyObject?) -> AnyObject? {
        return self.resourceCache.object(key, self, generate)
    }
    
    public static func ==(lhs: PresentationTheme, rhs: PresentationTheme) -> Bool {
        return lhs === rhs
    }
}
