import Foundation
import UIKit

private func decodeColor<Key>(_ values: KeyedDecodingContainer<Key>, _ key: Key) throws -> UIColor {
    return UIColor(rgb: try values.decode(UInt32.self, forKey: key))
}

extension PresentationThemeGradientColors: Decodable {
    enum CodingKeys: String, CodingKey {
        case topColor
        case bottomColor
    }
    
    public convenience init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(topColor: try decodeColor(values, .topColor),
                  bottomColor: try decodeColor(values, .bottomColor))
    }
}

extension PresentationThemeAuth: Decodable {
    enum CodingKeys: String, CodingKey {
        case introStartButton
        case introDot
    }
    
    public convenience init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(introStartButtonColor: try decodeColor(values, .introStartButton),
                  introDotColor: try decodeColor(values, .introDot))
    }
}

extension PresentationThemePasscode: Decodable {
    enum CodingKeys: String, CodingKey {
        case background
        case button
    }
    
    public convenience init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(backgroundColors: try values.decode(PresentationThemeGradientColors.self, forKey: .background),
                  buttonColor: try decodeColor(values, .button))
    }
}

extension PresentationThemeRootTabBar: Decodable {
    enum CodingKeys: String, CodingKey {
        case background
        case separator
        case icon
        case selectedIcon
        case text
        case selectedText
        case badgeBackground
        case badgeStroke
        case badgeText
    }
    
    public convenience init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(backgroundColor: try decodeColor(values, .background),
                  separatorColor: try decodeColor(values, .separator),
                  iconColor: try decodeColor(values, .icon),
                  selectedIconColor: try decodeColor(values, .selectedIcon),
                  textColor: try decodeColor(values, .text),
                  selectedTextColor: try decodeColor(values, .selectedText),
                  badgeBackgroundColor: try decodeColor(values, .badgeBackground),
                  badgeStrokeColor: try decodeColor(values, .badgeStroke),
                  badgeTextColor: try decodeColor(values, .badgeText))
    }
}

extension PresentationThemeRootNavigationBar: Decodable {
    enum CodingKeys: String, CodingKey {
        case button
        case disabledButton
        case primaryText
        case secondaryText
        case control
        case accentText
        case background
        case separator
        case badgeBackground
        case badgeStroke
        case badgeText
    }
    
    public convenience init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(buttonColor: try decodeColor(values, .button),
                  disabledButtonColor: try decodeColor(values, .disabledButton),
                  primaryTextColor: try decodeColor(values, .primaryText),
                  secondaryTextColor: try decodeColor(values, .secondaryText),
                  controlColor: try decodeColor(values, .control),
                  accentTextColor: try decodeColor(values, .accentText),
                  backgroundColor: try decodeColor(values, .background),
                  separatorColor: try decodeColor(values, .separator),
                  badgeBackgroundColor: try decodeColor(values, .badgeBackground),
                  badgeStrokeColor: try decodeColor(values, .badgeStroke),
                  badgeTextColor: try decodeColor(values, .badgeText))
    }
}

extension PresentationThemeNavigationSearchBar: Decodable {
    enum CodingKeys: String, CodingKey {
        case background
        case accent
        case inputFill
        case inputText
        case inputPlaceholderText
        case inputIcon
        case inputClearButton
        case separator
    }
    
    public convenience init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(backgroundColor: try decodeColor(values, .background),
                  accentColor: try decodeColor(values, .accent),
                  inputFillColor: try decodeColor(values, .inputFill),
                  inputTextColor: try decodeColor(values, .inputText),
                  inputPlaceholderTextColor: try decodeColor(values, .inputPlaceholderText),
                  inputIconColor: try decodeColor(values, .inputIcon),
                  inputClearButtonColor: try decodeColor(values, .inputClearButton),
                  separatorColor: try decodeColor(values, .separator))
    }
}

extension PresentationThemeRootController: Decodable {
    enum CodingKeys: String, CodingKey {
        case statusBarStyle
        case tabBar
        case navigationBar
        case navigationSearchBar
    }
    
