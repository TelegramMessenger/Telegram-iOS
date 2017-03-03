import Foundation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

private final class ConvertToSupergroupArguments {
    let convert: () -> Void
    
    init(convert: @escaping () -> Void) {
        self.convert = convert
    }
}

private enum ConvertToSupergroupSection: Int32 {
    case info
    case action
}

private enum ConvertToSupergroupEntry: ItemListNodeEntry {
    case info
    case action
    case actionInfo
    
    var section: ItemListSectionId {
        switch self {
            case .info:
                return ConvertToSupergroupSection.info.rawValue
            case .action, .actionInfo:
                return ConvertToSupergroupSection.action.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
            case .info:
                return 0
            case .action:
                return 1
            case .actionInfo:
                return 2
        }
    }
    
    static func ==(lhs: ConvertToSupergroupEntry, rhs: ConvertToSupergroupEntry) -> Bool {
        return lhs.stableId == rhs.stableId
    }
    
    static func <(lhs: ConvertToSupergroupEntry, rhs: ConvertToSupergroupEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(_ arguments: ConvertToSupergroupArguments) -> ListViewItem {
        switch self {
            case .info:
                return ItemListTextItem(text: "In supergroups:\n• New members can see the full message history\n• Deleted messages will disappear for all members\n• Admins can pin important messages\n• Creator can set a public link for the group", sectionId: self.section)
            case .action:
                return ItemListActionItem(title: "Convert to Supergroup", kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    arguments.convert()
                })
            case .actionInfo:
                return ItemListTextItem(text: "Note: this action can't be undone", sectionId: self.section)
        }
    }
}

private struct ConvertToSupergroupState: Equatable {
    let isConverting: Bool
    
    init() {
        self.isConverting = false
    }
    
    init(isConverting: Bool) {
        self.isConverting = isConverting
    }
    
    static func ==(lhs: ConvertToSupergroupState, rhs: ConvertToSupergroupState) -> Bool {
        if lhs.isConverting != rhs.isConverting {
            return false
        }
        return true
    }
}

private func convertToSupergroupEntries() -> [ConvertToSupergroupEntry] {
    var entries: [ConvertToSupergroupEntry] = []
    
    entries.append(.info)
    entries.append(.action)
    entries.append(.actionInfo)
    
    return entries
}

public func convertToSupergroupController(account: Account, peerId: PeerId) -> ViewController {
    var replaceControllerImpl: ((ViewController) -> Void)?
    
    let statePromise = ValuePromise(ConvertToSupergroupState(), ignoreRepeated: true)
    let stateValue = Atomic(value: ConvertToSupergroupState())
    let updateState: ((ConvertToSupergroupState) -> ConvertToSupergroupState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    let actionsDisposable = DisposableSet()
    
    let convertDisposable = MetaDisposable()
    actionsDisposable.add(convertDisposable)
    
    let arguments = ConvertToSupergroupArguments(convert: {
        var alreadyConverting = false
        updateState { state in
            if state.isConverting {
                alreadyConverting = true
            }
            return ConvertToSupergroupState(isConverting: true)
        }
        
        if !alreadyConverting {
            convertDisposable.set((convertGroupToSupergroup(account: account, peerId: peerId) |> deliverOnMainQueue).start(next: { createdPeerId in
                replaceControllerImpl?(ChatController(account: account, peerId: createdPeerId))
            }))
        }
    })
    
    let signal = statePromise.get()
        |> deliverOnMainQueue
        |> map { state -> (ItemListControllerState, (ItemListNodeState<ConvertToSupergroupEntry>, ConvertToSupergroupEntry.ItemGenerationArguments)) in
            
            var rightNavigationButton: ItemListNavigationButton?
            if state.isConverting {
                rightNavigationButton = ItemListNavigationButton(title: "", style: .activity, enabled: true, action: {})
            }
            
            let controllerState = ItemListControllerState(title: "Supergroup", leftNavigationButton: nil, rightNavigationButton: rightNavigationButton)
            let listState = ItemListNodeState(entries: convertToSupergroupEntries(), style: .blocks)
            
            return (controllerState, (listState, arguments))
        }
        |> afterDisposed {
            actionsDisposable.dispose()
        }
    
    let controller = ItemListController(signal)
    replaceControllerImpl = { [weak controller] c in
        if let controller = controller {
            (controller.navigationController as? NavigationController)?.replaceAllButRootController(c, animated: true)
        }
    }
    return controller
}
