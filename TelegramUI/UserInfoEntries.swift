import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit
import Display

private enum UserInfoSection: UInt32, PeerInfoSection {
    case info
    case actions
    case sharedMediaAndNotifications
    case block
    
    func isEqual(to: PeerInfoSection) -> Bool {
        guard let section = to as? UserInfoSection else {
            return false
        }
        return section == self
    }
    
    func isOrderedBefore(_ section: PeerInfoSection) -> Bool {
        guard let section = section as? UserInfoSection else {
            return false
        }
        return self.rawValue < section.rawValue
    }
}

enum DestructiveUserInfoAction {
    case block
    case removeContact
}

enum UserInfoEntry: PeerInfoEntry {
    case info(peer: Peer?, cachedData: CachedPeerData?, editingState: PeerInfoAvatarAndNameItemEditingState?)
    case about(text: String)
    case phoneNumber(index: Int, value: PhoneNumberWithLabel)
    case userName(value: String)
    case sendMessage
    case shareContact
    case startSecretChat
    case sharedMedia
    case notifications(settings: PeerNotificationSettings?)
    case notificationSound(settings: PeerNotificationSettings?)
    case block(action: DestructiveUserInfoAction)
    
    var section: PeerInfoSection {
        switch self {
            case .info, .about, .phoneNumber, .userName:
                return UserInfoSection.info
            case .sendMessage, .shareContact, .startSecretChat:
                return UserInfoSection.actions
            case .sharedMedia, .notifications, .notificationSound:
                return UserInfoSection.sharedMediaAndNotifications
            case .block:
                return UserInfoSection.block
        }
    }
    
    var stableId: PeerInfoEntryStableId {
        return IntPeerInfoEntryStableId(value: self.sortIndex)
    }
    
    func isEqual(to: PeerInfoEntry) -> Bool {
        guard let entry = to as? UserInfoEntry else {
            return false
        }
        
        switch self {
            case let .info(lhsPeer, lhsCachedData, lhsEditingState):
                switch entry {
                    case let .info(rhsPeer, rhsCachedData, rhsEditingState):
                        if let lhsPeer = lhsPeer, let rhsPeer = rhsPeer {
                            if !lhsPeer.isEqual(rhsPeer) {
                                return false
                            }
                        } else if (lhsPeer == nil) != (rhsPeer != nil) {
                            return false
                        }
                        if let lhsCachedData = lhsCachedData, let rhsCachedData = rhsCachedData {
                            if !lhsCachedData.isEqual(to: rhsCachedData) {
                                return false
                            }
                        } else if (lhsCachedData != nil) != (rhsCachedData != nil) {
                            return false
                        }
                        if lhsEditingState != rhsEditingState {
                            return false
                        }
                        return true
                    default:
                        return false
                }
            case let .about(lhsText):
                switch entry {
                    case let .about(lhsText):
                        return true
                    default:
                        return false
                }
            case let .phoneNumber(lhsIndex, lhsValue):
                switch entry {
                    case let .phoneNumber(rhsIndex, rhsValue) where lhsIndex == rhsIndex && lhsValue == rhsValue:
                        return true
                    default:
                        return false
                }
            case let .userName(value):
                switch entry {
                    case .userName(value):
                        return true
                    default:
                        return false
                }
            case .sendMessage:
                switch entry {
                    case .sendMessage:
                        return true
                    default:
                        return false
                }
            case .shareContact:
                switch entry {
                    case .shareContact:
                        return true
                    default:
                        return false
                }
            case .startSecretChat:
                switch entry {
                    case .startSecretChat:
                        return true
                    default:
                        return false
                }
            case .sharedMedia:
                switch entry {
                    case .sharedMedia:
                        return true
                    default:
                        return false
                }
            case let .notifications(lhsSettings):
                switch entry {
                    case let .notifications(rhsSettings):
                        if let lhsSettings = lhsSettings, let rhsSettings = rhsSettings {
                            return lhsSettings.isEqual(to: rhsSettings)
                        } else if (lhsSettings != nil) != (rhsSettings != nil) {
                            return false
                        }
                        return true
                    default:
                        return false
                }
            case let .notificationSound(lhsSettings):
                switch entry {
                case let .notificationSound(rhsSettings):
                    if let lhsSettings = lhsSettings, let rhsSettings = rhsSettings {
                        return lhsSettings.isEqual(to: rhsSettings)
                    } else if (lhsSettings != nil) != (rhsSettings != nil) {
                        return false
                    }
                    return true
                default:
                    return false
                }
            case let .block(action):
                switch entry {
                    case .block(action):
                        return true
                    default:
                        return false
                }
            }
    }
    
