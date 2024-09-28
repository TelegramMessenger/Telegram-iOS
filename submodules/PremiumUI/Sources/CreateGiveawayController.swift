import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import AccountContext
import AlertUI
import PresentationDataUtils
import AppBundle
import TelegramStringFormatting
import ItemListPeerItem
import ItemListDatePickerItem
import ItemListPeerActionItem
import ShareWithPeersScreen
import InAppPurchaseManager
import UndoUI
import CountrySelectionUI

private final class CreateGiveawayControllerArguments {
    let context: AccountContext
    let updateState: ((CreateGiveawayControllerState) -> CreateGiveawayControllerState) -> Void
    let dismissInput: () -> Void
    let openPeersSelection: () -> Void
    let openChannelsSelection: () -> Void
    let openCountriesSelection: () -> Void
    let openPremiumIntro: () -> Void
    let scrollToDate: () -> Void
    let scrollToDescription: () -> Void
    let setItemIdWithRevealedOptions: (EnginePeer.Id?, EnginePeer.Id?) -> Void
    let removeChannel: (EnginePeer.Id) -> Void
    let expandStars: () -> Void
    
    init(context: AccountContext, updateState: @escaping ((CreateGiveawayControllerState) -> CreateGiveawayControllerState) -> Void, dismissInput: @escaping () -> Void, openPeersSelection: @escaping () -> Void, openChannelsSelection: @escaping () -> Void, openCountriesSelection: @escaping () -> Void, openPremiumIntro: @escaping () -> Void, scrollToDate: @escaping () -> Void, scrollToDescription: @escaping () -> Void, setItemIdWithRevealedOptions: @escaping (EnginePeer.Id?, EnginePeer.Id?) -> Void, removeChannel: @escaping (EnginePeer.Id) -> Void, expandStars: @escaping () -> Void) {
        self.context = context
        self.updateState = updateState
        self.dismissInput = dismissInput
        self.openPeersSelection = openPeersSelection
        self.openChannelsSelection = openChannelsSelection
        self.openCountriesSelection = openCountriesSelection
        self.openPremiumIntro = openPremiumIntro
        self.scrollToDate = scrollToDate
        self.scrollToDescription = scrollToDescription
        self.setItemIdWithRevealedOptions = setItemIdWithRevealedOptions
        self.removeChannel = removeChannel
        self.expandStars = expandStars
    }
}

private enum CreateGiveawaySection: Int32 {
    case header
    case mode
    case stars
    case subscriptions
    case channels
    case users
    case winners
    case prizeDescription
    case time
    case duration
}

private enum CreateGiveawayEntryTag: ItemListItemTag {
    case description
    case date

    func isEqual(to other: ItemListItemTag) -> Bool {
        if let other = other as? CreateGiveawayEntryTag, self == other {
            return true
        } else {
            return false
        }
    }
}

private enum CreateGiveawayEntry: ItemListNodeEntry {
    case header(PresentationTheme, String, String)
    
    case modeHeader(PresentationTheme, String)
    case giftPremium(PresentationTheme, String, String, Bool)
    case giftStars(PresentationTheme, String, String, Bool)
    
    case prepaidHeader(PresentationTheme, String)
    case prepaid(PresentationTheme, String, String, PrepaidGiveaway)
    
    case starsHeader(PresentationTheme, String, String)
    case stars(Int32, PresentationTheme, Int32, String, String, String, Bool, Int32)
    case starsMore(PresentationTheme, String)
    case starsInfo(PresentationTheme, String)
    
    case subscriptionsHeader(PresentationTheme, String, String)
    case subscriptions(PresentationTheme, Int32, [Int32])
    case subscriptionsInfo(PresentationTheme, String)
    
    case channelsHeader(PresentationTheme, String)
    case channel(Int32, PresentationTheme, EnginePeer, Int32?, Bool)
    case channelAdd(PresentationTheme, String)
    case channelsInfo(PresentationTheme, String)
    
    case usersHeader(PresentationTheme, String)
    case usersAll(PresentationTheme, String, String, Bool)
    case usersNew(PresentationTheme, String, String, Bool)
    case usersInfo(PresentationTheme, String)
    
    case durationHeader(PresentationTheme, String)
    case duration(Int32, PresentationTheme, Int32, String, String, String, String?, Bool)
    case durationInfo(PresentationTheme, String)
    
    case prizeDescription(PresentationTheme, String, Bool)
    case prizeDescriptionText(PresentationTheme, String, String, Int32)
    case prizeDescriptionInfo(PresentationTheme, String)
    
    case timeHeader(PresentationTheme, String)
    case timeExpiryDate(PresentationTheme, PresentationDateTimeFormat, Int32?, Bool)
    case timeCustomPicker(PresentationTheme, PresentationDateTimeFormat, Int32?, Int32?, Int32?, Bool, Bool)
    case timeInfo(PresentationTheme, String)
    
