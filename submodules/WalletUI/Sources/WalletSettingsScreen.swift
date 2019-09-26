import Foundation
import UIKit
import AppBundle
import AccountContext
import TelegramPresentationData
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SolidRoundedButtonNode
import AnimationUI
import SwiftSignalKit
import OverlayStatusController
import ItemListUI

private final class WalletSettingsControllerArguments {
    let exportWallet: () -> Void
    let deleteWallet: () -> Void
    
    init(exportWallet: @escaping () -> Void, deleteWallet: @escaping () -> Void) {
        self.exportWallet = exportWallet
        self.deleteWallet = deleteWallet
    }
}

private enum WalletSettingsSection: Int32 {
    case exportWallet
    case deleteWallet
}

private enum WalletSettingsEntry: ItemListNodeEntry {
    case exportWallet(PresentationTheme, String)
    case deleteWallet(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
        case .exportWallet:
            return WalletSettingsSection.exportWallet.rawValue
        case .deleteWallet:
            return WalletSettingsSection.deleteWallet.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
        case .exportWallet:
            return 0
        case .deleteWallet:
            return 1
        }
    }
    
    static func <(lhs: WalletSettingsEntry, rhs: WalletSettingsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(_ arguments: WalletSettingsControllerArguments) -> ListViewItem {
        switch self {
        case let .exportWallet(theme, text):
            return ItemListActionItem(theme: theme, title: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.exportWallet()
            })
        case let .deleteWallet(theme, text):
            return ItemListActionItem(theme: theme, title: text, kind: .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.deleteWallet()
            })
        }
    }
}

private struct WalletSettingsControllerState: Equatable {
}

private func walletSettingsControllerEntries(presentationData: PresentationData, state: WalletSettingsControllerState) -> [WalletSettingsEntry] {
    var entries: [WalletSettingsEntry] = []
    
    entries.append(.exportWallet(presentationData.theme, "Export Wallet"))
    entries.append(.deleteWallet(presentationData.theme, "Delete Wallet"))
    
    return entries
}

public func walletSettingsController(context: AccountContext, tonContext: TonContext, walletInfo: WalletInfo) -> ViewController {
    let statePromise = ValuePromise(WalletSettingsControllerState(), ignoreRepeated: true)
    let stateValue = Atomic(value: WalletSettingsControllerState())
    let updateState: ((WalletSettingsControllerState) -> WalletSettingsControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var dismissImpl: (() -> Void)?
    var presentControllerImpl: ((ViewController, Any?) -> Void)?
    var pushControllerImpl: ((ViewController) -> Void)?
    
    var replaceAllWalletControllersImpl: ((ViewController) -> Void)?
    
    let arguments = WalletSettingsControllerArguments(exportWallet: {
        let _ = (walletRestoreWords(network: context.account.network, walletInfo: walletInfo, tonInstance: tonContext.instance, keychain: tonContext.keychain)
        |> deliverOnMainQueue).start(next: { wordList in
            pushControllerImpl?(WalletWordDisplayScreen(context: context, tonContext: tonContext, walletInfo: walletInfo, wordList: wordList))
        })
    }, deleteWallet: {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let actionSheet = ActionSheetController(presentationTheme: presentationData.theme)
        actionSheet.setItemGroups([ActionSheetItemGroup(items: [
            ActionSheetButtonItem(title: "Delete Wallet", color: .destructive, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
                let _ = (deleteLocalWalletData(postbox: context.account.postbox, network: context.account.network, tonInstance: tonContext.instance, keychain: tonContext.keychain, walletInfo: walletInfo)
                |> deliverOnMainQueue).start(error: { _ in
                }, completed: {
                    replaceAllWalletControllersImpl?(WalletSplashScreen(context: context, tonContext: tonContext, mode: .intro))
                })
            })
        ]), ActionSheetItemGroup(items: [
            ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
            })
        ])])
        presentControllerImpl?(actionSheet, nil)
    })
    
    let signal = combineLatest(queue: .mainQueue(), context.sharedContext.presentationData, statePromise.get())
    |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState<WalletSettingsEntry>, WalletSettingsEntry.ItemGenerationArguments)) in
        let controllerState = ItemListControllerState(theme: presentationData.theme, title: .text("Wallet Settings"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
        let listState = ItemListNodeState(entries: walletSettingsControllerEntries(presentationData: presentationData, state: state), style: .blocks, animateChanges: false)
        
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
    }
    
    let controller = ItemListController(context: context, state: signal)
    controller.navigationPresentation = .modal
    controller.enableInteractiveDismiss = true
    dismissImpl = { [weak controller] in
        controller?.view.endEditing(true)
        controller?.dismiss()
    }
    presentControllerImpl = { [weak controller] c, a in
        controller?.present(c, in: .window(.root), with: a)
    }
    pushControllerImpl = { [weak controller] c in
        controller?.push(c)
    }
    replaceAllWalletControllersImpl = { [weak controller] c in
        if let navigationController = controller?.navigationController as? NavigationController {
            var controllers = navigationController.viewControllers
            controllers = controllers.filter { listController in
                if listController === controller {
                    return false
                }
                if listController is WalletInfoScreen {
                    return false
                }
                return true
            }
            controllers.append(c)
            navigationController.setViewControllers(controllers, animated: true)
        }
    }
    
    return controller
}
