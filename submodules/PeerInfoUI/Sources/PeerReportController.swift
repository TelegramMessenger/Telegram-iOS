import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
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
    case profilePhoto(PeerId, Int64)
}

public enum PeerReportOption {
    case spam
    case fake
    case violence
    case copyright
    case pornography
    case childAbuse
    case illegalDrugs
    case personalDetails
    case other
}

public func presentPeerReportOptions(context: AccountContext, parent: ViewController, contextController: ContextControllerProtocol?, backAction: ((ContextControllerProtocol) -> Void)? = nil, subject: PeerReportSubject, options: [PeerReportOption] = [.spam, .violence, .pornography, .childAbuse, .copyright, .other], passthrough: Bool = false, completion: @escaping (ReportReason?, Bool) -> Void) {
    if let contextController = contextController {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        var items: [ContextMenuItem] = []
        for option in options {
            let title: String
            let color: ContextMenuActionItemTextColor = .primary
            var icon: UIImage?
            switch option {
            case .spam:
                title = presentationData.strings.ReportPeer_ReasonSpam
                icon = UIImage(bundleImageName: "Chat/Context Menu/Delete")
            case .fake:
                title = presentationData.strings.ReportPeer_ReasonFake
                icon = UIImage(bundleImageName: "Chat/Context Menu/ReportFake")
            case .violence:
                title = presentationData.strings.ReportPeer_ReasonViolence
                icon = UIImage(bundleImageName: "Chat/Context Menu/ReportViolence")
            case .pornography:
                title = presentationData.strings.ReportPeer_ReasonPornography
                icon = UIImage(bundleImageName: "Chat/Context Menu/ReportXxx")
            case .childAbuse:
                title = presentationData.strings.ReportPeer_ReasonChildAbuse
                icon = UIImage(bundleImageName: "Chat/Context Menu/Restrict")
            case .copyright:
                title = presentationData.strings.ReportPeer_ReasonCopyright
                icon = UIImage(bundleImageName: "Chat/Context Menu/ReportCopyright")
            case .illegalDrugs:
                title = presentationData.strings.ReportPeer_ReasonIllegalDrugs
                icon = UIImage(bundleImageName: "Chat/Context Menu/ReportDrugs")
            case .personalDetails:
                title = presentationData.strings.ReportPeer_ReasonPersonalDetails
                icon = UIImage(bundleImageName: "Chat/Context Menu/ReportPersonal")
            case .other:
                title = presentationData.strings.ReportPeer_ReasonOther
                icon = UIImage(bundleImageName: "Chat/Context Menu/Report")
            }
            items.append(.action(ContextMenuActionItem(text: title, textColor: color, icon: { theme in
                return generateTintedImage(image: icon, color: theme.contextMenu.primaryColor)
            }, action: { [weak parent] _, f in
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                
                let reportReason: ReportReason
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
                case .illegalDrugs:
                    reportReason = .illegalDrugs
                case .personalDetails:
                    reportReason = .personalDetails
                case .other:
                    reportReason = .custom
                }
                
                var passthrough = passthrough
                if [.fake, .custom].contains(reportReason) {
                    passthrough = false
                }
                
                let displaySuccess = {
                    parent?.present(UndoOverlayController(presentationData: presentationData, content: .emoji(name: "PoliceCar", text: presentationData.strings.Report_Succeed), elevatedLayout: false, action: { _ in return false }), in: .current)
                }
                
                if passthrough {
                    completion(reportReason, true)
                } else {
                    let action: (String) -> Void = { message in
                        if passthrough {
                            completion(reportReason, true)
                        } else {
                            switch subject {
                                case let .peer(peerId):
                                    let _ = (context.engine.peers.reportPeer(peerId: peerId, reason: reportReason, message: "")
                                    |> deliverOnMainQueue).start(completed: {
                                        displaySuccess()
                                        completion(nil, false)
                                    })
                                case let .messages(messageIds):
                                    let _ = (context.engine.peers.reportPeerMessages(messageIds: messageIds, reason: reportReason, message: "")
                                    |> deliverOnMainQueue).start(completed: {
                                        displaySuccess()
                                        completion(nil, false)
                                    })
                                case let .profilePhoto(peerId, _):
                                    let _ = (context.engine.peers.reportPeerPhoto(peerId: peerId, reason: reportReason, message: "")
                                    |> deliverOnMainQueue).start(completed: {
                                        displaySuccess()
                                        completion(nil, false)
                                    })
                            }
                        }
                    }
                    
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
             
                        action(message)
                    }))
                    
                    controller.setItemGroups([
                        ActionSheetItemGroup(items: items),
                        ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { dismissAction() })])
                    ])
                    parent?.present(controller, in: .window(.root))
                }
                f(.dismissWithoutContent)
            })))
        }
        if let backAction = backAction {
            items.append(.separator)
            items.append(.action(ContextMenuActionItem(text: presentationData.strings.Common_Back, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Back"), color: theme.actionSheet.primaryTextColor)
            }, action: { (c, _) in
                backAction(c)
            })))
        }
        contextController.setItems(.single(ContextController.Items(content: .list(items))), minHeight: nil)
    } else {
        contextController?.dismiss(completion: nil)
        parent.view.endEditing(true)
        parent.present(peerReportOptionsController(context: context, subject: subject, passthrough: passthrough, present: { [weak parent] c, a in
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
            case .illegalDrugs:
                title = presentationData.strings.ReportPeer_ReasonIllegalDrugs
            case .personalDetails:
                title = presentationData.strings.ReportPeer_ReasonPersonalDetails
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
                case .illegalDrugs:
                    reportReason = .illegalDrugs
                case .personalDetails:
                    reportReason = .personalDetails
                case .other:
                    reportReason = .custom
            }
            if let reportReason = reportReason {
                var passthrough = passthrough
                if [.fake, .custom].contains(reportReason) {
                    passthrough = false
                }
                
                let displaySuccess = {
                    present(UndoOverlayController(presentationData: presentationData, content: .emoji(name: "PoliceCar", text: presentationData.strings.Report_Succeed), elevatedLayout: false, action: { _ in return false }), nil)
                }
                
                let action: (String) -> Void = { message in
                    if passthrough {
                        completion(reportReason, true)
                    } else {
                        switch subject {
                            case let .peer(peerId):
                                let _ = (context.engine.peers.reportPeer(peerId: peerId, reason: reportReason, message: message)
                                |> deliverOnMainQueue).start(completed: {
                                    displaySuccess()
                                    completion(nil, true)
                                })
                            case let .messages(messageIds):
                                let _ = (context.engine.peers.reportPeerMessages(messageIds: messageIds, reason: reportReason, message: message)
                                |> deliverOnMainQueue).start(completed: {
                                    displaySuccess()
                                    completion(nil, true)
                                })
                            case let .profilePhoto(peerId, _):
                                let _ = (context.engine.peers.reportPeerPhoto(peerId: peerId, reason: reportReason, message: message)
                                |> deliverOnMainQueue).start(completed: {
                                    displaySuccess()
                                    completion(nil, true)
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
             
                        action(message)
                    }))
                    
                    controller.setItemGroups([
                        ActionSheetItemGroup(items: items),
                        ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { dismissAction() })])
                    ])
                    present(controller, nil)
                } else {
                    action("")
                }
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
