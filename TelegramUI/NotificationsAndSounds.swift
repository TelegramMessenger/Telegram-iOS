import Foundation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

private final class NotificationsAndSoundsArguments {
    let account: Account
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
    let updateTotalUnreadCountStyle: (Bool) -> Void
    let updateIncludeTag: (PeerSummaryCounterTags, Bool) -> Void
    let updateTotalUnreadCountCategory: (Bool) -> Void
    
    let resetNotifications: () -> Void
    
    let updatedExceptionMode: (NotificationExceptionMode) -> Void
    
    let openAppSettings: () -> Void
    
    init(account: Account, presentController: @escaping (ViewController, ViewControllerPresentationArguments?) -> Void, pushController: @escaping(ViewController)->Void, soundSelectionDisposable: MetaDisposable, authorizeNotifications: @escaping () -> Void, suppressWarning: @escaping () -> Void, updateMessageAlerts: @escaping (Bool) -> Void, updateMessagePreviews: @escaping (Bool) -> Void, updateMessageSound: @escaping (PeerMessageSound) -> Void, updateGroupAlerts: @escaping (Bool) -> Void, updateGroupPreviews: @escaping (Bool) -> Void, updateGroupSound: @escaping (PeerMessageSound) -> Void, updateChannelAlerts: @escaping (Bool) -> Void, updateChannelPreviews: @escaping (Bool) -> Void, updateChannelSound: @escaping (PeerMessageSound) -> Void, updateInAppSounds: @escaping (Bool) -> Void, updateInAppVibration: @escaping (Bool) -> Void, updateInAppPreviews: @escaping (Bool) -> Void, updateDisplayNameOnLockscreen: @escaping (Bool) -> Void, updateTotalUnreadCountStyle: @escaping (Bool) -> Void, updateIncludeTag: @escaping (PeerSummaryCounterTags, Bool) -> Void, updateTotalUnreadCountCategory: @escaping (Bool) -> Void, resetNotifications: @escaping () -> Void, updatedExceptionMode: @escaping(NotificationExceptionMode) -> Void, openAppSettings: @escaping () -> Void) {
        self.account = account
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
        self.updateTotalUnreadCountStyle = updateTotalUnreadCountStyle
        self.updateIncludeTag = updateIncludeTag
        self.updateTotalUnreadCountCategory = updateTotalUnreadCountCategory
        self.resetNotifications = resetNotifications
        self.updatedExceptionMode = updatedExceptionMode
        self.openAppSettings = openAppSettings
    }
}

private enum NotificationsAndSoundsSection: Int32 {
    case permission
    case messages
    case groups
    case channels
    case inApp
    case displayNamesOnLockscreen
    case badge
    case reset
}

private enum NotificationsAndSoundsEntry: ItemListNodeEntry {
    case permissionInfo(PresentationTheme, PresentationStrings, AccessType)
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
    case unreadCountStyle(PresentationTheme, String, Bool)
    case includePublicGroups(PresentationTheme, String, Bool)
    case includeChannels(PresentationTheme, String, Bool)
    case unreadCountCategory(PresentationTheme, String, Bool)
    case unreadCountCategoryInfo(PresentationTheme, String)
    
