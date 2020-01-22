import Foundation
import UIKit
import TelegramCore
import SyncCore
import TelegramUIPreferences

private let defaultDarkTintedAccentColor = UIColor(rgb: 0x2ea6ff)
public let defaultDarkTintedPresentationTheme = makeDefaultDarkTintedPresentationTheme(preview: false)

public func customizeDefaultDarkTintedPresentationTheme(theme: PresentationTheme, editing: Bool, title: String?, accentColor: UIColor?, backgroundColors: (UIColor, UIColor?)?, bubbleColors: (UIColor, UIColor?)?, wallpaper forcedWallpaper: TelegramWallpaper? = nil) -> PresentationTheme {
    if (theme.referenceTheme != .nightAccent) {
        return theme
    }
    
    var accentColor = accentColor
    if accentColor == PresentationThemeBaseColor.blue.color {
        accentColor = defaultDarkTintedAccentColor
    }
    
    var intro = theme.intro
    var passcode = theme.passcode
    var rootController = theme.rootController
    var list = theme.list
    var chatList = theme.chatList
    var chat = theme.chat
    var actionSheet = theme.actionSheet
    var contextMenu = theme.contextMenu
    var inAppNotification = theme.inAppNotification
    
    
    var mainBackgroundColor: UIColor?
    var mainSelectionColor: UIColor?
    var additionalBackgroundColor: UIColor?
    var mainSeparatorColor: UIColor?
    var mainForegroundColor: UIColor?
    var mainSecondaryColor: UIColor?
    var mainSecondaryTextColor: UIColor?
    var mainFreeTextColor: UIColor?
    var secondaryBadgeTextColor: UIColor
    var mainInputColor: UIColor?
    var inputBackgroundColor: UIColor?
    var buttonStrokeColor: UIColor?
    
    var suggestedWallpaper: TelegramWallpaper?
    
    var bubbleColors = bubbleColors
    if bubbleColors == nil, editing {
        if let accentColor = accentColor {
            let color = accentColor.withMultiplied(hue: 1.024, saturation: 0.573, brightness: 0.18)
            suggestedWallpaper = .color(color.argb)
        }
        
        let accentColor = accentColor ?? defaultDarkTintedAccentColor
        let bottomColor = accentColor.withMultiplied(hue: 1.019, saturation: 0.731, brightness: 0.59)
        let topColor = bottomColor.withMultiplied(hue: 0.966, saturation: 0.61, brightness: 0.98)
        bubbleColors = (topColor, bottomColor)
    }
    
    if let initialAccentColor = accentColor {
        let hsb = initialAccentColor.hsb
        accentColor = UIColor(hue: hsb.0, saturation: hsb.1, brightness: max(hsb.2, 0.18), alpha: 1.0)
        
        if let lightness = accentColor?.lightness, lightness > 0.7 {
            secondaryBadgeTextColor = UIColor(rgb: 0x000000)
        } else {
            secondaryBadgeTextColor = UIColor(rgb: 0xffffff)
        }
        
        mainBackgroundColor = accentColor?.withMultiplied(hue: 1.024, saturation: 0.585, brightness: 0.25)
        mainSelectionColor = accentColor?.withMultiplied(hue: 1.03, saturation: 0.585, brightness: 0.12)
        additionalBackgroundColor = accentColor?.withMultiplied(hue: 1.024, saturation: 0.573, brightness: 0.18)
        mainSeparatorColor = accentColor?.withMultiplied(hue: 1.033, saturation: 0.426, brightness: 0.34)
        mainForegroundColor = accentColor?.withMultiplied(hue: 0.99, saturation: 0.256, brightness: 0.62)
        mainSecondaryColor = accentColor?.withMultiplied(hue: 1.019, saturation: 0.109, brightness: 0.59)
        mainSecondaryTextColor = accentColor?.withMultiplied(hue: 0.956, saturation: 0.17, brightness: 1.0)
        mainFreeTextColor = accentColor?.withMultiplied(hue: 1.019, saturation: 0.097, brightness: 0.56)
        mainInputColor = accentColor?.withMultiplied(hue: 1.029, saturation: 0.609, brightness: 0.19)
        inputBackgroundColor = accentColor?.withMultiplied(hue: 1.02, saturation: 0.609, brightness: 0.15)
        buttonStrokeColor = accentColor?.withMultiplied(hue: 1.014, saturation: 0.56, brightness: 0.64).withAlphaComponent(0.15)
        
        intro = intro.withUpdated(
            accentTextColor: accentColor,
            disabledTextColor: accentColor?.withMultiplied(hue: 1.033, saturation: 0.219, brightness: 0.44),
            startButtonColor: accentColor,
            dotColor: mainSecondaryColor
        )
        passcode = passcode.withUpdated(backgroundColors: passcode.backgroundColors.withUpdated(topColor: accentColor?.withMultiplied(hue: 1.049, saturation: 0.573, brightness: 0.47), bottomColor: additionalBackgroundColor), buttonColor: mainBackgroundColor)
        rootController = rootController.withUpdated(
            tabBar: rootController.tabBar.withUpdated(
                backgroundColor: mainBackgroundColor,
                separatorColor: mainSeparatorColor,
                iconColor: mainForegroundColor,
                selectedIconColor: accentColor,
                textColor: mainForegroundColor,
                selectedTextColor: accentColor
            ),
            navigationBar: rootController.navigationBar.withUpdated(
                buttonColor: accentColor,
                disabledButtonColor: accentColor?.withMultiplied(hue: 1.033, saturation: 0.219, brightness: 0.44),
                secondaryTextColor: mainSecondaryColor,
                controlColor: mainSecondaryColor,
                accentTextColor: accentColor,
                backgroundColor: mainBackgroundColor,
                separatorColor: mainSeparatorColor,
                segmentedBackgroundColor: mainInputColor,
                segmentedForegroundColor: mainBackgroundColor,
                segmentedDividerColor: mainSecondaryTextColor?.withAlphaComponent(0.5)
            ),
            navigationSearchBar: rootController.navigationSearchBar.withUpdated(
                backgroundColor: mainBackgroundColor,
                accentColor: accentColor,
                inputFillColor: mainInputColor,
                inputPlaceholderTextColor: mainSecondaryColor,
                inputIconColor: mainSecondaryColor,
                inputClearButtonColor: mainSecondaryColor,
                separatorColor: additionalBackgroundColor
            )
        )
        list = list.withUpdated(
            blocksBackgroundColor: additionalBackgroundColor,
            plainBackgroundColor: additionalBackgroundColor,
            itemSecondaryTextColor: mainSecondaryTextColor?.withAlphaComponent(0.5),
            itemDisabledTextColor: mainSecondaryTextColor?.withAlphaComponent(0.5),
            itemAccentColor: accentColor,
            itemPlaceholderTextColor: mainSecondaryTextColor?.withAlphaComponent(0.5),
            itemBlocksBackgroundColor: mainBackgroundColor,
            itemHighlightedBackgroundColor: mainSelectionColor,
            itemBlocksSeparatorColor: mainSeparatorColor,
            itemPlainSeparatorColor: mainSeparatorColor,
            disclosureArrowColor: mainSecondaryTextColor?.withAlphaComponent(0.5),
            sectionHeaderTextColor: mainFreeTextColor,
            freeTextColor: mainFreeTextColor,
            freeMonoIconColor: mainFreeTextColor,
            itemSwitchColors: list.itemSwitchColors.withUpdated(
                frameColor: mainSecondaryTextColor?.withAlphaComponent(0.5),
                contentColor: accentColor
            ),
            itemDisclosureActions: list.itemDisclosureActions.withUpdated(
                neutral1: list.itemDisclosureActions.neutral1.withUpdated(fillColor: accentColor),
                accent: list.itemDisclosureActions.accent.withUpdated(fillColor: accentColor),
                inactive: list.itemDisclosureActions.inactive.withUpdated(fillColor: accentColor?.withMultiplied(hue: 1.029, saturation: 0.609, brightness: 0.3))
            ),
            itemCheckColors: list.itemCheckColors.withUpdated(
                fillColor: accentColor,
                strokeColor: mainSecondaryTextColor?.withAlphaComponent(0.5),
                foregroundColor: secondaryBadgeTextColor
            ),
            controlSecondaryColor: mainSecondaryTextColor?.withAlphaComponent(0.5),
            freeInputField: list.freeInputField.withUpdated(
                backgroundColor: mainSecondaryTextColor?.withAlphaComponent(0.5),
                strokeColor: mainSecondaryTextColor?.withAlphaComponent(0.5)
            ),
            freePlainInputField: list.freePlainInputField.withUpdated(
                backgroundColor: mainSecondaryTextColor?.withAlphaComponent(0.5),
                strokeColor: mainSecondaryTextColor?.withAlphaComponent(0.5)
            ),
            mediaPlaceholderColor: UIColor(rgb: 0xffffff).mixedWith(mainBackgroundColor ?? list.itemBlocksBackgroundColor, alpha: 0.9),
            pageIndicatorInactiveColor: mainSecondaryTextColor?.withAlphaComponent(0.4),
            inputClearButtonColor: mainSecondaryColor,
            itemBarChart: list.itemBarChart.withUpdated(
                color1: accentColor,
                color2: mainSecondaryTextColor?.withAlphaComponent(0.5),
                color3: accentColor?.withMultiplied(hue: 1.038, saturation: 0.329, brightness: 0.33)
            )
        )
        chatList = chatList.withUpdated(
            backgroundColor: additionalBackgroundColor,
            itemSeparatorColor: mainSeparatorColor,
            itemBackgroundColor: additionalBackgroundColor,
            pinnedItemBackgroundColor: mainBackgroundColor,
            itemHighlightedBackgroundColor: mainSelectionColor,
            itemSelectedBackgroundColor: mainSelectionColor,
            dateTextColor: mainSecondaryTextColor?.withAlphaComponent(0.5),
            messageTextColor: mainSecondaryTextColor?.withAlphaComponent(0.5),
            checkmarkColor: accentColor,
            pendingIndicatorColor: mainSecondaryTextColor?.withAlphaComponent(0.4),
            muteIconColor: mainSecondaryTextColor?.withAlphaComponent(0.4),
            unreadBadgeActiveBackgroundColor: accentColor,
            unreadBadgeActiveTextColor: secondaryBadgeTextColor,
            unreadBadgeInactiveBackgroundColor: mainSecondaryTextColor?.withAlphaComponent(0.4),
            unreadBadgeInactiveTextColor: additionalBackgroundColor,
            pinnedBadgeColor: mainSecondaryTextColor?.withAlphaComponent(0.5),
            pinnedSearchBarColor: mainInputColor,
            regularSearchBarColor: accentColor?.withMultiplied(hue: 1.029, saturation: 0.609, brightness: 0.12),
            sectionHeaderFillColor: mainBackgroundColor,
            sectionHeaderTextColor: mainSecondaryTextColor?.withAlphaComponent(0.5),
            verifiedIconFillColor: accentColor,
            unpinnedArchiveAvatarColor: chatList.unpinnedArchiveAvatarColor.withUpdated(
                backgroundColors: chatList.unpinnedArchiveAvatarColor.backgroundColors.withUpdated(
                    topColor: accentColor?.withMultiplied(hue: 0.985, saturation: 0.268, brightness: 0.47),
                    bottomColor: accentColor?.withMultiplied(hue: 0.98, saturation: 0.268, brightness: 0.39)
                ),
                foregroundColor: additionalBackgroundColor
            )
        )
        actionSheet = actionSheet.withUpdated(
            opaqueItemBackgroundColor: mainBackgroundColor,
            itemBackgroundColor: mainBackgroundColor?.withAlphaComponent(0.8),
            opaqueItemHighlightedBackgroundColor: mainSelectionColor,
            itemHighlightedBackgroundColor: mainSelectionColor?.withAlphaComponent(0.2),
            opaqueItemSeparatorColor: additionalBackgroundColor,
            standardActionTextColor: accentColor,
            controlAccentColor: accentColor,
            inputBackgroundColor: mainInputColor,
            inputHollowBackgroundColor: mainInputColor,
            inputBorderColor: mainInputColor,
            inputPlaceholderColor: mainSecondaryColor,
            inputClearButtonColor: mainSecondaryColor,
            checkContentColor: secondaryBadgeTextColor
        )
        contextMenu = contextMenu.withUpdated(backgroundColor: mainBackgroundColor?.withAlphaComponent(0.78))
        inAppNotification = inAppNotification.withUpdated(
            fillColor: mainBackgroundColor,
            expandedNotification: inAppNotification.expandedNotification.withUpdated(navigationBar: inAppNotification.expandedNotification.navigationBar.withUpdated(
                backgroundColor: mainBackgroundColor,
                controlColor: accentColor,
                separatorColor: mainSeparatorColor)
            )
        )
    }
    
    var defaultWallpaper: TelegramWallpaper?
    if let forcedWallpaper = forcedWallpaper {
        defaultWallpaper = forcedWallpaper
    } else if let backgroundColors = backgroundColors {
        if let secondColor = backgroundColors.1 {
            defaultWallpaper = .gradient(backgroundColors.0.argb, secondColor.argb, WallpaperSettings())
        } else {
            defaultWallpaper = .color(backgroundColors.0.argb)
        }
    } else if let forcedWallpaper = suggestedWallpaper {
        defaultWallpaper = forcedWallpaper
    }
    
    var outgoingBubbleFillColor: UIColor?
    var outgoingBubbleFillGradientColor: UIColor?
    var outgoingBubbleHighlightedFillColor: UIColor?
    var outgoingPrimaryTextColor: UIColor?
    var outgoingSecondaryTextColor: UIColor?
    var outgoingLinkTextColor: UIColor?
    var outgoingScamColor: UIColor?
    var outgoingCheckColor: UIColor?
    var highlightedIncomingBubbleColor: UIColor?
    var highlightedOutgoingBubbleColor: UIColor?
    
    if let bubbleColors = bubbleColors {
        outgoingBubbleFillColor = bubbleColors.0
        outgoingBubbleFillGradientColor = bubbleColors.1 ?? bubbleColors.0
     
        let lightnessColor = bubbleColors.0.mixedWith(bubbleColors.1 ?? bubbleColors.0, alpha: 0.5)
        if lightnessColor.lightness > 0.7 {
            outgoingPrimaryTextColor = UIColor(rgb: 0x000000)
            outgoingSecondaryTextColor = UIColor(rgb: 0x000000, alpha: 0.5)
            outgoingLinkTextColor = UIColor(rgb: 0x000000)
            outgoingScamColor = UIColor(rgb: 0x000000)
            outgoingCheckColor = UIColor(rgb: 0x000000, alpha: 0.5)
        } else {
            outgoingPrimaryTextColor = UIColor(rgb: 0xffffff)
            outgoingSecondaryTextColor = UIColor(rgb: 0xffffff, alpha: 0.5)
            outgoingLinkTextColor = UIColor(rgb: 0xffffff)
            outgoingScamColor = UIColor(rgb: 0xffffff)
            outgoingCheckColor = UIColor(rgb: 0xffffff, alpha: 0.5)
        }
        
        highlightedIncomingBubbleColor = accentColor?.withMultiplied(hue: 1.03, saturation: 0.463, brightness: 0.29)
        highlightedOutgoingBubbleColor = outgoingBubbleFillColor?.withMultiplied(hue: 1.019, saturation: 0.609, brightness: 0.63)
    }
        
    chat = chat.withUpdated(
        defaultWallpaper: defaultWallpaper,
        message: chat.message.withUpdated(
            incoming: chat.message.incoming.withUpdated(
                bubble: chat.message.incoming.bubble.withUpdated(
                    withWallpaper: chat.message.outgoing.bubble.withWallpaper.withUpdated(
                        fill: mainBackgroundColor,
                        gradientFill: mainBackgroundColor,
                        highlightedFill: highlightedIncomingBubbleColor,
                        stroke: mainBackgroundColor
                    ),
                    withoutWallpaper: chat.message.outgoing.bubble.withoutWallpaper.withUpdated(
                        fill: mainBackgroundColor,
                        gradientFill: mainBackgroundColor,
                        highlightedFill: highlightedIncomingBubbleColor,
                        stroke: mainBackgroundColor
                    )
                ),
                secondaryTextColor: mainSecondaryTextColor?.withAlphaComponent(0.5),
                linkTextColor: accentColor,
                linkHighlightColor: accentColor?.withAlphaComponent(0.5),
                accentTextColor: accentColor,
                accentControlColor: accentColor,
                mediaActiveControlColor: accentColor,
                mediaInactiveControlColor: accentColor?.withAlphaComponent(0.5),
                mediaControlInnerBackgroundColor: mainBackgroundColor,
                pendingActivityColor: mainSecondaryTextColor?.withAlphaComponent(0.5),
                fileTitleColor: accentColor,
                fileDescriptionColor: mainSecondaryTextColor?.withAlphaComponent(0.5),
                fileDurationColor: mainSecondaryTextColor?.withAlphaComponent(0.5),
                mediaPlaceholderColor: accentColor?.withMultiplied(hue: 1.019, saturation: 0.585, brightness: 0.23),
                polls: chat.message.incoming.polls.withUpdated(
                    radioButton: accentColor?.withMultiplied(hue: 0.995, saturation: 0.317, brightness: 0.51),
                    radioProgress: accentColor,
                    highlight: accentColor?.withAlphaComponent(0.12),
                    separator: mainSeparatorColor,
                    bar: accentColor
                ),
                actionButtonsFillColor: chat.message.incoming.actionButtonsFillColor.withUpdated(
                    withWallpaper: additionalBackgroundColor?.withAlphaComponent(0.5),
                    withoutWallpaper: additionalBackgroundColor?.withAlphaComponent(0.5)
                ),
                actionButtonsStrokeColor: buttonStrokeColor.flatMap { PresentationThemeVariableColor(color: $0) },
                textSelectionColor: accentColor?.withAlphaComponent(0.2),
                textSelectionKnobColor: accentColor
            ),
            outgoing: chat.message.outgoing.withUpdated(
                bubble: chat.message.outgoing.bubble.withUpdated(
                    withWallpaper: chat.message.outgoing.bubble.withWallpaper.withUpdated(
                        fill: outgoingBubbleFillColor,
                        gradientFill: outgoingBubbleFillGradientColor,
                        highlightedFill: highlightedOutgoingBubbleColor,
                        stroke: .clear
                    ),
                    withoutWallpaper: chat.message.outgoing.bubble.withoutWallpaper.withUpdated(
                        fill: outgoingBubbleFillColor,
                        gradientFill: outgoingBubbleFillGradientColor,
                        highlightedFill: highlightedOutgoingBubbleColor,
                        stroke: .clear
                    )
                ),
                primaryTextColor: outgoingPrimaryTextColor,
                secondaryTextColor: outgoingSecondaryTextColor,
                linkTextColor: outgoingLinkTextColor,
                scamColor: outgoingScamColor,
                accentTextColor: outgoingPrimaryTextColor,
                accentControlColor: outgoingPrimaryTextColor,
                mediaActiveControlColor: outgoingPrimaryTextColor,
                mediaInactiveControlColor: outgoingSecondaryTextColor,
                mediaControlInnerBackgroundColor: outgoingBubbleFillColor,
                pendingActivityColor: outgoingSecondaryTextColor,
                fileTitleColor: outgoingPrimaryTextColor,
                fileDescriptionColor: outgoingSecondaryTextColor,
                fileDurationColor: outgoingSecondaryTextColor,
                mediaPlaceholderColor: accentColor?.withMultiplied(hue: 1.019, saturation: 0.804, brightness: 0.51),
                polls: chat.message.outgoing.polls.withUpdated(radioButton: outgoingPrimaryTextColor, radioProgress: outgoingPrimaryTextColor, highlight: outgoingPrimaryTextColor?.withAlphaComponent(0.12), separator: mainSeparatorColor, bar: outgoingPrimaryTextColor),
                actionButtonsFillColor: chat.message.outgoing.actionButtonsFillColor.withUpdated(withWallpaper: additionalBackgroundColor?.withAlphaComponent(0.5), withoutWallpaper: additionalBackgroundColor?.withAlphaComponent(0.5)),
                actionButtonsStrokeColor: buttonStrokeColor.flatMap { PresentationThemeVariableColor(color: $0) }
            ),
            freeform: chat.message.freeform.withUpdated(
                withWallpaper: chat.message.freeform.withWallpaper.withUpdated(
                    fill: mainBackgroundColor,
                    highlightedFill: highlightedIncomingBubbleColor,
                    stroke: mainBackgroundColor
                ), withoutWallpaper: chat.message.freeform.withoutWallpaper.withUpdated(
                    fill: mainBackgroundColor,
                    highlightedFill: highlightedIncomingBubbleColor,
                    stroke: mainBackgroundColor
                )
            ),
            infoLinkTextColor: accentColor,
            outgoingCheckColor: outgoingCheckColor,
            shareButtonFillColor: additionalBackgroundColor.flatMap { PresentationThemeVariableColor(color: $0.withAlphaComponent(0.5)) },
            shareButtonStrokeColor: buttonStrokeColor.flatMap { PresentationThemeVariableColor(color: $0) },
            selectionControlColors: chat.message.selectionControlColors.withUpdated(fillColor: accentColor)
        ),
        
        serviceMessage: chat.serviceMessage.withUpdated(
            components: chat.serviceMessage.components.withUpdated(
                withDefaultWallpaper: chat.serviceMessage.components.withDefaultWallpaper.withUpdated(
                    fill: additionalBackgroundColor,
                    dateFillStatic: additionalBackgroundColor?.withAlphaComponent(0.6),
                    dateFillFloating: additionalBackgroundColor?.withAlphaComponent(0.2)
                ),
                withCustomWallpaper: chat.serviceMessage.components.withCustomWallpaper.withUpdated(
                    fill: additionalBackgroundColor,
                    dateFillStatic: additionalBackgroundColor?.withAlphaComponent(0.6),
                    dateFillFloating: additionalBackgroundColor?.withAlphaComponent(0.2)
                )
            ),
            unreadBarFillColor: mainBackgroundColor,
            unreadBarStrokeColor: mainBackgroundColor
        ),
        inputPanel: chat.inputPanel.withUpdated(
            panelBackgroundColor: mainBackgroundColor,
            panelSeparatorColor: mainSeparatorColor,
            panelControlAccentColor: accentColor,
            panelControlColor: mainSecondaryTextColor?.withAlphaComponent(0.5),
            inputBackgroundColor: inputBackgroundColor,
            inputStrokeColor: accentColor?.withMultiplied(hue: 1.038, saturation: 0.463, brightness: 0.26),
            inputPlaceholderColor: mainSecondaryTextColor?.withAlphaComponent(0.4),
            inputControlColor: mainSecondaryTextColor?.withAlphaComponent(0.4),
            actionControlFillColor: accentColor,
            mediaRecordingDotColor: accentColor,
            mediaRecordingControl: chat.inputPanel.mediaRecordingControl.withUpdated(
                buttonColor: accentColor,
                micLevelColor: accentColor?.withAlphaComponent(0.2)
            )
        ),
        inputMediaPanel: chat.inputMediaPanel.withUpdated(
            panelSeparatorColor: mainBackgroundColor,
            panelIconColor: mainSecondaryTextColor?.withAlphaComponent(0.5),
            panelHighlightedIconBackgroundColor: inputBackgroundColor,
            stickersBackgroundColor: additionalBackgroundColor,
            stickersSectionTextColor: mainSecondaryTextColor?.withAlphaComponent(0.5),
            stickersSearchBackgroundColor: accentColor?.withMultiplied(hue: 1.009, saturation: 0.621, brightness: 0.15),
            stickersSearchPlaceholderColor: accentColor?.withMultiplied(hue: 0.99, saturation: 0.243, brightness: 0.59),
            stickersSearchControlColor: accentColor?.withMultiplied(hue: 0.99, saturation: 0.243, brightness: 0.59),
            gifsBackgroundColor: additionalBackgroundColor
        ),
        inputButtonPanel: chat.inputButtonPanel.withUpdated(
            panelSeparatorColor: mainBackgroundColor,
            panelBackgroundColor: accentColor?.withMultiplied(hue: 1.048, saturation: 0.378, brightness: 0.13),
            buttonFillColor: accentColor?.withMultiplied(hue: 1.0, saturation: 0.085, brightness: 0.38),
            buttonStrokeColor: accentColor?.withMultiplied(hue: 1.019, saturation: 0.39, brightness: 0.07),
            buttonHighlightedFillColor: accentColor?.withMultiplied(hue: 1.0, saturation: 0.085, brightness: 0.38).withAlphaComponent(0.7),
            buttonHighlightedStrokeColor: accentColor?.withMultiplied(hue: 1.019, saturation: 0.39, brightness: 0.07)
        ),
        historyNavigation: chat.historyNavigation.withUpdated(
            fillColor: mainBackgroundColor,
            strokeColor: mainSeparatorColor,
            foregroundColor: mainSecondaryTextColor?.withAlphaComponent(0.5),
            badgeBackgroundColor: accentColor,
            badgeStrokeColor: accentColor
        )
    )
    
    return PresentationTheme(
        name: title.flatMap { .custom($0) } ?? theme.name,
        index: theme.index,
        referenceTheme: theme.referenceTheme,
        overallDarkAppearance: theme.overallDarkAppearance,
        intro: intro,
        passcode: passcode,
        rootController: rootController,
        list: list,
        chatList: chatList,
        chat: chat,
        actionSheet: actionSheet,
        contextMenu: contextMenu,
        inAppNotification: inAppNotification,
        preview: theme.preview
    )
}

