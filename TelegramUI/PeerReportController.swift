import Foundation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

enum PeerReportSubject {
    case peer(PeerId)
    case messages([MessageId])
}

private enum PeerReportOption {
    case spam
    case violence
    case copyright
    case pornoghraphy
    case childAbuse
    case other
}

func peerReportOptionsController(account: Account, subject: PeerReportSubject, present: @escaping (ViewController, Any?) -> Void) -> ViewController {
    let presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
    let controller = ActionSheetController(theme: ActionSheetControllerTheme(presentationTheme: presentationData.theme))
    
    let options: [PeerReportOption] = [
        .spam,
        .violence,
        .pornoghraphy,
        .childAbuse,
        .copyright,
        .other
    ]
    
    var items: [ActionSheetItem] = []
    for option in options {
        let title: String
        var color: ActionSheetButtonColor = .accent
        switch option {
            case .spam:
                title = presentationData.strings.ReportPeer_ReasonSpam
            case .violence:
                title = presentationData.strings.ReportPeer_ReasonViolence
            case .pornoghraphy:
                title = presentationData.strings.ReportPeer_ReasonPornography
            case .childAbuse:
                title = presentationData.strings.ReportPeer_ReasonChildAbuse
                color = .destructive
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
                case .violence:
                    reportReason = .violence
                case .pornoghraphy:
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
                        let _ = (reportPeer(account: account, peerId: peerId, reason: reportReason)
                        |> deliverOnMainQueue).start(completed: {
                            let alert = standardTextAlertController(theme: AlertControllerTheme(presentationTheme: presentationData.theme), title: nil, text: presentationData.strings.ReportPeer_AlertSuccess, actions: [TextAlertAction.init(type: TextAlertActionType.defaultAction, title: presentationData.strings.Common_OK, action: {
                                
                            })])
                            present(alert, nil)
                        })
                    case let .messages(messageIds):
                        let _ = (reportPeerMessages(account: account, messageIds: messageIds, reason: reportReason)
                        |> deliverOnMainQueue).start(completed: {
                            let alert = standardTextAlertController(theme: AlertControllerTheme(presentationTheme: presentationData.theme), title: nil, text: presentationData.strings.ReportPeer_AlertSuccess, actions: [TextAlertAction.init(type: TextAlertActionType.defaultAction, title: presentationData.strings.Common_OK, action: {
                                
                            })])
                            present(alert, nil)
                        })
                }
            } else {
                controller?.present(peerReportController(account: account, subject: subject), in: .window(.root), with: ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
            }
            
            controller?.dismissAnimated()
        }))
    }
    
    controller.setItemGroups([
        ActionSheetItemGroup(items: items),
        ActionSheetItemGroup(items: [
            ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { [weak controller] in
                controller?.dismissAnimated()
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
    
    func item(_ arguments: PeerReportControllerArguments) -> ListViewItem {
        switch self {
            case let .text(theme, title, value):
                return ItemListMultilineInputItem(theme: theme, text: value, placeholder: title, maxLength: nil, sectionId: self.section, style: .blocks, textUpdated: { text in
                    arguments.updateText(text)
                }, tag: PeerReportControllerEntryTag.text, action: {})
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

private func peerReportController(account: Account, subject: PeerReportSubject) -> ViewController {
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
    
    let signal = combineLatest((account.applicationContext as! TelegramApplicationContext).presentationData, statePromise.get())
        |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState<PeerReportControllerEntry>, PeerReportControllerEntry.ItemGenerationArguments)) in
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
                        let completed: () -> Void = {
                            let presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
                            
                            let alert = standardTextAlertController(theme: AlertControllerTheme(presentationTheme: presentationData.theme), title: nil, text: presentationData.strings.ReportPeer_AlertSuccess, actions: [TextAlertAction.init(type: TextAlertActionType.defaultAction, title: presentationData.strings.Common_OK, action: {
                                
                            })])
                            presentControllerImpl?(alert, nil)
                            dismissImpl?()
                        }
                        switch subject {
                        case let .peer(peerId):
                            reportDisposable.set((reportPeer(account: account, peerId: peerId, reason: .custom(text))
                                |> deliverOnMainQueue).start(completed: {
                                    completed()
                                }))
                        case let .messages(messageIds):
                            reportDisposable.set((reportPeerMessages(account: account, messageIds: messageIds, reason: .custom(text))
                                |> deliverOnMainQueue).start(completed: {
                                    completed()
                                }))
                        }
                    }
                })
            }
            
            let controllerState = ItemListControllerState(theme: presentationData.theme, title: .text(presentationData.strings.ReportPeer_ReasonOther_Title), leftNavigationButton: ItemListNavigationButton(content: .text(presentationData.strings.Common_Cancel), style: .regular, enabled: true, action: {
                dismissImpl?()
            }), rightNavigationButton: rightButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
            let listState = ItemListNodeState(entries: peerReportControllerEntries(presentationData: presentationData, state: state), style: .blocks,  focusItemTag: PeerReportControllerEntryTag.text)
            
            return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
        reportDisposable.dispose()
    }
    
    let controller = ItemListController(account: account, state: signal)
    presentControllerImpl = { [weak controller] c, a in
        controller?.present(c, in: .window(.root), with: a)
    }
    dismissImpl = { [weak controller] in
        controller?.view.endEditing(true)
        controller?.dismiss()
    }
    return controller
}
