import Foundation
import UIKit
import AppBundle
import AccountContext
import TelegramPresentationData
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import ItemListUI
import SwiftSignalKit
import OverlayStatusController
import ShareController

private final class WalletReceiveScreenArguments {
    let context: AccountContext
    let copyAddress: () -> Void
    let shareAddressLink: () -> Void
    
    init(context: AccountContext, copyAddress: @escaping () -> Void, shareAddressLink: @escaping () -> Void) {
        self.context = context
        self.copyAddress = copyAddress
        self.shareAddressLink = shareAddressLink
    }
}

private enum WalletReceiveScreenSection: Int32 {
    case address
}

private enum WalletReceiveScreenEntry: ItemListNodeEntry {
    case addressHeader(PresentationTheme, String)
    case addressCode(PresentationTheme, String)
    case address(PresentationTheme, String)
    case copyAddress(PresentationTheme, String)
    case shareAddressLink(PresentationTheme, String)
    case addressInfo(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
        case .addressHeader, .addressCode, .address, .copyAddress, .shareAddressLink, .addressInfo:
            return WalletReceiveScreenSection.address.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
        case .addressHeader:
            return 0
        case .addressCode:
            return 1
        case .address:
            return 2
        case .copyAddress:
            return 3
        case .shareAddressLink:
            return 4
        case .addressInfo:
            return 5
        }
    }
    
    static func ==(lhs: WalletReceiveScreenEntry, rhs: WalletReceiveScreenEntry) -> Bool {
        switch lhs {
        case let .addressHeader(lhsTheme, lhsText):
            if case let .addressHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                return true
            } else {
                return false
            }
        case let .addressCode(lhsTheme, lhsAddress):
            if case let .addressCode(rhsTheme, rhsAddress) = rhs, lhsTheme === rhsTheme, lhsAddress == rhsAddress {
                return true
            } else {
                return false
            }
        case let .address(lhsTheme, lhsAddress):
            if case let .address(rhsTheme, rhsAddress) = rhs, lhsTheme === rhsTheme, lhsAddress == rhsAddress {
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
        }
    }
    
    static func <(lhs: WalletReceiveScreenEntry, rhs: WalletReceiveScreenEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(_ arguments: WalletReceiveScreenArguments) -> ListViewItem {
        switch self {
        case let .addressHeader(theme, text):
            return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
        case let .addressCode(theme, address):
            return WalletQrCodeItem(theme: theme, address: "ton://\(address)", sectionId: self.section, style: .blocks)
        case let .address(theme, address):
            return ItemListMultilineTextItem(theme: theme, text: address, enabledEntityTypes: [], font: .monospace, sectionId: self.section, style: .blocks)
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
        }
    }
}

private func walletReceiveScreenEntries(presentationData: PresentationData, address: String) -> [WalletReceiveScreenEntry] {
    var entries: [WalletReceiveScreenEntry] = []
    entries.append(.addressHeader(presentationData.theme, "YOUR WALLET ADDRESS"))
    
    let address = String(address[address.startIndex..<address.index(address.startIndex, offsetBy: 24)] + "\n" + address[address.index(address.startIndex, offsetBy: 24)..<address.endIndex])
    entries.append(.addressCode(presentationData.theme, address))
    entries.append(.address(presentationData.theme, address))
    entries.append(.copyAddress(presentationData.theme, "Copy Wallet Address"))
    entries.append(.shareAddressLink(presentationData.theme, "Share Wallet Address"))
    entries.append(.addressInfo(presentationData.theme, "Share this link with other Gram wallet owners to receive Grams from them."))
    return entries
}

protocol WalletReceiveScreen {
    
}

private final class WalletReceiveScreenImpl: ItemListController<WalletReceiveScreenEntry>, WalletSendScreen {
    
}

func walletReceiveScreen(context: AccountContext, tonContext: TonContext, walletInfo: WalletInfo, address: String) -> ViewController {
    var presentControllerImpl: ((ViewController, Any?) -> Void)?
    var dismissImpl: (() -> Void)?
    
    let arguments = WalletReceiveScreenArguments(context: context, copyAddress: {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        UIPasteboard.general.string = address

        presentControllerImpl?(OverlayStatusController(theme: presentationData.theme, strings: presentationData.strings, type: .genericSuccess("Address copied to clipboard.", false)), nil)
    }, shareAddressLink: {
        guard let address = address.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) else {
            return
        }
        let controller = ShareController(context: context, subject: .url("ton://\(address)"), preferredAction: .default)
        presentControllerImpl?(controller, nil)
    })
    
    let address: Signal<String, NoError> = .single(address)
    
    let signal = combineLatest(queue: .mainQueue(), context.sharedContext.presentationData, address)
    |> map { presentationData, address -> (ItemListControllerState, (ItemListNodeState<WalletReceiveScreenEntry>, WalletReceiveScreenEntry.ItemGenerationArguments)) in
        let rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Done), style: .regular, enabled: true, action: {
            dismissImpl?()
        })
    
        let controllerState = ItemListControllerState(theme: presentationData.theme, title: .text("Receive Grams"), leftNavigationButton: rightNavigationButton, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
        let listState = ItemListNodeState(entries: walletReceiveScreenEntries(presentationData: presentationData, address: address), style: .blocks, animateChanges: false)
        
        return (controllerState, (listState, arguments))
    }
    
    let controller = WalletReceiveScreenImpl(context: context, state: signal)
    controller.navigationPresentation = .modal
    presentControllerImpl = { [weak controller] c, a in
        controller?.present(c, in: .window(.root), with: a)
    }
    dismissImpl = { [weak controller] in
        let _ = controller?.dismiss()
    }
    return controller
}