    public convenience init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(statusBarStyle: try values.decode(PresentationThemeStatusBarStyle.self, forKey: .statusBarStyle),
                  tabBar: try values.decode(PresentationThemeRootTabBar.self, forKey: .tabBar),
                  navigationBar: try values.decode(PresentationThemeRootNavigationBar.self, forKey: .navigationBar),
                  navigationSearchBar: try values.decode(PresentationThemeNavigationSearchBar.self, forKey: .navigationSearchBar))
    }
}

extension PresentationThemeActionSheet: Decodable {
    enum CodingKeys: String, CodingKey {
        case dim
        case backgroundType
        case opaqueItemBackground
        case itemBackground
        case opaqueItemHighlightedBackground
        case itemHighlightedBackground
        case opaqueItemSeparator
        case standardActionText
        case destructiveActionText
        case disabledActionText
        case primaryText
        case secondaryText
        case controlAccent
        case inputBackground
        case inputHollowBackground
        case inputBorder
        case inputPlaceholder
        case inputText
        case inputClearButton
        case checkContent
    }
    
    public convenience init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(dimColor: try decodeColor(values, .dim),
                  backgroundType: try values.decode(PresentationThemeActionSheetBackgroundType.self, forKey: .backgroundType),
                  opaqueItemBackgroundColor: try decodeColor(values, .opaqueItemBackground),
                  itemBackgroundColor: try decodeColor(values, .itemBackground),
                  opaqueItemHighlightedBackgroundColor: try decodeColor(values, .opaqueItemHighlightedBackground),
                  itemHighlightedBackgroundColor: try decodeColor(values, .itemHighlightedBackground),
                  opaqueItemSeparatorColor: try decodeColor(values, .opaqueItemSeparator),
                  standardActionTextColor: try decodeColor(values, .standardActionText),
                  destructiveActionTextColor: try decodeColor(values, .destructiveActionText),
                  disabledActionTextColor: try decodeColor(values, .disabledActionText),
                  primaryTextColor: try decodeColor(values, .primaryText),
                  secondaryTextColor: try decodeColor(values, .secondaryText),
                  controlAccentColor: try decodeColor(values, .controlAccent),
                  inputBackgroundColor: try decodeColor(values, .inputBackground),
                  inputHollowBackgroundColor: try decodeColor(values, .inputHollowBackground),
                  inputBorderColor: try decodeColor(values, .inputBorder),
                  inputPlaceholderColor: try decodeColor(values, .inputPlaceholder),
                  inputTextColor: try decodeColor(values, .inputText),
                  inputClearButtonColor: try decodeColor(values, .inputClearButton),
                  checkContentColor: try decodeColor(values, .checkContent))
    }
}

extension PresentationThemeSwitch: Decodable {
    enum CodingKeys: String, CodingKey {
        case frame
        case handle
        case content
        case positive
        case negative
    }
    
    public convenience init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(frameColor: try decodeColor(values, .frame),
                  handleColor: try decodeColor(values, .handle),
                  contentColor: try decodeColor(values, .content),
                  positiveColor: try decodeColor(values, .positive),
                  negativeColor: try decodeColor(values, .negative))
    }
}

extension PresentationThemeFillForeground: Decodable {
    enum CodingKeys: String, CodingKey {
        case fill
        case foreground
    }
    
    public convenience init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(fillColor: try decodeColor(values, .fill),
                  foregroundColor: try decodeColor(values, .foreground))
    }
}

extension PresentationThemeItemDisclosureActions: Decodable {
    enum CodingKeys: String, CodingKey {
        case neutral1
        case neutral2
        case destructive
        case constructive
        case accent
        case warning
        case inactive
    }
    
    public convenience init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(neutral1: try values.decode(PresentationThemeFillForeground.self, forKey: .neutral1),
                  neutral2: try values.decode(PresentationThemeFillForeground.self, forKey: .neutral2),
                  destructive: try values.decode(PresentationThemeFillForeground.self, forKey: .destructive),
                  constructive: try values.decode(PresentationThemeFillForeground.self, forKey: .constructive),
                  accent: try values.decode(PresentationThemeFillForeground.self, forKey: .accent),
                  warning: try values.decode(PresentationThemeFillForeground.self, forKey: .warning),
                  inactive: try values.decode(PresentationThemeFillForeground.self, forKey: .inactive))
    }
}