    case winners(PresentationTheme, String, Bool)
    case winnersInfo(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
        case .header:
            return CreateGiveawaySection.header.rawValue
        case .modeHeader, .giftPremium, .giftStars, .prepaidHeader, .prepaid:
            return CreateGiveawaySection.mode.rawValue
        case .starsHeader, .stars, .starsMore, .starsInfo:
            return CreateGiveawaySection.stars.rawValue
        case .subscriptionsHeader, .subscriptions, .subscriptionsInfo:
            return CreateGiveawaySection.subscriptions.rawValue
        case .channelsHeader, .channel, .channelAdd, .channelsInfo:
            return CreateGiveawaySection.channels.rawValue
        case .usersHeader, .usersAll, .usersNew, .usersInfo:
            return CreateGiveawaySection.users.rawValue
        case .durationHeader, .duration, .durationInfo:
            return CreateGiveawaySection.duration.rawValue
        case .prizeDescription, .prizeDescriptionText, .prizeDescriptionInfo:
            return CreateGiveawaySection.prizeDescription.rawValue
        case .timeHeader, .timeExpiryDate, .timeCustomPicker, .timeInfo:
            return CreateGiveawaySection.time.rawValue
        case .winners, .winnersInfo:
            return CreateGiveawaySection.winners.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
        case .header:
            return -2
        case .modeHeader:
            return -1
        case .giftPremium:
            return 0
        case .giftStars:
            return 1
        case .prepaidHeader:
            return 2
        case .prepaid:
            return 3
        case .starsHeader:
            return 4
        case let .stars(_, _, stars, _, _, _, _, _):
            return 5 + stars
        case .starsMore:
            return 100000
        case .starsInfo:
            return 100001
        case .subscriptionsHeader:
            return 100002
        case .subscriptions:
            return 100003
        case .subscriptionsInfo:
            return 100004
        case .channelsHeader:
            return 100005
        case let .channel(index, _, _, _, _):
            return 100006 + index
        case .channelAdd:
            return 100200
        case .channelsInfo:
            return 100201
        case .usersHeader:
            return 100202
        case .usersAll:
            return 100203
        case .usersNew:
            return 100204
        case .usersInfo:
            return 100205
        case .durationHeader:
            return 100206
        case let .duration(index, _, _, _, _, _, _, _):
            return 100207 + index
        case .durationInfo:
            return 100300
        case .prizeDescription:
            return 100301
        case .prizeDescriptionText:
            return 100302
        case .prizeDescriptionInfo:
            return 100303
        case .timeHeader:
            return 100304
        case .timeExpiryDate:
            return 100305
        case .timeCustomPicker:
            return 100306
        case .timeInfo:
            return 100307
        case .winners:
            return 100308
        case .winnersInfo:
            return 100309
        }
    }
    
    static func ==(lhs: CreateGiveawayEntry, rhs: CreateGiveawayEntry) -> Bool {
        switch lhs {
        case let .header(lhsTheme, lhsTitle, lhsText):
            if case let .header(rhsTheme, rhsTitle, rhsText) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsText == rhsText {
                return true
            } else {
                return false
            }
        case let .modeHeader(lhsTheme, lhsText):
            if case let .modeHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                return true
            } else {
                return false
            }
        case let .giftPremium(lhsTheme, lhsText, lhsSubtext, lhsSelected):
            if case let .giftPremium(rhsTheme, rhsText, rhsSubtext, rhsSelected) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsSubtext == rhsSubtext, lhsSelected == rhsSelected {
                return true
            } else {
                return false
            }
        case let .giftStars(lhsTheme, lhsText, lhsSubtext, lhsSelected):
            if case let .giftStars(rhsTheme, rhsText, rhsSubtext, rhsSelected) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsSubtext == rhsSubtext, lhsSelected == rhsSelected {
                return true
            } else {
                return false
            }
        case let .prepaidHeader(lhsTheme, lhsText):
            if case let .prepaidHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                return true
            } else {
                return false
            }
        case let .prepaid(lhsTheme, lhsText, lhsSubtext, lhsPrepaidGiveaway):
            if case let .prepaid(rhsTheme, rhsText, rhsSubtext, rhsPrepaidGiveaway) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsSubtext == rhsSubtext, lhsPrepaidGiveaway == rhsPrepaidGiveaway {
                return true
            } else {
                return false
            }
        case let .starsHeader(lhsTheme, lhsText, lhsAdditionalText):
            if case let .starsHeader(rhsTheme, rhsText, rhsAdditionalText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsAdditionalText == rhsAdditionalText {
                return true
            } else {
                return false
            }
        case let .stars(lhsIndex, lhsTheme, lhsStars, lhsTitle, lhsSubtitle, lhsLabel, lhsIsSelected, lhsMaxWinners):
            if case let .stars(rhsIndex, rhsTheme, rhsStars, rhsTitle, rhsSubtitle, rhsLabel, rhsIsSelected, rhsMaxWinners) = rhs, lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsStars == rhsStars, lhsTitle == rhsTitle, lhsSubtitle == rhsSubtitle, lhsLabel == rhsLabel, lhsIsSelected == rhsIsSelected, lhsMaxWinners == rhsMaxWinners {
                return true
            } else {
                return false
            }
        case let .starsMore(lhsTheme, lhsText):
            if case let .starsMore(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                return true
            } else {
                return false
            }
        case let .starsInfo(lhsTheme, lhsText):
            if case let .starsInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                return true
            } else {
                return false
            }
        case let .subscriptionsHeader(lhsTheme, lhsText, lhsAdditionalText):
            if case let .subscriptionsHeader(rhsTheme, rhsText, rhsAdditionalText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsAdditionalText == rhsAdditionalText {
                return true
            } else {
                return false
            }
        case let .subscriptions(lhsTheme, lhsValue, lhsValues):
            if case let .subscriptions(rhsTheme, rhsValue, rhsValues) = rhs, lhsTheme === rhsTheme, lhsValue == rhsValue, lhsValues == rhsValues {
                return true
            } else {
                return false
            }
        case let .subscriptionsInfo(lhsTheme, lhsText):
            if case let .subscriptionsInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                return true
            } else {
                return false
            }
        case let .channelsHeader(lhsTheme, lhsText):
            if case let .channelsHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                return true
            } else {
                return false
            }
        case let .channel(lhsIndex, lhsTheme, lhsPeer, lhsBoosts, lhsIsRevealed):
            if case let .channel(rhsIndex, rhsTheme, rhsPeer, rhsBoosts, rhsIsRevealed) = rhs, lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsPeer == rhsPeer, lhsBoosts == rhsBoosts, lhsIsRevealed == rhsIsRevealed {
                return true
            } else {
                return false
            }
        case let .channelAdd(lhsTheme, lhsText):
            if case let .channelAdd(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                return true
            } else {
                return false
            }
        case let .channelsInfo(lhsTheme, lhsText):
            if case let .channelsInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                return true
            } else {
                return false
            }
        case let .usersHeader(lhsTheme, lhsText):
            if case let .usersHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                return true
            } else {
                return false
            }
        case let .usersAll(lhsTheme, lhsText, lhsSubtitle, lhsSelected):
            if case let .usersAll(rhsTheme, rhsText, rhsSubtitle, rhsSelected) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsSubtitle == rhsSubtitle, lhsSelected == rhsSelected {
                return true
            } else {
                return false
            }
        case let .usersNew(lhsTheme, lhsText, lhsSubtitle, lhsSelected):
            if case let .usersNew(rhsTheme, rhsText, rhsSubtitle, rhsSelected) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsSubtitle == rhsSubtitle, lhsSelected == rhsSelected {
                return true
            } else {
                return false
            }
        case let .usersInfo(lhsTheme, lhsText):
            if case let .usersInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                return true
            } else {
                return false
            }
        case let .durationHeader(lhsTheme, lhsText):
            if case let .durationHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                return true
            } else {
                return false
            }
        case let .duration(lhsIndex, lhsTheme, lhsMonths, lhsTitle, lhsSubtitle, lhsLabel, lhsBadge, lhsIsSelected):
            if case let .duration(rhsIndex, rhsTheme, rhsMonths, rhsTitle, rhsSubtitle, rhsLabel, rhsBadge, rhsIsSelected) = rhs, lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsMonths == rhsMonths, lhsTitle == rhsTitle, lhsSubtitle == rhsSubtitle, lhsLabel == rhsLabel, lhsBadge == rhsBadge, lhsIsSelected == rhsIsSelected {
                return true
            } else {
                return false
            }
        case let .durationInfo(lhsTheme, lhsText):
            if case let .durationInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                return true
            } else {
                return false
            }
        case let .prizeDescription(lhsTheme, lhsText, lhsValue):
            if case let .prizeDescription(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                return true
            } else {
                return false
            }
        case let .prizeDescriptionText(lhsTheme, lhsPlaceholder, lhsValue, lhsCount):
            if case let .prizeDescriptionText(rhsTheme, rhsPlaceholder, rhsValue, rhsCount) = rhs, lhsTheme === rhsTheme, lhsPlaceholder == rhsPlaceholder, lhsValue == rhsValue, lhsCount == rhsCount {
                return true
            } else {
                return false
            }
        case let .prizeDescriptionInfo(lhsTheme, lhsText):
            if case let .prizeDescriptionInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                return true
            } else {
                return false
            }
        case let .timeHeader(lhsTheme, lhsText):
            if case let .timeHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                return true
            } else {
                return false
            }
        case let .timeExpiryDate(lhsTheme, lhsDateTimeFormat, lhsDate, lhsActive):
            if case let .timeExpiryDate(rhsTheme, rhsDateTimeFormat, rhsDate, rhsActive) = rhs, lhsTheme === rhsTheme, lhsDateTimeFormat == rhsDateTimeFormat, lhsDate == rhsDate, lhsActive == rhsActive {
                return true
            } else {
                return false
            }
        case let .timeCustomPicker(lhsTheme, lhsDateTimeFormat, lhsDate, lhsMinDate, lhsMaxDate, lhsDisplayingDateSelection, lhsDisplayingTimeSelection):
            if case let .timeCustomPicker(rhsTheme, rhsDateTimeFormat, rhsDate, rhsMinDate, rhsMaxDate, rhsDisplayingDateSelection, rhsDisplayingTimeSelection) = rhs, lhsTheme === rhsTheme, lhsDateTimeFormat == rhsDateTimeFormat, lhsDate == rhsDate, lhsMinDate == rhsMinDate, lhsMaxDate == rhsMaxDate, lhsDisplayingDateSelection == rhsDisplayingDateSelection, lhsDisplayingTimeSelection == rhsDisplayingTimeSelection {
                return true
            } else {
                return false
            }
        case let .timeInfo(lhsTheme, lhsText):
            if case let .timeInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                return true
            } else {
                return false
            }
        case let .winners(lhsTheme, lhsText, lhsValue):
            if case let .winners(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                return true
            } else {
                return false
            }
        case let .winnersInfo(lhsTheme, lhsText):
            if case let .winnersInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                return true
            } else {
                return false
            }
        }
    }
    
    static func <(lhs: CreateGiveawayEntry, rhs: CreateGiveawayEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! CreateGiveawayControllerArguments
        switch self {
        case let .header(_, title, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(title + text), sectionId: self.section)
        case let .modeHeader(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .giftPremium(_, title, subtitle, isSelected):
            return GiftOptionItem(presentationData: presentationData, context: arguments.context, icon: .image(color: .premium, name: "Peer Info/PremiumIcon"), title: title, subtitle: subtitle, subtitleActive: true, isSelected: isSelected, sectionId: self.section, action: {
                var openSelection = false
                arguments.updateState { state in
                    var updatedState = state
                    if (state.mode == .giveaway && state.peers.isEmpty) {
                        openSelection = true
                    }
                    updatedState.mode = .giveaway
                    return updatedState
                }
                if openSelection {
                    arguments.openPeersSelection()
                }
            })
        case let .giftStars(_, title, subtitle, isSelected):
            return GiftOptionItem(presentationData: presentationData, context: arguments.context, icon: .image(color: .stars, name: "Peer Info/PremiumIcon"), title: title, subtitle: subtitle, subtitleActive: false, isSelected: isSelected, sectionId: self.section, action: {
                arguments.updateState { state in
                    var updatedState = state
                    updatedState.mode = .starsGiveaway
                    return updatedState
                }
            })
        case let .prepaidHeader(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .prepaid(_, title, subtitle, prepaidGiveaway):
            let color: GiftOptionItem.Icon.Color
            let icon: String
            let boosts: Int32
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
            return GiftOptionItem(presentationData: presentationData, context: arguments.context, icon: .image(color: color, name: icon), title: title, titleFont: .bold, titleBadge: "\(boosts)", subtitle: subtitle, sectionId: self.section, action: nil)
        case let .starsHeader(_, text, additionalText):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, accessoryText: ItemListSectionHeaderAccessoryText(value: additionalText, color: .generic), sectionId: self.section)
        case let .stars(_, _, stars, title, subtitle, label, isSelected, maxWinners):
            return GiftOptionItem(presentationData: presentationData, context: arguments.context, title: title, subtitle: subtitle, subtitleFont: .small, label: .generic(label), badge: nil, isSelected: isSelected, stars: Int64(stars), sectionId: self.section, action: {
                arguments.updateState { state in
                    var updatedState = state
                    updatedState.stars = Int64(stars)
                    updatedState.winners = min(updatedState.winners, maxWinners)
                    return updatedState
                }
            })
        case let .starsMore(theme, title):
            return ItemListPeerActionItem(presentationData: presentationData, icon: PresentationResourcesItemList.downArrowImage(theme), title: title, sectionId: self.section, editing: false, action: {
                arguments.expandStars()
            })
        case let .starsInfo(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .subscriptionsHeader(_, text, additionalText):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, accessoryText: ItemListSectionHeaderAccessoryText(value: additionalText, color: .generic), sectionId: self.section)
        case let .subscriptions(_, value, values):
            return SubscriptionsCountItem(theme: presentationData.theme, strings: presentationData.strings, value: value, values: values, sectionId: self.section, updated: { value in
                arguments.updateState { state in
                    var updatedState = state
                    if state.mode == .giveaway {
                        updatedState.subscriptions = value
                    } else if state.mode == .starsGiveaway {
                        updatedState.winners = value
                    }
                    return updatedState
                }
            })
        case let .subscriptionsInfo(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .channelsHeader(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .channel(_, _, peer, boosts, isRevealed):
            var isGroup = false
            if case let .channel(channel) = peer, case .group = channel.info {
                isGroup = true
            }
            return ItemListPeerItem(presentationData: presentationData, dateTimeFormat: PresentationDateTimeFormat(), nameDisplayOrder: presentationData.nameDisplayOrder, context: arguments.context, peer: peer, presence: nil, text: boosts.flatMap { .text(isGroup ? presentationData.strings.BoostGift_GroupBoosts($0) : presentationData.strings.BoostGift_ChannelsBoosts($0), .secondary) } ?? .none, label: .none, editing: ItemListPeerItemEditing(editable: boosts == nil, editing: false, revealed: isRevealed), switchValue: nil, enabled: true, selectable: peer.id != arguments.context.account.peerId, sectionId: self.section, action: {
            }, setPeerIdWithRevealedOptions: { lhs, rhs in
                arguments.setItemIdWithRevealedOptions(lhs, rhs)
            }, removePeer: { id in
                arguments.removeChannel(id)
            })
        case let .channelAdd(theme, text):
            return ItemListPeerActionItem(presentationData: presentationData, icon: PresentationResourcesItemList.roundPlusIconImage(theme), title: text, alwaysPlain: false, hasSeparator: true, sectionId: self.section, height: .compactPeerList, color: .accent, editing: false, action: {
                arguments.openChannelsSelection()
            })
        case let .channelsInfo(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .usersHeader(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .usersAll(_, title, subtitle, isSelected):
            return GiftOptionItem(presentationData: presentationData, context: arguments.context, title: title, subtitle: subtitle, subtitleActive: true, isSelected: isSelected, sectionId: self.section, action: {
                var openSelection = false
                arguments.updateState { state in
                    var updatedState = state
                    if !updatedState.onlyNewEligible {
                        openSelection = true
                    }
                    updatedState.onlyNewEligible = false
                    return updatedState
                }
                if openSelection {
                    arguments.openCountriesSelection()
                }
            })
        case let .usersNew(_, title, subtitle, isSelected):
            return GiftOptionItem(presentationData: presentationData, context: arguments.context, title: title, subtitle: subtitle, subtitleActive: true, isSelected: isSelected, sectionId: self.section, action: {
                var openSelection = false
                arguments.updateState { state in
                    var updatedState = state
                    if updatedState.onlyNewEligible {
                        openSelection = true
                    }
                    updatedState.onlyNewEligible = true
                    return updatedState
                }
                if openSelection {
                    arguments.openCountriesSelection()
                }
            })
        case let .usersInfo(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .durationHeader(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .duration(_, _, months, title, subtitle, label, badge, isSelected):
            return GiftOptionItem(presentationData: presentationData, context: arguments.context, title: title, subtitle: subtitle, subtitleFont: .small, label: .generic(label), badge: badge, isSelected: isSelected, sectionId: self.section, action: {
                arguments.updateState { state in
                    var updatedState = state
                    updatedState.selectedMonths = months
                    return updatedState
                }
            })
        case let .durationInfo(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .markdown(text), sectionId: self.section, linkAction: { _ in
                arguments.openPremiumIntro()
            })
        case let .prizeDescription(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateState { state in
                    var updatedState = state
                    updatedState.showPrizeDescription = value
                    return updatedState
                }
            })
        case let .prizeDescriptionText(_, placeholder, value, count):
            return ItemListSingleLineInputItem(presentationData: presentationData, title: NSAttributedString(string: "\(count)"), text: value, placeholder: placeholder, returnKeyType: .done, spacing: 24.0, maxLength: 128, tag: CreateGiveawayEntryTag.description, sectionId: self.section, textUpdated: { value in
                arguments.updateState { state in
                    var updatedState = state
                    updatedState.prizeDescription = value
                    return updatedState
                }
            }, updatedFocus: { focused in
                if focused {
                    Queue.mainQueue().after(0.05) {
                        arguments.scrollToDescription()
                    }
                }
            }, action: {
                arguments.dismissInput()
            })
        case let .prizeDescriptionInfo(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .markdown(text), sectionId: self.section)
        case let .timeHeader(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .timeExpiryDate(theme, dateTimeFormat, value, active):
            let text: String
            if let value = value {
                text = stringForMediumDate(timestamp: value, strings: presentationData.strings, dateTimeFormat: dateTimeFormat)
            } else {
                text = presentationData.strings.InviteLink_Create_TimeLimitExpiryDateNever
            }
            return ItemListDisclosureItem(presentationData: presentationData, title: presentationData.strings.BoostGift_DateEnds, label: text, labelStyle: active ? .coloredText(theme.list.itemAccentColor) : .text, sectionId: self.section, style: .blocks, disclosureStyle: .none, action: {
                arguments.dismissInput()
                var focus = false
                arguments.updateState { state in
                    var updatedState = state
                    updatedState.pickingExpiryTime = !state.pickingExpiryTime
                    if updatedState.pickingExpiryTime {
                        focus = true
                    }
                    return updatedState
                }
                if focus {
                    Queue.mainQueue().after(0.1) {
                        arguments.scrollToDate()
                    }
                }
            })
        case let .timeCustomPicker(_, dateTimeFormat, date, minDate, maxDate, displayingDateSelection, displayingTimeSelection):
            let title = presentationData.strings.BoostGift_DateEnds
            return ItemListDatePickerItem(presentationData: presentationData, dateTimeFormat: dateTimeFormat, date: date, minDate: minDate, maxDate: maxDate, title: title, displayingDateSelection: displayingDateSelection, displayingTimeSelection: displayingTimeSelection, sectionId: self.section, style: .blocks, toggleDateSelection: {
                var focus = false
                arguments.updateState({ state in
                    var updatedState = state
                    updatedState.pickingExpiryDate = !updatedState.pickingExpiryDate
                    if updatedState.pickingExpiryDate {
                        updatedState.pickingExpiryTime = false
                        focus = true
                    }
                    return updatedState
                })
                if focus {
                    Queue.mainQueue().after(0.1) {
                        arguments.scrollToDate()
                    }
                }
            }, toggleTimeSelection: {
                var focus = false
                arguments.updateState({ state in
                    var updatedState = state
                    updatedState.pickingExpiryTime = !updatedState.pickingExpiryTime
                    if updatedState.pickingExpiryTime {
                        updatedState.pickingExpiryDate = false
                        focus = true
                    }
                    return updatedState
                })
                if focus {
                    Queue.mainQueue().after(0.1) {
                        arguments.scrollToDate()
                    }
                }
            }, updated: { date in
                arguments.updateState({ state in
                    var updatedState = state
                    updatedState.time = date
                    return updatedState
                })
            }, tag: CreateGiveawayEntryTag.date)
        case let .timeInfo(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .winners(_, text, value):
            return ItemListSwitchItem(presentationData: presentationData, title: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.updateState { state in
                    var updatedState = state
                    updatedState.showWinners = value
                    return updatedState
                }
            })
        case let .winnersInfo(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private struct PremiumGiftProduct: Equatable {
    let giftOption: PremiumGiftCodeOption
    let storeProduct: InAppPurchaseManager.Product
    
    var id: String {
        return self.storeProduct.id
    }
    
    var months: Int32 {
        return self.giftOption.months
    }
    
    var price: String {
        return self.storeProduct.price
    }
    
    var pricePerMonth: String {
        return self.storeProduct.pricePerMonth(Int(self.months))
    }
}

private struct StarsGiveawayProduct: Equatable {
    let giveawayOption: StarsGiveawayOption
    let storeProduct: InAppPurchaseManager.Product
    
    var id: String {
        return self.storeProduct.id
    }
        
    var price: String {
        return self.storeProduct.price
    }
}

private func createGiveawayControllerEntries(
    peerId: EnginePeer.Id,
    subject: CreateGiveawaySubject,
    state: CreateGiveawayControllerState,
    presentationData: PresentationData,
    locale: Locale,
    peers: [EnginePeer.Id: EnginePeer],
    products: [PremiumGiftProduct],
    defaultPrice: (Int64, NSDecimalNumber),
    starsGiveawayOptions: [StarsGiveawayProduct],
    minDate: Int32,
    maxDate: Int32
) -> [CreateGiveawayEntry] {
    var isGroup = false
    if let peer = peers[peerId], case let .channel(channel) = peer, case .group = channel.info {
        isGroup = true
    }
        
    var entries: [CreateGiveawayEntry] = []
        
    switch subject {
    case .generic:
        let recipientsText: String
        if !state.peers.isEmpty && state.mode == .gift {
            var peerNamesArray: [String] = []
            let peersCount = state.peers.count
            for peerId in state.peers.prefix(2) {
                if let peer = peers[peerId] {
                    peerNamesArray.append(peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder))
                }
            }
            let peerNames = String(peerNamesArray.map { $0 }.joined(separator: ", "))
            if !peerNames.isEmpty {
                recipientsText = peerNames
            } else {
                recipientsText = presentationData.strings.PremiumGift_LabelRecipients(Int32(peersCount))
            }
        } else {
            recipientsText = presentationData.strings.BoostGift_CreateGiveawayInfo //presentationData.strings.BoostGift_SelectRecipients
        }
        
        entries.append(.modeHeader(presentationData.theme, presentationData.strings.BoostGift_Prize.uppercased()))
        entries.append(.giftPremium(presentationData.theme, presentationData.strings.BoostGift_Prize_Premium, recipientsText, state.mode == .giveaway || state.mode == .gift))
        
        entries.append(.giftStars(presentationData.theme, presentationData.strings.BoostGift_Prize_Stars, presentationData.strings.BoostGift_CreateGiveawayInfo, state.mode == .starsGiveaway))
    case let .prepaid(prepaidGiveaway):
        entries.append(.prepaidHeader(presentationData.theme, presentationData.strings.BoostGift_PrepaidGiveawayTitle))
        let title: String
        let text: String
        switch prepaidGiveaway.prize {
        case let .premium(months):
            title = presentationData.strings.BoostGift_PrepaidGiveawayCount(prepaidGiveaway.quantity)
            text = presentationData.strings.BoostGift_PrepaidGiveawayMonths("\(months)").string
        case let .stars(stars, _):
            title = presentationData.strings.BoostGift_PrepaidGiveaway_StarsCount(Int32(stars))
            text = presentationData.strings.BoostGift_PrepaidGiveaway_StarsWinners(prepaidGiveaway.quantity)
        }
        entries.append(.prepaid(presentationData.theme, title, text, prepaidGiveaway))
    }
    
    var starsPerUser: Int64 = 0
    if case .generic = subject, case .starsGiveaway = state.mode, !starsGiveawayOptions.isEmpty {
        let selectedOption = starsGiveawayOptions.first(where: { $0.giveawayOption.count == state.stars })!
        entries.append(.starsHeader(presentationData.theme, presentationData.strings.BoostGift_Stars_Title.uppercased(), presentationData.strings.BoostGift_Stars_Boosts(selectedOption.giveawayOption.yearlyBoosts).uppercased()))
        
        var i: Int32 = 0
        for product in starsGiveawayOptions {
            if !state.starsExpanded && product.giveawayOption.isExtended {
                continue
            }
            let giftTitle: String = presentationData.strings.BoostGift_Stars_Stars(Int32(product.giveawayOption.count))
            let winners = product.giveawayOption.winners.first(where: { $0.users == state.winners }) ?? product.giveawayOption.winners.first!
            
            let maxWinners = product.giveawayOption.winners.sorted(by: { $0.users < $1.users }).last?.users ?? 1
            
            let subtitle = presentationData.strings.BoostGift_Stars_PerUser("\(winners.starsPerUser)").string
            let label = product.storeProduct.price
            starsPerUser = winners.starsPerUser
            
            let isSelected = product.giveawayOption.count == state.stars
            entries.append(.stars(i, presentationData.theme, Int32(product.giveawayOption.count), giftTitle, subtitle, label, isSelected, maxWinners))
            
            i += 1
        }
        
        if !state.starsExpanded {
            entries.append(.starsMore(presentationData.theme, presentationData.strings.BoostGift_Stars_ShowMoreOptions))
        }
        
        entries.append(.starsInfo(presentationData.theme, presentationData.strings.BoostGift_Stars_Info))
    }
    
    let appendDurationEntries = {
        entries.append(.durationHeader(presentationData.theme, presentationData.strings.BoostGift_DurationTitle.uppercased()))
        
        let recipientCount: Int
        switch state.mode {
        case .giveaway:
            recipientCount = Int(state.subscriptions)
        case .gift:
            recipientCount = state.peers.count
        case .starsGiveaway:
            recipientCount = Int(state.subscriptions)
        }
        
        var i: Int32 = 0
        var existingMonths = Set<Int32>()
        for product in products {
            if existingMonths.contains(product.months) {
                continue
            }
            existingMonths.insert(product.months)
            let giftTitle: String
            if product.months == 12 {
                giftTitle = presentationData.strings.Premium_Gift_Years(1)
            } else {
                giftTitle = presentationData.strings.Premium_Gift_Months(product.months)
            }
            
            let discountValue = Int((1.0 - Float(product.storeProduct.priceCurrencyAndAmount.amount) / Float(product.months) / Float(defaultPrice.0)) * 100.0)
            let discount: String?
            if discountValue > 0 {
                discount = "-\(discountValue)%"
            } else {
                discount = nil
            }
            
            let subtitle = "\(product.storeProduct.price) x \(recipientCount)"
            let label = product.storeProduct.multipliedPrice(count: recipientCount)
            
            let selectedMonths = state.selectedMonths ?? 12
            let isSelected = product.months == selectedMonths
            
            entries.append(.duration(i, presentationData.theme, product.months, giftTitle, subtitle, label, discount, isSelected))
            
            i += 1
        }
        
        entries.append(.durationInfo(presentationData.theme, presentationData.strings.BoostGift_PremiumInfo))
    }
    
    switch state.mode {
    case .giveaway, .starsGiveaway:
        if case .starsGiveaway = state.mode {
            if case .prepaid = subject {
            } else {
                var values: [Int32] = [1]
                if let selectedOption = starsGiveawayOptions.first(where: { $0.giveawayOption.count == state.stars }) {
                    values = selectedOption.giveawayOption.winners.map { $0.users }
                }
                if values.count > 1 {
                    entries.append(.subscriptionsHeader(presentationData.theme, presentationData.strings.BoostGift_Stars_Winners, ""))
                    entries.append(.subscriptions(presentationData.theme, state.winners, values))
                    entries.append(.subscriptionsInfo(presentationData.theme, presentationData.strings.BoostGift_Stars_WinnersInfo))
                }
            }
        } else {
            if case .generic = subject {
                entries.append(.subscriptionsHeader(presentationData.theme, presentationData.strings.BoostGift_QuantityTitle.uppercased(), presentationData.strings.BoostGift_QuantityBoosts(state.subscriptions * 4)))
                entries.append(.subscriptions(presentationData.theme, state.subscriptions, [1, 3, 5, 7, 10, 25, 50]))
                entries.append(.subscriptionsInfo(presentationData.theme, presentationData.strings.BoostGift_QuantityInfo))
            }
        }
        
        entries.append(.channelsHeader(presentationData.theme, isGroup ? presentationData.strings.BoostGift_GroupsAndChannelsTitle.uppercased() : presentationData.strings.BoostGift_ChannelsAndGroupsTitle.uppercased()))
        var index: Int32 = 0
        let channels = [peerId] + state.channels
        for channelId in channels {
            if let channel = peers[channelId] {
                entries.append(.channel(index, presentationData.theme, channel, channel.id == peerId ? state.subscriptions * 4 : nil, false))
            }
            index += 1
        }
        entries.append(.channelAdd(presentationData.theme, isGroup ? presentationData.strings.BoostGift_AddGroupOrChannel : presentationData.strings.BoostGift_AddChannelOrGroup))
        entries.append(.channelsInfo(presentationData.theme, isGroup ? presentationData.strings.BoostGift_GroupsAndChannelsInfo : presentationData.strings.BoostGift_ChannelsAndGroupsInfo))
        
        entries.append(.usersHeader(presentationData.theme, presentationData.strings.BoostGift_UsersTitle.uppercased()))
        
        let countriesText: String
        if state.countries.count > 2 {
            countriesText = presentationData.strings.BoostGift_FromCountries(Int32(state.countries.count))
        } else if !state.countries.isEmpty {
            if state.countries.count == 2 {
                let firstCountryCode = state.countries.first ?? ""
                let secondCountryCode = state.countries.last ?? ""
                let firstCountryName = locale.localizedString(forRegionCode: firstCountryCode) ?? firstCountryCode
                let secondCountryName = locale.localizedString(forRegionCode: secondCountryCode) ?? secondCountryCode
                countriesText = presentationData.strings.BoostGift_FromTwoCountries(firstCountryName, secondCountryName).string
            } else {
                let countryCode = state.countries.first ?? ""
                let countryName = locale.localizedString(forRegionCode: countryCode) ?? countryCode
                countriesText = presentationData.strings.BoostGift_FromOneCountry(countryName).string
            }
        } else {
            countriesText = presentationData.strings.BoostGift_FromAllCountries
        }
        
        entries.append(.usersAll(presentationData.theme, isGroup ? presentationData.strings.BoostGift_Group_AllMembers : presentationData.strings.BoostGift_AllSubscribers, countriesText, !state.onlyNewEligible))
        entries.append(.usersNew(presentationData.theme, isGroup ? presentationData.strings.BoostGift_Group_OnlyNewMembers : presentationData.strings.BoostGift_OnlyNewSubscribers, countriesText, state.onlyNewEligible))
        entries.append(.usersInfo(presentationData.theme, isGroup ? presentationData.strings.BoostGift_Group_LimitMembersInfo : presentationData.strings.BoostGift_LimitSubscribersInfo))
        
        if case .starsGiveaway = state.mode  {

        } else {
            if case .generic = subject {
                appendDurationEntries()
            }
        }
        
        entries.append(.prizeDescription(presentationData.theme, presentationData.strings.BoostGift_AdditionalPrizes, state.showPrizeDescription))
        var prizeDescriptionInfoText = state.mode == .starsGiveaway ? presentationData.strings.BoostGift_AdditionalPrizesInfoStarsOff : presentationData.strings.BoostGift_AdditionalPrizesInfoOff
        if state.showPrizeDescription {
            entries.append(.prizeDescriptionText(presentationData.theme, presentationData.strings.BoostGift_AdditionalPrizesPlaceholder, state.prizeDescription, state.subscriptions))
           
            if state.mode == .starsGiveaway {
                let starsString = presentationData.strings.BoostGift_AdditionalPrizesInfoStars(Int32(state.stars))
                if state.prizeDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let _ = starsPerUser
                    prizeDescriptionInfoText = presentationData.strings.BoostGift_AdditionalPrizesInfoStarsOn(starsString, "").string
                } else {
                    prizeDescriptionInfoText = presentationData.strings.BoostGift_AdditionalPrizesInfoStarsOn(starsString, presentationData.strings.BoostGift_AdditionalPrizesInfoStarsAndOther("\(state.winners)", state.prizeDescription).string).string
                }
            } else {
                let monthsString = presentationData.strings.BoostGift_AdditionalPrizesInfoForMonths(state.selectedMonths ?? 12)
                if state.prizeDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let subscriptionsString = presentationData.strings.BoostGift_AdditionalPrizesInfoSubscriptions(state.subscriptions).replacingOccurrences(of: "\(state.subscriptions) ", with: "")
                    prizeDescriptionInfoText = presentationData.strings.BoostGift_AdditionalPrizesInfoOn("\(state.subscriptions)", subscriptionsString, monthsString).string
                } else {
                    let subscriptionsString = presentationData.strings.BoostGift_AdditionalPrizesInfoWithSubscriptions(state.subscriptions).replacingOccurrences(of: "\(state.subscriptions) ", with: "")
                    let description = "\(state.prizeDescription) \(subscriptionsString)"
                    prizeDescriptionInfoText = presentationData.strings.BoostGift_AdditionalPrizesInfoOn("\(state.subscriptions)", description, monthsString).string
                }
            }
        }
        entries.append(.prizeDescriptionInfo(presentationData.theme, prizeDescriptionInfoText))
                
        entries.append(.timeHeader(presentationData.theme, presentationData.strings.BoostGift_DateTitle.uppercased()))
        entries.append(.timeCustomPicker(presentationData.theme, presentationData.dateTimeFormat, state.time, minDate, maxDate, state.pickingExpiryDate, state.pickingExpiryTime))
        
        let timeInfoText: String
        if isGroup {
            if case .starsGiveaway = state.mode {
                timeInfoText = presentationData.strings.BoostGift_Group_StarsDateInfo(presentationData.strings.BoostGift_Group_DateInfoMembers(Int32(state.winners))).string
            } else {
                timeInfoText = presentationData.strings.BoostGift_Group_DateInfo(presentationData.strings.BoostGift_Group_DateInfoMembers(Int32(state.subscriptions))).string
            }
        } else {
            if case .starsGiveaway = state.mode {
                timeInfoText = presentationData.strings.BoostGift_StarsDateInfo(presentationData.strings.BoostGift_DateInfoSubscribers(Int32(state.winners))).string
            } else {
                timeInfoText = presentationData.strings.BoostGift_DateInfo(presentationData.strings.BoostGift_DateInfoSubscribers(Int32(state.subscriptions))).string
            }
        }
        entries.append(.timeInfo(presentationData.theme, timeInfoText))
        
        entries.append(.winners(presentationData.theme, presentationData.strings.BoostGift_Winners, state.showWinners))
        entries.append(.winnersInfo(presentationData.theme, presentationData.strings.BoostGift_WinnersInfo))
    case .gift:
        appendDurationEntries()
    }
    
    return entries
}

private struct CreateGiveawayControllerState: Equatable {
    enum Mode {
        case giveaway
        case gift
        case starsGiveaway
    }
    
    var mode: Mode
    var subscriptions: Int32
    var stars: Int64
    var winners: Int32
    var channels: [EnginePeer.Id] = []
    var peers: [EnginePeer.Id] = []
    var selectedMonths: Int32?
    var countries: [String] = []
    var onlyNewEligible: Bool = false
    var showWinners: Bool = true
    var showPrizeDescription: Bool = false
    var prizeDescription: String = ""
    var time: Int32
    var pickingExpiryTime = false
    var pickingExpiryDate = false
    var revealedItemId: EnginePeer.Id? = nil
    var updating = false
    var starsExpanded = false
}

public enum CreateGiveawaySubject {
    case generic
    case prepaid(PrepaidGiveaway)
}

public func createGiveawayController(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, peerId: EnginePeer.Id, subject: CreateGiveawaySubject, completion: (() -> Void)? = nil) -> ViewController {
    let actionsDisposable = DisposableSet()
    
    let initialSubscriptions: Int32
    let initialStars: Int64
    let initialWinners: Int32
    var initialMode: CreateGiveawayControllerState.Mode = .giveaway
    if case let .prepaid(prepaidGiveaway) = subject {
        if case let .stars(stars, _) = prepaidGiveaway.prize {
            initialStars = stars
            initialMode = .starsGiveaway
        } else {
            initialStars = 500
        }
        initialSubscriptions = prepaidGiveaway.quantity
        initialWinners = prepaidGiveaway.quantity
    } else {
        initialSubscriptions = 5
        initialStars = 500
        initialWinners = 5
    }
    let currentTime = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
    
    let timeZone = TimeZone(secondsFromGMT: 0)!
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    let currentDate = Date()
    var components = calendar.dateComponents(Set([.era, .year, .month, .day, .hour, .minute, .second]), from: currentDate)
    components.hour = (components.hour ?? 0) + 1
    components.minute = 0
    components.second = 0
    let expiryDate = calendar.date(byAdding: .day, value: 3, to: calendar.date(from: components)!)!
    let expiryTime = Int32(expiryDate.timeIntervalSince1970)
    
    let minDate = currentTime + 60 * 1
    let maxDate = currentTime + context.userLimits.maxGiveawayPeriodSeconds
    
    let initialState: CreateGiveawayControllerState = CreateGiveawayControllerState(mode: initialMode, subscriptions: initialSubscriptions, stars: initialStars, winners: initialWinners, time: expiryTime)

    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((CreateGiveawayControllerState) -> CreateGiveawayControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    let isGroupValue = Atomic<Bool>(value: false)
    
    let productsValue = Atomic<[PremiumGiftProduct]?>(value: nil)
    let starsValue = Atomic<[StarsGiveawayProduct]?>(value: nil)

    var buyActionImpl: (() -> Void)?
    var openPeersSelectionImpl: (() -> Void)?
    var openChannelsSelectionImpl: (() -> Void)?
    var openCountriesSelectionImpl: (() -> Void)?
    var openPremiumIntroImpl: (() -> Void)?
    var presentControllerImpl: ((ViewController) -> Void)?
    var pushControllerImpl: ((ViewController) -> Void)?
    var scrollToDescriptionImpl: (() -> Void)?
    var scrollToDateImpl: (() -> Void)?
    var dismissImpl: (() -> Void)?
    var dismissInputImpl: (() -> Void)?
    
    let arguments = CreateGiveawayControllerArguments(context: context, updateState: { f in
        updateState(f)
    }, dismissInput: {
       dismissInputImpl?()
    }, openPeersSelection: {
        openPeersSelectionImpl?()
    }, openChannelsSelection: {
        openChannelsSelectionImpl?()
    }, openCountriesSelection: {
        openCountriesSelectionImpl?()
    }, openPremiumIntro: {
        openPremiumIntroImpl?()
    }, scrollToDate: {
        scrollToDateImpl?()
    }, scrollToDescription: {
        scrollToDescriptionImpl?()
    }, setItemIdWithRevealedOptions: { itemId, fromItemId in
        updateState { state in
            var updatedState = state
            if (itemId == nil && fromItemId == state.revealedItemId) || (itemId != nil && fromItemId == nil) {
                updatedState.revealedItemId = itemId
            }
            return updatedState
        }
    },
    removeChannel: { id in
        updateState { state in
            var updatedState = state
            updatedState.channels = updatedState.channels.filter { $0 != id }
            return updatedState
        }
    },
    expandStars: {
        updateState { state in
            var updatedState = state
            updatedState.starsExpanded = true
            return updatedState
        }
    })
    
    let presentationData = updatedPresentationData?.signal ?? context.sharedContext.presentationData
    
    let locale = localeWithStrings(context.sharedContext.currentPresentationData.with { $0 }.strings)
    
    let productsAndDefaultPrice: Signal<([PremiumGiftProduct], (Int64, NSDecimalNumber)), NoError> = combineLatest(
        .single([]) |> then(context.engine.payments.premiumGiftCodeOptions(peerId: peerId)),
        context.inAppPurchaseManager?.availableProducts ?? .single([])
    )
    |> map { options, products in
        var gifts: [PremiumGiftProduct] = []
        for option in options {
            if let product = products.first(where: { $0.id == option.storeProductId }), !product.isSubscription {
                gifts.append(PremiumGiftProduct(giftOption: option, storeProduct: product))
            }
        }
        let defaultPrice: (Int64, NSDecimalNumber)
        if let defaultProduct = products.first(where: { $0.id == "org.telegram.telegramPremium.monthly" }) {
            defaultPrice = (defaultProduct.priceCurrencyAndAmount.amount, defaultProduct.priceValue)
        } else {
            defaultPrice = (1, NSDecimalNumber(value: 1))
        }
        return (gifts, defaultPrice)
    }
    
    let starsGiveawayOptions: Signal<[StarsGiveawayProduct], NoError> = combineLatest(
        .single([]) |> then(context.engine.payments.starsGiveawayOptions()),
        context.inAppPurchaseManager?.availableProducts ?? .single([])
    )
    |> map { options, products in
        var result: [StarsGiveawayProduct] = []
        for option in options {
            if let product = products.first(where: { $0.id == option.storeProductId }), !product.isSubscription {
                result.append(StarsGiveawayProduct(giveawayOption: option, storeProduct: product))
            }
        }
        return result
    }
    
    let previousState = Atomic<CreateGiveawayControllerState?>(value: nil)
    let signal = combineLatest(
        presentationData,
        statePromise.get()
        |> mapToSignal { state in
            return context.engine.data.get(EngineDataMap(
                Set([peerId] + state.channels + state.peers).map {
                    TelegramEngine.EngineData.Item.Peer.Peer(id: $0)
                }
            ))
            |> map { peers in
                return (state, peers)
            }
        },
        productsAndDefaultPrice,
        starsGiveawayOptions
    )
    |> deliverOnMainQueue
    |> map { presentationData, stateAndPeersMap, productsAndDefaultPrice, starsGiveawayOptions -> (ItemListControllerState, (ItemListNodeState, Any)) in
        var presentationData = presentationData
        
        let (products, defaultPrice) = productsAndDefaultPrice
        
        let updatedTheme = presentationData.theme.withModalBlocksBackground()
        presentationData = presentationData.withUpdated(theme: updatedTheme)
        
        let (state, peersMap) = stateAndPeersMap
        
        var isGroup = false
        if let peer = peersMap[peerId], case let .channel(channel) = peer, case .group = channel.info {
            isGroup = true
        }
        let _ = isGroupValue.swap(isGroup)
                
        let headerText = isGroup ? presentationData.strings.BoostGift_NewDescriptionGroup : presentationData.strings.BoostGift_NewDescription
        let headerItem = CreateGiveawayHeaderItem(theme: presentationData.theme, strings: presentationData.strings, title: presentationData.strings.BoostGift_Title, text: headerText, isStars: state.mode == .starsGiveaway, cancel: {
            dismissImpl?()
        })
        
        let badgeCount: Int32
        switch state.mode {
        case .giveaway:
            badgeCount = state.subscriptions * 4
        case .gift:
            badgeCount = Int32(state.peers.count) * 4
        case .starsGiveaway:
            badgeCount = Int32(state.stars) / 500
        }
        let footerItem = CreateGiveawayFooterItem(theme: presentationData.theme, title: state.mode == .gift ? presentationData.strings.BoostGift_GiftPremium : presentationData.strings.BoostGift_StartGiveaway, badgeCount: badgeCount, isLoading: state.updating, action: {
            if case .prepaid = subject {
                let alertController = textAlertController(context: context, title: presentationData.strings.BoostGift_StartConfirmation_Title, text: presentationData.strings.BoostGift_StartConfirmation_Text, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .defaultAction, title: presentationData.strings.BoostGift_StartConfirmation_Start, action: {
                    buyActionImpl?()
                })], parseMarkdown: true)
                presentControllerImpl?(alertController)
            } else {
                buyActionImpl?()
            }
        })
        let leftNavigationButton = ItemListNavigationButton(content: .none, style: .regular, enabled: false, action: {})
        
        let _ = productsValue.swap(products)
        let previousStars = starsValue.swap(starsGiveawayOptions)
        if (previousStars ?? []).isEmpty && !starsGiveawayOptions.isEmpty {
            
        }
        
        let previousState = previousState.swap(state)
        var animateChanges = false
        if let previousState = previousState {
            if previousState.pickingExpiryTime != state.pickingExpiryTime {
                animateChanges = true
            }
            if previousState.pickingExpiryDate != state.pickingExpiryDate {
                animateChanges = true
            }
            if previousState.mode != state.mode {
                animateChanges = true
            }
            if previousState.channels.count > state.channels.count {
                animateChanges = true
            }
            if previousState.showPrizeDescription != state.showPrizeDescription {
                animateChanges = true
            }
            if previousState.starsExpanded != state.starsExpanded {
                animateChanges = true
            }
        }
        
        var peers: [EnginePeer.Id: EnginePeer] = [:]
        for (peerId, peer) in peersMap {
            if let peer {
                peers[peerId] = peer
            }
        }
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(""), leftNavigationButton: leftNavigationButton, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: true)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: createGiveawayControllerEntries(peerId: peerId, subject: subject, state: state, presentationData: presentationData, locale: locale, peers: peers, products: products, defaultPrice: defaultPrice, starsGiveawayOptions: starsGiveawayOptions, minDate: minDate, maxDate: maxDate), style: .blocks, emptyStateItem: nil, headerItem: headerItem, footerItem: footerItem, crossfadeState: false, animateChanges: animateChanges)
        
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
        actionsDisposable.dispose()
    }
    
    let controller = ItemListController(context: context, state: signal)
    controller.navigationPresentation = .modal
    controller.beganInteractiveDragging = {
//        dismissInputImpl?()
    }
    presentControllerImpl = { [weak controller] c in
        controller?.present(c, in: .window(.root))
    }
    pushControllerImpl = { [weak controller] c in
        controller?.push(c)
    }
    dismissInputImpl = { [weak controller] in
        controller?.view.endEditing(true)
    }
    dismissImpl = { [weak controller] in
        controller?.dismiss()
    }
    
    buyActionImpl = { [weak controller] in
        let isGroup = isGroupValue.with { $0 }
        
        let state = stateValue.with { $0 }

        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                     
        switch subject {
        case .generic:
            guard let products = productsValue.with({ $0 }), !products.isEmpty else {
                return
            }
            var selectedProduct: PremiumGiftProduct?
            var selectedStarsProduct: StarsGiveawayProduct?
            let selectedMonths = state.selectedMonths ?? 12
            let selectedStars = state.stars
            switch state.mode {
            case .giveaway:
                if let product = products.first(where: { $0.months == selectedMonths && $0.giftOption.users == state.subscriptions }) {
                    selectedProduct = product
                }
            case .gift:
                if let product = products.first(where: { $0.months == selectedMonths && $0.giftOption.users == 1 }) {
                    selectedProduct = product
                }
            case .starsGiveaway:
                guard let starsOptions = starsValue.with({ $0 }), !starsOptions.isEmpty else {
                    return
                }
                if let product = starsOptions.first(where: { $0.giveawayOption.count == selectedStars }) {
                    selectedStarsProduct = product
                }
            }
            
            if [.gift, .giveaway].contains(state.mode) {
                guard let _ = selectedProduct else {
                    let alertController = textAlertController(context: context, title: presentationData.strings.BoostGift_ReduceQuantity_Title, text: presentationData.strings.BoostGift_ReduceQuantity_Text("\(state.subscriptions)", "\(selectedMonths)", "\(25)").string, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .defaultAction, title: presentationData.strings.BoostGift_ReduceQuantity_Reduce, action: {
                        updateState { state in
                            var updatedState = state
                            updatedState.subscriptions = 25
                            return updatedState
                        }
                    })], parseMarkdown: true)
                    presentControllerImpl?(alertController)
                    return
                }
            }
            
            updateState { state in
                var updatedState = state
                updatedState.updating = true
                return updatedState
            }
            
            let purpose: AppStoreTransactionPurpose
            let quantity: Int32
            var storeProduct: InAppPurchaseManager.Product?
            switch state.mode {
            case .giveaway:
                guard let selectedProduct else {
                    return
                }
                let (currency, amount) = selectedProduct.storeProduct.priceCurrencyAndAmount
                let currentTime = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
                let untilDate = max(state.time, currentTime + 60)
                purpose = .giveaway(boostPeer: peerId, additionalPeerIds: state.channels.filter { $0 != peerId }, countries: state.countries, onlyNewSubscribers: state.onlyNewEligible, showWinners: state.showWinners, prizeDescription: state.prizeDescription.isEmpty ? nil : state.prizeDescription, randomId: Int64.random(in: .min ..< .max), untilDate: untilDate, currency: currency, amount: amount)
                quantity = selectedProduct.giftOption.storeQuantity
                storeProduct = selectedProduct.storeProduct
            case .gift:
                guard let selectedProduct else {
                    return
                }
                let (currency, amount) = selectedProduct.storeProduct.priceCurrencyAndAmount
                purpose = .giftCode(peerIds: state.peers, boostPeer: peerId, currency: currency, amount: amount)
                quantity = Int32(state.peers.count)
                storeProduct = selectedProduct.storeProduct
            case .starsGiveaway:
                guard let selectedStarsProduct else {
                    return
                }
                let (currency, amount) = selectedStarsProduct.storeProduct.priceCurrencyAndAmount
                let currentTime = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
                let untilDate = max(state.time, currentTime + 60)
                purpose = .starsGiveaway(stars: selectedStarsProduct.giveawayOption.count, boostPeer: peerId, additionalPeerIds: state.channels.filter { $0 != peerId }, countries: state.countries, onlyNewSubscribers: state.onlyNewEligible, showWinners: state.showWinners, prizeDescription: state.prizeDescription.isEmpty ? nil : state.prizeDescription, randomId: Int64.random(in: .min ..< .max), untilDate: untilDate, currency: currency, amount: amount, users: state.winners)
                quantity = 1
                storeProduct = selectedStarsProduct.storeProduct
            }
            
            guard let storeProduct else {
                return
            }
            
            let _ = (context.engine.payments.canPurchasePremium(purpose: purpose)
            |> deliverOnMainQueue).startStandalone(next: { [weak controller] available in
                if available, let inAppPurchaseManager = context.inAppPurchaseManager {
                    let _ = (inAppPurchaseManager.buyProduct(storeProduct, quantity: quantity, purpose: purpose)
                    |> deliverOnMainQueue).startStandalone(next: { [weak controller] status in
                        if case .purchased = status {
                            if let controller, let navigationController = controller.navigationController as? NavigationController {
                                var controllers = navigationController.viewControllers
                                var count = 0
                                for c in controllers.reversed() {
                                    if c is PeerInfoScreen {
                                        if case .giveaway = state.mode {
                                            count += 1
                                        }
                                        break
                                    } else {
                                        count += 1
                                    }
                                }
                                controllers.removeLast(count)
                                navigationController.setViewControllers(controllers, animated: true)
                                
                                let title: String
                                let text: String
                                switch state.mode {
                                case .giveaway:
                                    title = presentationData.strings.BoostGift_GiveawayCreated_Title
                                    text = isGroup ? presentationData.strings.BoostGift_Group_GiveawayCreated_Text : presentationData.strings.BoostGift_GiveawayCreated_Text
                                case .starsGiveaway:
                                    title = presentationData.strings.BoostGift_StarsGiveawayCreated_Title
                                    text = isGroup ? presentationData.strings.BoostGift_Group_StarsGiveawayCreated_Text : presentationData.strings.BoostGift_StarsGiveawayCreated_Text
                                case .gift:
                                    title = presentationData.strings.BoostGift_PremiumGifted_Title
                                    text = isGroup ? presentationData.strings.BoostGift_Group_PremiumGifted_Text : presentationData.strings.BoostGift_PremiumGifted_Text
                                }
                                
                                var content: UndoOverlayContent
                                if case .starsGiveaway = state.mode {
                                    content = .universal(
                                        animation: "StarsBuy",
                                        scale: 0.066,
                                        colors: [:],
                                        title: title,
                                        text: text,
                                        customUndoText: nil,
                                        timeout: nil
                                    )
                                } else {
                                    content = .premiumPaywall(title: title, text: text, customUndoText: nil, timeout: nil, linkAction: { [weak navigationController] _ in
                                        let statsController = context.sharedContext.makeChannelStatsController(context: context, updatedPresentationData: updatedPresentationData, peerId: peerId, boosts: true, boostStatus: nil)
                                        navigationController?.pushViewController(statsController)
                                    })
                                }
                                
                                let tooltipController = UndoOverlayController(presentationData: presentationData, content: content, elevatedLayout: false, action: { [weak navigationController] action in
                                    if case .info = action {
                                        let statsController = context.sharedContext.makeChannelStatsController(context: context, updatedPresentationData: updatedPresentationData, peerId: peerId, boosts: true, boostStatus: nil)
                                        navigationController?.pushViewController(statsController)
                                    }
                                    return true
                                })
                                (controllers.last as? ViewController)?.present(tooltipController, in: .current)
                            }
                        }
                    }, error: { error in
                        var errorText: String?
                        switch error {
                        case .generic:
                            errorText = presentationData.strings.Premium_Purchase_ErrorUnknown
                        case .network:
                            errorText = presentationData.strings.Premium_Purchase_ErrorNetwork
                        case .notAllowed:
                            errorText = presentationData.strings.Premium_Purchase_ErrorNotAllowed
                        case .cantMakePayments:
                            errorText = presentationData.strings.Premium_Purchase_ErrorCantMakePayments
                        case .assignFailed:
                            errorText = presentationData.strings.Premium_Purchase_ErrorUnknown
                        case .tryLater:
                            errorText = presentationData.strings.Premium_Purchase_ErrorUnknown
                        case .cancelled:
                            break
                        }
                        
                        if let errorText = errorText {
                            let alertController = textAlertController(context: context, updatedPresentationData: updatedPresentationData, title: nil, text: errorText, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})])
                            presentControllerImpl?(alertController)
                        }
                        
                        updateState { state in
                            var updatedState = state
                            updatedState.updating = false
                            return updatedState
                        }
                    })
                } else {
                    updateState { state in
                        var updatedState = state
                        updatedState.updating = false
                        return updatedState
                    }
                }
            })
        case let .prepaid(prepaidGiveaway):
            updateState { state in
                var updatedState = state
                updatedState.updating = true
                return updatedState
            }
            
            let purpose: LaunchGiveawayPurpose
            switch prepaidGiveaway.prize {
            case .premium:
                purpose = .premium
            case let .stars(stars, _):
                purpose = .stars(stars: stars, users: state.winners)
            }
            
            let _ = (context.engine.payments.launchPrepaidGiveaway(peerId: peerId, id: prepaidGiveaway.id, purpose: purpose, additionalPeerIds: state.channels.filter { $0 != peerId }, countries: state.countries, onlyNewSubscribers: state.onlyNewEligible, showWinners: state.showWinners, prizeDescription: state.prizeDescription.isEmpty ? nil : state.prizeDescription, randomId: Int64.random(in: .min ..< .max), untilDate: state.time)
            |> deliverOnMainQueue).startStandalone(completed: {
                if let controller, let navigationController = controller.navigationController as? NavigationController {
                    var controllers = navigationController.viewControllers
                    var count = 0
                    for c in controllers.reversed() {
                        if c is PeerInfoScreen {
                            if case .giveaway = state.mode {
                                count += 1
                            }
                            break
                        } else {
                            count += 1
                        }
                    }
                    controllers.removeLast(count)
                    navigationController.setViewControllers(controllers, animated: true)
                    
                    let title = presentationData.strings.BoostGift_GiveawayCreated_Title
                    let text = isGroup ? presentationData.strings.BoostGift_Group_GiveawayCreated_Text : presentationData.strings.BoostGift_GiveawayCreated_Text
                    
                    let tooltipController = UndoOverlayController(presentationData: presentationData, content: .premiumPaywall(title: title, text: text, customUndoText: nil, timeout: nil, linkAction: { [weak navigationController] _ in
                        let statsController = context.sharedContext.makeChannelStatsController(context: context, updatedPresentationData: updatedPresentationData, peerId: peerId, boosts: true, boostStatus: nil)
                        navigationController?.pushViewController(statsController)
                    }), elevatedLayout: false, action: { _ in
                        return true
                    })
                    (controllers.last as? ViewController)?.present(tooltipController, in: .current)
                }
            })
            break
        }
    }
    
    openPeersSelectionImpl = {
        let isGroup = isGroupValue.with { $0 }
        let state = stateValue.with { $0 }
        let stateContext = ShareWithPeersScreen.StateContext(
            context: context,
            subject: .members(isGroup: isGroup, peerId: peerId, searchQuery: nil),
            initialPeerIds: Set(state.peers)
        )
        let _ = (stateContext.ready |> filter { $0 } |> take(1) |> deliverOnMainQueue).startStandalone(next: { _ in
            let controller = ShareWithPeersScreen(
                context: context,
                initialPrivacy: EngineStoryPrivacy(base: .nobody, additionallyIncludePeers: state.peers),
                stateContext: stateContext,
                completion: { _, privacy ,_, _, _, _ in
                    updateState { state in
                        var updatedState = state
                        updatedState.peers = privacy.additionallyIncludePeers
                        if updatedState.peers.isEmpty {
                            updatedState.mode = .giveaway
                        } else {
                            updatedState.mode = .gift
                        }
                        return updatedState
                    }
                }
            )
            controller.dismissed = {
                updateState { state in
                    var updatedState = state
                    if updatedState.peers.isEmpty {
                        updatedState.mode = .giveaway
                    }
                    return updatedState
                }
            }
            pushControllerImpl?(controller)
        })
    }
    
    openChannelsSelectionImpl = {
        let isGroup = isGroupValue.with { $0 }
        let state = stateValue.with { $0 }
        let stateContext = ShareWithPeersScreen.StateContext(
            context: context,
            subject: .channels(isGroup: isGroup, exclude: Set([peerId]), searchQuery: nil),
            initialPeerIds: Set(state.channels.filter { $0 != peerId })
        )
        let _ = (stateContext.ready |> filter { $0 } |> take(1) |> deliverOnMainQueue).startStandalone(next: { _ in
            let controller = ShareWithPeersScreen(
                context: context,
                initialPrivacy: EngineStoryPrivacy(base: .nobody, additionallyIncludePeers: state.peers),
                stateContext: stateContext,
                completion: { _, privacy ,_, _, _, _ in
                    updateState { state in
                        var updatedState = state
                        updatedState.channels = privacy.additionallyIncludePeers
                        return updatedState
                    }
                }
            )
            pushControllerImpl?(controller)
        })
    }
    
    openCountriesSelectionImpl = {
        let state = stateValue.with { $0 }
        
        let stateContext = CountriesMultiselectionScreen.StateContext(
            context: context,
            subject: .countries,
            initialSelectedCountries: state.countries
        )
        let _ = (stateContext.ready |> filter { $0 } |> take(1) |> deliverOnMainQueue).startStandalone(next: { _ in
            let controller = CountriesMultiselectionScreen(
                context: context,
                stateContext: stateContext,
                completion: { countries in
                    updateState { state in
                        var updatedState = state
                        updatedState.countries = countries
                        return updatedState
                    }
                }
            )
            pushControllerImpl?(controller)
        })
    }
    
    openPremiumIntroImpl = {
        let controller = context.sharedContext.makePremiumIntroController(context: context, source: .settings, forceDark: false, dismissed: nil)
        pushControllerImpl?(controller)
    }
    
    scrollToDescriptionImpl = { [weak controller] in
        controller?.afterLayout({
            guard let controller = controller else {
                return
            }
            
            var resultItemNode: ListViewItemNode?
            let _ = controller.frameForItemNode({ listItemNode in
                if let itemNode = listItemNode as? ItemListItemNode {
                    if let tag = itemNode.tag as? CreateGiveawayEntryTag, tag == .description {
                        resultItemNode = listItemNode
                        return true
                    }
                }
                return false
            })
            if let resultItemNode = resultItemNode {
                controller.ensureItemNodeVisible(resultItemNode, overflow: 120.0, atTop: false)
            }
        })
    }
    
    scrollToDateImpl = { [weak controller] in
        controller?.afterLayout({
            guard let controller = controller else {
                return
            }
            
            var resultItemNode: ListViewItemNode?
            let _ = controller.frameForItemNode({ listItemNode in
                if let itemNode = listItemNode as? ItemListItemNode {
                    if let tag = itemNode.tag as? CreateGiveawayEntryTag, tag == .date {
                        resultItemNode = listItemNode
                        return true
                    }
                }
                return false
            })
            if let resultItemNode = resultItemNode {
                controller.ensureItemNodeVisible(resultItemNode, overflow: 120.0, atTop: true)
            }
        })
    }
    
    let countriesConfiguration = context.currentCountriesConfiguration.with { $0 }
    AuthorizationSequenceCountrySelectionController.setupCountryCodes(countries: countriesConfiguration.countries, codesByPrefix: countriesConfiguration.countriesByPrefix)
    
    return controller
}
