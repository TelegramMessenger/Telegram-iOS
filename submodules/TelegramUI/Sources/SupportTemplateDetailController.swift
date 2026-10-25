import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import AccountContext

/// Shared Template Detail view (D30). One controller, three uses:
/// - `.official`: read-only, plus a "Clone as User Template" action (D32 - officials are
///   immutable; cloning is the only customization path).
/// - `.user`, viewing: read-only, plus Edit/Delete (D30). Edit pushes a second instance of
///   this same controller with `startInEditMode: true` rather than toggling state in place -
///   simpler to get right, and Cancel/Save both just pop back to the previous screen.
/// - `.user` or `.newUserTemplate`, editing: Question/Keys/Value input rows, Save disabled
///   until valid.
///
/// Rows use the dedicated types in SupportTemplateDetailItems.swift, not the generic
/// `ItemListTextItem` - that one always renders in `theme.list.freeTextColor` (this
/// framework's muted footer/description style), which read as too small/basic for what
/// should be the screen's main readable content.
enum SupportTemplateDetailSource {
    case official(SupportTemplate)
    case user(SupportUserTemplate)
    /// Blank when opened from Settings' Add button; pre-filled (but still unsaved - nothing
    /// persists until Save is tapped) when opened from an official template's Clone button.
    case newUserTemplate(prefill: SupportTemplate?)
}

private enum SupportTemplateDetailSection: Int32 {
    case title
    case content
    case actions
}

private enum SupportTemplateDetailEntry: ItemListNodeEntry {
    case title(String)
    case keys(keys: [String], highlighted: Set<String>, note: String?)
    case value(String)
    case questionInput(String)
    case keysEditor([String])
    case keysAddInput(String)
    case keysInputFooter(String)
    case valueInput(String)
    case valueInputFooter(String)
    case clone(String)
    case delete(String)
    
    var section: ItemListSectionId {
        switch self {
        case .title:
            return SupportTemplateDetailSection.title.rawValue
        case .keys, .value, .questionInput, .keysEditor, .keysAddInput, .keysInputFooter, .valueInput, .valueInputFooter:
            return SupportTemplateDetailSection.content.rawValue
        case .clone, .delete:
            return SupportTemplateDetailSection.actions.rawValue
        }
    }
    
    var stableId: Int {
        switch self {
        case .title:
            return 0
        case .keys:
            return 1
        case .value:
            return 2
        case .questionInput:
            return 3
        case .keysEditor:
            return 4
        case .keysAddInput:
            return 5
        case .keysInputFooter:
            return 6
        case .valueInput:
            return 7
        case .valueInputFooter:
            return 8
        case .clone:
            return 9
        case .delete:
            return 10
        }
    }
    
    static func ==(lhs: SupportTemplateDetailEntry, rhs: SupportTemplateDetailEntry) -> Bool {
        switch lhs {
        case let .title(lhsText):
            if case let .title(rhsText) = rhs { return lhsText == rhsText }
            return false
        case let .keys(lhsKeys, lhsHighlighted, lhsNote):
            if case let .keys(rhsKeys, rhsHighlighted, rhsNote) = rhs {
                return lhsKeys == rhsKeys && lhsHighlighted == rhsHighlighted && lhsNote == rhsNote
            }
            return false
        case let .value(lhsText):
            if case let .value(rhsText) = rhs { return lhsText == rhsText }
            return false
        case let .questionInput(lhsText):
            if case let .questionInput(rhsText) = rhs { return lhsText == rhsText }
            return false
        case let .keysEditor(lhsKeys):
            if case let .keysEditor(rhsKeys) = rhs { return lhsKeys == rhsKeys }
            return false
        case let .keysAddInput(lhsText):
            if case let .keysAddInput(rhsText) = rhs { return lhsText == rhsText }
            return false
        case let .keysInputFooter(lhsText):
            if case let .keysInputFooter(rhsText) = rhs { return lhsText == rhsText }
            return false
        case let .valueInput(lhsText):
            if case let .valueInput(rhsText) = rhs { return lhsText == rhsText }
            return false
        case let .valueInputFooter(lhsText):
            if case let .valueInputFooter(rhsText) = rhs { return lhsText == rhsText }
            return false
        case let .clone(lhsText):
            if case let .clone(rhsText) = rhs { return lhsText == rhsText }
            return false
        case let .delete(lhsText):
            if case let .delete(rhsText) = rhs { return lhsText == rhsText }
            return false
        }
    }
    