public func makeDefaultDarkTintedPresentationTheme(extendingThemeReference: PresentationThemeReference? = nil, preview: Bool) -> PresentationTheme {
    let accentColor = defaultDarkTintedAccentColor
    
    let secondaryBadgeTextColor: UIColor
    let lightness = accentColor.lightness
    if lightness > 0.7 {
        secondaryBadgeTextColor = .black
    } else {
        secondaryBadgeTextColor = .white
    }
    
    let mainBackgroundColor = accentColor.withMultiplied(hue: 1.024, saturation: 0.585, brightness: 0.25)
    let mainSelectionColor = accentColor.withMultiplied(hue: 1.03, saturation: 0.585, brightness: 0.12)
    let additionalBackgroundColor = accentColor.withMultiplied(hue: 1.024, saturation: 0.573, brightness: 0.18)
    let mainSeparatorColor = accentColor.withMultiplied(hue: 1.033, saturation: 0.426, brightness: 0.34)
    let mainForegroundColor = accentColor.withMultiplied(hue: 0.99, saturation: 0.256, brightness: 0.62)
    let mainSecondaryColor = accentColor.withMultiplied(hue: 1.019, saturation: 0.109, brightness: 0.59)
    let mainSecondaryTextColor = accentColor.withMultiplied(hue: 0.956, saturation: 0.17, brightness: 1.0)
    let mainFreeTextColor = accentColor.withMultiplied(hue: 1.019, saturation: 0.097, brightness: 0.56)
    
    let outgoingBubbleFillGradientColor = accentColor.withMultiplied(hue: 1.019, saturation: 0.731, brightness: 0.59)
    let outgoingBubbleFillColor = outgoingBubbleFillGradientColor.withMultiplied(hue: 0.966, saturation: 0.61, brightness: 0.98)
    let outgoingBubbleHighlightedFillColor: UIColor
    let outgoingScamColor = UIColor(rgb: 0xffffff)
    let outgoingPrimaryTextColor = UIColor(rgb: 0xffffff)
    let outgoingSecondaryTextColor = UIColor(rgb: 0xffffff, alpha: 0.5)
    let outgoingLinkTextColor = UIColor(rgb: 0xffffff)
    let outgoingCheckColor = UIColor(rgb: 0xffffff, alpha: 0.5)
    
    let highlightedIncomingBubbleColor = accentColor.withMultiplied(hue: 1.03, saturation: 0.463, brightness: 0.29)
    let highlightedOutgoingBubbleColor = accentColor.withMultiplied(hue: 1.019, saturation: 0.609, brightness: 0.63)
    
    let mainInputColor = accentColor.withMultiplied(hue: 1.029, saturation: 0.609, brightness: 0.19)
    let inputBackgroundColor = accentColor.withMultiplied(hue: 1.02, saturation: 0.609, brightness: 0.15)
    
    let rootTabBar = PresentationThemeRootTabBar(
        backgroundColor: mainBackgroundColor,
        separatorColor: mainSeparatorColor,
        iconColor: mainForegroundColor,
        selectedIconColor: accentColor,
        textColor: mainForegroundColor,
        selectedTextColor: accentColor,
        badgeBackgroundColor: UIColor(rgb: 0xef5b5b),
        badgeStrokeColor: UIColor(rgb: 0xef5b5b),
        badgeTextColor: UIColor(rgb: 0xffffff)
    )

    let rootNavigationBar = PresentationThemeRootNavigationBar(
        buttonColor: accentColor,
        disabledButtonColor: accentColor.withMultiplied(hue: 1.033, saturation: 0.219, brightness: 0.44),
        primaryTextColor: .white,
        secondaryTextColor: mainSecondaryColor,
        controlColor: mainSecondaryColor,
        accentTextColor: accentColor,
        backgroundColor: mainBackgroundColor,
        separatorColor: mainSeparatorColor,
        badgeBackgroundColor: UIColor(rgb: 0xef5b5b),
        badgeStrokeColor: UIColor(rgb: 0xef5b5b),
        badgeTextColor: UIColor(rgb: 0xffffff),
        segmentedBackgroundColor: mainInputColor,
        segmentedForegroundColor: mainBackgroundColor,
        segmentedTextColor: UIColor(rgb: 0xffffff),
        segmentedDividerColor: mainSecondaryTextColor.withAlphaComponent(0.5)
    )

    let navigationSearchBar = PresentationThemeNavigationSearchBar(
        backgroundColor: mainBackgroundColor,
        accentColor: accentColor,
        inputFillColor: mainInputColor,
        inputTextColor: UIColor(rgb: 0xffffff),
        inputPlaceholderTextColor: mainSecondaryColor,
        inputIconColor: mainSecondaryColor,
        inputClearButtonColor: mainSecondaryColor,
        separatorColor: additionalBackgroundColor
    )

    let intro = PresentationThemeIntro(
        statusBarStyle: .white,
        primaryTextColor: .white,
        accentTextColor: accentColor,
        disabledTextColor: accentColor.withMultiplied(hue: 1.033, saturation: 0.219, brightness: 0.44),
        startButtonColor: accentColor,
        dotColor: mainSecondaryColor
    )

    let passcode = PresentationThemePasscode(
        backgroundColors: PresentationThemeGradientColors(topColor: accentColor.withMultiplied(hue: 1.049, saturation: 0.573, brightness: 0.47), bottomColor: additionalBackgroundColor),
        buttonColor: mainBackgroundColor
    )

    let rootController = PresentationThemeRootController(
        statusBarStyle: .white,
        tabBar: rootTabBar,
        navigationBar: rootNavigationBar,
        navigationSearchBar: navigationSearchBar,
        keyboardColor: .dark
    )

    let switchColors = PresentationThemeSwitch(
        frameColor: mainSecondaryTextColor.withAlphaComponent(0.5),
        handleColor: UIColor(rgb: 0x121212),
        contentColor: accentColor,
        positiveColor: UIColor(rgb: 0x08a723),
        negativeColor: UIColor(rgb: 0xff6767)
    )

    let list = PresentationThemeList(
        blocksBackgroundColor: additionalBackgroundColor,
        plainBackgroundColor: additionalBackgroundColor,
        itemPrimaryTextColor: UIColor(rgb: 0xffffff),
        itemSecondaryTextColor: mainSecondaryTextColor.withAlphaComponent(0.5),
        itemDisabledTextColor: mainSecondaryTextColor.withAlphaComponent(0.5),
        itemAccentColor: accentColor,
        itemHighlightedColor: UIColor(rgb: 0x28b772),
        itemDestructiveColor: UIColor(rgb: 0xff6767),
        itemPlaceholderTextColor: mainSecondaryTextColor.withAlphaComponent(0.5),
        itemBlocksBackgroundColor: mainBackgroundColor,
        itemHighlightedBackgroundColor: mainSelectionColor,
        itemBlocksSeparatorColor: mainSeparatorColor,
        itemPlainSeparatorColor: mainSeparatorColor,
        disclosureArrowColor: mainSecondaryTextColor.withAlphaComponent(0.5),
        sectionHeaderTextColor: mainFreeTextColor,
        freeTextColor: mainFreeTextColor,
        freeTextErrorColor: UIColor(rgb: 0xff6767),
        freeTextSuccessColor: UIColor(rgb: 0x30cf30),
        freeMonoIconColor: mainFreeTextColor,
        itemSwitchColors: switchColors,
        itemDisclosureActions: PresentationThemeItemDisclosureActions(
            neutral1: PresentationThemeFillForeground(fillColor: accentColor, foregroundColor: .white),
            neutral2: PresentationThemeFillForeground(fillColor: UIColor(rgb: 0xcd7800), foregroundColor: .white),
            destructive: PresentationThemeFillForeground(fillColor: UIColor(rgb: 0xc70c0c), foregroundColor: .white),
            constructive: PresentationThemeFillForeground(fillColor: UIColor(rgb: 0x08a723), foregroundColor: .white),
            accent: PresentationThemeFillForeground(fillColor: accentColor, foregroundColor: .white),
            warning: PresentationThemeFillForeground(fillColor: UIColor(rgb: 0xcd7800), foregroundColor: .white),
            inactive: PresentationThemeFillForeground(fillColor: accentColor.withMultiplied(hue: 1.029, saturation: 0.609, brightness: 0.3), foregroundColor: .white)
        ),
        itemCheckColors: PresentationThemeFillStrokeForeground(
            fillColor: accentColor,
            strokeColor: mainSecondaryTextColor.withAlphaComponent(0.5),
            foregroundColor: secondaryBadgeTextColor
        ),
        controlSecondaryColor: mainSecondaryTextColor.withAlphaComponent(0.5),
        freeInputField: PresentationInputFieldTheme(
            backgroundColor: mainSecondaryTextColor.withAlphaComponent(0.5),
            strokeColor: mainSecondaryTextColor.withAlphaComponent(0.5),
            placeholderColor: UIColor(rgb: 0x4d4d4d),
            primaryColor: .white,
            controlColor: UIColor(rgb: 0x4d4d4d)
        ),
        freePlainInputField: PresentationInputFieldTheme(
            backgroundColor: mainSecondaryTextColor.withAlphaComponent(0.5),
            strokeColor: mainSecondaryTextColor.withAlphaComponent(0.5),
            placeholderColor: UIColor(rgb: 0x4d4d4d),
            primaryColor: .white,
            controlColor: UIColor(rgb: 0x4d4d4d)
        ),
        mediaPlaceholderColor: UIColor(rgb: 0xffffff).mixedWith(mainBackgroundColor, alpha: 0.9),
        scrollIndicatorColor: UIColor(white: 1.0, alpha: 0.3),
        pageIndicatorInactiveColor: mainSecondaryTextColor.withAlphaComponent(0.4),
        inputClearButtonColor: mainSecondaryColor,
        itemBarChart: PresentationThemeItemBarChart(color1: accentColor, color2: mainSecondaryTextColor.withAlphaComponent(0.5), color3: accentColor.withMultiplied(hue: 1.038, saturation: 0.329, brightness: 0.33))
    )
    
    let chatList = PresentationThemeChatList(
        backgroundColor: additionalBackgroundColor,
        itemSeparatorColor: mainSeparatorColor,
        itemBackgroundColor: additionalBackgroundColor,
        pinnedItemBackgroundColor: mainBackgroundColor,
        itemHighlightedBackgroundColor: mainSelectionColor,
        itemSelectedBackgroundColor: mainSelectionColor,
        titleColor: UIColor(rgb: 0xffffff),
        secretTitleColor: UIColor(rgb: 0x89df9e),
        dateTextColor: mainSecondaryTextColor.withAlphaComponent(0.5),
        authorNameColor: UIColor(rgb: 0xffffff),
        messageTextColor: mainSecondaryTextColor.withAlphaComponent(0.5),
        messageHighlightedTextColor: UIColor(rgb: 0xffffff),
        messageDraftTextColor: UIColor(rgb: 0xdd4b39),
        checkmarkColor: accentColor,
        pendingIndicatorColor: mainSecondaryTextColor.withAlphaComponent(0.4),
        failedFillColor: UIColor(rgb: 0xff6767),
        failedForegroundColor: .white,
        muteIconColor: mainSecondaryTextColor.withAlphaComponent(0.4),
        unreadBadgeActiveBackgroundColor: accentColor,
        unreadBadgeActiveTextColor: secondaryBadgeTextColor,
        unreadBadgeInactiveBackgroundColor: mainSecondaryTextColor.withAlphaComponent(0.4),
        unreadBadgeInactiveTextColor: additionalBackgroundColor,
        pinnedBadgeColor: mainSecondaryTextColor.withAlphaComponent(0.5),
        pinnedSearchBarColor: mainInputColor,
        regularSearchBarColor: accentColor.withMultiplied(hue: 1.029, saturation: 0.609, brightness: 0.12),
        sectionHeaderFillColor: mainBackgroundColor,
        sectionHeaderTextColor: mainSecondaryTextColor.withAlphaComponent(0.5),
        verifiedIconFillColor: accentColor,
        verifiedIconForegroundColor: .white,
        secretIconColor: UIColor(rgb: 0x89df9e),
        pinnedArchiveAvatarColor: PresentationThemeArchiveAvatarColors(backgroundColors: PresentationThemeGradientColors(topColor: UIColor(rgb: 0x72d5fd), bottomColor: UIColor(rgb: 0x2a9ef1)), foregroundColor: .white),
        unpinnedArchiveAvatarColor: PresentationThemeArchiveAvatarColors(backgroundColors: PresentationThemeGradientColors(topColor: accentColor.withMultiplied(hue: 0.985, saturation: 0.268, brightness: 0.47), bottomColor: accentColor.withMultiplied(hue: 0.98, saturation: 0.268, brightness: 0.39)), foregroundColor: additionalBackgroundColor),
        onlineDotColor: UIColor(rgb: 0x4cc91f)
    )
    
    let buttonStrokeColor = accentColor.withMultiplied(hue: 1.014, saturation: 0.56, brightness: 0.64).withAlphaComponent(0.15)
    
    let message = PresentationThemeChatMessage(
        incoming: PresentationThemePartedColors(bubble: PresentationThemeBubbleColor(withWallpaper: PresentationThemeBubbleColorComponents(fill: mainBackgroundColor, highlightedFill: highlightedIncomingBubbleColor, stroke: mainBackgroundColor), withoutWallpaper: PresentationThemeBubbleColorComponents(fill: mainBackgroundColor, highlightedFill: highlightedIncomingBubbleColor, stroke: mainBackgroundColor)), primaryTextColor: .white, secondaryTextColor: mainSecondaryTextColor.withAlphaComponent(0.5), linkTextColor: accentColor, linkHighlightColor: accentColor.withAlphaComponent(0.5), scamColor: UIColor(rgb: 0xff6767), textHighlightColor: UIColor(rgb: 0xf5c038), accentTextColor: accentColor, accentControlColor: accentColor, accentControlDisabledColor: mainSecondaryTextColor.withAlphaComponent(0.5), mediaActiveControlColor: accentColor, mediaInactiveControlColor: accentColor.withAlphaComponent(0.5), mediaControlInnerBackgroundColor: mainBackgroundColor, pendingActivityColor: mainSecondaryTextColor.withAlphaComponent(0.5), fileTitleColor: accentColor, fileDescriptionColor: mainSecondaryTextColor.withAlphaComponent(0.5), fileDurationColor: mainSecondaryTextColor.withAlphaComponent(0.5), mediaPlaceholderColor: accentColor.withMultiplied(hue: 1.019, saturation: 0.585, brightness: 0.23), polls: PresentationThemeChatBubblePolls(radioButton: accentColor.withMultiplied(hue: 0.995, saturation: 0.317, brightness: 0.51), radioProgress: accentColor, highlight: accentColor.withAlphaComponent(0.12), separator: mainSeparatorColor, bar: accentColor, barIconForeground: .white, barPositive: UIColor(rgb: 0x00A700), barNegative: UIColor(rgb: 0xFE3824)), actionButtonsFillColor: PresentationThemeVariableColor(withWallpaper: additionalBackgroundColor.withAlphaComponent(0.5), withoutWallpaper: additionalBackgroundColor.withAlphaComponent(0.5)), actionButtonsStrokeColor: PresentationThemeVariableColor(color: buttonStrokeColor), actionButtonsTextColor: PresentationThemeVariableColor(color: .white), textSelectionColor: accentColor.withAlphaComponent(0.2), textSelectionKnobColor: accentColor),
        outgoing: PresentationThemePartedColors(bubble: PresentationThemeBubbleColor(withWallpaper: PresentationThemeBubbleColorComponents(fill: outgoingBubbleFillColor, gradientFill: outgoingBubbleFillGradientColor, highlightedFill: highlightedOutgoingBubbleColor, stroke: outgoingBubbleFillColor), withoutWallpaper: PresentationThemeBubbleColorComponents(fill: outgoingBubbleFillColor, gradientFill: outgoingBubbleFillGradientColor, highlightedFill: highlightedOutgoingBubbleColor, stroke: outgoingBubbleFillColor)), primaryTextColor: outgoingPrimaryTextColor, secondaryTextColor: outgoingSecondaryTextColor, linkTextColor: outgoingLinkTextColor, linkHighlightColor: UIColor.white.withAlphaComponent(0.5), scamColor: outgoingScamColor, textHighlightColor: UIColor(rgb: 0xf5c038), accentTextColor: outgoingPrimaryTextColor, accentControlColor: outgoingPrimaryTextColor, accentControlDisabledColor: mainSecondaryTextColor.withAlphaComponent(0.5), mediaActiveControlColor: outgoingPrimaryTextColor, mediaInactiveControlColor: outgoingSecondaryTextColor, mediaControlInnerBackgroundColor: outgoingBubbleFillColor, pendingActivityColor: outgoingSecondaryTextColor, fileTitleColor: outgoingPrimaryTextColor, fileDescriptionColor: outgoingSecondaryTextColor, fileDurationColor: outgoingSecondaryTextColor, mediaPlaceholderColor: accentColor.withMultiplied(hue: 1.019, saturation: 0.804, brightness: 0.51), polls: PresentationThemeChatBubblePolls(radioButton: outgoingPrimaryTextColor, radioProgress: accentColor.withMultiplied(hue: 0.99, saturation: 0.56, brightness: 1.0), highlight: accentColor.withMultiplied(hue: 0.99, saturation: 0.56, brightness: 1.0).withAlphaComponent(0.12), separator: mainSeparatorColor, bar: outgoingPrimaryTextColor, barIconForeground: .clear, barPositive: outgoingPrimaryTextColor, barNegative: outgoingPrimaryTextColor), actionButtonsFillColor: PresentationThemeVariableColor(withWallpaper: additionalBackgroundColor.withAlphaComponent(0.5), withoutWallpaper: additionalBackgroundColor.withAlphaComponent(0.5)), actionButtonsStrokeColor: PresentationThemeVariableColor(color: buttonStrokeColor), actionButtonsTextColor: PresentationThemeVariableColor(color: .white), textSelectionColor: UIColor.white.withAlphaComponent(0.2), textSelectionKnobColor: UIColor.white),
        freeform: PresentationThemeBubbleColor(withWallpaper: PresentationThemeBubbleColorComponents(fill: mainBackgroundColor, highlightedFill: highlightedIncomingBubbleColor, stroke: mainBackgroundColor), withoutWallpaper: PresentationThemeBubbleColorComponents(fill: mainBackgroundColor, highlightedFill: highlightedIncomingBubbleColor, stroke: mainBackgroundColor)),
        infoPrimaryTextColor: UIColor(rgb: 0xffffff),
        infoLinkTextColor: accentColor,
        outgoingCheckColor: outgoingCheckColor,
        mediaDateAndStatusFillColor: UIColor(white: 0.0, alpha: 0.5),
        mediaDateAndStatusTextColor: UIColor(rgb: 0xffffff),
        shareButtonFillColor: PresentationThemeVariableColor(color: additionalBackgroundColor.withAlphaComponent(0.5)),
        shareButtonStrokeColor: PresentationThemeVariableColor(color: buttonStrokeColor),
        shareButtonForegroundColor: PresentationThemeVariableColor(color: UIColor(rgb: 0xb2b2b2)),
        mediaOverlayControlColors: PresentationThemeFillForeground(fillColor: UIColor(rgb: 0x000000, alpha: 0.6), foregroundColor: .white),
        selectionControlColors: PresentationThemeFillStrokeForeground(fillColor: accentColor, strokeColor: .white, foregroundColor: .white),
        deliveryFailedColors: PresentationThemeFillForeground(fillColor: UIColor(rgb: 0xff6767), foregroundColor: .white),
        mediaHighlightOverlayColor: UIColor(white: 1.0, alpha: 0.6)
    )
    
    let serviceMessage = PresentationThemeServiceMessage(
        components: PresentationThemeServiceMessageColor(withDefaultWallpaper: PresentationThemeServiceMessageColorComponents(fill: additionalBackgroundColor, primaryText: .white, linkHighlight: UIColor(rgb: 0xffffff, alpha: 0.12), scam: UIColor(rgb: 0xff6767), dateFillStatic: additionalBackgroundColor.withAlphaComponent(0.6), dateFillFloating: additionalBackgroundColor.withAlphaComponent(0.2)), withCustomWallpaper: PresentationThemeServiceMessageColorComponents(fill: additionalBackgroundColor, primaryText: .white, linkHighlight: UIColor(rgb: 0xffffff, alpha: 0.12), scam: UIColor(rgb: 0xff6767), dateFillStatic: additionalBackgroundColor.withAlphaComponent(0.6), dateFillFloating: additionalBackgroundColor.withAlphaComponent(0.2))),
        unreadBarFillColor: mainBackgroundColor,
        unreadBarStrokeColor: mainBackgroundColor,
        unreadBarTextColor: .white,
        dateTextColor: PresentationThemeVariableColor(color: .white)
    )

    let inputPanelMediaRecordingControl = PresentationThemeChatInputPanelMediaRecordingControl(
        buttonColor: accentColor,
        micLevelColor: accentColor.withAlphaComponent(0.2),
        activeIconColor: .white
    )
    
    let inputPanel = PresentationThemeChatInputPanel(
        panelBackgroundColor: mainBackgroundColor,
        panelBackgroundColorNoWallpaper: accentColor.withMultiplied(hue: 1.024, saturation: 0.573, brightness: 0.18),
        panelSeparatorColor: mainSeparatorColor,
        panelControlAccentColor: accentColor,
        panelControlColor: mainSecondaryTextColor.withAlphaComponent(0.5),
        panelControlDisabledColor: UIColor(rgb: 0x90979F, alpha: 0.5),
        panelControlDestructiveColor: UIColor(rgb: 0xff6767),
        inputBackgroundColor: inputBackgroundColor,
        inputStrokeColor: accentColor.withMultiplied(hue: 1.038, saturation: 0.463, brightness: 0.26),
        inputPlaceholderColor: mainSecondaryTextColor.withAlphaComponent(0.4),
        inputTextColor: UIColor(rgb: 0xffffff),
        inputControlColor: mainSecondaryTextColor.withAlphaComponent(0.4),
        actionControlFillColor: accentColor,
        actionControlForegroundColor: .white,
        primaryTextColor: UIColor(rgb: 0xffffff),
        secondaryTextColor: UIColor(rgb: 0xffffff, alpha: 0.5),
        mediaRecordingDotColor: accentColor,
        mediaRecordingControl: inputPanelMediaRecordingControl
    )

    let inputMediaPanel = PresentationThemeInputMediaPanel(
        panelSeparatorColor: mainBackgroundColor,
        panelIconColor: mainSecondaryTextColor.withAlphaComponent(0.5),
        panelHighlightedIconBackgroundColor: inputBackgroundColor,
        stickersBackgroundColor: additionalBackgroundColor,
        stickersSectionTextColor: mainSecondaryTextColor.withAlphaComponent(0.5),
        stickersSearchBackgroundColor: accentColor.withMultiplied(hue: 1.009, saturation: 0.621, brightness: 0.15),
        stickersSearchPlaceholderColor: accentColor.withMultiplied(hue: 0.99, saturation: 0.243, brightness: 0.59),
        stickersSearchPrimaryColor: .white,
        stickersSearchControlColor: accentColor.withMultiplied(hue: 0.99, saturation: 0.243, brightness: 0.59),
        gifsBackgroundColor: additionalBackgroundColor
    )

    let inputButtonPanel = PresentationThemeInputButtonPanel(
        panelSeparatorColor: mainBackgroundColor,
        panelBackgroundColor: accentColor.withMultiplied(hue: 1.048, saturation: 0.378, brightness: 0.13),
        buttonFillColor: accentColor.withMultiplied(hue: 1.0, saturation: 0.085, brightness: 0.38),
        buttonStrokeColor: accentColor.withMultiplied(hue: 1.019, saturation: 0.39, brightness: 0.07),
        buttonHighlightedFillColor: accentColor.withMultiplied(hue: 1.0, saturation: 0.085, brightness: 0.38).withAlphaComponent(0.7),
        buttonHighlightedStrokeColor: accentColor.withMultiplied(hue: 1.019, saturation: 0.39, brightness: 0.07),
        buttonTextColor: UIColor(rgb: 0xffffff)
    )

    let historyNavigation = PresentationThemeChatHistoryNavigation(
        fillColor: mainBackgroundColor,
        strokeColor: mainSeparatorColor,
        foregroundColor: mainSecondaryTextColor.withAlphaComponent(0.5),
        badgeBackgroundColor: accentColor,
        badgeStrokeColor: accentColor,
        badgeTextColor: .white
    )

    let chat = PresentationThemeChat(
        defaultWallpaper: .color(accentColor.withMultiplied(hue: 1.024, saturation: 0.573, brightness: 0.18).argb),
        message: message,
        serviceMessage: serviceMessage,
        inputPanel: inputPanel,
        inputMediaPanel: inputMediaPanel,
        inputButtonPanel: inputButtonPanel,
        historyNavigation: historyNavigation
    )

    let actionSheet = PresentationThemeActionSheet(
        dimColor: UIColor(white: 0.0, alpha: 0.5),
        backgroundType: .dark,
        opaqueItemBackgroundColor: mainBackgroundColor,
        itemBackgroundColor: mainBackgroundColor.withAlphaComponent(0.8),
        opaqueItemHighlightedBackgroundColor: mainSelectionColor,
        itemHighlightedBackgroundColor: mainSelectionColor.withAlphaComponent(0.2),
        opaqueItemSeparatorColor: additionalBackgroundColor,
        standardActionTextColor: accentColor,
        destructiveActionTextColor: UIColor(rgb: 0xff6767),
        disabledActionTextColor: UIColor(white: 1.0, alpha: 0.5),
        primaryTextColor: .white,
        secondaryTextColor: UIColor(white: 1.0, alpha: 0.5),
        controlAccentColor: accentColor,
        inputBackgroundColor: mainInputColor,
        inputHollowBackgroundColor: mainInputColor,
        inputBorderColor: mainInputColor,
        inputPlaceholderColor: mainSecondaryColor,
        inputTextColor: .white,
        inputClearButtonColor: mainSecondaryColor,
        checkContentColor: secondaryBadgeTextColor
    )
    
    let contextMenu = PresentationThemeContextMenu(
        dimColor: UIColor(rgb: 0x000000, alpha: 0.6),
        backgroundColor: rootNavigationBar.backgroundColor.withAlphaComponent(0.78),
        itemSeparatorColor: UIColor(rgb: 0xffffff, alpha: 0.15),
        sectionSeparatorColor: UIColor(rgb: 0x000000, alpha: 0.2),
        itemBackgroundColor: UIColor(rgb: 0x000000, alpha: 0.0),
        itemHighlightedBackgroundColor: UIColor(rgb: 0xffffff, alpha: 0.15),
        primaryColor: UIColor(rgb: 0xffffff, alpha: 1.0),
        secondaryColor: UIColor(rgb: 0xffffff, alpha: 0.8),
        destructiveColor: UIColor(rgb: 0xff6767)
    )

    let inAppNotification = PresentationThemeInAppNotification(
        fillColor: mainBackgroundColor,
        primaryTextColor: .white,
        expandedNotification: PresentationThemeExpandedNotification(
            backgroundType: .dark,
            navigationBar: PresentationThemeExpandedNotificationNavigationBar(
                backgroundColor: mainBackgroundColor,
                primaryTextColor: UIColor(rgb: 0xffffff),
                controlColor: accentColor,
                separatorColor: mainSeparatorColor
            )
        )
    )

    return PresentationTheme(
        name: extendingThemeReference?.name ?? .builtin(.nightAccent),
        index: extendingThemeReference?.index ?? PresentationThemeReference.builtin(.nightAccent).index,
        referenceTheme: .nightAccent,
        overallDarkAppearance: true,
        intro: intro,
        passcode: passcode,
        rootController: rootController,
        list: list,
        chatList: chatList,
        chat: chat,
        actionSheet: actionSheet,
        contextMenu: contextMenu,
        inAppNotification: inAppNotification,
        preview: preview
    )
}
