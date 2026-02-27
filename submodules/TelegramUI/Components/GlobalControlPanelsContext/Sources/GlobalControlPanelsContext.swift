import Foundation
import UIKit
import SwiftSignalKit
import TelegramCore
import AccountContext
import TelegramUIPreferences
import TelegramCallsUI
import Display
import UndoUI

public final class GlobalControlPanelsContext {
    public final class MediaPlayback: Equatable {
        public let version: Int
        public let item: SharedMediaPlaylistItem
        public let previousItem: SharedMediaPlaylistItem?
        public let nextItem: SharedMediaPlaylistItem?
        public let playbackOrder: MusicPlaybackSettingsOrder
        public let kind: MediaManagerPlayerType
        public let playlistLocation: SharedMediaPlaylistLocation
        public let account: Account
        
        public init(version: Int, item: SharedMediaPlaylistItem, previousItem: SharedMediaPlaylistItem?, nextItem: SharedMediaPlaylistItem?, playbackOrder: MusicPlaybackSettingsOrder, kind: MediaManagerPlayerType, playlistLocation: SharedMediaPlaylistLocation, account: Account) {
            self.version = version
            self.item = item
            self.previousItem = previousItem
            self.nextItem = nextItem
            self.playbackOrder = playbackOrder
            self.kind = kind
            self.playlistLocation = playlistLocation
            self.account = account
        }
        
        public static func ==(lhs: MediaPlayback, rhs: MediaPlayback) -> Bool {
            if lhs.version != rhs.version {
                return false
            }
            return true
        }
    }
    
    public enum LiveLocationMode {
        case all
        case peer(EnginePeer.Id)
    }
    
    public final class LiveLocation: Equatable {
        public let mode: LiveLocationMode
        public let peers: [EnginePeer]
        public let messages: [EngineMessage.Id: EngineMessage]
        public let canClose: Bool
        public let version: Int
        
        public init(mode: LiveLocationMode, peers: [EnginePeer], messages: [EngineMessage.Id: EngineMessage], canClose: Bool, version: Int) {
            self.mode = mode
            self.peers = peers
            self.messages = messages
            self.canClose = canClose
            self.version = version
        }
        
        public static func ==(lhs: LiveLocation, rhs: LiveLocation) -> Bool {
            if lhs.version != rhs.version {
                return false
            }
            return true
        }
    }
    
    public enum ChatListNotice: Equatable {
        case clearStorage(sizeFraction: Double)
        case setupPassword
        case premiumUpgrade(discount: Int32)
        case premiumAnnualDiscount(discount: Int32)
        case premiumRestore(discount: Int32)
        case xmasPremiumGift
        case setupBirthday
        case birthdayPremiumGift(peers: [EnginePeer], birthdays: [EnginePeer.Id: TelegramBirthday])
        case reviewLogin(newSessionReview: NewSessionReview, totalCount: Int)
        case premiumGrace
        case starsSubscriptionLowBalance(amount: StarsAmount, peers: [EnginePeer])
        case setupPhoto(EnginePeer)
        case accountFreeze
        case link(id: String, url: String, title: ServerSuggestionInfo.Item.Text, subtitle: ServerSuggestionInfo.Item.Text)
    }
    
    public final class GroupCall: Equatable {
        public let peerId: EnginePeer.Id
        public let isChannel: Bool
        public let info: GroupCallInfo
        public let topParticipants: [GroupCallParticipantsContext.Participant]
        public let participantCount: Int
        public let activeSpeakers: Set<EnginePeer.Id>
        public let groupCall: PresentationGroupCall?
        
        public init(
            peerId: EnginePeer.Id,
            isChannel: Bool,
            info: GroupCallInfo,
            topParticipants: [GroupCallParticipantsContext.Participant],
            participantCount: Int,
            activeSpeakers: Set<EnginePeer.Id>,
            groupCall: PresentationGroupCall?
        ) {
            self.peerId = peerId
            self.isChannel = isChannel
            self.info = info
            self.topParticipants = topParticipants
            self.participantCount = participantCount
            self.activeSpeakers = activeSpeakers
            self.groupCall = groupCall
        }
        
