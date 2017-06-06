import Foundation

private let accentColor: UIColor = UIColor(rgb: 0x007ee5)
private let destructiveColor: UIColor = UIColor(rgb: 0xff3b30)

private let rootStatusBar = PresentationThemeRootNavigationStatusBar(
    style: .black
)

private let rootTabBar = PresentationThemeRootTabBar(
    backgroundColor: UIColor(rgb: 0xf7f7f7),
    separatorColor: UIColor(rgb: 0xa3a3a3),
    iconColor: UIColor(rgb: 0x929292),
    selectedIconColor: accentColor,
    textColor: UIColor(rgb: 0x929292),
    selectedTextColor: accentColor,
    badgeBackgroundColor: UIColor(rgb: 0xff3b30),
    badgeTextColor: .white)

private let rootNavigationBar = PresentationThemeRootNavigationBar(
    buttonColor: accentColor,
    primaryTextColor: .black,
    secondaryTextColor: UIColor(rgb: 0x787878),
    controlColor: UIColor(rgb: 0x7e8791),
    accentTextColor: accentColor,
    backgroundColor: UIColor(red: 0.968626451, green: 0.968626451, blue: 0.968626451, alpha: 1.0),
    separatorColor: UIColor(red: 0.6953125, green: 0.6953125, blue: 0.6953125, alpha: 1.0)
)

private let activeNavigationSearchBar = PresentationThemeActiveNavigationSearchBar(
    backgroundColor: .white,
    accentColor: accentColor,
    inputFillColor: UIColor(rgb: 0xe9e9e9),
    inputTextColor: .black,
    inputPlaceholderTextColor: UIColor(rgb: 0x8e8e93),
    inputIconColor: UIColor(rgb: 0x8e8e93),
    separatorColor: UIColor(red: 0.6953125, green: 0.6953125, blue: 0.6953125, alpha: 1.0)
)

private let rootController = PresentationThemeRootController(
    statusBar: rootStatusBar,
    tabBar: rootTabBar,
    navigationBar: rootNavigationBar,
    activeNavigationSearchBar: activeNavigationSearchBar
)

private let switchColors = PresentationThemeSwitch(
    frameColor: UIColor(rgb: 0xe0e0e0),
    handleColor: UIColor(rgb: 0xffffff),
    contentColor: UIColor(rgb: 0x42d451)
)

private let list = PresentationThemeList(
    blocksBackgroundColor: UIColor(rgb: 0xefeff4),
    plainBackgroundColor: .white,
    itemPrimaryTextColor: .black,
    itemSecondaryTextColor: UIColor(rgb: 0x8e8e93),
    itemDisabledTextColor: UIColor(rgb: 0x8e8e93),
    itemAccentColor: accentColor,
    itemDestructiveColor: destructiveColor,
    itemPlaceholderTextColor: UIColor(rgb: 0xc8c8ce),
    itemBackgroundColor: .white,
    itemHighlightedBackgroundColor: UIColor(rgb: 0xd9d9d9),
    itemSeparatorColor: UIColor(rgb: 0xc8c7cc),
    disclosureArrowColor: UIColor(rgb: 0xbab9be),
    sectionHeaderTextColor: UIColor(rgb: 0x6d6d72),
    freeTextColor: UIColor(rgb: 0x6d6d72),
    freeTextErrorColor: UIColor(rgb: 0xcf3030),
    freeTextSuccessColor: UIColor(rgb: 0x26972c),
    itemSwitchColors: switchColors
)

private let chatList = PresentationThemeChatList(
    backgroundColor: .white,
    itemSeparatorColor: UIColor(rgb: 0xc8c7cc),
    itemBackgroundColor: .white,
    pinnedItemBackgroundColor: UIColor(rgb: 0xf7f7f7),
    itemHighlightedBackgroundColor: UIColor(rgb: 0xd9d9d9),
    titleColor: .black,
    secretTitleColor: UIColor(rgb: 0x00a629),
    dateTextColor: UIColor(rgb: 0x8e8e93),
    authorNameColor: .black,
    messageTextColor: UIColor(rgb: 0x8e8e93),
    messageDraftTextColor: UIColor(rgb: 0xdd4b39),
    checkmarkColor: UIColor(rgb: 0x21c004),
    pendingIndicatorColor: UIColor(rgb: 0x8e8e93),
    unreadBadgeActiveBackgroundColor: UIColor(rgb: 0x007ee5),
    unreadBadgeActiveTextColor: .white,
    unreadBadgeInactiveBackgroundColor: UIColor(rgb: 0xadb3bb),
    unreadBadgeInactiveTextColor: .white,
    pinnedSearchBarColor: UIColor(rgb: 0xdfdfdf),
    regularSearchBarColor: UIColor(rgb: 0xe9e9e9),
    sectionHeaderFillColor: UIColor(rgb: 0xf7f7f7),
    sectionHeaderTextColor: UIColor(rgb: 0x8e8e93),
    searchBarKeyboardColor: .light
)

