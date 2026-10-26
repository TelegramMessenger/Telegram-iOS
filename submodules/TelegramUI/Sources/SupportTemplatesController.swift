import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import AccountContext
import LegacyMediaPickerUI
import ContextUI

/// TSupport Templates browser/settings screen (D29). Two presentations share one screen:
/// - `.chat`: pushed from the chat input bar's accessory icon. Official + User Templates are
///   merged into one labeled list (D34: a browsing context never hides a candidate silently -
///   unlike the `/`-strip, which applies the override via `SupportTemplateCollisions`); tap
///   inserts into the draft. (Simplification carried from Round A: pushed onto the existing
///   navigation stack with a Close button, rather than a true bottom sheet.)
/// - `.settings`: pushed from Settings -> Support -> Templates. An Official/Mine segmented
///   control (D29 §9) switches between the language-filtered official list (unchanged from
///   Round A) and the local User Templates list (Round B) with its own Add/Export/Import
///   actions; tap pushes Template Detail either way.
enum SupportTemplatesControllerMode {
    case chat(selectTemplate: (SupportTemplate) -> Void)
    case settings
}

private enum SupportTemplatesTab: Int32, Equatable {
    case official = 0
    case mine = 1
}

private struct SupportTemplatesControllerState: Equatable {
    var tab: SupportTemplatesTab = .official
    /// Owner feedback (Round B polish, items 5/7): a nav-bar icon toggles an inline search
    /// field at the top of the list - the established per-screen search pattern in this
    /// codebase (`ItemListControllerSearch`) is also nav-icon-triggered, never a pull-down
    /// gesture, so this reuses the same activation model without needing to fork the
    /// shared `ItemListController`/`ListView` scroll system for a custom gesture.
    var isSearching: Bool = false
    var searchQuery: String = ""
}

private final class SupportTemplatesControllerArguments {
    let selectLanguage: () -> Void
    let selectOfficialTemplate: (SupportTemplate) -> Void
    let selectUserTemplate: (SupportUserTemplate) -> Void
    let reload: () -> Void
    let addUserTemplate: () -> Void
    let deleteUserTemplate: (SupportUserTemplate) -> Void
    let exportUserTemplates: () -> Void
    let importUserTemplates: () -> Void
    let toggleSearch: () -> Void
    let updateSearchQuery: (String) -> Void
    /// Long-press "peek" preview (owner: "like 3D touch") - fired by `SupportTemplateRowItemNode`
    /// on activation; the actual `ContextController` is built/presented in
    /// `supportTemplatesController(context:mode:)` below (`showTemplatePreviewImpl`), not here.
    let showTemplatePreview: (SupportTemplatePreviewPayload, ASDisplayNode, ContextGesture?) -> Void
    
    init(selectLanguage: @escaping () -> Void, selectOfficialTemplate: @escaping (SupportTemplate) -> Void, selectUserTemplate: @escaping (SupportUserTemplate) -> Void, reload: @escaping () -> Void, addUserTemplate: @escaping () -> Void, deleteUserTemplate: @escaping (SupportUserTemplate) -> Void, exportUserTemplates: @escaping () -> Void, importUserTemplates: @escaping () -> Void, toggleSearch: @escaping () -> Void, updateSearchQuery: @escaping (String) -> Void, showTemplatePreview: @escaping (SupportTemplatePreviewPayload, ASDisplayNode, ContextGesture?) -> Void) {
        self.selectLanguage = selectLanguage
        self.selectOfficialTemplate = selectOfficialTemplate
        self.selectUserTemplate = selectUserTemplate
        self.reload = reload
        self.addUserTemplate = addUserTemplate
        self.deleteUserTemplate = deleteUserTemplate
        self.exportUserTemplates = exportUserTemplates
        self.importUserTemplates = importUserTemplates
        self.toggleSearch = toggleSearch
        self.updateSearchQuery = updateSearchQuery
        self.showTemplatePreview = showTemplatePreview
    }
}

private enum SupportTemplatesSection: Int32 {
    case search
    case language
    case templates
    case actions
}