        public static func ==(lhs: GroupCall, rhs: GroupCall) -> Bool {
            if lhs.peerId != rhs.peerId {
                return false
            }
            if lhs.isChannel != rhs.isChannel {
                return false
            }
            if lhs.info != rhs.info {
                return false
            }
            if lhs.topParticipants != rhs.topParticipants {
                return false
            }
            if lhs.participantCount != rhs.participantCount {
                return false
            }
            if lhs.activeSpeakers != rhs.activeSpeakers {
                return false
            }
            if lhs.groupCall !== rhs.groupCall {
                return false
            }
            return true
        }
    }

    public final class State {
        public let mediaPlayback: MediaPlayback?
        public let liveLocation: LiveLocation?
        public let chatListNotice: ChatListNotice?
        public let groupCall: GroupCall?

        public init(
            mediaPlayback: MediaPlayback?,
            liveLocation: LiveLocation?,
            chatListNotice: ChatListNotice?,
            groupCall: GroupCall?
        ) {
            self.mediaPlayback = mediaPlayback
            self.liveLocation = liveLocation
            self.chatListNotice = chatListNotice
            self.groupCall = groupCall
        }
    }

    private final class Impl {
        let queue: Queue
        let context: AccountContext
        
        private(set) var stateValue: State
        let statePipe = ValuePipe<State>()
        
        private var nextVersion: Int = 0

        var tempVoicePlaylistEnded: (() -> Void)?
        var tempVoicePlaylistItemChanged: ((SharedMediaPlaylistItem?, SharedMediaPlaylistItem?) -> Void)?
        var tempVoicePlaylistCurrentItem: SharedMediaPlaylistItem?
        
        var playlistStateAndType: (SharedMediaPlaylistItem, SharedMediaPlaylistItem?, SharedMediaPlaylistItem?, MusicPlaybackSettingsOrder, MediaManagerPlayerType, Account, SharedMediaPlaylistLocation, Int)?
        var mediaStatusDisposable: Disposable?
        
        var liveLocationState: (mode: LiveLocationMode, peers: [EnginePeer], messages: [EngineMessage.Id: EngineMessage], canClose: Bool, version: Int)?
        var liveLocationDisposable: Disposable?
        
        var chatListNotice: ChatListNotice?
        var suggestedChatListNoticeDisposable: Disposable?
        
        var groupCall: GroupCall?
        var currentGroupCallDisposable: Disposable?

