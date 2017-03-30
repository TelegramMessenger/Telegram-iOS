import Foundation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

private final class ChannelInfoControllerArguments {
    let account: Account
    let updateEditingName: (ItemListAvatarAndNameInfoItemName) -> Void
    let updateEditingDescriptionText: (String) -> Void
    let openChannelTypeSetup: () -> Void
    let changeNotificationMuteSettings: () -> Void
    let openSharedMedia: () -> Void
    let openAdmins: () -> Void
    let openMembers: () -> Void
    let openBanned: () -> Void
    let reportChannel: () -> Void
    let leaveChannel: () -> Void
    let deleteChannel: () -> Void
    let displayAddressNameContextMenu: (String) -> Void
    
    init(account: Account, updateEditingName: @escaping (ItemListAvatarAndNameInfoItemName) -> Void, updateEditingDescriptionText: @escaping (String) -> Void, openChannelTypeSetup: @escaping () -> Void, changeNotificationMuteSettings: @escaping () -> Void, openSharedMedia: @escaping () -> Void, openAdmins: @escaping () -> Void, openMembers: @escaping () -> Void, openBanned: @escaping () -> Void, reportChannel: @escaping () -> Void, leaveChannel: @escaping () -> Void, deleteChannel: @escaping () -> Void, displayAddressNameContextMenu: @escaping (String) -> Void) {
        self.account = account
        self.updateEditingName = updateEditingName
        self.updateEditingDescriptionText = updateEditingDescriptionText
        self.openChannelTypeSetup = openChannelTypeSetup
        self.changeNotificationMuteSettings = changeNotificationMuteSettings
        self.openSharedMedia = openSharedMedia
        self.openAdmins = openAdmins
        self.openMembers = openMembers
        self.openBanned = openBanned
        self.reportChannel = reportChannel
        self.leaveChannel = leaveChannel
        self.deleteChannel = deleteChannel
        self.displayAddressNameContextMenu = displayAddressNameContextMenu
    }
}

private enum ChannelInfoSection: ItemListSectionId {
    case info
    case sharedMediaAndNotifications
    case members
    case reportOrLeave
}

private enum ChannelInfoEntryTag {
    case addressName
}

private enum ChannelInfoEntry: ItemListNodeEntry {
    case info(peer: Peer?, cachedData: CachedPeerData?, state: ItemListAvatarAndNameInfoItemState)
    case about(text: String)
    case addressName(value: String)
    case channelTypeSetup(isPublic: Bool)
    case channelDescriptionSetup(text: String)
    case admins(count: Int32)
    case members(count: Int32)
    case banned(count: Int32)
    case notifications(settings: PeerNotificationSettings)
    case sharedMedia
    case report
    case leave
    case deleteChannel
    
    var section: ItemListSectionId {
        switch self {
            case .info, .about, .addressName, .channelTypeSetup, .channelDescriptionSetup:
                return ChannelInfoSection.info.rawValue
            case .admins, .members, .banned:
                return ChannelInfoSection.members.rawValue
            case .sharedMedia, .notifications:
                return ChannelInfoSection.sharedMediaAndNotifications.rawValue
            case .report, .leave, .deleteChannel:
                return ChannelInfoSection.reportOrLeave.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
            case .info:
                return 0
            case .about:
                return 1
            case .addressName:
                return 2
            case .channelDescriptionSetup:
                return 3
            case .channelTypeSetup:
                return 4
            case .admins:
                return 5
            case .members:
                return 6
            case .banned:
                return 7
            case .notifications:
                return 8
            case .sharedMedia:
                return 9
            case .report:
                return 10
            case .leave:
                return 11
            case .deleteChannel:
                return 12
        }
    }
    
