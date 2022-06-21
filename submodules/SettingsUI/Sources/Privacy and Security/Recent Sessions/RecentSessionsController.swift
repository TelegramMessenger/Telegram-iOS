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
import AuthTransferUI
import ItemListPeerActionItem
import DeviceAccess
import QrCodeUI

private final class RecentSessionsControllerArguments {
    let context: AccountContext
    
    let setSessionIdWithRevealedOptions: (Int64?, Int64?) -> Void
    let removeSession: (Int64) -> Void
    let terminateOtherSessions: () -> Void
    
    let openSession: (RecentAccountSession) -> Void
    let openWebSession: (WebAuthorization, Peer?) -> Void
    
    let removeWebSession: (Int64) -> Void
    let terminateAllWebSessions: () -> Void

    let addDevice: () -> Void
    
    let openOtherAppsUrl: () -> Void
    let setupAuthorizationTTL: () -> Void
    
    let openDesktopLink: () -> Void
    let openWebLink: () -> Void
    
    init(context: AccountContext, setSessionIdWithRevealedOptions: @escaping (Int64?, Int64?) -> Void, removeSession: @escaping (Int64) -> Void, terminateOtherSessions: @escaping () -> Void, openSession: @escaping (RecentAccountSession) -> Void, openWebSession: @escaping (WebAuthorization, Peer?) -> Void, removeWebSession: @escaping (Int64) -> Void, terminateAllWebSessions: @escaping () -> Void, addDevice: @escaping () -> Void, openOtherAppsUrl: @escaping () -> Void, setupAuthorizationTTL: @escaping () -> Void, openDesktopLink: @escaping () -> Void, openWebLink: @escaping () -> Void) {
        self.context = context
        self.setSessionIdWithRevealedOptions = setSessionIdWithRevealedOptions
        self.removeSession = removeSession
        self.terminateOtherSessions = terminateOtherSessions
        
        self.openSession = openSession
        self.openWebSession = openWebSession
        
        self.removeWebSession = removeWebSession
        self.terminateAllWebSessions = terminateAllWebSessions
        
        self.addDevice = addDevice
        
        self.openOtherAppsUrl = openOtherAppsUrl
        
        self.setupAuthorizationTTL = setupAuthorizationTTL
        
        self.openDesktopLink = openDesktopLink
        self.openWebLink = openWebLink
    }
}

private enum RecentSessionsMode: Int {
    case sessions
    case websites
}

private enum RecentSessionsSection: Int32 {
    case header
    case currentSession
    case pendingSessions
    case otherSessions
    case ttl
}

private enum RecentSessionsEntryStableId: Hashable {
    case session(Int64)
    case index(Int32)
    case devicesInfo
    case ttl(Int32)
}

private struct SortIndex: Comparable {
    var section: Int
    var item: Int

    static func <(lhs: SortIndex, rhs: SortIndex) -> Bool {
        if lhs.section != rhs.section {
            return lhs.section < rhs.section
        }
        return lhs.item < rhs.item
    }
}

private enum RecentSessionsEntry: ItemListNodeEntry {
    case header(SortIndex, String)
    case currentSessionHeader(SortIndex, String)
    case currentSession(SortIndex, PresentationStrings, PresentationDateTimeFormat, RecentAccountSession)
    case terminateOtherSessions(SortIndex, String)
    case terminateAllWebSessions(SortIndex, String)
    case currentAddDevice(SortIndex, String)
    case currentSessionInfo(SortIndex, String)
    case pendingSessionsHeader(SortIndex, String)
    case pendingSession(index: Int32, sortIndex: SortIndex, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat, session: RecentAccountSession, enabled: Bool, editing: Bool, revealed: Bool)
    case pendingSessionsInfo(SortIndex, String)
    case otherSessionsHeader(SortIndex, String)
    case addDevice(SortIndex, String)
    case session(index: Int32, sortIndex: SortIndex, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat, session: RecentAccountSession, enabled: Bool, editing: Bool, revealed: Bool)
    case website(index: Int32, sortIndex: SortIndex, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat, nameDisplayOrder: PresentationPersonNameOrder, website: WebAuthorization, peer: Peer?, enabled: Bool, editing: Bool, revealed: Bool)
    case devicesInfo(SortIndex, String)
    case ttlHeader(SortIndex, String)
    case ttlTimeout(SortIndex, String, String)
    
