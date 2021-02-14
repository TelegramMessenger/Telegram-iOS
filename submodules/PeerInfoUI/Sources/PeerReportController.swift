import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import SyncCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import ContextUI
import AlertUI
import PresentationDataUtils
import UndoUI
import AppBundle
import TelegramPermissionsUI
import Markdown

public enum PeerReportSubject {
    case peer(PeerId)
    case messages([MessageId])
}

public enum PeerReportOption {
    case spam
    case fake
    case violence
    case copyright
    case pornography
    case childAbuse
    case other
}

public func presentPeerReportOptions(context: AccountContext, parent: ViewController, contextController: ContextController?, subject: PeerReportSubject, options: [PeerReportOption] = [.spam, .violence, .pornography, .childAbuse, .copyright, .other], completion: @escaping (ReportReason?, Bool) -> Void) {
    if let contextController = contextController {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        var items: [ContextMenuItem] = []
        for option in options {
            let title: String
            let color: ContextMenuActionItemTextColor = .primary
            switch option {
            case .spam:
                title = presentationData.strings.ReportPeer_ReasonSpam
            case .fake:
                title = presentationData.strings.ReportPeer_ReasonFake
            case .violence:
                title = presentationData.strings.ReportPeer_ReasonViolence
            case .pornography:
                title = presentationData.strings.ReportPeer_ReasonPornography
            case .childAbuse:
                title = presentationData.strings.ReportPeer_ReasonChildAbuse
            case .copyright:
                title = presentationData.strings.ReportPeer_ReasonCopyright
            case .other:
                title = presentationData.strings.ReportPeer_ReasonOther
            }
            items.append(.action(ContextMenuActionItem(text: title, textColor: color, icon: { _ in
                return nil
            }, action: { [weak parent] _, f in
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                
                var reportReason: ReportReason?
                switch option {
                case .spam:
                    reportReason = .spam
                case .fake:
                    reportReason = .fake
                case .violence:
                    reportReason = .violence
                case .pornography:
                    reportReason = .porno
                case .childAbuse:
                    reportReason = .childAbuse
                case .copyright:
                    reportReason = .copyright
                case .other:
                    break
                }
                if let reportReason = reportReason {
                    switch subject {
                    case let .peer(peerId):
                        let _ = (reportPeer(account: context.account, peerId: peerId, reason: reportReason, message: "")
                        |> deliverOnMainQueue).start(completed: {
                            if let path = getAppBundle().path(forResource: "PoliceCar", ofType: "tgs") {
                                parent?.present(UndoOverlayController(presentationData: presentationData, content: .emoji(path: path, text: presentationData.strings.Report_Succeed), elevatedLayout: false, action: { _ in return false }), in: .current)
                            }
                            completion(reportReason, true)
                        })
                    case let .messages(messageIds):
                        let _ = (reportPeerMessages(account: context.account, messageIds: messageIds, reason: reportReason, message: "")
                        |> deliverOnMainQueue).start(completed: {
                            if let path = getAppBundle().path(forResource: "PoliceCar", ofType: "tgs") {
                                parent?.present(UndoOverlayController(presentationData: presentationData, content: .emoji(path: path, text: presentationData.strings.Report_Succeed), elevatedLayout: false, action: { _ in return false }), in: .current)
                            }
                            completion(reportReason, true)
                        })
                    }
                } else {
                    parent?.push(peerReportController(context: context, subject: subject, completion: completion))
                }
                f(.dismissWithoutContent)
            })))
        }
        contextController.setItems(.single(items))
    } else {
        contextController?.dismiss()
        parent.view.endEditing(true)
        parent.present(peerReportOptionsController(context: context, subject: subject, passthrough: false, present: { [weak parent] c, a in
            parent?.present(c, in: .window(.root), with: a)
        }, push: { [weak parent] c in
            parent?.push(c)
        }, completion: completion), in: .window(.root))
    }
}

