import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit
import AccountContext
import TelegramPresentationData
import PresentationDataUtils
import ComponentFlow
import ViewControllerComponent
import SheetComponent
import MultilineTextComponent
import MultilineTextWithEntitiesComponent
import BundleIconComponent
import SolidRoundedButtonComponent
import Markdown
import BalancedTextComponent
import AvatarNode
import TextFormat
import TelegramStringFormatting
import UndoUI
import StarsImageComponent
import GalleryUI
import StarsAvatarComponent
import MiniAppListScreen
import PremiumStarComponent
import GiftAnimationComponent

private final class StarsTransactionSheetContent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let subject: StarsTransactionScreen.Subject
    let cancel: (Bool) -> Void
    let openPeer: (EnginePeer, Bool) -> Void
    let openMessage: (EngineMessage.Id) -> Void
    let openMedia: ([Media], @escaping (Media) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))?, @escaping (UIView) -> Void) -> Void
    let openAppExamples: () -> Void
    let openPaidMessageFee: () -> Void
    let copyTransactionId: (String) -> Void
    let updateSubscription: () -> Void
    let sendGift: (EnginePeer.Id) -> Void
    
    init(
        context: AccountContext,
        subject: StarsTransactionScreen.Subject,
        cancel: @escaping  (Bool) -> Void,
        openPeer: @escaping (EnginePeer, Bool) -> Void,
        openMessage: @escaping (EngineMessage.Id) -> Void,
        openMedia: @escaping ([Media], @escaping (Media) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))?, @escaping (UIView) -> Void) -> Void,
        openAppExamples: @escaping () -> Void,
        openPaidMessageFee: @escaping () -> Void,
        copyTransactionId: @escaping (String) -> Void,
        updateSubscription: @escaping () -> Void,
        sendGift: @escaping (EnginePeer.Id) -> Void
    ) {
        self.context = context
        self.subject = subject
        self.cancel = cancel
        self.openPeer = openPeer
        self.openMessage = openMessage
        self.openMedia = openMedia
        self.openAppExamples = openAppExamples
        self.openPaidMessageFee = openPaidMessageFee
        self.copyTransactionId = copyTransactionId
        self.updateSubscription = updateSubscription
        self.sendGift = sendGift
    }
    
    static func ==(lhs: StarsTransactionSheetContent, rhs: StarsTransactionSheetContent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.subject != rhs.subject {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        private let context: AccountContext
        private var disposable: Disposable?
        var initialized = false
        
        var peerMap: [EnginePeer.Id: EnginePeer] = [:]
        
        var cachedCloseImage: (UIImage, PresentationTheme)?
        var cachedOverlayCloseImage: UIImage?
        var cachedChevronImage: (UIImage, PresentationTheme)?
        
        var inProgress = false
        
        init(context: AccountContext, subject: StarsTransactionScreen.Subject) {
            self.context = context
            
            super.init()
            
            var peerIds: [EnginePeer.Id] = []
            switch subject {
            case let .transaction(transaction, _):
                if case let .peer(peer) = transaction.peer {
                    peerIds.append(peer.id)
                }
                if let starrefPeerId = transaction.starrefPeerId {
                    peerIds.append(starrefPeerId)
                }
            case let .receipt(receipt):
                peerIds.append(receipt.botPaymentId)
            case let .gift(message):
                peerIds.append(message.id.peerId)
                if let action = message.media.first(where: { $0 is TelegramMediaAction }) as? TelegramMediaAction, case let .prizeStars(_, _, boostPeerId, _, _) = action.action, let boostPeerId {
                    peerIds.append(boostPeerId)
                }
            case let .subscription(subscription):
                peerIds.append(subscription.peer.id)
            case let .importer(_, _, importer, _):
                peerIds.append(importer.peer.peerId)
            case let .boost(peerId, _):
                peerIds.append(peerId)
            }
            
            self.disposable = (context.engine.data.get(
                EngineDataMap(
                    peerIds.map { peerId -> TelegramEngine.EngineData.Item.Peer.Peer in
                        return TelegramEngine.EngineData.Item.Peer.Peer(id: peerId)
                    }
                )
            ) |> deliverOnMainQueue).startStrict(next: { [weak self] peers in
                if let strongSelf = self {
                    var peersMap: [EnginePeer.Id: EnginePeer] = [:]
                    for peerId in peerIds {
                        if let maybePeer = peers[peerId], let peer = maybePeer {
                            peersMap[peerId] = peer
                        }
                    }
                    strongSelf.peerMap = peersMap
                    strongSelf.initialized = true
                
                    strongSelf.updated(transition: .immediate)
                }
            })
        }
        
        deinit {
            self.disposable?.dispose()
        }
    }
    
    func makeState() -> State {
        return State(context: self.context, subject: self.subject)
    }
    
    static var body: Body {
        let closeButton = Child(Button.self)
        let title = Child(MultilineTextComponent.self)
        let star = Child(StarsImageComponent.self)
        let activeStar = Child(PremiumStarComponent.self)
        let gift = Child(GiftCompositionComponent.self)
        let amountBackground = Child(RoundedRectangle.self)
        let amount = Child(BalancedTextComponent.self)
        let amountStar = Child(BundleIconComponent.self)
        let description = Child(MultilineTextComponent.self)
        let table = Child(TableComponent.self)
        let additional = Child(BalancedTextComponent.self)
        let status = Child(BalancedTextComponent.self)
        let cancelButton = Child(SolidRoundedButtonComponent.self)
        let button = Child(SolidRoundedButtonComponent.self)
        
        let transactionStatusBackgound = Child(RoundedRectangle.self)
        let transactionStatusText = Child(MultilineTextComponent.self)
        
        let spaceRegex = try? NSRegularExpression(pattern: "\\[(.*?)\\]", options: [])
        
        let giftCompositionExternalState = GiftCompositionComponent.ExternalState()
        
        return { context in
            let environment = context.environment[ViewControllerComponentContainer.Environment.self].value
            let controller = environment.controller
            
            let component = context.component
            let theme = environment.theme
            let strings = environment.strings
            let dateTimeFormat = environment.dateTimeFormat
            
            let state = context.state
            let subject = component.subject
            
            let sideInset: CGFloat = 16.0 + environment.safeInsets.left
            let textSideInset: CGFloat = 32.0 + environment.safeInsets.left
            
            let closeImage: UIImage
            if let (image, theme) = state.cachedCloseImage, theme === environment.theme {
                closeImage = image
            } else {
                closeImage = generateCloseButtonImage(backgroundColor: UIColor(rgb: 0x808084, alpha: 0.1), foregroundColor: theme.actionSheet.inputClearButtonColor)!
                state.cachedCloseImage = (closeImage, theme)
            }
            
            let closeOverlayImage: UIImage
            if let image = state.cachedOverlayCloseImage {
                closeOverlayImage = image
            } else {
                closeOverlayImage = generateCloseButtonImage(backgroundColor: UIColor(rgb: 0xffffff, alpha: 0.1), foregroundColor: .white)!
                state.cachedOverlayCloseImage = closeOverlayImage
            }
                        
            let titleText: String
            let amountText: String
            var descriptionText: String
            var boostsText: String?
            let additionalText = strings.Stars_Transaction_Terms
            var buttonText: String? = strings.Common_OK
            
            var cancelButtonText: String?
            var statusText: String?
            var statusIsDestructive = false
            
            let count: CurrencyAmount
            var countIsGeneric = false
            var countOnTop = false
            var transactionId: String?
            let date: Int32
            var additionalDate: Int32?
            var via: String?
            var messageId: EngineMessage.Id?
            var toPeer: EnginePeer?
            var transactionPeer: StarsContext.State.Transaction.Peer?
            var media: [AnyMediaReference] = []
            var photo: TelegramMediaWebFile?
            var transactionStatus: (String, UIColor)? = nil
            var isGift = false
            var isSubscription = false
            var isSubscriber = false
            var isSubscriptionFee = false
            var isBotSubscription = false
            var isBusinessSubscription = false
            var isCancelled = false
            var isReaction = false
            var giveawayMessageId: MessageId?
            var isBoost = false
            var giftAnimationSubject: GiftCompositionComponent.Subject?
            var isGiftUpgrade = false
            var giftAvailability: StarGift.Gift.Availability?
            var isRefProgram = false
            var isPaidMessage = false
            var premiumGiftMonths: Int32?
            
            var delayedCloseOnOpenPeer = true
            switch subject {
            case let .boost(peerId, boost):
                guard let stars = boost.stars else {
                    fatalError()
                }
                let boosts = boost.multiplier
                titleText = strings.Stars_Transaction_Giveaway_Boost_Stars(Int32(stars))
                descriptionText = ""
                boostsText = strings.Stars_Transaction_Giveaway_Boost_Boosts(boosts)
                count = CurrencyAmount(amount: StarsAmount(value: stars, nanos: 0), currency: .stars)
                date = boost.date
                toPeer = state.peerMap[peerId]
                giveawayMessageId = boost.giveawayMessageId
                isBoost = true
            case let .importer(peer, pricing, importer, usdRate):
                let usdValue = formatTonUsdValue(pricing.amount.value, divide: false, rate: usdRate, dateTimeFormat: environment.dateTimeFormat)
                titleText = strings.Stars_Transaction_Subscription_Title
                descriptionText = strings.Stars_Transaction_Subscription_PerMonthUsd(usdValue).string
                count = CurrencyAmount(amount: pricing.amount, currency: .stars)
                countOnTop = true
                date = importer.date
                toPeer = importer.peer.peer.flatMap(EnginePeer.init)
                transactionPeer = .peer(peer)
                isSubscriber = true
            case let .subscription(subscription):
                if case let .user(user) = subscription.peer {
                    if user.botInfo != nil {
                        isBotSubscription = true
                    } else {
                        isBusinessSubscription = true
                    }
                }
                if let title = subscription.title {
                    titleText = title
                } else {
                    titleText = strings.Stars_Transaction_Subscription_Title
                }
                photo = subscription.photo
                
                descriptionText = ""
                count = CurrencyAmount(amount: subscription.pricing.amount, currency: .stars)
                date = subscription.untilDate
                if let creationDate = (subscription.peer._asPeer() as? TelegramChannel)?.creationDate, creationDate > 0 {
                    additionalDate = creationDate
                } else {
                    additionalDate = nil
                }
                toPeer = subscription.peer
                transactionPeer = .peer(subscription.peer)
                isSubscription = true
                                
                var hasLeft = false
                var isKicked = false
                if let toPeer, case let .channel(channel) = toPeer {
                    switch channel.participationStatus {
                    case .left:
                        hasLeft = true
                    case .kicked:
                        isKicked = true
                    default:
                        break
                    }
                }
                
                if hasLeft || isKicked {
                    if subscription.flags.contains(.isCancelled) {
                        statusText = strings.Stars_Transaction_Subscription_Cancelled
                        statusIsDestructive = true
                        if date > Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970) {
                            buttonText = strings.Stars_Transaction_Subscription_Renew
                        } else {
                            if let _ = subscription.inviteHash, !isKicked {
                                buttonText = strings.Stars_Transaction_Subscription_JoinAgainChannel
                            } else {
                                buttonText = strings.Common_OK
                            }
                        }
                    } else {
                        if date < Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970) {
                            statusText = strings.Stars_Transaction_Subscription_Expired(stringForMediumDate(timestamp: subscription.untilDate, strings: strings, dateTimeFormat: dateTimeFormat, withTime: false)).string
                            buttonText = strings.Stars_Transaction_Subscription_Renew
                        } else {
                            statusText = strings.Stars_Transaction_Subscription_LeftChannel(stringForMediumDate(timestamp: subscription.untilDate, strings: strings, dateTimeFormat: dateTimeFormat, withTime: false)).string
                            buttonText = strings.Stars_Transaction_Subscription_JoinChannel
                        }
                    }
                    isCancelled = true
                } else {
                    if subscription.flags.contains(.isCancelledByBot) {
                        if case let .user(user) = subscription.peer, user.botInfo == nil {
                            statusText = strings.Stars_Transaction_Subscription_CancelledByBusiness
                        } else {
                            statusText = strings.Stars_Transaction_Subscription_CancelledByBot
                        }
                        statusIsDestructive = true
                        buttonText = strings.Common_OK
                        isCancelled = true
                    } else if subscription.flags.contains(.isCancelled) {
                        statusText = strings.Stars_Transaction_Subscription_Cancelled
                        statusIsDestructive = true
                        if date > Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970) {
                            buttonText = strings.Stars_Transaction_Subscription_Renew
                        } else {
                            if let _ = subscription.invoiceSlug {
                                buttonText = strings.Stars_Transaction_Subscription_Renew
                            } else if let _ = subscription.inviteHash, !isKicked {
                                buttonText = strings.Stars_Transaction_Subscription_JoinAgainChannel
                            } else {
                                buttonText = strings.Common_OK
                            }
                        }
                        isCancelled = true
                    } else {
                        statusText = strings.Stars_Transaction_Subscription_Active(stringForMediumDate(timestamp: subscription.untilDate, strings: strings, dateTimeFormat: dateTimeFormat, withTime: false)).string
                        cancelButtonText = strings.Stars_Transaction_Subscription_Cancel
                        buttonText = strings.Common_OK
                    }
                }
            case let .transaction(transaction, parentPeer):
                if let starGift = transaction.starGift {
                    switch starGift {
                    case .generic:
                        titleText = strings.Stars_Transaction_Gift_Title
                        descriptionText = ""
                    case let .unique(gift):
                        titleText = gift.title
                        descriptionText = "\(strings.Gift_Unique_Collectible) #\(presentationStringsFormattedNumber(gift.number, dateTimeFormat.groupingSeparator))"
                    }
                    count = transaction.count
                    transactionId = transaction.id
                    date = transaction.date
                    if case let .peer(peer) = transaction.peer {
                        toPeer = peer
                    }
                    transactionPeer = transaction.peer
                    
                    switch starGift {
                    case let .generic(gift):
                        giftAnimationSubject = .generic(gift.file)
                        giftAvailability = gift.availability
                    case let .unique(gift):
                        giftAnimationSubject = .unique(gift)
                    }
                    isGiftUpgrade = transaction.flags.contains(.isStarGiftUpgrade)
                } else if let giveawayMessageIdValue = transaction.giveawayMessageId {
                    titleText = strings.Stars_Transaction_Giveaway_Title
                    descriptionText = ""
                    count = transaction.count
                    transactionId = transaction.id
                    date = transaction.date
                    giveawayMessageId = giveawayMessageIdValue
                    if case let .peer(peer) = transaction.peer {
                        toPeer = peer
                    }
                    transactionPeer = transaction.peer
                } else if let _ = transaction.subscriptionPeriod {
                    titleText = strings.Stars_Transaction_SubscriptionFee
                    descriptionText = ""
                    count = transaction.count
                    transactionId = transaction.id
                    date = transaction.date
                    if case let .peer(peer) = transaction.peer {
                        toPeer = peer
                    }
                    transactionPeer = transaction.peer
                    isSubscriptionFee = true
                } else if transaction.flags.contains(.isGift) {
                    titleText = strings.Stars_Gift_Received_Title
                    count = transaction.count
                    
                    if count.currency == .ton {
                        descriptionText = strings.Stars_Gift_Ton_Text
                    } else {
                        descriptionText = strings.Stars_Gift_Received_Text
                    }
                    
                    countOnTop = true
                    transactionId = transaction.id
                    date = transaction.date
                    if case let .peer(peer) = transaction.peer {
                        toPeer = peer
                    }
                    transactionPeer = transaction.peer
                    isGift = true
                } else if let starrefCommissionPermille = transaction.starrefCommissionPermille {
                    isRefProgram = true
                    if transaction.flags.contains(.isPaidMessage) {
                        isPaidMessage = true
                        titleText = strings.Stars_Transaction_PaidMessage(transaction.paidMessageCount ?? 1)
                        if !transaction.flags.contains(.isRefund) {
                            countOnTop = true
                            descriptionText = strings.Stars_Transaction_PaidMessage_Text(formatPermille(1000 - starrefCommissionPermille)).string
                        } else {
                            descriptionText = ""
                        }
                    } else if transaction.starrefPeerId == nil {
                        titleText = strings.StarsTransaction_TitleCommission(formatPermille(starrefCommissionPermille)).string
                        countOnTop = false
                        descriptionText = ""
                    } else {
                        titleText = transaction.title ?? " "
                        countOnTop = false
                        descriptionText = ""
                    }
                    count = transaction.count
                    transactionId = transaction.id
                    date = transaction.date
                    transactionPeer = transaction.peer
                    if case let .peer(peer) = transaction.peer {
                        toPeer = peer
                    }
                } else if transaction.flags.contains(.isReaction) {
                    titleText = strings.Stars_Transaction_Reaction_Title
                    descriptionText = ""
                    messageId = transaction.paidMessageId
                    count = transaction.count
                    transactionId = transaction.id
                    date = transaction.date
                    if case let .peer(peer) = transaction.peer {
                        toPeer = peer
                    }
                    transactionPeer = transaction.peer
                    isReaction = true
                } else {
                    switch transaction.peer {
                    case let .peer(peer):
                        if let months = transaction.premiumGiftMonths {
                            premiumGiftMonths = months
                            titleText = strings.Stars_Transaction_TelegramPremium(months)
                        } else if transaction.flags.contains(.isPaidMessage) {
                            isPaidMessage = true
                            titleText = strings.Stars_Transaction_PaidMessage(transaction.paidMessageCount ?? 1)
                        } else if !transaction.media.isEmpty {
                            titleText = strings.Stars_Transaction_MediaPurchase
                        } else {
                            titleText = transaction.title ?? peer.compactDisplayTitle
                        }
                    case .appStore:
                        titleText = strings.Stars_Transaction_AppleTopUp_Title
                        via = strings.Stars_Transaction_AppleTopUp_Subtitle
                    case .playMarket:
                        titleText = strings.Stars_Transaction_GoogleTopUp_Title
                        via = strings.Stars_Transaction_GoogleTopUp_Subtitle
                    case .premiumBot:
                        titleText = strings.Stars_Transaction_PremiumBotTopUp_Title
                        via = strings.Stars_Transaction_PremiumBotTopUp_Subtitle
                    case .fragment:
                        if parentPeer.id == component.context.account.peerId {
                            if (transaction.count.amount.value < 0 && !transaction.flags.contains(.isRefund)) || (transaction.count.amount.value > 0 && transaction.flags.contains(.isRefund)) {
                                titleText = strings.Stars_Transaction_FragmentWithdrawal_Title
                                via = strings.Stars_Transaction_FragmentWithdrawal_Subtitle
                            } else {
                                titleText = strings.Stars_Transaction_FragmentTopUp_Title
                                via = strings.Stars_Transaction_FragmentTopUp_Subtitle
                            }
                        } else {
                            titleText = strings.Stars_Transaction_FragmentWithdrawal_Title
                            via = strings.Stars_Transaction_FragmentWithdrawal_Subtitle
                        }
                    case .ads:
                        titleText = strings.Stars_Transaction_TelegramAds_Title
                        via = strings.Stars_Transaction_TelegramAds_Subtitle
                    case .apiLimitExtension:
                        titleText = strings.Stars_Transaction_TelegramBotApi_Title
                    case .unsupported:
                        titleText = strings.Stars_Transaction_Unsupported_Title
                    }
                    
                    if let floodskipNumber = transaction.floodskipNumber {
                        descriptionText = strings.Stars_Transaction_TelegramBotApi_Messages(floodskipNumber)
                    } else if !transaction.media.isEmpty {
                        var description: String = ""
                        var photoCount: Int32 = 0
                        var videoCount: Int32 = 0
                        for media in transaction.media {
                            if let _ = media as? TelegramMediaFile {
                                videoCount += 1
                            } else {
                                photoCount += 1
                            }
                        }
                        if photoCount > 0 && videoCount > 0 {
                            description += strings.Stars_Transaction_MediaAnd(strings.Stars_Transaction_Photos(photoCount), strings.Stars_Transaction_Videos(videoCount)).string
                        } else if photoCount > 0 {
                            if photoCount > 1 {
                                description += strings.Stars_Transaction_Photos(photoCount)
                            } else {
                                description += strings.Stars_Transaction_SinglePhoto
                            }
                        } else if videoCount > 0 {
                            if videoCount > 1 {
                                description += strings.Stars_Transaction_Videos(videoCount)
                            } else {
                                description += strings.Stars_Transaction_SingleVideo
                            }
                        }
                        descriptionText = description
                    } else {
                        descriptionText = transaction.description ?? ""
                    }
                    
                    messageId = transaction.paidMessageId
                    
                    count = transaction.count
                    transactionId = transaction.id
                    date = transaction.date
                    if case let .peer(peer) = transaction.peer {
                        toPeer = peer
                    }
                    transactionPeer = transaction.peer
                    media = transaction.media.map { AnyMediaReference.starsTransaction(transaction: StarsTransactionReference(peerId: parentPeer.id, ton: false, id: transaction.id, isRefund: transaction.flags.contains(.isRefund)), media: $0) }
                    photo = transaction.photo
                    
                    if transaction.flags.contains(.isRefund) {
                        transactionStatus = (strings.Stars_Transaction_Refund, theme.list.itemDisclosureActions.constructive.fillColor)
                    } else if transaction.flags.contains(.isPending) {
                        transactionStatus = (strings.Monetization_Transaction_Pending, theme.list.itemDisclosureActions.warning.fillColor)
                    }
                }
            case let .receipt(receipt):
                titleText = receipt.invoiceMedia.title
                descriptionText = receipt.invoiceMedia.description
                count = CurrencyAmount(amount: StarsAmount(value: (receipt.invoice.prices.first?.amount ?? receipt.invoiceMedia.totalAmount) * -1, nanos: 0), currency: .stars)
                transactionId = receipt.transactionId
                date = receipt.date
                if let peer = state.peerMap[receipt.botPaymentId] {
                    toPeer = peer
                }
                photo = receipt.invoiceMedia.photo
                delayedCloseOnOpenPeer = false
            case let .gift(message):
                let incoming = message.flags.contains(.Incoming)

                let peerName = state.peerMap[message.id.peerId]?.compactDisplayTitle ?? ""
                descriptionText = incoming ? strings.Stars_Gift_Received_Text : strings.Stars_Gift_Sent_Text(peerName).string
                if let action = message.media.first(where: { $0 is TelegramMediaAction }) as? TelegramMediaAction {
                    if case let .giftStars(_, _, countValue, _, _, _) = action.action {
                        titleText = incoming ? strings.Stars_Gift_Received_Title : strings.Stars_Gift_Sent_Title
                        
                        count = CurrencyAmount(amount: StarsAmount(value: countValue, nanos: 0), currency: .stars)
                        if !incoming {
                            countIsGeneric = true
                        }
                        countOnTop = true
                        transactionId = nil
                        if message.id.peerId.id._internalGetInt64Value() == 777000 {
                            toPeer = nil
                        } else {
                            toPeer = state.peerMap[message.id.peerId]
                        }
                    } else if case let .prizeStars(countValue, _, boostPeerId, _, giveawayMessageIdValue) = action.action {
                        titleText = strings.Stars_Transaction_Giveaway_Title
                        
                        count = CurrencyAmount(amount: StarsAmount(value: countValue, nanos: 0), currency: .stars)
                        countOnTop = true
                        transactionId = nil
                        giveawayMessageId = giveawayMessageIdValue
                        if let boostPeerId {
                            toPeer = state.peerMap[boostPeerId]
                        }
                    } else {
                        fatalError()
                    }
                } else {
                    fatalError()
                }
                date = message.timestamp
                isGift = true
                delayedCloseOnOpenPeer = false
            }
            if let spaceRegex {
                let nsRange = NSRange(descriptionText.startIndex..., in: descriptionText)
                let matches = spaceRegex.matches(in: descriptionText, options: [], range: nsRange)
                var modifiedString = descriptionText
                
                for match in matches.reversed() {
                    let matchRange = Range(match.range, in: descriptionText)!
                    let matchedSubstring = String(descriptionText[matchRange])
                    let replacedSubstring = matchedSubstring.replacingOccurrences(of: " ", with: "\u{00A0}")
                    modifiedString.replaceSubrange(matchRange, with: replacedSubstring)
                }
                descriptionText = modifiedString
            }
            
            var closeButtonImage = closeImage
            if case .unique = giftAnimationSubject {
                closeButtonImage = closeOverlayImage
            }
            let closeButton = closeButton.update(
                component: Button(
                    content: AnyComponent(Image(image: closeButtonImage)),
                    action: { [weak component] in
                        component?.cancel(true)
                    }
                ),
                availableSize: CGSize(width: 30.0, height: 30.0),
                transition: .immediate
            )
            
            let headerTextColor: UIColor
            if case .unique = giftAnimationSubject {
                headerTextColor = .white
            } else {
                headerTextColor = theme.actionSheet.primaryTextColor
            }
            
            let absCount = StarsAmount(value: abs(count.amount.value), nanos: abs(count.amount.nanos))
            let formattedAmount: String
            switch count.currency {
            case .stars:
                formattedAmount = formatStarsAmountText(absCount, dateTimeFormat: dateTimeFormat)
            case .ton:
                formattedAmount = formatTonAmountText(absCount.value, dateTimeFormat: dateTimeFormat)
            }
            let countColor: UIColor
            var countFont: UIFont = isSubscription || isSubscriber ? Font.regular(17.0) : Font.semibold(17.0)
            var countBackgroundColor: UIColor?
            if let boostsText {
                amountText = boostsText
                countColor = .white
                countBackgroundColor = UIColor(rgb: 0x9671ff)
                countFont = Font.with(size: 14.0, design: .round, weight: .semibold)
            } else if isSubscription || isSubscriber {
                amountText = strings.Stars_Transaction_Subscription_PerMonth(formattedAmount).string
                countColor = theme.list.itemSecondaryTextColor
            } else if countIsGeneric {
                amountText = "\(formattedAmount)"
                countColor = theme.list.itemPrimaryTextColor
            } else if count.amount < StarsAmount.zero {
                amountText = "- \(formattedAmount)"
                if case .unique = giftAnimationSubject {
                    countColor = .white
                } else {
                    countColor = theme.list.itemDestructiveColor
                }
            } else {
                amountText = "+ \(formattedAmount)"
                if case .unique = giftAnimationSubject {
                    countColor = .white
                } else {
                    countColor = theme.list.itemDisclosureActions.constructive.fillColor
                }
            }
            
            var titleFont = Font.bold(25.0)
            if case .unique = giftAnimationSubject {
                titleFont = Font.bold(20.0)
            }
            
            let title = title.update(
                component: MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: titleText,
                        font: titleFont,
                        textColor: headerTextColor,
                        paragraphAlignment: .center
                    )),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 1
                ),
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0 - 60.0, height: CGFloat.greatestFiniteMagnitude),
                transition: .immediate
            )
            
            if count.currency == .ton {
                premiumGiftMonths = 1000
            }
            
            let imageSubject: StarsImageComponent.Subject
            var imageIcon: StarsImageComponent.Icon?
            if let premiumGiftMonths {
                imageSubject = .gift(premiumGiftMonths)
            } else if isGift {
                var value: Int32 = 3
                if count.amount.value <= 1000 {
                    value = 3
                } else if count.amount.value < 2500 {
                    value = 6
                } else {
                    value = 12
                }
                imageSubject = .gift(value)
            } else if !media.isEmpty {
                imageSubject = .media(media)
            } else if let photo {
                imageSubject = .photo(photo)
            } else if let transactionPeer {
                imageSubject = .transactionPeer(transactionPeer)
            } else if let toPeer {
                imageSubject = .transactionPeer(.peer(toPeer))
            } else {
                imageSubject = .none
            }
            if isSubscription || isSubscriber || isSubscriptionFee || giveawayMessageId != nil {
                imageIcon = count.currency == .ton ? nil : .star
            } else {
                imageIcon = nil
            }
            
            if isSubscription && "".isEmpty {
                imageIcon = nil
            }
            
            var starOriginY: CGFloat = 81.0
            var starChild: _UpdatedChildComponent
            if let giftAnimationSubject {
                let animationHeight: CGFloat
                if case .unique = giftAnimationSubject {
                    animationHeight = 268.0
                } else {
                    animationHeight = 210.0
                }
                starChild = gift.update(
                    component: GiftCompositionComponent(
                        context: component.context,
                        theme: theme,
                        subject: giftAnimationSubject,
                        externalState: giftCompositionExternalState
                    ),
                    availableSize: CGSize(width: context.availableSize.width, height: animationHeight),
                    transition: .immediate
                )
                starOriginY = animationHeight / 2.0
            } else if isBoost {
                starChild = activeStar.update(
                    component: PremiumStarComponent(
                        theme: theme,
                        isIntro: false,
                        isVisible: true,
                        hasIdleAnimations: true,
                        colors: [
                            UIColor(rgb: 0xe57d02),
                            UIColor(rgb: 0xf09903),
                            UIColor(rgb: 0xf9b004),
                            UIColor(rgb: 0xfdd219)
                        ],
                        particleColor: UIColor(rgb: 0xf9b004),
                        backgroundColor: theme.actionSheet.opaqueItemBackgroundColor
                    ),
                    availableSize: CGSize(width: context.availableSize.width, height: 200.0),
                    transition: .immediate
                )
            } else {
                starChild = star.update(
                    component: StarsImageComponent(
                        context: component.context,
                        subject: imageSubject,
                        theme: theme,
                        diameter: 90.0,
                        backgroundColor: theme.actionSheet.opaqueItemBackgroundColor,
                        icon: imageIcon,
                        action: !media.isEmpty ? { transitionNode, addToTransitionSurface in
                            component.openMedia(media.map { $0.media }, transitionNode, addToTransitionSurface)
                        } : nil
                    ),
                    availableSize: CGSize(width: context.availableSize.width, height: 200.0),
                    transition: .immediate
                )
            }
             
            let amountAttributedText: NSAttributedString
            if amountText.contains(environment.dateTimeFormat.decimalSeparator) {
                let smallCountFont = Font.regular(14.0)
                amountAttributedText = tonAmountAttributedString(amountText, integralFont: countFont, fractionalFont: smallCountFont, color: countColor, decimalSeparator: environment.dateTimeFormat.decimalSeparator)
            } else {
                amountAttributedText = NSAttributedString(string: amountText, font: countFont, textColor: countColor)
            }
            
            let amount = amount.update(
                component: BalancedTextComponent(
                    text: .plain(amountAttributedText),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.2
                ),
                availableSize: CGSize(width: context.availableSize.width - textSideInset * 2.0, height: context.availableSize.height),
                transition: .immediate
            )
            
            let amountStarIconName: String
            var amountStarTintColor: UIColor?
            var amountStarMaxSize: CGSize?
            var amountOffset = CGPoint()
            if boostsText != nil {
                amountStarIconName = "Premium/BoostButtonIcon"
            } else if case .ton = count.currency {
                amountStarIconName = "Ads/TonBig"
                amountStarTintColor = countColor
                amountStarMaxSize = CGSize(width: 13.0, height: 13.0)
                amountOffset.y += 4.0 - UIScreenPixel
            } else {
                amountStarIconName = "Premium/Stars/StarMedium"
            }
            
            let amountStar = amountStar.update(
                component: BundleIconComponent(
                    name: amountStarIconName,
                    tintColor: amountStarTintColor,
                    maxSize: amountStarMaxSize
                ),
                availableSize: context.availableSize,
                transition: .immediate
            )
            
            let tableFont = Font.regular(15.0)
            let tableBoldFont = Font.semibold(15.0)
            let tableTextColor = theme.list.itemPrimaryTextColor
            let tableLinkColor = theme.list.itemAccentColor
            var tableItems: [TableComponent.Item] = []
                        
            if isGiftUpgrade {
                tableItems.append(.init(
                    id: "reason",
                    title: strings.Stars_Transaction_Giveaway_Reason,
                    component: AnyComponent(
                        MultilineTextComponent(text: .plain(NSAttributedString(string: strings.Stars_Transaction_GiftUpgrade, font: tableFont, textColor: tableTextColor)))
                    )
                ))
            } else if case .unique = giftAnimationSubject {
                let reason: String
                if count.amount < StarsAmount.zero, case let .transaction(transaction, _) = subject {
                    if transaction.flags.contains(.isStarGiftResale) {
                        reason = strings.Stars_Transaction_GiftPurchase
                    } else {
                        reason = strings.Stars_Transaction_GiftTransfer
                    }
                } else {
                    reason = strings.Stars_Transaction_GiftSale
                }
                tableItems.append(.init(
                    id: "reason",
                    title: strings.Stars_Transaction_Giveaway_Reason,
                    component: AnyComponent(
                        MultilineTextComponent(text: .plain(NSAttributedString(string: reason, font: tableFont, textColor: tableTextColor)))
                    )
                ))
            }
            
            if isGift, toPeer == nil {
                tableItems.append(.init(
                    id: "from",
                    title: strings.Stars_Transaction_From,
                    component: AnyComponent(
                        Button(
                            content: AnyComponent(
                                PeerCellComponent(
                                    context: component.context,
                                    theme: theme,
                                    peer: nil
                                )
                            ),
                            action: {
                                let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                                component.context.sharedContext.openExternalUrl(context: component.context, urlContext: .generic, url: strings.Stars_Transaction_FragmentUnknown_URL, forceExternal: true, presentationData: presentationData, navigationController: nil, dismissInput: {})
                                Queue.mainQueue().after(1.0, {
                                    component.cancel(false)
                                })
                            }
                        )
                    )
                ))
            } else if let toPeer, !isRefProgram {
                let title: String
                if isGiftUpgrade {
                    title = strings.Stars_Transaction_GiftFrom
                } else if isSubscription {
                    if isBotSubscription {
                        title = strings.Stars_Transaction_Subscription_Bot
                    } else if isBusinessSubscription {
                        title = strings.Stars_Transaction_Subscription_Business
                    } else {
                        title = strings.Stars_Transaction_Subscription_Subscription
                    }
                } else if isSubscriber {
                    title = strings.Stars_Transaction_Subscription_Subscriber
                } else {
                    title = count.amount < StarsAmount.zero || countIsGeneric ? strings.Stars_Transaction_To : strings.Stars_Transaction_From
                }
                
                let toComponent: AnyComponent<Empty>
                if let _ = giftAnimationSubject, !toPeer.isDeleted && !isGiftUpgrade {
                    toComponent = AnyComponent(
                        HStack([
                            AnyComponentWithIdentity(
                                id: AnyHashable(0),
                                component: AnyComponent(Button(
                                    content: AnyComponent(
                                        PeerCellComponent(
                                            context: component.context,
                                            theme: theme,
                                            peer: toPeer
                                        )
                                    ),
                                    action: {
                                        if delayedCloseOnOpenPeer {
                                            component.openPeer(toPeer, false)
                                            Queue.mainQueue().after(1.0, {
                                                component.cancel(false)
                                            })
                                        } else {
                                            if let controller = controller() as? StarsTransactionScreen, let navigationController = controller.navigationController, let chatController = navigationController.viewControllers.first(where: { $0 is ChatController }) as? ChatController {
                                                chatController.playShakeAnimation()
                                            }
                                            component.cancel(true)
                                        }
                                    }
                                ))
                            ),
                            AnyComponentWithIdentity(
                                id: AnyHashable(1),
                                component: AnyComponent(Button(
                                    content: AnyComponent(ButtonContentComponent(
                                        context: component.context,
                                        text: strings.Gift_View_Send,
                                        color: theme.list.itemAccentColor
                                    )),
                                    action: {
                                        component.sendGift(toPeer.id)
                                        Queue.mainQueue().after(1.0, {
                                            component.cancel(false)
                                        })
                                    }
                                ))
                            )
                        ], spacing: 4.0)
                    )
                } else {
                    toComponent = AnyComponent(
                        Button(
                            content: AnyComponent(
                                PeerCellComponent(
                                    context: component.context,
                                    theme: theme,
                                    peer: toPeer
                                )
                            ),
                            action: {
                                if delayedCloseOnOpenPeer {
                                    component.openPeer(toPeer, false)
                                    Queue.mainQueue().after(1.0, {
                                        component.cancel(false)
                                    })
                                } else {
                                    if let controller = controller() as? StarsTransactionScreen, let navigationController = controller.navigationController, let chatController = navigationController.viewControllers.first(where: { $0 is ChatController }) as? ChatController {
                                        chatController.playShakeAnimation()
                                    }
                                    component.cancel(true)
                                }
                            }
                        )
                    )
                }
                tableItems.append(.init(
                    id: "to",
                    title: title,
                    component: toComponent
                ))
                if case let .subscription(subscription) = component.subject, let title = subscription.title {
                    tableItems.append(.init(
                        id: "subscription",
                        title: strings.Stars_Transaction_Subscription,
                        component: AnyComponent(
                            MultilineTextComponent(text: .plain(NSAttributedString(string: title, font: tableFont, textColor: tableTextColor)))
                        )
                    ))
                }
            } else if let via {
                tableItems.append(.init(
                    id: "via",
                    title: strings.Stars_Transaction_Via,
                    component: AnyComponent(
                        MultilineTextComponent(text: .plain(NSAttributedString(string: via, font: tableFont, textColor: tableTextColor)))
                    )
                ))
            }
            
            if let giveawayMessageId {
                tableItems.append(.init(
                    id: "prize",
                    title: strings.Stars_Transaction_Giveaway_Prize,
                    component: AnyComponent(
                        MultilineTextComponent(text: .plain(NSAttributedString(string: strings.Stars_Transaction_Giveaway_Stars(Int32(count.amount.value)), font: tableFont, textColor: tableTextColor)))
                    )
                ))
                
                tableItems.append(.init(
                    id: "reason",
                    title: strings.Stars_Transaction_Giveaway_Reason,
                    component: AnyComponent(
                        Button(
                            content: AnyComponent(
                                MultilineTextComponent(text: .plain(NSAttributedString(string: strings.Stars_Transaction_Giveaway_Giveaway, font: tableFont, textColor: tableLinkColor)))
                            ),
                            action: {
                                component.openMessage(giveawayMessageId)
                                Queue.mainQueue().after(1.0, {
                                    component.cancel(false)
                                })
                            }
                        )
                    )
                ))
            }
            
            if let messageId {
                let peerName: String
                if case let .transaction(_, parentPeer) = component.subject {
                    if parentPeer.id == component.context.account.peerId {
                        if let toPeer {
                            peerName = toPeer.addressName ?? "c/\(toPeer.id.id._internalGetInt64Value())"
                        } else {
                            peerName = ""
                        }
                    } else {
                        peerName = parentPeer.addressName ?? "c/\(parentPeer.id.id._internalGetInt64Value())"
                    }
                } else {
                    peerName = ""
                }
                tableItems.append(.init(
                    id: "media",
                    title: isReaction ? strings.Stars_Transaction_Reaction_Post : strings.Stars_Transaction_Media,
                    component: AnyComponent(
                        Button(
                            content: AnyComponent(
                                MultilineTextComponent(text: .plain(NSAttributedString(string: "t.me/\(peerName)/\(messageId.id)", font: tableFont, textColor: tableLinkColor)))
                            ),
                            action: {
                                component.openMessage(messageId)
                                Queue.mainQueue().after(1.0, {
                                    component.cancel(false)
                                })
                            }
                        )
                    )
                ))
            }
            
            if case let .transaction(transaction, _) = subject {
                if transaction.starrefCommissionPermille != nil {
                    if transaction.starrefPeerId == nil {
                        tableItems.append(.init(
                            id: "reason",
                            title: strings.StarsTransaction_StarRefReason_Title,
                            component: AnyComponent(
                                Button(
                                    content: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: strings.StarsTransaction_StarRefReason_Program, font: tableFont, textColor: tableLinkColor))
                                    )),
                                    action: {
                                        if let toPeer {
                                            component.openPeer(toPeer, true)
                                            Queue.mainQueue().after(1.0, {
                                                component.cancel(false)
                                            })
                                        }
                                    }
                                )
                            ),
                            insets: UIEdgeInsets(top: 0.0, left: 12.0, bottom: 0.0, right: 5.0)
                        ))
                    }
                    if let toPeer, transaction.starrefPeerId == nil {
                        tableItems.append(.init(
                            id: "miniapp",
                            title: strings.StarsTransaction_StarRefReason_Miniapp,
                            component: AnyComponent(
                                Button(
                                    content: AnyComponent(
                                        PeerCellComponent(
                                            context: component.context,
                                            theme: theme,
                                            peer: toPeer
                                        )
                                    ),
                                    action: {
                                        if delayedCloseOnOpenPeer {
                                            component.openPeer(toPeer, false)
                                            Queue.mainQueue().after(1.0, {
                                                component.cancel(false)
                                            })
                                        } else {
                                            if let controller = controller() as? StarsTransactionScreen, let navigationController = controller.navigationController, let chatController = navigationController.viewControllers.first(where: { $0 is ChatController }) as? ChatController {
                                                chatController.playShakeAnimation()
                                            }
                                            component.cancel(true)
                                        }
                                    }
                                )
                            )
                        ))
                    }
                }
                if let starRefPeerId = transaction.starrefPeerId, let starRefPeer = state.peerMap[starRefPeerId] {
                    if !transaction.flags.contains(.isPaidMessage) && !transaction.flags.contains(.isStarGiftResale) {
                        tableItems.append(.init(
                            id: "to",
                            title: strings.StarsTransaction_StarRefReason_Affiliate,
                            component: AnyComponent(
                                Button(
                                    content: AnyComponent(
                                        PeerCellComponent(
                                            context: component.context,
                                            theme: theme,
                                            peer: starRefPeer
                                        )
                                    ),
                                    action: {
                                        if delayedCloseOnOpenPeer {
                                            component.openPeer(starRefPeer, false)
                                            Queue.mainQueue().after(1.0, {
                                                component.cancel(false)
                                            })
                                        } else {
                                            if let controller = controller() as? StarsTransactionScreen, let navigationController = controller.navigationController, let chatController = navigationController.viewControllers.first(where: { $0 is ChatController }) as? ChatController {
                                                chatController.playShakeAnimation()
                                            }
                                            component.cancel(true)
                                        }
                                    }
                                )
                            )
                        ))
                    }
                    
                    if let toPeer, !transaction.flags.contains(.isStarGiftResale) {
                        tableItems.append(.init(
                            id: "referred",
                            title: transaction.flags.contains(.isPaidMessage) ? strings.Stars_Transaction_From : strings.StarsTransaction_StarRefReason_Referred,
                            component: AnyComponent(
                                Button(
                                    content: AnyComponent(
                                        PeerCellComponent(
                                            context: component.context,
                                            theme: theme,
                                            peer: toPeer
                                        )
                                    ),
                                    action: {
                                        if delayedCloseOnOpenPeer {
                                            component.openPeer(toPeer, true)
                                            Queue.mainQueue().after(1.0, {
                                                component.cancel(false)
                                            })
                                        } else {
                                            if let controller = controller() as? StarsTransactionScreen, let navigationController = controller.navigationController, let chatController = navigationController.viewControllers.first(where: { $0 is ChatController }) as? ChatController {
                                                chatController.playShakeAnimation()
                                            }
                                            component.cancel(true)
                                        }
                                    }
                                )
                            )
                        ))
                    }
                }
                if let starrefCommissionPermille = transaction.starrefCommissionPermille, transaction.starrefPeerId != nil {
                    if transaction.flags.contains(.isPaidMessage) || transaction.flags.contains(.isStarGiftResale) {
                        var totalStars = transaction.count
                        if let starrefCount = transaction.starrefAmount {
                            totalStars = CurrencyAmount(amount: totalStars.amount + starrefCount, currency: .stars)
                        }
                        let valueString = "\(presentationStringsFormattedNumber(abs(Int32(totalStars.amount.value)), dateTimeFormat.groupingSeparator))⭐️"
                        let valueAttributedString = NSMutableAttributedString(string: valueString, font: tableBoldFont, textColor: theme.list.itemDisclosureActions.constructive.fillColor)
                        let range = (valueAttributedString.string as NSString).range(of: "⭐️")
                        if range.location != NSNotFound {
                            valueAttributedString.addAttribute(ChatTextInputAttributes.customEmoji, value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: 0, file: nil, custom: .stars(tinted: false)), range: range)
                            valueAttributedString.addAttribute(.baselineOffset, value: 1.0, range: range)
                        }
                        tableItems.append(.init(
                            id: "paid",
                            title: strings.Stars_Transaction_Paid,
                            component: AnyComponent(
                                MultilineTextWithEntitiesComponent(
                                    context: component.context,
                                    animationCache: component.context.animationCache,
                                    animationRenderer: component.context.animationRenderer,
                                    placeholderColor: theme.list.mediaPlaceholderColor,
                                    text: .plain(valueAttributedString),
                                    maximumNumberOfLines: 0
                                )
                            ),
                            insets: UIEdgeInsets(top: 0.0, left: 12.0, bottom: 0.0, right: 5.0)
                        ))
                    } else {
                        tableItems.append(.init(
                            id: "commission",
                            title: strings.StarsTransaction_StarRefReason_Commission,
                            component: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: "\(formatPermille(starrefCommissionPermille))%", font: tableFont, textColor: tableTextColor)))),
                            insets: UIEdgeInsets(top: 0.0, left: 12.0, bottom: 0.0, right: 5.0)
                        ))
                    }
                }
            }

            if let transactionId {
                tableItems.append(.init(
                    id: "transaction",
                    title: strings.Stars_Transaction_Id,
                    component: AnyComponent(
                        Button(
                            content: AnyComponent(
                                TransactionCellComponent(
                                    backgroundColor: theme.actionSheet.opaqueItemBackgroundColor,
                                    textColor: tableTextColor,
                                    accentColor: tableLinkColor,
                                    transactionId: transactionId
                                )
                            ),
                            action: {
                                component.copyTransactionId(transactionId)
                            }
                        )
                    ),
                    insets: UIEdgeInsets(top: 0.0, left: 12.0, bottom: 0.0, right: 5.0)
                ))
            }
            
            if isSubscription, let additionalDate {
                tableItems.append(.init(
                    id: "additionalDate",
                    title: strings.Stars_Transaction_Subscription_Status_Subscribed,
                    component: AnyComponent(
                        MultilineTextComponent(text: .plain(NSAttributedString(string: stringForMediumDate(timestamp: additionalDate, strings: strings, dateTimeFormat: dateTimeFormat), font: tableFont, textColor: tableTextColor)))
                    )
                ))
            }
            
            let dateTitle: String
            if isSubscription {
                if date > Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970) {
                    if isCancelled {
                        dateTitle = strings.Stars_Transaction_Subscription_Status_Expires
                    } else {
                        dateTitle = strings.Stars_Transaction_Subscription_Status_Renews
                    }
                } else {
                    dateTitle = strings.Stars_Transaction_Subscription_Status_Expired
                }
            } else if isSubscriber {
                dateTitle = strings.Stars_Transaction_Subscription_Status_Subscribed
            } else {
                dateTitle = strings.Stars_Transaction_Date
            }
            tableItems.append(.init(
                id: "date",
                title: dateTitle,
                component: AnyComponent(
                    MultilineTextComponent(text: .plain(NSAttributedString(string: stringForMediumDate(timestamp: date, strings: strings, dateTimeFormat: dateTimeFormat), font: tableFont, textColor: tableTextColor)))
                )
            ))
            if let giftAvailability {
                let remainsString = presentationStringsFormattedNumber(giftAvailability.remains, environment.dateTimeFormat.groupingSeparator)
                let totalString = presentationStringsFormattedNumber(giftAvailability.total, environment.dateTimeFormat.groupingSeparator)
                tableItems.append(.init(
                    id: "availability",
                    title: strings.Gift_View_Availability,
                    component: AnyComponent(
                        MultilineTextComponent(text: .plain(NSAttributedString(string: strings.Gift_View_Availability_NewOf("\(remainsString)", "\(totalString)").string, font: tableFont, textColor: tableTextColor)))
                    )
                ))
            }
            
            if isSubscriber, let additionalDate {
                tableItems.append(.init(
                    id: "additionalDate",
                    title: strings.Stars_Transaction_Subscription_Status_Renews,
                    component: AnyComponent(
                        MultilineTextComponent(text: .plain(NSAttributedString(string: stringForMediumDate(timestamp: additionalDate, strings: strings, dateTimeFormat: dateTimeFormat), font: tableFont, textColor: tableTextColor)))
                    )
                ))
            }
            
            let table = table.update(
                component: TableComponent(
                    theme: environment.theme,
                    items: tableItems
                ),
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: .greatestFiniteMagnitude),
                transition: .immediate
            )
            
            let textFont = Font.regular(15.0)
            let boldTextFont = Font.semibold(15.0)
            let textColor = theme.actionSheet.secondaryTextColor
            let linkColor = theme.actionSheet.controlAccentColor
            let destructiveColor = theme.actionSheet.destructiveActionTextColor
            let markdownAttributes = MarkdownAttributes(body: MarkdownAttributeSet(font: textFont, textColor: textColor), bold: MarkdownAttributeSet(font: boldTextFont, textColor: textColor), link: MarkdownAttributeSet(font: textFont, textColor: linkColor), linkAttribute: { contents in
                return (TelegramTextAttributes.URL, contents)
            })
            let additional = additional.update(
                component: BalancedTextComponent(
                    text: .markdown(text: additionalText, attributes: markdownAttributes),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.2,
                    highlightColor: linkColor.withAlphaComponent(0.2),
                    highlightAction: { attributes in
                        if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] {
                            return NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)
                        } else {
                            return nil
                        }
                    },
                    tapAction: { attributes, _ in
                        if let controller = controller() as? StarsTransactionScreen, let navigationController = controller.navigationController as? NavigationController {
                            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                            component.context.sharedContext.openExternalUrl(context: component.context, urlContext: .generic, url: strings.Stars_Transaction_Terms_URL, forceExternal: false, presentationData: presentationData, navigationController: navigationController, dismissInput: {})
                            component.cancel(true)
                        }
                    }
                ),
                availableSize: CGSize(width: context.availableSize.width - textSideInset * 2.0, height: context.availableSize.height),
                transition: .immediate
            )
                    
            context.add(starChild
                .position(CGPoint(x: context.availableSize.width / 2.0, y: starOriginY))
            )
        
            var originY: CGFloat = 156.0
            switch giftAnimationSubject {
            case .generic:
                originY += 20.0
            case .unique:
                originY += 34.0
            default:
                break
            }
            context.add(title
                .position(CGPoint(x: context.availableSize.width / 2.0, y: originY))
            )
            if case .unique = giftAnimationSubject {
                originY += 17.0
            } else {
                originY += 21.0
            }
            
            let vibrantColor: UIColor
            if let previewPatternColor = giftCompositionExternalState.previewPatternColor {
                vibrantColor = previewPatternColor.withMultiplied(hue: 1.0, saturation: 1.02, brightness: 1.25).mixedWith(UIColor.white, alpha: 0.3)
            } else {
                vibrantColor = UIColor.white.withAlphaComponent(0.6)
            }
            
            var descriptionSize: CGSize = .zero
            if !descriptionText.isEmpty {
                let openAppExamples = component.openAppExamples
                let openPaidMessageFee = component.openPaidMessageFee
                
                if state.cachedChevronImage == nil || state.cachedChevronImage?.1 !== environment.theme {
                    state.cachedChevronImage = (generateTintedImage(image: UIImage(bundleImageName: "Settings/TextArrowRight"), color: linkColor)!, theme)
                }

                var textFont = Font.regular(15.0)
                let boldTextFont = Font.semibold(15.0)
                var textColor = theme.actionSheet.secondaryTextColor
                if case .unique = giftAnimationSubject {
                    textFont = Font.regular(13.0)
                    textColor = vibrantColor
                } else if countOnTop && !isSubscriber {
                    textColor = theme.list.itemPrimaryTextColor
                }
                let linkColor = theme.actionSheet.controlAccentColor
                
                let markdownAttributes = MarkdownAttributes(body: MarkdownAttributeSet(font: textFont, textColor: textColor), bold: MarkdownAttributeSet(font: boldTextFont, textColor: textColor), link: MarkdownAttributeSet(font: textFont, textColor: linkColor), linkAttribute: { contents in
                    return (TelegramTextAttributes.URL, contents)
                })
                let attributedString = parseMarkdownIntoAttributedString(descriptionText, attributes: markdownAttributes, textAlignment: .center).mutableCopy() as! NSMutableAttributedString
                if let range = attributedString.string.range(of: ">"), let chevronImage = state.cachedChevronImage?.0 {
                    attributedString.addAttribute(.attachment, value: chevronImage, range: NSRange(range, in: attributedString.string))
                }
                let descriptionAvailableWidth = isPaidMessage ? context.availableSize.width - sideInset * 2.0 - 16.0 : context.availableSize.width - sideInset * 2.0 - 60.0
                let description = description.update(
                    component: MultilineTextComponent(
                        text: .plain(attributedString),
                        horizontalAlignment: .center,
                        maximumNumberOfLines: 5,
                        lineSpacing: 0.2,
                        highlightColor: linkColor.withAlphaComponent(0.1),
                        highlightInset: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: -8.0),
                        highlightAction: { attributes in
                            if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] {
                                return NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)
                            } else {
                                return nil
                            }
                        },
                        tapAction: { attributes, _ in
                            if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] {
                                if isPaidMessage {
                                    openPaidMessageFee()
                                } else {
                                    openAppExamples()
                                }
                            }
                        }
                    ),
                    availableSize: CGSize(width: descriptionAvailableWidth, height: CGFloat.greatestFiniteMagnitude),
                    transition: .immediate
                )
                descriptionSize = description.size
                var descriptionOrigin = originY
                if countOnTop {
                    descriptionOrigin += amount.size.height + 13.0
                }
                context.add(description
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: descriptionOrigin + description.size.height / 2.0))
                )
                originY += description.size.height
                
                if case .unique = giftAnimationSubject {
                    originY += 6.0
                } else {
                    originY += 10.0
                }
            }
            
            let amountSpacing: CGFloat = countBackgroundColor != nil ? 4.0 : 1.0
            var totalAmountWidth: CGFloat = amount.size.width + amountSpacing + amountStar.size.width
            var amountOriginX: CGFloat = floor(context.availableSize.width - totalAmountWidth) / 2.0
            if let (statusText, statusColor) = transactionStatus {
                let refundText = transactionStatusText.update(
                    component: MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: statusText,
                            font: Font.medium(14.0),
                            textColor: statusColor
                        ))
                    ),
                    availableSize: context.availableSize,
                    transition: .immediate
                )
                let refundBackground = transactionStatusBackgound.update(
                    component: RoundedRectangle(
                        color: statusColor.withAlphaComponent(0.1),
                        cornerRadius: 6.0
                    ),
                    availableSize: CGSize(width: refundText.size.width + 10.0, height: refundText.size.height + 4.0),
                    transition: .immediate
                )
                totalAmountWidth += amountSpacing * 2.0 + refundBackground.size.width
                amountOriginX = floor(context.availableSize.width - totalAmountWidth) / 2.0
                
                context.add(refundBackground
                    .position(CGPoint(x: amountOriginX + amount.size.width + amountSpacing + amountStar.size.width + amountSpacing * 2.0 + refundBackground.size.width / 2.0, y: originY + refundBackground.size.height / 2.0))
                )
                context.add(refundText
                    .position(CGPoint(x: amountOriginX + amount.size.width + amountSpacing + amountStar.size.width + amountSpacing * 2.0 + refundBackground.size.width / 2.0, y: originY + refundBackground.size.height / 2.0))
                )
            }
            
            var amountOrigin = originY
            if countOnTop {
                amountOrigin -= descriptionSize.height + 10.0
                originY += amount.size.height + 26.0
            } else {
                originY += amount.size.height + 20.0
            }
            
            let amountLabelOriginX: CGFloat
            let amountStarOriginX: CGFloat
            if isSubscription || isSubscriber || boostsText != nil {
                amountStarOriginX = amountOriginX + amountStar.size.width / 2.0
                amountLabelOriginX = amountOriginX + amountStar.size.width + amountSpacing + amount.size.width / 2.0
            } else {
                amountLabelOriginX = amountOriginX + amount.size.width / 2.0
                amountStarOriginX = amountOriginX + amount.size.width + amountSpacing + amountStar.size.width / 2.0
            }
            
            var amountLabelOffsetY: CGFloat = 0.0
            var amountStarOffsetY: CGFloat = 0.0
            if let countBackgroundColor {
                let amountBackground = amountBackground.update(
                    component: RoundedRectangle(color: countBackgroundColor, cornerRadius: 23 / 2.0),
                    availableSize: CGSize(width: totalAmountWidth + 14.0, height: 23.0),
                    transition: .immediate
                )
                context.add(amountBackground
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: amountOrigin + amount.size.height / 2.0 + 1.0))
                )
                amountLabelOffsetY = 2.0
                amountStarOffsetY = 6.0
            }
            amountStarOffsetY += amountOffset.y
            
            context.add(amount
                .position(CGPoint(x: amountLabelOriginX, y: amountOrigin + amount.size.height / 2.0 + amountLabelOffsetY))
            )
            context.add(amountStar
                .position(CGPoint(x: amountStarOriginX, y: amountOrigin + amountStar.size.height / 2.0 - UIScreenPixel + amountStarOffsetY))
            )
            
            if case .unique = giftAnimationSubject {
                originY += 21.0
            }
               
            context.add(table
                .position(CGPoint(x: context.availableSize.width / 2.0, y: originY + table.size.height / 2.0))
            )
            originY += table.size.height + 23.0
            
            context.add(additional
                .position(CGPoint(x: context.availableSize.width / 2.0, y: originY + additional.size.height / 2.0))
            )
            originY += additional.size.height + 23.0
            
            if let statusText {
                originY += 7.0
                let status = status.update(
                    component: BalancedTextComponent(
                        text: .plain(NSAttributedString(string: statusText, font: textFont, textColor: statusIsDestructive ? destructiveColor : textColor)),
                        horizontalAlignment: .center,
                        maximumNumberOfLines: 0,
                        lineSpacing: 0.1
                    ),
                    availableSize: CGSize(width: context.availableSize.width - textSideInset * 2.0, height: context.availableSize.height),
                    transition: .immediate
                )
                context.add(status
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: originY + status.size.height / 2.0))
                )
                originY += status.size.height + (statusIsDestructive ? 23.0 : 13.0)
            }
            
            if let cancelButtonText {
                let cancelButton = cancelButton.update(
                    component: SolidRoundedButtonComponent(
                        title: cancelButtonText,
                        theme: SolidRoundedButtonComponent.Theme(backgroundColor: .clear, foregroundColor: linkColor),
                        font: .regular,
                        fontSize: 17.0,
                        height: 50.0,
                        cornerRadius: 10.0,
                        gloss: false,
                        iconName: nil,
                        animationName: nil,
                        iconPosition: .left,
                        isLoading: state.inProgress,
                        action: {
                            component.cancel(true)
                            if isSubscription {
                                component.updateSubscription()
                            }
                        }
                    ),
                    availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: 50.0),
                    transition: context.transition
                )
                
                let cancelButtonFrame = CGRect(origin: CGPoint(x: sideInset, y: originY), size: cancelButton.size)
                context.add(cancelButton
                    .position(CGPoint(x: cancelButtonFrame.midX, y: cancelButtonFrame.midY))
                )
                originY += cancelButton.size.height
                originY += 8.0
            }
            
            if let buttonText {
                let button = button.update(
                    component: SolidRoundedButtonComponent(
                        title: buttonText,
                        theme: SolidRoundedButtonComponent.Theme(theme: theme),
                        font: .bold,
                        fontSize: 17.0,
                        height: 50.0,
                        cornerRadius: 10.0,
                        gloss: false,
                        iconName: nil,
                        animationName: nil,
                        iconPosition: .left,
                        isLoading: state.inProgress,
                        action: {
                            component.cancel(true)
                            if isSubscription && cancelButtonText == nil {
                                component.updateSubscription()
                            }
                        }
                    ),
                    availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: 50.0),
                    transition: context.transition
                )
                
                let buttonFrame = CGRect(origin: CGPoint(x: sideInset, y: originY), size: button.size)
                context.add(button
                    .position(CGPoint(x: buttonFrame.midX, y: buttonFrame.midY))
                )
                originY += button.size.height
                originY += 7.0
            }
            
            context.add(closeButton
                .position(CGPoint(x: context.availableSize.width - environment.safeInsets.left - closeButton.size.width, y: 28.0))
            )
            
            let effectiveBottomInset: CGFloat = environment.metrics.isTablet ? 0.0 : environment.safeInsets.bottom
            return CGSize(width: context.availableSize.width, height: originY + 5.0 + effectiveBottomInset)
        }
    }
}