        init(queue: Queue, context: AccountContext, mediaPlayback: Bool, liveLocationMode: LiveLocationMode?, groupCalls: EnginePeer.Id?, chatListNotices: Bool) {
            self.queue = queue
            self.context = context
            
            self.stateValue = State(mediaPlayback: nil, liveLocation: nil, chatListNotice: nil, groupCall: nil)

            if mediaPlayback {
                self.mediaStatusDisposable = (context.sharedContext.mediaManager.globalMediaPlayerState
                |> mapToSignal { playlistStateAndType -> Signal<(Account, SharedMediaPlayerItemPlaybackState, MediaManagerPlayerType)?, NoError> in
                    if let (account, state, type) = playlistStateAndType {
                        switch state {
                        case let .state(state):
                            return .single((account, state, type))
                        case .loading:
                            return .single(nil) |> delay(0.2, queue: .mainQueue())
                        }
                    } else {
                        return .single(nil)
                    }
                }
                |> deliverOnMainQueue).start(next: { [weak self] playlistStateAndType in
                    guard let strongSelf = self else {
                        return
                    }
                    if !arePlaylistItemsEqual(strongSelf.playlistStateAndType?.0, playlistStateAndType?.1.item) ||
                        !arePlaylistItemsEqual(strongSelf.playlistStateAndType?.1, playlistStateAndType?.1.previousItem) ||
                        !arePlaylistItemsEqual(strongSelf.playlistStateAndType?.2, playlistStateAndType?.1.nextItem) ||
                        strongSelf.playlistStateAndType?.3 != playlistStateAndType?.1.order || strongSelf.playlistStateAndType?.4 != playlistStateAndType?.2 {
                        var previousVoiceItem: SharedMediaPlaylistItem?
                        if let playlistStateAndType = strongSelf.playlistStateAndType, playlistStateAndType.4 == .voice {
                            previousVoiceItem = playlistStateAndType.0
                        }
                        
                        var updatedVoiceItem: SharedMediaPlaylistItem?
                        if let playlistStateAndType = playlistStateAndType, playlistStateAndType.2 == .voice {
                            updatedVoiceItem = playlistStateAndType.1.item
                        }
                        
                        strongSelf.tempVoicePlaylistCurrentItem = updatedVoiceItem
                        strongSelf.tempVoicePlaylistItemChanged?(previousVoiceItem, updatedVoiceItem)
                        if let playlistStateAndType = playlistStateAndType {
                            strongSelf.playlistStateAndType = (playlistStateAndType.1.item, playlistStateAndType.1.previousItem, playlistStateAndType.1.nextItem, playlistStateAndType.1.order, playlistStateAndType.2, playlistStateAndType.0, playlistStateAndType.1.playlistLocation, 0)
                        } else {
                            var voiceEnded = false
                            if strongSelf.playlistStateAndType?.4 == .voice {
                                voiceEnded = true
                            }
                            strongSelf.playlistStateAndType = nil
                            if voiceEnded {
                                strongSelf.tempVoicePlaylistEnded?()
                            }
                        }
                        strongSelf.playlistStateAndType?.7 = strongSelf.nextVersion
                        strongSelf.nextVersion += 1
                        strongSelf.notifyStateUpdated()
                    }
                })
            }
            
            if let liveLocationMode, let liveLocationManager = context.liveLocationManager {
                let signal: Signal<([EnginePeer]?, [EngineMessage.Id: EngineMessage]?), NoError>
                switch liveLocationMode {
                case let .peer(peerId):
                    signal = combineLatest(liveLocationManager.summaryManager.peersBroadcastingTo(peerId: peerId), liveLocationManager.summaryManager.broadcastingToMessages())
                    |> map { peersAndMessages, outgoingMessages in
                        var peers = peersAndMessages?.map { $0.0 }
                        for message in outgoingMessages.values {
                            if message.id.peerId == peerId, let author = message.author {
                                if peers == nil {
                                    peers = []
                                }
                                peers?.append(author)
                            }
                        }
                        return (peers, outgoingMessages)
                    }
                case .all:
                    signal = liveLocationManager.summaryManager.broadcastingToMessages()
                    |> map { messages -> ([EnginePeer]?, [EngineMessage.Id: EngineMessage]?) in
                        if messages.isEmpty {
                            return (nil, nil)
                        } else {
                            var peers: [EnginePeer] = []
                            for message in messages.values.sorted(by: { $0.index < $1.index }) {
                                if let peer = message.peers[message.id.peerId] {
                                    peers.append(EnginePeer(peer))
                                }
                            }
                            return (peers, messages)
                        }
                    }
                }
                
                self.liveLocationDisposable = (signal
                |> deliverOnMainQueue).start(next: { [weak self] peers, messages in
                    guard let self else {
                        return
                    }
                    var updated = false
                    if let current = self.liveLocationState?.peers, let peers {
                        updated = current != peers
                    } else if (self.liveLocationState != nil) != (peers != nil) {
                        updated = true
                    }
                    
                    if updated {
                        if let peers, let messages {
                            var canClose = true
                            if case let .peer(peerId) = liveLocationMode {
                                canClose = false
                                for messageId in messages.keys {
                                    if messageId.peerId == peerId {
                                        canClose = true
                                    }
                                }
                            }
                            
                            self.liveLocationState = (
                                mode: liveLocationMode,
                                peers: peers,
                                messages: messages,
                                canClose: canClose,
                                version: self.nextVersion
                            )
                            self.nextVersion += 1
                        } else {
                            self.liveLocationState = nil
                        }
                        self.notifyStateUpdated()
                    }
                })
            }
            
            if chatListNotices {
                let twoStepData: Signal<TwoStepVerificationConfiguration?, NoError> = .single(nil) |> then(context.engine.auth.twoStepVerificationConfiguration() |> map(Optional.init))
                
                let accountFreezeConfiguration = (context.account.postbox.preferencesView(keys: [PreferencesKeys.appConfiguration])
                                                  |> map { view -> AppConfiguration in
                    let appConfiguration: AppConfiguration = view.values[PreferencesKeys.appConfiguration]?.get(AppConfiguration.self) ?? AppConfiguration.defaultValue
                    return appConfiguration
                }
                |> distinctUntilChanged
                |> map { appConfiguration -> AccountFreezeConfiguration in
                    return AccountFreezeConfiguration.with(appConfiguration: appConfiguration)
                })
                
                let starsSubscriptionsContextPromise = Promise<StarsSubscriptionsContext?>(nil)
                
                let suggestedChatListNoticeSignal: Signal<ChatListNotice?, NoError> = combineLatest(
                    context.engine.notices.getServerProvidedSuggestions(),
                    context.engine.notices.getServerDismissedSuggestions(),
                    twoStepData,
                    newSessionReviews(postbox: context.account.postbox),
                    context.engine.data.subscribe(
                        TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId),
                        TelegramEngine.EngineData.Item.Peer.Birthday(id: context.account.peerId)
                    ),
                    context.account.stateManager.contactBirthdays,
                    starsSubscriptionsContextPromise.get(),
                    accountFreezeConfiguration
                )
                |> mapToSignal { suggestions, dismissedSuggestions, configuration, newSessionReviews, data, birthdays, starsSubscriptionsContext, accountFreezeConfiguration -> Signal<ChatListNotice?, NoError> in
                    let (accountPeer, birthday) = data
                    
                    if let newSessionReview = newSessionReviews.first {
                        return .single(.reviewLogin(newSessionReview: newSessionReview, totalCount: newSessionReviews.count))
                    }
                    if suggestions.contains(.setupPassword), let configuration {
                        var notSet = false
                        switch configuration {
                        case let .notSet(pendingEmail):
                            if pendingEmail == nil {
                                notSet = true
                            }
                        case .set:
                            break
                        }
                        if notSet {
                            return .single(.setupPassword)
                        }
                    }
                    
                    let today = Calendar(identifier: .gregorian).component(.day, from: Date())
                    var todayBirthdayPeerIds: [EnginePeer.Id] = []
                    for (peerId, birthday) in birthdays {
                        if birthday.day == today {
                            todayBirthdayPeerIds.append(peerId)
                        }
                    }
                    todayBirthdayPeerIds.sort { lhs, rhs in
                        return lhs < rhs
                    }
                    
                    if dismissedSuggestions.contains(ServerProvidedSuggestion.todayBirthdays.id) {
                        todayBirthdayPeerIds = []
                    }
                    
                    if let _ = accountFreezeConfiguration.freezeUntilDate {
                        return .single(.accountFreeze)
                    } else if suggestions.contains(.starsSubscriptionLowBalance) {
                        if let starsSubscriptionsContext {
                            return starsSubscriptionsContext.state
                            |> map { state in
                                if state.balance > StarsAmount.zero && !state.subscriptions.isEmpty {
                                    return .starsSubscriptionLowBalance(
                                        amount: state.balance,
                                        peers: state.subscriptions.map { $0.peer }
                                    )
                                } else {
                                    return nil
                                }
                            }
                        } else {
                            starsSubscriptionsContextPromise.set(.single(context.engine.payments.peerStarsSubscriptionsContext(starsContext: nil, missingBalance: true)))
                            return .single(nil)
                        }
                    } else if suggestions.contains(.setupPhoto), let accountPeer, accountPeer.smallProfileImage == nil {
                        return .single(.setupPhoto(accountPeer))
                    } else if suggestions.contains(.gracePremium) {
                        return .single(.premiumGrace)
                    } else if suggestions.contains(.xmasPremiumGift) {
                        return .single(.xmasPremiumGift)
                    } else if suggestions.contains(.annualPremium) || suggestions.contains(.upgradePremium) || suggestions.contains(.restorePremium), let inAppPurchaseManager = context.inAppPurchaseManager {
                        return inAppPurchaseManager.availableProducts
                        |> map { products -> ChatListNotice? in
                            if products.count > 1 {
                                let shortestOptionPrice: (Int64, NSDecimalNumber)
                                if let product = products.first(where: { $0.id.hasSuffix(".monthly") }) {
                                    shortestOptionPrice = (Int64(Float(product.priceCurrencyAndAmount.amount)), product.priceValue)
                                } else {
                                    shortestOptionPrice = (1, NSDecimalNumber(decimal: 1))
                                }
                                for product in products {
                                    if product.id.hasSuffix(".annual") {
                                        let fraction = Float(product.priceCurrencyAndAmount.amount) / Float(12) / Float(shortestOptionPrice.0)
                                        let discount = Int32(round((1.0 - fraction) * 20.0) * 5.0)
                                        if discount > 0 {
                                            if suggestions.contains(.restorePremium) {
                                                return .premiumRestore(discount: discount)
                                            } else if suggestions.contains(.annualPremium) {
                                                return .premiumAnnualDiscount(discount: discount)
                                            } else if suggestions.contains(.upgradePremium) {
                                                return .premiumUpgrade(discount: discount)
                                            }
                                        }
                                        break
                                    }
                                }
                                return nil
                            } else {
                                if !GlobalExperimentalSettings.isAppStoreBuild {
                                    if suggestions.contains(.restorePremium) {
                                        return .premiumRestore(discount: 0)
                                    } else if suggestions.contains(.annualPremium) {
                                        return .premiumAnnualDiscount(discount: 0)
                                    } else if suggestions.contains(.upgradePremium) {
                                        return .premiumUpgrade(discount: 0)
                                    }
                                }
                                return nil
                            }
                        }
                    } else if !todayBirthdayPeerIds.isEmpty {
                        return context.engine.data.get(
                            EngineDataMap(todayBirthdayPeerIds.map(TelegramEngine.EngineData.Item.Peer.Peer.init(id:)))
                        )
                        |> map { result -> ChatListNotice? in
                            var todayBirthdayPeers: [EnginePeer] = []
                            for (peerId, _) in birthdays {
                                if let maybePeer = result[peerId], let peer = maybePeer {
                                    todayBirthdayPeers.append(peer)
                                }
                            }
                            return .birthdayPremiumGift(peers: todayBirthdayPeers, birthdays: birthdays)
                        }
                    } else if suggestions.contains(.setupBirthday) && birthday == nil {
                        return .single(.setupBirthday)
                    } else if case let .link(id, url, title, subtitle) = suggestions.first(where: { if case .link = $0 { return true } else { return false} }) {
                        return .single(.link(id: id, url: url, title: title, subtitle: subtitle))
                    } else {
                        return .single(nil)
                    }
                }
                |> distinctUntilChanged
                
                self.suggestedChatListNoticeDisposable = (suggestedChatListNoticeSignal
                |> deliverOn(self.queue)).startStrict(next: { [weak self] chatListNotice in
                    guard let self else {
                        return
                    }
                    if self.chatListNotice != chatListNotice {
                        self.chatListNotice = chatListNotice
                        self.notifyStateUpdated()
                    }
                })
            }
            
