import Foundation
import UIKit

private let accentColor: UIColor = UIColor(rgb: 0xffffff)
private let destructiveColor: UIColor = UIColor(rgb: 0xFF736B)
private let constructiveColor: UIColor = UIColor(rgb: 0x08a723)
private let secretColor: UIColor = UIColor(rgb: 0x00B12C)

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
    badgeBackgroundColor: UIColor(rgb: 0xffffff),
    badgeStrokeColor: UIColor(rgb: 0x1c1c1d),
    badgeTextColor: UIColor(rgb: 0x000000)
)

private let rootNavigationBar = PresentationThemeRootNavigationBar(
    buttonColor: accentColor,
    disabledButtonColor: UIColor(rgb: 0x525252),
    primaryTextColor: accentColor,
    secondaryTextColor: UIColor(rgb: 0xffffff, alpha: 0.5),
    controlColor: UIColor(rgb: 0x767677),
    accentTextColor: accentColor,
    backgroundColor: UIColor(rgb: 0x1c1c1d),
    separatorColor: UIColor(rgb: 0x000000),
    badgeBackgroundColor: UIColor(rgb: 0xffffff),
    badgeStrokeColor: UIColor(rgb: 0x1c1c1d),
    badgeTextColor: UIColor(rgb: 0x1c1c1d)
)

private let activeNavigationSearchBar = PresentationThemeActiveNavigationSearchBar(
    backgroundColor: UIColor(rgb: 0x1c1c1d),
    accentColor: accentColor,
    inputFillColor: UIColor(rgb: 0x272728),
    inputTextColor: accentColor,
    inputPlaceholderTextColor: UIColor(rgb: 0x5e5e5e),
    inputIconColor: UIColor(rgb: 0x5e5e5e),
    inputClearButtonColor: UIColor(rgb: 0x5e5e5e),
    separatorColor: UIColor(rgb: 0x000000)
)

private let auth = PresentationThemeAuth(
    introStartButton: accentColor,
    introDotColor: UIColor(rgb: 0x5e5e5e)
)

private let passcode = PresentationThemePasscode(
    backgroundColors: (UIColor(rgb: 0x000000), UIColor(rgb: 0x000000)),
    buttonColor: UIColor(rgb: 0x1c1c1d)
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
    contentColor: UIColor(rgb: 0xb2b2b2),
    positiveColor: UIColor(rgb: 0x000000),
    negativeColor: destructiveColor
)

private let list = PresentationThemeList(
    blocksBackgroundColor: UIColor(rgb: 0x000000),
    plainBackgroundColor: UIColor(rgb: 0x000000),
    itemPrimaryTextColor: UIColor(rgb: 0xffffff),
    itemSecondaryTextColor: UIColor(rgb: 0xffffff, alpha: 0.5),
    itemDisabledTextColor: UIColor(rgb: 0x4d4d4d), //!!!
    itemAccentColor: accentColor,
    itemHighlightedColor: UIColor(rgb: 0x28b772),
    itemDestructiveColor: destructiveColor,
    itemPlaceholderTextColor: UIColor(rgb: 0x4d4d4d), //!!!
    itemBlocksBackgroundColor: UIColor(rgb: 0x1c1c1d),
    itemHighlightedBackgroundColor: UIColor(rgb: 0x191919),
    itemBlocksSeparatorColor: UIColor(rgb: 0x000000),
    itemPlainSeparatorColor: UIColor(rgb: 0x252525),
    disclosureArrowColor: UIColor(rgb: 0x545454), //!!!
    sectionHeaderTextColor: UIColor(rgb: 0xffffff),
    freeTextColor: UIColor(rgb: 0x8d8e93),
    freeTextErrorColor: UIColor(rgb: 0xcf3030), //!!!
    freeTextSuccessColor: UIColor(rgb: 0x30cf30), //!!!
    freeMonoIcon: UIColor(rgb: 0x8d8e93),
    itemSwitchColors: switchColors,
    itemDisclosureActions: PresentationThemeItemDisclosureActions(
        neutral1: PresentationThemeItemDisclosureAction(fillColor: UIColor(rgb: 0x666666), foregroundColor: .white),
        neutral2: PresentationThemeItemDisclosureAction(fillColor: UIColor(rgb: 0xcd7800), foregroundColor: .white),
        destructive: PresentationThemeItemDisclosureAction(fillColor: UIColor(rgb: 0xc70c0c), foregroundColor: .white),
        constructive: PresentationThemeItemDisclosureAction(fillColor: constructiveColor, foregroundColor: .white),
        accent: PresentationThemeItemDisclosureAction(fillColor: UIColor(rgb: 0x666666), foregroundColor: .white),
        warning: PresentationThemeItemDisclosureAction(fillColor: UIColor(rgb: 0xcd7800), foregroundColor: .white),
        inactive: PresentationThemeItemDisclosureAction(fillColor: UIColor(rgb: 0x666666), foregroundColor: .white)
    ),
    itemCheckColors: PresentationThemeCheck(
        strokeColor: UIColor(rgb: 0xffffff, alpha: 0.5),
        fillColor: accentColor,
        foregroundColor: UIColor(rgb: 0x000000)
    ),
    controlSecondaryColor: UIColor(rgb: 0xffffff, alpha: 0.5),
    freeInputField: PresentationInputFieldTheme(
        backgroundColor: UIColor(rgb: 0xffffff, alpha: 0.5),
        placeholderColor: UIColor(rgb: 0x4d4d4d),
        primaryColor: .white,
        controlColor: UIColor(rgb: 0x4d4d4d)
    ),
    mediaPlaceholderColor: UIColor(rgb: 0x1c1c1d),
    scrollIndicatorColor: UIColor(white: 1.0, alpha: 0.3),
    pageIndicatorInactiveColor: UIColor(white: 1.0, alpha: 0.3)
)

