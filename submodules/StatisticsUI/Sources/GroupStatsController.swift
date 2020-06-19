import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import SyncCore
import MapKit
import TelegramPresentationData
import TelegramUIPreferences
import TelegramStringFormatting
import ItemListUI
import PresentationDataUtils
import AccountContext
import PresentationDataUtils
import AppBundle
import GraphUI
import ItemListPeerItem

private final class GroupStatsControllerArguments {
    let context: AccountContext
    let loadDetailedGraph: (StatsGraph, Int64) -> Signal<StatsGraph?, NoError>
    let openPeer: (PeerId) -> Void
    
    init(context: AccountContext, loadDetailedGraph: @escaping (StatsGraph, Int64) -> Signal<StatsGraph?, NoError>, openPeer: @escaping (PeerId) -> Void) {
        self.context = context
        self.loadDetailedGraph = loadDetailedGraph
        self.openPeer = openPeer
    }
}

private enum StatsSection: Int32 {
    case overview
    case growth
    case members
    case newMembersBySource
    case languages
    case messages
    case actions
    case topHours
    case topPosters
    case topAdmins
    case topInviters
}

private enum StatsEntry: ItemListNodeEntry {
    case overviewTitle(PresentationTheme, String, String)
    case overview(PresentationTheme, GroupStats)
    
    case growthTitle(PresentationTheme, String)
    case growthGraph(PresentationTheme, PresentationStrings, PresentationDateTimeFormat, StatsGraph, ChartType)
    
    case membersTitle(PresentationTheme, String)
    case membersGraph(PresentationTheme, PresentationStrings, PresentationDateTimeFormat, StatsGraph, ChartType)
     
    case newMembersBySourceTitle(PresentationTheme, String)
    case newMembersBySourceGraph(PresentationTheme, PresentationStrings, PresentationDateTimeFormat, StatsGraph, ChartType)
    
    case languagesTitle(PresentationTheme, String)
    case languagesGraph(PresentationTheme, PresentationStrings, PresentationDateTimeFormat, StatsGraph, ChartType)
        
    case messagesTitle(PresentationTheme, String)
    case messagesGraph(PresentationTheme, PresentationStrings, PresentationDateTimeFormat, StatsGraph, ChartType)
    
    case actionsTitle(PresentationTheme, String)
    case actionsGraph(PresentationTheme, PresentationStrings, PresentationDateTimeFormat, StatsGraph, ChartType)
    
    case topHoursTitle(PresentationTheme, String)
    case topHoursGraph(PresentationTheme, PresentationStrings, PresentationDateTimeFormat, StatsGraph, ChartType)
    
    case topPostersTitle(PresentationTheme, String, String)
    case topPoster(Int32, PresentationTheme, PresentationStrings, PresentationDateTimeFormat, Peer, GroupStatsTopPoster)
    
    case topAdminsTitle(PresentationTheme, String, String)
    case topAdmin(Int32, PresentationTheme, PresentationStrings, PresentationDateTimeFormat, Peer, GroupStatsTopAdmin)
    
    case topInvitersTitle(PresentationTheme, String, String)
    case topInviter(Int32, PresentationTheme, PresentationStrings, PresentationDateTimeFormat, Peer, GroupStatsTopInviter)
        
