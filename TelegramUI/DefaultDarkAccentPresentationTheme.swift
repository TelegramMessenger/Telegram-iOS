import Foundation
import UIKit

private let accentColor: UIColor = UIColor(rgb: 0x2EA6FF)
private let destructiveColor: UIColor = UIColor(rgb: 0xFF6767)
private let constructiveColor: UIColor = UIColor(rgb: 0x4cd964)
private let secretColor: UIColor = UIColor(rgb: 0x89DF9E)

private let rootStatusBar = PresentationThemeRootNavigationStatusBar(
    style: .white
)

private let rootTabBar = PresentationThemeRootTabBar(
    backgroundColor: UIColor(rgb: 0x213040),
    separatorColor: UIColor(rgb: 0x131A23),
    iconColor: UIColor(rgb: 0x7e929f),
    selectedIconColor: accentColor,
    textColor: UIColor(rgb: 0x7e929f),
    selectedTextColor: accentColor,
    badgeBackgroundColor: UIColor(rgb: 0xEF5B5B),
    badgeStrokeColor: UIColor(rgb: 0xEF5B5B),
    badgeTextColor: UIColor(rgb: 0xffffff)
)

private let rootNavigationBar = PresentationThemeRootNavigationBar(
    buttonColor: accentColor,
    disabledButtonColor: UIColor(rgb: 0x5b646f),
    primaryTextColor: UIColor(rgb: 0xffffff),
    secondaryTextColor: UIColor(rgb: 0x8B9197),
    controlColor: UIColor(rgb: 0x8B9197),
    accentTextColor: accentColor,
    backgroundColor: UIColor(rgb: 0x213040),
    separatorColor: UIColor(rgb: 0x131A23),
    badgeBackgroundColor: UIColor(rgb: 0xEF5B5B),
    badgeStrokeColor: UIColor(rgb: 0xEF5B5B),
    badgeTextColor: UIColor(rgb: 0xffffff)
)

private let activeNavigationSearchBar = PresentationThemeActiveNavigationSearchBar(
    backgroundColor: UIColor(rgb: 0x213040),
    accentColor: accentColor,
    inputFillColor: UIColor(rgb: 0x182330),
    inputTextColor: UIColor(rgb: 0xffffff),
    inputPlaceholderTextColor: UIColor(rgb: 0x8B9197),
    inputIconColor: UIColor(rgb: 0x8B9197),
    inputClearButtonColor: UIColor(rgb: 0x8B9197),
    separatorColor: UIColor(rgb: 0x18222C)
)

private let rootController = PresentationThemeRootController(
    statusBar: rootStatusBar,
    tabBar: rootTabBar,
    navigationBar: rootNavigationBar,
    activeNavigationSearchBar: activeNavigationSearchBar
)

private let switchColors = PresentationThemeSwitch(
    frameColor: UIColor(rgb: 0xDBF5FF, alpha: 0.5),
    handleColor: UIColor(rgb: 0x121212),
    contentColor: accentColor
)

