import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import AlertUI
import SupportTemplates
import LegacyMediaPickerUI

private final class SupportTemplatesListControllerArguments {
    let openFile: () -> Void
    let restoreDefaults: () -> Void
    let export: () -> Void
    let addTemplate: () -> Void
    let openTemplate: (SupportTemplatesListEntry) -> Void

    init(openFile: @escaping () -> Void, restoreDefaults: @escaping () -> Void, export: @escaping () -> Void, addTemplate: @escaping () -> Void, openTemplate: @escaping (SupportTemplatesListEntry) -> Void) {
        self.openFile = openFile
        self.restoreDefaults = restoreDefaults
        self.export = export
        self.addTemplate = addTemplate
        self.openTemplate = openTemplate
    }
}

private enum SupportTemplatesListSection: Int32 {
    case file
    case top
    case templates
}

private enum SupportTemplatesListEntryId: Hashable {
    case fileName
    case fileUrl
    case restore
    case add
    case info
    case header
    case empty
    case template(String)
}

private enum SupportTemplatesListItemEntry: ItemListNodeEntry {
    case fileName(String)
    case fileUrl(String)
    case restore(isEnabled: Bool)
    case add
    case info(String)
    case header(String)
    case empty(String)
    case template(index: Int, entry: SupportTemplatesListEntry)

    var section: ItemListSectionId {
        switch self {
        case .fileName, .fileUrl:
            return SupportTemplatesListSection.file.rawValue
        case .restore, .add, .info:
            return SupportTemplatesListSection.top.rawValue
        case .header, .empty, .template:
            return SupportTemplatesListSection.templates.rawValue
        }
    }

    var stableId: SupportTemplatesListEntryId {
        switch self {
        case .fileName:
            return .fileName
        case .fileUrl:
            return .fileUrl
        case .restore:
            return .restore
        case .add:
            return .add
        case .info:
            return .info
        case .header:
            return .header
        case .empty:
            return .empty
        case let .template(_, entry):
            return .template(entry.id)
        }
    }

    private var sortIndex: Int {
        switch self {
        case .fileName:
            return -2
        case .fileUrl:
            return -1
        case .restore:
            return 1
        case .add:
            return 2
        case .info:
            return 3
        case .header:
            return 5
        case .empty:
            return 6
        case let .template(index, _):
            return 7 + index
        }
    }

    static func <(lhs: SupportTemplatesListItemEntry, rhs: SupportTemplatesListItemEntry) -> Bool {
        return lhs.sortIndex < rhs.sortIndex
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! SupportTemplatesListControllerArguments
        switch self {
        case let .fileName(name):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: presentationData.strings.Support_Templates_FileName, label: name, sectionId: self.section, style: .blocks, action: {
                arguments.openFile()
            })
        case let .fileUrl(url):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: presentationData.strings.Support_Templates_FileUrl, label: url.isEmpty ? presentationData.strings.Support_Templates_FileUrlNone : url, sectionId: self.section, style: .blocks, action: {
                arguments.openFile()
            })
        case let .restore(isEnabled):
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: presentationData.strings.Support_Templates_RestoreDefaults, kind: isEnabled ? .destructive : .disabled, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                if isEnabled {
                    arguments.restoreDefaults()
                }
            })
        case .add:
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: presentationData.strings.Support_Templates_NewTemplate, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.addTemplate()
            })
        case let .info(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .header(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .empty(text):
            return ItemListPlaceholderItem(theme: presentationData.theme, systemStyle: .glass, text: text, sectionId: self.section, style: .blocks)
        case let .template(_, entry):
            let label: String
            switch entry.status {
            case .original:
                label = ""
            case .edited:
                label = presentationData.strings.Support_Templates_Edited
            case .removed:
                label = presentationData.strings.Support_Templates_Deleted
            }
            let title = entry.template.question.isEmpty ? entry.template.originalKeys.joined(separator: ", ") : entry.template.question
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: title, label: label, additionalDetailLabel: supportTemplatesListDetail(entry.template), sectionId: self.section, style: .blocks, action: {
                arguments.openTemplate(entry)
            })
        }
    }
}

