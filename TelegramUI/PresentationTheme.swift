import Foundation
import UIKit
import Display
import Postbox

public enum PresentationThemeParsingError: Error {
    case generic
}

private func parseColor(_ decoder: PostboxDecoder, _ key: String) throws -> UIColor {
    if let value = decoder.decodeOptionalInt32ForKey(key) {
        return UIColor(argb: UInt32(bitPattern: value))
    } else {
        throw PresentationThemeParsingError.generic
    }
}

public final class PresentationThemeRootTabBar {
    public let backgroundColor: UIColor
    public let separatorColor: UIColor
    public let iconColor: UIColor
    public let selectedIconColor: UIColor
    public let textColor: UIColor
    public let selectedTextColor: UIColor
    public let badgeBackgroundColor: UIColor
    public let badgeTextColor: UIColor
    
    public init(backgroundColor: UIColor, separatorColor: UIColor, iconColor: UIColor, selectedIconColor: UIColor, textColor: UIColor, selectedTextColor: UIColor, badgeBackgroundColor: UIColor, badgeTextColor: UIColor) {
        self.backgroundColor = backgroundColor
        self.separatorColor = separatorColor
        self.iconColor = iconColor
        self.selectedIconColor = selectedIconColor
        self.textColor = textColor
        self.selectedTextColor = selectedTextColor
        self.badgeBackgroundColor = badgeBackgroundColor
        self.badgeTextColor = badgeTextColor
    }
    
    public init(decoder: PostboxDecoder) throws {
        self.backgroundColor = try parseColor(decoder, "backgroundColor")
        self.separatorColor = try parseColor(decoder, "separatorColor")
        self.iconColor = try parseColor(decoder, "iconColor")
        self.selectedIconColor = try parseColor(decoder, "selectedIconColor")
        self.textColor = try parseColor(decoder, "textColor")
        self.selectedTextColor = try parseColor(decoder, "selectedTextColor")
        self.badgeBackgroundColor = try parseColor(decoder, "badgeBackgroundColor")
        self.badgeTextColor = try parseColor(decoder, "badgeTextColor")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        for child in Mirror(reflecting: self).children {
            if let label = child.label {
                if let value = child.value as? UIColor {
                    encoder.encodeInt32(Int32(bitPattern: value.argb), forKey: label)
                } else {
                    assertionFailure()
                }
            }
        }
    }
}

public enum PresentationThemeStatusBarStyle: Int32 {
    case black = 0
    case white = 1
    
    var style: StatusBarStyle {
        switch self {
            case .black:
                return .Black
            case .white:
                return .White
        }
    }
}

public final class PresentationThemeRootNavigationStatusBar {
    public let style: PresentationThemeStatusBarStyle
    
    public init(style: PresentationThemeStatusBarStyle) {
        self.style = style
    }
    
    public init(decoder: PostboxDecoder) throws {
        if let styleValue = decoder.decodeOptionalInt32ForKey("style"), let style = PresentationThemeStatusBarStyle(rawValue: styleValue) {
            self.style = style
        } else {
            throw PresentationThemeParsingError.generic
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.style.rawValue, forKey: "style")
    }
}

public final class PresentationThemeRootNavigationBar {
    public let buttonColor: UIColor
    public let primaryTextColor: UIColor
    public let secondaryTextColor: UIColor
    public let controlColor: UIColor
    public let accentTextColor: UIColor
    public let backgroundColor: UIColor
    public let separatorColor: UIColor
    public let badgeBackgroundColor: UIColor
    public let badgeTextColor: UIColor
    
    public init(buttonColor: UIColor, primaryTextColor: UIColor, secondaryTextColor: UIColor, controlColor: UIColor, accentTextColor: UIColor, backgroundColor: UIColor, separatorColor: UIColor, badgeBackgroundColor: UIColor, badgeTextColor: UIColor) {
        self.buttonColor = buttonColor
        self.primaryTextColor = primaryTextColor
        self.secondaryTextColor = secondaryTextColor
        self.controlColor = controlColor
        self.accentTextColor = accentTextColor
        self.backgroundColor = backgroundColor
        self.separatorColor = separatorColor
        self.badgeBackgroundColor = badgeBackgroundColor
        self.badgeTextColor = badgeTextColor
    }
    
    public init(decoder: PostboxDecoder) throws {
        self.buttonColor = try parseColor(decoder, "buttonColor")
        self.primaryTextColor = try parseColor(decoder, "primaryTextColor")
        self.secondaryTextColor = try parseColor(decoder, "secondaryTextColor")
        self.controlColor = try parseColor(decoder, "controlColor")
        self.accentTextColor = try parseColor(decoder, "accentTextColor")
        self.backgroundColor = try parseColor(decoder, "backgroundColor")
        self.separatorColor = try parseColor(decoder, "separatorColor")
        self.badgeBackgroundColor = try parseColor(decoder, "badgeBackgroundColor")
        self.badgeTextColor = try parseColor(decoder, "badgeTextColor")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        for child in Mirror(reflecting: self).children {
            if let label = child.label {
                if let value = child.value as? UIColor {
                    encoder.encodeInt32(Int32(bitPattern: value.argb), forKey: label)
                } else {
                    assertionFailure()
                }
            }
        }
    }
}

public final class PresentationThemeActiveNavigationSearchBar {
    public let backgroundColor: UIColor
    public let accentColor: UIColor
    public let inputFillColor: UIColor
    public let inputTextColor: UIColor
    public let inputPlaceholderTextColor: UIColor
    public let inputIconColor: UIColor
    public let inputClearButtonColor: UIColor
    public let separatorColor: UIColor
    
    public init(backgroundColor: UIColor, accentColor: UIColor, inputFillColor: UIColor, inputTextColor: UIColor, inputPlaceholderTextColor: UIColor, inputIconColor: UIColor, inputClearButtonColor: UIColor, separatorColor: UIColor) {
        self.backgroundColor = backgroundColor
        self.accentColor = accentColor
        self.inputFillColor = inputFillColor
        self.inputTextColor = inputTextColor
        self.inputPlaceholderTextColor = inputPlaceholderTextColor
        self.inputIconColor = inputIconColor
        self.inputClearButtonColor = inputClearButtonColor
        self.separatorColor = separatorColor
    }
    
    public init(decoder: PostboxDecoder) throws {
        self.backgroundColor = try parseColor(decoder, "backgroundColor")
        self.accentColor = try parseColor(decoder, "accentColor")
        self.inputFillColor = try parseColor(decoder, "inputFillColor")
        self.inputTextColor = try parseColor(decoder, "inputTextColor")
        self.inputPlaceholderTextColor = try parseColor(decoder, "inputPlaceholderTextColor")
        self.inputIconColor = try parseColor(decoder, "inputIconColor")
        self.inputClearButtonColor = try parseColor(decoder, "inputClearButtonColor")
        self.separatorColor = try parseColor(decoder, "separatorColor")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        for child in Mirror(reflecting: self).children {
            if let label = child.label {
                if let value = child.value as? UIColor {
                    encoder.encodeInt32(Int32(bitPattern: value.argb), forKey: label)
                } else {
                    assertionFailure()
                }
            }
        }
    }
}

public final class PresentationThemeRootController {
    public let statusBar: PresentationThemeRootNavigationStatusBar
    public let tabBar: PresentationThemeRootTabBar
    public let navigationBar: PresentationThemeRootNavigationBar
    public let activeNavigationSearchBar: PresentationThemeActiveNavigationSearchBar
    