extension PresentationThemeFillStrokeForeground: Decodable {
    enum CodingKeys: String, CodingKey {
        case fill
        case stroke
        case foreground
    }
    
    public convenience init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(fillColor: try decodeColor(values, .fill),
                  strokeColor: try decodeColor(values, .stroke),
                  foregroundColor: try decodeColor(values, .foreground))
    }
}

extension PresentationInputFieldTheme: Decodable {
    enum CodingKeys: String, CodingKey {
        case background
        case placeholder
        case primary
        case control
    }
    
    public convenience init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(backgroundColor: try decodeColor(values, .background),
                  placeholderColor: try decodeColor(values, .placeholder),
                  primaryColor: try decodeColor(values, .primary),
                  controlColor: try decodeColor(values, .control))
    }
}

extension PresentationThemeList: Decodable {
    enum CodingKeys: String, CodingKey {
        case blocksBackground
        case plainBackground
        case itemPrimaryText
        case itemSecondaryText
        case itemDisabledText
        case itemAccent
        case itemHighlighted
        case itemDestructive
        case itemPlaceholderText
        case itemBlocksBackground
        case itemHighlightedBackground
        case itemBlocksSeparator
        case itemPlainSeparator
        case disclosureArrow
        case sectionHeaderText
        case freeText
        case freeTextError
        case freeTextSuccess
        case freeMonoIcon
        case itemSwitch
        case itemDisclosureActions
        case itemCheck
        case controlSecondary
        case freeInputField
        case mediaPlaceholder
        case scrollIndicator
        case pageIndicatorInactive
        case inputClearButton
    }
    
    public convenience init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        
        self.init(blocksBackgroundColor: try decodeColor(values, .blocksBackground),
                  plainBackgroundColor: try decodeColor(values, .plainBackground),
                  itemPrimaryTextColor: try decodeColor(values, .itemPrimaryText),
                  itemSecondaryTextColor: try decodeColor(values, .itemSecondaryText),
                  itemDisabledTextColor: try decodeColor(values, .itemDisabledText),
                  itemAccentColor: try decodeColor(values, .itemAccent),
                  itemHighlightedColor: try decodeColor(values, .itemHighlighted),
                  itemDestructiveColor: try decodeColor(values, .itemDestructive),
                  itemPlaceholderTextColor: try decodeColor(values, .itemPlaceholderText),
                  itemBlocksBackgroundColor: try decodeColor(values, .itemBlocksBackground),
                  itemHighlightedBackgroundColor: try decodeColor(values, .itemHighlightedBackground),
                  itemBlocksSeparatorColor: try decodeColor(values, .itemBlocksSeparator),
                  itemPlainSeparatorColor: try decodeColor(values, .itemPlainSeparator),
                  disclosureArrowColor: try decodeColor(values, .disclosureArrow),
                  sectionHeaderTextColor: try decodeColor(values, .sectionHeaderText),
                  freeTextColor: try decodeColor(values, .freeText),
                  freeTextErrorColor: try decodeColor(values, .freeTextError),
                  freeTextSuccessColor: try decodeColor(values, .freeTextSuccess),
                  freeMonoIconColor: try decodeColor(values, .freeMonoIcon),
                  itemSwitchColors: try values.decode(PresentationThemeSwitch.self, forKey: .itemSwitch),
                  itemDisclosureActions: try values.decode(PresentationThemeItemDisclosureActions.self, forKey: .itemDisclosureActions),
                  itemCheckColors: try values.decode(PresentationThemeFillStrokeForeground.self, forKey: .itemCheck),
                  controlSecondaryColor: try decodeColor(values, .controlSecondary),
                  freeInputField: try values.decode(PresentationInputFieldTheme.self, forKey: .freeInputField),
                  mediaPlaceholderColor: try decodeColor(values, .mediaPlaceholder),
                  scrollIndicatorColor: try decodeColor(values, .scrollIndicator),
                  pageIndicatorInactiveColor: try decodeColor(values, .pageIndicatorInactive),
                  inputClearButtonColor: try decodeColor(values, .inputClearButton))
    }
}

extension PresentationThemeArchiveAvatarColors: Decodable {
    enum CodingKeys: String, CodingKey {
        case background
        case foreground
    }
    
