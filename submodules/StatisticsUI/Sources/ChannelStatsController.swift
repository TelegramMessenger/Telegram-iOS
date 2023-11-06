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
import PremiumUI

private let initialBoostersDisplayedLimit: Int32 = 5

private final class ChannelStatsControllerArguments {
    let context: AccountContext
    let loadDetailedGraph: (StatsGraph, Int64) -> Signal<StatsGraph?, NoError>
    let openMessageStats: (MessageId) -> Void
    let contextAction: (MessageId, ASDisplayNode, ContextGesture?) -> Void
    let copyBoostLink: (String) -> Void
    let shareBoostLink: (String) -> Void
    let openBoost: (ChannelBoostersContext.State.Boost) -> Void
    let expandBoosters: () -> Void
    let openGifts: () -> Void
    let createPrepaidGiveaway: (PrepaidGiveaway) -> Void
    let updateGiftsSelected: (Bool) -> Void
        
    init(context: AccountContext, loadDetailedGraph: @escaping (StatsGraph, Int64) -> Signal<StatsGraph?, NoError>, openMessage: @escaping (MessageId) -> Void, contextAction: @escaping (MessageId, ASDisplayNode, ContextGesture?) -> Void, copyBoostLink: @escaping (String) -> Void, shareBoostLink: @escaping (String) -> Void, openBoost: @escaping (ChannelBoostersContext.State.Boost) -> Void, expandBoosters: @escaping () -> Void, openGifts: @escaping () -> Void, createPrepaidGiveaway: @escaping (PrepaidGiveaway) -> Void, updateGiftsSelected: @escaping (Bool) -> Void) {
        self.context = context
        self.loadDetailedGraph = loadDetailedGraph
        self.openMessageStats = openMessage
        self.contextAction = contextAction
        self.copyBoostLink = copyBoostLink
        self.shareBoostLink = shareBoostLink
        self.openBoost = openBoost
        self.expandBoosters = expandBoosters
        self.openGifts = openGifts
        self.createPrepaidGiveaway = createPrepaidGiveaway
        self.updateGiftsSelected = updateGiftsSelected
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
    case boostPrepaid
    case boosters
    case boostLink
    case gifts
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
    
    case boostPrepaidTitle(PresentationTheme, String)
    case boostPrepaid(Int32, PresentationTheme, String, String, PrepaidGiveaway)
    case boostPrepaidInfo(PresentationTheme, String)
    
    case boostersTitle(PresentationTheme, String)
    case boostersPlaceholder(PresentationTheme, String)
    case boosterTabs(PresentationTheme, String, String, Bool)
    case booster(Int32, PresentationTheme, PresentationDateTimeFormat, ChannelBoostersContext.State.Boost)
    case boostersExpand(PresentationTheme, String)
    case boostersInfo(PresentationTheme, String)
    
    case boostLinkTitle(PresentationTheme, String)
    case boostLink(PresentationTheme, String)
    case boostLinkInfo(PresentationTheme, String)
    
    case gifts(PresentationTheme, String)
    case giftsInfo(PresentationTheme, String)
    
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
            case .boostPrepaidTitle, .boostPrepaid, .boostPrepaidInfo:
                return StatsSection.boostPrepaid.rawValue
            case .boostersTitle, .boostersPlaceholder, .boosterTabs, .booster, .boostersExpand, .boostersInfo:
                return StatsSection.boosters.rawValue
            case .boostLinkTitle, .boostLink, .boostLinkInfo:
                return StatsSection.boostLink.rawValue
            case .gifts, .giftsInfo:
                return StatsSection.gifts.rawValue
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
            case .boostPrepaidTitle:
                return 2003
            case let .boostPrepaid(index, _, _, _, _):
                return 2004 + index
            case .boostPrepaidInfo:
                return 2100
            case .boostersTitle:
                return 2101
            case .boostersPlaceholder:
                return 2102
            case .boosterTabs:
                return 2103
            case let .booster(index, _, _, _):
                return 2104 + index
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
            case .gifts:
                return 10005
            case .giftsInfo:
                return 10006
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
            case let .boostPrepaidTitle(lhsTheme, lhsText):
                if case let .boostPrepaidTitle(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .boostPrepaid(lhsIndex, lhsTheme, lhsTitle, lhsSubtitle, lhsPrepaidGiveaway):
                if case let .boostPrepaid(rhsIndex, rhsTheme, rhsTitle, rhsSubtitle, rhsPrepaidGiveaway) = rhs, lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsSubtitle == rhsSubtitle, lhsPrepaidGiveaway == rhsPrepaidGiveaway {
                    return true
                } else {
                    return false
                }
            case let .boostPrepaidInfo(lhsTheme, lhsText):
                if case let .boostPrepaidInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
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
            case let .boosterTabs(lhsTheme, lhsBoostText, lhsGiftText, lhsGiftSelected):
                if case let .boosterTabs(rhsTheme, rhsBoostText, rhsGiftText, rhsGiftSelected) = rhs, lhsTheme === rhsTheme, lhsBoostText == rhsBoostText, lhsGiftText == rhsGiftText, lhsGiftSelected == rhsGiftSelected {
                    return true
                } else {
                    return false
                }
            case let .booster(lhsIndex, lhsTheme, lhsDateTimeFormat, lhsBoost):
                if case let .booster(rhsIndex, rhsTheme, rhsDateTimeFormat, rhsBoost) = rhs, lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsDateTimeFormat == rhsDateTimeFormat, lhsBoost == rhsBoost {
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
            case let .gifts(lhsTheme, lhsText):
                if case let .gifts(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .giftsInfo(lhsTheme, lhsText):
                if case let .giftsInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
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
                 let .boostPrepaidTitle(_, text),
                 let .boostersTitle(_, text),
                 let .boostLinkTitle(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .boostPrepaidInfo(_, text),
                 let .boostersInfo(_, text),
                 let .boostLinkInfo(_, text),
                 let .giftsInfo(_, text):
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
            case let .boosterTabs(_, boostText, giftText, giftSelected):
                return BoostsTabsItem(theme: presentationData.theme, boostsText: boostText, giftsText: giftText, selectedTab: giftSelected ? .gifts : .boosts, sectionId: self.section, selectionUpdated: { tab in
                    arguments.updateGiftsSelected(tab == .gifts)
                })
            case let .booster(_, _, _, boost):
                let count = boost.multiplier
                let expiresValue = stringForDate(timestamp: boost.expires, strings: presentationData.strings)
                let expiresString: String
                
                let durationMonths = Int32(round(Float(boost.expires - boost.date) / (86400.0 * 30.0)))
                let durationString = presentationData.strings.Stats_Boosts_ShortMonth("\(durationMonths)").string
            
                let title: String
                let icon: GiftOptionItem.Icon
                var label: String?
                if boost.flags.contains(.isGiveaway) {
                    label = "🏆 \(presentationData.strings.Stats_Boosts_Giveaway)"
                } else if boost.flags.contains(.isGift) {
                    label = "🎁 \(presentationData.strings.Stats_Boosts_Gift)"
                }
            
                let color: GiftOptionItem.Icon.Color
                if durationMonths > 11 {
                    color = .red
                } else if durationMonths > 5 {
                    color = .blue
                } else {
                    color = .green
                }
            
                if boost.flags.contains(.isUnclaimed) {
                    title = presentationData.strings.Stats_Boosts_Unclaimed
                    icon = .image(color: color, name: "Premium/Unclaimed")
                    expiresString = "\(durationString) • \(expiresValue)"
                } else if let peer = boost.peer {
                    title = peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                    icon = .peer(peer)
                    if let _ = label {
                        expiresString = "\(durationString) • \(expiresValue)"
                    } else {
                        expiresString = presentationData.strings.Stats_Boosts_ExpiresOn(expiresValue).string
                    }
                } else {
                    if boost.flags.contains(.isUnclaimed) {
                        title = presentationData.strings.Stats_Boosts_Unclaimed
                        icon = .image(color: color, name: "Premium/Unclaimed")
                    } else if boost.flags.contains(.isGiveaway) {
                        title = presentationData.strings.Stats_Boosts_ToBeDistributed
                        icon = .image(color: color, name: "Premium/ToBeDistributed")
                    } else {
                        title = "Unknown"
                        icon = .image(color: color, name: "Premium/ToBeDistributed")
                    }
                    expiresString = "\(durationString) • \(expiresValue)"
                }
                return GiftOptionItem(presentationData: presentationData, context: arguments.context, icon: icon, title: title, titleFont: .bold, titleBadge: count > 1 ? "\(count)" : nil, subtitle: expiresString, label: label.flatMap { .semitransparent($0) }, sectionId: self.section, action: {
                    arguments.openBoost(boost)
                })
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
            case let .gifts(theme, title):
                return ItemListPeerActionItem(presentationData: presentationData, icon: PresentationResourcesItemList.addBoostsIcon(theme), title: title, sectionId: self.section, editing: false, action: {
                    arguments.openGifts()
                })
            case let .boostPrepaid(_, _, title, subtitle, prepaidGiveaway):
                let color: GiftOptionItem.Icon.Color
                switch prepaidGiveaway.months {
                case 3:
                    color = .green
                case 6:
                    color = .blue
                case 12:
                    color = .red
                default:
                    color = .blue
                }
                return GiftOptionItem(presentationData: presentationData, context: arguments.context, icon: .image(color: color, name: "Premium/Giveaway"), title: title, titleFont: .bold, titleBadge: "\(prepaidGiveaway.quantity * 4)", subtitle: subtitle, label: nil, sectionId: self.section, action: {
                    arguments.createPrepaidGiveaway(prepaidGiveaway)
                })
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
    let moreBoostersDisplayed: Int32
    let giftsSelected: Bool
  
    init() {
        self.section = .stats
        self.boostersExpanded = false
        self.moreBoostersDisplayed = 0
        self.giftsSelected = false
    }
    
    init(section: ChannelStatsSection, boostersExpanded: Bool, moreBoostersDisplayed: Int32, giftsSelected: Bool) {
        self.section = section
        self.boostersExpanded = boostersExpanded
        self.moreBoostersDisplayed = moreBoostersDisplayed
        self.giftsSelected = giftsSelected
    }
    
    static func ==(lhs: ChannelStatsControllerState, rhs: ChannelStatsControllerState) -> Bool {
        if lhs.section != rhs.section {
            return false
        }
        if lhs.boostersExpanded != rhs.boostersExpanded {
            return false
        }
        if lhs.moreBoostersDisplayed != rhs.moreBoostersDisplayed {
            return false
        }
        if lhs.giftsSelected != rhs.giftsSelected {
            return false
        }
        return true
    }
    
    func withUpdatedSection(_ section: ChannelStatsSection) -> ChannelStatsControllerState {
        return ChannelStatsControllerState(section: section, boostersExpanded: self.boostersExpanded, moreBoostersDisplayed: self.moreBoostersDisplayed, giftsSelected: self.giftsSelected)
    }
    
    func withUpdatedBoostersExpanded(_ boostersExpanded: Bool) -> ChannelStatsControllerState {
        return ChannelStatsControllerState(section: self.section, boostersExpanded: boostersExpanded, moreBoostersDisplayed: self.moreBoostersDisplayed, giftsSelected: self.giftsSelected)
    }
    
    func withUpdatedMoreBoostersDisplayed(_ moreBoostersDisplayed: Int32) -> ChannelStatsControllerState {
        return ChannelStatsControllerState(section: self.section, boostersExpanded: self.boostersExpanded, moreBoostersDisplayed: moreBoostersDisplayed, giftsSelected: self.giftsSelected)
    }
    
    func withUpdatedGiftsSelected(_ giftsSelected: Bool) -> ChannelStatsControllerState {
        return ChannelStatsControllerState(section: self.section, boostersExpanded: self.boostersExpanded, moreBoostersDisplayed: self.moreBoostersDisplayed, giftsSelected: giftsSelected)
    }
}


private func channelStatsControllerEntries(state: ChannelStatsControllerState, peer: EnginePeer?, data: ChannelStats?, messages: [Message]?, interactions: [MessageId: ChannelStatsMessageInteractions]?, boostData: ChannelBoostStatus?, boostersState: ChannelBoostersContext.State?, giftsState: ChannelBoostersContext.State?, presentationData: PresentationData, giveawayAvailable: Bool) -> [StatsEntry] {
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
            
            if !boostData.prepaidGiveaways.isEmpty {
                entries.append(.boostPrepaidTitle(presentationData.theme, presentationData.strings.Stats_Boosts_PrepaidGiveawaysTitle))
                var i: Int32 = 0
                for giveaway in boostData.prepaidGiveaways {
                    entries.append(.boostPrepaid(i, presentationData.theme, presentationData.strings.Stats_Boosts_PrepaidGiveawayCount(giveaway.quantity), presentationData.strings.Stats_Boosts_PrepaidGiveawayMonths("\(giveaway.months)").string, giveaway))
                    i += 1
                }
                entries.append(.boostPrepaidInfo(presentationData.theme, presentationData.strings.Stats_Boosts_PrepaidGiveawaysInfo))
            }
            
            let boostersTitle: String
            let boostersPlaceholder: String?
            let boostersFooter: String?
            if let boostersState, boostersState.count > 0 {
                boostersTitle = presentationData.strings.Stats_Boosts_Boosts(boostersState.count)
                boostersPlaceholder = nil
                boostersFooter = presentationData.strings.Stats_Boosts_BoostersInfo
            } else {
                boostersTitle = presentationData.strings.Stats_Boosts_BoostsNone
                boostersPlaceholder = presentationData.strings.Stats_Boosts_NoBoostersYet
                boostersFooter = nil
            }
            entries.append(.boostersTitle(presentationData.theme, boostersTitle))
            
            if let boostersPlaceholder {
                entries.append(.boostersPlaceholder(presentationData.theme, boostersPlaceholder))
            }
            
            var boostsCount: Int32 = 0
            if let boostersState {
                boostsCount = boostersState.count
            }
            var giftsCount: Int32 = 0
            if let giftsState {
                giftsCount = giftsState.count
            }
            
            if boostsCount > 0 && giftsCount > 0 && boostsCount != giftsCount {
                entries.append(.boosterTabs(presentationData.theme, presentationData.strings.Stats_Boosts_TabBoosts(boostsCount), presentationData.strings.Stats_Boosts_TabGifts(giftsCount), state.giftsSelected))
            }
            
            let selectedState: ChannelBoostersContext.State?
            if state.giftsSelected {
                selectedState = giftsState
            } else {
                selectedState = boostersState
            }
            
            if let selectedState {
                var boosterIndex: Int32 = 0
                
                var boosters: [ChannelBoostersContext.State.Boost] = selectedState.boosts
                
                var limit: Int32
                if state.boostersExpanded {
                    limit = 25 + state.moreBoostersDisplayed
                } else {
                    limit = initialBoostersDisplayedLimit
                }
                boosters = Array(boosters.prefix(Int(limit)))
                
                for booster in boosters {
                    entries.append(.booster(boosterIndex, presentationData.theme, presentationData.dateTimeFormat, booster))
                    boosterIndex += 1
                }
                
                let totalBoostsCount = boosters.reduce(Int32(0)) { partialResult, boost in
                    return partialResult + boost.multiplier
                }
                
                if totalBoostsCount < selectedState.count {
                    let moreCount: Int32
                    if !state.boostersExpanded {
                        moreCount = min(80, selectedState.count - totalBoostsCount)
                    } else {
                        moreCount = min(200, selectedState.count - totalBoostsCount)
                    }
                    entries.append(.boostersExpand(presentationData.theme, presentationData.strings.Stats_Boosts_ShowMoreBoosts(moreCount)))
                }
            }
            
            if let boostersFooter {
                entries.append(.boostersInfo(presentationData.theme, boostersFooter))
            }
            
            entries.append(.boostLinkTitle(presentationData.theme, presentationData.strings.Stats_Boosts_LinkHeader))
            entries.append(.boostLink(presentationData.theme, boostData.url))
            entries.append(.boostLinkInfo(presentationData.theme, presentationData.strings.Stats_Boosts_LinkInfo))
            
            if giveawayAvailable {
                entries.append(.gifts(presentationData.theme, presentationData.strings.Stats_Boosts_GetBoosts))
                entries.append(.giftsInfo(presentationData.theme, presentationData.strings.Stats_Boosts_GetBoostsInfo))
            }
        }
    }
    
    return entries
}

public func channelStatsController(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, peerId: PeerId, section: ChannelStatsSection = .stats, boostStatus: ChannelBoostStatus? = nil, statsDatacenterId: Int32?) -> ViewController {
    let statePromise = ValuePromise(ChannelStatsControllerState(section: section, boostersExpanded: false, moreBoostersDisplayed: 0, giftsSelected: false), ignoreRepeated: true)
    let stateValue = Atomic(value: ChannelStatsControllerState(section: section, boostersExpanded: false, moreBoostersDisplayed: 0, giftsSelected: false))
    let updateState: ((ChannelStatsControllerState) -> ChannelStatsControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    let premiumConfiguration = PremiumConfiguration.with(appConfiguration: context.currentAppConfiguration.with { $0 })
    
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
        boostData = .single(nil) |> then(context.engine.peers.getChannelBoostStatus(peerId: peerId))
    }
    let boostsContext = ChannelBoostersContext(account: context.account, peerId: peerId, gift: false)
    let giftsContext = ChannelBoostersContext(account: context.account, peerId: peerId, gift: true)
    
    var dismissAllTooltipsImpl: (() -> Void)?
    var presentImpl: ((ViewController) -> Void)?
    var pushImpl: ((ViewController) -> Void)?
    var navigateToChatImpl: ((EnginePeer) -> Void)?
    var navigateToMessageImpl: ((EngineMessage.Id) -> Void)?
    
    let arguments = ChannelStatsControllerArguments(context: context, loadDetailedGraph: { graph, x -> Signal<StatsGraph?, NoError> in
        return statsContext.loadDetailedGraph(graph, x: x)
    }, openMessage: { messageId in
        openMessageStatsImpl?(messageId)
    }, contextAction: { messageId, node, gesture in
        contextActionImpl?(messageId, node, gesture)
    }, copyBoostLink: { link in
        UIPasteboard.general.string = link
                
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        presentImpl?(UndoOverlayController(presentationData: presentationData, content: .linkCopied(text: presentationData.strings.ChannelBoost_BoostLinkCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }))
    }, shareBoostLink: { link in        
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
    openBoost: { boost in
        dismissAllTooltipsImpl?()
        
        if let peer = boost.peer, !boost.flags.contains(.isGiveaway) && !boost.flags.contains(.isGift) {
            navigateToChatImpl?(peer)
            return
        }
        
        if boost.peer == nil, boost.flags.contains(.isGiveaway) && !boost.flags.contains(.isUnclaimed) {
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            presentImpl?(UndoOverlayController(presentationData: presentationData, content: .info(title: nil, text: presentationData.strings.Stats_Boosts_TooltipToBeDistributed, timeout: nil, customUndoText: nil), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }))
            return
        }
        
        let controller = PremiumGiftCodeScreen(
            context: context,
            subject: .boost(peerId, boost),
            action: {},
            openPeer: { peer in
                navigateToChatImpl?(peer)
            },
            openMessage: { messageId in
                navigateToMessageImpl?(messageId)
            })
        pushImpl?(controller)
    },
    expandBoosters: {
        var giftsSelected = false
        updateState { state in
            giftsSelected = state.giftsSelected
            if state.boostersExpanded {
                return state.withUpdatedMoreBoostersDisplayed(state.moreBoostersDisplayed + 50)
            } else {
                return state.withUpdatedBoostersExpanded(true)
            }
        }
        if giftsSelected {
            giftsContext.loadMore()
        } else {
            boostsContext.loadMore()
        }
    },
    openGifts: {
        let controller = createGiveawayController(context: context, peerId: peerId, subject: .generic)
        pushImpl?(controller)
    },
    createPrepaidGiveaway: { prepaidGiveaway in
        let controller = createGiveawayController(context: context, peerId: peerId, subject: .prepaid(prepaidGiveaway))
        pushImpl?(controller)
    },
    updateGiftsSelected: { selected in
        updateState { $0.withUpdatedGiftsSelected(selected).withUpdatedBoostersExpanded(false) }
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
        boostsContext.state,
        giftsContext.state,
        longLoadingSignal
    )
    |> deliverOnMainQueue
    |> map { presentationData, state, peer, data, messageView, boostData, boostersState, giftsState, longLoading -> (ItemListControllerState, (ItemListNodeState, Any)) in
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
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: channelStatsControllerEntries(state: state, peer: peer, data: data, messages: messages, interactions: interactions, boostData: boostData, boostersState: boostersState, giftsState: giftsState, presentationData: presentationData, giveawayAvailable: premiumConfiguration.giveawayGiftsPurchaseAvailable), style: .blocks, emptyStateItem: emptyStateItem, crossfadeState: previous == nil, animateChanges: false)
        
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
                        context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peer), subject: .message(id: .id(messageId), highlight: ChatControllerSubject.MessageHighlight(quote: nil), timecode: nil)))
                    }
                })
            })
        })))
        
        let contextController = ContextController(presentationData: presentationData, source: .extracted(ChannelStatsContextExtractedContentSource(controller: controller, sourceNode: sourceNode, keepInPlace: false)), items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
        controller.presentInGlobalOverlay(contextController)
    }
    dismissAllTooltipsImpl = { [weak controller] in
        if let controller {
            controller.window?.forEachController({ controller in
                if let controller = controller as? UndoOverlayController {
                    controller.dismiss()
                }
            })
            controller.forEachController({ controller in
                if let controller = controller as? UndoOverlayController {
                    controller.dismiss()
                }
                return true
            })
        }
    }
    presentImpl = { [weak controller] c in
        controller?.present(c, in: .window(.root))
    }
    pushImpl = { [weak controller] c in
        controller?.push(c)
    }
    navigateToChatImpl = { [weak controller] peer in
        if let navigationController = controller?.navigationController as? NavigationController {
            context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peer), keepStack: .always, purposefulAction: {}, peekData: nil))
        }
    }
    navigateToMessageImpl = { [weak controller] messageId in
        let _ = (context.engine.data.get(
            TelegramEngine.EngineData.Item.Peer.Peer(id: messageId.peerId)
        )
        |> deliverOnMainQueue).start(next: { peer in
            guard let peer = peer else {
                return
            }
            if let navigationController = controller?.navigationController as? NavigationController {
                context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peer), subject: .message(id: .id(messageId), highlight: ChatControllerSubject.MessageHighlight(quote: nil), timecode: nil), keepStack: .always, useExisting: false, purposefulAction: {}, peekData: nil))
            }
        })
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
