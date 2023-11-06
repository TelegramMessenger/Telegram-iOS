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
    let setItemIdWithRevealedOptions: (EnginePeer.Id?, EnginePeer.Id?) -> Void
    let removeChannel: (EnginePeer.Id) -> Void
    
    init(context: AccountContext, updateState: @escaping ((CreateGiveawayControllerState) -> CreateGiveawayControllerState) -> Void, dismissInput: @escaping () -> Void, openPeersSelection: @escaping () -> Void, openChannelsSelection: @escaping () -> Void, openCountriesSelection: @escaping () -> Void, openPremiumIntro: @escaping () -> Void, scrollToDate: @escaping () -> Void, setItemIdWithRevealedOptions: @escaping (EnginePeer.Id?, EnginePeer.Id?) -> Void, removeChannel: @escaping (EnginePeer.Id) -> Void) {
        self.context = context
        self.updateState = updateState
        self.dismissInput = dismissInput
        self.openPeersSelection = openPeersSelection
        self.openChannelsSelection = openChannelsSelection
        self.openCountriesSelection = openCountriesSelection
        self.openPremiumIntro = openPremiumIntro
        self.scrollToDate = scrollToDate
        self.setItemIdWithRevealedOptions = setItemIdWithRevealedOptions
        self.removeChannel = removeChannel
    }
}

private enum CreateGiveawaySection: Int32 {
    case header
    case mode
    case subscriptions
    case channels
    case users
    case time
    case duration
}

private enum CreateGiveawayEntryTag: ItemListItemTag {
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
    
    case createGiveaway(PresentationTheme, String, String, Bool)
    case awardUsers(PresentationTheme, String, String, Bool)
    
    case prepaidHeader(PresentationTheme, String)
    case prepaid(PresentationTheme, String, String, PrepaidGiveaway)
    
    case subscriptionsHeader(PresentationTheme, String, String)
    case subscriptions(PresentationTheme, Int32)
    case subscriptionsInfo(PresentationTheme, String)
    
    case channelsHeader(PresentationTheme, String)
    case channel(Int32, PresentationTheme, EnginePeer, Int32?, Bool)
    case channelAdd(PresentationTheme, String)
    case channelsInfo(PresentationTheme, String)
    
    case usersHeader(PresentationTheme, String)
    case usersAll(PresentationTheme, String, String, Bool)
    case usersNew(PresentationTheme, String, String, Bool)
    case usersInfo(PresentationTheme, String)
    
    case timeHeader(PresentationTheme, String)
    case timeExpiryDate(PresentationTheme, PresentationDateTimeFormat, Int32?, Bool)
    case timeCustomPicker(PresentationTheme, PresentationDateTimeFormat, Int32?, Int32?, Int32?, Bool, Bool)
    case timeInfo(PresentationTheme, String)
    