    var section: ItemListSectionId {
        switch self {
            case .header:
                return RecentSessionsSection.header.rawValue
            case .currentSessionHeader, .currentSession, .terminateOtherSessions, .terminateAllWebSessions, .currentAddDevice, .currentSessionInfo:
                return RecentSessionsSection.currentSession.rawValue
            case .pendingSessionsHeader, .pendingSession, .pendingSessionsInfo:
                return RecentSessionsSection.pendingSessions.rawValue
            case .otherSessionsHeader, .addDevice, .session, .website, .devicesInfo:
                return RecentSessionsSection.otherSessions.rawValue
            case .ttlHeader, .ttlTimeout:
                return RecentSessionsSection.ttl.rawValue
        }
    }
    
    var stableId: RecentSessionsEntryStableId {
        switch self {
        case .header:
            return .index(0)
        case .currentSessionHeader:
            return .index(1)
        case .currentSession:
            return .index(2)
        case .terminateOtherSessions:
            return .index(3)
        case .terminateAllWebSessions:
            return .index(4)
        case .currentAddDevice:
            return .index(5)
        case .currentSessionInfo:
            return .index(6)
        case .pendingSessionsHeader:
            return .index(7)
        case let .pendingSession(_, _, _, _, session, _, _, _):
            return .session(session.hash)
        case .pendingSessionsInfo:
            return .index(8)
        case .otherSessionsHeader:
            return .index(9)
        case .addDevice:
            return .index(10)
        case let .session(_, _, _, _, session, _, _, _):
            return .session(session.hash)
        case let .website(_, _, _, _, _, website, _, _, _, _):
            return .session(website.hash)
        case .devicesInfo:
            return .devicesInfo
        case .ttlHeader:
            return .index(11)
        case .ttlTimeout:
            return .index(12)
        }
    }

    var sortIndex: SortIndex {
        switch self {
        case let .header(index, _):
            return index
        case let .currentSessionHeader(index, _):
            return index
        case let .currentSession(index, _, _, _):
            return index
        case let .terminateOtherSessions(index, _):
            return index
        case let .terminateAllWebSessions(index, _):
            return index
        case let .currentAddDevice(index, _):
            return index
        case let .currentSessionInfo(index, _):
            return index
        case let .pendingSessionsHeader(index, _):
            return index
        case let .pendingSession(_, index, _, _, _, _, _, _):
            return index
        case let .pendingSessionsInfo(index, _):
            return index
        case let .otherSessionsHeader(index, _):
            return index
        case let .addDevice(index, _):
            return index
        case let .session(_, index, _, _, _, _, _, _):
            return index
        case let .website(_, index, _, _, _, _, _, _, _, _):
            return index
        case let .devicesInfo(index, _):
            return index
        case let .ttlHeader(index, _):
            return index
        case let .ttlTimeout(index, _, _):
            return index
        }
    }
    
