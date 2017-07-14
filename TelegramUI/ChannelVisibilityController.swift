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
    case typeHeader(PresentationTheme, String)
    case typePublic(PresentationTheme, String, Bool)
    case typePrivate(PresentationTheme, String, Bool)
    case typeInfo(PresentationTheme, String)
    
    case publicLinkAvailability(PresentationTheme, String, Bool)
    case privateLink(PresentationTheme, String, String?)
    case editablePublicLink(PresentationTheme, String)
    case privateLinkInfo(PresentationTheme, String)
    case publicLinkInfo(PresentationTheme, String)
    case publicLinkStatus(PresentationTheme, String, AddressNameValidationStatus)
    
    case existingLinksInfo(PresentationTheme, String)
    case existingLinkPeerItem(Int32, PresentationTheme, PresentationStrings, Peer, ItemListPeerItemEditing, Bool)
    
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
            case let .existingLinkPeerItem(index, _, _, _, _, _):
                return 11 + index
        }
    }
    
    static func ==(lhs: ChannelVisibilityEntry, rhs: ChannelVisibilityEntry) -> Bool {
        switch lhs {
            case let .typeHeader(lhsTheme, lhsTitle):
                if case let .typeHeader(rhsTheme, rhsTitle) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle {
                    return true
                } else {
                    return false
                }
            case let .typePublic(lhsTheme, lhsTitle, lhsSelected):
                if case let .typePublic(rhsTheme, rhsTitle, rhsSelected) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsSelected == rhsSelected {
                    return true
                } else {
                    return false
                }
            case let .typePrivate(lhsTheme, lhsTitle, lhsSelected):
                if case let .typePrivate(rhsTheme, rhsTitle, rhsSelected) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsSelected == rhsSelected {
                    return true
                } else {
                    return false
                }
            case let .typeInfo(lhsTheme, lhsText):
                if case let .typeInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .publicLinkAvailability(lhsTheme, lhsText, lhsValue):
                if case let .publicLinkAvailability(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .privateLink(lhsTheme, lhsText, lhsLink):
                if case let .privateLink(rhsTheme, rhsText, rhsLink) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsLink == rhsLink {
                    return true
                } else {
                    return false
                }
            case let .editablePublicLink(lhsTheme, lhsCurrentText):
                if case let .editablePublicLink(rhsTheme, rhsCurrentText) = rhs, lhsTheme === rhsTheme, lhsCurrentText == rhsCurrentText {
                    return true
                } else {
                    return false
                }
            case let .privateLinkInfo(lhsTheme, lhsText):
                if case let .privateLinkInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .publicLinkInfo(lhsTheme, lhsText):
                if case let .publicLinkInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .publicLinkStatus(lhsTheme, lhsText, lhsStatus):
                if case let .publicLinkStatus(rhsTheme, rhsText, rhsStatus) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsStatus == rhsStatus {
                    return true
                } else {
                    return false
                }
            case let .existingLinksInfo(lhsTheme, lhsText):
                if case let .existingLinksInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .existingLinkPeerItem(lhsIndex, lhsTheme, lhsStrings, lhsPeer, lhsEditing, lhsEnabled):
                if case let .existingLinkPeerItem(rhsIndex, rhsTheme, rhsStrings, rhsPeer, rhsEditing, rhsEnabled) = rhs {
                    if lhsIndex != rhsIndex {
                        return false
                    }
                    if lhsTheme !== rhsTheme {
                        return false
                    }
                    if lhsStrings !== rhsStrings {
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
            case let .typeHeader(theme, title):
                return ItemListSectionHeaderItem(theme: theme, text: title, sectionId: self.section)
            case let .typePublic(theme, text, selected):
                return ItemListCheckboxItem(theme: theme, title: text, checked: selected, zeroSeparatorInsets: false, sectionId: self.section, action: {
                    arguments.updateCurrentType(.publicChannel)
                })
            case let .typePrivate(theme, text, selected):
                return ItemListCheckboxItem(theme: theme, title: text, checked: selected, zeroSeparatorInsets: false, sectionId: self.section, action: {
                    arguments.updateCurrentType(.privateChannel)
                })
            case let .typeInfo(theme, text):
                return ItemListTextItem(theme: theme, text: .plain(text), sectionId: self.section)
            case let .publicLinkAvailability(theme, text, value):
                return ItemListActivityTextItem(displayActivity: value, text: NSAttributedString(string: text, textColor: value ? theme.list.freeTextColor : theme.list.freeTextErrorColor), sectionId: self.section)
            case let .privateLink(theme, text, value):
                return ItemListActionItem(theme: theme, title: text, kind: value != nil ? .neutral : .disabled, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    if let value = value {
                        arguments.displayPrivateLinkMenu(value)
                    }
                }, tag: ChannelVisibilityEntryTag.privateLink)
            case let .editablePublicLink(theme, currentText):
                return ItemListSingleLineInputItem(theme: theme, title: NSAttributedString(string: "t.me/", textColor: theme.list.itemPrimaryTextColor), text: currentText, placeholder: "", sectionId: self.section, textUpdated: { updatedText in
                    arguments.updatePublicLinkText(currentText, updatedText)
                }, action: {
                    
                })
            case let .privateLinkInfo(theme, text):
                return ItemListTextItem(theme: theme, text: .plain(text), sectionId: self.section)
            case let .publicLinkInfo(theme, text):
                return ItemListTextItem(theme: theme, text: .plain(text), sectionId: self.section)
            case let .publicLinkStatus(theme, text, status):
                var displayActivity = false
                let color: UIColor
                switch status {
                    case .invalidFormat:
                        color = theme.list.freeTextErrorColor
                    case let .availability(availability):
                        switch availability {
                            case .available:
                                color = theme.list.freeTextSuccessColor
                            case .invalid:
                                color = theme.list.freeTextErrorColor
                            case .taken:
                                color = theme.list.freeTextErrorColor
                        }
                    case .checking:
                        color = theme.list.freeTextColor
                        displayActivity = true
                }
                return ItemListActivityTextItem(displayActivity: displayActivity, text: NSAttributedString(string: text, textColor: color), sectionId: self.section)
            case let .existingLinksInfo(theme, text):
                return ItemListTextItem(theme: theme, text: .plain(text), sectionId: self.section)
            case let .existingLinkPeerItem(_, theme, strings, peer, editing, enabled):
                var label = ""
                if let addressName = peer.addressName {
                    label = "t.me/" + addressName
                }
                return ItemListPeerItem(account: arguments.account, peer: peer, presence: nil, text: .text(label), label: .none, editing: editing, switchValue: nil, enabled: enabled, sectionId: self.section, action: nil, setPeerIdWithRevealedOptions: { previousId, id in
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

private func channelVisibilityControllerEntries(presentationData: PresentationData, view: PeerView, publicChannelsToRevoke: [Peer]?, state: ChannelVisibilityControllerState) -> [ChannelVisibilityEntry] {
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
        
        entries.append(.typeHeader(presentationData.theme, isGroup ? presentationData.strings.GroupInfo_GroupType : presentationData.strings.Channel_Edit_LinkItem))
        entries.append(.typePublic(presentationData.theme, presentationData.strings.Channel_Setup_TypePublic, selectedType == .publicChannel))
        entries.append(.typePrivate(presentationData.theme, presentationData.strings.Channel_Setup_TypePrivate, selectedType == .privateChannel))
        
        switch selectedType {
            case .publicChannel:
                if isGroup {
                    entries.append(.typeInfo(presentationData.theme, "Public groups can be found in search, chat history is available to everyone and anyone can join."))
                } else {
                    entries.append(.typeInfo(presentationData.theme, "Public channels can be found in search and anyone can join."))
                }
            case .privateChannel:
                if isGroup {
                    entries.append(.typeInfo(presentationData.theme, "Private groups can only be joined if you were invited of have an invite link."))
                } else {
                    entries.append(.typeInfo(presentationData.theme, "Private channels can only be joined if you were invited of have an invite link."))
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
                        entries.append(.publicLinkAvailability(presentationData.theme, presentationData.strings.Group_Username_RemoveExistingUsernamesInfo, false))
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
                            entries.append(.existingLinkPeerItem(index, presentationData.theme, presentationData.strings, peer, ItemListPeerItemEditing(editable: true, editing: true, revealed: state.revealedRevokePeerId == peer.id), state.revokingPeerId == nil))
                            index += 1
                        }
                    } else {
                        entries.append(.publicLinkAvailability(presentationData.theme, presentationData.strings.Group_Username_CreatePublicLinkHelp, true))
                    }
                } else {
                    entries.append(.editablePublicLink(presentationData.theme, currentAddressName))
                    if let status = state.addressNameValidationStatus {
                        let text: String
                        switch status {
                            case let .invalidFormat(error):
                                switch error {
                                    case .startsWithDigit:
                                        text = "Names can't start with a digit."
                                    case .startsWithUnderscore:
                                        text = "Names can't start with an underscore."
                                    case .endsWithUnderscore:
                                        text = "Names can't end with an underscore."
                                    case .tooShort:
                                        text = "Names must have at least 5 characters."
                                    case .invalidCharacters:
                                        text = "Sorry, this name is invalid."
                                }
                            case let .availability(availability):
                                switch availability {
                                    case .available:
                                        text = "\(currentAddressName) is available."
                                    case .invalid:
                                        text = "Sorry, this name is invalid."
                                    case .taken:
                                        text = "\(currentAddressName) is already taken."
                                }
                            case .checking:
                                text = "Checking name..."
                        }
                        
                        entries.append(.publicLinkStatus(presentationData.theme, text, status))
                    }
                    entries.append(.publicLinkInfo(presentationData.theme, "People can share this link with others and find your group using Telegram search."))
                }
            case .privateChannel:
                let link = (view.cachedData as? CachedChannelData)?.exportedInvitation?.link
                let text: String
                if let link = link {
                    text = link
                } else {
                    text = "Loading..."
                }
                entries.append(.privateLink(presentationData.theme, text, link))
                if isGroup {
                    entries.append(.publicLinkInfo(presentationData.theme, "People can join your group by following this link. You can revoke the link at any time."))
                } else {
                    entries.append(.publicLinkInfo(presentationData.theme, "People can join your channel by following this link. You can revoke the link at any time."))
                }
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

public enum ChannelVisibilityControllerMode {
    case initialSetup
    case generic
}

public func channelVisibilityController(account: Account, peerId: PeerId, mode: ChannelVisibilityControllerMode) -> ViewController {
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
    var nextImpl: (() -> Void)?
    var displayPrivateLinkMenuImpl: ((String) -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    let checkAddressNameDisposable = MetaDisposable()
    actionsDisposable.add(checkAddressNameDisposable)
    
    let updateAddressNameDisposable = MetaDisposable()
    actionsDisposable.add(updateAddressNameDisposable)
    
    let revokeAddressNameDisposable = MetaDisposable()
    actionsDisposable.add(revokeAddressNameDisposable)
    
    actionsDisposable.add(ensuredExistingPeerExportedInvitation(account: account, peerId: peerId).start())
    
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
        |> deliverOnMainQueue
    
    let signal = combineLatest((account.applicationContext as! TelegramApplicationContext).presentationData, statePromise.get() |> deliverOnMainQueue, peerView, peersDisablingAddressNameAssignment.get() |> deliverOnMainQueue)
        |> deliverOnMainQueue
        |> map { presentationData, state, view, publicChannelsToRevoke -> (ItemListControllerState, (ItemListNodeState<ChannelVisibilityEntry>, ChannelVisibilityEntry.ItemGenerationArguments)) in
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
                
                rightNavigationButton = ItemListNavigationButton(title: mode == .initialSetup ? "Next" : "Done", style: state.updatingAddressName ? .activity : .bold, enabled: doneEnabled, action: {
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
                            
                            switch mode {
                                case .initialSetup:
                                    nextImpl?()
                                case .generic:
                                    dismissImpl?()
                            }
                        }))
                    } else {
                        switch mode {
                            case .initialSetup:
                                nextImpl?()
                            case .generic:
                                dismissImpl?()
                        }
                    }
                })
            }
            
            var isGroup = false
            if let peer = peer as? TelegramChannel {
                if case .group = peer.info {
                    isGroup = true
                }
            }
            
            let leftNavigationButton: ItemListNavigationButton?
            switch mode {
                case .initialSetup:
                    leftNavigationButton = nil
                case .generic:
                    leftNavigationButton = ItemListNavigationButton(title: "Cancel", style: .regular, enabled: true, action: {
                        dismissImpl?()
                    })
            }
            
            let controllerState = ItemListControllerState(theme: presentationData.theme, title: .text(isGroup ? "Group Type" : "Channel Link"), leftNavigationButton: leftNavigationButton, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: "Back"), animateChanges: false)
            let listState = ItemListNodeState(entries: channelVisibilityControllerEntries(presentationData: presentationData, view: view, publicChannelsToRevoke: publicChannelsToRevoke, state: state), style: .blocks, animateChanges: false)
            
            return (controllerState, (listState, arguments))
        } |> afterDisposed {
            actionsDisposable.dispose()
        }
    
    let controller = ItemListController(account: account, state: signal)
    dismissImpl = { [weak controller] in
        controller?.dismiss()
    }
    nextImpl = { [weak controller] in
        if let controller = controller {
            (controller.navigationController as? NavigationController)?.replaceAllButRootController(ChatController(account: account, peerId: peerId), animated: true)
        }
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
                strongController.present(contextMenuController, in: .window(.root), with: ContextMenuControllerPresentationArguments(sourceNodeAndRect: { [weak resultItemNode] in
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