    var section: ItemListSectionId {
        switch self {
            case .overviewTitle, .overview:
                return StatsSection.overview.rawValue
            case .growthTitle, .growthGraph:
                return StatsSection.growth.rawValue
            case .membersTitle, .membersGraph:
                return StatsSection.members.rawValue
            case .newMembersBySourceTitle, .newMembersBySourceGraph:
                return StatsSection.newMembersBySource.rawValue
            case .languagesTitle, .languagesGraph:
                return StatsSection.languages.rawValue
            case .messagesTitle, . messagesGraph:
                return StatsSection.messages.rawValue
            case .actionsTitle, .actionsGraph:
                return StatsSection.actions.rawValue
            case .topHoursTitle, .topHoursGraph:
                return StatsSection.topHours.rawValue
            case .topPostersTitle, .topPoster:
                return StatsSection.topPosters.rawValue
            case .topAdminsTitle, .topAdmin:
                return StatsSection.topAdmins.rawValue
            case .topInvitersTitle, .topInviter:
                return StatsSection.topInviters.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
            case .overviewTitle:
                return 0
            case .overview:
                return 1
            case .growthTitle:
                return 2
            case .growthGraph:
                return 3
            case .membersTitle:
                return 4
            case .membersGraph:
                return 5
            case .newMembersBySourceTitle:
                return 6
            case .newMembersBySourceGraph:
                return 7
            case .languagesTitle:
                return 8
            case .languagesGraph:
                return 9
            case .messagesTitle:
                return 10
            case .messagesGraph:
                return 11
            case .actionsTitle:
                return 12
            case .actionsGraph:
                return 13
            case .topHoursTitle:
                return 14
            case .topHoursGraph:
                return 15
            case .topPostersTitle:
                return 1000
            case let .topPoster(index, _, _, _, _, _):
                return 1001 + index
            case .topAdminsTitle:
                return 2000
            case let .topAdmin(index, _, _, _, _, _):
                return 2001 + index
            case .topInvitersTitle:
                return 3000
            case let .topInviter(index, _, _, _, _, _):
                return 30001 + index
        }
    }
    