private let list = PresentationThemeList(
    blocksBackgroundColor: UIColor(rgb: 0x18222D),
    plainBackgroundColor: UIColor(rgb: 0x18222D),
    itemPrimaryTextColor: UIColor(rgb: 0xffffff),
    itemSecondaryTextColor: UIColor(rgb: 0xDBF5FF, alpha: 0.5),
    itemDisabledTextColor: UIColor(rgb: 0xDBF5FF, alpha: 0.5), //!!!
    itemAccentColor: accentColor,
    itemHighlightedColor: UIColor(rgb: 0x28b772),
    itemDestructiveColor: destructiveColor,
    itemPlaceholderTextColor: UIColor(rgb: 0xDBF5FF, alpha: 0.5), //!!!
    itemBlocksBackgroundColor: UIColor(rgb: 0x213040),
    itemHighlightedBackgroundColor: UIColor(rgb: 0x10171F),
    itemBlocksSeparatorColor: UIColor(rgb: 0x131A23),
    itemPlainSeparatorColor: UIColor(rgb: 0x131A23),
    disclosureArrowColor: UIColor(rgb: 0xDBF5FF, alpha: 0.5), //!!!
    sectionHeaderTextColor: UIColor(rgb: 0x82888E),
    freeTextColor: UIColor(rgb: 0x82888E),
    freeTextErrorColor: destructiveColor, //!!!
    freeTextSuccessColor: UIColor(rgb: 0x30cf30), //!!!
    freeMonoIcon: UIColor(rgb: 0x82888E),
    itemSwitchColors: switchColors,
    itemDisclosureActions: PresentationThemeItemDisclosureActions(
        neutral1: PresentationThemeItemDisclosureAction(fillColor: UIColor(rgb: 0x415A71), foregroundColor: .white),
        neutral2: PresentationThemeItemDisclosureAction(fillColor: UIColor(rgb: 0x374F63), foregroundColor: .white),
        destructive: PresentationThemeItemDisclosureAction(fillColor: destructiveColor, foregroundColor: .white),
        constructive: PresentationThemeItemDisclosureAction(fillColor: constructiveColor, foregroundColor: .white),
        accent: PresentationThemeItemDisclosureAction(fillColor: accentColor, foregroundColor: .white),
        warning: PresentationThemeItemDisclosureAction(fillColor: UIColor(rgb: 0x3c4e61), foregroundColor: .white),
        inactive: PresentationThemeItemDisclosureAction(fillColor: UIColor(rgb: 0x415A71), foregroundColor: .white)
    ),
    itemCheckColors: PresentationThemeCheck(
        strokeColor: UIColor(rgb: 0xDBF5FF, alpha: 0.5),
        fillColor: accentColor,
        foregroundColor: .white
    ),
    controlSecondaryColor: UIColor(rgb: 0xDBF5FF, alpha: 0.5),
    freeInputField: PresentationInputFieldTheme(
        backgroundColor: UIColor(rgb: 0xDBF5FF, alpha: 0.5),
        placeholderColor: UIColor(rgb: 0x4d4d4d),
        primaryColor: .white,
        controlColor: UIColor(rgb: 0x4d4d4d)
    ),
    mediaPlaceholderColor: UIColor(rgb: 0x1e2c3a),
    scrollIndicatorColor: UIColor(white: 1.0, alpha: 0.3)
)

private let chatList = PresentationThemeChatList(
    backgroundColor: UIColor(rgb: 0x18222D),
    itemSeparatorColor: UIColor(rgb: 0x131A23),
    itemBackgroundColor: UIColor(rgb: 0x18222D),
    pinnedItemBackgroundColor: UIColor(rgb: 0x213040),
    itemHighlightedBackgroundColor: UIColor(rgb: 0x10171F),
    itemSelectedBackgroundColor: UIColor(rgb: 0x10171F),
    titleColor: UIColor(rgb: 0xffffff),
    secretTitleColor: secretColor,
    dateTextColor: UIColor(rgb: 0xDBF5FF, alpha: 0.5),
    authorNameColor: UIColor(rgb: 0xffffff),
    messageTextColor: UIColor(rgb: 0xDBF5FF, alpha: 0.5),
    messageDraftTextColor: UIColor(rgb: 0xdd4b39), //!!!
    checkmarkColor: accentColor,
    pendingIndicatorColor: UIColor(rgb: 0x8E8E93),
    muteIconColor: UIColor(rgb: 0x8E8E93),
    unreadBadgeActiveBackgroundColor: accentColor,
    unreadBadgeActiveTextColor: UIColor(rgb: 0xffffff),
    unreadBadgeInactiveBackgroundColor: UIColor(rgb: 0xDBF5FF, alpha: 0.4),
    unreadBadgeInactiveTextColor: UIColor(rgb: 0x000000),
    pinnedBadgeColor: UIColor(rgb: 0xDBF5FF, alpha: 0.5),
    pinnedSearchBarColor: UIColor(rgb: 0x182330),
    regularSearchBarColor: UIColor(rgb: 0x0F161E),
    sectionHeaderFillColor: UIColor(rgb: 0x213040),
    sectionHeaderTextColor: UIColor(rgb: 0xDBF5FF, alpha: 0.5),
    searchBarKeyboardColor: .dark,
    verifiedIconFillColor: accentColor,
    verifiedIconForegroundColor: .white,
    secretIconColor: secretColor
)

