import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import TelegramStringFormatting
import ItemListUI
import PresentationDataUtils
import AccountContext
import UndoUI
import PremiumUI
import MessagePriceItem

private final class IncomingMessagePrivacyScreenArguments {
    let context: AccountContext
    let updateValue: (GlobalPrivacySettings.NonContactChatsPrivacy) -> Void
    let disabledValuePressed: () -> Void
    let infoLinkAction: () -> Void
    let openExceptions: () -> Void
    let openPremiumInfo: () -> Void
    let openSetCustomStarsAmount: () -> Void
    
    init(
        context: AccountContext,
        updateValue: @escaping (GlobalPrivacySettings.NonContactChatsPrivacy) -> Void,
        disabledValuePressed: @escaping () -> Void,
        infoLinkAction: @escaping () -> Void,
        openExceptions: @escaping () -> Void,
        openPremiumInfo: @escaping () -> Void,
        openSetCustomStarsAmount: @escaping () -> Void
    ) {
        self.context = context
        self.updateValue = updateValue
        self.disabledValuePressed = disabledValuePressed
        self.infoLinkAction = infoLinkAction
        self.openExceptions = openExceptions
        self.openPremiumInfo = openPremiumInfo
        self.openSetCustomStarsAmount = openSetCustomStarsAmount
    }
}

private enum IncomingMessagePrivacySection: Int32 {
    case header
    case info
    case price
    case exceptions
}

private enum GlobalAutoremoveEntry: ItemListNodeEntry {
    case header
    case optionEverybody(value: GlobalPrivacySettings.NonContactChatsPrivacy)
    case optionPremium(value: GlobalPrivacySettings.NonContactChatsPrivacy, isEnabled: Bool)
    case optionChargeForMessages(value: GlobalPrivacySettings.NonContactChatsPrivacy, isEnabled: Bool)
    case footer(value: GlobalPrivacySettings.NonContactChatsPrivacy)
    case priceHeader
    case price(value: Int64, maxValue: Int64, price: String, isEnabled: Bool)
    case priceInfo(commission: Int32, value: String)
    case exceptionsHeader
    case exceptions(count: Int)
    case exceptionsInfo
    case info
    
    var section: ItemListSectionId {
        switch self {
        case .header, .optionEverybody, .optionPremium, .optionChargeForMessages, .footer:
            return IncomingMessagePrivacySection.header.rawValue
        case .info:
            return IncomingMessagePrivacySection.info.rawValue
        case .priceHeader, .price, .priceInfo:
            return IncomingMessagePrivacySection.price.rawValue
        case .exceptionsHeader, .exceptions, .exceptionsInfo:
            return IncomingMessagePrivacySection.exceptions.rawValue
        }
    }
    
    var stableId: Int {
        return self.sortIndex
    }

    var sortIndex: Int {
        switch self {
        case .header:
            return 0
        case .optionEverybody:
            return 1
        case .optionPremium:
            return 2
        case .optionChargeForMessages:
            return 3
        case .footer:
            return 4
        case .info:
            return 5
        case .priceHeader:
            return 6
        case .price:
            return 7
        case .priceInfo:
            return 8
        case .exceptionsHeader:
            return 9
        case .exceptions:
            return 10
        case .exceptionsInfo:
            return 11
        }
    }
    
