import Foundation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

private struct CreateChannelArguments {
    let account: Account
    
    let updateEditingName: (ItemListAvatarAndNameInfoItemName) -> Void
    let updateEditingDescriptionText: (String) -> Void
    let done: () -> Void
}

private enum CreateChannelSection: Int32 {
    case info
    case description
}

private enum CreateChannelEntry: ItemListNodeEntry {
    case channelInfo(Peer?, ItemListAvatarAndNameInfoItemState)
    case setProfilePhoto
    
    case descriptionSetup(text: String)
    case descriptionInfo
    
    var section: ItemListSectionId {
        switch self {
            case .channelInfo, .setProfilePhoto:
                return CreateChannelSection.info.rawValue
            case .descriptionSetup, .descriptionInfo:
                return CreateChannelSection.description.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
            case .channelInfo:
                return 0
            case .setProfilePhoto:
                return 1
            case .descriptionSetup:
                return 2
            case .descriptionInfo:
                return 3
        }
    }
    
    static func ==(lhs: CreateChannelEntry, rhs: CreateChannelEntry) -> Bool {
        switch lhs {
            case let .channelInfo(lhsPeer, lhsEditingState):
                if case let .channelInfo(rhsPeer, rhsEditingState) = rhs {
                    if let lhsPeer = lhsPeer, let rhsPeer = rhsPeer {
                        if !lhsPeer.isEqual(rhsPeer) {
                            return false
                        }
                    } else if (lhsPeer != nil) != (rhsPeer != nil) {
                        return false
                    }
                    if lhsEditingState != rhsEditingState {
                        return false
                    }
                    return true
                } else {
                    return false
                }
            case .setProfilePhoto:
                if case .setProfilePhoto = rhs {
                    return true
                } else {
                    return false
                }
            case let .descriptionSetup(text):
                if case .descriptionSetup(text) = rhs {
                    return true
                } else {
                    return false
                }
            case .descriptionInfo:
                if case .descriptionInfo = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: CreateChannelEntry, rhs: CreateChannelEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(_ arguments: CreateChannelArguments) -> ListViewItem {
        switch self {
            case let .channelInfo(peer, state):
                return ItemListAvatarAndNameInfoItem(account: arguments.account, peer: peer, presence: nil, cachedData: nil, state: state, sectionId: ItemListSectionId(self.section), style: .blocks, editingNameUpdated: { editingName in
                    arguments.updateEditingName(editingName)
                })
            case .setProfilePhoto:
                return ItemListActionItem(title: "Set Profile Photo", kind: .generic, alignment: .natural, sectionId: ItemListSectionId(self.section), style: .blocks, action: {
                    
                })
            case let .descriptionSetup(text):
                return ItemListMultilineInputItem(text: text, placeholder: "Description", sectionId: self.section, style: .blocks, textUpdated: { updatedText in
                    arguments.updateEditingDescriptionText(updatedText)
                }, action: {
                    
                })
            case .descriptionInfo:
                return ItemListTextItem(text: .plain("You can provide an optional description for your channel."), sectionId: self.section)
        }
    }
}

private struct CreateChannelState: Equatable {
    let creating: Bool
    let editingName: ItemListAvatarAndNameInfoItemName
    let editingDescriptionText: String
    
    init(creating: Bool, editingName: ItemListAvatarAndNameInfoItemName, editingDescriptionText: String) {
        self.creating = creating
        self.editingName = editingName
        self.editingDescriptionText = editingDescriptionText
    }
    
    init() {
        self.creating = false
        self.editingName = .title(title: "")
        self.editingDescriptionText = ""
    }
    
    static func ==(lhs: CreateChannelState, rhs: CreateChannelState) -> Bool {
        if lhs.creating != rhs.creating {
            return false
        }
        if lhs.editingName != rhs.editingName {
            return false
        }
        if lhs.editingDescriptionText != rhs.editingDescriptionText {
            return false
        }
        return true
    }
}

private func CreateChannelEntries(state: CreateChannelState) -> [CreateChannelEntry] {
    var entries: [CreateChannelEntry] = []
    
    let groupInfoState = ItemListAvatarAndNameInfoItemState(editingName: state.editingName, updatingName: nil)
    
    let peer = TelegramGroup(id: PeerId(namespace: 100, id: 0), title: state.editingName.composedTitle, photo: [], participantCount: 0, role: .creator, membership: .Member, flags: [], migrationReference: nil, creationDate: 0, version: 0)
    
    entries.append(.channelInfo(peer, groupInfoState))
    entries.append(.setProfilePhoto)
    
    entries.append(.descriptionSetup(text: state.editingDescriptionText))
    entries.append(.descriptionInfo)
    
    return entries
}

public func createChannelController(account: Account) -> ViewController {
    let initialState = CreateChannelState()
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((CreateChannelState) -> CreateChannelState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var replaceControllerImpl: ((ViewController) -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    let arguments = CreateChannelArguments(account: account, updateEditingName: { editingName in
        updateState { current in
            return CreateChannelState(creating: current.creating, editingName: editingName, editingDescriptionText: current.editingDescriptionText)
        }
    }, updateEditingDescriptionText: { text in
        updateState { current in
            return CreateChannelState(creating: current.creating, editingName: current.editingName, editingDescriptionText: text)
        }
    }, done: {
        let (creating, title, description) = stateValue.with { state -> (Bool, String, String) in
            return (state.creating, state.editingName.composedTitle, state.editingDescriptionText)
        }
        
        if !creating && !title.isEmpty {
            updateState { current in
                return CreateChannelState(creating: true, editingName: current.editingName, editingDescriptionText: current.editingDescriptionText)
            }
            
            actionsDisposable.add((createChannel(account: account, title: title, description: description.isEmpty ? nil : description) |> deliverOnMainQueue |> afterDisposed {
                Queue.mainQueue().async {
                    updateState { current in
                        return CreateChannelState(creating: false, editingName: current.editingName, editingDescriptionText: current.editingDescriptionText)
                    }
                }
            }).start(next: { peerId in
                if let peerId = peerId {
                    let controller = channelVisibilityController(account: account, peerId: peerId, mode: .initialSetup)
                    replaceControllerImpl?(controller)
                }
            }, error: { _ in
                
            }))
        }
    })
    
    let signal = statePromise.get()
        |> map { state -> (ItemListControllerState, (ItemListNodeState<CreateChannelEntry>, CreateChannelEntry.ItemGenerationArguments)) in
            
            let rightNavigationButton: ItemListNavigationButton
            if state.creating {
                rightNavigationButton = ItemListNavigationButton(title: "", style: .activity, enabled: true, action: {})
            } else {
                rightNavigationButton = ItemListNavigationButton(title: "Next", style: .bold, enabled: !state.editingName.composedTitle.isEmpty, action: {
                    arguments.done()
                })
            }
            
            let controllerState = ItemListControllerState(title: "Create Channel", leftNavigationButton: nil, rightNavigationButton: rightNavigationButton)
            let listState = ItemListNodeState(entries: CreateChannelEntries(state: state), style: .blocks)
            
            return (controllerState, (listState, arguments))
        } |> afterDisposed {
            actionsDisposable.dispose()
        }
    
    let controller = ItemListController(signal)
    controller.navigationItem.backBarButtonItem = UIBarButtonItem(title: "Back", style: .plain, target: nil, action: nil)
    replaceControllerImpl = { [weak controller] value in
        (controller?.navigationController as? NavigationController)?.replaceAllButRootController(value, animated: true)
    }
    return controller
}
