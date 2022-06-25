import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import LegacyComponents
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import AlertUI
import PresentationDataUtils
import UrlHandling
import InviteLinksUI

private struct DeleteAccountDataArguments {
    let context: AccountContext
    let openLink: (String) -> Void
}

private enum DeleteAccountDataSection: Int32 {
    case main
}

private enum DeleteAccountDataEntry: ItemListNodeEntry, Equatable {
    case header(PresentationTheme, String, String, String)
    
    case peers(PresentationTheme, [Peer])
    case info(PresentationTheme, String)

    var section: ItemListSectionId {
        switch self {
            case .header, .peers, .info:
                return DeleteAccountDataSection.main.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
            case .header:
                return 0
            case .peers:
                return 1
            case .info:
                return 3
        }
    }

    static func == (lhs: DeleteAccountDataEntry, rhs: DeleteAccountDataEntry) -> Bool {
        switch lhs {
            case let .header(lhsTheme, lhsAnimation, lhsTitle, lhsText):
                if case let .header(rhsTheme, rhsAnimation, rhsTitle, rhsText) = rhs, lhsTheme === rhsTheme, lhsAnimation == rhsAnimation, lhsTitle == rhsTitle, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .peers(lhsTheme, lhsPeers):
                if case let .peers(rhsTheme, rhsPeers) = rhs, lhsTheme === rhsTheme, arePeerArraysEqual(lhsPeers, rhsPeers) {
                    return true
                } else {
                    return false
                }
            case let .info(lhsTheme, lhsText):
                if case let .info(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: DeleteAccountDataEntry, rhs: DeleteAccountDataEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! DeleteAccountDataArguments
        switch self {
            case let .header(theme, animation, title, text):
                return InviteLinkHeaderItem(context: arguments.context, theme: theme, title: title, text: text, animationName: animation, sectionId: self.section, linkAction: nil)
            case let .peers(_, peers):
                return ItemListTextItem(presentationData: presentationData, text: .plain(peers.first?.debugDisplayTitle ?? ""), sectionId: self.section)
            case let .info(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .markdown(text), sectionId: self.section)
        }
    }
}

private func deleteAccountDataEntries(presentationData: PresentationData, mode: DeleteAccountDataMode, peers: [Peer]) -> [DeleteAccountDataEntry] {
    var entries: [DeleteAccountDataEntry] = []
    
    let headerTitle: String
    let headerText: String
    let headerAnimation: String
    
    switch mode {
    case .peers:
        headerAnimation = ""
        headerTitle = presentationData.strings.DeleteAccount_CloudStorageTitle
        headerText = presentationData.strings.DeleteAccount_CloudStorageText
    case .groups:
        headerAnimation = ""
        headerTitle = presentationData.strings.DeleteAccount_GroupsAndChannelsTitle
        headerText = presentationData.strings.DeleteAccount_GroupsAndChannelsText
    case .messages:
        headerAnimation = ""
        headerTitle = presentationData.strings.DeleteAccount_MessageHistoryTitle
        headerText = presentationData.strings.DeleteAccount_MessageHistoryText
    }
    
    entries.append(.header(presentationData.theme, headerAnimation, headerTitle, headerText))
    entries.append(.peers(presentationData.theme, peers))
    
    if case .groups = mode {
        entries.append(.info(presentationData.theme, presentationData.strings.DeleteAccount_GroupsAndChannelsInfo))
    }
    
    return entries
}

enum DeleteAccountDataMode {
    case peers
    case groups
    case messages
}

func deleteAccountDataController(context: AccountContext, mode: DeleteAccountDataMode) -> ViewController {
    var replaceTopControllerImpl: ((ViewController) -> Void)?
    var dismissImpl: (() -> Void)?

    let arguments = DeleteAccountDataArguments(context: context, openLink: { _ in
      
    })
    
    let peers: Signal<[Peer], NoError> = .single([])

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        peers
    )
    |> map { presentationData, peers -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let leftNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Cancel), style: .regular, enabled: true, action: {
            dismissImpl?()
        })

        let footerItem = DeleteAccountFooterItem(theme: presentationData.theme, title: presentationData.strings.DeleteAccount_ComeBackLater, secondaryTitle: presentationData.strings.DeleteAccount_Continue, action: {
            dismissImpl?()
        }, secondaryAction: {
            let nextMode: DeleteAccountDataMode?
            switch mode {
                case .peers:
                    nextMode = .groups
                case .groups:
                    nextMode = .messages
                case .messages:
                    nextMode = nil
            }
            
            if let nextMode = nextMode {
                let controller = deleteAccountDataController(context: context, mode: nextMode)
                replaceTopControllerImpl?(controller)
            }
        })
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.DeleteAccount_DeleteMyAccountTitle), leftNavigationButton: leftNavigationButton, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: deleteAccountDataEntries(presentationData: presentationData, mode: mode, peers: peers), style: .blocks, footerItem: footerItem)

        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal, tabBarItem: nil)
    replaceTopControllerImpl = { [weak controller] c in
        if let navigationController = controller?.navigationController as? NavigationController {
            navigationController.pushViewController(c, completion: { [weak navigationController, weak controller, weak c] in
                if let navigationController = navigationController {
                    let controllers = navigationController.viewControllers.filter { $0 !== controller }
                    c?.navigationPresentation = .modal
                    navigationController.setViewControllers(controllers, animated: false)
                }
            })
        }
    }
    dismissImpl = { [weak controller] in
        let _ = controller?.dismiss()
    }

    return controller
}