private let bubble = PresentationThemeChatBubble(
    incomingFillColor: UIColor(rgb: 0xffffff),
    incomingFillHighlightedColor: UIColor(rgb: 0xd9f4ff),
    incomingStrokeColor: UIColor(rgb: 0x86A9C9, alpha: 0.5),
    outgoingFillColor: UIColor(rgb: 0xE1FFC7),
    outgoingFillHighlightedColor: UIColor(rgb: 0xc8ffa6),
    outgoingStrokeColor: UIColor(rgb: 0x86A9C9, alpha: 0.5),
    freeformFillColor: UIColor(rgb: 0xffffff),
    freeformFillHighlightedColor: UIColor(rgb: 0xd9f4ff),
    freeformStrokeColor: UIColor(rgb: 0x86A9C9, alpha: 0.5),
    infoFillColor: UIColor(rgb: 0xffffff),
    infoStrokeColor: UIColor(rgb: 0x86A9C9, alpha: 0.5),
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
    incomingAccentColor: UIColor(rgb: 0x3ca7fe),
    outgoingAccentColor: UIColor(rgb: 0x00a700),
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
    shareButtonForegroundColor: .white,
    mediaOverlayControlBackgroundColor: UIColor(white: 0.0, alpha: 0.6),
    mediaOverlayControlForegroundColor: UIColor(white: 1.0, alpha: 0.6),
    actionButtonsFillColor: UIColor(rgb: 0x596E89),
    actionButtonsTextColor: .white
)

private let serviceMessage = PresentationThemeServiceMessage(
    serviceMessageFillColor: UIColor(rgb: 0x748391, alpha: 0.45),
    serviceMessagePrimaryTextColor: .white,
    unreadBarFillColor: UIColor(white: 1.0, alpha: 0.9),
    unreadBarStrokeColor: UIColor(white: 0.0, alpha: 0.2),
    unreadBarTextColor: UIColor(rgb: 0x86868d),
    dateFillStaticColor: UIColor(rgb: 0x748391, alpha: 0.45),
    dateFillFloatingColor: UIColor(rgb: 0x939fab, alpha: 0.5),
    dateTextColor: .white
)

private let inputPanel = PresentationThemeChatInputPanel(
    panelBackgroundColor: UIColor(rgb: 0xf2f4f6),
    panelStrokeColor: UIColor(rgb: 0xbdc2c7),
    panelControlAccentColor: accentColor,
    panelControlColor: UIColor(rgb: 0x727b87),
    panelControlDisabledColor: UIColor(rgb: 0x727b87, alpha: 0.5),
    panelControlDestructiveColor: UIColor(rgb: 0xff3b30),
    inputBackgroundColor: UIColor(rgb: 0xffffff),
    inputStrokeColor: UIColor(rgb: 0xd3d6da),
    inputPlaceholderColor: UIColor(rgb: 0xbebec0),
    inputTextColor: .black,
    inputControlColor: UIColor(rgb: 0x9099A2, alpha: 0.6),
    primaryTextColor: .black,
    mediaRecordingDotColor: UIColor(rgb: 0xed2521),
    keyboardColor: .light
)

private let inputMediaPanel = PresentationThemeInputMediaPanel(
    panelSerapatorColor: UIColor(rgb: 0xBEC2C6),
    panelIconColor: UIColor(rgb: 0x9099A2),
    panelHighlightedIconBackgroundColor: UIColor(rgb: 0x9099A2, alpha: 0.2),
    stickersBackgroundColor: UIColor(rgb: 0xE8EBF0),
    stickersSectionTextColor: UIColor(rgb: 0x9099A2),
    gifsBackgroundColor: .white
)

private let inputButtonPanel = PresentationThemeInputButtonPanel(
    panelSerapatorColor: UIColor(rgb: 0xBEC2C6),
    panelBackgroundColor: UIColor(rgb: 0x9099A2),
    buttonFillColor: .white,
    buttonStrokeColor: UIColor(rgb: 0xc3c7c9),
    buttonHighlightedFillColor: UIColor(rgb: 0xa8b3c0),
    buttonHighlightedStrokeColor: UIColor(rgb: 0xc3c7c9),
    buttonTextColor: .black
)

private let historyNavigation = PresentationThemeChatHistoryNavigation(
    fillColor: .white,
    strokeColor: UIColor(rgb: 0x000000, alpha: 0.15),
    foregroundColor: UIColor(rgb: 0x88888D),
    badgeBackgroundColor: accentColor,
    badgeTextColor: .white
)

private let chat = PresentationThemeChat(
    bubble: bubble,
    serviceMessage: serviceMessage,
    inputPanel: inputPanel,
    inputMediaPanel: inputMediaPanel,
    inputButtonPanel: inputButtonPanel,
    historyNavigation: historyNavigation
)

let defaultPresentationTheme = PresentationTheme(
    rootController: rootController,
    list: list,
    chatList: chatList,
    chat: chat
)