private let bubble = PresentationThemeChatBubble(
    incoming: PresentationThemeBubbleColor(withWallpaper: PresentationThemeBubbleColorComponents(fill: UIColor(rgb: 0x213040), highlightedFill: UIColor(rgb: 0x2D3A49), stroke: UIColor(rgb: 0x213040)), withoutWallpaper: PresentationThemeBubbleColorComponents(fill: UIColor(rgb: 0x213040), highlightedFill: UIColor(rgb: 0x2D3A49), stroke: UIColor(rgb: 0x213040))),
    outgoing: PresentationThemeBubbleColor(withWallpaper: PresentationThemeBubbleColorComponents(fill: UIColor(rgb: 0x3D6A97), highlightedFill: UIColor(rgb: 0x5079A1), stroke: UIColor(rgb: 0x3D6A97)), withoutWallpaper: PresentationThemeBubbleColorComponents(fill: UIColor(rgb: 0x3D6A97), highlightedFill: UIColor(rgb: 0x5079A1), stroke: UIColor(rgb: 0x3D6A97))),
    freeform: PresentationThemeBubbleColor(withWallpaper: PresentationThemeBubbleColorComponents(fill: UIColor(rgb: 0x213040), highlightedFill: UIColor(rgb: 0x2D3A49), stroke: UIColor(rgb: 0x213040)), withoutWallpaper: PresentationThemeBubbleColorComponents(fill: UIColor(rgb: 0x213040), highlightedFill: UIColor(rgb: 0x2D3A49), stroke: UIColor(rgb: 0x213040))),
    incomingPrimaryTextColor: UIColor(rgb: 0xffffff),
    incomingSecondaryTextColor: UIColor(rgb: 0xDBF5FF, alpha: 0.5),
    incomingLinkTextColor: accentColor,
    incomingLinkHighlightColor: accentColor.withAlphaComponent(0.5),
    outgoingPrimaryTextColor: UIColor(rgb: 0xffffff),
    outgoingSecondaryTextColor: UIColor(rgb: 0xDBF5FF, alpha: 0.5),
    outgoingLinkTextColor: accentColor,
    outgoingLinkHighlightColor: accentColor.withAlphaComponent(0.5),
    infoPrimaryTextColor: UIColor(rgb: 0xffffff),
    infoLinkTextColor: accentColor,
    incomingAccentTextColor: UIColor(rgb: 0xffffff),
    outgoingAccentTextColor: UIColor(rgb: 0xffffff),
    incomingAccentControlColor: UIColor(rgb: 0xffffff),
    outgoingAccentControlColor: UIColor(rgb: 0xffffff),
    incomingMediaActiveControlColor: UIColor(rgb: 0xffffff, alpha: 0.6),
    outgoingMediaActiveControlColor: UIColor(rgb: 0xffffff, alpha: 0.6),
    incomingMediaInactiveControlColor: UIColor(rgb: 0xffffff, alpha: 0.3),
    outgoingMediaInactiveControlColor: UIColor(rgb: 0xffffff, alpha: 0.3),
    outgoingCheckColor: UIColor(rgb: 0x64c0ff),
    incomingPendingActivityColor: UIColor(rgb: 0xDBF5FF, alpha: 0.5),
    outgoingPendingActivityColor: UIColor(rgb: 0xDBF5FF, alpha: 0.5),
    mediaDateAndStatusFillColor: UIColor(white: 0.0, alpha: 0.5),
    mediaDateAndStatusTextColor: .white,
    incomingFileTitleColor: UIColor(rgb: 0xffffff),
    outgoingFileTitleColor: UIColor(rgb: 0xffffff),
    incomingFileDescriptionColor: UIColor(rgb: 0xDBF5FF, alpha: 0.5),
    outgoingFileDescriptionColor: UIColor(rgb: 0xDBF5FF, alpha: 0.5),
    incomingFileDurationColor: UIColor(rgb: 0xDBF5FF, alpha: 0.5),
    outgoingFileDurationColor: UIColor(rgb: 0xDBF5FF, alpha: 0.5),
    shareButtonFillColor: PresentationThemeVariableColor(withWallpaper: UIColor(rgb: 0x18222D, alpha: 0.5), withoutWallpaper: UIColor(rgb: 0x18222D, alpha: 0.5)),
    shareButtonStrokeColor: UIColor(rgb: 0x213040),
    shareButtonForegroundColor: UIColor(rgb: 0xb2b2b2), //!!!
    mediaOverlayControlBackgroundColor: UIColor(white: 0.0, alpha: 0.6), //!!!
    mediaOverlayControlForegroundColor: UIColor(white: 1.0, alpha: 1.0), //!!!
    actionButtonsIncomingFillColor: PresentationThemeVariableColor(withWallpaper: UIColor(rgb: 0x18222D, alpha: 0.5), withoutWallpaper: UIColor(rgb: 0x18222D, alpha: 0.5)),
    actionButtonsIncomingStrokeColor: UIColor(rgb: 0x213040),
    actionButtonsIncomingTextColor: UIColor(rgb: 0xffffff),
    actionButtonsOutgoingFillColor: PresentationThemeVariableColor(withWallpaper: UIColor(rgb: 0x18222D, alpha: 0.5), withoutWallpaper: UIColor(rgb: 0x18222D, alpha: 0.5)),
    actionButtonsOutgoingStrokeColor: UIColor(rgb: 0x213040),
    actionButtonsOutgoingTextColor: UIColor(rgb: 0xffffff),
    selectionControlBorderColor: .white,
    selectionControlFillColor: accentColor,
    selectionControlForegroundColor: .white,
    mediaHighlightOverlayColor: UIColor(white: 1.0, alpha: 0.6),
    deliveryFailedFillColor: destructiveColor,
    deliveryFailedForegroundColor: .white,
    incomingMediaPlaceholderColor: UIColor(rgb: 0x1e2c3a),
    outgoingMediaPlaceholderColor: UIColor(rgb: 0x2d5883)
)

