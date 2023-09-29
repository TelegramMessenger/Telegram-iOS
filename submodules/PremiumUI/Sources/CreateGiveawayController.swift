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

private final class CreateGiveawayControllerArguments {
    let context: AccountContext
    let updateState: ((CreateGiveawayControllerState) -> CreateGiveawayControllerState) -> Void
    let dismissInput: () -> Void
    let openPeersSelection: () -> Void
    let openChannelsSelection: () -> Void
    
    init(context: AccountContext, updateState: @escaping ((CreateGiveawayControllerState) -> CreateGiveawayControllerState) -> Void, dismissInput: @escaping () -> Void, openPeersSelection: @escaping () -> Void, openChannelsSelection: @escaping () -> Void) {
        self.context = context
        self.updateState = updateState
        self.dismissInput = dismissInput
        self.openPeersSelection = openPeersSelection
        self.openChannelsSelection = openChannelsSelection
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
    
    case subscriptionsHeader(PresentationTheme, String)
    case subscriptions(PresentationTheme, Int32)
    case subscriptionsInfo(PresentationTheme, String)
    
    case channelsHeader(PresentationTheme, String)
    case channel(Int32, PresentationTheme, EnginePeer, Int32)
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
    case duration(Int32, PresentationTheme, String, String, String, String, String?, Bool)
    case durationInfo(PresentationTheme, String)
    
    var section: ItemListSectionId {
        switch self {
        case .header:
            return CreateGiveawaySection.header.rawValue
        case .createGiveaway, .awardUsers:
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
            case .subscriptionsHeader:
                return 2
            case .subscriptions:
                return 3
            case .subscriptionsInfo:
                return 4
            case .channelsHeader:
                return 5
            case let .channel(index, _, _, _):
                return 6 + index
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
        case let .subscriptionsHeader(lhsTheme, lhsText):
            if case let .subscriptionsHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
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
        case let .duration(lhsIndex, lhsTheme, lhsProductId, lhsTitle, lhsSubtitle, lhsLabel, lhsBadge, lhsIsSelected):
            if case let .duration(rhsIndex, rhsTheme, rhsProductId, rhsTitle, rhsSubtitle, rhsLabel, rhsBadge, rhsIsSelected) = rhs, lhsIndex == rhsIndex, lhsTheme === rhsTheme, lhsProductId == rhsProductId, lhsTitle == rhsTitle, lhsSubtitle == rhsSubtitle, lhsLabel == rhsLabel, lhsBadge == rhsBadge, lhsIsSelected == rhsIsSelected {
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
            return CreateGiveawayHeaderItem(theme: presentationData.theme, title: title, text: text, sectionId: self.section)
        case let .createGiveaway(_, title, subtitle, isSelected):
            return GiftModeItem(presentationData: presentationData, context: arguments.context, iconName: "Premium/Giveaway", title: title, subtitle: subtitle, label: nil, badge: nil, isSelected: isSelected, sectionId: self.section, action: {
                arguments.updateState { state in
                    var updatedState = state
                    updatedState.mode = .giveaway
                    return updatedState
                }
            })
        case let .awardUsers(_, title, subtitle, isSelected):
            return GiftModeItem(presentationData: presentationData, context: arguments.context, iconName: "Media Editor/Privacy/SelectedUsers", title: title, subtitle: subtitle, subtitleActive: true, label: nil, badge: nil, isSelected: isSelected, sectionId: self.section, action: {
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
        case let .subscriptionsHeader(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .subscriptions(_, value):
            let text = "\(value) Subscriptions / Boosts"
            return SubscriptionsCountItem(theme: presentationData.theme, strings: presentationData.strings, text: text, value: value, range: 1 ..< 11, sectionId: self.section, updated: { value in
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
            return ItemListPeerItem(presentationData: presentationData, dateTimeFormat: PresentationDateTimeFormat(), nameDisplayOrder: presentationData.nameDisplayOrder, context: arguments.context, peer: peer, presence: nil, text: .text("this channel will receive \(boosts) boosts", .secondary), label: .none, editing: ItemListPeerItemEditing(editable: false, editing: false, revealed: false), switchValue: nil, enabled: true, selectable: peer.id != arguments.context.account.peerId, sectionId: self.section, action: {
//                arguments.openPeer(peer)
            }, setPeerIdWithRevealedOptions: { _, _ in }, removePeer: { _ in })
        case let .channelAdd(theme, text):
            return ItemListPeerActionItem(presentationData: presentationData, icon: PresentationResourcesItemList.roundPlusIconImage(theme), title: text, alwaysPlain: false, hasSeparator: true, sectionId: self.section, height: .generic, color: .accent, editing: false, action: {
                arguments.openChannelsSelection()
            })
        case let .channelsInfo(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .usersHeader(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .usersAll(_, title, isSelected):
            return GiftModeItem(presentationData: presentationData, context: arguments.context, title: title, subtitle: nil, label: nil, badge: nil, isSelected: isSelected, sectionId: self.section, action: {
                arguments.updateState { state in
                    var updatedState = state
                    updatedState.onlyNewEligible = false
                    return updatedState
                }
            })
        case let .usersNew(_, title, isSelected):
            return GiftModeItem(presentationData: presentationData, context: arguments.context, title: title, subtitle: nil, label: nil, badge: nil, isSelected: isSelected, sectionId: self.section, action: {
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
        case let .duration(_, _, productId, title, subtitle, label, badge, isSelected):
            return GiftModeItem(presentationData: presentationData, context: arguments.context, title: title, subtitle: subtitle, label: label, badge: badge, isSelected: isSelected, sectionId: self.section, action: {
                arguments.updateState { state in
                    var updatedState = state
                    updatedState.selectedProductId = productId
                    return updatedState
                }
            })
        case let .durationInfo(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .markdown(text), sectionId: self.section)
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

private func createGiveawayControllerEntries(state: CreateGiveawayControllerState, presentationData: PresentationData, peers: [EnginePeer.Id: EnginePeer], products: [PremiumGiftProduct]) -> [CreateGiveawayEntry] {
    var entries: [CreateGiveawayEntry] = []
    
    entries.append(.header(presentationData.theme, "Boosts via Gifts", "Get more boosts for your channel by gifting\nPremium to your subscribers."))
    
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
    
    if case .giveaway = state.mode {
        entries.append(.subscriptionsHeader(presentationData.theme, "QUANTITY OF PRIZES / BOOSTS".uppercased()))
        entries.append(.subscriptions(presentationData.theme, state.subscriptions))
        entries.append(.subscriptionsInfo(presentationData.theme, "Choose how many Premium subscriptions to give away and boosts to receive."))
        
        entries.append(.channelsHeader(presentationData.theme, "CHANNELS INCLUDED IN THE GIVEAWAY".uppercased()))
        var index: Int32 = 0
        for peerId in state.channels {
            if let peer = peers[peerId] {
                entries.append(.channel(index, presentationData.theme, peer, state.subscriptions))
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
                
    entries.append(.durationHeader(presentationData.theme, "DURATION OF PREMIUM SUBSCRIPTIONS".uppercased()))
    
    let recipientCount: Int
    switch state.mode {
    case .giveaway:
        recipientCount = Int(state.subscriptions)
    case .gift:
        recipientCount = state.peers.count
    }
    
    let shortestOptionPrice: (Int64, NSDecimalNumber)
    if let product = products.last {
        shortestOptionPrice = (Int64(Float(product.storeProduct.priceCurrencyAndAmount.amount) / Float(product.months)), product.storeProduct.priceValue.dividing(by: NSDecimalNumber(value: product.months)))
    } else {
        shortestOptionPrice = (1, NSDecimalNumber(decimal: 1))
    }
    
    var i: Int32 = 0
    for product in products {
        let giftTitle: String
        if product.months == 12 {
            giftTitle = presentationData.strings.Premium_Gift_Years(1)
        } else {
            giftTitle = presentationData.strings.Premium_Gift_Months(product.months)
        }
        
        let discountValue = Int((1.0 - Float(product.storeProduct.priceCurrencyAndAmount.amount) / Float(product.months) / Float(shortestOptionPrice.0)) * 100.0)
        let discount: String?
        if discountValue > 0 {
            discount = "-\(discountValue)%"
        } else {
            discount = nil
        }
        
        let subtitle = "\(product.storeProduct.price) x \(recipientCount)"
        let label = product.storeProduct.multipliedPrice(count: recipientCount)
      
        var isSelected = false
        if let selectedProductId = state.selectedProductId {
            isSelected = product.id == selectedProductId
        } else if i == 0 {
            isSelected = true
        }
        
        entries.append(.duration(i, presentationData.theme, product.id, giftTitle, subtitle, label, discount, isSelected))
       
        i += 1
    }
    
//    entries.append(.duration(0, presentationData.theme, "3 Months", "$13.99 x \(state.subscriptions)", "$41.99", nil, true))
//    entries.append(.duration(1, presentationData.theme, "6 Months", "$15.99 x \(state.subscriptions)", "$47.99", nil, false))
//    entries.append(.duration(2, presentationData.theme, "1 Year", "$29.99 x \(state.subscriptions)", "$89.99", nil, false))
    
    entries.append(.durationInfo(presentationData.theme, "You can review the list of features and terms of use for Telegram Premium [here]()."))
    
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
    var selectedProductId: String?
    var onlyNewEligible: Bool
    var time: Int32
    var pickingTimeLimit = false
    var updating = false
}

public func createGiveawayController(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, peerId: EnginePeer.Id, completion: (() -> Void)? = nil) -> ViewController {
    let actionsDisposable = DisposableSet()
    
    let expiryTime = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970) + 86400 * 5
    let initialState: CreateGiveawayControllerState = CreateGiveawayControllerState(mode: .giveaway, subscriptions: 5, channels: [peerId], peers: [], onlyNewEligible: false, time: expiryTime)

    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((CreateGiveawayControllerState) -> CreateGiveawayControllerState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    let productsValue = Atomic<[PremiumGiftProduct]?>(value: nil)

    var buyActionImpl: (() -> Void)?
    var openPeersSelectionImpl: (() -> Void)?
    var openChannelsSelectionImpl: (() -> Void)?
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
    })
    
    let presentationData = updatedPresentationData?.signal ?? context.sharedContext.presentationData
    
    let products = combineLatest(
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
        return gifts
    }
    
    let previousState = Atomic<CreateGiveawayControllerState?>(value: nil)
    let signal = combineLatest(
        presentationData,
        statePromise.get()
        |> mapToSignal { state in
            return context.engine.data.get(EngineDataMap(
                Set(state.channels + state.peers).map {
                    TelegramEngine.EngineData.Item.Peer.Peer(id: $0)
                }
            ))
            |> map { peers in
                return (state, peers)
            }
        },
        products
    )
    |> deliverOnMainQueue
    |> map { presentationData, stateAndPeersMap, products -> (ItemListControllerState, (ItemListNodeState, Any)) in
        var presentationData = presentationData
        
        let updatedTheme = presentationData.theme.withModalBlocksBackground()
        presentationData = presentationData.withUpdated(theme: updatedTheme)
        
        let (state, peersMap) = stateAndPeersMap
                
        let footerItem = CreateGiveawayFooterItem(theme: presentationData.theme, title: state.mode == .gift ? "Gift Premium" : "Start Giveaway", action: {
            buyActionImpl?()
        })
        let leftNavigationButton = ItemListNavigationButton(content: .text(presentationData.strings.Common_Cancel), style: .regular, enabled: true, action: {
            dismissImpl?()
        })
        
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
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: createGiveawayControllerEntries(state: state, presentationData: presentationData, peers: peers, products: products), style: .blocks, emptyStateItem: nil, footerItem: footerItem, crossfadeState: false, animateChanges: animateChanges)
        
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
    
    buyActionImpl = {
        let state = stateValue.with { $0 }
        guard let products = productsValue.with({ $0 }) else {
            return
        }
        
        let selectedProduct: PremiumGiftProduct
        if let selectedProductId = state.selectedProductId, let product = products.first(where: { $0.id == selectedProductId }) {
            selectedProduct = product
        } else {
            selectedProduct = products.first!
        }
        
        let (currency, amount) = selectedProduct.storeProduct.priceCurrencyAndAmount
        
        let purpose: AppStoreTransactionPurpose
        switch state.mode {
        case .giveaway:
            purpose = .giveaway(boostPeer: peerId, randomId: 1000, untilDate: state.time, currency: currency, amount: amount)
        case .gift:
            purpose = .giftCode(peerIds: state.peers, boostPeer: peerId, currency: currency, amount: amount)
        }
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        let _ = (context.engine.payments.canPurchasePremium(purpose: purpose)
        |> deliverOnMainQueue).startStandalone(next: { available in
            if available, let inAppPurchaseManager = context.inAppPurchaseManager {
                let _ = (inAppPurchaseManager.buyProduct(selectedProduct.storeProduct, purpose: purpose)
                |> deliverOnMainQueue).startStandalone(next: { status in
                    if case .purchased = status {
                        dismissImpl?()
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
                })
            } else {
                let alertController = textAlertController(context: context, updatedPresentationData: updatedPresentationData, title: nil, text: presentationData.strings.Premium_Purchase_ErrorUnknown, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})])
                presentControllerImpl?(alertController)
            }
        })
    }
    
    openPeersSelectionImpl = {
        let state = stateValue.with { $0 }
        
        let stateContext = ShareWithPeersScreen.StateContext(
            context: context,
            subject: .members(peerId: peerId),
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
                        return updatedState
                    }
                }
            )
            pushControllerImpl?(controller)
        })
    }
    
    openChannelsSelectionImpl = {
        let controller = context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: context, requestPeerType: [ReplyMarkupButtonRequestPeerType.channel(ReplyMarkupButtonRequestPeerType.Channel(isCreator: false, hasUsername: nil, userAdminRights: TelegramChatAdminRights(rights: [.canChangeInfo]), botAdminRights: nil))]))
        controller.peerSelected = { [weak controller] peer, _ in
            updateState { state in
                var updatedState = state
                var channels = state.channels
                channels.append(peer.id)
                updatedState.channels = channels
                return updatedState
            }
            controller?.dismiss()
        }
        pushControllerImpl?(controller)
    }
    
    return controller
}
