import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import SyncCore
import TelegramPresentationData
import TelegramUIPreferences
import DeviceAccess
import ItemListUI
import PresentationDataUtils
import AccountContext
import AlertUI
import PresentationDataUtils
import TelegramNotices
import NotificationSoundSelectionUI
import TelegramStringFormatting

private struct CounterTagSettings: OptionSet {
    var rawValue: Int32
    
    init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    init(summaryTags: PeerSummaryCounterTags) {
        var result = CounterTagSettings()
        if summaryTags.contains(.privateChat) {
            result.insert(.regularChatsAndPrivateGroups)
        }
        if summaryTags.contains(.channel) {
            result.insert(.channels)
        }
        if summaryTags.contains(.publicGroup) {
            result.insert(.publicGroups)
        }
        self = result
    }
    
    func toSumaryTags() -> PeerSummaryCounterTags {
        var result = PeerSummaryCounterTags()
        if self.contains(.regularChatsAndPrivateGroups) {
            result.insert(.privateChat)
            result.insert(.secretChat)
            result.insert(.bot)
            result.insert(.privateGroup)
        }
        if self.contains(.publicGroups) {
            result.insert(.publicGroup)
        }
        if self.contains(.channels) {
            result.insert(.channel)
        }
        return result
    }
    
    static let regularChatsAndPrivateGroups = CounterTagSettings(rawValue: 1 << 0)
    static let publicGroups = CounterTagSettings(rawValue: 1 << 1)
    static let channels = CounterTagSettings(rawValue: 1 << 2)
}

private final class NotificationsAndSoundsArguments {
    let context: AccountContext
    let presentController: (ViewController, ViewControllerPresentationArguments?) -> Void
    let pushController: (ViewController) -> Void
    let soundSelectionDisposable: MetaDisposable
    
    let authorizeNotifications: () -> Void
    let suppressWarning: () -> Void
    
    let updateMessageAlerts: (Bool) -> Void
    let updateMessagePreviews: (Bool) -> Void
    let updateMessageSound: (PeerMessageSound) -> Void
    
    let updateGroupAlerts: (Bool) -> Void
    let updateGroupPreviews: (Bool) -> Void
    let updateGroupSound: (PeerMessageSound) -> Void
    
    let updateChannelAlerts: (Bool) -> Void
    let updateChannelPreviews: (Bool) -> Void
    let updateChannelSound: (PeerMessageSound) -> Void
    
    let updateInAppSounds: (Bool) -> Void
    let updateInAppVibration: (Bool) -> Void
    let updateInAppPreviews: (Bool) -> Void
    
    let updateDisplayNameOnLockscreen: (Bool) -> Void
    let updateIncludeTag: (CounterTagSettings, Bool) -> Void
    let updateTotalUnreadCountCategory: (Bool) -> Void
    
    let updateJoinedNotifications: (Bool) -> Void
    
    let resetNotifications: () -> Void
    
    let updatedExceptionMode: (NotificationExceptionMode) -> Void
    
    let openAppSettings: () -> Void
    
    let updateNotificationsFromAllAccounts: (Bool) -> Void
    
    init(context: AccountContext, presentController: @escaping (ViewController, ViewControllerPresentationArguments?) -> Void, pushController: @escaping(ViewController)->Void, soundSelectionDisposable: MetaDisposable, authorizeNotifications: @escaping () -> Void, suppressWarning: @escaping () -> Void, updateMessageAlerts: @escaping (Bool) -> Void, updateMessagePreviews: @escaping (Bool) -> Void, updateMessageSound: @escaping (PeerMessageSound) -> Void, updateGroupAlerts: @escaping (Bool) -> Void, updateGroupPreviews: @escaping (Bool) -> Void, updateGroupSound: @escaping (PeerMessageSound) -> Void, updateChannelAlerts: @escaping (Bool) -> Void, updateChannelPreviews: @escaping (Bool) -> Void, updateChannelSound: @escaping (PeerMessageSound) -> Void, updateInAppSounds: @escaping (Bool) -> Void, updateInAppVibration: @escaping (Bool) -> Void, updateInAppPreviews: @escaping (Bool) -> Void, updateDisplayNameOnLockscreen: @escaping (Bool) -> Void, updateIncludeTag: @escaping (CounterTagSettings, Bool) -> Void, updateTotalUnreadCountCategory: @escaping (Bool) -> Void, resetNotifications: @escaping () -> Void, updatedExceptionMode: @escaping(NotificationExceptionMode) -> Void, openAppSettings: @escaping () -> Void, updateJoinedNotifications: @escaping (Bool) -> Void, updateNotificationsFromAllAccounts: @escaping (Bool) -> Void) {
        self.context = context
        self.presentController = presentController
        self.pushController = pushController
        self.soundSelectionDisposable = soundSelectionDisposable
        self.authorizeNotifications = authorizeNotifications
        self.suppressWarning = suppressWarning
        self.updateMessageAlerts = updateMessageAlerts
        self.updateMessagePreviews = updateMessagePreviews
        self.updateMessageSound = updateMessageSound
        self.updateGroupAlerts = updateGroupAlerts
        self.updateGroupPreviews = updateGroupPreviews
        self.updateGroupSound = updateGroupSound
        self.updateChannelAlerts = updateChannelAlerts
        self.updateChannelPreviews = updateChannelPreviews
        self.updateChannelSound = updateChannelSound
        self.updateInAppSounds = updateInAppSounds
        self.updateInAppVibration = updateInAppVibration
        self.updateInAppPreviews = updateInAppPreviews
        self.updateDisplayNameOnLockscreen = updateDisplayNameOnLockscreen
        self.updateIncludeTag = updateIncludeTag
        self.updateTotalUnreadCountCategory = updateTotalUnreadCountCategory
        self.resetNotifications = resetNotifications
        self.updatedExceptionMode = updatedExceptionMode
        self.openAppSettings = openAppSettings
        self.updateJoinedNotifications = updateJoinedNotifications
        self.updateNotificationsFromAllAccounts = updateNotificationsFromAllAccounts
    }
}

