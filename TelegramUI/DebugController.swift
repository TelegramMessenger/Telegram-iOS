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
}

private enum DebugControllerEntry: ItemListNodeEntry {
    case sendLogs
    case accounts
    
    var section: ItemListSectionId {
        switch self {
            case .sendLogs:
                return DebugControllerSection.logs.rawValue
            case .accounts:
                return DebugControllerSection.logs.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
            case .sendLogs:
                return 0
            case .accounts:
                return 1
        }
    }
    
    static func ==(lhs: DebugControllerEntry, rhs: DebugControllerEntry) -> Bool {
        switch lhs {
            case .sendLogs, .accounts:
                return lhs.stableId == rhs.stableId
        }
    }
    
    static func <(lhs: DebugControllerEntry, rhs: DebugControllerEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(_ arguments: DebugControllerArguments) -> ListViewItem {
        switch self {
            case .sendLogs:
                return ItemListDisclosureItem(title: "Seng Logs", label: "", sectionId: self.section, style: .blocks, action: {
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
            case .accounts:
                return ItemListDisclosureItem(title: "Accounts", label: "", sectionId: self.section, style: .blocks, action: {
                    arguments.pushController(debugAccountsController(account: arguments.account, accountManager: arguments.accountManager))
                })
        }
    }
}

private func debugControllerEntries() -> [DebugControllerEntry] {
    var entries: [DebugControllerEntry] = []
    
    entries.append(.sendLogs)
    entries.append(.accounts)
    
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
    
    let signal = Signal<Void, NoError>.single(Void())
        |> map { _ -> (ItemListControllerState, (ItemListNodeState<DebugControllerEntry>, DebugControllerEntry.ItemGenerationArguments)) in
            let controllerState = ItemListControllerState(title: "Debug", leftNavigationButton: nil, rightNavigationButton: nil)
            let listState = ItemListNodeState(entries: debugControllerEntries(), style: .blocks)
            
            return (controllerState, (listState, arguments))
    }
    
    let controller = ItemListController(signal)
    presentControllerImpl = { [weak controller] c, a in
        controller?.present(c, in: .window, with: a)
    }
    pushControllerImpl = { [weak controller] c in
        (controller?.navigationController as? NavigationController)?.pushViewController(c)
    }
    return controller
}