    public init(statusBar: PresentationThemeRootNavigationStatusBar, tabBar: PresentationThemeRootTabBar, navigationBar: PresentationThemeRootNavigationBar, activeNavigationSearchBar: PresentationThemeActiveNavigationSearchBar) {
        self.statusBar = statusBar
        self.tabBar = tabBar
        self.navigationBar = navigationBar
        self.activeNavigationSearchBar = activeNavigationSearchBar
    }
    
    public init(decoder: PostboxDecoder) throws {
        if let statusBar = (try? decoder.decodeObjectForKeyThrowing("statusBar", decoder: { try PresentationThemeRootNavigationStatusBar(decoder: $0) })) as? PresentationThemeRootNavigationStatusBar {
            self.statusBar = statusBar
        } else {
            throw PresentationThemeParsingError.generic
        }
        if let tabBar = (try? decoder.decodeObjectForKeyThrowing("tabBar", decoder: { try PresentationThemeRootTabBar(decoder: $0) })) as? PresentationThemeRootTabBar {
            self.tabBar = tabBar
        } else {
            throw PresentationThemeParsingError.generic
        }
        if let navigationBar = (try? decoder.decodeObjectForKeyThrowing("navigationBar", decoder: { try PresentationThemeRootNavigationBar(decoder: $0) })) as? PresentationThemeRootNavigationBar {
            self.navigationBar = navigationBar
        } else {
            throw PresentationThemeParsingError.generic
        }
        if let activeNavigationSearchBar = (try? decoder.decodeObjectForKeyThrowing("activeNavigationSearchBar", decoder: { try PresentationThemeActiveNavigationSearchBar(decoder: $0) })) as? PresentationThemeActiveNavigationSearchBar {
            self.activeNavigationSearchBar = activeNavigationSearchBar
        } else {
            throw PresentationThemeParsingError.generic
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObjectWithEncoder(self.statusBar, encoder: { self.statusBar.encode($0) }, forKey: "statusBar")
        encoder.encodeObjectWithEncoder(self.tabBar, encoder: { self.tabBar.encode($0) }, forKey: "tabBar")
        encoder.encodeObjectWithEncoder(self.navigationBar, encoder: { self.navigationBar.encode($0) }, forKey: "navigationBar")
        encoder.encodeObjectWithEncoder(self.activeNavigationSearchBar, encoder: { self.activeNavigationSearchBar.encode($0) }, forKey: "activeNavigationSearchBar")
    }
}

public enum PresentationThemeActionSheetBackgroundType: Int32 {
    case light
    case dark
}

public final class PresentationThemeActionSheet {
    public let dimColor: UIColor
    public let backgroundType: PresentationThemeActionSheetBackgroundType
    public let itemBackgroundColor: UIColor
    public let itemHighlightedBackgroundColor: UIColor
    public let standardActionTextColor: UIColor
    public let destructiveActionTextColor: UIColor
    public let disabledActionTextColor: UIColor
    public let primaryTextColor: UIColor
    public let secondaryTextColor: UIColor
    public let controlAccentColor: UIColor
    
    init(dimColor: UIColor, backgroundType: PresentationThemeActionSheetBackgroundType, itemBackgroundColor: UIColor, itemHighlightedBackgroundColor: UIColor, standardActionTextColor: UIColor, destructiveActionTextColor: UIColor, disabledActionTextColor: UIColor, primaryTextColor: UIColor, secondaryTextColor: UIColor, controlAccentColor: UIColor) {
        self.dimColor = dimColor
        self.backgroundType = backgroundType
        self.itemBackgroundColor = itemBackgroundColor
        self.itemHighlightedBackgroundColor = itemHighlightedBackgroundColor
        self.standardActionTextColor = standardActionTextColor
        self.destructiveActionTextColor = destructiveActionTextColor
        self.disabledActionTextColor = disabledActionTextColor
        self.primaryTextColor = primaryTextColor
        self.secondaryTextColor = secondaryTextColor
        self.controlAccentColor = controlAccentColor
    }
    
    public init(decoder: PostboxDecoder) throws {
        self.dimColor = try parseColor(decoder, "dimColor")
        self.backgroundType = PresentationThemeActionSheetBackgroundType(rawValue: decoder.decodeInt32ForKey("backgroundType", orElse: 0)) ?? .light
        self.itemBackgroundColor = try parseColor(decoder, "itemBackgroundColor")
        self.itemHighlightedBackgroundColor = try parseColor(decoder, "itemHighlightedBackgroundColor")
        self.standardActionTextColor = try parseColor(decoder, "standardActionTextColor")
        self.destructiveActionTextColor = try parseColor(decoder, "destructiveActionTextColor")
        self.disabledActionTextColor = try parseColor(decoder, "disabledActionTextColor")
        self.primaryTextColor = try parseColor(decoder, "primaryTextColor")
        self.secondaryTextColor = try parseColor(decoder, "secondaryTextColor")
        self.controlAccentColor = try parseColor(decoder, "controlAccentColor")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        for child in Mirror(reflecting: self).children {
            if let label = child.label {
                if let value = child.value as? UIColor {
                    encoder.encodeInt32(Int32(bitPattern: value.argb), forKey: label)
                } else if let value = child.value as? PresentationThemeActionSheetBackgroundType {
                    encoder.encodeInt32(value.rawValue, forKey: label)
                } else {
                    assertionFailure()
                }
            }
        }
    }
}

public final class PresentationThemeSwitch {
    public let frameColor: UIColor
    public let handleColor: UIColor
    public let contentColor: UIColor
    
    public init(frameColor: UIColor, handleColor: UIColor, contentColor: UIColor) {
        self.frameColor = frameColor
        self.handleColor = handleColor
        self.contentColor = contentColor
    }
    
    public init(decoder: PostboxDecoder) throws {
        self.frameColor = try parseColor(decoder, "frameColor")
        self.handleColor = try parseColor(decoder, "handleColor")
        self.contentColor = try parseColor(decoder, "contentColor")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        for child in Mirror(reflecting: self).children {
            if let label = child.label {
                if let value = child.value as? UIColor {
                    encoder.encodeInt32(Int32(bitPattern: value.argb), forKey: label)
                } else {
                    assertionFailure()
                }
            }
        }
    }
}

public final class PresentationThemeList {
    public let blocksBackgroundColor: UIColor
    public let plainBackgroundColor: UIColor
    public let itemPrimaryTextColor: UIColor
    public let itemSecondaryTextColor: UIColor
    public let itemDisabledTextColor: UIColor
    public let itemAccentColor: UIColor
    public let itemDestructiveColor: UIColor
    public let itemPlaceholderTextColor: UIColor
    public let itemBackgroundColor: UIColor
    public let itemHighlightedBackgroundColor: UIColor
    public let itemSeparatorColor: UIColor
    public let disclosureArrowColor: UIColor
    public let sectionHeaderTextColor: UIColor
    public let freeTextColor: UIColor
    public let freeTextErrorColor: UIColor
    public let freeTextSuccessColor: UIColor
    public let itemSwitchColors: PresentationThemeSwitch
    
