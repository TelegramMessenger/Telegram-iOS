import Foundation
import UIKit
import TelegramCore
import SyncCore
import TelegramUIPreferences

public let defaultDarkPresentationTheme = makeDefaultDarkPresentationTheme(preview: false)

public func customizeDefaultDarkPresentationTheme(theme: PresentationTheme, editing: Bool, title: String?, accentColor: UIColor?, backgroundColors: (UIColor, UIColor?)?, bubbleColors: (UIColor, UIColor?)?, wallpaper forcedWallpaper: TelegramWallpaper? = nil) -> PresentationTheme {
    if (theme.referenceTheme != .night) {
        return theme
    }
       
    var intro = theme.intro
    var rootController = theme.rootController
    var list = theme.list
    var chatList = theme.chatList
    var chat = theme.chat
    var actionSheet = theme.actionSheet
    
    var bubbleColors = bubbleColors
    var monochrome = false
    if bubbleColors == nil, editing {
        let accentColor = accentColor ?? UIColor(rgb: 0xffffff)
        if accentColor.rgb == 0xffffff {
            monochrome = true
            bubbleColors = (UIColor(rgb: 0x313131), UIColor(rgb: 0x313131))
        } else {
            bubbleColors = (accentColor.withMultiplied(hue: 0.966, saturation: 0.61, brightness: 0.98), accentColor)
        }
    }
    
    var badgeFillColor: UIColor?
    var badgeTextColor: UIColor?
    var secondaryBadgeTextColor: UIColor?
    
    var accentColor = accentColor
    if let initialAccentColor = accentColor {
        if monochrome {
            badgeFillColor = UIColor(rgb: 0xffffff)
            badgeTextColor = UIColor(rgb: 0x000000)
            secondaryBadgeTextColor = UIColor(rgb: 0x000000)
        } else {
            badgeFillColor = UIColor(rgb: 0xeb5545)
            badgeTextColor = UIColor(rgb: 0xffffff)
            if initialAccentColor.lightness > 0.7 {
                secondaryBadgeTextColor = UIColor(rgb: 0x000000)
            } else {
                secondaryBadgeTextColor = UIColor(rgb: 0xffffff)
                
                let hsb = initialAccentColor.hsb
                accentColor = UIColor(hue: hsb.0, saturation: hsb.1, brightness: max(hsb.2, 0.55), alpha: 1.0)
            }
        }
        
        intro = intro.withUpdated(accentTextColor: accentColor, startButtonColor: accentColor)
        rootController = rootController.withUpdated(
            tabBar: rootController.tabBar.withUpdated(selectedIconColor: accentColor, selectedTextColor: accentColor, badgeBackgroundColor: badgeFillColor, badgeTextColor: badgeTextColor),
            navigationBar: rootController.navigationBar.withUpdated(buttonColor: accentColor, accentTextColor: accentColor, badgeBackgroundColor: badgeFillColor, badgeTextColor: badgeTextColor),
            navigationSearchBar: rootController.navigationSearchBar.withUpdated(accentColor: accentColor)
        )
        list = list.withUpdated(
            itemAccentColor: accentColor,
            itemCheckColors: list.itemCheckColors.withUpdated(fillColor: accentColor, foregroundColor: secondaryBadgeTextColor),
            itemBarChart: list.itemBarChart.withUpdated(color1: accentColor)
        )
        chatList = chatList.withUpdated(
            checkmarkColor: accentColor,
            unreadBadgeActiveBackgroundColor: accentColor,
            unreadBadgeActiveTextColor: secondaryBadgeTextColor,
            verifiedIconFillColor: accentColor,
            verifiedIconForegroundColor: badgeTextColor
        )
        actionSheet = actionSheet.withUpdated(
            standardActionTextColor: accentColor,
            controlAccentColor: accentColor,
            checkContentColor: secondaryBadgeTextColor
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
    }
    
    var outgoingBubbleFillColor: UIColor?
    var outgoingBubbleFillGradientColor: UIColor?
    var outgoingBubbleHighlightedFillColor: UIColor?
    var outgoingPrimaryTextColor: UIColor?
    var outgoingSecondaryTextColor: UIColor?
    var outgoingLinkTextColor: UIColor?
    var outgoingScamColor: UIColor?
    var outgoingCheckColor: UIColor?
   
    if let bubbleColors = bubbleColors {
        var topBubbleColor = bubbleColors.0
        var bottomBubbleColor = bubbleColors.1 ?? bubbleColors.0

        if topBubbleColor.rgb != bottomBubbleColor.rgb {
            let topBubbleColorLightness = topBubbleColor.lightness
            let bottomBubbleColorLightness = bottomBubbleColor.lightness
            if abs(topBubbleColorLightness - bottomBubbleColorLightness) > 0.7 {
                if topBubbleColorLightness > bottomBubbleColorLightness {
                    topBubbleColor = topBubbleColor.withMultiplied(hue: 1.0, saturation: 1.0, brightness: 0.85)
                } else {
                    bottomBubbleColor = bottomBubbleColor.withMultiplied(hue: 1.0, saturation: 1.0, brightness: 0.85)
                }
            }
        }
        
        outgoingBubbleFillColor = topBubbleColor
        outgoingBubbleFillGradientColor = bottomBubbleColor
     
        let lightnessColor = topBubbleColor.mixedWith(bottomBubbleColor, alpha: 0.5)
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
            outgoingCheckColor = UIColor(rgb: 0xffffff)
        }
    }
    
    chat = chat.withUpdated(
        defaultWallpaper: defaultWallpaper,
        message: chat.message.withUpdated(
            incoming: chat.message.incoming.withUpdated(
                linkTextColor: accentColor,
                linkHighlightColor: accentColor?.withAlphaComponent(0.5),
                accentTextColor: accentColor,
                accentControlColor: accentColor,
                mediaActiveControlColor: accentColor,
                mediaInactiveControlColor: accentColor?.withAlphaComponent(0.4),
                fileTitleColor: accentColor,
                polls: chat.message.incoming.polls.withUpdated(
                    radioProgress: accentColor,
                    highlight: accentColor?.withAlphaComponent(0.12),
                    bar: accentColor
                ),
                textSelectionColor: accentColor?.withAlphaComponent(0.2),
                textSelectionKnobColor: accentColor
            ),
            outgoing: chat.message.outgoing.withUpdated(
                bubble: chat.message.outgoing.bubble.withUpdated(
                    withWallpaper: chat.message.outgoing.bubble.withWallpaper.withUpdated(
                        fill: outgoingBubbleFillColor,
                        gradientFill: outgoingBubbleFillGradientColor,
                        highlightedFill: outgoingBubbleFillColor?.withMultipliedBrightnessBy(1.421),
                        stroke: .clear
                    ),
                    withoutWallpaper: chat.message.outgoing.bubble.withoutWallpaper.withUpdated(
                        fill: outgoingBubbleFillColor,
                        gradientFill: outgoingBubbleFillGradientColor,
                        highlightedFill: outgoingBubbleFillColor?.withMultipliedBrightnessBy(1.421),
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
                polls: chat.message.outgoing.polls.withUpdated(radioButton: outgoingPrimaryTextColor, radioProgress: outgoingPrimaryTextColor, highlight: outgoingPrimaryTextColor?.withAlphaComponent(0.12), separator: outgoingSecondaryTextColor, bar: outgoingPrimaryTextColor)
            ),
            infoLinkTextColor: accentColor,
            outgoingCheckColor: outgoingCheckColor,
            selectionControlColors: chat.message.selectionControlColors.withUpdated(fillColor: accentColor, foregroundColor: badgeTextColor)
        ),
        inputPanel: chat.inputPanel.withUpdated(
            panelControlAccentColor: accentColor,
            actionControlFillColor: accentColor,
            actionControlForegroundColor: secondaryBadgeTextColor,
            mediaRecordingControl: chat.inputPanel.mediaRecordingControl.withUpdated(
                buttonColor: accentColor,
                micLevelColor: accentColor?.withAlphaComponent(0.2),
                activeIconColor: secondaryBadgeTextColor
            )
        ),
        historyNavigation: chat.historyNavigation.withUpdated(
            badgeBackgroundColor: accentColor,
            badgeStrokeColor: accentColor,
            badgeTextColor: badgeTextColor
        )
    )
    
    return PresentationTheme(
        name: title.flatMap { .custom($0) } ?? theme.name,
        index: theme.index,
        referenceTheme: theme.referenceTheme,
        overallDarkAppearance: theme.overallDarkAppearance,
        intro: intro,
        passcode: theme.passcode,
        rootController: rootController,
        list: list,
        chatList: chatList,
        chat: chat,
        actionSheet: actionSheet,
        contextMenu: theme.contextMenu,
        inAppNotification: theme.inAppNotification,
        preview: theme.preview
    )
}

public func makeDefaultDarkPresentationTheme(extendingThemeReference: PresentationThemeReference? = nil, preview: Bool) -> PresentationTheme {
    let rootTabBar = PresentationThemeRootTabBar(
        backgroundColor: UIColor(rgb: 0x1c1c1d),
        separatorColor: UIColor(rgb: 0x3d3d40),
        iconColor: UIColor(rgb: 0x828282),
        selectedIconColor: UIColor(rgb: 0xffffff),
        textColor: UIColor(rgb: 0x828282),
        selectedTextColor: UIColor(rgb: 0xffffff),
        badgeBackgroundColor:  UIColor(rgb: 0xffffff),
        badgeStrokeColor: UIColor(rgb: 0x1c1c1d),
        badgeTextColor:  UIColor(rgb: 0x000000)
    )

    let rootNavigationBar = PresentationThemeRootNavigationBar(
        buttonColor: UIColor(rgb: 0xffffff),
        disabledButtonColor: UIColor(rgb: 0x525252),
        primaryTextColor: UIColor(rgb: 0xffffff),
        secondaryTextColor: UIColor(rgb: 0xffffff, alpha: 0.5),
        controlColor: UIColor(rgb: 0x767676),
        accentTextColor: UIColor(rgb: 0xffffff),
        backgroundColor: UIColor(rgb: 0x1c1c1d),
        separatorColor: UIColor(rgb: 0x3d3d40),
        badgeBackgroundColor:  UIColor(rgb: 0xffffff),
        badgeStrokeColor: UIColor(rgb: 0x1c1c1d),
        badgeTextColor:  UIColor(rgb: 0x000000),
        segmentedBackgroundColor: UIColor(rgb: 0x3a3b3d),
        segmentedForegroundColor: UIColor(rgb: 0x6f7075),
        segmentedTextColor: UIColor(rgb: 0xffffff),
        segmentedDividerColor: UIColor(rgb: 0x505155)
    )

    let navigationSearchBar = PresentationThemeNavigationSearchBar(
        backgroundColor: UIColor(rgb: 0x1c1c1d),
        accentColor: UIColor(rgb: 0xffffff),
        inputFillColor: UIColor(rgb: 0x0f0f0f),
        inputTextColor: UIColor(rgb: 0xffffff),
        inputPlaceholderTextColor: UIColor(rgb: 0x8f8f8f),
        inputIconColor: UIColor(rgb: 0x8f8f8f),
        inputClearButtonColor: UIColor(rgb: 0x8f8f8f),
        separatorColor: UIColor(rgb: 0x3d3d40)
    )

    let intro = PresentationThemeIntro(
        statusBarStyle: .white,
        primaryTextColor: UIColor(rgb: 0xffffff),
        accentTextColor: UIColor(rgb: 0xffffff),
        disabledTextColor: UIColor(rgb: 0x525252),
        startButtonColor: UIColor(rgb: 0xffffff),
        dotColor: UIColor(rgb: 0x5e5e5e)
    )

    let passcode = PresentationThemePasscode(
        backgroundColors: PresentationThemeGradientColors(topColor: UIColor(rgb: 0x000000), bottomColor: UIColor(rgb: 0x000000)),
        buttonColor: UIColor(rgb: 0x1c1c1d)
    )

    let rootController = PresentationThemeRootController(
        statusBarStyle: .white,
        tabBar: rootTabBar,
        navigationBar: rootNavigationBar,
        navigationSearchBar: navigationSearchBar,
        keyboardColor: .dark
    )

    let switchColors = PresentationThemeSwitch(
        frameColor: UIColor(rgb: 0x39393d),
        handleColor: UIColor(rgb: 0x121212),
        contentColor: UIColor(rgb: 0x67ce67),
        positiveColor: UIColor(rgb: 0x08a723),
        negativeColor: UIColor(rgb: 0xeb5545)
    )

    let list = PresentationThemeList(
        blocksBackgroundColor: UIColor(rgb: 0x000000),
        plainBackgroundColor: UIColor(rgb: 0x000000),
        itemPrimaryTextColor: UIColor(rgb: 0xffffff),
        itemSecondaryTextColor: UIColor(rgb: 0x98989e),
        itemDisabledTextColor: UIColor(rgb: 0x8f8f8f),
        itemAccentColor: UIColor(rgb: 0xffffff),
        itemHighlightedColor: UIColor(rgb: 0x28b772),
        itemDestructiveColor: UIColor(rgb: 0xeb5545),
        itemPlaceholderTextColor: UIColor(rgb: 0x4d4d4d),
        itemBlocksBackgroundColor: UIColor(rgb: 0x1c1c1d),
        itemHighlightedBackgroundColor: UIColor(rgb: 0x313135),
        itemBlocksSeparatorColor: UIColor(rgb: 0x3d3d40),
        itemPlainSeparatorColor: UIColor(rgb: 0x3d3d40),
        disclosureArrowColor: UIColor(rgb: 0xffffff, alpha: 0.28),
        sectionHeaderTextColor: UIColor(rgb: 0x8d8e93),
        freeTextColor: UIColor(rgb: 0x8d8e93),
        freeTextErrorColor: UIColor(rgb: 0xcf3030),
        freeTextSuccessColor: UIColor(rgb: 0x30cf30),
        freeMonoIconColor: UIColor(rgb: 0x8d8e93),
        itemSwitchColors: switchColors,
        itemDisclosureActions: PresentationThemeItemDisclosureActions(
            neutral1: PresentationThemeFillForeground(fillColor: UIColor(rgb: 0x666666), foregroundColor: UIColor(rgb: 0xffffff)),
            neutral2: PresentationThemeFillForeground(fillColor: UIColor(rgb: 0xcd7800), foregroundColor: UIColor(rgb: 0xffffff)),
            destructive: PresentationThemeFillForeground(fillColor: UIColor(rgb: 0xc70c0c), foregroundColor: UIColor(rgb: 0xffffff)),
            constructive: PresentationThemeFillForeground(fillColor: UIColor(rgb: 0x08a723), foregroundColor: UIColor(rgb: 0xffffff)),
            accent: PresentationThemeFillForeground(fillColor: UIColor(rgb: 0x666666), foregroundColor: UIColor(rgb: 0xffffff)),
            warning: PresentationThemeFillForeground(fillColor: UIColor(rgb: 0xcd7800), foregroundColor: UIColor(rgb: 0xffffff)),
            inactive: PresentationThemeFillForeground(fillColor: UIColor(rgb: 0x666666), foregroundColor: UIColor(rgb: 0xffffff))
        ),
        itemCheckColors: PresentationThemeFillStrokeForeground(
            fillColor: UIColor(rgb: 0xffffff),
            strokeColor: UIColor(rgb: 0xffffff, alpha: 0.5),
            foregroundColor:  UIColor(rgb: 0x000000)
        ),
        controlSecondaryColor: UIColor(rgb: 0xffffff, alpha: 0.5),
        freeInputField: PresentationInputFieldTheme(
            backgroundColor: UIColor(rgb: 0xffffff, alpha: 0.5),
            strokeColor: UIColor(rgb: 0xffffff, alpha: 0.5),
            placeholderColor: UIColor(rgb: 0x4d4d4d),
            primaryColor: UIColor(rgb: 0xffffff),
            controlColor: UIColor(rgb: 0x4d4d4d)
        ),
        freePlainInputField: PresentationInputFieldTheme(
            backgroundColor: UIColor(rgb: 0xffffff, alpha: 0.5),
            strokeColor: UIColor(rgb: 0xffffff, alpha: 0.5),
            placeholderColor: UIColor(rgb: 0x4d4d4d),
            primaryColor: UIColor(rgb: 0xffffff),
            controlColor: UIColor(rgb: 0x4d4d4d)
        ),
        mediaPlaceholderColor: UIColor(rgb: 0x1c1c1d),
        scrollIndicatorColor: UIColor(rgb: 0xffffff, alpha: 0.3),
        pageIndicatorInactiveColor: UIColor(white: 1.0, alpha: 0.3),
        inputClearButtonColor: UIColor(rgb: 0x8b9197),
        itemBarChart: PresentationThemeItemBarChart(color1: UIColor(rgb: 0xffffff), color2: UIColor(rgb: 0x929196), color3: UIColor(rgb: 0x333333))
    )

    let chatList = PresentationThemeChatList(
        backgroundColor: UIColor(rgb: 0x000000),
        itemSeparatorColor: UIColor(rgb: 0x3d3d40),
        itemBackgroundColor: UIColor(rgb: 0x000000),
        pinnedItemBackgroundColor: UIColor(rgb: 0x1c1c1d),
        itemHighlightedBackgroundColor: UIColor(rgb: 0x191919),
        itemSelectedBackgroundColor: UIColor(rgb: 0x191919),
        titleColor: UIColor(rgb: 0xffffff),
        secretTitleColor: UIColor(rgb: 0x00b12c),
        dateTextColor: UIColor(rgb: 0x8d8e93),
        authorNameColor: UIColor(rgb: 0xffffff),
        messageTextColor: UIColor(rgb: 0x8d8e93),
        messageHighlightedTextColor: UIColor(rgb: 0xffffff),
        messageDraftTextColor: UIColor(rgb: 0xdd4b39),
        checkmarkColor: UIColor(rgb: 0xffffff),
        pendingIndicatorColor: UIColor(rgb: 0xffffff),
        failedFillColor: UIColor(rgb: 0xeb5545),
        failedForegroundColor: UIColor(rgb: 0xffffff),
        muteIconColor: UIColor(rgb: 0x8d8e93),
        unreadBadgeActiveBackgroundColor: UIColor(rgb: 0xffffff),
        unreadBadgeActiveTextColor:  UIColor(rgb: 0x000000),
        unreadBadgeInactiveBackgroundColor: UIColor(rgb: 0x666666),
        unreadBadgeInactiveTextColor:UIColor(rgb: 0x000000),
        pinnedBadgeColor: UIColor(rgb: 0x767677),
        pinnedSearchBarColor: UIColor(rgb: 0x272728),
        regularSearchBarColor: UIColor(rgb: 0x272728),
        sectionHeaderFillColor: UIColor(rgb: 0x1c1c1d),
        sectionHeaderTextColor: UIColor(rgb: 0xffffff),
        verifiedIconFillColor: UIColor(rgb: 0xffffff),
        verifiedIconForegroundColor:  UIColor(rgb: 0x000000),
        secretIconColor: UIColor(rgb: 0x00b12c),
        pinnedArchiveAvatarColor: PresentationThemeArchiveAvatarColors(backgroundColors: PresentationThemeGradientColors(topColor: UIColor(rgb: 0x72d5fd), bottomColor: UIColor(rgb: 0x2a9ef1)), foregroundColor: UIColor(rgb: 0xffffff)),
        unpinnedArchiveAvatarColor: PresentationThemeArchiveAvatarColors(backgroundColors: PresentationThemeGradientColors(topColor: UIColor(rgb: 0x666666), bottomColor: UIColor(rgb: 0x666666)), foregroundColor: UIColor(rgb: 0x000000)),
        onlineDotColor: UIColor(rgb: 0x4cc91f)
    )
    
    let message = PresentationThemeChatMessage(
        incoming: PresentationThemePartedColors(bubble: PresentationThemeBubbleColor(withWallpaper: PresentationThemeBubbleColorComponents(fill: UIColor(rgb: 0x262628), highlightedFill: UIColor(rgb: 0x353539), stroke: UIColor(rgb: 0x262628)), withoutWallpaper: PresentationThemeBubbleColorComponents(fill: UIColor(rgb: 0x262628), highlightedFill: UIColor(rgb: 0x353539), stroke: UIColor(rgb: 0x262628))), primaryTextColor: UIColor(rgb: 0xffffff), secondaryTextColor: UIColor(rgb: 0xffffff, alpha: 0.5), linkTextColor: UIColor(rgb: 0xffffff), linkHighlightColor: UIColor(rgb: 0xffffff, alpha: 0.5), scamColor: UIColor(rgb: 0xeb5545), textHighlightColor: UIColor(rgb: 0xf5c038), accentTextColor: UIColor(rgb: 0xffffff), accentControlColor: UIColor(rgb: 0xffffff), mediaActiveControlColor: UIColor(rgb: 0xffffff), mediaInactiveControlColor: UIColor(rgb: 0xffffff, alpha: 0.4), mediaControlInnerBackgroundColor: UIColor(rgb: 0x262628), pendingActivityColor: UIColor(rgb: 0xffffff, alpha: 0.5), fileTitleColor: UIColor(rgb: 0xffffff), fileDescriptionColor: UIColor(rgb: 0xffffff, alpha: 0.5), fileDurationColor: UIColor(rgb: 0xffffff, alpha: 0.5), mediaPlaceholderColor: UIColor(rgb: 0x1f1f1f).mixedWith(UIColor(rgb: 0xffffff), alpha: 0.05), polls: PresentationThemeChatBubblePolls(radioButton: UIColor(rgb: 0x737373), radioProgress: UIColor(rgb: 0xffffff), highlight: UIColor(rgb: 0xffffff, alpha: 0.12), separator: UIColor(rgb: 0x000000), bar: UIColor(rgb: 0xffffff)), actionButtonsFillColor: PresentationThemeVariableColor(withWallpaper: UIColor(rgb: 0x000000, alpha: 0.5), withoutWallpaper: UIColor(rgb: 0x000000, alpha: 0.5)), actionButtonsStrokeColor: PresentationThemeVariableColor(color: UIColor(rgb: 0xb2b2b2, alpha: 0.18)), actionButtonsTextColor: PresentationThemeVariableColor(color: UIColor(rgb: 0xffffff)), textSelectionColor: UIColor(rgb: 0xffffff, alpha: 0.2), textSelectionKnobColor: UIColor(rgb: 0xffffff)),
        outgoing: PresentationThemePartedColors(bubble: PresentationThemeBubbleColor(withWallpaper: PresentationThemeBubbleColorComponents(fill:  UIColor(rgb: 0x313131), gradientFill:  UIColor(rgb: 0x313131), highlightedFill: UIColor(rgb: 0x464646), stroke:  UIColor(rgb: 0x313131)), withoutWallpaper: PresentationThemeBubbleColorComponents(fill:  UIColor(rgb: 0x313131), gradientFill:  UIColor(rgb: 0x313131), highlightedFill: UIColor(rgb: 0x464646), stroke:  UIColor(rgb: 0x313131))), primaryTextColor: UIColor(rgb: 0xffffff), secondaryTextColor: UIColor(rgb: 0xffffff, alpha: 0.5), linkTextColor: UIColor(rgb: 0xffffff), linkHighlightColor: UIColor(rgb: 0xffffff, alpha: 0.5), scamColor: UIColor(rgb: 0xeb5545), textHighlightColor: UIColor(rgb: 0xf5c038), accentTextColor: UIColor(rgb: 0xffffff), accentControlColor: UIColor(rgb: 0xffffff), mediaActiveControlColor: UIColor(rgb: 0xffffff), mediaInactiveControlColor: UIColor(rgb: 0xffffff, alpha: 0.5), mediaControlInnerBackgroundColor:  UIColor(rgb: 0x313131), pendingActivityColor: UIColor(rgb: 0xffffff, alpha: 0.5), fileTitleColor: UIColor(rgb: 0xffffff), fileDescriptionColor: UIColor(rgb: 0xffffff, alpha: 0.5), fileDurationColor: UIColor(rgb: 0xffffff, alpha: 0.5), mediaPlaceholderColor: UIColor(rgb: 0x313131).mixedWith(UIColor(rgb: 0xffffff), alpha: 0.05), polls: PresentationThemeChatBubblePolls(radioButton: UIColor(rgb: 0xffffff), radioProgress: UIColor(rgb: 0xffffff), highlight: UIColor(rgb: 0xffffff).withAlphaComponent(0.12), separator: UIColor(rgb: 0xffffff, alpha: 0.5), bar: UIColor(rgb: 0xffffff)), actionButtonsFillColor: PresentationThemeVariableColor(withWallpaper: UIColor(rgb: 0x000000, alpha: 0.5), withoutWallpaper: UIColor(rgb: 0x000000, alpha: 0.5)), actionButtonsStrokeColor: PresentationThemeVariableColor(color: UIColor(rgb: 0xb2b2b2, alpha: 0.18)), actionButtonsTextColor: PresentationThemeVariableColor(color: UIColor(rgb: 0xffffff)), textSelectionColor: UIColor(rgb: 0xffffff, alpha: 0.2), textSelectionKnobColor: UIColor(rgb: 0xffffff)),
        freeform: PresentationThemeBubbleColor(withWallpaper: PresentationThemeBubbleColorComponents(fill: UIColor(rgb: 0x1f1f1f), highlightedFill: UIColor(rgb: 0x2a2a2a), stroke: UIColor(rgb: 0x1f1f1f)), withoutWallpaper: PresentationThemeBubbleColorComponents(fill: UIColor(rgb: 0x1f1f1f), highlightedFill: UIColor(rgb: 0x2a2a2a), stroke: UIColor(rgb: 0x1f1f1f))),
        infoPrimaryTextColor: UIColor(rgb: 0xffffff),
        infoLinkTextColor: UIColor(rgb: 0xffffff),
        outgoingCheckColor: UIColor(rgb: 0xffffff),
        mediaDateAndStatusFillColor: UIColor(white: 0.0, alpha: 0.5),
        mediaDateAndStatusTextColor: UIColor(rgb: 0xffffff),
        shareButtonFillColor: PresentationThemeVariableColor(withWallpaper: UIColor(rgb: 0x000000, alpha: 0.5), withoutWallpaper: UIColor(rgb: 0x000000, alpha: 0.5)),
        shareButtonStrokeColor: PresentationThemeVariableColor(withWallpaper: UIColor(rgb: 0xb2b2b2, alpha: 0.18), withoutWallpaper: UIColor(rgb: 0xb2b2b2, alpha: 0.18)),
        shareButtonForegroundColor: PresentationThemeVariableColor(withWallpaper: UIColor(rgb: 0xb2b2b2), withoutWallpaper: UIColor(rgb: 0xb2b2b2)),
        mediaOverlayControlColors: PresentationThemeFillForeground(fillColor: UIColor(rgb: 0x000000, alpha: 0.6), foregroundColor: UIColor(rgb: 0xffffff)),
        selectionControlColors: PresentationThemeFillStrokeForeground(fillColor: UIColor(rgb: 0xffffff), strokeColor: UIColor(rgb: 0xffffff), foregroundColor:  UIColor(rgb: 0x000000)),
        deliveryFailedColors: PresentationThemeFillForeground(fillColor: UIColor(rgb: 0xeb5545), foregroundColor: UIColor(rgb: 0xffffff)),
        mediaHighlightOverlayColor: UIColor(white: 1.0, alpha: 0.6)
    )
    
    let serviceMessage = PresentationThemeServiceMessage(
        components: PresentationThemeServiceMessageColor(withDefaultWallpaper: PresentationThemeServiceMessageColorComponents(fill: UIColor(rgb: 0x1f1f1f, alpha: 1.0), primaryText: UIColor(rgb: 0xffffff), linkHighlight: UIColor(rgb: 0xffffff, alpha: 0.12), scam: UIColor(rgb: 0xeb5545), dateFillStatic: UIColor(rgb: 0x000000, alpha: 0.6), dateFillFloating: UIColor(rgb: 0x000000, alpha: 0.2)), withCustomWallpaper: PresentationThemeServiceMessageColorComponents(fill: UIColor(rgb: 0x1f1f1f, alpha: 1.0), primaryText: UIColor(rgb: 0xffffff), linkHighlight: UIColor(rgb: 0xffffff, alpha: 0.12), scam: UIColor(rgb: 0xeb5545), dateFillStatic: UIColor(rgb: 0x000000, alpha: 0.6), dateFillFloating: UIColor(rgb: 0x000000, alpha: 0.2))),
        unreadBarFillColor: UIColor(rgb: 0x1b1b1b),
        unreadBarStrokeColor: UIColor(rgb: 0x1b1b1b),
        unreadBarTextColor: UIColor(rgb: 0xffffff),
        dateTextColor: PresentationThemeVariableColor(color: UIColor(rgb: 0xffffff))
    )

    let inputPanelMediaRecordingControl = PresentationThemeChatInputPanelMediaRecordingControl(
        buttonColor: UIColor(rgb: 0xffffff),
        micLevelColor: UIColor(rgb: 0xffffff, alpha: 0.2),
        activeIconColor:  UIColor(rgb: 0x000000)
    )

    let inputPanel = PresentationThemeChatInputPanel(
        panelBackgroundColor: UIColor(rgb: 0x1c1c1d),
        panelBackgroundColorNoWallpaper: UIColor(rgb: 0x000000),
        panelSeparatorColor: UIColor(rgb: 0x3d3d40),
        panelControlAccentColor: UIColor(rgb: 0xffffff),
        panelControlColor: UIColor(rgb: 0x808080),
        panelControlDisabledColor: UIColor(rgb: 0x808080, alpha: 0.5),
        panelControlDestructiveColor: UIColor(rgb: 0xff3b30),
        inputBackgroundColor: UIColor(rgb: 0x060606),
        inputStrokeColor: UIColor(rgb: 0x353537),
        inputPlaceholderColor: UIColor(rgb: 0x7b7b7b),
        inputTextColor: UIColor(rgb: 0xffffff),
        inputControlColor: UIColor(rgb: 0x7b7b7b),
        actionControlFillColor: UIColor(rgb: 0xffffff),
        actionControlForegroundColor:  UIColor(rgb: 0x000000),
        primaryTextColor: UIColor(rgb: 0xffffff),
        secondaryTextColor: UIColor(rgb: 0xffffff, alpha: 0.5),
        mediaRecordingDotColor: UIColor(rgb: 0xeb5545),
        mediaRecordingControl: inputPanelMediaRecordingControl
    )

    let inputMediaPanel = PresentationThemeInputMediaPanel(
        panelSeparatorColor: UIColor(rgb: 0x3d3d40),
        panelIconColor: UIColor(rgb: 0x808080),
        panelHighlightedIconBackgroundColor: UIColor(rgb: 0x262628),
        stickersBackgroundColor: UIColor(rgb: 0x000000),
        stickersSectionTextColor: UIColor(rgb: 0x7b7b7b),
        stickersSearchBackgroundColor: UIColor(rgb: 0x1c1c1d),
        stickersSearchPlaceholderColor: UIColor(rgb: 0x8d8e93),
        stickersSearchPrimaryColor: UIColor(rgb: 0xffffff),
        stickersSearchControlColor: UIColor(rgb: 0x8d8e93),
        gifsBackgroundColor: UIColor(rgb: 0x000000)
    )

    let inputButtonPanel = PresentationThemeInputButtonPanel(
        panelSeparatorColor: UIColor(rgb: 0x3d3d40),
        panelBackgroundColor: UIColor(rgb: 0x141414),
        buttonFillColor: UIColor(rgb: 0x5a5a5a),
        buttonStrokeColor: UIColor(rgb: 0x0c0c0c),
        buttonHighlightedFillColor: UIColor(rgb: 0x5a5a5a, alpha: 0.7),
        buttonHighlightedStrokeColor: UIColor(rgb: 0x0c0c0c),
        buttonTextColor: UIColor(rgb: 0xffffff)
    )

    let historyNavigation = PresentationThemeChatHistoryNavigation(
        fillColor: UIColor(rgb: 0x1c1c1d),
        strokeColor: UIColor(rgb: 0x3d3d40),
        foregroundColor: UIColor(rgb: 0xffffff),
        badgeBackgroundColor: UIColor(rgb: 0xffffff),
        badgeStrokeColor: UIColor(rgb: 0xffffff),
        badgeTextColor:  UIColor(rgb: 0x000000)
    )

    let chat = PresentationThemeChat(
        defaultWallpaper: .color(0x000000),
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
        opaqueItemBackgroundColor: UIColor(rgb: 0x1c1c1d),
        itemBackgroundColor: UIColor(rgb: 0x1c1c1d, alpha: 0.8),
        opaqueItemHighlightedBackgroundColor: UIColor(white: 0.0, alpha: 1.0),
        itemHighlightedBackgroundColor: UIColor(rgb: 0x000000, alpha: 0.5),
        opaqueItemSeparatorColor: UIColor(rgb: 0x3d3d40),
        standardActionTextColor: UIColor(rgb: 0xffffff),
        destructiveActionTextColor: UIColor(rgb: 0xeb5545),
        disabledActionTextColor: UIColor(rgb: 0x4d4d4d),
        primaryTextColor: UIColor(rgb: 0xffffff),
        secondaryTextColor: UIColor(rgb: 0x5e5e5e),
        controlAccentColor: UIColor(rgb: 0xffffff),
        inputBackgroundColor: UIColor(rgb: 0x0f0f0f),
        inputHollowBackgroundColor: UIColor(rgb: 0x0f0f0f),
        inputBorderColor: UIColor(rgb: 0x0f0f0f),
        inputPlaceholderColor: UIColor(rgb: 0x8f8f8f),
        inputTextColor: UIColor(rgb: 0xffffff),
        inputClearButtonColor: UIColor(rgb: 0x8f8f8f),
        checkContentColor:  UIColor(rgb: 0x000000)
    )
    
    let contextMenu = PresentationThemeContextMenu(
        dimColor: UIColor(rgb: 0x000000, alpha: 0.6),
        backgroundColor: UIColor(rgb: 0x252525, alpha: 0.78),
        itemSeparatorColor: UIColor(rgb: 0xffffff, alpha: 0.15),
        sectionSeparatorColor: UIColor(rgb: 0x000000, alpha: 0.2),
        itemBackgroundColor: UIColor(rgb: 0x000000, alpha: 0.0),
        itemHighlightedBackgroundColor: UIColor(rgb: 0xffffff, alpha: 0.15),
        primaryColor: UIColor(rgb: 0xffffff, alpha: 1.0),
        secondaryColor: UIColor(rgb: 0xffffff, alpha: 0.8),
        destructiveColor: UIColor(rgb: 0xeb5545)
    )

    let inAppNotification = PresentationThemeInAppNotification(
        fillColor: UIColor(rgb: 0x1c1c1d),
        primaryTextColor: UIColor(rgb: 0xffffff),
        expandedNotification: PresentationThemeExpandedNotification(
            backgroundType: .dark,
            navigationBar: PresentationThemeExpandedNotificationNavigationBar(
                backgroundColor: UIColor(rgb: 0x1c1c1d),
                primaryTextColor: UIColor(rgb: 0xffffff),
                controlColor: UIColor(rgb: 0xffffff),
                separatorColor: UIColor(rgb: 0x000000)
            )
        )
    )

    return PresentationTheme(
        name: extendingThemeReference?.name ?? .builtin(.night),
        index: extendingThemeReference?.index ?? PresentationThemeReference.builtin(.night).index,
        referenceTheme: .night,
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
