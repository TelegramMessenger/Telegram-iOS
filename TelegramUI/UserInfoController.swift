import Foundation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

private final class UserInfoControllerArguments {
    let account: Account
    let updateEditingName: (ItemListAvatarAndNameInfoItemName) -> Void
    let openChat: () -> Void
    let changeNotificationMuteSettings: () -> Void
    let openSharedMedia: () -> Void
    let openGroupsInCommon: () -> Void
    let updatePeerBlocked: (Bool) -> Void
    let deleteContact: () -> Void
    let displayUsernameContextMenu: (String) -> Void
    
    init(account: Account, updateEditingName: @escaping (ItemListAvatarAndNameInfoItemName) -> Void, openChat: @escaping () -> Void, changeNotificationMuteSettings: @escaping () -> Void, openSharedMedia: @escaping () -> Void, openGroupsInCommon: @escaping () -> Void, updatePeerBlocked: @escaping (Bool) -> Void, deleteContact: @escaping () -> Void, displayUsernameContextMenu: @escaping (String) -> Void) {
        self.account = account
        self.updateEditingName = updateEditingName
        self.openChat = openChat
        self.changeNotificationMuteSettings = changeNotificationMuteSettings
        self.openSharedMedia = openSharedMedia
        self.openGroupsInCommon = openGroupsInCommon
        self.updatePeerBlocked = updatePeerBlocked
        self.deleteContact = deleteContact
        self.displayUsernameContextMenu = displayUsernameContextMenu
    }
}

private enum UserInfoSection: ItemListSectionId {
    case info
    case actions
    case sharedMediaAndNotifications
    case block
}

private enum UserInfoEntryTag {
    case username
}

private enum UserInfoEntry: ItemListNodeEntry {
    case info(peer: Peer?, presence: PeerPresence?, cachedData: CachedPeerData?, state: ItemListAvatarAndNameInfoItemState)
    case about(text: String)
    case phoneNumber(index: Int, value: PhoneNumberWithLabel)
    case userName(value: String)
    case sendMessage
    case shareContact
    case startSecretChat
    case sharedMedia
    case notifications(settings: PeerNotificationSettings?)
    case notificationSound(settings: PeerNotificationSettings?)
    case groupsInCommon(Int32)
    case secretEncryptionKey(SecretChatKeyFingerprint)
    case block(action: DestructiveUserInfoAction)
    
    var section: ItemListSectionId {
        switch self {
            case .info, .about, .phoneNumber, .userName:
                return UserInfoSection.info.rawValue
            case .sendMessage, .shareContact, .startSecretChat:
                return UserInfoSection.actions.rawValue
            case .sharedMedia, .notifications, .notificationSound, .secretEncryptionKey, .groupsInCommon:
                return UserInfoSection.sharedMediaAndNotifications.rawValue
            case .block:
                return UserInfoSection.block.rawValue
        }
    }
    
    var stableId: Int {
        return self.sortIndex
    }
    