    static func <(lhs: GlobalAutoremoveEntry, rhs: GlobalAutoremoveEntry) -> Bool {
        return lhs.sortIndex < rhs.sortIndex
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! IncomingMessagePrivacyScreenArguments
        switch self {
        case .header:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: presentationData.strings.Privacy_Messages_SectionTitle, sectionId: self.section)
        case let .optionEverybody(value):
            return ItemListCheckboxItem(presentationData: presentationData, title: presentationData.strings.Privacy_Messages_ValueEveryone, style: .left, checked: value == .everybody, zeroSeparatorInsets: false, sectionId: self.section, action: {
                arguments.updateValue(.everybody)
            })
        case let .optionPremium(value, isEnabled):
            return ItemListCheckboxItem(presentationData: presentationData, icon: isEnabled ? nil : generateTintedImage(image: UIImage(bundleImageName: "Chat/Stickers/Lock"), color: presentationData.theme.list.itemSecondaryTextColor), iconPlacement: .check, title: presentationData.strings.Privacy_Messages_ValueContactsAndPremium, style: .left, checked: isEnabled && value == .requirePremium, zeroSeparatorInsets: false, sectionId: self.section, action: {
                if isEnabled {
                    arguments.updateValue(.requirePremium)
                } else {
                    arguments.disabledValuePressed()
                }
            })
        case let .optionChargeForMessages(value, isEnabled):
            var isChecked = false
            if case .paidMessages = value  {
                isChecked = true
            }
            return ItemListCheckboxItem(presentationData: presentationData, icon: isEnabled || isChecked ? nil : generateTintedImage(image: UIImage(bundleImageName: "Chat/Stickers/Lock"), color: presentationData.theme.list.itemSecondaryTextColor), iconPlacement: .check, title: presentationData.strings.Privacy_Messages_ChargeForMessages, style: .left, checked: isChecked, zeroSeparatorInsets: false, sectionId: self.section, action: {
                arguments.updateValue(.paidMessages(StarsAmount(value: 400, nanos: 0)))
            })
        case let .footer(value):
            let text: String
            if case .paidMessages = value {
                text = presentationData.strings.Privacy_Messages_ChargeForMessagesInfo
            } else {
                text = presentationData.strings.Privacy_Messages_SectionFooter
            }
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case .info:
            return ItemListTextItem(presentationData: presentationData, text: .markdown(presentationData.strings.Privacy_Messages_PremiumInfoFooter), sectionId: self.section, linkAction: { _ in
                arguments.infoLinkAction()
            })
        case .priceHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: presentationData.strings.Privacy_Messages_MessagePrice, sectionId: self.section)
        case let .price(value, maxValue, price, isEnabled):
            return MessagePriceItem(theme: presentationData.theme, strings: presentationData.strings, isEnabled: isEnabled, minValue: 1, maxValue: maxValue, value: value, price: price, sectionId: self.section, updated: { value, _ in
                arguments.updateValue(.paidMessages(StarsAmount(value: value, nanos: 0)))
            }, openSetCustom: {
                arguments.openSetCustomStarsAmount()
            }, openPremiumInfo: {
                arguments.openPremiumInfo()
            })
        case let .priceInfo(commission, value):
            return ItemListTextItem(presentationData: presentationData, text: .markdown(presentationData.strings.Privacy_Messages_MessagePriceInfo("\(commission)", value).string), sectionId: self.section)
        case .exceptionsHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: presentationData.strings.Privacy_Messages_RemoveFeeHeader, sectionId: self.section)
        case let .exceptions(count):
            return ItemListDisclosureItem(presentationData: presentationData, title: presentationData.strings.Privacy_Messages_RemoveFee, label: count > 0 ? "\(count)" : "", sectionId: self.section, style: .blocks, action: {
                arguments.openExceptions()
            })
        case .exceptionsInfo:
            return ItemListTextItem(presentationData: presentationData, text: .markdown(presentationData.strings.Privacy_Messages_RemoveFeeInfo), sectionId: self.section)
        }
    }
}

private struct IncomingMessagePrivacyScreenState: Equatable {
    var updatedValue: GlobalPrivacySettings.NonContactChatsPrivacy
    var disableFor: [EnginePeer.Id: SelectivePrivacyPeer]
}

