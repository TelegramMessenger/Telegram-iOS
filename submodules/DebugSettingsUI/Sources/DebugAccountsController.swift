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

private final class DebugAccountsControllerArguments {
    let context: AccountContext
    let presentController: (ViewController, ViewControllerPresentationArguments) -> Void
    
    let switchAccount: (AccountRecordId) -> Void
    let loginNewAccount: () -> Void
    
    init(context: AccountContext, presentController: @escaping (ViewController, ViewControllerPresentationArguments) -> Void, switchAccount: @escaping (AccountRecordId) -> Void, loginNewAccount: @escaping () -> Void) {
        self.context = context
        self.presentController = presentController
        self.switchAccount = switchAccount
        self.loginNewAccount = loginNewAccount
    }
}

private enum DebugAccountsControllerSection: Int32 {
    case accounts
    case actions
}

private enum DebugAccountsControllerEntry: ItemListNodeEntry {
    case record(PresentationTheme, AccountRecord<TelegramAccountManagerTypes.Attribute>, Bool)
    case loginNewAccount(PresentationTheme)
    
    var section: ItemListSectionId {
        switch self {
            case .record:
                return DebugAccountsControllerSection.accounts.rawValue
            case .loginNewAccount:
                return DebugAccountsControllerSection.actions.rawValue
        }
    }
    
    var stableId: Int64 {
        switch self {
            case let .record(_, record, _):
                return record.id.int64
            case .loginNewAccount:
                return Int64.max
        }
    }
    
    static func ==(lhs: DebugAccountsControllerEntry, rhs: DebugAccountsControllerEntry) -> Bool {
        switch lhs {
            case let .record(lhsTheme, lhsRecord, lhsCurrent):
                if case let .record(rhsTheme, rhsRecord, rhsCurrent) = rhs, lhsTheme === rhsTheme, lhsRecord == rhsRecord, lhsCurrent == rhsCurrent {
                    return true
                } else {
                    return false
                }
            case let .loginNewAccount(lhsTheme):
                if case let .loginNewAccount(rhsTheme) = rhs, lhsTheme === rhsTheme {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: DebugAccountsControllerEntry, rhs: DebugAccountsControllerEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! DebugAccountsControllerArguments
        switch self {
            case let .record(_, record, current):
                return ItemListCheckboxItem(presentationData: presentationData, title: "\(UInt64(bitPattern: record.id.int64))", style: .left, checked: current, zeroSeparatorInsets: false, sectionId: self.section, action: {
                    arguments.switchAccount(record.id)
                })
            case .loginNewAccount:
                return ItemListActionItem(presentationData: presentationData, title: "Login to another account", kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    arguments.loginNewAccount()
                })
        }
    }
}

private func debugAccountsControllerEntries(view: AccountRecordsView<TelegramAccountManagerTypes>, presentationData: PresentationData) -> [DebugAccountsControllerEntry] {
    var entries: [DebugAccountsControllerEntry] = []
    
    for entry in view.records.sorted(by: {
        $0.id < $1.id
    }) {
        entries.append(.record(presentationData.theme, entry, entry.id == view.currentRecord?.id))
    }
    
    entries.append(.loginNewAccount(presentationData.theme))
    
    return entries
}

public func debugAccountsController(context: AccountContext, accountManager: AccountManager<TelegramAccountManagerTypes>) -> ViewController {
    var presentControllerImpl: ((ViewController, ViewControllerPresentationArguments?) -> Void)?
    
    let arguments = DebugAccountsControllerArguments(context: context, presentController: { controller, arguments in
        presentControllerImpl?(controller, arguments)
    }, switchAccount: { id in
        let _ = accountManager.transaction({ transaction -> Void in
            transaction.setCurrentId(id)
        }).start()
    }, loginNewAccount: {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let controller = ActionSheetController(presentationData: presentationData)
        let dismissAction: () -> Void = { [weak controller] in
            controller?.dismissAnimated()
        }
        controller.setItemGroups([
            ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: "Production", color: .accent, action: {
                    dismissAction()
                    
                    if case .internal = context.sharedContext.applicationBindings.appBuildType {
                        context.sharedContext.beginNewAuth(testingEnvironment: false)
                    }
                }),
                ActionSheetButtonItem(title: "Test", color: .accent, action: {
                    dismissAction()
                    context.sharedContext.beginNewAuth(testingEnvironment: true)
                })
            ]),
        ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { dismissAction() })])
        ])
        presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
    })
    
    let signal = combineLatest(context.sharedContext.presentationData, accountManager.accountRecords())
        |> map { presentationData, view -> (ItemListControllerState, (ItemListNodeState, Any)) in
            let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("Accounts"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
            let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: debugAccountsControllerEntries(view: view, presentationData: presentationData), style: .blocks)
            
            return (controllerState, (listState, arguments))
    }
    
    let controller = ItemListController(context: context, state: signal)
    presentControllerImpl = { [weak controller] c, a in
        controller?.present(c, in: .window(.root), with: a)
    }
    return controller
}