    case reset(PresentationTheme, String)
    case resetNotice(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
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
            case .badgeHeader, .unreadCountStyle, .includePublicGroups, .includeChannels, .unreadCountCategory, .unreadCountCategoryInfo:
                return NotificationsAndSoundsSection.badge.rawValue
            case .reset, .resetNotice:
                return NotificationsAndSoundsSection.reset.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
            case .permissionInfo:
                return 0
            case .permissionEnable:
                return 1
            case .messageHeader:
                return 2
            case .messageAlerts:
                return 3
            case .messagePreviews:
                return 4
            case .messageSound:
                return 5
            case .userExceptions:
                return 6
            case .messageNotice:
                return 7
            case .groupHeader:
                return 8
            case .groupAlerts:
                return 9
            case .groupPreviews:
                return 10
            case .groupSound:
                return 11
            case .groupExceptions:
                return 12
            case .groupNotice:
                return 13
            case .channelHeader:
                return 14
            case .channelAlerts:
                return 15
            case .channelPreviews:
                return 16
            case .channelSound:
                return 17
            case .channelExceptions:
                return 18
            case .channelNotice:
                return 19
            case .inAppHeader:
                return 20
            case .inAppSounds:
                return 21
            case .inAppVibrate:
                return 22
            case .inAppPreviews:
                return 23
            case .displayNamesOnLockscreen:
                return 24
            case .displayNamesOnLockscreenInfo:
                return 25
            case .badgeHeader:
                return 26
            case .unreadCountStyle:
                return 27
            case .includePublicGroups:
                return 28
            case .includeChannels:
                return 29
            case .unreadCountCategory:
                return 30
            case .unreadCountCategoryInfo:
                return 31
            case .reset:
                return 32
            case .resetNotice:
                return 33
        }
    }
    
    static func ==(lhs: NotificationsAndSoundsEntry, rhs: NotificationsAndSoundsEntry) -> Bool {
        switch lhs {
            case let .permissionInfo(lhsTheme, lhsStrings, lhsAccessType):
                if case let .permissionInfo(rhsTheme, rhsStrings, rhsAccessType) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsAccessType == rhsAccessType {
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
            case let .unreadCountStyle(lhsTheme, lhsText, lhsValue):
                if case let .unreadCountStyle(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
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
    
    func item(_ arguments: NotificationsAndSoundsArguments) -> ListViewItem {
        switch self {
            case let .permissionInfo(theme, strings, type):
                return PermissionInfoItemListItem(theme: theme, strings: strings, subject: .notifications, type: type, style: .blocks, sectionId: self.section, close: {
                    arguments.suppressWarning()
                })
            case let .permissionEnable(theme, text):
                return ItemListActionItem(theme: theme, title: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    arguments.authorizeNotifications()
                })
            case let .messageHeader(theme, text):
                return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
            case let .messageAlerts(theme, text, value):
                return ItemListSwitchItem(theme: theme, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateMessageAlerts(updatedValue)
                })
            case let .messagePreviews(theme, text, value):
                return ItemListSwitchItem(theme: theme, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateMessagePreviews(updatedValue)
                })
            case let .messageSound(theme, text, value, sound):
                return ItemListDisclosureItem(theme: theme, title: text, label: value, sectionId: self.section, style: .blocks, action: {
                    let controller = notificationSoundSelectionController(account: arguments.account, isModal: true, currentSound: sound, defaultSound: nil, completion: { [weak arguments] value in
                        arguments?.updateMessageSound(value)
                    })
                    arguments.presentController(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                })
            case let .userExceptions(theme, strings, text, value):
                return ItemListDisclosureItem(theme: theme, title: text, label: strings.Notifications_Exceptions(Int32(value.settings.count)), sectionId: self.section, style: .blocks, action: {
                    let controller = NotificationExceptionsController(account: arguments.account, mode: value, updatedMode: arguments.updatedExceptionMode)
                    arguments.pushController(controller)
                })
            case let .messageNotice(theme, text):
                return ItemListTextItem(theme: theme, text: .plain(text), sectionId: self.section)
            case let .groupHeader(theme, text):
                return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
            case let .groupAlerts(theme, text, value):
                return ItemListSwitchItem(theme: theme, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateGroupAlerts(updatedValue)
                })
            case let .groupPreviews(theme, text, value):
                return ItemListSwitchItem(theme: theme, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateGroupPreviews(updatedValue)
                })
            case let .groupSound(theme, text, value, sound):
                return ItemListDisclosureItem(theme: theme, title: text, label: value, sectionId: self.section, style: .blocks, action: {
                    let controller = notificationSoundSelectionController(account: arguments.account, isModal: true, currentSound: sound, defaultSound: nil, completion: { [weak arguments] value in
                        arguments?.updateGroupSound(value)
                    })
                    arguments.presentController(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                })
            case let .groupExceptions(theme, strings, text, value):
                return ItemListDisclosureItem(theme: theme, title: text, label: strings.Notifications_Exceptions(Int32(value.settings.count)), sectionId: self.section, style: .blocks, action: {
                    let controller = NotificationExceptionsController(account: arguments.account, mode: value, updatedMode: arguments.updatedExceptionMode)
                    arguments.pushController(controller)
                })
            case let .groupNotice(theme, text):
                return ItemListTextItem(theme: theme, text: .plain(text), sectionId: self.section)
            case let .channelHeader(theme, text):
                return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
            case let .channelAlerts(theme, text, value):
                return ItemListSwitchItem(theme: theme, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateChannelAlerts(updatedValue)
                })
            case let .channelPreviews(theme, text, value):
                return ItemListSwitchItem(theme: theme, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateChannelPreviews(updatedValue)
                })
            case let .channelSound(theme, text, value, sound):
                return ItemListDisclosureItem(theme: theme, title: text, label: value, sectionId: self.section, style: .blocks, action: {
                    let controller = notificationSoundSelectionController(account: arguments.account, isModal: true, currentSound: sound, defaultSound: nil, completion: { [weak arguments] value in
                        arguments?.updateChannelSound(value)
                    })
                    arguments.presentController(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                })
            case let .channelExceptions(theme, strings, text, value):
                return ItemListDisclosureItem(theme: theme, title: text, label: strings.Notifications_Exceptions(Int32(value.settings.count)), sectionId: self.section, style: .blocks, action: {
                    let controller = NotificationExceptionsController(account: arguments.account, mode: value, updatedMode: arguments.updatedExceptionMode)
                    arguments.pushController(controller)
                })
            case let .channelNotice(theme, text):
                return ItemListTextItem(theme: theme, text: .plain(text), sectionId: self.section)
            case let .inAppHeader(theme, text):
                return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
            case let .inAppSounds(theme, text, value):
                return ItemListSwitchItem(theme: theme, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateInAppSounds(updatedValue)
                })
            case let .inAppVibrate(theme, text, value):
                return ItemListSwitchItem(theme: theme, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateInAppVibration(updatedValue)
                })
            case let .inAppPreviews(theme, text, value):
                return ItemListSwitchItem(theme: theme, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateInAppPreviews(updatedValue)
                })
            case let .displayNamesOnLockscreen(theme, text, value):
                return ItemListSwitchItem(theme: theme, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateDisplayNameOnLockscreen(updatedValue)
                })
            case let .displayNamesOnLockscreenInfo(theme, text):
                return ItemListTextItem(theme: theme, text: .markdown(text.replacingOccurrences(of: "]", with: "]()")), sectionId: self.section, linkAction: { _ in
                    arguments.openAppSettings()
                })
            case let .badgeHeader(theme, text):
                return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
            case let .unreadCountStyle(theme, text, value):
                return ItemListSwitchItem(theme: theme, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateTotalUnreadCountStyle(updatedValue)
                })
            case let .includePublicGroups(theme, text, value):
                return ItemListSwitchItem(theme: theme, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateIncludeTag(.publicGroups, updatedValue)
                })
            case let .includeChannels(theme, text, value):
                return ItemListSwitchItem(theme: theme, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateIncludeTag(.channels, updatedValue)
                })
            case let .unreadCountCategory(theme, text, value):
                return ItemListSwitchItem(theme: theme, title: text, value: value, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    arguments.updateTotalUnreadCountCategory(updatedValue)
                })
            case let .unreadCountCategoryInfo(theme, text):
                return ItemListTextItem(theme: theme, text: .plain(text), sectionId: self.section)
            case let .reset(theme, text):
                return ItemListActionItem(theme: theme, title: text, kind: .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    arguments.resetNotifications()
                })
            case let .resetNotice(theme, text):
                return ItemListTextItem(theme: theme, text: .plain(text), sectionId: self.section)
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

