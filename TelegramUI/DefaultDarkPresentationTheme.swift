import Foundation
import UIKit

private let accentColor: UIColor = UIColor(rgb: 0xb2b2b2)
private let destructiveColor: UIColor = .red

private let rootStatusBar = PresentationThemeRootNavigationStatusBar(
    style: .white
)

private let rootTabBar = PresentationThemeRootTabBar(
    backgroundColor: UIColor(rgb: 0x121212),
    separatorColor: UIColor(rgb: 0x1f1f1f),
    iconColor: UIColor(rgb: 0x5e5e5e),
    selectedIconColor: accentColor,
    textColor: UIColor(rgb: 0x5e5e5e),
    selectedTextColor: accentColor,
    badgeBackgroundColor: UIColor(rgb: 0xff3600),
    badgeTextColor: .white)

private let rootNavigationBar = PresentationThemeRootNavigationBar(
    buttonColor: accentColor,
    primaryTextColor: accentColor,
    secondaryTextColor: UIColor(rgb: 0x5e5e5e),
    controlColor: UIColor(rgb: 0x5e5e5e),
    accentTextColor: accentColor,
    backgroundColor: UIColor(rgb: 0x121212),
    separatorColor: UIColor(rgb: 0x1a1a1a),
    badgeBackgroundColor: UIColor(rgb: 0xff3600),
    badgeTextColor: .white
)

private let activeNavigationSearchBar = PresentationThemeActiveNavigationSearchBar(
    backgroundColor: UIColor(rgb: 0x121212),
    accentColor: accentColor,
    inputFillColor: UIColor(rgb: 0x545454),
    inputTextColor: accentColor,
    inputPlaceholderTextColor: UIColor(rgb: 0x5e5e5e),
    inputIconColor: UIColor(rgb: 0x5e5e5e),
    inputClearButtonColor: UIColor(rgb: 0x5e5e5e),
    separatorColor: UIColor(rgb: 0x1a1a1a)
)

private let rootController = PresentationThemeRootController(
    statusBar: rootStatusBar,
    tabBar: rootTabBar,
    navigationBar: rootNavigationBar,
    activeNavigationSearchBar: activeNavigationSearchBar
)

private let switchColors = PresentationThemeSwitch(
    frameColor: UIColor(rgb: 0x545454),
    handleColor: UIColor(rgb: 0x121212),
    contentColor: UIColor(rgb: 0xb2b2b2)
)

private let list = PresentationThemeList(
    blocksBackgroundColor: UIColor(rgb: 0x121212),
    plainBackgroundColor: UIColor(rgb: 0x121212),
    itemPrimaryTextColor: UIColor(rgb: 0xb2b2b2),
    itemSecondaryTextColor: UIColor(rgb: 0x545454),
    itemDisabledTextColor: UIColor(rgb: 0x4d4d4d),
    itemAccentColor: accentColor,
    itemDestructiveColor: destructiveColor,
    itemPlaceholderTextColor: UIColor(rgb: 0x4d4d4d),
    itemBackgroundColor: UIColor(rgb: 0x121212),
    itemHighlightedBackgroundColor: UIColor(rgb: 0x1b1b1b),
    itemSeparatorColor: UIColor(rgb: 0x1a1a1a),
    disclosureArrowColor: UIColor(rgb: 0x545454),
    sectionHeaderTextColor: UIColor(rgb: 0x545454),
    freeTextColor: UIColor(rgb: 0x545454),
    freeTextErrorColor: UIColor(rgb: 0xcf3030),
    freeTextSuccessColor: UIColor(rgb: 0x30cf30),
    itemSwitchColors: switchColors
)

