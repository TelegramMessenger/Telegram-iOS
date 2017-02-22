import Foundation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

private final class ChannelVisibilityControllerArguments {
    let account: Account
    
    let updateCurrentType: (CurrentChannelType) -> Void
    let updatePublicLinkText: (String?, String) -> Void
    let displayPrivateLinkMenu: (String) -> Void
    let setPeerIdWithRevealedOptions: (PeerId?, PeerId?) -> Void
    let revokePeerId: (PeerId) -> Void
    
    init(account: Account, updateCurrentType: @escaping (CurrentChannelType) -> Void, updatePublicLinkText: @escaping (String?, String) -> Void, displayPrivateLinkMenu: @escaping (String) -> Void, setPeerIdWithRevealedOptions: @escaping (PeerId?, PeerId?) -> Void, revokePeerId: @escaping (PeerId) -> Void) {
        self.account = account
        self.updateCurrentType = updateCurrentType
        self.updatePublicLinkText = updatePublicLinkText
        self.displayPrivateLinkMenu = displayPrivateLinkMenu
        self.setPeerIdWithRevealedOptions = setPeerIdWithRevealedOptions
        self.revokePeerId = revokePeerId
    }
}

private enum ChannelVisibilitySection: Int32 {
    case type
    case link
}

private enum ChannelVisibilityEntryTag {
    case privateLink
}

private enum ChannelVisibilityEntry: ItemListNodeEntry {
    case typeHeader(String)
    case typePublic(Bool)
    case typePrivate(Bool)
    case typeInfo(String)
    
    case publicLinkAvailability(Bool)
    case privateLink(String?)
    case editablePublicLink(String?, String)
    case privateLinkInfo(String)
    case publicLinkInfo(String)
    case publicLinkStatus(String, AddressNameValidationStatus)
    
    case existingLinksInfo(String)
    case existingLinkPeerItem(Int32, Peer, ItemListPeerItemEditing, Bool)
    
    var section: ItemListSectionId {
        switch self {
            case .typeHeader, .typePublic, .typePrivate, .typeInfo:
                return ChannelVisibilitySection.type.rawValue
            case .publicLinkAvailability, .privateLink, .editablePublicLink, .privateLinkInfo, .publicLinkInfo, .publicLinkStatus:
                return ChannelVisibilitySection.link.rawValue
            case .existingLinksInfo, .existingLinkPeerItem:
                return ChannelVisibilitySection.link.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
            case .typeHeader:
                return 0
            case .typePublic:
                return 1
            case .typePrivate:
                return 2
            case .typeInfo:
                return 3
            
            case .publicLinkAvailability:
                return 4
            case .privateLink:
                return 5
            case .editablePublicLink:
                return 6
            case .privateLinkInfo:
                return 7
            case .publicLinkStatus:
                return 8
            case .publicLinkInfo:
                return 9
            
            case .existingLinksInfo:
                return 10
            case let .existingLinkPeerItem(index, _, _, _):
                return 11 + index
        }
    }
    
