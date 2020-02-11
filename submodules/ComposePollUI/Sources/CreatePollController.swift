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

private struct OrderedLinkedListItemOrderingId: RawRepresentable, Hashable {
    var rawValue: Int
}

private struct OrderedLinkedListItemOrdering: Comparable {
    var id: OrderedLinkedListItemOrderingId
    var lowerItemIds: Set<OrderedLinkedListItemOrderingId>
    var higherItemIds: Set<OrderedLinkedListItemOrderingId>
    
    static func <(lhs: OrderedLinkedListItemOrdering, rhs: OrderedLinkedListItemOrdering) -> Bool {
        if rhs.lowerItemIds.contains(lhs.id) {
            return true
        }
        if rhs.higherItemIds.contains(lhs.id) {
            return false
        }
        if lhs.lowerItemIds.contains(rhs.id) {
            return false
        }
        if lhs.higherItemIds.contains(rhs.id) {
            return true
        }
        assertionFailure()
        return false
    }
}

private struct OrderedLinkedListItem<T: Equatable> {
    var item: T
    var ordering: OrderedLinkedListItemOrdering
}

private struct OrderedLinkedList<T: Equatable>: Sequence, Equatable {
    private var items: [OrderedLinkedListItem<T>] = []
    private var nextId: Int = 0
    
    init(items: [T]) {
        for i in 0 ..< items.count {
            self.insert(items[i], at: i, id: nil)
        }
    }
    
    static func ==(lhs: OrderedLinkedList<T>, rhs: OrderedLinkedList<T>) -> Bool {
        if lhs.items.count != rhs.items.count {
            return false
        }
        for i in 0 ..< lhs.items.count {
            if lhs.items[i].item != rhs.items[i].item {
                return false
            }
        }
        return true
    }
    
    func makeIterator() -> AnyIterator<OrderedLinkedListItem<T>> {
        var index = 0
        return AnyIterator { () -> OrderedLinkedListItem<T>? in
            if index < self.items.count {
                let currentIndex = index
                index += 1
                return self.items[currentIndex]
            }
            return nil
        }
    }
    
    subscript(index: Int) -> OrderedLinkedListItem<T> {
        return self.items[index]
    }
    
    mutating func update(at index: Int, _ f: (inout T) -> Void) {
        f(&self.items[index].item)
    }
    
    var count: Int {
        return self.items.count
    }
    
    var isEmpty: Bool {
        return self.items.isEmpty
    }
    
    var last: OrderedLinkedListItem<T>? {
        return self.items.last
    }
    
    mutating func append(_ item: T, id: OrderedLinkedListItemOrderingId?) {
        self.insert(item, at: self.items.count, id: id)
    }
    
    mutating func insert(_ item: T, at index: Int, id: OrderedLinkedListItemOrderingId?) {
        let previousId = id
        let id = previousId ?? OrderedLinkedListItemOrderingId(rawValue: self.nextId)
        self.nextId += 1
        
        if let previousId = previousId {
            for i in 0 ..< self.items.count {
                self.items[i].ordering.higherItemIds.remove(previousId)
                self.items[i].ordering.lowerItemIds.remove(previousId)
            }
        }
        
        var lowerItemIds = Set<OrderedLinkedListItemOrderingId>()
        var higherItemIds = Set<OrderedLinkedListItemOrderingId>()
        for i in 0 ..< self.items.count {
            if i < index {
                lowerItemIds.insert(self.items[i].ordering.id)
                self.items[i].ordering.higherItemIds.insert(id)
            } else {
                higherItemIds.insert(self.items[i].ordering.id)
                self.items[i].ordering.lowerItemIds.insert(id)
            }
        }
        
        self.items.insert(OrderedLinkedListItem(item: item, ordering: OrderedLinkedListItemOrdering(id: id, lowerItemIds: lowerItemIds, higherItemIds: higherItemIds)), at: index)
    }
    
    mutating func remove(at index: Int) {
        self.items.remove(at: index)
    }
}

private let maxTextLength = 255
private let maxOptionLength = 100
private let maxOptionCount = 10

private func processPollText(_ text: String) -> String {
    var text = text.trimmingCharacters(in: .whitespacesAndNewlines)
    while text.contains("\n\n\n") {
        text = text.replacingOccurrences(of: "\n\n\n", with: "\n\n")
    }
    return text
}