private enum NotificationsAndSoundsSection: Int32 {
    case accounts
    case permission
    case messages
    case groups
    case channels
    case inApp
    case displayNamesOnLockscreen
    case badge
    case joinedNotifications
    case reset
}

public enum NotificationsAndSoundsEntryTag: ItemListItemTag {
    case allAccounts
    case messageAlerts
    case messagePreviews
    case groupAlerts
    case groupPreviews
    case channelAlerts
    case channelPreviews
    case inAppSounds
    case inAppVibrate
    case inAppPreviews
    case displayNamesOnLockscreen
    case includePublicGroups
    case includeChannels
    case unreadCountCategory
    case joinedNotifications
    case reset
    
    public func isEqual(to other: ItemListItemTag) -> Bool {
        if let other = other as? NotificationsAndSoundsEntryTag, self == other {
            return true
        } else {
            return false
        }
    }
}

private enum NotificationsAndSoundsEntry: ItemListNodeEntry {
    case accountsHeader(PresentationTheme, String)
    case allAccounts(PresentationTheme, String, Bool)
    case accountsInfo(PresentationTheme, String)
    
    case permissionInfo(PresentationTheme, String, String, Bool)
    case permissionEnable(PresentationTheme, String)
    
    case messageHeader(PresentationTheme, String)
    case messageAlerts(PresentationTheme, String, Bool)
    case messagePreviews(PresentationTheme, String, Bool)
    case messageSound(PresentationTheme, String, String, PeerMessageSound)
    case userExceptions(PresentationTheme, PresentationStrings, String, NotificationExceptionMode)

    case messageNotice(PresentationTheme, String)
    
    case groupHeader(PresentationTheme, String)
    case groupAlerts(PresentationTheme, String, Bool)
    case groupPreviews(PresentationTheme, String, Bool)
    case groupSound(PresentationTheme, String, String, PeerMessageSound)
    case groupExceptions(PresentationTheme, PresentationStrings, String, NotificationExceptionMode)
    case groupNotice(PresentationTheme, String)
    
    case channelHeader(PresentationTheme, String)
    case channelAlerts(PresentationTheme, String, Bool)
    case channelPreviews(PresentationTheme, String, Bool)
    case channelSound(PresentationTheme, String, String, PeerMessageSound)
    case channelExceptions(PresentationTheme, PresentationStrings, String, NotificationExceptionMode)
    case channelNotice(PresentationTheme, String)
    
    case inAppHeader(PresentationTheme, String)
    case inAppSounds(PresentationTheme, String, Bool)
    case inAppVibrate(PresentationTheme, String, Bool)
    case inAppPreviews(PresentationTheme, String, Bool)
    
    case displayNamesOnLockscreen(PresentationTheme, String, Bool)
    case displayNamesOnLockscreenInfo(PresentationTheme, String)
    
    case badgeHeader(PresentationTheme, String)
    case includePublicGroups(PresentationTheme, String, Bool)
    case includeChannels(PresentationTheme, String, Bool)
    case unreadCountCategory(PresentationTheme, String, Bool)
    case unreadCountCategoryInfo(PresentationTheme, String)
    
    case joinedNotifications(PresentationTheme, String, Bool)
    case joinedNotificationsInfo(PresentationTheme, String)
    
