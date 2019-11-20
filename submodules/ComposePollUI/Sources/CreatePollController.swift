import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import SyncCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import AlertUI
import PresentationDataUtils

private let maxTextLength = 255
private let maxOptionLength = 100

private func processPollText(_ text: String) -> String {
    var text = text.trimmingCharacters(in: .whitespacesAndNewlines)
    while text.contains("\n\n\n") {
        text = text.replacingOccurrences(of: "\n\n\n", with: "\n\n")
    }
    return text
}

private final class CreatePollControllerArguments {
    let updatePollText: (String) -> Void
    let updateOptionText: (Int, String) -> Void
    let moveToNextOption: (Int) -> Void
    let addOption: () -> Void
    let removeOption: (Int, Bool) -> Void
    let optionFocused: (Int) -> Void
    let setItemIdWithRevealedOptions: (Int?, Int?) -> Void
    
    init(updatePollText: @escaping (String) -> Void, updateOptionText: @escaping (Int, String) -> Void, moveToNextOption: @escaping (Int) -> Void, addOption: @escaping () -> Void, removeOption: @escaping (Int, Bool) -> Void, optionFocused: @escaping (Int) -> Void, setItemIdWithRevealedOptions: @escaping (Int?, Int?) -> Void) {
        self.updatePollText = updatePollText
        self.updateOptionText = updateOptionText
        self.moveToNextOption = moveToNextOption
        self.addOption = addOption
        self.removeOption = removeOption
        self.optionFocused = optionFocused
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
    case addOption(Int)
    
    func isEqual(to other: ItemListItemTag) -> Bool {
        if let other = other as? CreatePollEntryTag {
            return self == other
        } else {
            return false
        }
    }
}

private enum CreatePollEntry: ItemListNodeEntry {
    case textHeader(PresentationTheme, String, ItemListSectionHeaderAccessoryText)
    case text(PresentationTheme, String, String, Int)
    case optionsHeader(PresentationTheme, String)
    case option(PresentationTheme, PresentationStrings, Int, Int, String, String, Bool, Bool)
    case addOption(PresentationTheme, String, Bool, Int)
    case optionsInfo(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
            case .textHeader, .text:
                return CreatePollSection.text.rawValue
            case .optionsHeader, .option, .addOption, .optionsInfo:
                return CreatePollSection.options.rawValue
        }
    }
    
    var tag: ItemListItemTag? {
        switch self {
            case .text:
                return CreatePollEntryTag.text
            case let .option(_, _, id, _, _, _, _, _):
                return CreatePollEntryTag.option(id)
            case let .addOption(_, _, _, id):
                return CreatePollEntryTag.addOption(id)
            default:
                break
        }
        return nil
    }
    