private func supportTemplatesListDetail(_ template: SupportTemplatesQuestion) -> String {
    let value = String(template.value.prefix(200)).replacingOccurrences(of: "\n", with: " ")
    if template.originalKeys.isEmpty {
        return value
    }
    return template.originalKeys.joined(separator: ", ") + " · " + value
}

private struct SupportTemplatesListItems {
    let entries: [SupportTemplatesListEntry]
    let searchTexts: [String]
    let editCount: Int
    let url: String
}

private func supportTemplatesSearchFolded(_ text: String) -> String {
    return text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
}

private func supportTemplatesListItems(manager: SupportTemplatesManager, source: SupportTemplatesSource) -> Signal<SupportTemplatesListItems, NoError> {
    return supportTemplatesStateSignal(manager: manager)
    |> deliverOn(Queue.concurrentDefaultQueue())
    |> map { state -> SupportTemplatesListItems in
        let entries = manager.listEntries(source)
        let searchTexts = entries.map { entry in
            supportTemplatesSearchFolded(entry.template.question + "\n" + entry.template.originalKeys.joined(separator: "\n") + "\n" + entry.template.value)
        }
        var editCount = 0
        var url = ""
        if case let .file(name) = source, let info = state?.files.first(where: { $0.name == name }) {
            editCount = info.editCount
            url = info.url
        }
        return SupportTemplatesListItems(entries: entries, searchTexts: searchTexts, editCount: editCount, url: url)
    }
}

private func supportTemplatesListEntries(strings: PresentationStrings, source: SupportTemplatesSource, items: SupportTemplatesListItems?, query: String, isSearchActive: Bool) -> [SupportTemplatesListItemEntry] {
    var result: [SupportTemplatesListItemEntry] = []
    let count = items?.entries.count ?? 0
    let countText = strings.Support_Templates_FileTemplates(Int32(count))
    if !isSearchActive {
        switch source {
        case let .file(name):
            result.append(.fileName(name))
            result.append(.fileUrl(items?.url ?? ""))
            let editCount = items?.editCount ?? 0
            result.append(.restore(isEnabled: editCount > 0))
            if editCount == 0 {
                result.append(.info(strings.Support_Templates_ListInfo.replacingOccurrences(of: "{templates}", with: countText)))
            } else {
                result.append(.info(strings.Support_Templates_ListInfoEdited.replacingOccurrences(of: "{templates}", with: countText).replacingOccurrences(of: "{edited}", with: strings.Support_Templates_FileEdited(Int32(editCount)))))
            }
        case .own:
            result.append(.add)
            result.append(.info(strings.Support_Templates_OwnInfo))
        }
    }
    guard let items else {
        return result
    }

    let words = supportTemplatesSearchFolded(query).split(whereSeparator: { $0.isWhitespace }).map(String.init)
    var matches: [SupportTemplatesListEntry] = []
    if words.isEmpty {
        matches = items.entries
    } else {
        for (index, entry) in items.entries.enumerated() {
            let text = items.searchTexts[index]
            if words.allSatisfy({ text.contains($0) }) {
                matches.append(entry)
            }
        }
    }

    if words.isEmpty {
        if !matches.isEmpty {
            result.append(.header(strings.Support_Templates_Header))
        }
    } else {
        result.append(.header(strings.Support_Templates_SearchResults(Int32(matches.count))))
        if matches.isEmpty {
            result.append(.empty(strings.Support_Templates_SearchEmpty))
        }
    }
    for (index, entry) in matches.enumerated() {
        result.append(.template(index: index, entry: entry))
    }
    return result
}

