import Foundation
import UIKit
import TelegramUIPreferences

private func makeDarkPresentationTheme(accentColor: UIColor, baseColor: PresentationThemeBaseColor?, preview: Bool) -> PresentationTheme {
    let destructiveColor: UIColor = UIColor(rgb: 0xeb5545)
    let constructiveColor: UIColor = UIColor(rgb: 0x08a723)
    let secretColor: UIColor = UIColor(rgb: 0x00b12c)
    
    let badgeFillColor: UIColor
    let badgeTextColor: UIColor
    let secondaryBadgeTextColor: UIColor
    let outgoingBubbleFillColor: UIColor
    let outgoingBubbleHighlightedFillColor: UIColor
    let outgoingScamColor: UIColor
    
    let outgoingPrimaryTextColor: UIColor
    let outgoingSecondaryTextColor: UIColor
    let outgoingLinkTextColor: UIColor
    let outgoingCheckColor: UIColor
    
    var accentColor = accentColor
    
    if accentColor.rgb == UIColor.white.rgb {
        badgeFillColor = .white
        badgeTextColor = .black
        secondaryBadgeTextColor = .black
        outgoingBubbleFillColor = UIColor(rgb: 0x313131)
        outgoingBubbleHighlightedFillColor = UIColor(rgb: 0x464646)
        outgoingScamColor = destructiveColor
        
        outgoingPrimaryTextColor = .white
        outgoingSecondaryTextColor = UIColor(rgb: 0xffffff, alpha: 0.5)
        outgoingLinkTextColor = .white
        outgoingCheckColor = UIColor(rgb: 0xffffff, alpha: 0.5)
    } else {
        badgeFillColor = destructiveColor
        badgeTextColor = .white
        outgoingBubbleFillColor = accentColor
        outgoingBubbleHighlightedFillColor = accentColor.withMultipliedBrightnessBy(1.421)
        
        let lightness = accentColor.lightness
        if lightness > 0.7 {
            outgoingScamColor = .black
            
            secondaryBadgeTextColor = .black
            outgoingPrimaryTextColor = .black
            outgoingSecondaryTextColor = UIColor(rgb: 0x000000, alpha: 0.5)
            outgoingLinkTextColor = .black
            outgoingCheckColor = UIColor(rgb: 0x000000, alpha: 0.5)
        } else {
            outgoingScamColor = .white
            
            secondaryBadgeTextColor = .white
            outgoingPrimaryTextColor = .white
            outgoingSecondaryTextColor = UIColor(rgb: 0xffffff, alpha: 0.5)
            outgoingLinkTextColor = .white
            outgoingCheckColor = UIColor(rgb: 0xffffff, alpha: 0.5)
            
            let hsv = accentColor.hsv
            accentColor = UIColor(hue: hsv.0, saturation: hsv.1, brightness: max(hsv.2, 0.55), alpha: 1.0)
        }
    }

    let rootTabBar = PresentationThemeRootTabBar(
        backgroundColor: UIColor(rgb: 0x1c1c1d),
        separatorColor: UIColor(rgb: 0x3d3d40),
        iconColor: UIColor(rgb: 0x828282),
        selectedIconColor: accentColor,
        textColor: UIColor(rgb: 0x828282),
        selectedTextColor: accentColor,
        badgeBackgroundColor: badgeFillColor,
        badgeStrokeColor: UIColor(rgb: 0x1c1c1d),
        badgeTextColor: badgeTextColor
    )

    let rootNavigationBar = PresentationThemeRootNavigationBar(
        buttonColor: accentColor,
        disabledButtonColor: UIColor(rgb: 0x525252),
        primaryTextColor: .white,
        secondaryTextColor: UIColor(rgb: 0xffffff, alpha: 0.5),
        controlColor: UIColor(rgb: 0x767676),
        accentTextColor: accentColor,
        backgroundColor: UIColor(rgb: 0x1c1c1d),
        separatorColor: UIColor(rgb: 0x3d3d40),
        badgeBackgroundColor: badgeFillColor,
        badgeStrokeColor: UIColor(rgb: 0x1c1c1d),
        badgeTextColor: badgeTextColor
    )

    let navigationSearchBar = PresentationThemeNavigationSearchBar(
        backgroundColor: UIColor(rgb: 0x1c1c1d),
        accentColor: accentColor,
        inputFillColor: UIColor(rgb: 0x0f0f0f),
        inputTextColor: .white,
        inputPlaceholderTextColor: UIColor(rgb: 0x8f8f8f),
        inputIconColor: UIColor(rgb: 0x8f8f8f),
        inputClearButtonColor: UIColor(rgb: 0x8f8f8f),
        separatorColor: UIColor(rgb: 0x3d3d40)
    )

    let intro = PresentationThemeIntro(
        statusBarStyle: .white,
        startButtonColor: accentColor,
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
        frameColor: UIColor(rgb: 0x5a5a5e),
        handleColor: UIColor(rgb: 0x121212),
        contentColor: UIColor(rgb: 0x77d572),
        positiveColor: constructiveColor,
        negativeColor: destructiveColor
    )

    let list = PresentationThemeList(
        blocksBackgroundColor: UIColor(rgb: 0x000000),
        plainBackgroundColor: UIColor(rgb: 0x000000),
        itemPrimaryTextColor: UIColor(rgb: 0xffffff),
        itemSecondaryTextColor: UIColor(rgb: 0x8f8f8f),
        itemDisabledTextColor: UIColor(rgb: 0x4d4d4d),
        itemAccentColor: accentColor,
        itemHighlightedColor: UIColor(rgb: 0x28b772),
        itemDestructiveColor: destructiveColor,
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
            neutral1: PresentationThemeFillForeground(fillColor: UIColor(rgb: 0x666666), foregroundColor: .white),
            neutral2: PresentationThemeFillForeground(fillColor: UIColor(rgb: 0xcd7800), foregroundColor: .white),
            destructive: PresentationThemeFillForeground(fillColor: UIColor(rgb: 0xc70c0c), foregroundColor: .white),
            constructive: PresentationThemeFillForeground(fillColor: constructiveColor, foregroundColor: .white),
            accent: PresentationThemeFillForeground(fillColor: UIColor(rgb: 0x666666), foregroundColor: .white),
            warning: PresentationThemeFillForeground(fillColor: UIColor(rgb: 0xcd7800), foregroundColor: .white),
            inactive: PresentationThemeFillForeground(fillColor: UIColor(rgb: 0x666666), foregroundColor: .white)
        ),
        itemCheckColors: PresentationThemeFillStrokeForeground(
            fillColor: accentColor,
            strokeColor: UIColor(rgb: 0xffffff, alpha: 0.5),
            foregroundColor: secondaryBadgeTextColor
        ),
        controlSecondaryColor: UIColor(rgb: 0xffffff, alpha: 0.5),
        freeInputField: PresentationInputFieldTheme(
            backgroundColor: UIColor(rgb: 0xffffff, alpha: 0.5),
            strokeColor: UIColor(rgb: 0xffffff, alpha: 0.5),
            placeholderColor: UIColor(rgb: 0x4d4d4d),
            primaryColor: .white,
            controlColor: UIColor(rgb: 0x4d4d4d)
        ),
        mediaPlaceholderColor: UIColor(rgb: 0x1c1c1d),
        scrollIndicatorColor: UIColor(white: 1.0, alpha: 0.3),
        pageIndicatorInactiveColor: UIColor(white: 1.0, alpha: 0.3),
        inputClearButtonColor: UIColor(rgb: 0x8b9197)
    )

    let chatList = PresentationThemeChatList(
        backgroundColor: UIColor(rgb: 0x000000),
        itemSeparatorColor: UIColor(rgb: 0x3d3d40),
        itemBackgroundColor: UIColor(rgb: 0x000000),
        pinnedItemBackgroundColor: UIColor(rgb: 0x1c1c1d),
        itemHighlightedBackgroundColor: UIColor(rgb: 0x191919),
        itemSelectedBackgroundColor: UIColor(rgb: 0x191919),
        titleColor: UIColor(rgb: 0xffffff),
        secretTitleColor: secretColor,
        dateTextColor: UIColor(rgb: 0x8e8e92),
        authorNameColor: UIColor(rgb: 0xffffff),
        messageTextColor: UIColor(rgb: 0x8e8e92),
        messageDraftTextColor: UIColor(rgb: 0xdd4b39),
        checkmarkColor: accentColor,
        pendingIndicatorColor: UIColor(rgb: 0xffffff),
        failedFillColor: destructiveColor,
        failedForegroundColor: .white,
        muteIconColor: UIColor(rgb: 0x8e8e92),
        unreadBadgeActiveBackgroundColor: accentColor,
        unreadBadgeActiveTextColor: secondaryBadgeTextColor,
        unreadBadgeInactiveBackgroundColor: UIColor(rgb: 0x666666),
        unreadBadgeInactiveTextColor:UIColor(rgb: 0x000000),
        pinnedBadgeColor: UIColor(rgb: 0x767677),
        pinnedSearchBarColor: UIColor(rgb: 0x272728),
        regularSearchBarColor: UIColor(rgb: 0x272728),
        sectionHeaderFillColor: UIColor(rgb: 0x1c1c1d),
        sectionHeaderTextColor: UIColor(rgb: 0xffffff),
        verifiedIconFillColor: accentColor,
        verifiedIconForegroundColor: badgeTextColor,
        secretIconColor: secretColor,
        pinnedArchiveAvatarColor: PresentationThemeArchiveAvatarColors(backgroundColors: PresentationThemeGradientColors(topColor: UIColor(rgb: 0x72d5fd), bottomColor: UIColor(rgb: 0x2a9ef1)), foregroundColor: .white),
        unpinnedArchiveAvatarColor: PresentationThemeArchiveAvatarColors(backgroundColors: PresentationThemeGradientColors(topColor: UIColor(rgb: 0x666666), bottomColor: UIColor(rgb: 0x666666)), foregroundColor: .black),
        onlineDotColor: UIColor(rgb: 0x4cc91f)
    )
    
    let message = PresentationThemeChatMessage(
        incoming: PresentationThemePartedColors(bubble: PresentationThemeBubbleColor(withWallpaper: PresentationThemeBubbleColorComponents(fill: UIColor(rgb: 0x262628), highlightedFill: UIColor(rgb: 0x353539), stroke: UIColor(rgb: 0x262628)), withoutWallpaper: PresentationThemeBubbleColorComponents(fill: UIColor(rgb: 0x262628), highlightedFill: UIColor(rgb: 0x353539), stroke: UIColor(rgb: 0x262628))), primaryTextColor: .white, secondaryTextColor: UIColor(rgb: 0xffffff, alpha: 0.5), linkTextColor: accentColor, linkHighlightColor: accentColor.withAlphaComponent(0.5), scamColor: destructiveColor, textHighlightColor: UIColor(rgb: 0xffe438), accentTextColor: accentColor, accentControlColor: accentColor, mediaActiveControlColor: accentColor, mediaInactiveControlColor: accentColor.withAlphaComponent(0.4), pendingActivityColor: UIColor(rgb: 0xffffff, alpha: 0.5), fileTitleColor: accentColor, fileDescriptionColor: UIColor(rgb: 0xffffff, alpha: 0.5), fileDurationColor: UIColor(rgb: 0xffffff, alpha: 0.5), mediaPlaceholderColor: UIColor(rgb: 0x1f1f1f).mixedWith(.white, alpha: 0.05), polls: PresentationThemeChatBubblePolls(radioButton: UIColor(rgb: 0x737373), radioProgress: accentColor, highlight: accentColor.withAlphaComponent(0.12), separator: UIColor(rgb: 0x000000), bar: accentColor), actionButtonsFillColor: PresentationThemeVariableColor(withWallpaper: UIColor(rgb: 0x000000, alpha: 0.5), withoutWallpaper: UIColor(rgb: 0x000000, alpha: 0.5)), actionButtonsStrokeColor: PresentationThemeVariableColor(color: UIColor(rgb: 0xb2b2b2, alpha: 0.18)), actionButtonsTextColor: PresentationThemeVariableColor(color: UIColor(rgb: 0xffffff)), textSelectionColor: accentColor.withAlphaComponent(0.2), textSelectionKnobColor: accentColor),
        outgoing: PresentationThemePartedColors(bubble: PresentationThemeBubbleColor(withWallpaper: PresentationThemeBubbleColorComponents(fill: outgoingBubbleFillColor, highlightedFill: outgoingBubbleHighlightedFillColor, stroke: outgoingBubbleFillColor), withoutWallpaper: PresentationThemeBubbleColorComponents(fill: outgoingBubbleFillColor, highlightedFill: outgoingBubbleHighlightedFillColor, stroke: outgoingBubbleFillColor)), primaryTextColor: outgoingPrimaryTextColor, secondaryTextColor: outgoingSecondaryTextColor, linkTextColor: outgoingLinkTextColor, linkHighlightColor: UIColor.white.withAlphaComponent(0.5), scamColor: outgoingScamColor, textHighlightColor: UIColor(rgb: 0xffe438), accentTextColor: outgoingPrimaryTextColor, accentControlColor: outgoingPrimaryTextColor, mediaActiveControlColor: outgoingPrimaryTextColor, mediaInactiveControlColor: outgoingSecondaryTextColor, pendingActivityColor: outgoingSecondaryTextColor, fileTitleColor: outgoingPrimaryTextColor, fileDescriptionColor: outgoingSecondaryTextColor, fileDurationColor: outgoingSecondaryTextColor, mediaPlaceholderColor: UIColor(rgb: 0x313131).mixedWith(.white, alpha: 0.05), polls: PresentationThemeChatBubblePolls(radioButton: outgoingPrimaryTextColor, radioProgress: outgoingPrimaryTextColor, highlight: outgoingPrimaryTextColor.withAlphaComponent(0.12), separator: outgoingSecondaryTextColor, bar: outgoingPrimaryTextColor), actionButtonsFillColor: PresentationThemeVariableColor(withWallpaper: UIColor(rgb: 0x000000, alpha: 0.5), withoutWallpaper: UIColor(rgb: 0x000000, alpha: 0.5)), actionButtonsStrokeColor: PresentationThemeVariableColor(color: UIColor(rgb: 0xb2b2b2, alpha: 0.18)), actionButtonsTextColor: PresentationThemeVariableColor(color: UIColor(rgb: 0xffffff)), textSelectionColor: UIColor.white.withAlphaComponent(0.2), textSelectionKnobColor: UIColor.white),
        freeform: PresentationThemeBubbleColor(withWallpaper: PresentationThemeBubbleColorComponents(fill: UIColor(rgb: 0x1f1f1f), highlightedFill: UIColor(rgb: 0x2a2a2a), stroke: UIColor(rgb: 0x1f1f1f)), withoutWallpaper: PresentationThemeBubbleColorComponents(fill: UIColor(rgb: 0x1f1f1f), highlightedFill: UIColor(rgb: 0x2a2a2a), stroke: UIColor(rgb: 0x1f1f1f))),
        infoPrimaryTextColor: .white,
        infoLinkTextColor: accentColor,
        outgoingCheckColor: outgoingCheckColor,
        mediaDateAndStatusFillColor: UIColor(white: 0.0, alpha: 0.5),
        mediaDateAndStatusTextColor: .white,
        shareButtonFillColor: PresentationThemeVariableColor(withWallpaper: UIColor(rgb: 0x000000, alpha: 0.5), withoutWallpaper: UIColor(rgb: 0x000000, alpha: 0.5)),
        shareButtonStrokeColor: PresentationThemeVariableColor(withWallpaper: UIColor(rgb: 0xb2b2b2, alpha: 0.18), withoutWallpaper: UIColor(rgb: 0xb2b2b2, alpha: 0.18)),
        shareButtonForegroundColor: PresentationThemeVariableColor(withWallpaper: UIColor(rgb: 0xb2b2b2), withoutWallpaper: UIColor(rgb: 0xb2b2b2)),
        mediaOverlayControlColors: PresentationThemeFillForeground(fillColor: UIColor(rgb: 0x000000, alpha: 0.6), foregroundColor: .white),
        selectionControlColors: PresentationThemeFillStrokeForeground(fillColor: accentColor, strokeColor: .white, foregroundColor: badgeTextColor),
        deliveryFailedColors: PresentationThemeFillForeground(fillColor: destructiveColor, foregroundColor: .white),
        mediaHighlightOverlayColor: UIColor(white: 1.0, alpha: 0.6)
    )
    
    let serviceMessage = PresentationThemeServiceMessage(
        components: PresentationThemeServiceMessageColor(withDefaultWallpaper: PresentationThemeServiceMessageColorComponents(fill: UIColor(rgb: 0x1f1f1f, alpha: 1.0), primaryText: UIColor(rgb: 0xffffff), linkHighlight: UIColor(rgb: 0xffffff, alpha: 0.12), scam: destructiveColor, dateFillStatic: UIColor(rgb: 0x1f1f1f, alpha: 1.0), dateFillFloating: UIColor(rgb: 0xffffff, alpha: 0.2)), withCustomWallpaper: PresentationThemeServiceMessageColorComponents(fill: UIColor(rgb: 0x1f1f1f, alpha: 1.0), primaryText: .white, linkHighlight: UIColor(rgb: 0xffffff, alpha: 0.12), scam: destructiveColor, dateFillStatic: UIColor(rgb: 0x1f1f1f, alpha: 1.0), dateFillFloating: UIColor(rgb: 0xffffff, alpha: 0.2))),
        unreadBarFillColor: UIColor(rgb: 0x1b1b1b),
        unreadBarStrokeColor: UIColor(rgb: 0x1b1b1b),
        unreadBarTextColor: .white,
        dateTextColor: PresentationThemeVariableColor(color: .white)
    )

    let inputPanelMediaRecordingControl = PresentationThemeChatInputPanelMediaRecordingControl(
        buttonColor: accentColor,
        micLevelColor: accentColor.withAlphaComponent(0.2),
        activeIconColor: .white
    )

    let inputPanel = PresentationThemeChatInputPanel(
        panelBackgroundColor: UIColor(rgb: 0x1c1c1d),
        panelSeparatorColor: UIColor(rgb: 0x3d3d40),
        panelControlAccentColor: accentColor,
        panelControlColor: UIColor(rgb: 0x808080),
        panelControlDisabledColor: UIColor(rgb: 0x808080, alpha: 0.5),
        panelControlDestructiveColor: UIColor(rgb: 0xff3b30),
        inputBackgroundColor: UIColor(rgb: 0x060606),
        inputStrokeColor: UIColor(rgb: 0x353537),
        inputPlaceholderColor: UIColor(rgb: 0x7b7b7b),
        inputTextColor: .white,
        inputControlColor: UIColor(rgb: 0x7b7b7b),
        actionControlFillColor: accentColor,
        actionControlForegroundColor: badgeTextColor,
        primaryTextColor: .white,
        secondaryTextColor: UIColor(rgb: 0xffffff, alpha: 0.5),
        mediaRecordingDotColor: destructiveColor,
        mediaRecordingControl: inputPanelMediaRecordingControl
    )

    let inputMediaPanel = PresentationThemeInputMediaPanel(
        panelSeparatorColor: UIColor(rgb: 0x3d3d40),
        panelIconColor: UIColor(rgb: 0x808080),
        panelHighlightedIconBackgroundColor: UIColor(rgb: 0x000000),
        stickersBackgroundColor: UIColor(rgb: 0x000000),
        stickersSectionTextColor: UIColor(rgb: 0x7b7b7b),
        stickersSearchBackgroundColor: UIColor(rgb: 0x1c1c1d),
        stickersSearchPlaceholderColor: UIColor(rgb: 0x8e8e92),
        stickersSearchPrimaryColor: .white,
        stickersSearchControlColor: UIColor(rgb: 0x8e8e92),
        gifsBackgroundColor: UIColor(rgb: 0x000000)
    )

    let inputButtonPanel = PresentationThemeInputButtonPanel(
        panelSeparatorColor: UIColor(rgb: 0x3d3d40),
        panelBackgroundColor: UIColor(rgb: 0x141414),
        buttonFillColor: UIColor(rgb: 0x5a5a5a),
        buttonStrokeColor: UIColor(rgb: 0x0c0c0c),
        buttonHighlightedFillColor: UIColor(rgb: 0x5a5a5a, alpha: 0.7),
        buttonHighlightedStrokeColor: UIColor(rgb: 0x0c0c0c),
        buttonTextColor: .white
    )

    let historyNavigation = PresentationThemeChatHistoryNavigation(
        fillColor: UIColor(rgb: 0x1c1c1d),
        strokeColor: UIColor(rgb: 0x3d3d40),
        foregroundColor: .white,
        badgeBackgroundColor: accentColor,
        badgeStrokeColor: accentColor,
        badgeTextColor: badgeTextColor
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
        standardActionTextColor: accentColor,
        destructiveActionTextColor: destructiveColor,
        disabledActionTextColor: UIColor(rgb: 0x4d4d4d),
        primaryTextColor: .white,
        secondaryTextColor: UIColor(rgb: 0x5e5e5e),
        controlAccentColor: accentColor,
        inputBackgroundColor: UIColor(rgb: 0x0f0f0f),
        inputHollowBackgroundColor: UIColor(rgb: 0x0f0f0f),
        inputBorderColor: UIColor(rgb: 0x0f0f0f),
        inputPlaceholderColor: UIColor(rgb: 0x8f8f8f),
        inputTextColor: .white,
        inputClearButtonColor: UIColor(rgb: 0x8f8f8f),
        checkContentColor: secondaryBadgeTextColor
    )
    
    let contextMenu = PresentationThemeContextMenu(
        dimColor: UIColor(rgb: 0x000000, alpha: 0.6),
        backgroundColor: UIColor(rgb: 0x252525, alpha: 0.78),
        itemSeparatorColor: UIColor(rgb: 0xFFFFFF, alpha: 0.15),
        sectionSeparatorColor: UIColor(rgb: 0x000000, alpha: 0.2),
        itemBackgroundColor: UIColor(rgb: 0x000000, alpha: 0.0),
        itemHighlightedBackgroundColor: UIColor(rgb: 0xFFFFFF, alpha: 0.15),
        primaryColor: UIColor(rgb: 0xffffff, alpha: 1.0),
        secondaryColor: UIColor(rgb: 0xffffff, alpha: 0.8),
        destructiveColor: destructiveColor
    )

    let inAppNotification = PresentationThemeInAppNotification(
        fillColor: UIColor(rgb: 0x1c1c1d),
        primaryTextColor: .white,
        expandedNotification: PresentationThemeExpandedNotification(
            backgroundType: .dark,
            navigationBar: PresentationThemeExpandedNotificationNavigationBar(
                backgroundColor: UIColor(rgb: 0x1c1c1d),
                primaryTextColor: .white,
                controlColor: .white,
                separatorColor: UIColor(rgb: 0x000000)
            )
        )
    )

    return PresentationTheme(
        name: .builtin(.night),
        referenceTheme: .night,
        overallDarkAppearance: true,
        baseColor: baseColor,
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

public let defaultDarkPresentationTheme = makeDarkPresentationTheme(accentColor: .white, baseColor: .white, preview: false)

public func makeDarkPresentationTheme(accentColor: UIColor?, baseColor: PresentationThemeBaseColor?, preview: Bool) -> PresentationTheme {
    let accentColor = accentColor ?? .white
    return makeDarkPresentationTheme(accentColor: accentColor, baseColor: baseColor, preview: preview)
}