private let chatList = PresentationThemeChatList(
    backgroundColor: UIColor(rgb: 0x121212),
    itemSeparatorColor: UIColor(rgb: 0x1a1a1a),
    itemBackgroundColor: UIColor(rgb: 0x121212),
    pinnedItemBackgroundColor: UIColor(rgb: 0x121212),
    itemHighlightedBackgroundColor: UIColor(rgb: 0x1b1b1b),
    titleColor: UIColor(rgb: 0xb2b2b2),
    secretTitleColor: UIColor(rgb: 0xb2b2b2),
    dateTextColor: UIColor(rgb: 0x545454),
    authorNameColor: UIColor(rgb: 0xb2b2b2),
    messageTextColor: UIColor(rgb: 0x545454),
    messageDraftTextColor: UIColor(rgb: 0xdd4b39),
    checkmarkColor: UIColor(rgb: 0x545454),
    pendingIndicatorColor: UIColor(rgb: 0x545454),
    muteIconColor: UIColor(rgb: 0x626262),
    unreadBadgeActiveBackgroundColor: UIColor(rgb: 0xb2b2b2),
    unreadBadgeActiveTextColor: UIColor(rgb: 0x121212),
    unreadBadgeInactiveBackgroundColor: UIColor(rgb: 0x626262),
    unreadBadgeInactiveTextColor:UIColor(rgb: 0x121212),
    pinnedBadgeColor: UIColor(rgb: 0x121212),
    pinnedSearchBarColor: UIColor(rgb: 0x545454),
    regularSearchBarColor: UIColor(rgb: 0x545454),
    sectionHeaderFillColor: UIColor(rgb: 0x000000),
    sectionHeaderTextColor: UIColor(rgb: 0x545454),
    searchBarKeyboardColor: .dark
)

private let bubble = PresentationThemeChatBubble(
    incomingFillColor: UIColor(rgb: 0x1b1b1b),
    incomingFillHighlightedColor: UIColor(rgb: 0x4b4b4b),
    incomingStrokeColor: UIColor(rgb: 0x000000),
    outgoingFillColor: UIColor(rgb: 0x1b1b1b),
    outgoingFillHighlightedColor: UIColor(rgb: 0x4b4b4b),
    outgoingStrokeColor: UIColor(rgb: 0x000000),
    freeformFillColor: UIColor(rgb: 0x1b1b1b),
    freeformFillHighlightedColor: UIColor(rgb: 0x4b4b4b),
    freeformStrokeColor: UIColor(rgb: 0x000000),
    infoFillColor: UIColor(rgb: 0x1b1b1b),
    infoStrokeColor: UIColor(rgb: 0x000000),
    incomingPrimaryTextColor: UIColor(rgb: 0xb2b2b2),
    incomingSecondaryTextColor: UIColor(rgb: 0x545454),
    incomingLinkTextColor: accentColor,
    incomingLinkHighlightColor: accentColor.withAlphaComponent(0.5),
    outgoingPrimaryTextColor: UIColor(rgb: 0xb2b2b2),
    outgoingSecondaryTextColor: UIColor(rgb: 0x545454),
    outgoingLinkTextColor: accentColor,
    outgoingLinkHighlightColor: accentColor.withAlphaComponent(0.5),
    infoPrimaryTextColor: UIColor(rgb: 0xb2b2b2),
    infoLinkTextColor: accentColor,
    incomingAccentColor: accentColor,
    outgoingAccentColor: accentColor,
    outgoingCheckColor: UIColor(rgb: 0x545454),
    incomingPendingActivityColor: UIColor(rgb: 0x545454),
    outgoingPendingActivityColor: UIColor(rgb: 0x545454),
    mediaDateAndStatusFillColor: UIColor(white: 0.0, alpha: 0.5),
    mediaDateAndStatusTextColor: .white,
    incomingFileTitleColor: UIColor(rgb: 0xb2b2b2),
    outgoingFileTitleColor: UIColor(rgb: 0xb2b2b2),
    incomingFileDescriptionColor: UIColor(rgb: 0x545454),
    outgoingFileDescriptionColor: UIColor(rgb: 0x545454),
    incomingFileDurationColor: UIColor(rgb: 0x545454),
    outgoingFileDurationColor: UIColor(rgb: 0x545454),
    shareButtonFillColor: UIColor(rgb: 0xffffff, alpha: 0.2),
    shareButtonForegroundColor: UIColor(rgb: 0xb2b2b2),
    mediaOverlayControlBackgroundColor: UIColor(white: 0.0, alpha: 0.6),
    mediaOverlayControlForegroundColor: UIColor(white: 1.0, alpha: 0.6),
    actionButtonsFillColor: UIColor(rgb: 0x1b1b1b),
    actionButtonsTextColor: UIColor(rgb: 0xb2b2b2)
)