private func notificationsAndSoundsEntries(authorizationStatus: AccessType, warningSuppressed: Bool, globalSettings: GlobalNotificationSettingsSet, inAppSettings: InAppNotificationSettings, exceptions: (users: NotificationExceptionMode, groups: NotificationExceptionMode, channels: NotificationExceptionMode), presentationData: PresentationData) -> [NotificationsAndSoundsEntry] {
    var entries: [NotificationsAndSoundsEntry] = []
    
    if #available(iOSApplicationExtension 10.0, *) {
        switch (authorizationStatus, warningSuppressed) {
            case (.denied, _):
                entries.append(.permissionInfo(presentationData.theme, presentationData.strings, authorizationStatus))
                entries.append(.permissionEnable(presentationData.theme, presentationData.strings.Notifications_PermissionsAllowInSettings))
            case (.unreachable, false):
                entries.append(.permissionInfo(presentationData.theme, presentationData.strings, authorizationStatus))
                entries.append(.permissionEnable(presentationData.theme, presentationData.strings.Notifications_PermissionsOpenSettings))
            case (.notDetermined, _):
                entries.append(.permissionInfo(presentationData.theme, presentationData.strings, authorizationStatus))
                entries.append(.permissionEnable(presentationData.theme, presentationData.strings.Notifications_PermissionsAllow))
            default:
                break
        }
    }
    
    entries.append(.messageHeader(presentationData.theme, presentationData.strings.Notifications_MessageNotifications))
    entries.append(.messageAlerts(presentationData.theme, presentationData.strings.Notifications_MessageNotificationsAlert, globalSettings.privateChats.enabled))
    entries.append(.messagePreviews(presentationData.theme, presentationData.strings.Notifications_MessageNotificationsPreview, globalSettings.privateChats.displayPreviews))
    entries.append(.messageSound(presentationData.theme, presentationData.strings.Notifications_MessageNotificationsSound, localizedPeerNotificationSoundString(strings: presentationData.strings, sound: filteredGlobalSound(globalSettings.privateChats.sound)), filteredGlobalSound(globalSettings.privateChats.sound)))
    if !exceptions.users.isEmpty {
        entries.append(.userExceptions(presentationData.theme, presentationData.strings, presentationData.strings.Notifications_MessageNotificationsExceptions, exceptions.users))
        entries.append(.messageNotice(presentationData.theme, presentationData.strings.Notifications_MessageNotificationsExceptionsHelp))
    } else {
        entries.append(.messageNotice(presentationData.theme, presentationData.strings.Notifications_MessageNotificationsHelp))
    }
    
    entries.append(.groupHeader(presentationData.theme, presentationData.strings.Notifications_GroupNotifications))
    entries.append(.groupAlerts(presentationData.theme, presentationData.strings.Notifications_MessageNotificationsAlert, globalSettings.groupChats.enabled))
    entries.append(.groupPreviews(presentationData.theme, presentationData.strings.Notifications_MessageNotificationsPreview, globalSettings.groupChats.displayPreviews))
    entries.append(.groupSound(presentationData.theme, presentationData.strings.Notifications_MessageNotificationsSound, localizedPeerNotificationSoundString(strings: presentationData.strings, sound: filteredGlobalSound(globalSettings.groupChats.sound)), filteredGlobalSound(globalSettings.groupChats.sound)))
    if !exceptions.groups.isEmpty {
        entries.append(.groupExceptions(presentationData.theme, presentationData.strings, presentationData.strings.Notifications_MessageNotificationsExceptions, exceptions.groups))
        entries.append(.groupNotice(presentationData.theme, presentationData.strings.Notifications_GroupNotificationsExceptionsHelp))
    } else {
        entries.append(.groupNotice(presentationData.theme, presentationData.strings.Notifications_GroupNotificationsHelp))
    }
    
    entries.append(.channelHeader(presentationData.theme, presentationData.strings.Notifications_ChannelNotifications))
    entries.append(.channelAlerts(presentationData.theme, presentationData.strings.Notifications_MessageNotificationsAlert, globalSettings.channels.enabled))
    entries.append(.channelPreviews(presentationData.theme, presentationData.strings.Notifications_MessageNotificationsPreview, globalSettings.channels.displayPreviews))
    entries.append(.channelSound(presentationData.theme, presentationData.strings.Notifications_MessageNotificationsSound, localizedPeerNotificationSoundString(strings: presentationData.strings, sound: filteredGlobalSound(globalSettings.channels.sound)), filteredGlobalSound(globalSettings.channels.sound)))
    if !exceptions.channels.isEmpty {
          entries.append(.channelExceptions(presentationData.theme, presentationData.strings, presentationData.strings.Notifications_MessageNotificationsExceptions, exceptions.channels))
        entries.append(.channelNotice(presentationData.theme, presentationData.strings.Notifications_ChannelNotificationsExceptionsHelp))
    } else {
        entries.append(.channelNotice(presentationData.theme, presentationData.strings.Notifications_ChannelNotificationsHelp))
    }
    
    entries.append(.inAppHeader(presentationData.theme, presentationData.strings.Notifications_InAppNotifications))
    entries.append(.inAppSounds(presentationData.theme, presentationData.strings.Notifications_InAppNotificationsSounds, inAppSettings.playSounds))
    entries.append(.inAppVibrate(presentationData.theme, presentationData.strings.Notifications_InAppNotificationsVibrate, inAppSettings.vibrate))
    entries.append(.inAppPreviews(presentationData.theme, presentationData.strings.Notifications_InAppNotificationsPreview, inAppSettings.displayPreviews))
    
    entries.append(.displayNamesOnLockscreen(presentationData.theme, presentationData.strings.Notifications_DisplayNamesOnLockScreen, inAppSettings.displayNameOnLockscreen))
    entries.append(.displayNamesOnLockscreenInfo(presentationData.theme, presentationData.strings.Notifications_DisplayNamesOnLockScreenInfoWithLink))
    
    entries.append(.badgeHeader(presentationData.theme, presentationData.strings.Notifications_Badge))
    entries.append(.unreadCountStyle(presentationData.theme, presentationData.strings.Notifications_Badge_IncludeMutedChats, inAppSettings.totalUnreadCountDisplayStyle == .raw))
    entries.append(.includePublicGroups(presentationData.theme, presentationData.strings.Notifications_Badge_IncludePublicGroups, inAppSettings.totalUnreadCountIncludeTags.contains(.publicGroups)))
    entries.append(.includeChannels(presentationData.theme, presentationData.strings.Notifications_Badge_IncludeChannels, inAppSettings.totalUnreadCountIncludeTags.contains(.channels)))
    entries.append(.unreadCountCategory(presentationData.theme, presentationData.strings.Notifications_Badge_CountUnreadMessages, inAppSettings.totalUnreadCountDisplayCategory == .messages))
    entries.append(.unreadCountCategoryInfo(presentationData.theme, inAppSettings.totalUnreadCountDisplayCategory == .chats ? presentationData.strings.Notifications_Badge_CountUnreadMessages_InfoOff : presentationData.strings.Notifications_Badge_CountUnreadMessages_InfoOn))
    
    entries.append(.reset(presentationData.theme, presentationData.strings.Notifications_ResetAllNotifications))
    entries.append(.resetNotice(presentationData.theme, presentationData.strings.Notifications_ResetAllNotificationsHelp))
    
    return entries
}