private final class CreatePollControllerArguments {
    let updatePollText: (String) -> Void
    let updateOptionText: (Int, String, Bool) -> Void
    let moveToNextOption: (Int) -> Void
    let moveToPreviousOption: (Int) -> Void
    let removeOption: (Int, Bool) -> Void
    let optionFocused: (Int, Bool) -> Void
    let setItemIdWithRevealedOptions: (Int?, Int?) -> Void
    let toggleOptionSelected: (Int) -> Void
    let updateAnonymous: (Bool) -> Void
    let updateMultipleChoice: (Bool) -> Void
    let displayMultipleChoiceDisabled: () -> Void
    let updateQuiz: (Bool) -> Void
    
    init(updatePollText: @escaping (String) -> Void, updateOptionText: @escaping (Int, String, Bool) -> Void, moveToNextOption: @escaping (Int) -> Void, moveToPreviousOption: @escaping (Int) -> Void, removeOption: @escaping (Int, Bool) -> Void, optionFocused: @escaping (Int, Bool) -> Void, setItemIdWithRevealedOptions: @escaping (Int?, Int?) -> Void, toggleOptionSelected: @escaping (Int) -> Void, updateAnonymous: @escaping (Bool) -> Void, updateMultipleChoice: @escaping (Bool) -> Void, displayMultipleChoiceDisabled: @escaping () -> Void, updateQuiz: @escaping (Bool) -> Void) {
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
        self.displayMultipleChoiceDisabled = displayMultipleChoiceDisabled
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
    case optionsInfo
    
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
    case option(id: Int, ordering: OrderedLinkedListItemOrdering, placeholder: String, text: String, revealed: Bool, hasNext: Bool, isLast: Bool, canMove: Bool, isSelected: Bool?)
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
            return 3
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
        switch lhs {
        case let .option(lhsOption):
            switch rhs {
            case let .option(rhsOption):
                return lhsOption.ordering < rhsOption.ordering
            default:
                break
            }
        default:
            break
        }
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
        case let .option(id, _, placeholder, text, revealed, hasNext, isLast, canMove, isSelected):
            return CreatePollOptionItem(presentationData: presentationData, id: id, placeholder: placeholder, value: text, isSelected: isSelected, maxLength: maxOptionLength, editing: CreatePollOptionItemEditing(editable: true, hasActiveRevealControls: revealed), sectionId: self.section, setItemIdWithRevealedOptions: { id, fromId in
                arguments.setItemIdWithRevealedOptions(id, fromId)
            }, updated: { value, isFocused in
                arguments.updateOptionText(id, value, isFocused)
            }, next: hasNext ? {
                arguments.moveToNextOption(id)
            } : nil, delete: { focused in
                if !isLast {
                    arguments.removeOption(id, focused)
                } else {
                    arguments.moveToPreviousOption(id)
                }
            }, canDelete: !isLast,
            canMove: canMove,
            focused: { isFocused in
                arguments.optionFocused(id, isFocused)
            }, toggleSelected: {
                arguments.toggleOptionSelected(id)
            }, tag: CreatePollEntryTag.option(id))
        case let .optionsInfo(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section, tag: CreatePollEntryTag.optionsInfo)
        case let .anonymousVotes(text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateAnonymous(value)
            })
        case let .multipleChoice(text, value, enabled):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, enabled: enabled, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateMultipleChoice(value)
            }, activatedWhileDisabled: {
                arguments.displayMultipleChoiceDisabled()
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
    var options = OrderedLinkedList<CreatePollControllerOption>(items: [CreatePollControllerOption(text: "", id: 0, isSelected: false), CreatePollControllerOption(text: "", id: 1, isSelected: false)])
    var nextOptionId: Int = 2
    var focusOptionId: Int?
    var optionIdWithRevealControls: Int?
    var isAnonymous: Bool = true
    var isMultipleChoice: Bool = false
    var isQuiz: Bool = false
}

