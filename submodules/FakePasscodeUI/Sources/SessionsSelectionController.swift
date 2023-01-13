import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import AccountContext
import FakePasscode

private final class SessionsControllerArguments {
    let changeSelectionMode: () -> Void
    let checkSession: (Bool, RecentAccountSession) -> Void
    let clearSessions: () -> Void
    let checkAllSessions: () -> Void

    init(changeSelectionMode: @escaping () -> Void, checkSession: @escaping (Bool, RecentAccountSession) -> Void, clearSessions: @escaping () -> Void, checkAllSessions: @escaping () -> Void) {
        self.changeSelectionMode = changeSelectionMode
        self.checkSession = checkSession
        self.clearSessions = clearSessions
        self.checkAllSessions = checkAllSessions
    }
}

private enum SessionsEntryStableId: Hashable {
    case index(Int32)
    case session(Int)

    static func <(lhs: SessionsEntryStableId, rhs: SessionsEntryStableId) -> Bool {
        switch (lhs, rhs) {
        case (.index(let lidx), .index(let ridx)):
            return lidx < ridx
        case (.session(let lidx), .session(let ridx)):
            return lidx < ridx
        case (.index, .session):
            return true
        case (.session, .index):
            return false
        }
    }
}

private enum SessionsSection: Int32 {
    case control
    case sessions
}

private enum HideSessionsEntry: ItemListNodeEntry {
    case selectionMode(String, SessionSelectionMode)
    case activeSessionHeader(String)
    case activeSession(Int, PresentationStrings, PresentationDateTimeFormat, RecentAccountSession, Bool)

    var section: ItemListSectionId {
        switch self {
            case .selectionMode:
                return SessionsSection.control.rawValue
            case .activeSessionHeader, .activeSession:
                return SessionsSection.sessions.rawValue
        }
    }

    var stableId: SessionsEntryStableId {
        switch self {
        case .selectionMode:
            return .index(0)
        case .activeSessionHeader:
            return .index(1)
        case .activeSession(let index, _, _, _, _):
            return .session(index)
        }
    }

    static func ==(lhs: HideSessionsEntry, rhs: HideSessionsEntry) -> Bool {
        switch lhs {
        case let .selectionMode(lhsText, lhsMode):
            if case let .selectionMode(rhsText, rhsMode) = rhs, lhsText == rhsText, lhsMode == rhsMode {
                return true
            } else {
                return false
            }
        case let .activeSessionHeader(lhsText):
            if case let .activeSessionHeader(rhsText) = rhs, lhsText == rhsText {
                return true
            } else {
                return false
            }
        case let .activeSession(rhsIndex, rhsStrings, rhsDateTimeFormat, rhsSession, rhsChecked):
            if case let .activeSession(lhsIndex, lhsStrings, lhsDateTimeFormat, lhsSession, lhsChecked) = rhs, lhsIndex == rhsIndex, lhsStrings === rhsStrings, lhsDateTimeFormat == rhsDateTimeFormat, lhsSession == rhsSession, rhsChecked == lhsChecked {
                return true
            } else {
                return false
            }
        }
    }

    static func <(lhs: HideSessionsEntry, rhs: HideSessionsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! SessionsControllerArguments
        switch self {
        case let .selectionMode(title, mode):
            let label = mode == .selected ? presentationData.strings.AccountActions_SessionsToHide_Selected : presentationData.strings.AccountActions_SessionsToHide_ExceptSelected
            return ItemListDisclosureItem(presentationData: presentationData, title: title, label: label, sectionId: self.section, style: .blocks, action: {
                arguments.changeSelectionMode()
            })
        case let .activeSessionHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text.uppercased(), sectionId: self.section)
        case let .activeSession(_, _, dateTimeFormat, session, checked):
            return ItemListSessionItem(presentationData: presentationData, dateTimeFormat: dateTimeFormat, session: session, checked: checked, sectionId: self.section, updated: { checked in
                arguments.checkSession(checked, session)
            })
        }
    }
}

private func sessionsSelectionControllerEntries(presentationData: PresentationData, modeTitle: String, selector: SessionSelector, sessionsState: ActiveSessionsContextState) -> [HideSessionsEntry] {
    var entries: [HideSessionsEntry] = []

    entries.append(.selectionMode(modeTitle, selector.mode))

    if !sessionsState.sessions.isEmpty {
        entries.append(.activeSessionHeader(presentationData.strings.AccountActions_SessionsToHide_ActiveSessions))
        for (index, session) in sessionsState.sessions.enumerated() {
            if session.hash == 0 {
                continue
            }
            entries.append(.activeSession(index, presentationData.strings, presentationData.dateTimeFormat, session, selector.sessions.contains(where: { $0 == session.hash })))
        }
    }

    return entries
}

