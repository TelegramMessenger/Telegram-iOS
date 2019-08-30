import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import AccountContext

private final class RecentSessionsControllerArguments {
    let account: Account
    
    let setSessionIdWithRevealedOptions: (Int64?, Int64?) -> Void
    let removeSession: (Int64) -> Void
    let terminateOtherSessions: () -> Void
    
    let removeWebSession: (Int64) -> Void
    let terminateAllWebSessions: () -> Void
    
    init(account: Account, setSessionIdWithRevealedOptions: @escaping (Int64?, Int64?) -> Void, removeSession: @escaping (Int64) -> Void, terminateOtherSessions: @escaping () -> Void, removeWebSession: @escaping (Int64) -> Void, terminateAllWebSessions: @escaping () -> Void) {
        self.account = account
        self.setSessionIdWithRevealedOptions = setSessionIdWithRevealedOptions
        self.removeSession = removeSession
        self.terminateOtherSessions = terminateOtherSessions
        
        self.removeWebSession = removeWebSession
        self.terminateAllWebSessions = terminateAllWebSessions
    }
}

private enum RecentSessionsMode: Int {
    case sessions
    case websites
}

private enum RecentSessionsSection: Int32 {
    case currentSession
    case pendingSessions
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
    case currentSessionHeader(PresentationTheme, String)
    case currentSession(PresentationTheme, PresentationStrings, PresentationDateTimeFormat, RecentAccountSession)
    case terminateOtherSessions(PresentationTheme, String)
    case terminateAllWebSessions(PresentationTheme, String)
    case currentSessionInfo(PresentationTheme, String)
    case pendingSessionsHeader(PresentationTheme, String)
    case pendingSession(index: Int32, theme: PresentationTheme, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat, session: RecentAccountSession, enabled: Bool, editing: Bool, revealed: Bool)
    case pendingSessionsInfo(PresentationTheme, String)
    case otherSessionsHeader(PresentationTheme, String)
    case session(index: Int32, theme: PresentationTheme, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat, session: RecentAccountSession, enabled: Bool, editing: Bool, revealed: Bool)
    case website(index: Int32, theme: PresentationTheme, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat, nameDisplayOrder: PresentationPersonNameOrder, website: WebAuthorization, peer: Peer?, enabled: Bool, editing: Bool, revealed: Bool)
    
    var section: ItemListSectionId {
        switch self {
            case .currentSessionHeader, .currentSession, .terminateOtherSessions, .terminateAllWebSessions, .currentSessionInfo:
                return RecentSessionsSection.currentSession.rawValue
            case .pendingSessionsHeader, .pendingSession, .pendingSessionsInfo:
                return RecentSessionsSection.pendingSessions.rawValue
            case .otherSessionsHeader, .session, .website:
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
            case .terminateAllWebSessions:
                return .index(3)
            case .currentSessionInfo:
                return .index(4)
            case .pendingSessionsHeader:
                return .index(5)
            case let .pendingSession(_, _, _, _, session, _, _, _):
                return .session(session.hash)
            case .pendingSessionsInfo:
                return .index(6)
            case .otherSessionsHeader:
                return .index(7)
            case let .session(_, _, _, _, session, _, _, _):
                return .session(session.hash)
            case let .website(_, _, _, _, _, website, _, _, _, _):
                return .session(website.hash)
        }
    }
    
