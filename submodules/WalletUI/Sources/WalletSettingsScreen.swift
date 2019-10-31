import Foundation
import UIKit
import AppBundle
import AsyncDisplayKit
import Display
import SolidRoundedButtonNode
import SwiftSignalKit
import OverlayStatusController
import WalletCore

private final class WalletSettingsControllerArguments {
    let openConfiguration: () -> Void
    let exportWallet: () -> Void
    let deleteWallet: () -> Void
    
    init(openConfiguration: @escaping () -> Void, exportWallet: @escaping () -> Void, deleteWallet: @escaping () -> Void) {
        self.openConfiguration = openConfiguration
        self.exportWallet = exportWallet
        self.deleteWallet = deleteWallet
    }
}

private enum WalletSettingsSection: Int32 {
    case configuration
    case exportWallet
    case deleteWallet
}

private enum WalletSettingsEntry: ItemListNodeEntry {
    case configuration(WalletTheme, String)
    case configurationInfo(WalletTheme, String)
    case exportWallet(WalletTheme, String)
    case deleteWallet(WalletTheme, String)
    case deleteWalletInfo(WalletTheme, String)
    
    var section: ItemListSectionId {
        switch self {
        case .configuration, .configurationInfo:
            return WalletSettingsSection.configuration.rawValue
        case .exportWallet:
            return WalletSettingsSection.exportWallet.rawValue
        case .deleteWallet, .deleteWalletInfo:
            return WalletSettingsSection.deleteWallet.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
        case .configuration:
            return 0
        case .configurationInfo:
            return 1
        case .exportWallet:
            return 2
        case .deleteWallet:
            return 3
        case .deleteWalletInfo:
            return 4
        }
    }
    
    static func <(lhs: WalletSettingsEntry, rhs: WalletSettingsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(_ arguments: Any) -> ListViewItem {
        let arguments = arguments as! WalletSettingsControllerArguments
        switch self {
        case let .configuration(theme, text):
            return ItemListActionItem(theme: theme, title: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.openConfiguration()
            })
        case let .configurationInfo(theme, text):
            return ItemListTextItem(theme: theme, text: .plain(text), sectionId: self.section)
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

private func walletSettingsControllerEntries(presentationData: WalletPresentationData, state: WalletSettingsControllerState, supportsCustomConfigurations: Bool) -> [WalletSettingsEntry] {
    var entries: [WalletSettingsEntry] = []
    
    if supportsCustomConfigurations {
        entries.append(.configuration(presentationData.theme, presentationData.strings.Wallet_Settings_Configuration))
        entries.append(.configurationInfo(presentationData.theme, presentationData.strings.Wallet_Settings_ConfigurationInfo))
    }
    entries.append(.exportWallet(presentationData.theme, presentationData.strings.Wallet_Settings_BackupWallet))
    entries.append(.deleteWallet(presentationData.theme, presentationData.strings.Wallet_Settings_DeleteWallet))
    entries.append(.deleteWalletInfo(presentationData.theme, presentationData.strings.Wallet_Settings_DeleteWalletInfo))

    return entries
}

public func walletSettingsController(context: WalletContext, walletInfo: WalletInfo) -> ViewController {
    let statePromise = ValuePromise(WalletSettingsControllerState(), ignoreRepeated: true)
    let stateValue = Atomic(value: WalletSettingsControllerState())
    let updateState: ((WalletSettingsControllerState) -> WalletSettingsControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var dismissImpl: (() -> Void)?
    var presentControllerImpl: ((ViewController, Any?) -> Void)?
    var pushControllerImpl: ((ViewController) -> Void)?
    
    var replaceAllWalletControllersImpl: ((ViewController) -> Void)?
    
    let arguments = WalletSettingsControllerArguments(openConfiguration: {
        let _ = (context.storage.localWalletConfiguration()
        |> take(1)
        |> deliverOnMainQueue).start(next: { configuration in
            pushControllerImpl?(walletConfigurationScreen(context: context, currentConfiguration: configuration))
        })
    }, exportWallet: {
        let presentationData = context.presentationData
        let controller = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: nil))
        presentControllerImpl?(controller, nil)
        let _ = (context.keychain.decrypt(walletInfo.encryptedSecret)
        |> deliverOnMainQueue).start(next: { [weak controller] decryptedSecret in
            let _ = (context.getServerSalt()
            |> deliverOnMainQueue).start(next: { serverSalt in
                let _ = (walletRestoreWords(tonInstance: context.tonInstance, publicKey: walletInfo.publicKey, decryptedSecret:  decryptedSecret, localPassword: serverSalt)
                |> deliverOnMainQueue).start(next: { [weak controller] wordList in
                    controller?.dismiss()
                    pushControllerImpl?(WalletWordDisplayScreen(context: context, walletInfo: walletInfo, wordList: wordList, mode: .export, walletCreatedPreloadState: nil))
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
        let presentationData = context.presentationData
        let actionSheet = ActionSheetController(theme: presentationData.theme.actionSheet)
        actionSheet.setItemGroups([ActionSheetItemGroup(items: [
            ActionSheetTextItem(title: presentationData.strings.Wallet_Settings_DeleteWalletInfo),
            ActionSheetButtonItem(title: presentationData.strings.Wallet_Settings_DeleteWallet, color: .destructive, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
                let controller = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: nil))
                presentControllerImpl?(controller, nil)
                let _ = (deleteAllLocalWalletsData(storage: context.storage, tonInstance: context.tonInstance)
                |> deliverOnMainQueue).start(error: { [weak controller] _ in
                    controller?.dismiss()
                }, completed: { [weak controller] in
                    controller?.dismiss()
                    replaceAllWalletControllersImpl?(WalletSplashScreen(context: context, mode: .intro, walletCreatedPreloadState: nil))
                })
            })
        ]), ActionSheetItemGroup(items: [
            ActionSheetButtonItem(title: presentationData.strings.Wallet_Navigation_Cancel, color: .accent, action: { [weak actionSheet] in
                actionSheet?.dismissAnimated()
            })
        ])])
        presentControllerImpl?(actionSheet, nil)
    })
    
    let signal = combineLatest(queue: .mainQueue(), .single(context.presentationData), statePromise.get())
    |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(theme: presentationData.theme, title: .text(presentationData.strings.Wallet_Settings_Title), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Wallet_Navigation_Back), animateChanges: false)
        let listState = ItemListNodeState(entries: walletSettingsControllerEntries(presentationData: presentationData, state: state, supportsCustomConfigurations: context.supportsCustomConfigurations), style: .blocks, animateChanges: false)
        
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
    }
    
    let controller = ItemListController(theme: context.presentationData.theme, strings: context.presentationData.strings, updatedPresentationData: .single((context.presentationData.theme, context.presentationData.strings)), state: signal, tabBarItem: nil)
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
