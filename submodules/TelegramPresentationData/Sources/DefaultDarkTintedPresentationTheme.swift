import Foundation
import UIKit

private func makeDarkPresentationTheme(accentColor: UIColor, preview: Bool) -> PresentationTheme {
    let destructiveColor: UIColor = UIColor(rgb: 0xff6767)
    let constructiveColor: UIColor = UIColor(rgb: 0x08a723)
    let secretColor: UIColor = UIColor(rgb: 0x89df9e)
    
    let mainBackgroundColor = accentColor.withMultiplied(hue: 1.024, saturation: 0.585, brightness: 0.25)
    let mainSelectionColor = accentColor.withMultiplied(hue: 1.03, saturation: 0.585, brightness: 0.12)
    let additionalBackgroundColor = accentColor.withMultiplied(hue: 1.024, saturation: 0.573, brightness: 0.18)

    let mainSeparatorColor = accentColor.withMultiplied(hue: 1.033, saturation: 0.426, brightness: 0.34)
    let mainForegroundColor = accentColor.withMultiplied(hue: 0.99, saturation: 0.256, brightness: 0.62)
    
    let mainSecondaryColor = accentColor.withMultiplied(hue: 1.019, saturation: 0.109, brightness: 0.59)
    let mainSecondaryTextColor = accentColor.withMultiplied(hue: 0.956, saturation: 0.17, brightness: 1.0)
    
    let mainFreeTextColor = accentColor.withMultiplied(hue: 1.019, saturation: 0.097, brightness: 0.56)
    
    let outgoingBubbleColor = accentColor.withMultiplied(hue: 1.019, saturation: 0.731, brightness: 0.59)
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
        primaryTextColor: UIColor(rgb: 0xffffff),
        secondaryTextColor: mainSecondaryColor,
        controlColor: mainSecondaryColor,
        accentTextColor: accentColor,
        backgroundColor: mainBackgroundColor,
        separatorColor: mainSeparatorColor,
        badgeBackgroundColor: UIColor(rgb: 0xef5b5b),
        badgeStrokeColor: UIColor(rgb: 0xef5b5b),
        badgeTextColor: UIColor(rgb: 0xffffff)
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
        navigationSearchBar: navigationSearchBar
    )

    let switchColors = PresentationThemeSwitch(
        frameColor: mainSecondaryTextColor.withAlphaComponent(0.5),
        handleColor: UIColor(rgb: 0x121212),
        contentColor: accentColor,
        positiveColor: constructiveColor,
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
        freeMonoIconColor: mainFreeTextColor,
        itemSwitchColors: switchColors,
        itemDisclosureActions: PresentationThemeItemDisclosureActions(
            neutral1: PresentationThemeFillForeground(fillColor: UIColor(rgb: 0x007cd6), foregroundColor: .white),
            neutral2: PresentationThemeFillForeground(fillColor: UIColor(rgb: 0xcd7800), foregroundColor: .white),
            destructive: PresentationThemeFillForeground(fillColor: UIColor(rgb: 0xc70c0c), foregroundColor: .white),
            constructive: PresentationThemeFillForeground(fillColor: constructiveColor, foregroundColor: .white),
            accent: PresentationThemeFillForeground(fillColor: UIColor(rgb: 0x007cd6), foregroundColor: .white),
            warning: PresentationThemeFillForeground(fillColor: UIColor(rgb: 0xcd7800), foregroundColor: .white),
            inactive: PresentationThemeFillForeground(fillColor: UIColor(rgb: 0x26384c), foregroundColor: .white)
        ),
        itemCheckColors: PresentationThemeFillStrokeForeground(
            fillColor: accentColor,
            strokeColor: mainSecondaryTextColor.withAlphaComponent(0.5),
            foregroundColor: .white
        ),
        controlSecondaryColor: mainSecondaryTextColor.withAlphaComponent(0.5),
        freeInputField: PresentationInputFieldTheme(
            backgroundColor: mainSecondaryTextColor.withAlphaComponent(0.5),
            strokeColor: mainSecondaryTextColor.withAlphaComponent(0.5),
            placeholderColor: UIColor(rgb: 0x4d4d4d),
            primaryColor: .white,
            controlColor: UIColor(rgb: 0x4d4d4d)
        ),
        mediaPlaceholderColor: accentColor.withMultiplied(hue: 1.019, saturation: 0.585, brightness: 0.23),
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
        pinnedArchiveAvatarColor: PresentationThemeArchiveAvatarColors(backgroundColors: PresentationThemeGradientColors(topColor: UIColor(rgb: 0x72d5fd), bottomColor: UIColor(rgb: 0x2a9ef1)), foregroundColor: .white),
        unpinnedArchiveAvatarColor: PresentationThemeArchiveAvatarColors(backgroundColors: PresentationThemeGradientColors(topColor: accentColor.withMultiplied(hue: 0.985, saturation: 0.268, brightness: 0.47), bottomColor: accentColor.withMultiplied(hue: 0.98, saturation: 0.268, brightness: 0.39)), foregroundColor: additionalBackgroundColor),
        onlineDotColor: UIColor(rgb: 0x4cc91f)
    )
    
    let buttonStrokeColor = accentColor.withMultiplied(hue: 1.014, saturation: 0.56, brightness: 0.64).withAlphaComponent(0.15)
    
    let message = PresentationThemeChatMessage(
        incoming: PresentationThemePartedColors(bubble: PresentationThemeBubbleColor(withWallpaper: PresentationThemeBubbleColorComponents(fill: mainBackgroundColor, highlightedFill: highlightedIncomingBubbleColor, stroke: mainBackgroundColor), withoutWallpaper: PresentationThemeBubbleColorComponents(fill: mainBackgroundColor, highlightedFill: highlightedIncomingBubbleColor, stroke: mainBackgroundColor)), primaryTextColor: .white, secondaryTextColor: mainSecondaryTextColor.withAlphaComponent(0.5), linkTextColor: accentColor, linkHighlightColor: accentColor.withAlphaComponent(0.5), scamColor: destructiveColor, textHighlightColor: UIColor(rgb: 0xffe438), accentTextColor: accentColor, accentControlColor: accentColor, mediaActiveControlColor: accentColor, mediaInactiveControlColor: accentColor.withAlphaComponent(0.5), pendingActivityColor: mainSecondaryTextColor.withAlphaComponent(0.5), fileTitleColor: accentColor, fileDescriptionColor: mainSecondaryTextColor.withAlphaComponent(0.5), fileDurationColor: mainSecondaryTextColor.withAlphaComponent(0.5), mediaPlaceholderColor: accentColor.withMultiplied(hue: 1.019, saturation: 0.585, brightness: 0.23), polls: PresentationThemeChatBubblePolls(radioButton: accentColor.withMultiplied(hue: 0.995, saturation: 0.317, brightness: 0.51), radioProgress: accentColor, highlight: accentColor.withAlphaComponent(0.12), separator: mainSeparatorColor, bar: accentColor), actionButtonsFillColor: PresentationThemeVariableColor(withWallpaper: additionalBackgroundColor.withAlphaComponent(0.5), withoutWallpaper: additionalBackgroundColor.withAlphaComponent(0.5)), actionButtonsStrokeColor: PresentationThemeVariableColor(color: buttonStrokeColor), actionButtonsTextColor: PresentationThemeVariableColor(color: .white)),
        outgoing: PresentationThemePartedColors(bubble: PresentationThemeBubbleColor(withWallpaper: PresentationThemeBubbleColorComponents(fill: outgoingBubbleColor, highlightedFill: highlightedOutgoingBubbleColor, stroke: outgoingBubbleColor), withoutWallpaper: PresentationThemeBubbleColorComponents(fill: outgoingBubbleColor, highlightedFill: highlightedOutgoingBubbleColor, stroke: outgoingBubbleColor)), primaryTextColor: .white, secondaryTextColor: mainSecondaryTextColor.withAlphaComponent(0.5), linkTextColor: accentColor, linkHighlightColor: accentColor.withAlphaComponent(0.5), scamColor: destructiveColor, textHighlightColor: UIColor(rgb: 0xffe438), accentTextColor: .white, accentControlColor: .white, mediaActiveControlColor: .white, mediaInactiveControlColor: UIColor(rgb: 0xffffff, alpha: 0.5), pendingActivityColor: mainSecondaryTextColor.withAlphaComponent(0.5), fileTitleColor: .white, fileDescriptionColor: mainSecondaryTextColor.withAlphaComponent(0.5), fileDurationColor: mainSecondaryTextColor.withAlphaComponent(0.5), mediaPlaceholderColor: accentColor.withMultiplied(hue: 1.019, saturation: 0.804, brightness: 0.51), polls: PresentationThemeChatBubblePolls(radioButton: .white, radioProgress: accentColor.withMultiplied(hue: 0.99, saturation: 0.56, brightness: 1.0), highlight: accentColor.withMultiplied(hue: 0.99, saturation: 0.56, brightness: 1.0).withAlphaComponent(0.12), separator: mainSeparatorColor, bar: .white), actionButtonsFillColor: PresentationThemeVariableColor(withWallpaper: additionalBackgroundColor.withAlphaComponent(0.5), withoutWallpaper: additionalBackgroundColor.withAlphaComponent(0.5)), actionButtonsStrokeColor: PresentationThemeVariableColor(color: buttonStrokeColor), actionButtonsTextColor: PresentationThemeVariableColor(color: .white)),
        freeform: PresentationThemeBubbleColor(withWallpaper: PresentationThemeBubbleColorComponents(fill: mainBackgroundColor, highlightedFill: highlightedIncomingBubbleColor, stroke: mainBackgroundColor), withoutWallpaper: PresentationThemeBubbleColorComponents(fill: mainBackgroundColor, highlightedFill: highlightedIncomingBubbleColor, stroke: mainBackgroundColor)),
        infoPrimaryTextColor: UIColor(rgb: 0xffffff),
        infoLinkTextColor: accentColor,
        outgoingCheckColor: accentColor.withMultiplied(hue: 0.99, saturation: 0.743, brightness: 1.0),
        mediaDateAndStatusFillColor: UIColor(white: 0.0, alpha: 0.5),
        mediaDateAndStatusTextColor: .white,
        shareButtonFillColor: PresentationThemeVariableColor(color: additionalBackgroundColor.withAlphaComponent(0.5)),
        shareButtonStrokeColor: PresentationThemeVariableColor(color: buttonStrokeColor),
        shareButtonForegroundColor: PresentationThemeVariableColor(color: UIColor(rgb: 0xb2b2b2)),
        mediaOverlayControlColors: PresentationThemeFillForeground(fillColor: UIColor(rgb: 0x000000, alpha: 0.6), foregroundColor: .white),
        selectionControlColors: PresentationThemeFillStrokeForeground(fillColor: accentColor, strokeColor: .white, foregroundColor: .white),
        deliveryFailedColors: PresentationThemeFillForeground(fillColor: destructiveColor, foregroundColor: .white),
        mediaHighlightOverlayColor: UIColor(white: 1.0, alpha: 0.6)
    )
    
    let serviceMessage = PresentationThemeServiceMessage(
        components: PresentationThemeServiceMessageColor(withDefaultWallpaper: PresentationThemeServiceMessageColorComponents(fill: additionalBackgroundColor, primaryText: .white, linkHighlight: UIColor(rgb: 0xffffff, alpha: 0.12), scam: destructiveColor, dateFillStatic: additionalBackgroundColor, dateFillFloating: additionalBackgroundColor.withAlphaComponent(0.2)), withCustomWallpaper: PresentationThemeServiceMessageColorComponents(fill: additionalBackgroundColor, primaryText: .white, linkHighlight: UIColor(rgb: 0xffffff, alpha: 0.12), scam: destructiveColor, dateFillStatic: additionalBackgroundColor, dateFillFloating: additionalBackgroundColor.withAlphaComponent(0.2))),
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
        panelSeparatorColor: mainSeparatorColor,
        panelControlAccentColor: accentColor,
        panelControlColor: mainSecondaryTextColor.withAlphaComponent(0.5),
        panelControlDisabledColor: UIColor(rgb: 0x90979F, alpha: 0.5),
        panelControlDestructiveColor: destructiveColor,
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
        keyboardColor: .dark,
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
        defaultWallpaper: .color(Int32(bitPattern: accentColor.withMultiplied(hue: 1.024, saturation: 0.573, brightness: 0.18).rgb)),
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
        author: "Telegram",
        overallDarkAppearance: true,
        intro: intro,
        passcode: passcode,
        rootController: rootController,
        list: list,
        chatList: chatList,
        chat: chat,
        actionSheet: actionSheet,
        inAppNotification: inAppNotification,
        preview: preview
    )
}

public let defaultDarkAccentPresentationTheme = makeDarkAccentPresentationTheme(accentColor: UIColor(rgb: 0x2ea6ff), preview: false)

public func makeDarkAccentPresentationTheme(accentColor: UIColor?, preview: Bool) -> PresentationTheme {
    let accentColor = accentColor ?? defaultDayAccentColor
    return makeDarkPresentationTheme(accentColor: accentColor, preview: preview)
}
