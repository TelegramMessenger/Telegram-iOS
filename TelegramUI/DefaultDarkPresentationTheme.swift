import Foundation
import UIKit

private let accentColor: UIColor = UIColor(rgb: 0xffffff)
private let destructiveColor: UIColor = .red

private let rootStatusBar = PresentationThemeRootNavigationStatusBar(
    style: .white
)

private let rootTabBar = PresentationThemeRootTabBar(
    backgroundColor: UIColor(rgb: 0x1c1c1d),
    separatorColor: UIColor(rgb: 0x000000),
    iconColor: UIColor(rgb: 0x808080),
    selectedIconColor: accentColor,
    textColor: UIColor(rgb: 0x929292),
    selectedTextColor: accentColor,
    badgeBackgroundColor: .red, //!!!
    badgeTextColor: .white //!!!
)

private let rootNavigationBar = PresentationThemeRootNavigationBar(
    buttonColor: accentColor,
    primaryTextColor: accentColor,
    secondaryTextColor: UIColor(rgb: 0x5e5e5e),
    controlColor: accentColor,
    accentTextColor: accentColor,
    backgroundColor: UIColor(rgb: 0x1c1c1d),
    separatorColor: UIColor(rgb: 0x000000),
    badgeBackgroundColor: UIColor(rgb: 0xffffff),
    badgeTextColor: UIColor(rgb: 0x1c1c1d)
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
    blocksBackgroundColor: UIColor(rgb: 0x000000),
    plainBackgroundColor: UIColor(rgb: 0x000000),
    itemPrimaryTextColor: UIColor(rgb: 0xffffff),
    itemSecondaryTextColor: UIColor(rgb: 0x545454), //!!!
    itemDisabledTextColor: UIColor(rgb: 0x4d4d4d), //!!!
    itemAccentColor: accentColor,
    itemDestructiveColor: destructiveColor,
    itemPlaceholderTextColor: UIColor(rgb: 0x4d4d4d), //!!!
    itemBackgroundColor: UIColor(rgb: 0x1c1c1d),
    itemHighlightedBackgroundColor: UIColor(rgb: 0x1b1b1b), //!!!
    itemSeparatorColor: UIColor(rgb: 0x000000),
    disclosureArrowColor: UIColor(rgb: 0x545454), //!!!
    sectionHeaderTextColor: UIColor(rgb: 0x8d8e93),
    freeTextColor: UIColor(rgb: 0x8d8e93),
    freeTextErrorColor: UIColor(rgb: 0xcf3030), //!!!
    freeTextSuccessColor: UIColor(rgb: 0x30cf30), //!!!
    itemSwitchColors: switchColors
)

private let chatList = PresentationThemeChatList(
    backgroundColor: UIColor(rgb: 0x000000),
    itemSeparatorColor: UIColor(rgb: 0x252525),
    itemBackgroundColor: UIColor(rgb: 0x000000),
    pinnedItemBackgroundColor: UIColor(rgb: 0x1c1c1d),
    itemHighlightedBackgroundColor: UIColor(rgb: 0x1b1b1b), //!!!
    titleColor: UIColor(rgb: 0xffffff),
    secretTitleColor: UIColor(rgb: 0xb2b2b2), //!!!
    dateTextColor: UIColor(rgb: 0x8e8e93),
    authorNameColor: UIColor(rgb: 0xffffff),
    messageTextColor: UIColor(rgb: 0x8e8e93),
    messageDraftTextColor: UIColor(rgb: 0xdd4b39), //!!!
    checkmarkColor: UIColor(rgb: 0xffffff),
    pendingIndicatorColor: UIColor(rgb: 0xffffff), //!!!
    muteIconColor: UIColor(rgb: 0x8e8e93), //!!!
    unreadBadgeActiveBackgroundColor: UIColor(rgb: 0xffffff),
    unreadBadgeActiveTextColor: UIColor(rgb: 0x000000),
    unreadBadgeInactiveBackgroundColor: UIColor(rgb: 0x666666),
    unreadBadgeInactiveTextColor:UIColor(rgb: 0x000000),
    pinnedBadgeColor: UIColor(rgb: 0x767677),
    pinnedSearchBarColor: UIColor(rgb: 0x272728),
    regularSearchBarColor: UIColor(rgb: 0x272728), //!!!
    sectionHeaderFillColor: UIColor(rgb: 0x000000), //!!!
    sectionHeaderTextColor: UIColor(rgb: 0x545454), //!!!
    searchBarKeyboardColor: .dark
)

