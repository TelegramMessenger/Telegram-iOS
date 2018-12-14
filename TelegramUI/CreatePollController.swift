import Foundation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

private final class CreatePollControllerArguments {
    let updatePollText: (String) -> Void
    let updateOptionText: (Int, String) -> Void
    let addOption: () -> Void
    let removeOption: (Int) -> Void
    let setItemIdWithRevealedOptions: (Int?, Int?) -> Void
    
    init(updatePollText: @escaping (String) -> Void, updateOptionText: @escaping (Int, String) -> Void, addOption: @escaping () -> Void, removeOption: @escaping (Int) -> Void, setItemIdWithRevealedOptions: @escaping (Int?, Int?) -> Void) {
        self.updatePollText = updatePollText
        self.updateOptionText = updateOptionText
        self.addOption = addOption
        self.removeOption = removeOption
        self.setItemIdWithRevealedOptions = setItemIdWithRevealedOptions
    }
}

private enum CreatePollSection: Int32 {
    case text
    case options
}

private enum CreatePollEntryTag: Equatable, ItemListItemTag {
    case text
    case option(Int)
    
    func isEqual(to other: ItemListItemTag) -> Bool {
        if let other = other as? CreatePollEntryTag {
            return self == other
        } else {
            return false
        }
    }
}

private enum CreatePollEntry: ItemListNodeEntry {
    case textHeader(PresentationTheme, String)
    case text(PresentationTheme, String, String)
    case optionsHeader(PresentationTheme, String)
    case option(PresentationTheme, PresentationStrings, Int, Int, String, String, Bool)
    case addOption(PresentationTheme, String, Bool)
    case optionsInfo(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
            case .textHeader, .text:
                return CreatePollSection.text.rawValue
            case .optionsHeader, .option, .addOption, .optionsInfo:
                return CreatePollSection.options.rawValue
        }
    }
    
    var stableId: Int {
        switch self {
            case .textHeader:
                return 0
            case .text:
                return 1
            case .optionsHeader:
                return 2
            case let .option(_, _, id, _, _, _, _):
                return 3 + id
            case .addOption:
                return 1000
            case .optionsInfo:
                return 1001
        }
    }
    
    private var sortId: Int {
        switch self {
            case .textHeader:
                return 0
            case .text:
                return 1
            case .optionsHeader:
                return 2
            case let .option(_, _, _, index, _, _, _):
                return 3 + index
            case .addOption:
                return 1000
            case .optionsInfo:
                return 1001
        }
    }
    
    static func <(lhs: CreatePollEntry, rhs: CreatePollEntry) -> Bool {
        return lhs.sortId < rhs.sortId
    }
    
    func item(_ arguments: CreatePollControllerArguments) -> ListViewItem {
        switch self {
            case let .textHeader(theme, text):
                return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
            case let .text(theme, placeholder, text):
                return ItemListMultilineInputItem(theme: theme, text: text, placeholder: placeholder, maxLength: nil, sectionId: self.section, style: .blocks, textUpdated: { value in
                    arguments.updatePollText(value)
                }, tag: CreatePollEntryTag.text, action: {})
            case let .optionsHeader(theme, text):
                return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
            case let .option(theme, strings, id, _, placeholder, text, revealed):
                return CreatePollOptionItem(theme: theme, strings: strings, id: id, placeholder: placeholder, value: text, editing: CreatePollOptionItemEditing(editable: true, hasActiveRevealControls: revealed), sectionId: self.section, setItemIdWithRevealedOptions: { id, fromId in
                    arguments.setItemIdWithRevealedOptions(id, fromId)
                }, updated: { value in
                    arguments.updateOptionText(id, value)
                }, delete: {
                    arguments.removeOption(id)
                }, tag: CreatePollEntryTag.option(id))
            case let .addOption(theme, title, enabled):
                return CreatePollOptionActionItem(theme: theme, title: title, enabled: enabled, sectionId: self.section, action: {
                    arguments.addOption()
                })
            case let .optionsInfo(theme, text):
                return ItemListTextItem(theme: theme, text: .plain(text), sectionId: self.section)
        }
    }
}

private struct CreatePollControllerOption: Equatable {
    var text: String
    let id: Int
}

private struct CreatePollControllerState: Equatable {
    var text: String = ""
    var options: [CreatePollControllerOption] = [CreatePollControllerOption(text: "", id: 0)]
    var nextOptionId: Int = 1
    var optionIdWithRevealControls: Int?
}

private func createPollControllerEntries(presentationData: PresentationData, state: CreatePollControllerState) -> [CreatePollEntry] {
    var entries: [CreatePollEntry] = []
    
    entries.append(.textHeader(presentationData.theme, presentationData.strings.CreatePoll_TextHeader))
    entries.append(.text(presentationData.theme, presentationData.strings.CreatePoll_TextPlaceholder, state.text))
    entries.append(.optionsHeader(presentationData.theme, presentationData.strings.CreatePoll_OptionsHeader))
    for i in 0 ..< state.options.count {
        entries.append(.option(presentationData.theme, presentationData.strings, state.options[i].id, i, presentationData.strings.CreatePoll_OptionPlaceholder, state.options[i].text, state.optionIdWithRevealControls == state.options[i].id))
    }
    entries.append(.addOption(presentationData.theme, presentationData.strings.CreatePoll_AddOption, state.options.count < 10))
    entries.append(.optionsInfo(presentationData.theme, presentationData.strings.CreatePoll_OptionsInfo))
    
    return entries
}