private let serviceMessage = PresentationThemeServiceMessage(
    components: PresentationThemeServiceMessageColor(withDefaultWallpaper: PresentationThemeServiceMessageColorComponents(fill: UIColor(rgb: 0x18222D, alpha: 1.0), primaryText: UIColor(rgb: 0xffffff), linkHighlight: UIColor(rgb: 0xffffff, alpha: 0.12), dateFillStatic: UIColor(rgb: 0x18222D, alpha: 1.0), dateFillFloating: UIColor(rgb: 0x18222D, alpha: 0.2)), withCustomWallpaper: PresentationThemeServiceMessageColorComponents(fill: UIColor(rgb: 0x18222D, alpha: 1.0), primaryText: UIColor(rgb: 0xffffff), linkHighlight: UIColor(rgb: 0xffffff, alpha: 0.12), dateFillStatic: UIColor(rgb: 0x18222D, alpha: 1.0), dateFillFloating: UIColor(rgb: 0x18222D, alpha: 0.2))),
    unreadBarFillColor: UIColor(rgb: 0x213040),
    unreadBarStrokeColor: UIColor(rgb: 0x213040),
    unreadBarTextColor: UIColor(rgb: 0xffffff),
    dateTextColor: UIColor(rgb: 0xffffff)
)

private let inputPanelMediaRecordingControl = PresentationThemeChatInputPanelMediaRecordingControl(
    buttonColor: accentColor,
    micLevelColor: accentColor.withAlphaComponent(0.2),
    activeIconColor: .white,
    panelControlFillColor: UIColor(rgb: 0x213040),
    panelControlStrokeColor: UIColor(rgb: 0x213040),
    panelControlContentPrimaryColor: UIColor(rgb: 0xDBF5FF, alpha: 0.5), //!!!
    panelControlContentAccentColor: accentColor
)

private let inputPanel = PresentationThemeChatInputPanel(
    panelBackgroundColor: UIColor(rgb: 0x213040),
    panelStrokeColor: UIColor(rgb: 0x131A23),
    panelControlAccentColor: accentColor,
    panelControlColor: UIColor(rgb: 0xDBF5FF, alpha: 0.5),
    panelControlDisabledColor: UIColor(rgb: 0x90979F, alpha: 0.5), //!!!
    panelControlDestructiveColor: destructiveColor,
    inputBackgroundColor: UIColor(rgb: 0x131C26),
    inputStrokeColor: UIColor(rgb: 0x131C26),
    inputPlaceholderColor: UIColor(rgb: 0xDBF5FF, alpha: 0.4),
    inputTextColor: UIColor(rgb: 0xffffff),
    inputControlColor: UIColor(rgb: 0xDBF5FF, alpha: 0.4),
    actionControlFillColor: accentColor,
    actionControlForegroundColor: .white,
    primaryTextColor: UIColor(rgb: 0xffffff),
    secondaryTextColor: UIColor(rgb: 0xffffff, alpha: 0.5),
    mediaRecordingDotColor: accentColor,
    keyboardColor: .dark,
    mediaRecordingControl: inputPanelMediaRecordingControl
)