    public init(blocksBackgroundColor: UIColor, plainBackgroundColor: UIColor, itemPrimaryTextColor: UIColor, itemSecondaryTextColor: UIColor, itemDisabledTextColor: UIColor, itemAccentColor: UIColor, itemDestructiveColor: UIColor, itemPlaceholderTextColor: UIColor, itemBackgroundColor: UIColor, itemHighlightedBackgroundColor: UIColor, itemSeparatorColor: UIColor, disclosureArrowColor: UIColor, sectionHeaderTextColor: UIColor, freeTextColor: UIColor, freeTextErrorColor: UIColor, freeTextSuccessColor: UIColor, itemSwitchColors: PresentationThemeSwitch) {
        self.blocksBackgroundColor = blocksBackgroundColor
        self.plainBackgroundColor = plainBackgroundColor
        self.itemPrimaryTextColor = itemPrimaryTextColor
        self.itemSecondaryTextColor = itemSecondaryTextColor
        self.itemDisabledTextColor = itemDisabledTextColor
        self.itemAccentColor = itemAccentColor
        self.itemDestructiveColor = itemDestructiveColor
        self.itemPlaceholderTextColor = itemPlaceholderTextColor
        self.itemBackgroundColor = itemBackgroundColor
        self.itemHighlightedBackgroundColor = itemHighlightedBackgroundColor
        self.itemSeparatorColor = itemSeparatorColor
        self.disclosureArrowColor = disclosureArrowColor
        self.sectionHeaderTextColor = sectionHeaderTextColor
        self.freeTextColor = freeTextColor
        self.freeTextErrorColor = freeTextErrorColor
        self.freeTextSuccessColor = freeTextSuccessColor
        self.itemSwitchColors = itemSwitchColors
    }
    
    public init(decoder: PostboxDecoder) throws {
        self.blocksBackgroundColor = try parseColor(decoder, "blocksBackgroundColor")
        self.plainBackgroundColor = try parseColor(decoder, "plainBackgroundColor")
        self.itemPrimaryTextColor = try parseColor(decoder, "itemPrimaryTextColor")
        self.itemSecondaryTextColor = try parseColor(decoder, "itemSecondaryTextColor")
        self.itemDisabledTextColor = try parseColor(decoder, "itemDisabledTextColor")
        self.itemAccentColor = try parseColor(decoder, "itemAccentColor")
        self.itemDestructiveColor = try parseColor(decoder, "itemDestructiveColor")
        self.itemPlaceholderTextColor = try parseColor(decoder, "itemPlaceholderTextColor")
        self.itemBackgroundColor = try parseColor(decoder, "itemBackgroundColor")
        self.itemHighlightedBackgroundColor = try parseColor(decoder, "itemHighlightedBackgroundColor")
        self.itemSeparatorColor = try parseColor(decoder, "itemSeparatorColor")
        self.disclosureArrowColor = try parseColor(decoder, "disclosureArrowColor")
        self.sectionHeaderTextColor = try parseColor(decoder, "sectionHeaderTextColor")
        self.freeTextColor = try parseColor(decoder, "freeTextColor")
        self.freeTextErrorColor = try parseColor(decoder, "freeTextErrorColor")
        self.freeTextSuccessColor = try parseColor(decoder, "freeTextSuccessColor")
        if let itemSwitchColors = (try? decoder.decodeObjectForKeyThrowing("itemSwitchColors", decoder: { try PresentationThemeSwitch(decoder: $0) })) as? PresentationThemeSwitch {
            self.itemSwitchColors = itemSwitchColors
        } else {
            throw PresentationThemeParsingError.generic
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        for child in Mirror(reflecting: self).children {
            if let label = child.label {
                if let value = child.value as? UIColor {
                    encoder.encodeInt32(Int32(bitPattern: value.argb), forKey: label)
                } else if let value = child.value as? PresentationThemeSwitch {
                    encoder.encodeObjectWithEncoder(value, encoder: { value.encode($0) }, forKey: label)
                } else {
                    assertionFailure()
                }
            }
        }
    }
}

public final class PresentationThemeChatList {
    public let backgroundColor: UIColor
    public let itemSeparatorColor: UIColor
    public let itemBackgroundColor: UIColor
    public let pinnedItemBackgroundColor: UIColor
    public let itemHighlightedBackgroundColor: UIColor
    public let titleColor: UIColor
    public let secretTitleColor: UIColor
    public let dateTextColor: UIColor
    public let authorNameColor: UIColor
    public let messageTextColor: UIColor
    public let messageDraftTextColor: UIColor
    public let checkmarkColor: UIColor
    public let pendingIndicatorColor: UIColor
    public let muteIconColor: UIColor
    public let unreadBadgeActiveBackgroundColor: UIColor
    public let unreadBadgeActiveTextColor: UIColor
    public let unreadBadgeInactiveBackgroundColor: UIColor
    public let unreadBadgeInactiveTextColor: UIColor
    public let pinnedBadgeColor: UIColor
    public let pinnedSearchBarColor: UIColor
    public let regularSearchBarColor: UIColor
    public let sectionHeaderFillColor: UIColor
    public let sectionHeaderTextColor: UIColor
    public let searchBarKeyboardColor: PresentationThemeKeyboardColor
    
    init(backgroundColor: UIColor, itemSeparatorColor: UIColor, itemBackgroundColor: UIColor, pinnedItemBackgroundColor: UIColor, itemHighlightedBackgroundColor: UIColor, titleColor: UIColor, secretTitleColor: UIColor, dateTextColor: UIColor, authorNameColor: UIColor, messageTextColor: UIColor, messageDraftTextColor: UIColor, checkmarkColor: UIColor, pendingIndicatorColor: UIColor, muteIconColor: UIColor, unreadBadgeActiveBackgroundColor: UIColor, unreadBadgeActiveTextColor: UIColor, unreadBadgeInactiveBackgroundColor: UIColor, unreadBadgeInactiveTextColor: UIColor, pinnedBadgeColor: UIColor, pinnedSearchBarColor: UIColor, regularSearchBarColor: UIColor, sectionHeaderFillColor: UIColor, sectionHeaderTextColor: UIColor, searchBarKeyboardColor: PresentationThemeKeyboardColor) {
        self.backgroundColor = backgroundColor
        self.itemSeparatorColor = itemSeparatorColor
        self.itemBackgroundColor = itemBackgroundColor
        self.pinnedItemBackgroundColor = pinnedItemBackgroundColor
        self.itemHighlightedBackgroundColor = itemHighlightedBackgroundColor
        self.titleColor = titleColor
        self.secretTitleColor = secretTitleColor
        self.dateTextColor = dateTextColor
        self.authorNameColor = authorNameColor
        self.messageTextColor = messageTextColor
        self.messageDraftTextColor = messageDraftTextColor
        self.checkmarkColor = checkmarkColor
        self.pendingIndicatorColor = pendingIndicatorColor
        self.muteIconColor = muteIconColor
        self.unreadBadgeActiveBackgroundColor = unreadBadgeActiveBackgroundColor
        self.unreadBadgeActiveTextColor = unreadBadgeActiveTextColor
        self.unreadBadgeInactiveBackgroundColor = unreadBadgeInactiveBackgroundColor
        self.unreadBadgeInactiveTextColor = unreadBadgeInactiveTextColor
        self.pinnedBadgeColor = pinnedBadgeColor
        self.pinnedSearchBarColor = pinnedSearchBarColor
        self.regularSearchBarColor = regularSearchBarColor
        self.sectionHeaderFillColor = sectionHeaderFillColor
        self.sectionHeaderTextColor = sectionHeaderTextColor
        self.searchBarKeyboardColor = searchBarKeyboardColor
    }
    
