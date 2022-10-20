import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import TelegramStringFormatting

private struct PhoneLabelArguments {
    let selectLabel: (String) -> Void
    let complete: () -> Void
    let cancel: () -> Void
}

private struct PhoneLabelState: Equatable {
    var currentLabel: String
}

private enum PhoneLabelSection: Int32 {
    case labels
}

private enum PhoneLabelEntryId: Hashable {
    case label(String)
}

private enum PhoneLabelEntry: ItemListNodeEntry {
    case label(Int, PresentationTheme, String, String, Bool)
    
    var section: ItemListSectionId {
        switch self {
        case .label:
            return PhoneLabelSection.labels.rawValue
        }
    }
    
    var stableId: PhoneLabelEntryId {
        switch self {
        case let .label(_, _, label, _, _):
            return .label(label)
        }
    }
    
    var index: Int {
        switch self {
        case let .label(index, _, _, _, _):
            return index
        }
    }
    
    static func <(lhs: PhoneLabelEntry, rhs: PhoneLabelEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! PhoneLabelArguments
        switch self {
        case let .label(_, _, value, text, selected):
            return ItemListCheckboxItem(presentationData: presentationData, title: text, style: .left, checked: selected, zeroSeparatorInsets: false, sectionId: self.section, action: {
                arguments.selectLabel(value)
            })
        }
    }
}

private func phoneLabelEntries(presentationData: PresentationData, state: PhoneLabelState) -> [PhoneLabelEntry] {
    var entries: [PhoneLabelEntry] = []
    
    let labels: [String] = [
        "_$!<Work>!$_",
        "X-iPhone",
        "_$!<Mobile>!$_",
        "_$!<Main>!$_",
        "_$!<Pager>!$_",
        "_$!<Other>!$_",
    ]
    
    for label in labels {
        entries.append(.label(entries.count, presentationData.theme, label, localizedPhoneNumberLabel(label: label, strings: presentationData.strings), state.currentLabel == label))
    }
    
    return entries
}

public func phoneLabelController(context: AccountContext, currentLabel: String, completion: @escaping (String) -> Void) -> ViewController {
    let statePromise = ValuePromise(PhoneLabelState(currentLabel: currentLabel))
    let stateValue = Atomic(value: PhoneLabelState(currentLabel: currentLabel))
    let updateState: ((PhoneLabelState) -> PhoneLabelState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var completeImpl: (() -> Void)?
    var cancelImpl: (() -> Void)?
    
    let arguments = PhoneLabelArguments(selectLabel: { label in
        updateState { state in
            var state = state
            state.currentLabel = label
            return state
        }
    }, complete: {
        completeImpl?()
    }, cancel: {
        cancelImpl?()
    })
    
    let signal = combineLatest(context.sharedContext.presentationData, statePromise.get())
        |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
            
            let leftNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Cancel), style: .regular, enabled: true, action: {
                arguments.cancel()
            })
            
            let rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Done), style: .bold, enabled: true, action: {
                arguments.complete()
            })
            
            let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.PhoneLabel_Title), leftNavigationButton: leftNavigationButton, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
            let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: phoneLabelEntries(presentationData: presentationData, state: state), style: .blocks)
            
            return (controllerState, (listState, arguments))
    }
    
    let controller = ItemListController(context: context, state: signal
    |> afterDisposed {
    })
    controller.navigationPresentation = .modal
    controller.enableInteractiveDismiss = true
    
    completeImpl = { [weak controller] in
        let currentLabel = stateValue.with({ $0 }).currentLabel
        completion(currentLabel)
        controller?.dismiss()
    }
    
    cancelImpl = { [weak controller] in
        controller?.dismiss()
    }
    
    return controller
}
