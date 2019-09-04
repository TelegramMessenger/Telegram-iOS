import Foundation
import UIKit
import TelegramCore
import TelegramUIPreferences

private func makeDefaultDayPresentationTheme(accentColor: UIColor, serviceBackgroundColor: UIColor, baseColor: PresentationThemeBaseColor?, day: Bool, preview: Bool) -> PresentationTheme {
    let destructiveColor: UIColor = UIColor(rgb: 0xff3b30)
    let constructiveColor: UIColor = UIColor(rgb: 0x00c900)
    let secretColor: UIColor = UIColor(rgb: 0x00b12c)
    
    var accentColor = accentColor
    
    let outgoingPrimaryTextColor: UIColor
    let outgoingSecondaryTextColor: UIColor
    let outgoingLinkTextColor: UIColor
    let outgoingCheckColor: UIColor
    let outgoingControlColor: UIColor
    let outgoingBubbleFillColor: UIColor
    let outgoingBubbleStrokeColor: UIColor
    let outgoingSelectionBaseColor: UIColor
    if accentColor.lightness > 0.705 {
        outgoingPrimaryTextColor = .black
        outgoingSecondaryTextColor = UIColor(rgb: 0x000000, alpha: 0.55)
        outgoingLinkTextColor = .black
        outgoingCheckColor = .black
        outgoingControlColor = outgoingPrimaryTextColor
        outgoingBubbleFillColor = accentColor
        if outgoingBubbleFillColor.rgb == 0xffffff {
            outgoingBubbleStrokeColor = UIColor(rgb: 0xc8c7cc)
        } else {
            outgoingBubbleStrokeColor = outgoingBubbleFillColor
        }
        
        let hsv = accentColor.hsv
        accentColor = UIColor(hue: hsv.0, saturation: min(1.0, hsv.1 * 1.1), brightness: min(hsv.2, 0.6), alpha: 1.0)
        outgoingSelectionBaseColor = accentColor
    } else {
        outgoingPrimaryTextColor = .white
        outgoingSecondaryTextColor = UIColor(rgb: 0xffffff, alpha: 0.65)
        outgoingLinkTextColor = .white
        outgoingCheckColor = .white
        outgoingControlColor = outgoingPrimaryTextColor
        outgoingBubbleFillColor = accentColor
        outgoingBubbleStrokeColor = outgoingBubbleFillColor
        outgoingSelectionBaseColor = .white
    }
    
    let rootTabBar = PresentationThemeRootTabBar(
        backgroundColor: UIColor(rgb: 0xf7f7f7),
        separatorColor: UIColor(rgb: 0xa3a3a3),
        iconColor: UIColor(rgb: 0x959595),
        selectedIconColor: accentColor,
        textColor: UIColor(rgb: 0x959595),
        selectedTextColor: accentColor,
        badgeBackgroundColor: UIColor(rgb: 0xff3b30),
        badgeStrokeColor: UIColor(rgb: 0xff3b30),
        badgeTextColor: .white
    )
    
    let rootNavigationBar = PresentationThemeRootNavigationBar(
        buttonColor: accentColor,
        disabledButtonColor: UIColor(rgb: 0xd0d0d0),
        primaryTextColor: .black,
        secondaryTextColor: UIColor(rgb: 0x787878),
        controlColor: UIColor(rgb: 0x7e8791),
        accentTextColor: accentColor,
        backgroundColor: UIColor(rgb: 0xf7f7f7),
        separatorColor: UIColor(rgb: 0xb1b1b1),
        badgeBackgroundColor: UIColor(rgb: 0xff3b30),
        badgeStrokeColor: UIColor(rgb: 0xff3b30),
        badgeTextColor: .white
    )
    
    let navigationSearchBar = PresentationThemeNavigationSearchBar(
        backgroundColor: .white,
        accentColor: accentColor,
        inputFillColor: UIColor(rgb: 0xe9e9e9),
        inputTextColor: .black,
        inputPlaceholderTextColor: UIColor(rgb: 0x8e8e93),
        inputIconColor: UIColor(rgb: 0x8e8e93),
        inputClearButtonColor: UIColor(rgb: 0x7b7b81),
        separatorColor: UIColor(rgb: 0xb1b1b1)
    )
    
    let intro = PresentationThemeIntro(
        statusBarStyle: .black,
        startButtonColor: UIColor(rgb: 0x2ca5e0),
        dotColor: UIColor(rgb: 0xd9d9d9)
    )
    
    let passcode = PresentationThemePasscode(
        backgroundColors: PresentationThemeGradientColors(topColor: UIColor(rgb: 0x46739e), bottomColor: UIColor(rgb: 0x2a5982)),
        buttonColor: .clear
    )
    
    let rootController = PresentationThemeRootController(
        statusBarStyle: .black,
        tabBar: rootTabBar,
        navigationBar: rootNavigationBar,
        navigationSearchBar: navigationSearchBar,
        keyboardColor: .light
    )
    
    let switchColors = PresentationThemeSwitch(
        frameColor: UIColor(rgb: 0xe0e0e0),
        handleColor: UIColor(rgb: 0xffffff),
        contentColor: UIColor(rgb: 0x77d572),
        positiveColor: constructiveColor,
        negativeColor: destructiveColor
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
        freeMonoIconColor: UIColor(rgb: 0x7e7e87),
        itemSwitchColors: switchColors,
        itemDisclosureActions: PresentationThemeItemDisclosureActions(
            neutral1: PresentationThemeFillForeground(fillColor: UIColor(rgb: 0x4892f2), foregroundColor: .white),
            neutral2: PresentationThemeFillForeground(fillColor: UIColor(rgb: 0xf09a37), foregroundColor: .white),
            destructive: PresentationThemeFillForeground(fillColor: UIColor(rgb: 0xff3824), foregroundColor: .white),
            constructive: PresentationThemeFillForeground(fillColor: constructiveColor, foregroundColor: .white),
            accent: PresentationThemeFillForeground(fillColor: accentColor, foregroundColor: .white),
            warning: PresentationThemeFillForeground(fillColor: UIColor(rgb: 0xff9500), foregroundColor: .white),
            inactive: PresentationThemeFillForeground(fillColor: UIColor(rgb: 0xbcbcc3), foregroundColor: .white)
        ),
        itemCheckColors: PresentationThemeFillStrokeForeground(
            fillColor: accentColor,
            strokeColor: UIColor(rgb: 0xc7c7cc),
            foregroundColor: .white
        ),
        controlSecondaryColor: UIColor(rgb: 0xdedede),
        freeInputField: PresentationInputFieldTheme(
            backgroundColor: UIColor(rgb: 0xd6d6dc),
            strokeColor: UIColor(rgb: 0xd6d6dc),
            placeholderColor: UIColor(rgb: 0x96979d),
            primaryColor: .black,
            controlColor: UIColor(rgb: 0x96979d)
        ),
        mediaPlaceholderColor: UIColor(rgb: 0xe4e4e4),
        scrollIndicatorColor: UIColor(white: 0.0, alpha: 0.3),
        pageIndicatorInactiveColor: UIColor(rgb: 0xe3e3e7),
        inputClearButtonColor: UIColor(rgb: 0xcccccc)
    )
    
    let chatList = PresentationThemeChatList(
        backgroundColor: .white,
        itemSeparatorColor: UIColor(rgb: 0xc8c7cc),
        itemBackgroundColor: .white,
        pinnedItemBackgroundColor: UIColor(rgb: 0xf7f7f7),
        itemHighlightedBackgroundColor: UIColor(rgb: 0xd9d9d9),
        itemSelectedBackgroundColor: UIColor(rgb: 0xe9f0fa),
        titleColor: .black,
        secretTitleColor: secretColor,
        dateTextColor: UIColor(rgb: 0x8e8e93),
        authorNameColor: .black,
        messageTextColor: UIColor(rgb: 0x8e8e93),
        messageDraftTextColor: UIColor(rgb: 0xdd4b39),
        checkmarkColor: day ? accentColor : UIColor(rgb: 0x21c004),
        pendingIndicatorColor: UIColor(rgb: 0x8e8e93),
        failedFillColor: destructiveColor,
        failedForegroundColor: .white,
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
        verifiedIconFillColor: accentColor,
        verifiedIconForegroundColor: .white,
        secretIconColor: secretColor,
        pinnedArchiveAvatarColor: PresentationThemeArchiveAvatarColors(backgroundColors: PresentationThemeGradientColors(topColor: UIColor(rgb: 0x72d5fd), bottomColor: UIColor(rgb: 0x2a9ef1)), foregroundColor: .white),
        unpinnedArchiveAvatarColor: PresentationThemeArchiveAvatarColors(backgroundColors: PresentationThemeGradientColors(topColor: UIColor(rgb: 0xdedee5), bottomColor: UIColor(rgb: 0xc5c6cc)), foregroundColor: .white),
        onlineDotColor: UIColor(rgb: 0x4cc91f)
    )
    
    let message = PresentationThemeChatMessage(
        incoming: PresentationThemePartedColors(bubble: PresentationThemeBubbleColor(withWallpaper: PresentationThemeBubbleColorComponents(fill: UIColor(rgb: 0xffffff), highlightedFill: UIColor(rgb: 0xd9f4ff), stroke: UIColor(rgb: 0x86A9C9, alpha: 0.5)), withoutWallpaper: PresentationThemeBubbleColorComponents(fill: UIColor(rgb: 0xffffff), highlightedFill: UIColor(rgb: 0xd9f4ff), stroke: UIColor(rgb: 0x86A9C9, alpha: 0.5))), primaryTextColor: .black, secondaryTextColor: UIColor(rgb: 0x525252, alpha: 0.6), linkTextColor: UIColor(rgb: 0x004bad), linkHighlightColor: accentColor.withAlphaComponent(0.3), scamColor: destructiveColor, textHighlightColor: UIColor(rgb: 0xffe438), accentTextColor: UIColor(rgb: 0x007ee5), accentControlColor: UIColor(rgb: 0x007ee5), mediaActiveControlColor: UIColor(rgb: 0x007ee5), mediaInactiveControlColor: UIColor(rgb: 0xcacaca), pendingActivityColor: UIColor(rgb: 0x525252, alpha: 0.6), fileTitleColor: UIColor(rgb: 0x0b8bed), fileDescriptionColor: UIColor(rgb: 0x999999), fileDurationColor: UIColor(rgb: 0x525252, alpha: 0.6), mediaPlaceholderColor: UIColor(rgb: 0xe8ecf0), polls: PresentationThemeChatBubblePolls(radioButton: UIColor(rgb: 0xc8c7cc), radioProgress: UIColor(rgb: 0x007ee5), highlight: UIColor(rgb: 0x007ee5).withAlphaComponent(0.08), separator: UIColor(rgb: 0xc8c7cc), bar: UIColor(rgb: 0x007ee5)), actionButtonsFillColor: PresentationThemeVariableColor(withWallpaper: serviceBackgroundColor, withoutWallpaper: UIColor(rgb: 0x596e89, alpha: 0.35)), actionButtonsStrokeColor: PresentationThemeVariableColor(color: .clear), actionButtonsTextColor: PresentationThemeVariableColor(color: .white), textSelectionColor: accentColor.withAlphaComponent(0.2), textSelectionKnobColor: accentColor),
        outgoing: PresentationThemePartedColors(bubble: PresentationThemeBubbleColor(withWallpaper: PresentationThemeBubbleColorComponents(fill: UIColor(rgb: 0xE1FFC7), highlightedFill: UIColor(rgb: 0xc8ffa6), stroke: UIColor(rgb: 0x86a9c9, alpha: 0.5)), withoutWallpaper: PresentationThemeBubbleColorComponents(fill: UIColor(rgb: 0xe1ffc7), highlightedFill: UIColor(rgb: 0xc8ffa6), stroke: UIColor(rgb: 0x86a9c9, alpha: 0.5))), primaryTextColor: .black, secondaryTextColor: UIColor(rgb: 0x008c09, alpha: 0.8), linkTextColor: UIColor(rgb: 0x004bad), linkHighlightColor: accentColor.withAlphaComponent(0.3), scamColor: destructiveColor, textHighlightColor: UIColor(rgb: 0xffe438), accentTextColor: UIColor(rgb: 0x00a700), accentControlColor: UIColor(rgb: 0x3fc33b), mediaActiveControlColor: UIColor(rgb: 0x3fc33b), mediaInactiveControlColor: UIColor(rgb: 0x93d987), pendingActivityColor: UIColor(rgb: 0x42b649), fileTitleColor: UIColor(rgb: 0x3faa3c), fileDescriptionColor: UIColor(rgb: 0x6fb26a), fileDurationColor: UIColor(rgb: 0x008c09, alpha: 0.8), mediaPlaceholderColor: UIColor(rgb: 0xd2f2b6), polls: PresentationThemeChatBubblePolls(radioButton: UIColor(rgb: 0x93d987), radioProgress: UIColor(rgb: 0x3fc33b), highlight: UIColor(rgb: 0x3fc33b).withAlphaComponent(0.08), separator: UIColor(rgb: 0x93d987), bar: UIColor(rgb: 0x3fc33b)), actionButtonsFillColor: PresentationThemeVariableColor(withWallpaper: serviceBackgroundColor, withoutWallpaper: UIColor(rgb: 0x596e89, alpha: 0.35)), actionButtonsStrokeColor: PresentationThemeVariableColor(color: .clear), actionButtonsTextColor: PresentationThemeVariableColor(color: .white), textSelectionColor: UIColor(rgb: 0xBBDE9F), textSelectionKnobColor: UIColor(rgb: 0x3FC33B)),
        freeform: PresentationThemeBubbleColor(withWallpaper: PresentationThemeBubbleColorComponents(fill: UIColor(rgb: 0xffffff), highlightedFill: UIColor(rgb: 0xd9f4ff), stroke: UIColor(rgb: 0x86A9C9, alpha: 0.5)), withoutWallpaper: PresentationThemeBubbleColorComponents(fill: UIColor(rgb: 0xffffff), highlightedFill: UIColor(rgb: 0xd9f4ff), stroke: UIColor(rgb: 0x86A9C9, alpha: 0.5))),
        infoPrimaryTextColor: UIColor(rgb: 0x000000),
        infoLinkTextColor: UIColor(rgb: 0x004bad),
        outgoingCheckColor: UIColor(rgb: 0x19c700),
        mediaDateAndStatusFillColor: UIColor(white: 0.0, alpha: 0.5),
        mediaDateAndStatusTextColor: .white,
        shareButtonFillColor: PresentationThemeVariableColor(withWallpaper: serviceBackgroundColor, withoutWallpaper: UIColor(rgb: 0x748391, alpha: 0.45)),
        shareButtonStrokeColor: PresentationThemeVariableColor(withWallpaper: .clear, withoutWallpaper: .clear),
        shareButtonForegroundColor: PresentationThemeVariableColor(withWallpaper: .white, withoutWallpaper: .white),
        mediaOverlayControlColors: PresentationThemeFillForeground(fillColor: UIColor(rgb: 0x000000, alpha: 0.6), foregroundColor: .white),
        selectionControlColors: PresentationThemeFillStrokeForeground(fillColor: accentColor, strokeColor: UIColor(rgb: 0xc7c7cc), foregroundColor: .white),
        deliveryFailedColors: PresentationThemeFillForeground(fillColor: destructiveColor, foregroundColor: .white),
        mediaHighlightOverlayColor: UIColor(white: 1.0, alpha: 0.6)
    )
    
    let messageDay = PresentationThemeChatMessage(
        incoming: PresentationThemePartedColors(bubble: PresentationThemeBubbleColor(withWallpaper: PresentationThemeBubbleColorComponents(fill: UIColor(rgb: 0xffffff), highlightedFill: UIColor(rgb: 0xdadade), stroke: UIColor(rgb: 0xffffff)), withoutWallpaper: PresentationThemeBubbleColorComponents(fill: UIColor(rgb: 0xf1f1f4), highlightedFill: UIColor(rgb: 0xdadade), stroke: UIColor(rgb: 0xf1f1f4))), primaryTextColor: .black, secondaryTextColor: UIColor(rgb: 0x525252, alpha: 0.6), linkTextColor: UIColor(rgb: 0x004bad), linkHighlightColor: accentColor.withAlphaComponent(0.3), scamColor: destructiveColor, textHighlightColor: UIColor(rgb: 0xffe438), accentTextColor: accentColor, accentControlColor: accentColor, mediaActiveControlColor: accentColor, mediaInactiveControlColor: UIColor(rgb: 0xcacaca), pendingActivityColor: UIColor(rgb: 0x525252, alpha: 0.6), fileTitleColor: accentColor, fileDescriptionColor: UIColor(rgb: 0x999999), fileDurationColor: UIColor(rgb: 0x525252, alpha: 0.6), mediaPlaceholderColor: UIColor(rgb: 0xffffff).withMultipliedBrightnessBy(0.95), polls: PresentationThemeChatBubblePolls(radioButton: UIColor(rgb: 0xc8c7cc), radioProgress: accentColor, highlight: accentColor.withAlphaComponent(0.12), separator: UIColor(rgb: 0xc8c7cc), bar: accentColor), actionButtonsFillColor: PresentationThemeVariableColor(withWallpaper: serviceBackgroundColor, withoutWallpaper: UIColor(rgb: 0xffffff, alpha: 0.8)), actionButtonsStrokeColor: PresentationThemeVariableColor(withWallpaper: .clear, withoutWallpaper: accentColor), actionButtonsTextColor: PresentationThemeVariableColor(withWallpaper: .white, withoutWallpaper: accentColor), textSelectionColor: accentColor.withAlphaComponent(0.3), textSelectionKnobColor: accentColor),
        outgoing: PresentationThemePartedColors(bubble: PresentationThemeBubbleColor(withWallpaper: PresentationThemeBubbleColorComponents(fill: outgoingBubbleFillColor, highlightedFill: outgoingBubbleFillColor.withMultipliedBrightnessBy(0.7), stroke: outgoingBubbleFillColor), withoutWallpaper: PresentationThemeBubbleColorComponents(fill: outgoingBubbleFillColor, highlightedFill: outgoingBubbleFillColor.withMultipliedBrightnessBy(0.7), stroke: outgoingBubbleStrokeColor)), primaryTextColor: outgoingPrimaryTextColor, secondaryTextColor: outgoingSecondaryTextColor, linkTextColor: outgoingLinkTextColor, linkHighlightColor: UIColor(rgb: 0xffffff, alpha: 0.3), scamColor: outgoingPrimaryTextColor, textHighlightColor: UIColor(rgb: 0xffe438), accentTextColor: outgoingPrimaryTextColor, accentControlColor: outgoingPrimaryTextColor, mediaActiveControlColor: outgoingPrimaryTextColor, mediaInactiveControlColor: outgoingSecondaryTextColor, pendingActivityColor: outgoingSecondaryTextColor, fileTitleColor: outgoingPrimaryTextColor, fileDescriptionColor: outgoingSecondaryTextColor, fileDurationColor: outgoingSecondaryTextColor, mediaPlaceholderColor: accentColor.withMultipliedBrightnessBy(0.95), polls: PresentationThemeChatBubblePolls(radioButton: outgoingSecondaryTextColor, radioProgress: outgoingPrimaryTextColor, highlight: outgoingPrimaryTextColor.withAlphaComponent(0.12), separator: outgoingSecondaryTextColor, bar: outgoingPrimaryTextColor), actionButtonsFillColor: PresentationThemeVariableColor(withWallpaper: serviceBackgroundColor, withoutWallpaper: UIColor(rgb: 0xffffff, alpha: 0.8)), actionButtonsStrokeColor: PresentationThemeVariableColor(withWallpaper: .clear, withoutWallpaper: accentColor), actionButtonsTextColor: PresentationThemeVariableColor(withWallpaper: .white, withoutWallpaper: accentColor), textSelectionColor: outgoingSelectionBaseColor.withAlphaComponent(0.2), textSelectionKnobColor: outgoingSelectionBaseColor),
        freeform: PresentationThemeBubbleColor(withWallpaper: PresentationThemeBubbleColorComponents(fill: UIColor(rgb: 0xE5E5EA), highlightedFill: UIColor(rgb: 0xDADADE), stroke: UIColor(rgb: 0xE5E5EA)), withoutWallpaper: PresentationThemeBubbleColorComponents(fill: UIColor(rgb: 0xE5E5EA), highlightedFill: UIColor(rgb: 0xdadade), stroke: UIColor(rgb: 0xE5E5EA))),
        infoPrimaryTextColor: UIColor(rgb: 0x000000),
        infoLinkTextColor: UIColor(rgb: 0x004bad),
        outgoingCheckColor: outgoingCheckColor,
        mediaDateAndStatusFillColor: UIColor(rgb: 0x000000, alpha: 0.5),
        mediaDateAndStatusTextColor: .white,
        shareButtonFillColor: PresentationThemeVariableColor(withWallpaper: serviceBackgroundColor, withoutWallpaper: UIColor(rgb: 0xffffff, alpha: 0.8)),
        shareButtonStrokeColor: PresentationThemeVariableColor(withWallpaper: .clear, withoutWallpaper: UIColor(rgb: 0xe5e5ea)),
        shareButtonForegroundColor: PresentationThemeVariableColor(withWallpaper: .white, withoutWallpaper: accentColor),
        mediaOverlayControlColors: PresentationThemeFillForeground(fillColor: UIColor(rgb: 0x000000, alpha: 0.6), foregroundColor: .white),
        selectionControlColors: PresentationThemeFillStrokeForeground(fillColor: accentColor, strokeColor: UIColor(rgb: 0xc7c7cc), foregroundColor: .white),
        deliveryFailedColors: PresentationThemeFillForeground(fillColor: destructiveColor, foregroundColor: .white),
        mediaHighlightOverlayColor: UIColor(rgb: 0xffffff, alpha: 0.6)
    )
    
    let serviceMessage = PresentationThemeServiceMessage(
        components: PresentationThemeServiceMessageColor(withDefaultWallpaper: PresentationThemeServiceMessageColorComponents(fill: UIColor(rgb: 0x748391, alpha: 0.45), primaryText: .white, linkHighlight: UIColor(rgb: 0x748391, alpha: 0.25), scam: .white,  dateFillStatic: UIColor(rgb: 0x748391, alpha: 0.45), dateFillFloating: UIColor(rgb: 0x939fab, alpha: 0.5)), withCustomWallpaper: PresentationThemeServiceMessageColorComponents(fill: serviceBackgroundColor, primaryText: .white, linkHighlight: UIColor(rgb: 0x748391, alpha: 0.25), scam: .white, dateFillStatic: serviceBackgroundColor, dateFillFloating: serviceBackgroundColor.withAlphaComponent(serviceBackgroundColor.alpha * 0.6667))),
        unreadBarFillColor: UIColor(white: 1.0, alpha: 0.9),
        unreadBarStrokeColor: UIColor(white: 0.0, alpha: 0.2),
        unreadBarTextColor: UIColor(rgb: 0x86868d),
        dateTextColor: PresentationThemeVariableColor(color: .white)
    )
    
    let serviceMessageDay = PresentationThemeServiceMessage(
        components: PresentationThemeServiceMessageColor(withDefaultWallpaper: PresentationThemeServiceMessageColorComponents(fill: UIColor(rgb: 0xffffff, alpha: 0.8), primaryText: UIColor(rgb: 0x8d8e93), linkHighlight: UIColor(rgb: 0x748391, alpha: 0.25), scam: destructiveColor, dateFillStatic: UIColor(rgb: 0xffffff, alpha: 0.8), dateFillFloating: UIColor(rgb: 0xffffff, alpha: 0.8)), withCustomWallpaper: PresentationThemeServiceMessageColorComponents(fill: serviceBackgroundColor, primaryText: .white, linkHighlight: UIColor(rgb: 0x748391, alpha: 0.25), scam: destructiveColor, dateFillStatic: serviceBackgroundColor, dateFillFloating: serviceBackgroundColor.withAlphaComponent(serviceBackgroundColor.alpha * 0.6667))),
        unreadBarFillColor: UIColor(rgb: 0xffffff),
        unreadBarStrokeColor: UIColor(rgb: 0xffffff),
        unreadBarTextColor: UIColor(rgb: 0x8d8e93),
        dateTextColor: PresentationThemeVariableColor(withWallpaper: .white, withoutWallpaper: UIColor(rgb: 0x8d8e93))
    )
    
    let inputPanelMediaRecordingControl = PresentationThemeChatInputPanelMediaRecordingControl(
        buttonColor: accentColor,
        micLevelColor: accentColor.withAlphaComponent(0.2),
        activeIconColor: .white
    )
    
    let inputPanel = PresentationThemeChatInputPanel(
        panelBackgroundColor: UIColor(rgb: 0xf7f7f7),
        panelSeparatorColor: UIColor(rgb: 0xb2b2b2),
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
        mediaRecordingControl: inputPanelMediaRecordingControl
    )
    
    let inputMediaPanel = PresentationThemeInputMediaPanel(
        panelSeparatorColor: UIColor(rgb: 0xbec2c6),
        panelIconColor: UIColor(rgb: 0x858e99),
        panelHighlightedIconBackgroundColor: UIColor(rgb: 0x858e99, alpha: 0.2),
        stickersBackgroundColor: UIColor(rgb: 0xe8ebf0),
        stickersSectionTextColor: UIColor(rgb: 0x9099a2),
        stickersSearchBackgroundColor: UIColor(rgb: 0xd9dbe1),
        stickersSearchPlaceholderColor: UIColor(rgb: 0x8e8e93),
        stickersSearchPrimaryColor: .black,
        stickersSearchControlColor: UIColor(rgb: 0x8e8e93),
        gifsBackgroundColor: .white
    )
    
    let inputButtonPanel = PresentationThemeInputButtonPanel(
        panelSeparatorColor: UIColor(rgb: 0xbec2c6),
        panelBackgroundColor: UIColor(rgb: 0xdee2e6),
        buttonFillColor: .white,
        buttonStrokeColor: UIColor(rgb: 0xc3c7c9),
        buttonHighlightedFillColor: UIColor(rgb: 0xa8b3c0),
        buttonHighlightedStrokeColor: UIColor(rgb: 0xc3c7c9),
        buttonTextColor: .black
    )
    
    let historyNavigation = PresentationThemeChatHistoryNavigation(
        fillColor: UIColor(rgb: 0xf7f7f7),
        strokeColor: UIColor(rgb: 0xb1b1b1),
        foregroundColor: UIColor(rgb: 0x88888d),
        badgeBackgroundColor: accentColor,
        badgeStrokeColor: accentColor,
        badgeTextColor: .white
    )
    
    let chat = PresentationThemeChat(
        defaultWallpaper: day ? .color(0xffffff) : .builtin(WallpaperSettings()),
        message: day ? messageDay : message,
        serviceMessage: day ? serviceMessageDay : serviceMessage,
        inputPanel: inputPanel,
        inputMediaPanel: inputMediaPanel,
        inputButtonPanel: inputButtonPanel,
        historyNavigation: historyNavigation
    )
    
    let actionSheet = PresentationThemeActionSheet(
        dimColor: UIColor(white: 0.0, alpha: 0.4),
        backgroundType: .light,
        opaqueItemBackgroundColor: .white,
        itemBackgroundColor: UIColor(white: 1.0, alpha: 0.87),
        opaqueItemHighlightedBackgroundColor: UIColor(white: 0.9, alpha: 1.0),
        itemHighlightedBackgroundColor: UIColor(white: 0.9, alpha: 0.7),
        opaqueItemSeparatorColor: UIColor(white: 0.9, alpha: 1.0),
        standardActionTextColor: accentColor,
        destructiveActionTextColor: destructiveColor,
        disabledActionTextColor: UIColor(rgb: 0xb3b3b3),
        primaryTextColor: .black,
        secondaryTextColor: UIColor(rgb: 0x5e5e5e),
        controlAccentColor: accentColor,
        inputBackgroundColor: UIColor(rgb: 0xe9e9e9),
        inputHollowBackgroundColor: .white,
        inputBorderColor: UIColor(rgb: 0xe4e4e6),
        inputPlaceholderColor: UIColor(rgb: 0x818086),
        inputTextColor: .black,
        inputClearButtonColor: UIColor(rgb: 0x7b7b81),
        checkContentColor: .white
    )
    
    let contextMenu = PresentationThemeContextMenu(
        dimColor: UIColor(rgb: 0x000a26, alpha: 0.2),
        backgroundColor: UIColor(rgb: 0xf9f9f9, alpha: 0.78),
        itemSeparatorColor: UIColor(rgb: 0x3c3c43, alpha: 0.2),
        sectionSeparatorColor: UIColor(rgb: 0x8a8a8a, alpha: 0.2),
        itemBackgroundColor: UIColor(rgb: 0x000000, alpha: 0.0),
        itemHighlightedBackgroundColor: UIColor(rgb: 0x3c3c43, alpha: 0.2),
        primaryColor: UIColor(rgb: 0x000000, alpha: 1.0),
        secondaryColor: UIColor(rgb: 0x000000, alpha: 0.8),
        destructiveColor: destructiveColor
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
                separatorColor: UIColor(rgb: 0xb1b1b1)
            )
        )
    )
    
    return PresentationTheme(
        name: .builtin(day ? .day : .dayClassic),
        referenceTheme: day ? .day : .dayClassic,
        overallDarkAppearance: false,
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

public let defaultPresentationTheme = makeDefaultDayPresentationTheme(accentColor: UIColor(rgb: 0x007ee5), serviceBackgroundColor: defaultServiceBackgroundColor, baseColor: nil, day: false, preview: false)

public let defaultDayAccentColor = UIColor(rgb: 0x007ee5)
public let defaultServiceBackgroundColor = UIColor(rgb: 0x000000, alpha: 0.3)

public func makeDefaultDayPresentationTheme(accentColor: UIColor? = nil, serviceBackgroundColor: UIColor, baseColor: PresentationThemeBaseColor?, day: Bool, preview: Bool) -> PresentationTheme {
    let accentColor = accentColor ?? defaultDayAccentColor
    return makeDefaultDayPresentationTheme(accentColor: accentColor, serviceBackgroundColor: serviceBackgroundColor, baseColor: baseColor, day: day, preview: preview)
}