private let bubble = PresentationThemeChatBubble(
    incomingFillColor: UIColor(rgb: 0x1f1f1f),
    incomingFillHighlightedColor: UIColor(rgb: 0x4b4b4b), //!!!
    incomingStrokeColor: UIColor(rgb: 0x000000), //!!!
    outgoingFillColor: UIColor(rgb: 0x313131),
    outgoingFillHighlightedColor: UIColor(rgb: 0x4b4b4b), //!!!
    outgoingStrokeColor: UIColor(rgb: 0x000000),
    freeformFillColor: UIColor(rgb: 0x1f1f1f),
    freeformFillHighlightedColor: UIColor(rgb: 0x4b4b4b), //!!!
    freeformStrokeColor: UIColor(rgb: 0x000000),
    infoFillColor: UIColor(rgb: 0x1f1f1f),
    infoStrokeColor: UIColor(rgb: 0x000000),
    incomingPrimaryTextColor: UIColor(rgb: 0xffffff),
    incomingSecondaryTextColor: UIColor(rgb: 0xacacac), //!!!
    incomingLinkTextColor: accentColor, //!!!
    incomingLinkHighlightColor: accentColor.withAlphaComponent(0.5), //!!!
    outgoingPrimaryTextColor: UIColor(rgb: 0xffffff), //!!!
    outgoingSecondaryTextColor: UIColor(rgb: 0xacacac), //!!!
    outgoingLinkTextColor: accentColor, //!!!
    outgoingLinkHighlightColor: accentColor.withAlphaComponent(0.5), //!!!
    infoPrimaryTextColor: UIColor(rgb: 0xffffff),
    infoLinkTextColor: accentColor, //!!!
    incomingAccentColor: UIColor(rgb: 0xacacac), //!!!
    outgoingAccentColor: UIColor(rgb: 0xacacac),
    outgoingCheckColor: UIColor(rgb: 0xacacac),
    incomingPendingActivityColor: UIColor(rgb: 0xacacac), //!!!
    outgoingPendingActivityColor: UIColor(rgb: 0xacacac),
    mediaDateAndStatusFillColor: UIColor(white: 0.0, alpha: 0.5), //!!!
    mediaDateAndStatusTextColor: .white,
    incomingFileTitleColor: UIColor(rgb: 0xffffff),
    outgoingFileTitleColor: UIColor(rgb: 0xffffff),
    incomingFileDescriptionColor: UIColor(rgb: 0xacacac), //!!!
    outgoingFileDescriptionColor: UIColor(rgb: 0xacacac),
    incomingFileDurationColor: UIColor(rgb: 0xacacac),
    outgoingFileDurationColor: UIColor(rgb: 0xacacac),
    shareButtonFillColor: UIColor(rgb: 0xffffff, alpha: 0.2), //!!!
    shareButtonForegroundColor: UIColor(rgb: 0xb2b2b2), //!!!
    mediaOverlayControlBackgroundColor: UIColor(white: 0.0, alpha: 0.6), //!!!
    mediaOverlayControlForegroundColor: UIColor(white: 1.0, alpha: 0.6), //!!!
    actionButtonsFillColor: UIColor(rgb: 0x1b1b1b), //!!!
    actionButtonsTextColor: UIColor(rgb: 0xb2b2b2) //!!!
)

private let serviceMessage = PresentationThemeServiceMessage(
    serviceMessageFillColor: UIColor(rgb: 0x1f1f1f, alpha: 1.0),
    serviceMessagePrimaryTextColor: UIColor(rgb: 0xffffff),
    serviceMessageLinkHighlightColor: UIColor(rgb: 0xffffff, alpha: 0.12), //!!!
    unreadBarFillColor: UIColor(rgb: 0x1b1b1b), //!!!
    unreadBarStrokeColor: UIColor(rgb: 0x000000),
    unreadBarTextColor: UIColor(rgb: 0xb2b2b2), //!!!
    dateFillStaticColor: UIColor(rgb: 0x1f1f1f, alpha: 1.0),
    dateFillFloatingColor: UIColor(rgb: 0xffffff, alpha: 0.2),
    dateTextColor: UIColor(rgb: 0xb2b2b2)
)

private let inputPanelMediaRecordingControl = PresentationThemeChatInputPanelMediaRecordingControl(
    buttonColor: accentColor,
    micLevelColor: accentColor.withAlphaComponent(0.2),
    activeIconColor: .black,
    panelControlFillColor: UIColor(rgb: 0x1C1C1D),
    panelControlStrokeColor: UIColor(rgb: 0x1C1C1D),
    panelControlContentPrimaryColor: UIColor(rgb: 0x9597a0), //!!!
    panelControlContentAccentColor: accentColor
)

private let inputPanel = PresentationThemeChatInputPanel(
    panelBackgroundColor: UIColor(rgb: 0x1c1c1d),
    panelStrokeColor: UIColor(rgb: 0x000000),
    panelControlAccentColor: accentColor,
    panelControlColor: UIColor(rgb: 0x808080),
    panelControlDisabledColor: UIColor(rgb: 0x808080, alpha: 0.5), //!!!
    panelControlDestructiveColor: UIColor(rgb: 0xff3b30), //!!!
    inputBackgroundColor: UIColor(rgb: 0x060606),
    inputStrokeColor: UIColor(rgb: 0x060606),
    inputPlaceholderColor: UIColor(rgb: 0x7b7b7b),
    inputTextColor: UIColor(rgb: 0xffffff),
    inputControlColor: UIColor(rgb: 0xb2b2b2, alpha: 0.5), //!!!
    primaryTextColor: UIColor(rgb: 0xffffff),
    mediaRecordingDotColor: .white,
    keyboardColor: .dark,
    mediaRecordingControl: inputPanelMediaRecordingControl
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

private let actionSheet = PresentationThemeActionSheet(
    dimColor: UIColor(white: 0.0, alpha: 0.5),
    backgroundType: .dark,
    itemBackgroundColor: UIColor(rgb: 0x1c1c1d, alpha: 0.8), //!!!
    itemHighlightedBackgroundColor: UIColor(rgb: 0x000000, alpha: 0.5), //!!!
    standardActionTextColor: accentColor,
    destructiveActionTextColor: destructiveColor,
    disabledActionTextColor: UIColor(rgb: 0x4d4d4d), //!!!
    primaryTextColor: .white,
    secondaryTextColor: UIColor(rgb: 0x5e5e5e), //!!!
    controlAccentColor: accentColor
)

let defaultDarkPresentationTheme = PresentationTheme(
    rootController: rootController,
    list: list,
    chatList: chatList,
    chat: chat,
    actionSheet: actionSheet
)