private func createPollControllerEntries(presentationData: PresentationData, peer: Peer, state: CreatePollControllerState, limitsConfiguration: LimitsConfiguration, defaultIsQuiz: Bool?) -> [CreatePollEntry] {
    var entries: [CreatePollEntry] = []
    
    var textLimitText = ItemListSectionHeaderAccessoryText(value: "", color: .generic)
    if state.text.count >= Int(maxTextLength) * 70 / 100 {
        let remainingCount = Int(maxTextLength) - state.text.count
        textLimitText = ItemListSectionHeaderAccessoryText(value: "\(remainingCount)", color: remainingCount < 0 ? .destructive : .generic)
    }
    entries.append(.textHeader(presentationData.strings.CreatePoll_TextHeader, textLimitText))
    entries.append(.text(presentationData.strings.CreatePoll_TextPlaceholder, state.text, Int(limitsConfiguration.maxMediaCaptionLength)))
    let optionsHeaderTitle: String
    if let defaultIsQuiz = defaultIsQuiz, defaultIsQuiz {
        optionsHeaderTitle = presentationData.strings.CreatePoll_QuizOptionsHeader
    } else {
        optionsHeaderTitle = presentationData.strings.CreatePoll_OptionsHeader
    }
    entries.append(.optionsHeader(optionsHeaderTitle))
    for i in 0 ..< state.options.count {
        let isSecondLast = state.options.count == 2 && i == 0
        let isLast = i == state.options.count - 1
        let option = state.options[i].item
        entries.append(.option(id: option.id, ordering: state.options[i].ordering, placeholder: isLast ? presentationData.strings.CreatePoll_AddOption : presentationData.strings.CreatePoll_OptionPlaceholder, text: option.text, revealed: state.optionIdWithRevealControls == option.id, hasNext: i != 9, isLast: isLast || isSecondLast, canMove: !isLast || state.options.count == 10, isSelected: state.isQuiz ? option.isSelected : nil))
    }
    if state.options.count < maxOptionCount {
        entries.append(.optionsInfo(presentationData.strings.CreatePoll_AddMoreOptions(Int32(maxOptionCount - state.options.count))))
    } else {
        entries.append(.optionsInfo(presentationData.strings.CreatePoll_AllOptionsAdded))
    }
    
    var canBePublic = true
    if let channel = peer as? TelegramChannel, case .broadcast = channel.info {
        canBePublic = false
    }
    
    if canBePublic {
        entries.append(.anonymousVotes(presentationData.strings.CreatePoll_Anonymous, state.isAnonymous))
    }
    if let defaultIsQuiz = defaultIsQuiz {
        if !defaultIsQuiz {
            entries.append(.multipleChoice(presentationData.strings.CreatePoll_MultipleChoice, state.isMultipleChoice && !state.isQuiz, !state.isQuiz))
        }
    } else {
        entries.append(.multipleChoice(presentationData.strings.CreatePoll_MultipleChoice, state.isMultipleChoice && !state.isQuiz, !state.isQuiz))
        entries.append(.quiz(presentationData.strings.CreatePoll_Quiz, state.isQuiz))
        entries.append(.quizInfo(presentationData.strings.CreatePoll_QuizInfo))
    }
    
    return entries
}