private final class StarsTransactionSheetComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let subject: StarsTransactionScreen.Subject
    let openPeer: (EnginePeer, Bool) -> Void
    let openMessage: (EngineMessage.Id) -> Void
    let openMedia: ([Media], @escaping (Media) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))?, @escaping (UIView) -> Void) -> Void
    let openAppExamples: () -> Void
    let openPaidMessageFee: () -> Void
    let copyTransactionId: (String) -> Void
    let updateSubscription: () -> Void
    let sendGift: (EnginePeer.Id) -> Void
    
    init(
        context: AccountContext,
        subject: StarsTransactionScreen.Subject,
        openPeer: @escaping (EnginePeer, Bool) -> Void,
        openMessage: @escaping (EngineMessage.Id) -> Void,
        openMedia: @escaping ([Media], @escaping (Media) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))?, @escaping (UIView) -> Void) -> Void,
        openAppExamples: @escaping () -> Void,
        openPaidMessageFee: @escaping () -> Void,
        copyTransactionId: @escaping (String) -> Void,
        updateSubscription: @escaping () -> Void,
        sendGift: @escaping (EnginePeer.Id) -> Void
    ) {
        self.context = context
        self.subject = subject
        self.openPeer = openPeer
        self.openMessage = openMessage
        self.openMedia = openMedia
        self.openAppExamples = openAppExamples
        self.openPaidMessageFee = openPaidMessageFee
        self.copyTransactionId = copyTransactionId
        self.updateSubscription = updateSubscription
        self.sendGift = sendGift
    }
    
    static func ==(lhs: StarsTransactionSheetComponent, rhs: StarsTransactionSheetComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.subject != rhs.subject {
            return false
        }
        return true
    }
    
    static var body: Body {
        let sheet = Child(SheetComponent<EnvironmentType>.self)
        let animateOut = StoredActionSlot(Action<Void>.self)
        
        let sheetExternalState = SheetComponent<EnvironmentType>.ExternalState()
        
        return { context in
            let environment = context.environment[EnvironmentType.self]
            let controller = environment.controller
            
            let sheet = sheet.update(
                component: SheetComponent<EnvironmentType>(
                    content: AnyComponent<EnvironmentType>(StarsTransactionSheetContent(
                        context: context.component.context,
                        subject: context.component.subject,
                        cancel: { animate in
                            if animate {
                                if let controller = controller() as? StarsTransactionScreen {
                                    controller.dismissAllTooltips()
                                    animateOut.invoke(Action { [weak controller] _ in
                                        controller?.dismiss(completion: nil)
                                    })
                                }
                            } else if let controller = controller() {
                                controller.dismiss(animated: false, completion: nil)
                            }
                        },
                        openPeer: context.component.openPeer,
                        openMessage: context.component.openMessage,
                        openMedia: context.component.openMedia,
                        openAppExamples: context.component.openAppExamples,
                        openPaidMessageFee: context.component.openPaidMessageFee,
                        copyTransactionId: context.component.copyTransactionId,
                        updateSubscription: context.component.updateSubscription,
                        sendGift: context.component.sendGift
                    )),
                    backgroundColor: .color(environment.theme.actionSheet.opaqueItemBackgroundColor),
                    followContentSizeChanges: true,
                    clipsContent: true,
                    externalState: sheetExternalState,
                    animateOut: animateOut,
                    onPan: {
                        if let controller = controller() as? StarsTransactionScreen {
                            controller.dismissAllTooltips()
                        }
                    }
                ),
                environment: {
                    environment
                    SheetComponentEnvironment(
                        isDisplaying: environment.value.isVisible,
                        isCentered: environment.metrics.widthClass == .regular,
                        hasInputHeight: !environment.inputHeight.isZero,
                        regularMetricsSize: CGSize(width: 430.0, height: 900.0),
                        dismiss: { animated in
                            if animated {
                                if let controller = controller() as? StarsTransactionScreen {
                                    controller.dismissAllTooltips()
                                    animateOut.invoke(Action { _ in
                                        controller.dismiss(completion: nil)
                                    })
                                }
                            } else {
                                if let controller = controller() as? StarsTransactionScreen {
                                    controller.dismissAllTooltips()
                                    controller.dismiss(completion: nil)
                                }
                            }
                        }
                    )
                },
                availableSize: context.availableSize,
                transition: context.transition
            )
            
            context.add(sheet
                .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height / 2.0))
            )
            
            if let controller = controller(), !controller.automaticallyControlPresentationContextLayout {
                let layout = ContainerViewLayout(
                    size: context.availableSize,
                    metrics: environment.metrics,
                    deviceMetrics: environment.deviceMetrics,
                    intrinsicInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: max(environment.safeInsets.bottom, sheetExternalState.contentHeight), right: 0.0),
                    safeInsets: UIEdgeInsets(top: 0.0, left: environment.safeInsets.left, bottom: 0.0, right: environment.safeInsets.right),
                    additionalInsets: .zero,
                    statusBarHeight: environment.statusBarHeight,
                    inputHeight: nil,
                    inputHeightIsInteractivellyChanging: false,
                    inVoiceOver: false
                )
                controller.presentationContext.containerLayoutUpdated(layout, transition: context.transition.containedViewLayoutTransition)
            }
            
            return context.availableSize
        }
    }
}