    case durationHeader(PresentationTheme, String)
    case duration(Int32, PresentationTheme, Int32, String, String, String, String?, Bool)
    case durationInfo(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
        case .header:
            return CreateGiveawaySection.header.rawValue
        case .createGiveaway, .awardUsers, .prepaidHeader, .prepaid:
            return CreateGiveawaySection.mode.rawValue
        case .subscriptionsHeader, .subscriptions, .subscriptionsInfo:
            return CreateGiveawaySection.subscriptions.rawValue
        case .channelsHeader, .channel, .channelAdd, .channelsInfo:
            return CreateGiveawaySection.channels.rawValue
        case .usersHeader, .usersAll, .usersNew, .usersInfo:
            return CreateGiveawaySection.users.rawValue
        case .timeHeader, .timeExpiryDate, .timeCustomPicker, .timeInfo:
            return CreateGiveawaySection.time.rawValue
        case .durationHeader, .duration, .durationInfo:
            return CreateGiveawaySection.duration.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
            case .header:
                return -1
            case .createGiveaway:
                return 0
            case .awardUsers:
                return 1
            case .prepaidHeader:
                return 2
            case .prepaid:
                return 3
            case .subscriptionsHeader:
                return 4
            case .subscriptions:
                return 5
            case .subscriptionsInfo:
                return 6
            case .channelsHeader:
                return 7
            case let .channel(index, _, _, _, _):
                return 8 + index
            case .channelAdd:
                return 100
            case .channelsInfo:
                return 101
            case .usersHeader:
                return 102
            case .usersAll:
                return 103
            case .usersNew:
                return 104
            case .usersInfo:
                return 105
            case .timeHeader:
                return 106
            case .timeExpiryDate:
                return 107
            case .timeCustomPicker:
                return 108
            case .timeInfo:
                return 109
            case .durationHeader:
                return 110
            case let .duration(index, _, _, _, _, _, _, _):
                return 111 + index
            case .durationInfo:
                return 120
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
        case let .createGiveaway(lhsTheme, lhsText, lhsSubtext, lhsSelected):
            if case let .createGiveaway(rhsTheme, rhsText, rhsSubtext, rhsSelected) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsSubtext == rhsSubtext, lhsSelected == rhsSelected {
                return true
            } else {
                return false
            }
        case let .awardUsers(lhsTheme, lhsText, lhsSubtext, lhsSelected):
            if case let .awardUsers(rhsTheme, rhsText, rhsSubtext, rhsSelected) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsSubtext == rhsSubtext, lhsSelected == rhsSelected {
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
        case let .subscriptionsHeader(lhsTheme, lhsText, lhsAdditionalText):
            if case let .subscriptionsHeader(rhsTheme, rhsText, rhsAdditionalText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsAdditionalText == rhsAdditionalText {
                return true
            } else {
                return false
            }
        case let .subscriptions(lhsTheme, lhsValue):
            if case let .subscriptions(rhsTheme, rhsValue) = rhs, lhsTheme === rhsTheme, lhsValue == rhsValue {
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
        case let .createGiveaway(_, title, subtitle, isSelected):
            return GiftOptionItem(presentationData: presentationData, context: arguments.context, icon: .image(color: .blue, name: "Premium/Giveaway"), title: title, subtitle: subtitle, isSelected: isSelected, sectionId: self.section, action: {
                arguments.updateState { state in
                    var updatedState = state
                    updatedState.mode = .giveaway
                    return updatedState
                }
            })
        case let .awardUsers(_, title, subtitle, isSelected):
            return GiftOptionItem(presentationData: presentationData, context: arguments.context, icon: .image(color: .violet, name: "Media Editor/Privacy/SelectedUsers"), title: title, subtitle: subtitle, subtitleActive: true, isSelected: isSelected, sectionId: self.section, action: {
                var openSelection = false
                arguments.updateState { state in
                    var updatedState = state
                    if state.mode == .gift || state.peers.isEmpty {
                        openSelection = true
                    }
                    updatedState.mode = .gift
                    return updatedState
                }
                if openSelection {
                    arguments.openPeersSelection()
                }
            })
        case let .prepaidHeader(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .prepaid(_, title, subtitle, prepaidGiveaway):
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
            return GiftOptionItem(presentationData: presentationData, context: arguments.context, icon: .image(color: color, name: "Premium/Giveaway"), title: title, titleFont: .bold, titleBadge: "\(prepaidGiveaway.quantity * 4)", subtitle: subtitle, sectionId: self.section, action: nil)
        case let .subscriptionsHeader(_, text, additionalText):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, accessoryText: ItemListSectionHeaderAccessoryText(value: additionalText, color: .generic), sectionId: self.section)
        case let .subscriptions(_, value):
            return SubscriptionsCountItem(theme: presentationData.theme, strings: presentationData.strings, value: value, sectionId: self.section, updated: { value in
                arguments.updateState { state in
                    var updatedState = state
                    updatedState.subscriptions = value
                    return updatedState
                }
            })
        case let .subscriptionsInfo(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .channelsHeader(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .channel(_, _, peer, boosts, isRevealed):
            return ItemListPeerItem(presentationData: presentationData, dateTimeFormat: PresentationDateTimeFormat(), nameDisplayOrder: presentationData.nameDisplayOrder, context: arguments.context, peer: peer, presence: nil, text: boosts.flatMap { .text(presentationData.strings.BoostGift_ChannelsBoosts($0), .secondary) } ?? .none, label: .none, editing: ItemListPeerItemEditing(editable: boosts == nil, editing: false, revealed: isRevealed), switchValue: nil, enabled: true, selectable: peer.id != arguments.context.account.peerId, sectionId: self.section, action: {
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

private func createGiveawayControllerEntries(
    peerId: EnginePeer.Id,
    subject: CreateGiveawaySubject,
    state: CreateGiveawayControllerState,
    presentationData: PresentationData,
    locale: Locale,
    peers: [EnginePeer.Id: EnginePeer],
    products: [PremiumGiftProduct],
    defaultPrice: (Int64, NSDecimalNumber),
    minDate: Int32,
    maxDate: Int32
) -> [CreateGiveawayEntry] {
    var entries: [CreateGiveawayEntry] = []
        
    switch subject {
    case .generic:
        entries.append(.createGiveaway(presentationData.theme, presentationData.strings.BoostGift_CreateGiveaway, presentationData.strings.BoostGift_CreateGiveawayInfo, state.mode == .giveaway))
        
        let recipientsText: String
        if !state.peers.isEmpty {
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
            recipientsText = presentationData.strings.BoostGift_SelectRecipients
        }
        entries.append(.awardUsers(presentationData.theme, presentationData.strings.BoostGift_AwardSpecificUsers, recipientsText, state.mode == .gift))
    case let .prepaid(prepaidGiveaway):
        entries.append(.prepaidHeader(presentationData.theme, presentationData.strings.BoostGift_PrepaidGiveawayTitle))
        entries.append(.prepaid(presentationData.theme, presentationData.strings.BoostGift_PrepaidGiveawayCount(prepaidGiveaway.quantity), presentationData.strings.BoostGift_PrepaidGiveawayMonths("\(prepaidGiveaway.months)").string, prepaidGiveaway))
    }
    
    if case .giveaway = state.mode {
        if case .generic = subject {
            entries.append(.subscriptionsHeader(presentationData.theme, presentationData.strings.BoostGift_QuantityTitle.uppercased(), presentationData.strings.BoostGift_QuantityBoosts(state.subscriptions * 4)))
            entries.append(.subscriptions(presentationData.theme, state.subscriptions))
            entries.append(.subscriptionsInfo(presentationData.theme, presentationData.strings.BoostGift_QuantityInfo))
        }
        
        entries.append(.channelsHeader(presentationData.theme, presentationData.strings.BoostGift_ChannelsTitle.uppercased()))
        var index: Int32 = 0
        let channels = [peerId] + state.channels
        for channelId in channels {
            if let channel = peers[channelId] {
                entries.append(.channel(index, presentationData.theme, channel, channel.id == peerId ? state.subscriptions * 4 : nil, false))
            }
            index += 1
        }
        entries.append(.channelAdd(presentationData.theme, presentationData.strings.BoostGift_AddChannel))
        entries.append(.channelsInfo(presentationData.theme, presentationData.strings.BoostGift_ChannelsInfo))
        
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
        
        entries.append(.usersAll(presentationData.theme, presentationData.strings.BoostGift_AllSubscribers, countriesText, !state.onlyNewEligible))
        entries.append(.usersNew(presentationData.theme, presentationData.strings.BoostGift_OnlyNewSubscribers, countriesText, state.onlyNewEligible))
        entries.append(.usersInfo(presentationData.theme, presentationData.strings.BoostGift_LimitSubscribersInfo))
        
        entries.append(.timeHeader(presentationData.theme, presentationData.strings.BoostGift_DateTitle.uppercased()))
        entries.append(.timeCustomPicker(presentationData.theme, presentationData.dateTimeFormat, state.time, minDate, maxDate, state.pickingExpiryDate, state.pickingExpiryTime))
        entries.append(.timeInfo(presentationData.theme, presentationData.strings.BoostGift_DateInfo(presentationData.strings.BoostGift_DateInfoSubscribers(Int32(state.subscriptions))).string))
    }
    
    if case .generic = subject {
        entries.append(.durationHeader(presentationData.theme, presentationData.strings.BoostGift_DurationTitle.uppercased()))
        
        let recipientCount: Int
        switch state.mode {
        case .giveaway:
            recipientCount = Int(state.subscriptions)
        case .gift:
            recipientCount = state.peers.count
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
    
    return entries
}

private struct CreateGiveawayControllerState: Equatable {
    enum Mode {
        case giveaway
        case gift
    }
    
    var mode: Mode
    var subscriptions: Int32
    var channels: [EnginePeer.Id]
    var peers: [EnginePeer.Id]
    var selectedMonths: Int32?
    var countries: [String]
    var onlyNewEligible: Bool
    var time: Int32
    var pickingExpiryTime = false
    var pickingExpiryDate = false
    var revealedItemId: EnginePeer.Id? = nil
    var updating = false
}

public enum CreateGiveawaySubject {
    case generic
    case prepaid(PrepaidGiveaway)
}

public func createGiveawayController(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, peerId: EnginePeer.Id, subject: CreateGiveawaySubject,  completion: (() -> Void)? = nil) -> ViewController {
    let actionsDisposable = DisposableSet()
    
    let initialSubscriptions: Int32
    if case let .prepaid(prepaidGiveaway) = subject {
        initialSubscriptions = prepaidGiveaway.quantity
    } else {
        initialSubscriptions = 5
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
    
    let minDate = currentTime + 60 * 30
    let maxDate = currentTime + context.userLimits.maxGiveawayPeriodSeconds
    
    let initialState: CreateGiveawayControllerState = CreateGiveawayControllerState(mode: .giveaway, subscriptions: initialSubscriptions, channels: [], peers: [], countries: [], onlyNewEligible: false, time: expiryTime)

    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((CreateGiveawayControllerState) -> CreateGiveawayControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    let productsValue = Atomic<[PremiumGiftProduct]?>(value: nil)

    var buyActionImpl: (() -> Void)?
    var openPeersSelectionImpl: (() -> Void)?
    var openChannelsSelectionImpl: (() -> Void)?
    var openCountriesSelectionImpl: (() -> Void)?
    var openPremiumIntroImpl: (() -> Void)?
    var presentControllerImpl: ((ViewController) -> Void)?
    var pushControllerImpl: ((ViewController) -> Void)?
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
        productsAndDefaultPrice
    )
    |> deliverOnMainQueue
    |> map { presentationData, stateAndPeersMap, productsAndDefaultPrice -> (ItemListControllerState, (ItemListNodeState, Any)) in
        var presentationData = presentationData
        
        let (products, defaultPrice) = productsAndDefaultPrice
        
        let updatedTheme = presentationData.theme.withModalBlocksBackground()
        presentationData = presentationData.withUpdated(theme: updatedTheme)
        
        let (state, peersMap) = stateAndPeersMap
                
        let headerItem = CreateGiveawayHeaderItem(theme: presentationData.theme, strings: presentationData.strings, title: presentationData.strings.BoostGift_Title, text: presentationData.strings.BoostGift_Description, cancel: {
            dismissImpl?()
        })
        
        let badgeCount: Int32
        switch state.mode {
        case .giveaway:
            badgeCount = state.subscriptions * 4
        case .gift:
            badgeCount = Int32(state.peers.count) * 4
        }
        let footerItem = CreateGiveawayFooterItem(theme: presentationData.theme, title: state.mode == .gift ? presentationData.strings.BoostGift_GiftPremium : presentationData.strings.BoostGift_StartGiveaway, badgeCount: badgeCount, isLoading: state.updating, action: {
            buyActionImpl?()
        })
        let leftNavigationButton = ItemListNavigationButton(content: .none, style: .regular, enabled: false, action: {})
        
        let _ = productsValue.swap(products)
        
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
        }
        
        var peers: [EnginePeer.Id: EnginePeer] = [:]
        for (peerId, peer) in peersMap {
            if let peer {
                peers[peerId] = peer
            }
        }
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(""), leftNavigationButton: leftNavigationButton, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: true)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: createGiveawayControllerEntries(peerId: peerId, subject: subject, state: state, presentationData: presentationData, locale: locale, peers: peers, products: products, defaultPrice: defaultPrice, minDate: minDate, maxDate: maxDate), style: .blocks, emptyStateItem: nil, headerItem: headerItem, footerItem: footerItem, crossfadeState: false, animateChanges: animateChanges)
        
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
        actionsDisposable.dispose()
    }
    
    let controller = ItemListController(context: context, state: signal)
    controller.navigationPresentation = .modal
    controller.beganInteractiveDragging = {
        dismissInputImpl?()
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
        let state = stateValue.with { $0 }

        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                     
        switch subject {
        case .generic:
            guard let products = productsValue.with({ $0 }), !products.isEmpty else {
                return
            }
            var selectedProduct: PremiumGiftProduct?
            let selectedMonths = state.selectedMonths ?? 12
            switch state.mode {
            case .giveaway:
                if let product = products.first(where: { $0.months == selectedMonths && $0.giftOption.users == state.subscriptions }) {
                    selectedProduct = product
                }
            case .gift:
                if let product = products.first(where: { $0.months == selectedMonths && $0.giftOption.users == 1 }) {
                    selectedProduct = product
                }
            }
            
            guard let selectedProduct else {
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
            
            updateState { state in
                var updatedState = state
                updatedState.updating = true
                return updatedState
            }
            
            let (currency, amount) = selectedProduct.storeProduct.priceCurrencyAndAmount
            
            let purpose: AppStoreTransactionPurpose
            let quantity: Int32
            switch state.mode {
            case .giveaway:
                purpose = .giveaway(boostPeer: peerId, additionalPeerIds: state.channels.filter { $0 != peerId }, countries: state.countries, onlyNewSubscribers: state.onlyNewEligible, randomId: Int64.random(in: .min ..< .max), untilDate: state.time, currency: currency, amount: amount)
                quantity = selectedProduct.giftOption.storeQuantity
            case .gift:
                purpose = .giftCode(peerIds: state.peers, boostPeer: peerId, currency: currency, amount: amount)
                quantity = Int32(state.peers.count)
            }
            
            let _ = (context.engine.payments.canPurchasePremium(purpose: purpose)
            |> deliverOnMainQueue).startStandalone(next: { [weak controller] available in
                if available, let inAppPurchaseManager = context.inAppPurchaseManager {
                    let _ = (inAppPurchaseManager.buyProduct(selectedProduct.storeProduct, quantity: quantity, purpose: purpose)
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
                                    text = presentationData.strings.BoostGift_GiveawayCreated_Text
                                case .gift:
                                    title = presentationData.strings.BoostGift_PremiumGifted_Title
                                    text = presentationData.strings.BoostGift_PremiumGifted_Text
                                }
                                
                                let tooltipController = UndoOverlayController(presentationData: presentationData, content: .premiumPaywall(title: title, text: text, customUndoText: nil, timeout: nil, linkAction: { [weak navigationController] _ in
                                    let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.StatsDatacenterId(id: peerId))
                                    |> deliverOnMainQueue).startStandalone(next: { [weak navigationController] statsDatacenterId in
                                        guard let statsDatacenterId else {
                                            return
                                        }
                                        let statsController = context.sharedContext.makeChannelStatsController(context: context, updatedPresentationData: updatedPresentationData, peerId: peerId, boosts: true, boostStatus: nil, statsDatacenterId: statsDatacenterId)
                                        navigationController?.pushViewController(statsController)
                                    })
                                }), elevatedLayout: false, action: { _ in
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
            
            let _ = (context.engine.payments.launchPrepaidGiveaway(peerId: peerId, id: prepaidGiveaway.id, additionalPeerIds: state.channels.filter { $0 != peerId }, countries: state.countries, onlyNewSubscribers: state.onlyNewEligible, randomId: Int64.random(in: .min ..< .max), untilDate: state.time)
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
                    let text = presentationData.strings.BoostGift_GiveawayCreated_Text
                    
                    let tooltipController = UndoOverlayController(presentationData: presentationData, content: .premiumPaywall(title: title, text: text, customUndoText: nil, timeout: nil, linkAction: { [weak navigationController] _ in
                        let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.StatsDatacenterId(id: peerId))
                        |> deliverOnMainQueue).startStandalone(next: { [weak navigationController] statsDatacenterId in
                            guard let statsDatacenterId else {
                                return
                            }
                            let statsController = context.sharedContext.makeChannelStatsController(context: context, updatedPresentationData: updatedPresentationData, peerId: peerId, boosts: true, boostStatus: nil, statsDatacenterId: statsDatacenterId)
                            navigationController?.pushViewController(statsController)
                        })
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
        let state = stateValue.with { $0 }
        
        let stateContext = ShareWithPeersScreen.StateContext(
            context: context,
            subject: .members(peerId: peerId, searchQuery: nil),
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
        let state = stateValue.with { $0 }
        
        let stateContext = ShareWithPeersScreen.StateContext(
            context: context,
            subject: .channels(exclude: Set([peerId]), searchQuery: nil),
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