            if let callManager = context.sharedContext.callManager, let peerId = groupCalls {
                let currentGroupCall: Signal<PresentationGroupCall?, NoError> = callManager.currentGroupCallSignal
                |> distinctUntilChanged(isEqual: { lhs, rhs in
                    return lhs == rhs
                })
                |> map { call -> PresentationGroupCall? in
                    guard case let .group(call) = call else {
                        return nil
                    }
                    guard call.peerId == peerId && call.account.peerId == context.account.peerId else {
                        return nil
                    }
                    return call
                }
                
                let availableGroupCall: Signal<AccountGroupCallContextImpl.GroupCallPanelData?, NoError>
                if let peerId = groupCalls {
                    availableGroupCall = context.account.viewTracker.peerView(peerId)
                    |> map { peerView -> (CachedChannelData.ActiveCall?, EnginePeer?) in
                        let peer = peerView.peers[peerId].flatMap(EnginePeer.init)
                        if let cachedData = peerView.cachedData as? CachedChannelData {
                            return (cachedData.activeCall, peer)
                        } else if let cachedData = peerView.cachedData as? CachedGroupData {
                            return (cachedData.activeCall, peer)
                        } else {
                            return (nil, peer)
                        }
                    }
                    |> distinctUntilChanged(isEqual: { lhs, rhs in
                        return lhs.0 == rhs.0
                    })
                    |> mapToSignal { activeCall, peer -> Signal<AccountGroupCallContextImpl.GroupCallPanelData?, NoError> in
                        guard let activeCall = activeCall else {
                            return .single(nil)
                        }

                        var isChannel = false
                        if let peer = peer, case let .channel(channel) = peer, case .broadcast = channel.info {
                            isChannel = true
                        }
                        
                        return Signal { [weak context] subscriber in
                            guard let context = context, let callContextCache = context.cachedGroupCallContexts as? AccountGroupCallContextCacheImpl else {
                                return EmptyDisposable
                            }
                            
                            let disposable = MetaDisposable()
                            
                            callContextCache.impl.syncWith { impl in
                                let callContext = impl.get(account: context.account, engine: context.engine, peerId: peerId, isChannel: isChannel, call: EngineGroupCallDescription(activeCall))
                                disposable.set((callContext.context.panelData
                                |> deliverOnMainQueue).start(next: { panelData in
                                    callContext.keep()
                                    var updatedPanelData = panelData
                                    if let panelData {
                                        var updatedInfo = panelData.info
                                        updatedInfo.subscribedToScheduled = activeCall.subscribedToScheduled
                                        updatedPanelData = panelData.withInfo(updatedInfo)
                                    }
                                    subscriber.putNext(updatedPanelData)
                                }))
                            }
                            
                            return ActionDisposable {
                                disposable.dispose()
                            }
                        }
                        |> runOn(.mainQueue())
                    }
                } else {
                    availableGroupCall = .single(nil)
                }
                
                let previousCurrentGroupCall = Atomic<PresentationGroupCall?>(value: nil)
                self.currentGroupCallDisposable = combineLatest(queue: .mainQueue(), availableGroupCall, currentGroupCall).start(next: { [weak self] availableState, currentGroupCall in
                    guard let self else {
                        return
                    }
                    
                    let previousCurrentGroupCall = previousCurrentGroupCall.swap(currentGroupCall)
                    
                    let panelData: AccountGroupCallContextImpl.GroupCallPanelData?
                    if previousCurrentGroupCall != nil && currentGroupCall == nil && availableState?.participantCount == 1 {
                        panelData = nil
                    } else {
                        panelData = currentGroupCall != nil || (availableState?.participantCount == 0 && availableState?.info.scheduleTimestamp == nil && availableState?.info.isStream == false) ? nil : availableState
                    }
                    
                    let groupCall = panelData.flatMap { panelData in
                        return GroupCall(
                            peerId: panelData.peerId,
                            isChannel: panelData.isChannel,
                            info: panelData.info,
                            topParticipants: panelData.topParticipants,
                            participantCount: panelData.participantCount,
                            activeSpeakers: panelData.activeSpeakers,
                            groupCall: panelData.groupCall
                        )
                    }
                    if self.groupCall != groupCall {
                        self.groupCall = groupCall
                        self.notifyStateUpdated()
                    }
                })
            }
        }