public class StarsTransactionScreen: ViewControllerComponentContainer {
    enum SubscriptionAction {
        case cancel
        case renew
    }
    
    public enum Subject: Equatable {
        case transaction(StarsContext.State.Transaction, EnginePeer)
        case receipt(BotPaymentReceipt)
        case gift(EngineMessage)
        case subscription(StarsContext.State.Subscription)
        case importer(EnginePeer, StarsSubscriptionPricing, PeerInvitationImportersState.Importer, Double)
        case boost(EnginePeer.Id, ChannelBoostersContext.State.Boost)
    }
    
    private let context: AccountContext
    public var disposed: () -> Void = {}
    
    private let hapticFeedback = HapticFeedback()
    
    public init(
        context: AccountContext,
        subject: StarsTransactionScreen.Subject,
        forceDark: Bool = false,
        updateSubscription: @escaping (Bool) -> Void = { _ in }
    ) {
        self.context = context
        
        var openPeerImpl: ((EnginePeer, Bool) -> Void)?
        var openMessageImpl: ((EngineMessage.Id) -> Void)?
        var openMediaImpl: (([Media], @escaping (Media) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))?, @escaping (UIView) -> Void) -> Void)?
        var openAppExamplesImpl: (() -> Void)?
        var openPaidMessageFeeImpl: (() -> Void)?
        var copyTransactionIdImpl: ((String) -> Void)?
        var updateSubscriptionImpl: (() -> Void)?
        var sendGiftImpl: ((EnginePeer.Id) -> Void)?
        
        super.init(
            context: context,
            component: StarsTransactionSheetComponent(
                context: context,
                subject: subject,
                openPeer: { peerId, isProfile in
                    openPeerImpl?(peerId, isProfile)
                },
                openMessage: { messageId in
                    openMessageImpl?(messageId)
                },
                openMedia: { media, transitionNode, addToTransitionSurface in
                    openMediaImpl?(media, transitionNode, addToTransitionSurface)
                },
                openAppExamples: {
                    openAppExamplesImpl?()
                },
                openPaidMessageFee: {
                    openPaidMessageFeeImpl?()
                },
                copyTransactionId: { transactionId in
                    copyTransactionIdImpl?(transactionId)
                },
                updateSubscription: {
                    updateSubscriptionImpl?()
                },
                sendGift: { peerId in
                    sendGiftImpl?(peerId)
                }
            ),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            theme: forceDark ? .dark : .default
        )
        
        self.navigationPresentation = .flatModal
        self.automaticallyControlPresentationContextLayout = false
        
        openPeerImpl = { [weak self] peer, isProfile in
            guard let self, let navigationController = self.navigationController as? NavigationController else {
                return
            }
            self.dismissAllTooltips()
            
            let _ = (context.engine.data.get(
                TelegramEngine.EngineData.Item.Peer.Peer(id: peer.id)
            )
            |> deliverOnMainQueue).start(next: { peer in
                guard let peer else {
                    return
                }
                if isProfile {
                    if let controller = context.sharedContext.makePeerInfoController(context: context, updatedPresentationData: nil, peer: peer._asPeer(), mode: .generic, avatarInitiallyExpanded: false, fromChat: false, requestsContext: nil) {
                        navigationController.pushViewController(controller)
                    }
                } else {
                    context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, chatController: nil, context: context, chatLocation: .peer(peer), subject: nil, botStart: nil, updateTextInputState: nil, keepStack: .always, useExisting: true, purposefulAction: nil, scrollToEndIfExists: false, activateMessageSearch: nil, animated: true))
                }
            })
        }
        
        openMessageImpl = { [weak self] messageId in
            guard let self else {
                return
            }
            let _ = (context.engine.data.get(
                TelegramEngine.EngineData.Item.Peer.Peer(id: messageId.peerId)
            )
            |> deliverOnMainQueue).start(next: { peer in
                guard let peer = peer else {
                    return
                }
                if let navigationController = self.navigationController as? NavigationController {
                    context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: context, chatLocation: .peer(peer), subject: .message(id: .id(messageId), highlight: ChatControllerSubject.MessageHighlight(quote: nil), timecode: nil, setupReply: false), keepStack: .always, useExisting: false, purposefulAction: {}, peekData: nil))
                }
            })
        }
        
        openMediaImpl = { [weak self] media, transitionNode, addToTransitionSurface in
            guard let self else {
                return
            }
        
            let message = Message(
                stableId: 0,
                stableVersion: 0,
                id: MessageId(peerId: PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(0)), namespace: Namespaces.Message.Local, id: 0),
                globallyUniqueId: 0,
                groupingKey: nil,
                groupInfo: nil,
                threadId: nil,
                timestamp: 0,
                flags: [],
                tags: [],
                globalTags: [],
                localTags: [],
                customTags: [],
                forwardInfo: nil,
                author: nil,
                text: "",
                attributes: [],
                media: [TelegramMediaPaidContent(amount: 0, extendedMedia: media.map { .full(media: $0) })],
                peers: SimpleDictionary(),
                associatedMessages: SimpleDictionary(),
                associatedMessageIds: [],
                associatedMedia: [:],
                associatedThreadInfo: nil,
                associatedStories: [:]
            )
            let gallery = GalleryController(context: self.context, source: .standaloneMessage(message, 0), replaceRootController: { _, _ in
            }, baseNavigationController: nil)
            self.present(gallery, in: .window(.root), with: GalleryControllerPresentationArguments(transitionArguments: { messageId, media in
                if let transitionNode = transitionNode(media) {
                    return GalleryTransitionArguments(transitionNode: transitionNode, addToTransitionSurface: addToTransitionSurface)
                }
                return nil
            }))
        }
        
        openAppExamplesImpl = { [weak self] in
            guard let self else {
                return
            }
            let _ = (context.sharedContext.makeMiniAppListScreenInitialData(context: context)
            |> deliverOnMainQueue).startStandalone(next: { [weak self] initialData in
                guard let self, let navigationController = self.navigationController as? NavigationController else {
                    return
                }
                navigationController.pushViewController(context.sharedContext.makeMiniAppListScreen(context: context, initialData: initialData))
            })
        }
        
        openPaidMessageFeeImpl = { [weak self] in
            guard let self, let navigationController = self.navigationController as? NavigationController else {
                return
            }
            self.dismissAnimated()
            
            let _ = (context.engine.privacy.requestAccountPrivacySettings()
            |> deliverOnMainQueue).start(next: { [weak navigationController] privacySettings in
                let controller = context.sharedContext.makeIncomingMessagePrivacyScreen(context: context, value: privacySettings.globalSettings.nonContactChatsPrivacy, exceptions: privacySettings.noPaidMessages, update: { settingValue in
                    let _ = context.engine.privacy.updateNonContactChatsPrivacy(value: settingValue).start()
                })
                Queue.mainQueue().after(0.4) {
                    navigationController?.pushViewController(controller)
                }
            })
        }
        
        copyTransactionIdImpl = { [weak self] transactionId in
            guard let self else {
                return
            }
            UIPasteboard.general.string = transactionId
            
            self.dismissAllTooltips()
            
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            self.present(UndoOverlayController(presentationData: presentationData, content: .copy(text: presentationData.strings.Stars_Transaction_CopiedId), elevatedLayout: false, position: .bottom, action: { _ in return true }), in: .current)
            
            HapticFeedback().tap()
        }
        
        updateSubscriptionImpl = { [weak self] in
            guard let self, case let .subscription(subscription) = subject, let navigationController = self.navigationController as? NavigationController else {
                return
            }
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            var titleAndText: (String, String)?
            if subscription.flags.contains(.isCancelled) {
                updateSubscription(false)
                if subscription.untilDate > Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970) {
                    titleAndText = (
                        presentationData.strings.Stars_Transaction_Subscription_Renewed_Title,
                        presentationData.strings.Stars_Transaction_Subscription_Renewed_Text(subscription.peer.compactDisplayTitle).string
                    )
                }
            } else {
                if subscription.untilDate < Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970) {
                    updateSubscription(false)
                } else {
                    updateSubscription(true)
                    titleAndText = (
                        presentationData.strings.Stars_Transaction_Subscription_Cancelled_Title,
                        presentationData.strings.Stars_Transaction_Subscription_Cancelled_Text(subscription.peer.compactDisplayTitle, stringForMediumDate(timestamp: subscription.untilDate, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat)).string
                    )
                }
            }
            
            if let (title, text) = titleAndText {
                let controller = UndoOverlayController(presentationData: presentationData, content: .invitedToVoiceChat(context: context, peer: subscription.peer, title: title, text: text, action: nil, duration: 3.0), elevatedLayout: false, position: .bottom, action: { _ in return true })
                Queue.mainQueue().after(0.6) {
                    navigationController.presentOverlay(controller: controller)
                }
            }
        }
        
        sendGiftImpl = { [weak self] peerId in
            guard let self else {
                return
            }
            let _ = (context.engine.payments.premiumGiftCodeOptions(peerId: nil, onlyCached: true)
            |> filter { !$0.isEmpty }
            |> deliverOnMainQueue).start(next: { giftOptions in
                let premiumOptions = giftOptions.filter { $0.users == 1 }.map { CachedPremiumGiftOption(months: $0.months, currency: $0.currency, amount: $0.amount, botUrl: "", storeProductId: $0.storeProductId) }
                let controller = context.sharedContext.makeGiftOptionsController(context: context, peerId: peerId, premiumOptions: premiumOptions, hasBirthday: false, completion: nil)
                self.push(controller)
            })
        }
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.disposed()
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.disablesInteractiveModalDismiss = true
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.dismissAllTooltips()
    }
    
    public func dismissAnimated() {
        self.dismissAllTooltips()

        if let view = self.node.hostView.findTaggedView(tag: SheetComponent<ViewControllerComponentContainer.Environment>.View.Tag()) as? SheetComponent<ViewControllerComponentContainer.Environment>.View {
            view.dismissAnimated()
        }
    }
    
    fileprivate func dismissAllTooltips() {
        self.window?.forEachController({ controller in
            if let controller = controller as? UndoOverlayController {
                controller.dismiss()
            }
        })
        self.forEachController({ controller in
            if let controller = controller as? UndoOverlayController {
                controller.dismiss()
            }
            return true
        })
    }
}