private let chatList = PresentationThemeChatList(
    backgroundColor: UIColor(rgb: 0x000000),
    itemSeparatorColor: UIColor(rgb: 0x252525),
    itemBackgroundColor: UIColor(rgb: 0x000000),
    pinnedItemBackgroundColor: UIColor(rgb: 0x1c1c1d),
    itemHighlightedBackgroundColor: UIColor(rgb: 0x191919),
    itemSelectedBackgroundColor: UIColor(rgb: 0x191919),
    titleColor: UIColor(rgb: 0xffffff),
    secretTitleColor: secretColor, //!!!
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
    sectionHeaderFillColor: UIColor(rgb: 0x1C1C1D),
    sectionHeaderTextColor: UIColor(rgb: 0xffffff),
    searchBarKeyboardColor: .dark,
    verifiedIconFillColor: accentColor,
    verifiedIconForegroundColor: .white,
    secretIconColor: secretColor,
    pinnedArchiveAvatarColor: PresentationThemeArchiveAvatarColors(backgroundColors: (UIColor(rgb: 0x72d5fd), UIColor(rgb: 0x2a9ef1)), foregroundColor: .white),
    unpinnedArchiveAvatarColor: PresentationThemeArchiveAvatarColors(backgroundColors: (UIColor(rgb: 0x666666), UIColor(rgb: 0x666666)), foregroundColor: .black),
    onlineDotColor: UIColor(rgb: 0x4cc91f)
)

