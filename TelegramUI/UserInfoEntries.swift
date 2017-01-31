import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit
import Display

private enum UserInfoSection: ItemListSectionId {
    case info
    case actions
    case sharedMediaAndNotifications
    case block
}

enum DestructiveUserInfoAction {
    case block
    case removeContact
}

enum UserInfoEntry: PeerInfoEntry {
    case info(peer: Peer?, cachedData: CachedPeerData?, state: ItemListAvatarAndNameInfoItemState)
    case about(text: String)
    case phoneNumber(index: Int, value: PhoneNumberWithLabel)
    case userName(value: String)
    case sendMessage
    case shareContact
    case startSecretChat
    case sharedMedia
    case notifications(settings: PeerNotificationSettings?)
    case notificationSound(settings: PeerNotificationSettings?)
    case secretEncryptionKey(SecretChatKeyFingerprint)
    case block(action: DestructiveUserInfoAction)
    
    var section: ItemListSectionId {
        switch self {
            case .info, .about, .phoneNumber, .userName:
                return UserInfoSection.info.rawValue
            case .sendMessage, .shareContact, .startSecretChat:
                return UserInfoSection.actions.rawValue
            case .sharedMedia, .notifications, .notificationSound, .secretEncryptionKey:
                return UserInfoSection.sharedMediaAndNotifications.rawValue
            case .block:
                return UserInfoSection.block.rawValue
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
            case let .info(lhsPeer, lhsCachedData, lhsState):
                switch entry {
                    case let .info(rhsPeer, rhsCachedData, rhsState):
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
                        if lhsState != rhsState {
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
            case let .secretEncryptionKey(fingerprint):
                if case .secretEncryptionKey(fingerprint) = entry {
                    return true
                } else {
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
            case .secretEncryptionKey:
                return 1007
            case .block:
                return 1008
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
            case let .info(peer, cachedData, state):
                return ItemListAvatarAndNameInfoItem(account: account, peer: peer, cachedData: cachedData, state: state, sectionId: self.section, style: .plain, editingNameUpdated: { editingName in
                    
                })
            case let .about(text):
                return ItemListTextWithLabelItem(label: "about", text: text, multiline: true, sectionId: self.section)
            case let .phoneNumber(_, value):
                return ItemListTextWithLabelItem(label: value.label, text: formatPhoneNumber(value.number), multiline: false, sectionId: self.section)
            case let .userName(value):
                return ItemListTextWithLabelItem(label: "username", text: "@\(value)", multiline: false, sectionId: self.section)
            case .sendMessage:
                return ItemListActionItem(title: "Send Message", kind: .generic, alignment: .natural, sectionId: self.section, style: .plain, action: {
                    
                })
            case .shareContact:
                return ItemListActionItem(title: "Share Contact", kind: .generic, alignment: .natural, sectionId: self.section, style: .plain, action: {
                    
                })
            case .startSecretChat:
                return ItemListActionItem(title: "Start Secret Chat", kind: .generic, alignment: .natural, sectionId: self.section, style: .plain, action: {
                    
                })
            case .sharedMedia:
                return ItemListDisclosureItem(title: "Shared Media", label: "", sectionId: self.section, style: .plain, action: {
                    interaction.openSharedMedia()
                })
            case let .notifications(settings):
                let label: String
                if let settings = settings as? TelegramPeerNotificationSettings, case .muted = settings.muteState {
                    label = "Disabled"
                } else {
                    label = "Enabled"
                }
                return ItemListDisclosureItem(title: "Notifications", label: label, sectionId: self.section, style: .plain, action: {
                    interaction.changeNotificationMuteSettings()
                })
            case let .notificationSound(settings):
                let label: String
                label = "Default"
                return ItemListDisclosureItem(title: "Sound", label: label, sectionId: self.section, style: .plain, action: {
                })
            case let .secretEncryptionKey(fingerprint):
                return ItemListDisclosureItem(title: "Encryption Key", label: "", sectionId: self.section, style: .plain, action: {
                })
            case let .block(action):
                let title: String
                switch action {
                    case .block:
                        title = "Block User"
                    case .removeContact:
                        title = "Remove Contact"
                }
                return ItemListActionItem(title: title, kind: .destructive, alignment: .natural, sectionId: self.section, style: .plain, action: {
                    
                })
        }
    }
}

struct UserInfoEditingState: Equatable {
    let editingName: ItemListAvatarAndNameInfoItemName
    
    static func ==(lhs: UserInfoEditingState, rhs: UserInfoEditingState) -> Bool {
        if lhs.editingName != rhs.editingName {
            return false
        }
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
    guard let peer = view.peers[view.peerId], let user = peerViewMainPeer(view) as? TelegramUser else {
        return PeerInfoEntries(entries: [], leftNavigationButton: nil, rightNavigationButton: nil)
    }
    
    var entries: [PeerInfoEntry] = []
    
    var editingName: ItemListAvatarAndNameInfoItemName?
    var updatingName: ItemListAvatarAndNameInfoItemName?
    
    var isEditing = false
    if let state = state as? UserInfoState, let editingState = state.editingState {
        isEditing = true
        
        if view.peerIsContact {
            editingName = editingState.editingName
        }
    }
    
    entries.append(UserInfoEntry.info(peer: user, cachedData: view.cachedData, state: ItemListAvatarAndNameInfoItemState(editingName: editingName, updatingName: updatingName)))
    if let cachedUserData = view.cachedData as? CachedUserData {
        if let about = cachedUserData.about, !about.isEmpty {
            entries.append(UserInfoEntry.about(text: about))
        }
    }
    
    var editable = true
    if peer is TelegramSecretChat {
        editable = false
    }
    
    if let phoneNumber = user.phone, !phoneNumber.isEmpty {
        entries.append(UserInfoEntry.phoneNumber(index: 0, value: PhoneNumberWithLabel(label: "home", number: phoneNumber)))
    }
    
    if !isEditing {
        if let username = user.username, !username.isEmpty {
            entries.append(UserInfoEntry.userName(value: username))
        }
        
        if !(peer is TelegramSecretChat) {
            entries.append(UserInfoEntry.sendMessage)
            if view.peerIsContact {
                entries.append(UserInfoEntry.shareContact)
            }
            entries.append(UserInfoEntry.startSecretChat)
        }
        entries.append(UserInfoEntry.sharedMedia)
    }
    entries.append(UserInfoEntry.notifications(settings: view.notificationSettings))
    
    if let peer = peer as? TelegramSecretChat {
        entries.append(UserInfoEntry.secretEncryptionKey(SecretChatKeyFingerprint(k0: 0, k1: 0, k2: 0, k3: 0)))
    }
    
    if isEditing {
        entries.append(UserInfoEntry.notificationSound(settings: view.notificationSettings))
        if view.peerIsContact {
            entries.append(UserInfoEntry.block(action: .removeContact))
        }
    } else {
        entries.append(UserInfoEntry.block(action: .block))
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
            let infoEditingName: ItemListAvatarAndNameInfoItemName
            if let peer = peerViewMainPeer(view) {
                infoEditingName = ItemListAvatarAndNameInfoItemName(peer.indexName)
            } else {
                infoEditingName = .personName(firstName: "", lastName: "")
            }
            rightNavigationButton = PeerInfoNavigationButton(title: "Edit", action: { state in
                if state == nil {
                    return UserInfoState(editingState: UserInfoEditingState(editingName: infoEditingName))
                } else if let state = state as? UserInfoState {
                    return state.updateEditingState(UserInfoEditingState(editingName: infoEditingName))
                } else {
                    return state
                }
            })
        }
    }
    
    return PeerInfoEntries(entries: entries, leftNavigationButton: leftNavigationButton, rightNavigationButton: rightNavigationButton)
}