private let inputMediaPanel = PresentationThemeInputMediaPanel(
    panelSerapatorColor: UIColor(rgb: 0x213040),
    panelIconColor: UIColor(rgb: 0xDBF5FF, alpha: 0.5),
    panelHighlightedIconBackgroundColor: UIColor(rgb: 0x131C26), //!!!
    stickersBackgroundColor: UIColor(rgb: 0x18222d),
    stickersSectionTextColor: UIColor(rgb: 0xDBF5FF, alpha: 0.5),
    stickersSearchBackgroundColor: UIColor(rgb: 0x121c25),
    stickersSearchPlaceholderColor: UIColor(rgb: 0x788a96),
    stickersSearchPrimaryColor: .white,
    stickersSearchControlColor: UIColor(rgb: 0x788a96),
    gifsBackgroundColor: UIColor(rgb: 0x18222d)
)

private let inputButtonPanel = PresentationThemeInputButtonPanel(
    panelSerapatorColor: UIColor(rgb: 0x213040),
    panelBackgroundColor: UIColor(rgb: 0x161A20),
    buttonFillColor: UIColor(rgb: 0x5B5F62),
    buttonStrokeColor: UIColor(rgb: 0x0D1013),
    buttonHighlightedFillColor: UIColor(rgb: 0x5B5F62, alpha: 0.7),
    buttonHighlightedStrokeColor: UIColor(rgb: 0x0D1013),
    buttonTextColor: UIColor(rgb: 0xffffff)
)

private let historyNavigation = PresentationThemeChatHistoryNavigation(
    fillColor: UIColor(rgb: 0x213040),
    strokeColor: UIColor(rgb: 0x131A23),
    foregroundColor: UIColor(rgb: 0xDBF5FF, alpha: 0.5),
    badgeBackgroundColor: accentColor,
    badgeStrokeColor: accentColor,
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

private let actionSheet = PresentationThemeActionSheet(
    dimColor: UIColor(white: 0.0, alpha: 0.5),
    backgroundType: .dark,
    opaqueItemBackgroundColor: UIColor(rgb: 0x213040),
    itemBackgroundColor: UIColor(rgb: 0x213040, alpha: 0.8),
    opaqueItemHighlightedBackgroundColor: UIColor(rgb: 0x10171F),
    itemHighlightedBackgroundColor: UIColor(rgb: 0x10171F, alpha: 0.2), //!!!
    standardActionTextColor: accentColor,
    opaqueItemSeparatorColor: UIColor(rgb: 0x18222D),
    destructiveActionTextColor: destructiveColor,
    disabledActionTextColor: UIColor(white: 1.0, alpha: 0.5), //!!!
    primaryTextColor: .white,
    secondaryTextColor: UIColor(white: 1.0, alpha: 0.5), //!!!
    controlAccentColor: accentColor,
    inputBackgroundColor: UIColor(rgb: 0x182330), //!!!
    inputPlaceholderColor: UIColor(rgb: 0x8B9197), //!!!
    inputTextColor: .white,
    inputClearButtonColor: UIColor(rgb: 0x8B9197),
    checkContentColor: .white
)

private let inAppNotification = PresentationThemeInAppNotification(
    fillColor: UIColor(rgb: 0x213040),
    primaryTextColor: .white,
    expandedNotification: PresentationThemeExpandedNotification(
        backgroundType: .dark,
        navigationBar: PresentationThemeExpandedNotificationNavigationBar(
            backgroundColor: UIColor(rgb: 0x213040),
            primaryTextColor: UIColor(rgb: 0xffffff),
            controlColor: accentColor,
            separatorColor: UIColor(rgb: 0x131A23)
        )
    )
)

let defaultDarkAccentPresentationTheme = PresentationTheme(
    name: .builtin(.nightAccent),
    overallDarkAppearance: true,
    allowsCustomWallpapers: false,
    rootController: rootController,
    list: list,
    chatList: chatList,
    chat: chat,
    actionSheet: actionSheet,
    inAppNotification: inAppNotification
)
