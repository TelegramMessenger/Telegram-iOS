import Foundation
import UIKit
import AppBundle
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SwiftSignalKit
import OverlayStatusController
import ShareController

private final class WalletReceiveScreenArguments {
    let context: WalletContext
    let copyAddress: () -> Void
    let shareAddressLink: () -> Void
    let openQrCode: () -> Void
    let displayQrCodeContextMenu: () -> Void
    let openCreateInvoice: () -> Void
    
    init(context: WalletContext, copyAddress: @escaping () -> Void, shareAddressLink: @escaping () -> Void, openQrCode: @escaping () -> Void, displayQrCodeContextMenu: @escaping () -> Void, openCreateInvoice: @escaping () -> Void) {
        self.context = context
        self.copyAddress = copyAddress
        self.shareAddressLink = shareAddressLink
        self.openQrCode = openQrCode
        self.displayQrCodeContextMenu = displayQrCodeContextMenu
        self.openCreateInvoice = openCreateInvoice
    }
}

private enum WalletReceiveScreenSection: Int32 {
    case address
    case invoice
}

private enum WalletReceiveScreenEntry: ItemListNodeEntry {
    case addressCode(WalletTheme, String)
    case addressHeader(WalletTheme, String)
    case address(WalletTheme, String, Bool)
    case copyAddress(WalletTheme, String)
    case shareAddressLink(WalletTheme, String)
    case addressInfo(WalletTheme, String)
    case invoice(WalletTheme, String)
    case invoiceInfo(WalletTheme, String)

    var section: ItemListSectionId {
        switch self {
        case .addressCode, .addressHeader, .address, .copyAddress, .shareAddressLink, .addressInfo:
            return WalletReceiveScreenSection.address.rawValue
        case .invoice, .invoiceInfo:
            return WalletReceiveScreenSection.invoice.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
        case .addressCode:
            return 0
        case .addressHeader:
            return 1
        case .address:
            return 2
        case .copyAddress:
            return 3
        case .shareAddressLink:
            return 4
        case .addressInfo:
            return 5
        case .invoice:
            return 6
        case .invoiceInfo:
            return 7
        }
    }
    
    static func ==(lhs: WalletReceiveScreenEntry, rhs: WalletReceiveScreenEntry) -> Bool {
        switch lhs {
        case let .addressCode(lhsTheme, lhsAddress):
            if case let .addressCode(rhsTheme, rhsAddress) = rhs, lhsTheme === rhsTheme, lhsAddress == rhsAddress {
                return true
            } else {
                return false
            }
        case let .addressHeader(lhsTheme, lhsText):
            if case let .addressHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                return true
            } else {
                return false
            }
        case let .address(lhsTheme, lhsAddress, lhsMonospace):
            if case let .address(rhsTheme, rhsAddress, rhsMonospace) = rhs, lhsTheme === rhsTheme, lhsAddress == rhsAddress, lhsMonospace == rhsMonospace {
                return true
            } else {
                return false
            }
        case let .copyAddress(lhsTheme, lhsText):
            if case let .copyAddress(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                return true
            } else {
                return false
            }
        case let .shareAddressLink(lhsTheme, lhsText):
            if case let .shareAddressLink(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                return true
            } else {
                return false
            }
        case let .addressInfo(lhsTheme, lhsText):
            if case let .addressInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                return true
            } else {
                return false
            }
        case let .invoice(lhsTheme, lhsText):
            if case let .invoice(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                return true
            } else {
                return false
            }
        case let .invoiceInfo(lhsTheme, lhsText):
            if case let .invoiceInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                return true
            } else {
                return false
            }
        }
    }
    
    static func <(lhs: WalletReceiveScreenEntry, rhs: WalletReceiveScreenEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(_ arguments: Any) -> ListViewItem {
        let arguments = arguments as! WalletReceiveScreenArguments
        switch self {
        case let .addressCode(theme, text):
            return WalletQrCodeItem(theme: theme, address: text, sectionId: self.section, style: .blocks, action: {
                arguments.openQrCode()
            }, longTapAction: {
                arguments.displayQrCodeContextMenu()
            })
        case let .addressHeader(theme, text):
            return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
        case let .address(theme, text, monospace):
            return ItemListMultilineTextItem(theme: theme, text: text, enabledEntityTypes: [], font: monospace ? .monospace : .default, sectionId: self.section, style: .blocks)
        case let .copyAddress(theme, text):
            return ItemListActionItem(theme: theme, title: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.copyAddress()
            })
        case let .shareAddressLink(theme, text):
            return ItemListActionItem(theme: theme, title: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.shareAddressLink()
            })
        case let .addressInfo(theme, text):
            return ItemListTextItem(theme: theme, text: .markdown(text), sectionId: self.section)
        case let .invoice(theme, text):
            return ItemListActionItem(theme: theme, title: text, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.openCreateInvoice()
            })
        case let .invoiceInfo(theme, text):
            return ItemListTextItem(theme: theme, text: .markdown(text), sectionId: self.section)
        }
    }
}

