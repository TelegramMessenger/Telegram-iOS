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

private final class CreateGiveawayControllerArguments {
    let context: AccountContext
    let updateState: ((CreateGiveawayControllerState) -> CreateGiveawayControllerState) -> Void
    let dismissInput: () -> Void
    let openPeersSelection: () -> Void
    let openChannelsSelection: () -> Void
    let openPremiumIntro: () -> Void
    
    init(context: AccountContext, updateState: @escaping ((CreateGiveawayControllerState) -> CreateGiveawayControllerState) -> Void, dismissInput: @escaping () -> Void, openPeersSelection: @escaping () -> Void, openChannelsSelection: @escaping () -> Void, openPremiumIntro: @escaping () -> Void) {
        self.context = context
        self.updateState = updateState
        self.dismissInput = dismissInput
        self.openPeersSelection = openPeersSelection
        self.openChannelsSelection = openChannelsSelection
        self.openPremiumIntro = openPremiumIntro
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
    case usage

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
    case prepaid(PresentationTheme, String, String, Int32, Int32)
    
    case subscriptionsHeader(PresentationTheme, String, String)
    case subscriptions(PresentationTheme, Int32)
    case subscriptionsInfo(PresentationTheme, String)
    
    case channelsHeader(PresentationTheme, String)
    case channel(Int32, PresentationTheme, EnginePeer, Int32?)
    case channelAdd(PresentationTheme, String)
    case channelsInfo(PresentationTheme, String)
    
    case usersHeader(PresentationTheme, String)
    case usersAll(PresentationTheme, String, Bool)
    case usersNew(PresentationTheme, String, Bool)
    case usersInfo(PresentationTheme, String)
    
    case timeHeader(PresentationTheme, String)
    case timeExpiryDate(PresentationTheme, PresentationDateTimeFormat, Int32?, Bool)
    case timeCustomPicker(PresentationTheme, PresentationDateTimeFormat, Int32?)
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
            case let .channel(index, _, _, _):
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
        case let .prepaid(lhsTheme, lhsText, lhsSubtext, lhsBoosts, lhsMonths):
            if case let .prepaid(rhsTheme, rhsText, rhsSubtext, rhsBoosts, rhsMonths) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsSubtext == rhsSubtext, lhsBoosts == rhsBoosts, lhsMonths == rhsMonths {
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
        case let .channel(lhsIndex, lhsTheme, lhsPeer, lhsBoosts):
            if case let .channel(rhsIndex, rhsTheme, rhsPeer, rhsBoosts) = rhs, lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsPeer == rhsPeer, lhsBoosts == rhsBoosts {
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
        case let .usersAll(lhsTheme, lhsText, lhsSelected):
            if case let .usersAll(rhsTheme, rhsText, rhsSelected) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsSelected == rhsSelected {
                return true
            } else {
                return false
            }
        case let .usersNew(lhsTheme, lhsText, lhsSelected):
            if case let .usersNew(rhsTheme, rhsText, rhsSelected) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsSelected == rhsSelected {
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
        case let .timeCustomPicker(lhsTheme, lhsDateTimeFormat, lhsDate):
            if case let .timeCustomPicker(rhsTheme, rhsDateTimeFormat, rhsDate) = rhs, lhsTheme === rhsTheme, lhsDateTimeFormat == rhsDateTimeFormat, lhsDate == rhsDate {
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
            return GiftOptionItem(presentationData: presentationData, context: arguments.context, icon: GiftOptionItem.Icon(color: .blue, name: "Premium/Giveaway"), title: title, subtitle: subtitle, isSelected: isSelected, sectionId: self.section, action: {
                arguments.updateState { state in
                    var updatedState = state
                    updatedState.mode = .giveaway
                    return updatedState
                }
            })
        case let .awardUsers(_, title, subtitle, isSelected):
            return GiftOptionItem(presentationData: presentationData, context: arguments.context, icon: GiftOptionItem.Icon(color: .violet, name: "Media Editor/Privacy/SelectedUsers"), title: title, subtitle: subtitle, subtitleActive: true, isSelected: isSelected, sectionId: self.section, action: {
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
        case let .prepaid(_, title, subtitle, boosts, months):
            let _ = boosts
            let color: GiftOptionItem.Icon.Color
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
            return GiftOptionItem(presentationData: presentationData, context: arguments.context, icon: GiftOptionItem.Icon(color: color, name: "Premium/Giveaway"), title: title, titleFont: .bold, subtitle: subtitle, label: .boosts(boosts), sectionId: self.section, action: nil)
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
        case let .channel(_, _, peer, boosts):
            return ItemListPeerItem(presentationData: presentationData, dateTimeFormat: PresentationDateTimeFormat(), nameDisplayOrder: presentationData.nameDisplayOrder, context: arguments.context, peer: peer, presence: nil, text: boosts.flatMap { .text("this channel will receive \($0) boosts", .secondary) } ?? .none, label: .none, editing: ItemListPeerItemEditing(editable: false, editing: false, revealed: false), switchValue: nil, enabled: true, selectable: peer.id != arguments.context.account.peerId, sectionId: self.section, action: {
//                arguments.openPeer(peer)
            }, setPeerIdWithRevealedOptions: { _, _ in }, removePeer: { _ in })
        case let .channelAdd(theme, text):
            return ItemListPeerActionItem(presentationData: presentationData, icon: PresentationResourcesItemList.roundPlusIconImage(theme), title: text, alwaysPlain: false, hasSeparator: true, sectionId: self.section, height: .compactPeerList, color: .accent, editing: false, action: {
                arguments.openChannelsSelection()
            })
        case let .channelsInfo(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .usersHeader(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .usersAll(_, title, isSelected):
            return GiftOptionItem(presentationData: presentationData, context: arguments.context, title: title, subtitle: nil, isSelected: isSelected, sectionId: self.section, action: {
                arguments.updateState { state in
                    var updatedState = state
                    updatedState.onlyNewEligible = false
                    return updatedState
                }
            })
        case let .usersNew(_, title, isSelected):
            return GiftOptionItem(presentationData: presentationData, context: arguments.context, title: title, subtitle: nil, isSelected: isSelected, sectionId: self.section, action: {
                arguments.updateState { state in
                    var updatedState = state
                    updatedState.onlyNewEligible = true
                    return updatedState
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
            return ItemListDisclosureItem(presentationData: presentationData, title: "Ends", label: text, labelStyle: active ? .coloredText(theme.list.itemAccentColor) : .text, sectionId: self.section, style: .blocks, disclosureStyle: .none, action: {
                arguments.dismissInput()
                arguments.updateState { state in
                    var updatedState = state
                    updatedState.pickingTimeLimit = !state.pickingTimeLimit
                    return updatedState
                }
            })
        case let .timeCustomPicker(_, dateTimeFormat, date):
            return ItemListDatePickerItem(presentationData: presentationData, dateTimeFormat: dateTimeFormat, date: date, sectionId: self.section, style: .blocks, updated: { date in
                arguments.updateState({ state in
                    var updatedState = state
                    updatedState.time = date
                    return updatedState
                })
            })
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

private func createGiveawayControllerEntries(peerId: EnginePeer.Id, subject: CreateGiveawaySubject, state: CreateGiveawayControllerState, presentationData: PresentationData, peers: [EnginePeer.Id: EnginePeer], products: [PremiumGiftProduct], defaultPrice: (Int64, NSDecimalNumber)) -> [CreateGiveawayEntry] {
    var entries: [CreateGiveawayEntry] = []
        
    switch subject {
    case .generic:
        entries.append(.createGiveaway(presentationData.theme, "Create Giveaway", "winners are chosen randomly", state.mode == .giveaway))
        
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
            recipientsText = "select recipients"
        }
        entries.append(.awardUsers(presentationData.theme, "Award Specific Users", recipientsText, state.mode == .gift))
    case let .prepaid(months, count):
        entries.append(.prepaidHeader(presentationData.theme, "PREPAID GIVEAWAY"))
        entries.append(.prepaid(presentationData.theme, "\(count) Telegram Premium", "\(months)-month subscriptions", count, months))
    }
    
    if case .giveaway = state.mode {
        if case .generic = subject {
            entries.append(.subscriptionsHeader(presentationData.theme, "QUANTITY OF PRIZES".uppercased(), "\(state.subscriptions) BOOSTS"))
            entries.append(.subscriptions(presentationData.theme, state.subscriptions))
            entries.append(.subscriptionsInfo(presentationData.theme, "Choose how many Premium subscriptions to give away and boosts to receive."))
        }
        
        entries.append(.channelsHeader(presentationData.theme, "CHANNELS INCLUDED IN THE GIVEAWAY".uppercased()))
        var index: Int32 = 0
        let channels = [peerId] + state.channels
        for channelId in channels {
            if let channel = peers[channelId] {
                entries.append(.channel(index, presentationData.theme, channel, channel.id == peerId ? state.subscriptions : nil))
            }
            index += 1
        }
        entries.append(.channelAdd(presentationData.theme,  "Add Channel"))
        entries.append(.channelsInfo(presentationData.theme, "Choose the channels users need to be subscribed to take part in the giveaway"))
        
        entries.append(.usersHeader(presentationData.theme, "USERS ELIGIBLE FOR THE GIVEAWAY".uppercased()))
        entries.append(.usersAll(presentationData.theme, "All subscribers", !state.onlyNewEligible))
        entries.append(.usersNew(presentationData.theme, "Only new subscribers", state.onlyNewEligible))
        entries.append(.usersInfo(presentationData.theme, "Choose if you want to limit the giveaway only to those who joined the channel after the giveaway started."))
        
        entries.append(.timeHeader(presentationData.theme, "DATE WHEN GIVEAWAY ENDS".uppercased()))
        entries.append(.timeExpiryDate(presentationData.theme, presentationData.dateTimeFormat, state.time, state.pickingTimeLimit))
        if state.pickingTimeLimit {
            entries.append(.timeCustomPicker(presentationData.theme, presentationData.dateTimeFormat, state.time))
        }
        entries.append(.timeInfo(presentationData.theme, "Choose when \(state.subscriptions) subscribers of your channel will be randomly selected to receive Telegram Premium."))
    }
    
    if case .generic = subject {
        entries.append(.durationHeader(presentationData.theme, "DURATION OF PREMIUM SUBSCRIPTIONS".uppercased()))
        
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
        
        entries.append(.durationInfo(presentationData.theme, "You can review the list of features and terms of use for Telegram Premium [here]()."))
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
    var onlyNewEligible: Bool
    var time: Int32
    var pickingTimeLimit = false
    var updating = false
}

public enum CreateGiveawaySubject {
    case generic
    case prepaid(months: Int32, count: Int32)
}

public func createGiveawayController(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, peerId: EnginePeer.Id, subject: CreateGiveawaySubject,  completion: (() -> Void)? = nil) -> ViewController {
    let actionsDisposable = DisposableSet()
    
    let initialSubscriptions: Int32
    if case let .prepaid(_, count) = subject {
        initialSubscriptions = count
    } else {
        initialSubscriptions = 5
    }
    
    let expiryTime = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970) + 86400 * 5
    let initialState: CreateGiveawayControllerState = CreateGiveawayControllerState(mode: .giveaway, subscriptions: initialSubscriptions, channels: [], peers: [], onlyNewEligible: false, time: expiryTime)

    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((CreateGiveawayControllerState) -> CreateGiveawayControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    let productsValue = Atomic<[PremiumGiftProduct]?>(value: nil)

    var buyActionImpl: (() -> Void)?
    var openPeersSelectionImpl: (() -> Void)?
    var openChannelsSelectionImpl: (() -> Void)?
    var openPremiumIntroImpl: (() -> Void)?
    var presentControllerImpl: ((ViewController) -> Void)?
    var pushControllerImpl: ((ViewController) -> Void)?
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
    }, openPremiumIntro: {
        openPremiumIntroImpl?()
    })
    
    let presentationData = updatedPresentationData?.signal ?? context.sharedContext.presentationData
    
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
                
        let headerItem = CreateGiveawayHeaderItem(theme: presentationData.theme, title: "Boosts via Gifts", text: "Get more boosts for your channel by gifting\nPremium to your subscribers.", cancel: {
            dismissImpl?()
        })
        
        let badgeCount: Int32
        switch state.mode {
        case .giveaway:
            badgeCount = state.subscriptions
        case .gift:
            badgeCount = Int32(state.peers.count)
        }
        let footerItem = CreateGiveawayFooterItem(theme: presentationData.theme, title: state.mode == .gift ? "Gift Premium" : "Start Giveaway", badgeCount: badgeCount, isLoading: state.updating, action: {
            buyActionImpl?()
        })
        let leftNavigationButton = ItemListNavigationButton(content: .none, style: .regular, enabled: false, action: {})
        
        let _ = productsValue.swap(products)
        
        let previousState = previousState.swap(state)
        var animateChanges = false
        if let previousState = previousState, previousState.pickingTimeLimit != state.pickingTimeLimit || previousState.mode != state.mode {
            animateChanges = true
        }
        
        var peers: [EnginePeer.Id: EnginePeer] = [:]
        for (peerId, peer) in peersMap {
            if let peer {
                peers[peerId] = peer
            }
        }
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(""), leftNavigationButton: leftNavigationButton, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: true)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: createGiveawayControllerEntries(peerId: peerId, subject: subject, state: state, presentationData: presentationData, peers: peers, products: products, defaultPrice: defaultPrice), style: .blocks, emptyStateItem: nil, headerItem: headerItem, footerItem: footerItem, crossfadeState: false, animateChanges: animateChanges)
        
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
        guard let products = productsValue.with({ $0 }), !products.isEmpty else {
            return
        }
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    
        var selectedProduct: PremiumGiftProduct?
        let selectedMonths = state.selectedMonths ?? 12
        if let product = products.first(where: { $0.months == selectedMonths && $0.giftOption.users == state.subscriptions }) {
            selectedProduct = product
        }
        
        guard let selectedProduct else {
            let alertController = textAlertController(context: context, title: "Reduce Quantity", text: "You can't acquire \(state.subscriptions) \(selectedMonths)-month subscriptions in the app. Do you want to reduce quantity to 25?", actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .defaultAction, title: "Reduce", action: {
                updateState { state in
                    var updatedState = state
                    updatedState.subscriptions = 25
                    return updatedState
                }
            })], parseMarkdown: true)
            presentControllerImpl?(alertController)
            return
        }
        
        let (currency, amount) = selectedProduct.storeProduct.priceCurrencyAndAmount
        
        let purpose: AppStoreTransactionPurpose
        switch state.mode {
        case .giveaway:
            purpose = .giveaway(boostPeer: peerId, additionalPeerIds: state.channels.filter { $0 != peerId}, onlyNewSubscribers: state.onlyNewEligible, randomId: Int64.random(in: .min ..< .max), untilDate: state.time, currency: currency, amount: amount)
        case .gift:
            purpose = .giftCode(peerIds: state.peers, boostPeer: peerId, currency: currency, amount: amount)
        }
                
        updateState { state in
            var updatedState = state
            updatedState.updating = true
            return updatedState
        }
        
        let _ = (context.engine.payments.canPurchasePremium(purpose: purpose)
        |> deliverOnMainQueue).startStandalone(next: { [weak controller] available in
            if available, let inAppPurchaseManager = context.inAppPurchaseManager {
                let _ = (inAppPurchaseManager.buyProduct(selectedProduct.storeProduct, quantity: selectedProduct.giftOption.storeQuantity, purpose: purpose)
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
                                title = "Giveaway Created"
                                text = "Check your channel's [Statistics]() to see how this giveaway boosted your channel."
                            case .gift:
                                title = "Premium Subscriptions Gifted"
                                text = "Check your channel's [Statistics]() to see how gifts boosted your channel."
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
                let alertController = textAlertController(context: context, updatedPresentationData: updatedPresentationData, title: nil, text: presentationData.strings.Premium_Purchase_ErrorUnknown, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})])
                presentControllerImpl?(alertController)
                
                updateState { state in
                    var updatedState = state
                    updatedState.updating = false
                    return updatedState
                }
            }
        })
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
            pushControllerImpl?(controller)
        })
    }
    
    openChannelsSelectionImpl = {
        let state = stateValue.with { $0 }
        
        let stateContext = ShareWithPeersScreen.StateContext(
            context: context,
            subject: .channels(exclude: Set([peerId])),
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
    
    openPremiumIntroImpl = {
        let controller = context.sharedContext.makePremiumIntroController(context: context, source: .settings, forceDark: false, dismissed: nil)
        pushControllerImpl?(controller)
    }
    
    return controller
}