        deinit {
            self.mediaStatusDisposable?.dispose()
            self.liveLocationDisposable?.dispose()
            self.suggestedChatListNoticeDisposable?.dispose()
            self.currentGroupCallDisposable?.dispose()
        }
        
        private func notifyStateUpdated() {
            self.stateValue = State(
                mediaPlayback: self.playlistStateAndType.flatMap { playlistStateAndType in
                    return MediaPlayback(
                        version: playlistStateAndType.7,
                        item: playlistStateAndType.0,
                        previousItem: playlistStateAndType.1,
                        nextItem: playlistStateAndType.2,
                        playbackOrder: playlistStateAndType.3,
                        kind: playlistStateAndType.4,
                        playlistLocation: playlistStateAndType.6,
                        account: playlistStateAndType.5
                    )
                },
                liveLocation: self.liveLocationState.flatMap { liveLocationState in
                    return GlobalControlPanelsContext.LiveLocation(
                        mode: liveLocationState.mode,
                        peers: liveLocationState.peers,
                        messages: liveLocationState.messages,
                        canClose: liveLocationState.canClose,
                        version: liveLocationState.version
                    )
                },
                chatListNotice: self.chatListNotice,
                groupCall: self.groupCall
            )
            self.statePipe.putNext(self.stateValue)
        }
        