    static func ==(lhs: RecentSessionsEntry, rhs: RecentSessionsEntry) -> Bool {
        switch lhs {
        case let .header(lhsSortIndex, lhsText):
            if case let .header(rhsSortIndex, rhsText) = rhs, lhsSortIndex == rhsSortIndex, lhsText == rhsText {
                return true
            } else {
                return false
            }
        case let .currentSessionHeader(lhsSortIndex, lhsText):
            if case let .currentSessionHeader(rhsSortIndex, rhsText) = rhs, lhsSortIndex == rhsSortIndex, lhsText == rhsText {
                return true
            } else {
                return false
            }
        case let .terminateOtherSessions(lhsSortIndex, lhsText):
            if case let .terminateOtherSessions(rhsSortIndex, rhsText) = rhs, lhsSortIndex == rhsSortIndex, lhsText == rhsText {
                return true
            } else {
                return false
            }
        case let .terminateAllWebSessions(lhsSortIndex, lhsText):
            if case let .terminateAllWebSessions(rhsSortIndex, rhsText) = rhs, lhsSortIndex == rhsSortIndex, lhsText == rhsText {
                return true
            } else {
                return false
            }
        case let .currentAddDevice(lhsSortIndex, lhsText):
            if case let .currentAddDevice(rhsSortIndex, rhsText) = rhs, lhsSortIndex == rhsSortIndex, lhsText == rhsText {
                return true
            } else {
                return false
            }
        case let .currentSessionInfo(lhsSortIndex, lhsText):
            if case let .currentSessionInfo(rhsSortIndex, rhsText) = rhs, lhsSortIndex == rhsSortIndex, lhsText == rhsText {
                return true
            } else {
                return false
            }
        case let .pendingSessionsHeader(lhsSortIndex, lhsText):
            if case let .pendingSessionsHeader(rhsSortIndex, rhsText) = rhs, lhsSortIndex == rhsSortIndex, lhsText == rhsText {
                return true
            } else {
                return false
            }
        case let .pendingSession(lhsIndex, lhsSortIndex, lhsStrings, lhsDateTimeFormat, lhsSession, lhsEnabled, lhsEditing, lhsRevealed):
            if case let .pendingSession(rhsIndex, rhsSortIndex, rhsStrings, rhsDateTimeFormat, rhsSession, rhsEnabled, rhsEditing, rhsRevealed) = rhs, lhsIndex == rhsIndex, lhsSortIndex == rhsSortIndex, lhsStrings === rhsStrings, lhsDateTimeFormat == rhsDateTimeFormat, lhsSession == rhsSession, lhsEnabled == rhsEnabled, lhsEditing == rhsEditing, lhsRevealed == rhsRevealed {
                return true
            } else {
                return false
            }
        case let .pendingSessionsInfo(lhsSortIndex, lhsText):
            if case let .pendingSessionsInfo(rhsSortIndex, rhsText) = rhs, lhsSortIndex == rhsSortIndex, lhsText == rhsText {
                return true
            } else {
                return false
            }
        case let .otherSessionsHeader(lhsSortIndex, lhsText):
            if case let .otherSessionsHeader(rhsSortIndex, rhsText) = rhs, lhsSortIndex == rhsSortIndex, lhsText == rhsText {
                return true
            } else {
                return false
            }
        case let .addDevice(lhsSortIndex, lhsText):
            if case let .addDevice(rhsSortIndex, rhsText) = rhs, lhsSortIndex == rhsSortIndex, lhsText == rhsText {
                return true
            } else {
                return false
            }
        case let .currentSession(lhsSortIndex, lhsStrings, lhsDateTimeFormat, lhsSession):
            if case let .currentSession(rhsSortIndex, rhsStrings, rhsDateTimeFormat, rhsSession) = rhs, lhsSortIndex == rhsSortIndex, lhsStrings === rhsStrings, lhsDateTimeFormat == rhsDateTimeFormat, lhsSession == rhsSession {
                return true
            } else {
                return false
            }
        case let .session(lhsIndex, lhsSortIndex, lhsStrings, lhsDateTimeFormat, lhsSession, lhsEnabled, lhsEditing, lhsRevealed):
            if case let .session(rhsIndex, rhsSortIndex, rhsStrings, rhsDateTimeFormat, rhsSession, rhsEnabled, rhsEditing, rhsRevealed) = rhs, lhsIndex == rhsIndex, lhsSortIndex == rhsSortIndex, lhsStrings === rhsStrings, lhsDateTimeFormat == rhsDateTimeFormat, lhsSession == rhsSession, lhsEnabled == rhsEnabled, lhsEditing == rhsEditing, lhsRevealed == rhsRevealed {
                return true
            } else {
                return false
            }
        case let .website(lhsIndex, lhsSortIndex, lhsStrings, lhsDateTimeFormat, lhsNameOrder, lhsWebsite, lhsPeer, lhsEnabled, lhsEditing, lhsRevealed):
            if case let .website(rhsIndex, rhsSortIndex, rhsStrings, rhsDateTimeFormat, rhsNameOrder, rhsWebsite, rhsPeer, rhsEnabled, rhsEditing, rhsRevealed) = rhs, lhsIndex == rhsIndex, lhsSortIndex == rhsSortIndex, lhsStrings === rhsStrings, lhsDateTimeFormat == rhsDateTimeFormat, lhsNameOrder == rhsNameOrder, lhsWebsite == rhsWebsite, arePeersEqual(lhsPeer, rhsPeer), lhsEnabled == rhsEnabled, lhsEditing == rhsEditing, lhsRevealed == rhsRevealed {
                return true
            } else {
                return false
            }
        case let .devicesInfo(lhsSortIndex, lhsText):
            if case let .devicesInfo(rhsSortIndex, rhsText) = rhs, lhsSortIndex == rhsSortIndex, lhsText == rhsText {
                return true
            } else {
                return false
            }
        case let .ttlHeader(lhsSortIndex, lhsText):
            if case let .ttlHeader(rhsSortIndex, rhsText) = rhs, lhsSortIndex == rhsSortIndex, lhsText == rhsText {
                return true
            } else {
                return false
            }
        case let .ttlTimeout(lhsSortIndex, lhsText, lhsValue):
            if case let .ttlTimeout(rhsSortIndex, rhsText, rhsValue) = rhs, lhsSortIndex == rhsSortIndex, lhsText == rhsText, lhsValue == rhsValue {
                return true
            } else {
                return false
            }
        }
    }
    