public func peerReportOptionsController(context: AccountContext, subject: PeerReportSubject, options: [PeerReportOption] = [.spam, .violence, .pornography, .childAbuse, .copyright, .other], passthrough: Bool, present: @escaping (ViewController, Any?) -> Void, push: @escaping (ViewController) -> Void, completion: @escaping (ReportReason?, Bool) -> Void) -> ViewController {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let controller = ActionSheetController(theme: ActionSheetControllerTheme(presentationData: presentationData))
        
    var items: [ActionSheetItem] = []
    for option in options {
        let title: String
        let color: ActionSheetButtonColor = .accent
        switch option {
            case .spam:
                title = presentationData.strings.ReportPeer_ReasonSpam
            case .fake:
                title = presentationData.strings.ReportPeer_ReasonFake
            case .violence:
                title = presentationData.strings.ReportPeer_ReasonViolence
            case .pornography:
                title = presentationData.strings.ReportPeer_ReasonPornography
            case .childAbuse:
                title = presentationData.strings.ReportPeer_ReasonChildAbuse
            case .copyright:
                title = presentationData.strings.ReportPeer_ReasonCopyright
            case .other:
                title = presentationData.strings.ReportPeer_ReasonOther
        }
        items.append(ActionSheetButtonItem(title: title, color: color, action: { [weak controller] in
            var reportReason: ReportReason?
            switch option {
                case .spam:
                    reportReason = .spam
                case .fake:
                    reportReason = .fake
                case .violence:
                    reportReason = .violence
                case .pornography:
                    reportReason = .porno
                case .childAbuse:
                    reportReason = .childAbuse
                case .copyright:
                    reportReason = .copyright
                case .other:
                    reportReason = .custom
            }
            if let reportReason = reportReason {
                var passthrough = passthrough
                if [.fake, .custom].contains(reportReason) {
                    passthrough = false
                }
                
                let action = {
                    switch subject {
                        case let .peer(peerId):
                            if passthrough {
                                completion(reportReason, true)
                            } else {
                                let _ = (reportPeer(account: context.account, peerId: peerId, reason: reportReason, message: "")
                                |> deliverOnMainQueue).start(completed: {
                                    if let path = getAppBundle().path(forResource: "PoliceCar", ofType: "tgs") {
                                        present(UndoOverlayController(presentationData: presentationData, content: .emoji(path: path, text: presentationData.strings.Report_Succeed), elevatedLayout: false, action: { _ in return false }), nil)
                                    }
                                    completion(nil, false)
                                })
                            }
                        case let .messages(messageIds):
                            if passthrough {
                                completion(reportReason, true)
                            } else {
                                let _ = (reportPeerMessages(account: context.account, messageIds: messageIds, reason: reportReason, message: "")
                                |> deliverOnMainQueue).start(completed: {
                                    if let path = getAppBundle().path(forResource: "PoliceCar", ofType: "tgs") {
                                        present(UndoOverlayController(presentationData: presentationData, content: .emoji(path: path, text: presentationData.strings.Report_Succeed), elevatedLayout: false, action: { _ in return false }), nil)
                                    }
                                    completion(nil, false)
                                })
                            }
                    }
                }
                
                if [.fake, .custom].contains(reportReason) {
                    let controller = ActionSheetController(presentationData: presentationData, allowInputInset: true)
                    let dismissAction: () -> Void = { [weak controller] in
                        controller?.dismissAnimated()
                    }
                    var message = ""
                    var items: [ActionSheetItem] = []
                    items.append(ReportPeerHeaderActionSheetItem(context: context, text: presentationData.strings.Report_AdditionalDetailsText))
                    items.append(ReportPeerDetailsActionSheetItem(context: context, placeholderText: presentationData.strings.Report_AdditionalDetailsPlaceholder, textUpdated: { text in
                        message = text
                    }))
                    items.append(ActionSheetButtonItem(title: presentationData.strings.Report_Report, color: .accent, font: .bold, enabled: true, action: {
                        dismissAction()
             
                        action()
                    }))
                    
                    controller.setItemGroups([
                        ActionSheetItemGroup(items: items),
                        ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { dismissAction() })])
                    ])
                    present(controller, nil)
                } else {
                    action()
                }
            } else {
                push(peerReportController(context: context, subject: subject, completion: completion))
            }
            
            controller?.dismissAnimated()
        }))
    }
    
    controller.setItemGroups([
        ActionSheetItemGroup(items: items),
        ActionSheetItemGroup(items: [
            ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { [weak controller] in
                controller?.dismissAnimated()
                completion(nil, false)
            })
        ])
    ])
    return controller
}

private final class PeerReportControllerArguments {
    let updateText: (String) -> Void
    
    init(updateText: @escaping (String) -> Void) {
        self.updateText = updateText
    }
}

private enum PeerReportControllerSection: Int32 {
    case text
}

private enum PeerReportControllerEntryTag: ItemListItemTag {
    case text
    
    func isEqual(to other: ItemListItemTag) -> Bool {
        if let other = other as? PeerReportControllerEntryTag {
            switch self {
                case .text:
                    if case .text = other {
                        return true
                    } else {
                        return false
                    }
            }
        } else {
            return false
        }
    }
}