    static func ==(lhs: ChannelVisibilityEntry, rhs: ChannelVisibilityEntry) -> Bool {
        switch lhs {
            case let .typeHeader(title):
                if case .typeHeader(title) = rhs {
                    return true
                } else {
                    return false
                }
            case let .typePublic(selected):
                if case .typePublic(selected) = rhs {
                    return true
                } else {
                    return false
                }
            case let .typePrivate(selected):
                if case .typePrivate(selected) = rhs {
                    return true
                } else {
                    return false
                }
            case let .typeInfo(text):
                if case .typeInfo(text) = rhs {
                    return true
                } else {
                    return false
                }
            case let .publicLinkAvailability(value):
                if case .publicLinkAvailability(value) = rhs {
                    return true
                } else {
                    return false
                }
            case let .privateLink(lhsLink):
                if case let .privateLink(rhsLink) = rhs, lhsLink == rhsLink {
                    return true
                } else {
                    return false
                }
            case let .editablePublicLink(lhsCurrentText, lhsText):
                if case let .editablePublicLink(rhsCurrentText, rhsText) = rhs, lhsCurrentText == rhsCurrentText, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .privateLinkInfo(text):
                if case .privateLinkInfo(text) = rhs {
                    return true
                } else {
                    return false
                }
            case let .publicLinkInfo(text):
                if case .publicLinkInfo(text) = rhs {
                    return true
                } else {
                    return false
                }
            case let .publicLinkStatus(addressName, status):
                if case .publicLinkStatus(addressName, status) = rhs {
                    return true
                } else {
                    return false
                }
            case let .existingLinksInfo(text):
                if case .existingLinksInfo(text) = rhs {
                    return true
                } else {
                    return false
                }
            case let .existingLinkPeerItem(lhsIndex, lhsPeer, lhsEditing, lhsEnabled):
                if case let .existingLinkPeerItem(rhsIndex, rhsPeer, rhsEditing, rhsEnabled) = rhs {
                    if lhsIndex != rhsIndex {
                        return false
                    }
                    if !lhsPeer.isEqual(rhsPeer) {
                        return false
                    }
                    if lhsEditing != rhsEditing {
                        return false
                    }
                    if lhsEnabled != rhsEnabled {
                        return false
                    }
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: ChannelVisibilityEntry, rhs: ChannelVisibilityEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(_ arguments: ChannelVisibilityControllerArguments) -> ListViewItem {
        switch self {
            case let .typeHeader(title):
                return ItemListSectionHeaderItem(text: title, sectionId: self.section)
            case let .typePublic(selected):
                return ItemListCheckboxItem(title: "Public", checked: selected, zeroSeparatorInsets: false, sectionId: self.section, action: {
                    arguments.updateCurrentType(.publicChannel)
                })
            case let .typePrivate(selected):
                return ItemListCheckboxItem(title: "Private", checked: selected, zeroSeparatorInsets: false, sectionId: self.section, action: {
                    arguments.updateCurrentType(.privateChannel)
                })
            case let .typeInfo(text):
                return ItemListTextItem(text: text, sectionId: self.section)
            case let .publicLinkAvailability(value):
                if value {
                    return ItemListActivityTextItem(displayActivity: true, text: NSAttributedString(string: "Checking", textColor: UIColor(0x6d6d72)), sectionId: self.section)
                } else {
                    return ItemListActivityTextItem(displayActivity: false, text: NSAttributedString(string: "Sorry, you have reserved too many public usernames. You can revoke the link from one of your older groups or channels, or create a private entity instead.", textColor: UIColor(0xcf3030)), sectionId: self.section)
                }
            case let .privateLink(link):
                return ItemListActionItem(title: link ?? "Loading", kind: .neutral, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    if let link = link {
                        arguments.displayPrivateLinkMenu(link)
                    }
                }, tag: ChannelVisibilityEntryTag.privateLink)
            case let .editablePublicLink(currentText, text):
                return ItemListSingleLineInputItem(title: NSAttributedString(string: "t.me/", textColor: .black), text: text, placeholder: "", sectionId: self.section, textUpdated: { updatedText in
                    arguments.updatePublicLinkText(currentText, updatedText)
                }, action: {
                    
                })
            case let .privateLinkInfo(text):
                return ItemListTextItem(text: text, sectionId: self.section)
            case let .publicLinkInfo(text):
                return ItemListTextItem(text: text, sectionId: self.section)
            case let .publicLinkStatus(addressName, status):
                var displayActivity = false
                let text: NSAttributedString
                switch status {
                    case let .invalidFormat(error):
                        switch error {
                            case .startsWithDigit:
                                text = NSAttributedString(string: "Names can't start with a digit.", textColor: UIColor(0xcf3030))
                            case .startsWithUnderscore:
                                text = NSAttributedString(string: "Names can't start with an underscore.", textColor: UIColor(0xcf3030))
                            case .endsWithUnderscore:
                                text = NSAttributedString(string: "Names can't end with an underscore.", textColor: UIColor(0xcf3030))
                            case .tooShort:
                                text = NSAttributedString(string: "Names must have at least 5 characters.", textColor: UIColor(0xcf3030))
                            case .invalidCharacters:
                                text = NSAttributedString(string: "Sorry, this name is invalid.", textColor: UIColor(0xcf3030))
                        }
                    case let .availability(availability):
                        switch availability {
                            case .available:
                                text = NSAttributedString(string: "\(addressName) is available.", textColor: UIColor(0x26972c))
                            case .invalid:
                                text = NSAttributedString(string: "Sorry, this name is invalid.", textColor: UIColor(0xcf3030))
                            case .taken:
                                text = NSAttributedString(string: "\(addressName) is already taken.", textColor: UIColor(0xcf3030))
                        }
                    case .checking:
                        text = NSAttributedString(string: "Checking name...", textColor: UIColor(0x6d6d72))
                        displayActivity = true
                }
                return ItemListActivityTextItem(displayActivity: displayActivity, text: text, sectionId: self.section)
            case let .existingLinksInfo(text):
                return ItemListTextItem(text: text, sectionId: self.section)
            case let .existingLinkPeerItem(_, peer, editing, enabled):
                var label = ""
                if let addressName = peer.addressName {
                    label = "t.me/" + addressName
                }
                return ItemListPeerItem(account: arguments.account, peer: peer, presence: nil, text: .text(label), label: nil, editing: editing, enabled: enabled, sectionId: self.section, action: nil, setPeerIdWithRevealedOptions: { previousId, id in
                    arguments.setPeerIdWithRevealedOptions(previousId, id)
                }, removePeer: { peerId in
                    arguments.revokePeerId(peerId)
                })
        }
    }
}

private enum CurrentChannelType {
    case publicChannel
    case privateChannel
}

private struct ChannelVisibilityControllerState: Equatable {
    let selectedType: CurrentChannelType?
    let editingPublicLinkText: String?
    let addressNameValidationStatus: AddressNameValidationStatus?
    let updatingAddressName: Bool
    let revealedRevokePeerId: PeerId?
    let revokingPeerId: PeerId?
    
    init() {
        self.selectedType = nil
        self.editingPublicLinkText = nil
        self.addressNameValidationStatus = nil
        self.updatingAddressName = false
        self.revealedRevokePeerId = nil
        self.revokingPeerId = nil
    }
    
    init(selectedType: CurrentChannelType?, editingPublicLinkText: String?, addressNameValidationStatus: AddressNameValidationStatus?, updatingAddressName: Bool, revealedRevokePeerId: PeerId?, revokingPeerId: PeerId?) {
        self.selectedType = selectedType
        self.editingPublicLinkText = editingPublicLinkText
        self.addressNameValidationStatus = addressNameValidationStatus
        self.updatingAddressName = updatingAddressName
        self.revealedRevokePeerId = revealedRevokePeerId
        self.revokingPeerId = revokingPeerId
    }
    
    static func ==(lhs: ChannelVisibilityControllerState, rhs: ChannelVisibilityControllerState) -> Bool {
        if lhs.selectedType != rhs.selectedType {
            return false
        }
        if lhs.editingPublicLinkText != rhs.editingPublicLinkText {
            return false
        }
        if lhs.addressNameValidationStatus != rhs.addressNameValidationStatus {
            return false
        }
        if lhs.updatingAddressName != rhs.updatingAddressName {
            return false
        }
        if lhs.revealedRevokePeerId != rhs.revealedRevokePeerId {
            return false
        }
        if lhs.revokingPeerId != rhs.revokingPeerId {
            return false
        }
        
        return true
    }
    
    func withUpdatedSelectedType(_ selectedType: CurrentChannelType?) -> ChannelVisibilityControllerState {
        return ChannelVisibilityControllerState(selectedType: selectedType, editingPublicLinkText: self.editingPublicLinkText, addressNameValidationStatus: self.addressNameValidationStatus, updatingAddressName: self.updatingAddressName, revealedRevokePeerId: self.revealedRevokePeerId, revokingPeerId: self.revokingPeerId)
    }
    
    func withUpdatedEditingPublicLinkText(_ editingPublicLinkText: String?) -> ChannelVisibilityControllerState {
        return ChannelVisibilityControllerState(selectedType: self.selectedType, editingPublicLinkText: editingPublicLinkText, addressNameValidationStatus: self.addressNameValidationStatus, updatingAddressName: self.updatingAddressName, revealedRevokePeerId: self.revealedRevokePeerId, revokingPeerId: self.revokingPeerId)
    }
    
    func withUpdatedAddressNameValidationStatus(_ addressNameValidationStatus: AddressNameValidationStatus?) -> ChannelVisibilityControllerState {
        return ChannelVisibilityControllerState(selectedType: self.selectedType, editingPublicLinkText: self.editingPublicLinkText, addressNameValidationStatus: addressNameValidationStatus, updatingAddressName: self.updatingAddressName, revealedRevokePeerId: self.revealedRevokePeerId, revokingPeerId: self.revokingPeerId)
    }
    
    func withUpdatedUpdatingAddressName(_ updatingAddressName: Bool) -> ChannelVisibilityControllerState {
        return ChannelVisibilityControllerState(selectedType: self.selectedType, editingPublicLinkText: self.editingPublicLinkText, addressNameValidationStatus: self.addressNameValidationStatus, updatingAddressName: updatingAddressName, revealedRevokePeerId: self.revealedRevokePeerId, revokingPeerId: self.revokingPeerId)
    }
    
    func withUpdatedRevealedRevokePeerId(_ revealedRevokePeerId: PeerId?) -> ChannelVisibilityControllerState {
        return ChannelVisibilityControllerState(selectedType: self.selectedType, editingPublicLinkText: self.editingPublicLinkText, addressNameValidationStatus: self.addressNameValidationStatus, updatingAddressName: updatingAddressName, revealedRevokePeerId: revealedRevokePeerId, revokingPeerId: self.revokingPeerId)
    }
    
    func withUpdatedRevokingPeerId(_ revokingPeerId: PeerId?) -> ChannelVisibilityControllerState {
        return ChannelVisibilityControllerState(selectedType: self.selectedType, editingPublicLinkText: self.editingPublicLinkText, addressNameValidationStatus: self.addressNameValidationStatus, updatingAddressName: updatingAddressName, revealedRevokePeerId: self.revealedRevokePeerId, revokingPeerId: revokingPeerId)
    }
}

private func channelVisibilityControllerEntries(view: PeerView, publicChannelsToRevoke: [Peer]?, state: ChannelVisibilityControllerState) -> [ChannelVisibilityEntry] {
    var entries: [ChannelVisibilityEntry] = []
    
    if let peer = view.peers[view.peerId] as? TelegramChannel {
        var isGroup = false
        if case .group = peer.info {
            isGroup = true
        }
        
        let selectedType: CurrentChannelType
        if let current = state.selectedType {
            selectedType = current
        } else {
            if let addressName = peer.addressName, !addressName.isEmpty {
                selectedType = .publicChannel
            } else {
                selectedType = .privateChannel
            }
        }
        
        let currentAddressName: String
        if let current = state.editingPublicLinkText {
            currentAddressName = current
        } else {
            if let addressName = peer.addressName {
                currentAddressName = addressName
            } else {
                currentAddressName = ""
            }
        }
        
        entries.append(.typeHeader(isGroup ? "GROUP TYPE" : "CHANNEL TYPE"))
        entries.append(.typePublic(selectedType == .publicChannel))
        entries.append(.typePrivate(selectedType == .privateChannel))
        
        switch selectedType {
            case .publicChannel:
                if isGroup {
                    entries.append(.typeInfo("Public groups can be found in search, chat history is available to everyone and anyone can join."))
                } else {
                    entries.append(.typeInfo("Public channels can be found in search and anyone can join."))
                }
            case .privateChannel:
                if isGroup {
                    entries.append(.typeInfo("Private groups can only be joined if you were invited of have an invite link."))
                } else {
                    entries.append(.typeInfo("Private channels can only be joined if you were invited of have an invite link."))
                }
        }

        switch selectedType {
            case .publicChannel:
                var displayAvailability = false
                if peer.addressName == nil {
                    displayAvailability = publicChannelsToRevoke == nil || !(publicChannelsToRevoke!.isEmpty)
                }
                
                if displayAvailability {
                    if let publicChannelsToRevoke = publicChannelsToRevoke {
                        entries.append(.publicLinkAvailability(false))
                        var index: Int32 = 0
                        for peer in publicChannelsToRevoke.sorted(by: { lhs, rhs in
                            var lhsDate: Int32 = 0
                            var rhsDate: Int32 = 0
                            if let lhs = lhs as? TelegramChannel {
                                lhsDate = lhs.creationDate
                            }
                            if let rhs = rhs as? TelegramChannel {
                                rhsDate = rhs.creationDate
                            }
                            return lhsDate > rhsDate
                        }) {
                            entries.append(.existingLinkPeerItem(index, peer, ItemListPeerItemEditing(editable: true, editing: true, revealed: state.revealedRevokePeerId == peer.id), state.revokingPeerId == nil))
                            index += 1
                        }
                    } else {
                        entries.append(.publicLinkAvailability(true))
                    }
                } else {
                    entries.append(.editablePublicLink(peer.addressName, currentAddressName))
                    if let status = state.addressNameValidationStatus {
                        entries.append(.publicLinkStatus(currentAddressName, status))
                    }
                    entries.append(.publicLinkInfo("People can share this link with others and find your group using Telegram search."))
                }
            case .privateChannel:
                entries.append(.privateLink((view.cachedData as? CachedChannelData)?.exportedInvitation?.link))
                entries.append(.publicLinkInfo("People can join your group by following this link. You can revoke the link at any time."))
        }
    }
    
    return entries
}
private func effectiveChannelType(state: ChannelVisibilityControllerState, peer: TelegramChannel) -> CurrentChannelType {
    let selectedType: CurrentChannelType
    if let current = state.selectedType {
        selectedType = current
    } else {
        if let addressName = peer.addressName, !addressName.isEmpty {
            selectedType = .publicChannel
        } else {
            selectedType = .privateChannel
        }
    }
    return selectedType
}

private func updatedAddressName(state: ChannelVisibilityControllerState, peer: TelegramChannel) -> String? {
    let selectedType = effectiveChannelType(state: state, peer: peer)
    
    let currentAddressName: String
    
    switch selectedType {
        case .privateChannel:
            currentAddressName = ""
        case .publicChannel:
            if let current = state.editingPublicLinkText {
                currentAddressName = current
            } else {
                if let addressName = peer.addressName {
                    currentAddressName = addressName
                } else {
                    currentAddressName = ""
                }
            }
    }
    
    if !currentAddressName.isEmpty {
        if currentAddressName != peer.addressName {
            return currentAddressName
        } else {
            return nil
        }
    } else if peer.addressName != nil {
        return ""
    } else {
        return nil
    }
}

public func channelVisibilityController(account: Account, peerId: PeerId) -> ViewController {
    let statePromise = ValuePromise(ChannelVisibilityControllerState(), ignoreRepeated: true)
    let stateValue = Atomic(value: ChannelVisibilityControllerState())
    let updateState: ((ChannelVisibilityControllerState) -> ChannelVisibilityControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    let peersDisablingAddressNameAssignment = Promise<[Peer]?>()
    peersDisablingAddressNameAssignment.set(.single(nil) |> then(channelAddressNameAssignmentAvailability(account: account, peerId: peerId) |> mapToSignal { result -> Signal<[Peer]?, NoError> in
        if case .addressNameLimitReached = result {
            return adminedPublicChannels(account: account)
                |> map { Optional($0) }
        } else {
            return .single([])
        }
    }))
    
    var dismissImpl: (() -> Void)?
    var displayPrivateLinkMenuImpl: ((String) -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    let checkAddressNameDisposable = MetaDisposable()
    actionsDisposable.add(checkAddressNameDisposable)
    
    let updateAddressNameDisposable = MetaDisposable()
    actionsDisposable.add(updateAddressNameDisposable)
    
    let revokeAddressNameDisposable = MetaDisposable()
    actionsDisposable.add(revokeAddressNameDisposable)
    
    let arguments = ChannelVisibilityControllerArguments(account: account, updateCurrentType: { type in
        updateState { state in
            return state.withUpdatedSelectedType(type)
        }
    }, updatePublicLinkText: { currentText, text in
        if text.isEmpty {
            checkAddressNameDisposable.set(nil)
            updateState { state in
                return state.withUpdatedEditingPublicLinkText(text).withUpdatedAddressNameValidationStatus(nil)
            }
        } else if currentText == text {
            checkAddressNameDisposable.set(nil)
            updateState { state in
                return state.withUpdatedEditingPublicLinkText(text).withUpdatedAddressNameValidationStatus(nil).withUpdatedAddressNameValidationStatus(nil)
            }
        } else {
            updateState { state in
                return state.withUpdatedEditingPublicLinkText(text)
            }
            
            checkAddressNameDisposable.set((validateAddressNameInteractive(account: account, domain: .peer(peerId), name: text)
                |> deliverOnMainQueue).start(next: { result in
                    updateState { state in
                        return state.withUpdatedAddressNameValidationStatus(result)
                    }
                }))
        }
    }, displayPrivateLinkMenu: { text in
        displayPrivateLinkMenuImpl?(text)
    }, setPeerIdWithRevealedOptions: { peerId, fromPeerId in
        updateState { state in
            if (peerId == nil && fromPeerId == state.revealedRevokePeerId) || (peerId != nil && fromPeerId == nil) {
                return state.withUpdatedRevealedRevokePeerId(peerId)
            } else {
                return state
            }
        }
    }, revokePeerId: { peerId in
        updateState { state in
            return state.withUpdatedRevokingPeerId(peerId)
        }
        
        revokeAddressNameDisposable.set((updateAddressName(account: account, domain: .peer(peerId), name: nil) |> deliverOnMainQueue).start(error: { _ in
            updateState { state in
                return state.withUpdatedRevokingPeerId(nil)
            }
        }, completed: {
            updateState { state in
                return state.withUpdatedRevokingPeerId(nil)
            }
            peersDisablingAddressNameAssignment.set(.single([]))
        }))
    })
    
    let peerView = account.viewTracker.peerView(peerId)
    
    let signal = combineLatest(statePromise.get(), peerView, peersDisablingAddressNameAssignment.get())
        |> map { state, view, publicChannelsToRevoke -> (ItemListControllerState, (ItemListNodeState<ChannelVisibilityEntry>, ChannelVisibilityEntry.ItemGenerationArguments)) in
            let peer = peerViewMainPeer(view)
            
            var rightNavigationButton: ItemListNavigationButton?
            if let peer = peer as? TelegramChannel {
                var doneEnabled = true
                if let selectedType = state.selectedType {
                    switch selectedType {
                        case .privateChannel:
                            break
                        case .publicChannel:
                            if let addressNameValidationStatus = state.addressNameValidationStatus {
                                switch addressNameValidationStatus {
                                    case .availability(.available):
                                        break
                                    default:
                                        doneEnabled = false
                                }
                            }
                    }
                }
                
                rightNavigationButton = ItemListNavigationButton(title: "Done", style: state.updatingAddressName ? .activity : .bold, enabled: doneEnabled, action: {
                    var updatedAddressNameValue: String?
                    updateState { state in
                        updatedAddressNameValue = updatedAddressName(state: state, peer: peer)
                        
                        if updatedAddressNameValue != nil {
                            return state.withUpdatedUpdatingAddressName(true)
                        } else {
                            return state
                        }
                    }
                    
                    if let updatedAddressNameValue = updatedAddressNameValue {
                        updateAddressNameDisposable.set((updateAddressName(account: account, domain: .peer(peerId), name: updatedAddressNameValue.isEmpty ? nil : updatedAddressNameValue)
                        |> deliverOnMainQueue).start(error: { _ in
                            updateState { state in
                                return state.withUpdatedUpdatingAddressName(false)
                            }
                        }, completed: {
                            updateState { state in
                                return state.withUpdatedUpdatingAddressName(false)
                            }
                            
                            dismissImpl?()
                        }))
                    } else {
                        dismissImpl?()
                    }
                })
            }
            
            var isGroup = false
            if let peer = peer as? TelegramChannel {
                if case .group = peer.info {
                    isGroup = true
                }
            }
            
            let leftNavigationButton = ItemListNavigationButton(title: "Cancel", style: .regular, enabled: true, action: {
                dismissImpl?()
            })
            
            let controllerState = ItemListControllerState(title: isGroup ? "Group Type" : "Channel Link", leftNavigationButton: leftNavigationButton, rightNavigationButton: rightNavigationButton, animateChanges: false)
            let listState = ItemListNodeState(entries: channelVisibilityControllerEntries(view: view, publicChannelsToRevoke: publicChannelsToRevoke, state: state), style: .blocks, animateChanges: false)
            
            return (controllerState, (listState, arguments))
        } |> afterDisposed {
            actionsDisposable.dispose()
        }
    
    let controller = ItemListController(signal)
    dismissImpl = { [weak controller] in
        controller?.dismiss()
    }
    displayPrivateLinkMenuImpl = { [weak controller] text in
        if let strongController = controller {
            var resultItemNode: ListViewItemNode?
            let _ = strongController.frameForItemNode({ itemNode in
                if let itemNode = itemNode as? ItemListActionItemNode {
                    if let tag = itemNode.tag as? ChannelVisibilityEntryTag {
                        if tag == .privateLink {
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
