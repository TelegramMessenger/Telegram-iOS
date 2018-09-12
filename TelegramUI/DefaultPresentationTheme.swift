import Foundation
import UIKit

private func makeDefaultPresentationTheme(accentColor: UIColor, day: Bool) -> PresentationTheme {
    let destructiveColor: UIColor = UIColor(rgb: 0xff3b30)
    let constructiveColor: UIColor = UIColor(rgb: 0x4cd964)
    let secretColor: UIColor = UIColor(rgb: 0x00B12C)
    
    let rootStatusBar = PresentationThemeRootNavigationStatusBar(
        style: .black
    )
    
    let rootTabBar = PresentationThemeRootTabBar(
        backgroundColor: UIColor(rgb: 0xf7f7f7),
        separatorColor: UIColor(rgb: 0xa3a3a3),
        iconColor: UIColor(rgb: 0xA1A1A1),
        selectedIconColor: accentColor,
        textColor: UIColor(rgb: 0xA1A1A1),
        selectedTextColor: accentColor,
        badgeBackgroundColor: UIColor(rgb: 0xff3b30),
        badgeStrokeColor: UIColor(rgb: 0xff3b30),
        badgeTextColor: .white
    )
    
    let rootNavigationBar = PresentationThemeRootNavigationBar(
        buttonColor: accentColor,
        primaryTextColor: .black,
        secondaryTextColor: UIColor(rgb: 0x787878),
        controlColor: UIColor(rgb: 0x7e8791),
        accentTextColor: accentColor,
        backgroundColor: UIColor(red: 0.968626451, green: 0.968626451, blue: 0.968626451, alpha: 1.0),
        separatorColor: UIColor(red: 0.6953125, green: 0.6953125, blue: 0.6953125, alpha: 1.0),
        badgeBackgroundColor: UIColor(rgb: 0xff3b30),
        badgeStrokeColor: UIColor(rgb: 0xff3b30),
        badgeTextColor: .white
    )
    
    let activeNavigationSearchBar = PresentationThemeActiveNavigationSearchBar(
        backgroundColor: .white,
        accentColor: accentColor,
        inputFillColor: UIColor(rgb: 0xe9e9e9),
        inputTextColor: .black,
        inputPlaceholderTextColor: UIColor(rgb: 0x8e8e93),
        inputIconColor: UIColor(rgb: 0x8e8e93),
        inputClearButtonColor: UIColor(rgb: 0x7b7b81),
        separatorColor: UIColor(red: 0.6953125, green: 0.6953125, blue: 0.6953125, alpha: 1.0)
    )
    
    let rootController = PresentationThemeRootController(
        statusBar: rootStatusBar,
        tabBar: rootTabBar,
        navigationBar: rootNavigationBar,
        activeNavigationSearchBar: activeNavigationSearchBar
    )
    
    let switchColors = PresentationThemeSwitch(
        frameColor: UIColor(rgb: 0xe0e0e0),
        handleColor: UIColor(rgb: 0xffffff),
        contentColor: UIColor(rgb: 0x42d451)
    )
    
    let list = PresentationThemeList(
        blocksBackgroundColor: UIColor(rgb: 0xefeff4),
        plainBackgroundColor: .white,
        itemPrimaryTextColor: .black,
        itemSecondaryTextColor: UIColor(rgb: 0x8e8e93),
        itemDisabledTextColor: UIColor(rgb: 0x8e8e93),
        itemAccentColor: accentColor,
        itemHighlightedColor: secretColor,
        itemDestructiveColor: destructiveColor,
        itemPlaceholderTextColor: UIColor(rgb: 0xc8c8ce),
        itemBlocksBackgroundColor: .white,
        itemHighlightedBackgroundColor: UIColor(rgb: 0xd9d9d9),
        itemBlocksSeparatorColor: UIColor(rgb: 0xc8c7cc),
        itemPlainSeparatorColor: UIColor(rgb: 0xc8c7cc),
        disclosureArrowColor: UIColor(rgb: 0xbab9be),
        sectionHeaderTextColor: UIColor(rgb: 0x6d6d72),
        freeTextColor: UIColor(rgb: 0x6d6d72),
        freeTextErrorColor: UIColor(rgb: 0xcf3030),
        freeTextSuccessColor: UIColor(rgb: 0x26972c),
        freeMonoIcon: UIColor(rgb: 0x7e7e87),
        itemSwitchColors: switchColors,
        itemDisclosureActions: PresentationThemeItemDisclosureActions(
            neutral1: PresentationThemeItemDisclosureAction(fillColor: UIColor(rgb: 0x4892f2), foregroundColor: .white),
            neutral2: PresentationThemeItemDisclosureAction(fillColor: UIColor(rgb: 0xf09a37), foregroundColor: .white),
            destructive: PresentationThemeItemDisclosureAction(fillColor: UIColor(rgb: 0xff3824), foregroundColor: .white),
            constructive: PresentationThemeItemDisclosureAction(fillColor: constructiveColor, foregroundColor: .white),
            accent: PresentationThemeItemDisclosureAction(fillColor: accentColor, foregroundColor: .white),
            warning: PresentationThemeItemDisclosureAction(fillColor: UIColor(rgb: 0xff9500), foregroundColor: .white)
        ),
        itemCheckColors: PresentationThemeCheck(
            strokeColor: UIColor(rgb: 0xC7C7CC),
            fillColor: accentColor,
            foregroundColor: .white
        ),
        controlSecondaryColor: UIColor(rgb: 0xdedede),
        freeInputField: PresentationInputFieldTheme(
            backgroundColor: UIColor(rgb: 0xd6d6dc),
            placeholderColor: UIColor(rgb: 0x96979d),
            primaryColor: .black,
            controlColor: UIColor(rgb: 0x96979d)
        )
    )
    
    let chatList = PresentationThemeChatList(
        backgroundColor: .white,
        itemSeparatorColor: UIColor(rgb: 0xc8c7cc),
        itemBackgroundColor: .white,
        pinnedItemBackgroundColor: UIColor(rgb: 0xf7f7f7),
        itemHighlightedBackgroundColor: UIColor(rgb: 0xd9d9d9),
        titleColor: .black,
        secretTitleColor: secretColor,
        dateTextColor: UIColor(rgb: 0x8e8e93),
        authorNameColor: .black,
        messageTextColor: UIColor(rgb: 0x8e8e93),
        messageDraftTextColor: UIColor(rgb: 0xdd4b39),
        checkmarkColor: UIColor(rgb: 0x21c004),
        pendingIndicatorColor: UIColor(rgb: 0x8e8e93),
        muteIconColor: UIColor(rgb: 0xa7a7ad),
        unreadBadgeActiveBackgroundColor: accentColor,
        unreadBadgeActiveTextColor: .white,
        unreadBadgeInactiveBackgroundColor: UIColor(rgb: 0xb6b6bb),
        unreadBadgeInactiveTextColor: .white,
        pinnedBadgeColor: UIColor(rgb: 0xb6b6bb),
        pinnedSearchBarColor: UIColor(rgb: 0xe5e5e5),
        regularSearchBarColor: UIColor(rgb: 0xe9e9e9),
        sectionHeaderFillColor: UIColor(rgb: 0xf7f7f7),
        sectionHeaderTextColor: UIColor(rgb: 0x8e8e93),
        searchBarKeyboardColor: .light,
        verifiedIconFillColor: accentColor,
        verifiedIconForegroundColor: .white,
        secretIconColor: secretColor
    )
    
    let chatListDay = PresentationThemeChatList(
        backgroundColor: .white,
        itemSeparatorColor: UIColor(rgb: 0xc8c7cc),
        itemBackgroundColor: .white,
        pinnedItemBackgroundColor: UIColor(rgb: 0xf7f7f7),
        itemHighlightedBackgroundColor: UIColor(rgb: 0xd9d9d9),
        titleColor: .black,
        secretTitleColor: secretColor,
        dateTextColor: UIColor(rgb: 0x8e8e93),
        authorNameColor: .black,
        messageTextColor: UIColor(rgb: 0x8e8e93),
        messageDraftTextColor: UIColor(rgb: 0xdd4b39),
        checkmarkColor: accentColor,
        pendingIndicatorColor: UIColor(rgb: 0x8e8e93),
        muteIconColor: UIColor(rgb: 0xa7a7ad),
        unreadBadgeActiveBackgroundColor: accentColor,
        unreadBadgeActiveTextColor: .white,
        unreadBadgeInactiveBackgroundColor: UIColor(rgb: 0xb6b6bb),
        unreadBadgeInactiveTextColor: .white,
        pinnedBadgeColor: UIColor(rgb: 0x939399),
        pinnedSearchBarColor: UIColor(rgb: 0xe5e5e5),
        regularSearchBarColor: UIColor(rgb: 0xe9e9e9),
        sectionHeaderFillColor: UIColor(rgb: 0xf7f7f7),
        sectionHeaderTextColor: UIColor(rgb: 0x8e8e93),
        searchBarKeyboardColor: .light,
        verifiedIconFillColor: accentColor,
        verifiedIconForegroundColor: .white,
        secretIconColor: secretColor
    )
    
    let bubble = PresentationThemeChatBubble(
        incoming: PresentationThemeBubbleColor(withWallpaper: PresentationThemeBubbleColorComponents(fill: UIColor(rgb: 0xffffff), highlightedFill: UIColor(rgb: 0xd9f4ff), stroke: UIColor(rgb: 0x86A9C9, alpha: 0.5)), withoutWallpaper: PresentationThemeBubbleColorComponents(fill: UIColor(rgb: 0xffffff), highlightedFill: UIColor(rgb: 0xd9f4ff), stroke: UIColor(rgb: 0x86A9C9, alpha: 0.5))),
        outgoing: PresentationThemeBubbleColor(withWallpaper: PresentationThemeBubbleColorComponents(fill: UIColor(rgb: 0xE1FFC7), highlightedFill: UIColor(rgb: 0xc8ffa6), stroke: UIColor(rgb: 0x86A9C9, alpha: 0.5)), withoutWallpaper: PresentationThemeBubbleColorComponents(fill: UIColor(rgb: 0xE1FFC7), highlightedFill: UIColor(rgb: 0xc8ffa6), stroke: UIColor(rgb: 0x86A9C9, alpha: 0.5))),
        freeform: PresentationThemeBubbleColor(withWallpaper: PresentationThemeBubbleColorComponents(fill: UIColor(rgb: 0xffffff), highlightedFill: UIColor(rgb: 0xd9f4ff), stroke: UIColor(rgb: 0x86A9C9, alpha: 0.5)), withoutWallpaper: PresentationThemeBubbleColorComponents(fill: UIColor(rgb: 0xffffff), highlightedFill: UIColor(rgb: 0xd9f4ff), stroke: UIColor(rgb: 0x86A9C9, alpha: 0.5))),
        incomingPrimaryTextColor: UIColor(rgb: 0x000000),
        incomingSecondaryTextColor: UIColor(rgb: 0x525252, alpha: 0.6),
        incomingLinkTextColor: UIColor(rgb: 0x004bad),
        incomingLinkHighlightColor: accentColor.withAlphaComponent(0.3),
        outgoingPrimaryTextColor: UIColor(rgb: 0x000000),
        outgoingSecondaryTextColor: UIColor(rgb: 0x008c09, alpha: 0.8),
        outgoingLinkTextColor: UIColor(rgb: 0x004bad),
        outgoingLinkHighlightColor: accentColor.withAlphaComponent(0.3),
        infoPrimaryTextColor: UIColor(rgb: 0x000000),
        infoLinkTextColor: UIColor(rgb: 0x004bad),
        incomingAccentTextColor: UIColor(rgb: 0x3ca7fe),
        outgoingAccentTextColor: UIColor(rgb: 0x00a700),
        incomingAccentControlColor: UIColor(rgb: 0x3ca7fe),
        outgoingAccentControlColor: UIColor(rgb: 0x3FC33B),
        incomingMediaActiveControlColor: UIColor(rgb: 0x3ca7fe),
        outgoingMediaActiveControlColor: UIColor(rgb: 0x3FC33B),
        incomingMediaInactiveControlColor: UIColor(rgb: 0xcacaca),
        outgoingMediaInactiveControlColor: UIColor(rgb: 0x93D987),
        outgoingCheckColor: UIColor(rgb: 0x19C700),
        incomingPendingActivityColor: UIColor(rgb: 0x525252, alpha: 0.6),
        outgoingPendingActivityColor: UIColor(rgb: 0x42b649),
        mediaDateAndStatusFillColor: UIColor(white: 0.0, alpha: 0.5),
        mediaDateAndStatusTextColor: .white,
        incomingFileTitleColor: UIColor(rgb: 0x0b8bed),
        outgoingFileTitleColor: UIColor(rgb: 0x3faa3c),
        incomingFileDescriptionColor: UIColor(rgb: 0x999999),
        outgoingFileDescriptionColor: UIColor(rgb: 0x6fb26a),
        incomingFileDurationColor: UIColor(rgb: 0x525252, alpha: 0.6),
        outgoingFileDurationColor: UIColor(rgb: 0x008c09, alpha: 0.8),
        shareButtonFillColor: UIColor(rgb: 0x748391, alpha: 0.45),
        shareButtonStrokeColor: .clear,
        shareButtonForegroundColor: .white,
        mediaOverlayControlBackgroundColor: UIColor(white: 0.0, alpha: 0.6),
        mediaOverlayControlForegroundColor: UIColor(white: 1.0, alpha: 1.0),
        actionButtonsIncomingFillColor: UIColor(rgb: 0x596E89, alpha: 0.35),
        actionButtonsIncomingStrokeColor: .clear,
        actionButtonsIncomingTextColor: .white,
        actionButtonsOutgoingFillColor: UIColor(rgb: 0x596E89, alpha: 0.35),
        actionButtonsOutgoingStrokeColor: .clear,
        actionButtonsOutgoingTextColor: .white,
        selectionControlBorderColor: UIColor(rgb: 0xC7C7CC),
        selectionControlFillColor: accentColor,
        selectionControlForegroundColor: .white,
        mediaHighlightOverlayColor: UIColor(white: 1.0, alpha: 0.6)
    )
    
    let bubbleDay = PresentationThemeChatBubble(
        incoming: PresentationThemeBubbleColor(withWallpaper: PresentationThemeBubbleColorComponents(fill: UIColor(rgb: 0xffffff), highlightedFill: UIColor(rgb: 0xDADADE), stroke: UIColor(rgb: 0xffffff)), withoutWallpaper: PresentationThemeBubbleColorComponents(fill: UIColor(rgb: 0xF1F1F4), highlightedFill: UIColor(rgb: 0xDADADE), stroke: UIColor(rgb: 0xF1F1F4))),
        outgoing: PresentationThemeBubbleColor(withWallpaper: PresentationThemeBubbleColorComponents(fill: accentColor, highlightedFill: accentColor.withMultipliedBrightnessBy(0.7), stroke: accentColor), withoutWallpaper: PresentationThemeBubbleColorComponents(fill: accentColor, highlightedFill: accentColor.withMultipliedBrightnessBy(0.7), stroke: accentColor)),
        freeform: PresentationThemeBubbleColor(withWallpaper: PresentationThemeBubbleColorComponents(fill: UIColor(rgb: 0xE5E5EA), highlightedFill: UIColor(rgb: 0xDADADE), stroke: UIColor(rgb: 0xE5E5EA)), withoutWallpaper: PresentationThemeBubbleColorComponents(fill: UIColor(rgb: 0xE5E5EA), highlightedFill: UIColor(rgb: 0xDADADE), stroke: UIColor(rgb: 0xE5E5EA))),
        incomingPrimaryTextColor: UIColor(rgb: 0x000000),
        incomingSecondaryTextColor: UIColor(rgb: 0x525252, alpha: 0.6),
        incomingLinkTextColor: UIColor(rgb: 0x004bad),
        incomingLinkHighlightColor: accentColor.withAlphaComponent(0.3),
        outgoingPrimaryTextColor: UIColor(rgb: 0xffffff),
        outgoingSecondaryTextColor: UIColor(rgb: 0xffffff, alpha: 0.6),
        outgoingLinkTextColor: UIColor(rgb: 0xffffff),
        outgoingLinkHighlightColor: UIColor(rgb: 0xffffff, alpha: 0.3),
        infoPrimaryTextColor: UIColor(rgb: 0x000000),
        infoLinkTextColor: UIColor(rgb: 0x004bad),
        incomingAccentTextColor: accentColor,
        outgoingAccentTextColor: UIColor(white: 1.0, alpha: 0.7),
        incomingAccentControlColor: accentColor,
        outgoingAccentControlColor: UIColor(white: 1.0, alpha: 0.7),
        incomingMediaActiveControlColor: accentColor,
        outgoingMediaActiveControlColor: UIColor(white: 1.0, alpha: 1.0),
        incomingMediaInactiveControlColor: UIColor(rgb: 0xcacaca),
        outgoingMediaInactiveControlColor: UIColor(white: 1.0, alpha: 0.6),
        outgoingCheckColor: UIColor(rgb: 0xffffff, alpha: 0.6),
        incomingPendingActivityColor: UIColor(rgb: 0x525252, alpha: 0.6),
        outgoingPendingActivityColor: UIColor(white: 1.0, alpha: 0.7),
        mediaDateAndStatusFillColor: UIColor(white: 0.0, alpha: 0.5),
        mediaDateAndStatusTextColor: .white,
        incomingFileTitleColor: UIColor(rgb: 0x0b8bed),
        outgoingFileTitleColor: UIColor(rgb: 0xffffff),
        incomingFileDescriptionColor: UIColor(rgb: 0x999999),
        outgoingFileDescriptionColor: UIColor(white: 1.0, alpha: 0.7),
        incomingFileDurationColor: UIColor(rgb: 0x525252, alpha: 0.6),
        outgoingFileDurationColor: UIColor(white: 1.0, alpha: 0.7),
        shareButtonFillColor: UIColor(rgb: 0xffffff, alpha: 0.5),
        shareButtonStrokeColor: UIColor(rgb: 0xE5E5EA),
        shareButtonForegroundColor: accentColor,
        mediaOverlayControlBackgroundColor: UIColor(white: 0.0, alpha: 0.6),
        mediaOverlayControlForegroundColor: UIColor(white: 1.0, alpha: 1.0),
        actionButtonsIncomingFillColor: UIColor(rgb: 0xffffff, alpha: 0.5),
        actionButtonsIncomingStrokeColor: UIColor(rgb: 0x3996ee),
        actionButtonsIncomingTextColor: UIColor(rgb: 0x3996ee),
        actionButtonsOutgoingFillColor: UIColor(rgb: 0xffffff, alpha: 0.5),
        actionButtonsOutgoingStrokeColor: UIColor(rgb: 0x3996ee),
        actionButtonsOutgoingTextColor: UIColor(rgb: 0x3996ee),
        selectionControlBorderColor: UIColor(rgb: 0xC7C7CC),
        selectionControlFillColor: accentColor,
        selectionControlForegroundColor: .white,
        mediaHighlightOverlayColor: UIColor(white: 1.0, alpha: 0.6)
    )
    
    let serviceMessage = PresentationThemeServiceMessage(
        serviceMessageFillColor: UIColor(rgb: 0x748391, alpha: 0.45),
        serviceMessagePrimaryTextColor: .white,
        serviceMessageLinkHighlightColor: UIColor(rgb: 0x748391, alpha: 0.25),
        unreadBarFillColor: UIColor(white: 1.0, alpha: 0.9),
        unreadBarStrokeColor: UIColor(white: 0.0, alpha: 0.2),
        unreadBarTextColor: UIColor(rgb: 0x86868d),
        dateFillStaticColor: UIColor(rgb: 0x748391, alpha: 0.45),
        dateFillFloatingColor: UIColor(rgb: 0x939fab, alpha: 0.5),
        dateTextColor: .white
    )
    
    let serviceMessageDay = PresentationThemeServiceMessage(
        serviceMessageFillColor: UIColor(rgb: 0xffffff, alpha: 0.8),
        serviceMessagePrimaryTextColor: UIColor(rgb: 0x8D8E93),
        serviceMessageLinkHighlightColor: UIColor(rgb: 0x748391, alpha: 0.25),
        unreadBarFillColor: UIColor(white: 1.0, alpha: 1.0),
        unreadBarStrokeColor: UIColor(white: 1.0, alpha: 1.0),
        unreadBarTextColor: UIColor(rgb: 0x8D8E93),
        dateFillStaticColor: UIColor(rgb: 0xffffff, alpha: 0.8),
        dateFillFloatingColor: UIColor(rgb: 0xffffff, alpha: 0.8),
        dateTextColor: UIColor(rgb: 0x8D8E93)
    )
    
    let inputPanelMediaRecordingControl = PresentationThemeChatInputPanelMediaRecordingControl(
        buttonColor: accentColor,
        micLevelColor: accentColor.withAlphaComponent(0.2),
        activeIconColor: .white,
        panelControlFillColor: UIColor(rgb: 0xf7f7f7),
        panelControlStrokeColor: UIColor(rgb: 0xb2b2b2),
        panelControlContentPrimaryColor: UIColor(rgb: 0x9597a0),
        panelControlContentAccentColor: accentColor
    )
    
    let inputPanel = PresentationThemeChatInputPanel(
        panelBackgroundColor: UIColor(rgb: 0xf7f7f7),
        panelStrokeColor: UIColor(rgb: 0xb2b2b2),
        panelControlAccentColor: accentColor,
        panelControlColor: UIColor(rgb: 0x858e99),
        panelControlDisabledColor: UIColor(rgb: 0x727b87, alpha: 0.5),
        panelControlDestructiveColor: UIColor(rgb: 0xff3b30),
        inputBackgroundColor: UIColor(rgb: 0xffffff),
        inputStrokeColor: UIColor(rgb: 0xd9dcdf),
        inputPlaceholderColor: UIColor(rgb: 0xbebec0),
        inputTextColor: .black,
        inputControlColor: UIColor(rgb: 0xa0a7b0),
        actionControlFillColor: accentColor,
        actionControlForegroundColor: .white,
        primaryTextColor: .black,
        secondaryTextColor: UIColor(rgb: 0x8e8e93),
        mediaRecordingDotColor: UIColor(rgb: 0xed2521),
        keyboardColor: .light,
        mediaRecordingControl: inputPanelMediaRecordingControl
    )
    
    let inputMediaPanel = PresentationThemeInputMediaPanel(
        panelSerapatorColor: UIColor(rgb: 0xBEC2C6),
        panelIconColor: UIColor(rgb: 0x858e99),
        panelHighlightedIconBackgroundColor: UIColor(rgb: 0x858e99, alpha: 0.2),
        stickersBackgroundColor: UIColor(rgb: 0xe8ebf0),
        stickersSectionTextColor: UIColor(rgb: 0x9099A2),
        stickersSearchBackgroundColor: UIColor(rgb: 0xd9dbe1),
        stickersSearchPlaceholderColor: UIColor(rgb: 0x8e8e93),
        stickersSearchPrimaryColor: .black,
        stickersSearchControlColor: UIColor(rgb: 0x8e8e93),
        gifsBackgroundColor: .white
    )
    
    let inputButtonPanel = PresentationThemeInputButtonPanel(
        panelSerapatorColor: UIColor(rgb: 0xBEC2C6),
        panelBackgroundColor: UIColor(rgb: 0xdee2e6),
        buttonFillColor: .white,
        buttonStrokeColor: UIColor(rgb: 0xc3c7c9),
        buttonHighlightedFillColor: UIColor(rgb: 0xa8b3c0),
        buttonHighlightedStrokeColor: UIColor(rgb: 0xc3c7c9),
        buttonTextColor: .black
    )
    
    let historyNavigation = PresentationThemeChatHistoryNavigation(
        fillColor: .white,
        strokeColor: UIColor(rgb: 0x000000, alpha: 0.15),
        foregroundColor: UIColor(rgb: 0x88888D),
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
    
    let chatDay = PresentationThemeChat(
        bubble: bubbleDay,
        serviceMessage: serviceMessageDay,
        inputPanel: inputPanel,
        inputMediaPanel: inputMediaPanel,
        inputButtonPanel: inputButtonPanel,
        historyNavigation: historyNavigation
    )
    
    let actionSheet = PresentationThemeActionSheet(
        dimColor: UIColor(white: 0.0, alpha: 0.4),
        backgroundType: .light,
        opaqueItemBackgroundColor: .white,
        itemBackgroundColor: UIColor(white: 1.0, alpha: 0.8),
        opaqueItemHighlightedBackgroundColor: UIColor(white: 0.9, alpha: 1.0),
        itemHighlightedBackgroundColor: UIColor(white: 0.9, alpha: 0.7),
        standardActionTextColor: accentColor,
        opaqueItemSeparatorColor: UIColor(white: 0.9, alpha: 1.0),
        destructiveActionTextColor: destructiveColor,
        disabledActionTextColor: UIColor(rgb: 0x4d4d4d),
        primaryTextColor: .black,
        secondaryTextColor: UIColor(rgb: 0x5e5e5e),
        controlAccentColor: accentColor,
        inputBackgroundColor: UIColor(rgb: 0xe9e9e9),
        inputPlaceholderColor: UIColor(rgb: 0x818086),
        inputTextColor: .black,
        inputClearButtonColor: UIColor(rgb: 0x7b7b81),
        checkContentColor: .white
    )
    
    let inAppNotification = PresentationThemeInAppNotification(
        fillColor: .white,
        primaryTextColor: .black,
        expandedNotification: PresentationThemeExpandedNotification(
            backgroundType: .light,
            navigationBar: PresentationThemeExpandedNotificationNavigationBar(
                backgroundColor: .white,
                primaryTextColor: .black,
                controlColor: UIColor(rgb: 0x7e8791),
                separatorColor: UIColor(red: 0.6953125, green: 0.6953125, blue: 0.6953125, alpha: 1.0)
            )
        )
    )
    
    return PresentationTheme(
        name: .builtin(day ? .day : .dayClassic),
        overallDarkAppearance: false,
        allowsCustomWallpapers: true,
        rootController: rootController,
        list: list,
        chatList: day ? chatListDay : chatList,
        chat: day ? chatDay : chat,
        actionSheet: actionSheet,
        inAppNotification: inAppNotification
    )
}

public let defaultPresentationTheme = makeDefaultPresentationTheme(accentColor: UIColor(rgb: 0x007ee5), day: false)

let defaultDayAccentColor: Int32 = 0x007ee5

func makeDefaultDayPresentationTheme(accentColor: Int32?) -> PresentationTheme {
    let color: UIColor
    if let accentColor = accentColor {
        color = UIColor(rgb: UInt32(bitPattern: accentColor))
    } else {
        color = UIColor(rgb: UInt32(bitPattern: defaultDayAccentColor))
    }
    return makeDefaultPresentationTheme(accentColor: color, day: true)
}
