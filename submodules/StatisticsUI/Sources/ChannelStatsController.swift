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
import StoryContainerScreen
import TelegramNotices
import ComponentFlow
import BoostLevelIconComponent
import StarsWithdrawalScreen

private let initialBoostersDisplayedLimit: Int32 = 5
private let initialTransactionsDisplayedLimit: Int32 = 5

private final class ChannelStatsControllerArguments {
    let context: AccountContext
    let loadDetailedGraph: (StatsGraph, Int64) -> Signal<StatsGraph?, NoError>
    let openPostStats: (EnginePeer, StatsPostItem) -> Void
    let openStory: (EngineStoryItem, UIView) -> Void
    let contextAction: (MessageId, ASDisplayNode, ContextGesture?) -> Void
    let copyBoostLink: (String) -> Void
    let shareBoostLink: (String) -> Void
    let openBoost: (ChannelBoostersContext.State.Boost) -> Void
    let expandBoosters: () -> Void
    let openGifts: () -> Void
    let createPrepaidGiveaway: (PrepaidGiveaway) -> Void
    let updateGiftsSelected: (Bool) -> Void
    let updateStarsSelected: (Bool) -> Void
    
    let requestTonWithdraw: () -> Void
    let requestStarsWithdraw: () -> Void
    let showTimeoutTooltip: (Int32) -> Void
    let buyAds: () -> Void
    let openMonetizationIntro: () -> Void
    let openMonetizationInfo: () -> Void
    let openTonTransaction: (StarsContext.State.Transaction) -> Void
    let openStarsTransaction: (StarsContext.State.Transaction) -> Void
    let expandTransactions: (Bool) -> Void
    let updateCpmEnabled: (Bool) -> Void
    let presentCpmLocked: () -> Void
    let openEarnStars: () -> Void
    let dismissInput: () -> Void
    
    init(context: AccountContext, loadDetailedGraph: @escaping (StatsGraph, Int64) -> Signal<StatsGraph?, NoError>, openPostStats: @escaping (EnginePeer, StatsPostItem) -> Void, openStory: @escaping (EngineStoryItem, UIView) -> Void, contextAction: @escaping (MessageId, ASDisplayNode, ContextGesture?) -> Void, copyBoostLink: @escaping (String) -> Void, shareBoostLink: @escaping (String) -> Void, openBoost: @escaping (ChannelBoostersContext.State.Boost) -> Void, expandBoosters: @escaping () -> Void, openGifts: @escaping () -> Void, createPrepaidGiveaway: @escaping (PrepaidGiveaway) -> Void, updateGiftsSelected: @escaping (Bool) -> Void, updateStarsSelected: @escaping (Bool) -> Void, requestTonWithdraw: @escaping () -> Void, requestStarsWithdraw: @escaping () -> Void, showTimeoutTooltip: @escaping (Int32) -> Void, buyAds: @escaping () -> Void, openMonetizationIntro: @escaping () -> Void, openMonetizationInfo: @escaping () -> Void, openTonTransaction: @escaping (StarsContext.State.Transaction) -> Void, openStarsTransaction: @escaping (StarsContext.State.Transaction) -> Void, expandTransactions: @escaping (Bool) -> Void, updateCpmEnabled: @escaping (Bool) -> Void, presentCpmLocked: @escaping () -> Void, openEarnStars: @escaping () -> Void, dismissInput: @escaping () -> Void) {
        self.context = context
        self.loadDetailedGraph = loadDetailedGraph
        self.openPostStats = openPostStats
        self.openStory = openStory
        self.contextAction = contextAction
        self.copyBoostLink = copyBoostLink
        self.shareBoostLink = shareBoostLink
        self.openBoost = openBoost
        self.expandBoosters = expandBoosters
        self.openGifts = openGifts
        self.createPrepaidGiveaway = createPrepaidGiveaway
        self.updateGiftsSelected = updateGiftsSelected
        self.updateStarsSelected = updateStarsSelected
        self.requestTonWithdraw = requestTonWithdraw
        self.requestStarsWithdraw = requestStarsWithdraw
        self.showTimeoutTooltip = showTimeoutTooltip
        self.buyAds = buyAds
        self.openMonetizationIntro = openMonetizationIntro
        self.openMonetizationInfo = openMonetizationInfo
        self.openTonTransaction = openTonTransaction
        self.openStarsTransaction = openStarsTransaction
        self.expandTransactions = expandTransactions
        self.updateCpmEnabled = updateCpmEnabled
        self.presentCpmLocked = presentCpmLocked
        self.openEarnStars = openEarnStars
        self.dismissInput = dismissInput
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
    case instantPageInteractions
    case reactionsByEmotion
    case storyInteractions
    case storyReactionsByEmotion
    case recentPosts
  
    case boostLevel
    case boostOverview
    case boostPrepaid
    case boosters
    case boostLink
    case boostGifts
    
    case adsHeader
    case adsImpressions
    case adsTonRevenue
    case adsStarsRevenue
    case adsProceeds
    case adsTonBalance
    case adsStarsBalance
    case adsTransactions
    case adsCpm
    
    case earnStars
}

enum StatsPostItem: Equatable {
    static func == (lhs: StatsPostItem, rhs: StatsPostItem) -> Bool {
        switch lhs {
        case let .message(lhsMessage):
            if case let .message(rhsMessage) = rhs {
                return lhsMessage.id == rhsMessage.id
            } else {
                return false
            }
        case let .story(lhsPeer, lhsStory):
            if case let .story(rhsPeer, rhsStory) = rhs, lhsPeer == rhsPeer, lhsStory == rhsStory {
                return true
            } else {
                return false
            }
        }
    }
    
    case message(Message)
    case story(EnginePeer, EngineStoryItem)
    
    var isStory: Bool {
        if case .story = self {
            return true
        } else {
            return false
        }
    }
    
    var timestamp: Int32 {
        switch self {
        case let .message(message):
            return message.timestamp
        case let .story(_, story):
            return story.timestamp
        }
    }
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

    case reactionsByEmotionTitle(PresentationTheme, String)
    case reactionsByEmotionGraph(PresentationTheme, PresentationStrings, PresentationDateTimeFormat, StatsGraph, ChartType)
    
    case storyInteractionsTitle(PresentationTheme, String)
    case storyInteractionsGraph(PresentationTheme, PresentationStrings, PresentationDateTimeFormat, StatsGraph, ChartType)
    
    case storyReactionsByEmotionTitle(PresentationTheme, String)
    case storyReactionsByEmotionGraph(PresentationTheme, PresentationStrings, PresentationDateTimeFormat, StatsGraph, ChartType)
    
    case instantPageInteractionsTitle(PresentationTheme, String)
    case instantPageInteractionsGraph(PresentationTheme, PresentationStrings, PresentationDateTimeFormat, StatsGraph, ChartType)
    
    case postsTitle(PresentationTheme, String)
    case post(Int32, PresentationTheme, PresentationStrings, PresentationDateTimeFormat, Peer, StatsPostItem, ChannelStatsPostInteractions)

    case boostLevel(PresentationTheme, Int32, Int32, CGFloat)
    
    case boostOverviewTitle(PresentationTheme, String)
    case boostOverview(PresentationTheme, ChannelBoostStatus, Bool)
    
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
    
    case boostGifts(PresentationTheme, String)
    case boostGiftsInfo(PresentationTheme, String)
    
    case adsHeader(PresentationTheme, String)
  
    case adsImpressionsTitle(PresentationTheme, String)
    case adsImpressionsGraph(PresentationTheme, PresentationStrings, PresentationDateTimeFormat, StatsGraph, ChartType)
    
    case adsTonRevenueTitle(PresentationTheme, String)
    case adsTonRevenueGraph(PresentationTheme, PresentationStrings, PresentationDateTimeFormat, StatsGraph, ChartType, Double)
    
    case adsStarsRevenueTitle(PresentationTheme, String)
    case adsStarsRevenueGraph(PresentationTheme, PresentationStrings, PresentationDateTimeFormat, StatsGraph, ChartType, Double)
    
    case adsProceedsTitle(PresentationTheme, String)
    case adsProceedsOverview(PresentationTheme, StarsRevenueStats?, StarsRevenueStats?)
    case adsProceedsInfo(PresentationTheme, String)
    
    case adsTonBalanceTitle(PresentationTheme, String)
    case adsTonBalance(PresentationTheme, StarsRevenueStats, Bool, Bool)
    case adsTonBalanceInfo(PresentationTheme, String)
    
    case adsStarsBalanceTitle(PresentationTheme, String)
    case adsStarsBalance(PresentationTheme, StarsRevenueStats, Bool, Bool, Bool, Int32?)
    case adsStarsBalanceInfo(PresentationTheme, String)
    
    case earnStarsInfo
    case adsTransactionsTitle(PresentationTheme, String)
    case adsTransactionsTabs(PresentationTheme, String, String, Bool)
    case adsTransaction(Int32, PresentationTheme, StarsContext.State.Transaction)
    case adsStarsTransaction(Int32, PresentationTheme, StarsContext.State.Transaction)
    case adsTransactionsExpand(PresentationTheme, String, Bool)
    
