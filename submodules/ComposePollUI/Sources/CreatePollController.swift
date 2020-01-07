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
    let moveToPreviousOption: (Int) -> Void
    let removeOption: (Int, Bool) -> Void
    let optionFocused: (Int) -> Void
    let setItemIdWithRevealedOptions: (Int?, Int?) -> Void
    let toggleOptionSelected: (Int) -> Void
    let updateAnonymous: (Bool) -> Void
    let updateMultipleChoice: (Bool) -> Void
    let updateQuiz: (Bool) -> Void
    
    init(updatePollText: @escaping (String) -> Void, updateOptionText: @escaping (Int, String) -> Void, moveToNextOption: @escaping (Int) -> Void, moveToPreviousOption: @escaping (Int) -> Void, removeOption: @escaping (Int, Bool) -> Void, optionFocused: @escaping (Int) -> Void, setItemIdWithRevealedOptions: @escaping (Int?, Int?) -> Void, toggleOptionSelected: @escaping (Int) -> Void, updateAnonymous: @escaping (Bool) -> Void, updateMultipleChoice: @escaping (Bool) -> Void, updateQuiz: @escaping (Bool) -> Void) {
        self.updatePollText = updatePollText
        self.updateOptionText = updateOptionText
        self.moveToNextOption = moveToNextOption
        self.moveToPreviousOption = moveToPreviousOption
        self.removeOption = removeOption
        self.optionFocused = optionFocused
        self.setItemIdWithRevealedOptions = setItemIdWithRevealedOptions
        self.toggleOptionSelected = toggleOptionSelected
        self.updateAnonymous = updateAnonymous
        self.updateMultipleChoice = updateMultipleChoice
        self.updateQuiz = updateQuiz
    }
}

private enum CreatePollSection: Int32 {
    case text
    case options
    case settings
}

private enum CreatePollEntryId: Hashable {
    case textHeader
    case text
    case optionsHeader
    case option(Int)
    case optionsInfo
    case anonymousVotes
    case multipleChoice
    case quiz
    case quizInfo
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
    case textHeader(String, ItemListSectionHeaderAccessoryText)
    case text(String, String, Int)
    case optionsHeader(String)
    case option(id: Int, index: Int, placeholder: String, text: String, revealed: Bool, hasNext: Bool, isLast: Bool, isSelected: Bool?)
    case optionsInfo(String)
    case anonymousVotes(String, Bool)
    case multipleChoice(String, Bool, Bool)
    case quiz(String, Bool)
    case quizInfo(String)
    
    var section: ItemListSectionId {
        switch self {
        case .textHeader, .text:
            return CreatePollSection.text.rawValue
        case .optionsHeader, .option, .optionsInfo:
            return CreatePollSection.options.rawValue
        case .anonymousVotes, .multipleChoice, .quiz, .quizInfo:
            return CreatePollSection.settings.rawValue
        }
    }
    
    var tag: ItemListItemTag? {
        switch self {
        case .text:
            return CreatePollEntryTag.text
        case let .option(option):
            return CreatePollEntryTag.option(option.id)
        default:
            break
        }
        return nil
    }
    
    var stableId: CreatePollEntryId {
        switch self {
        case .textHeader:
            return .textHeader
        case .text:
            return .text
        case .optionsHeader:
            return .optionsHeader
        case let .option(option):
            return .option(option.id)
        case .optionsInfo:
            return .optionsInfo
        case .anonymousVotes:
            return .anonymousVotes
        case .multipleChoice:
            return .multipleChoice
        case .quiz:
            return .quiz
        case .quizInfo:
            return .quizInfo
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
        case let .option(option):
            return 3 + option.index
        case .optionsInfo:
            return 1001
        case .anonymousVotes:
            return 1002
        case .multipleChoice:
            return 1003
        case .quiz:
            return 1004
        case .quizInfo:
            return 1005
        }
    }
    