    public convenience init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(backgroundColors: try values.decode(PresentationThemeGradientColors.self, forKey: .background),
                  foregroundColor: try decodeColor(values, .foreground))
    }
}

extension PresentationThemeChatList: Decodable {
    enum CodingKeys: String, CodingKey {
        case background
        case itemSeparator
        case itemBackground
        case pinnedItemBackground
        case itemHighlightedBackground
        case itemSelectedBackground
        case title
        case secretTitle
        case dateText
        case authorName
        case messageText
        case messageDraftText
        case checkmark
        case pendingIndicator
        case failedFill
        case failedForeground
        case muteIcon
        case unreadBadgeActiveBackground
        case unreadBadgeActiveText
        case unreadBadgeInactiveBackground
        case unreadBadgeInactiveText
        case pinnedBadge
        case pinnedSearchBar
        case regularSearchBar
        case sectionHeaderFill
        case sectionHeaderText
        case searchBarKeyboard
        case verifiedIconFill
        case verifiedIconForeground
        case secretIcon
        case pinnedArchiveAvatar
        case unpinnedArchiveAvatar
        case onlineDot
    }
    
    public convenience init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(backgroundColor: try decodeColor(values, .background),
                  itemSeparatorColor: try decodeColor(values, .itemSeparator),
                  itemBackgroundColor: try decodeColor(values, .itemBackground),
                  pinnedItemBackgroundColor: try decodeColor(values, .pinnedItemBackground),
                  itemHighlightedBackgroundColor: try decodeColor(values, .itemHighlightedBackground),
                  itemSelectedBackgroundColor: try decodeColor(values, .itemSelectedBackground),
                  titleColor: try decodeColor(values, .title),
                  secretTitleColor: try decodeColor(values, .secretTitle),
                  dateTextColor: try decodeColor(values, .dateText),
                  authorNameColor: try decodeColor(values, .authorName),
                  messageTextColor: try decodeColor(values, .messageText),
                  messageDraftTextColor: try decodeColor(values, .messageDraftText),
                  checkmarkColor: try decodeColor(values, .checkmark),
                  pendingIndicatorColor: try decodeColor(values, .pendingIndicator),
                  failedFillColor: try decodeColor(values, .failedFill),
                  failedForegroundColor: try decodeColor(values, .failedForeground),
                  muteIconColor: try decodeColor(values, .muteIcon),
                  unreadBadgeActiveBackgroundColor: try decodeColor(values, .unreadBadgeActiveBackground),
                  unreadBadgeActiveTextColor: try decodeColor(values, .unreadBadgeActiveText),
                  unreadBadgeInactiveBackgroundColor: try decodeColor(values, .unreadBadgeInactiveBackground),
                  unreadBadgeInactiveTextColor: try decodeColor(values, .unreadBadgeInactiveText),
                  pinnedBadgeColor: try decodeColor(values, .pinnedBadge),
                  pinnedSearchBarColor: try decodeColor(values, .pinnedSearchBar),
                  regularSearchBarColor: try decodeColor(values, .regularSearchBar),
                  sectionHeaderFillColor: try decodeColor(values, .sectionHeaderFill),
                  sectionHeaderTextColor: try decodeColor(values, .sectionHeaderText),
                  searchBarKeyboardColor: try values.decode(PresentationThemeKeyboardColor.self, forKey: .searchBarKeyboard),
                  verifiedIconFillColor: try decodeColor(values, .verifiedIconFill),
                  verifiedIconForegroundColor: try decodeColor(values, .verifiedIconForeground),
                  secretIconColor: try decodeColor(values, .secretIcon),
                  pinnedArchiveAvatarColor: try values.decode(PresentationThemeArchiveAvatarColors.self, forKey: .pinnedArchiveAvatar),
                  unpinnedArchiveAvatarColor: try values.decode(PresentationThemeArchiveAvatarColors.self, forKey: .unpinnedArchiveAvatar),
                  onlineDotColor: try decodeColor(values, .onlineDot))
    }
}

extension PresentationThemeBubbleColorComponents: Decodable {
    enum CodingKeys: String, CodingKey {
        case fill
        case highlightedFill
        case stroke
    }
    