public func createPollController(account: Account, peerId: PeerId) -> ViewController {
    let statePromise = ValuePromise(CreatePollControllerState(), ignoreRepeated: true)
    let stateValue = Atomic(value: CreatePollControllerState())
    let updateState: ((CreatePollControllerState) -> CreatePollControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var dismissImpl: (() -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    let checkAddressNameDisposable = MetaDisposable()
    actionsDisposable.add(checkAddressNameDisposable)
    
    let updateAddressNameDisposable = MetaDisposable()
    actionsDisposable.add(updateAddressNameDisposable)
    
    let arguments = CreatePollControllerArguments(updatePollText: { value in
        updateState { state in
            var state = state
            state.text = value
            return state
        }
    }, updateOptionText: { id, value in
        updateState { state in
            var state = state
            for i in 0 ..< state.options.count {
                if state.options[i].id == id {
                    state.options[i].text = value
                }
            }
            return state
        }
    }, addOption: {
        updateState { state in
            var state = state
            state.options.append(CreatePollControllerOption(text: "", id: state.nextOptionId))
            state.nextOptionId += 1
            return state
        }
    }, removeOption: { id in
        updateState { state in
            var state = state
            state.options = state.options.filter({ $0.id != id })
            return state
        }
    }, setItemIdWithRevealedOptions: { id, fromId in
        updateState { state in
            var state = state
            if (id == nil && fromId == state.optionIdWithRevealControls) || (id != nil && fromId == nil) {
                state.optionIdWithRevealControls = id
                return state
            } else {
                return state
            }
        }
    })
    
    let previousOptionIds = Atomic<[Int]?>(value: nil)
    
    let signal = combineLatest((account.applicationContext as! TelegramApplicationContext).presentationData, statePromise.get() |> deliverOnMainQueue)
    |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState<CreatePollEntry>, CreatePollEntry.ItemGenerationArguments)) in
        var enabled = true
        if state.text.isEmpty {
            enabled = false
        }
        for option in state.options {
            if option.text.isEmpty {
                enabled = false
            }
        }
        var rightNavigationButton: ItemListNavigationButton?
        rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.CreatePoll_Create), style: .regular, enabled: enabled, action: {
            let state = stateValue.with { $0 }
            var options: [TelegramMediaPollOption] = []
            for i in 0 ..< state.options.count {
                options.append(TelegramMediaPollOption(text: state.options[i].text, opaqueIdentifier: "\(i)".data(using: .utf8)!))
            }
            let _ = enqueueMessages(account: account, peerId: peerId, messages: [.message(text: "", attributes: [], mediaReference: .standalone(media: TelegramMediaPoll(text: state.text, options: options, results: nil)), replyToMessageId: nil, localGroupingKey: nil)]).start()
            dismissImpl?()
        })
        
        let leftNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Cancel), style: .regular, enabled: true, action: {
            dismissImpl?()
        })
        
        let optionIds = state.options.map { $0.id }
        let previousIds = previousOptionIds.swap(optionIds)
        
        var focusItemTag: ItemListItemTag?
        if state.nextOptionId == 1 {
            focusItemTag = CreatePollEntryTag.text
        } else {
            focusItemTag = CreatePollEntryTag.option(state.nextOptionId - 1)
        }
        
        let controllerState = ItemListControllerState(theme: presentationData.theme, title: .text(presentationData.strings.CreatePoll_Title), leftNavigationButton: leftNavigationButton, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
        let listState = ItemListNodeState(entries: createPollControllerEntries(presentationData: presentationData, state: state), style: .blocks, focusItemTag: focusItemTag, animateChanges: previousIds != nil && previousIds != optionIds)
        
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
        actionsDisposable.dispose()
    }
    
    let controller = ItemListController(account: account, state: signal)
    controller.enableInteractiveDismiss = true
    dismissImpl = { [weak controller] in
        controller?.view.endEditing(true)
        controller?.dismiss()
    }
    
    controller.reorderEntry = { fromIndex, toIndex, entries in
        let fromEntry = entries[fromIndex]
        guard case let .option(_, _, id, _, _, _, _) = fromEntry else {
            return
        }
        var referenceId: Int?
        var beforeAll = false
        var afterAll = false
        if toIndex < entries.count {
            switch entries[toIndex] {
                case let .option(_, _, toId, _, _, _, _):
                    referenceId = toId
                default:
                    if entries[toIndex] < fromEntry {
                        beforeAll = true
                    } else {
                        afterAll = true
                    }
            }
        } else {
            afterAll = true
        }
        updateState { state in
            var state = state
            var options = state.options
            var reorderOption: CreatePollControllerOption?
            for i in 0 ..< options.count {
                if options[i].id == id {
                    reorderOption = options[i]
                    options.remove(at: i)
                    break
                }
            }
            if let reorderOption = reorderOption {
                if let referenceId = referenceId {
                    var inserted = false
                    for i in 0 ..< options.count {
                        if options[i].id == referenceId {
                            if fromIndex < toIndex {
                                options.insert(reorderOption, at: i + 1)
                            } else {
                                options.insert(reorderOption, at: i)
                            }
                            inserted = true
                            break
                        }
                    }
                    if !inserted {
                        options.append(reorderOption)
                    }
                } else if beforeAll {
                    options.insert(reorderOption, at: 0)
                } else if afterAll {
                    options.append(reorderOption)
                }
                state.options = options
            }
            return state
        }
    }
    
    return controller
}