    static func <(lhs: SupportTemplateDetailEntry, rhs: SupportTemplateDetailEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! SupportTemplateDetailControllerArguments
        switch self {
        case let .title(text):
            return SupportTemplateDetailTitleItem(presentationData: presentationData, title: text, sectionId: self.section)
        case let .keys(keys, highlighted, note):
            return SupportTemplateDetailKeysItem(presentationData: presentationData, label: presentationData.strings.SupportTemplates_DetailKeysLabel, keys: keys, highlightedKeys: highlighted, note: note, sectionId: self.section, collisionTapped: {
                arguments.showCollisions()
            })
        case let .value(text):
            return SupportTemplateDetailValueItem(presentationData: presentationData, label: presentationData.strings.SupportTemplates_DetailValueLabel, text: text, sectionId: self.section)
        case let .questionInput(text):
            return ItemListMultilineInputItem(presentationData: presentationData, text: text, placeholder: presentationData.strings.SupportTemplates_QuestionPlaceholder, maxLength: nil, sectionId: self.section, style: .blocks, capitalization: true, autocorrection: true, minimalHeight: nil, textUpdated: { value in
                arguments.updateState { state in
                    var state = state
                    state.question = value
                    return state
                }
            })
        case let .keysEditor(keys):
            return SupportTemplateDetailKeysItem(presentationData: presentationData, label: presentationData.strings.SupportTemplates_DetailKeysLabel, keys: keys, sectionId: self.section, editable: true, removeKey: { key in
                arguments.updateState { state in
                    var state = state
                    state.keys.removeAll { $0 == key }
                    return state
                }
            })
        case let .keysAddInput(text):
            return ItemListSingleLineInputItem(presentationData: presentationData, title: NSAttributedString(string: "", textColor: .black), text: text, placeholder: presentationData.strings.SupportTemplates_KeysAddPlaceholder, type: .regular(capitalization: false, autocorrection: false), returnKeyType: .done, clearType: .always, sectionId: self.section, textUpdated: { value in
                arguments.updateState { state in
                    var state = state
                    state.pendingNewKeyText = value
                    return state
                }
            }, action: {
                arguments.updateState { state in
                    var state = state
                    let trimmed = state.pendingNewKeyText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty && !state.keys.contains(trimmed) {
                        state.keys.append(trimmed)
                    }
                    state.pendingNewKeyText = ""
                    return state
                }
            })
        case let .keysInputFooter(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .valueInput(text):
            return ItemListMultilineInputItem(presentationData: presentationData, text: text, placeholder: presentationData.strings.SupportTemplates_ValuePlaceholder, maxLength: nil, sectionId: self.section, style: .blocks, capitalization: true, autocorrection: true, minimalHeight: 120.0, textUpdated: { value in
                arguments.updateState { state in
                    var state = state
                    state.valueText = value
                    return state
                }
            })
        case let .valueInputFooter(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .clone(text):
            return ItemListActionItem(presentationData: presentationData, title: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.clone()
            })
        case let .delete(text):
            return ItemListActionItem(presentationData: presentationData, title: text, kind: .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.delete()
            })
        }
    }
}

private final class SupportTemplateDetailControllerArguments {
    let updateState: ((SupportTemplateDetailState) -> SupportTemplateDetailState) -> Void
    let showCollisions: () -> Void
    let clone: () -> Void
    let delete: () -> Void
    
    init(updateState: @escaping ((SupportTemplateDetailState) -> SupportTemplateDetailState) -> Void, showCollisions: @escaping () -> Void, clone: @escaping () -> Void, delete: @escaping () -> Void) {
        self.updateState = updateState
        self.showCollisions = showCollisions
        self.clone = clone
        self.delete = delete
    }
}

private struct SupportTemplateDetailState: Equatable {
    var question: String
    var keys: [String]
    /// Live text in the "Add key" row (Round B polish - replaces the old newline-separated
    /// free-text field with pill chips + a dedicated single-line add field, item 2).
    var pendingNewKeyText: String
    var valueText: String
    
