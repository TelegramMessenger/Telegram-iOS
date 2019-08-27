import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import LegacyComponents
import TelegramPresentationData
import ItemListUI
import AccountContext
import TextFormat
import OverlayStatusController
import TelegramStringFormatting
import AccountContext
import ShareController
import AlertUI
import TelegramNotices
import GalleryUI
import ItemListAvatarAndNameInfoItem
import PeerAvatarGalleryUI
import NotificationMuteSettingsUI
import NotificationSoundSelectionUI

private final class UserInfoControllerArguments {
    let account: Account
    let avatarAndNameInfoContext: ItemListAvatarAndNameInfoItemContext
    let updateEditingName: (ItemListAvatarAndNameInfoItemName) -> Void
    let tapAvatarAction: () -> Void
    let openChat: () -> Void
    let addContact: () -> Void
    let shareContact: () -> Void
    let shareMyContact: () -> Void
    let startSecretChat: () -> Void
    let changeNotificationMuteSettings: () -> Void
    let openSharedMedia: () -> Void
    let openGroupsInCommon: () -> Void
    let updatePeerBlocked: (Bool) -> Void
    let deleteContact: () -> Void
    let displayUsernameContextMenu: (String) -> Void
    let displayCopyContextMenu: (UserInfoEntryTag, String) -> Void
    let call: () -> Void
    let openCallMenu: (String) -> Void
    let requestPhoneNumber: () -> Void
    let aboutLinkAction: (TextLinkItemActionType, TextLinkItem) -> Void
    let displayAboutContextMenu: (String) -> Void
    let openEncryptionKey: (SecretChatKeyFingerprint) -> Void
    let addBotToGroup: () -> Void
    let shareBot: () -> Void
    let botSettings: () -> Void
    let botHelp: () -> Void
    let botPrivacy: () -> Void
    let report: () -> Void
    
    init(account: Account, avatarAndNameInfoContext: ItemListAvatarAndNameInfoItemContext, updateEditingName: @escaping (ItemListAvatarAndNameInfoItemName) -> Void, tapAvatarAction: @escaping () -> Void, openChat: @escaping () -> Void, addContact: @escaping () -> Void, shareContact: @escaping () -> Void, shareMyContact: @escaping () -> Void, startSecretChat: @escaping () -> Void, changeNotificationMuteSettings: @escaping () -> Void, openSharedMedia: @escaping () -> Void, openGroupsInCommon: @escaping () -> Void, updatePeerBlocked: @escaping (Bool) -> Void, deleteContact: @escaping () -> Void, displayUsernameContextMenu: @escaping (String) -> Void, displayCopyContextMenu: @escaping (UserInfoEntryTag, String) -> Void, call: @escaping () -> Void, openCallMenu: @escaping (String) -> Void, requestPhoneNumber: @escaping () -> Void, aboutLinkAction: @escaping (TextLinkItemActionType, TextLinkItem) -> Void, displayAboutContextMenu: @escaping (String) -> Void, openEncryptionKey: @escaping (SecretChatKeyFingerprint) -> Void, addBotToGroup: @escaping () -> Void, shareBot: @escaping () -> Void, botSettings: @escaping () -> Void, botHelp: @escaping () -> Void, botPrivacy: @escaping () -> Void, report: @escaping () -> Void) {
        self.account = account
        self.avatarAndNameInfoContext = avatarAndNameInfoContext
        self.updateEditingName = updateEditingName
        self.tapAvatarAction = tapAvatarAction
        self.openChat = openChat
        self.addContact = addContact
        
        self.shareContact = shareContact
        self.shareMyContact = shareMyContact
        self.startSecretChat = startSecretChat
        self.changeNotificationMuteSettings = changeNotificationMuteSettings
        self.openSharedMedia = openSharedMedia
        self.openGroupsInCommon = openGroupsInCommon
        self.updatePeerBlocked = updatePeerBlocked
        self.deleteContact = deleteContact
        self.displayUsernameContextMenu = displayUsernameContextMenu
        self.displayCopyContextMenu = displayCopyContextMenu
        self.call = call
        self.openCallMenu = openCallMenu
        self.requestPhoneNumber = requestPhoneNumber
        self.aboutLinkAction = aboutLinkAction
        self.displayAboutContextMenu = displayAboutContextMenu
        self.openEncryptionKey = openEncryptionKey
        self.addBotToGroup = addBotToGroup
        self.shareBot = shareBot
        self.botSettings = botSettings
        self.botHelp = botHelp
        self.botPrivacy = botPrivacy
        self.report = report
    }
}

private enum UserInfoSection: ItemListSectionId {
    case info
    case actions
    case sharedMediaAndNotifications
    case bot
    case block
}

private enum UserInfoEntryTag {
    case about
    case phoneNumber
    case username
}

private func areMessagesEqual(_ lhsMessage: Message, _ rhsMessage: Message) -> Bool {
    if lhsMessage.stableVersion != rhsMessage.stableVersion {
        return false
    }
    if lhsMessage.id != rhsMessage.id || lhsMessage.flags != rhsMessage.flags {
        return false
    }
    return true
}

private enum UserInfoEntry: ItemListNodeEntry {
    case info(PresentationTheme, PresentationStrings, PresentationDateTimeFormat, peer: Peer?, presence: PeerPresence?, cachedData: CachedPeerData?, state: ItemListAvatarAndNameInfoItemState, displayCall: Bool)
    case calls(PresentationTheme, PresentationStrings, PresentationDateTimeFormat, messages: [Message])
    case about(PresentationTheme, Peer, String, String)
    case phoneNumber(PresentationTheme, Int, String, String, Bool)
    case requestPhoneNumber(PresentationTheme, String, String)
    case userName(PresentationTheme, String, String)
    case sendMessage(PresentationTheme, String)
    case addContact(PresentationTheme, String)
    case shareContact(PresentationTheme, String)
    case shareMyContact(PresentationTheme, String)
    case startSecretChat(PresentationTheme, String)
    case sharedMedia(PresentationTheme, String)
    case notifications(PresentationTheme, String, String)
    case groupsInCommon(PresentationTheme, String, String)
    case secretEncryptionKey(PresentationTheme, String, SecretChatKeyFingerprint)
    case botAddToGroup(PresentationTheme, String)
    case botShare(PresentationTheme, String)
    case botSettings(PresentationTheme, String)
    case botHelp(PresentationTheme, String)
    case botPrivacy(PresentationTheme, String)
    case botReport(PresentationTheme, String)
    case block(PresentationTheme, String, DestructiveUserInfoAction)
    
    var section: ItemListSectionId {
        switch self {
            case .info, .calls, .about, .phoneNumber, .requestPhoneNumber, .userName:
                return UserInfoSection.info.rawValue
            case .sendMessage, .addContact, .shareContact, .shareMyContact, .startSecretChat, .botAddToGroup, .botShare:
                return UserInfoSection.actions.rawValue
            case .botSettings, .botHelp, .botPrivacy:
                return UserInfoSection.bot.rawValue
            case .sharedMedia, .notifications, .groupsInCommon, .secretEncryptionKey:
                return UserInfoSection.sharedMediaAndNotifications.rawValue
            case .botReport, .block:
                return UserInfoSection.block.rawValue
        }
    }
    
    var stableId: Int {
        return self.sortIndex
    }
    