func sessionsSelectionController(context: AccountContext, title: String, selector: SessionSelector, updated: @escaping ((SessionSelector) -> Void)) -> ViewController {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let activeSessionsContext = context.engine.privacy.activeSessions()

    activeSessionsContext.loadMore()

    var presentControllerImpl: ((ViewController) -> Void)?

    let actionsDisposable = DisposableSet()
    let selectorPromise = Promise<SessionSelector>(selector)

    let confirmChange: ((@escaping (SessionSelector) -> Void) -> Void) = { confirmed in
        let actionSheet = ActionSheetController(presentationData: presentationData)

        actionSheet.setItemGroups([
            ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: presentationData.strings.Common_Yes, color: .destructive, action: { [weak actionSheet] in
                    let _ = (selectorPromise.get() |> take(1)).start(next: { data in
                        confirmed(data)
                    })
                    actionSheet?.dismissAnimated()
                })
            ]),
            ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                    actionSheet?.dismissAnimated()
                })
            ])
        ])
        presentControllerImpl?(actionSheet)
    }

    let arguments = SessionsControllerArguments(changeSelectionMode: {
        let actionSheet = ActionSheetController(presentationData: presentationData)
        let items: [(String, SessionSelectionMode)] = [
            (presentationData.strings.AccountActions_SessionsToHide_Selected, .selected),
            (presentationData.strings.AccountActions_SessionsToHide_ExceptSelected, .excluded),
        ]
        let itemsGroups = items.map { (title, mode) in
            ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: title, color: .accent, action: { [weak actionSheet] in
                    let _ = (selectorPromise.get() |> take(1)).start(next: { [weak selectorPromise] selector in
                        let updatedSelector = selector.withUpdatedMode(mode)
                        selectorPromise?.set(.single(updatedSelector))
                        updated(updatedSelector)
                    })
                    actionSheet?.dismissAnimated()
                })
            ])
        }
        actionSheet.setItemGroups(itemsGroups)
        presentControllerImpl?(actionSheet)
    }, checkSession: { checked, session in
        let _ = (selectorPromise.get() |> take(1)).start(next: { [weak selectorPromise] selector in
            var sessions = selector.sessions
            if checked {
                sessions.append(session.hash)
            } else {
                if let index = sessions.firstIndex(of: session.hash) {
                    sessions.remove(at: index)
                } else {
                    assertionFailure("Session with id \(session.hash) not found")
                }
            }
            let updatedSelector = selector.withUpdatedSessions(sessions)
            selectorPromise?.set(.single(updatedSelector))
            updated(updatedSelector)
        })
    }, clearSessions: {
        confirmChange { data in
            let updatedData = data.withUpdatedSessions([])
            selectorPromise.set(.single(updatedData))
            updated(updatedData)
        }
    }, checkAllSessions: {
        confirmChange { data in
            let _ = (activeSessionsContext.state |> take(1)).start(next: { [weak selectorPromise] activeSessionsContext in
                let allSessions = activeSessionsContext.sessions.map { s in s.hash }
                let updatedSelector = data.withUpdatedSessions(allSessions)
                selectorPromise?.set(.single(updatedSelector))
                updated(updatedSelector)
            })
        }
    })

    let signal = combineLatest(context.sharedContext.presentationData, activeSessionsContext.state, selectorPromise.get())
    |> deliverOnMainQueue
    |> map { presentationData, sessionsState, selector -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let noSelectedSessions = selector.sessions.isEmpty
        let rightNavButtonContent = noSelectedSessions ? presentationData.strings.AccountActions_SessionsToHide_CheckAll : presentationData.strings.AccountActions_SessionsToHide_Clear
        let rightNavButtonAction : () -> Void = noSelectedSessions ? { arguments.checkAllSessions() } : { arguments.clearSessions() }
        let rightNavigationButton = ItemListNavigationButton(content: .text(rightNavButtonContent), style: .regular, enabled: true, action: {
            rightNavButtonAction()
        })

        let entries = sessionsSelectionControllerEntries(presentationData: presentationData, modeTitle: title, selector: selector, sessionsState: sessionsState)

        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(title), leftNavigationButton: nil, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: true)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks)

        return (controllerState, (listState, arguments))
    } |> afterDisposed {
        actionsDisposable.dispose()
    }

    let controller = ItemListControllerReactiveToPasscodeSwitch(context: context, state: signal, onPasscodeSwitch: { controller in
        controller.dismiss(animated: false)
    })

    presentControllerImpl = { [weak controller] c in
        if let controller = controller {
            controller.present(c, in: .window(.root))
        }
    }

    return controller
}
