import Foundation
import UIKit
import Display
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
import ItemListPeerItem
import ItemListPeerActionItem

private let maxUsersDisplayedLimit: Int32 = 10
private let maxUsersDisplayedHighLimit: Int32 = 12

private final class GroupStatsControllerArguments {
    let context: AccountContext
    let loadDetailedGraph: (StatsGraph, Int64) -> Signal<StatsGraph?, NoError>
    let openPeer: (PeerId) -> Void
    let openPeerHistory: (PeerId) -> Void
    let openPeerAdminActions: (PeerId) -> Void
    let promotePeer: (PeerId) -> Void
    let expandTopPosters: () -> Void
    let expandTopAdmins: () -> Void
    let expandTopInviters: () -> Void
    let setPostersPeerIdWithRevealedOptions: (PeerId?, PeerId?) -> Void
    let setAdminsPeerIdWithRevealedOptions: (PeerId?, PeerId?) -> Void
    let setInvitersPeerIdWithRevealedOptions: (PeerId?, PeerId?) -> Void
    
    init(context: AccountContext, loadDetailedGraph: @escaping (StatsGraph, Int64) -> Signal<StatsGraph?, NoError>, openPeer: @escaping (PeerId) -> Void, openPeerHistory: @escaping (PeerId) -> Void, openPeerAdminActions: @escaping (PeerId) -> Void, promotePeer: @escaping (PeerId) -> Void, expandTopPosters: @escaping () -> Void, expandTopAdmins: @escaping () -> Void, expandTopInviters: @escaping () -> Void, setPostersPeerIdWithRevealedOptions: @escaping (PeerId?, PeerId?) -> Void, setAdminsPeerIdWithRevealedOptions: @escaping (PeerId?, PeerId?) -> Void, setInvitersPeerIdWithRevealedOptions: @escaping (PeerId?, PeerId?) -> Void) {
        self.context = context
        self.loadDetailedGraph = loadDetailedGraph
        self.openPeer = openPeer
        self.openPeerHistory = openPeerHistory
        self.openPeerAdminActions = openPeerAdminActions
        self.promotePeer = promotePeer
        self.expandTopPosters = expandTopPosters
        self.expandTopAdmins = expandTopAdmins
        self.expandTopInviters = expandTopInviters
        self.setPostersPeerIdWithRevealedOptions = setPostersPeerIdWithRevealedOptions
        self.setAdminsPeerIdWithRevealedOptions = setAdminsPeerIdWithRevealedOptions
        self.setInvitersPeerIdWithRevealedOptions = setInvitersPeerIdWithRevealedOptions
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
    case topWeekdays
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
    
    case topWeekdaysTitle(PresentationTheme, String)
    case topWeekdaysGraph(PresentationTheme, PresentationStrings, PresentationDateTimeFormat, StatsGraph, ChartType)
    
    case topPostersTitle(PresentationTheme, String, String)
    case topPoster(Int32, PresentationTheme, PresentationStrings, PresentationDateTimeFormat, Peer, GroupStatsTopPoster, Bool, Bool)
    case topPostersExpand(PresentationTheme, String)
    
    case topAdminsTitle(PresentationTheme, String, String)
    case topAdmin(Int32, PresentationTheme, PresentationStrings, PresentationDateTimeFormat, Peer, GroupStatsTopAdmin, Bool, Bool)
    case topAdminsExpand(PresentationTheme, String)
    
    case topInvitersTitle(PresentationTheme, String, String)
    case topInviter(Int32, PresentationTheme, PresentationStrings, PresentationDateTimeFormat, Peer, GroupStatsTopInviter, Bool, Bool)
    case topInvitersExpand(PresentationTheme, String)
    
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
            case .topWeekdaysTitle, .topWeekdaysGraph:
                return StatsSection.topWeekdays.rawValue
            case .topPostersTitle, .topPoster, .topPostersExpand:
                return StatsSection.topPosters.rawValue
            case .topAdminsTitle, .topAdmin, .topAdminsExpand:
                return StatsSection.topAdmins.rawValue
            case .topInvitersTitle, .topInviter, .topInvitersExpand:
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
            case .topWeekdaysTitle:
                return 16
            case .topWeekdaysGraph:
                return 17
            case .topPostersTitle:
                return 1000
            case let .topPoster(index, _, _, _, _, _, _, _):
                return 1001 + index
            case .topPostersExpand:
                return 1999
            case .topAdminsTitle:
                return 2000
            case let .topAdmin(index, _, _, _, _, _, _, _):
                return 2001 + index
            case .topAdminsExpand:
                return 2999
            case .topInvitersTitle:
                return 3000
            case let .topInviter(index, _, _, _, _, _, _, _):
                return 3001 + index
            case .topInvitersExpand:
                return 3999
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
            case let .topWeekdaysTitle(lhsTheme, lhsText):
                if case let .topWeekdaysTitle(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
            }
            case let .topWeekdaysGraph(lhsTheme, lhsStrings, lhsDateTimeFormat, lhsGraph, lhsType):
                if case let .topWeekdaysGraph(rhsTheme, rhsStrings, rhsDateTimeFormat, rhsGraph, rhsType) = rhs, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsDateTimeFormat == rhsDateTimeFormat, lhsGraph == rhsGraph, lhsType == rhsType {
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
            case let .topPoster(lhsIndex, lhsTheme, lhsStrings, lhsDateTimeFormat, lhsPeer, lhsTopPoster, lhsRevealed, lhsCanPromote):
                if case let .topPoster(rhsIndex, rhsTheme, rhsStrings, rhsDateTimeFormat, rhsPeer, rhsTopPoster, rhsRevealed, rhsCanPromote) = rhs, lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsDateTimeFormat == rhsDateTimeFormat, arePeersEqual(lhsPeer, rhsPeer), lhsTopPoster == rhsTopPoster, lhsRevealed == rhsRevealed, lhsCanPromote == rhsCanPromote {
                    return true
                } else {
                    return false
                }
            case let .topPostersExpand(lhsTheme, lhsText):
                if case let .topPostersExpand(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
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
            case let .topAdmin(lhsIndex, lhsTheme, lhsStrings, lhsDateTimeFormat, lhsPeer, lhsTopAdmin, lhsRevealed, lhsCanPromote):
                if case let .topAdmin(rhsIndex, rhsTheme, rhsStrings, rhsDateTimeFormat, rhsPeer, rhsTopAdmin, rhsRevealed, rhsCanPromote) = rhs, lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsDateTimeFormat == rhsDateTimeFormat, arePeersEqual(lhsPeer, rhsPeer), lhsTopAdmin == rhsTopAdmin, lhsRevealed == rhsRevealed, lhsCanPromote == rhsCanPromote {
                    return true
                } else {
                    return false
                }
            case let .topAdminsExpand(lhsTheme, lhsText):
                if case let .topAdminsExpand(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
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
            case let .topInviter(lhsIndex, lhsTheme, lhsStrings, lhsDateTimeFormat, lhsPeer, lhsTopInviter, lhsRevealed, lhsCanPromote):
                if case let .topInviter(rhsIndex, rhsTheme, rhsStrings, rhsDateTimeFormat, rhsPeer, rhsTopInviter, rhsRevealed, rhsCanPromote) = rhs, lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsStrings === rhsStrings, lhsDateTimeFormat == rhsDateTimeFormat, arePeersEqual(lhsPeer, rhsPeer), lhsTopInviter == rhsTopInviter, lhsRevealed == rhsRevealed, lhsCanPromote == rhsCanPromote {
                    return true
                } else {
                    return false
                }
            case let .topInvitersExpand(lhsTheme, lhsText):
                if case let .topInvitersExpand(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
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
                 let .topHoursTitle(_, text),
                 let .topWeekdaysTitle(_, text):
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
                 let .topHoursGraph(_, _, _, graph, type),
                 let .topWeekdaysGraph(_, _, _, graph, type):
                return StatsGraphItem(presentationData: presentationData, graph: graph, type: type, sectionId: self.section, style: .blocks)
            case let .topPoster(_, _, strings, dateTimeFormat, peer, topPoster, revealed, canPromote):
                var textComponents: [String] = []
                if topPoster.messageCount > 0 {
                    textComponents.append(strings.Stats_GroupTopPosterMessages(topPoster.messageCount))
                    if topPoster.averageChars > 0 {
                        textComponents.append(strings.Stats_GroupTopPosterChars(topPoster.averageChars))
                    }
                }
                var options: [ItemListPeerItemRevealOption] = []
                if !peer.isDeleted {
                    options.append(ItemListPeerItemRevealOption(type: .accent, title: strings.Stats_GroupTopPoster_History, action: {
                        arguments.openPeerHistory(peer.id)
                    }))
                    if canPromote && arguments.context.account.peerId != peer.id {
                        options.append(ItemListPeerItemRevealOption(type: .neutral, title: strings.Stats_GroupTopPoster_Promote, action: {
                            arguments.promotePeer(peer.id)
                        }))
                    }
                }
                return ItemListPeerItem(presentationData: presentationData, dateTimeFormat: dateTimeFormat, nameDisplayOrder: .firstLast, context: arguments.context, peer: EnginePeer(peer), height: .generic, aliasHandling: .standard, nameColor: .primary, nameStyle: .plain, presence: nil, text: .text(textComponents.joined(separator: ", "), .secondary), label: .none, editing: ItemListPeerItemEditing(editable: true, editing: false, revealed: revealed), revealOptions: ItemListPeerItemRevealOptions(options: options), switchValue: nil, enabled: true, highlighted: false, selectable: arguments.context.account.peerId != peer.id, sectionId: self.section, action: {
                    arguments.openPeer(peer.id)
                }, setPeerIdWithRevealedOptions: { peerId, fromPeerId in
                    arguments.setPostersPeerIdWithRevealedOptions(peerId, fromPeerId)
                }, removePeer: { _ in })
            case let .topPostersExpand(theme, title):
                return ItemListPeerActionItem(presentationData: presentationData, icon: PresentationResourcesItemList.downArrowImage(theme), title: title, sectionId: self.section, editing: false, action: {
                    arguments.expandTopPosters()
                })
            case let .topAdmin(_, _, strings, dateTimeFormat, peer, topAdmin, revealed, canPromote):
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
                var options: [ItemListPeerItemRevealOption] = []
                if !peer.isDeleted {
                    options.append(ItemListPeerItemRevealOption(type: .accent, title: strings.Stats_GroupTopAdmin_Actions, action: {
                        arguments.openPeerAdminActions(peer.id)
                    }))
                    if canPromote && arguments.context.account.peerId != peer.id {
                        options.append(ItemListPeerItemRevealOption(type: .neutral, title: strings.Stats_GroupTopAdmin_Promote, action: {
                            arguments.promotePeer(peer.id)
                        }))
                    }
                }
                return ItemListPeerItem(presentationData: presentationData, dateTimeFormat: dateTimeFormat, nameDisplayOrder: .firstLast, context: arguments.context, peer: EnginePeer(peer), height: .generic, aliasHandling: .standard, nameColor: .primary, nameStyle: .plain, presence: nil, text: .text(textComponents.joined(separator: ", "), .secondary), label: .none, editing: ItemListPeerItemEditing(editable: true, editing: false, revealed: revealed), revealOptions: ItemListPeerItemRevealOptions(options: options), switchValue: nil, enabled: true, highlighted: false, selectable: arguments.context.account.peerId != peer.id, sectionId: self.section, action: {
                    arguments.openPeer(peer.id)
                }, setPeerIdWithRevealedOptions: { peerId, fromPeerId in
                    arguments.setAdminsPeerIdWithRevealedOptions(peerId, fromPeerId)
                }, removePeer: { _ in })
            case let .topAdminsExpand(theme, title):
                return ItemListPeerActionItem(presentationData: presentationData, icon: PresentationResourcesItemList.downArrowImage(theme), title: title, sectionId: self.section, editing: false, action: {
                    arguments.expandTopAdmins()
                })
            case let .topInviter(_, _, strings, dateTimeFormat, peer, topInviter, revealed, canPromote):
                var textComponents: [String] = []
                textComponents.append(strings.Stats_GroupTopInviterInvites(topInviter.inviteCount))
                var options: [ItemListPeerItemRevealOption] = []
                if !peer.isDeleted {
                    options.append(ItemListPeerItemRevealOption(type: .accent, title: strings.Stats_GroupTopPoster_History, action: {
                        arguments.openPeerHistory(peer.id)
                    }))
                    if canPromote && arguments.context.account.peerId != peer.id {
                        options.append(ItemListPeerItemRevealOption(type: .neutral, title: strings.Stats_GroupTopPoster_Promote, action: {
                            arguments.promotePeer(peer.id)
                        }))
                    }
                }
                return ItemListPeerItem(presentationData: presentationData, dateTimeFormat: dateTimeFormat, nameDisplayOrder: .firstLast, context: arguments.context, peer: EnginePeer(peer), height: .generic, aliasHandling: .standard, nameColor: .primary, nameStyle: .plain, presence: nil, text: .text(textComponents.joined(separator: ", "), .secondary), label: .none, editing: ItemListPeerItemEditing(editable: true, editing: false, revealed: revealed), revealOptions: ItemListPeerItemRevealOptions(options: options), switchValue: nil, enabled: true, highlighted: false, selectable: arguments.context.account.peerId != peer.id, sectionId: self.section, action: {
                    arguments.openPeer(peer.id)
                }, setPeerIdWithRevealedOptions: { peerId, fromPeerId in
                    arguments.setInvitersPeerIdWithRevealedOptions(peerId, fromPeerId)
                }, removePeer: { _ in })
            case let .topInvitersExpand(theme, title):
                return ItemListPeerActionItem(presentationData: presentationData, icon: PresentationResourcesItemList.downArrowImage(theme), title: title, sectionId: self.section, editing: false, action: {
                    arguments.expandTopInviters()
                })
        }
    }
}

private func groupStatsControllerEntries(accountPeerId: PeerId, state: GroupStatsState, data: GroupStats?, channelPeer: Peer, peers: [EnginePeer.Id: EnginePeer]?, presentationData: PresentationData) -> [StatsEntry] {
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
        
        if !data.topWeekdaysGraph.isEmpty {
            entries.append(.topWeekdaysTitle(presentationData.theme, presentationData.strings.Stats_GroupTopWeekdaysTitle))
            entries.append(.topWeekdaysGraph(presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, data.topWeekdaysGraph, .pie))
        }
                
        if let peers = peers {
            let canPromote = canEditAdminRights(accountPeerId: accountPeerId, channelPeer: channelPeer, initialParticipant: nil)
            if !data.topPosters.isEmpty {
                entries.append(.topPostersTitle(presentationData.theme, presentationData.strings.Stats_GroupTopPostersTitle, dates))
                var index: Int32 = 0
                
                var topPosters = data.topPosters
                var effectiveExpanded = state.topPostersExpanded
                if topPosters.count > maxUsersDisplayedHighLimit && !effectiveExpanded {
                    topPosters = Array(topPosters.prefix(Int(maxUsersDisplayedLimit)))
                } else {
                    effectiveExpanded = true
                }
                
                for topPoster in topPosters {
                    if let peer = peers[topPoster.peerId], topPoster.messageCount > 0 {
                        entries.append(.topPoster(index, presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, peer._asPeer(), topPoster, topPoster.peerId == state.posterPeerIdWithRevealedOptions, canPromote))
                        index += 1
                    }
                }

                if !effectiveExpanded {
                    entries.append(.topPostersExpand(presentationData.theme, presentationData.strings.Stats_GroupShowMoreTopPosters(Int32(data.topPosters.count) - maxUsersDisplayedLimit)))
                }
            }
            if !data.topAdmins.isEmpty {
                entries.append(.topAdminsTitle(presentationData.theme, presentationData.strings.Stats_GroupTopAdminsTitle, dates))
                var index: Int32 = 0
                
                var topAdmins = data.topAdmins
                var effectiveExpanded = state.topAdminsExpanded
                if topAdmins.count > maxUsersDisplayedHighLimit && !effectiveExpanded {
                    topAdmins = Array(topAdmins.prefix(Int(maxUsersDisplayedLimit)))
                } else {
                    effectiveExpanded = true
                }
                
                for topAdmin in data.topAdmins {
                    if let peer = peers[topAdmin.peerId], (topAdmin.deletedCount + topAdmin.kickedCount + topAdmin.bannedCount) > 0 {
                        entries.append(.topAdmin(index, presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, peer._asPeer(), topAdmin, topAdmin.peerId == state.adminPeerIdWithRevealedOptions, canPromote))
                        index += 1
                    }
                }
                
                if !effectiveExpanded {
                    entries.append(.topAdminsExpand(presentationData.theme, presentationData.strings.Stats_GroupShowMoreTopAdmins(Int32(data.topAdmins.count) - maxUsersDisplayedLimit)))
                }
            }
            if !data.topInviters.isEmpty {
                entries.append(.topInvitersTitle(presentationData.theme, presentationData.strings.Stats_GroupTopInvitersTitle, dates))
                var index: Int32 = 0
                
                var topInviters = data.topInviters
                var effectiveExpanded = state.topInvitersExpanded
                if topInviters.count > maxUsersDisplayedHighLimit && !effectiveExpanded {
                    topInviters = Array(topInviters.prefix(Int(maxUsersDisplayedLimit)))
                } else {
                    effectiveExpanded = true
                }
                
                for topInviter in data.topInviters {
                    if let peer = peers[topInviter.peerId], topInviter.inviteCount > 0 {
                        entries.append(.topInviter(index, presentationData.theme, presentationData.strings, presentationData.dateTimeFormat, peer._asPeer(), topInviter, topInviter.peerId == state.inviterPeerIdWithRevealedOptions, canPromote))
                        index += 1
                    }
                }
                
                if !effectiveExpanded {
                    entries.append(.topInvitersExpand(presentationData.theme, presentationData.strings.Stats_GroupShowMoreTopInviters(Int32(data.topInviters.count) - maxUsersDisplayedLimit)))
                }
            }
        }
    }
    
    return entries
}

private struct GroupStatsState: Equatable {
    let topPostersExpanded: Bool
    let topAdminsExpanded: Bool
    let topInvitersExpanded: Bool
    let posterPeerIdWithRevealedOptions: PeerId?
    let adminPeerIdWithRevealedOptions: PeerId?
    let inviterPeerIdWithRevealedOptions: PeerId?
    
    init() {
        self.topPostersExpanded = false
        self.topAdminsExpanded = false
        self.topInvitersExpanded = false
        self.posterPeerIdWithRevealedOptions = nil
        self.adminPeerIdWithRevealedOptions = nil
        self.inviterPeerIdWithRevealedOptions = nil
    }
    
    init(topPostersExpanded: Bool, topAdminsExpanded: Bool, topInvitersExpanded: Bool, posterPeerIdWithRevealedOptions: PeerId?, adminPeerIdWithRevealedOptions: PeerId?, inviterPeerIdWithRevealedOptions: PeerId?) {
        self.topPostersExpanded = topPostersExpanded
        self.topAdminsExpanded = topAdminsExpanded
        self.topInvitersExpanded = topInvitersExpanded
        self.posterPeerIdWithRevealedOptions = posterPeerIdWithRevealedOptions
        self.adminPeerIdWithRevealedOptions = adminPeerIdWithRevealedOptions
        self.inviterPeerIdWithRevealedOptions = inviterPeerIdWithRevealedOptions
    }
  
    static func ==(lhs: GroupStatsState, rhs: GroupStatsState) -> Bool {
        if lhs.topPostersExpanded != rhs.topPostersExpanded {
            return false
        }
        if lhs.topAdminsExpanded != rhs.topAdminsExpanded {
            return false
        }
        if lhs.topInvitersExpanded != rhs.topInvitersExpanded {
            return false
        }
        if lhs.posterPeerIdWithRevealedOptions != rhs.posterPeerIdWithRevealedOptions {
            return false
        }
        if lhs.adminPeerIdWithRevealedOptions != rhs.adminPeerIdWithRevealedOptions {
            return false
        }
        if lhs.inviterPeerIdWithRevealedOptions != rhs.inviterPeerIdWithRevealedOptions {
            return false
        }
        return true
    }
    
    func withUpdatedTopPostersExpanded(_ topPostersExpanded: Bool) -> GroupStatsState {
        return GroupStatsState(topPostersExpanded: topPostersExpanded, topAdminsExpanded: self.topAdminsExpanded, topInvitersExpanded: self.topInvitersExpanded, posterPeerIdWithRevealedOptions: self.posterPeerIdWithRevealedOptions, adminPeerIdWithRevealedOptions: self.adminPeerIdWithRevealedOptions, inviterPeerIdWithRevealedOptions: self.inviterPeerIdWithRevealedOptions)
    }
    
    func withUpdatedTopAdminsExpanded(_ topAdminsExpanded: Bool) -> GroupStatsState {
        return GroupStatsState(topPostersExpanded: self.topPostersExpanded, topAdminsExpanded: topAdminsExpanded, topInvitersExpanded: self.topInvitersExpanded, posterPeerIdWithRevealedOptions: self.posterPeerIdWithRevealedOptions, adminPeerIdWithRevealedOptions: self.adminPeerIdWithRevealedOptions, inviterPeerIdWithRevealedOptions: self.inviterPeerIdWithRevealedOptions)
    }
    
    func withUpdatedTopInvitersExpanded(_ topInvitersExpanded: Bool) -> GroupStatsState {
        return GroupStatsState(topPostersExpanded: self.topPostersExpanded, topAdminsExpanded: self.topAdminsExpanded, topInvitersExpanded: topInvitersExpanded, posterPeerIdWithRevealedOptions: self.posterPeerIdWithRevealedOptions, adminPeerIdWithRevealedOptions: self.adminPeerIdWithRevealedOptions, inviterPeerIdWithRevealedOptions: self.inviterPeerIdWithRevealedOptions)
    }
    
    func withUpdatedPosterPeerIdWithRevealedOptions(_ posterPeerIdWithRevealedOptions: PeerId?) -> GroupStatsState {
        return GroupStatsState(topPostersExpanded: self.topPostersExpanded, topAdminsExpanded: self.topAdminsExpanded, topInvitersExpanded: self.topInvitersExpanded, posterPeerIdWithRevealedOptions: posterPeerIdWithRevealedOptions, adminPeerIdWithRevealedOptions: posterPeerIdWithRevealedOptions != nil ? nil : self.adminPeerIdWithRevealedOptions, inviterPeerIdWithRevealedOptions: posterPeerIdWithRevealedOptions != nil ? nil : self.inviterPeerIdWithRevealedOptions)
    }
    
    func withUpdatedAdminPeerIdWithRevealedOptions(_ adminPeerIdWithRevealedOptions: PeerId?) -> GroupStatsState {
        return GroupStatsState(topPostersExpanded: self.topPostersExpanded, topAdminsExpanded: self.topAdminsExpanded, topInvitersExpanded: self.topInvitersExpanded, posterPeerIdWithRevealedOptions: adminPeerIdWithRevealedOptions != nil ? nil : self.posterPeerIdWithRevealedOptions, adminPeerIdWithRevealedOptions: adminPeerIdWithRevealedOptions, inviterPeerIdWithRevealedOptions: adminPeerIdWithRevealedOptions != nil ? nil : self.inviterPeerIdWithRevealedOptions)
    }
    
    func withUpdatedInviterPeerIdWithRevealedOptions(_ inviterPeerIdWithRevealedOptions: PeerId?) -> GroupStatsState {
        return GroupStatsState(topPostersExpanded: self.topPostersExpanded, topAdminsExpanded: self.topAdminsExpanded, topInvitersExpanded: self.topInvitersExpanded, posterPeerIdWithRevealedOptions: inviterPeerIdWithRevealedOptions != nil ? nil : self.posterPeerIdWithRevealedOptions, adminPeerIdWithRevealedOptions: inviterPeerIdWithRevealedOptions != nil ? nil : self.adminPeerIdWithRevealedOptions, inviterPeerIdWithRevealedOptions: inviterPeerIdWithRevealedOptions)
    }
}

private func canEditAdminRights(accountPeerId: PeerId, channelPeer: Peer, initialParticipant: ChannelParticipant?) -> Bool {
    if let channel = channelPeer as? TelegramChannel {
        if channel.flags.contains(.isCreator) {
            return true
        } else if let initialParticipant = initialParticipant {
            switch initialParticipant {
                case .creator:
                    return false
                case let .member(_, _, adminInfo, _, _):
                    if let adminInfo = adminInfo {
                        return adminInfo.canBeEditedByAccountPeer || adminInfo.promotedBy == accountPeerId
                    } else {
                        return channel.hasPermission(.addAdmins)
                    }
            }
        } else {
            return channel.hasPermission(.addAdmins)
        }
    } else if let group = channelPeer as? TelegramGroup {
        if case .creator = group.role {
            return true
        } else {
            return false
        }
    } else {
        return false
    }
}

public func groupStatsController(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, peerId: PeerId, statsDatacenterId: Int32?) -> ViewController {
    let statePromise = ValuePromise(GroupStatsState())
    let stateValue = Atomic(value: GroupStatsState())
    let updateState: ((GroupStatsState) -> GroupStatsState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    let actionsDisposable = DisposableSet()
    let dataPromise = Promise<GroupStats?>(nil)
    let peersPromise = Promise<[EnginePeer.Id: EnginePeer]?>(nil)
    
    let datacenterId: Int32 = statsDatacenterId ?? 0
    
    var openPeerImpl: ((PeerId) -> Void)?
    var openPeerHistoryImpl: ((PeerId) -> Void)?
    var openPeerAdminActionsImpl: ((PeerId) -> Void)?
    var promotePeerImpl: ((PeerId) -> Void)?
    
    let peerView = Promise<PeerView>()
    peerView.set(context.account.viewTracker.peerView(peerId, updateData: true))
        
    let statsContext = GroupStatsContext(postbox: context.account.postbox, network: context.account.network, datacenterId: datacenterId, peerId: peerId)
    let dataSignal: Signal<GroupStats?, NoError> = statsContext.state
    |> map { state in
        return state.stats
    } |> afterNext({ [weak statsContext] stats in
        if let statsContext = statsContext, let stats = stats {
            if case .OnDemand = stats.topWeekdaysGraph {
                statsContext.loadGrowthGraph()
                statsContext.loadMembersGraph()
                statsContext.loadNewMembersBySourceGraph()
                statsContext.loadLanguagesGraph()
                statsContext.loadMessagesGraph()
                statsContext.loadActionsGraph()
                statsContext.loadTopHoursGraph()
                statsContext.loadTopWeekdaysGraph()
            }
        }
    })
    dataPromise.set(.single(nil) |> then(dataSignal))
    
    peersPromise.set(.single(nil) |> then(dataPromise.get()
    |> filter { value in
        return value != nil
    }
    |> take(1)
    |> map { stats -> [EnginePeer.Id]? in
        guard let stats = stats else {
            return nil
        }
        var peerIds = Set<EnginePeer.Id>()
        peerIds.formUnion(stats.topPosters.map { $0.peerId })
        peerIds.formUnion(stats.topAdmins.map { $0.peerId })
        peerIds.formUnion(stats.topInviters.map { $0.peerId })
        return Array(peerIds)
    }
    |> mapToSignal { peerIds -> Signal<[EnginePeer.Id: EnginePeer]?, NoError> in
        if let peerIds = peerIds {
            return context.engine.data.get(EngineDataMap(
                peerIds.map(TelegramEngine.EngineData.Item.Peer.Peer.init)
            ))
            |> map { peerMap -> [EnginePeer.Id: EnginePeer]? in
                return peerMap.compactMapValues { $0 }
            }
        } else {
            return .single([:])
        }
    }))
    
    let arguments = GroupStatsControllerArguments(context: context, loadDetailedGraph: { graph, x -> Signal<StatsGraph?, NoError> in
        return statsContext.loadDetailedGraph(graph, x: x)
    }, openPeer: { peerId in
        openPeerImpl?(peerId)
    }, openPeerHistory: { peerId in
        openPeerHistoryImpl?(peerId)
    }, openPeerAdminActions: { peerId in
        openPeerAdminActionsImpl?(peerId)
    }, promotePeer: { peerId in
        promotePeerImpl?(peerId)
    }, expandTopPosters: {
        updateState { state in
            return state.withUpdatedTopPostersExpanded(true)
        }
    }, expandTopAdmins: {
        updateState { state in
            return state.withUpdatedTopAdminsExpanded(true)
        }
    }, expandTopInviters: {
        updateState { state in
            return state.withUpdatedTopInvitersExpanded(true)
        }
    }, setPostersPeerIdWithRevealedOptions: { peerId, fromPeerId in
        updateState { state in
            if (peerId == nil && fromPeerId == state.posterPeerIdWithRevealedOptions) || (peerId != nil && fromPeerId == nil) {
                return state.withUpdatedPosterPeerIdWithRevealedOptions(peerId)
            } else {
                return state
            }
        }
    }, setAdminsPeerIdWithRevealedOptions: { peerId, fromPeerId in
        updateState { state in
            if (peerId == nil && fromPeerId == state.adminPeerIdWithRevealedOptions) || (peerId != nil && fromPeerId == nil) {
                return state.withUpdatedAdminPeerIdWithRevealedOptions(peerId)
            } else {
                return state
            }
        }
    }, setInvitersPeerIdWithRevealedOptions: { peerId, fromPeerId in
        updateState { state in
            if (peerId == nil && fromPeerId == state.inviterPeerIdWithRevealedOptions) || (peerId != nil && fromPeerId == nil) {
                return state.withUpdatedInviterPeerIdWithRevealedOptions(peerId)
            } else {
                return state
            }
        }
    })
        
    let longLoadingSignal: Signal<Bool, NoError> = .single(false) |> then(.single(true) |> delay(2.0, queue: Queue.mainQueue()))
    
    let previousData = Atomic<GroupStats?>(value: nil)
    
    let presentationData = updatedPresentationData?.signal ?? context.sharedContext.presentationData
    let signal = combineLatest(statePromise.get(), presentationData, dataPromise.get(), context.account.postbox.loadedPeerWithId(peerId), peersPromise.get(), longLoadingSignal)
    |> deliverOnMainQueue
    |> map { state, presentationData, data, channelPeer, peers, longLoading -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let previous = previousData.swap(data)
        var emptyStateItem: ItemListControllerEmptyStateItem?
        if data == nil {
            if longLoading {
                emptyStateItem = StatsEmptyStateItem(context: context, theme: presentationData.theme, strings: presentationData.strings)
            } else {
                emptyStateItem = ItemListLoadingIndicatorEmptyStateItem(theme: presentationData.theme)
            }
        }
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.ChannelInfo_Stats), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: true)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: groupStatsControllerEntries(accountPeerId: context.account.peerId, state: state, data: data, channelPeer: channelPeer, peers: peers, presentationData: presentationData), style: .blocks, emptyStateItem: emptyStateItem, crossfadeState: previous == nil, animateChanges: false)
        
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
                if let controller = context.sharedContext.makePeerInfoController(context: context, updatedPresentationData: nil, peer: peer, mode: .generic, avatarInitiallyExpanded: false, fromChat: false, requestsContext: nil) {
                    navigationController.pushViewController(controller)
                }
            })
        }
    }
    openPeerHistoryImpl = { [weak controller] participantPeerId in
        if let navigationController = controller?.navigationController as? NavigationController {
            let _ = (context.account.postbox.loadedPeerWithId(participantPeerId)
            |> take(1)
            |> deliverOnMainQueue).start(next: { peer in
                context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, chatController: nil, context: context, chatLocation: .peer(id: peerId), subject: nil, botStart: nil, updateTextInputState: nil, activateInput: false, keepStack: .always, useExisting: false, purposefulAction: nil, scrollToEndIfExists: false, activateMessageSearch: (.member(peer), ""), animated: true))
            })
        }
    }
    openPeerAdminActionsImpl = { [weak controller] participantPeerId in
        if let navigationController = controller?.navigationController as? NavigationController {
            let _ = (context.account.postbox.loadedPeerWithId(peerId)
            |> take(1)
            |> deliverOnMainQueue).start(next: { peer in
                let controller = context.sharedContext.makeChatRecentActionsController(context: context, peer: peer, adminPeerId: participantPeerId)
                navigationController.pushViewController(controller)
            })
        }
    }
    promotePeerImpl = { [weak controller] participantPeerId in
        if let navigationController = controller?.navigationController as? NavigationController {
            let _ = (context.engine.peers.fetchChannelParticipant(peerId: peerId, participantId: participantPeerId)
            |> take(1)
            |> deliverOnMainQueue).start(next: { participant in
                if let participant = participant, let controller = context.sharedContext.makeChannelAdminController(context: context, peerId: peerId, adminId: participantPeerId, initialParticipant: participant) {
                    navigationController.pushViewController(controller)
                }
            })
        }
    }
    return controller
}