private final class TableComponent: CombinedComponent {
    class Item: Equatable {
        public let id: AnyHashable
        public let title: String
        public let component: AnyComponent<Empty>
        public let insets: UIEdgeInsets?

        public init<IdType: Hashable>(id: IdType, title: String, component: AnyComponent<Empty>, insets: UIEdgeInsets? = nil) {
            self.id = AnyHashable(id)
            self.title = title
            self.component = component
            self.insets = insets
        }

        public static func == (lhs: Item, rhs: Item) -> Bool {
            if lhs.id != rhs.id {
                return false
            }
            if lhs.title != rhs.title {
                return false
            }
            if lhs.component != rhs.component {
                return false
            }
            if lhs.insets != rhs.insets {
                return false
            }
            return true
        }
    }
    
    private let theme: PresentationTheme
    private let items: [Item]

    public init(theme: PresentationTheme, items: [Item]) {
        self.theme = theme
        self.items = items
    }

    public static func ==(lhs: TableComponent, rhs: TableComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.items != rhs.items {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        var cachedBorderImage: (UIImage, PresentationTheme)?
    }
    
    func makeState() -> State {
        return State()
    }

    public static var body: Body {
        let leftColumnBackground = Child(Rectangle.self)
        let verticalBorder = Child(Rectangle.self)
        let titleChildren = ChildMap(environment: Empty.self, keyedBy: AnyHashable.self)
        let valueChildren = ChildMap(environment: Empty.self, keyedBy: AnyHashable.self)
        let borderChildren = ChildMap(environment: Empty.self, keyedBy: AnyHashable.self)
        let outerBorder = Child(Image.self)

        return { context in
            let verticalPadding: CGFloat = 11.0
            let horizontalPadding: CGFloat = 12.0
            let borderWidth: CGFloat = 1.0
            
            let backgroundColor = context.component.theme.actionSheet.opaqueItemBackgroundColor
            let borderColor = backgroundColor.mixedWith(context.component.theme.list.itemBlocksSeparatorColor, alpha: 0.6)
            
            var leftColumnWidth: CGFloat = 0.0
            
            var updatedTitleChildren: [_UpdatedChildComponent] = []
            var updatedValueChildren: [(_UpdatedChildComponent, UIEdgeInsets)] = []
            var updatedBorderChildren: [_UpdatedChildComponent] = []
            
            for item in context.component.items {
                let titleChild = titleChildren[item.id].update(
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: item.title, font: Font.regular(15.0), textColor: context.component.theme.list.itemPrimaryTextColor))
                    )),
                    availableSize: context.availableSize,
                    transition: context.transition
                )
                updatedTitleChildren.append(titleChild)
                