    private var sortIndex: Int {
        switch self {
            case .info:
                return 0
            case .about:
                return 1
            case let .phoneNumber(index, _):
                return 2 + index
            case .userName:
                return 1000
            case .sendMessage:
                return 1001
            case .shareContact:
                return 1002
            case .startSecretChat:
                return 1003
            case .sharedMedia:
                return 1004
            case .notifications:
                return 1005
            case .notificationSound:
                return 1006
            case .block:
                return 1007
        }
    }
    
    func isOrderedBefore(_ entry: PeerInfoEntry) -> Bool {
        guard let other = entry as? UserInfoEntry else {
            return false
        }
        
        return self.sortIndex < other.sortIndex
    }
    
    func item(account: Account, interaction: PeerInfoControllerInteraction) -> ListViewItem {
        switch self {
            case let .info(peer, cachedData, editingState):
                return PeerInfoAvatarAndNameItem(account: account, peer: peer, cachedData: cachedData, editingState: editingState, sectionId: self.section.rawValue, style: .plain)
            case let .about(text):
                return PeerInfoTextWithLabelItem(label: "about", text: text, multiline: true, sectionId: self.section.rawValue)
            case let .phoneNumber(_, value):
                return PeerInfoTextWithLabelItem(label: value.label, text: formatPhoneNumber(value.number), multiline: false, sectionId: self.section.rawValue)
            case let .userName(value):
                return PeerInfoTextWithLabelItem(label: "username", text: "@\(value)", multiline: false, sectionId: self.section.rawValue)
            case .sendMessage:
                return PeerInfoActionItem(title: "Send Message", kind: .generic, alignment: .natural, sectionId: self.section.rawValue, style: .plain, action: {
                    
                })
            case .shareContact:
                return PeerInfoActionItem(title: "Share Contact", kind: .generic, alignment: .natural, sectionId: self.section.rawValue, style: .plain, action: {
                    
                })
            case .startSecretChat:
                return PeerInfoActionItem(title: "Start Secret Chat", kind: .generic, alignment: .natural, sectionId: self.section.rawValue, style: .plain, action: {
                    
                })
            case .sharedMedia:
                return PeerInfoDisclosureItem(title: "Shared Media", label: "", sectionId: self.section.rawValue, style: .plain, action: {
                    interaction.openSharedMedia()
                })
            case let .notifications(settings):
                let label: String
                if let settings = settings as? TelegramPeerNotificationSettings, case .muted = settings.muteState {
                    label = "Disabled"
                } else {
                    label = "Enabled"
                }
                return PeerInfoDisclosureItem(title: "Notifications", label: label, sectionId: self.section.rawValue, style: .plain, action: {
                    interaction.changeNotificationMuteSettings()
                })
            case let .notificationSound(settings):
                let label: String
                label = "Default"
                return PeerInfoDisclosureItem(title: "Sound", label: label, sectionId: self.section.rawValue, style: .plain, action: {
                })
            case let .block(action):
                let title: String
                switch action {
                    case .block:
                        title = "Block User"
                    case .removeContact:
                        title = "Remove Contact"
                }
                return PeerInfoActionItem(title: title, kind: .destructive, alignment: .natural, sectionId: self.section.rawValue, style: .plain, action: {
                    
                })
        }
    }
}