    public convenience init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(fill: try decodeColor(values, .fill),
                  highlightedFill: try decodeColor(values, .highlightedFill),
                  stroke: try decodeColor(values, .stroke))
    }
}

extension PresentationThemeBubbleColor: Decodable {
    enum CodingKeys: String, CodingKey {
        case withWallpaper
        case withoutWallpaper
    }
    
    public convenience init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(withWallpaper: try values.decode(PresentationThemeBubbleColorComponents.self, forKey: .withWallpaper),
                  withoutWallpaper: try values.decode(PresentationThemeBubbleColorComponents.self, forKey: .withoutWallpaper))
    }
}

extension PresentationThemeVariableColor: Decodable {
    enum CodingKeys: String, CodingKey {
        case withWallpaper
        case withoutWallpaper
    }
    
    public convenience init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(withWallpaper: try decodeColor(values, .withWallpaper),
                  withoutWallpaper: try decodeColor(values, .withoutWallpaper))
    }
}

extension PresentationThemeChatBubblePolls: Decodable {
    enum CodingKeys: String, CodingKey {
        case radioButton
        case radioProgress
        case highlight
        case separator
        case bar
    }
    
    public convenience init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(radioButton: try decodeColor(values, .radioButton),
                  radioProgress: try decodeColor(values, .radioProgress),
                  highlight: try decodeColor(values, .highlight),
                  separator: try decodeColor(values, .separator),
                  bar: try decodeColor(values, .bar))
    }
}

extension PresentationThemePartedColors: Decodable {
    enum CodingKeys: String, CodingKey {
        case bubble
        case primaryText
        case secondaryText
        case linkText
        case linkHighlight
        case scam
        case textHighlight
        case accentText
        case accentControl
        case mediaActiveControl
        case mediaInactiveControl
        case pendingActivity
        case fileTitle
        case fileDescription
        case fileDuration
        case mediaPlaceholder
        case polls
        case actionButtonsFill
        case actionButtonsStroke
        case actionButtonsText
    }
    
    public convenience init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(bubble: try values.decode(PresentationThemeBubbleColor.self, forKey: .bubble),
                  primaryTextColor: try decodeColor(values, .primaryText),
                  secondaryTextColor: try decodeColor(values, .secondaryText),
                  linkTextColor: try decodeColor(values, .linkText),
                  linkHighlightColor: try decodeColor(values, .linkHighlight),
                  scamColor: try decodeColor(values, .scam),
                  textHighlightColor: try decodeColor(values, .textHighlight),
                  accentTextColor: try decodeColor(values, .accentText),
                  accentControlColor: try decodeColor(values, .accentControl),
                  mediaActiveControlColor: try decodeColor(values, .mediaActiveControl),
                  mediaInactiveControlColor: try decodeColor(values, .mediaInactiveControl),
                  pendingActivityColor: try decodeColor(values, .pendingActivity),
                  fileTitleColor: try decodeColor(values, .fileTitle),
                  fileDescriptionColor: try decodeColor(values, .fileDescription),
                  fileDurationColor: try decodeColor(values, .fileDuration),
                  mediaPlaceholderColor: try decodeColor(values, .mediaPlaceholder),
                  polls: try values.decode(PresentationThemeChatBubblePolls.self, forKey: .polls),
                  actionButtonsFillColor: try values.decode(PresentationThemeVariableColor.self, forKey: .actionButtonsFill),
                  actionButtonsStrokeColor: try values.decode(PresentationThemeVariableColor.self, forKey: .actionButtonsStroke),
                  actionButtonsTextColor: try values.decode(PresentationThemeVariableColor.self, forKey: .actionButtonsText))
    }
}

extension PresentationThemeChatMessage: Decodable {
    enum CodingKeys: String, CodingKey {
        case incoming
        case outgoing
        case freeform
        case infoPrimaryText
        case infoLinkText
        case outgoingCheck
        case mediaDateAndStatusFill
        case mediaDateAndStatusText
        case shareButtonFill
        case shareButtonStroke
        case shareButtonForeground
        case mediaOverlayControl
        case selectionControl
        case deliveryFailed
        case mediaHighlightOverlay
    }
    
