import Foundation
import Display
import Postbox
import SwiftSignalKit
import TelegramCore

private enum UserInfoSection: UInt32 {
    case info
    case actions
    case sharedMediaAndNotifications
    case block
}

private enum UserInfoEntry: Comparable, Identifiable {
    case info(peer: Peer?, cachedData: CachedPeerData?)
    case about(text: String)
    case phoneNumber(index: Int, value: PhoneNumberWithLabel)
    case userName(value: String)
    case sendMessage
    case shareContact
    case startSecretChat
    case sharedMedia
    case notifications(settings: PeerNotificationSettings?)
    case block
    
    fileprivate var section: UserInfoSection {
        switch self {
            case .info, .about, .phoneNumber, .userName:
                return .info
            case .sendMessage, .shareContact, .startSecretChat:
                return .actions
            case .sharedMedia, .notifications:
                return .sharedMediaAndNotifications
            case .block:
                return .block
        }
    }
    
    fileprivate var stableId: Int {
        return self.sortIndex
    }
    
    fileprivate static func ==(lhs: UserInfoEntry, rhs: UserInfoEntry) -> Bool {
        switch lhs {
            case let .info(lhsPeer, lhsCachedData):
                switch rhs {
                    case let .info(rhsPeer, rhsCachedData):
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
                        } else if (rhsCachedData == nil) != (rhsCachedData != nil) {
                            return false
                        }
                        return true
                    default:
                        return false
                }
            case let .about(lhsText):
                switch rhs {
                    case let .about(lhsText):
                        return true
                    default:
                        return false
                }
            case let .phoneNumber(lhsIndex, lhsValue):
                switch rhs {
                    case let .phoneNumber(rhsIndex, rhsValue) where lhsIndex == rhsIndex && lhsValue == rhsValue:
                        return true
                    default:
                        return false
                }
            case let .userName(value):
                switch rhs {
                    case .userName(value):
                        return true
                    default:
                        return false
                }
            case .sendMessage:
                switch rhs {
                    case .sendMessage:
                        return true
                    default:
                        return false
                }
            case .shareContact:
                switch rhs {
                    case .shareContact:
                        return true
                    default:
                        return false
                }
            case .startSecretChat:
                switch rhs {
                    case .startSecretChat:
                        return true
                    default:
                        return false
                }
            case .sharedMedia:
                switch rhs {
                    case .sharedMedia:
                        return true
                    default:
                        return false
                }
            case let .notifications(lhsSettings):
                switch rhs {
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
            case .block:
                switch rhs {
                    case .block:
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
            case .block:
                return 1006
        }
    }
    
    fileprivate static func <(lhs: UserInfoEntry, rhs: UserInfoEntry) -> Bool {
        return lhs.sortIndex < rhs.sortIndex
    }
}

private func userInfoEntries(account: Account, peerId: PeerId) -> Signal<[UserInfoEntry], NoError> {
    return account.viewTracker.peerView(peerId)
        |> map { view -> [UserInfoEntry] in
            var entries: [UserInfoEntry] = []
            entries.append(.info(peer: view.peers[peerId], cachedData: view.cachedData))
            if let cachedUserData = view.cachedData as? CachedUserData {
                if let about = cachedUserData.about, !about.isEmpty {
                    entries.append(.about(text: about))
                }
            }
            if let user = view.peers[peerId] as? TelegramUser {
                if let phoneNumber = user.phone, !phoneNumber.isEmpty {
                    entries.append(.phoneNumber(index: 0, value: PhoneNumberWithLabel(label: "home", number: phoneNumber)))
                }
                if let username = user.username, !username.isEmpty {
                    entries.append(.userName(value: username))
                }
                entries.append(.sendMessage)
                entries.append(.shareContact)
                entries.append(.startSecretChat)
                entries.append(.sharedMedia)
                entries.append(.notifications(settings: view.notificationSettings))
                entries.append(.block)
            }
            return entries
        }
}

private struct UserInfoEntryTransition {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
}

private func infoItemForEntry(account: Account, entry: UserInfoEntry, interaction: PeerInfoControllerInteraction) -> ListViewItem {
    switch entry {
        case let .info(peer, cachedData):
            return PeerInfoAvatarAndNameItem(account: account, peer: peer, cachedData: cachedData, sectionId: entry.section.rawValue)
        case let .about(text):
            return PeerInfoTextWithLabelItem(label: "about", text: text, multiline: true, sectionId: entry.section.rawValue)
        case let .phoneNumber(_, value):
            return PeerInfoTextWithLabelItem(label: value.label, text: formatPhoneNumber(value.number), multiline: false, sectionId: entry.section.rawValue)
        case let .userName(value):
            return PeerInfoTextWithLabelItem(label: "username", text: "@\(value)", multiline: false, sectionId: entry.section.rawValue)
        case .sendMessage:
            return PeerInfoActionItem(title: "Send Message", kind: .generic, sectionId: entry.section.rawValue, action: {
                
            })
        case .shareContact:
            return PeerInfoActionItem(title: "Share Contact", kind: .generic, sectionId: entry.section.rawValue, action: {
                
            })
        case .startSecretChat:
            return PeerInfoActionItem(title: "Start Secret Chat", kind: .generic, sectionId: entry.section.rawValue, action: {
                
            })
        case .sharedMedia:
            return PeerInfoDisclosureItem(title: "Shared Media", label: "", sectionId: entry.section.rawValue, action: {
                interaction.openSharedMedia()
            })
        case let .notifications(settings):
            let label: String
            if let settings = settings as? TelegramPeerNotificationSettings, case .muted = settings.muteState {
                label = "Disabled"
            } else {
                label = "Enabled"
            }
            return PeerInfoDisclosureItem(title: "Notifications", label: label, sectionId: entry.section.rawValue, action: {
                interaction.changeNotificationNoteSettings()
            })
        case .block:
            return PeerInfoActionItem(title: "Block User", kind: .destructive, sectionId: entry.section.rawValue, action: {
                
            })
    }
}

private func preparedUserInfoEntryTransition(account: Account, from fromEntries: [UserInfoEntry], to toEntries: [UserInfoEntry], interaction: PeerInfoControllerInteraction) -> UserInfoEntryTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: infoItemForEntry(account: account, entry: $0.1, interaction: interaction), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: infoItemForEntry(account: account, entry: $0.1, interaction: interaction), directionHint: nil) }
    
    return UserInfoEntryTransition(deletions: deletions, insertions: insertions, updates: updates)
}