private enum SupportTemplatesEntry: ItemListNodeEntry {
    case searchInput(String)
    case language(String, String)
    case templatesHeader(String)
    case officialTemplate(Int, SupportTemplate, showBadge: Bool, contextActionTitle: String)
    case userTemplate(Int, SupportUserTemplate, showBadge: Bool, deletable: Bool, contextActionTitle: String)
    case empty(String)
    case lastUpdated(String)
    case reload(String)
    case export(String, Bool)
    case importTemplates(String)
    
    var section: ItemListSectionId {
        switch self {
        case .searchInput:
            return SupportTemplatesSection.search.rawValue
        case .language:
            return SupportTemplatesSection.language.rawValue
        case .templatesHeader, .officialTemplate, .userTemplate, .empty, .lastUpdated, .reload:
            return SupportTemplatesSection.templates.rawValue
        case .export, .importTemplates:
            return SupportTemplatesSection.actions.rawValue
        }
    }
    
    var stableId: Int {
        switch self {
        case .searchInput:
            return -1
        case .language:
            return 0
        case .templatesHeader:
            return 1
        case let .userTemplate(index, _, _, _, _):
            return 200_000 + index
        // Must sort after .userTemplate: chat mode (D34) appends every .userTemplate entry
        // before any .officialTemplate entry, and ItemListControllerNode asserts entries
        // are strictly increasing by stableId - this used to start at 2 and crashed
        // (EXC_BREAKPOINT assertion failure) the first time a volunteer had at least one of
        // each kind of template simultaneously, since array order (user then official) then
        // contradicted stableId order (2+index was always less than 200_000+index).
        case let .officialTemplate(index, _, _, _):
            return 300_000 + index
        case .empty:
            return 1_000_000
        case .lastUpdated:
            return 1_000_001
        case .reload:
            return 1_000_002
        case .export:
            return 1_000_003
        case .importTemplates:
            return 1_000_004
        }
    }
    
    static func ==(lhs: SupportTemplatesEntry, rhs: SupportTemplatesEntry) -> Bool {
        switch lhs {
        case let .searchInput(lhsText):
            if case let .searchInput(rhsText) = rhs {
                return lhsText == rhsText
            }
            return false
        case let .language(lhsTitle, lhsValue):
            if case let .language(rhsTitle, rhsValue) = rhs {
                return lhsTitle == rhsTitle && lhsValue == rhsValue
            }
            return false
        case let .templatesHeader(lhsText):
            if case let .templatesHeader(rhsText) = rhs {
                return lhsText == rhsText
            }
            return false
        case let .officialTemplate(lhsIndex, lhsTemplate, lhsShowBadge, lhsContextActionTitle):
            if case let .officialTemplate(rhsIndex, rhsTemplate, rhsShowBadge, rhsContextActionTitle) = rhs {
                return lhsIndex == rhsIndex && lhsTemplate == rhsTemplate && lhsShowBadge == rhsShowBadge && lhsContextActionTitle == rhsContextActionTitle
            }
            return false
        case let .userTemplate(lhsIndex, lhsTemplate, lhsShowBadge, lhsDeletable, lhsContextActionTitle):
            if case let .userTemplate(rhsIndex, rhsTemplate, rhsShowBadge, rhsDeletable, rhsContextActionTitle) = rhs {
                return lhsIndex == rhsIndex && lhsTemplate == rhsTemplate && lhsShowBadge == rhsShowBadge && lhsDeletable == rhsDeletable && lhsContextActionTitle == rhsContextActionTitle
            }
            return false
        case let .empty(lhsText):
            if case let .empty(rhsText) = rhs {
                return lhsText == rhsText
            }
            return false
        case let .lastUpdated(lhsText):
            if case let .lastUpdated(rhsText) = rhs {
                return lhsText == rhsText
            }
            return false
        case let .reload(lhsText):
            if case let .reload(rhsText) = rhs {
                return lhsText == rhsText
            }
            return false
        case let .export(lhsText, lhsEnabled):
            if case let .export(rhsText, rhsEnabled) = rhs {
                return lhsText == rhsText && lhsEnabled == rhsEnabled
            }
            return false
        case let .importTemplates(lhsText):
            if case let .importTemplates(rhsText) = rhs {
                return lhsText == rhsText
            }
            return false
        }
    }
    
