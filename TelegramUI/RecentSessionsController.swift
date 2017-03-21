import Foundation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

private final class RecentSessionsControllerArguments {
    let account: Account
    
    let setSessionIdWithRevealedOptions: (Int64?, Int64?) -> Void
    let removeSession: (Int64) -> Void
    let terminateOtherSessions: () -> Void
    
    init(account: Account, setSessionIdWithRevealedOptions: @escaping (Int64?, Int64?) -> Void, removeSession: @escaping (Int64) -> Void, terminateOtherSessions: @escaping () -> Void) {
        self.account = account
        self.setSessionIdWithRevealedOptions = setSessionIdWithRevealedOptions
        self.removeSession = removeSession
        self.terminateOtherSessions = terminateOtherSessions
    }
}

private enum RecentSessionsSection: Int32 {
    case currentSession
    case otherSessions
}

private enum RecentSessionsEntryStableId: Hashable {
    case session(Int64)
    case index(Int32)
    
    var hashValue: Int {
        switch self {
            case let .session(hash):
                return hash.hashValue
            case let .index(index):
                return index.hashValue
        }
    }
    
    static func ==(lhs: RecentSessionsEntryStableId, rhs: RecentSessionsEntryStableId) -> Bool {
        switch lhs {
            case let .session(hash):
                if case .session(hash) = rhs {
                    return true
                } else {
                    return false
                }
            case let .index(index):
                if case .index(index) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}

private enum RecentSessionsEntry: ItemListNodeEntry {
    case currentSessionHeader
    case currentSession(RecentAccountSession)
    case terminateOtherSessions
    case currentSessionInfo
    
    case otherSessionsHeader
    case session(index: Int32, session: RecentAccountSession, enabled: Bool, editing: Bool, revealed: Bool)
    
    var section: ItemListSectionId {
        switch self {
            case .currentSessionHeader, .currentSession, .terminateOtherSessions, .currentSessionInfo:
                return RecentSessionsSection.currentSession.rawValue
            case .otherSessionsHeader, .session:
                return RecentSessionsSection.otherSessions.rawValue
        }
    }
    
    var stableId: RecentSessionsEntryStableId {
        switch self {
            case .currentSessionHeader:
                return .index(0)
            case .currentSession:
                return .index(1)
            case .terminateOtherSessions:
                return .index(2)
            case .currentSessionInfo:
                return .index(3)
            case .otherSessionsHeader:
                return .index(4)
            case let .session(_, session, _, _, _):
                return .session(session.hash)
        }
    }
    
    static func ==(lhs: RecentSessionsEntry, rhs: RecentSessionsEntry) -> Bool {
        switch lhs {
            case .currentSessionHeader, .terminateOtherSessions, .currentSessionInfo, .otherSessionsHeader:
                return lhs.stableId == rhs.stableId
            case let .currentSession(session):
                if case .currentSession(session) = rhs {
                    return true
                } else {
                    return false
                }
            case let .session(index, session, enabled, editing, revealed):
                if case .session(index, session, enabled, editing, revealed) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: RecentSessionsEntry, rhs: RecentSessionsEntry) -> Bool {
        switch lhs.stableId {
            case let .index(lhsIndex):
                if case let .index(rhsIndex) = rhs.stableId {
                    return lhsIndex <= rhsIndex
                } else {
                    return true
                }
            case .session:
                switch lhs {
                    case let .session(lhsIndex, _, _, _, _):
                        if case let .session(rhsIndex, _, _, _, _) = rhs {
                            return lhsIndex <= rhsIndex
                        } else {
                            return false
                        }
                    default:
                        preconditionFailure()
                }
        }
    }
    
    func item(_ arguments: RecentSessionsControllerArguments) -> ListViewItem {
        switch self {
            case .currentSessionHeader:
                return ItemListSectionHeaderItem(text: "CURRENT SESSION", sectionId: self.section)
            case let .currentSession(session):
                return ItemListRecentSessionItem(session: session, enabled: true, editable: false, editing: false, revealed: false, sectionId: self.section, setSessionIdWithRevealedOptions: { _, _ in
                }, removeSession: { _ in
                })
            case .terminateOtherSessions:
                return ItemListActionItem(title: "Terminate all other sessions", kind: .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    arguments.terminateOtherSessions()
                })
            case .currentSessionInfo:
                return ItemListTextItem(text: .plain("Logs out all devices except for this one."), sectionId: self.section)
            case .otherSessionsHeader:
                return ItemListSectionHeaderItem(text: "ACTIVE SESSIONS", sectionId: self.section)
            case let .session(_, session, enabled, editing, revealed):
                return ItemListRecentSessionItem(session: session, enabled: enabled, editable: true, editing: editing, revealed: revealed, sectionId: self.section, setSessionIdWithRevealedOptions: { previousId, id in
                    arguments.setSessionIdWithRevealedOptions(previousId, id)
                }, removeSession: { id in
                    arguments.removeSession(id)
                })
        }
    }
}

private struct RecentSessionsControllerState: Equatable {
    let editing: Bool
    let sessionIdWithRevealedOptions: Int64?
    let removingSessionId: Int64?
    let terminatingOtherSessions: Bool
    
    init() {
        self.editing = false
        self.sessionIdWithRevealedOptions = nil
        self.removingSessionId = nil
        self.terminatingOtherSessions = false
    }
    
    init(editing: Bool, sessionIdWithRevealedOptions: Int64?, removingSessionId: Int64?, terminatingOtherSessions: Bool) {
        self.editing = editing
        self.sessionIdWithRevealedOptions = sessionIdWithRevealedOptions
        self.removingSessionId = removingSessionId
        self.terminatingOtherSessions = terminatingOtherSessions
    }
    
    static func ==(lhs: RecentSessionsControllerState, rhs: RecentSessionsControllerState) -> Bool {
        if lhs.editing != rhs.editing {
            return false
        }
        if lhs.sessionIdWithRevealedOptions != rhs.sessionIdWithRevealedOptions {
            return false
        }
        if lhs.removingSessionId != rhs.removingSessionId {
            return false
        }
        if lhs.terminatingOtherSessions != rhs.terminatingOtherSessions {
            return false
        }
        
        return true
    }
    
    func withUpdatedEditing(_ editing: Bool) -> RecentSessionsControllerState {
        return RecentSessionsControllerState(editing: editing, sessionIdWithRevealedOptions: self.sessionIdWithRevealedOptions, removingSessionId: self.removingSessionId, terminatingOtherSessions: self.terminatingOtherSessions)
    }
    
    func withUpdatedSessionIdWithRevealedOptions(_ sessionIdWithRevealedOptions: Int64?) -> RecentSessionsControllerState {
        return RecentSessionsControllerState(editing: self.editing, sessionIdWithRevealedOptions: sessionIdWithRevealedOptions, removingSessionId: self.removingSessionId, terminatingOtherSessions: self.terminatingOtherSessions)
    }
    
    func withUpdatedRemovingSessionId(_ removingSessionId: Int64?) -> RecentSessionsControllerState {
        return RecentSessionsControllerState(editing: self.editing, sessionIdWithRevealedOptions: self.sessionIdWithRevealedOptions, removingSessionId: removingSessionId, terminatingOtherSessions: self.terminatingOtherSessions)
    }
    
    func withUpdatedTerminatingOtherSessions(_ terminatingOtherSessions: Bool) -> RecentSessionsControllerState {
        return RecentSessionsControllerState(editing: self.editing, sessionIdWithRevealedOptions: self.sessionIdWithRevealedOptions, removingSessionId: self.removingSessionId, terminatingOtherSessions: terminatingOtherSessions)
    }
}

private func recentSessionsControllerEntries(state: RecentSessionsControllerState, sessions: [RecentAccountSession]?) -> [RecentSessionsEntry] {
    var entries: [RecentSessionsEntry] = []
    
    if let sessions = sessions {
        var existingSessionIds = Set<Int64>()
        entries.append(.currentSessionHeader)
        if let index = sessions.index(where: { $0.hash == 0 }) {
            existingSessionIds.insert(sessions[index].hash)
            entries.append(.currentSession(sessions[index]))
        }
        
        if sessions.count > 1 {
            entries.append(.terminateOtherSessions)
            entries.append(.currentSessionInfo)
        
            entries.append(.otherSessionsHeader)
            
            let filteredSessions: [RecentAccountSession] = sessions.sorted(by: { lhs, rhs in
                return lhs.activityDate > rhs.activityDate
            })
            
            for i in 0 ..< filteredSessions.count {
                if !existingSessionIds.contains(sessions[i].hash) {
                    existingSessionIds.insert(sessions[i].hash)
                    entries.append(.session(index: Int32(i), session: sessions[i], enabled: state.removingSessionId != sessions[i].hash && !state.terminatingOtherSessions, editing: state.editing, revealed: state.sessionIdWithRevealedOptions == sessions[i].hash))
                }
            }
        }
    }
    
    return entries
}

public func recentSessionsController(account: Account) -> ViewController {
    let statePromise = ValuePromise(RecentSessionsControllerState(), ignoreRepeated: true)
    let stateValue = Atomic(value: RecentSessionsControllerState())
    let updateState: ((RecentSessionsControllerState) -> RecentSessionsControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var presentControllerImpl: ((ViewController, ViewControllerPresentationArguments?) -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    let removeSessionDisposable = MetaDisposable()
    actionsDisposable.add(removeSessionDisposable)
    
    let terminateOtherSessionsDisposable = MetaDisposable()
    actionsDisposable.add(terminateOtherSessionsDisposable)
    
    let sessionsPromise = Promise<[RecentAccountSession]?>(nil)
    
    let arguments = RecentSessionsControllerArguments(account: account, setSessionIdWithRevealedOptions: { sessionId, fromSessionId in
        updateState { state in
            if (sessionId == nil && fromSessionId == state.sessionIdWithRevealedOptions) || (sessionId != nil && fromSessionId == nil) {
                return state.withUpdatedSessionIdWithRevealedOptions(sessionId)
            } else {
                return state
            }
        }
    }, removeSession: { sessionId in
        updateState {
            return $0.withUpdatedRemovingSessionId(sessionId)
        }
        
        let applySessions: Signal<Void, NoError> = sessionsPromise.get()
            |> filter { $0 != nil }
            |> take(1)
            |> deliverOnMainQueue
            |> mapToSignal { sessions -> Signal<Void, NoError> in
                if let sessions = sessions {
                    var updatedSessions = sessions
                    for i in 0 ..< updatedSessions.count {
                        if updatedSessions[i].hash == sessionId {
                            updatedSessions.remove(at: i)
                            break
                        }
                    }
                    sessionsPromise.set(.single(updatedSessions))
                }
                
                return .complete()
        }
        
        removeSessionDisposable.set((terminateAccountSession(account: account, hash: sessionId) |> then(applySessions) |> deliverOnMainQueue).start(error: { _ in
            updateState {
                return $0.withUpdatedRemovingSessionId(nil)
            }
        }, completed: {
            updateState {
                return $0.withUpdatedRemovingSessionId(nil)
            }
        }))
    }, terminateOtherSessions: {
        let controller = ActionSheetController()
        let dismissAction: () -> Void = { [weak controller] in
            controller?.dismissAnimated()
        }
        controller.setItemGroups([
            ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: "Terminate all other sessions", color: .destructive, action: {
                    dismissAction()
                    
                    updateState {
                        return $0.withUpdatedTerminatingOtherSessions(true)
                    }
                    
                    let applySessions: Signal<Void, NoError> = sessionsPromise.get()
                        |> filter { $0 != nil }
                        |> take(1)
                        |> deliverOnMainQueue
                        |> mapToSignal { sessions -> Signal<Void, NoError> in
                            if let sessions = sessions {
                                let updatedSessions = sessions.filter { $0.isCurrent }
                                sessionsPromise.set(.single(updatedSessions))
                            }
                            
                            return .complete()
                    }
                    
                    terminateOtherSessionsDisposable.set((terminateOtherAccountSessions(account: account) |> then(applySessions)).start(error: { _ in
                        updateState {
                            return $0.withUpdatedTerminatingOtherSessions(false)
                        }
                    }, completed: {
                        updateState {
                            return $0.withUpdatedTerminatingOtherSessions(false)
                        }
                    }))
                })
            ]),
            ActionSheetItemGroup(items: [ActionSheetButtonItem(title: "Cancel", action: { dismissAction() })])
            ])
        presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
    })
    
    let sessionsSignal: Signal<[RecentAccountSession]?, NoError> = .single(nil) |> then(requestRecentAccountSessions(account: account) |> map { Optional($0) })
    
    sessionsPromise.set(sessionsSignal)
    
    var previousSessions: [RecentAccountSession]?
    
    let signal = combineLatest(statePromise.get(), sessionsPromise.get())
        |> deliverOnMainQueue
        |> map { state, sessions -> (ItemListControllerState, (ItemListNodeState<RecentSessionsEntry>, RecentSessionsEntry.ItemGenerationArguments)) in
            var rightNavigationButton: ItemListNavigationButton?
            if let sessions = sessions, sessions.count > 1 {
                if state.terminatingOtherSessions {
                    rightNavigationButton = ItemListNavigationButton(title: "", style: .activity, enabled: true, action: {})
                } else if state.editing {
                    rightNavigationButton = ItemListNavigationButton(title: "Done", style: .bold, enabled: true, action: {
                        updateState { state in
                            return state.withUpdatedEditing(false)
                        }
                    })
                } else {
                    rightNavigationButton = ItemListNavigationButton(title: "Edit", style: .regular, enabled: true, action: {
                        updateState { state in
                            return state.withUpdatedEditing(true)
                        }
                    })
                }
            }
            
            var emptyStateItem: ItemListControllerEmptyStateItem?
            if sessions == nil {
                emptyStateItem = ItemListLoadingIndicatorEmptyStateItem()
            }
            
            let previous = previousSessions
            previousSessions = sessions
            
            let controllerState = ItemListControllerState(title: "Active Sessions", leftNavigationButton: nil, rightNavigationButton: rightNavigationButton, animateChanges: true)
            let listState = ItemListNodeState(entries: recentSessionsControllerEntries(state: state, sessions: sessions), style: .blocks, emptyStateItem: emptyStateItem, animateChanges: previous != nil && sessions != nil && previous!.count >= sessions!.count)
            
            return (controllerState, (listState, arguments))
        } |> afterDisposed {
            actionsDisposable.dispose()
    }
    
    let controller = ItemListController(signal)
    presentControllerImpl = { [weak controller] c, p in
        if let controller = controller {
            controller.present(c, in: .window, with: p)
        }
    }
    return controller
}
