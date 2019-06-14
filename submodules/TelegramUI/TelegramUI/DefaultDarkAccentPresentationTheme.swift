import Foundation
import UIKit

private let accentColor: UIColor = UIColor(rgb: 0x2EA6FF)
private let destructiveColor: UIColor = UIColor(rgb: 0xFF6767)
private let constructiveColor: UIColor = UIColor(rgb: 0x08a723)
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

private let auth = PresentationThemeAuth(
    introStartButton: accentColor,
    introDotColor: UIColor(rgb: 0x8B9197)
)

private let passcode = PresentationThemePasscode(
    backgroundColors: (UIColor(rgb: 0x1d2937), UIColor(rgb: 0x18222d)),
    buttonColor: UIColor(rgb: 0x213040)
    //backgroundColors: (UIColor(rgb: 0x263646), UIColor(rgb: 0x213040)),
    //buttonColor: UIColor(rgb: 0x7e93a0)
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
    contentColor: accentColor,
    positiveColor: accentColor,
    negativeColor: destructiveColor
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
        neutral1: PresentationThemeItemDisclosureAction(fillColor: UIColor(rgb: 0x007cd6), foregroundColor: .white),
        neutral2: PresentationThemeItemDisclosureAction(fillColor: UIColor(rgb: 0xcd7800), foregroundColor: .white),
        destructive: PresentationThemeItemDisclosureAction(fillColor: UIColor(rgb: 0xc70c0c), foregroundColor: .white),
        constructive: PresentationThemeItemDisclosureAction(fillColor: constructiveColor, foregroundColor: .white),
        accent: PresentationThemeItemDisclosureAction(fillColor: UIColor(rgb: 0x007cd6), foregroundColor: .white),
        warning: PresentationThemeItemDisclosureAction(fillColor: UIColor(rgb: 0xcd7800), foregroundColor: .white),
        inactive: PresentationThemeItemDisclosureAction(fillColor: UIColor(rgb: 0x26384c), foregroundColor: .white)
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
    scrollIndicatorColor: UIColor(white: 1.0, alpha: 0.3),
    pageIndicatorInactiveColor: UIColor(rgb: 0xDBF5FF, alpha: 0.4)
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
    failedFillColor: destructiveColor,
    failedForegroundColor: .white,
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
    secretIconColor: secretColor,
    pinnedArchiveAvatarColor: PresentationThemeArchiveAvatarColors(backgroundColors: (UIColor(rgb: 0x72d5fd), UIColor(rgb: 0x2a9ef1)), foregroundColor: .white),
    unpinnedArchiveAvatarColor: PresentationThemeArchiveAvatarColors(backgroundColors: (UIColor(rgb: 0x5d6d77), UIColor(rgb: 0x4e5c64)), foregroundColor: UIColor(rgb: 0x18222d)),
    onlineDotColor: UIColor(rgb: 0x4cc91f)
)

