import Foundation
import Postbox
import TelegramCore
import TelegramUIPreferences
import Display
import ItemListUI
import TelegramPresentationData
import SwiftSignalKit
import AccountContext
import ItemListPeerItem
import AccountUtils

private final class AccountSelectionControllerArguments {
    let selectAccount: (AccountContext) -> Void
    
    init(selectAccount: @escaping (AccountContext) -> Void) {
        self.selectAccount = selectAccount
    }
}

private enum AccountSelectionControllerSection: Int32 {
    case accounts
}

private enum AccountSelectionControllerEntry: ItemListNodeEntry {
    case accountsHeader(String)
    case account(Int32, PresentationDateTimeFormat, PresentationPersonNameOrder, EnginePeer, EquatableAccountContext, Bool)
    
    var section: ItemListSectionId {
        switch self {
        case .accountsHeader, .account:
            return AccountSelectionControllerSection.accounts.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
        case .accountsHeader:
            return 0
        case let .account(index, _, _, _, _, _):
            return 1 + index
        }
    }
    
    static func < (lhs: Self, rhs: Self) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! AccountSelectionControllerArguments
        switch self {
        case let .accountsHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .account(_, dateTimeFormat, nameDisplayOrder, peer, context, disclosable):
            return ItemListPeerItem(presentationData: presentationData, dateTimeFormat: dateTimeFormat, nameDisplayOrder: nameDisplayOrder, context: context.context, peer: peer, nameStyle: .plain, presence: nil, text: .none, label: disclosable ? .disclosure("") : .none, editing: ItemListPeerItemEditing(editable: false, editing: false, revealed: nil), switchValue: nil, enabled: true, selectable: true, sectionId: self.section, action: {
                arguments.selectAccount(context.context)
            }, setPeerIdWithRevealedOptions: { _, _ in }, removePeer: { _ in })
        }
    }
}

private func accountSelectionControllerEntries(presentationData: PresentationData, accounts: [(AccountContext, EnginePeer)], areItemsDisclosable: Bool) -> [AccountSelectionControllerEntry] {
    var entries: [AccountSelectionControllerEntry] = []
    
    entries.append(.accountsHeader(presentationData.strings.SecretPasscode_AccountListTitle.uppercased()))
    
    for (index, value) in accounts.enumerated() {
        entries.append(.account(Int32(index), presentationData.dateTimeFormat, presentationData.nameDisplayOrder, value.1, EquatableAccountContext(context: value.0), areItemsDisclosable))
    }
    
    return entries
}

public func accountSelectionController(context: AccountContext, areItemsDisclosable: Bool, accountSelected: @escaping (AccountContext) -> Void) -> ViewController {
    let arguments = AccountSelectionControllerArguments(selectAccount: { selectedContext in
        accountSelected(selectedContext)
    })
    
    var dismissImpl: (() -> Void)?
    
    let signal = combineLatest(context.sharedContext.presentationData, activeAccountsAndPeers(context: context, includePrimary: true))
    |> deliverOnMainQueue
    |> map { presentationData, accountsAndPeers -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let leftNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Cancel), style: .regular, enabled: true, action: {
            dismissImpl?()
        })
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.SecretPasscode_AccountSelectionTitle), leftNavigationButton: leftNavigationButton, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: accountSelectionControllerEntries(presentationData: presentationData, accounts: accountsAndPeers.1.map({ ($0.0, $0.1) }), areItemsDisclosable: areItemsDisclosable), style: .blocks)
        
        return (controllerState, (listState, arguments))
    }
    
    let controller = ItemListController(context: context, state: signal)
    
    dismissImpl = { [weak controller] in
        controller?.dismiss()
    }
    
    controller.isSensitiveUI = true
    
    return controller
}