        func dismissChatListNotice(parentController: ViewController, notice: ChatListNotice) {
            let presentationData = self.context.sharedContext.currentPresentationData.with({ $0 })
            switch notice {
            case .xmasPremiumGift:
                let _ = self.context.engine.notices.dismissServerProvidedSuggestion(suggestion: ServerProvidedSuggestion.xmasPremiumGift.id).startStandalone()
                parentController.present(UndoOverlayController(presentationData: presentationData, content: .universal(animation: "anim_gift", scale: 0.058, colors: ["__allcolors__": UIColor.white], title: nil, text: presentationData.strings.ChatList_PremiumGiftInSettingsInfo, customUndoText: nil, timeout: 5.0), elevatedLayout: false, action: { _ in
                    return true
                }), in: .current)
            case .setupBirthday:
                let _ = self.context.engine.notices.dismissServerProvidedSuggestion(suggestion: ServerProvidedSuggestion.setupBirthday.id).startStandalone()
                parentController.present(UndoOverlayController(presentationData: presentationData, content: .universal(animation: "anim_gift", scale: 0.058, colors: ["__allcolors__": UIColor.white], title: nil, text: presentationData.strings.ChatList_BirthdayInSettingsInfo, customUndoText: nil, timeout: 5.0), elevatedLayout: false, action: { _ in
                    return true
                }), in: .current)
            case .birthdayPremiumGift:
                let _ = self.context.engine.notices.dismissServerProvidedSuggestion(suggestion: ServerProvidedSuggestion.todayBirthdays.id).startStandalone()
                parentController.present(UndoOverlayController(presentationData: presentationData, content: .universal(animation: "anim_gift", scale: 0.058, colors: ["__allcolors__": UIColor.white], title: nil, text: presentationData.strings.ChatList_PremiumGiftInSettingsInfo, customUndoText: nil, timeout: 5.0), elevatedLayout: false, action: { _ in
                    return true
                }), in: .current)
            case .premiumGrace:
                let _ = self.context.engine.notices.dismissServerProvidedSuggestion(suggestion: ServerProvidedSuggestion.gracePremium.id).startStandalone()
            case .setupPhoto:
                let _ = self.context.engine.notices.dismissServerProvidedSuggestion(suggestion: ServerProvidedSuggestion.setupPhoto.id).startStandalone()
            case .starsSubscriptionLowBalance:
                let _ = self.context.engine.notices.dismissServerProvidedSuggestion(suggestion: ServerProvidedSuggestion.starsSubscriptionLowBalance.id).startStandalone()
            case let .link(id, _, _, _):
                let _ = self.context.engine.notices.dismissServerProvidedSuggestion(suggestion: id).startStandalone()
            default:
                break
            }
        }
    }

    private let impl: QueueLocalObject<Impl>
    public var state: Signal<State, NoError> {
        return self.impl.signalWith { impl, subscriber in
            subscriber.putNext(impl.stateValue)
            return impl.statePipe.signal().start(next: subscriber.putNext)
        }
    }

    public init(context: AccountContext, mediaPlayback: Bool, liveLocationMode: LiveLocationMode?, groupCalls: EnginePeer.Id?, chatListNotices: Bool) {
        self.impl = QueueLocalObject(queue: .mainQueue(), generate: {
            return Impl(queue: .mainQueue(), context: context, mediaPlayback: mediaPlayback, liveLocationMode: liveLocationMode, groupCalls: groupCalls, chatListNotices: chatListNotices)
        })
    }
    
    public func dismissChatListNotice(parentController: ViewController, notice: ChatListNotice) {
        self.impl.with { impl in
            impl.dismissChatListNotice(parentController: parentController, notice: notice)
        }
    }
    
    public func setTempVoicePlaylistEnded(_ f: (() -> Void)?) {
        self.impl.with { impl in
            return impl.tempVoicePlaylistEnded = f
        }
    }
    
    public func setTempVoicePlaylistItemChanged(_ f: ((SharedMediaPlaylistItem?, SharedMediaPlaylistItem?) -> Void)?) {
        self.impl.with { impl in
            return impl.tempVoicePlaylistItemChanged = f
        }
    }
    
    public var tempVoicePlaylistCurrentItem: SharedMediaPlaylistItem? {
        return self.impl.syncWith { impl in
            return impl.tempVoicePlaylistCurrentItem
        }
    }
    
    public var playlistStateAndType: (SharedMediaPlaylistItem, SharedMediaPlaylistItem?, SharedMediaPlaylistItem?, MusicPlaybackSettingsOrder, MediaManagerPlayerType, Account, SharedMediaPlaylistLocation, Int)? {
        return self.impl.syncWith { impl in
            return impl.playlistStateAndType
        }
    }
}
