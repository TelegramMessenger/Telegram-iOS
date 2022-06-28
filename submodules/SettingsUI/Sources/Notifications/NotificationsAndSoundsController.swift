import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
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
        if summaryTags.contains(.contact) {
            result.insert(.regularChatsAndGroups)
        }
        if summaryTags.contains(.channel) {
            result.insert(.channels)
        }
        self = result
    }
    
    func toSumaryTags() -> PeerSummaryCounterTags {
        var result = PeerSummaryCounterTags()
        if self.contains(.regularChatsAndGroups) {
            result.insert(.contact)
            result.insert(.nonContact)
            result.insert(.bot)
            result.insert(.group)
        }
        if self.contains(.channels) {
            result.insert(.channel)
        }
        return result
    }
    
    static let regularChatsAndGroups = CounterTagSettings(rawValue: 1 << 0)
    static let channels = CounterTagSettings(rawValue: 1 << 1)
}

private final class NotificationsAndSoundsArguments {
    let context: AccountContext
    let presentController: (ViewController, ViewControllerPresentationArguments?) -> Void
    let pushController: (ViewController) -> Void
    let soundSelectionDisposable: MetaDisposable
    
    let authorizeNotifications: () -> Void
    let suppressWarning: () -> Void
    
    let openPeerCategory: (NotificationsPeerCategory) -> Void
        
    let updateInAppSounds: (Bool) -> Void
    let updateInAppVibration: (Bool) -> Void
    let updateInAppPreviews: (Bool) -> Void
    
    let updateDisplayNameOnLockscreen: (Bool) -> Void
    let updateIncludeTag: (CounterTagSettings, Bool) -> Void
    let updateTotalUnreadCountCategory: (Bool) -> Void
    
    let updateJoinedNotifications: (Bool) -> Void
    
    let resetNotifications: () -> Void
        
    let openAppSettings: () -> Void
    
    let updateNotificationsFromAllAccounts: (Bool) -> Void
    
    init(context: AccountContext, presentController: @escaping (ViewController, ViewControllerPresentationArguments?) -> Void, pushController: @escaping(ViewController)->Void, soundSelectionDisposable: MetaDisposable, authorizeNotifications: @escaping () -> Void, suppressWarning: @escaping () -> Void, openPeerCategory: @escaping (NotificationsPeerCategory) -> Void, updateInAppSounds: @escaping (Bool) -> Void, updateInAppVibration: @escaping (Bool) -> Void, updateInAppPreviews: @escaping (Bool) -> Void, updateDisplayNameOnLockscreen: @escaping (Bool) -> Void, updateIncludeTag: @escaping (CounterTagSettings, Bool) -> Void, updateTotalUnreadCountCategory: @escaping (Bool) -> Void, resetNotifications: @escaping () -> Void, openAppSettings: @escaping () -> Void, updateJoinedNotifications: @escaping (Bool) -> Void, updateNotificationsFromAllAccounts: @escaping (Bool) -> Void) {
        self.context = context
        self.presentController = presentController
        self.pushController = pushController
        self.soundSelectionDisposable = soundSelectionDisposable
        self.authorizeNotifications = authorizeNotifications
        self.suppressWarning = suppressWarning
        self.openPeerCategory = openPeerCategory
        self.updateInAppSounds = updateInAppSounds
        self.updateInAppVibration = updateInAppVibration
        self.updateInAppPreviews = updateInAppPreviews
        self.updateDisplayNameOnLockscreen = updateDisplayNameOnLockscreen
        self.updateIncludeTag = updateIncludeTag
        self.updateTotalUnreadCountCategory = updateTotalUnreadCountCategory
        self.resetNotifications = resetNotifications
        self.openAppSettings = openAppSettings
        self.updateJoinedNotifications = updateJoinedNotifications
        self.updateNotificationsFromAllAccounts = updateNotificationsFromAllAccounts
    }
}