public func notificationsAndSoundsController(account: Account, exceptionsList: NotificationExceptionsList?) -> ViewController {
    var presentControllerImpl: ((ViewController, ViewControllerPresentationArguments?) -> Void)?
    var pushControllerImpl: ((ViewController) -> Void)?
    
    let notificationExceptions: Promise<(users: NotificationExceptionMode, groups: NotificationExceptionMode, channels: NotificationExceptionMode)> = Promise()
    
    let updateNotificationExceptions:((users: NotificationExceptionMode, groups: NotificationExceptionMode, channels: NotificationExceptionMode)) -> Void = { value in
        notificationExceptions.set(.single(value))
    }
    
    let arguments = NotificationsAndSoundsArguments(account: account, presentController: { controller, arguments in
        presentControllerImpl?(controller, arguments)
    }, pushController: { controller in
        pushControllerImpl?(controller)
    }, soundSelectionDisposable: MetaDisposable(), authorizeNotifications: {
        let _ = (DeviceAccess.authorizationStatus(account: account, subject: .notifications)
        |> take(1)
        |> deliverOnMainQueue).start(next: { status in
            switch status {
                case .notDetermined:
                    DeviceAccess.authorizeAccess(to: .notifications)
                case .denied, .restricted, .unreachable:
                    account.telegramApplicationContext.applicationBindings.openSettings()
                default:
                    break
            }
        })
    }, suppressWarning: {
        let presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        presentControllerImpl?(textAlertController(account: account, title: nil, text: presentationData.strings.Notifications_PermissionsSuppressWarningTitle, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .genericAction, title: presentationData.strings.Common_OK, action: {
            ApplicationSpecificNotice.setNotificationsPermissionWarning(postbox: account.postbox, value: Int32(Date().timeIntervalSince1970))
        })]), nil)
    }, updateMessageAlerts: { value in
        let _ = updateGlobalNotificationSettingsInteractively(postbox: account.postbox, { settings in
            return settings.withUpdatedPrivateChats {
                return $0.withUpdatedEnabled(value)
            }
        }).start()
    }, updateMessagePreviews: { value in
        let _ = updateGlobalNotificationSettingsInteractively(postbox: account.postbox, { settings in
            return settings.withUpdatedPrivateChats {
                return $0.withUpdatedDisplayPreviews(value)
            }
        }).start()
    }, updateMessageSound: { value in
        let _ = updateGlobalNotificationSettingsInteractively(postbox: account.postbox, { settings in
            return settings.withUpdatedPrivateChats {
                return $0.withUpdatedSound(value)
            }
        }).start()
    }, updateGroupAlerts: { value in
        let _ = updateGlobalNotificationSettingsInteractively(postbox: account.postbox, { settings in
            return settings.withUpdatedGroupChats {
                return $0.withUpdatedEnabled(value)
            }
        }).start()
    }, updateGroupPreviews: { value in
        let _ = updateGlobalNotificationSettingsInteractively(postbox: account.postbox, { settings in
            return settings.withUpdatedGroupChats {
                return $0.withUpdatedDisplayPreviews(value)
            }
        }).start()
    }, updateGroupSound: {value in
        let _ = updateGlobalNotificationSettingsInteractively(postbox: account.postbox, { settings in
            return settings.withUpdatedGroupChats {
                return $0.withUpdatedSound(value)
            }
        }).start()
    }, updateChannelAlerts: { value in
        let _ = updateGlobalNotificationSettingsInteractively(postbox: account.postbox, { settings in
            return settings.withUpdatedChannels {
                return $0.withUpdatedEnabled(value)
            }
        }).start()
    }, updateChannelPreviews: { value in
        let _ = updateGlobalNotificationSettingsInteractively(postbox: account.postbox, { settings in
            return settings.withUpdatedChannels {
                return $0.withUpdatedDisplayPreviews(value)
            }
        }).start()
    }, updateChannelSound: {value in
        let _ = updateGlobalNotificationSettingsInteractively(postbox: account.postbox, { settings in
            return settings.withUpdatedChannels {
                return $0.withUpdatedSound(value)
            }
        }).start()
    }, updateInAppSounds: { value in
        let _ = updateInAppNotificationSettingsInteractively(postbox: account.postbox, { settings in
            var settings = settings
            settings.playSounds = value
            return settings
        }).start()
    }, updateInAppVibration: { value in
        let _ = updateInAppNotificationSettingsInteractively(postbox: account.postbox, { settings in
            var settings = settings
            settings.vibrate = value
            return settings
        }).start()
    }, updateInAppPreviews: { value in
        let _ = updateInAppNotificationSettingsInteractively(postbox: account.postbox, { settings in
            var settings = settings
            settings.displayPreviews = value
            return settings
        }).start()
    }, updateDisplayNameOnLockscreen: { value in
        let _ = updateInAppNotificationSettingsInteractively(postbox: account.postbox, { settings in
            var settings = settings
            settings.displayNameOnLockscreen = value
            return settings
        }).start()
    }, updateTotalUnreadCountStyle: { value in
        let _ = updateInAppNotificationSettingsInteractively(postbox: account.postbox, { settings in
            var settings = settings
            settings.totalUnreadCountDisplayStyle = value ? .raw : .filtered
            return settings
        }).start()
    }, updateIncludeTag: { tag, value in
        let _ = updateInAppNotificationSettingsInteractively(postbox: account.postbox, { settings in
            var settings = settings
            if !value {
                settings.totalUnreadCountIncludeTags.remove(tag)
            } else {
                settings.totalUnreadCountIncludeTags.insert(tag)
            }
            return settings
        }).start()
    }, updateTotalUnreadCountCategory: { value in
        let _ = updateInAppNotificationSettingsInteractively(postbox: account.postbox, { settings in
            var settings = settings
            settings.totalUnreadCountDisplayCategory = value ? .messages : .chats
            return settings
        }).start()
    }, resetNotifications: {
        let presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        let actionSheet = ActionSheetController(presentationTheme: presentationData.theme)
        actionSheet.setItemGroups([ActionSheetItemGroup(items: [
            ActionSheetButtonItem(title: presentationData.strings.Notifications_Reset, color: .destructive, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
                
                let modifyPeers = account.postbox.transaction { transaction -> Void in
                    transaction.resetAllPeerNotificationSettings(TelegramPeerNotificationSettings.defaultSettings)
                }
                let updateGlobal = updateGlobalNotificationSettingsInteractively(postbox: account.postbox, { _ in
                    return GlobalNotificationSettingsSet.defaultSettings
                })
                let reset = resetPeerNotificationSettings(network: account.network)
                let signal = combineLatest(modifyPeers, updateGlobal, reset)
                let _ = signal.start()
            })
        ]), ActionSheetItemGroup(items: [
            ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, action: { [weak actionSheet] in
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
        account.telegramApplicationContext.applicationBindings.openSettings()
    })
    
    let preferences = account.postbox.preferencesView(keys: [PreferencesKeys.globalNotifications, ApplicationSpecificPreferencesKeys.inAppNotificationSettings])
    
    let exceptionsSignal = Signal<NotificationExceptionsList?, NoError>.single(exceptionsList) |> then(notificationExceptionsList(network: account.network) |> map(Optional.init))
    
    notificationExceptions.set(exceptionsSignal |> map { list -> (NotificationExceptionMode, NotificationExceptionMode, NotificationExceptionMode) in
        var users:[PeerId : NotificationExceptionWrapper] = [:]
        var groups: [PeerId : NotificationExceptionWrapper] = [:]
        var channels:[PeerId : NotificationExceptionWrapper] = [:]
        if let list = list {
            for (key, value) in list.settings {
                if  let peer = list.peers[key], !peer.debugDisplayTitle.isEmpty, peer.id != account.peerId {
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
    if #available(iOSApplicationExtension 10.0, *) {
        let warningKey = PostboxViewKey.noticeEntry(ApplicationSpecificNotice.notificationsPermissionWarningKey())
        notificationsWarningSuppressed.set(.single(true)
        |> then(account.postbox.combinedView(keys: [warningKey])
            |> map { combined -> Bool in
                let timestamp = (combined.views[warningKey] as? NoticeEntryView)?.value.flatMap({ ApplicationSpecificNotice.getTimestampValue($0) })
                if let timestamp = timestamp, timestamp > 0 || timestamp == -1 {
                    return true
                } else {
                    return false
                }
            }))
    }
    
    let signal = combineLatest((account.applicationContext as! TelegramApplicationContext).presentationData, preferences, notificationExceptions.get(), DeviceAccess.authorizationStatus(account: account, subject: .notifications), notificationsWarningSuppressed.get())
        |> map { presentationData, view, exceptions, authorizationStatus, warningSuppressed -> (ItemListControllerState, (ItemListNodeState<NotificationsAndSoundsEntry>, NotificationsAndSoundsEntry.ItemGenerationArguments)) in
            
            let viewSettings: GlobalNotificationSettingsSet
            if let settings = view.values[PreferencesKeys.globalNotifications] as? GlobalNotificationSettings {
                viewSettings = settings.effective
            } else {
                viewSettings = GlobalNotificationSettingsSet.defaultSettings
            }
            
            let inAppSettings: InAppNotificationSettings
            if let settings = view.values[ApplicationSpecificPreferencesKeys.inAppNotificationSettings] as? InAppNotificationSettings {
                inAppSettings = settings
            } else {
                inAppSettings = InAppNotificationSettings.defaultSettings
            }
            
            let controllerState = ItemListControllerState(theme: presentationData.theme, title: .text(presentationData.strings.Notifications_Title), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
            let listState = ItemListNodeState(entries: notificationsAndSoundsEntries(authorizationStatus: authorizationStatus, warningSuppressed: warningSuppressed, globalSettings: viewSettings, inAppSettings: inAppSettings, exceptions: exceptions, presentationData: presentationData), style: .blocks)
            
            return (controllerState, (listState, arguments))
    }
    
    let controller = ItemListController(account: account, state: signal)
    presentControllerImpl = { [weak controller] c, a in
        controller?.present(c, in: .window(.root), with: a)
    }
    pushControllerImpl = { [weak controller] c in
        (controller?.navigationController as? NavigationController)?.pushViewController(c)
    }
    return controller
}