                if titleChild.size.width > leftColumnWidth {
                    leftColumnWidth = titleChild.size.width
                }
            }
            
            leftColumnWidth = max(100.0, leftColumnWidth + horizontalPadding * 2.0)
            let rightColumnWidth = context.availableSize.width - leftColumnWidth
            
            var i = 0
            var rowHeights: [Int: CGFloat] = [:]
            var totalHeight: CGFloat = 0.0
            
            for item in context.component.items {
                let titleChild = updatedTitleChildren[i]
                
                let insets: UIEdgeInsets
                if let customInsets = item.insets {
                    insets = customInsets
                } else {
                    insets = UIEdgeInsets(top: 0.0, left: horizontalPadding, bottom: 0.0, right: horizontalPadding)
                }
                let valueChild = valueChildren[item.id].update(
                    component: item.component,
                    availableSize: CGSize(width: rightColumnWidth - insets.left - insets.right, height: context.availableSize.height),
                    transition: context.transition
                )
                updatedValueChildren.append((valueChild, insets))
                
                let rowHeight = max(40.0, max(titleChild.size.height, valueChild.size.height) + verticalPadding * 2.0)
                rowHeights[i] = rowHeight
                totalHeight += rowHeight
                
                if i < context.component.items.count - 1 {
                    let borderChild = borderChildren[item.id].update(
                        component: AnyComponent(Rectangle(color: borderColor)),
                        availableSize: CGSize(width: context.availableSize.width, height: borderWidth),
                        transition: context.transition
                    )
                    updatedBorderChildren.append(borderChild)
                }
                
                i += 1
            }
            
            let leftColumnBackground = leftColumnBackground.update(
                component: Rectangle(color: context.component.theme.list.itemInputField.backgroundColor),
                availableSize: CGSize(width: leftColumnWidth, height: totalHeight),
                transition: context.transition
            )
            context.add(
                leftColumnBackground
                    .position(CGPoint(x: leftColumnWidth / 2.0, y: totalHeight / 2.0))
            )
            
            let borderImage: UIImage
            if let (currentImage, theme) = context.state.cachedBorderImage, theme === context.component.theme {
                borderImage = currentImage
            } else {
                let borderRadius: CGFloat = 5.0
                borderImage = generateImage(CGSize(width: 16.0, height: 16.0), rotatedContext: { size, context in
                    let bounds = CGRect(origin: .zero, size: size)
                    context.setFillColor(backgroundColor.cgColor)
                    context.fill(bounds)
                    
                    let path = CGPath(roundedRect: bounds.insetBy(dx: borderWidth / 2.0, dy: borderWidth / 2.0), cornerWidth: borderRadius, cornerHeight: borderRadius, transform: nil)
                    context.setBlendMode(.clear)
                    context.addPath(path)
                    context.fillPath()
                    
                    context.setBlendMode(.normal)
                    context.setStrokeColor(borderColor.cgColor)
                    context.setLineWidth(borderWidth)
                    context.addPath(path)
                    context.strokePath()
                })!.stretchableImage(withLeftCapWidth: 5, topCapHeight: 5)
                context.state.cachedBorderImage = (borderImage, context.component.theme)
            }
            
            let outerBorder = outerBorder.update(
                component: Image(image: borderImage),
                availableSize: CGSize(width: context.availableSize.width, height: totalHeight),
                transition: context.transition
            )
            context.add(outerBorder
                .position(CGPoint(x: context.availableSize.width / 2.0, y: totalHeight / 2.0))
            )
            
            let verticalBorder = verticalBorder.update(
                component: Rectangle(color: borderColor),
                availableSize: CGSize(width: borderWidth, height: totalHeight),
                transition: context.transition
            )
            context.add(
                verticalBorder
                    .position(CGPoint(x: leftColumnWidth - borderWidth / 2.0, y: totalHeight / 2.0))
            )
            
            i = 0
            var originY: CGFloat = 0.0
            for (titleChild, (valueChild, valueInsets)) in zip(updatedTitleChildren, updatedValueChildren) {
                let rowHeight = rowHeights[i] ?? 0.0
                
                let titleFrame = CGRect(origin: CGPoint(x: horizontalPadding, y: originY + verticalPadding), size: titleChild.size)
                let valueFrame = CGRect(origin: CGPoint(x: leftColumnWidth + valueInsets.left, y: originY + verticalPadding), size: valueChild.size)
                
                context.add(titleChild
                    .position(titleFrame.center)
                )
                
                context.add(valueChild
                    .position(valueFrame.center)
                )
                
                if i < updatedBorderChildren.count {
                    let borderChild = updatedBorderChildren[i]
                    context.add(borderChild
                        .position(CGPoint(x: context.availableSize.width / 2.0, y: originY + rowHeight - borderWidth / 2.0))
                    )
                }
                
                originY += rowHeight
                i += 1
            }
            
            return CGSize(width: context.availableSize.width, height: totalHeight)
        }
    }
}