    static func <(lhs: RecentSessionsEntry, rhs: RecentSessionsEntry) -> Bool {
        return lhs.sortIndex < rhs.sortIndex
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! RecentSessionsControllerArguments
        switch self {
        case let .header(_, text):
            return RecentSessionsHeaderItem(context: arguments.context, theme: presentationData.theme, text: text, animationName: "Devices", sectionId: self.section, buttonAction: {
                arguments.addDevice()
            }, linkAction: { action in
                if case let .tap(link) = action {
                    switch link {
                    case "desktop":
                        arguments.openDesktopLink()
                    case "web":
                        arguments.openWebLink()
                    default:
                        break
                    }
                }
            })
        case let .currentSessionHeader(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .currentSession(_, _, dateTimeFormat, session):
            return ItemListRecentSessionItem(presentationData: presentationData, dateTimeFormat: dateTimeFormat, session: session, enabled: true, editable: false, editing: false, revealed: false, sectionId: self.section, setSessionIdWithRevealedOptions: { _, _ in
            }, removeSession: { _ in
            }, action: {
                arguments.openSession(session)
            })
        case let .terminateOtherSessions(_, text):
            return ItemListPeerActionItem(presentationData: presentationData, icon: PresentationResourcesItemList.blockDestructiveIcon(presentationData.theme), title: text, sectionId: self.section, height: .generic, color: .destructive, editing: false, action: {
                arguments.terminateOtherSessions()
            })
        case let .terminateAllWebSessions(_, text):
            return ItemListPeerActionItem(presentationData: presentationData, icon: PresentationResourcesItemList.blockDestructiveIcon(presentationData.theme), title: text, sectionId: self.section, height: .generic, color: .destructive, editing: false, action: {
                arguments.terminateAllWebSessions()
            })
        case let .currentAddDevice(_, text):
            return ItemListPeerActionItem(presentationData: presentationData, icon: PresentationResourcesItemList.addDeviceIcon(presentationData.theme), title: text, sectionId: self.section, height: .generic, color: .accent, editing: false, action: {
                arguments.addDevice()
            })
        case let .currentSessionInfo(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .markdown(text), sectionId: self.section, linkAction: { action in
                switch action {
                case .tap:
                    arguments.openOtherAppsUrl()
                }
            })
        case let .pendingSessionsHeader(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .pendingSession(_, _, _, dateTimeFormat, session, enabled, editing, revealed):
            return ItemListRecentSessionItem(presentationData: presentationData, dateTimeFormat: dateTimeFormat, session: session, enabled: enabled, editable: true, editing: editing, revealed: revealed, sectionId: self.section, setSessionIdWithRevealedOptions: { previousId, id in
                arguments.setSessionIdWithRevealedOptions(previousId, id)
            }, removeSession: { id in
                arguments.removeSession(id)
            }, action: {
                arguments.openSession(session)
            })
        case let .pendingSessionsInfo(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .otherSessionsHeader(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .addDevice(_, text):
            return ItemListPeerActionItem(presentationData: presentationData, icon: PresentationResourcesItemList.addDeviceIcon(presentationData.theme), title: text, sectionId: self.section, height: .generic, color: .accent, editing: false, action: {
                arguments.addDevice()
            })
        case let .session(_, _, _, dateTimeFormat, session, enabled, editing, revealed):
            return ItemListRecentSessionItem(presentationData: presentationData, dateTimeFormat: dateTimeFormat, session: session, enabled: enabled, editable: true, editing: editing, revealed: revealed, sectionId: self.section, setSessionIdWithRevealedOptions: { previousId, id in
                arguments.setSessionIdWithRevealedOptions(previousId, id)
            }, removeSession: { id in
                arguments.removeSession(id)
            }, action: {
                arguments.openSession(session)
            })
        case let .website(_, _, _, dateTimeFormat, nameDisplayOrder, website, peer, enabled, editing, revealed):
            return ItemListWebsiteItem(context: arguments.context, presentationData: presentationData, dateTimeFormat: dateTimeFormat, nameDisplayOrder: nameDisplayOrder, website: website, peer: peer, enabled: enabled, editing: editing, revealed: revealed, sectionId: self.section, setSessionIdWithRevealedOptions: { previousId, id in
                arguments.setSessionIdWithRevealedOptions(previousId, id)
            }, removeSession: { id in
                arguments.removeWebSession(id)
            }, action: {
                arguments.openWebSession(website, peer)
            })
        case let .devicesInfo(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .markdown(text), sectionId: self.section, linkAction: { action in
                switch action {
                case .tap:
                    arguments.openOtherAppsUrl()
                }
            })
        case let .ttlHeader(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .ttlTimeout(_, text, value):
            return ItemListDisclosureItem(presentationData: presentationData, title: text, label: value, sectionId: self.section, style: .blocks, action: {
                arguments.setupAuthorizationTTL()
            }, tag: PrivacyAndSecurityEntryTag.accountTimeout)
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

private func recentSessionsControllerEntries(presentationData: PresentationData, state: RecentSessionsControllerState, sessionsState: ActiveSessionsContextState, enableQRLogin: Bool) -> [RecentSessionsEntry] {
    var entries: [RecentSessionsEntry] = []
    
    entries.append(.header(SortIndex(section: 0, item: 0), presentationData.strings.AuthSessions_HeaderInfo))
    
    if !sessionsState.sessions.isEmpty {
        var existingSessionIds = Set<Int64>()
        entries.append(.currentSessionHeader(SortIndex(section: 1, item: 0), presentationData.strings.AuthSessions_CurrentSession))
        if let index = sessionsState.sessions.firstIndex(where: { $0.hash == 0 }) {
            existingSessionIds.insert(sessionsState.sessions[index].hash)
            entries.append(.currentSession(SortIndex(section: 1, item: 1), presentationData.strings, presentationData.dateTimeFormat, sessionsState.sessions[index]))
        }
        
        var hasAddDevice = false
        if sessionsState.sessions.count > 1 || enableQRLogin {
            if sessionsState.sessions.count > 1 {
                entries.append(.terminateOtherSessions(SortIndex(section: 1, item: 2), presentationData.strings.AuthSessions_TerminateOtherSessions))
                entries.append(.currentSessionInfo(SortIndex(section: 1, item: 3), presentationData.strings.AuthSessions_TerminateOtherSessionsHelp))
            } else if enableQRLogin {
                hasAddDevice = true
//                entries.append(.currentAddDevice(SortIndex(section: 1, item: 4), presentationData.strings.AuthSessions_AddDevice))
                entries.append(.currentSessionInfo(SortIndex(section: 1, item: 5), presentationData.strings.AuthSessions_OtherDevices))
            }
            
            let filteredPendingSessions: [RecentAccountSession] = sessionsState.sessions.filter({ $0.flags.contains(.passwordPending) })
            if !filteredPendingSessions.isEmpty {
                entries.append(.pendingSessionsHeader(SortIndex(section: 1, item: 6), presentationData.strings.AuthSessions_IncompleteAttempts))
                for i in 0 ..< filteredPendingSessions.count {
                    if !existingSessionIds.contains(filteredPendingSessions[i].hash) {
                        existingSessionIds.insert(filteredPendingSessions[i].hash)
                        entries.append(.pendingSession(index: Int32(i), sortIndex: SortIndex(section: 2, item: i), strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat, session: filteredPendingSessions[i], enabled: state.removingSessionId != filteredPendingSessions[i].hash && !state.terminatingOtherSessions, editing: state.editing, revealed: state.sessionIdWithRevealedOptions == filteredPendingSessions[i].hash))
                    }
                }
                entries.append(.pendingSessionsInfo(SortIndex(section: 3, item: 0), presentationData.strings.AuthSessions_IncompleteAttemptsInfo))
            }
            
            if sessionsState.sessions.count > 1 {
                entries.append(.otherSessionsHeader(SortIndex(section: 4, item: 0), presentationData.strings.AuthSessions_OtherSessions))
            }
            
//            if enableQRLogin && !hasAddDevice {
//                entries.append(.addDevice(SortIndex(section: 4, item: 1), presentationData.strings.AuthSessions_AddDevice))
//            }
            
            let filteredSessions: [RecentAccountSession] = sessionsState.sessions.sorted(by: { lhs, rhs in
                return lhs.activityDate > rhs.activityDate
            })
            
            for i in 0 ..< filteredSessions.count {
                if !existingSessionIds.contains(filteredSessions[i].hash) {
                    existingSessionIds.insert(filteredSessions[i].hash)
                    entries.append(.session(index: Int32(i), sortIndex: SortIndex(section: 5, item: i), strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat, session: filteredSessions[i], enabled: state.removingSessionId != filteredSessions[i].hash && !state.terminatingOtherSessions, editing: state.editing, revealed: state.sessionIdWithRevealedOptions == filteredSessions[i].hash))
                }
            }
            
            if enableQRLogin && !hasAddDevice {
                entries.append(.devicesInfo(SortIndex(section: 6, item: 0), presentationData.strings.AuthSessions_OtherDevices))
            }
        }
        
        entries.append(.ttlHeader(SortIndex(section: 7, item: 0), presentationData.strings.AuthSessions_TerminateIfAwayTitle.uppercased()))
        entries.append(.ttlTimeout(SortIndex(section: 7, item: 1), presentationData.strings.AuthSessions_TerminateIfAwayFor, timeIntervalString(strings: presentationData.strings, value: sessionsState.ttlDays * 24 * 60 * 60)))
    }
    
    return entries
}

private func recentSessionsControllerEntries(presentationData: PresentationData, state: RecentSessionsControllerState, websites: [WebAuthorization]?, peers: [PeerId : Peer]?) -> [RecentSessionsEntry] {
    var entries: [RecentSessionsEntry] = []
    
    if let websites = websites, let peers = peers {
        var existingSessionIds = Set<Int64>()
        if websites.count > 0 {
            entries.append(.terminateAllWebSessions(SortIndex(section: 0, item: 0), presentationData.strings.AuthSessions_LogOutApplications))
            entries.append(.currentSessionInfo(SortIndex(section: 0, item: 1), presentationData.strings.AuthSessions_LogOutApplicationsHelp))
            
            entries.append(.otherSessionsHeader(SortIndex(section: 0, item: 2), presentationData.strings.AuthSessions_LoggedInWithTelegram))
            
            let filteredWebsites: [WebAuthorization] = websites.sorted(by: { lhs, rhs in
                return lhs.dateActive > rhs.dateActive
            })
            
            for i in 0 ..< filteredWebsites.count {
                let website = websites[i]
                if !existingSessionIds.contains(website.hash) {
                    existingSessionIds.insert(website.hash)
                    entries.append(.website(index: Int32(i), sortIndex: SortIndex(section: 1, item: i), strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat, nameDisplayOrder: presentationData.nameDisplayOrder, website: website, peer: peers[website.botId], enabled: state.removingSessionId != website.hash && !state.terminatingOtherSessions, editing: state.editing, revealed: state.sessionIdWithRevealedOptions == website.hash))
                }
            }
        }
    }
    
    return entries
}

private final class RecentSessionsControllerImpl: ItemListController, RecentSessionsController {
}

public func recentSessionsController(context: AccountContext, activeSessionsContext: ActiveSessionsContext, webSessionsContext: WebSessionsContext, websitesOnly: Bool) -> ViewController & RecentSessionsController {
    let statePromise = ValuePromise(RecentSessionsControllerState(), ignoreRepeated: true)
    let stateValue = Atomic(value: RecentSessionsControllerState())
    let updateState: ((RecentSessionsControllerState) -> RecentSessionsControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    activeSessionsContext.loadMore()
    webSessionsContext.loadMore()
    
    var presentControllerImpl: ((ViewController, ViewControllerPresentationArguments?) -> Void)?
    var pushControllerImpl: ((ViewController) -> Void)?
    var dismissImpl: (() -> Void)?
    
    let actionsDisposable = DisposableSet()
    
    let removeSessionDisposable = MetaDisposable()
    actionsDisposable.add(removeSessionDisposable)
    
    let terminateOtherSessionsDisposable = MetaDisposable()
    actionsDisposable.add(terminateOtherSessionsDisposable)
    
    let didAppearValue = ValuePromise<Bool>(false)
    
    if websitesOnly {
        let autoDismissDisposable = (webSessionsContext.state
        |> filter { !$0.isLoadingMore && $0.sessions.isEmpty }
        |> take(1)
        |> mapToSignal { _ in
            return didAppearValue.get()
            |> filter { $0 }
            |> take(1)
        }
        |> deliverOnMainQueue).start(next: { _ in
            dismissImpl?()
        })
        actionsDisposable.add(autoDismissDisposable)
    }
    
    let mode = ValuePromise<RecentSessionsMode>(websitesOnly ? .websites : .sessions)
    
    let removeSessionImpl: (Int64, @escaping () -> Void) -> Void = { sessionId, completion in
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let controller = ActionSheetController(presentationData: presentationData)
        let dismissAction: () -> Void = { [weak controller] in
            controller?.dismissAnimated()
        }
        controller.setItemGroups([
            ActionSheetItemGroup(items: [
                ActionSheetTextItem(title: presentationData.strings.AuthSessions_TerminateSessionText),
                ActionSheetButtonItem(title: presentationData.strings.AuthSessions_TerminateSession, color: .destructive, action: {
                    dismissAction()
                    completion()
                    
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
    }
    
    let removeWebSessionImpl: (Int64) -> Void = { sessionId in
        updateState {
            return $0.withUpdatedRemovingSessionId(sessionId)
        }
        
        removeSessionDisposable.set(((webSessionsContext.remove(hash: sessionId)
        |> mapToSignal { _ -> Signal<Void, NoError> in
        })
        |> deliverOnMainQueue).start(error: { _ in
        }, completed: {
            updateState {
                return $0.withUpdatedRemovingSessionId(nil)
            }
        }))
    }
    
    let updateAuthorizationTTLDisposable = MetaDisposable()
    actionsDisposable.add(updateAuthorizationTTLDisposable)
    
    let updateSessionDisposable = MetaDisposable()
    actionsDisposable.add(updateSessionDisposable)
    
    let arguments = RecentSessionsControllerArguments(context: context, setSessionIdWithRevealedOptions: { sessionId, fromSessionId in
        updateState { state in
            if (sessionId == nil && fromSessionId == state.sessionIdWithRevealedOptions) || (sessionId != nil && fromSessionId == nil) {
                return state.withUpdatedSessionIdWithRevealedOptions(sessionId)
            } else {
                return state
            }
        }
    }, removeSession: { sessionId in
        removeSessionImpl(sessionId, {})
    }, terminateOtherSessions: {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let controller = ActionSheetController(presentationData: presentationData)
        let dismissAction: () -> Void = { [weak controller] in
            controller?.dismissAnimated()
        }
        controller.setItemGroups([
            ActionSheetItemGroup(items: [
                ActionSheetTextItem(title: presentationData.strings.AuthSessions_TerminateOtherSessionsText),
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
    }, openSession: { session in
        let controller = RecentSessionScreen(context: context, subject: .session(session), updateAcceptSecretChats: { value in
            updateSessionDisposable.set(activeSessionsContext.updateSessionAcceptsSecretChats(session, accepts: value).start())
        }, updateAcceptIncomingCalls: { value in
            updateSessionDisposable.set(activeSessionsContext.updateSessionAcceptsIncomingCalls(session, accepts: value).start())
        }, remove: { completion in
            removeSessionImpl(session.hash, {
                completion()
            })
        })
        presentControllerImpl?(controller, nil)
    }, openWebSession: { session, peer in
        let controller = RecentSessionScreen(context: context, subject: .website(session, peer), updateAcceptSecretChats: { _ in }, updateAcceptIncomingCalls: { _ in }, remove: { completion in
            removeWebSessionImpl(session.hash)
            completion()
        })
        presentControllerImpl?(controller, nil)
    }, removeWebSession: { sessionId in
        removeWebSessionImpl(sessionId)
    }, terminateAllWebSessions: {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let controller = ActionSheetController(presentationData: presentationData)
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
                    
                    terminateOtherSessionsDisposable.set((webSessionsContext.removeAll()
                    |> deliverOnMainQueue).start(error: { _ in
                    }, completed: {
                        updateState {
                            return $0.withUpdatedTerminatingOtherSessions(false)
                        }
                        mode.set(.sessions)
                    }))
                })
            ]),
            ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { dismissAction() })])
            ])
        presentControllerImpl?(controller, ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
    }, addDevice: {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        DeviceAccess.authorizeAccess(to: .camera(.qrCode), presentationData: presentationData, present: { c, a in
            c.presentationArguments = a
            context.sharedContext.mainWindow?.present(c, on: .root)
        }, openSettings: {
            context.sharedContext.applicationBindings.openSettings()
        }, { granted in
            guard granted else {
                return
            }
            pushControllerImpl?(QrCodeScanScreen(context: context, subject: .authTransfer(activeSessionsContext: activeSessionsContext)))
        })
    }, openOtherAppsUrl: {
        context.sharedContext.openExternalUrl(context: context, urlContext: .generic, url: "https://telegram.org/apps", forceExternal: true, presentationData: context.sharedContext.currentPresentationData.with { $0 }, navigationController: nil, dismissInput: {})
    }, setupAuthorizationTTL: {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let controller = ActionSheetController(presentationData: presentationData)
        let dismissAction: () -> Void = { [weak controller] in
            controller?.dismissAnimated()
        }
        let ttlAction: (Int32) -> Void = { ttl in
            updateAuthorizationTTLDisposable.set(activeSessionsContext.updateAuthorizationTTL(days: ttl).start())
        }
        let timeoutValues: [Int32] = [
            7,
            30,
            90,
            180
        ]
        let timeoutItems: [ActionSheetItem] = timeoutValues.map { value in
            return ActionSheetButtonItem(title: timeIntervalString(strings: presentationData.strings, value: value * 24 * 60 * 60), action: {
                dismissAction()
                ttlAction(value)
            })
        }
        controller.setItemGroups([
            ActionSheetItemGroup(items: timeoutItems),
            ActionSheetItemGroup(items: [ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, action: { dismissAction() })])
        ])
        presentControllerImpl?(controller, nil)
    }, openDesktopLink: {
        context.sharedContext.openExternalUrl(context: context, urlContext: .generic, url: "https://getdesktop.telegram.org", forceExternal: true, presentationData: context.sharedContext.currentPresentationData.with { $0 }, navigationController: nil, dismissInput: {})
    }, openWebLink: {
        context.sharedContext.openExternalUrl(context: context, urlContext: .generic, url: "https://web.telegram.org", forceExternal: true, presentationData: context.sharedContext.currentPresentationData.with { $0 }, navigationController: nil, dismissInput: {})
    })
    
    let previousMode = Atomic<RecentSessionsMode>(value: .sessions)
    
    let enableQRLogin = context.account.postbox.preferencesView(keys: [PreferencesKeys.appConfiguration])
    |> map { view -> Bool in
        guard let appConfiguration = view.values[PreferencesKeys.appConfiguration]?.get(AppConfiguration.self) else {
            return false
        }
        guard let data = appConfiguration.data, let enableQR = data["qr_login_camera"] as? Bool, enableQR else {
            return false
        }
        return true
    }
    |> distinctUntilChanged
    
    let signal = combineLatest(context.sharedContext.presentationData, mode.get(), statePromise.get(), activeSessionsContext.state, webSessionsContext.state, enableQRLogin)
    |> deliverOnMainQueue
    |> map { presentationData, mode, state, sessionsState, websitesAndPeers, enableQRLogin -> (ItemListControllerState, (ItemListNodeState, Any)) in
        var rightNavigationButton: ItemListNavigationButton?
        let websites = websitesAndPeers.sessions
        let peers = websitesAndPeers.peers
        
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
        
        let emptyStateItem: ItemListControllerEmptyStateItem? = nil
//        if sessionsState.sessions.count == 1 && mode == .sessions {
//            emptyStateItem = RecentSessionsEmptyStateItem(theme: presentationData.theme, strings: presentationData.strings)
//        } else {
//            emptyStateItem = nil
//        }
        
        let title: ItemListControllerTitle
        let entries: [RecentSessionsEntry]
        if websitesOnly {
            title = .text(presentationData.strings.AuthSessions_LoggedIn)
        } else {
            title = .text(presentationData.strings.AuthSessions_DevicesTitle)
        }
        
        var animateChanges = true
        switch (mode, websites, peers) {
            case (.websites, let websites, let peers):
                entries = recentSessionsControllerEntries(presentationData: presentationData, state: state, websites: websites, peers: peers)
            default:
                entries = recentSessionsControllerEntries(presentationData: presentationData, state: state, sessionsState: sessionsState, enableQRLogin: enableQRLogin)
        }
        
        let previousMode = previousMode.swap(mode)
        var crossfadeState = false
        
        if previousMode != mode {
            crossfadeState = true
            animateChanges = false
        }
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: title, leftNavigationButton: nil, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: true)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, emptyStateItem: emptyStateItem, crossfadeState: crossfadeState, animateChanges: animateChanges, scrollEnabled: emptyStateItem == nil)
        
        return (controllerState, (listState, arguments))
    } |> afterDisposed {
        actionsDisposable.dispose()
    }
    
    let controller = RecentSessionsControllerImpl(context: context, state: signal)
    controller.titleControlValueChanged = { [weak mode] index in
        mode?.set(index == 0 ? .sessions : .websites)
    }
    controller.didAppear = { _ in
        didAppearValue.set(true)
    }
    presentControllerImpl = { [weak controller] c, p in
        if let controller = controller {
            controller.present(c, in: .window(.root), with: p)
        }
    }
    pushControllerImpl = { [weak controller] c in
        controller?.push(c)
    }
    dismissImpl = { [weak controller] in
        controller?.dismiss()
    }
    
    return controller
}