public func createPollController(context: AccountContext, peer: Peer, isQuiz: Bool? = nil, completion: @escaping (EnqueueMessage) -> Void) -> ViewController {
    var initialState = CreatePollControllerState()
    if let isQuiz = isQuiz {
        initialState.isQuiz = isQuiz
    }
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((CreatePollControllerState) -> CreatePollControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var presentControllerImpl: ((ViewController, Any?) -> Void)?
    var dismissImpl: (() -> Void)?
    var ensureTextVisibleImpl: (() -> Void)?
    var ensureOptionVisibleImpl: ((Int) -> Void)?
    var displayQuizTooltipImpl: ((Bool) -> Void)?
    var attemptNavigationImpl: (() -> Bool)?
    
    let actionsDisposable = DisposableSet()
    
    let checkAddressNameDisposable = MetaDisposable()
    actionsDisposable.add(checkAddressNameDisposable)
    
    let updateAddressNameDisposable = MetaDisposable()
    actionsDisposable.add(updateAddressNameDisposable)
    
    let arguments = CreatePollControllerArguments(updatePollText: { value in
        updateState { state in
            var state = state
            state.focusOptionId = nil
            state.text = value
            return state
        }
        ensureTextVisibleImpl?()
    }, updateOptionText: { id, value, isFocused in
        var ensureVisibleId = id
        updateState { state in
            var state = state
            for i in 0 ..< state.options.count {
                if state.options[i].item.id == id {
                    if isFocused {
                        state.focusOptionId = id
                    }
                    state.options.update(at: i, { option in
                        option.text = value
                    })
                    if !value.isEmpty && i == state.options.count - 1 && state.options.count < maxOptionCount {
                        state.options.append(CreatePollControllerOption(text: "", id: state.nextOptionId, isSelected: false), id: nil)
                        state.nextOptionId += 1
                    }
                    if i != state.options.count - 1 {
                        ensureVisibleId = state.options[i + 1].item.id
                    }
                    break
                }
            }
            return state
        }
        if isFocused {
            ensureOptionVisibleImpl?(ensureVisibleId)
        }
    }, moveToNextOption: { id in
        var resetFocusOptionId: Int?
        updateState { state in
            var state = state
            for i in 0 ..< state.options.count {
                if state.options[i].item.id == id {
                    if i == state.options.count - 1 {
                        /*state.options.append(CreatePollControllerOption(text: "", id: state.nextOptionId, isSelected: false))
                        state.focusOptionId = state.nextOptionId
                        state.nextOptionId += 1*/
                    } else {
                        if state.focusOptionId == state.options[i + 1].item.id {
                            resetFocusOptionId = state.options[i + 1].item.id
                            state.focusOptionId = -1
                        } else {
                            state.focusOptionId = state.options[i + 1].item.id
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
                if state.options[i].item.id == id {
                    if i != 0 {
                        if state.focusOptionId == state.options[i - 1].item.id {
                            resetFocusOptionId = state.options[i - 1].item.id
                            state.focusOptionId = -1
                        } else {
                            state.focusOptionId = state.options[i - 1].item.id
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
                if state.options[i].item.id == id {
                    state.options.remove(at: i)
                    if focused && i != 0 {
                        state.focusOptionId = state.options[i - 1].item.id
                    }
                    break
                }
            }
            let focusOnFirst = state.options.isEmpty
            if state.options.count < 2 {
                for i in 0 ..< (2 - state.options.count) {
                    if i == 0 && focusOnFirst {
                        state.options.append(CreatePollControllerOption(text: "", id: state.nextOptionId, isSelected: false), id: nil)
                        state.focusOptionId = state.nextOptionId
                        state.nextOptionId += 1
                    } else {
                        state.options.append(CreatePollControllerOption(text: "", id: state.nextOptionId, isSelected: false), id: nil)
                        state.nextOptionId += 1
                    }
                }
            }
            return state
        }
    }, optionFocused: { id, isFocused in
        if isFocused {
            ensureOptionVisibleImpl?(id)
        } else {
            updateState { state in
                var state = state
                if state.options.count > 2 {
                    for i in 0 ..< state.options.count {
                        if state.options[i].item.id == id {
                            if state.options[i].item.text.isEmpty && i != state.options.count - 1 {
                                state.options.remove(at: i)
                            }
                            break
                        }
                    }
                }
                return state
            }
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
    }, toggleOptionSelected: { id in
        updateState { state in
            var state = state
            for i in 0 ..< state.options.count {
                if state.options[i].item.id == id {
                    state.options.update(at: i, { option in
                        option.isSelected = !option.isSelected
                    })
                    if state.options[i].item.isSelected && state.isQuiz {
                        for j in 0 ..< state.options.count {
                            if i != j {
                                state.options.update(at: j, { option in
                                    option.isSelected = false
                                })
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
            state.focusOptionId = -1
            state.isAnonymous = value
            return state
        }
    }, updateMultipleChoice: { value in
        updateState { state in
            var state = state
            state.focusOptionId = -1
            state.isMultipleChoice = value
            return state
        }
    }, displayMultipleChoiceDisabled: {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        presentControllerImpl?(textAlertController(context: context, title: nil, text: presentationData.strings.CreatePoll_MultipleChoiceQuizAlert, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_OK, action: {})]), nil)
    }, updateQuiz: { value in
        if !value {
            displayQuizTooltipImpl?(value)
        }
        updateState { state in
            var state = state
            state.focusOptionId = -1
            state.isQuiz = value
            if value {
                state.isMultipleChoice = false
                var foundSelectedOption = false
                for i in 0 ..< state.options.count {
                    if state.options[i].item.isSelected {
                        if !foundSelectedOption {
                            foundSelectedOption = true
                        } else {
                            state.options.update(at: i, { option in
                                option.isSelected = false
                            })
                        }
                    }
                }
            }
            return state
        }
        if value {
            displayQuizTooltipImpl?(value)
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
            if !option.item.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                nonEmptyOptionCount += 1
            }
            if option.item.text.count > maxOptionLength {
                enabled = false
            }
            if option.item.isSelected {
                hasSelectedOptions = true
            }
            if state.isQuiz {
                if option.item.text.isEmpty && option.item.isSelected {
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
                let optionText = state.options[i].item.text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !optionText.isEmpty {
                    let optionData = "\(i)".data(using: .utf8)!
                    options.append(TelegramMediaPollOption(text: optionText, opaqueIdentifier: optionData))
                    if state.isQuiz && state.options[i].item.isSelected {
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
            dismissImpl?()
            completion(.message(text: "", attributes: [], mediaReference: .standalone(media: TelegramMediaPoll(pollId: MediaId(namespace: Namespaces.Media.LocalPoll, id: arc4random64()), publicity: publicity, kind: kind, text: processPollText(state.text), options: options, correctAnswers: correctAnswers, results: TelegramMediaPollResults(voters: nil, totalVoters: nil, recentVoters: []), isClosed: false)), replyToMessageId: nil, localGroupingKey: nil))
        })
        
        let leftNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Cancel), style: .regular, enabled: true, action: {
            if let attemptNavigationImpl = attemptNavigationImpl, attemptNavigationImpl() {
                dismissImpl?()
            }
        })
        
        let optionIds = state.options.map { $0.item.id }
        let previousIds = previousOptionIds.swap(optionIds)
        
        var focusItemTag: ItemListItemTag?
        var ensureVisibleItemTag: ItemListItemTag?
        if let focusOptionId = state.focusOptionId {
            focusItemTag = CreatePollEntryTag.option(focusOptionId)
            if focusOptionId == state.options.last?.item.id {
                ensureVisibleItemTag = nil
            } else {
                ensureVisibleItemTag = focusItemTag
            }
        } else {
            focusItemTag = CreatePollEntryTag.text
            ensureVisibleItemTag = focusItemTag
        }
        
        let title: String
        if let isQuiz = isQuiz, isQuiz {
            title = presentationData.strings.CreatePoll_QuizTitle
        } else {
            title = presentationData.strings.CreatePoll_Title
        }
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(title), leftNavigationButton: leftNavigationButton, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: createPollControllerEntries(presentationData: presentationData, peer: peer, state: state, limitsConfiguration: limitsConfiguration, defaultIsQuiz: isQuiz), style: .blocks, focusItemTag: focusItemTag, ensureVisibleItemTag: ensureVisibleItemTag, animateChanges: previousIds != nil)
        
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
        actionsDisposable.dispose()
    }
    
    weak var currentTooltipController: TooltipController?
    let controller = ItemListController(context: context, state: signal)
    controller.navigationPresentation = .modal
    presentControllerImpl = { [weak controller] c, a in
        controller?.present(c, in: .window(.root), with: a)
    }
    dismissImpl = { [weak controller] in
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
            var isLast = false
            if state.options.last?.item.id == id {
                isLast = true
            }
            if resultItemNode == nil {
                let _ = controller.frameForItemNode({ itemNode in
                    if let itemNode = itemNode as? ItemListItemNode, let tag = itemNode.tag {
                        if isLast {
                            if tag.isEqual(to: CreatePollEntryTag.optionsInfo) {
                                resultItemNode = itemNode as? ListViewItemNode
                                return true
                            }
                        } else {
                            if tag.isEqual(to: CreatePollEntryTag.option(id)) {
                                resultItemNode = itemNode as? ListViewItemNode
                                return true
                            }
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
    displayQuizTooltipImpl = { [weak controller] display in
        guard let controller = controller else {
            return
        }
        var resultItemNode: CreatePollOptionItemNode?
        let insets = controller.listInsets
        let _ = controller.frameForItemNode({ itemNode in
            if resultItemNode == nil, let itemNode = itemNode as? CreatePollOptionItemNode {
                if itemNode.frame.minY >= insets.top {
                    resultItemNode = itemNode
                    return true
                }
            }
            return false
        })
        if let resultItemNode = resultItemNode, let localCheckNodeFrame = resultItemNode.checkNodeFrame {
            let checkNodeFrame = resultItemNode.view.convert(localCheckNodeFrame, to: controller.view)
            if display {
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                let tooltipController = TooltipController(content: .text(presentationData.strings.CreatePoll_QuizTip), baseFontSize: presentationData.listsFontSize.baseDisplaySize, dismissByTapOutside: true)
                controller.present(tooltipController, in: .window(.root), with: TooltipControllerPresentationArguments(sourceViewAndRect: { [weak controller] in
                    if let controller = controller {
                        return (controller.view, checkNodeFrame.insetBy(dx: 0.0, dy: 0.0))
                    }
                    return nil
                }))
                tooltipController.displayNode.layer.animatePosition(from: CGPoint(x: -checkNodeFrame.maxX, y: 0.0), to: CGPoint(), duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
                currentTooltipController = tooltipController
            } else if let tooltipController = currentTooltipController{
                currentTooltipController = nil
                tooltipController.displayNode.layer.animatePosition(from: CGPoint(), to: CGPoint(x: -checkNodeFrame.maxX, y: 0.0), duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, additive: true)
            }
        }
    }
    controller.setReorderEntry({ (fromIndex: Int, toIndex: Int, entries: [CreatePollEntry]) -> Signal<Bool, NoError> in
        let fromEntry = entries[fromIndex]
        guard case let .option(option) = fromEntry else {
            return .single(false)
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
        
        var didReorder = false
        
        updateState { state in
            var state = state
            var options = state.options
            var reorderOption: OrderedLinkedListItem<CreatePollControllerOption>?
            var previousIndex: Int?
            for i in 0 ..< options.count {
                if options[i].item.id == id {
                    reorderOption = options[i]
                    previousIndex = i
                    options.remove(at: i)
                    break
                }
            }
            if let reorderOption = reorderOption {
                if let referenceId = referenceId {
                    var inserted = false
                    for i in 0 ..< options.count - 1 {
                        if options[i].item.id == referenceId {
                            if fromIndex < toIndex {
                                didReorder = previousIndex != i + 1
                                options.insert(reorderOption.item, at: i + 1, id: reorderOption.ordering.id)
                            } else {
                                didReorder = previousIndex != i
                                options.insert(reorderOption.item, at: i, id: reorderOption.ordering.id)
                            }
                            inserted = true
                            break
                        }
                    }
                    if !inserted {
                        if options.count >= 2 {
                            didReorder = previousIndex != options.count - 1
                            options.insert(reorderOption.item, at: options.count - 1, id: reorderOption.ordering.id)
                        } else {
                            didReorder = previousIndex != options.count
                            options.append(reorderOption.item, id: reorderOption.ordering.id)
                        }
                    }
                } else if beforeAll {
                    didReorder = previousIndex != 0
                    options.insert(reorderOption.item, at: 0, id: reorderOption.ordering.id)
                } else if afterAll {
                    if options.count >= 2 {
                        didReorder = previousIndex != options.count - 1
                        options.insert(reorderOption.item, at: options.count - 1, id: reorderOption.ordering.id)
                    } else {
                        didReorder = previousIndex != options.count
                        options.append(reorderOption.item, id: reorderOption.ordering.id)
                    }
                }
                state.options = options
            }
            return state
        }
        
        return .single(didReorder)
    })
    attemptNavigationImpl = {
        let state = stateValue.with { $0 }
        var hasNonEmptyOptions = false
        for i in 0 ..< state.options.count {
            let optionText = state.options[i].item.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !optionText.isEmpty {
                hasNonEmptyOptions = true
            }
        }
        if hasNonEmptyOptions || !state.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            presentControllerImpl?(textAlertController(context: context, title: nil, text: presentationData.strings.CreatePoll_CancelConfirmation, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_No, action: {}), TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_Yes, action: {
                dismissImpl?()
            })]), nil)
            return false
        } else {
            return true
        }
    }
    controller.attemptNavigation = { _ in
        if let attemptNavigationImpl = attemptNavigationImpl, attemptNavigationImpl() {
            return true
        }
        return false
    }
    controller.isOpaqueWhenInOverlay = true
    controller.blocksBackgroundWhenInOverlay = true
    controller.experimentalSnapScrollToItem = true
    controller.alwaysSynchronous = true
    
    return controller
}