private let bubble = PresentationThemeChatBubble(
    incoming: PresentationThemeBubbleColor(withWallpaper: PresentationThemeBubbleColorComponents(fill: UIColor(rgb: 0x1f1f1f), highlightedFill: UIColor(rgb: 0x2A2A2A), stroke: UIColor(rgb: 0x1f1f1f)), withoutWallpaper: PresentationThemeBubbleColorComponents(fill: UIColor(rgb: 0x1f1f1f), highlightedFill: UIColor(rgb: 0x2A2A2A), stroke: UIColor(rgb: 0x1f1f1f))),
    outgoing: PresentationThemeBubbleColor(withWallpaper: PresentationThemeBubbleColorComponents(fill: UIColor(rgb: 0x313131), highlightedFill: UIColor(rgb: 0x464646), stroke: UIColor(rgb: 0x313131)), withoutWallpaper: PresentationThemeBubbleColorComponents(fill: UIColor(rgb: 0x313131), highlightedFill: UIColor(rgb: 0x464646), stroke: UIColor(rgb: 0x313131))),
    freeform: PresentationThemeBubbleColor(withWallpaper: PresentationThemeBubbleColorComponents(fill: UIColor(rgb: 0x1f1f1f), highlightedFill: UIColor(rgb: 0x2A2A2A), stroke: UIColor(rgb: 0x1f1f1f)), withoutWallpaper: PresentationThemeBubbleColorComponents(fill: UIColor(rgb: 0x1f1f1f), highlightedFill: UIColor(rgb: 0x2A2A2A), stroke: UIColor(rgb: 0x1f1f1f))),
    incomingPrimaryTextColor: UIColor(rgb: 0xffffff),
    incomingSecondaryTextColor: UIColor(rgb: 0xffffff, alpha: 0.5),
    incomingLinkTextColor: accentColor,
    incomingLinkHighlightColor: accentColor.withAlphaComponent(0.5),
    incomingScamColor: destructiveColor,
    outgoingPrimaryTextColor: UIColor(rgb: 0xffffff),
    outgoingSecondaryTextColor: UIColor(rgb: 0xffffff, alpha: 0.5),
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
    outgoingCheckColor: UIColor(rgb: 0xffffff, alpha: 0.5),
    incomingPendingActivityColor: UIColor(rgb: 0xffffff, alpha: 0.5),
    outgoingPendingActivityColor: UIColor(rgb: 0xffffff, alpha: 0.5),
    mediaDateAndStatusFillColor: UIColor(white: 0.0, alpha: 0.5),
    mediaDateAndStatusTextColor: .white,
    incomingFileTitleColor: UIColor(rgb: 0xffffff),
    outgoingFileTitleColor: UIColor(rgb: 0xffffff),
    incomingFileDescriptionColor: UIColor(rgb: 0xffffff, alpha: 0.5),
    outgoingFileDescriptionColor: UIColor(rgb: 0xffffff, alpha: 0.5),
    incomingFileDurationColor: UIColor(rgb: 0xffffff, alpha: 0.5),
    outgoingFileDurationColor: UIColor(rgb: 0xffffff, alpha: 0.5),
    shareButtonFillColor: PresentationThemeVariableColor(withWallpaper: UIColor(rgb: 0x000000, alpha: 0.5), withoutWallpaper: UIColor(rgb: 0x000000, alpha: 0.5)),
    shareButtonStrokeColor: PresentationThemeVariableColor(withWallpaper: UIColor(rgb: 0xb2b2b2, alpha: 0.18), withoutWallpaper: UIColor(rgb: 0xb2b2b2, alpha: 0.18)),
    shareButtonForegroundColor: PresentationThemeVariableColor(withWallpaper: UIColor(rgb: 0xb2b2b2), withoutWallpaper: UIColor(rgb: 0xb2b2b2)), //!!!
    mediaOverlayControlBackgroundColor: UIColor(white: 0.0, alpha: 0.6), //!!!
    mediaOverlayControlForegroundColor: UIColor(white: 1.0, alpha: 1.0), //!!!
    actionButtonsIncomingFillColor: PresentationThemeVariableColor(withWallpaper: UIColor(rgb: 0x000000, alpha: 0.5), withoutWallpaper: UIColor(rgb: 0x000000, alpha: 0.5)),
    actionButtonsIncomingStrokeColor: PresentationThemeVariableColor(color: UIColor(rgb: 0xb2b2b2, alpha: 0.18)),
    actionButtonsIncomingTextColor: PresentationThemeVariableColor(color: UIColor(rgb: 0xffffff)),
    actionButtonsOutgoingFillColor: PresentationThemeVariableColor(withWallpaper: UIColor(rgb: 0x000000, alpha: 0.5), withoutWallpaper: UIColor(rgb: 0x000000, alpha: 0.5)),
    actionButtonsOutgoingStrokeColor: PresentationThemeVariableColor(color: UIColor(rgb: 0xb2b2b2, alpha: 0.18)),
    actionButtonsOutgoingTextColor: PresentationThemeVariableColor(color: UIColor(rgb: 0xffffff)),
    selectionControlBorderColor: .white,
    selectionControlFillColor: accentColor,
    selectionControlForegroundColor: .black,
    mediaHighlightOverlayColor: UIColor(white: 1.0, alpha: 0.6),
    deliveryFailedFillColor: destructiveColor,
    deliveryFailedForegroundColor: .white,
    incomingMediaPlaceholderColor: UIColor(rgb: 0x1f1f1f).mixedWith(.white, alpha: 0.05),
    outgoingMediaPlaceholderColor: UIColor(rgb: 0x313131).mixedWith(.white, alpha: 0.05),
    incomingPolls: PresentationThemeChatBubblePolls(radioButton: UIColor(rgb: 0x737373), radioProgress: accentColor, highlight: accentColor.withAlphaComponent(0.12), separator: UIColor(rgb: 0x000000), bar: accentColor),
    outgoingPolls: PresentationThemeChatBubblePolls(radioButton: UIColor(rgb: 0x838383), radioProgress: accentColor, highlight: accentColor.withAlphaComponent(0.12), separator: UIColor(white: 0.3, alpha: 1.0), bar: accentColor)
)

