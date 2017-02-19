import Foundation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

private final class DebugAccountsControllerArguments {
    let account: Account
    let presentController: (ViewController, ViewControllerPresentationArguments) -> Void
    
    let switchAccount: (AccountRecordId) -> Void
    let loginNewAccount: () -> Void
    
    init(account: Account, presentController: @escaping (ViewController, ViewControllerPresentationArguments) -> Void, switchAccount: @escaping (AccountRecordId) -> Void, loginNewAccount: @escaping () -> Void) {
        self.account = account
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
    case record(AccountRecord, Bool)
    case loginNewAccount
    
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
            case let .record(record, _):
                return record.id.int64
            case .loginNewAccount:
                return Int64.max
        }
    }
    
    static func ==(lhs: DebugAccountsControllerEntry, rhs: DebugAccountsControllerEntry) -> Bool {
        switch lhs {
            case let .record(record, current):
                if case .record(record, current) = rhs {
                    return true
                } else {
                    return false
                }
            case .loginNewAccount:
                if case .loginNewAccount = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: DebugAccountsControllerEntry, rhs: DebugAccountsControllerEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(_ arguments: DebugAccountsControllerArguments) -> ListViewItem {
        switch self {
            case let .record(record, current):
                return ItemListCheckboxItem(title: "\(UInt64(bitPattern: record.id.int64))", checked: current, zeroSeparatorInsets: false, sectionId: self.section, action: {
                    arguments.switchAccount(record.id)
                })
            case .loginNewAccount:
                return ItemListActionItem(title: "Login to another account", kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    arguments.loginNewAccount()
                })
        }
    }
}

private func debugAccountsControllerEntries(view: AccountRecordsView) -> [DebugAccountsControllerEntry] {
    var entries: [DebugAccountsControllerEntry] = []
    
    for entry in view.records.sorted(by: {
        $0.id < $1.id
    }) {
        entries.append(.record(entry, entry.id == view.currentRecord?.id))
    }
    
    entries.append(.loginNewAccount)
    
    return entries
}

public func debugAccountsController(account: Account, accountManager: AccountManager) -> ViewController {
    var presentControllerImpl: ((ViewController, ViewControllerPresentationArguments?) -> Void)?
    
    let arguments = DebugAccountsControllerArguments(account: account, presentController: { controller, arguments in
        presentControllerImpl?(controller, arguments)
    }, switchAccount: { id in
        let _ = accountManager.modify({ modifier -> Void in
            modifier.setCurrentId(id)
        }).start()
    }, loginNewAccount: {
        let _ = accountManager.modify({ modifier -> Void in
            let id = modifier.createRecord([])
            modifier.setCurrentId(id)
        }).start()
    })
    
    let signal = accountManager.accountRecords()
        |> map { view -> (ItemListControllerState, (ItemListNodeState<DebugAccountsControllerEntry>, DebugAccountsControllerEntry.ItemGenerationArguments)) in
            let controllerState = ItemListControllerState(title: "Accounts", leftNavigationButton: nil, rightNavigationButton: nil)
            let listState = ItemListNodeState(entries: debugAccountsControllerEntries(view: view), style: .blocks)
            
            return (controllerState, (listState, arguments))
    }
    
    let controller = ItemListController(signal)
    presentControllerImpl = { [weak controller] c, a in
        controller?.present(c, in: .window, with: a)
    }
    return controller
}