    case adsCpmToggle(PresentationTheme, String, Int32, Bool?)
    case adsCpmInfo(PresentationTheme, String)
    
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
            case .instantPageInteractionsTitle, .instantPageInteractionsGraph:
                return StatsSection.instantPageInteractions.rawValue
            case .reactionsByEmotionTitle, .reactionsByEmotionGraph:
                return StatsSection.reactionsByEmotion.rawValue
            case .storyInteractionsTitle, .storyInteractionsGraph:
                return StatsSection.storyInteractions.rawValue
            case .storyReactionsByEmotionTitle, .storyReactionsByEmotionGraph:
                return StatsSection.storyReactionsByEmotion.rawValue
            case .postsTitle, .post:
                return StatsSection.recentPosts.rawValue
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
            case .boostGifts, .boostGiftsInfo:
                return StatsSection.boostGifts.rawValue
            case .adsHeader:
                return StatsSection.adsHeader.rawValue
            case .adsImpressionsTitle, .adsImpressionsGraph:
                return StatsSection.adsImpressions.rawValue
            case .adsTonRevenueTitle, .adsTonRevenueGraph:
                return StatsSection.adsTonRevenue.rawValue
            case .adsStarsRevenueTitle, .adsStarsRevenueGraph:
                return StatsSection.adsStarsRevenue.rawValue
            case .adsProceedsTitle, .adsProceedsOverview, .adsProceedsInfo:
                return StatsSection.adsProceeds.rawValue
            case .adsTonBalanceTitle, .adsTonBalance, .adsTonBalanceInfo:
                return StatsSection.adsTonBalance.rawValue
            case .adsStarsBalanceTitle, .adsStarsBalance, .adsStarsBalanceInfo:
                return StatsSection.adsStarsBalance.rawValue
            case .earnStarsInfo:
                return StatsSection.earnStars.rawValue
            case .adsTransactionsTitle, .adsTransactionsTabs, .adsTransaction, .adsStarsTransaction, .adsTransactionsExpand:
                return StatsSection.adsTransactions.rawValue
            case .adsCpmToggle, .adsCpmInfo:
                return StatsSection.adsCpm.rawValue
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
            case .reactionsByEmotionTitle:
                return 20
            case .reactionsByEmotionGraph:
                return 21
            case .storyInteractionsTitle:
                return 22
            case .storyInteractionsGraph:
                return 23
            case .storyReactionsByEmotionTitle:
                return 24
            case .storyReactionsByEmotionGraph:
                return 25
            case .postsTitle:
                return 26
            case let .post(index, _, _, _, _, _, _):
                return 27 + index
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
            case .boostGifts:
                return 10005
            case .boostGiftsInfo:
                return 10006
            case .adsHeader:
                return 20000
            case .adsImpressionsTitle:
                return 20001
            case .adsImpressionsGraph:
                return 20002
            case .adsTonRevenueTitle:
                return 20003
            case .adsTonRevenueGraph:
                return 20004
            case .adsStarsRevenueTitle:
                return 20005
            case .adsStarsRevenueGraph:
                return 20006
            case .adsProceedsTitle:
                return 20007
            case .adsProceedsOverview:
                return 20008
            case .adsProceedsInfo:
                return 20009
            case .adsTonBalanceTitle:
                return 20010
            case .adsTonBalance:
                return 20011
            case .adsTonBalanceInfo:
                return 20012
            case .adsStarsBalanceTitle:
                return 20013
            case .adsStarsBalance:
                return 20014
            case .adsStarsBalanceInfo:
                return 20015
            case .earnStarsInfo:
                return 20016
            case .adsTransactionsTitle:
                return 20017
            case .adsTransactionsTabs:
                return 20018
            case let .adsTransaction(index, _, _):
                return 20019 + index
            case let .adsStarsTransaction(index, _, _):
                return 30018 + index
            case .adsTransactionsExpand:
                return 40000
            case .adsCpmToggle:
                return 40001
            case .adsCpmInfo:
                return 40002
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
            case let .reactionsByEmotionTitle(lhsTheme, lhsText):
                if case let .reactionsByEmotionTitle(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .reactionsByEmotionGraph(lhsTheme, lhsStrings, lhsDateTimeFormat, lhsGraph, lhsType):
                if case let .reactionsByEmotionGraph(rhsTheme, rhsStrings, rhsDateTimeFormat, rhsGraph, rhsType) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsDateTimeFormat == rhsDateTimeFormat, lhsGraph == rhsGraph, lhsType == rhsType {
                    return true
                } else {
                    return false
                }
            case let .storyInteractionsTitle(lhsTheme, lhsText):
                if case let .storyInteractionsTitle(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .storyInteractionsGraph(lhsTheme, lhsStrings, lhsDateTimeFormat, lhsGraph, lhsType):
                if case let .storyInteractionsGraph(rhsTheme, rhsStrings, rhsDateTimeFormat, rhsGraph, rhsType) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsDateTimeFormat == rhsDateTimeFormat, lhsGraph == rhsGraph, lhsType == rhsType {
                    return true
                } else {
                    return false
                }
            case let .storyReactionsByEmotionTitle(lhsTheme, lhsText):
                if case let .storyReactionsByEmotionTitle(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .storyReactionsByEmotionGraph(lhsTheme, lhsStrings, lhsDateTimeFormat, lhsGraph, lhsType):
                if case let .storyReactionsByEmotionGraph(rhsTheme, rhsStrings, rhsDateTimeFormat, rhsGraph, rhsType) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsDateTimeFormat == rhsDateTimeFormat, lhsGraph == rhsGraph, lhsType == rhsType {
                    return true
                } else {
                    return false
                }
            case let .post(lhsIndex, lhsTheme, lhsStrings, lhsDateTimeFormat, lhsPeer, lhsPost, lhsInteractions):
                if case let .post(rhsIndex, rhsTheme, rhsStrings, rhsDateTimeFormat, rhsPeer, rhsPost, rhsInteractions) = rhs, lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsDateTimeFormat == rhsDateTimeFormat, arePeersEqual(lhsPeer, rhsPeer), lhsPost == rhsPost, lhsInteractions == rhsInteractions {
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
            case let .boostOverview(lhsTheme, lhsStats, lhsIsGroup):
                if case let .boostOverview(rhsTheme, rhsStats, rhsIsGroup) = rhs, lhsTheme === rhsTheme, lhsStats == rhsStats, lhsIsGroup == rhsIsGroup {
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
            case let .boostGifts(lhsTheme, lhsText):
                if case let .boostGifts(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .boostGiftsInfo(lhsTheme, lhsText):
                if case let .boostGiftsInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .adsHeader(lhsTheme, lhsText):
                if case let .adsHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .adsImpressionsTitle(lhsTheme, lhsText):
                if case let .adsImpressionsTitle(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .adsImpressionsGraph(lhsTheme, lhsStrings, lhsDateTimeFormat, lhsGraph, lhsType):
                if case let .adsImpressionsGraph(rhsTheme, rhsStrings, rhsDateTimeFormat, rhsGraph, rhsType) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsDateTimeFormat == rhsDateTimeFormat, lhsGraph == rhsGraph, lhsType == rhsType {
                    return true
                } else {
                    return false
                }
            case let .adsTonRevenueTitle(lhsTheme, lhsText):
                if case let .adsTonRevenueTitle(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .adsTonRevenueGraph(lhsTheme, lhsStrings, lhsDateTimeFormat, lhsGraph, lhsType, lhsRate):
                if case let .adsTonRevenueGraph(rhsTheme, rhsStrings, rhsDateTimeFormat, rhsGraph, rhsType, rhsRate) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsDateTimeFormat == rhsDateTimeFormat, lhsGraph == rhsGraph, lhsType == rhsType,  lhsRate == rhsRate {
                    return true
                } else {
                    return false
                }
            case let .adsStarsRevenueTitle(lhsTheme, lhsText):
                if case let .adsStarsRevenueTitle(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .adsStarsRevenueGraph(lhsTheme, lhsStrings, lhsDateTimeFormat, lhsGraph, lhsType, lhsRate):
                if case let .adsStarsRevenueGraph(rhsTheme, rhsStrings, rhsDateTimeFormat, rhsGraph, rhsType, rhsRate) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsDateTimeFormat == rhsDateTimeFormat, lhsGraph == rhsGraph, lhsType == rhsType,  lhsRate == rhsRate {
                    return true
                } else {
                    return false
                }
            case let .adsProceedsTitle(lhsTheme, lhsText):
                if case let .adsProceedsTitle(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .adsProceedsOverview(lhsTheme, lhsStatus, lhsStarsStatus):
                if case let .adsProceedsOverview(rhsTheme, rhsStatus, rhsStarsStatus) = rhs, lhsTheme === rhsTheme, lhsStatus == rhsStatus, lhsStarsStatus == rhsStarsStatus {
                    return true
                } else {
                    return false
                }
            case let .adsProceedsInfo(lhsTheme, lhsText):
                if case let .adsProceedsInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .adsTonBalanceTitle(lhsTheme, lhsText):
                if case let .adsTonBalanceTitle(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .adsTonBalance(lhsTheme, lhsStats, lhsCanWithdraw, lhsIsEnabled):
                if case let .adsTonBalance(rhsTheme, rhsStats, rhsCanWithdraw, rhsIsEnabled) = rhs, lhsTheme === rhsTheme, lhsStats == rhsStats, lhsCanWithdraw == rhsCanWithdraw, lhsIsEnabled == rhsIsEnabled {
                    return true
                } else {
                    return false
                }
            case let .adsTonBalanceInfo(lhsTheme, lhsText):
                if case let .adsTonBalanceInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .adsStarsBalanceTitle(lhsTheme, lhsText):
                if case let .adsStarsBalanceTitle(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .adsStarsBalance(lhsTheme, lhsStats, lhsCanWithdraw, lhsCanBuyAds, lhsIsEnabled, lhsCooldownUntilTimestamp):
            if case let .adsStarsBalance(rhsTheme, rhsStats, rhsCanWithdraw, rhsCanBuyAds, rhsIsEnabled, rhsCooldownUntilTimestamp) = rhs, lhsTheme === rhsTheme, lhsStats == rhsStats, lhsCanWithdraw == rhsCanWithdraw, lhsCanBuyAds == rhsCanBuyAds, lhsIsEnabled == rhsIsEnabled, lhsCooldownUntilTimestamp == rhsCooldownUntilTimestamp {
                    return true
                } else {
                    return false
                }
            case let .adsStarsBalanceInfo(lhsTheme, lhsText):
                if case let .adsStarsBalanceInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
        case .earnStarsInfo:
                if case .earnStarsInfo = rhs {
                    return true
                } else {
                    return false
                }
            case let .adsTransactionsTitle(lhsTheme, lhsText):
                if case let .adsTransactionsTitle(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .adsTransactionsTabs(lhsTheme, lhsTonText, lhsStarsText, lhsStarsSelected):
                if case let .adsTransactionsTabs(rhsTheme, rhsTonText, rhsStarsText, rhsStarsSelected) = rhs, lhsTheme === rhsTheme, lhsTonText == rhsTonText, lhsStarsText == rhsStarsText, lhsStarsSelected == rhsStarsSelected {
                    return true
                } else {
                    return false
                }
            case let .adsTransaction(lhsIndex, lhsTheme, lhsTransaction):
                if case let .adsTransaction(rhsIndex, rhsTheme, rhsTransaction) = rhs, lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsTransaction == rhsTransaction {
                    return true
                } else {
                    return false
                }
            case let .adsStarsTransaction(lhsIndex, lhsTheme, lhsTransaction):
                if case let .adsStarsTransaction(rhsIndex, rhsTheme, rhsTransaction) = rhs, lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsTransaction == rhsTransaction {
                    return true
                } else {
                    return false
                }
            case let .adsTransactionsExpand(lhsTheme, lhsText, lhsStars):
                if case let .adsTransactionsExpand(rhsTheme, rhsText, rhsStars) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsStars == rhsStars {
                    return true
                } else {
                    return false
                }
            case let .adsCpmToggle(lhsTheme, lhsText, lhsMinLevel, lhsValue):
                if case let .adsCpmToggle(rhsTheme, rhsText, rhsMinLevel, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsMinLevel == rhsMinLevel, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .adsCpmInfo(lhsTheme, lhsText):
                if case let .adsCpmInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
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
                 let .instantPageInteractionsTitle(_, text),
                 let .reactionsByEmotionTitle(_, text),
                 let .storyInteractionsTitle(_, text),
                 let .storyReactionsByEmotionTitle(_, text),
                 let .postsTitle(_, text),
                 let .boostOverviewTitle(_, text),
                 let .boostPrepaidTitle(_, text),
                 let .boostersTitle(_, text),
                 let .boostLinkTitle(_, text),
                 let .adsImpressionsTitle(_, text),
                 let .adsTonRevenueTitle(_, text),
                 let .adsStarsRevenueTitle(_, text),
                 let .adsProceedsTitle(_, text),
                 let .adsTonBalanceTitle(_, text),
                 let .adsStarsBalanceTitle(_, text),
                 let .adsTransactionsTitle(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .boostPrepaidInfo(_, text),
                 let .boostersInfo(_, text),
                 let .boostLinkInfo(_, text),
                 let .boostGiftsInfo(_, text),
                 let .adsCpmInfo(_, text),
                 let .adsProceedsInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .markdown(text), sectionId: self.section)
            case let .overview(_, stats):
                return StatsOverviewItem(context: arguments.context, presentationData: presentationData, isGroup: false, stats: stats, sectionId: self.section, style: .blocks)
            case let .growthGraph(_, _, _, graph, type),
                 let .followersGraph(_, _, _, graph, type),
                 let .notificationsGraph(_, _, _, graph, type),
                 let .viewsByHourGraph(_, _, _, graph, type),
                 let .viewsBySourceGraph(_, _, _, graph, type),
                 let .followersBySourceGraph(_, _, _, graph, type),
                 let .languagesGraph(_, _, _, graph, type),
                 let .reactionsByEmotionGraph(_, _, _, graph, type),
                 let .storyReactionsByEmotionGraph(_, _, _, graph, type),
                 let .adsImpressionsGraph(_, _, _, graph, type):
                return StatsGraphItem(presentationData: presentationData, graph: graph, type: type, sectionId: self.section, style: .blocks)
            case let .adsTonRevenueGraph(_, _, _, graph, type, rate):
                return StatsGraphItem(presentationData: presentationData, graph: graph, type: type, conversionRate: rate, sectionId: self.section, style: .blocks)
            case let .adsStarsRevenueGraph(_, _, _, graph, type, rate):
                return StatsGraphItem(presentationData: presentationData, graph: graph, type: type, conversionRate: rate, sectionId: self.section, style: .blocks)
            case let .postInteractionsGraph(_, _, _, graph, type),
                 let .instantPageInteractionsGraph(_, _, _, graph, type),
                 let .storyInteractionsGraph(_, _, _, graph, type):
                return StatsGraphItem(presentationData: presentationData, graph: graph, type: type, getDetailsData: { date, completion in
                    let _ = arguments.loadDetailedGraph(graph, Int64(date.timeIntervalSince1970) * 1000).start(next: { graph in
                        if let graph = graph, case let .Loaded(_, data) = graph {
                            completion(data)
                        }
                    })
                }, sectionId: self.section, style: .blocks)
            case let .post(_, _, _, _, peer, post, interactions):
                return StatsMessageItem(context: arguments.context, presentationData: presentationData, peer: peer, item: post, views: interactions.views, reactions: interactions.reactions, forwards: interactions.forwards, sectionId: self.section, style: .blocks, action: {
                    arguments.openPostStats(EnginePeer(peer), post)
                }, openStory: { sourceView in
                    if case let .story(_, story) = post {
                        arguments.openStory(story, sourceView)
                    }
                }, contextAction: !post.isStory ? { node, gesture in
                    if case let .message(message) = post {
                        arguments.contextAction(message.id, node, gesture)
                    }
                } : nil)
            case let .boosterTabs(_, boostText, giftText, giftSelected):
                return BoostsTabsItem(theme: presentationData.theme, boostsText: boostText, giftsText: giftText, selectedTab: giftSelected ? .gifts : .boosts, sectionId: self.section, selectionUpdated: { tab in
                    arguments.updateGiftsSelected(tab == .gifts)
                })
            case let .booster(_, _, _, boost):
                let count = boost.multiplier
                let expiresValue = stringForDate(timestamp: boost.expires, strings: presentationData.strings)
                var expiresString: String
                
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
                    expiresString = "\(durationString) • \(expiresValue)"
                    if boost.flags.contains(.isUnclaimed) {
                        title = presentationData.strings.Stats_Boosts_Unclaimed
                        icon = .image(color: color, name: "Premium/Unclaimed")
                    } else if boost.flags.contains(.isGiveaway) {
                        if let stars = boost.stars {
                            title = presentationData.strings.Stats_Boosts_Stars(Int32(stars))
                            icon = .image(color: .stars, name: "Premium/PremiumStar")
                            expiresString = expiresValue
                        } else {
                            title = presentationData.strings.Stats_Boosts_ToBeDistributed
                            icon = .image(color: color, name: "Premium/ToBeDistributed")
                        }
                    } else {
                        title = "Unknown"
                        icon = .image(color: color, name: "Premium/ToBeDistributed")
                    }
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
            case let .boostOverview(_, stats, isGroup):
                return StatsOverviewItem(context: arguments.context, presentationData: presentationData, isGroup: isGroup, stats: stats, sectionId: self.section, style: .blocks)
            case let .boostLink(_, link):
                let invite: ExportedInvitation = .link(link: link, title: nil, isPermanent: false, requestApproval: false, isRevoked: false, adminId: PeerId(0), date: 0, startDate: nil, expireDate: nil, usageLimit: nil, count: nil, requestedCount: nil, pricing: nil)
                return ItemListPermanentInviteLinkItem(context: arguments.context, presentationData: presentationData, invite: invite, count: 0, peers: [], displayButton: true, displayImporters: false, buttonColor: nil, sectionId: self.section, style: .blocks, copyAction: {
                    arguments.copyBoostLink(link)
                }, shareAction: {
                    arguments.shareBoostLink(link)
                }, contextAction: nil, viewAction: nil, openCallAction: nil, tag: nil)
            case let .boostersPlaceholder(_, text):
                return ItemListPlaceholderItem(theme: presentationData.theme, text: text, sectionId: self.section, style: .blocks)
            case let .boostGifts(theme, title):
                return ItemListPeerActionItem(presentationData: presentationData, icon: PresentationResourcesItemList.addBoostsIcon(theme), title: title, sectionId: self.section, editing: false, action: {
                    arguments.openGifts()
                })
            case let .boostPrepaid(_, _, title, subtitle, prepaidGiveaway):
                let color: GiftOptionItem.Icon.Color
                let icon: String
                var boosts: Int32
                switch prepaidGiveaway.prize {
                case let .premium(months):
                    switch months {
                    case 3:
                        color = .green
                    case 6:
                        color = .blue
                    case 12:
                        color = .red
                    default:
                        color = .blue
                    }
                    icon = "Premium/Giveaway"
                    boosts = prepaidGiveaway.quantity * 4
                case let .stars(_, boostCount):
                    color = .stars
                    icon = "Premium/PremiumStar"
                    boosts = boostCount
                }
                return GiftOptionItem(presentationData: presentationData, context: arguments.context, icon: .image(color: color, name: icon), title: title, titleFont: .bold, titleBadge: "\(boosts)", subtitle: subtitle, label: nil, sectionId: self.section, action: {
                    arguments.createPrepaidGiveaway(prepaidGiveaway)
                })
            case let .adsHeader(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .markdown(text), sectionId: self.section, linkAction: { _ in
                    arguments.openMonetizationIntro()
                })
            case let .adsProceedsOverview(_, stats, starsStats):
                return StatsOverviewItem(context: arguments.context, presentationData: presentationData, isGroup: false, stats: stats ?? starsStats, additionalStats: stats != nil ? starsStats : nil, sectionId: self.section, style: .blocks)
            case let .adsTonBalance(_, stats, canWithdraw, isEnabled):
                return MonetizationBalanceItem(
                    context: arguments.context,
                    presentationData: presentationData,
                    stats: stats,
                    canWithdraw: canWithdraw,
                    isEnabled: isEnabled,
                    actionCooldownUntilTimestamp: nil,
                    withdrawAction: {
                        arguments.requestTonWithdraw()
                    },
                    buyAdsAction: nil,
                    sectionId: self.section,
                    style: .blocks
                )
            case let .adsTonBalanceInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .markdown(text), sectionId: self.section, linkAction: { _ in
                    arguments.openMonetizationInfo()
                })
            case let .adsStarsBalance(_, stats, canWithdraw, canBuyAds, isEnabled, cooldownUntilTimestamp):
                return MonetizationBalanceItem(
                    context: arguments.context,
                    presentationData: presentationData,
                    stats: stats,
                    canWithdraw: canWithdraw,
                    isEnabled: isEnabled,
                    actionCooldownUntilTimestamp: cooldownUntilTimestamp,
                    withdrawAction: {
                        var remainingCooldownSeconds: Int32 = 0
                        if let cooldownUntilTimestamp {
                            remainingCooldownSeconds = cooldownUntilTimestamp - Int32(Date().timeIntervalSince1970)
                            remainingCooldownSeconds = max(0, remainingCooldownSeconds)
                            
                            if remainingCooldownSeconds > 0 {
                                arguments.showTimeoutTooltip(cooldownUntilTimestamp)
                            } else {
                                arguments.requestStarsWithdraw()
                            }
                        } else {
                            arguments.requestStarsWithdraw()
                        }
                    },
                    buyAdsAction: canWithdraw && canBuyAds ? {
                        arguments.buyAds()
                    } : nil,
                    sectionId: self.section,
                    style: .blocks
                )
            case let .adsStarsBalanceInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .markdown(text), sectionId: self.section, linkAction: { _ in
                    arguments.openMonetizationInfo()
                })
            case let .adsTransactionsTabs(_, tonText, starsText, starsSelected):
                return BoostsTabsItem(theme: presentationData.theme, boostsText: tonText, giftsText: starsText, selectedTab: starsSelected ? .gifts : .boosts, sectionId: self.section, selectionUpdated: { tab in
                    arguments.updateStarsSelected(tab == .gifts)
                })
            case let .adsTransaction(_, theme, transaction):
                let font = Font.with(size: floor(presentationData.fontSize.itemListBaseFontSize))
                let smallLabelFont = Font.with(size: floor(presentationData.fontSize.itemListBaseFontSize / 17.0 * 13.0))
            
                var labelColor = theme.list.itemDisclosureActions.constructive.fillColor
           
                let title: NSAttributedString
                let detailText: String
                var detailColor: ItemListDisclosureItemDetailLabelColor = .generic
            
                if let fromDate = transaction.adsProceedsFromDate, let toDate = transaction.adsProceedsToDate {
                    title = NSAttributedString(string: presentationData.strings.Monetization_Transaction_Proceeds, font: font, textColor: theme.list.itemPrimaryTextColor)
                    let fromDateString = stringForMediumCompactDate(timestamp: fromDate, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat, withTime: false)
                    let toDateString = stringForMediumCompactDate(timestamp: toDate, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat, withTime: false)
                    if fromDateString == toDateString {
                        detailText = stringForMediumCompactDate(timestamp: toDate, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat, withTime: true)
                    } else {
                        detailText = "\(fromDateString) – \(toDateString)"
                    }
                } else if case .fragment = transaction.peer {
                    if transaction.flags.contains(.isRefund) {
                        title = NSAttributedString(string: presentationData.strings.Monetization_Transaction_Refund, font: font, textColor: theme.list.itemPrimaryTextColor)
                        detailText = stringForMediumCompactDate(timestamp: transaction.date, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat)
                    } else {
                        title = NSAttributedString(string: presentationData.strings.Monetization_Transaction_Withdrawal("Fragment").string, font: font, textColor: theme.list.itemPrimaryTextColor)
                        labelColor = theme.list.itemDestructiveColor
                        if transaction.flags.contains(.isPending) {
                            detailText = presentationData.strings.Monetization_Transaction_Pending
                        } else if transaction.flags.contains(.isFailed) {
                            detailText = stringForMediumCompactDate(timestamp: transaction.date, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat, withTime: false) + " – \(presentationData.strings.Monetization_Transaction_Failed)"
                            detailColor = .destructive
                        } else {
                            detailText = stringForMediumCompactDate(timestamp: transaction.date, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat)
                        }
                    }
                } else if transaction.flags.contains(.isRefund) {
                    title = NSAttributedString(string: presentationData.strings.Monetization_Transaction_Refund, font: font, textColor: theme.list.itemPrimaryTextColor)
                    detailText = stringForMediumCompactDate(timestamp: transaction.date, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat)
                } else if case .peer = transaction.peer {
                    return StarsTransactionItem(context: arguments.context, presentationData: presentationData, transaction: transaction, action: {
                        arguments.openStarsTransaction(transaction)
                    }, sectionId: self.section, style: .blocks)
                } else {
                    title = NSAttributedString()
                    detailText = ""
                }
            
                let label = tonAmountAttributedString(formatTonAmountText(transaction.count.amount.value, dateTimeFormat: presentationData.dateTimeFormat, showPlus: true), integralFont: font, fractionalFont: smallLabelFont, color: labelColor, decimalSeparator: presentationData.dateTimeFormat.decimalSeparator).mutableCopy() as! NSMutableAttributedString
            
                label.insert(NSAttributedString(string: " $ ", font: font, textColor: labelColor), at: 1)
                if let range = label.string.range(of: "$"), let icon = generateTintedImage(image: UIImage(bundleImageName: "Ads/TonMedium"), color: labelColor) {
                    label.addAttribute(.attachment, value: icon, range: NSRange(range, in: label.string))
                    label.addAttribute(.baselineOffset, value: 1.0, range: NSRange(range, in: label.string))
                }
                
                return ItemListDisclosureItem(presentationData: presentationData, title: "", attributedTitle: title, label: "", attributedLabel: label, labelStyle: .coloredText(labelColor), additionalDetailLabel: detailText, additionalDetailLabelColor: detailColor, sectionId: self.section, style: .blocks, disclosureStyle: .none, action: {
                    arguments.openTonTransaction(transaction)
                })
            case let .adsStarsTransaction(_, _, transaction):
                return StarsTransactionItem(context: arguments.context, presentationData: presentationData, transaction: transaction, action: {
                    arguments.openStarsTransaction(transaction)
                }, sectionId: self.section, style: .blocks)
            case let .adsTransactionsExpand(theme, title, stars):
                return ItemListPeerActionItem(presentationData: presentationData, icon: PresentationResourcesItemList.downArrowImage(theme), title: title, sectionId: self.section, editing: false, action: {
                    arguments.expandTransactions(stars)
                })
            case let .adsCpmToggle(_, title, minLevel, value):
                var badgeComponent: AnyComponent<Empty>?
                if value == nil {
                    badgeComponent = AnyComponent(BoostLevelIconComponent(
                        strings: presentationData.strings,
                        level: Int(minLevel)
                    ))
                }
                return ItemListSwitchItem(presentationData: presentationData, title: title, titleBadgeComponent: badgeComponent, value: value == true, enableInteractiveChanges: value != nil, enabled: true, displayLocked: value == nil, sectionId: self.section, style: .blocks, updated: { updatedValue in
                    if value != nil {
                        arguments.updateCpmEnabled(updatedValue)
                    } else {
                        arguments.presentCpmLocked()
                    }
                }, activatedWhileDisabled: {
                    arguments.presentCpmLocked()
                })
            case .earnStarsInfo:
                return ItemListDisclosureItem(presentationData: presentationData, icon: PresentationResourcesSettings.earnStars, title: presentationData.strings.Monetization_EarnStarsInfo_Title, titleBadge: presentationData.strings.Settings_New, label: presentationData.strings.Monetization_EarnStarsInfo_Text, labelStyle: .multilineDetailText, sectionId: self.section, style: .blocks, action: {
                    arguments.openEarnStars()
                })
        }
    }
}

public enum ChannelStatsSection {
    case stats
    case boosts
    case monetization
}

private struct ChannelStatsControllerState: Equatable {
    let section: ChannelStatsSection
    let boostersExpanded: Bool
    let moreBoostersDisplayed: Int32
    let giftsSelected: Bool
    let starsSelected: Bool
    let transactionsExpanded: Bool
    let moreTransactionsDisplayed: Int32
    
    init() {
        self.section = .stats
        self.boostersExpanded = false
        self.moreBoostersDisplayed = 0
        self.giftsSelected = false
        self.starsSelected = false
        self.transactionsExpanded = false
        self.moreTransactionsDisplayed = 0
    }
    
    init(section: ChannelStatsSection, boostersExpanded: Bool, moreBoostersDisplayed: Int32, giftsSelected: Bool, starsSelected: Bool, transactionsExpanded: Bool, moreTransactionsDisplayed: Int32) {
        self.section = section
        self.boostersExpanded = boostersExpanded
        self.moreBoostersDisplayed = moreBoostersDisplayed
        self.giftsSelected = giftsSelected
        self.starsSelected = starsSelected
        self.transactionsExpanded = transactionsExpanded
        self.moreTransactionsDisplayed = moreTransactionsDisplayed
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
        if lhs.starsSelected != rhs.starsSelected {
            return false
        }
        if lhs.transactionsExpanded != rhs.transactionsExpanded {
            return false
        }
        if lhs.moreTransactionsDisplayed != rhs.moreTransactionsDisplayed {
            return false
        }
        return true
    }
    
    func withUpdatedSection(_ section: ChannelStatsSection) -> ChannelStatsControllerState {
        return ChannelStatsControllerState(section: section, boostersExpanded: self.boostersExpanded, moreBoostersDisplayed: self.moreBoostersDisplayed, giftsSelected: self.giftsSelected, starsSelected: self.starsSelected, transactionsExpanded: self.transactionsExpanded, moreTransactionsDisplayed: self.moreTransactionsDisplayed)
    }
    
    func withUpdatedBoostersExpanded(_ boostersExpanded: Bool) -> ChannelStatsControllerState {
        return ChannelStatsControllerState(section: self.section, boostersExpanded: boostersExpanded, moreBoostersDisplayed: self.moreBoostersDisplayed, giftsSelected: self.giftsSelected, starsSelected: self.starsSelected, transactionsExpanded: self.transactionsExpanded, moreTransactionsDisplayed: self.moreTransactionsDisplayed)
    }
    
    func withUpdatedMoreBoostersDisplayed(_ moreBoostersDisplayed: Int32) -> ChannelStatsControllerState {
        return ChannelStatsControllerState(section: self.section, boostersExpanded: self.boostersExpanded, moreBoostersDisplayed: moreBoostersDisplayed, giftsSelected: self.giftsSelected, starsSelected: self.starsSelected, transactionsExpanded: self.transactionsExpanded, moreTransactionsDisplayed: self.moreTransactionsDisplayed)
    }
    
    func withUpdatedGiftsSelected(_ giftsSelected: Bool) -> ChannelStatsControllerState {
        return ChannelStatsControllerState(section: self.section, boostersExpanded: self.boostersExpanded, moreBoostersDisplayed: self.moreBoostersDisplayed, giftsSelected: giftsSelected, starsSelected: self.starsSelected, transactionsExpanded: self.transactionsExpanded, moreTransactionsDisplayed: self.moreTransactionsDisplayed)
    }
    
    func withUpdatedStarsSelected(_ starsSelected: Bool) -> ChannelStatsControllerState {
        return ChannelStatsControllerState(section: self.section, boostersExpanded: self.boostersExpanded, moreBoostersDisplayed: self.moreBoostersDisplayed, giftsSelected: self.giftsSelected, starsSelected: starsSelected, transactionsExpanded: self.transactionsExpanded, moreTransactionsDisplayed: self.moreTransactionsDisplayed)
    }
    
    func withUpdatedTransactionsExpanded(_ transactionsExpanded: Bool) -> ChannelStatsControllerState {
        return ChannelStatsControllerState(section: self.section, boostersExpanded: self.boostersExpanded, moreBoostersDisplayed: self.moreBoostersDisplayed, giftsSelected: self.giftsSelected, starsSelected: self.starsSelected, transactionsExpanded: transactionsExpanded, moreTransactionsDisplayed: self.moreTransactionsDisplayed)
    }
    
    func withUpdatedMoreTransactionsDisplayed(_ moreTransactionsDisplayed: Int32) -> ChannelStatsControllerState {
        return ChannelStatsControllerState(section: self.section, boostersExpanded: self.boostersExpanded, moreBoostersDisplayed: self.moreBoostersDisplayed, giftsSelected: self.giftsSelected, starsSelected: self.starsSelected, transactionsExpanded: self.transactionsExpanded, moreTransactionsDisplayed: moreTransactionsDisplayed)
    }
}

private func statsEntries(
    presentationData: PresentationData,
    data: ChannelStats,
    peer: EnginePeer?,
    messages: [Message]?,
    stories: StoryListContext.State?,
    interactions: [ChannelStatsPostInteractions.PostId: ChannelStatsPostInteractions]?
) -> [StatsEntry] {
    var entries: [StatsEntry] = []
    
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
    
    if !data.reactionsByEmotionGraph.isEmpty {
        entries.append(.reactionsByEmotionTitle(presentationData.theme, presentationData.strings.Stats_ReactionsByEmotionTitle))
        entries.append(.reactionsByEmotionGraph(presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, data.reactionsByEmotionGraph, .bars))
    }
    
    if !data.storyInteractionsGraph.isEmpty {
        entries.append(.storyInteractionsTitle(presentationData.theme, presentationData.strings.Stats_StoryInteractionsTitle))
        entries.append(.storyInteractionsGraph(presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, data.storyInteractionsGraph, .twoAxisStep))
    }
    
    if !data.storyReactionsByEmotionGraph.isEmpty {
        entries.append(.storyReactionsByEmotionTitle(presentationData.theme, presentationData.strings.Stats_StoryReactionsByEmotionTitle))
        entries.append(.storyReactionsByEmotionGraph(presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, data.storyReactionsByEmotionGraph, .bars))
    }
    
    if let peer, let interactions {
        var posts: [StatsPostItem] = []
        if let messages {
            for message in messages {
                if let _ = interactions[.message(id: message.id)] {
                    posts.append(.message(message))
                }
            }
        }
        if let stories {
            for story in stories.items {
                if let _ = interactions[.story(peerId: peer.id, id: story.storyItem.id)] {
                    posts.append(.story(peer, story.storyItem))
                }
            }
        }
        posts.sort(by: { $0.timestamp > $1.timestamp })
        
        if !posts.isEmpty {
            entries.append(.postsTitle(presentationData.theme, presentationData.strings.Stats_PostsTitle))
            var index: Int32 = 0
            for post in posts {
                switch post {
                case let .message(message):
                    if let interactions = interactions[.message(id: message.id)] {
                        entries.append(.post(index, presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, peer._asPeer(), post, interactions))
                    }
                case let .story(_, story):
                    if let interactions = interactions[.story(peerId: peer.id, id: story.id)] {
                        entries.append(.post(index, presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, peer._asPeer(), post, interactions))
                    }
                }
                index += 1
            }
        }
    }
    return entries
}

private func boostsEntries(
    presentationData: PresentationData,
    state: ChannelStatsControllerState,
    isGroup: Bool,
    boostData: ChannelBoostStatus,
    boostsOnly: Bool,
    boostersState: ChannelBoostersContext.State?,
    giftsState: ChannelBoostersContext.State?,
    giveawayAvailable: Bool
) -> [StatsEntry] {
    var entries: [StatsEntry] = []
    
    if !boostsOnly {
        let progress: CGFloat
        if let nextLevelBoosts = boostData.nextLevelBoosts {
            progress = CGFloat(boostData.boosts - boostData.currentLevelBoosts) / CGFloat(nextLevelBoosts - boostData.currentLevelBoosts)
        } else {
            progress = 1.0
        }
        entries.append(.boostLevel(presentationData.theme, Int32(boostData.boosts), Int32(boostData.level), progress))
    }
    
    entries.append(.boostOverviewTitle(presentationData.theme, presentationData.strings.Stats_Boosts_OverviewHeader))
    entries.append(.boostOverview(presentationData.theme, boostData, isGroup))
    
    if !boostData.prepaidGiveaways.isEmpty {
        entries.append(.boostPrepaidTitle(presentationData.theme, presentationData.strings.Stats_Boosts_PrepaidGiveawaysTitle))
        var i: Int32 = 0
        for giveaway in boostData.prepaidGiveaways {
            let title: String
            let text: String
            switch giveaway.prize {
            case let .premium(months):
                title = presentationData.strings.Stats_Boosts_PrepaidGiveawayCount(giveaway.quantity)
                text = presentationData.strings.Stats_Boosts_PrepaidGiveawayMonths("\(months)").string
            case let .stars(stars, _):
                title = presentationData.strings.Stats_Boosts_Stars(Int32(stars))
                text = presentationData.strings.Stats_Boosts_StarsWinners(giveaway.quantity)
            }
            entries.append(.boostPrepaid(i, presentationData.theme, title, text, giveaway))
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
        boostersFooter = isGroup ? presentationData.strings.Stats_Boosts_Group_BoostersInfo : presentationData.strings.Stats_Boosts_BoostersInfo
    } else {
        boostersTitle = presentationData.strings.Stats_Boosts_BoostsNone
        boostersPlaceholder = isGroup ? presentationData.strings.Stats_Boosts_Group_NoBoostersYet : presentationData.strings.Stats_Boosts_NoBoostersYet
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
    entries.append(.boostLinkInfo(presentationData.theme, isGroup ? presentationData.strings.Stats_Boosts_Group_LinkInfo : presentationData.strings.Stats_Boosts_LinkInfo))
    
    if giveawayAvailable {
        entries.append(.boostGifts(presentationData.theme, presentationData.strings.Stats_Boosts_GetBoosts))
        entries.append(.boostGiftsInfo(presentationData.theme, isGroup ? presentationData.strings.Stats_Boosts_Group_GetBoostsInfo : presentationData.strings.Stats_Boosts_GetBoostsInfo))
    }
    return entries
}

private func monetizationEntries(
    presentationData: PresentationData,
    state: ChannelStatsControllerState,
    peer: EnginePeer?,
    data: StarsRevenueStats?,
    boostData: ChannelBoostStatus?,
    transactionsInfo: StarsTransactionsContext.State,
    starsData: StarsRevenueStats?,
    starsTransactionsInfo: StarsTransactionsContext.State,
    adsRestricted: Bool,
    premiumConfiguration: PremiumConfiguration,
    monetizationConfiguration: MonetizationConfiguration,
    canViewRevenue: Bool,
    canViewStarsRevenue: Bool,
    canJoinRefPrograms: Bool
) -> [StatsEntry] {
    var entries: [StatsEntry] = []
    
    var isBot = false
    if case let .user(user) = peer, let _ = user.botInfo {
        isBot = true
    }
    
    if canViewRevenue, let data {
        entries.append(.adsHeader(presentationData.theme, isBot ? presentationData.strings.Monetization_Bot_Header : presentationData.strings.Monetization_Header))
        
        if let topHoursGraph = data.topHoursGraph, !topHoursGraph.isEmpty {
            entries.append(.adsImpressionsTitle(presentationData.theme, presentationData.strings.Monetization_ImpressionsTitle))
            entries.append(.adsImpressionsGraph(presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, topHoursGraph, .hourlyStep))
        }
        
        if !data.revenueGraph.isEmpty {
            entries.append(.adsTonRevenueTitle(presentationData.theme, presentationData.strings.Monetization_AdRevenueTitle))
            entries.append(.adsTonRevenueGraph(presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, data.revenueGraph, .currency, data.usdRate))
        }
    }
    
    if canViewStarsRevenue {
        if let starsData, !starsData.revenueGraph.isEmpty {
            entries.append(.adsStarsRevenueTitle(presentationData.theme, presentationData.strings.Monetization_StarsRevenueTitle))
            entries.append(.adsStarsRevenueGraph(presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, starsData.revenueGraph, .stars, starsData.usdRate))
        }
    }
        
    entries.append(.adsProceedsTitle(presentationData.theme, presentationData.strings.Monetization_StarsProceeds_Title))
    entries.append(.adsProceedsOverview(presentationData.theme, canViewRevenue ? data : nil, canViewStarsRevenue ? starsData : nil))
    
    let hasTonBalance = (data?.balances.overallRevenue.amount ?? StarsAmount.zero) > StarsAmount.zero
    let hasStarsBalance = (starsData?.balances.overallRevenue.amount ?? StarsAmount.zero) > StarsAmount.zero
    
    let proceedsInfo: String
    if (canViewStarsRevenue && hasStarsBalance) && (canViewRevenue && hasTonBalance) {
        proceedsInfo = presentationData.strings.Monetization_Proceeds_TonAndStars_Info
    } else if canViewStarsRevenue && hasStarsBalance {
        proceedsInfo = presentationData.strings.Monetization_Proceeds_Stars_Info
    } else {
        proceedsInfo = presentationData.strings.Monetization_Proceeds_Ton_Info
    }
    entries.append(.adsProceedsInfo(presentationData.theme, proceedsInfo))
    
    var isCreator = false
    var isGroup = false
    if let peer, case let .channel(channel) = peer, channel.flags.contains(.isCreator) {
        isCreator = true
        if case .group = channel.info {
            isGroup = true
        }
    }
    
    if canViewRevenue, let data {
        entries.append(.adsTonBalanceTitle(presentationData.theme, isBot ? presentationData.strings.Monetization_Bot_BalanceTitle : presentationData.strings.Monetization_TonBalanceTitle))
        entries.append(.adsTonBalance(presentationData.theme, data, (isCreator || isBot) && data.balances.availableBalance.amount > StarsAmount.zero, data.balances.withdrawEnabled))
    
        if isCreator || isBot {
            let withdrawalInfoText: String
            if data.balances.availableBalance.amount == StarsAmount.zero {
                withdrawalInfoText = presentationData.strings.Monetization_Balance_ZeroInfo
            } else if monetizationConfiguration.withdrawalAvailable {
                withdrawalInfoText = presentationData.strings.Monetization_Balance_AvailableInfo
            } else {
                withdrawalInfoText = presentationData.strings.Monetization_Balance_ComingLaterInfo
            }
            entries.append(.adsTonBalanceInfo(presentationData.theme, withdrawalInfoText))
        }
    }
    
    if canViewStarsRevenue, let starsData, starsData.balances.overallRevenue.amount > StarsAmount.zero {
        entries.append(.adsStarsBalanceTitle(presentationData.theme, presentationData.strings.Monetization_StarsBalanceTitle))
        entries.append(.adsStarsBalance(presentationData.theme, starsData, isCreator && starsData.balances.availableBalance.amount > StarsAmount.zero, !isGroup, starsData.balances.withdrawEnabled, starsData.balances.nextWithdrawalTimestamp))
        entries.append(.adsStarsBalanceInfo(presentationData.theme, isGroup ? presentationData.strings.Monetization_Balance_StarsInfoGroup : presentationData.strings.Monetization_Balance_StarsInfo))
    }
    
    if canJoinRefPrograms && !isGroup {
        entries.append(.earnStarsInfo)
    }
    
    var addedTransactionsTabs = false
    if !transactionsInfo.transactions.isEmpty && !starsTransactionsInfo.transactions.isEmpty && canViewRevenue && canViewStarsRevenue {
        addedTransactionsTabs = true
        entries.append(.adsTransactionsTabs(presentationData.theme, presentationData.strings.Monetization_TonTransactions, presentationData.strings.Monetization_StarsTransactions, state.starsSelected))
    }
    
    var displayTonTransactions = false
    if canViewRevenue && !transactionsInfo.transactions.isEmpty && (starsTransactionsInfo.transactions.isEmpty || !state.starsSelected) {
        displayTonTransactions = true
    }
    
    var displayStarsTransactions = false
    if canViewStarsRevenue && !starsTransactionsInfo.transactions.isEmpty && (transactionsInfo.transactions.isEmpty || state.starsSelected) {
        displayStarsTransactions = true
    }
        
    if displayTonTransactions {
        if !addedTransactionsTabs {
            entries.append(.adsTransactionsTitle(presentationData.theme, isBot ? presentationData.strings.Monetization_TransactionsTitle.uppercased() : presentationData.strings.Monetization_TonTransactions.uppercased()))
        }
        
        var transactions = transactionsInfo.transactions
        var limit: Int32
        if state.transactionsExpanded {
            limit = 25 + state.moreTransactionsDisplayed
        } else {
            limit = initialTransactionsDisplayedLimit
        }
        transactions = Array(transactions.prefix(Int(limit)))
        
        var i: Int32 = 0
        for transaction in transactions {
            entries.append(.adsTransaction(i, presentationData.theme, transaction))
            i += 1
        }
        
        if transactionsInfo.canLoadMore || transactionsInfo.transactions.count > transactions.count {
            let moreCount: Int32
            if !state.transactionsExpanded {
                moreCount = min(20, Int32(transactionsInfo.transactions.count - transactions.count))
            } else {
                moreCount = min(50, Int32(transactionsInfo.transactions.count - transactions.count))
            }
            entries.append(.adsTransactionsExpand(presentationData.theme, presentationData.strings.Monetization_Transaction_ShowMoreTransactions(moreCount), false))
        }
    }
    
    if displayStarsTransactions {
        if !addedTransactionsTabs {
            entries.append(.adsTransactionsTitle(presentationData.theme, isGroup ? presentationData.strings.Monetization_TransactionsTitle.uppercased() : presentationData.strings.Monetization_StarsTransactions.uppercased()))
        }
        
        var transactions = starsTransactionsInfo.transactions
        var limit: Int32
        if state.transactionsExpanded {
            limit = 25 + state.moreTransactionsDisplayed
        } else {
            limit = initialTransactionsDisplayedLimit
        }
        transactions = Array(transactions.prefix(Int(limit)))
        
        var i: Int32 = 0
        for transaction in transactions {
            entries.append(.adsStarsTransaction(i, presentationData.theme, transaction))
            i += 1
        }
        
        if starsTransactionsInfo.canLoadMore || starsTransactionsInfo.transactions.count > transactions.count {
            let moreCount: Int32
            if !state.transactionsExpanded {
                moreCount = min(20, Int32(starsTransactionsInfo.transactions.count - transactions.count))
            } else {
                moreCount = min(50, Int32(starsTransactionsInfo.transactions.count - transactions.count))
            }
            entries.append(.adsTransactionsExpand(presentationData.theme, presentationData.strings.Monetization_Transaction_ShowMoreTransactions(moreCount), true))
        }
    }
    
    if isCreator && canViewRevenue && !isGroup {
        var switchOffAdds: Bool? = nil
        if let boostData, boostData.level >= premiumConfiguration.minChannelRestrictAdsLevel {
            switchOffAdds = adsRestricted
        }
        
        entries.append(.adsCpmToggle(presentationData.theme, presentationData.strings.Monetization_SwitchOffAds, premiumConfiguration.minChannelRestrictAdsLevel, switchOffAdds))
        entries.append(.adsCpmInfo(presentationData.theme, presentationData.strings.Monetization_SwitchOffAdsInfo))
    }
    
    return entries
}

private func channelStatsControllerEntries(
    presentationData: PresentationData,
    state: ChannelStatsControllerState,
    peer: EnginePeer?,
    data: ChannelStats?,
    messages: [Message]?,
    stories: StoryListContext.State?,
    interactions: [ChannelStatsPostInteractions.PostId: ChannelStatsPostInteractions]?,
    boostData: ChannelBoostStatus?,
    boostersState: ChannelBoostersContext.State?,
    giftsState: ChannelBoostersContext.State?,
    giveawayAvailable: Bool,
    isGroup: Bool,
    boostsOnly: Bool,
    revenueState: StarsRevenueStats?,
    revenueTransactions: StarsTransactionsContext.State,
    starsState: StarsRevenueStats?,
    starsTransactions: StarsTransactionsContext.State,
    adsRestricted: Bool,
    premiumConfiguration: PremiumConfiguration,
    monetizationConfiguration: MonetizationConfiguration,
    canViewRevenue: Bool,
    canViewStarsRevenue: Bool,
    canJoinRefPrograms: Bool
) -> [StatsEntry] {
    switch state.section {
    case .stats:
        if let data {
            return statsEntries(
                presentationData: presentationData,
                data: data,
                peer: peer,
                messages: messages,
                stories: stories,
                interactions: interactions
            )
        }
    case .boosts:
        if let boostData {
            return boostsEntries(
                presentationData: presentationData,
                state: state,
                isGroup: isGroup,
                boostData: boostData,
                boostsOnly: boostsOnly,
                boostersState: boostersState,
                giftsState: giftsState,
                giveawayAvailable: giveawayAvailable
            )
        }
    case .monetization:
        if revenueState != nil || starsState != nil {
            return monetizationEntries(
                presentationData: presentationData,
                state: state,
                peer: peer,
                data: revenueState,
                boostData: boostData,
                transactionsInfo: revenueTransactions,
                starsData: starsState,
                starsTransactionsInfo: starsTransactions,
                adsRestricted: adsRestricted,
                premiumConfiguration: premiumConfiguration,
                monetizationConfiguration: monetizationConfiguration,
                canViewRevenue: canViewRevenue,
                canViewStarsRevenue: canViewStarsRevenue,
                canJoinRefPrograms: canJoinRefPrograms
            )
        }
    }
    return []
}

public func channelStatsController(
    context: AccountContext,
    updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil,
    peerId: PeerId,
    section: ChannelStatsSection = .stats,
    existingRevenueContext: StarsRevenueStatsContext? = nil,
    existingStarsRevenueContext: StarsRevenueStatsContext? = nil,
    boostStatus: ChannelBoostStatus? = nil,
    boostStatusUpdated: ((ChannelBoostStatus) -> Void)? = nil
) -> ViewController {
    let statePromise = ValuePromise(ChannelStatsControllerState(section: section, boostersExpanded: false, moreBoostersDisplayed: 0, giftsSelected: false, starsSelected: false, transactionsExpanded: false, moreTransactionsDisplayed: 0), ignoreRepeated: true)
    let stateValue = Atomic(value: ChannelStatsControllerState(section: section, boostersExpanded: false, moreBoostersDisplayed: 0, giftsSelected: false, starsSelected: false, transactionsExpanded: false, moreTransactionsDisplayed: 0))
    let updateState: ((ChannelStatsControllerState) -> ChannelStatsControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    let premiumConfiguration = PremiumConfiguration.with(appConfiguration: context.currentAppConfiguration.with { $0 })
    let monetizationConfiguration = MonetizationConfiguration.with(appConfiguration: context.currentAppConfiguration.with { $0 })
    
    var openPostStatsImpl: ((EnginePeer, StatsPostItem) -> Void)?
    var openStoryImpl: ((EngineStoryItem, UIView) -> Void)?
    var contextActionImpl: ((MessageId, ASDisplayNode, ContextGesture?) -> Void)?
    
    let actionsDisposable = DisposableSet()    
    let dataPromise = Promise<ChannelStats?>(nil)
    let messagesPromise = Promise<MessageHistoryView?>(nil)
    
    let withdrawalDisposable = MetaDisposable()
    actionsDisposable.add(withdrawalDisposable)
    
    let storiesPromise = Promise<StoryListContext.State?>()
            
    let statsContext = ChannelStatsContext(postbox: context.account.postbox, network: context.account.network, peerId: peerId)
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
                statsContext.loadReactionsByEmotionGraph()
                statsContext.loadStoryInteractionsGraph()
                statsContext.loadStoryReactionsByEmotionGraph()
            }
        }
    })
    dataPromise.set(.single(nil) |> then(dataSignal))
    
    let boostDataPromise = Promise<ChannelBoostStatus?>()
    boostDataPromise.set(.single(boostStatus) |> then(context.engine.peers.getChannelBoostStatus(peerId: peerId)))
    
    actionsDisposable.add((boostDataPromise.get()
    |> deliverOnMainQueue).start(next: { boostStatus in
        if let boostStatus, let boostStatusUpdated {
            boostStatusUpdated(boostStatus)
        }
    }))

    let boostsContext = ChannelBoostersContext(account: context.account, peerId: peerId, gift: false)
    let giftsContext = ChannelBoostersContext(account: context.account, peerId: peerId, gift: true)
    let revenueContext = existingRevenueContext ?? context.engine.payments.peerStarsRevenueContext(peerId: peerId, ton: true)
    let revenueState = Promise<StarsRevenueStatsContextState?>()
    revenueState.set(.single(nil) |> then(revenueContext.state |> map(Optional.init)))
    
    let starsContext = existingStarsRevenueContext ?? context.engine.payments.peerStarsRevenueContext(peerId: peerId, ton: false)
    let starsState = Promise<StarsRevenueStatsContextState?>()
    starsState.set(.single(nil) |> then(starsContext.state |> map(Optional.init)))
    
    let revenueTransactions = context.engine.payments.peerStarsTransactionsContext(subject: .peer(peerId: peerId, ton: true), mode: .all)
    revenueTransactions.loadMore()
    let starsTransactions = context.engine.payments.peerStarsTransactionsContext(subject: .peer(peerId: peerId, ton: false), mode: .all)
    starsTransactions.loadMore()
    
    var dismissAllTooltipsImpl: (() -> Void)?
    var presentImpl: ((ViewController) -> Void)?
    var pushImpl: ((ViewController) -> Void)?
    var dismissImpl: (() -> Void)?
    var navigateToChatImpl: ((EnginePeer) -> Void)?
    var navigateToMessageImpl: ((EngineMessage.Id) -> Void)?
    var openBoostImpl: ((Bool) -> Void)?
    var openTonTransactionImpl: ((StarsContext.State.Transaction) -> Void)?
    var openStarsTransactionImpl: ((StarsContext.State.Transaction) -> Void)?
    var requestTonWithdrawImpl: (() -> Void)?
    var requestStarsWithdrawImpl: (() -> Void)?
    var showTimeoutTooltipImpl: ((Int32) -> Void)?
    var buyAdsImpl: (() -> Void)?
    var updateStatusBarImpl: ((StatusBarStyle) -> Void)?
    var dismissInputImpl: (() -> Void)?
    
    let arguments = ChannelStatsControllerArguments(context: context, loadDetailedGraph: { graph, x -> Signal<StatsGraph?, NoError> in
        return statsContext.loadDetailedGraph(graph, x: x)
    }, openPostStats: { peer, item in
        openPostStatsImpl?(peer, item)
    }, openStory: { story, sourceView in
        openStoryImpl?(story, sourceView)
    }, contextAction: { messageId, node, gesture in
        contextActionImpl?(messageId, node, gesture)
    }, copyBoostLink: { link in
        UIPasteboard.general.string = link
                
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        presentImpl?(UndoOverlayController(presentationData: presentationData, content: .linkCopied(title: nil, text: presentationData.strings.ChannelBoost_BoostLinkCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }))
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
                
                presentImpl?(UndoOverlayController(presentationData: presentationData, content: .forward(savedMessages: savedMessages, text: text), elevatedLayout: false, animateInAsReplacement: true, action: { action in
                    if savedMessages, action == .info {
                        let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))
                        |> deliverOnMainQueue).start(next: { peer in
                            guard let peer else {
                                return
                            }
                            navigateToChatImpl?(peer)
                        })
                    }
                    return false
                }))
            })
        }
        shareController.actionCompleted = {
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            presentImpl?(UndoOverlayController(presentationData: presentationData, content: .linkCopied(title: nil, text: presentationData.strings.ChannelBoost_BoostLinkCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }))
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
            if let _ = boost.stars {
                let controller = context.sharedContext.makeStarsGiveawayBoostScreen(context: context, peerId: peerId, boost: boost)
                pushImpl?(controller)
            } else {
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                presentImpl?(UndoOverlayController(presentationData: presentationData, content: .info(title: nil, text: presentationData.strings.Stats_Boosts_TooltipToBeDistributed, timeout: nil, customUndoText: nil), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }))
            }
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
    },
    updateStarsSelected: { selected in
        updateState { $0.withUpdatedStarsSelected(selected).withUpdatedTransactionsExpanded(false) }
    },
    requestTonWithdraw: {
        requestTonWithdrawImpl?()
    },
    requestStarsWithdraw: {
        requestStarsWithdrawImpl?()
    },
    showTimeoutTooltip: { timestamp in
        showTimeoutTooltipImpl?(timestamp)
    },
    buyAds: {
        buyAdsImpl?()
    },
    openMonetizationIntro: {
        let controller = MonetizationIntroScreen(context: context, mode: existingRevenueContext != nil ? .bot : .channel, openMore: {})
        pushImpl?(controller)
    },
    openMonetizationInfo: {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        context.sharedContext.openExternalUrl(context: context, urlContext: .generic, url: presentationData.strings.Monetization_BalanceInfo_URL, forceExternal: true, presentationData: presentationData, navigationController: nil, dismissInput: {})
    },
    openTonTransaction: { transaction in
        openTonTransactionImpl?(transaction)
    },
    openStarsTransaction: { transaction in
        openStarsTransactionImpl?(transaction)
    },
    expandTransactions: { stars in
        updateState { state in
            if state.transactionsExpanded {
                return state.withUpdatedMoreTransactionsDisplayed(state.moreTransactionsDisplayed + 50)
            } else {
                return state.withUpdatedTransactionsExpanded(true)
            }
        }
        if stars {
            starsTransactions.loadMore()
        } else {
            revenueTransactions.loadMore()
        }
    },
    updateCpmEnabled: { value in
        let _ = context.engine.peers.updateChannelRestrictAdMessages(peerId: peerId, restricted: value).start()
    },
    presentCpmLocked: {
        let _ = combineLatest(
            queue: Queue.mainQueue(),
            context.engine.peers.getChannelBoostStatus(peerId: peerId),
            context.engine.peers.getMyBoostStatus()
        ).startStandalone(next: { boostStatus, myBoostStatus in
            guard let boostStatus, let myBoostStatus else {
                return
            }
            boostDataPromise.set(.single(boostStatus))
            
            let controller = context.sharedContext.makePremiumBoostLevelsController(context: context, peerId: peerId, subject: .noAds, boostStatus: boostStatus, myBoostStatus: myBoostStatus, forceDark: false, openStats: nil)
            pushImpl?(controller)
        })
    },
    openEarnStars: {
        let _ = (context.sharedContext.makeAffiliateProgramSetupScreenInitialData(context: context, peerId: peerId, mode: .connectedPrograms)
        |> deliverOnMainQueue).startStandalone(next: { initialData in
            pushImpl?(context.sharedContext.makeAffiliateProgramSetupScreen(context: context, initialData: initialData))
        })
    },
    dismissInput: {
        dismissInputImpl?()
    })
    
    let messageView = context.account.viewTracker.aroundMessageHistoryViewForLocation(.peer(peerId: peerId, threadId: nil), index: .upperBound, anchorIndex: .upperBound, count: 200, fixedCombinedReadStates: nil)
    |> map { messageHistoryView, _, _ -> MessageHistoryView? in
        return messageHistoryView
    }
    messagesPromise.set(.single(nil) |> then(messageView))
    
    let storyList = PeerStoryListContext(account: context.account, peerId: peerId, isArchived: false)
    storyList.loadMore()
    storiesPromise.set(
        .single(nil) 
        |> then(
            storyList.state
            |> map(Optional.init)
        )
    )
    
    let peer = Promise<EnginePeer?>()
    peer.set(context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)))
    
    let canViewStatsValue = Atomic<Bool>(value: true)
    let peerData = context.engine.data.get(
        TelegramEngine.EngineData.Item.Peer.CanViewStats(id: peerId),
        TelegramEngine.EngineData.Item.Peer.AdsRestricted(id: peerId),
        TelegramEngine.EngineData.Item.Peer.CanViewRevenue(id: peerId),
        TelegramEngine.EngineData.Item.Peer.CanViewStarsRevenue(id: peerId)
    )
    
    let longLoadingSignal: Signal<Bool, NoError> = .single(false) |> then(.single(true) |> delay(2.0, queue: Queue.mainQueue()))
    let previousData = Atomic<ChannelStats?>(value: nil)

    let presentationData = updatedPresentationData?.signal ?? context.sharedContext.presentationData
    let signal = combineLatest(
        presentationData,
        statePromise.get(),
        peer.get(),
        dataPromise.get(),
        messagesPromise.get(),
        storiesPromise.get(),
        boostDataPromise.get(),
        boostsContext.state,
        giftsContext.state,
        revenueState.get(),
        revenueTransactions.state,
        starsState.get(),
        starsTransactions.state,
        peerData,
        longLoadingSignal
    )
    |> deliverOnMainQueue
    |> map { presentationData, state, peer, data, messageView, stories, boostData, boostersState, giftsState, revenueState, revenueTransactions, starsState, starsTransactions, peerData, longLoading -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let (canViewStats, adsRestricted, _, _) = peerData
        var canViewRevenue = peerData.2
        var canViewStarsRevenue = peerData.3
        
        var canJoinRefPrograms = false
        if let data = context.currentAppConfiguration.with({ $0 }).data, let value = data["starref_connect_allowed"] {
            if let value = value as? Double {
                canJoinRefPrograms = value != 0.0
            } else if let value = value as? Bool {
                canJoinRefPrograms = value
            }
        }
        
        let _ = canViewStatsValue.swap(canViewStats)
        
        var isGroup = false
        if let peer, case let .channel(channel) = peer, case .group = channel.info {
            isGroup = true
        }
        
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
        case .monetization:
            if revenueState?.stats == nil && starsState?.stats == nil {
                emptyStateItem = ItemListLoadingIndicatorEmptyStateItem(theme: presentationData.theme)
            }
        }
        
        var existingGroupingKeys = Set<Int64>()
        var idsToFilter = Set<MessageId>()
        var messages = messageView?.entries.map { $0.message } ?? []
        for message in messages {
            if let groupingKey = message.groupingKey {
                if existingGroupingKeys.contains(groupingKey) {
                    idsToFilter.insert(message.id)
                } else {
                    existingGroupingKeys.insert(groupingKey)
                }
            }
        }
        messages = messages.filter { !idsToFilter.contains($0.id) }.sorted(by: { (lhsMessage, rhsMessage) -> Bool in
            return lhsMessage.timestamp > rhsMessage.timestamp
        })
        let interactions = data?.postInteractions.reduce([ChannelStatsPostInteractions.PostId : ChannelStatsPostInteractions]()) { (map, interactions) -> [ChannelStatsPostInteractions.PostId : ChannelStatsPostInteractions] in
            var map = map
            map[interactions.postId] = interactions
            return map
        }
                
        var title: ItemListControllerTitle
        var headerItem: BoostHeaderItem?
        var leftNavigationButton: ItemListNavigationButton?
        var boostsOnly = false
        if existingStarsRevenueContext != nil {
            title = .text(presentationData.strings.Stats_Monetization)
            canViewStarsRevenue = true
        } else if existingRevenueContext != nil {
            title = .text(presentationData.strings.Stats_TonBotRevenue_Title)
            canViewRevenue = true
        } else if section == .boosts {
            title = .text("")
            
            let headerTitle = isGroup ? presentationData.strings.GroupBoost_Title : presentationData.strings.ChannelBoost_Title
            let headerText = isGroup ? presentationData.strings.GroupBoost_Info : presentationData.strings.ChannelBoost_Info
            
            headerItem = BoostHeaderItem(context: context, theme: presentationData.theme, strings: presentationData.strings, status: boostData, title: headerTitle, text: headerText, openBoost: {
                openBoostImpl?(false)
            }, createGiveaway: {
                arguments.openGifts()
            }, openFeatures: {
                openBoostImpl?(true)
            }, back: {
                dismissImpl?()
            }, updateStatusBar: { style in
                updateStatusBarImpl?(style)
            })
            leftNavigationButton = ItemListNavigationButton(content: .none, style: .regular, enabled: false, action: {})
            boostsOnly = true
        } else {
            var index: Int
            switch state.section {
            case .stats:
                index = 0
            case .boosts:
                if canViewStats {
                    index = 1
                } else {
                    index = 0
                }
            case .monetization:
                if canViewStats {
                    index = 2
                } else {
                    index = 1
                }
            }
            var tabs: [String] = []
            if canViewStats {
                tabs.append(presentationData.strings.Stats_Statistics)
            }
            tabs.append(presentationData.strings.Stats_Boosts)
            if canViewRevenue || canViewStarsRevenue {
                tabs.append(presentationData.strings.Stats_Monetization)
            }
            title = .textWithTabs(peer?.compactDisplayTitle ?? "", tabs, index)
        }
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: title, leftNavigationButton: leftNavigationButton, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: true)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: channelStatsControllerEntries(presentationData: presentationData, state: state, peer: peer, data: data, messages: messages, stories: stories, interactions: interactions, boostData: boostData, boostersState: boostersState, giftsState: giftsState, giveawayAvailable: premiumConfiguration.giveawayGiftsPurchaseAvailable, isGroup: isGroup, boostsOnly: boostsOnly, revenueState: revenueState?.stats, revenueTransactions: revenueTransactions, starsState: starsState?.stats, starsTransactions: starsTransactions, adsRestricted: adsRestricted, premiumConfiguration: premiumConfiguration, monetizationConfiguration: monetizationConfiguration, canViewRevenue: canViewRevenue, canViewStarsRevenue: canViewStarsRevenue, canJoinRefPrograms: canJoinRefPrograms), style: .blocks, emptyStateItem: emptyStateItem, headerItem: headerItem, crossfadeState: previous == nil, animateChanges: false)
        
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
        actionsDisposable.dispose()
        let _ = statsContext.state
        let _ = storyList.state
        let _ = revenueContext.state
        let _ = starsContext.state
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
        updateState { state in
            let canViewStats = canViewStatsValue.with { $0 }
            let section: ChannelStatsSection
            switch value {
            case 0:
                if canViewStats {
                    section = .stats
                } else {
                    section = .boosts
                }
            case 1:
                if canViewStats {
                    section = .boosts
                } else {
                    section = .monetization
                }
            case 2:
                section = .monetization
                let _ = (ApplicationSpecificNotice.monetizationIntroDismissed(accountManager: context.sharedContext.accountManager)
                |> deliverOnMainQueue).start(next: { dismissed in
                    if !dismissed {
                        arguments.openMonetizationIntro()
                        let _ = ApplicationSpecificNotice.setMonetizationIntroDismissed(accountManager: context.sharedContext.accountManager).start()
                    }
                })
            default:
                section = .stats
            }
            return state.withUpdatedSection(section)
        }
    }
    controller.didDisappear = { [weak controller] _ in
        controller?.clearItemNodesHighlight(animated: true)
    }
    openPostStatsImpl = { [weak controller] peer, post in
        let subject: StatsSubject
        switch post {
        case let .message(message):
            subject = .message(id: message.id)
        case let .story(_, story):
            subject = .story(peerId: peerId, id: story.id, item: story, fromStory: false)
        }
        controller?.push(messageStatsController(context: context, subject: subject))
    }
    openStoryImpl = { [weak controller] story, sourceView in
        let storyContent = SingleStoryContentContextImpl(context: context, storyId: StoryId(peerId: peerId, id: story.id), storyItem: story, readGlobally: false)
        let _ = (storyContent.state
        |> take(1)
        |> deliverOnMainQueue).startStandalone(next: { [weak controller, weak sourceView] _ in
            guard let controller, let sourceView else {
                return
            }
            let transitionIn = StoryContainerScreen.TransitionIn(
                sourceView: sourceView,
                sourceRect: sourceView.bounds,
                sourceCornerRadius: sourceView.bounds.width * 0.5,
                sourceIsAvatar: false
            )
        
            let storyContainerScreen = StoryContainerScreen(
                context: context,
                content: storyContent,
                transitionIn: transitionIn,
                transitionOut: { [weak sourceView] peerId, storyIdValue in
                    if let sourceView {
                        let destinationView = sourceView
                        return StoryContainerScreen.TransitionOut(
                            destinationView: destinationView,
                            transitionView: StoryContainerScreen.TransitionView(
                                makeView: { [weak destinationView] in
                                    let parentView = UIView()
                                    if let copyView = destinationView?.snapshotContentTree(unhide: true) {
                                        parentView.addSubview(copyView)
                                    }
                                    return parentView
                                },
                                updateView: { copyView, state, transition in
                                    guard let view = copyView.subviews.first else {
                                        return
                                    }
                                    let size = state.sourceSize.interpolate(to: state.destinationSize, amount: state.progress)
                                    transition.setPosition(view: view, position: CGPoint(x: size.width * 0.5, y: size.height * 0.5))
                                    transition.setScale(view: view, scale: size.width / state.destinationSize.width)
                                },
                                insertCloneTransitionView: nil
                            ),
                            destinationRect: destinationView.bounds,
                            destinationCornerRadius: destinationView.bounds.width * 0.5,
                            destinationIsAvatar: false,
                            completed: { [weak sourceView] in
                                guard let sourceView else {
                                    return
                                }
                                sourceView.isHidden = false
                            }
                        )
                    } else {
                        return nil
                    }
                }
            )
            controller.push(storyContainerScreen)
        })
    }
    contextActionImpl = { [weak controller] messageId, sourceNode, gesture in
        guard let controller = controller, let sourceNode = sourceNode as? ContextExtractedContentContainingNode else {
            return
        }
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        var items: [ContextMenuItem] = []
        items.append(.action(ContextMenuActionItem(text: presentationData.strings.Conversation_ViewInChannel, icon: { theme in generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/GoToMessage"), color: theme.contextMenu.primaryColor) }, action: { [weak controller] c, _ in
            c?.dismiss(completion: {
                let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
                |> deliverOnMainQueue).start(next: { peer in
                    guard let peer = peer else {
                        return
                    }
                    
                    if let navigationController = controller?.navigationController as? NavigationController {
                        context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peer), subject: .message(id: .id(messageId), highlight: ChatControllerSubject.MessageHighlight(quote: nil), timecode: nil, setupReply: false)))
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
    dismissImpl = { [weak controller] in
        controller?.dismiss()
    }
    navigateToChatImpl = { [weak controller] peer in
        if let navigationController = controller?.navigationController as? NavigationController {
            context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peer), keepStack: .always, purposefulAction: {}, peekData: nil, forceOpenChat: true))
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
                context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peer), subject: .message(id: .id(messageId), highlight: ChatControllerSubject.MessageHighlight(quote: nil), timecode: nil, setupReply: false), keepStack: .always, useExisting: false, purposefulAction: {}, peekData: nil))
            }
        })
    }
    openBoostImpl = { features in
        if features {
            let boostController = PremiumBoostLevelsScreen(
                context: context,
                peerId: peerId,
                mode: .features,
                status: nil,
                myBoostStatus: nil
            )
            pushImpl?(boostController)
        } else {
            let _ = combineLatest(
                queue: Queue.mainQueue(),
                context.engine.peers.getChannelBoostStatus(peerId: peerId),
                context.engine.peers.getMyBoostStatus()
            ).startStandalone(next: { boostStatus, myBoostStatus in
                guard let boostStatus, let myBoostStatus else {
                    return
                }
                boostDataPromise.set(.single(boostStatus))
                
                let boostController = PremiumBoostLevelsScreen(
                    context: context,
                    peerId: peerId,
                    mode: .owner(subject: nil),
                    status: boostStatus,
                    myBoostStatus: myBoostStatus,
                    openGift: {
                        let giveawayController = createGiveawayController(context: context, peerId: peerId, subject: .generic)
                        pushImpl?(giveawayController)
                    }
                )
                boostController.boostStatusUpdated = { boostStatus, _ in
                    boostDataPromise.set(.single(boostStatus))
                }
                pushImpl?(boostController)
            })
        }
    }
    requestTonWithdrawImpl = {
        withdrawalDisposable.set((context.engine.peers.checkStarsRevenueWithdrawalAvailability()
        |> deliverOnMainQueue).start(error: { error in
            let controller = revenueWithdrawalController(context: context, updatedPresentationData: updatedPresentationData, peerId: peerId, initialError: error, present: { c, _ in
                presentImpl?(c)
            }, completion: { url in
                let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                context.sharedContext.openExternalUrl(context: context, urlContext: .generic, url: url, forceExternal: true, presentationData: presentationData, navigationController: nil, dismissInput: {})
            })
            presentImpl?(controller)
        }))
    }
    requestStarsWithdrawImpl = {
        withdrawalDisposable.set((context.engine.peers.checkStarsRevenueWithdrawalAvailability()
        |> deliverOnMainQueue).start(error: { error in
            switch error {
            case .serverProvided:
                return
            case .requestPassword:
                let _ = (starsContext.state
                |> take(1)
                |> deliverOnMainQueue).startStandalone(next: { state in
                    guard let stats = state.stats else {
                        return
                    }
                    let controller = context.sharedContext.makeStarsWithdrawalScreen(context: context, stats: stats, completion: { amount in
                        let controller = confirmStarsRevenueWithdrawalController(context: context, peerId: peerId, amount: amount, present: { c, a in
                            presentImpl?(c)
                        }, completion: { url in
                            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                            context.sharedContext.openExternalUrl(context: context, urlContext: .generic, url: url, forceExternal: true, presentationData: presentationData, navigationController: nil, dismissInput: {})
                            
                            Queue.mainQueue().after(2.0) {
                                starsContext.reload()
                                starsTransactions.reload()
                            }
                        })
                        presentImpl?(controller)
                    })
                    pushImpl?(controller)
                })
            default:
                let controller = starsRevenueWithdrawalController(context: context, peerId: peerId, amount: 0, initialError: error, present: { c, a in
                    presentImpl?(c)
                }, completion: { _ in
                    
                })
                presentImpl?(controller)
            }
        }))
    }
    var tooltipScreen: UndoOverlayController?
    #if compiler(>=6.0) // Xcode 16
    nonisolated(unsafe) var timer: Foundation.Timer?
    #else
    var timer: Foundation.Timer?
    #endif
    showTimeoutTooltipImpl = { cooldownUntilTimestamp in
        let remainingCooldownSeconds = cooldownUntilTimestamp - Int32(Date().timeIntervalSince1970)
    
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let content: UndoOverlayContent = .universal(
            animation: "anim_clock",
            scale: 0.058,
            colors: [:],
            title: nil,
            text: presentationData.strings.Stars_Withdraw_Withdraw_ErrorTimeout(stringForRemainingTime(remainingCooldownSeconds)).string,
            customUndoText: nil,
            timeout: nil
        )
        let controller = UndoOverlayController(presentationData: presentationData, content: content, elevatedLayout: false, position: .bottom, animateInAsReplacement: false, action: { _ in
            return true
        })
        tooltipScreen = controller
        presentImpl?(controller)
        
        if remainingCooldownSeconds < 3600 {
            if timer == nil {
                timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true, block: { _ in
                    if let tooltipScreen {
                        let remainingCooldownSeconds = cooldownUntilTimestamp - Int32(Date().timeIntervalSince1970)
                        let content: UndoOverlayContent = .universal(
                            animation: "anim_clock",
                            scale: 0.058,
                            colors: [:],
                            title: nil,
                            text: presentationData.strings.Stars_Withdraw_Withdraw_ErrorTimeout(stringForRemainingTime(remainingCooldownSeconds)).string,
                            customUndoText: nil,
                            timeout: nil
                        )
                        tooltipScreen.content = content
                    } else {
                        if let currentTimer = timer {
                            timer = nil
                            currentTimer.invalidate()
                        }
                    }
                })
            }
        }
    }
    buyAdsImpl = {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let _ = (context.engine.peers.requestStarsRevenueAdsAccountlUrl(peerId: peerId)
        |> deliverOnMainQueue).startStandalone(next: { url in
            guard let url else {
                return
            }
            context.sharedContext.openExternalUrl(context: context, urlContext: .generic, url: url, forceExternal: true, presentationData: presentationData, navigationController: nil, dismissInput: {})
        })
    }
    openTonTransactionImpl = { transaction in
        let _ = (peer.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { peer in
            guard let peer else {
                return
            }
            pushImpl?(TransactionInfoScreen(context: context, peer: peer, transaction: transaction, openExplorer: { url in
                context.sharedContext.openExternalUrl(context: context, urlContext: .generic, url: url, forceExternal: true, presentationData: context.sharedContext.currentPresentationData.with { $0 }, navigationController: nil, dismissInput: {})
            }))
        })
    }
    openStarsTransactionImpl = { transaction in
        let _ = (peer.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { peer in
            guard let peer else {
                return
            }
            pushImpl?(context.sharedContext.makeStarsTransactionScreen(context: context, transaction: transaction, peer: peer))
        })
    }
    updateStatusBarImpl = { [weak controller] style in
        controller?.setStatusBarStyle(style, animated: true)
    }
    dismissInputImpl = { [weak controller] in
        controller?.view.endEditing(true)
    }
    return controller
}

final class ChannelStatsContextExtractedContentSource: ContextExtractedContentSource {
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

private struct MonetizationConfiguration {
    static var defaultValue: MonetizationConfiguration {
        return MonetizationConfiguration(withdrawalAvailable: false)
    }
    
    public let withdrawalAvailable: Bool
    
    fileprivate init(withdrawalAvailable: Bool) {
        self.withdrawalAvailable = withdrawalAvailable
    }
    
    static func with(appConfiguration: AppConfiguration) -> MonetizationConfiguration {
        if let data = appConfiguration.data, let withdrawalAvailable = data["channel_revenue_withdrawal_enabled"] as? Bool {
            return MonetizationConfiguration(withdrawalAvailable: withdrawalAvailable)
        } else {
            return .defaultValue
        }
    }
}