private final class PeerCellComponent: Component {
    let context: AccountContext
    let theme: PresentationTheme
    let peer: EnginePeer?

    init(context: AccountContext, theme: PresentationTheme, peer: EnginePeer?) {
        self.context = context
        self.theme = theme
        self.peer = peer
    }

    static func ==(lhs: PeerCellComponent, rhs: PeerCellComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.peer != rhs.peer {
            return false
        }
        return true
    }

    final class View: UIView {
        private let avatar = ComponentView<Empty>()
        private let text = ComponentView<Empty>()
                
        private var component: PeerCellComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: PeerCellComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
                                    
            let avatarSize = CGSize(width: 22.0, height: 22.0)
            let spacing: CGFloat = 6.0
            
            let peerName: String
            let peer: StarsContext.State.Transaction.Peer
            if let peerValue = component.peer {
                peerName = peerValue.compactDisplayTitle
                peer = .peer(peerValue)
            } else {
                peerName = "Unknown User"
                peer = .fragment
            }
            
            let avatarNaturalSize = self.avatar.update(
                transition: .immediate,
                component: AnyComponent(
                    StarsAvatarComponent(context: component.context, theme: component.theme, peer: peer, photo: nil, media: [], uniqueGift: nil, backgroundColor: .clear)
                ),
                environment: {},
                containerSize: CGSize(width: 40.0, height: 40.0)
            )
            