    static func ==(lhs: StatsEntry, rhs: StatsEntry) -> Bool {
        switch lhs {
            case let .overviewTitle(lhsTheme, lhsText, lhsDates):
                if case let .overviewTitle(rhsTheme, rhsText, rhsDates) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsDates == rhsDates {
                    return true
                } else {
                    return false
                }
            case let .overview(lhsTheme, lhsStats):
                if case let .overview(rhsTheme, rhsStats) = rhs, lhsTheme === rhsTheme, lhsStats == rhsStats {
                    return true
                } else {
                    return false
                }
            case let .growthTitle(lhsTheme, lhsText):
                if case let .growthTitle(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .growthGraph(lhsTheme, lhsStrings, lhsDateTimeFormat, lhsGraph, lhsType):
                if case let .growthGraph(rhsTheme, rhsStrings, rhsDateTimeFormat, rhsGraph, rhsType) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsDateTimeFormat == rhsDateTimeFormat, lhsGraph == rhsGraph, lhsType == rhsType {
                    return true
                } else {
                    return false
                }
            case let .membersTitle(lhsTheme, lhsText):
                if case let .membersTitle(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .membersGraph(lhsTheme, lhsStrings, lhsDateTimeFormat, lhsGraph, lhsType):
                if case let .membersGraph(rhsTheme, rhsStrings, rhsDateTimeFormat, rhsGraph, rhsType) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsDateTimeFormat == rhsDateTimeFormat, lhsGraph == rhsGraph, lhsType == rhsType {
                    return true
                } else {
                    return false
                }
            case let .newMembersBySourceTitle(lhsTheme, lhsText):
                if case let .newMembersBySourceTitle(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .newMembersBySourceGraph(lhsTheme, lhsStrings, lhsDateTimeFormat, lhsGraph, lhsType):
                if case let .newMembersBySourceGraph(rhsTheme, rhsStrings, rhsDateTimeFormat, rhsGraph, rhsType) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsDateTimeFormat == rhsDateTimeFormat, lhsGraph == rhsGraph, lhsType == rhsType {
                    return true
                } else {
                    return false
                }
            case let .languagesTitle(lhsTheme, lhsText):
                if case let .languagesTitle(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
            }
            case let .languagesGraph(lhsTheme, lhsStrings, lhsDateTimeFormat, lhsGraph, lhsType):
                if case let .languagesGraph(rhsTheme, rhsStrings, rhsDateTimeFormat, rhsGraph, rhsType) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsDateTimeFormat == rhsDateTimeFormat, lhsGraph == rhsGraph, lhsType == rhsType {
                    return true
                } else {
                    return false
                }
            case let .messagesTitle(lhsTheme, lhsText):
                if case let .messagesTitle(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
            }
            case let .messagesGraph(lhsTheme, lhsStrings, lhsDateTimeFormat, lhsGraph, lhsType):
                if case let .messagesGraph(rhsTheme, rhsStrings, rhsDateTimeFormat, rhsGraph, rhsType) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsDateTimeFormat == rhsDateTimeFormat, lhsGraph == rhsGraph, lhsType == rhsType {
                    return true
                } else {
                    return false
                }
            case let .actionsTitle(lhsTheme, lhsText):
                if case let .actionsTitle(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
            }
            case let .actionsGraph(lhsTheme, lhsStrings, lhsDateTimeFormat, lhsGraph, lhsType):
                if case let .actionsGraph(rhsTheme, rhsStrings, rhsDateTimeFormat, rhsGraph, rhsType) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsDateTimeFormat == rhsDateTimeFormat, lhsGraph == rhsGraph, lhsType == rhsType {
                    return true
                } else {
                    return false
                }
            case let .topHoursTitle(lhsTheme, lhsText):
                if case let .topHoursTitle(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
            }
            case let .topHoursGraph(lhsTheme, lhsStrings, lhsDateTimeFormat, lhsGraph, lhsType):
                if case let .topHoursGraph(rhsTheme, rhsStrings, rhsDateTimeFormat, rhsGraph, rhsType) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsDateTimeFormat == rhsDateTimeFormat, lhsGraph == rhsGraph, lhsType == rhsType {
                    return true
                } else {
                    return false
                }
            case let .topPostersTitle(lhsTheme, lhsText, lhsDates):
                if case let .topPostersTitle(rhsTheme, rhsText, rhsDates) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsDates == rhsDates {
                    return true
                } else {
                    return false
                }
            case let .topPoster(lhsIndex, lhsTheme, lhsStrings, lhsDateTimeFormat, lhsPeer, lhsTopPoster):
                if case let .topPoster(rhsIndex, rhsTheme, rhsStrings, rhsDateTimeFormat, rhsPeer, rhsTopPoster) = rhs, lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsDateTimeFormat == rhsDateTimeFormat, arePeersEqual(lhsPeer, rhsPeer), lhsTopPoster == rhsTopPoster {
                    return true
                } else {
                    return false
                }
            case let .topAdminsTitle(lhsTheme, lhsText, lhsDates):
                if case let .topAdminsTitle(rhsTheme, rhsText, rhsDates) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsDates == rhsDates {
                    return true
                } else {
                    return false
                }
            case let .topAdmin(lhsIndex, lhsTheme, lhsStrings, lhsDateTimeFormat, lhsPeer, lhsTopAdmin):
                if case let .topAdmin(rhsIndex, rhsTheme, rhsStrings, rhsDateTimeFormat, rhsPeer, rhsTopAdmin) = rhs, lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsDateTimeFormat == rhsDateTimeFormat, arePeersEqual(lhsPeer, rhsPeer), lhsTopAdmin == rhsTopAdmin {
                    return true
                } else {
                    return false
                }
            case let .topInvitersTitle(lhsTheme, lhsText, lhsDates):
                if case let .topInvitersTitle(rhsTheme, rhsText, rhsDates) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsDates == rhsDates {
                    return true
                } else {
                    return false
                }
            case let .topInviter(lhsIndex, lhsTheme, lhsStrings, lhsDateTimeFormat, lhsPeer, lhsTopInviter):
                if case let .topInviter(rhsIndex, rhsTheme, rhsStrings, rhsDateTimeFormat, rhsPeer, rhsTopInviter) = rhs, lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsDateTimeFormat == rhsDateTimeFormat, arePeersEqual(lhsPeer, rhsPeer), lhsTopInviter == rhsTopInviter {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: StatsEntry, rhs: StatsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! GroupStatsControllerArguments
        switch self {
            case let .overviewTitle(_, text, dates):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, accessoryText: ItemListSectionHeaderAccessoryText(value: dates, color: .generic), sectionId: self.section)
            case let .growthTitle(_, text),
                 let .membersTitle(_, text),
                 let .newMembersBySourceTitle(_, text),
                 let .languagesTitle(_, text),
                 let .messagesTitle(_, text),
                 let .actionsTitle(_, text),
                 let .topHoursTitle(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .topPostersTitle(_, text, dates),
                 let .topAdminsTitle(_, text, dates),
                 let .topInvitersTitle(_, text, dates):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, accessoryText: ItemListSectionHeaderAccessoryText(value: dates, color: .generic), sectionId: self.section)
            case let .overview(_, stats):
                return StatsOverviewItem(presentationData: presentationData, stats: stats, sectionId: self.section, style: .blocks)
            case let .growthGraph(_, _, _, graph, type),
                 let .membersGraph(_, _, _, graph, type),
                 let .newMembersBySourceGraph(_, _, _, graph, type),
                 let .languagesGraph(_, _, _, graph, type),
                 let .messagesGraph(_, _, _, graph, type),
                 let .actionsGraph(_, _, _, graph, type),
                 let .topHoursGraph(_, _, _, graph, type):
                return StatsGraphItem(presentationData: presentationData, graph: graph, type: type, sectionId: self.section, style: .blocks)
            case let .topPoster(_, _, strings, dateTimeFormat, peer, topPoster):
                var textComponents: [String] = []
                if topPoster.messageCount > 0 {
                    textComponents.append(strings.Stats_GroupTopPosterMessages(topPoster.messageCount))
                    if topPoster.averageChars > 0 {
                        textComponents.append(strings.Stats_GroupTopPosterChars(topPoster.averageChars))
                    }
                }
                return ItemListPeerItem(presentationData: presentationData, dateTimeFormat: dateTimeFormat, nameDisplayOrder: .firstLast, context: arguments.context, peer: peer, height: .generic, aliasHandling: .standard, nameColor: .primary, nameStyle: .plain, presence: nil, text: .text(textComponents.joined(separator: ", ")), label: .none, editing: ItemListPeerItemEditing(editable: false, editing: false, revealed: nil), revealOptions: nil, switchValue: nil, enabled: true, highlighted: false, selectable: true, sectionId: self.section, action: {
                    arguments.openPeer(peer.id)
                }, setPeerIdWithRevealedOptions: { _, _ in }, removePeer: { _ in })
            case let .topAdmin(_, _, strings, dateTimeFormat, peer, topAdmin):
                var textComponents: [String] = []
                if topAdmin.deletedCount > 0 {
                    textComponents.append(strings.Stats_GroupTopAdminDeletions(topAdmin.deletedCount))
                }
                if topAdmin.kickedCount > 0 {
                    textComponents.append(strings.Stats_GroupTopAdminKicks(topAdmin.kickedCount))
                }
                if topAdmin.bannedCount > 0 {
                    textComponents.append(strings.Stats_GroupTopAdminBans(topAdmin.bannedCount))
                }
                
                return ItemListPeerItem(presentationData: presentationData, dateTimeFormat: dateTimeFormat, nameDisplayOrder: .firstLast, context: arguments.context, peer: peer, height: .generic, aliasHandling: .standard, nameColor: .primary, nameStyle: .plain, presence: nil, text: .text(textComponents.joined(separator: ", ")), label: .none, editing: ItemListPeerItemEditing(editable: false, editing: false, revealed: nil), revealOptions: nil, switchValue: nil, enabled: true, highlighted: false, selectable: true, sectionId: self.section, action: {
                    arguments.openPeer(peer.id)
                }, setPeerIdWithRevealedOptions: { _, _ in }, removePeer: { _ in })
            case let .topInviter(_, _, strings, dateTimeFormat, peer, topInviter):
                var textComponents: [String] = []
                textComponents.append(strings.Stats_GroupTopInviterInvites(topInviter.inviteCount))
                
                return ItemListPeerItem(presentationData: presentationData, dateTimeFormat: dateTimeFormat, nameDisplayOrder: .firstLast, context: arguments.context, peer: peer, height: .generic, aliasHandling: .standard, nameColor: .primary, nameStyle: .plain, presence: nil, text: .text(textComponents.joined(separator: ", ")), label: .none, editing: ItemListPeerItemEditing(editable: false, editing: false, revealed: nil), revealOptions: nil, switchValue: nil, enabled: true, highlighted: false, selectable: true, sectionId: self.section, action: {
                    arguments.openPeer(peer.id)
                }, setPeerIdWithRevealedOptions: { _, _ in }, removePeer: { _ in })
        }
    }
}

private func groupStatsControllerEntries(data: GroupStats?, peers: [PeerId: Peer]?, presentationData: PresentationData) -> [StatsEntry] {
    var entries: [StatsEntry] = []
    
    if let data = data {
        let minDate = stringForDate(timestamp: data.period.minDate, strings: presentationData.strings)
        let maxDate = stringForDate(timestamp: data.period.maxDate, strings: presentationData.strings)
        let dates = "\(minDate) – \(maxDate)"
        
        entries.append(.overviewTitle(presentationData.theme, presentationData.strings.Stats_Overview, dates))
        entries.append(.overview(presentationData.theme, data))
    
        if !data.growthGraph.isEmpty {
            entries.append(.growthTitle(presentationData.theme, presentationData.strings.Stats_GroupGrowthTitle))
            entries.append(.growthGraph(presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, data.growthGraph, .lines))
        }
        
        if !data.membersGraph.isEmpty {
            entries.append(.membersTitle(presentationData.theme, presentationData.strings.Stats_GroupMembersTitle))
            entries.append(.membersGraph(presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, data.membersGraph, .lines))
        }

        if !data.newMembersBySourceGraph.isEmpty {
            entries.append(.newMembersBySourceTitle(presentationData.theme, presentationData.strings.Stats_GroupNewMembersBySourceTitle))
            entries.append(.newMembersBySourceGraph(presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, data.newMembersBySourceGraph, .bars))
        }
        
        if !data.languagesGraph.isEmpty {
            entries.append(.languagesTitle(presentationData.theme, presentationData.strings.Stats_GroupLanguagesTitle))
            entries.append(.languagesGraph(presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, data.languagesGraph, .pie))
        }

        if !data.messagesGraph.isEmpty {
            entries.append(.messagesTitle(presentationData.theme, presentationData.strings.Stats_GroupMessagesTitle))
            entries.append(.messagesGraph(presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, data.messagesGraph, .bars))
        }

        if !data.actionsGraph.isEmpty {
            entries.append(.actionsTitle(presentationData.theme, presentationData.strings.Stats_GroupActionsTitle))
            entries.append(.actionsGraph(presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, data.actionsGraph, .lines))
        }

        if !data.topHoursGraph.isEmpty {
            entries.append(.topHoursTitle(presentationData.theme, presentationData.strings.Stats_GroupTopHoursTitle))
            entries.append(.topHoursGraph(presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, data.topHoursGraph, .hourlyStep))
        }
        
        if let peers = peers {
            if !data.topPosters.isEmpty {
                entries.append(.topPostersTitle(presentationData.theme, presentationData.strings.Stats_GroupTopPostersTitle, dates))
                var index: Int32 = 0
                for topPoster in data.topPosters {
                    if let peer = peers[topPoster.peerId], topPoster.messageCount > 0 {
                        entries.append(.topPoster(index, presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, peer, topPoster))
                        index += 1
                    }
                }
            }
            if !data.topAdmins.isEmpty {
                entries.append(.topAdminsTitle(presentationData.theme, presentationData.strings.Stats_GroupTopAdminsTitle, dates))
                var index: Int32 = 0
                for topAdmin in data.topAdmins {
                    if let peer = peers[topAdmin.peerId], (topAdmin.deletedCount + topAdmin.kickedCount + topAdmin.bannedCount) > 0 {
                        entries.append(.topAdmin(index, presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, peer, topAdmin))
                        index += 1
                    }
                }
            }
            if !data.topInviters.isEmpty {
                entries.append(.topInvitersTitle(presentationData.theme, presentationData.strings.Stats_GroupTopInvitersTitle, dates))
                var index: Int32 = 0
                for topInviter in data.topInviters {
                    if let peer = peers[topInviter.peerId], topInviter.inviteCount > 0 {
                        entries.append(.topInviter(index, presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, peer, topInviter))
                        index += 1
                    }
                }
            }
        }
    }
    
    return entries
}

public func groupStatsController(context: AccountContext, peerId: PeerId, cachedPeerData: CachedPeerData) -> ViewController {
    var openPeerImpl: ((PeerId) -> Void)?
    
    let actionsDisposable = DisposableSet()
    let dataPromise = Promise<GroupStats?>(nil)
    let peersPromise = Promise<[PeerId: Peer]?>(nil)
    
    var datacenterId: Int32 = 0
    if let cachedData = cachedPeerData as? CachedChannelData {
        datacenterId = cachedData.statsDatacenterId
    }
        
    let statsContext = GroupStatsContext(postbox: context.account.postbox, network: context.account.network, datacenterId: datacenterId, peerId: peerId)
    let dataSignal: Signal<GroupStats?, NoError> = statsContext.state
    |> map { state in
        return state.stats
    } |> afterNext({ [weak statsContext] stats in
        if let statsContext = statsContext, let stats = stats {
            if case .OnDemand = stats.newMembersBySourceGraph {
                statsContext.loadGrowthGraph()
                statsContext.loadMembersGraph()
                statsContext.loadNewMembersBySourceGraph()
                statsContext.loadLanguagesGraph()
                statsContext.loadMessagesGraph()
                statsContext.loadActionsGraph()
                statsContext.loadTopHoursGraph()
            }
        }
    })
    dataPromise.set(.single(nil) |> then(dataSignal))
    
    peersPromise.set(.single(nil) |> then(dataPromise.get()
    |> filter { value in
        return value != nil
    }
    |> take(1)
    |> map { stats -> [PeerId]? in
        guard let stats = stats else {
            return nil
        }
        var peerIds = Set<PeerId>()
        peerIds.formUnion(stats.topPosters.map { $0.peerId })
        peerIds.formUnion(stats.topAdmins.map { $0.peerId })
        peerIds.formUnion(stats.topInviters.map { $0.peerId })
        return Array(peerIds)
    }
    |> mapToSignal { peerIds -> Signal<[PeerId: Peer]?, NoError> in
        return context.account.postbox.transaction { transaction -> [PeerId: Peer]? in
            var peers: [PeerId: Peer] = [:]
            if let peerIds = peerIds {
                for peerId in peerIds {
                    if let peer = transaction.getPeer(peerId) {
                        peers[peerId] = peer
                    }
                }
            }
            return peers
        }
    }))
    
    let arguments = GroupStatsControllerArguments(context: context, loadDetailedGraph: { graph, x -> Signal<StatsGraph?, NoError> in
        return statsContext.loadDetailedGraph(graph, x: x)
    }, openPeer: { peerId in
        openPeerImpl?(peerId)
    })
        
    let longLoadingSignal: Signal<Bool, NoError> = .single(false) |> then(.single(true) |> delay(2.0, queue: Queue.mainQueue()))
    
    let previousData = Atomic<GroupStats?>(value: nil)
    
    let signal = combineLatest(context.sharedContext.presentationData, dataPromise.get(), peersPromise.get(), longLoadingSignal)
    |> deliverOnMainQueue
    |> map { presentationData, data, peers, longLoading -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let previous = previousData.swap(data)
        var emptyStateItem: ItemListControllerEmptyStateItem?
        if data == nil {
            if longLoading {
                emptyStateItem = StatsEmptyStateItem(theme: presentationData.theme, strings: presentationData.strings)
            } else {
                emptyStateItem = ItemListLoadingIndicatorEmptyStateItem(theme: presentationData.theme)
            }
        }
                
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.ChannelInfo_Stats), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: true)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: groupStatsControllerEntries(data: data, peers: peers, presentationData: presentationData), style: .blocks, emptyStateItem: emptyStateItem, crossfadeState: previous == nil, animateChanges: false)
        
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
        actionsDisposable.dispose()
        let _ = statsContext.state
    }
    
    let controller = ItemListController(context: context, state: signal)
    controller.contentOffsetChanged = { [weak controller] _, _ in
        controller?.forEachItemNode({ itemNode in
            if let itemNode = itemNode as? StatsGraphItemNode {
                itemNode.resetInteraction()
            }
        })
    }
    controller.didDisappear = { [weak controller] _ in
        controller?.clearItemNodesHighlight(animated: true)
    }
    openPeerImpl = { [weak controller] peerId in
        if let navigationController = controller?.navigationController as? NavigationController {
            let _ = (context.account.postbox.loadedPeerWithId(peerId)
            |> take(1)
            |> deliverOnMainQueue).start(next: { peer in
                if let controller = context.sharedContext.makePeerInfoController(context: context, peer: peer, mode: .generic, avatarInitiallyExpanded: false, fromChat: false) {
                    navigationController.pushViewController(controller)
                }
            })
        }
    }
    return controller
}
