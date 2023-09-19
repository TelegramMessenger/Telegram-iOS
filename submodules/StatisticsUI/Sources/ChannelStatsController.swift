import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import TelegramStringFormatting
import ItemListUI
import PresentationDataUtils
import AccountContext
import PresentationDataUtils
import AppBundle
import GraphUI
import ContextUI
import ItemListPeerItem
import InviteLinksUI
import UndoUI
import ShareController
import ItemListPeerActionItem

private let maxUsersDisplayedLimit: Int32 = 50

private final class ChannelStatsControllerArguments {
    let context: AccountContext
    let loadDetailedGraph: (StatsGraph, Int64) -> Signal<StatsGraph?, NoError>
    let openMessageStats: (MessageId) -> Void
    let contextAction: (MessageId, ASDisplayNode, ContextGesture?) -> Void
    let copyBoostLink: (String) -> Void
    let shareBoostLink: (String) -> Void
    let openPeer: (EnginePeer) -> Void
    let expandBoosters: () -> Void
        
    init(context: AccountContext, loadDetailedGraph: @escaping (StatsGraph, Int64) -> Signal<StatsGraph?, NoError>, openMessage: @escaping (MessageId) -> Void, contextAction: @escaping (MessageId, ASDisplayNode, ContextGesture?) -> Void, copyBoostLink: @escaping (String) -> Void, shareBoostLink: @escaping (String) -> Void, openPeer: @escaping (EnginePeer) -> Void, expandBoosters: @escaping () -> Void) {
        self.context = context
        self.loadDetailedGraph = loadDetailedGraph
        self.openMessageStats = openMessage
        self.contextAction = contextAction
        self.copyBoostLink = copyBoostLink
        self.shareBoostLink = shareBoostLink
        self.openPeer = openPeer
        self.expandBoosters = expandBoosters
    }
}

private enum StatsSection: Int32 {
    case overview
    case growth
    case followers
    case notifications
    case viewsByHour
    case viewsBySource
    case followersBySource
    case languages
    case postInteractions
    case recentPosts
    case instantPageInteractions
    case boostLevel
    case boostOverview
    case boosters
    case boostLink
}

private enum StatsEntry: ItemListNodeEntry {
    case overviewTitle(PresentationTheme, String, String)
    case overview(PresentationTheme, ChannelStats)
    
    case growthTitle(PresentationTheme, String)
    case growthGraph(PresentationTheme, PresentationStrings, PresentationDateTimeFormat, StatsGraph, ChartType)
    
    case followersTitle(PresentationTheme, String)
    case followersGraph(PresentationTheme, PresentationStrings, PresentationDateTimeFormat, StatsGraph, ChartType)
     
    case notificationsTitle(PresentationTheme, String)
    case notificationsGraph(PresentationTheme, PresentationStrings, PresentationDateTimeFormat, StatsGraph, ChartType)
    
    case viewsByHourTitle(PresentationTheme, String)
    case viewsByHourGraph(PresentationTheme, PresentationStrings, PresentationDateTimeFormat, StatsGraph, ChartType)
        
    case viewsBySourceTitle(PresentationTheme, String)
    case viewsBySourceGraph(PresentationTheme, PresentationStrings, PresentationDateTimeFormat, StatsGraph, ChartType)
    
    case followersBySourceTitle(PresentationTheme, String)
    case followersBySourceGraph(PresentationTheme, PresentationStrings, PresentationDateTimeFormat, StatsGraph, ChartType)
    
    case languagesTitle(PresentationTheme, String)
    case languagesGraph(PresentationTheme, PresentationStrings, PresentationDateTimeFormat, StatsGraph, ChartType)
    
    case postInteractionsTitle(PresentationTheme, String)
    case postInteractionsGraph(PresentationTheme, PresentationStrings, PresentationDateTimeFormat, StatsGraph, ChartType)
    
    case postsTitle(PresentationTheme, String)
    case post(Int32, PresentationTheme, PresentationStrings, PresentationDateTimeFormat, Message, ChannelStatsMessageInteractions)
    
    case instantPageInteractionsTitle(PresentationTheme, String)
    case instantPageInteractionsGraph(PresentationTheme, PresentationStrings, PresentationDateTimeFormat, StatsGraph, ChartType)
    
    case boostLevel(PresentationTheme, Int32, Int32, CGFloat)
    
    case boostOverviewTitle(PresentationTheme, String)
    case boostOverview(PresentationTheme, ChannelBoostStatus)
    
    case boostersTitle(PresentationTheme, String)
    case boostersPlaceholder(PresentationTheme, String)
    case booster(Int32, PresentationTheme, PresentationDateTimeFormat, EnginePeer, Int32)
    case boostersExpand(PresentationTheme, String)
    case boostersInfo(PresentationTheme, String)
    