private func walletReceiveScreenEntries(presentationData: WalletPresentationData, address: String) -> [WalletReceiveScreenEntry] {
    var entries: [WalletReceiveScreenEntry] = []
    entries.append(.addressCode(presentationData.theme, walletInvoiceUrl(address: address)))
    entries.append(.addressHeader(presentationData.theme, presentationData.strings.Wallet_Receive_AddressHeader))
    
    entries.append(.address(presentationData.theme, formatAddress(address), true))
    entries.append(.copyAddress(presentationData.theme, presentationData.strings.Wallet_Receive_CopyAddress))
    entries.append(.shareAddressLink(presentationData.theme, presentationData.strings.Wallet_Receive_ShareAddress))
    entries.append(.addressInfo(presentationData.theme, presentationData.strings.Wallet_Receive_ShareUrlInfo))
    
    entries.append(.invoice(presentationData.theme, presentationData.strings.Wallet_Receive_CreateInvoice))
    entries.append(.invoiceInfo(presentationData.theme, presentationData.strings.Wallet_Receive_CreateInvoiceInfo))
    
    return entries
}

protocol WalletReceiveScreen {
    
}

private final class WalletReceiveScreenImpl: ItemListController, WalletReceiveScreen {
    
}

func walletReceiveScreen(context: WalletContext, address: String) -> ViewController {
    var presentControllerImpl: ((ViewController, Any?) -> Void)?
    var pushImpl: ((ViewController) -> Void)?
    var dismissImpl: (() -> Void)?
    var displayQrCodeContextMenuImpl: (() -> Void)?
    
    weak var currentStatusController: ViewController?
    let arguments = WalletReceiveScreenArguments(context: context, copyAddress: {
        let presentationData = context.presentationData
    
        UIPasteboard.general.string = address
        
        if currentStatusController == nil {
            let statusController = OverlayStatusController(theme: presentationData.theme, type: .genericSuccess(presentationData.strings.Wallet_Receive_AddressCopied, false))
            presentControllerImpl?(statusController, nil)
            currentStatusController = statusController
        }
    }, shareAddressLink: {
        context.shareUrl(walletInvoiceUrl(address: address))
    }, openQrCode: {
        let url = walletInvoiceUrl(address: address)
        pushImpl?(WalletQrViewScreen(context: context, invoice: url))
    }, displayQrCodeContextMenu: {
        displayQrCodeContextMenuImpl?()
    }, openCreateInvoice: {
        pushImpl?(walletCreateInvoiceScreen(context: context, address: address))
    })
    
    let signal = Signal<WalletPresentationData, NoError>.single(context.presentationData)
    |> deliverOnMainQueue
    |> map { presentationData -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Wallet_Navigation_Done), style: .bold, enabled: true, action: {
            dismissImpl?()
        })
    
        let controllerState = ItemListControllerState(theme: presentationData.theme, title: .text(presentationData.strings.Wallet_Receive_Title), leftNavigationButton: ItemListNavigationButton(content: .none, style: .regular, enabled: false, action: {}), rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Wallet_Navigation_Back), animateChanges: false)
        let listState = ItemListNodeState(entries: walletReceiveScreenEntries(presentationData: presentationData, address: address), style: .blocks, animateChanges: false)
        
        return (controllerState, (listState, arguments))
    }
    
    let controller = WalletReceiveScreenImpl(theme: context.presentationData.theme, strings: context.presentationData.strings, updatedPresentationData: .single((context.presentationData.theme, context.presentationData.strings)), state: signal, tabBarItem: nil)
    controller.navigationPresentation = .modal
    controller.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
    presentControllerImpl = { [weak controller] c, a in
        controller?.present(c, in: .window(.root), with: a)
    }
    pushImpl = { [weak controller] c in
        controller?.push(c)
    }
    dismissImpl = { [weak controller] in
        controller?.view.endEditing(true)
        let _ = controller?.dismiss()
    }
    displayQrCodeContextMenuImpl = { [weak controller] in
        let url = walletInvoiceUrl(address: address)
        shareInvoiceQrCode(context: context, invoice: url)
    }
    return controller
}