            let textSize = self.text.update(
                transition: .immediate,
                component: AnyComponent(
                    MultilineTextComponent(
                        text: .plain(NSAttributedString(string: peerName, font: Font.regular(15.0), textColor: component.theme.list.itemAccentColor, paragraphAlignment: .left))
                    )
                ),
                environment: {},
                containerSize: CGSize(width: availableSize.width - avatarSize.width - spacing, height: availableSize.height)
            )
            
            let size = CGSize(width: avatarSize.width + textSize.width + spacing, height: textSize.height)
            
            let avatarFrame = CGRect(origin: CGPoint(x: 0.0, y: floorToScreenPixels((size.height - avatarSize.height) / 2.0)), size: avatarSize)
            
            if let view = self.avatar.view {
                if view.superview == nil {
                    self.addSubview(view)
                }
                let scale = avatarSize.width / avatarNaturalSize.width
                view.transform = CGAffineTransform(scaleX: scale, y: scale)
                view.frame = avatarFrame
            }
            
            if let view = self.text.view {
                if view.superview == nil {
                    self.addSubview(view)
                }
                let textFrame = CGRect(origin: CGPoint(x: avatarSize.width + spacing, y: floorToScreenPixels((size.height - textSize.height) / 2.0)), size: textSize)
                transition.setFrame(view: view, frame: textFrame)
            }
            