    init(decoder: PostboxDecoder) throws {
        self.backgroundColor = try parseColor(decoder, "backgroundColor")
        self.itemSeparatorColor = try parseColor(decoder, "itemSeparatorColor")
        self.itemBackgroundColor = try parseColor(decoder, "itemBackgroundColor")
        self.pinnedItemBackgroundColor = try parseColor(decoder, "pinnedItemBackgroundColor")
        self.itemHighlightedBackgroundColor = try parseColor(decoder, "itemHighlightedBackgroundColor")
        self.titleColor = try parseColor(decoder, "titleColor")
        self.secretTitleColor = try parseColor(decoder, "secretTitleColor")
        self.dateTextColor = try parseColor(decoder, "dateTextColor")
        self.authorNameColor = try parseColor(decoder, "authorNameColor")
        self.messageTextColor = try parseColor(decoder, "messageTextColor")
        self.messageDraftTextColor = try parseColor(decoder, "messageDraftTextColor")
        self.checkmarkColor = try parseColor(decoder, "checkmarkColor")
        self.pendingIndicatorColor = try parseColor(decoder, "pendingIndicatorColor")
        self.muteIconColor = try parseColor(decoder, "muteIconColor")
        self.unreadBadgeActiveBackgroundColor = try parseColor(decoder, "unreadBadgeActiveBackgroundColor")
        self.unreadBadgeActiveTextColor = try parseColor(decoder, "unreadBadgeActiveTextColor")
        self.unreadBadgeInactiveBackgroundColor = try parseColor(decoder, "unreadBadgeInactiveBackgroundColor")
        self.unreadBadgeInactiveTextColor = try parseColor(decoder, "unreadBadgeInactiveTextColor")
        self.pinnedBadgeColor = try parseColor(decoder, "pinnedBadgeColor")
        self.pinnedSearchBarColor = try parseColor(decoder, "pinnedSearchBarColor")
        self.regularSearchBarColor = try parseColor(decoder, "regularSearchBarColor")
        self.sectionHeaderFillColor = try parseColor(decoder, "sectionHeaderFillColor")
        self.sectionHeaderTextColor = try parseColor(decoder, "sectionHeaderTextColor")
        if let value = decoder.decodeOptionalInt32ForKey("searchBarKeyboardColor"), let color = PresentationThemeKeyboardColor(rawValue: value) {
            self.searchBarKeyboardColor = color
        } else {
            throw PresentationThemeParsingError.generic
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        for child in Mirror(reflecting: self).children {
            if let label = child.label {
                if let value = child.value as? UIColor {
                    encoder.encodeInt32(Int32(bitPattern: value.argb), forKey: label)
                } else if let value = child.value as? PresentationThemeSwitch {
                    encoder.encodeObjectWithEncoder(value, encoder: { value.encode($0) }, forKey: label)
                } else if let value = child.value as? PresentationThemeKeyboardColor {
                    encoder.encodeInt32(value.rawValue, forKey: label)
                } else {
                    assertionFailure()
                }
            }
        }
    }
}

public final class PresentationThemeChatBubble {
    public let incomingFillColor: UIColor
    public let incomingFillHighlightedColor: UIColor
    public let incomingStrokeColor: UIColor
    
    public let outgoingFillColor: UIColor
    public let outgoingFillHighlightedColor: UIColor
    public let outgoingStrokeColor: UIColor
    
    public let freeformFillColor: UIColor
    public let freeformFillHighlightedColor: UIColor
    public let freeformStrokeColor: UIColor
    
    public let infoFillColor: UIColor
    public let infoStrokeColor: UIColor
    
    public let incomingPrimaryTextColor: UIColor
    public let incomingSecondaryTextColor: UIColor
    public let incomingLinkTextColor: UIColor
    public let incomingLinkHighlightColor: UIColor
    public let outgoingPrimaryTextColor: UIColor
    public let outgoingSecondaryTextColor: UIColor
    public let outgoingLinkTextColor: UIColor
    public let outgoingLinkHighlightColor: UIColor
    public let infoPrimaryTextColor: UIColor
    public let infoLinkTextColor: UIColor
    
    public let incomingAccentColor: UIColor
    public let outgoingAccentColor: UIColor
    
    public let outgoingCheckColor: UIColor
    public let incomingPendingActivityColor: UIColor
    public let outgoingPendingActivityColor: UIColor
    
    public let mediaDateAndStatusFillColor: UIColor
    public let mediaDateAndStatusTextColor: UIColor
    
    public let incomingFileTitleColor: UIColor
    public let outgoingFileTitleColor: UIColor
    public let incomingFileDescriptionColor: UIColor
    public let outgoingFileDescriptionColor: UIColor
    public let incomingFileDurationColor: UIColor
    public let outgoingFileDurationColor: UIColor
    
    public let shareButtonFillColor: UIColor
    public let shareButtonForegroundColor: UIColor
    
    public let mediaOverlayControlBackgroundColor: UIColor
    public let mediaOverlayControlForegroundColor: UIColor
    
    public let actionButtonsFillColor: UIColor
    public let actionButtonsTextColor: UIColor
    