    case reset(PresentationTheme, String)
    case resetNotice(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
            case .accountsHeader, .allAccounts, .accountsInfo:
                return NotificationsAndSoundsSection.accounts.rawValue
            case .permissionInfo, .permissionEnable:
                return NotificationsAndSoundsSection.permission.rawValue
            case .messageHeader, .messageAlerts, .messagePreviews, .messageSound, .messageNotice, .userExceptions:
                return NotificationsAndSoundsSection.messages.rawValue
            case .groupHeader, .groupAlerts, .groupPreviews, .groupSound, .groupNotice, .groupExceptions:
                return NotificationsAndSoundsSection.groups.rawValue
            case .channelHeader, .channelAlerts, .channelPreviews, .channelSound, .channelNotice, .channelExceptions:
                return NotificationsAndSoundsSection.channels.rawValue
            case .inAppHeader, .inAppSounds, .inAppVibrate, .inAppPreviews:
                return NotificationsAndSoundsSection.inApp.rawValue
            case .displayNamesOnLockscreen, .displayNamesOnLockscreenInfo:
                return NotificationsAndSoundsSection.displayNamesOnLockscreen.rawValue
            case .badgeHeader, .includePublicGroups, .includeChannels, .unreadCountCategory, .unreadCountCategoryInfo:
                return NotificationsAndSoundsSection.badge.rawValue
            case .joinedNotifications, .joinedNotificationsInfo:
                return NotificationsAndSoundsSection.joinedNotifications.rawValue
            case .reset, .resetNotice:
                return NotificationsAndSoundsSection.reset.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
            case .accountsHeader:
                return 0
            case .allAccounts:
                return 1
            case .accountsInfo:
                return 2
            case .permissionInfo:
                return 3
            case .permissionEnable:
                return 4
            case .messageHeader:
                return 5
            case .messageAlerts:
                return 6
            case .messagePreviews:
                return 7
            case .messageSound:
                return 8
            case .userExceptions:
                return 9
            case .messageNotice:
                return 10
            case .groupHeader:
                return 11
            case .groupAlerts:
                return 12
            case .groupPreviews:
                return 13
            case .groupSound:
                return 14
            case .groupExceptions:
                return 15
            case .groupNotice:
                return 16
            case .channelHeader:
                return 17
            case .channelAlerts:
                return 18
            case .channelPreviews:
                return 19
            case .channelSound:
                return 20
            case .channelExceptions:
                return 21
            case .channelNotice:
                return 22
            case .inAppHeader:
                return 23
            case .inAppSounds:
                return 24
            case .inAppVibrate:
                return 25
            case .inAppPreviews:
                return 26
            case .displayNamesOnLockscreen:
                return 27
            case .displayNamesOnLockscreenInfo:
                return 28
            case .badgeHeader:
                return 29
            case .includePublicGroups:
                return 31
            case .includeChannels:
                return 32
            case .unreadCountCategory:
                return 33
            case .unreadCountCategoryInfo:
                return 34
            case .joinedNotifications:
                return 35
            case .joinedNotificationsInfo:
                return 36
            case .reset:
                return 37
            case .resetNotice:
                return 38
        }
    }
    
    var tag: ItemListItemTag? {
        switch self {
            case .allAccounts:
                return NotificationsAndSoundsEntryTag.allAccounts
            case .messageAlerts:
                return NotificationsAndSoundsEntryTag.messageAlerts
            case .messagePreviews:
                return NotificationsAndSoundsEntryTag.messagePreviews
            case .groupAlerts:
                return NotificationsAndSoundsEntryTag.groupAlerts
            case .groupPreviews:
                return NotificationsAndSoundsEntryTag.groupPreviews
            case .channelAlerts:
                return NotificationsAndSoundsEntryTag.channelAlerts
            case .channelPreviews:
                return NotificationsAndSoundsEntryTag.channelPreviews
            case .inAppSounds:
                return NotificationsAndSoundsEntryTag.inAppSounds
            case .inAppVibrate:
                return NotificationsAndSoundsEntryTag.inAppVibrate
            case .inAppPreviews:
                return NotificationsAndSoundsEntryTag.inAppPreviews
            case .displayNamesOnLockscreen:
                return NotificationsAndSoundsEntryTag.displayNamesOnLockscreen
            case .includePublicGroups:
                return NotificationsAndSoundsEntryTag.includePublicGroups
            case .includeChannels:
                return NotificationsAndSoundsEntryTag.includeChannels
            case .unreadCountCategory:
                return NotificationsAndSoundsEntryTag.unreadCountCategory
            case .joinedNotifications:
                return NotificationsAndSoundsEntryTag.joinedNotifications
            case .reset:
                return NotificationsAndSoundsEntryTag.reset
            default:
                return nil
        }
    }
    
    static func ==(lhs: NotificationsAndSoundsEntry, rhs: NotificationsAndSoundsEntry) -> Bool {
        switch lhs {
            case let .accountsHeader(lhsTheme, lhsText):
                if case let .accountsHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .allAccounts(lhsTheme, lhsText, lhsValue):
                if case let .allAccounts(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .accountsInfo(lhsTheme, lhsText):
                if case let .accountsInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .permissionInfo(lhsTheme, lhsTitle, lhsText, lhsSuppressed):
                if case let .permissionInfo(rhsTheme, rhsTitle, rhsText, rhsSuppressed) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText, lhsSuppressed == rhsSuppressed {
                    return true
                } else {
                    return false
            }
            case let .permissionEnable(lhsTheme, lhsText):
                if case let .permissionEnable(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .messageHeader(lhsTheme, lhsText):
                if case let .messageHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .messageAlerts(lhsTheme, lhsText, lhsValue):
                if case let .messageAlerts(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .messagePreviews(lhsTheme, lhsText, lhsValue):
                if case let .messagePreviews(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .messageSound(lhsTheme, lhsText, lhsValue, lhsSound):
                if case let .messageSound(rhsTheme, rhsText, rhsValue, rhsSound) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue, lhsSound == rhsSound {
                    return true
                } else {
                    return false
                }
            case let .userExceptions(lhsTheme, lhsStrings, lhsText, lhsValue):
                if case let .userExceptions(rhsTheme, rhsStrings, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .messageNotice(lhsTheme, lhsText):
                if case let .messageNotice(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .groupHeader(lhsTheme, lhsText):
                if case let .groupHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .groupAlerts(lhsTheme, lhsText, lhsValue):
                if case let .groupAlerts(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .groupPreviews(lhsTheme, lhsText, lhsValue):
                if case let .groupPreviews(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .groupSound(lhsTheme, lhsText, lhsValue, lhsSound):
                if case let .groupSound(rhsTheme, rhsText, rhsValue, rhsSound) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue, lhsSound == rhsSound {
                    return true
                } else {
                    return false
                }
            case let .groupExceptions(lhsTheme, lhsStrings, lhsText, lhsValue):
                if case let .groupExceptions(rhsTheme, rhsStrings, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .groupNotice(lhsTheme, lhsText):
                if case let .groupNotice(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .channelHeader(lhsTheme, lhsText):
                if case let .channelHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .channelAlerts(lhsTheme, lhsText, lhsValue):
                if case let .channelAlerts(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .channelPreviews(lhsTheme, lhsText, lhsValue):
                if case let .channelPreviews(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .channelSound(lhsTheme, lhsText, lhsValue, lhsSound):
                if case let .channelSound(rhsTheme, rhsText, rhsValue, rhsSound) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue, lhsSound == rhsSound {
                    return true
                } else {
                    return false
                }
            case let .channelExceptions(lhsTheme, lhsStrings, lhsText, lhsValue):
                if case let .channelExceptions(rhsTheme, rhsStrings, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .channelNotice(lhsTheme, lhsText):
                if case let .channelNotice(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .inAppHeader(lhsTheme, lhsText):
                if case let .inAppHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .inAppSounds(lhsTheme, lhsText, lhsValue):
                if case let .inAppSounds(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .inAppVibrate(lhsTheme, lhsText, lhsValue):
                if case let .inAppVibrate(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .inAppPreviews(lhsTheme, lhsText, lhsValue):
                if case let .inAppPreviews(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .displayNamesOnLockscreen(lhsTheme, lhsText, lhsValue):
                if case let .displayNamesOnLockscreen(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .displayNamesOnLockscreenInfo(lhsTheme, lhsText):
                if case let .displayNamesOnLockscreenInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .badgeHeader(lhsTheme, lhsText):
                if case let .badgeHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .includePublicGroups(lhsTheme, lhsText, lhsValue):
                if case let .includePublicGroups(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .includeChannels(lhsTheme, lhsText, lhsValue):
                if case let .includeChannels(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .unreadCountCategory(lhsTheme, lhsText, lhsValue):
                if case let .unreadCountCategory(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .unreadCountCategoryInfo(lhsTheme, lhsText):
                if case let .unreadCountCategoryInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .joinedNotifications(lhsTheme, lhsText, lhsValue):
                if case let .joinedNotifications(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .joinedNotificationsInfo(lhsTheme, lhsText):
                if case let .joinedNotificationsInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .reset(lhsTheme, lhsText):
                if case let .reset(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .resetNotice(lhsTheme, lhsText):
                if case let .resetNotice(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: NotificationsAndSoundsEntry, rhs: NotificationsAndSoundsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! NotificationsAndSoundsArguments
        switch self {
            case let .accountsHeader(theme, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .allAccounts(theme, text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateNotificationsFromAllAccounts(updatedValue)
                }, tag: self.tag)
            case let .accountsInfo(theme, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            case let .permissionInfo(theme, title, text, suppressed):
                return ItemListInfoItem(presentationData: presentationData, title: title, text: .plain(text), style: .blocks, sectionId: self.section, closeAction: suppressed ? nil : {
                    arguments.suppressWarning()
                })
            case let .permissionEnable(theme, text):
                return ItemListActionItem(presentationData: presentationData, title: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    arguments.authorizeNotifications()
                })
            case let .messageHeader(theme, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .messageAlerts(theme, text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateMessageAlerts(updatedValue)
                }, tag: self.tag)
            case let .messagePreviews(theme, text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateMessagePreviews(updatedValue)
                }, tag: self.tag)
            case let .messageSound(theme, text, value, sound):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, action: {
                    let controller = notificationSoundSelectionController(context: arguments.context, isModal: true, currentSound: sound, defaultSound: nil, completion: { [weak arguments] value in
                        arguments?.updateMessageSound(value)
                    })
                    arguments.presentController(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                })
            case let .userExceptions(theme, strings, text, value):
                let label = value.settings.count > 0 ? strings.Notifications_Exceptions(Int32(value.settings.count)) : strings.Notification_Exceptions_Add
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: label, sectionId: self.section, style: .blocks, action: {
                    let controller = NotificationExceptionsController(context: arguments.context, mode: value, updatedMode: arguments.updatedExceptionMode)
                    arguments.pushController(controller)
                })
            case let .messageNotice(theme, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            case let .groupHeader(theme, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .groupAlerts(theme, text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateGroupAlerts(updatedValue)
                }, tag: self.tag)
            case let .groupPreviews(theme, text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateGroupPreviews(updatedValue)
                }, tag: self.tag)
            case let .groupSound(theme, text, value, sound):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, action: {
                    let controller = notificationSoundSelectionController(context: arguments.context, isModal: true, currentSound: sound, defaultSound: nil, completion: { [weak arguments] value in
                        arguments?.updateGroupSound(value)
                    })
                    arguments.presentController(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                })
            case let .groupExceptions(theme, strings, text, value):
                let label = value.settings.count > 0 ? strings.Notifications_Exceptions(Int32(value.settings.count)) : strings.Notification_Exceptions_Add
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: label, sectionId: self.section, style: .blocks, action: {
                    let controller = NotificationExceptionsController(context: arguments.context, mode: value, updatedMode: arguments.updatedExceptionMode)
                    arguments.pushController(controller)
                })
            case let .groupNotice(theme, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            case let .channelHeader(theme, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .channelAlerts(theme, text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateChannelAlerts(updatedValue)
                }, tag: self.tag)
            case let .channelPreviews(theme, text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateChannelPreviews(updatedValue)
                }, tag: self.tag)
            case let .channelSound(theme, text, value, sound):
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, action: {
                    let controller = notificationSoundSelectionController(context: arguments.context, isModal: true, currentSound: sound, defaultSound: nil, completion: { [weak arguments] value in
                        arguments?.updateChannelSound(value)
                    })
                    arguments.presentController(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                })
            case let .channelExceptions(theme, strings, text, value):
                let label = value.settings.count > 0 ? strings.Notifications_Exceptions(Int32(value.settings.count)) : strings.Notification_Exceptions_Add
                return ItemListDisclosureItem(presentationData: presentationData, title: text, label: label, sectionId: self.section, style: .blocks, action: {
                    let controller = NotificationExceptionsController(context: arguments.context, mode: value, updatedMode: arguments.updatedExceptionMode)
                    arguments.pushController(controller)
                })
            case let .channelNotice(theme, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            case let .inAppHeader(theme, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .inAppSounds(theme, text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateInAppSounds(updatedValue)
                }, tag: self.tag)
            case let .inAppVibrate(theme, text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateInAppVibration(updatedValue)
                }, tag: self.tag)
            case let .inAppPreviews(theme, text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateInAppPreviews(updatedValue)
                }, tag: self.tag)
            case let .displayNamesOnLockscreen(theme, text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateDisplayNameOnLockscreen(updatedValue)
                }, tag: self.tag)
            case let .displayNamesOnLockscreenInfo(theme, text):
                return ItemListTextItem(presentationData: presentationData, text: .markdown(text.replacingOccurrences(of: "]", with: "]()")), sectionId: self.section, linkAction: { _ in
                    arguments.openAppSettings()
                })
            case let .badgeHeader(theme, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .includePublicGroups(theme, text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateIncludeTag(.publicGroups, updatedValue)
                }, tag: self.tag)
            case let .includeChannels(theme, text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateIncludeTag(.channels, updatedValue)
                }, tag: self.tag)
            case let .unreadCountCategory(theme, text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateTotalUnreadCountCategory(updatedValue)
                }, tag: self.tag)
            case let .unreadCountCategoryInfo(theme, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            case let .joinedNotifications(theme, text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateJoinedNotifications(updatedValue)
                }, tag: self.tag)
            case let .joinedNotificationsInfo(theme, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            case let .reset(theme, text):
                return ItemListActionItem(presentationData: presentationData, title: text, kind: .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    arguments.resetNotifications()
                }, tag: self.tag)
            case let .resetNotice(theme, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private func filteredGlobalSound(_ sound: PeerMessageSound) -> PeerMessageSound {
    if case .default = sound {
        return .bundledModern(id: 0)
    } else {
        return sound
    }
}

private func notificationsAndSoundsEntries(authorizationStatus: AccessType, warningSuppressed: Bool, globalSettings: GlobalNotificationSettingsSet, inAppSettings: InAppNotificationSettings, exceptions: (users: NotificationExceptionMode, groups: NotificationExceptionMode, channels: NotificationExceptionMode), presentationData: PresentationData, hasMoreThanOneAccount: Bool) -> [NotificationsAndSoundsEntry] {
    var entries: [NotificationsAndSoundsEntry] = []
    
    if hasMoreThanOneAccount {
        entries.append(.accountsHeader(presentationData.theme, presentationData.strings.NotificationSettings_ShowNotificationsFromAccountsSection))
        entries.append(.allAccounts(presentationData.theme, presentationData.strings.NotificationSettings_ShowNotificationsAllAccounts, inAppSettings.displayNotificationsFromAllAccounts))
        entries.append(.accountsInfo(presentationData.theme, inAppSettings.displayNotificationsFromAllAccounts ? presentationData.strings.NotificationSettings_ShowNotificationsAllAccountsInfoOn : presentationData.strings.NotificationSettings_ShowNotificationsAllAccountsInfoOff))
    }
    
    if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
        let title: String
        let text: String
        if case .unreachable = authorizationStatus {
            title = presentationData.strings.Notifications_PermissionsUnreachableTitle
            text = presentationData.strings.Notifications_PermissionsUnreachableText
        } else {
            title = presentationData.strings.Notifications_PermissionsTitle
            text = presentationData.strings.Notifications_PermissionsText
        }
    
        switch (authorizationStatus, warningSuppressed) {
            case (.denied, _):
                entries.append(.permissionInfo(presentationData.theme, title, text, true))
                entries.append(.permissionEnable(presentationData.theme, presentationData.strings.Notifications_PermissionsAllowInSettings))
            case (.unreachable, false):
                entries.append(.permissionInfo(presentationData.theme, title, text, false))
                entries.append(.permissionEnable(presentationData.theme, presentationData.strings.Notifications_PermissionsOpenSettings))
            case (.notDetermined, _):
                entries.append(.permissionInfo(presentationData.theme, title, text, true))
                entries.append(.permissionEnable(presentationData.theme, presentationData.strings.Notifications_PermissionsAllow))
            default:
                break
        }
    }
    
    entries.append(.messageHeader(presentationData.theme, presentationData.strings.Notifications_MessageNotifications.uppercased()))
    entries.append(.messageAlerts(presentationData.theme, presentationData.strings.Notifications_MessageNotificationsAlert, globalSettings.privateChats.enabled))
    entries.append(.messagePreviews(presentationData.theme, presentationData.strings.Notifications_MessageNotificationsPreview, globalSettings.privateChats.displayPreviews))
    entries.append(.messageSound(presentationData.theme, presentationData.strings.Notifications_MessageNotificationsSound, localizedPeerNotificationSoundString(strings: presentationData.strings, sound: filteredGlobalSound(globalSettings.privateChats.sound)), filteredGlobalSound(globalSettings.privateChats.sound)))
    entries.append(.userExceptions(presentationData.theme, presentationData.strings, presentationData.strings.Notifications_MessageNotificationsExceptions, exceptions.users))
    entries.append(.messageNotice(presentationData.theme, presentationData.strings.Notifications_MessageNotificationsExceptionsHelp))
    
    entries.append(.groupHeader(presentationData.theme, presentationData.strings.Notifications_GroupNotifications.uppercased()))
    entries.append(.groupAlerts(presentationData.theme, presentationData.strings.Notifications_MessageNotificationsAlert, globalSettings.groupChats.enabled))
    entries.append(.groupPreviews(presentationData.theme, presentationData.strings.Notifications_MessageNotificationsPreview, globalSettings.groupChats.displayPreviews))
    entries.append(.groupSound(presentationData.theme, presentationData.strings.Notifications_MessageNotificationsSound, localizedPeerNotificationSoundString(strings: presentationData.strings, sound: filteredGlobalSound(globalSettings.groupChats.sound)), filteredGlobalSound(globalSettings.groupChats.sound)))
    entries.append(.groupExceptions(presentationData.theme, presentationData.strings, presentationData.strings.Notifications_MessageNotificationsExceptions, exceptions.groups))
    entries.append(.groupNotice(presentationData.theme, presentationData.strings.Notifications_GroupNotificationsExceptionsHelp))
    
    entries.append(.channelHeader(presentationData.theme, presentationData.strings.Notifications_ChannelNotifications.uppercased()))
    entries.append(.channelAlerts(presentationData.theme, presentationData.strings.Notifications_MessageNotificationsAlert, globalSettings.channels.enabled))
    entries.append(.channelPreviews(presentationData.theme, presentationData.strings.Notifications_MessageNotificationsPreview, globalSettings.channels.displayPreviews))
    entries.append(.channelSound(presentationData.theme, presentationData.strings.Notifications_MessageNotificationsSound, localizedPeerNotificationSoundString(strings: presentationData.strings, sound: filteredGlobalSound(globalSettings.channels.sound)), filteredGlobalSound(globalSettings.channels.sound)))
    entries.append(.channelExceptions(presentationData.theme, presentationData.strings, presentationData.strings.Notifications_MessageNotificationsExceptions, exceptions.channels))
    entries.append(.channelNotice(presentationData.theme, presentationData.strings.Notifications_ChannelNotificationsExceptionsHelp))
    
    entries.append(.inAppHeader(presentationData.theme, presentationData.strings.Notifications_InAppNotifications.uppercased()))
    entries.append(.inAppSounds(presentationData.theme, presentationData.strings.Notifications_InAppNotificationsSounds, inAppSettings.playSounds))
    entries.append(.inAppVibrate(presentationData.theme, presentationData.strings.Notifications_InAppNotificationsVibrate, inAppSettings.vibrate))
    entries.append(.inAppPreviews(presentationData.theme, presentationData.strings.Notifications_InAppNotificationsPreview, inAppSettings.displayPreviews))
    
    entries.append(.displayNamesOnLockscreen(presentationData.theme, presentationData.strings.Notifications_DisplayNamesOnLockScreen, inAppSettings.displayNameOnLockscreen))
    entries.append(.displayNamesOnLockscreenInfo(presentationData.theme, presentationData.strings.Notifications_DisplayNamesOnLockScreenInfoWithLink))
    
    entries.append(.badgeHeader(presentationData.theme, presentationData.strings.Notifications_Badge.uppercased()))
    
    let counterTagSettings = CounterTagSettings(summaryTags: inAppSettings.totalUnreadCountIncludeTags)
    
    entries.append(.includePublicGroups(presentationData.theme, presentationData.strings.Notifications_Badge_IncludePublicGroups, counterTagSettings.contains(.publicGroups)))
    entries.append(.includeChannels(presentationData.theme, presentationData.strings.Notifications_Badge_IncludeChannels, counterTagSettings.contains(.channels)))
    entries.append(.unreadCountCategory(presentationData.theme, presentationData.strings.Notifications_Badge_CountUnreadMessages, inAppSettings.totalUnreadCountDisplayCategory == .messages))
    entries.append(.unreadCountCategoryInfo(presentationData.theme, inAppSettings.totalUnreadCountDisplayCategory == .chats ? presentationData.strings.Notifications_Badge_CountUnreadMessages_InfoOff : presentationData.strings.Notifications_Badge_CountUnreadMessages_InfoOn))
    entries.append(.joinedNotifications(presentationData.theme, presentationData.strings.NotificationSettings_ContactJoined, globalSettings.contactsJoined))
    entries.append(.joinedNotificationsInfo(presentationData.theme, presentationData.strings.NotificationSettings_ContactJoinedInfo))
    
    entries.append(.reset(presentationData.theme, presentationData.strings.Notifications_ResetAllNotifications))
    entries.append(.resetNotice(presentationData.theme, presentationData.strings.Notifications_ResetAllNotificationsHelp))
    
    return entries
}

public func notificationsAndSoundsController(context: AccountContext, exceptionsList: NotificationExceptionsList?, focusOnItemTag: NotificationsAndSoundsEntryTag? = nil) -> ViewController {
    var presentControllerImpl: ((ViewController, ViewControllerPresentationArguments?) -> Void)?
    var pushControllerImpl: ((ViewController) -> Void)?
    
    let notificationExceptions: Promise<(users: NotificationExceptionMode, groups: NotificationExceptionMode, channels: NotificationExceptionMode)> = Promise()
    
    let updateNotificationExceptions:((users: NotificationExceptionMode, groups: NotificationExceptionMode, channels: NotificationExceptionMode)) -> Void = { value in
        notificationExceptions.set(.single(value))
    }
    
    let arguments = NotificationsAndSoundsArguments(context: context, presentController: { controller, arguments in
        presentControllerImpl?(controller, arguments)
    }, pushController: { controller in
        pushControllerImpl?(controller)
    }, soundSelectionDisposable: MetaDisposable(), authorizeNotifications: {
        let _ = (DeviceAccess.authorizationStatus(applicationInForeground: context.sharedContext.applicationBindings.applicationInForeground, subject: .notifications)
        |> take(1)
        |> deliverOnMainQueue).start(next: { status in
            switch status {
                case .notDetermined:
                    DeviceAccess.authorizeAccess(to: .notifications, registerForNotifications: { result in
                        context.sharedContext.applicationBindings.registerForNotifications(result)
                    })
                case .denied, .restricted:
                    context.sharedContext.applicationBindings.openSettings()
                case .unreachable:
                    ApplicationSpecificNotice.setPermissionWarning(accountManager: context.sharedContext.accountManager, permission: .notifications, value: Int32(Date().timeIntervalSince1970))
                    context.sharedContext.applicationBindings.openSettings()
                default:
                    break
            }
        })
    }, suppressWarning: {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        presentControllerImpl?(textAlertController(context: context, title: presentationData.strings.Notifications_PermissionsSuppressWarningTitle, text: presentationData.strings.Notifications_PermissionsSuppressWarningText, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Notifications_PermissionsKeepDisabled, action: {
            ApplicationSpecificNotice.setPermissionWarning(accountManager: context.sharedContext.accountManager, permission: .notifications, value: Int32(Date().timeIntervalSince1970))
        }), TextAlertAction(type: .defaultAction, title: presentationData.strings.Notifications_PermissionsEnable, action: {
            context.sharedContext.applicationBindings.openSettings()
        })]), nil)
    }, updateMessageAlerts: { value in
        let _ = updateGlobalNotificationSettingsInteractively(postbox: context.account.postbox, { settings in
            var settings = settings
            settings.privateChats.enabled = value
            return settings
        }).start()
    }, updateMessagePreviews: { value in
        let _ = updateGlobalNotificationSettingsInteractively(postbox: context.account.postbox, { settings in
            var settings = settings
            settings.privateChats.displayPreviews = value
            return settings
        }).start()
    }, updateMessageSound: { value in
        let _ = updateGlobalNotificationSettingsInteractively(postbox: context.account.postbox, { settings in
            var settings = settings
            settings.privateChats.sound = value
            return settings
        }).start()
    }, updateGroupAlerts: { value in
        let _ = updateGlobalNotificationSettingsInteractively(postbox: context.account.postbox, { settings in
            var settings = settings
            settings.groupChats.enabled = value
            return settings
        }).start()
    }, updateGroupPreviews: { value in
        let _ = updateGlobalNotificationSettingsInteractively(postbox: context.account.postbox, { settings in
            var settings = settings
            settings.groupChats.displayPreviews = value
            return settings
        }).start()
    }, updateGroupSound: {value in
        let _ = updateGlobalNotificationSettingsInteractively(postbox: context.account.postbox, { settings in
            var settings = settings
            settings.groupChats.sound = value
            return settings
        }).start()
    }, updateChannelAlerts: { value in
        let _ = updateGlobalNotificationSettingsInteractively(postbox: context.account.postbox, { settings in
            var settings = settings
            settings.channels.enabled = value
            return settings
        }).start()
    }, updateChannelPreviews: { value in
        let _ = updateGlobalNotificationSettingsInteractively(postbox: context.account.postbox, { settings in
            var settings = settings
            settings.channels.displayPreviews = value
            return settings
        }).start()
    }, updateChannelSound: {value in
        let _ = updateGlobalNotificationSettingsInteractively(postbox: context.account.postbox, { settings in
            var settings = settings
            settings.channels.sound = value
            return settings
        }).start()
    }, updateInAppSounds: { value in
        let _ = updateInAppNotificationSettingsInteractively(accountManager: context.sharedContext.accountManager, { settings in
            var settings = settings
            settings.playSounds = value
            return settings
        }).start()
    }, updateInAppVibration: { value in
        let _ = updateInAppNotificationSettingsInteractively(accountManager: context.sharedContext.accountManager, { settings in
            var settings = settings
            settings.vibrate = value
            return settings
        }).start()
    }, updateInAppPreviews: { value in
        let _ = updateInAppNotificationSettingsInteractively(accountManager: context.sharedContext.accountManager, { settings in
            var settings = settings
            settings.displayPreviews = value
            return settings
        }).start()
    }, updateDisplayNameOnLockscreen: { value in
        let _ = updateInAppNotificationSettingsInteractively(accountManager: context.sharedContext.accountManager, { settings in
            var settings = settings
            settings.displayNameOnLockscreen = value
            return settings
        }).start()
    }, updateIncludeTag: { tag, value in
        let _ = updateInAppNotificationSettingsInteractively(accountManager: context.sharedContext.accountManager, { settings in
            var currentSettings = CounterTagSettings(summaryTags: settings.totalUnreadCountIncludeTags)
            if !value {
                currentSettings.remove(tag)
            } else {
                currentSettings.insert(tag)
            }
            var settings = settings
            settings.totalUnreadCountIncludeTags = currentSettings.toSumaryTags()
            return settings
        }).start()
    }, updateTotalUnreadCountCategory: { value in
        let _ = updateInAppNotificationSettingsInteractively(accountManager: context.sharedContext.accountManager, { settings in
            var settings = settings
            settings.totalUnreadCountDisplayCategory = value ? .messages : .chats
            return settings
        }).start()
    }, resetNotifications: {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let actionSheet = ActionSheetController(presentationData: presentationData)
        actionSheet.setItemGroups([ActionSheetItemGroup(items: [
            ActionSheetButtonItem(title: presentationData.strings.Notifications_Reset, color: .destructive, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
                
                let modifyPeers = context.account.postbox.transaction { transaction -> Void in
                    transaction.resetAllPeerNotificationSettings(TelegramPeerNotificationSettings.defaultSettings)
                }
                let updateGlobal = updateGlobalNotificationSettingsInteractively(postbox: context.account.postbox, { _ in
                    return GlobalNotificationSettingsSet.defaultSettings
                })
                let reset = resetPeerNotificationSettings(network: context.account.network)
                let signal = combineLatest(modifyPeers, updateGlobal, reset)
                let _ = signal.start()
            })
        ]), ActionSheetItemGroup(items: [
            ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
            })
        ])])
        presentControllerImpl?(actionSheet, nil)
    }, updatedExceptionMode: { mode in
        _ = (notificationExceptions.get() |> take(1) |> deliverOnMainQueue).start(next: { (users, groups, channels) in
            switch mode {
                case .users:
                    updateNotificationExceptions((mode, groups, channels))
                case .groups:
                    updateNotificationExceptions((users, mode, channels))
                case .channels:
                    updateNotificationExceptions((users, groups, mode))
            }
        })
    }, openAppSettings: {
        context.sharedContext.applicationBindings.openSettings()
    }, updateJoinedNotifications: { value in
        let _ = updateGlobalNotificationSettingsInteractively(postbox: context.account.postbox, { settings in
            var settings = settings
            settings.contactsJoined = value
            return settings
        }).start()
    }, updateNotificationsFromAllAccounts: { value in
        let _ = updateInAppNotificationSettingsInteractively(accountManager: context.sharedContext.accountManager, { settings in
            var settings = settings
            settings.displayNotificationsFromAllAccounts = value
            return settings
        }).start()
    })
    
    let sharedData = context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.inAppNotificationSettings])
    let preferences = context.account.postbox.preferencesView(keys: [PreferencesKeys.globalNotifications])
    
    let exceptionsSignal = Signal<NotificationExceptionsList?, NoError>.single(exceptionsList) |> then(notificationExceptionsList(postbox: context.account.postbox, network: context.account.network) |> map(Optional.init))
    
    notificationExceptions.set(exceptionsSignal |> map { list -> (NotificationExceptionMode, NotificationExceptionMode, NotificationExceptionMode) in
        var users:[PeerId : NotificationExceptionWrapper] = [:]
        var groups: [PeerId : NotificationExceptionWrapper] = [:]
        var channels:[PeerId : NotificationExceptionWrapper] = [:]
        if let list = list {
            for (key, value) in list.settings {
                if  let peer = list.peers[key], !peer.debugDisplayTitle.isEmpty, peer.id != context.account.peerId {
                    switch value.muteState {
                    case .default:
                        switch value.messageSound {
                        case .default:
                            break
                        default:
                            switch key.namespace {
                            case Namespaces.Peer.CloudUser:
                                users[key] = NotificationExceptionWrapper(settings: value, peer: peer)
                            default:
                                if let peer = peer as? TelegramChannel, case .broadcast = peer.info {
                                    channels[key] = NotificationExceptionWrapper(settings: value, peer: peer)
                                } else {
                                    groups[key] = NotificationExceptionWrapper(settings: value, peer: peer)
                                }
                            }
                        }
                    default:
                        switch key.namespace {
                        case Namespaces.Peer.CloudUser:
                            users[key] = NotificationExceptionWrapper(settings: value, peer: peer)
                        default:
                            if let peer = peer as? TelegramChannel, case .broadcast = peer.info {
                                channels[key] = NotificationExceptionWrapper(settings: value, peer: peer)
                            } else {
                                groups[key] = NotificationExceptionWrapper(settings: value, peer: peer)
                            }
                        }
                    }
                }
            }
        }
        
        return (.users(users), .groups(groups), .channels(channels))
    })
    
    let notificationsWarningSuppressed = Promise<Bool>(true)
    if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
        notificationsWarningSuppressed.set(.single(true)
        |> then(
            context.sharedContext.accountManager.noticeEntry(key: ApplicationSpecificNotice.permissionWarningKey(permission: .notifications)!)
            |> map { noticeView -> Bool in
                let timestamp = noticeView.value.flatMap({ ApplicationSpecificNotice.getTimestampValue($0) })
                if let timestamp = timestamp, timestamp > 0 {
                    return true
                } else {
                    return false
                }
            }))
    }
    
    let hasMoreThanOneAccount = context.sharedContext.activeAccounts
    |> map { _, accounts, _ -> Bool in
        return accounts.count > 1
    }
    |> distinctUntilChanged
    
    let signal = combineLatest(context.sharedContext.presentationData, sharedData, preferences, notificationExceptions.get(), DeviceAccess.authorizationStatus(applicationInForeground: context.sharedContext.applicationBindings.applicationInForeground, subject: .notifications), notificationsWarningSuppressed.get(), hasMoreThanOneAccount)
        |> map { presentationData, sharedData, view, exceptions, authorizationStatus, warningSuppressed, hasMoreThanOneAccount -> (ItemListControllerState, (ItemListNodeState, Any)) in
            
            let viewSettings: GlobalNotificationSettingsSet
            if let settings = view.values[PreferencesKeys.globalNotifications] as? GlobalNotificationSettings {
                viewSettings = settings.effective
            } else {
                viewSettings = GlobalNotificationSettingsSet.defaultSettings
            }
            
            let inAppSettings: InAppNotificationSettings
            if let settings = sharedData.entries[ApplicationSpecificSharedDataKeys.inAppNotificationSettings] as? InAppNotificationSettings {
                inAppSettings = settings
            } else {
                inAppSettings = InAppNotificationSettings.defaultSettings
            }
            
            let entries = notificationsAndSoundsEntries(authorizationStatus: authorizationStatus, warningSuppressed: warningSuppressed, globalSettings: viewSettings, inAppSettings: inAppSettings, exceptions: exceptions, presentationData: presentationData, hasMoreThanOneAccount: hasMoreThanOneAccount)
            
            var index = 0
            var scrollToItem: ListViewScrollToItem?
            if let focusOnItemTag = focusOnItemTag {
                for entry in entries {
                    if entry.tag?.isEqual(to: focusOnItemTag) ?? false {
                        scrollToItem = ListViewScrollToItem(index: index, position: .top(0.0), animated: false, curve: .Default(duration: 0.0), directionHint: .Up)
                    }
                    index += 1
                }
            }
            
            let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.Notifications_Title), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
            let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, ensureVisibleItemTag: focusOnItemTag, initialScrollToItem: scrollToItem)
            
            return (controllerState, (listState, arguments))
    }
    
    let controller = ItemListController(context: context, state: signal)
    presentControllerImpl = { [weak controller] c, a in
        controller?.present(c, in: .window(.root), with: a)
    }
    pushControllerImpl = { [weak controller] c in
        (controller?.navigationController as? NavigationController)?.pushViewController(c)
    }
    return controller
}