    public convenience init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(incoming: try values.decode(PresentationThemePartedColors.self, forKey: .incoming),
                  outgoing: try values.decode(PresentationThemePartedColors.self, forKey: .outgoing),
                  freeform: try values.decode(PresentationThemeBubbleColor.self, forKey: .freeform),
                  infoPrimaryTextColor: try decodeColor(values, .infoPrimaryText),
                  infoLinkTextColor: try decodeColor(values, .infoLinkText),
                  outgoingCheckColor: try decodeColor(values, .outgoingCheck),
                  mediaDateAndStatusFillColor: try decodeColor(values, .mediaDateAndStatusFill),
                  mediaDateAndStatusTextColor: try decodeColor(values, .mediaDateAndStatusText),
                  shareButtonFillColor: try values.decode(PresentationThemeVariableColor.self, forKey: .shareButtonFill),
                  shareButtonStrokeColor: try values.decode(PresentationThemeVariableColor.self, forKey: .shareButtonStroke),
                  shareButtonForegroundColor: try values.decode(PresentationThemeVariableColor.self, forKey: .shareButtonForeground),
                  mediaOverlayControlColors: try values.decode(PresentationThemeFillForeground.self, forKey: .mediaOverlayControl),
                  selectionControlColors: try values.decode(PresentationThemeFillStrokeForeground.self, forKey: .selectionControl),
                  deliveryFailedColors: try values.decode(PresentationThemeFillForeground.self, forKey: .deliveryFailed),
                  mediaHighlightOverlayColor: try decodeColor(values, .mediaHighlightOverlay))
    }
}

extension PresentationThemeServiceMessageColorComponents: Decodable {
    enum CodingKeys: String, CodingKey {
        case fill
        case primaryText
        case linkHighlight
        case scam
        case dateFillStatic
        case dateFillFloating
    }
    
    public convenience init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(fill: try decodeColor(values, .fill),
                  primaryText: try decodeColor(values, .primaryText),
                  linkHighlight: try decodeColor(values, .linkHighlight),
                  scam: try decodeColor(values, .scam),
                  dateFillStatic: try decodeColor(values, .dateFillStatic),
                  dateFillFloating: try decodeColor(values, .dateFillFloating))
    }
}

extension PresentationThemeServiceMessageColor: Decodable {
    enum CodingKeys: String, CodingKey {
        case withDefaultWallpaper
        case withCustomWallpaper
    }
    
    public convenience init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(withDefaultWallpaper: try values.decode(PresentationThemeServiceMessageColorComponents.self, forKey: .withDefaultWallpaper),
                  withCustomWallpaper: try values.decode(PresentationThemeServiceMessageColorComponents.self, forKey: .withCustomWallpaper))
    }
}

extension PresentationThemeServiceMessage: Decodable {
    enum CodingKeys: String, CodingKey {
        case components
        case unreadBarFill
        case unreadBarStroke
        case unreadBarText
        case dateText
    }
    
    public convenience init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(components: try values.decode(PresentationThemeServiceMessageColor.self, forKey: .components),
                  unreadBarFillColor: try decodeColor(values, .unreadBarFill),
                  unreadBarStrokeColor: try decodeColor(values, .unreadBarStroke),
                  unreadBarTextColor: try decodeColor(values, .unreadBarText),
                  dateTextColor: try values.decode(PresentationThemeVariableColor.self, forKey: .dateText))
    }
}

extension PresentationThemeChatInputPanelMediaRecordingControl: Decodable {
    enum CodingKeys: String, CodingKey {
        case button
        case micLevel
        case activeIcon
        case panelControlFill
        case panelControlStroke
        case panelControlContentPrimary
        case panelControlContentAccent
    }
    
    public convenience init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(buttonColor: try decodeColor(values, .button),
                  micLevelColor: try decodeColor(values, .micLevel),
                  activeIconColor: try decodeColor(values, .activeIcon),
                  panelControlFillColor: try decodeColor(values, .panelControlFill),
                  panelControlStrokeColor: try decodeColor(values, .panelControlStroke),
                  panelControlContentPrimaryColor: try decodeColor(values, .panelControlContentPrimary),
                  panelControlContentAccentColor: try decodeColor(values, .panelControlContentAccent))
    }
}

