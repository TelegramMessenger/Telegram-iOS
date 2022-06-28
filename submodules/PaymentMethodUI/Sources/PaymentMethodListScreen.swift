import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import AccountContext
import PresentationDataUtils
import TelegramStringFormatting
import UndoUI
import InviteLinksUI
import Stripe

private final class PaymentMethodListScreenArguments {
    let context: AccountContext
    let addMethod: () -> Void
    let deleteMethod: (UInt64) -> Void
    let selectMethod: (UInt64) -> Void
    
    init(context: AccountContext, addMethod: @escaping () -> Void, deleteMethod: @escaping (UInt64) -> Void, selectMethod: @escaping (UInt64) -> Void) {
        self.context = context
        self.addMethod = addMethod
        self.deleteMethod = deleteMethod
        self.selectMethod = selectMethod
    }
}

private enum PaymentMethodListSection: Int32 {
    case header
    case methods
}

private enum InviteLinksListEntry: ItemListNodeEntry {
    case header(String)
    case methodsHeader(String)
    case addMethod(String)
    case item(index: Int, info: PaymentCardEntryScreen.EnteredCardInfo, isSelected: Bool)
    
    var section: ItemListSectionId {
        switch self {
        case .header:
            return PaymentMethodListSection.header.rawValue
        case .methodsHeader, .addMethod, .item:
            return PaymentMethodListSection.methods.rawValue
        }
    }
    
    var sortId: Int {
        switch self {
        case .header:
            return 0
        case .methodsHeader:
            return 1
        case .addMethod:
            return 2
        case let .item(index, _, _):
            return 10 + index
        }
    }
    
    var stableId: UInt64 {
        switch self {
        case .header:
            return 0
        case .methodsHeader:
            return 1
        case .addMethod:
            return 2
        case let .item(_, item, _):
            return item.id
        }
    }
    
    static func ==(lhs: InviteLinksListEntry, rhs: InviteLinksListEntry) -> Bool {
        switch lhs {
        case let .header(lhsText):
            if case let .header(rhsText) = rhs, lhsText == rhsText {
                return true
            } else {
                return false
            }
        case let .methodsHeader(lhsText):
            if case let .methodsHeader(rhsText) = rhs, lhsText == rhsText {
                return true
            } else {
                return false
            }
        case let .addMethod(lhsText):
            if case let .addMethod(rhsText) = rhs, lhsText == rhsText {
                return true
            } else {
                return false
            }
        case let .item(lhsIndex, lhsItem, lhsIsSelected):
            if case let .item(rhsIndex, rhsItem, rhsIsSelected) = rhs, lhsIndex == rhsIndex, lhsItem == rhsItem, lhsIsSelected == rhsIsSelected {
                return true
            } else {
                return false
            }
        }
    }
    
    static func <(lhs: InviteLinksListEntry, rhs: InviteLinksListEntry) -> Bool {
        return lhs.sortId < rhs.sortId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! PaymentMethodListScreenArguments
        switch self {
        case let .header(text):
            return InviteLinkHeaderItem(context: arguments.context, theme: presentationData.theme, text: text, animationName: "Invite", sectionId: self.section)
        case let .methodsHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .addMethod(text):
            let icon = PresentationResourcesItemList.plusIconImage(presentationData.theme)
            return ItemListCheckboxItem(presentationData: presentationData, icon: icon, iconSize: nil, iconPlacement: .check, title: text, style: .left, textColor: .accent, checked: false, zeroSeparatorInsets: false, sectionId: self.section, action: {
                arguments.addMethod()
            })
        case let .item(_, info, isSelected):
            return ItemListCheckboxItem(
                presentationData: presentationData,
                icon: STPPaymentCardTextField.brandImage(for: .masterCard), iconSize: nil,
                iconPlacement: .default,
                title: "•••• " + info.number.suffix(4),
                subtitle: "Expires \(info.expiration)",
                style: .right,
                color: .accent,
                textColor: .primary,
                checked: isSelected,
                zeroSeparatorInsets: false,
                sectionId: self.section,
                action: {
                    arguments.selectMethod(info.id)
                },
                deleteAction: {
                    arguments.deleteMethod(info.id)
                }
            )
        }
    }
}

