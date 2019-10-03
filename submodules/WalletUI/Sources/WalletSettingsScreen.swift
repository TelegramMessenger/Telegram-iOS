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
    case deleteWalletInfo(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
        case .exportWallet:
            return WalletSettingsSection.exportWallet.rawValue
        case .deleteWallet, .deleteWalletInfo:
            return WalletSettingsSection.deleteWallet.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
        case .exportWallet:
            return 0
        case .deleteWallet:
            return 1
        case .deleteWalletInfo:
            return 2
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
        case let .deleteWalletInfo(theme, text):
            return ItemListTextItem(theme: theme, text: .plain(text), sectionId: self.section)
        }
    }
}

private struct WalletSettingsControllerState: Equatable {
}

private func walletSettingsControllerEntries(presentationData: PresentationData, state: WalletSettingsControllerState) -> [WalletSettingsEntry] {
    var entries: [WalletSettingsEntry] = []
    
    entries.append(.exportWallet(presentationData.theme, "Export Wallet"))
    entries.append(.deleteWallet(presentationData.theme, presentationData.strings.Wallet_Settings_DeleteWallet))
    entries.append(.deleteWalletInfo(presentationData.theme, presentationData.strings.Wallet_Settings_DeleteWalletInfo))

    
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
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let controller = OverlayStatusController(theme: presentationData.theme, strings: presentationData.strings, type: .loading(cancelled: nil))
        presentControllerImpl?(controller, nil)
        let _ = (tonContext.keychain.decrypt(walletInfo.encryptedSecret)
        |> deliverOnMainQueue).start(next: { [weak controller] decryptedSecret in
            let _ = (getServerWalletSalt(network: context.account.network)
            |> deliverOnMainQueue).start(next: { serverSalt in
                let _ = (walletRestoreWords(tonInstance: tonContext.instance, publicKey: walletInfo.publicKey, decryptedSecret:  decryptedSecret, localPassword: serverSalt)
                |> deliverOnMainQueue).start(next: { [weak controller] wordList in
                    controller?.dismiss()
                    pushControllerImpl?(WalletWordDisplayScreen(context: context, tonContext: tonContext, walletInfo: walletInfo, wordList: wordList, mode: .export, walletCreatedPreloadState: nil))
                    }, error: { [weak controller] _ in
                        controller?.dismiss()
                })
            }, error: { [weak controller] _ in
                controller?.dismiss()
            })
        }, error: { [weak controller] _ in
            controller?.dismiss()
        })
    }, deleteWallet: {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let actionSheet = ActionSheetController(presentationTheme: presentationData.theme)
        actionSheet.setItemGroups([ActionSheetItemGroup(items: [
            ActionSheetTextItem(title: presentationData.strings.Wallet_Settings_DeleteWalletInfo),
            ActionSheetButtonItem(title: presentationData.strings.Wallet_Settings_DeleteWallet, color: .destructive, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
                let controller = OverlayStatusController(theme: presentationData.theme, strings: presentationData.strings, type: .loading(cancelled: nil))
                presentControllerImpl?(controller, nil)
                let _ = (deleteAllLocalWalletsData(postbox: context.account.postbox, network: context.account.network, tonInstance: tonContext.instance)
                |> deliverOnMainQueue).start(error: { [weak controller] _ in
                    controller?.dismiss()
                }, completed: { [weak controller] in
                    controller?.dismiss()
                    replaceAllWalletControllersImpl?(WalletSplashScreen(context: context, tonContext: tonContext, mode: .intro, walletCreatedPreloadState: nil))
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
        let controllerState = ItemListControllerState(theme: presentationData.theme, title: .text(presentationData.strings.Wallet_Settings_Title), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
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