private let bubble = PresentationThemeChatBubble(
    incoming: PresentationThemeBubbleColor(withWallpaper: PresentationThemeBubbleColorComponents(fill: UIColor(rgb: 0x213040), highlightedFill: UIColor(rgb: 0x2D3A49), stroke: UIColor(rgb: 0x213040)), withoutWallpaper: PresentationThemeBubbleColorComponents(fill: UIColor(rgb: 0x213040), highlightedFill: UIColor(rgb: 0x2D3A49), stroke: UIColor(rgb: 0x213040))),
    outgoing: PresentationThemeBubbleColor(withWallpaper: PresentationThemeBubbleColorComponents(fill: UIColor(rgb: 0x3D6A97), highlightedFill: UIColor(rgb: 0x5079A1), stroke: UIColor(rgb: 0x3D6A97)), withoutWallpaper: PresentationThemeBubbleColorComponents(fill: UIColor(rgb: 0x3D6A97), highlightedFill: UIColor(rgb: 0x5079A1), stroke: UIColor(rgb: 0x3D6A97))),
    freeform: PresentationThemeBubbleColor(withWallpaper: PresentationThemeBubbleColorComponents(fill: UIColor(rgb: 0x213040), highlightedFill: UIColor(rgb: 0x2D3A49), stroke: UIColor(rgb: 0x213040)), withoutWallpaper: PresentationThemeBubbleColorComponents(fill: UIColor(rgb: 0x213040), highlightedFill: UIColor(rgb: 0x2D3A49), stroke: UIColor(rgb: 0x213040))),
    incomingPrimaryTextColor: UIColor(rgb: 0xffffff),
    incomingSecondaryTextColor: UIColor(rgb: 0xDBF5FF, alpha: 0.5),
    incomingLinkTextColor: accentColor,
    incomingLinkHighlightColor: accentColor.withAlphaComponent(0.5),
    incomingScamColor: destructiveColor,
    outgoingPrimaryTextColor: UIColor(rgb: 0xffffff),
    outgoingSecondaryTextColor: UIColor(rgb: 0xDBF5FF, alpha: 0.5),
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
    shareButtonFillColor: PresentationThemeVariableColor(color: UIColor(rgb: 0x18222d, alpha: 0.5)),
    shareButtonStrokeColor: PresentationThemeVariableColor(color: UIColor(rgb: 0x587fa3, alpha: 0.15)),
    shareButtonForegroundColor: PresentationThemeVariableColor(color: UIColor(rgb: 0xb2b2b2)),
    mediaOverlayControlBackgroundColor: UIColor(white: 0.0, alpha: 0.6), //!!!
    mediaOverlayControlForegroundColor: UIColor(white: 1.0, alpha: 1.0), //!!!
    actionButtonsIncomingFillColor: PresentationThemeVariableColor(withWallpaper: UIColor(rgb: 0x18222D, alpha: 0.5), withoutWallpaper: UIColor(rgb: 0x18222D, alpha: 0.5)),
    actionButtonsIncomingStrokeColor: PresentationThemeVariableColor(color: UIColor(rgb: 0x587fa3, alpha: 0.15)),
    actionButtonsIncomingTextColor: PresentationThemeVariableColor(color: UIColor(rgb: 0xffffff)),
    actionButtonsOutgoingFillColor: PresentationThemeVariableColor(withWallpaper: UIColor(rgb: 0x18222D, alpha: 0.5), withoutWallpaper: UIColor(rgb: 0x18222D, alpha: 0.5)),
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
    incomingPolls: PresentationThemeChatBubblePolls(radioButton: UIColor(rgb: 0x617583), radioProgress: accentColor, highlight: accentColor.withAlphaComponent(0.12), separator: UIColor(rgb: 0x131a23), bar: accentColor),
    outgoingPolls: PresentationThemeChatBubblePolls(radioButton: UIColor(rgb: 0x8eaac0), radioProgress: UIColor(rgb: 0x89d0ff), highlight: UIColor(rgb: 0x89d0ff).withAlphaComponent(0.12), separator: UIColor(rgb: 0x264b70), bar: UIColor(rgb: 0x89d0ff))
)

private let serviceMessage = PresentationThemeServiceMessage(
    components: PresentationThemeServiceMessageColor(withDefaultWallpaper: PresentationThemeServiceMessageColorComponents(fill: UIColor(rgb: 0x18222D, alpha: 1.0), primaryText: .white, linkHighlight: UIColor(rgb: 0xffffff, alpha: 0.12), scam: destructiveColor, dateFillStatic: UIColor(rgb: 0x18222D, alpha: 1.0), dateFillFloating: UIColor(rgb: 0x18222D, alpha: 0.2)), withCustomWallpaper: PresentationThemeServiceMessageColorComponents(fill: UIColor(rgb: 0x18222D, alpha: 1.0), primaryText: .white, linkHighlight: UIColor(rgb: 0xffffff, alpha: 0.12), scam: destructiveColor, dateFillStatic: UIColor(rgb: 0x18222D, alpha: 1.0), dateFillFloating: UIColor(rgb: 0x18222D, alpha: 0.2))),
    unreadBarFillColor: UIColor(rgb: 0x213040),
    unreadBarStrokeColor: UIColor(rgb: 0x213040),
    unreadBarTextColor: UIColor(rgb: 0xffffff),
    dateTextColor: PresentationThemeVariableColor(color: UIColor(rgb: 0xffffff))
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
    panelSeparatorColor: UIColor(rgb: 0x213040),
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
    panelSeparatorColor: UIColor(rgb: 0x213040),
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
    inputHollowBackgroundColor: UIColor(rgb: 0x182330),
    inputBorderColor: UIColor(rgb: 0x182330),
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
    auth: auth,
    passcode: passcode,
    rootController: rootController,
    list: list,
    chatList: chatList,
    chat: chat,
    actionSheet: actionSheet,
    inAppNotification: inAppNotification
)