    var stableId: Int {
        switch self {
            case .textHeader:
                return 0
            case .text:
                return 1
            case .optionsHeader:
                return 2
            case let .option(_, _, id, _, _, _, _, _):
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
            case let .option(_, _, _, index, _, _, _, _):
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
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! CreatePollControllerArguments
        switch self {
            case let .textHeader(theme, text, accessoryText):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, accessoryText: accessoryText, sectionId: self.section)
            case let .text(theme, placeholder, text, maxLength):
                return ItemListMultilineInputItem(presentationData: presentationData, text: text, placeholder: placeholder, maxLength: ItemListMultilineInputItemTextLimit(value: maxLength, display: false), sectionId: self.section, style: .blocks, textUpdated: { value in
                    arguments.updatePollText(value)
                }, tag: CreatePollEntryTag.text)
            case let .optionsHeader(theme, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .option(theme, strings, id, _, placeholder, text, revealed, hasNext):
                return CreatePollOptionItem(theme: theme, strings: strings, id: id, placeholder: placeholder, value: text, maxLength: maxOptionLength, editing: CreatePollOptionItemEditing(editable: true, hasActiveRevealControls: revealed), sectionId: self.section, setItemIdWithRevealedOptions: { id, fromId in
                    arguments.setItemIdWithRevealedOptions(id, fromId)
                }, updated: { value in
                    arguments.updateOptionText(id, value)
                }, next: hasNext ? {
                    arguments.moveToNextOption(id)
                } : nil, delete: { focused in
                    arguments.removeOption(id, focused)
                }, focused: {
                    arguments.optionFocused(id)
                }, tag: CreatePollEntryTag.option(id))
            case let .addOption(theme, title, enabled, id):
                return CreatePollOptionActionItem(theme: theme, title: title, enabled: enabled, tag: CreatePollEntryTag.addOption(id), sectionId: self.section, action: {
                    arguments.addOption()
                })
            case let .optionsInfo(theme, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private struct CreatePollControllerOption: Equatable {
    var text: String
    let id: Int
}

private struct CreatePollControllerState: Equatable {
    var text: String = ""
    var options: [CreatePollControllerOption] = [CreatePollControllerOption(text: "", id: 0), CreatePollControllerOption(text: "", id: 1)]
    var nextOptionId: Int = 2
    var focusOptionId: Int?
    var optionIdWithRevealControls: Int?
}

private func createPollControllerEntries(presentationData: PresentationData, state: CreatePollControllerState, limitsConfiguration: LimitsConfiguration) -> [CreatePollEntry] {
    var entries: [CreatePollEntry] = []
    
    var textLimitText = ItemListSectionHeaderAccessoryText(value: "", color: .generic)
    if state.text.count >= Int(maxTextLength) * 70 / 100 {
        let remainingCount = Int(maxTextLength) - state.text.count
        textLimitText = ItemListSectionHeaderAccessoryText(value: "\(remainingCount)", color: remainingCount < 0 ? .destructive : .generic)
    }
    entries.append(.textHeader(presentationData.theme, presentationData.strings.CreatePoll_TextHeader, textLimitText))
    entries.append(.text(presentationData.theme, presentationData.strings.CreatePoll_TextPlaceholder, state.text, Int(limitsConfiguration.maxMediaCaptionLength)))
    entries.append(.optionsHeader(presentationData.theme, presentationData.strings.CreatePoll_OptionsHeader))
    for i in 0 ..< state.options.count {
        entries.append(.option(presentationData.theme, presentationData.strings, state.options[i].id, i, presentationData.strings.CreatePoll_OptionPlaceholder, state.options[i].text, state.optionIdWithRevealControls == state.options[i].id, i != 9))
    }
    if state.options.count < 10 {
        entries.append(.addOption(presentationData.theme, presentationData.strings.CreatePoll_AddOption, true, state.options.last?.id ?? -1))
        entries.append(.optionsInfo(presentationData.theme, presentationData.strings.CreatePoll_AddMoreOptions(Int32(10 - state.options.count))))
    } else {
        entries.append(.optionsInfo(presentationData.theme, presentationData.strings.CreatePoll_AllOptionsAdded))
    }
    
    return entries
}

public func createPollController(context: AccountContext, peerId: PeerId, completion: @escaping (EnqueueMessage) -> Void) -> ViewController {
    let statePromise = ValuePromise(CreatePollControllerState(), ignoreRepeated: true)
    let stateValue = Atomic(value: CreatePollControllerState())
    let updateState: ((CreatePollControllerState) -> CreatePollControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var presentControllerImpl: ((ViewController, Any?) -> Void)?
    var dismissImpl: (() -> Void)?
    var ensureTextVisibleImpl: (() -> Void)?
    var ensureOptionVisibleImpl: ((Int) -> Void)?
    
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
        ensureTextVisibleImpl?()
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
        ensureOptionVisibleImpl?(id)
    }, moveToNextOption: { id in
        var resetFocusOptionId: Int?
        updateState { state in
            var state = state
            for i in 0 ..< state.options.count {
                if state.options[i].id == id {
                    if i == state.options.count - 1 {
                        state.options.append(CreatePollControllerOption(text: "", id: state.nextOptionId))
                        state.focusOptionId = state.nextOptionId
                        state.nextOptionId += 1
                    } else {
                        if state.focusOptionId == state.options[i + 1].id {
                            resetFocusOptionId = state.options[i + 1].id
                            state.focusOptionId = -1
                        } else {
                            state.focusOptionId = state.options[i + 1].id
                        }
                    }
                    break
                }
            }
            return state
        }
        if let resetFocusOptionId = resetFocusOptionId {
            updateState { state in
                var state = state
                state.focusOptionId = resetFocusOptionId
                return state
            }
        }
    }, addOption: {
        updateState { state in
            var state = state
            state.options.append(CreatePollControllerOption(text: "", id: state.nextOptionId))
            state.focusOptionId = state.nextOptionId
            state.nextOptionId += 1
            return state
        }
    }, removeOption: { id, focused in
        updateState { state in
            var state = state
            for i in 0 ..< state.options.count {
                if state.options[i].id == id {
                    state.options.remove(at: i)
                    if focused && i != 0 {
                        state.focusOptionId = state.options[i - 1].id
                    }
                    break
                }
            }
            return state
        }
    }, optionFocused: { id in
        ensureOptionVisibleImpl?(id)
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
    
    let limitsKey = PostboxViewKey.preferences(keys: Set([PreferencesKeys.limitsConfiguration]))
    let signal = combineLatest(context.sharedContext.presentationData, statePromise.get() |> deliverOnMainQueue, context.account.postbox.combinedView(keys: [limitsKey]))
    |> map { presentationData, state, combinedView -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let limitsConfiguration: LimitsConfiguration = (combinedView.views[limitsKey] as? PreferencesView)?.values[PreferencesKeys.limitsConfiguration] as? LimitsConfiguration ?? LimitsConfiguration.defaultValue
        
        var enabled = true
        if processPollText(state.text).isEmpty {
            enabled = false
        }
        if state.text.count > maxTextLength {
            enabled = false
        }
        var nonEmptyOptionCount = 0
        for option in state.options {
            if !option.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                nonEmptyOptionCount += 1
            }
            if option.text.count > maxOptionLength {
                enabled = false
            }
        }
        if nonEmptyOptionCount < 2 {
            enabled = false
        }
        var rightNavigationButton: ItemListNavigationButton?
        rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.CreatePoll_Create), style: .bold, enabled: enabled, action: {
            let state = stateValue.with { $0 }
            var options: [TelegramMediaPollOption] = []
            for i in 0 ..< state.options.count {
                let optionText = state.options[i].text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !optionText.isEmpty {
                    options.append(TelegramMediaPollOption(text: optionText, opaqueIdentifier: "\(i)".data(using: .utf8)!))
                }
            }
            completion(.message(text: "", attributes: [], mediaReference: .standalone(media: TelegramMediaPoll(pollId: MediaId(namespace: Namespaces.Media.LocalPoll, id: arc4random64()), text: processPollText(state.text), options: options, results: TelegramMediaPollResults(voters: nil, totalVoters: nil), isClosed: false)), replyToMessageId: nil, localGroupingKey: nil))
            dismissImpl?()
        })
        
        let leftNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Cancel), style: .regular, enabled: true, action: {
            let state = stateValue.with { $0 }
            var hasNonEmptyOptions = false
            for i in 0 ..< state.options.count {
                let optionText = state.options[i].text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !optionText.isEmpty {
                    hasNonEmptyOptions = true
                }
            }
            if hasNonEmptyOptions || !state.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                presentControllerImpl?(textAlertController(context: context, title: nil, text: presentationData.strings.CreatePoll_CancelConfirmation, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_No, action: {}), TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_Yes, action: {
                    dismissImpl?()
                })]), nil)
            } else {
                dismissImpl?()
            }
        })
        
        let optionIds = state.options.map { $0.id }
        let previousIds = previousOptionIds.swap(optionIds)
        
        var focusItemTag: ItemListItemTag?
        var ensureVisibleItemTag: ItemListItemTag?
        if let focusOptionId = state.focusOptionId {
            focusItemTag = CreatePollEntryTag.option(focusOptionId)
            if focusOptionId == state.options.last?.id {
                ensureVisibleItemTag = CreatePollEntryTag.addOption(focusOptionId)
            } else {
                ensureVisibleItemTag = focusItemTag
            }
        } else {
            focusItemTag = CreatePollEntryTag.text
            ensureVisibleItemTag = focusItemTag
        }
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.CreatePoll_Title), leftNavigationButton: leftNavigationButton, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: createPollControllerEntries(presentationData: presentationData, state: state, limitsConfiguration: limitsConfiguration), style: .blocks, focusItemTag: focusItemTag, ensureVisibleItemTag: ensureVisibleItemTag, animateChanges: previousIds != nil && previousIds != optionIds)
        
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
        actionsDisposable.dispose()
    }
    
    let controller = ItemListController(context: context, state: signal)
    controller.navigationPresentation = .modal
    presentControllerImpl = { [weak controller] c, a in
        controller?.present(c, in: .window(.root), with: a)
    }
    dismissImpl = { [weak controller] in
        //controller?.view.endEditing(true)
        controller?.dismiss()
    }
    ensureTextVisibleImpl = { [weak controller] in
        controller?.afterLayout({
            guard let controller = controller else {
                return
            }
            
            var resultItemNode: ListViewItemNode?
            let _ = controller.frameForItemNode({ itemNode in
                if let itemNode = itemNode as? ItemListItemNode {
                    if let tag = itemNode.tag, tag.isEqual(to: CreatePollEntryTag.text) {
                        resultItemNode = itemNode as? ListViewItemNode
                        return true
                    }
                }
                return false
            })
            if let resultItemNode = resultItemNode {
                controller.ensureItemNodeVisible(resultItemNode)
            }
        })
    }
    ensureOptionVisibleImpl = { [weak controller] id in
        controller?.afterLayout({
            guard let controller = controller else {
                return
            }
            
            var resultItemNode: ListViewItemNode?
            let state = stateValue.with({ $0 })
            if state.options.last?.id == id {
                let _ = controller.frameForItemNode({ itemNode in
                    if let itemNode = itemNode as? ItemListItemNode {
                        if let tag = itemNode.tag, tag.isEqual(to: CreatePollEntryTag.addOption(id)) {
                            resultItemNode = itemNode as? ListViewItemNode
                            return true
                        }
                    }
                    return false
                })
            }
            if resultItemNode == nil {
                let _ = controller.frameForItemNode({ itemNode in
                    if let itemNode = itemNode as? ItemListItemNode {
                        if let tag = itemNode.tag, tag.isEqual(to: CreatePollEntryTag.option(id)) {
                            resultItemNode = itemNode as? ListViewItemNode
                            return true
                        }
                    }
                    return false
                })
            }
                
            if let resultItemNode = resultItemNode {
                controller.ensureItemNodeVisible(resultItemNode)
            }
        })
    }
    
    controller.setReorderEntry({ (fromIndex: Int, toIndex: Int, entries: [CreatePollEntry]) -> Void in
        let fromEntry = entries[fromIndex]
        guard case let .option(_, _, id, _, _, _, _, _) = fromEntry else {
            return
        }
        var referenceId: Int?
        var beforeAll = false
        var afterAll = false
        if toIndex < entries.count {
            switch entries[toIndex] {
                case let .option(_, _, toId, _, _, _, _, _):
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
    })
    controller.isOpaqueWhenInOverlay = true
    controller.blocksBackgroundWhenInOverlay = true
    controller.experimentalSnapScrollToItem = true
    
    return controller
}