func supportTemplatesListController(context: AccountContext, manager: SupportTemplatesManager, source: SupportTemplatesSource) -> ViewController {
    var presentControllerImpl: ((ViewController) -> Void)?
    var pushControllerImpl: ((ViewController) -> Void)?

    let queryPromise = ValuePromise<String>("", ignoreRepeated: true)
    let isSearchActivePromise = ValuePromise<Bool>(false, ignoreRepeated: true)

    var requestLayoutImpl: ((ContainedViewLayoutTransition) -> Void)?

    let currentSource = Atomic<SupportTemplatesSource>(value: source)
    let sourcePromise = ValuePromise<SupportTemplatesSource>(source, ignoreRepeated: true)

    let arguments = SupportTemplatesListControllerArguments(openFile: {
        guard case let .file(name) = currentSource.with({ $0 }) else {
            return
        }
        let url = manager.state.files.first(where: { $0.name == name })?.url ?? ""
        pushControllerImpl?(supportTemplateFileController(context: context, manager: manager, name: name, url: url, changed: { newName in
            let updated = SupportTemplatesSource.file(newName)
            let _ = currentSource.swap(updated)
            sourcePromise.set(updated)
        }))
    }, restoreDefaults: {
        guard case let .file(name) = currentSource.with({ $0 }) else {
            return
        }
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        presentControllerImpl?(textAlertController(context: context, title: presentationData.strings.Support_Templates_RestoreTitle, text: presentationData.strings.Support_Templates_RestoreText.replacingOccurrences(of: "{name}", with: name), actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {
        }), TextAlertAction(type: .destructiveAction, title: presentationData.strings.Support_Templates_RestoreAction, action: {
            manager.restoreDefaults(file: name)
        })]))
    }, export: {
        let source = currentSource.with { $0 }
        let name: String
        switch source {
        case let .file(fileName):
            name = fileName
        case .own:
            name = "tl_my_templates.txt"
        }
        let folder = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("support-templates-export", isDirectory: true)
        let url = folder.appendingPathComponent(name)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try Data(manager.exportText(source).utf8).write(to: url, options: .atomic)
        } catch {
            return
        }
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        presentControllerImpl?(legacyICloudFilePicker(theme: presentationData.theme, mode: .export, url: url, documentTypes: ["public.plain-text"], completion: { _ in
        }))
    }, addTemplate: {
        pushControllerImpl?(supportTemplateEditController(context: context, manager: manager, target: .newOwn))
    }, openTemplate: { entry in
        switch currentSource.with({ $0 }) {
        case let .file(name):
            pushControllerImpl?(supportTemplateEditController(context: context, manager: manager, target: .file(name: name, entry: entry)))
        case .own:
            if let template = manager.ownTemplate(id: entry.id) {
                pushControllerImpl?(supportTemplateEditController(context: context, manager: manager, target: .own(template)))
            }
        }
    })

    let items: Signal<(SupportTemplatesSource, SupportTemplatesListItems?), NoError> = .single((source, nil))
    |> then(sourcePromise.get()
    |> mapToSignal { source -> Signal<(SupportTemplatesSource, SupportTemplatesListItems?), NoError> in
        return supportTemplatesListItems(manager: manager, source: source) |> map { (source, $0) }
    })

    let signal = combineLatest(queue: Queue.concurrentDefaultQueue(),
        context.sharedContext.presentationData,
        items,
        queryPromise.get(),
        isSearchActivePromise.get()
    )
    |> map { presentationData, sourceAndItems, query, isSearchActive -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let (source, items) = sourceAndItems
        let title: String
        switch source {
        case let .file(name):
            title = name
        case .own:
            title = presentationData.strings.Support_Templates_MyTemplates
        }
        let canExport: Bool
        switch source {
        case .file:
            canExport = (items?.editCount ?? 0) > 0
        case .own:
            canExport = !(items?.entries.isEmpty ?? true)
        }
        let exportButton = canExport ? ItemListNavigationButton(content: .icon(.action), style: .regular, enabled: true, action: {
            arguments.export()
        }) : nil
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(title), leftNavigationButton: nil, rightNavigationButton: exportButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
        let footerItem = SupportTemplatesSearchFooterItem(theme: presentationData.theme, strings: presentationData.strings, updateQuery: { query in
            queryPromise.set(query)
        }, updateIsActive: { isActive in
            isSearchActivePromise.set(isActive)
        }, requestLayout: { transition in
            requestLayoutImpl?(transition)
        })
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: supportTemplatesListEntries(strings: presentationData.strings, source: source, items: items, query: query, isSearchActive: isSearchActive), style: .blocks, footerItem: footerItem, animateChanges: false)
        return (controllerState, (listState, arguments))
    }
    |> deliverOnMainQueue

    let controller = ItemListController(context: context, state: signal)
    presentControllerImpl = { [weak controller] c in
        controller?.present(c, in: .window(.root))
    }
    pushControllerImpl = { [weak controller] c in
        controller?.push(c)
    }
    requestLayoutImpl = { [weak controller] transition in
        controller?.requestLayout(transition: transition)
    }
    return controller
}
