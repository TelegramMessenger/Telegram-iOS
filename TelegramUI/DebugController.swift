import Foundation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

private final class DebugControllerArguments {
    let account: Account
    let accountManager: AccountManager
    let presentController: (ViewController, ViewControllerPresentationArguments) -> Void
    let pushController: (ViewController) -> Void
    
    init(account: Account, accountManager: AccountManager, presentController: @escaping (ViewController, ViewControllerPresentationArguments) -> Void, pushController: @escaping (ViewController) -> Void) {
        self.account = account
        self.accountManager = accountManager
        self.presentController = presentController
        self.pushController = pushController
    }
}

private enum DebugControllerSection: Int32 {
    case logs
    case payments
}

private enum DebugControllerEntry: ItemListNodeEntry {
    case sendLogs(PresentationTheme)
    case accounts(PresentationTheme)
    case clearPaymentData(PresentationTheme)
    
    var section: ItemListSectionId {
        switch self {
            case .sendLogs:
                return DebugControllerSection.logs.rawValue
            case .accounts:
                return DebugControllerSection.logs.rawValue
            case .clearPaymentData:
                return DebugControllerSection.payments.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
            case .sendLogs:
                return 0
            case .accounts:
                return 1
            case .clearPaymentData:
                return 2
        }
    }
    
    static func ==(lhs: DebugControllerEntry, rhs: DebugControllerEntry) -> Bool {
        switch lhs {
            case let .sendLogs(lhsTheme):
                if case let .sendLogs(rhsTheme) = rhs, lhsTheme === rhsTheme {
                    return true
                } else {
                    return false
                }
            case let .accounts(lhsTheme):
                if case let .accounts(rhsTheme) = rhs, lhsTheme === rhsTheme {
                    return true
                } else {
                    return false
                }
            case let .clearPaymentData(lhsTheme):
                if case let .clearPaymentData(rhsTheme) = rhs, lhsTheme === rhsTheme {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: DebugControllerEntry, rhs: DebugControllerEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(_ arguments: DebugControllerArguments) -> ListViewItem {
        switch self {
            case let .sendLogs(theme):
                return ItemListDisclosureItem(theme: theme, title: "Seng Logs", label: "", sectionId: self.section, style: .blocks, action: {
                    let _ = (Logger.shared.collectLogs()
                        |> deliverOnMainQueue).start(next: { logs in
                            let controller = PeerSelectionController(account: arguments.account)
                            controller.peerSelected = { [weak controller] peerId in
                                if let strongController = controller {
                                    strongController.dismiss()
                                    
                                    let messages = logs.map { (name, path) -> EnqueueMessage in
                                        let id = arc4random64()
                                        let file = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: id), resource: LocalFileReferenceMediaResource(localFilePath: path, randomId: id), previewRepresentations: [], mimeType: "application/text", size: nil, attributes: [.FileName(fileName: name)])
                                        return .message(text: "", attributes: [], media: file, replyToMessageId: nil)
                                    }
                                    let _ = enqueueMessages(account: arguments.account, peerId: peerId, messages: messages).start()
                                }
                            }
                            arguments.presentController(controller, ViewControllerPresentationArguments(presentationAnimation: ViewControllerPresentationAnimation.modalSheet))
                        })
                })
            case let .accounts(theme):
                return ItemListDisclosureItem(theme: theme, title: "Accounts", label: "", sectionId: self.section, style: .blocks, action: {
                    arguments.pushController(debugAccountsController(account: arguments.account, accountManager: arguments.accountManager))
                })
            case let .clearPaymentData(theme):
                return ItemListDisclosureItem(theme: theme, title: "Clear Payment Data", label: "", sectionId: self.section, style: .blocks, action: {
                    let _ = cacheTwoStepPasswordToken(postbox: arguments.account.postbox, token: nil).start()
                })
        }
    }
}

private func debugControllerEntries(presentationData: PresentationData) -> [DebugControllerEntry] {
    var entries: [DebugControllerEntry] = []
    
    entries.append(.sendLogs(presentationData.theme))
    entries.append(.accounts(presentationData.theme))
    entries.append(.clearPaymentData(presentationData.theme))
    
    return entries
}

public func debugController(account: Account, accountManager: AccountManager) -> ViewController {
    var presentControllerImpl: ((ViewController, ViewControllerPresentationArguments?) -> Void)?
    var pushControllerImpl: ((ViewController) -> Void)?
    
    let arguments = DebugControllerArguments(account: account, accountManager: accountManager, presentController: { controller, arguments in
        presentControllerImpl?(controller, arguments)
    }, pushController: { controller in
        pushControllerImpl?(controller)
    })
    
    let signal = (account.applicationContext as! TelegramApplicationContext).presentationData
        |> map { presentationData -> (ItemListControllerState, (ItemListNodeState<DebugControllerEntry>, DebugControllerEntry.ItemGenerationArguments)) in
            let controllerState = ItemListControllerState(theme: presentationData.theme, title: .text("Debug"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: "Back"))
            let listState = ItemListNodeState(entries: debugControllerEntries(presentationData: presentationData), style: .blocks)
            
            return (controllerState, (listState, arguments))
    }
    
    let controller = ItemListController(account: account, state: signal)
    presentControllerImpl = { [weak controller] c, a in
        controller?.present(c, in: .window(.root), with: a)
    }
    pushControllerImpl = { [weak controller] c in
        (controller?.navigationController as? NavigationController)?.pushViewController(c)
    }
    return controller
}