    static func ==(lhs: ChannelInfoEntry, rhs: ChannelInfoEntry) -> Bool {
        switch lhs {
            case let .info(lhsPeer, lhsCachedData, lhsState):
                if case let .info(rhsPeer, rhsCachedData, rhsState) = rhs {
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
                } else {
                    return false
                }
            case let .about(text):
                if case .about(text) = rhs {
                    return true
                } else {
                    return false
                }
            case let .addressName(value):
                if case .addressName(value) = rhs {
                    return true
                } else {
                    return false
                }
            case let .channelTypeSetup(isPublic):
                if case .channelTypeSetup(isPublic) = rhs {
                    return true
                } else {
                    return false
                }
            case let .channelDescriptionSetup(text):
                if case .channelDescriptionSetup(text) = rhs {
                    return true
                } else {
                    return false
                }
            case let .admins(count):
                if case .admins(count) = rhs {
                    return true
                } else {
                    return false
                }
            case let .members(count):
                if case .members(count) = rhs {
                    return true
                } else {
                    return false
                }
            case let .banned(count):
                if case .banned(count) = rhs {
                    return true
                } else {
                    return false
                }
            case .sharedMedia, .report, .leave, .deleteChannel:
                return lhs.stableId == rhs.stableId
            case let .notifications(lhsSettings):
                if case let .notifications(rhsSettings) = rhs {
                    return lhsSettings.isEqual(to: rhsSettings)
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: ChannelInfoEntry, rhs: ChannelInfoEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(_ arguments: ChannelInfoControllerArguments) -> ListViewItem {
        switch self {
            case let .info(peer, cachedData, state):
                return ItemListAvatarAndNameInfoItem(account: arguments.account, peer: peer, presence: nil, cachedData: cachedData, state: state, sectionId: self.section, style: .plain, editingNameUpdated: { editingName in
                    arguments.updateEditingName(editingName)
                })
            case let .about(text):
                return ItemListTextWithLabelItem(label: "about", text: text, multiline: true, sectionId: self.section, action: nil)
            case let .addressName(value):
                return ItemListTextWithLabelItem(label: "share link", text: "https://t.me/\(value)", multiline: false, sectionId: self.section, action: {
                    arguments.displayAddressNameContextMenu("https://t.me/\(value)")
                }, tag: ChannelInfoEntryTag.addressName)
            case let .channelTypeSetup(isPublic):
                return ItemListDisclosureItem(title: "Channel Type", label: isPublic ? "Public" : "Private", sectionId: self.section, style: .plain, action: {
                    arguments.openChannelTypeSetup()
                })
            case let .channelDescriptionSetup(text):
                return ItemListMultilineInputItem(text: text, placeholder: "Channel Description", sectionId: self.section, style: .plain, textUpdated: { updatedText in
                    arguments.updateEditingDescriptionText(updatedText)
                }, action: {
                    
                })
            case let .admins(count):
                return ItemListDisclosureItem(title: "Admins", label: "\(count)", sectionId: self.section, style: .plain, action: {
                    arguments.openAdmins()
                })
            case let .members(count):
                return ItemListDisclosureItem(title: "Members", label: "\(count)", sectionId: self.section, style: .plain, action: {
                    arguments.openMembers()
                })
            case let .banned(count):
                return ItemListDisclosureItem(title: "Blacklist", label: "\(count)", sectionId: self.section, style: .plain, action: {
                    arguments.openBanned()
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
            case .report:
                return ItemListActionItem(title: "Report", kind: .generic, alignment: .natural, sectionId: self.section, style: .plain, action: {
                    arguments.reportChannel()
                })
            case .leave:
                return ItemListActionItem(title: "Leave Channel", kind: .destructive, alignment: .natural, sectionId: self.section, style: .plain, action: {
                    arguments.leaveChannel()
                })
            case .deleteChannel:
                return ItemListActionItem(title: "Delete Channel", kind: .destructive, alignment: .natural, sectionId: self.section, style: .plain, action: {
                    arguments.deleteChannel()
                })
        }
    }
}

private struct ChannelInfoState: Equatable {
    let editingState: ChannelInfoEditingState?
    let savingData: Bool
    
    init(editingState: ChannelInfoEditingState?, savingData: Bool) {
        self.editingState = editingState
        self.savingData = savingData
    }
    
    init() {
        self.editingState = nil
        self.savingData = false
    }
    
    static func ==(lhs: ChannelInfoState, rhs: ChannelInfoState) -> Bool {
        if lhs.editingState != rhs.editingState {
            return false
        }
        if lhs.savingData != rhs.savingData {
            return false
        }
        return true
    }
    
    func withUpdatedEditingState(_ editingState: ChannelInfoEditingState?) -> ChannelInfoState {
        return ChannelInfoState(editingState: editingState, savingData: self.savingData)
    }
    
    func withUpdatedSavingData(_ savingData: Bool) -> ChannelInfoState {
        return ChannelInfoState(editingState: self.editingState, savingData: savingData)
    }
}

private struct ChannelInfoEditingState: Equatable {
    let editingName: ItemListAvatarAndNameInfoItemName?
    let editingDescriptionText: String
    
    func withUpdatedEditingDescriptionText(_ editingDescriptionText: String) -> ChannelInfoEditingState {
        return ChannelInfoEditingState(editingName: self.editingName, editingDescriptionText: editingDescriptionText)
    }
    
    static func ==(lhs: ChannelInfoEditingState, rhs: ChannelInfoEditingState) -> Bool {
        if lhs.editingName != rhs.editingName {
            return false
        }
        if lhs.editingDescriptionText != rhs.editingDescriptionText {
            return false
        }
        return true
    }
}

private func channelInfoEntries(account: Account, view: PeerView, state: ChannelInfoState) -> [ChannelInfoEntry] {
    var entries: [ChannelInfoEntry] = []
    
    if let peer = view.peers[view.peerId] as? TelegramChannel {
        var canManageChannel = false
        var canManageMembers = false
        let isPublic = peer.username != nil
        switch peer.role {
            case .creator:
                canManageChannel = true
                canManageMembers = true
            case .moderator:
                canManageMembers = true
            case .editor, .member:
                break
        }
        
        let infoState = ItemListAvatarAndNameInfoItemState(editingName: canManageChannel ? state.editingState?.editingName : nil, updatingName: nil)
        entries.append(.info(peer: peer, cachedData: view.cachedData, state: infoState))
        
        if let cachedChannelData = view.cachedData as? CachedChannelData {
            if let editingState = state.editingState, canManageChannel {
                entries.append(.channelDescriptionSetup(text: editingState.editingDescriptionText))
            } else {
                if let about = cachedChannelData.about, !about.isEmpty {
                    entries.append(.about(text: about))
                }
            }
        }
        
        if state.editingState != nil && canManageChannel {
            entries.append(.channelTypeSetup(isPublic: isPublic))
        } else if let username = peer.username, !username.isEmpty {
            entries.append(.addressName(value: username))
        }
        
        if let cachedChannelData = view.cachedData as? CachedChannelData {
            if state.editingState != nil && canManageMembers {
                if let bannedCount = cachedChannelData.participantsSummary.bannedCount {
                    entries.append(.banned(count: bannedCount))
                }
            } else if canManageMembers {
                if let adminCount = cachedChannelData.participantsSummary.adminCount {
                    entries.append(.admins(count: adminCount))
                }
                if let memberCount = cachedChannelData.participantsSummary.memberCount {
                    entries.append(.members(count: memberCount))
                }
            }
        }
        
        if let notificationSettings = view.notificationSettings {
            entries.append(ChannelInfoEntry.notifications(settings: notificationSettings))
        }
        entries.append(ChannelInfoEntry.sharedMedia)
        
        if peer.role == .creator {
            if state.editingState != nil {
                entries.append(ChannelInfoEntry.deleteChannel)
            }
        } else {
            entries.append(ChannelInfoEntry.report)
            if peer.participationStatus == .member {
                entries.append(ChannelInfoEntry.leave)
            }
        }
    }
    
    return entries
}

private func valuesRequiringUpdate(state: ChannelInfoState, view: PeerView) -> (title: String?, description: String?) {
    if let peer = view.peers[view.peerId] as? TelegramChannel {
        var titleValue: String?
        var descriptionValue: String?
        if let editingState = state.editingState {
            if let title = editingState.editingName?.composedTitle, title != peer.title {
                titleValue = title
            }
            if let cachedData = view.cachedData as? CachedChannelData {
                if let about = cachedData.about {
                    if about != editingState.editingDescriptionText {
                        descriptionValue = editingState.editingDescriptionText
                    }
                } else if !editingState.editingDescriptionText.isEmpty {
                    descriptionValue = editingState.editingDescriptionText
                }
            }
        }
        
        return (titleValue, descriptionValue)
    } else {
        return (nil, nil)
    }
}

public func channelInfoController(account: Account, peerId: PeerId) -> ViewController {
    let statePromise = ValuePromise(ChannelInfoState(), ignoreRepeated: true)
    let stateValue = Atomic(value: ChannelInfoState())
    let updateState: ((ChannelInfoState) -> ChannelInfoState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var pushControllerImpl: ((ViewController) -> Void)?
    var presentControllerImpl: ((ViewController, ViewControllerPresentationArguments) -> Void)?
    var popToRootControllerImpl: (() -> Void)?
    var displayAddressNameContextMenuImpl: ((String) -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    if peerId.namespace == Namespaces.Peer.CloudChannel {
        actionsDisposable.add(account.viewTracker.updatedCachedChannelParticipants(peerId, forceImmediateUpdate: true).start())
    }
    
    let updatePeerNameDisposable = MetaDisposable()
    actionsDisposable.add(updatePeerNameDisposable)
    
    let updatePeerDescriptionDisposable = MetaDisposable()
    actionsDisposable.add(updatePeerDescriptionDisposable)
    
    let changeMuteSettingsDisposable = MetaDisposable()
    actionsDisposable.add(changeMuteSettingsDisposable)
    
    let arguments = ChannelInfoControllerArguments(account: account, updateEditingName: { editingName in
        updateState { state in
            if let editingState = state.editingState {
                return state.withUpdatedEditingState(ChannelInfoEditingState(editingName: editingName, editingDescriptionText: editingState.editingDescriptionText))
            } else {
                return state
            }
        }
    }, updateEditingDescriptionText: { text in
        updateState { state in
            if let editingState = state.editingState {
                return state.withUpdatedEditingState(editingState.withUpdatedEditingDescriptionText(text))
            }
            return state
        }
    }, openChannelTypeSetup: {
        presentControllerImpl?(channelVisibilityController(account: account, peerId: peerId, mode: .generic), ViewControllerPresentationArguments(presentationAnimation: ViewControllerPresentationAnimation.modalSheet))
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
    }, openAdmins: {
        pushControllerImpl?(channelAdminsController(account: account, peerId: peerId))
    }, openMembers: {
        pushControllerImpl?(channelMembersController(account: account, peerId: peerId))
    }, openBanned: {
        pushControllerImpl?(channelBlacklistController(account: account, peerId: peerId))
    }, reportChannel: {
        
    }, leaveChannel: {
        let controller = ActionSheetController()
        let dismissAction: () -> Void = { [weak controller] in
            controller?.dismissAnimated()
        }
        controller.setItemGroups([
            ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: "Leave Channel", action: {
                    let _ = removePeerChat(postbox: account.postbox, peerId: peerId, reportChatSpam: false).start()
                    dismissAction()
                    popToRootControllerImpl?()
                }),
            ]),
            ActionSheetItemGroup(items: [ActionSheetButtonItem(title: "Cancel", action: { dismissAction() })])
            ])
        presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
    }, deleteChannel: {
        
    }, displayAddressNameContextMenu: { text in
        displayAddressNameContextMenuImpl?(text)
    })
    
    let signal = combineLatest(statePromise.get(), account.viewTracker.peerView(peerId))
        |> map { state, view -> (ItemListControllerState, (ItemListNodeState<ChannelInfoEntry>, ChannelInfoEntry.ItemGenerationArguments)) in
            let peer = peerViewMainPeer(view)
            
            var canManageChannel = false
            if let peer = peer as? TelegramChannel {
                switch peer.role {
                case .creator:
                    canManageChannel = true
                case .moderator:
                    break
                case .editor, .member:
                    break
                }
            }
            
            var leftNavigationButton: ItemListNavigationButton?
            var rightNavigationButton: ItemListNavigationButton?
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
                if peer is TelegramChannel {
                    if (view.cachedData as? CachedChannelData) == nil {
                        doneEnabled = false
                    }
                }
                
                if state.savingData {
                    rightNavigationButton = ItemListNavigationButton(title: "", style: .activity, enabled: doneEnabled, action: {})
                } else {
                    rightNavigationButton = ItemListNavigationButton(title: "Done", style: .bold, enabled: doneEnabled, action: {
                        var updateValues: (title: String?, description: String?) = (nil, nil)
                        updateState { state in
                            updateValues = valuesRequiringUpdate(state: state, view: view)
                            if updateValues.0 != nil || updateValues.1 != nil {
                                return state.withUpdatedSavingData(true)
                            } else {
                                return state.withUpdatedEditingState(nil)
                            }
                        }
                        
                        let updateTitle: Signal<Void, Void>
                        if let titleValue = updateValues.title {
                            updateTitle = updatePeerTitle(account: account, peerId: peerId, title: titleValue)
                                |> mapError { _ in return Void() }
                        } else {
                            updateTitle = .complete()
                        }
                        
                        let updateDescription: Signal<Void, Void>
                        if let descriptionValue = updateValues.description {
                            updateDescription = updatePeerDescription(account: account, peerId: peerId, description: descriptionValue.isEmpty ? nil : descriptionValue)
                                |> mapError { _ in return Void() }
                        } else {
                            updateDescription = .complete()
                        }
                        
                        let signal = combineLatest(updateTitle, updateDescription)
                        
                        updatePeerNameDisposable.set((signal |> deliverOnMainQueue).start(error: { _ in
                            updateState { state in
                                return state.withUpdatedSavingData(false)
                            }
                        }, completed: {
                            updateState { state in
                                return state.withUpdatedSavingData(false).withUpdatedEditingState(nil)
                            }
                        }))
                    })
                }
            } else if canManageChannel {
                rightNavigationButton = ItemListNavigationButton(title: "Edit", style: .regular, enabled: true, action: {
                    if let channel = peer as? TelegramChannel, case .broadcast = channel.info {
                        var text = ""
                        if let cachedData = view.cachedData as? CachedChannelData, let about = cachedData.about {
                            text = about
                        }
                        updateState { state in
                            return state.withUpdatedEditingState(ChannelInfoEditingState(editingName: ItemListAvatarAndNameInfoItemName(channel.indexName), editingDescriptionText: text))
                        }
                    }
                })
            }
            
            let controllerState = ItemListControllerState(title: "Info", leftNavigationButton: leftNavigationButton, rightNavigationButton: rightNavigationButton)
            let listState = ItemListNodeState(entries: channelInfoEntries(account: account, view: view, state: state), style: .plain)
            
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
    popToRootControllerImpl = { [weak controller] in
        (controller?.navigationController as? NavigationController)?.popToRoot(animated: true)
    }
    displayAddressNameContextMenuImpl = { [weak controller] text in
        if let strongController = controller {
            var resultItemNode: ListViewItemNode?
            let _ = strongController.frameForItemNode({ itemNode in
                if let itemNode = itemNode as? ItemListTextWithLabelItemNode {
                    if let tag = itemNode.tag as? ChannelInfoEntryTag {
                        if tag == .addressName {
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