    static func ==(lhs: UserInfoEntry, rhs: UserInfoEntry) -> Bool {
        switch lhs {
            case let .info(lhsTheme, lhsStrings, lhsDateTimeFormat, lhsPeer, lhsPresence, lhsCachedData, lhsState, lhsDisplayCall):
                switch rhs {
                    case let .info(rhsTheme, rhsStrings, rhsDateTimeFormat, rhsPeer, rhsPresence, rhsCachedData, rhsState, rhsDisplayCall):
                        if lhsTheme !== rhsTheme {
                            return false
                        }
                        if lhsStrings !== rhsStrings {
                            return false
                        }
                        if lhsDateTimeFormat != rhsDateTimeFormat {
                            return false
                        }
                        if let lhsPeer = lhsPeer, let rhsPeer = rhsPeer {
                            if !lhsPeer.isEqual(rhsPeer) {
                                return false
                            }
                        } else if (lhsPeer != nil) != (rhsPeer != nil) {
                            return false
                        }
                        if let lhsPresence = lhsPresence, let rhsPresence = rhsPresence {
                            if !lhsPresence.isEqual(to: rhsPresence) {
                                return false
                            }
                        } else if (lhsPresence != nil) != (rhsPresence != nil) {
                            return false
                        }
                        if let lhsCachedData = lhsCachedData, let rhsCachedData = rhsCachedData {
                            if !lhsCachedData.isEqual(to: rhsCachedData) {
                                return false
                            }
                        } else if (lhsCachedData != nil) != (rhsCachedData != nil) {
                            return false
                        }
                        if lhsState != rhsState {
                            return false
                        }
                        if lhsDisplayCall != rhsDisplayCall {
                            return false
                        }
                        return true
                    default:
                        return false
                }
            case let .calls(lhsTheme, lhsStrings, lhsDateTimeFormat, lhsMessages):
                if case let .calls(rhsTheme, rhsStrings, rhsDateTimeFormat, rhsMessages) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsDateTimeFormat == rhsDateTimeFormat {
                    if lhsMessages.count != rhsMessages.count {
                        return false
                    }
                    for i in 0 ..< lhsMessages.count {
                        if !areMessagesEqual(lhsMessages[i], rhsMessages[i]) {
                            return false
                        }
                    }
                    return true
                } else {
                    return false
                }
            case let .about(lhsTheme, lhsPeer, lhsText, lhsValue):
                if case let .about(rhsTheme, rhsPeer, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsPeer.isEqual(rhsPeer), lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .phoneNumber(lhsTheme, lhsIndex, lhsLabel, lhsValue, lhsMain):
                if case let .phoneNumber(rhsTheme, rhsIndex, rhsLabel, rhsValue, rhsMain) = rhs, lhsTheme === rhsTheme, lhsIndex == rhsIndex, lhsLabel == rhsLabel, lhsValue == rhsValue, lhsMain == rhsMain {
                    return true
                } else {
                    return false
                }
            case let .requestPhoneNumber(lhsTheme, lhsLabel, lhsValue):
                if case let .requestPhoneNumber(rhsTheme, rhsLabel, rhsValue) = rhs, lhsTheme === rhsTheme, lhsLabel == rhsLabel, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .userName(lhsTheme, lhsText, lhsValue):
                if case let .userName(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .sendMessage(lhsTheme, lhsText):
                if case let .sendMessage(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .addContact(lhsTheme, lhsText):
                if case let .addContact(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .shareContact(lhsTheme, lhsText):
                if case let .shareContact(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .shareMyContact(lhsTheme, lhsText):
                if case let .shareMyContact(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .startSecretChat(lhsTheme, lhsText):
                if case let .startSecretChat(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .sharedMedia(lhsTheme, lhsText):
                if case let .sharedMedia(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .notifications(lhsTheme, lhsText, lhsValue):
                if case let .notifications(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .groupsInCommon(lhsTheme, lhsText, lhsValue):
                if case let .groupsInCommon(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .secretEncryptionKey(lhsTheme, lhsText, lhsValue):
                if case let .secretEncryptionKey(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .botAddToGroup(lhsTheme, lhsText):
                if case let .botAddToGroup(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .botShare(lhsTheme, lhsText):
                if case let .botShare(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .botSettings(lhsTheme, lhsText):
                if case let .botSettings(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .botHelp(lhsTheme, lhsText):
                if case let .botHelp(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .botPrivacy(lhsTheme, lhsText):
                if case let .botPrivacy(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .botReport(lhsTheme, lhsText):
                if case let .botReport(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .block(lhsTheme, lhsText, lhsAction):
                if case let .block(rhsTheme, rhsText, rhsAction) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsAction == rhsAction {
                    return true
                } else {
                    return false
                }
        }
    }
    
    private var sortIndex: Int {
        switch self {
            case .info:
                return 0
            case .calls:
                return 1
            case let .phoneNumber(_, index, _, _, _):
                return 2 + index
            case .requestPhoneNumber:
                return 998
            case .about:
                return 999
            case .userName:
                return 1000
            case .sendMessage:
                return 1001
            case .addContact:
                return 1002
            case .shareContact:
                return 1003
            case .shareMyContact:
                return 1004
            case .startSecretChat:
                return 1005
            case .botAddToGroup:
                return 1006
            case .botShare:
                return 1007
            case .botSettings:
                return 1008
            case .botHelp:
                return 1009
            case .botPrivacy:
                return 1010
            case .sharedMedia:
                return 1011
            case .notifications:
                return 1012
            case .secretEncryptionKey:
                return 1014
            case .groupsInCommon:
                return 1015
            case .botReport:
                return 1016
            case .block:
                return 1017
        }
    }
    
    static func <(lhs: UserInfoEntry, rhs: UserInfoEntry) -> Bool {
        return lhs.sortIndex < rhs.sortIndex
    }
    
    func item(_ arguments: UserInfoControllerArguments) -> ListViewItem {
        switch self {
            case let .info(theme, strings, dateTimeFormat, peer, presence, cachedData, state, displayCall):
                return ItemListAvatarAndNameInfoItem(account: arguments.account, theme: theme, strings: strings, dateTimeFormat: dateTimeFormat, mode: .generic, peer: peer, presence: presence, cachedData: cachedData, state: state, sectionId: self.section, style: .plain, editingNameUpdated: { editingName in
                    arguments.updateEditingName(editingName)
                }, avatarTapped: {
                    arguments.tapAvatarAction()
                }, context: arguments.avatarAndNameInfoContext, call: displayCall ? {
                    arguments.call()
                } : nil)
            case let .calls(theme, strings, dateTimeFormat, messages):
                return ItemListCallListItem(theme: theme, strings: strings, dateTimeFormat: dateTimeFormat, messages: messages, sectionId: self.section, style: .plain)
            case let .about(theme, peer, text, value):
                var enabledEntityTypes: EnabledEntityTypes = []
                if let peer = peer as? TelegramUser, let _ = peer.botInfo {
                    enabledEntityTypes = [.url, .mention, .hashtag]
                }
                return ItemListTextWithLabelItem(theme: theme, label: text, text: foldMultipleLineBreaks(value), enabledEntityTypes: enabledEntityTypes, multiline: true, sectionId: self.section, action: nil, longTapAction: {
                    arguments.displayAboutContextMenu(value)
                }, linkItemAction: { action, itemLink in
                    arguments.aboutLinkAction(action, itemLink)
                }, tag: UserInfoEntryTag.about)
            case let .phoneNumber(theme, _, label, value, isMain):
                return ItemListTextWithLabelItem(theme: theme, label: label, text: value, textColor: isMain ? .highlighted : .accent, enabledEntityTypes: [], multiline: false, sectionId: self.section, action: {
                    arguments.openCallMenu(value)
                }, longTapAction: {
                    arguments.displayCopyContextMenu(.phoneNumber, value)
                }, tag: UserInfoEntryTag.phoneNumber)
            case let .requestPhoneNumber(theme, label, value):
                return ItemListTextWithLabelItem(theme: theme, label: label, text: value, textColor: .accent, enabledEntityTypes: [], multiline: false, sectionId: self.section, action: {
                    arguments.requestPhoneNumber()
                })
            case let .userName(theme, text, value):
                return ItemListTextWithLabelItem(theme: theme, label: text, text: "@\(value)", textColor: .accent, enabledEntityTypes: [], multiline: false, sectionId: self.section, action: {
                    arguments.displayUsernameContextMenu("@\(value)")
                }, longTapAction: {
                    arguments.displayCopyContextMenu(.username, "@\(value)")
                }, tag: UserInfoEntryTag.username)
            case let .sendMessage(theme, text):
                return ItemListActionItem(theme: theme, title: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .plain, action: {
                    arguments.openChat()
                })
            case let .addContact(theme, text):
                return ItemListActionItem(theme: theme, title: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .plain, action: {
                    arguments.addContact()
                })
            case let .shareContact(theme, text):
                return ItemListActionItem(theme: theme, title: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .plain, action: {
                    arguments.shareContact()
                })
            case let .shareMyContact(theme, text):
                return ItemListActionItem(theme: theme, title: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .plain, action: {
                    arguments.shareMyContact()
                })
            case let .startSecretChat(theme, text):
                return ItemListActionItem(theme: theme, title: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .plain, action: {
                    arguments.startSecretChat()
                })
            case let .sharedMedia(theme, text):
                return ItemListDisclosureItem(theme: theme, title: text, label: "", sectionId: self.section, style: .plain, action: {
                    arguments.openSharedMedia()
                })
            case let .notifications(theme, text, value):
                return ItemListDisclosureItem(theme: theme, title: text, label: value, sectionId: self.section, style: .plain, action: {
                    arguments.changeNotificationMuteSettings()
                })
            case let .groupsInCommon(theme, text, value):
                return ItemListDisclosureItem(theme: theme, title: text, label: value, sectionId: self.section, style: .plain, action: {
                    arguments.openGroupsInCommon()
                })
            case let .secretEncryptionKey(theme, text, fingerprint):
                return ItemListSecretChatKeyItem(theme: theme, title: text, fingerprint: fingerprint, sectionId: self.section, style: .plain, action: {
                    arguments.openEncryptionKey(fingerprint)
                })
            case let .botAddToGroup(theme, text):
                return ItemListActionItem(theme: theme, title: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .plain, action: {
                    arguments.addBotToGroup()
                })
            case let .botShare(theme, text):
                return ItemListActionItem(theme: theme, title: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .plain, action: {
                    arguments.shareBot()
            })
            case let .botSettings(theme, text):
                return ItemListActionItem(theme: theme, title: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .plain, action: {
                    arguments.botSettings()
                })
            case let .botHelp(theme, text):
                return ItemListActionItem(theme: theme, title: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .plain, action: {
                    arguments.botHelp()
                })
            case let .botPrivacy(theme, text):
                return ItemListActionItem(theme: theme, title: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .plain, action: {
                    arguments.botPrivacy()
                })
            case let .botReport(theme, text):
                return ItemListActionItem(theme: theme, title: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .plain, action: {
                    arguments.report()
                })
            case let .block(theme, text, action):
                return ItemListActionItem(theme: theme, title: text, kind: .destructive, alignment: .natural, sectionId: self.section, style: .plain, action: {
                    switch action {
                        case .block:
                            arguments.updatePeerBlocked(true)
                        case .unblock:
                            arguments.updatePeerBlocked(false)
                        case .removeContact:
                            arguments.deleteContact()
                    }
                })
        }
    }
}

private enum DestructiveUserInfoAction {
    case block
    case removeContact
    case unblock
}

private struct UserInfoEditingState: Equatable {
    let editingName: ItemListAvatarAndNameInfoItemName?
    
    static func ==(lhs: UserInfoEditingState, rhs: UserInfoEditingState) -> Bool {
        if lhs.editingName != rhs.editingName {
            return false
        }
        return true
    }
}

private struct UserInfoState: Equatable {
    let savingData: Bool
    let editingState: UserInfoEditingState?
    
    init() {
        self.savingData = false
        self.editingState = nil
    }
    
    init(savingData: Bool, editingState: UserInfoEditingState?) {
        self.savingData = savingData
        self.editingState = editingState
    }
    
    static func ==(lhs: UserInfoState, rhs: UserInfoState) -> Bool {
        if lhs.savingData != rhs.savingData {
            return false
        }
        if lhs.editingState != rhs.editingState {
            return false
        }
        return true
    }
    
    func withUpdatedSavingData(_ savingData: Bool) -> UserInfoState {
        return UserInfoState(savingData: savingData, editingState: self.editingState)
    }
    
    func withUpdatedEditingState(_ editingState: UserInfoEditingState?) -> UserInfoState {
        return UserInfoState(savingData: self.savingData, editingState: editingState)
    }
}

private func stringForBlockAction(strings: PresentationStrings, action: DestructiveUserInfoAction, peer: Peer) -> String {
    switch action {
        case .block:
            if let user = peer as? TelegramUser, user.botInfo != nil {
                return strings.Bot_Stop
            } else {
                return strings.Conversation_BlockUser
            }
        case .unblock:
            if let user = peer as? TelegramUser, user.botInfo != nil {
                return strings.Bot_Unblock
            } else {
                return strings.Conversation_UnblockUser
            }
        case .removeContact:
            return strings.UserInfo_DeleteContact
    }
}

private func userInfoEntries(account: Account, presentationData: PresentationData, view: PeerView, cachedPeerData: CachedPeerData?, deviceContacts: [(DeviceContactStableId, DeviceContactBasicData)], mode: PeerInfoControllerMode, state: UserInfoState, peerChatState: PostboxCoding?, globalNotificationSettings: GlobalNotificationSettings) -> [UserInfoEntry] {
    var entries: [UserInfoEntry] = []
    
    guard let peer = view.peers[view.peerId], let user = peerViewMainPeer(view) as? TelegramUser else {
        return []
    }
    
    var editingName: ItemListAvatarAndNameInfoItemName?
    
    var isEditing = false
    if let editingState = state.editingState {
        isEditing = true
        
        if view.peerIsContact {
            editingName = editingState.editingName
        }
    }
    
    var callsAvailable = true
    if let cachedUserData = cachedPeerData as? CachedUserData {
        callsAvailable = cachedUserData.callsAvailable
    }
    
    entries.append(UserInfoEntry.info(presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, peer: user, presence: view.peerPresences[user.id], cachedData: cachedPeerData, state: ItemListAvatarAndNameInfoItemState(editingName: editingName, updatingName: nil), displayCall: user.botInfo == nil && callsAvailable))
    
    if case let .calls(messages) = mode, !isEditing {
        entries.append(UserInfoEntry.calls(presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, messages: messages))
    }
    
    if let phoneNumber = user.phone, !phoneNumber.isEmpty {
        let formattedNumber = formatPhoneNumber(phoneNumber)
        let normalizedNumber = DeviceContactNormalizedPhoneNumber(rawValue: formattedNumber)
        
        var index = 0
        var found = false
        
        var existingNumbers = Set<DeviceContactNormalizedPhoneNumber>()
        var phoneNumbers: [(String, DeviceContactNormalizedPhoneNumber, Bool)] = []
        
        for (_, contact) in deviceContacts {
            inner: for number in contact.phoneNumbers {
                var isMain = false
                let normalizedContactNumber = DeviceContactNormalizedPhoneNumber(rawValue: formatPhoneNumber(number.value))
                if !existingNumbers.contains(normalizedContactNumber) {
                    existingNumbers.insert(normalizedContactNumber)
                } else {
                    continue inner
                }
                if normalizedContactNumber == normalizedNumber {
                    found = true
                    isMain = true
                }
                
                phoneNumbers.append((number.label, normalizedContactNumber, isMain))
            }
        }
        if !found {
            entries.append(UserInfoEntry.phoneNumber(presentationData.theme, index, "home", formattedNumber, false))
            index += 1
        } else {
            for (label, number, isMain) in phoneNumbers {
                entries.append(UserInfoEntry.phoneNumber(presentationData.theme, index, localizedPhoneNumberLabel(label: label, strings: presentationData.strings), number.rawValue, isMain && phoneNumbers.count != 1))
                index += 1
            }
        }
    } else {
        //entries.append(UserInfoEntry.requestPhoneNumber(presentationData.theme, "phone", "Request Number"))
    }
    
    let aboutTitle: String
    if let _ = user.botInfo {
        aboutTitle = presentationData.strings.Profile_BotInfo
    } else {
        aboutTitle = presentationData.strings.Profile_About
    }
    if user.isScam {
        let aboutValue: String
        if let _ = user.botInfo {
            aboutValue = presentationData.strings.UserInfo_ScamBotWarning
        } else {
            aboutValue = presentationData.strings.UserInfo_ScamUserWarning
        }
        entries.append(UserInfoEntry.about(presentationData.theme, peer, aboutTitle, aboutValue))
    } else if let cachedUserData = cachedPeerData as? CachedUserData, let about = cachedUserData.about, !about.isEmpty {
        entries.append(UserInfoEntry.about(presentationData.theme, peer, aboutTitle, about))
    }
    
    if !isEditing {
        if let username = user.username, !username.isEmpty {
            entries.append(UserInfoEntry.userName(presentationData.theme, presentationData.strings.Profile_Username, username))
        }
        
        if !(peer is TelegramSecretChat) {
            entries.append(UserInfoEntry.sendMessage(presentationData.theme, presentationData.strings.UserInfo_SendMessage))
        }
        
        if user.botInfo == nil {
            if view.peerIsContact {
                if let phone = user.phone, !phone.isEmpty {
                    entries.append(UserInfoEntry.shareContact(presentationData.theme, presentationData.strings.UserInfo_ShareContact))
                }
            } else {
                entries.append(UserInfoEntry.addContact(presentationData.theme, presentationData.strings.Conversation_AddToContacts))
            }
        }
            
        if let cachedUserData = cachedPeerData as? CachedUserData, let peerStatusSettings = cachedUserData.peerStatusSettings, peerStatusSettings.contains(.canShareContact) {
            entries.append(UserInfoEntry.shareMyContact(presentationData.theme, presentationData.strings.UserInfo_ShareMyContactInfo))
        }
        
        if let peer = peer as? TelegramUser, peer.botInfo == nil {
            entries.append(UserInfoEntry.startSecretChat(presentationData.theme, presentationData.strings.UserInfo_StartSecretChat))
        }
        
        if let peer = peer as? TelegramUser, let botInfo = peer.botInfo {
            if botInfo.flags.contains(.worksWithGroups) {
                entries.append(UserInfoEntry.botAddToGroup(presentationData.theme, presentationData.strings.UserInfo_InviteBotToGroup))
            }
            entries.append(UserInfoEntry.botShare(presentationData.theme, presentationData.strings.UserInfo_ShareBot))
            
            if let cachedUserData = cachedPeerData as? CachedUserData, let botInfo = cachedUserData.botInfo {
                for command in botInfo.commands {
                    if command.text == "settings" {
                        entries.append(UserInfoEntry.botSettings(presentationData.theme, presentationData.strings.UserInfo_BotSettings))
                    } else if command.text == "help" {
                        entries.append(UserInfoEntry.botHelp(presentationData.theme, presentationData.strings.UserInfo_BotHelp))
                    } else if command.text == "privacy" {
                        entries.append(UserInfoEntry.botPrivacy(presentationData.theme, presentationData.strings.UserInfo_BotPrivacy))
                    }
                }
            }
        }
        
        entries.append(UserInfoEntry.sharedMedia(presentationData.theme, presentationData.strings.GroupInfo_SharedMedia))
    }
    let notificationsLabel: String
    let notificationSettings = view.notificationSettings as? TelegramPeerNotificationSettings ?? TelegramPeerNotificationSettings.defaultSettings
    if case let .muted(until) = notificationSettings.muteState, until >= Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970) {
        if until < Int32.max - 1 {
            notificationsLabel = stringForRemainingMuteInterval(strings: presentationData.strings, muteInterval: until)
        } else {
            notificationsLabel = presentationData.strings.UserInfo_NotificationsDisabled
        }
    } else if case .default = notificationSettings.messageSound {
        notificationsLabel = presentationData.strings.UserInfo_NotificationsEnabled
    } else {
        notificationsLabel = localizedPeerNotificationSoundString(strings: presentationData.strings, sound: notificationSettings.messageSound, default: globalNotificationSettings.effective.channels.sound)
    }
    entries.append(UserInfoEntry.notifications(presentationData.theme, presentationData.strings.GroupInfo_Notifications, notificationsLabel))
    
    if isEditing {
        if view.peerIsContact {
            entries.append(UserInfoEntry.block(presentationData.theme, stringForBlockAction(strings: presentationData.strings, action: .removeContact, peer: user), .removeContact))
        }
    } else {
        if peer is TelegramSecretChat, let peerChatState = peerChatState as? SecretChatKeyState, let keyFingerprint = peerChatState.keyFingerprint {
            entries.append(UserInfoEntry.secretEncryptionKey(presentationData.theme, presentationData.strings.Profile_EncryptionKey, keyFingerprint))
        }
        
        if let groupsInCommon = (cachedPeerData as? CachedUserData)?.commonGroupCount, groupsInCommon != 0 {
            entries.append(UserInfoEntry.groupsInCommon(presentationData.theme, presentationData.strings.UserInfo_GroupsInCommon, presentationStringsFormattedNumber(groupsInCommon, presentationData.dateTimeFormat.groupingSeparator)))
        }
        
        if let peer = peer as? TelegramUser, let _ = peer.botInfo {
            entries.append(UserInfoEntry.botReport(presentationData.theme, presentationData.strings.ReportPeer_Report))
        }
        
        if let cachedData = cachedPeerData as? CachedUserData {
            if cachedData.isBlocked {
                entries.append(UserInfoEntry.block(presentationData.theme, stringForBlockAction(strings: presentationData.strings, action: .unblock, peer: user), .unblock))
            } else {
                if let peer = peer as? TelegramUser, peer.flags.contains(.isSupport) {
                } else {
                    entries.append(UserInfoEntry.block(presentationData.theme, stringForBlockAction(strings: presentationData.strings, action: .block, peer: user), .block))
                }
            }
        }
    }
    
    return entries
}

private func getUserPeer(postbox: Postbox, peerId: PeerId) -> Signal<(Peer?, CachedPeerData?), NoError> {
    return postbox.transaction { transaction -> (Peer?, CachedPeerData?) in
        guard let peer = transaction.getPeer(peerId) else {
            return (nil, nil)
        }
        var resultPeer: Peer?
        if let peer = peer as? TelegramSecretChat {
            resultPeer = transaction.getPeer(peer.regularPeerId)
        } else {
            resultPeer = peer
        }
        return (resultPeer, resultPeer.flatMap({ transaction.getPeerCachedData(peerId: $0.id) }))
    }
}

public func userInfoController(context: AccountContext, peerId: PeerId, mode: PeerInfoControllerMode = .generic) -> ViewController {
    let statePromise = ValuePromise(UserInfoState(), ignoreRepeated: true)
    let stateValue = Atomic(value: UserInfoState())
    let updateState: ((UserInfoState) -> UserInfoState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var pushControllerImpl: ((ViewController) -> Void)?
    var presentControllerImpl: ((ViewController, Any?) -> Void)?
    var openChatImpl: (() -> Void)?
    var shareContactImpl: (() -> Void)?
    var shareMyContactImpl: (() -> Void)?
    var startSecretChatImpl: (() -> Void)?
    var botAddToGroupImpl: (() -> Void)?
    var shareBotImpl: (() -> Void)?
    var dismissInputImpl: (() -> Void)?
    var dismissImpl: (() -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    let updatePeerNameDisposable = MetaDisposable()
    actionsDisposable.add(updatePeerNameDisposable)
    
    let updatePeerBlockedDisposable = MetaDisposable()
    actionsDisposable.add(updatePeerBlockedDisposable)
    
    let changeMuteSettingsDisposable = MetaDisposable()
    actionsDisposable.add(changeMuteSettingsDisposable)
    
    let hiddenAvatarRepresentationDisposable = MetaDisposable()
    actionsDisposable.add(hiddenAvatarRepresentationDisposable)
    
    let createSecretChatDisposable = MetaDisposable()
    actionsDisposable.add(createSecretChatDisposable)
    
    let navigateDisposable = MetaDisposable()
    actionsDisposable.add(navigateDisposable)
    
    var avatarGalleryTransitionArguments: ((AvatarGalleryEntry) -> GalleryTransitionArguments?)?
    let avatarAndNameInfoContext = ItemListAvatarAndNameInfoItemContext()
    var updateHiddenAvatarImpl: (() -> Void)?
    
    var aboutLinkActionImpl: ((TextLinkItemActionType, TextLinkItem) -> Void)?
    var displayAboutContextMenuImpl: ((String) -> Void)?
    var displayCopyContextMenuImpl: ((UserInfoEntryTag, String) -> Void)?
    var popToRootImpl: (() -> Void)?
    
    let cachedAvatarEntries = Atomic<Promise<[AvatarGalleryEntry]>?>(value: nil)
    
    let peerView = Promise<(PeerView, CachedPeerData?)>()
    peerView.set(context.account.viewTracker.peerView(peerId, updateData: true) |> mapToSignal({ view -> Signal<(PeerView, CachedPeerData?), NoError> in
        if peerId.namespace == Namespaces.Peer.SecretChat {
            if let peer = peerViewMainPeer(view) {
                return context.account.viewTracker.peerView(peer.id) |> map({ secretChatView -> (PeerView, CachedPeerData?) in
                    return (view, secretChatView.cachedData)
                })
            }
        }
        return .single((view, view.cachedData))
    }))
    
    let requestCallImpl: () -> Void = {
        let _ = (peerView.get()
            |> take(1)
            |> deliverOnMainQueue).start(next: { view in
            guard let peer = peerViewMainPeer(view.0) else {
                return
            }
            
            if let cachedUserData = view.1 as? CachedUserData, cachedUserData.callsPrivate {
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                presentControllerImpl?(textAlertController(context: context, title: presentationData.strings.Call_ConnectionErrorTitle, text: presentationData.strings.Call_PrivacyErrorMessage(peer.compactDisplayTitle).0, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
                return
            }
            
            let callResult = context.sharedContext.callManager?.requestCall(account: context.account, peerId: peer.id, endCurrentIfAny: false)
            if let callResult = callResult, case let .alreadyInProgress(currentPeerId) = callResult {
                if currentPeerId == peer.id {
                    context.sharedContext.navigateToCurrentCall()
                } else {
                    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                    let _ = (context.account.postbox.transaction { transaction -> (Peer?, Peer?) in
                        return (transaction.getPeer(peer.id), transaction.getPeer(currentPeerId))
                        } |> deliverOnMainQueue).start(next: { peer, current in
                            if let peer = peer, let current = current {
                                presentControllerImpl?(textAlertController(context: context, title: presentationData.strings.Call_CallInProgressTitle, text: presentationData.strings.Call_CallInProgressMessage(current.compactDisplayTitle, peer.compactDisplayTitle).0, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .genericAction, title: presentationData.strings.Common_OK, action: {
                                    let _ = context.sharedContext.callManager?.requestCall(account: context.account, peerId: peer.id, endCurrentIfAny: true)
                                })]), nil)
                            }
                        })
                }
            }
        })
    }
    
    let arguments = UserInfoControllerArguments(account: context.account, avatarAndNameInfoContext: avatarAndNameInfoContext, updateEditingName: { editingName in
        updateState { state in
            if let _ = state.editingState {
                return state.withUpdatedEditingState(UserInfoEditingState(editingName: editingName))
            } else {
                return state
            }
        }
    }, tapAvatarAction: {
        let _ = (getUserPeer(postbox: context.account.postbox, peerId: peerId) |> deliverOnMainQueue).start(next: { peer, _ in
            guard let peer = peer else {
                return
            }
            
            if peer.profileImageRepresentations.isEmpty {
                return
            }
            
            let galleryController = AvatarGalleryController(context: context, peer: peer, remoteEntries: cachedAvatarEntries.with { $0 }, replaceRootController: { controller, ready in
            })
            hiddenAvatarRepresentationDisposable.set((galleryController.hiddenMedia |> deliverOnMainQueue).start(next: { entry in
                avatarAndNameInfoContext.hiddenAvatarRepresentation = entry?.representations.first?.representation
                updateHiddenAvatarImpl?()
            }))
            presentControllerImpl?(galleryController, AvatarGalleryControllerPresentationArguments(transitionArguments: { entry in
                return avatarGalleryTransitionArguments?(entry)
            }))
        })
    }, openChat: {
        openChatImpl?()
    }, addContact: {
        let _ = (getUserPeer(postbox: context.account.postbox, peerId: peerId)
        |> deliverOnMainQueue).start(next: { peer, cachedData in
            guard let user = peer as? TelegramUser, let contactData = DeviceContactExtendedData(peer: user) else {
                return
            }
            
            var shareViaException = false
            if let cachedData = cachedData as? CachedUserData, let peerStatusSettings = cachedData.peerStatusSettings {
                shareViaException = peerStatusSettings.contains(.addExceptionWhenAddingContact)
            }
            
            presentControllerImpl?(deviceContactInfoController(context: context, subject: .create(peer: user, contactData: contactData, isSharing: true, shareViaException: shareViaException, completion: { peer, stableId, contactData in
                if let peer = peer as? TelegramUser {
                    if let phone = peer.phone, !phone.isEmpty {
                    }
                    
                    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                    presentControllerImpl?(OverlayStatusController(theme: presentationData.theme, strings: presentationData.strings, type: .genericSuccess(presentationData.strings.AddContact_StatusSuccess(peer.compactDisplayTitle).0, true)), nil)
                }
            }), completed: nil, cancelled: nil), ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
        })
    }, shareContact: {
        shareContactImpl?()
    }, shareMyContact: {
        shareMyContactImpl?()
    }, startSecretChat: {
        startSecretChatImpl?()
    }, changeNotificationMuteSettings: {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let _ = (context.account.postbox.transaction { transaction -> (TelegramPeerNotificationSettings, GlobalNotificationSettings) in
            let peerSettings: TelegramPeerNotificationSettings = (transaction.getPeerNotificationSettings(peerId) as? TelegramPeerNotificationSettings) ?? TelegramPeerNotificationSettings.defaultSettings
            let globalSettings: GlobalNotificationSettings = (transaction.getPreferencesEntry(key: PreferencesKeys.globalNotifications) as? GlobalNotificationSettings) ?? GlobalNotificationSettings.defaultSettings
            return (peerSettings, globalSettings)
            }
            |> deliverOnMainQueue).start(next: { peerSettings, globalSettings in
                let soundSettings: NotificationSoundSettings?
                if case .default = peerSettings.messageSound {
                    soundSettings = NotificationSoundSettings(value: nil)
                } else {
                    soundSettings = NotificationSoundSettings(value: peerSettings.messageSound)
                }
                let controller = notificationMuteSettingsController(presentationData: presentationData, notificationSettings: globalSettings.effective.groupChats, soundSettings: soundSettings, openSoundSettings: {
                    let controller = notificationSoundSelectionController(context: context, isModal: true, currentSound: peerSettings.messageSound, defaultSound: globalSettings.effective.groupChats.sound, completion: { sound in
                        let _ = updatePeerNotificationSoundInteractive(account: context.account, peerId: peerId, sound: sound).start()
                    })
                    presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                }, updateSettings: { value in
                    changeMuteSettingsDisposable.set(updatePeerMuteSetting(account: context.account, peerId: peerId, muteInterval: value).start())
                })
                presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
            })
    }, openSharedMedia: {
        if let controller = context.sharedContext.makePeerSharedMediaController(context: context, peerId: peerId) {
            pushControllerImpl?(controller)
        }
    }, openGroupsInCommon: {
        let _ = (getUserPeer(postbox: context.account.postbox, peerId: peerId)
            |> take(1)
            |> deliverOnMainQueue).start(next: { peer, _ in
                guard let peer = peer else {
                    return
                }
                
                pushControllerImpl?(groupsInCommonController(context: context, peerId: peer.id))
        })
    }, updatePeerBlocked: { value in
        let _ = (getUserPeer(postbox: context.account.postbox, peerId: peerId)
        |> take(1)
        |> deliverOnMainQueue).start(next: { peer, _ in
            guard let peer = peer else {
                return
            }
            
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            if let peer = peer as? TelegramUser, let _ = peer.botInfo {
                updatePeerBlockedDisposable.set(requestUpdatePeerIsBlocked(account: context.account, peerId: peer.id, isBlocked: value).start())
                if !value {
                    let _ = enqueueMessages(account: context.account, peerId: peer.id, messages: [.message(text: "/start", attributes: [], mediaReference: nil, replyToMessageId: nil, localGroupingKey: nil)]).start()
                    openChatImpl?()
                }
            } else {
                if value {
                    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                    let controller = ActionSheetController(presentationTheme: presentationData.theme)
                    let dismissAction: () -> Void = { [weak controller] in
                        controller?.dismissAnimated()
                    }
                    var reportSpam = false
                    var deleteChat = false
                    controller.setItemGroups([
                        ActionSheetItemGroup(items: [
                            ActionSheetTextItem(title: presentationData.strings.UserInfo_BlockConfirmationTitle(peer.compactDisplayTitle).0),
                            /*ActionSheetCheckboxItem(title: presentationData.strings.Conversation_Moderate_Report, label: "", value: reportSpam, action: { [weak controller] checkValue in
                                reportSpam = checkValue
                                controller?.updateItem(groupIndex: 0, itemIndex: 1, { item in
                                    if let item = item as? ActionSheetCheckboxItem {
                                        return ActionSheetCheckboxItem(title: item.title, label: item.label, value: !item.value, action: item.action)
                                    }
                                    return item
                                })
                            }),
                            ActionSheetCheckboxItem(title: presentationData.strings.ReportSpam_DeleteThisChat, label: "", value: deleteChat, action: { [weak controller] checkValue in
                                deleteChat = checkValue
                                controller?.updateItem(groupIndex: 0, itemIndex: 2, { item in
                                    if let item = item as? ActionSheetCheckboxItem {
                                        return ActionSheetCheckboxItem(title: item.title, label: item.label, value: !item.value, action: item.action)
                                    }
                                    return item
                                })
                            }),*/
                            ActionSheetButtonItem(title: presentationData.strings.UserInfo_BlockActionTitle(peer.compactDisplayTitle).0, color: .destructive, action: {
                                dismissAction()
                                updatePeerBlockedDisposable.set(requestUpdatePeerIsBlocked(account: context.account, peerId: peer.id, isBlocked: true).start())
                                if deleteChat {
                                    let _ = removePeerChat(account: context.account, peerId: peerId, reportChatSpam: reportSpam).start()
                                    popToRootImpl?()
                                } else if reportSpam {
                                    let _ = reportPeer(account: context.account, peerId: peerId, reason: .spam).start()
                                }
                            })
                        ]),
                        ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { dismissAction() })])
                    ])
                    presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                } else {
                    let text: String
                    if value {
                        text = presentationData.strings.UserInfo_BlockConfirmation(peer.displayTitle).0
                    } else {
                        text = presentationData.strings.UserInfo_UnblockConfirmation(peer.displayTitle).0
                    }
                    presentControllerImpl?(textAlertController(context: context, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_No, action: {}), TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Yes, action: {
                        updatePeerBlockedDisposable.set(requestUpdatePeerIsBlocked(account: context.account, peerId: peer.id, isBlocked: value).start())
                    })]), nil)
                }
            }
        })
    }, deleteContact: {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let controller = ActionSheetController(presentationTheme: presentationData.theme)
        let dismissAction: () -> Void = { [weak controller] in
            controller?.dismissAnimated()
        }
        controller.setItemGroups([
            ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: presentationData.strings.UserInfo_DeleteContact, color: .destructive, action: {
                    dismissAction()
                    let _ = (getUserPeer(postbox: context.account.postbox, peerId: peerId)
                    |> deliverOnMainQueue).start(next: { peer, _ in
                        guard let peer = peer else {
                            return
                        }
                        let deleteContactFromDevice: Signal<Never, NoError>
                        if let contactDataManager = context.sharedContext.contactDataManager {
                            deleteContactFromDevice = contactDataManager.deleteContactWithAppSpecificReference(peerId: peer.id)
                        } else {
                            deleteContactFromDevice = .complete()
                        }
                        
                        var deleteSignal = deleteContactPeerInteractively(account: context.account, peerId: peer.id)
                        |> then(deleteContactFromDevice)
                        
                        let progressSignal = Signal<Never, NoError> { subscriber in
                            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                            let controller = OverlayStatusController(theme: presentationData.theme, strings: presentationData.strings, type: .loading(cancelled: nil))
                            presentControllerImpl?(controller, nil)
                            return ActionDisposable { [weak controller] in
                                Queue.mainQueue().async() {
                                    controller?.dismiss()
                                }
                            }
                        }
                        |> runOn(Queue.mainQueue())
                        |> delay(0.15, queue: Queue.mainQueue())
                        let progressDisposable = progressSignal.start()
                        
                        deleteSignal = deleteSignal
                        |> afterDisposed {
                            Queue.mainQueue().async {
                                progressDisposable.dispose()
                            }
                        }
                        
                        updatePeerBlockedDisposable.set((deleteSignal
                        |> deliverOnMainQueue).start(completed: {
                            dismissImpl?()
                        }))
                    })
                })
            ]),
            ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { dismissAction() })])
            ])
        presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
    }, displayUsernameContextMenu: { text in
        let shareController = ShareController(context: context, subject: .url("\(text)"))
        presentControllerImpl?(shareController, nil)
    }, displayCopyContextMenu: { tag, phone in
        displayCopyContextMenuImpl?(tag, phone)
    }, call: {
        requestCallImpl()
    }, openCallMenu: { number in
        let _ = (getUserPeer(postbox: context.account.postbox, peerId: peerId)
        |> deliverOnMainQueue).start(next: { peer, _ in
            if let peer = peer as? TelegramUser, let peerPhoneNumber = peer.phone, formatPhoneNumber(number) == formatPhoneNumber(peerPhoneNumber) {
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                let controller = ActionSheetController(presentationTheme: presentationData.theme)
                let dismissAction: () -> Void = { [weak controller] in
                    controller?.dismissAnimated()
                }
                controller.setItemGroups([
                    ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(title: presentationData.strings.UserInfo_TelegramCall, action: {
                            dismissAction()
                            requestCallImpl()
                        }),
                        ActionSheetButtonItem(title: presentationData.strings.UserInfo_PhoneCall, action: {
                            dismissAction()
                            context.sharedContext.applicationBindings.openUrl("tel:\(formatPhoneNumber(number).replacingOccurrences(of: " ", with: ""))")
                        }),
                    ]),
                    ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { dismissAction() })])
                    ])
                presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
            } else {
                context.sharedContext.applicationBindings.openUrl("tel:\(formatPhoneNumber(number).replacingOccurrences(of: " ", with: ""))")
            }
        })
    }, requestPhoneNumber: {
        let _ = (requestPhoneNumber(account: context.account, peerId: peerId)
        |> deliverOnMainQueue).start(completed: {
            
        })
    }, aboutLinkAction: { action, itemLink in
        aboutLinkActionImpl?(action, itemLink)
    }, displayAboutContextMenu: { text in
        displayAboutContextMenuImpl?(text)
    }, openEncryptionKey: { fingerprint in
        let _ = (context.account.postbox.transaction { transaction -> Peer? in
            if let peer = transaction.getPeer(peerId) as? TelegramSecretChat {
                if let userPeer = transaction.getPeer(peer.regularPeerId) {
                    return userPeer
                }
            }
            return nil
        } |> deliverOnMainQueue).start(next: { peer in
            if let peer = peer {
                pushControllerImpl?(SecretChatKeyController(context: context, fingerprint: fingerprint, peer: peer))
            }
        })
    }, addBotToGroup: {
        botAddToGroupImpl?()
    }, shareBot: {
        shareBotImpl?()
    }, botSettings: {
        let _ = (context.account.postbox.loadedPeerWithId(peerId)
        |> deliverOnMainQueue).start(next: { peer in
            let _ = enqueueMessages(account: context.account, peerId: peer.id, messages: [.message(text: "/settings", attributes: [], mediaReference: nil, replyToMessageId: nil, localGroupingKey: nil)]).start()
            openChatImpl?()
        })
    }, botHelp: {
        let _ = (context.account.postbox.loadedPeerWithId(peerId)
        |> deliverOnMainQueue).start(next: { peer in
            let _ = enqueueMessages(account: context.account, peerId: peer.id, messages: [.message(text: "/help", attributes: [], mediaReference: nil, replyToMessageId: nil, localGroupingKey: nil)]).start()
            openChatImpl?()
        })
    }, botPrivacy: {
        let _ = (context.account.postbox.loadedPeerWithId(peerId)
            |> deliverOnMainQueue).start(next: { peer in
                let _ = enqueueMessages(account: context.account, peerId: peer.id, messages: [.message(text: "/privacy", attributes: [], mediaReference: nil, replyToMessageId: nil, localGroupingKey: nil)]).start()
                openChatImpl?()
            })
    }, report: {
        presentControllerImpl?(peerReportOptionsController(context: context, subject: .peer(peerId), present: { c, a in
            presentControllerImpl?(c, a)
        }, completion: { _ in }), nil)
    })
        
    let deviceContacts: Signal<[(DeviceContactStableId, DeviceContactBasicData)], NoError> = peerView.get()
    |> map { peerView -> String in
        if let peer = peerView.0.peers[peerId] as? TelegramUser {
            return peer.phone ?? ""
        }
        return ""
    }
    |> distinctUntilChanged
    |> mapToSignal { number -> Signal<[(DeviceContactStableId, DeviceContactBasicData)], NoError> in
        if number.isEmpty {
            return .single([])
        } else {
            return context.sharedContext.contactDataManager?.basicDataForNormalizedPhoneNumber(DeviceContactNormalizedPhoneNumber(rawValue: formatPhoneNumber(number))) ?? .single([])
        }
    }
    
    let globalNotificationsKey: PostboxViewKey = .preferences(keys: Set<ValueBoxKey>([PreferencesKeys.globalNotifications]))
    let signal = combineLatest(context.sharedContext.presentationData, statePromise.get(), peerView.get(), deviceContacts, context.account.postbox.combinedView(keys: [.peerChatState(peerId: peerId), globalNotificationsKey]))
    |> map { presentationData, state, view, deviceContacts, combinedView -> (ItemListControllerState, (ItemListNodeState<UserInfoEntry>, UserInfoEntry.ItemGenerationArguments)) in
        let peer = peerViewMainPeer(view.0)
        
        var globalNotificationSettings: GlobalNotificationSettings = .defaultSettings
        if let preferencesView = combinedView.views[globalNotificationsKey] as? PreferencesView {
            if let settings = preferencesView.values[PreferencesKeys.globalNotifications] as? GlobalNotificationSettings {
                globalNotificationSettings = settings
            }
        }
        
        if let peer = peer {
            let _ = cachedAvatarEntries.modify { value in
                if value != nil {
                    return value
                } else {
                    let promise = Promise<[AvatarGalleryEntry]>()
                    promise.set(fetchedAvatarGalleryEntries(account: context.account, peer: peer))
                    return promise
                }
            }
        }
        var leftNavigationButton: ItemListNavigationButton?
        let rightNavigationButton: ItemListNavigationButton
        if let editingState = state.editingState {
            leftNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Cancel), style: .regular, enabled: true, action: {
                updateState {
                    $0.withUpdatedEditingState(nil)
                }
            })
            
            var doneEnabled = true
            if let editingName = editingState.editingName, editingName.isEmpty {
                doneEnabled = false
            }
            
            if state.savingData {
                rightNavigationButton = ItemListNavigationButton(content: .none, style: .activity, enabled: doneEnabled, action: {})
            } else {
                rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Done), style: .bold, enabled: doneEnabled, action: {
                    var updateName: ItemListAvatarAndNameInfoItemName?
                    updateState { state in
                        if let editingState = state.editingState, let editingName = editingState.editingName {
                            if let user = peer {
                                if ItemListAvatarAndNameInfoItemName(user) != editingName {
                                    updateName = editingName
                                }
                            }
                        }
                        if updateName != nil {
                            return state.withUpdatedSavingData(true)
                        } else {
                            return state.withUpdatedEditingState(nil)
                        }
                    }
                    
                    if let updateName = updateName, case let .personName(firstName, lastName) = updateName {
                        updatePeerNameDisposable.set((updateContactName(account: context.account, peerId: peerId, firstName: firstName, lastName: lastName)
                        |> deliverOnMainQueue).start(error: { _ in
                            updateState { state in
                                return state.withUpdatedSavingData(false)
                            }
                        }, completed: {
                            updateState { state in
                                return state.withUpdatedSavingData(false).withUpdatedEditingState(nil)
                            }
                            
                            let _ = (getUserPeer(postbox: context.account.postbox, peerId: peerId)
                            |> mapToSignal { peer, _ -> Signal<Void, NoError> in
                                guard let peer = peer as? TelegramUser, let phone = peer.phone, !phone.isEmpty else {
                                    return .complete()
                                }
                                return (context.sharedContext.contactDataManager?.basicDataForNormalizedPhoneNumber(DeviceContactNormalizedPhoneNumber(rawValue: formatPhoneNumber(phone))) ?? .single([]))
                                |> take(1)
                                |> mapToSignal { records -> Signal<Void, NoError> in
                                    var signals: [Signal<DeviceContactExtendedData?, NoError>] = []
                                    if let contactDataManager = context.sharedContext.contactDataManager {
                                        for (id, basicData) in records {
                                            signals.append(contactDataManager.appendContactData(DeviceContactExtendedData(basicData: DeviceContactBasicData(firstName: firstName, lastName: lastName, phoneNumbers: basicData.phoneNumbers), middleName: "", prefix: "", suffix: "", organization: "", jobTitle: "", department: "", emailAddresses: [], urls: [], addresses: [], birthdayDate: nil, socialProfiles: [], instantMessagingProfiles: []), to: id))
                                        }
                                    }
                                    return combineLatest(signals)
                                    |> mapToSignal { _ -> Signal<Void, NoError> in
                                        return .complete()
                                    }
                                }
                            }).start()
                        }))
                    }
                })
            }
        } else {
            rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Edit), style: .regular, enabled: true, action: {
                if let user = peer {
                    updateState { state in
                        return state.withUpdatedEditingState(UserInfoEditingState(editingName: ItemListAvatarAndNameInfoItemName(user)))
                    }
                }
            })
        }
        
        let controllerState = ItemListControllerState(theme: presentationData.theme, title: .text(presentationData.strings.UserInfo_Title), leftNavigationButton: leftNavigationButton, rightNavigationButton: rightNavigationButton, backNavigationButton: nil)
        let listState = ItemListNodeState(entries: userInfoEntries(account: context.account, presentationData: presentationData, view: view.0, cachedPeerData: view.1, deviceContacts: deviceContacts, mode: mode, state: state, peerChatState: (combinedView.views[.peerChatState(peerId: peerId)] as? PeerChatStateView)?.chatState, globalNotificationSettings: globalNotificationSettings), style: .plain)
        
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
        actionsDisposable.dispose()
    }
    
    let controller = ItemListController(context: context, state: signal)
    
    pushControllerImpl = { [weak controller] value in
        (controller?.navigationController as? NavigationController)?.pushViewController(value)
    }
    dismissImpl = { [weak controller] in
        guard let controller = controller else {
            return
        }
        (controller.navigationController as? NavigationController)?.filterController(controller, animated: true)
    }
    presentControllerImpl = { [weak controller] value, presentationArguments in
        controller?.present(value, in: .window(.root), with: presentationArguments, blockInteraction: true)
    }
    dismissInputImpl = { [weak controller] in
        controller?.view.endEditing(true)
    }
    openChatImpl = { [weak controller] in
        if let navigationController = (controller?.navigationController as? NavigationController) {
            context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peerId)))
        }
    }
    shareContactImpl = { [weak controller] in
        let _ = (getUserPeer(postbox: context.account.postbox, peerId: peerId)
        |> deliverOnMainQueue).start(next: { peer, _ in
            if let peer = peer as? TelegramUser, let phone = peer.phone {
                let contact = TelegramMediaContact(firstName: peer.firstName ?? "", lastName: peer.lastName ?? "", phoneNumber: phone, peerId: peer.id, vCardData: nil)
                let shareController = ShareController(context: context, subject: .media(.standalone(media: contact)))
                controller?.present(shareController, in: .window(.root))
            }
        })
    }
    shareMyContactImpl = { [weak controller] in
        let _ = (getUserPeer(postbox: context.account.postbox, peerId: context.account.peerId)
            |> deliverOnMainQueue).start(next: { peer, _ in
                guard let peer = peer as? TelegramUser, let phone = peer.phone else {
                    return
                }
                let contact = TelegramMediaContact(firstName: peer.firstName ?? "", lastName: peer.lastName ?? "", phoneNumber: phone, peerId: peer.id, vCardData: nil)
                
                let _ = (enqueueMessages(account: context.account, peerId: peerId, messages: [.message(text: "", attributes: [], mediaReference: .standalone(media: contact), replyToMessageId: nil, localGroupingKey: nil)])
                    |> deliverOnMainQueue).start(next: { [weak controller] _ in
                        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                        controller?.present(OverlayStatusController(theme: presentationData.theme, strings: presentationData.strings, type: .success), in: .window(.root))
                    })
        })
    }
    startSecretChatImpl = { [weak controller] in
        let _ = (context.account.postbox.transaction { transaction -> PeerId? in
            let filteredPeerIds = Array(transaction.getAssociatedPeerIds(peerId)).filter { $0.namespace == Namespaces.Peer.SecretChat }
            var activeIndices: [ChatListIndex] = []
            for associatedId in filteredPeerIds {
                if let state = (transaction.getPeer(associatedId) as? TelegramSecretChat)?.embeddedState {
                    switch state {
                        case .active, .handshake:
                            if let (_, index) = transaction.getPeerChatListIndex(associatedId) {
                                activeIndices.append(index)
                            }
                        default:
                            break
                    }
                }
            }
            activeIndices.sort()
            if let index = activeIndices.last {
                return index.messageIndex.id.peerId
            } else {
                return nil
            }
        } |> deliverOnMainQueue).start(next: { currentPeerId in
            if let currentPeerId = currentPeerId {
                if let navigationController = (controller?.navigationController as? NavigationController) {
                    context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(currentPeerId)))
                }
            } else {
                var createSignal = createSecretChat(account: context.account, peerId: peerId)
                var cancelImpl: (() -> Void)?
                let progressSignal = Signal<Never, NoError> { subscriber in
                    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                    let controller = OverlayStatusController(theme: presentationData.theme, strings: presentationData.strings, type: .loading(cancelled: {
                        cancelImpl?()
                    }))
                    presentControllerImpl?(controller, nil)
                    return ActionDisposable { [weak controller] in
                        Queue.mainQueue().async() {
                            controller?.dismiss()
                        }
                    }
                }
                |> runOn(Queue.mainQueue())
                |> delay(0.15, queue: Queue.mainQueue())
                let progressDisposable = progressSignal.start()
                
                createSignal = createSignal
                |> afterDisposed {
                    Queue.mainQueue().async {
                        progressDisposable.dispose()
                    }
                }
                cancelImpl = {
                    createSecretChatDisposable.set(nil)
                }
                
                createSecretChatDisposable.set((createSignal |> deliverOnMainQueue).start(next: { peerId in
                    if let navigationController = (controller?.navigationController as? NavigationController) {
                        context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peerId)))
                    }
                }, error: { _ in
                    if let controller = controller {
                        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                        controller.present(textAlertController(context: context, title: nil, text: presentationData.strings.Login_UnknownError, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                    }
                }))
            }
        })
    }
    botAddToGroupImpl = { [weak controller] in
        guard let controller = controller else {
            return
        }
        context.sharedContext.openResolvedUrl(.groupBotStart(peerId: peerId, payload: ""), context: context, urlContext: .generic, navigationController: controller.navigationController as? NavigationController, openPeer: { id, navigation in
            
        }, sendFile: nil,
        sendSticker: nil,
        present: { c, a in
            presentControllerImpl?(c, a)
        }, dismissInput: {
            dismissInputImpl?()
        })
    }
    shareBotImpl = { [weak controller] in
        let _ = (getUserPeer(postbox: context.account.postbox, peerId: peerId)
            |> deliverOnMainQueue).start(next: { peer, _ in
                if let peer = peer as? TelegramUser, let username = peer.username {
                    let shareController = ShareController(context: context, subject: .url("https://t.me/\(username)"))
                    controller?.present(shareController, in: .window(.root))
                }
            })
    }
    avatarGalleryTransitionArguments = { [weak controller] entry in
        if let controller = controller {
            var result: ((ASDisplayNode, () -> (UIView?, UIView?)), CGRect)?
            controller.forEachItemNode { itemNode in
                if let itemNode = itemNode as? ItemListAvatarAndNameInfoItemNode {
                    result = itemNode.avatarTransitionNode()
                }
            }
            if let (node, _) = result {
                return GalleryTransitionArguments(transitionNode: node, addToTransitionSurface: { _ in
                })
            }
        }
        return nil
    }
    updateHiddenAvatarImpl = { [weak controller] in
        if let controller = controller {
            controller.forEachItemNode { itemNode in
                if let itemNode = itemNode as? ItemListAvatarAndNameInfoItemNode {
                    itemNode.updateAvatarHidden()
                }
            }
        }
    }
    aboutLinkActionImpl = { [weak context, weak controller] action, itemLink in
        if let controller = controller, let context = context {
            context.sharedContext.handleTextLinkAction(context: context, peerId: peerId, navigateDisposable: navigateDisposable, controller: controller, action: action, itemLink: itemLink)
        }
    }
    displayAboutContextMenuImpl = { [weak controller] text in
        if let strongController = controller {
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            var resultItemNode: ListViewItemNode?
            let _ = strongController.frameForItemNode({ itemNode in
                if let itemNode = itemNode as? ItemListTextWithLabelItemNode {
                    if let tag = itemNode.tag as? UserInfoEntryTag {
                        if tag == .about {
                            resultItemNode = itemNode
                            return true
                        }
                    }
                }
                return false
            })
            if let resultItemNode = resultItemNode {
                let contextMenuController = ContextMenuController(actions: [ContextMenuAction(content: .text(title: presentationData.strings.Conversation_ContextMenuCopy, accessibilityLabel: presentationData.strings.Conversation_ContextMenuCopy), action: {
                    UIPasteboard.general.string = text
                })])
                strongController.present(contextMenuController, in: .window(.root), with: ContextMenuControllerPresentationArguments(sourceNodeAndRect: { [weak resultItemNode] in
                    if let strongController = controller, let resultItemNode = resultItemNode {
                        return (resultItemNode, resultItemNode.contentBounds.insetBy(dx: 0.0, dy: -2.0), strongController.displayNode, strongController.view.bounds)
                    } else {
                        return nil
                    }
                }))
                
            }
        }
    }
    
    displayCopyContextMenuImpl = { [weak controller] tag, value in
        if let strongController = controller {
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            var resultItemNode: ListViewItemNode?
            let _ = strongController.frameForItemNode({ itemNode in
                if let itemNode = itemNode as? ItemListTextWithLabelItemNode {
                    if let itemTag = itemNode.tag as? UserInfoEntryTag {
                        if itemTag == tag && itemNode.item?.text == value {
                            resultItemNode = itemNode
                            return true
                        }
                    }
                }
                return false
            })
            if let resultItemNode = resultItemNode {
                let contextMenuController = ContextMenuController(actions: [ContextMenuAction(content: .text(title: presentationData.strings.Conversation_ContextMenuCopy, accessibilityLabel: presentationData.strings.Conversation_ContextMenuCopy), action: {
                    UIPasteboard.general.string = value
                })])
                strongController.present(contextMenuController, in: .window(.root), with: ContextMenuControllerPresentationArguments(sourceNodeAndRect: { [weak resultItemNode] in
                    if let strongController = controller, let resultItemNode = resultItemNode {
                        return (resultItemNode, resultItemNode.contentBounds.insetBy(dx: 0.0, dy: -2.0), strongController.displayNode, strongController.view.bounds)
                    } else {
                        return nil
                    }
                }))
            }
        }
    }
    
    popToRootImpl = { [weak controller] in
        (controller?.navigationController as? NavigationController)?.popToRoot(animated: true)
    }
    
    controller.didAppear = { [weak controller] firstTime in
        guard let controller = controller, firstTime else {
            return
        }
        
        var resultItemNode: ItemListAvatarAndNameInfoItemNode?
        let _ = controller.frameForItemNode({ itemNode in
            if let itemNode = itemNode as? ItemListAvatarAndNameInfoItemNode {
                resultItemNode = itemNode
                return true
            }
            return false
        })
        if let resultItemNode = resultItemNode, let callButtonFrame = resultItemNode.callButtonFrame {
            let _ = (ApplicationSpecificNotice.getProfileCallTips(accountManager: context.sharedContext.accountManager)
            |> deliverOnMainQueue).start(next: { [weak controller] counter in
                guard let controller = controller else {
                    return
                }
                
                var displayTip = false
                if counter == 0 {
                    displayTip = true
                } else if counter < 3 && arc4random_uniform(4) == 1 {
                    displayTip = true
                }
                if !displayTip {
                    return
                }
                let _ = ApplicationSpecificNotice.incrementProfileCallTips(accountManager: context.sharedContext.accountManager).start()
            
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                let text: String = presentationData.strings.UserInfo_TapToCall
                
                let tooltipController = TooltipController(content: .text(text), dismissByTapOutside: true)
                tooltipController.dismissed = {
                }
                controller.present(tooltipController, in: .window(.root), with: TooltipControllerPresentationArguments(sourceNodeAndRect: { [weak resultItemNode] in
                    if let resultItemNode = resultItemNode {
                        return (resultItemNode, callButtonFrame)
                    }
                    return nil
                }))
            })
        }
    }
    
    controller.navigationItem.backBarButtonItem = UIBarButtonItem(title: context.sharedContext.currentPresentationData.with{ $0 }.strings.Common_Back, style: .plain, target: nil, action: nil)
    
    return controller
}