extension PresentationThemeChatInputPanel: Decodable {
    enum CodingKeys: String, CodingKey {
        case panelBackground
        case panelStroke
        case panelControlAccent
        case panelControl
        case panelControlDisabled
        case panelControlDestructive
        case inputBackground
        case inputStroke
        case inputPlaceholder
        case inputText
        case inputControl
        case actionControlFill
        case actionControlForeground
        case primaryText
        case secondaryText
        case mediaRecordingDot
        case keyboard
        case mediaRecordingControl
    }
    
    public convenience init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(panelBackgroundColor: try decodeColor(values, .panelBackground),
                  panelStrokeColor: try decodeColor(values, .panelStroke),
                  panelControlAccentColor: try decodeColor(values, .panelControlAccent),
                  panelControlColor: try decodeColor(values, .panelControl),
                  panelControlDisabledColor: try decodeColor(values, .panelControlDisabled),
                  panelControlDestructiveColor: try decodeColor(values, .panelControlDestructive),
                  inputBackgroundColor: try decodeColor(values, .inputBackground),
                  inputStrokeColor: try decodeColor(values, .inputStroke),
                  inputPlaceholderColor: try decodeColor(values, .inputPlaceholder),
                  inputTextColor: try decodeColor(values, .inputText),
                  inputControlColor: try decodeColor(values, .inputControl),
                  actionControlFillColor: try decodeColor(values, .actionControlFill),
                  actionControlForegroundColor: try decodeColor(values, .actionControlForeground),
                  primaryTextColor: try decodeColor(values, .primaryText),
                  secondaryTextColor: try decodeColor(values, .secondaryText),
                  mediaRecordingDotColor: try decodeColor(values, .mediaRecordingDot),
                  keyboardColor: try values.decode(PresentationThemeKeyboardColor.self, forKey: .keyboard),
                  mediaRecordingControl: try values.decode(PresentationThemeChatInputPanelMediaRecordingControl.self, forKey: .mediaRecordingControl))
    }
}

extension PresentationThemeInputMediaPanel: Decodable {
    enum CodingKeys: String, CodingKey {
        case panelSeparator
        case panelIcon
        case panelHighlightedIconBackground
        case stickersBackground
        case stickersSectionText
        case stickersSearchBackground
        case stickersSearchPlaceholder
        case stickersSearchPrimary
        case stickersSearchControl
        case gifsBackground
    }
    
    public convenience init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(panelSeparatorColor: try decodeColor(values, .panelSeparator),
                  panelIconColor: try decodeColor(values, .panelIcon),
                  panelHighlightedIconBackgroundColor: try decodeColor(values, .panelHighlightedIconBackground),
                  stickersBackgroundColor: try decodeColor(values, .stickersBackground),
                  stickersSectionTextColor: try decodeColor(values, .stickersSectionText),
                  stickersSearchBackgroundColor: try decodeColor(values, .stickersSearchBackground),
                  stickersSearchPlaceholderColor: try decodeColor(values, .stickersSearchPlaceholder),
                  stickersSearchPrimaryColor: try decodeColor(values, .stickersSearchPrimary),
                  stickersSearchControlColor: try decodeColor(values, .stickersSearchControl),
                  gifsBackgroundColor: try decodeColor(values, .gifsBackground))
    }
}

extension PresentationThemeInputButtonPanel: Decodable {
    enum CodingKeys: String, CodingKey {
        case panelSeparator
        case panelBackground
        case buttonFill
        case buttonStroke
        case buttonHighlightedFill
        case buttonHighlightedStroke
        case buttonText
    }
    
    public convenience init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(panelSeparatorColor: try decodeColor(values, .panelSeparator),
                  panelBackgroundColor: try decodeColor(values, .panelBackground),
                  buttonFillColor: try decodeColor(values, .buttonFill),
                  buttonStrokeColor: try decodeColor(values, .buttonStroke),
                  buttonHighlightedFillColor: try decodeColor(values, .buttonHighlightedFill),
                  buttonHighlightedStrokeColor: try decodeColor(values, .buttonHighlightedStroke),
                  buttonTextColor: try decodeColor(values, .buttonText))
    }
}