final class PeerInfoControllerInteraction {
    let openSharedMedia: () -> Void
    let changeNotificationNoteSettings: () -> Void
    
    init(openSharedMedia: @escaping () -> Void, changeNotificationNoteSettings: @escaping () -> Void) {
        self.openSharedMedia = openSharedMedia
        self.changeNotificationNoteSettings = changeNotificationNoteSettings
    }
}

public class UserInfoController: ListController {
    private let account: Account
    private let peerId: PeerId
    
    private var _ready = Promise<Bool>()
    override public var ready: Promise<Bool> {
        return self._ready
    }
    private var didSetReady = false
    
    private let transitionDisposable = MetaDisposable()
    private let changeSettingsDisposable = MetaDisposable()
    
    public init(account: Account, peerId: PeerId) {
        self.account = account
        self.peerId = peerId
        
        super.init()
        
        self.title = "Info"
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.transitionDisposable.dispose()
        self.changeSettingsDisposable.dispose()
    }
    
    override public func displayNodeDidLoad() {
        super.displayNodeDidLoad()
        
        let interaction = PeerInfoControllerInteraction(openSharedMedia: { [weak self] in
            if let strongSelf = self {
                if let controller = peerSharedMediaController(account: strongSelf.account, peerId: strongSelf.peerId) {
                    (strongSelf.navigationController as? NavigationController)?.pushViewController(controller)
                }
            }
        }, changeNotificationNoteSettings: { [weak self] in
            if let strongSelf = self {
                let controller = ActionSheetController()
                let dismissAction: () -> Void = { [weak controller] in
                    controller?.dismissAnimated()
                }
                let notificationAction: (Int32) -> Void = { [weak strongSelf] muteUntil in
                    if let strongSelf = strongSelf {
                        let muteState: PeerMuteState
                        if muteUntil <= 0 {
                            muteState = .unmuted
                        } else if muteUntil == Int32.max {
                            muteState = .muted(until: Int32.max)
                        } else {
                            muteState = .muted(until: Int32(Date().timeIntervalSince1970) + muteUntil)
                        }
                        strongSelf.changeSettingsDisposable.set(changePeerNotificationSettings(account: strongSelf.account, peerId: strongSelf.peerId, settings: TelegramPeerNotificationSettings(muteState: muteState, messageSound: PeerMessageSound.appDefault)).start())
                    }
                }
                controller.setItemGroups([
                    ActionSheetItemGroup(items: [
                        ActionSheetButtonItem(title: "Enable", action: {
                            dismissAction()
                            notificationAction(0)
                        }),
                        ActionSheetButtonItem(title: "Mute for 1 hour", action: {
                            dismissAction()
                            notificationAction(1 * 60 * 60)
                        }),
                        ActionSheetButtonItem(title: "Mute for 8 hours", action: {
                            dismissAction()
                            notificationAction(8 * 60 * 60)
                        }),
                        ActionSheetButtonItem(title: "Mute for 2 days", action: {
                            dismissAction()
                            notificationAction(2 * 24 * 60 * 60)
                        }),
                        ActionSheetButtonItem(title: "Disable", action: {
                            dismissAction()
                            notificationAction(Int32.max)
                        })
                        ]),
                    ActionSheetItemGroup(items: [ActionSheetButtonItem(title: "Cancel", action: { dismissAction() })])
                    ])
                strongSelf.present(controller, in: .window)
            }
        })
        
        self.listDisplayNode.backgroundColor = UIColor.white
        
        let previousEntries = Atomic<[UserInfoEntry]?>(value: nil)
        
        let account = self.account
        let transition = userInfoEntries(account: self.account, peerId: self.peerId)
            |> map { entries -> (UserInfoEntryTransition, Bool, Bool) in
                let previous = previousEntries.swap(entries)
                return (preparedUserInfoEntryTransition(account: account, from: previous ?? [], to: entries, interaction: interaction), previous == nil, previous != nil)
            }
            |> deliverOnMainQueue
        
        self.transitionDisposable.set(transition.start(next: { [weak self] (transition, firstTime, animated) in
            self?.enqueueTransition(transition, firstTime: firstTime, animated: animated)
        }))
    }
    
    private func enqueueTransition(_ transition: UserInfoEntryTransition, firstTime: Bool, animated: Bool) {
        var options = ListViewDeleteAndInsertOptions()
        if firstTime {
            options.insert(.Synchronous)
            options.insert(.LowLatency)
        } else if animated {
            options.insert(.AnimateInsertion)
        }
        self.listDisplayNode.listView.deleteAndInsertItems(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, completion: { [weak self] _ in
            if let strongSelf = self {
                if !strongSelf.didSetReady {
                    strongSelf.didSetReady = true
                    strongSelf._ready.set(.single(true))
                }
            }
        })
    }
}