    static func <(lhs: SupportTemplatesEntry, rhs: SupportTemplatesEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! SupportTemplatesControllerArguments
        switch self {
        case let .searchInput(text):
            return ItemListSingleLineInputItem(presentationData: presentationData, title: NSAttributedString(string: "", textColor: .black), text: text, placeholder: presentationData.strings.SupportTemplates_SearchPlaceholder, type: .regular(capitalization: false, autocorrection: false), clearType: .always, sectionId: self.section, textUpdated: { value in
                arguments.updateSearchQuery(value)
            }, action: {
            })
        case let .language(title, value):
            return ItemListDisclosureItem(presentationData: presentationData, title: title, label: value, sectionId: self.section, style: .blocks, action: {
                arguments.selectLanguage()
            })
        case let .templatesHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .officialTemplate(_, template, showBadge, contextActionTitle):
            // Every template row (both cases below) uses the dedicated `SupportTemplateRowItem`
            // now, not the shared `ItemListDisclosureItem` - see that file's header comment
            // for why (badge/label overlap + a "ghost" badge-text leak, both confirmed
            // on-device, neither safe to patch in a widely-shared foundation type).
            return SupportTemplateRowItem(presentationData: presentationData, title: template.question, value: template.value, keys: template.keys, badgeText: showBadge ? presentationData.strings.SupportTemplates_SourceOfficial : nil, sectionId: self.section, action: {
                arguments.selectOfficialTemplate(template)
            }, contextActionTitle: contextActionTitle, deleteAction: nil, contextAction: { payload, node, gesture in
                arguments.showTemplatePreview(payload, node, gesture)
            })
        case let .userTemplate(_, userTemplate, showBadge, deletable, contextActionTitle):
            // Owner feedback: swipe-to-delete directly from the Mine tab, no need to open
            // Detail first - `deletable` is only ever `true` there, so `deleteAction` is
            // `nil` (no swipe, no menu Delete entry) everywhere else.
            return SupportTemplateRowItem(presentationData: presentationData, title: userTemplate.template.question, value: userTemplate.template.value, keys: userTemplate.template.keys, badgeText: showBadge ? presentationData.strings.SupportTemplates_SourceMine : nil, sectionId: self.section, action: {
                arguments.selectUserTemplate(userTemplate)
            }, contextActionTitle: contextActionTitle, deleteAction: deletable ? {
                arguments.deleteUserTemplate(userTemplate)
            } : nil, contextAction: { payload, node, gesture in
                arguments.showTemplatePreview(payload, node, gesture)
            })
        case let .empty(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .lastUpdated(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .reload(text):
            return ItemListActionItem(presentationData: presentationData, title: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.reload()
            })
        case let .export(text, enabled):
            return ItemListActionItem(presentationData: presentationData, title: text, kind: enabled ? .generic : .disabled, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.exportUserTemplates()
            })
        case let .importTemplates(text):
            return ItemListActionItem(presentationData: presentationData, title: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.importUserTemplates()
            })
        }
    }
}

/// Substring match (not prefix-only like the `/`-strip's `matchingSupportTemplates`)
/// against Question, every Key, and Value text - used by the explicit search fields in the
/// chat-mode browser and both Settings tabs (items 5/6/7).
private func supportTemplateMatchesSearchQuery(_ template: SupportTemplate, normalizedQuery: String) -> Bool {
    guard !normalizedQuery.isEmpty else {
        return true
    }
    if normalizeSupportTemplateQuestion(template.question).contains(normalizedQuery) {
        return true
    }
    if template.keys.contains(where: { normalizeSupportTemplateQuestion($0).contains(normalizedQuery) }) {
        return true
    }
    if case let .text(text) = template.value, normalizeSupportTemplateQuestion(text).contains(normalizedQuery) {
        return true
    }
    return false
}

func supportTemplateValuePreview(_ value: SupportTemplateValue) -> String {
    switch value {
    case let .text(text):
        let firstLine = text.components(separatedBy: "\n").first ?? text
        if firstLine.count > 60 {
            return String(firstLine.prefix(60)) + "…"
        }
        return firstLine
    case let .contact(_, name, _):
        return "👤 \(name)"
    }
}