final class UserInfoEditingState: Equatable {
    let infoState = PeerInfoAvatarAndNameItemEditingState()
    
    static func ==(lhs: UserInfoEditingState, rhs: UserInfoEditingState) -> Bool {
        return true
    }
}

private final class UserInfoState: PeerInfoState {
    fileprivate let editingState: UserInfoEditingState?
    
    init(editingState: UserInfoEditingState?) {
        self.editingState = editingState
    }
    
    func isEqual(to: PeerInfoState) -> Bool {
        if let to = to as? UserInfoState {
            return self.editingState == to.editingState
        } else {
            return false
        }
    }
    
    func updateEditingState(_ editingState: UserInfoEditingState?) -> UserInfoState {
        return UserInfoState(editingState: editingState)
    }
}

func userInfoEntries(view: PeerView, state: PeerInfoState?) -> PeerInfoEntries {
    var entries: [PeerInfoEntry] = []
    
    var infoEditingState: PeerInfoAvatarAndNameItemEditingState?
    
    var isEditing = false
    if let state = state as? UserInfoState, let editingState = state.editingState {
        isEditing = true
        
        if view.peerIsContact {
            infoEditingState = editingState.infoState
        }
    }
    
    entries.append(UserInfoEntry.info(peer: view.peers[view.peerId], cachedData: view.cachedData, editingState: infoEditingState))
    if let cachedUserData = view.cachedData as? CachedUserData {
        if let about = cachedUserData.about, !about.isEmpty {
            entries.append(UserInfoEntry.about(text: about))
        }
    }
    
    var editable = true
    
    if let user = view.peers[view.peerId] as? TelegramUser {
        if let phoneNumber = user.phone, !phoneNumber.isEmpty {
            entries.append(UserInfoEntry.phoneNumber(index: 0, value: PhoneNumberWithLabel(label: "home", number: phoneNumber)))
        }
        
        if !isEditing {
            if let username = user.username, !username.isEmpty {
                entries.append(UserInfoEntry.userName(value: username))
            }
            entries.append(UserInfoEntry.sendMessage)
            if view.peerIsContact {
                entries.append(UserInfoEntry.shareContact)
            }
            entries.append(UserInfoEntry.startSecretChat)
            entries.append(UserInfoEntry.sharedMedia)
        }
        entries.append(UserInfoEntry.notifications(settings: view.notificationSettings))
        
        if isEditing {
            entries.append(UserInfoEntry.notificationSound(settings: view.notificationSettings))
            if view.peerIsContact {
                entries.append(UserInfoEntry.block(action: .removeContact))
            }
        } else {
            entries.append(UserInfoEntry.block(action: .block))
        }
    }
    
    var leftNavigationButton: PeerInfoNavigationButton?
    var rightNavigationButton: PeerInfoNavigationButton?
    if editable {
        if let state = state as? UserInfoState, let _ = state.editingState {
            leftNavigationButton = PeerInfoNavigationButton(title: "Cancel", action: { state in
                if state == nil {
                    return UserInfoState(editingState: nil)
                } else if let state = state as? UserInfoState {
                    return state.updateEditingState(nil)
                } else {
                    return state
                }
            })
            rightNavigationButton = PeerInfoNavigationButton(title: "Done", action: { state in
                if state == nil {
                    return UserInfoState(editingState: nil)
                } else if let state = state as? UserInfoState {
                    return state.updateEditingState(nil)
                } else {
                    return state
                }
            })
        } else {
            rightNavigationButton = PeerInfoNavigationButton(title: "Edit", action: { state in
                if state == nil {
                    return UserInfoState(editingState: UserInfoEditingState())
                } else if let state = state as? UserInfoState {
                    return state.updateEditingState(UserInfoEditingState())
                } else {
                    return state
                }
            })
        }
    }
    
    return PeerInfoEntries(entries: entries, leftNavigationButton: leftNavigationButton, rightNavigationButton: rightNavigationButton)
}