    static func ==(lhs: UserInfoEntry, rhs: UserInfoEntry) -> Bool {
        switch lhs {
            case let .info(lhsPeer, lhsPresence, lhsCachedData, lhsState):
                switch rhs {
                    case let .info(rhsPeer, rhsPresence, rhsCachedData, rhsState):
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
                        return true
                    default:
                        return false
                }
            case let .about(lhsText):
                switch rhs {
                    case .about(lhsText):
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
            case let .notificationSound(lhsSettings):
                switch rhs {
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
            case let .groupsInCommon(count):
                if case .groupsInCommon(count) = rhs {
                    return true
                } else {
                    return false
                }
            case let .secretEncryptionKey(fingerprint):
                if case .secretEncryptionKey(fingerprint) = rhs {
                    return true
                } else {
                    return false
                }
            case let .block(action):
                switch rhs {
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
            case .groupsInCommon:
                return 1007
            case .secretEncryptionKey:
                return 1008
            case .block:
                return 1009
        }
    }
    
    static func <(lhs: UserInfoEntry, rhs: UserInfoEntry) -> Bool {
        return lhs.sortIndex < rhs.sortIndex
    }
    
    func item(_ arguments: UserInfoControllerArguments) -> ListViewItem {
        switch self {
            case let .info(peer, presence, cachedData, state):
                return ItemListAvatarAndNameInfoItem(account: arguments.account, peer: peer, presence: presence, cachedData: cachedData, state: state, sectionId: self.section, style: .plain, editingNameUpdated: { editingName in
                    arguments.updateEditingName(editingName)
                })
            case let .about(text):
                return ItemListTextWithLabelItem(label: "about", text: text, multiline: true, sectionId: self.section, action: nil)
            case let .phoneNumber(_, value):
                return ItemListTextWithLabelItem(label: value.label, text: formatPhoneNumber(value.number), multiline: false, sectionId: self.section, action: {
                    
                })
            case let .userName(value):
                return ItemListTextWithLabelItem(label: "username", text: "@\(value)", multiline: false, sectionId: self.section, action: {
                    arguments.displayUsernameContextMenu("@" + value)
                }, tag: UserInfoEntryTag.username)
            case .sendMessage:
                return ItemListActionItem(title: "Send Message", kind: .generic, alignment: .natural, sectionId: self.section, style: .plain, action: {
                    arguments.openChat()
                })
            case .shareContact:
                return ItemListActionItem(title: "Share Contact", kind: .generic, alignment: .natural, sectionId: self.section, style: .plain, action: {
                    
                })
            case .startSecretChat:
                return ItemListActionItem(title: "Start Secret Chat", kind: .generic, alignment: .natural, sectionId: self.section, style: .plain, action: {
                    
                })
            case .sharedMedia:
                return ItemListDisclosureItem(title: "Shared Media", label: "", sectionId: self.section, style: .plain, action: {
                    arguments.openSharedMedia()
                })
            case let .notifications(settings):
                let label: String
                if let settings = settings as? TelegramPeerNotificationSettings, case .muted = settings.muteState {
                    label = "Disabled"
                } else {
                    label = "Enabled"
                }
                return ItemListDisclosureItem(title: "Notifications", label: label, sectionId: self.section, style: .plain, action: {
                    arguments.changeNotificationMuteSettings()
                })
            case let .notificationSound(settings):
                let label: String
                label = "Default"
                return ItemListDisclosureItem(title: "Sound", label: label, sectionId: self.section, style: .plain, action: {
                })
            case let .groupsInCommon(count):
                return ItemListDisclosureItem(title: "Groups in Common", label: "\(count)", sectionId: self.section, style: .plain, action: {
                    arguments.openGroupsInCommon()
                })
            case let .secretEncryptionKey(fingerprint):
                return ItemListDisclosureItem(title: "Encryption Key", label: "", sectionId: self.section, style: .plain, action: {
                })
            case let .block(action):
                let title: String
                switch action {
                    case .block:
                        title = "Block User"
                    case .unblock:
                        title = "Unblock User"
                    case .removeContact:
                        title = "Remove Contact"
                }
                return ItemListActionItem(title: title, kind: .destructive, alignment: .natural, sectionId: self.section, style: .plain, action: {
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

private func userInfoEntries(account: Account, view: PeerView, state: UserInfoState, peerChatState: Coding?) -> [UserInfoEntry] {
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
    
    entries.append(UserInfoEntry.info(peer: user, presence: view.peerPresences[user.id], cachedData: view.cachedData, state: ItemListAvatarAndNameInfoItemState(editingName: editingName, updatingName: nil)))
    if let cachedUserData = view.cachedData as? CachedUserData {
        if let about = cachedUserData.about, !about.isEmpty {
            entries.append(UserInfoEntry.about(text: about))
        }
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
    if let groupsInCommon = (view.cachedData as? CachedUserData)?.commonGroupCount, groupsInCommon != 0 && !isEditing {
        entries.append(UserInfoEntry.groupsInCommon(groupsInCommon))
    }
    
    if peer is TelegramSecretChat, let peerChatState = peerChatState as? SecretChatKeyState, let keyFingerprint = peerChatState.keyFingerprint {
        entries.append(UserInfoEntry.secretEncryptionKey(keyFingerprint))
    }
    
    if isEditing {
        entries.append(UserInfoEntry.notificationSound(settings: view.notificationSettings))
        if view.peerIsContact {
            entries.append(UserInfoEntry.block(action: .removeContact))
        }
    } else {
        if let cachedData = view.cachedData as? CachedUserData {
            if cachedData.isBlocked {
                entries.append(UserInfoEntry.block(action: .unblock))
            } else {
                entries.append(UserInfoEntry.block(action: .block))
            }
        }
    }
    
    return entries
}

public func userInfoController(account: Account, peerId: PeerId) -> ViewController {
    let statePromise = ValuePromise(UserInfoState(), ignoreRepeated: true)
    let stateValue = Atomic(value: UserInfoState())
    let updateState: ((UserInfoState) -> UserInfoState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var pushControllerImpl: ((ViewController) -> Void)?
    var presentControllerImpl: ((ViewController, ViewControllerPresentationArguments) -> Void)?
    var openChatImpl: (() -> Void)?
    var displayUsernameContextMenuImpl: ((String) -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    if peerId.namespace == Namespaces.Peer.CloudChannel {
        actionsDisposable.add(account.viewTracker.updatedCachedChannelParticipants(peerId, forceImmediateUpdate: true).start())
    }
    
    let updatePeerNameDisposable = MetaDisposable()
    actionsDisposable.add(updatePeerNameDisposable)
    
    let updatePeerBlockedDisposable = MetaDisposable()
    actionsDisposable.add(updatePeerBlockedDisposable)
    
    let changeMuteSettingsDisposable = MetaDisposable()
    actionsDisposable.add(changeMuteSettingsDisposable)
    
    let arguments = UserInfoControllerArguments(account: account, updateEditingName: { editingName in
        updateState { state in
            if let _ = state.editingState {
                return state.withUpdatedEditingState(UserInfoEditingState(editingName: editingName))
            } else {
                return state
            }
        }
    }, openChat: {
        openChatImpl?()
    }, changeNotificationMuteSettings: {
        let controller = ActionSheetController()
        let dismissAction: () -> Void = { [weak controller] in
            controller?.dismissAnimated()
        }
        let notificationAction: (Int32) -> Void = {  muteUntil in
            let muteState: PeerMuteState
            if muteUntil <= 0 {
                muteState = .unmuted
            } else if muteUntil == Int32.max {
                muteState = .muted(until: Int32.max)
            } else {
                muteState = .muted(until: Int32(Date().timeIntervalSince1970) + muteUntil)
            }
            changeMuteSettingsDisposable.set(changePeerNotificationSettings(account: account, peerId: peerId, settings: TelegramPeerNotificationSettings(muteState: muteState, messageSound: PeerMessageSound.bundledModern(id: 0))).start())
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
        presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
    }, openSharedMedia: {
        if let controller = peerSharedMediaController(account: account, peerId: peerId) {
            pushControllerImpl?(controller)
        }
    }, openGroupsInCommon: {
        pushControllerImpl?(groupsInCommonController(account: account, peerId: peerId))
    }, updatePeerBlocked: { value in
        updatePeerBlockedDisposable.set(requestUpdatePeerIsBlocked(account: account, peerId: peerId, isBlocked: value).start())
    }, deleteContact: {
        
    }, displayUsernameContextMenu: { text in
        displayUsernameContextMenuImpl?(text)
    })
    
    let signal = combineLatest(statePromise.get(), account.viewTracker.peerView(peerId), account.postbox.combinedView(keys: [.peerChatState(peerId: peerId)]))
        |> map { state, view, chatState -> (ItemListControllerState, (ItemListNodeState<UserInfoEntry>, UserInfoEntry.ItemGenerationArguments)) in
            let peer = peerViewMainPeer(view)
            var leftNavigationButton: ItemListNavigationButton?
            let rightNavigationButton: ItemListNavigationButton
            if let editingState = state.editingState {
                leftNavigationButton = ItemListNavigationButton(title: "Cancel", style: .regular, enabled: true, action: {
                    updateState {
                        $0.withUpdatedEditingState(nil)
                    }
                })
                
                var doneEnabled = true
                if let editingName = editingState.editingName, editingName.isEmpty {
                    doneEnabled = false
                }
                
                if state.savingData {
                    rightNavigationButton = ItemListNavigationButton(title: "", style: .activity, enabled: doneEnabled, action: {})
                } else {
                    rightNavigationButton = ItemListNavigationButton(title: "Done", style: .bold, enabled: doneEnabled, action: {
                        var updateName: ItemListAvatarAndNameInfoItemName?
                        updateState { state in
                            if let editingState = state.editingState, let editingName = editingState.editingName {
                                if let user = peer {
                                    if ItemListAvatarAndNameInfoItemName(user.indexName) != editingName {
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
                            updatePeerNameDisposable.set((updateContactName(account: account, peerId: peerId, firstName: firstName, lastName: lastName) |> deliverOnMainQueue).start(error: { _ in
                                updateState { state in
                                    return state.withUpdatedSavingData(false)
                                }
                            }, completed: {
                                updateState { state in
                                    return state.withUpdatedSavingData(false).withUpdatedEditingState(nil)
                                }
                            }))
                        }
                    })
                }
            } else {
                rightNavigationButton = ItemListNavigationButton(title: "Edit", style: .regular, enabled: true, action: {
                    if let user = peer {
                        updateState { state in
                            return state.withUpdatedEditingState(UserInfoEditingState(editingName: ItemListAvatarAndNameInfoItemName(user.indexName)))
                        }
                    }
                })
            }
            
            let controllerState = ItemListControllerState(title: "Info", leftNavigationButton: leftNavigationButton, rightNavigationButton: rightNavigationButton)
            let listState = ItemListNodeState(entries: userInfoEntries(account: account, view: view, state: state, peerChatState: (chatState.views[.peerChatState(peerId: peerId)] as? PeerChatStateView)?.chatState), style: .plain)
            
            return (controllerState, (listState, arguments))
        } |> afterDisposed {
            actionsDisposable.dispose()
    }
    
    let controller = ItemListController(signal)
    
    pushControllerImpl = { [weak controller] value in
        (controller?.navigationController as? NavigationController)?.pushViewController(value)
    }
    presentControllerImpl = { [weak controller] value, presentationArguments in
        controller?.present(value, in: .window, with: presentationArguments)
    }
    openChatImpl = { [weak controller] in
        if let navigationController = (controller?.navigationController as? NavigationController) {
            navigateToChatController(navigationController: navigationController, account: account, peerId: peerId)
        }
    }
    displayUsernameContextMenuImpl = { [weak controller] text in
        if let strongController = controller {
            var resultItemNode: ListViewItemNode?
            let _ = strongController.frameForItemNode({ itemNode in
                if let itemNode = itemNode as? ItemListTextWithLabelItemNode {
                    if let tag = itemNode.tag as? UserInfoEntryTag {
                        if tag == .username {
                            resultItemNode = itemNode
                            return true
                        }
                    }
                }
                return false
            })
            if let resultItemNode = resultItemNode {
                let contextMenuController = ContextMenuController(actions: [ContextMenuAction(content: .text("Copy"), action: {
                    UIPasteboard.general.string = text
                })])
                strongController.present(contextMenuController, in: .window, with: ContextMenuControllerPresentationArguments(sourceNodeAndRect: { [weak resultItemNode] in
                    if let resultItemNode = resultItemNode {
                        return (resultItemNode, resultItemNode.contentBounds.insetBy(dx: 0.0, dy: -2.0))
                    } else {
                        return nil
                    }
                }))
                
            }
        }
    }
    return controller
}