private func paymentMethodListScreenEntries(presentationData: PresentationData, state: PaymentMethodListScreenState) -> [InviteLinksListEntry] {
    var entries: [InviteLinksListEntry] = []

    entries.append(.header("Add your debit or credit card to buy goods and\nservices on Telegram."))
    
    entries.append(.methodsHeader("PAYMENT METHOD"))
    entries.append(.addMethod("Add Payment Method"))
    
    for item in state.items {
        entries.append(.item(index: entries.count, info: item, isSelected: state.selectedId == item.id))
    }
    
    return entries
}

private struct PaymentMethodListScreenState: Equatable {
    var items: [PaymentCardEntryScreen.EnteredCardInfo]
    var selectedId: UInt64?
}

public func paymentMethodListScreen(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, items: [PaymentCardEntryScreen.EnteredCardInfo]) -> ViewController {
    var pushControllerImpl: ((ViewController) -> Void)?
    var presentControllerImpl: ((ViewController, ViewControllerPresentationArguments?) -> Void)?
    var presentInGlobalOverlayImpl: ((ViewController) -> Void)?
    
    let _ = presentControllerImpl
    let _ = presentInGlobalOverlayImpl
    
    var dismissTooltipsImpl: (() -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    let initialState = PaymentMethodListScreenState(items: items, selectedId: items.first?.id)
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((PaymentMethodListScreenState) -> PaymentMethodListScreenState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    let _ = updateState
        
    var getControllerImpl: (() -> ViewController?)?
    let _ = getControllerImpl
    
    let arguments = PaymentMethodListScreenArguments(
        context: context,
        addMethod: {
            pushControllerImpl?(PaymentCardEntryScreen(context: context, completion: { result in
                updateState { state in
                    var state = state
                    
                    state.items.insert(result, at: 0)
                    state.selectedId = result.id
                    
                    return state
                }
            }))
        },
        deleteMethod: { id in
            updateState { state in
                var state = state
                
                state.items.removeAll(where: { $0.id == id })
                if state.selectedId == id {
                    state.selectedId = state.items.first?.id
                }
                
                return state
            }
        },
        selectMethod: { id in
            updateState { state in
                var state = state
                
                state.selectedId = id
                
                return state
            }
        }
    )
    
    let presentationData = updatedPresentationData?.signal ?? context.sharedContext.presentationData
    let signal = combineLatest(queue: .mainQueue(),
        presentationData,
        statePromise.get()
    )
    |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("Payment Method"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: true)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: paymentMethodListScreenEntries(presentationData: presentationData, state: state), style: .blocks, emptyStateItem: nil, crossfadeState: false, animateChanges: false)
        
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
        actionsDisposable.dispose()
    }
    
    let controller = ItemListController(context: context, state: signal)
    controller.willDisappear = { _ in
        dismissTooltipsImpl?()
    }
    controller.didDisappear = { [weak controller] _ in
        controller?.clearItemNodesHighlight(animated: true)
    }
    controller.visibleBottomContentOffsetChanged = { offset in
        if case let .known(value) = offset, value < 40.0 {
        }
    }
    pushControllerImpl = { [weak controller] c in
        if let controller = controller {
            (controller.navigationController as? NavigationController)?.pushViewController(c, animated: true)
        }
    }
    presentControllerImpl = { [weak controller] c, p in
        if let controller = controller {
            controller.present(c, in: .window(.root), with: p)
        }
    }
    presentInGlobalOverlayImpl = { [weak controller] c in
        if let controller = controller {
            controller.presentInGlobalOverlay(c)
        }
    }
    getControllerImpl = { [weak controller] in
        return controller
    }
    dismissTooltipsImpl = { [weak controller] in
        controller?.window?.forEachController({ controller in
            if let controller = controller as? UndoOverlayController {
                controller.dismissWithCommitAction()
            }
        })
        controller?.forEachController({ controller in
            if let controller = controller as? UndoOverlayController {
                controller.dismissWithCommitAction()
            }
            return true
        })
    }
    return controller
}