    static func <(lhs: CreatePollEntry, rhs: CreatePollEntry) -> Bool {
        return lhs.sortId < rhs.sortId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! CreatePollControllerArguments
        switch self {
        case let .textHeader(text, accessoryText):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, accessoryText: accessoryText, sectionId: self.section)
        case let .text(placeholder, text, maxLength):
            return ItemListMultilineInputItem(presentationData: presentationData, text: text, placeholder: placeholder, maxLength: ItemListMultilineInputItemTextLimit(value: maxLength, display: false), sectionId: self.section, style: .blocks, textUpdated: { value in
                arguments.updatePollText(value)
            }, tag: CreatePollEntryTag.text)
        case let .optionsHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .option(id, _, placeholder, text, revealed, hasNext, isLast, isSelected):
            return CreatePollOptionItem(presentationData: presentationData, id: id, placeholder: placeholder, value: text, isSelected: isSelected, maxLength: maxOptionLength, editing: CreatePollOptionItemEditing(editable: true, hasActiveRevealControls: revealed), sectionId: self.section, setItemIdWithRevealedOptions: { id, fromId in
                arguments.setItemIdWithRevealedOptions(id, fromId)
            }, updated: { value in
                arguments.updateOptionText(id, value)
            }, next: hasNext ? {
                arguments.moveToNextOption(id)
            } : nil, delete: { focused in
                if !isLast {
                    arguments.removeOption(id, focused)
                } else {
                    arguments.moveToPreviousOption(id)
                }
            }, canDelete: !isLast,
            focused: {
                arguments.optionFocused(id)
            }, toggleSelected: {
                arguments.toggleOptionSelected(id)
            }, tag: CreatePollEntryTag.option(id))
        case let .optionsInfo(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .anonymousVotes(text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateAnonymous(value)
            })
        case let .multipleChoice(text, value, enabled):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, enabled: enabled, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateMultipleChoice(value)
            })
        case let .quiz(text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateQuiz(value)
            })
        case let .quizInfo(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private struct CreatePollControllerOption: Equatable {
    var text: String
    let id: Int
    var isSelected: Bool
}

private struct CreatePollControllerState: Equatable {
    var text: String = ""
    var options: [CreatePollControllerOption] = [CreatePollControllerOption(text: "", id: 0, isSelected: false), CreatePollControllerOption(text: "", id: 1, isSelected: false)]
    var nextOptionId: Int = 2
    var focusOptionId: Int?
    var optionIdWithRevealControls: Int?
    var isAnonymous: Bool = true
    var isMultipleChoice: Bool = false
    var isQuiz: Bool = false
}

private func createPollControllerEntries(presentationData: PresentationData, state: CreatePollControllerState, limitsConfiguration: LimitsConfiguration) -> [CreatePollEntry] {
    var entries: [CreatePollEntry] = []
    
    var textLimitText = ItemListSectionHeaderAccessoryText(value: "", color: .generic)
    if state.text.count >= Int(maxTextLength) * 70 / 100 {
        let remainingCount = Int(maxTextLength) - state.text.count
        textLimitText = ItemListSectionHeaderAccessoryText(value: "\(remainingCount)", color: remainingCount < 0 ? .destructive : .generic)
    }
    entries.append(.textHeader(presentationData.strings.CreatePoll_TextHeader, textLimitText))
    entries.append(.text(presentationData.strings.CreatePoll_TextPlaceholder, state.text, Int(limitsConfiguration.maxMediaCaptionLength)))
    entries.append(.optionsHeader(presentationData.strings.CreatePoll_OptionsHeader))
    for i in 0 ..< state.options.count {
        entries.append(.option(id: state.options[i].id, index: i, placeholder: presentationData.strings.CreatePoll_OptionPlaceholder, text: state.options[i].text, revealed: state.optionIdWithRevealControls == state.options[i].id, hasNext: i != 9, isLast: i == state.options.count - 1, isSelected: state.isQuiz ? state.options[i].isSelected : nil))
    }
    if state.options.count < 10 {
        entries.append(.optionsInfo(presentationData.strings.CreatePoll_AddMoreOptions(Int32(10 - state.options.count))))
    } else {
        entries.append(.optionsInfo(presentationData.strings.CreatePoll_AllOptionsAdded))
    }
    
    entries.append(.anonymousVotes(presentationData.strings.CreatePoll_Anonymous, state.isAnonymous))
    entries.append(.multipleChoice(presentationData.strings.CreatePoll_MultipleChoice, state.isMultipleChoice && !state.isQuiz, !state.isQuiz))
    entries.append(.quiz(presentationData.strings.CreatePoll_Quiz, state.isQuiz))
    entries.append(.quizInfo(presentationData.strings.CreatePoll_QuizInfo))
    
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
    var displayQuizTooltipImpl: (() -> Void)?
    
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
                    if !value.isEmpty && i == state.options.count - 1 {
                        state.options.append(CreatePollControllerOption(text: "", id: state.nextOptionId, isSelected: false))
                        state.nextOptionId += 1
                    }
                    break
                }
            }
            if state.options.count > 2 {
                for i in (1 ..< state.options.count - 1).reversed() {
                    if state.options[i - 1].text.isEmpty && state.options[i].text.isEmpty {
                        state.options.remove(at: i)
                    }
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
                        state.options.append(CreatePollControllerOption(text: "", id: state.nextOptionId, isSelected: false))
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
    }, moveToPreviousOption: { id in
        var resetFocusOptionId: Int?
        updateState { state in
            var state = state
            for i in 0 ..< state.options.count {
                if state.options[i].id == id {
                    if i != 0 {
                        if state.focusOptionId == state.options[i - 1].id {
                            resetFocusOptionId = state.options[i - 1].id
                            state.focusOptionId = -1
                        } else {
                            state.focusOptionId = state.options[i - 1].id
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
            let focusOnFirst = state.options.isEmpty
            if state.options.count < 2 {
                for i in 0 ..< (2 - state.options.count) {
                    if i == 0 && focusOnFirst {
                        state.options.append(CreatePollControllerOption(text: "", id: state.nextOptionId, isSelected: false))
                        state.focusOptionId = state.nextOptionId
                        state.nextOptionId += 1
                    } else {
                        state.options.append(CreatePollControllerOption(text: "", id: state.nextOptionId, isSelected: false))
                        state.nextOptionId += 1
                    }
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
    }, toggleOptionSelected: { id in
        updateState { state in
            var state = state
            for i in 0 ..< state.options.count {
                if state.options[i].id == id {
                    state.options[i].isSelected = !state.options[i].isSelected
                    if state.options[i].isSelected && state.isQuiz {
                        for j in 0 ..< state.options.count {
                            if i != j {
                                state.options[j].isSelected = false
                            }
                        }
                    }
                    break
                }
            }
            return state
        }
    }, updateAnonymous: { value in
        updateState { state in
            var state = state
            state.isAnonymous = value
            return state
        }
    }, updateMultipleChoice: { value in
        updateState { state in
            var state = state
            state.isMultipleChoice = value
            return state
        }
    }, updateQuiz: { value in
        updateState { state in
            var state = state
            state.isQuiz = value
            if value {
                state.isMultipleChoice = false
                var foundSelectedOption = false
                for i in 0 ..< state.options.count {
                    if state.options[i].isSelected {
                        if !foundSelectedOption {
                            foundSelectedOption = true
                        } else {
                            state.options[i].isSelected = false
                        }
                    }
                }
            }
            return state
        }
        if value {
            displayQuizTooltipImpl?()
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
        var hasSelectedOptions = false
        for option in state.options {
            if !option.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                nonEmptyOptionCount += 1
            }
            if option.text.count > maxOptionLength {
                enabled = false
            }
            if option.isSelected {
                hasSelectedOptions = true
            }
            if state.isQuiz {
                if option.text.isEmpty && option.isSelected {
                    enabled = false
                }
            }
        }
        if state.isQuiz {
            if !hasSelectedOptions {
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
            var correctAnswers: [Data]?
            for i in 0 ..< state.options.count {
                let optionText = state.options[i].text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !optionText.isEmpty {
                    let optionData = "\(i)".data(using: .utf8)!
                    options.append(TelegramMediaPollOption(text: optionText, opaqueIdentifier: optionData))
                    if state.isQuiz && state.options[i].isSelected {
                        correctAnswers = [optionData]
                    }
                }
            }
            let publicity: TelegramMediaPollPublicity
            if state.isAnonymous {
                publicity = .anonymous
            } else {
                publicity = .public
            }
            let kind: TelegramMediaPollKind
            if state.isQuiz {
                kind = .quiz
            } else {
                kind = .poll(multipleAnswers: state.isMultipleChoice)
            }
            completion(.message(text: "", attributes: [], mediaReference: .standalone(media: TelegramMediaPoll(pollId: MediaId(namespace: Namespaces.Media.LocalPoll, id: arc4random64()), publicity: publicity, kind: kind, text: processPollText(state.text), options: options, correctAnswers: correctAnswers, results: TelegramMediaPollResults(voters: nil, totalVoters: nil, recentVoters: []), isClosed: false)), replyToMessageId: nil, localGroupingKey: nil))
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
                ensureVisibleItemTag = nil
            } else {
                ensureVisibleItemTag = focusItemTag
            }
        } else {
            focusItemTag = CreatePollEntryTag.text
            ensureVisibleItemTag = focusItemTag
        }
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.CreatePoll_Title), leftNavigationButton: leftNavigationButton, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: createPollControllerEntries(presentationData: presentationData, state: state, limitsConfiguration: limitsConfiguration), style: .blocks, focusItemTag: focusItemTag, ensureVisibleItemTag: ensureVisibleItemTag, animateChanges: previousIds != nil)
        
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
    displayQuizTooltipImpl = { [weak controller] in
        guard let controller = controller else {
            return
        }
        var resultItemNode: CreatePollOptionItemNode?
        let _ = controller.frameForItemNode({ itemNode in
            if resultItemNode == nil, let itemNode = itemNode as? CreatePollOptionItemNode {
                resultItemNode = itemNode
                return true
            }
            return false
        })
        if let resultItemNode = resultItemNode {
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let tooltipController = TooltipController(content: .text(presentationData.strings.CreatePoll_QuizTip), baseFontSize: presentationData.listsFontSize.baseDisplaySize, dismissByTapOutside: true)
            controller.present(tooltipController, in: .window(.root), with: TooltipControllerPresentationArguments(sourceViewAndRect: { [weak resultItemNode] in
                if let resultItemNode = resultItemNode {
                    return (resultItemNode.view, CGRect(origin: CGPoint(x: 0.0, y: 4.0), size: CGSize(width: 54.0, height: resultItemNode.bounds.height - 8.0)))
                }
                return nil
            }))
        }
    }
    controller.setReorderEntry({ (fromIndex: Int, toIndex: Int, entries: [CreatePollEntry]) -> Void in
        let fromEntry = entries[fromIndex]
        guard case let .option(option) = fromEntry else {
            return
        }
        let id = option.id
        var referenceId: Int?
        var beforeAll = false
        var afterAll = false
        if toIndex < entries.count {
            switch entries[toIndex] {
                case let .option(toOption):
                    referenceId = toOption.id
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