    public init(incomingFillColor: UIColor, incomingFillHighlightedColor: UIColor, incomingStrokeColor: UIColor, outgoingFillColor: UIColor, outgoingFillHighlightedColor: UIColor, outgoingStrokeColor: UIColor, freeformFillColor: UIColor, freeformFillHighlightedColor: UIColor, freeformStrokeColor: UIColor, infoFillColor: UIColor, infoStrokeColor: UIColor, incomingPrimaryTextColor: UIColor, incomingSecondaryTextColor: UIColor, incomingLinkTextColor: UIColor, incomingLinkHighlightColor: UIColor, outgoingPrimaryTextColor: UIColor, outgoingSecondaryTextColor: UIColor, outgoingLinkTextColor: UIColor, outgoingLinkHighlightColor: UIColor, infoPrimaryTextColor: UIColor, infoLinkTextColor: UIColor, incomingAccentColor: UIColor, outgoingAccentColor: UIColor, outgoingCheckColor: UIColor, incomingPendingActivityColor: UIColor, outgoingPendingActivityColor: UIColor, mediaDateAndStatusFillColor: UIColor, mediaDateAndStatusTextColor: UIColor, incomingFileTitleColor: UIColor, outgoingFileTitleColor: UIColor, incomingFileDescriptionColor: UIColor, outgoingFileDescriptionColor: UIColor, incomingFileDurationColor: UIColor, outgoingFileDurationColor: UIColor, shareButtonFillColor: UIColor, shareButtonForegroundColor: UIColor, mediaOverlayControlBackgroundColor: UIColor, mediaOverlayControlForegroundColor: UIColor, actionButtonsFillColor: UIColor, actionButtonsTextColor: UIColor) {
        self.incomingFillColor = incomingFillColor
        self.incomingFillHighlightedColor = incomingFillHighlightedColor
        self.incomingStrokeColor = incomingStrokeColor
        self.outgoingFillColor = outgoingFillColor
        self.outgoingFillHighlightedColor = outgoingFillHighlightedColor
        self.outgoingStrokeColor = outgoingStrokeColor
        self.freeformFillColor = freeformFillColor
        self.freeformFillHighlightedColor = freeformFillHighlightedColor
        self.freeformStrokeColor = freeformStrokeColor
        self.infoFillColor = infoFillColor
        self.infoStrokeColor = infoStrokeColor
        
        self.incomingPrimaryTextColor = incomingPrimaryTextColor
        self.incomingSecondaryTextColor = incomingSecondaryTextColor
        self.incomingLinkTextColor = incomingLinkTextColor
        self.incomingLinkHighlightColor = incomingLinkHighlightColor
        self.outgoingPrimaryTextColor = outgoingPrimaryTextColor
        self.outgoingSecondaryTextColor = outgoingSecondaryTextColor
        self.outgoingLinkTextColor = outgoingLinkTextColor
        self.outgoingLinkHighlightColor = outgoingLinkHighlightColor
        self.infoPrimaryTextColor = infoPrimaryTextColor
        self.infoLinkTextColor = infoLinkTextColor
        
        self.incomingAccentColor = incomingAccentColor
        self.outgoingAccentColor = outgoingAccentColor
        
        self.outgoingCheckColor = outgoingCheckColor
        self.incomingPendingActivityColor = incomingPendingActivityColor
        self.outgoingPendingActivityColor = outgoingPendingActivityColor
        self.mediaDateAndStatusFillColor = mediaDateAndStatusFillColor
        self.mediaDateAndStatusTextColor = mediaDateAndStatusTextColor
        
        self.incomingFileTitleColor = incomingFileTitleColor
        self.outgoingFileTitleColor = outgoingFileTitleColor
        self.incomingFileDescriptionColor = incomingFileDescriptionColor
        self.outgoingFileDescriptionColor = outgoingFileDescriptionColor
        self.incomingFileDurationColor = incomingFileDurationColor
        self.outgoingFileDurationColor = outgoingFileDurationColor
        
        self.shareButtonFillColor = shareButtonFillColor
        self.shareButtonForegroundColor = shareButtonForegroundColor
        
        self.mediaOverlayControlBackgroundColor = mediaOverlayControlBackgroundColor
        self.mediaOverlayControlForegroundColor = mediaOverlayControlForegroundColor
        
        self.actionButtonsFillColor = actionButtonsFillColor
        self.actionButtonsTextColor = actionButtonsTextColor
    }
    
    public init(decoder: PostboxDecoder) throws {
        self.incomingFillColor = try parseColor(decoder, "incomingFillColor")
        self.incomingFillHighlightedColor = try parseColor(decoder, "incomingFillHighlightedColor")
        self.incomingStrokeColor = try parseColor(decoder, "incomingStrokeColor")
        self.outgoingFillColor = try parseColor(decoder, "outgoingFillColor")
        self.outgoingFillHighlightedColor = try parseColor(decoder, "outgoingFillHighlightedColor")
        self.outgoingStrokeColor = try parseColor(decoder, "outgoingStrokeColor")
        self.freeformFillColor = try parseColor(decoder, "freeformFillColor")
        self.freeformFillHighlightedColor = try parseColor(decoder, "freeformFillHighlightedColor")
        self.freeformStrokeColor = try parseColor(decoder, "freeformStrokeColor")
        self.infoFillColor = try parseColor(decoder, "infoFillColor")
        self.infoStrokeColor = try parseColor(decoder, "infoStrokeColor")
        
        self.incomingPrimaryTextColor = try parseColor(decoder, "incomingPrimaryTextColor")
        self.incomingSecondaryTextColor = try parseColor(decoder, "incomingSecondaryTextColor")
        self.incomingLinkTextColor = try parseColor(decoder, "incomingLinkTextColor")
        self.incomingLinkHighlightColor = try parseColor(decoder, "incomingLinkHighlightColor")
        self.outgoingPrimaryTextColor = try parseColor(decoder, "outgoingPrimaryTextColor")
        self.outgoingSecondaryTextColor = try parseColor(decoder, "outgoingSecondaryTextColor")
        self.outgoingLinkTextColor = try parseColor(decoder, "outgoingLinkTextColor")
        self.outgoingLinkHighlightColor = try parseColor(decoder, "outgoingLinkhighlightColor")
        self.infoPrimaryTextColor = try parseColor(decoder, "infoPrimaryTextColor")
        self.infoLinkTextColor = try parseColor(decoder, "infoLinkTextColor")
        
        self.incomingAccentColor = try parseColor(decoder, "incomingAccentColor")
        self.outgoingAccentColor = try parseColor(decoder, "outgoingAccentColor")
        
        self.outgoingCheckColor = try parseColor(decoder, "outgoingCheckColor")
        self.incomingPendingActivityColor = try parseColor(decoder, "incomingPendingActivityColor")
        self.outgoingPendingActivityColor = try parseColor(decoder, "outgoingPendingActivityColor")
        self.mediaDateAndStatusFillColor = try parseColor(decoder, "mediaDateAndStatusFillColor")
        self.mediaDateAndStatusTextColor = try parseColor(decoder, "mediaDateAndStatusTextColor")
        
        self.incomingFileTitleColor = try parseColor(decoder, "incomingFileTitleColor")
        self.outgoingFileTitleColor = try parseColor(decoder, "outgoingFileTitleColor")
        self.incomingFileDescriptionColor = try parseColor(decoder, "incomingFileDescriptionColor")
        self.outgoingFileDescriptionColor = try parseColor(decoder, "outgoingFileDescriptionColor")
        self.incomingFileDurationColor = try parseColor(decoder, "incomingFileDurationColor")
        self.outgoingFileDurationColor = try parseColor(decoder, "outgoingFileDurationColor")
        
        self.shareButtonFillColor = try parseColor(decoder, "shareButtonFillColor")
        self.shareButtonForegroundColor = try parseColor(decoder, "shareButtonForegroundColor")
        
        self.mediaOverlayControlBackgroundColor = try parseColor(decoder, "mediaOverlayControlBackgroundColor")
        self.mediaOverlayControlForegroundColor = try parseColor(decoder, "mediaOverlayControlForegroundColor")
        
        self.actionButtonsFillColor = try parseColor(decoder, "actionButtonsFillColor")
        self.actionButtonsTextColor = try parseColor(decoder, "actionButtonsTextColor")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        for child in Mirror(reflecting: self).children {
            if let label = child.label {
                if let value = child.value as? UIColor {
                    encoder.encodeInt32(Int32(bitPattern: value.argb), forKey: label)
                } else if let value = child.value as? PresentationThemeSwitch {
                    encoder.encodeObjectWithEncoder(value, encoder: { value.encode($0) }, forKey: label)
                } else {
                    assertionFailure()
                }
            }
        }
    }
}

public final class PresentationThemeServiceMessage {
    public let serviceMessageFillColor: UIColor
    public let serviceMessagePrimaryTextColor: UIColor
    public let serviceMessageLinkHighlightColor: UIColor
    
    public let unreadBarFillColor: UIColor
    public let unreadBarStrokeColor: UIColor
    public let unreadBarTextColor: UIColor
    
    public let dateFillStaticColor: UIColor
    public let dateFillFloatingColor: UIColor
    public let dateTextColor: UIColor
    