            return size
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private final class TransactionCellComponent: Component {
    let backgroundColor: UIColor
    let textColor: UIColor
    let accentColor: UIColor
    let transactionId: String
    
    init(backgroundColor: UIColor, textColor: UIColor, accentColor: UIColor, transactionId: String) {
        self.backgroundColor = backgroundColor
        self.textColor = textColor
        self.accentColor = accentColor
        self.transactionId = transactionId
    }

    static func ==(lhs: TransactionCellComponent, rhs: TransactionCellComponent) -> Bool {
        if lhs.backgroundColor != rhs.backgroundColor {
            return false
        }
        if lhs.textColor != rhs.textColor {
            return false
        }
        if lhs.accentColor != rhs.accentColor {
            return false
        }
        if lhs.transactionId != rhs.transactionId {
            return false
        }
        return true
    }

    final class View: UIView {
        private let text = ComponentView<Empty>()
        private let button = ComponentView<Empty>()
        private let gradientView = UIImageView()
        
        private var component: TransactionCellComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.layer.allowsGroupOpacity = true
            
            self.gradientView.image = generateGradientImage(size: CGSize(width: 40.0, height: 1.0), colors: [UIColor.white.withAlphaComponent(0.0), UIColor.white, UIColor.white], locations: [0.0, 0.65, 1.0], direction: .horizontal)?.withRenderingMode(.alwaysTemplate)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: TransactionCellComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
                                                
            self.gradientView.tintColor = component.backgroundColor
            
            let buttonSize = self.button.update(
                transition: .immediate,
                component: AnyComponent(
                    BundleIconComponent(
                        name: "Chat/Context Menu/Copy",
                        tintColor: component.accentColor
                    )
                ),
                environment: {},
                containerSize: CGSize(width: availableSize.width, height: availableSize.height)
            )
                        
            let textSize = self.text.update(
                transition: .immediate,
                component: AnyComponent(
                    MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: component.transactionId,
                            font: Font.monospace(15.0),
                            textColor: component.textColor,
                            paragraphAlignment: .left
                        )),
                        maximumNumberOfLines: 1
                    )
                ),
                environment: {},
                containerSize: CGSize(width: availableSize.width - buttonSize.width + 10.0, height: availableSize.height)
            )
            
            let size = CGSize(width: availableSize.width, height: textSize.height)
            
            let textFrame = CGRect(origin: CGPoint(x: 0.0, y: floorToScreenPixels((size.height - textSize.height) / 2.0) + 1.0), size: textSize)
            if let textView = self.text.view {
                if textView.superview == nil {
                    self.addSubview(textView)
                    self.addSubview(self.gradientView)
                }
                transition.setFrame(view: textView, frame: textFrame)
            }
            
            let buttonFrame = CGRect(origin: CGPoint(x: availableSize.width - buttonSize.width - 2.0, y: floorToScreenPixels((size.height - buttonSize.height) / 2.0)), size: buttonSize)
            if let buttonView = self.button.view {
                if buttonView.superview == nil {
                    self.addSubview(buttonView)
                }
                transition.setFrame(view: buttonView, frame: buttonFrame)
            }
            
            self.gradientView.frame = CGRect(x: size.width - buttonSize.width - 32.0, y: 0.0, width: 40.0, height: size.height)
            
            return size
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private func generateCloseButtonImage(backgroundColor: UIColor, foregroundColor: UIColor) -> UIImage? {
    return generateImage(CGSize(width: 30.0, height: 30.0), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        
        context.setFillColor(backgroundColor.cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
        
        context.setLineWidth(2.0)
        context.setLineCap(.round)
        context.setStrokeColor(foregroundColor.cgColor)
        
        context.move(to: CGPoint(x: 10.0, y: 10.0))
        context.addLine(to: CGPoint(x: 20.0, y: 20.0))
        context.strokePath()
        
        context.move(to: CGPoint(x: 20.0, y: 10.0))
        context.addLine(to: CGPoint(x: 10.0, y: 20.0))
        context.strokePath()
    })
}

private final class ButtonContentComponent: Component {
    let context: AccountContext
    let text: String
    let color: UIColor
    
    public init(
        context: AccountContext,
        text: String,
        color: UIColor
    ) {
        self.context = context
        self.text = text
        self.color = color
    }

    public static func ==(lhs: ButtonContentComponent, rhs: ButtonContentComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.text != rhs.text {
            return false
        }
        if lhs.color != rhs.color {
            return false
        }
        return true
    }

    public final class View: UIView {
        private var component: ButtonContentComponent?
        private weak var componentState: EmptyComponentState?
        
        private let backgroundLayer = SimpleLayer()
        private let title = ComponentView<Empty>()
                
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.layer.addSublayer(self.backgroundLayer)
            self.backgroundLayer.masksToBounds = true
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: ButtonContentComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.componentState = state
                        
            let attributedText = NSAttributedString(string: component.text, font: Font.regular(11.0), textColor: component.color)
            let titleSize = self.title.update(
                transition: transition,
                component: AnyComponent(
                    MultilineTextComponent(text: .plain(attributedText))
                ),
                environment: {},
                containerSize: availableSize
            )
            
            let padding: CGFloat = 6.0
            let size = CGSize(width: titleSize.width + padding * 2.0, height: 18.0)
                        
            let titleFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - titleSize.width) / 2.0), y: floorToScreenPixels((size.height - titleSize.height) / 2.0)), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                transition.setFrame(view: titleView, frame: titleFrame)
            }
            
            let backgroundColor = component.color.withAlphaComponent(0.1)
            self.backgroundLayer.backgroundColor = backgroundColor.cgColor
            transition.setFrame(layer: self.backgroundLayer, frame: CGRect(origin: .zero, size: size))
            self.backgroundLayer.cornerRadius = size.height / 2.0
                        
            return size
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }

    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