    var isValid: Bool {
        return !self.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !self.keys.isEmpty
            && !self.valueText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /// Reuses the real file parser on a synthetic single-template document so a typed
    /// `contact:+<phone> <Name>` first line is recognized identically to one coming from an
    /// actual `tl_*.txt` file or an import - one parsing rule, not two.
    var asTemplate: SupportTemplate {
        let synthetic = "{QUESTION}\nq\n{KEYS}\nk\n{VALUE}\n\(self.valueText)"
        let value = parseSupportTemplateFile(synthetic).templates.first?.value ?? .text(self.valueText)
        return SupportTemplate(question: self.question, keys: self.keys, value: value)
    }
}

func supportTemplateValueDisplayText(_ value: SupportTemplateValue) -> String {
    switch value {
    case let .text(text):
        return text
    case let .contact(phone, name, precedingText):
        var text = "👤 \(name)\n\(phone)"
        if !precedingText.isEmpty {
            text = precedingText + "\n\n" + text
        }
        return text
    }
}

func supportTemplateDetailController(context: AccountContext, source: SupportTemplateDetailSource, startInEditMode: Bool = false) -> ViewController {
    var dismissImpl: (() -> Void)?
    var presentImpl: ((ViewController) -> Void)?
    var pushImpl: ((ViewController) -> Void)?
    var showCollisionsImpl: (() -> Void)?
    
    let isEditing: Bool
    switch source {
    case .official, .user:
        isEditing = startInEditMode
    case .newUserTemplate:
        isEditing = true
    }
    
    let initialTemplate: SupportTemplate?
    switch source {
    case let .official(template):
        initialTemplate = template
    case let .user(userTemplate):
        initialTemplate = userTemplate.template
    case let .newUserTemplate(prefill):
        initialTemplate = prefill
    }
    
    let initialState = SupportTemplateDetailState(
        question: initialTemplate?.question ?? "",
        keys: initialTemplate?.keys ?? [],
        pendingNewKeyText: "",
        valueText: initialTemplate.map { supportTemplateValueDisplayText($0.value) } ?? ""
    )
    let stateValue = Atomic(value: initialState)
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let updateState: ((SupportTemplateDetailState) -> SupportTemplateDetailState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    let arguments = SupportTemplateDetailControllerArguments(updateState: { f in
        updateState(f)
    }, showCollisions: {
        showCollisionsImpl?()
    }, clone: {
        // Clone opens straight into a blank Save/Cancel editor pre-filled with the official
        // content (owner feedback: previously this saved immediately, so even hitting
        // Cancel afterwards had already created a copy - nothing should persist until Save).
        guard case let .official(template) = source else { return }
        pushImpl?(supportTemplateDetailController(context: context, source: .newUserTemplate(prefill: template)))
    }, delete: {
        guard case let .user(userTemplate) = source else { return }
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let alertController = textAlertController(context: context, title: nil, text: presentationData.strings.SupportTemplates_DeleteConfirmation, actions: [
            TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {}),
            TextAlertAction(type: .destructiveAction, title: presentationData.strings.Common_Delete, action: {
                let _ = (deleteSupportUserTemplate(context: context, id: userTemplate.id)
                |> deliverOnMainQueue).startStandalone(completed: {
                    dismissImpl?()
                })
            })
        ])
        presentImpl?(alertController)
    })
    
    let officialTemplatesSignal: Signal<[SupportTemplate], NoError>
    if context.isSupportUser {
        officialTemplatesSignal = supportTemplateLanguageSetting(context: context)
        |> mapToSignal { language -> Signal<[SupportTemplate], NoError> in
            return supportTemplates(context: context, language: language)
        }
    } else {
        officialTemplatesSignal = .single([])
    }
    
    let signal = combineLatest(
        context.sharedContext.presentationData,
        statePromise.get(),
        supportUserTemplates(context: context),
        officialTemplatesSignal
    )
    |> deliverOnMainQueue
    |> map { presentationData, state, allUserTemplates, allOfficialTemplates -> (ItemListControllerState, (ItemListNodeState, Any)) in
        var entries: [SupportTemplateDetailEntry] = []
        
        let title: String
        var rightNavigationButton: ItemListNavigationButton?
        var leftNavigationButton: ItemListNavigationButton?
        
        if isEditing {
            title = presentationData.strings.SupportTemplates_Title
            leftNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Cancel), style: .regular, enabled: true, action: {
                dismissImpl?()
            })
            rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Save), style: .bold, enabled: state.isValid, action: {
                guard state.isValid else { return }
                let template = state.asTemplate
                let userTemplate: SupportUserTemplate
                if case let .user(existing) = source {
                    userTemplate = SupportUserTemplate(id: existing.id, template: template)
                } else {
                    userTemplate = SupportUserTemplate(template: template)
                }
                let _ = (addOrUpdateSupportUserTemplate(context: context, userTemplate)
                |> deliverOnMainQueue).startStandalone(completed: {
                    dismissImpl?()
                })
            })
            
            entries.append(.questionInput(state.question))
            entries.append(.keysEditor(state.keys))
            entries.append(.keysAddInput(state.pendingNewKeyText))
            entries.append(.keysInputFooter(presentationData.strings.SupportTemplates_KeysFooter))
            entries.append(.valueInput(state.valueText))
            entries.append(.valueInputFooter(presentationData.strings.SupportTemplates_ValueFooter))
        } else {
            // Reactive, not `initialTemplate` (that's frozen at controller-creation time
            // from `source`): this view-mode instance stays alive on the nav stack while a
            // pushed Edit instance is on top, and must show the just-saved content when the
            // Edit instance pops back, not the stale pre-edit snapshot it was created with.
            // Bug: after Edit -> change something -> Save, the screen you land back on kept
            // showing the old content (looked like "changes are not getting saved" even
            // though the save itself succeeded) because this branch always rendered
            // `initialTemplate` regardless of what had since changed in the store.
            let template: SupportTemplate
            switch source {
            case let .user(userTemplate):
                template = allUserTemplates.first(where: { $0.id == userTemplate.id })?.template ?? userTemplate.template
            default:
                template = initialTemplate ?? SupportTemplate(question: "", keys: [], value: .text(""))
            }
            title = template.question
            
            entries.append(.title(template.question))
            
            switch source {
            case .official:
                entries.append(.keys(keys: template.keys, highlighted: [], note: nil))
            case let .user(userTemplate):
                var highlighted = Set<String>()
                var officialOverlapCount = 0
                for key in template.keys {
                    let others = SupportTemplateCollisions.otherUserTemplatesSharingKey(key, excludingId: userTemplate.id, in: allUserTemplates)
                    if !others.isEmpty {
                        highlighted.insert(key)
                    } else if SupportTemplateCollisions.officialTemplateSharesKey(key, in: allOfficialTemplates) {
                        officialOverlapCount += 1
                    }
                }
                let note: String?
                if officialOverlapCount > 0 {
                    note = presentationData.strings.SupportTemplates_OfficialOverlapNote(officialOverlapCount).string
                } else {
                    note = nil
                }
                entries.append(.keys(keys: template.keys, highlighted: highlighted, note: note))
            case .newUserTemplate:
                break
            }
            
            entries.append(.value(supportTemplateValueDisplayText(template.value)))
            
            switch source {
            case .official:
                rightNavigationButton = nil
                entries.append(.clone(presentationData.strings.SupportTemplates_CloneAsUserTemplate))
            case let .user(userTemplate):
                // Seed Edit from the reactive `template` (same fix as above), not the
                // frozen `source` - otherwise a second edit (Edit -> Save -> Edit again)
                // would silently revert the first edit by re-seeding from the original
                // pre-edit content captured when this controller was first pushed.
                rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Edit), style: .regular, enabled: true, action: {
                    pushImpl?(supportTemplateDetailController(context: context, source: .user(SupportUserTemplate(id: userTemplate.id, template: template)), startInEditMode: true))
                })
                entries.append(.delete(presentationData.strings.SupportTemplates_DeleteTemplate))
            case .newUserTemplate:
                break
            }
        }
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(title), leftNavigationButton: leftNavigationButton, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, animateChanges: false)
        
        return (controllerState, (listState, arguments))
    }
    
    let controller = ItemListController(context: context, state: signal)
    
    pushImpl = { [weak controller] pushedController in
        controller?.push(pushedController)
    }
    
    presentImpl = { [weak controller] presentedController in
        controller?.present(presentedController, in: .window(.root))
    }
    
    dismissImpl = { [weak controller] in
        guard let controller else { return }
        if let navigationController = controller.navigationController as? NavigationController {
            navigationController.filterController(controller, animated: true)
        } else {
            controller.dismiss()
        }
    }
    
    showCollisionsImpl = { [weak controller] in
        guard let controller, case let .user(userTemplate) = source else { return }
        let _ = (supportUserTemplates(context: context)
        |> take(1)
        |> deliverOnMainQueue).startStandalone(next: { allUserTemplates in
            var conflicting: [SupportUserTemplate] = []
            for key in userTemplate.template.keys {
                for other in SupportTemplateCollisions.otherUserTemplatesSharingKey(key, excludingId: userTemplate.id, in: allUserTemplates) {
                    if !conflicting.contains(where: { $0.id == other.id }) {
                        conflicting.append(other)
                    }
                }
            }
            guard !conflicting.isEmpty else { return }
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let actionSheet = ActionSheetController(presentationData: presentationData)
            var items: [ActionSheetItem] = []
            for other in conflicting {
                items.append(ActionSheetButtonItem(title: other.template.question, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                    controller.push(supportTemplateDetailController(context: context, source: .user(other)))
                }))
            }
            actionSheet.setItemGroups([
                ActionSheetItemGroup(items: items),
                ActionSheetItemGroup(items: [
                    ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                    })
                ])
            ])
            controller.present(actionSheet, in: .window(.root))
        })
    }
    
    return controller
}