    public init(serviceMessageFillColor: UIColor, serviceMessagePrimaryTextColor: UIColor, serviceMessageLinkHighlightColor: UIColor, unreadBarFillColor: UIColor, unreadBarStrokeColor: UIColor, unreadBarTextColor: UIColor, dateFillStaticColor: UIColor, dateFillFloatingColor: UIColor, dateTextColor: UIColor) {
        self.serviceMessageFillColor = serviceMessageFillColor
        self.serviceMessagePrimaryTextColor = serviceMessagePrimaryTextColor
        self.serviceMessageLinkHighlightColor = serviceMessageLinkHighlightColor
        self.unreadBarFillColor = unreadBarFillColor
        self.unreadBarStrokeColor = unreadBarStrokeColor
        self.unreadBarTextColor = unreadBarTextColor
        self.dateFillStaticColor = dateFillStaticColor
        self.dateFillFloatingColor = dateFillFloatingColor
        self.dateTextColor = dateTextColor
    }
    
    public init(decoder: PostboxDecoder) throws {
        self.serviceMessageFillColor = try parseColor(decoder, "serviceMessageFillColor")
        self.serviceMessagePrimaryTextColor = try parseColor(decoder, "serviceMessagePrimaryTextColor")
        self.serviceMessageLinkHighlightColor = try parseColor(decoder, "serviceMessageLinkHighlightColor")
        self.unreadBarFillColor = try parseColor(decoder, "unreadBarFillColor")
        self.unreadBarStrokeColor = try parseColor(decoder, "unreadBarStrokeColor")
        self.unreadBarTextColor = try parseColor(decoder, "unreadBarTextColor")
        self.dateFillStaticColor = try parseColor(decoder, "dateFillStaticColor")
        self.dateFillFloatingColor = try parseColor(decoder, "dateFillFloatingColor")
        self.dateTextColor = try parseColor(decoder, "dateTextColor")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        for child in Mirror(reflecting: self).children {
            if let label = child.label {
                if let value = child.value as? UIColor {
                    encoder.encodeInt32(Int32(bitPattern: value.argb), forKey: label)
                } else if let value = child.value as? PresentationThemeSwitch {
                    encoder.encodeObjectWithEncoder(value, encoder: { value.encode($0) }, forKey: label)
                } else {
                    assertionFailure()
                }
            }
        }
    }
}

public enum PresentationThemeKeyboardColor: Int32 {
    case light = 0
    case dark = 1
    
    public var keyboardAppearance: UIKeyboardAppearance {
        switch self {
            case .light:
                return .default
            case .dark:
                return .dark
        }
    }
}

public final class PresentationThemeChatInputPanelMediaRecordingControl {
    public let buttonColor: UIColor
    public let micLevelColor: UIColor
    public let activeIconColor: UIColor
    public let panelControlFillColor: UIColor
    public let panelControlStrokeColor: UIColor
    public let panelControlContentPrimaryColor: UIColor
    public let panelControlContentAccentColor: UIColor
    
    init(buttonColor: UIColor, micLevelColor: UIColor, activeIconColor: UIColor, panelControlFillColor: UIColor, panelControlStrokeColor: UIColor, panelControlContentPrimaryColor: UIColor, panelControlContentAccentColor: UIColor) {
        self.buttonColor = buttonColor
        self.micLevelColor = micLevelColor
        self.activeIconColor = activeIconColor
        self.panelControlFillColor = panelControlFillColor
        self.panelControlStrokeColor = panelControlStrokeColor
        self.panelControlContentPrimaryColor = panelControlContentPrimaryColor
        self.panelControlContentAccentColor = panelControlContentAccentColor
    }
    
    public init(decoder: PostboxDecoder) throws {
        self.buttonColor = try parseColor(decoder, "buttonColor")
        self.micLevelColor = try parseColor(decoder, "micLevelColor")
        self.activeIconColor = try parseColor(decoder, "activeIconColor")
        self.panelControlFillColor = try parseColor(decoder, "panelControlFillColor")
        self.panelControlStrokeColor = try parseColor(decoder, "panelControlStrokeColor")
        self.panelControlContentPrimaryColor = try parseColor(decoder, "panelControlContentPrimaryColor")
        self.panelControlContentAccentColor = try parseColor(decoder, "panelControlContentAccentColor")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        for child in Mirror(reflecting: self).children {
            if let label = child.label {
                if let value = child.value as? UIColor {
                    encoder.encodeInt32(Int32(bitPattern: value.argb), forKey: label)
                } else {
                    assertionFailure()
                }
            }
        }
    }
}

public final class PresentationThemeChatInputPanel {
    public let panelBackgroundColor: UIColor
    public let panelStrokeColor: UIColor
    public let panelControlAccentColor: UIColor
    public let panelControlColor: UIColor
    public let panelControlDisabledColor: UIColor
    public let panelControlDestructiveColor: UIColor
    public let inputBackgroundColor: UIColor
    public let inputStrokeColor: UIColor
    public let inputPlaceholderColor: UIColor
    public let inputTextColor: UIColor
    public let inputControlColor: UIColor
    public let primaryTextColor: UIColor
    public let mediaRecordingDotColor: UIColor
    public let keyboardColor: PresentationThemeKeyboardColor
    public let mediaRecordingControl: PresentationThemeChatInputPanelMediaRecordingControl
    
    public init(panelBackgroundColor: UIColor, panelStrokeColor: UIColor, panelControlAccentColor: UIColor, panelControlColor: UIColor, panelControlDisabledColor: UIColor, panelControlDestructiveColor: UIColor, inputBackgroundColor: UIColor, inputStrokeColor: UIColor, inputPlaceholderColor: UIColor, inputTextColor: UIColor, inputControlColor: UIColor, primaryTextColor: UIColor, mediaRecordingDotColor: UIColor, keyboardColor: PresentationThemeKeyboardColor, mediaRecordingControl: PresentationThemeChatInputPanelMediaRecordingControl) {
        self.panelBackgroundColor = panelBackgroundColor
        self.panelStrokeColor = panelStrokeColor
        self.panelControlAccentColor = panelControlAccentColor
        self.panelControlColor = panelControlColor
        self.panelControlDisabledColor = panelControlDisabledColor
        self.panelControlDestructiveColor = panelControlDestructiveColor
        self.inputBackgroundColor = inputBackgroundColor
        self.inputStrokeColor = inputStrokeColor
        self.inputPlaceholderColor = inputPlaceholderColor
        self.inputTextColor = inputTextColor
        self.inputControlColor = inputControlColor
        self.primaryTextColor = primaryTextColor
        self.mediaRecordingDotColor = mediaRecordingDotColor
        self.keyboardColor = keyboardColor
        self.mediaRecordingControl = mediaRecordingControl
    }
    