private let serviceMessage = PresentationThemeServiceMessage(
    components: PresentationThemeServiceMessageColor(withDefaultWallpaper: PresentationThemeServiceMessageColorComponents(fill: UIColor(rgb: 0x1f1f1f, alpha: 1.0), primaryText: UIColor(rgb: 0xffffff), linkHighlight: UIColor(rgb: 0xffffff, alpha: 0.12), scam: destructiveColor, dateFillStatic: UIColor(rgb: 0x1f1f1f, alpha: 1.0), dateFillFloating: UIColor(rgb: 0xffffff, alpha: 0.2)), withCustomWallpaper: PresentationThemeServiceMessageColorComponents(fill: UIColor(rgb: 0x1f1f1f, alpha: 1.0), primaryText: .white, linkHighlight: UIColor(rgb: 0xffffff, alpha: 0.12), scam: destructiveColor, dateFillStatic: UIColor(rgb: 0x1f1f1f, alpha: 1.0), dateFillFloating: UIColor(rgb: 0xffffff, alpha: 0.2))),
    unreadBarFillColor: UIColor(rgb: 0x1b1b1b), //!!!
    unreadBarStrokeColor: UIColor(rgb: 0x000000),
    unreadBarTextColor: UIColor(rgb: 0xb2b2b2), //!!!
    dateTextColor: PresentationThemeVariableColor(color: UIColor(rgb: 0xb2b2b2))
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
    inputControlColor: UIColor(rgb: 0x7b7b7b),
    actionControlFillColor: accentColor,
    actionControlForegroundColor: .black,
    primaryTextColor: UIColor(rgb: 0xffffff),
    secondaryTextColor: UIColor(rgb: 0xffffff, alpha: 0.5),
    mediaRecordingDotColor: .white,
    keyboardColor: .dark,
    mediaRecordingControl: inputPanelMediaRecordingControl
)

private let inputMediaPanel = PresentationThemeInputMediaPanel(
    panelSeparatorColor: UIColor(rgb: 0x000000),
    panelIconColor: UIColor(rgb: 0x808080),
    panelHighlightedIconBackgroundColor: UIColor(rgb: 0x000000), //!!!
    stickersBackgroundColor: UIColor(rgb: 0x000000),
    stickersSectionTextColor: UIColor(rgb: 0x7b7b7b),
    stickersSearchBackgroundColor: UIColor(rgb: 0x1c1c1d),
    stickersSearchPlaceholderColor: UIColor(rgb: 0x8e8e93),
    stickersSearchPrimaryColor: .white,
    stickersSearchControlColor: UIColor(rgb: 0x8e8e93),
    gifsBackgroundColor: UIColor(rgb: 0x000000)
)

private let inputButtonPanel = PresentationThemeInputButtonPanel(
    panelSeparatorColor: UIColor(rgb: 0x000000),
    panelBackgroundColor: UIColor(rgb: 0x141414),
    buttonFillColor: UIColor(rgb: 0x5A5A5A),
    buttonStrokeColor: UIColor(rgb: 0x0C0C0C),
    buttonHighlightedFillColor: UIColor(rgb: 0x5A5A5A, alpha: 0.7),
    buttonHighlightedStrokeColor: UIColor(rgb: 0x0C0C0C),
    buttonTextColor: UIColor(rgb: 0xffffff)
)

private let historyNavigation = PresentationThemeChatHistoryNavigation(
    fillColor: UIColor(rgb: 0x1C1C1D),
    strokeColor: UIColor(rgb: 0x000000),
    foregroundColor: UIColor(rgb: 0xffffff),
    badgeBackgroundColor: accentColor,
    badgeStrokeColor: .black,
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
    opaqueItemBackgroundColor: UIColor(rgb: 0x1c1c1d),
    itemBackgroundColor: UIColor(rgb: 0x1c1c1d, alpha: 0.8),
    opaqueItemHighlightedBackgroundColor: UIColor(white: 0.0, alpha: 1.0),
    itemHighlightedBackgroundColor: UIColor(rgb: 0x000000, alpha: 0.5), //!!!
    standardActionTextColor: accentColor,
    opaqueItemSeparatorColor: UIColor(white: 0.0, alpha: 1.0),
    destructiveActionTextColor: destructiveColor,
    disabledActionTextColor: UIColor(rgb: 0x4d4d4d), //!!!
    primaryTextColor: .white,
    secondaryTextColor: UIColor(rgb: 0x5e5e5e), //!!!
    controlAccentColor: accentColor,
    inputBackgroundColor: UIColor(rgb: 0x545454), //!!!
    inputPlaceholderColor: UIColor(rgb: 0xaaaaaa), //!!!
    inputTextColor: .white,
    inputClearButtonColor: UIColor(rgb: 0xaaaaaa),
    checkContentColor: .black
)

private let inAppNotification = PresentationThemeInAppNotification(
    fillColor: UIColor(rgb: 0x1c1c1d),
    primaryTextColor: .white,
    expandedNotification: PresentationThemeExpandedNotification(
        backgroundType: .dark,
        navigationBar: PresentationThemeExpandedNotificationNavigationBar(
            backgroundColor: UIColor(rgb: 0x1c1c1d),
            primaryTextColor: accentColor,
            controlColor: accentColor,
            separatorColor: UIColor(rgb: 0x000000)
        )
    )
)

let defaultDarkPresentationTheme = PresentationTheme(
    name: .builtin(.nightGrayscale),
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