private enum PeerReportControllerEntry: ItemListNodeEntry {
    case text(PresentationTheme, String, String)
    
    var section: ItemListSectionId {
        switch self {
            case .text:
                return PeerReportControllerSection.text.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
            case .text:
                return 0
        }
    }
    
    static func ==(lhs: PeerReportControllerEntry, rhs: PeerReportControllerEntry) -> Bool {
        switch lhs {
            case let .text(lhsTheme, lhsText, lhsValue):
                if case let .text(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: PeerReportControllerEntry, rhs: PeerReportControllerEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! PeerReportControllerArguments
        switch self {
            case let .text(theme, title, value):
                return ItemListMultilineInputItem(presentationData: presentationData, text: value, placeholder: title, maxLength: nil, sectionId: self.section, style: .blocks, textUpdated: { text in
                    arguments.updateText(text)
                }, tag: PeerReportControllerEntryTag.text)
        }
    }
}

private struct PeerReportControllerState: Equatable {
    var isReporting: Bool = false
    var text: String = ""
}

private func peerReportControllerEntries(presentationData: PresentationData, state: PeerReportControllerState) -> [PeerReportControllerEntry] {
    var entries: [PeerReportControllerEntry] = []
    
    entries.append(.text(presentationData.theme, presentationData.strings.ReportPeer_ReasonOther_Placeholder, state.text))
    
    return entries
}

private func peerReportController(context: AccountContext, subject: PeerReportSubject, completion: @escaping (ReportReason?, Bool) -> Void) -> ViewController {
    var dismissImpl: (() -> Void)?
    var presentControllerImpl: ((ViewController, ViewControllerPresentationArguments?) -> Void)?
    
    let statePromise = ValuePromise(PeerReportControllerState(), ignoreRepeated: true)
    let stateValue = Atomic(value: PeerReportControllerState())
    let updateState: ((PeerReportControllerState) -> PeerReportControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    let arguments = PeerReportControllerArguments(updateText: { text in
        updateState { state in
            var state = state
            state.text = text
            return state
        }
    })
    
    let reportDisposable = MetaDisposable()
    
    let signal = combineLatest(context.sharedContext.presentationData, statePromise.get())
    |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let rightButton: ItemListNavigationButton
        if state.isReporting {
            rightButton = ItemListNavigationButton(content: .none, style: .activity, enabled: true, action: {})
        } else {
            rightButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Done), style: .bold, enabled: !state.text.isEmpty, action: {
                var text: String = ""
                updateState { state in
                    var state = state
                    if !state.isReporting && !state.text.isEmpty {
                        text = state.text
                        state.isReporting = true
                    }
                    return state
                }
                
                if !text.isEmpty {
                    let reportReason: ReportReason = .custom
                    let completed: () -> Void = {
                        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                        presentControllerImpl?(textAlertController(context: context, title: nil, text: presentationData.strings.ReportPeer_AlertSuccess, actions: [TextAlertAction.init(type: TextAlertActionType.defaultAction, title: presentationData.strings.Common_OK, action: {})]), nil)
                        completion(reportReason, true)
                        dismissImpl?()
                    }
                    switch subject {
                    case let .peer(peerId):
                        reportDisposable.set((reportPeer(account: context.account, peerId: peerId, reason: reportReason, message: text)
                        |> deliverOnMainQueue).start(completed: {
                            completed()
                        }))
                    case let .messages(messageIds):
                        reportDisposable.set((reportPeerMessages(account: context.account, messageIds: messageIds, reason: reportReason, message: text)
                        |> deliverOnMainQueue).start(completed: {
                            completed()
                        }))
                    }
                }
            })
        }
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.ReportPeer_ReasonOther_Title), leftNavigationButton: ItemListNavigationButton(content: .text(presentationData.strings.Common_Cancel), style: .regular, enabled: true, action: {
            dismissImpl?()
            completion(nil, false)
        }), rightNavigationButton: rightButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: peerReportControllerEntries(presentationData: presentationData, state: state), style: .blocks, focusItemTag: PeerReportControllerEntryTag.text)
        
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
        reportDisposable.dispose()
    }
    
    let controller = ItemListController(context: context, state: signal)
    controller.navigationPresentation = .modal
    presentControllerImpl = { [weak controller] c, a in
        controller?.present(c, in: .window(.root), with: a)
    }
    dismissImpl = { [weak controller] in
        controller?.view.endEditing(true)
        controller?.dismiss()
    }
    return controller
}