private func incomingMessagePrivacyScreenEntries(presentationData: PresentationData, state: IncomingMessagePrivacyScreenState, enableSetting: Bool, isPremium: Bool, configuration: StarsSubscriptionConfiguration) -> [GlobalAutoremoveEntry] {
    var entries: [GlobalAutoremoveEntry] = []
    
    entries.append(.header)
    entries.append(.optionEverybody(value: state.updatedValue))
    entries.append(.optionPremium(value: state.updatedValue, isEnabled: enableSetting))
    if configuration.paidMessagesAvailable {
        entries.append(.optionChargeForMessages(value: state.updatedValue, isEnabled: isPremium))
    }
    
    if case let .paidMessages(amount) = state.updatedValue {
        entries.append(.footer(value: state.updatedValue))
        entries.append(.priceHeader)
        
        let usdRate = Double(configuration.usdWithdrawRate) / 1000.0 / 100.0
        
        let price = "≈\(formatTonUsdValue(amount.value, divide: false, rate: usdRate, dateTimeFormat: presentationData.dateTimeFormat))"
        
        entries.append(.price(value: amount.value, maxValue: configuration.paidMessageMaxAmount, price: price, isEnabled: isPremium))
        entries.append(.priceInfo(commission: configuration.paidMessageCommissionPermille / 10, value: price))
        
        if isPremium {
            entries.append(.exceptionsHeader)
            entries.append(.exceptions(count: state.disableFor.count))
            entries.append(.exceptionsInfo)
        }
    } else {
        entries.append(.footer(value: state.updatedValue))
        entries.append(.info)
    }
    
    return entries
}