    public init(decoder: PostboxDecoder) throws {
        self.panelBackgroundColor = try parseColor(decoder, "panelBackgroundColor")
        self.panelStrokeColor = try parseColor(decoder, "panelStrokeColor")
        self.panelControlAccentColor = try parseColor(decoder, "panelControlAccentColor")
        self.panelControlColor = try parseColor(decoder, "panelControlColor")
        self.panelControlDisabledColor = try parseColor(decoder, "panelControlDisabledColor")
        self.panelControlDestructiveColor = try parseColor(decoder, "panelControlDestructiveColor")
        self.inputBackgroundColor = try parseColor(decoder, "inputBackgroundColor")
        self.inputStrokeColor = try parseColor(decoder, "inputStrokeColor")
        self.inputPlaceholderColor = try parseColor(decoder, "inputPlaceholderColor")
        self.inputTextColor = try parseColor(decoder, "inputTextColor")
        self.inputControlColor = try parseColor(decoder, "inputControlColor")
        self.primaryTextColor = try parseColor(decoder, "primaryTextColor")
        self.mediaRecordingDotColor = try parseColor(decoder, "mediaRecordingDotColor")
        if let value = decoder.decodeOptionalInt32ForKey("keyboardColor"), let color = PresentationThemeKeyboardColor(rawValue: value) {
            self.keyboardColor = color
        } else {
            throw PresentationThemeParsingError.generic
        }
        if let mediaRecordingControl = (try? decoder.decodeObjectForKeyThrowing("mediaRecordingControl", decoder: { try PresentationThemeChatInputPanelMediaRecordingControl(decoder: $0) })) as? PresentationThemeChatInputPanelMediaRecordingControl {
            self.mediaRecordingControl = mediaRecordingControl
        } else {
            throw PresentationThemeParsingError.generic
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        for child in Mirror(reflecting: self).children {
            if let label = child.label {
                if let value = child.value as? UIColor {
                    encoder.encodeInt32(Int32(bitPattern: value.argb), forKey: label)
                } else if let value = child.value as? PresentationThemeSwitch {
                    encoder.encodeObjectWithEncoder(value, encoder: { value.encode($0) }, forKey: label)
                } else if let value = child.value as? PresentationThemeKeyboardColor {
                    encoder.encodeInt32(value.rawValue, forKey: label)
                } else if let value = child.value as? PresentationThemeChatInputPanelMediaRecordingControl {
                    encoder.encodeObjectWithEncoder(value, encoder: { value.encode($0) }, forKey: label)
                } else {
                    assertionFailure()
                }
            }
        }
    }
}

public final class PresentationThemeInputMediaPanel {
    public let panelSerapatorColor: UIColor
    public let panelIconColor: UIColor
    public let panelHighlightedIconBackgroundColor: UIColor
    public let stickersBackgroundColor: UIColor
    public let stickersSectionTextColor: UIColor
    public let gifsBackgroundColor: UIColor
    
    public init(panelSerapatorColor: UIColor, panelIconColor: UIColor, panelHighlightedIconBackgroundColor: UIColor, stickersBackgroundColor: UIColor, stickersSectionTextColor: UIColor, gifsBackgroundColor: UIColor) {
        self.panelSerapatorColor = panelSerapatorColor
        self.panelIconColor = panelIconColor
        self.panelHighlightedIconBackgroundColor = panelHighlightedIconBackgroundColor
        self.stickersBackgroundColor = stickersBackgroundColor
        self.stickersSectionTextColor = stickersSectionTextColor
        self.gifsBackgroundColor = gifsBackgroundColor
    }
    
    public init(decoder: PostboxDecoder) throws {
        self.panelSerapatorColor = try parseColor(decoder, "panelSerapatorColor")
        self.panelIconColor = try parseColor(decoder, "panelIconColor")
        self.panelHighlightedIconBackgroundColor = try parseColor(decoder, "panelHighlightedIconBackgroundColor")
        self.stickersBackgroundColor = try parseColor(decoder, "stickersBackgroundColor")
        self.stickersSectionTextColor = try parseColor(decoder, "stickersSectionTextColor")
        self.gifsBackgroundColor = try parseColor(decoder, "gifsBackgroundColor")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        for child in Mirror(reflecting: self).children {
            if let label = child.label {
                if let value = child.value as? UIColor {
                    encoder.encodeInt32(Int32(bitPattern: value.argb), forKey: label)
                } else if let value = child.value as? PresentationThemeSwitch {
                    encoder.encodeObjectWithEncoder(value, encoder: { value.encode($0) }, forKey: label)
                } else {
                    assertionFailure()
                }
            }
        }
    }
}

public final class PresentationThemeInputButtonPanel {
    public let panelSerapatorColor: UIColor
    public let panelBackgroundColor: UIColor
    public let buttonFillColor: UIColor
    public let buttonStrokeColor: UIColor
    public let buttonHighlightedFillColor: UIColor
    public let buttonHighlightedStrokeColor: UIColor
    public let buttonTextColor: UIColor
    
    public init(panelSerapatorColor: UIColor, panelBackgroundColor: UIColor, buttonFillColor: UIColor, buttonStrokeColor: UIColor, buttonHighlightedFillColor: UIColor, buttonHighlightedStrokeColor: UIColor, buttonTextColor: UIColor) {
        self.panelSerapatorColor = panelSerapatorColor
        self.panelBackgroundColor = panelBackgroundColor
        self.buttonFillColor = buttonFillColor
        self.buttonStrokeColor = buttonStrokeColor
        self.buttonHighlightedFillColor = buttonHighlightedFillColor
        self.buttonHighlightedStrokeColor = buttonHighlightedStrokeColor
        self.buttonTextColor = buttonTextColor
    }
    
    public init(decoder: PostboxDecoder) throws {
        self.panelSerapatorColor = try parseColor(decoder, "panelSerapatorColor")
        self.panelBackgroundColor = try parseColor(decoder, "panelBackgroundColor")
        self.buttonFillColor = try parseColor(decoder, "buttonFillColor")
        self.buttonStrokeColor = try parseColor(decoder, "buttonStrokeColor")
        self.buttonHighlightedFillColor = try parseColor(decoder, "buttonHighlightedFillColor")
        self.buttonHighlightedStrokeColor = try parseColor(decoder, "buttonHighlightedStrokeColor")
        self.buttonTextColor = try parseColor(decoder, "buttonTextColor")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        for child in Mirror(reflecting: self).children {
            if let label = child.label {
                if let value = child.value as? UIColor {
                    encoder.encodeInt32(Int32(bitPattern: value.argb), forKey: label)
                } else if let value = child.value as? PresentationThemeSwitch {
                    encoder.encodeObjectWithEncoder(value, encoder: { value.encode($0) }, forKey: label)
                } else {
                    assertionFailure()
                }
            }
        }
    }
}

public final class PresentationThemeChatHistoryNavigation {
    public let fillColor: UIColor
    public let strokeColor: UIColor
    public let foregroundColor: UIColor
    public let badgeBackgroundColor: UIColor
    public let badgeTextColor: UIColor
    
    public init(fillColor: UIColor, strokeColor: UIColor, foregroundColor: UIColor, badgeBackgroundColor: UIColor, badgeTextColor: UIColor) {
        self.fillColor = fillColor
        self.strokeColor = strokeColor
        self.foregroundColor = foregroundColor
        self.badgeBackgroundColor = badgeBackgroundColor
        self.badgeTextColor = badgeTextColor
    }
    
    public init(decoder: PostboxDecoder) throws {
        self.fillColor = try parseColor(decoder, "fillColor")
        self.strokeColor = try parseColor(decoder, "strokeColor")
        self.foregroundColor = try parseColor(decoder, "foregroundColor")
        self.badgeBackgroundColor = try parseColor(decoder, "badgeBackgroundColor")
        self.badgeTextColor = try parseColor(decoder, "badgeTextColor")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        for child in Mirror(reflecting: self).children {
            if let label = child.label {
                if let value = child.value as? UIColor {
                    encoder.encodeInt32(Int32(bitPattern: value.argb), forKey: label)
                } else if let value = child.value as? PresentationThemeSwitch {
                    encoder.encodeObjectWithEncoder(value, encoder: { value.encode($0) }, forKey: label)
                } else if let value = child.value as? PresentationThemeKeyboardColor {
                    encoder.encodeInt32(value.rawValue, forKey: label)
                } else {
                    assertionFailure()
                }
            }
        }
    }
}

public final class PresentationThemeChat {
    public let bubble: PresentationThemeChatBubble
    public let serviceMessage: PresentationThemeServiceMessage
    public let inputPanel: PresentationThemeChatInputPanel
    public let inputMediaPanel: PresentationThemeInputMediaPanel
    public let inputButtonPanel: PresentationThemeInputButtonPanel
    public let historyNavigation: PresentationThemeChatHistoryNavigation
    