private enum NotificationsAndSoundsSection: Int32 {
    case accounts
    case permission
    case categories
    case inApp
    case displayNamesOnLockscreen
    case badge
    case joinedNotifications
    case reset
}

public enum NotificationsAndSoundsEntryTag: ItemListItemTag {
    case allAccounts
    case inAppSounds
    case inAppVibrate
    case inAppPreviews
    case displayNamesOnLockscreen
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
    
    case categoriesHeader(PresentationTheme, String)
    case privateChats(PresentationTheme, String, String, String)
    case groupChats(PresentationTheme, String, String, String)
    case channels(PresentationTheme, String, String, String)
    
    case inAppHeader(PresentationTheme, String)
    case inAppSounds(PresentationTheme, String, Bool)
    case inAppVibrate(PresentationTheme, String, Bool)
    case inAppPreviews(PresentationTheme, String, Bool)
    
    case displayNamesOnLockscreen(PresentationTheme, String, Bool)
    case displayNamesOnLockscreenInfo(PresentationTheme, String)
    
    case badgeHeader(PresentationTheme, String)
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
            case .categoriesHeader, .privateChats, .groupChats, .channels:
                return NotificationsAndSoundsSection.categories.rawValue
            case .inAppHeader, .inAppSounds, .inAppVibrate, .inAppPreviews:
                return NotificationsAndSoundsSection.inApp.rawValue
            case .displayNamesOnLockscreen, .displayNamesOnLockscreenInfo:
                return NotificationsAndSoundsSection.displayNamesOnLockscreen.rawValue
            case .badgeHeader, .includeChannels, .unreadCountCategory, .unreadCountCategoryInfo:
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
            case .categoriesHeader:
                return 5
            case .privateChats:
                return 6
            case .groupChats:
                return 7
            case .channels:
                return 8
            case .inAppHeader:
                return 14
            case .inAppSounds:
                return 15
            case .inAppVibrate:
                return 16
            case .inAppPreviews:
                return 17
            case .displayNamesOnLockscreen:
                return 18
            case .displayNamesOnLockscreenInfo:
                return 19
            case .badgeHeader:
                return 20
            case .includeChannels:
                return 21
            case .unreadCountCategory:
                return 22
            case .unreadCountCategoryInfo:
                return 23
            case .joinedNotifications:
                return 24
            case .joinedNotificationsInfo:
                return 25
            case .reset:
                return 26
            case .resetNotice:
                return 27
        }
    }
    
    var tag: ItemListItemTag? {
        switch self {
            case .allAccounts:
                return NotificationsAndSoundsEntryTag.allAccounts
            case .inAppSounds:
                return NotificationsAndSoundsEntryTag.inAppSounds
            case .inAppVibrate:
                return NotificationsAndSoundsEntryTag.inAppVibrate
            case .inAppPreviews:
                return NotificationsAndSoundsEntryTag.inAppPreviews
            case .displayNamesOnLockscreen:
                return NotificationsAndSoundsEntryTag.displayNamesOnLockscreen
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
            case let .categoriesHeader(lhsTheme, lhsText):
                if case let .categoriesHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .privateChats(lhsTheme, lhsTitle, lhsSubtitle, lhsLabel):
                if case let .privateChats(rhsTheme, rhsTitle, rhsSubtitle, rhsLabel) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsSubtitle == rhsSubtitle, lhsLabel == rhsLabel {
                    return true
                } else {
                    return false
                }
            case let .groupChats(lhsTheme, lhsTitle, lhsSubtitle, lhsLabel):
                if case let .groupChats(rhsTheme, rhsTitle, rhsSubtitle, rhsLabel) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsSubtitle == rhsSubtitle, lhsLabel == rhsLabel {
                    return true
                } else {
                    return false
                }
            case let .channels(lhsTheme, lhsTitle, lhsSubtitle, lhsLabel):
                if case let .channels(rhsTheme, rhsTitle, rhsSubtitle, rhsLabel) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsSubtitle == rhsSubtitle, lhsLabel == rhsLabel {
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
            case let .accountsHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .allAccounts(_, text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateNotificationsFromAllAccounts(updatedValue)
                }, tag: self.tag)
            case let .accountsInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            case let .permissionInfo(_, title, text, suppressed):
                return ItemListInfoItem(presentationData: presentationData, title: title, text: .plain(text), style: .blocks, sectionId: self.section, closeAction: suppressed ? nil : {
                    arguments.suppressWarning()
                })
            case let .permissionEnable(_, text):
                return ItemListActionItem(presentationData: presentationData, title: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    arguments.authorizeNotifications()
                })
            case let .categoriesHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .privateChats(_, title, subtitle, label):
                return NotificationsCategoryItemListItem(presentationData: presentationData, icon: UIImage(bundleImageName: "Settings/Menu/EditProfile"), title: title, subtitle: subtitle, label: label, sectionId: self.section, style: .blocks, action: {
                    arguments.openPeerCategory(.privateChat)
                })
            case let .groupChats(_, title, subtitle, label):
                return NotificationsCategoryItemListItem(presentationData: presentationData, icon: UIImage(bundleImageName: "Settings/Menu/GroupChats"), title: title, subtitle: subtitle, label: label, sectionId: self.section, style: .blocks, action: {
                    arguments.openPeerCategory(.group)
                })
            case let .channels(_, title, subtitle, label):
                return NotificationsCategoryItemListItem(presentationData: presentationData, icon: UIImage(bundleImageName: "Settings/Menu/Channels"), title: title, subtitle: subtitle, label: label, sectionId: self.section, style: .blocks, action: {
                    arguments.openPeerCategory(.channel)
                })
            case let .inAppHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .inAppSounds(_, text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateInAppSounds(updatedValue)
                }, tag: self.tag)
            case let .inAppVibrate(_, text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateInAppVibration(updatedValue)
                }, tag: self.tag)
            case let .inAppPreviews(_, text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateInAppPreviews(updatedValue)
                }, tag: self.tag)
            case let .displayNamesOnLockscreen(_, text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateDisplayNameOnLockscreen(updatedValue)
                }, tag: self.tag)
            case let .displayNamesOnLockscreenInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .markdown(text.replacingOccurrences(of: "]", with: "]()")), sectionId: self.section, linkAction: { _ in
                    arguments.openAppSettings()
                })
            case let .badgeHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .includeChannels(_, text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateIncludeTag(.channels, updatedValue)
                }, tag: self.tag)
            case let .unreadCountCategory(_, text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateTotalUnreadCountCategory(updatedValue)
                }, tag: self.tag)
            case let .unreadCountCategoryInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            case let .joinedNotifications(_, text, value):
                return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateJoinedNotifications(updatedValue)
                }, tag: self.tag)
            case let .joinedNotificationsInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            case let .reset(_, text):
                return ItemListActionItem(presentationData: presentationData, title: text, kind: .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    arguments.resetNotifications()
                }, tag: self.tag)
            case let .resetNotice(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private func filteredGlobalSound(_ sound: PeerMessageSound) -> PeerMessageSound {
    if case .default = sound {
        return defaultCloudPeerNotificationSound
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
    
    entries.append(.categoriesHeader(presentationData.theme, presentationData.strings.Notifications_MessageNotifications.uppercased()))
    entries.append(.privateChats(presentationData.theme, presentationData.strings.Notifications_PrivateChats, !exceptions.users.isEmpty ? presentationData.strings.Notifications_CategoryExceptions(Int32(exceptions.users.peerIds.count)) : "", globalSettings.privateChats.enabled ? presentationData.strings.Notifications_On : presentationData.strings.Notifications_Off))
    entries.append(.groupChats(presentationData.theme, presentationData.strings.Notifications_GroupChats, !exceptions.groups.isEmpty ? presentationData.strings.Notifications_CategoryExceptions(Int32(exceptions.groups.peerIds.count)) : "", globalSettings.groupChats.enabled ? presentationData.strings.Notifications_On : presentationData.strings.Notifications_Off))
    entries.append(.channels(presentationData.theme, presentationData.strings.Notifications_Channels, !exceptions.channels.isEmpty ? presentationData.strings.Notifications_CategoryExceptions(Int32(exceptions.channels.peerIds.count)) : "", globalSettings.channels.enabled ? presentationData.strings.Notifications_On : presentationData.strings.Notifications_Off))
    
    entries.append(.inAppHeader(presentationData.theme, presentationData.strings.Notifications_InAppNotifications.uppercased()))
    entries.append(.inAppSounds(presentationData.theme, presentationData.strings.Notifications_InAppNotificationsSounds, inAppSettings.playSounds))
    entries.append(.inAppVibrate(presentationData.theme, presentationData.strings.Notifications_InAppNotificationsVibrate, inAppSettings.vibrate))
    entries.append(.inAppPreviews(presentationData.theme, presentationData.strings.Notifications_InAppNotificationsPreview, inAppSettings.displayPreviews))
    
    entries.append(.displayNamesOnLockscreen(presentationData.theme, presentationData.strings.Notifications_DisplayNamesOnLockScreen, inAppSettings.displayNameOnLockscreen))
    entries.append(.displayNamesOnLockscreenInfo(presentationData.theme, presentationData.strings.Notifications_DisplayNamesOnLockScreenInfoWithLink))
    
    entries.append(.badgeHeader(presentationData.theme, presentationData.strings.Notifications_Badge.uppercased()))
    
    let counterTagSettings = CounterTagSettings(summaryTags: inAppSettings.totalUnreadCountIncludeTags)
    
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
    }, openPeerCategory: { category in
        _ = (notificationExceptions.get() |> take(1) |> deliverOnMainQueue).start(next: { (users, groups, channels) in
            let mode: NotificationExceptionMode
            switch category {
                case .privateChat:
                    mode = users
                case .group:
                    mode = groups
                case .channel:
                    mode = channels
            }
            pushControllerImpl?(notificationsPeerCategoryController(context: context, category: category, mode: mode, updatedMode: { mode in
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
            }, focusOnItemTag: nil))
        })
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
            ActionSheetTextItem(title: presentationData.strings.Notifications_ResetAllNotificationsText),
            ActionSheetButtonItem(title: presentationData.strings.Notifications_Reset, color: .destructive, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
                
                let modifyPeers = context.engine.peers.resetAllPeerNotificationSettings()
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
    
    let exceptionsSignal = Signal<NotificationExceptionsList?, NoError>.single(exceptionsList) |> then(context.engine.peers.notificationExceptionsList() |> map(Optional.init))
    
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
    
    let hasMoreThanOneAccount = context.sharedContext.activeAccountContexts
    |> map { _, contexts, _ -> Bool in
        return contexts.count > 1
    }
    |> distinctUntilChanged
    
    let signal = combineLatest(context.sharedContext.presentationData, sharedData, preferences, notificationExceptions.get(), DeviceAccess.authorizationStatus(applicationInForeground: context.sharedContext.applicationBindings.applicationInForeground, subject: .notifications), notificationsWarningSuppressed.get(), hasMoreThanOneAccount)
        |> map { presentationData, sharedData, view, exceptions, authorizationStatus, warningSuppressed, hasMoreThanOneAccount -> (ItemListControllerState, (ItemListNodeState, Any)) in
            
            let viewSettings: GlobalNotificationSettingsSet
            if let settings = view.values[PreferencesKeys.globalNotifications]?.get(GlobalNotificationSettings.self) {
                viewSettings = settings.effective
            } else {
                viewSettings = GlobalNotificationSettingsSet.defaultSettings
            }
            
            let inAppSettings: InAppNotificationSettings
            if let settings = sharedData.entries[ApplicationSpecificSharedDataKeys.inAppNotificationSettings]?.get(InAppNotificationSettings.self) {
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