public func incomingMessagePrivacyScreen(context: AccountContext, value: GlobalPrivacySettings.NonContactChatsPrivacy, exceptions: SelectivePrivacySettings, update: @escaping (GlobalPrivacySettings.NonContactChatsPrivacy) -> Void) -> ViewController {
    var disableFor: [EnginePeer.Id: SelectivePrivacyPeer] = [:]
    if case let .enableContacts(value, _, _, _) = exceptions {
        disableFor = value
    }
    let initialState = IncomingMessagePrivacyScreenState(
        updatedValue: value,
        disableFor: disableFor
    )
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    let stateValue = Atomic(value: initialState)
    let updateState: ((IncomingMessagePrivacyScreenState) -> IncomingMessagePrivacyScreenState) -> Void = { f in
        statePromise.set(stateValue.modify { f($0) })
    }
    
    let configuration = StarsSubscriptionConfiguration.with(appConfiguration: context.currentAppConfiguration.with { $0 })
    
    var presentControllerImpl: ((ViewController, ViewControllerPresentationArguments?) -> Void)?
    var presentInCurrentControllerImpl: ((ViewController) -> Void)?
    var pushControllerImpl: ((ViewController) -> Void)?
    var dismissImpl: (() -> Void)?
    
    let _ = dismissImpl
    let _ = pushControllerImpl
    let _ = presentControllerImpl
    
    let actionsDisposable = DisposableSet()
    
    let addPeerDisposable = MetaDisposable()
    actionsDisposable.add(addPeerDisposable)
    
    let updateTimeoutDisposable = MetaDisposable()
    actionsDisposable.add(updateTimeoutDisposable)
    
    let presentationData = context.sharedContext.currentPresentationData.with({ $0 })
    let arguments = IncomingMessagePrivacyScreenArguments(
        context: context,
        updateValue: { value in
            updateState { state in
                var state = state
                state.updatedValue = value
                return state
            }
        },
        disabledValuePressed: {
            presentInCurrentControllerImpl?(UndoOverlayController(presentationData: presentationData, content: .premiumPaywall(title: presentationData.strings.Privacy_Messages_PremiumToast_Title, text: presentationData.strings.Privacy_Messages_PremiumToast_Text, customUndoText: presentationData.strings.Privacy_Messages_PremiumToast_Action, timeout: nil, linkAction: { _ in
            }), elevatedLayout: false, action: { action in
                if case .undo = action {
                    let controller = PremiumIntroScreen(context: context, source: .settings)
                    pushControllerImpl?(controller)
                }
                return false
            }))
        },
        infoLinkAction: {
            let controller = PremiumIntroScreen(context: context, source: .settings)
            pushControllerImpl?(controller)
        },
        openExceptions: {
            var peerIds: [EnginePeer.Id: SelectivePrivacyPeer] = [:]
            updateState { state in
                peerIds = state.disableFor
                return state
            }
            
            if peerIds.isEmpty {
                let controller = context.sharedContext.makeContactMultiselectionController(ContactMultiselectionControllerParams(context: context, mode: .chatSelection(ContactMultiselectionControllerMode.ChatSelection(
                    title: presentationData.strings.PrivacySettings_SearchUsersTitle,
                    searchPlaceholder: presentationData.strings.PrivacySettings_SearchUsersPlaceholder,
                    selectedChats: Set(),
                    additionalCategories: ContactMultiselectionControllerAdditionalCategories(categories: [], selectedCategories: Set()),
                    chatListFilters: nil,
                    onlyUsers: false,
                    disableChannels: true,
                    disableBots: true,
                    disableContacts: true
                ))))
                addPeerDisposable.set((controller.result
                |> take(1)
                |> deliverOnMainQueue).start(next: { [weak controller] result in
                    var peerIds: [ContactListPeerId] = []
                    if case let .result(peerIdsValue, _) = result {
                        peerIds = peerIdsValue
                    }
                    if peerIds.isEmpty {
                        controller?.dismiss()
                        return
                    }
                    let filteredIds = peerIds.compactMap { peerId -> EnginePeer.Id? in
                        if case let .peer(value) = peerId {
                            return value
                        } else {
                            return nil
                        }
                    }
                    let _ = (context.engine.data.get(
                        EngineDataMap(filteredIds.map(TelegramEngine.EngineData.Item.Peer.Peer.init)),
                        EngineDataMap(filteredIds.map(TelegramEngine.EngineData.Item.Peer.ParticipantCount.init))
                    )
                    |> map { peerMap, participantCountMap -> [EnginePeer.Id: SelectivePrivacyPeer] in
                        var updatedPeers: [EnginePeer.Id: SelectivePrivacyPeer] = [:]
                        var existingIds = Set(updatedPeers.values.map { $0.peer.id })
                        for peerId in peerIds {
                            guard case let .peer(peerId) = peerId else {
                                continue
                            }
                            if let maybePeer = peerMap[peerId], let peer = maybePeer, !existingIds.contains(peerId) {
                                existingIds.insert(peerId)
                                var participantCount: Int32?
                                if case let .channel(channel) = peer, case .group = channel.info {
                                    if let maybeParticipantCount = participantCountMap[peerId], let participantCountValue = maybeParticipantCount {
                                        participantCount = Int32(participantCountValue)
                                    }
                                }
                                
                                updatedPeers[peer.id] = SelectivePrivacyPeer(peer: peer._asPeer(), participantCount: participantCount)
                            }
                        }
                        return updatedPeers
                    }
                    |> deliverOnMainQueue).start(next: { updatedPeerIds in
                        controller?.dismiss()
                        
                        updateState { state in
                            var updatedState = state
                            updatedState.disableFor = updatedPeerIds
                            return updatedState
                        }
                        
                        let settings: SelectivePrivacySettings = .enableContacts(enableFor: updatedPeerIds, disableFor: [:], enableForPremium: false, enableForBots: false)
                        let _ = context.engine.privacy.updateSelectiveAccountPrivacySettings(type: .noPaidMessages, settings: settings).start()
                    })
                }))
                controller.navigationPresentation = .modal
                pushControllerImpl?(controller)
            } else {
                let controller = selectivePrivacyPeersController(context: context, title: presentationData.strings.Privacy_Messages_Exceptions_Title, footer: presentationData.strings.Privacy_Messages_RemoveFeeInfo, hideContacts: true, initialPeers: peerIds, initialEnableForPremium: false, displayPremiumCategory: false, initialEnableForBots: false, displayBotsCategory: false, updated: { updatedPeerIds, _, _ in
                    updateState { state in
                        var updatedState = state
                        updatedState.disableFor = updatedPeerIds
                        return updatedState
                    }
                    let settings: SelectivePrivacySettings = .enableContacts(enableFor: updatedPeerIds, disableFor: [:], enableForPremium: false, enableForBots: false)
                    let _ = context.engine.privacy.updateSelectiveAccountPrivacySettings(type: .noPaidMessages, settings: settings).start()
                })
                pushControllerImpl?(controller)
            }
        },
        openPremiumInfo: {
            var replaceImpl: ((ViewController) -> Void)?
            let controller = context.sharedContext.makePremiumDemoController(context: context, subject: .messagePrivacy, forceDark: false, action: {
                let controller = context.sharedContext.makePremiumIntroController(context: context, source: .messageEffects, forceDark: false, dismissed: nil)
                replaceImpl?(controller)
            }, dismissed: nil)
            replaceImpl = { [weak controller] c in
                controller?.replace(with: c)
            }
            pushControllerImpl?(controller)
        },
        openSetCustomStarsAmount: {
            var currentAmount: StarsAmount = StarsAmount(value: 1, nanos: 0)
            if case let .paidMessages(value) = stateValue.with({ $0 }).updatedValue {
                currentAmount = value
            }
            let starsScreen = context.sharedContext.makeStarsWithdrawalScreen(context: context, subject: .enterAmount(
                current: currentAmount,
                minValue: StarsAmount(value: 1, nanos: 0),
                fractionAfterCommission: 80, kind: .privacy,
                completion: { amount in
                    updateState { state in
                        var state = state
                        state.updatedValue = .paidMessages(StarsAmount(value: amount, nanos: 0))
                        return state
                    }
                }
            ))
            pushControllerImpl?(starsScreen)
        }
    )
    
    let enableSetting: Signal<Bool, NoError> = context.engine.data.subscribe(
        TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId),
        TelegramEngine.EngineData.Item.Configuration.App()
    )
    |> map { accountPeer, appConfig -> Bool in
        if let accountPeer, accountPeer.isPremium {
            return true
        }
        if let data = appConfig.data, let setting = data["new_noncontact_peers_require_premium_without_ownpremium"] as? Bool {
            if setting {
                return true
            }
        }
        return false
    }
    |> distinctUntilChanged
    
    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        statePromise.get(),
        enableSetting
    )
    |> map { presentationData, state, enableSetting -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let rightNavigationButton: ItemListNavigationButton? = nil
        
        let title: ItemListControllerTitle = .text(presentationData.strings.Privacy_Messages_Title)
        
        let entries: [GlobalAutoremoveEntry] = incomingMessagePrivacyScreenEntries(presentationData: presentationData, state: state, enableSetting: enableSetting, isPremium: context.isPremium, configuration: configuration)
        
        let animateChanges = false
        
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: title, leftNavigationButton: nil, rightNavigationButton: rightNavigationButton, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: true)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, emptyStateItem: nil, crossfadeState: false, animateChanges: animateChanges, scrollEnabled: true)
        
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
        actionsDisposable.dispose()
    }
    
    let controller = ItemListController(context: context, state: signal)
    presentControllerImpl = { [weak controller] c, p in
        guard let controller else {
            return
        }
        controller.present(c, in: .window(.root), with: p)
    }
    presentInCurrentControllerImpl = { [weak controller] c in
        guard let controller else {
            return
        }
        
        controller.forEachController { c in
            if let c = c as? UndoOverlayController {
                c.dismiss()
            }
            return true
        }
        controller.present(c, in: .current, with: nil)
    }
    pushControllerImpl = { [weak controller] c in
        controller?.push(c)
    }
    controller.attemptNavigation = { _ in
        let updatedValue = stateValue.with({ $0 }).updatedValue
        if !context.isPremium, case .paidMessages = updatedValue {
            
        } else {
            update(updatedValue)
        }
        return true
    }
    dismissImpl = { [weak controller] in
        controller?.dismiss()
    }
    
    return controller
}