extension PresentationThemeChatHistoryNavigation: Decodable {
    enum CodingKeys: String, CodingKey {
        case fill
        case stroke
        case foreground
        case badgeBackground
        case badgeStroke
        case badgeText
    }
    
    public convenience init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(fillColor: try decodeColor(values, .fill),
                  strokeColor: try decodeColor(values, .stroke),
                  foregroundColor: try decodeColor(values, .foreground),
                  badgeBackgroundColor: try decodeColor(values, .badgeBackground),
                  badgeStrokeColor: try decodeColor(values, .badgeStroke),
                  badgeTextColor: try decodeColor(values, .badgeText))
    }
}

extension PresentationThemeChat: Decodable {
    enum CodingKeys: String, CodingKey {
        case message
        case serviceMessage
        case inputPanel
        case inputMediaPanel
        case inputButtonPanel
        case historyNavigation
    }
    
    public convenience init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(message: try values.decode(PresentationThemeChatMessage.self, forKey: .message),
                  serviceMessage: try values.decode(PresentationThemeServiceMessage.self, forKey: .serviceMessage),
                  inputPanel: try values.decode(PresentationThemeChatInputPanel.self, forKey: .inputPanel),
                  inputMediaPanel: try values.decode(PresentationThemeInputMediaPanel.self, forKey: .inputMediaPanel),
                  inputButtonPanel: try values.decode(PresentationThemeInputButtonPanel.self, forKey: .inputButtonPanel),
                  historyNavigation: try values.decode(PresentationThemeChatHistoryNavigation.self, forKey: .historyNavigation))
    }
}

extension PresentationThemeExpandedNotificationNavigationBar: Decodable {
    enum CodingKeys: String, CodingKey {
        case background
        case primaryText
        case control
        case separator
    }
    
    public convenience init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(backgroundColor: try decodeColor(values, .background),
                  primaryTextColor: try decodeColor(values, .primaryText),
                  controlColor: try decodeColor(values, .control),
                  separatorColor: try decodeColor(values, .separator))
    }
}

extension PresentationThemeExpandedNotification: Decodable {
    enum CodingKeys: String, CodingKey {
        case backgroundType
        case navigationBar
    }
    
    public convenience init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(backgroundType: try values.decode(PresentationThemeExpandedNotificationBackgroundType.self, forKey: .backgroundType),
                  navigationBar: try values.decode(PresentationThemeExpandedNotificationNavigationBar.self, forKey: .navigationBar))
    }
}

extension PresentationThemeInAppNotification: Decodable {
    enum CodingKeys: String, CodingKey {
        case fill
        case primaryText
        case expandedNotification
    }
    
    public convenience init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(fillColor: try decodeColor(values, .fill),
                  primaryTextColor: try decodeColor(values, .primaryText),
                  expandedNotification: try values.decode(PresentationThemeExpandedNotification.self, forKey: .expandedNotification))
    }
}

extension PresentationThemeName: Decodable {
    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer()
        self = .custom(try value.decode(String.self))
    }
}

extension PresentationTheme: Decodable {
    enum CodingKeys: String, CodingKey {
        case name
        case author
        case dark
        case auth
        case passcode
        case root
        case list
        case chatList
        case chat
        case actionSheet
        case inAppNotification
    }
    
    public convenience init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(name: try values.decode(PresentationThemeName.self, forKey: .name),
                  author: (try? values.decode(String.self, forKey: .author)) ?? nil,
                  overallDarkAppearance: (try? values.decode(Bool.self, forKey: .dark)) ?? false,
                  auth: try values.decode(PresentationThemeAuth.self, forKey: .auth),
                  passcode: try values.decode(PresentationThemePasscode.self, forKey: .passcode),
                  rootController: try values.decode(PresentationThemeRootController.self, forKey: .root),
                  list: try values.decode(PresentationThemeList.self, forKey: .list),
                  chatList: try values.decode(PresentationThemeChatList.self, forKey: .chatList),
                  chat: try values.decode(PresentationThemeChat.self, forKey: .chat),
                  actionSheet: try values.decode(PresentationThemeActionSheet.self, forKey: .actionSheet),
                  inAppNotification: try values.decode(PresentationThemeInAppNotification.self, forKey: .inAppNotification))
    }
}