private func supportTemplatesControllerEntries(strings: PresentationStrings, mode: SupportTemplatesControllerMode, tab: SupportTemplatesTab, language: String, officialTemplates: [SupportTemplate], userTemplates: [SupportUserTemplate], lastUpdated: Date?, isSearching: Bool, searchQuery: String) -> [SupportTemplatesEntry] {
    var entries: [SupportTemplatesEntry] = []
    
    let isChatMode: Bool
    if case .chat = mode {
        isChatMode = true
    } else {
        isChatMode = false
    }
    
    if isSearching {
        entries.append(.searchInput(searchQuery))
    }
    
    // Owner feedback item 6/7: search matches Question/Keys/Value content, not just a keys
    // prefix - the `/`-strip's own (prefix-first, content-as-fallback) matching stays in
    // `matchingSupportTemplates`; this is a separate, explicit search field so a plain
    // substring match throughout is the right (and simpler) behavior here.
    let hasAnyUserTemplates = !userTemplates.isEmpty
    let normalizedQuery = normalizeSupportTemplateQuestion(searchQuery)
    let officialTemplates = isSearching ? officialTemplates.filter { supportTemplateMatchesSearchQuery($0, normalizedQuery: normalizedQuery) } : officialTemplates
    let userTemplates = isSearching ? userTemplates.filter { supportTemplateMatchesSearchQuery($0.template, normalizedQuery: normalizedQuery) } : userTemplates
    
    let languageTitle = supportTemplateLanguages.first(where: { $0.code == language })?.displayName ?? language
    // User Templates have no language concept at all (D35) - the picker only makes sense
    // where it actually filters something: the chat-mode merged list and the Official tab.
    if isChatMode || tab == .official {
        entries.append(.language(strings.SupportTemplates_Language, languageTitle))
    }
    
    if isChatMode {
        // D34: the full browser shows both sources merged, each labeled - never the
        // `/`-strip's override (that lives only in SupportTemplateCollisions, used by
        // ChatInterfaceStateContextQueries, not here).
        entries.append(.templatesHeader(strings.SupportTemplates_SectionTitle))
        if officialTemplates.isEmpty && userTemplates.isEmpty {
            entries.append(.empty(strings.SupportTemplates_Empty))
        } else {
            var index = 0
            for userTemplate in userTemplates {
                entries.append(.userTemplate(index, userTemplate, showBadge: true, deletable: false, contextActionTitle: strings.SupportTemplates_ContextUse))
                index += 1
            }
            for template in officialTemplates {
                entries.append(.officialTemplate(index, template, showBadge: true, contextActionTitle: strings.SupportTemplates_ContextUse))
                index += 1
            }
        }
        return entries
    }
    
    switch tab {
    case .official:
        entries.append(.templatesHeader(strings.SupportTemplates_SectionTitle))
        if officialTemplates.isEmpty {
            entries.append(.empty(strings.SupportTemplates_Empty))
        } else {
            for (index, template) in officialTemplates.enumerated() {
                entries.append(.officialTemplate(index, template, showBadge: false, contextActionTitle: strings.SupportTemplates_ContextViewDetails))
            }
        }
        if let lastUpdated = lastUpdated {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            entries.append(.lastUpdated(strings.SupportTemplates_LastUpdated(formatter.string(from: lastUpdated)).string))
        }
        entries.append(.reload(strings.SupportTemplates_ReloadNow))
    case .mine:
        entries.append(.templatesHeader(strings.SupportTemplates_MySectionTitle))
        if userTemplates.isEmpty {
            entries.append(.empty(strings.SupportTemplates_MineEmpty))
        } else {
            for (index, userTemplate) in userTemplates.enumerated() {
                // Reuses the generic "Edit" string rather than adding a new
                // `SupportTemplates_Context*` key, per the existing `Common_Edit`/`Common_Delete`
                // precedent already used for this tab's swipe-to-delete option below.
                entries.append(.userTemplate(index, userTemplate, showBadge: false, deletable: true, contextActionTitle: strings.Common_Edit))
            }
        }
        entries.append(.export(strings.SupportTemplates_ExportAction, hasAnyUserTemplates))
        entries.append(.importTemplates(strings.SupportTemplates_ImportAction))
    }
    
    return entries
}

