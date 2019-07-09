import Foundation
import UIKit

private func makeDarkPresentationTheme(accentColor: UIColor) -> PresentationTheme {
    let destructiveColor: UIColor = UIColor(rgb: 0xFF6767)
    let constructiveColor: UIColor = UIColor(rgb: 0x08a723)
    let secretColor: UIColor = UIColor(rgb: 0x89DF9E)
    
    let mainBackgroundColor = accentColor.withMultiplied(hue: 1.024, saturation: 0.585, brightness: 0.25)
    let mainSelectionColor = accentColor.withMultiplied(hue: 1.03, saturation: 0.585, brightness: 0.12)
    let additionalBackgroundColor = accentColor.withMultiplied(hue: 1.024, saturation: 0.573, brightness: 0.18)
    
    let mainSeparatorColor = accentColor.withMultiplied(hue: 1.039, saturation: 0.560, brightness: 0.14)
    let mainForegroundColor = accentColor.withMultiplied(hue: 0.99, saturation: 0.256, brightness: 0.62)
    
    let mainSecondaryColor = accentColor.withMultiplied(hue: 1.019, saturation: 0.109, brightness: 0.59)
    let mainSecondaryTextColor = accentColor.withMultiplied(hue: 0.956, saturation: 0.17, brightness: 1.0)
    
    let mainFreeTextColor = accentColor.withMultiplied(hue: 1.019, saturation: 0.097, brightness: 0.56)
    
    let outgoingBubbleColor = accentColor.withMultiplied(hue: 1.019, saturation: 0.731, brightness: 0.59)
    let highlightedIncomingBubbleColor = accentColor.withMultiplied(hue: 1.03, saturation: 0.463, brightness: 0.29)
    let highlightedOutgoingBubbleColor = accentColor.withMultiplied(hue: 1.019, saturation: 0.609, brightness: 0.63)
    
    let mainInputColor = accentColor.withMultiplied(hue: 1.029, saturation: 0.609, brightness: 0.19)
    let inputBackgroundColor = accentColor.withMultiplied(hue: 1.02, saturation: 0.609, brightness: 0.15)
    
    let rootStatusBar = PresentationThemeRootNavigationStatusBar(
        style: .white
    )

    let rootTabBar = PresentationThemeRootTabBar(
        backgroundColor: mainBackgroundColor,
        separatorColor: mainSeparatorColor,
        iconColor: mainForegroundColor,
        selectedIconColor: accentColor,
        textColor: mainForegroundColor,
        selectedTextColor: accentColor,
        badgeBackgroundColor: UIColor(rgb: 0xEF5B5B),
        badgeStrokeColor: UIColor(rgb: 0xEF5B5B),
        badgeTextColor: UIColor(rgb: 0xffffff)
    )

    let rootNavigationBar = PresentationThemeRootNavigationBar(
        buttonColor: accentColor,
        disabledButtonColor: accentColor.withMultiplied(hue: 1.033, saturation: 0.219, brightness: 0.44),
        primaryTextColor: UIColor(rgb: 0xffffff),
        secondaryTextColor: mainSecondaryColor,
        controlColor: mainSecondaryColor,
        accentTextColor: accentColor,
        backgroundColor: mainBackgroundColor,
        separatorColor: mainSeparatorColor,
        badgeBackgroundColor: UIColor(rgb: 0xEF5B5B),
        badgeStrokeColor: UIColor(rgb: 0xEF5B5B),
        badgeTextColor: UIColor(rgb: 0xffffff)
    )

    let activeNavigationSearchBar = PresentationThemeActiveNavigationSearchBar(
        backgroundColor: mainBackgroundColor,
        accentColor: accentColor,
        inputFillColor: mainInputColor,
        inputTextColor: UIColor(rgb: 0xffffff),
        inputPlaceholderTextColor: mainSecondaryColor,
        inputIconColor: mainSecondaryColor,
        inputClearButtonColor: mainSecondaryColor,
        separatorColor: additionalBackgroundColor
    )

    let auth = PresentationThemeAuth(
        introStartButton: accentColor,
        introDotColor: mainSecondaryColor
    )

    let passcode = PresentationThemePasscode(
        backgroundColors: (accentColor.withMultiplied(hue: 1.049, saturation: 0.573, brightness: 0.47), additionalBackgroundColor),
        buttonColor: mainBackgroundColor
    )

    let rootController = PresentationThemeRootController(
        statusBar: rootStatusBar,
        tabBar: rootTabBar,
        navigationBar: rootNavigationBar,
        activeNavigationSearchBar: activeNavigationSearchBar
    )

    let switchColors = PresentationThemeSwitch(
        frameColor: mainSecondaryTextColor.withAlphaComponent(0.5),
        handleColor: UIColor(rgb: 0x121212),
        contentColor: accentColor,
        positiveColor: accentColor,
        negativeColor: destructiveColor
    )

    let list = PresentationThemeList(
        blocksBackgroundColor: additionalBackgroundColor,
        plainBackgroundColor: additionalBackgroundColor,
        itemPrimaryTextColor: UIColor(rgb: 0xffffff),
        itemSecondaryTextColor: mainSecondaryTextColor.withAlphaComponent(0.5),
        itemDisabledTextColor: mainSecondaryTextColor.withAlphaComponent(0.5),
        itemAccentColor: accentColor,
        itemHighlightedColor: UIColor(rgb: 0x28b772),
        itemDestructiveColor: destructiveColor,
        itemPlaceholderTextColor: mainSecondaryTextColor.withAlphaComponent(0.5),
        itemBlocksBackgroundColor: mainBackgroundColor,
        itemHighlightedBackgroundColor: mainSelectionColor,
        itemBlocksSeparatorColor: mainSeparatorColor,
        itemPlainSeparatorColor: mainSeparatorColor,
        disclosureArrowColor: mainSecondaryTextColor.withAlphaComponent(0.5),
        sectionHeaderTextColor: mainFreeTextColor,
        freeTextColor: mainFreeTextColor,
        freeTextErrorColor: destructiveColor,
        freeTextSuccessColor: UIColor(rgb: 0x30cf30),
        freeMonoIcon: mainFreeTextColor,
        itemSwitchColors: switchColors,
        itemDisclosureActions: PresentationThemeItemDisclosureActions(
            neutral1: PresentationThemeItemDisclosureAction(fillColor: UIColor(rgb: 0x007cd6), foregroundColor: .white),
            neutral2: PresentationThemeItemDisclosureAction(fillColor: UIColor(rgb: 0xcd7800), foregroundColor: .white),
            destructive: PresentationThemeItemDisclosureAction(fillColor: UIColor(rgb: 0xc70c0c), foregroundColor: .white),
            constructive: PresentationThemeItemDisclosureAction(fillColor: constructiveColor, foregroundColor: .white),
            accent: PresentationThemeItemDisclosureAction(fillColor: UIColor(rgb: 0x007cd6), foregroundColor: .white),
            warning: PresentationThemeItemDisclosureAction(fillColor: UIColor(rgb: 0xcd7800), foregroundColor: .white),
            inactive: PresentationThemeItemDisclosureAction(fillColor: UIColor(rgb: 0x26384c), foregroundColor: .white)
        ),
        itemCheckColors: PresentationThemeCheck(
            strokeColor: mainSecondaryTextColor.withAlphaComponent(0.5),
            fillColor: accentColor,
            foregroundColor: .white
        ),
        controlSecondaryColor: mainSecondaryTextColor.withAlphaComponent(0.5),
        freeInputField: PresentationInputFieldTheme(
            backgroundColor: mainSecondaryTextColor.withAlphaComponent(0.5),
            placeholderColor: UIColor(rgb: 0x4d4d4d),
            primaryColor: .white,
            controlColor: UIColor(rgb: 0x4d4d4d)
        ),
        mediaPlaceholderColor: UIColor(rgb: 0x1e2c3a),
        scrollIndicatorColor: UIColor(white: 1.0, alpha: 0.3),
        pageIndicatorInactiveColor: mainSecondaryTextColor.withAlphaComponent(0.4),
        inputClearButtonColor: mainSecondaryColor
    )

    let chatList = PresentationThemeChatList(
        backgroundColor: additionalBackgroundColor,
        itemSeparatorColor: mainSeparatorColor,
        itemBackgroundColor: additionalBackgroundColor,
        pinnedItemBackgroundColor: mainBackgroundColor,
        itemHighlightedBackgroundColor: mainSelectionColor,
        itemSelectedBackgroundColor: mainSelectionColor,
        titleColor: UIColor(rgb: 0xffffff),
        secretTitleColor: secretColor,
        dateTextColor: mainSecondaryTextColor.withAlphaComponent(0.5),
        authorNameColor: UIColor(rgb: 0xffffff),
        messageTextColor: mainSecondaryTextColor.withAlphaComponent(0.5),
        messageDraftTextColor: UIColor(rgb: 0xdd4b39),
        checkmarkColor: accentColor,
        pendingIndicatorColor: mainSecondaryTextColor.withAlphaComponent(0.4),
        failedFillColor: destructiveColor,
        failedForegroundColor: .white,
        muteIconColor: mainSecondaryTextColor.withAlphaComponent(0.4),
        unreadBadgeActiveBackgroundColor: accentColor,
        unreadBadgeActiveTextColor: UIColor(rgb: 0xffffff),
        unreadBadgeInactiveBackgroundColor: mainSecondaryTextColor.withAlphaComponent(0.4),
        unreadBadgeInactiveTextColor: additionalBackgroundColor,
        pinnedBadgeColor: mainSecondaryTextColor.withAlphaComponent(0.5),
        pinnedSearchBarColor: mainInputColor,
        regularSearchBarColor: accentColor.withMultiplied(hue: 1.029, saturation: 0.609, brightness: 0.12),
        sectionHeaderFillColor: mainBackgroundColor,
        sectionHeaderTextColor: mainSecondaryTextColor.withAlphaComponent(0.5),
        searchBarKeyboardColor: .dark,
        verifiedIconFillColor: accentColor,
        verifiedIconForegroundColor: .white,
        secretIconColor: secretColor,
        pinnedArchiveAvatarColor: PresentationThemeArchiveAvatarColors(backgroundColors: (UIColor(rgb: 0x72d5fd), UIColor(rgb: 0x2a9ef1)), foregroundColor: .white),
        unpinnedArchiveAvatarColor: PresentationThemeArchiveAvatarColors(backgroundColors: (UIColor(rgb: 0x5d6d77), UIColor(rgb: 0x4e5c64)), foregroundColor: additionalBackgroundColor),
        onlineDotColor: UIColor(rgb: 0x4cc91f)
    )

    let bubble = PresentationThemeChatBubble(
        incoming: PresentationThemeBubbleColor(withWallpaper: PresentationThemeBubbleColorComponents(fill: mainBackgroundColor, highlightedFill: highlightedIncomingBubbleColor, stroke: mainBackgroundColor), withoutWallpaper: PresentationThemeBubbleColorComponents(fill: mainBackgroundColor, highlightedFill: highlightedIncomingBubbleColor, stroke: mainBackgroundColor)),
        outgoing: PresentationThemeBubbleColor(withWallpaper: PresentationThemeBubbleColorComponents(fill: outgoingBubbleColor, highlightedFill: highlightedOutgoingBubbleColor, stroke: outgoingBubbleColor), withoutWallpaper: PresentationThemeBubbleColorComponents(fill: outgoingBubbleColor, highlightedFill: highlightedOutgoingBubbleColor, stroke: outgoingBubbleColor)),
        freeform: PresentationThemeBubbleColor(withWallpaper: PresentationThemeBubbleColorComponents(fill: mainBackgroundColor, highlightedFill: highlightedIncomingBubbleColor, stroke: mainBackgroundColor), withoutWallpaper: PresentationThemeBubbleColorComponents(fill: mainBackgroundColor, highlightedFill: highlightedIncomingBubbleColor, stroke: mainBackgroundColor)),
        incomingPrimaryTextColor: UIColor(rgb: 0xffffff),
        incomingSecondaryTextColor: mainSecondaryTextColor.withAlphaComponent(0.5),
        incomingLinkTextColor: accentColor,
        incomingLinkHighlightColor: accentColor.withAlphaComponent(0.5),
        incomingScamColor: destructiveColor,
        outgoingPrimaryTextColor: UIColor(rgb: 0xffffff),
        outgoingSecondaryTextColor: mainSecondaryTextColor.withAlphaComponent(0.5),
        outgoingLinkTextColor: accentColor,
        outgoingLinkHighlightColor: accentColor.withAlphaComponent(0.5),
        outgoingScamColor: destructiveColor,
        infoPrimaryTextColor: UIColor(rgb: 0xffffff),
        infoLinkTextColor: accentColor,
        incomingTextHighlightColor: UIColor(rgb: 0xffe438),
        outgoingTextHighlightColor: UIColor(rgb: 0xffe438),
        incomingAccentTextColor: UIColor(rgb: 0xffffff),
        outgoingAccentTextColor: UIColor(rgb: 0xffffff),
        incomingAccentControlColor: UIColor(rgb: 0xffffff),
        outgoingAccentControlColor: UIColor(rgb: 0xffffff),
        incomingMediaActiveControlColor: UIColor(rgb: 0xffffff, alpha: 0.6),
        outgoingMediaActiveControlColor: UIColor(rgb: 0xffffff, alpha: 0.6),
        incomingMediaInactiveControlColor: UIColor(rgb: 0xffffff, alpha: 0.3),
        outgoingMediaInactiveControlColor: UIColor(rgb: 0xffffff, alpha: 0.3),
        outgoingCheckColor: accentColor.withMultiplied(hue: 0.99, saturation: 0.743, brightness: 1.0),
        incomingPendingActivityColor: mainSecondaryTextColor.withAlphaComponent(0.5),
        outgoingPendingActivityColor: mainSecondaryTextColor.withAlphaComponent(0.5),
        mediaDateAndStatusFillColor: UIColor(white: 0.0, alpha: 0.5),
        mediaDateAndStatusTextColor: .white,
        incomingFileTitleColor: UIColor(rgb: 0xffffff),
        outgoingFileTitleColor: UIColor(rgb: 0xffffff),
        incomingFileDescriptionColor: mainSecondaryTextColor.withAlphaComponent(0.5),
        outgoingFileDescriptionColor: mainSecondaryTextColor.withAlphaComponent(0.5),
        incomingFileDurationColor: mainSecondaryTextColor.withAlphaComponent(0.5),
        outgoingFileDurationColor: mainSecondaryTextColor.withAlphaComponent(0.5),
        shareButtonFillColor: PresentationThemeVariableColor(color: additionalBackgroundColor.withAlphaComponent(0.5)),
        shareButtonStrokeColor: PresentationThemeVariableColor(color: UIColor(rgb: 0x587fa3, alpha: 0.15)),
        shareButtonForegroundColor: PresentationThemeVariableColor(color: UIColor(rgb: 0xb2b2b2)),
        mediaOverlayControlBackgroundColor: UIColor(white: 0.0, alpha: 0.6),
        mediaOverlayControlForegroundColor: UIColor(white: 1.0, alpha: 1.0),
        actionButtonsIncomingFillColor: PresentationThemeVariableColor(withWallpaper: additionalBackgroundColor.withAlphaComponent(0.5), withoutWallpaper: additionalBackgroundColor.withAlphaComponent(0.5)),
        actionButtonsIncomingStrokeColor: PresentationThemeVariableColor(color: UIColor(rgb: 0x587fa3, alpha: 0.15)),
        actionButtonsIncomingTextColor: PresentationThemeVariableColor(color: UIColor(rgb: 0xffffff)),
        actionButtonsOutgoingFillColor: PresentationThemeVariableColor(withWallpaper: additionalBackgroundColor.withAlphaComponent(0.5), withoutWallpaper: additionalBackgroundColor.withAlphaComponent(0.5)),
        actionButtonsOutgoingStrokeColor: PresentationThemeVariableColor(color: UIColor(rgb: 0x587fa3, alpha: 0.15)),
        actionButtonsOutgoingTextColor: PresentationThemeVariableColor(color: UIColor(rgb: 0xffffff)),
        selectionControlBorderColor: .white,
        selectionControlFillColor: accentColor,
        selectionControlForegroundColor: .white,
        mediaHighlightOverlayColor: UIColor(white: 1.0, alpha: 0.6),
        deliveryFailedFillColor: destructiveColor,
        deliveryFailedForegroundColor: .white,
        incomingMediaPlaceholderColor: UIColor(rgb: 0x1e2c3a),
        outgoingMediaPlaceholderColor: UIColor(rgb: 0x2d5883),
        incomingPolls: PresentationThemeChatBubblePolls(radioButton: UIColor(rgb: 0x617583), radioProgress: accentColor, highlight: accentColor.withAlphaComponent(0.12), separator: mainSeparatorColor, bar: accentColor),
        outgoingPolls: PresentationThemeChatBubblePolls(radioButton: UIColor(rgb: 0x8eaac0), radioProgress: UIColor(rgb: 0x89d0ff), highlight: UIColor(rgb: 0x89d0ff).withAlphaComponent(0.12), separator: UIColor(rgb: 0x264b70), bar: UIColor(rgb: 0x89d0ff))
    )

    let serviceMessage = PresentationThemeServiceMessage(
        components: PresentationThemeServiceMessageColor(withDefaultWallpaper: PresentationThemeServiceMessageColorComponents(fill: additionalBackgroundColor, primaryText: .white, linkHighlight: UIColor(rgb: 0xffffff, alpha: 0.12), scam: destructiveColor, dateFillStatic: additionalBackgroundColor, dateFillFloating: additionalBackgroundColor.withAlphaComponent(0.2)), withCustomWallpaper: PresentationThemeServiceMessageColorComponents(fill: additionalBackgroundColor, primaryText: .white, linkHighlight: UIColor(rgb: 0xffffff, alpha: 0.12), scam: destructiveColor, dateFillStatic: additionalBackgroundColor, dateFillFloating: additionalBackgroundColor.withAlphaComponent(0.2))),
        unreadBarFillColor: mainBackgroundColor,
        unreadBarStrokeColor: mainBackgroundColor,
        unreadBarTextColor: UIColor(rgb: 0xffffff),
        dateTextColor: PresentationThemeVariableColor(color: UIColor(rgb: 0xffffff))
    )

    let inputPanelMediaRecordingControl = PresentationThemeChatInputPanelMediaRecordingControl(
        buttonColor: accentColor,
        micLevelColor: accentColor.withAlphaComponent(0.2),
        activeIconColor: .white,
        panelControlFillColor: mainBackgroundColor,
        panelControlStrokeColor: mainBackgroundColor,
        panelControlContentPrimaryColor: mainSecondaryTextColor.withAlphaComponent(0.5),
        panelControlContentAccentColor: accentColor
    )

    let inputPanel = PresentationThemeChatInputPanel(
        panelBackgroundColor: mainBackgroundColor,
        panelStrokeColor: mainSeparatorColor,
        panelControlAccentColor: accentColor,
        panelControlColor: mainSecondaryTextColor.withAlphaComponent(0.5),
        panelControlDisabledColor: UIColor(rgb: 0x90979F, alpha: 0.5),
        panelControlDestructiveColor: destructiveColor,
        inputBackgroundColor: inputBackgroundColor,
        inputStrokeColor: inputBackgroundColor,
        inputPlaceholderColor: mainSecondaryTextColor.withAlphaComponent(0.4),
        inputTextColor: UIColor(rgb: 0xffffff),
        inputControlColor: mainSecondaryTextColor.withAlphaComponent(0.4),
        actionControlFillColor: accentColor,
        actionControlForegroundColor: .white,
        primaryTextColor: UIColor(rgb: 0xffffff),
        secondaryTextColor: UIColor(rgb: 0xffffff, alpha: 0.5),
        mediaRecordingDotColor: accentColor,
        keyboardColor: .dark,
        mediaRecordingControl: inputPanelMediaRecordingControl
    )

    let inputMediaPanel = PresentationThemeInputMediaPanel(
        panelSeparatorColor: mainBackgroundColor,
        panelIconColor: mainSecondaryTextColor.withAlphaComponent(0.5),
        panelHighlightedIconBackgroundColor: inputBackgroundColor,
        stickersBackgroundColor: additionalBackgroundColor,
        stickersSectionTextColor: mainSecondaryTextColor.withAlphaComponent(0.5),
        stickersSearchBackgroundColor: UIColor(rgb: 0x121c25),
        stickersSearchPlaceholderColor: UIColor(rgb: 0x788a96),
        stickersSearchPrimaryColor: .white,
        stickersSearchControlColor: UIColor(rgb: 0x788a96),
        gifsBackgroundColor: additionalBackgroundColor
    )

    let inputButtonPanel = PresentationThemeInputButtonPanel(
        panelSeparatorColor: mainBackgroundColor,
        panelBackgroundColor: UIColor(rgb: 0x161A20),
        buttonFillColor: UIColor(rgb: 0x5B5F62),
        buttonStrokeColor: UIColor(rgb: 0x0D1013),
        buttonHighlightedFillColor: UIColor(rgb: 0x5B5F62, alpha: 0.7),
        buttonHighlightedStrokeColor: UIColor(rgb: 0x0D1013),
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
        bubble: bubble,
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
        standardActionTextColor: accentColor,
        opaqueItemSeparatorColor: additionalBackgroundColor,
        destructiveActionTextColor: destructiveColor,
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
        checkContentColor: .white
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
        name: .builtin(.nightAccent),
        overallDarkAppearance: true,
        auth: auth,
        passcode: passcode,
        rootController: rootController,
        list: list,
        chatList: chatList,
        chat: chat,
        actionSheet: actionSheet,
        inAppNotification: inAppNotification
    )
}

public let defaultDarkAccentPresentationTheme = makeDarkAccentPresentationTheme(accentColor: 0x2EA6FF)

public func makeDarkAccentPresentationTheme(accentColor: Int32?) -> PresentationTheme {
    let color: UIColor
    if let accentColor = accentColor {
        color = UIColor(rgb: UInt32(bitPattern: accentColor))
    } else {
        color = UIColor(rgb: UInt32(bitPattern: defaultDayAccentColor))
    }
    return makeDarkPresentationTheme(accentColor: color)
}