private let serviceMessage = PresentationThemeServiceMessage(
    serviceMessageFillColor: UIColor(rgb: 0xffffff, alpha: 0.2),
    serviceMessagePrimaryTextColor: UIColor(rgb: 0xb2b2b2),
    serviceMessageLinkHighlightColor: UIColor(rgb: 0xffffff, alpha: 0.2),
    unreadBarFillColor: UIColor(rgb: 0x1b1b1b),
    unreadBarStrokeColor: UIColor(rgb: 0x000000),
    unreadBarTextColor: UIColor(rgb: 0xb2b2b2),
    dateFillStaticColor: UIColor(rgb: 0xffffff, alpha: 0.2),
    dateFillFloatingColor: UIColor(rgb: 0xffffff, alpha: 0.2),
    dateTextColor: UIColor(rgb: 0xb2b2b2)
)

private let inputPanel = PresentationThemeChatInputPanel(
    panelBackgroundColor: UIColor(rgb: 0x1b1b1b),
    panelStrokeColor: UIColor(rgb: 0x000000),
    panelControlAccentColor: accentColor,
    panelControlColor: UIColor(rgb: 0x545454),
    panelControlDisabledColor: UIColor(rgb: 0x545454, alpha: 0.5),
    panelControlDestructiveColor: UIColor(rgb: 0xff3b30),
    inputBackgroundColor: UIColor(rgb: 0x121212),
    inputStrokeColor: UIColor(rgb: 0x000000),
    inputPlaceholderColor: UIColor(rgb: 0xb2b2b2, alpha: 0.5),
    inputTextColor: UIColor(rgb: 0xb2b2b2),
    inputControlColor: UIColor(rgb: 0xb2b2b2, alpha: 0.5),
    primaryTextColor: UIColor(rgb: 0xb2b2b2),
    mediaRecordingDotColor: .white,
    keyboardColor: .dark
)

private let inputMediaPanel = PresentationThemeInputMediaPanel(
    panelSerapatorColor: UIColor(rgb: 0x000000),
    panelIconColor: UIColor(rgb: 0x545454),
    panelHighlightedIconBackgroundColor: UIColor(rgb: 0x4b4b4b),
    stickersBackgroundColor: UIColor(rgb: 0x1b1b1b),
    stickersSectionTextColor: UIColor(rgb: 0xb2b2b2),
    gifsBackgroundColor: UIColor(rgb: 0x1b1b1b)
)

private let inputButtonPanel = PresentationThemeInputButtonPanel(
    panelSerapatorColor: UIColor(rgb: 0x000000),
    panelBackgroundColor: UIColor(rgb: 0x1b1b1b),
    buttonFillColor: UIColor(rgb: 0x1b1b1b),
    buttonStrokeColor: UIColor(rgb: 0x000000),
    buttonHighlightedFillColor: UIColor(rgb: 0x4b4b4b),
    buttonHighlightedStrokeColor: UIColor(rgb: 0x000000),
    buttonTextColor: UIColor(rgb: 0xb2b2b2)
)

private let historyNavigation = PresentationThemeChatHistoryNavigation(
    fillColor: .white,
    strokeColor: UIColor(rgb: 0x000000),
    foregroundColor: UIColor(rgb: 0x4b4b4b),
    badgeBackgroundColor: accentColor,
    badgeTextColor: .black
)

private let chat = PresentationThemeChat(
    bubble: bubble,
    serviceMessage: serviceMessage,
    inputPanel: inputPanel,
    inputMediaPanel: inputMediaPanel,
    inputButtonPanel: inputButtonPanel,
    historyNavigation: historyNavigation
)

let defaultDarkPresentationTheme = PresentationTheme(
    rootController: rootController,
    list: list,
    chatList: chatList,
    chat: chat
)