    public init(bubble: PresentationThemeChatBubble, serviceMessage: PresentationThemeServiceMessage, inputPanel: PresentationThemeChatInputPanel, inputMediaPanel: PresentationThemeInputMediaPanel, inputButtonPanel: PresentationThemeInputButtonPanel, historyNavigation: PresentationThemeChatHistoryNavigation) {
        self.bubble = bubble
        self.serviceMessage = serviceMessage
        self.inputPanel = inputPanel
        self.inputMediaPanel = inputMediaPanel
        self.inputButtonPanel = inputButtonPanel
        self.historyNavigation = historyNavigation
    }
    
    public init(decoder: PostboxDecoder) throws {
        if let bubble = (try? decoder.decodeObjectForKeyThrowing("bubble", decoder: { try PresentationThemeChatBubble(decoder: $0) })) as? PresentationThemeChatBubble {
            self.bubble = bubble
        } else {
            throw PresentationThemeParsingError.generic
        }
        if let serviceMessage = (try? decoder.decodeObjectForKeyThrowing("serviceMessage", decoder: { try PresentationThemeServiceMessage(decoder: $0) })) as? PresentationThemeServiceMessage {
            self.serviceMessage = serviceMessage
        } else {
            throw PresentationThemeParsingError.generic
        }
        if let inputPanel = (try? decoder.decodeObjectForKeyThrowing("inputPanel", decoder: { try PresentationThemeChatInputPanel(decoder: $0) })) as? PresentationThemeChatInputPanel {
            self.inputPanel = inputPanel
        } else {
            throw PresentationThemeParsingError.generic
        }
        if let inputMediaPanel = (try? decoder.decodeObjectForKeyThrowing("inputMediaPanel", decoder: { try PresentationThemeInputMediaPanel(decoder: $0) })) as? PresentationThemeInputMediaPanel {
            self.inputMediaPanel = inputMediaPanel
        } else {
            throw PresentationThemeParsingError.generic
        }
        if let inputButtonPanel = (try? decoder.decodeObjectForKeyThrowing("inputButtonPanel", decoder: { try PresentationThemeInputButtonPanel(decoder: $0) })) as? PresentationThemeInputButtonPanel {
            self.inputButtonPanel = inputButtonPanel
        } else {
            throw PresentationThemeParsingError.generic
        }
        if let historyNavigation = (try? decoder.decodeObjectForKeyThrowing("historyNavigation", decoder: { try PresentationThemeChatHistoryNavigation(decoder: $0) })) as? PresentationThemeChatHistoryNavigation {
            self.historyNavigation = historyNavigation
        } else {
            throw PresentationThemeParsingError.generic
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObjectWithEncoder(self.bubble, encoder: { self.bubble.encode($0) }, forKey: "bubble")
        encoder.encodeObjectWithEncoder(self.serviceMessage, encoder: { self.serviceMessage.encode($0) }, forKey: "serviceMessage")
        encoder.encodeObjectWithEncoder(self.inputPanel, encoder: { self.inputPanel.encode($0) }, forKey: "inputPanel")
        encoder.encodeObjectWithEncoder(self.inputMediaPanel, encoder: { self.inputMediaPanel.encode($0) }, forKey: "inputMediaPanel")
        encoder.encodeObjectWithEncoder(self.inputButtonPanel, encoder: { self.inputButtonPanel.encode($0) }, forKey: "inputButtonPanel")
        encoder.encodeObjectWithEncoder(self.historyNavigation, encoder: { self.historyNavigation.encode($0) }, forKey: "historyNavigation")
    }
}

public final class PresentationTheme: Equatable {
    public let rootController: PresentationThemeRootController
    public let list: PresentationThemeList
    public let chatList: PresentationThemeChatList
    public let chat: PresentationThemeChat
    public let actionSheet: PresentationThemeActionSheet
    
    public let resourceCache: PresentationsResourceCache = PresentationsResourceCache()
    
    public init(rootController: PresentationThemeRootController, list: PresentationThemeList, chatList: PresentationThemeChatList, chat: PresentationThemeChat, actionSheet: PresentationThemeActionSheet) {
        self.rootController = rootController
        self.list = list
        self.chatList = chatList
        self.chat = chat
        self.actionSheet = actionSheet
    }
    
    public init(decoder: PostboxDecoder) throws {
        if let rootController = (try? decoder.decodeObjectForKeyThrowing("rootController", decoder: { try PresentationThemeRootController(decoder: $0) })) as? PresentationThemeRootController {
            self.rootController = rootController
        } else {
            throw PresentationThemeParsingError.generic
        }
        if let list = (try? decoder.decodeObjectForKeyThrowing("list", decoder: { try PresentationThemeList(decoder: $0) })) as? PresentationThemeList {
            self.list = list
        } else {
            throw PresentationThemeParsingError.generic
        }
        if let chatList = (try? decoder.decodeObjectForKeyThrowing("chatList", decoder: { try PresentationThemeChatList(decoder: $0) })) as? PresentationThemeChatList {
            self.chatList = chatList
        } else {
            throw PresentationThemeParsingError.generic
        }
        if let chat = (try? decoder.decodeObjectForKeyThrowing("chat", decoder: { try PresentationThemeChat(decoder: $0) })) as? PresentationThemeChat {
            self.chat = chat
        } else {
            throw PresentationThemeParsingError.generic
        }
        if let actionSheet = (try? decoder.decodeObjectForKeyThrowing("actionSheet", decoder: { try PresentationThemeActionSheet(decoder: $0) })) as? PresentationThemeActionSheet {
            self.actionSheet = actionSheet
        } else {
            throw PresentationThemeParsingError.generic
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObjectWithEncoder(self.rootController, encoder: { self.rootController.encode($0) }, forKey: "list")
        encoder.encodeObjectWithEncoder(self.list, encoder: { self.list.encode($0) }, forKey: "list")
        encoder.encodeObjectWithEncoder(self.chatList, encoder: { self.chatList.encode($0) }, forKey: "chatList")
        encoder.encodeObjectWithEncoder(self.chat, encoder: { self.chat.encode($0) }, forKey: "chat")
        encoder.encodeObjectWithEncoder(self.actionSheet, encoder: { self.actionSheet.encode($0) }, forKey: "actionSheet")
    }
    
    public static func ==(lhs: PresentationTheme, rhs: PresentationTheme) -> Bool {
        return lhs === rhs
    }
    
    public func image(_ key: Int32, _ generate: (PresentationTheme) -> UIImage?) -> UIImage? {
        return self.resourceCache.image(key, self, generate)
    }
    
    public func object(_ key: Int32, _ generate: (PresentationTheme) -> AnyObject?) -> AnyObject? {
        return self.resourceCache.object(key, self, generate)
    }
}