func supportTemplatesController(context: AccountContext, mode: SupportTemplatesControllerMode) -> ViewController {
    var pushDetailImpl: ((SupportTemplateDetailSource, Bool) -> Void)?
    var presentLanguagePickerImpl: (() -> Void)?
    var dismissImpl: (() -> Void)?
    var presentNativeImpl: ((UIViewController) -> Void)?
    var presentImpl: ((ViewController) -> Void)?
    var showTemplatePreviewImpl: ((SupportTemplatePreviewPayload, ASDisplayNode, ContextGesture?) -> Void)?
    
    let isChatMode: Bool
    if case .chat = mode {
        isChatMode = true
    } else {
        isChatMode = false
    }
    
    let stateValue = Atomic(value: SupportTemplatesControllerState())
    let statePromise = ValuePromise(SupportTemplatesControllerState(), ignoreRepeated: true)
    let updateState: ((SupportTemplatesControllerState) -> SupportTemplatesControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    let importFile: (URL) -> String? = { url in
        guard url.startAccessingSecurityScopedResource() else { return nil }
        defer { url.stopAccessingSecurityScopedResource() }
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinationError: NSError?
        var text: String?
        coordinator.coordinate(readingItemAt: url, options: [], error: &coordinationError, byAccessor: { readURL in
            text = try? String(contentsOf: readURL, encoding: .utf8)
        })
        return text
    }
    
    let arguments = SupportTemplatesControllerArguments(selectLanguage: {
        presentLanguagePickerImpl?()
    }, selectOfficialTemplate: { template in
        switch mode {
        case let .chat(selectTemplate):
            // Both text and contact templates go straight through here - the contact
            // confirm step (D31) is provided by the caller's selectTemplate closure, so
            // there's no need to detour through Detail first in chat mode.
            selectTemplate(template)
            dismissImpl?()
        case .settings:
            pushDetailImpl?(.official(template), false)
        }
    }, selectUserTemplate: { userTemplate in
        switch mode {
        case let .chat(selectTemplate):
            selectTemplate(userTemplate.template)
            dismissImpl?()
        case .settings:
            // Owner feedback: a Mine-tab row is already yours, so tapping it should go
            // straight to editing it rather than the read-only view first - this `case`
            // is only ever reached from the Mine tab (the merged chat-mode list goes
            // through the `.chat` case above instead), so there's no other caller to
            // account for.
            pushDetailImpl?(.user(userTemplate), true)
        }
    }, reload: {
        let _ = (supportTemplateLanguageSetting(context: context)
        |> take(1)
        |> mapToSignal { language -> Signal<Never, NoError> in
            return reloadSupportTemplates(context: context, language: language)
        }).startStandalone()
    }, addUserTemplate: {
        // `startInEditMode` is irrelevant here - `.newUserTemplate` always forces editing
        // regardless of this flag - but `false` matches the call's actual intent.
        pushDetailImpl?(.newUserTemplate(prefill: nil), false)
    }, deleteUserTemplate: { userTemplate in
        // No confirmation dialog here (unlike Detail's Delete button): the swipe + tap on
        // the revealed red option is already a deliberate two-step gesture, and the owner
        // specifically asked for direct deletion from this list, matching the standard
        // iOS swipe-to-delete convention (Mail, Reminders, etc. don't double-confirm it).
        let _ = deleteSupportUserTemplate(context: context, id: userTemplate.id).startStandalone()
    }, exportUserTemplates: {
        let _ = (supportUserTemplates(context: context)
        |> take(1)
        |> deliverOnMainQueue).startStandalone(next: { userTemplates in
            guard !userTemplates.isEmpty else { return }
            let text = exportSupportUserTemplatesText(userTemplates)
            let tempFile = EngineTempBox.shared.tempFile(fileName: "tsupport_templates.txt")
            do {
                try text.write(toFile: tempFile.path, atomically: true, encoding: .utf8)
            } catch {
                return
            }
            let fileURL = URL(fileURLWithPath: tempFile.path)
            let activityController = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
            presentNativeImpl?(activityController)
        })
    }, importUserTemplates: {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        presentImpl?(legacyICloudFilePicker(theme: presentationData.theme, mode: .import, hasMultiselection: true, documentTypes: ["public.plain-text", "public.text", "public.item"], completion: { urls in
            guard !urls.isEmpty else { return }
            let combinedText = urls.compactMap(importFile).joined(separator: "\n\n")
            guard !combinedText.isEmpty else { return }
            let _ = (importSupportUserTemplates(context: context, text: combinedText)
            |> deliverOnMainQueue).startStandalone(next: { summary in
                guard !summary.isEmpty else { return }
                var text = presentationData.strings.SupportTemplates_ImportSummary(summary.addedCount, summary.updatedCount).string
                if !summary.newCollisionKeys.isEmpty {
                    text += "\n" + presentationData.strings.SupportTemplates_ImportCollisionNote(summary.newCollisionKeys.joined(separator: ", ")).string
                }
                presentImpl?(textAlertController(context: context, title: presentationData.strings.SupportTemplates_ImportResultTitle, text: text, actions: [
                    TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})
                ]))
            })
        }))
    }, toggleSearch: {
        updateState { state in
            var state = state
            state.isSearching.toggle()
            if !state.isSearching {
                state.searchQuery = ""
            }
            return state
        }
    }, updateSearchQuery: { query in
        updateState { state in
            var state = state
            state.searchQuery = query
            return state
        }
    }, showTemplatePreview: { payload, node, gesture in
        showTemplatePreviewImpl?(payload, node, gesture)
    })
    
    let signal = combineLatest(
        context.sharedContext.presentationData,
        statePromise.get(),
        supportTemplateLanguageSetting(context: context) |> mapToSignal { language -> Signal<(String, [SupportTemplate], Date?), NoError> in
            return combineLatest(supportTemplates(context: context, language: language), supportTemplateLastUpdated(context: context, language: language))
            |> map { templates, lastUpdated in
                return (language, templates, lastUpdated)
            }
        },
        supportUserTemplates(context: context)
    )
    |> deliverOnMainQueue
    |> map { presentationData, state, languageState, userTemplates -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let (language, officialTemplates, lastUpdated) = languageState
        
        let title: ItemListControllerTitle
        if isChatMode {
            title = .text(presentationData.strings.SupportTemplates_Title)
        } else {
            title = .textWithTabs(presentationData.strings.SupportTemplates_Title, [presentationData.strings.SupportTemplates_TabOfficial, presentationData.strings.SupportTemplates_TabMine], Int(state.tab.rawValue))
        }
        
        // Owner feedback items 5/7: a nav-bar icon toggles an inline search field. The Mine
        // tab's right slot is already Add, so the toggle moves to the left there (otherwise
        // unused in Settings mode); every other case uses the right slot, matching the
        // Close button's side in chat mode.
        //
        // Owner feedback (tried, reverted): a combined `.node(...)` button hosting Add and
        // Search together, so search would sit in one fixed position instead of swapping
        // sides between tabs. `ItemListController`'s navigation bar is unconditionally
        // `style: .glass` (ItemListController.swift:286, not a per-screen choice) - a plain
        // custom `ASDisplayNode` is not what that system expects for bar-button content
        // (confirmed on-device: the title disappeared and the custom node's buttons
        // rendered off-position, e.g. pinned to the screen's left edge instead of inside
        // the nav bar). Reverted to the plain `.icon(...)` buttons below, which the glass
        // nav bar already renders correctly natively - back to search swapping sides
        // between tabs, which is a known-working tradeoff rather than a broken screen.
        let searchToggleButton = ItemListNavigationButton(content: .icon(state.isSearching ? .close : .search), style: .regular, enabled: true, action: {
            arguments.toggleSearch()
        })
        
        var leftNavigationButton: ItemListNavigationButton?
        var rightNavigationButton: ItemListNavigationButton?
        if isChatMode {
            leftNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Close), style: .regular, enabled: true, action: {
                dismissImpl?()
            })
            rightNavigationButton = searchToggleButton
        } else if state.tab == .mine {
            leftNavigationButton = searchToggleButton
            rightNavigationButton = ItemListNavigationButton(content: .icon(.add), style: .regular, enabled: true, action: {
                arguments.addUserTemplate()
            })
        } else {
            rightNavigationButton = searchToggleButton
        }
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: title, leftNavigationButton: leftNavigationButton, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: supportTemplatesControllerEntries(strings: presentationData.strings, mode: mode, tab: state.tab, language: language, officialTemplates: officialTemplates, userTemplates: userTemplates, lastUpdated: lastUpdated, isSearching: state.isSearching, searchQuery: state.searchQuery), style: .blocks, animateChanges: true)
        
        return (controllerState, (listState, arguments))
    }
    
    let controller = ItemListController(context: context, state: signal)
    
    controller.titleControlValueChanged = { index in
        updateState { state in
            var state = state
            state.tab = SupportTemplatesTab(rawValue: Int32(index)) ?? .official
            return state
        }
    }
    
    pushDetailImpl = { [weak controller] source, startInEditMode in
        let detailController = supportTemplateDetailController(context: context, source: source, startInEditMode: startInEditMode)
        controller?.push(detailController)
    }
    
    presentLanguagePickerImpl = { [weak controller] in
        guard let controller else {
            return
        }
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let actionSheet = ActionSheetController(presentationData: presentationData)
        var items: [ActionSheetItem] = []
        for languageInfo in supportTemplateLanguages {
            items.append(ActionSheetButtonItem(title: languageInfo.displayName, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
                let _ = updateSupportTemplateLanguage(context: context, language: languageInfo.code).startStandalone()
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
    }
    
    presentImpl = { [weak controller] presentedController in
        controller?.present(presentedController, in: .window(.root))
    }
    
    presentNativeImpl = { controller in
        context.sharedContext.applicationBindings.presentNativeController(controller)
    }
    
    showTemplatePreviewImpl = { [weak controller] payload, node, gesture in
        guard let controller, let node = node as? ContextExtractedContentContainingNode else {
            gesture?.cancel()
            return
        }
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        var items: [ContextMenuItem] = []
        items.append(.custom(SupportTemplatePreviewContextItem(payload: payload), false))
        items.append(.action(ContextMenuActionItem(text: payload.primaryActionTitle, icon: { _ in
            return nil
        }, action: { _, f in
            f(.default)
            payload.primaryAction()
        })))
        if let deleteAction = payload.deleteAction {
            // No confirmation dialog, matching the same row's swipe-to-delete option -
            // see `deleteUserTemplate` above for the established rationale.
            items.append(.action(ContextMenuActionItem(text: presentationData.strings.Common_Delete, textColor: .destructive, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.actionSheet.destructiveActionTextColor)
            }, action: { _, f in
                f(.default)
                deleteAction()
            })))
        }
        
        let contextController = makeContextController(presentationData: presentationData, source: .extracted(SupportTemplateContextExtractedContentSource(controller: controller, sourceNode: node, keepInPlace: false, blurBackground: true)), items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
        controller.presentInGlobalOverlay(contextController)
    }
    
    dismissImpl = { [weak controller] in
        guard let controller else {
            return
        }
        if let navigationController = controller.navigationController as? NavigationController {
            navigationController.filterController(controller, animated: true)
        } else {
            controller.dismiss()
        }
    }
    
    return controller
}

/// ~15-line `ContextExtractedContentSource` conformer for the long-press preview, modeled
/// directly on `InviteLinksUI/Sources/InviteLinkListController.swift`'s
/// `InviteLinkContextExtractedContentSource`.
private final class SupportTemplateContextExtractedContentSource: ContextExtractedContentSource {
    public var keepInPlace: Bool
    public let ignoreContentTouches: Bool = true
    public let blurBackground: Bool
    
    private let controller: ViewController
    private let sourceNode: ContextExtractedContentContainingNode
    
    public init(controller: ViewController, sourceNode: ContextExtractedContentContainingNode, keepInPlace: Bool, blurBackground: Bool) {
        self.controller = controller
        self.sourceNode = sourceNode
        self.keepInPlace = keepInPlace
        self.blurBackground = blurBackground
    }
    
    public func takeView() -> ContextControllerTakeViewInfo? {
        return ContextControllerTakeViewInfo(containingItem: .node(self.sourceNode), contentAreaInScreenSpace: UIScreen.main.bounds)
    }
    
    public func putBack() -> ContextControllerPutBackViewInfo? {
        return ContextControllerPutBackViewInfo(contentAreaInScreenSpace: UIScreen.main.bounds)
    }
}