    static func ==(lhs: RecentSessionsEntry, rhs: RecentSessionsEntry) -> Bool {
        switch lhs {
            case let .currentSessionHeader(lhsTheme, lhsText):
                if case let .currentSessionHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .terminateOtherSessions(lhsTheme, lhsText):
                if case let .terminateOtherSessions(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .terminateAllWebSessions(lhsTheme, lhsText):
                if case let .terminateAllWebSessions(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .currentSessionInfo(lhsTheme, lhsText):
                if case let .currentSessionInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .pendingSessionsHeader(lhsTheme, lhsText):
                if case let .pendingSessionsHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .pendingSession(lhsIndex, lhsTheme, lhsStrings, lhsDateTimeFormat, lhsSession, lhsEnabled, lhsEditing, lhsRevealed):
                if case let .pendingSession(rhsIndex, rhsTheme, rhsStrings, rhsDateTimeFormat, rhsSession, rhsEnabled, rhsEditing, rhsRevealed) = rhs, lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsDateTimeFormat == rhsDateTimeFormat, lhsSession == rhsSession, lhsEnabled == rhsEnabled, lhsEditing == rhsEditing, lhsRevealed == rhsRevealed {
                    return true
                } else {
                    return false
                }
            case let .pendingSessionsInfo(lhsTheme, lhsText):
                if case let .pendingSessionsInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .otherSessionsHeader(lhsTheme, lhsText):
                if case let .otherSessionsHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .currentSession(lhsTheme, lhsStrings, lhsDateTimeFormat, lhsSession):
                if case let .currentSession(rhsTheme, rhsStrings, rhsDateTimeFormat, rhsSession) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsDateTimeFormat == rhsDateTimeFormat, lhsSession == rhsSession {
                    return true
                } else {
                    return false
                }
            case let .session(lhsIndex, lhsTheme, lhsStrings, lhsDateTimeFormat, lhsSession, lhsEnabled, lhsEditing, lhsRevealed):
                if case let .session(rhsIndex, rhsTheme, rhsStrings, rhsDateTimeFormat, rhsSession, rhsEnabled, rhsEditing, rhsRevealed) = rhs, lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsDateTimeFormat == rhsDateTimeFormat, lhsSession == rhsSession, lhsEnabled == rhsEnabled, lhsEditing == rhsEditing, lhsRevealed == rhsRevealed {
                    return true
                } else {
                    return false
                }
            case let .website(lhsIndex, lhsTheme, lhsStrings, lhsDateTimeFormat, lhsNameOrder, lhsWebsite, lhsPeer, lhsEnabled, lhsEditing, lhsRevealed):
                if case let .website(rhsIndex, rhsTheme, rhsStrings, rhsDateTimeFormat, rhsNameOrder, rhsWebsite, rhsPeer, rhsEnabled, rhsEditing, rhsRevealed) = rhs, lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsDateTimeFormat == rhsDateTimeFormat, lhsNameOrder == rhsNameOrder, lhsWebsite == rhsWebsite, arePeersEqual(lhsPeer, rhsPeer), lhsEnabled == rhsEnabled, lhsEditing == rhsEditing, lhsRevealed == rhsRevealed {
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
                    if case .pendingSession = rhs, lhsIndex > 5 {
                        return false
                    } else {
                        return true
                    }
                }
            case .session:
                switch lhs {
                    case let .session(lhsIndex, _, _, _, _, _, _, _):
                        if case let .session(rhsIndex, _, _, _, _, _, _, _) = rhs {
                            return lhsIndex <= rhsIndex
                        } else {
                            return false
                        }
                    case let .pendingSession(lhsIndex, _, _, _, _, _, _, _):
                        if case let .pendingSession(rhsIndex, _, _, _, _, _, _, _) = rhs {
                            return lhsIndex <= rhsIndex
                        } else if case .session = rhs {
                            return true
                        } else {
                            if case let .index(rhsIndex) = rhs.stableId {
                                return rhsIndex == 6
                            } else {
                                return false
                            }
                        }
                    case let .website(lhsIndex, _, _, _, _, _, _, _, _, _):
                        if case let .website(rhsIndex, _, _, _, _, _, _, _, _, _) = rhs {
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
            case let .currentSessionHeader(theme, text):
                return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
            case let .currentSession(theme, strings, dateTimeFormat, session):
                return ItemListRecentSessionItem(theme: theme, strings: strings, dateTimeFormat: dateTimeFormat, session: session, enabled: true, editable: false, editing: false, revealed: false, sectionId: self.section, setSessionIdWithRevealedOptions: { _, _ in
                }, removeSession: { _ in
                })
            case let .terminateOtherSessions(theme, text):
                return ItemListActionItem(theme: theme, title: text, kind: .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    arguments.terminateOtherSessions()
                })
            case let .terminateAllWebSessions(theme, text):
                return ItemListActionItem(theme: theme, title: text, kind: .destructive, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    arguments.terminateAllWebSessions()
                })
            case let .currentSessionInfo(theme, text):
                return ItemListTextItem(theme: theme, text: .plain(text), sectionId: self.section)
            case let .pendingSessionsHeader(theme, text):
                return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
            case let .pendingSession(_, theme, strings, dateTimeFormat, session, enabled, editing, revealed):
                return ItemListRecentSessionItem(theme: theme, strings: strings, dateTimeFormat: dateTimeFormat, session: session, enabled: enabled, editable: true, editing: editing, revealed: revealed, sectionId: self.section, setSessionIdWithRevealedOptions: { previousId, id in
                    arguments.setSessionIdWithRevealedOptions(previousId, id)
                }, removeSession: { id in
                    arguments.removeSession(id)
                })
            case let .pendingSessionsInfo(theme, text):
                return ItemListTextItem(theme: theme, text: .plain(text), sectionId: self.section)
            case let .otherSessionsHeader(theme, text):
                return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
            case let .session(_, theme, strings, dateTimeFormat, session, enabled, editing, revealed):
                return ItemListRecentSessionItem(theme: theme, strings: strings, dateTimeFormat: dateTimeFormat, session: session, enabled: enabled, editable: true, editing: editing, revealed: revealed, sectionId: self.section, setSessionIdWithRevealedOptions: { previousId, id in
                    arguments.setSessionIdWithRevealedOptions(previousId, id)
                }, removeSession: { id in
                    arguments.removeSession(id)
                })
            case let .website(_, theme, strings, dateTimeFormat, nameDisplayOrder, website, peer, enabled, editing, revealed):
                return ItemListWebsiteItem(account: arguments.account, theme: theme, strings: strings, dateTimeFormat: dateTimeFormat, nameDisplayOrder: nameDisplayOrder, website: website, peer: peer, enabled: enabled, editing: editing, revealed: revealed, sectionId: self.section, setSessionIdWithRevealedOptions: { previousId, id in
                    arguments.setSessionIdWithRevealedOptions(previousId, id)
                }, removeSession: { id in
                    arguments.removeWebSession(id)
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

private func recentSessionsControllerEntries(presentationData: PresentationData, state: RecentSessionsControllerState, sessionsState: ActiveSessionsContextState) -> [RecentSessionsEntry] {
    var entries: [RecentSessionsEntry] = []
    
    if !sessionsState.sessions.isEmpty {
        var existingSessionIds = Set<Int64>()
        entries.append(.currentSessionHeader(presentationData.theme, presentationData.strings.AuthSessions_CurrentSession))
        if let index = sessionsState.sessions.firstIndex(where: { $0.hash == 0 }) {
            existingSessionIds.insert(sessionsState.sessions[index].hash)
            entries.append(.currentSession(presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, sessionsState.sessions[index]))
        }
        
        if sessionsState.sessions.count > 1 {
            entries.append(.terminateOtherSessions(presentationData.theme, presentationData.strings.AuthSessions_TerminateOtherSessions))
            entries.append(.currentSessionInfo(presentationData.theme, presentationData.strings.AuthSessions_TerminateOtherSessionsHelp))
        
            let filteredPendingSessions: [RecentAccountSession] = sessionsState.sessions.filter({ $0.flags.contains(.passwordPending) })
            if !filteredPendingSessions.isEmpty {
                entries.append(.pendingSessionsHeader(presentationData.theme, presentationData.strings.AuthSessions_IncompleteAttempts))
                for i in 0 ..< filteredPendingSessions.count {
                    if !existingSessionIds.contains(filteredPendingSessions[i].hash) {
                        existingSessionIds.insert(filteredPendingSessions[i].hash)
                        entries.append(.pendingSession(index: Int32(i), theme: presentationData.theme, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat, session: filteredPendingSessions[i], enabled: state.removingSessionId != filteredPendingSessions[i].hash && !state.terminatingOtherSessions, editing: state.editing, revealed: state.sessionIdWithRevealedOptions == filteredPendingSessions[i].hash))
                    }
                }
                entries.append(.pendingSessionsInfo(presentationData.theme, presentationData.strings.AuthSessions_IncompleteAttemptsInfo))
            }
            
            entries.append(.otherSessionsHeader(presentationData.theme, presentationData.strings.AuthSessions_OtherSessions))
            
            let filteredSessions: [RecentAccountSession] = sessionsState.sessions.sorted(by: { lhs, rhs in
                return lhs.activityDate > rhs.activityDate
            })
            
            for i in 0 ..< filteredSessions.count {
                if !existingSessionIds.contains(filteredSessions[i].hash) {
                    existingSessionIds.insert(filteredSessions[i].hash)
                    entries.append(.session(index: Int32(i), theme: presentationData.theme, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat, session: filteredSessions[i], enabled: state.removingSessionId != filteredSessions[i].hash && !state.terminatingOtherSessions, editing: state.editing, revealed: state.sessionIdWithRevealedOptions == filteredSessions[i].hash))
                }
            }
        }
    }
    
    return entries
}

private func recentSessionsControllerEntries(presentationData: PresentationData, state: RecentSessionsControllerState, websites: [WebAuthorization]?, peers: [PeerId : Peer]?) -> [RecentSessionsEntry] {
    var entries: [RecentSessionsEntry] = []
    
    if let websites = websites, let peers = peers {
        var existingSessionIds = Set<Int64>()
        if websites.count > 0 {
            entries.append(.terminateAllWebSessions(presentationData.theme, presentationData.strings.AuthSessions_LogOutApplications))
            entries.append(.currentSessionInfo(presentationData.theme, presentationData.strings.AuthSessions_LogOutApplicationsHelp))
            
            entries.append(.otherSessionsHeader(presentationData.theme, presentationData.strings.AuthSessions_LoggedInWithTelegram))
            
            let filteredWebsites: [WebAuthorization] = websites.sorted(by: { lhs, rhs in
                return lhs.dateActive > rhs.dateActive
            })
            
            for i in 0 ..< filteredWebsites.count {
                let website = websites[i]
                if !existingSessionIds.contains(website.hash) {
                    existingSessionIds.insert(website.hash)
                    entries.append(.website(index: Int32(i), theme: presentationData.theme, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat, nameDisplayOrder: presentationData.nameDisplayOrder, website: website, peer: peers[website.botId], enabled: state.removingSessionId != website.hash && !state.terminatingOtherSessions, editing: state.editing, revealed: state.sessionIdWithRevealedOptions == website.hash))
                }
            }
        }
    }
    
    return entries
}

public func recentSessionsController(context: AccountContext, activeSessionsContext: ActiveSessionsContext) -> ViewController {
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
    
    let mode = ValuePromise<RecentSessionsMode>(.sessions)
    let websitesPromise = Promise<([WebAuthorization], [PeerId : Peer])?>(nil)
    
    let arguments = RecentSessionsControllerArguments(account: context.account, setSessionIdWithRevealedOptions: { sessionId, fromSessionId in
        updateState { state in
            if (sessionId == nil && fromSessionId == state.sessionIdWithRevealedOptions) || (sessionId != nil && fromSessionId == nil) {
                return state.withUpdatedSessionIdWithRevealedOptions(sessionId)
            } else {
                return state
            }
        }
    }, removeSession: { sessionId in
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let controller = ActionSheetController(presentationTheme: presentationData.theme)
        let dismissAction: () -> Void = { [weak controller] in
            controller?.dismissAnimated()
        }
        controller.setItemGroups([
            ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: presentationData.strings.AuthSessions_TerminateSession, color: .destructive, action: {
                    dismissAction()
                    
                    updateState {
                        return $0.withUpdatedRemovingSessionId(sessionId)
                    }
                    
                    removeSessionDisposable.set((activeSessionsContext.remove(hash: sessionId)
                    |> deliverOnMainQueue).start(error: { _ in
                        updateState {
                            return $0.withUpdatedRemovingSessionId(nil)
                        }
                    }, completed: {
                        updateState {
                            return $0.withUpdatedRemovingSessionId(nil)
                        }
                        context.sharedContext.updateNotificationTokensRegistration()
                    }))
                })
            ]),
            ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { dismissAction() })])
        ])
        presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
    }, terminateOtherSessions: {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let controller = ActionSheetController(presentationTheme: presentationData.theme)
        let dismissAction: () -> Void = { [weak controller] in
            controller?.dismissAnimated()
        }
        controller.setItemGroups([
            ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: presentationData.strings.AuthSessions_TerminateOtherSessions, color: .destructive, action: {
                    dismissAction()
                    
                    updateState {
                        return $0.withUpdatedTerminatingOtherSessions(true)
                    }
                    
                    terminateOtherSessionsDisposable.set((activeSessionsContext.removeOther()
                    |> deliverOnMainQueue).start(error: { _ in
                        updateState {
                            return $0.withUpdatedTerminatingOtherSessions(false)
                        }
                    }, completed: {
                        updateState {
                            return $0.withUpdatedTerminatingOtherSessions(false)
                        }
                        context.sharedContext.updateNotificationTokensRegistration()
                    }))
                })
            ]),
            ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { dismissAction() })])
            ])
        presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
    }, removeWebSession: { sessionId in
        updateState {
            return $0.withUpdatedRemovingSessionId(sessionId)
        }
        
        let applySessions: Signal<Void, NoError> = websitesPromise.get()
            |> filter { $0 != nil }
            |> take(1)
            |> deliverOnMainQueue
            |> mapToSignal { websitesAndPeers -> Signal<Void, NoError> in
                if let websites = websitesAndPeers?.0, let peers = websitesAndPeers?.1 {
                    var updatedWebsites = websites
                    for i in 0 ..< updatedWebsites.count {
                        if updatedWebsites[i].hash == sessionId {
                            updatedWebsites.remove(at: i)
                            break
                        }
                    }
                    
                    if updatedWebsites.isEmpty {
                        mode.set(.sessions)
                    }
                    websitesPromise.set(.single((updatedWebsites, peers)))
                }
                
                return .complete()
        }
        
        removeSessionDisposable.set(((terminateWebSession(network: context.account.network, hash: sessionId)
            |> mapToSignal { _ -> Signal<Void, NoError> in
                return .complete()
            }) |> then(applySessions) |> deliverOnMainQueue).start(error: { _ in
            updateState {
                return $0.withUpdatedRemovingSessionId(nil)
            }
        }, completed: {
            updateState {
                return $0.withUpdatedRemovingSessionId(nil)
            }
        }))
    }, terminateAllWebSessions: {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let controller = ActionSheetController(presentationTheme: presentationData.theme)
        let dismissAction: () -> Void = { [weak controller] in
            controller?.dismissAnimated()
        }
        controller.setItemGroups([
            ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: presentationData.strings.AuthSessions_LogOutApplications, color: .destructive, action: {
                    dismissAction()
                    
                    updateState {
                        return $0.withUpdatedTerminatingOtherSessions(true)
                    }
                    
                    terminateOtherSessionsDisposable.set((terminateAllWebSessions(network: context.account.network) |> deliverOnMainQueue).start(error: { _ in
                        updateState {
                            return $0.withUpdatedTerminatingOtherSessions(false)
                        }
                    }, completed: {
                        updateState {
                            return $0.withUpdatedTerminatingOtherSessions(false)
                        }
                        mode.set(.sessions)
                        websitesPromise.set(.single(([], [:])))
                    }))
                })
                ]),
            ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { dismissAction() })])
            ])
        presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
    })
    
    let websitesSignal: Signal<([WebAuthorization], [PeerId : Peer])?, NoError> = .single(nil) |> then(webSessions(network: context.account.network) |> map(Optional.init))
    websitesPromise.set(websitesSignal)
    
    let previousMode = Atomic<RecentSessionsMode>(value: .sessions)
    
    let signal = combineLatest(context.sharedContext.presentationData, mode.get(), statePromise.get(), activeSessionsContext.state, websitesPromise.get())
    |> deliverOnMainQueue
    |> map { presentationData, mode, state, sessionsState, websitesAndPeers -> (ItemListControllerState, (ItemListNodeState<RecentSessionsEntry>, RecentSessionsEntry.ItemGenerationArguments)) in
        var rightNavigationButton: ItemListNavigationButton?
        let websites = websitesAndPeers?.0
        let peers = websitesAndPeers?.1
        
        if sessionsState.sessions.count > 1 {
            if state.terminatingOtherSessions {
                rightNavigationButton = ItemListNavigationButton(content: .none, style: .activity, enabled: true, action: {})
            } else if state.editing {
                rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Done), style: .bold, enabled: true, action: {
                    updateState { state in
                        return state.withUpdatedEditing(false)
                    }
                })
            } else {
                rightNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Edit), style: .regular, enabled: true, action: {
                    updateState { state in
                        return state.withUpdatedEditing(true)
                    }
                })
            }
        }
        
        var emptyStateItem: ItemListControllerEmptyStateItem?
        if sessionsState.sessions.isEmpty {
            emptyStateItem = ItemListLoadingIndicatorEmptyStateItem(theme: presentationData.theme)
        } else if sessionsState.sessions.count == 1 && mode == .sessions {
            emptyStateItem = RecentSessionsEmptyStateItem(theme: presentationData.theme, strings: presentationData.strings)
        }
        
        let title: ItemListControllerTitle
        let entries: [RecentSessionsEntry]
        if let websites = websites, !websites.isEmpty {
            title = .sectionControl([presentationData.strings.AuthSessions_Sessions, presentationData.strings.AuthSessions_LoggedIn], mode.rawValue)
        } else {
            title = .text(presentationData.strings.AuthSessions_Title)
        }
        
        var animateChanges = true
        switch (mode, websites, peers) {
            case (.websites, let websites, let peers):
                entries = recentSessionsControllerEntries(presentationData: presentationData, state: state, websites: websites, peers: peers)
            default:
                entries = recentSessionsControllerEntries(presentationData: presentationData, state: state, sessionsState: sessionsState)
        }
        
        let previousMode = previousMode.swap(mode)
        var crossfadeState = false
        
        if previousMode != mode {
            crossfadeState = true
            animateChanges = false
        }
        
        let controllerState = ItemListControllerState(theme: presentationData.theme, title: title, leftNavigationButton: nil, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: true)
        let listState = ItemListNodeState(entries: entries, style: .blocks, emptyStateItem: emptyStateItem, crossfadeState: crossfadeState, animateChanges: animateChanges, scrollEnabled: emptyStateItem == nil)
        
        return (controllerState, (listState, arguments))
    } |> afterDisposed {
        actionsDisposable.dispose()
    }
    
    let controller = ItemListController(context: context, state: signal)
    controller.titleControlValueChanged = { [weak mode] index in
        mode?.set(index == 0 ? .sessions : .websites)
    }
    presentControllerImpl = { [weak controller] c, p in
        if let controller = controller {
            controller.present(c, in: .window(.root), with: p)
        }
    }
    
    return controller
}
