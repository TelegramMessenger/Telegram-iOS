import Foundation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

private struct ChannelVisibilityControllerArguments {
    let account: Account
    
    let updateCurrentType: (CurrentChannelType) -> Void
    let updatePublicLinkText: (String) -> Void
    let displayPrivateLinkMenu: () -> Void
}

private enum ChannelVisibilitySection: Int32 {
    case type
    case link
    case existingPublicLinks
}

private enum ChannelVisibilityEntry: ItemListNodeEntry {
    case typeHeader(String)
    case typePublic(Bool)
    case typePrivate(Bool)
    case typeInfo(String)
    
    case privateLink(String?)
    case editablePublicLink(String)
    case privateLinkInfo(String)
    case publicLinkInfo(String)
    case publicLinkStatus(String, AddressNameStatus)
    
    case existingLinksInfo(String)
    case existingLinkPeerItem(Int32, Peer, ItemListPeerItemEditing)
    
    var section: ItemListSectionId {
        switch self {
            case .typeHeader, .typePublic, .typePrivate, .typeInfo:
                return ChannelVisibilitySection.type.rawValue
            case .privateLink, .editablePublicLink, .privateLinkInfo, .publicLinkInfo, .publicLinkStatus:
                return ChannelVisibilitySection.link.rawValue
            case .existingLinksInfo, .existingLinkPeerItem:
                return ChannelVisibilitySection.existingPublicLinks.rawValue
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
            
            case .privateLink:
                return 4
            case .editablePublicLink:
                return 5
            case .privateLinkInfo:
                return 6
            case .publicLinkStatus:
                return 7
            case .publicLinkInfo:
                return 8
            
            case .existingLinksInfo:
                return 9
            case let .existingLinkPeerItem(index, _, _):
                return 10 + index
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
            case let .privateLink(lhsLink):
                if case let .privateLink(rhsLink) = rhs, lhsLink == rhsLink {
                    return true
                } else {
                    return false
                }
            case let .editablePublicLink(text):
                if case .editablePublicLink(text) = rhs {
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
            case let .existingLinkPeerItem(lhsIndex, lhsPeer, lhsEditing):
                if case let .existingLinkPeerItem(rhsIndex, rhsPeer, rhsEditing) = rhs {
                    if lhsIndex != rhsIndex {
                        return false
                    }
                    if !lhsPeer.isEqual(rhsPeer) {
                        return false
                    }
                    if lhsEditing != rhsEditing {
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
            case let .privateLink(link):
                return ItemListActionItem(title: link ?? "Loading", kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    
                })
            case let .editablePublicLink(text):
                return ItemListSingleLineInputItem(title: NSAttributedString(string: "t.me/", textColor: .black), text: text, placeholder: "", sectionId: self.section, textUpdated: { updatedText in
                    arguments.updatePublicLinkText(updatedText)
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
                    case .available:
                        text = NSAttributedString(string: "\(addressName) is available.", textColor: UIColor(0x26972c))
                    case .checking:
                        text = NSAttributedString(string: "Checking name...", textColor: .gray)
                        displayActivity = true
                    case let .invalid(reason):
                        switch reason {
                            case .alreadyTaken:
                                text = NSAttributedString(string: "\(addressName) is already taken.", textColor: .red)
                            case .digitStart:
                                text = NSAttributedString(string: "Names can't start with a digit.", textColor: UIColor(0xcf3030))
                            case .invalid, .underscopeEnd, .underscopeStart:
                                text = NSAttributedString(string: "Sorry, this name is invalid.", textColor: UIColor(0xcf3030))
                            case .short:
                                text = NSAttributedString(string: "Names must have at least 5 characters.", textColor: UIColor(0xcf3030))
                        }
                }
                return ItemListActivityTextItem(displayActivity: displayActivity, text: text, sectionId: self.section)
            case let .existingLinksInfo(text):
                return ItemListTextItem(text: text, sectionId: self.section)
            case let .existingLinkPeerItem(_, peer, editing):
                return ItemListPeerItem(account: arguments.account, peer: peer, presence: nil, text: .activity, label: nil, editing: editing, enabled: true, sectionId: self.section, action: nil, setPeerIdWithRevealedOptions: { previousId, id in
                    
                }, removePeer: { _ in
                    
                })
        }
    }
}

private enum CurrentChannelType {
    case publicChannel
    case privateChannel
}

private enum AddressNameStatus: Equatable {
    case available
    case checking
    case invalid(UsernameAvailabilityError)
    
    static func ==(lhs: AddressNameStatus, rhs: AddressNameStatus) -> Bool {
        switch lhs {
            case .available:
                if case .available = rhs {
                    return true
                } else {
                    return false
                }
            case .checking:
                if case .checking = rhs {
                    return true
                } else {
                    return false
                }
            case let .invalid(reason):
                if case .invalid(reason) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}

private struct ChannelVisibilityControllerState: Equatable {
    let selectedType: CurrentChannelType?
    let editingPublicLinkText: String?
    let addressNameStatus: AddressNameStatus?
    let updatingAddressName: Bool
    
    init() {
        self.selectedType = nil
        self.editingPublicLinkText = nil
        self.addressNameStatus = nil
        self.updatingAddressName = false
    }
    
    init(selectedType: CurrentChannelType?, editingPublicLinkText: String?, addressNameStatus: AddressNameStatus?, updatingAddressName: Bool) {
        self.selectedType = selectedType
        self.editingPublicLinkText = editingPublicLinkText
        self.addressNameStatus = addressNameStatus
        self.updatingAddressName = updatingAddressName
    }
    
    static func ==(lhs: ChannelVisibilityControllerState, rhs: ChannelVisibilityControllerState) -> Bool {
        if lhs.selectedType != rhs.selectedType {
            return false
        }
        if lhs.editingPublicLinkText != rhs.editingPublicLinkText {
            return false
        }
        if lhs.addressNameStatus != rhs.addressNameStatus {
            return false
        }
        if lhs.updatingAddressName != rhs.updatingAddressName {
            return false
        }
        
        return true
    }
    
    func withUpdatedSelectedType(_ selectedType: CurrentChannelType?) -> ChannelVisibilityControllerState {
        return ChannelVisibilityControllerState(selectedType: selectedType, editingPublicLinkText: self.editingPublicLinkText, addressNameStatus: self.addressNameStatus, updatingAddressName: self.updatingAddressName)
    }
    
    func withUpdatedEditingPublicLinkText(_ editingPublicLinkText: String?) -> ChannelVisibilityControllerState {
        return ChannelVisibilityControllerState(selectedType: self.selectedType, editingPublicLinkText: editingPublicLinkText, addressNameStatus: self.addressNameStatus, updatingAddressName: self.updatingAddressName)
    }
    
    func withUpdatedAddressNameStatus(_ addressNameStatus: AddressNameStatus?) -> ChannelVisibilityControllerState {
        return ChannelVisibilityControllerState(selectedType: self.selectedType, editingPublicLinkText: self.editingPublicLinkText, addressNameStatus: addressNameStatus, updatingAddressName: self.updatingAddressName)
    }
    
    func withUpdatedUpdatingAddressName(_ updatingAddressName: Bool) -> ChannelVisibilityControllerState {
        return ChannelVisibilityControllerState(selectedType: self.selectedType, editingPublicLinkText: self.editingPublicLinkText, addressNameStatus: self.addressNameStatus, updatingAddressName: updatingAddressName)
    }
}

private func channelVisibilityControllerEntries(view: PeerView, state: ChannelVisibilityControllerState) -> [ChannelVisibilityEntry] {
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
                entries.append(.editablePublicLink(currentAddressName))
                if let status = state.addressNameStatus {
                    entries.append(.publicLinkStatus(currentAddressName, status))
                }
                entries.append(.publicLinkInfo("People can share this link with others and find your group using Telegram search."))
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
    
    var dismissImpl: (() -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    let checkAddressNameDisposable = MetaDisposable()
    actionsDisposable.add(checkAddressNameDisposable)
    
    let updateAddressNameDisposable = MetaDisposable()
    actionsDisposable.add(updateAddressNameDisposable)
    
    let arguments = ChannelVisibilityControllerArguments(account: account, updateCurrentType: { type in
        updateState { state in
            return state.withUpdatedSelectedType(type)
        }
    }, updatePublicLinkText: { text in
        if text.isEmpty {
            checkAddressNameDisposable.set(nil)
            updateState { state in
                return state.withUpdatedEditingPublicLinkText(text).withUpdatedAddressNameStatus(nil)
            }
        } else {
            updateState { state in
                return state.withUpdatedEditingPublicLinkText(text)
            }
            checkAddressNameDisposable.set((addressNameAvailability(account: account, domain: .peer(peerId), def: nil, current: text)
                |> deliverOnMainQueue).start(next: { result in
                    updateState { state in
                        let status: AddressNameStatus
                        switch result {
                            case let .fail(_, error):
                                status = .invalid(error)
                            case .none:
                                status = .available
                            case .success:
                                status = .available
                            case .progress:
                                status = .checking
                        }
                        return state.withUpdatedAddressNameStatus(status)
                    }
                }))
        }
    }, displayPrivateLinkMenu: {
        
    })
    
    let peerView = account.viewTracker.peerView(peerId)
    
    let signal = combineLatest(statePromise.get(), peerView)
        |> map { state, view -> (ItemListControllerState, (ItemListNodeState<ChannelVisibilityEntry>, ChannelVisibilityEntry.ItemGenerationArguments)) in
            let peer = peerViewMainPeer(view)
            
            var rightNavigationButton: ItemListNavigationButton?
            if let peer = peer as? TelegramChannel {
                var doneEnabled = true
                if let selectedType = state.selectedType {
                    switch selectedType {
                        case .privateChannel:
                            break
                        case .publicChannel:
                            if let addressNameStatus = state.addressNameStatus {
                                switch addressNameStatus {
                                    case .available:
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
                        updateAddressNameDisposable.set((updatePeerAddressName(account: account, peerId: peerId, username: updatedAddressNameValue.isEmpty ? nil : updatedAddressNameValue)
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
            let listState = ItemListNodeState(entries: channelVisibilityControllerEntries(view: view, state: state), style: .blocks, animateChanges: false)
            
            return (controllerState, (listState, arguments))
        } |> afterDisposed {
            actionsDisposable.dispose()
        }
    
    let controller = ItemListController(signal)
    dismissImpl = { [weak controller] in
        controller?.dismiss()
    }
    return controller
}