    case boostLinkTitle(PresentationTheme, String)
    case boostLink(PresentationTheme, String)
    case boostLinkInfo(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
            case .overviewTitle, .overview:
                return StatsSection.overview.rawValue
            case .growthTitle, .growthGraph:
                return StatsSection.growth.rawValue
            case .followersTitle, .followersGraph:
                return StatsSection.followers.rawValue
            case .notificationsTitle, .notificationsGraph:
                return StatsSection.notifications.rawValue
            case .viewsByHourTitle, .viewsByHourGraph:
                return StatsSection.viewsByHour.rawValue
            case .viewsBySourceTitle, .viewsBySourceGraph:
                return StatsSection.viewsBySource.rawValue
            case .followersBySourceTitle, .followersBySourceGraph:
                return StatsSection.followersBySource.rawValue
            case .languagesTitle, .languagesGraph:
                return StatsSection.languages.rawValue
            case .postInteractionsTitle, .postInteractionsGraph:
                return StatsSection.postInteractions.rawValue
            case .postsTitle, .post:
                return StatsSection.recentPosts.rawValue
            case .instantPageInteractionsTitle, .instantPageInteractionsGraph:
                return StatsSection.instantPageInteractions.rawValue
            case .boostLevel:
                return StatsSection.boostLevel.rawValue
            case .boostOverviewTitle, .boostOverview:
                return StatsSection.boostOverview.rawValue
        case .boostersTitle, .boostersPlaceholder, .booster, .boostersExpand, .boostersInfo:
                return StatsSection.boosters.rawValue
            case .boostLinkTitle, .boostLink, .boostLinkInfo:
                return StatsSection.boostLink.rawValue
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
            case .followersTitle:
                return 4
            case .followersGraph:
                return 5
            case .notificationsTitle:
                return 6
            case .notificationsGraph:
                return 7
            case .viewsByHourTitle:
                return 8
            case .viewsByHourGraph:
                return 9
            case .viewsBySourceTitle:
                return 10
            case .viewsBySourceGraph:
                return 11
            case .followersBySourceTitle:
                return 12
            case .followersBySourceGraph:
                return 13
            case .languagesTitle:
                return 14
            case .languagesGraph:
                return 15
            case .postInteractionsTitle:
                return 16
            case .postInteractionsGraph:
                return 17
            case .instantPageInteractionsTitle:
                 return 18
             case .instantPageInteractionsGraph:
                 return 19
            case .postsTitle:
                return 20
            case let .post(index, _, _, _, _, _):
                return 21 + index
            case .boostLevel:
                return 2000
            case .boostOverviewTitle:
                return 2001
            case .boostOverview:
                return 2002
            case .boostersTitle:
                return 2003
            case .boostersPlaceholder:
                return 2004
            case let .booster(index, _, _, _, _):
                return 2005 + index
            case .boostersExpand:
                return 10000
            case .boostersInfo:
                return 10001
            case .boostLinkTitle:
                return 10002
            case .boostLink:
                return 10003
            case .boostLinkInfo:
                return 10004
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
            case let .followersTitle(lhsTheme, lhsText):
                if case let .followersTitle(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .followersGraph(lhsTheme, lhsStrings, lhsDateTimeFormat, lhsGraph, lhsType):
                if case let .followersGraph(rhsTheme, rhsStrings, rhsDateTimeFormat, rhsGraph, rhsType) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsDateTimeFormat == rhsDateTimeFormat, lhsGraph == rhsGraph, lhsType == rhsType {
                    return true
                } else {
                    return false
                }
            case let .notificationsTitle(lhsTheme, lhsText):
                  if case let .notificationsTitle(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                      return true
                  } else {
                      return false
                  }
            case let .notificationsGraph(lhsTheme, lhsStrings, lhsDateTimeFormat, lhsGraph, lhsType):
                if case let .notificationsGraph(rhsTheme, rhsStrings, rhsDateTimeFormat, rhsGraph, rhsType) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsDateTimeFormat == rhsDateTimeFormat, lhsGraph == rhsGraph, lhsType == rhsType {
                    return true
                } else {
                    return false
                }
            case let .viewsByHourTitle(lhsTheme, lhsText):
                if case let .viewsByHourTitle(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .viewsByHourGraph(lhsTheme, lhsStrings, lhsDateTimeFormat, lhsGraph, lhsType):
                if case let .viewsByHourGraph(rhsTheme, rhsStrings, rhsDateTimeFormat, rhsGraph, rhsType) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsDateTimeFormat == rhsDateTimeFormat, lhsGraph == rhsGraph, lhsType == rhsType {
                    return true
                } else {
                    return false
                }
            case let .viewsBySourceTitle(lhsTheme, lhsText):
                if case let .viewsBySourceTitle(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .viewsBySourceGraph(lhsTheme, lhsStrings, lhsDateTimeFormat, lhsGraph, lhsType):
                if case let .viewsBySourceGraph(rhsTheme, rhsStrings, rhsDateTimeFormat, rhsGraph, rhsType) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsDateTimeFormat == rhsDateTimeFormat, lhsGraph == rhsGraph, lhsType == rhsType {
                    return true
                } else {
                    return false
                }
            case let .followersBySourceTitle(lhsTheme, lhsText):
                if case let .followersBySourceTitle(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .followersBySourceGraph(lhsTheme, lhsStrings, lhsDateTimeFormat, lhsGraph, lhsType):
                if case let .followersBySourceGraph(rhsTheme, rhsStrings, rhsDateTimeFormat, rhsGraph, rhsType) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsDateTimeFormat == rhsDateTimeFormat, lhsGraph == rhsGraph, lhsType == rhsType {
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
            case let .postInteractionsTitle(lhsTheme, lhsText):
                if case let .postInteractionsTitle(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .postInteractionsGraph(lhsTheme, lhsStrings, lhsDateTimeFormat, lhsGraph, lhsType):
                if case let .postInteractionsGraph(rhsTheme, rhsStrings, rhsDateTimeFormat, rhsGraph, rhsType) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsDateTimeFormat == rhsDateTimeFormat, lhsGraph == rhsGraph, lhsType == rhsType {
                    return true
                } else {
                    return false
                }
            case let .postsTitle(lhsTheme, lhsText):
                if case let .postsTitle(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .post(lhsIndex, lhsTheme, lhsStrings, lhsDateTimeFormat, lhsMessage, lhsInteractions):
                if case let .post(rhsIndex, rhsTheme, rhsStrings, rhsDateTimeFormat, rhsMessage, rhsInteractions) = rhs, lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsDateTimeFormat == rhsDateTimeFormat, lhsMessage.id == rhsMessage.id, lhsInteractions == rhsInteractions {
                    return true
                } else {
                    return false
                }
            case let .instantPageInteractionsTitle(lhsTheme, lhsText):
                if case let .instantPageInteractionsTitle(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .instantPageInteractionsGraph(lhsTheme, lhsStrings, lhsDateTimeFormat, lhsGraph, lhsType):
                if case let .instantPageInteractionsGraph(rhsTheme, rhsStrings, rhsDateTimeFormat, rhsGraph, rhsType) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsDateTimeFormat == rhsDateTimeFormat, lhsGraph == rhsGraph, lhsType == rhsType {
                    return true
                } else {
                    return false
                }
            case let .boostLevel(lhsTheme, lhsBoosts, lhsLevel, lhsPosition):
                if case let .boostLevel(rhsTheme, rhsBoosts, rhsLevel, rhsPosition) = rhs, lhsTheme === rhsTheme, lhsBoosts == rhsBoosts, lhsLevel == rhsLevel, lhsPosition == rhsPosition {
                    return true
                } else {
                    return false
                }
            case let .boostOverviewTitle(lhsTheme, lhsText):
                if case let .boostOverviewTitle(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .boostOverview(lhsTheme, lhsStats):
                if case let .boostOverview(rhsTheme, rhsStats) = rhs, lhsTheme === rhsTheme, lhsStats == rhsStats {
                    return true
                } else {
                    return false
                }
            case let .boostersTitle(lhsTheme, lhsText):
                if case let .boostersTitle(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .boostersPlaceholder(lhsTheme, lhsText):
                if case let .boostersPlaceholder(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .booster(lhsIndex, lhsTheme, lhsDateTimeFormat, lhsPeer, lhsExpires):
                if case let .booster(rhsIndex, rhsTheme, rhsDateTimeFormat, rhsPeer, rhsExpires) = rhs, lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsDateTimeFormat == rhsDateTimeFormat, lhsPeer == rhsPeer, lhsExpires == rhsExpires {
                    return true
                } else {
                    return false
                }
            case let .boostersExpand(lhsTheme, lhsText):
                if case let .boostersExpand(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .boostersInfo(lhsTheme, lhsText):
                if case let .boostersInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .boostLinkTitle(lhsTheme, lhsText):
                if case let .boostLinkTitle(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .boostLink(lhsTheme, lhsText):
                if case let .boostLink(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .boostLinkInfo(lhsTheme, lhsText):
                if case let .boostLinkInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
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
        let arguments = arguments as! ChannelStatsControllerArguments
        switch self {
            case let .overviewTitle(_, text, dates):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, accessoryText: ItemListSectionHeaderAccessoryText(value: dates, color: .generic), sectionId: self.section)
            case let .growthTitle(_, text),
                 let .followersTitle(_, text),
                 let .notificationsTitle(_, text),
                 let .viewsByHourTitle(_, text),
                 let .viewsBySourceTitle(_, text),
                 let .followersBySourceTitle(_, text),
                 let .languagesTitle(_, text),
                 let .postInteractionsTitle(_, text),
                 let .postsTitle(_, text),
                 let .instantPageInteractionsTitle(_, text),
                 let .boostOverviewTitle(_, text),
                 let .boostersTitle(_, text),
                 let .boostLinkTitle(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .boostersInfo(_, text),
                 let .boostLinkInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .markdown(text), sectionId: self.section)
            case let .overview(_, stats):
                return StatsOverviewItem(presentationData: presentationData, stats: stats, sectionId: self.section, style: .blocks)
            case let .growthGraph(_, _, _, graph, type),
                 let .followersGraph(_, _, _, graph, type),
                 let .notificationsGraph(_, _, _, graph, type),
                 let .viewsByHourGraph(_, _, _, graph, type),
                 let .viewsBySourceGraph(_, _, _, graph, type),
                 let .followersBySourceGraph(_, _, _, graph, type),
                 let .languagesGraph(_, _, _, graph, type):
                return StatsGraphItem(presentationData: presentationData, graph: graph, type: type, sectionId: self.section, style: .blocks)
            case let .postInteractionsGraph(_, _, _, graph, type),
                 let .instantPageInteractionsGraph(_, _, _, graph, type):
                return StatsGraphItem(presentationData: presentationData, graph: graph, type: type, getDetailsData: { date, completion in
                    let _ = arguments.loadDetailedGraph(graph, Int64(date.timeIntervalSince1970) * 1000).start(next: { graph in
                        if let graph = graph, case let .Loaded(_, data) = graph {
                            completion(data)
                        }
                    })
                }, sectionId: self.section, style: .blocks)
            case let .post(_, _, _, _, message, interactions):
                return StatsMessageItem(context: arguments.context, presentationData: presentationData, message: message, views: interactions.views, forwards: interactions.forwards, sectionId: self.section, style: .blocks, action: {
                    arguments.openMessageStats(message.id)
                }, contextAction: { node, gesture in
                    arguments.contextAction(message.id, node, gesture)
                })
            case let .booster(_, _, dateTimeFormat, peer, expires):
                let expiresValue = stringForMediumDate(timestamp: expires, strings: presentationData.strings, dateTimeFormat: dateTimeFormat)
                return ItemListPeerItem(presentationData: presentationData, dateTimeFormat: PresentationDateTimeFormat(), nameDisplayOrder: presentationData.nameDisplayOrder, context: arguments.context, peer: peer, presence: nil, text: .text(presentationData.strings.Stats_Boosts_ExpiresOn(expiresValue).string, .secondary), label: .none, editing: ItemListPeerItemEditing(editable: false, editing: false, revealed: false), switchValue: nil, enabled: true, selectable: peer.id != arguments.context.account.peerId, sectionId: self.section, action: {
                    arguments.openPeer(peer)
                }, setPeerIdWithRevealedOptions: { _, _ in }, removePeer: { _ in })
            case let .boostersExpand(theme, title):
                return ItemListPeerActionItem(presentationData: presentationData, icon: PresentationResourcesItemList.downArrowImage(theme), title: title, sectionId: self.section, editing: false, action: {
                    arguments.expandBoosters()
                })
            case let .boostLevel(_, count, level, position):
                let inactiveText = presentationData.strings.ChannelBoost_Level("\(level)").string
                let activeText = presentationData.strings.ChannelBoost_Level("\(level + 1)").string
                return BoostLevelHeaderItem(theme: presentationData.theme, count: count, position: position, activeText: activeText, inactiveText: inactiveText, sectionId: self.section)
            case let .boostOverview(_, stats):
                return StatsOverviewItem(presentationData: presentationData, stats: stats, sectionId: self.section, style: .blocks)
            case let .boostLink(_, link):
                let invite: ExportedInvitation = .link(link: link, title: nil, isPermanent: false, requestApproval: false, isRevoked: false, adminId: PeerId(0), date: 0, startDate: nil, expireDate: nil, usageLimit: nil, count: nil, requestedCount: nil)
                return ItemListPermanentInviteLinkItem(context: arguments.context, presentationData: presentationData, invite: invite, count: 0, peers: [], displayButton: true, displayImporters: false, buttonColor: nil, sectionId: self.section, style: .blocks, copyAction: {
                    arguments.copyBoostLink(link)
                }, shareAction: {
                    arguments.shareBoostLink(link)
                }, contextAction: nil, viewAction: nil, tag: nil)
            case let .boostersPlaceholder(_, text):
                return ItemListPlaceholderItem(theme: presentationData.theme, text: text, sectionId: self.section, style: .blocks)
        }
    }
}

public enum ChannelStatsSection {
    case stats
    case boosts
}

private struct ChannelStatsControllerState: Equatable {
    let section: ChannelStatsSection
    let boostersExpanded: Bool
  
    init() {
        self.section = .stats
        self.boostersExpanded = false
    }
    
    init(section: ChannelStatsSection, boostersExpanded: Bool) {
        self.section = section
        self.boostersExpanded = boostersExpanded
    }
    
    static func ==(lhs: ChannelStatsControllerState, rhs: ChannelStatsControllerState) -> Bool {
        if lhs.section != rhs.section {
            return false
        }
        if lhs.boostersExpanded != rhs.boostersExpanded {
            return false
        }
        return true
    }
    
    func withUpdatedSection(_ section: ChannelStatsSection) -> ChannelStatsControllerState {
        return ChannelStatsControllerState(section: section, boostersExpanded: self.boostersExpanded)
    }
    
    func withUpdatedBoostersExpanded(_ boostersExpanded: Bool) -> ChannelStatsControllerState {
        return ChannelStatsControllerState(section: self.section, boostersExpanded: boostersExpanded)
    }
}


private func channelStatsControllerEntries(state: ChannelStatsControllerState, peer: EnginePeer?, data: ChannelStats?, messages: [Message]?, interactions: [MessageId: ChannelStatsMessageInteractions]?, boostData: ChannelBoostStatus?, boostersState: ChannelBoostersContext.State?, presentationData: PresentationData) -> [StatsEntry] {
    var entries: [StatsEntry] = []
    
    switch state.section {
    case .stats:
        if let data = data {
            let minDate = stringForDate(timestamp: data.period.minDate, strings: presentationData.strings)
            let maxDate = stringForDate(timestamp: data.period.maxDate, strings: presentationData.strings)
            
            entries.append(.overviewTitle(presentationData.theme, presentationData.strings.Stats_Overview, "\(minDate) – \(maxDate)"))
            entries.append(.overview(presentationData.theme, data))
            
            if !data.growthGraph.isEmpty {
                entries.append(.growthTitle(presentationData.theme, presentationData.strings.Stats_GrowthTitle))
                entries.append(.growthGraph(presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, data.growthGraph, .lines))
            }
            
            if !data.followersGraph.isEmpty {
                entries.append(.followersTitle(presentationData.theme, presentationData.strings.Stats_FollowersTitle))
                entries.append(.followersGraph(presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, data.followersGraph, .lines))
            }
            
            if !data.muteGraph.isEmpty {
                entries.append(.notificationsTitle(presentationData.theme, presentationData.strings.Stats_NotificationsTitle))
                entries.append(.notificationsGraph(presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, data.muteGraph, .lines))
            }
            
            if !data.topHoursGraph.isEmpty {
                entries.append(.viewsByHourTitle(presentationData.theme, presentationData.strings.Stats_ViewsByHoursTitle))
                entries.append(.viewsByHourGraph(presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, data.topHoursGraph, .hourlyStep))
            }
            
            if !data.viewsBySourceGraph.isEmpty {
                entries.append(.viewsBySourceTitle(presentationData.theme, presentationData.strings.Stats_ViewsBySourceTitle))
                entries.append(.viewsBySourceGraph(presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, data.viewsBySourceGraph, .bars))
            }
            
            if !data.newFollowersBySourceGraph.isEmpty {
                entries.append(.followersBySourceTitle(presentationData.theme, presentationData.strings.Stats_FollowersBySourceTitle))
                entries.append(.followersBySourceGraph(presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, data.newFollowersBySourceGraph, .bars))
            }
            
            if !data.languagesGraph.isEmpty {
                entries.append(.languagesTitle(presentationData.theme, presentationData.strings.Stats_LanguagesTitle))
                entries.append(.languagesGraph(presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, data.languagesGraph, .pie))
            }
            
            if !data.interactionsGraph.isEmpty {
                entries.append(.postInteractionsTitle(presentationData.theme, presentationData.strings.Stats_InteractionsTitle))
                entries.append(.postInteractionsGraph(presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, data.interactionsGraph, .twoAxisStep))
            }
            
            if !data.instantPageInteractionsGraph.isEmpty {
                entries.append(.instantPageInteractionsTitle(presentationData.theme, presentationData.strings.Stats_InstantViewInteractionsTitle))
                entries.append(.instantPageInteractionsGraph(presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, data.instantPageInteractionsGraph, .twoAxisStep))
            }
            
            if let messages = messages, !messages.isEmpty, let interactions = interactions, !interactions.isEmpty {
                entries.append(.postsTitle(presentationData.theme, presentationData.strings.Stats_PostsTitle))
                var index: Int32 = 0
                for message in messages {
                    if let interactions = interactions[message.id] {
                        entries.append(.post(index, presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, message, interactions))
                        index += 1
                    }
                }
            }
        }
    case .boosts:
        if let boostData {
            let progress: CGFloat
            if let nextLevelBoosts = boostData.nextLevelBoosts {
                progress = CGFloat(boostData.boosts - boostData.currentLevelBoosts) / CGFloat(nextLevelBoosts - boostData.currentLevelBoosts)
            } else {
                progress = 1.0
            }
            entries.append(.boostLevel(presentationData.theme, Int32(boostData.boosts), Int32(boostData.level), progress))
            
            entries.append(.boostOverviewTitle(presentationData.theme, presentationData.strings.Stats_Boosts_OverviewHeader))
            entries.append(.boostOverview(presentationData.theme, boostData))
            
            let boostersTitle: String
            let boostersPlaceholder: String?
            let boostersFooter: String?
            if let boostersState, boostersState.count > 0 {
                boostersTitle = presentationData.strings.Stats_Boosts_Boosters(boostersState.count)
                boostersPlaceholder = nil
                boostersFooter = presentationData.strings.Stats_Boosts_BoostersInfo
            } else {
                boostersTitle = presentationData.strings.Stats_Boosts_BoostersNone
                boostersPlaceholder = presentationData.strings.Stats_Boosts_NoBoostersYet
                boostersFooter = nil
            }
            entries.append(.boostersTitle(presentationData.theme, boostersTitle))
            
            if let boostersPlaceholder {
                entries.append(.boostersPlaceholder(presentationData.theme, boostersPlaceholder))
            }
            
            if let boostersState {
                var boosterIndex: Int32 = 0
                
                var boosters: [ChannelBoostersContext.State.Booster] = boostersState.boosters
                var effectiveExpanded = state.boostersExpanded
                if boosters.count > maxUsersDisplayedLimit && !state.boostersExpanded {
                    boosters = Array(boosters.prefix(Int(maxUsersDisplayedLimit)))
                } else {
                    effectiveExpanded = true
                }
                
                for booster in boosters {
                    entries.append(.booster(boosterIndex, presentationData.theme, presentationData.dateTimeFormat, booster.peer, booster.expires))
                    boosterIndex += 1
                }
                
                if !effectiveExpanded {
                    entries.append(.boostersExpand(presentationData.theme, presentationData.strings.PeopleNearby_ShowMorePeople(Int32(boostersState.count) - maxUsersDisplayedLimit)))
                }
            }
            
            if let boostersFooter {
                entries.append(.boostersInfo(presentationData.theme, boostersFooter))
            }
            
            entries.append(.boostLinkTitle(presentationData.theme, presentationData.strings.Stats_Boosts_LinkHeader))
            
            if let peer {
                let link: String
                if let addressName = peer.addressName, !addressName.isEmpty {
                    link = "t.me/\(addressName)?boost"
                } else {
                    link = "t.me/c/\(peer.id.id._internalGetInt64Value())?boost"
                }
                entries.append(.boostLink(presentationData.theme, link))
            }
            
            entries.append(.boostLinkInfo(presentationData.theme, presentationData.strings.Stats_Boosts_LinkInfo))
        }
    }
    
    return entries
}

public func channelStatsController(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, peerId: PeerId, section: ChannelStatsSection = .stats, boostStatus: ChannelBoostStatus? = nil, statsDatacenterId: Int32?) -> ViewController {
    let statePromise = ValuePromise(ChannelStatsControllerState(section: section, boostersExpanded: false), ignoreRepeated: true)
    let stateValue = Atomic(value: ChannelStatsControllerState(section: section, boostersExpanded: false))
    let updateState: ((ChannelStatsControllerState) -> ChannelStatsControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    var openMessageStatsImpl: ((MessageId) -> Void)?
    var contextActionImpl: ((MessageId, ASDisplayNode, ContextGesture?) -> Void)?
    
    let actionsDisposable = DisposableSet()    
    let dataPromise = Promise<ChannelStats?>(nil)
    let messagesPromise = Promise<MessageHistoryView?>(nil)
    
    let datacenterId: Int32 = statsDatacenterId ?? 0
        
    let statsContext = ChannelStatsContext(postbox: context.account.postbox, network: context.account.network, datacenterId: datacenterId, peerId: peerId)
    let dataSignal: Signal<ChannelStats?, NoError> = statsContext.state
    |> map { state in
        return state.stats
    } |> afterNext({ [weak statsContext] stats in
        if let statsContext = statsContext, let stats = stats {
            if case .OnDemand = stats.interactionsGraph {
                statsContext.loadInteractionsGraph()
                statsContext.loadMuteGraph()
                statsContext.loadTopHoursGraph()
                statsContext.loadNewFollowersBySourceGraph()
                statsContext.loadViewsBySourceGraph()
                statsContext.loadLanguagesGraph()
                statsContext.loadInstantPageInteractionsGraph()
            }
        }
    })
    dataPromise.set(.single(nil) |> then(dataSignal))
    
    let boostData: Signal<ChannelBoostStatus?, NoError>
    if let boostStatus {
        boostData = .single(boostStatus)
    } else {
        boostData = context.engine.peers.getChannelBoostStatus(peerId: peerId)
    }
    let boostersContext = ChannelBoostersContext(account: context.account, peerId: peerId)
    
    var presentImpl: ((ViewController) -> Void)?
    var navigateToProfileImpl: ((EnginePeer) -> Void)?
    
    let arguments = ChannelStatsControllerArguments(context: context, loadDetailedGraph: { graph, x -> Signal<StatsGraph?, NoError> in
        return statsContext.loadDetailedGraph(graph, x: x)
    }, openMessage: { messageId in
        openMessageStatsImpl?(messageId)
    }, contextAction: { messageId, node, gesture in
        contextActionImpl?(messageId, node, gesture)
    }, copyBoostLink: { link in
        UIPasteboard.general.string = "https://\(link)"
                
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        presentImpl?(UndoOverlayController(presentationData: presentationData, content: .linkCopied(text: presentationData.strings.ChannelBoost_BoostLinkCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }))
    }, shareBoostLink: { link in
        let link = "https://\(link)"
        
        let shareController = ShareController(context: context, subject: .url(link), updatedPresentationData: updatedPresentationData)
        shareController.completed = {  peerIds in
            let _ = (context.engine.data.get(
                EngineDataList(
                    peerIds.map(TelegramEngine.EngineData.Item.Peer.Peer.init)
                )
            )
            |> deliverOnMainQueue).start(next: { peerList in
                let peers = peerList.compactMap { $0 }
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                
                let text: String
                var savedMessages = false
                if peerIds.count == 1, let peerId = peerIds.first, peerId == context.account.peerId {
                    text = presentationData.strings.ChannelBoost_BoostLinkForwardTooltip_SavedMessages_One
                    savedMessages = true
                } else {
                    if peers.count == 1, let peer = peers.first {
                        let peerName = peer.id == context.account.peerId ? presentationData.strings.DialogList_SavedMessages : peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                        text = presentationData.strings.ChannelBoost_BoostLinkForwardTooltip_Chat_One(peerName).string
                    } else if peers.count == 2, let firstPeer = peers.first, let secondPeer = peers.last {
                        let firstPeerName = firstPeer.id == context.account.peerId ? presentationData.strings.DialogList_SavedMessages : firstPeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                        let secondPeerName = secondPeer.id == context.account.peerId ? presentationData.strings.DialogList_SavedMessages : secondPeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                        text = presentationData.strings.ChannelBoost_BoostLinkForwardTooltip_TwoChats_One(firstPeerName, secondPeerName).string
                    } else if let peer = peers.first {
                        let peerName = peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                        text = presentationData.strings.ChannelBoost_BoostLinkForwardTooltip_ManyChats_One(peerName, "\(peers.count - 1)").string
                    } else {
                        text = ""
                    }
                }
                
                presentImpl?(UndoOverlayController(presentationData: presentationData, content: .forward(savedMessages: savedMessages, text: text), elevatedLayout: false, animateInAsReplacement: true, action: { _ in return false }))
            })
        }
        shareController.actionCompleted = {
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            presentImpl?(UndoOverlayController(presentationData: presentationData, content: .linkCopied(text: presentationData.strings.ChannelBoost_BoostLinkCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }))
        }
        presentImpl?(shareController)
    },
    openPeer: { peer in
        navigateToProfileImpl?(peer)
    },
    expandBoosters: {
        updateState { $0.withUpdatedBoostersExpanded(true) }
    })
    
    let messageView = context.account.viewTracker.aroundMessageHistoryViewForLocation(.peer(peerId: peerId, threadId: nil), index: .upperBound, anchorIndex: .upperBound, count: 100, fixedCombinedReadStates: nil)
    |> map { messageHistoryView, _, _ -> MessageHistoryView? in
        return messageHistoryView
    }
    messagesPromise.set(.single(nil) |> then(messageView))
    
    let longLoadingSignal: Signal<Bool, NoError> = .single(false) |> then(.single(true) |> delay(2.0, queue: Queue.mainQueue()))
    
    let previousData = Atomic<ChannelStats?>(value: nil)
    
    let presentationData = updatedPresentationData?.signal ?? context.sharedContext.presentationData
    let signal = combineLatest(
        presentationData,
        statePromise.get(),
        context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)),
        dataPromise.get(),
        messagesPromise.get(),
        boostData,
        boostersContext.state,
        longLoadingSignal
    )
    |> deliverOnMainQueue
    |> map { presentationData, state, peer, data, messageView, boostData, boostersState, longLoading -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let previous = previousData.swap(data)
        var emptyStateItem: ItemListControllerEmptyStateItem?
        switch state.section {
        case .stats:
            if data == nil {
                if longLoading {
                    emptyStateItem = StatsEmptyStateItem(context: context, theme: presentationData.theme, strings: presentationData.strings)
                } else {
                    emptyStateItem = ItemListLoadingIndicatorEmptyStateItem(theme: presentationData.theme)
                }
            }
        case .boosts:
            if boostData == nil {
                emptyStateItem = ItemListLoadingIndicatorEmptyStateItem(theme: presentationData.theme)
            }
        }
        
        let messages = messageView?.entries.map { $0.message }.sorted(by: { (lhsMessage, rhsMessage) -> Bool in
            return lhsMessage.timestamp > rhsMessage.timestamp
        })
        let interactions = data?.messageInteractions.reduce([MessageId : ChannelStatsMessageInteractions]()) { (map, interactions) -> [MessageId : ChannelStatsMessageInteractions] in
            var map = map
            map[interactions.messageId] = interactions
            return map
        }
        
        
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .sectionControl([presentationData.strings.Stats_Statistics, presentationData.strings.Stats_Boosts], state.section == .boosts ? 1 : 0), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: true)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: channelStatsControllerEntries(state: state, peer: peer, data: data, messages: messages, interactions: interactions, boostData: boostData, boostersState: boostersState, presentationData: presentationData), style: .blocks, emptyStateItem: emptyStateItem, crossfadeState: previous == nil, animateChanges: false)
        
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
    controller.visibleBottomContentOffsetChanged = { offset in
        let state = stateValue.with { $0 }
        if case let .known(value) = offset, value < 100.0, case .boosts = state.section, state.boostersExpanded {
            boostersContext.loadMore()
        }
    }
    controller.titleControlValueChanged = { value in
        updateState { $0.withUpdatedSection(value == 1 ? .boosts : .stats) }
    }
    controller.didDisappear = { [weak controller] _ in
        controller?.clearItemNodesHighlight(animated: true)
    }
    openMessageStatsImpl = { [weak controller] messageId in
        controller?.push(messageStatsController(context: context, messageId: messageId, statsDatacenterId: statsDatacenterId))
    }
    contextActionImpl = { [weak controller] messageId, sourceNode, gesture in
        guard let controller = controller, let sourceNode = sourceNode as? ContextExtractedContentContainingNode else {
            return
        }
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        var items: [ContextMenuItem] = []
        items.append(.action(ContextMenuActionItem(text: presentationData.strings.Conversation_ViewInChannel, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/GoToMessage"), color: theme.contextMenu.primaryColor) }, action: { [weak controller] c, _ in
            c.dismiss(completion: {
                let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
                |> deliverOnMainQueue).start(next: { peer in
                    guard let peer = peer else {
                        return
                    }
                    
                    if let navigationController = controller?.navigationController as? NavigationController {
                        context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peer), subject: .message(id: .id(messageId), highlight: true, timecode: nil)))
                    }
                })
            })
        })))
        
        let contextController = ContextController(presentationData: presentationData, source: .extracted(ChannelStatsContextExtractedContentSource(controller: controller, sourceNode: sourceNode, keepInPlace: false)), items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
        controller.presentInGlobalOverlay(contextController)
    }
    presentImpl = { [weak controller] c in
        controller?.present(c, in: .window(.root))
    }
    navigateToProfileImpl = { [weak controller] peer in
        if let navigationController = controller?.navigationController as? NavigationController, let controller = context.sharedContext.makePeerInfoController(context: context, updatedPresentationData: nil, peer: peer._asPeer(), mode: .generic, avatarInitiallyExpanded: peer.largeProfileImage != nil, fromChat: false, requestsContext: nil) {
            navigationController.pushViewController(controller)
        }
    }
    return controller
}

private final class ChannelStatsContextExtractedContentSource: ContextExtractedContentSource {
    var keepInPlace: Bool
    let ignoreContentTouches: Bool = true
    let blurBackground: Bool = true
    
    private let controller: ViewController
    private let sourceNode: ContextExtractedContentContainingNode
    
    init(controller: ViewController, sourceNode: ContextExtractedContentContainingNode, keepInPlace: Bool) {
        self.controller = controller
        self.sourceNode = sourceNode
        self.keepInPlace = keepInPlace
    }
    
    func takeView() -> ContextControllerTakeViewInfo? {
        return ContextControllerTakeViewInfo(containingItem: .node(self.sourceNode), contentAreaInScreenSpace: UIScreen.main.bounds)
    }
    
    func putBack() -> ContextControllerPutBackViewInfo? {
        return ContextControllerPutBackViewInfo(contentAreaInScreenSpace: UIScreen.main.bounds)
    }
}
