import Foundation
import SwiftSignalKit
import Postbox

public extension TelegramEngine {
    final class Payments {
        private let account: Account
        
        init(account: Account) {
            self.account = account
        }
        
        public func getBankCardInfo(cardNumber: String) -> Signal<BankCardInfo?, NoError> {
            return _internal_getBankCardInfo(account: self.account, cardNumber: cardNumber)
        }
        
        public func fetchBotPaymentInvoice(source: BotPaymentInvoiceSource) -> Signal<TelegramMediaInvoice, BotPaymentFormRequestError> {
            return _internal_fetchBotPaymentInvoice(postbox: self.account.postbox, network: self.account.network, source: source)
        }
        
        public func fetchBotPaymentForm(source: BotPaymentInvoiceSource, themeParams: [String: Any]?) -> Signal<BotPaymentForm, BotPaymentFormRequestError> {
            return _internal_fetchBotPaymentForm(accountPeerId: self.account.peerId, postbox: self.account.postbox, network: self.account.network, source: source, themeParams: themeParams)
        }
        
        public func validateBotPaymentForm(saveInfo: Bool, source: BotPaymentInvoiceSource, formInfo: BotPaymentRequestedInfo) -> Signal<BotPaymentValidatedFormInfo, ValidateBotPaymentFormError> {
            return _internal_validateBotPaymentForm(account: self.account, saveInfo: saveInfo, source: source, formInfo: formInfo)
        }
        
        public func sendBotPaymentForm(source: BotPaymentInvoiceSource, formId: Int64, validatedInfoId: String?, shippingOptionId: String?, tipAmount: Int64?, credentials: BotPaymentCredentials) -> Signal<SendBotPaymentResult, SendBotPaymentFormError> {
            return _internal_sendBotPaymentForm(account: self.account, formId: formId, source: source, validatedInfoId: validatedInfoId, shippingOptionId: shippingOptionId, tipAmount: tipAmount, credentials: credentials)
        }
        
        public func requestBotPaymentReceipt(messageId: MessageId) -> Signal<BotPaymentReceipt, RequestBotPaymentReceiptError> {
            return _internal_requestBotPaymentReceipt(account: self.account, messageId: messageId)
        }
        
        public func clearBotPaymentInfo(info: BotPaymentInfo) -> Signal<Void, NoError> {
            return _internal_clearBotPaymentInfo(network: self.account.network, info: info)
        }
        
        public func sendAppStoreReceipt(receipt: Data, purpose: AppStoreTransactionPurpose) -> Signal<Never, AssignAppStoreTransactionError> {
            return _internal_sendAppStoreReceipt(postbox: self.account.postbox, network: self.account.network, stateManager: self.account.stateManager, receipt: receipt, purpose: purpose)
        }
        
        public func canPurchasePremium(purpose: AppStoreTransactionPurpose) -> Signal<Bool, NoError> {
            return _internal_canPurchasePremium(postbox: self.account.postbox, network: self.account.network, purpose: purpose)
        }
        
        public func checkPremiumGiftCode(slug: String) -> Signal<PremiumGiftCodeInfo?, NoError> {
            return _internal_checkPremiumGiftCode(account: self.account, slug: slug)
        }
        
        public func applyPremiumGiftCode(slug: String) -> Signal<Never, ApplyPremiumGiftCodeError> {
            return _internal_applyPremiumGiftCode(account: self.account, slug: slug)
        }
        
        public func premiumGiftCodeOptions(peerId: EnginePeer.Id?, onlyCached: Bool = false) -> Signal<[PremiumGiftCodeOption], NoError> {
            return _internal_premiumGiftCodeOptions(account: self.account, peerId: peerId, onlyCached: onlyCached)
        }
        
        public func premiumGiveawayInfo(peerId: EnginePeer.Id, messageId: EngineMessage.Id) -> Signal<PremiumGiveawayInfo?, NoError> {
            return _internal_getPremiumGiveawayInfo(account: self.account, peerId: peerId, messageId: messageId)
        }
        
        public func launchPrepaidGiveaway(peerId: EnginePeer.Id, id: Int64, purpose: LaunchGiveawayPurpose, additionalPeerIds: [EnginePeer.Id], countries: [String], onlyNewSubscribers: Bool, showWinners: Bool, prizeDescription: String?, randomId: Int64, untilDate: Int32) -> Signal<Never, LaunchPrepaidGiveawayError> {
            return _internal_launchPrepaidGiveaway(account: self.account, peerId: peerId, purpose: purpose, id: id, additionalPeerIds: additionalPeerIds, countries: countries, onlyNewSubscribers: onlyNewSubscribers, showWinners: showWinners, prizeDescription: prizeDescription, randomId: randomId, untilDate: untilDate)
        }
        
        public func starsTopUpOptions() -> Signal<[StarsTopUpOption], NoError> {
            return _internal_starsTopUpOptions(account: self.account)
        }
        
        public func starsGiftOptions(peerId: EnginePeer.Id?) -> Signal<[StarsGiftOption], NoError> {
            return _internal_starsGiftOptions(account: self.account, peerId: peerId)
        }
        
        public func starsGiveawayOptions() -> Signal<[StarsGiveawayOption], NoError> {
            return _internal_starsGiveawayOptions(account: self.account)
        }
        
        public func peerStarsContext() -> StarsContext {
            return StarsContext(account: self.account, ton: false)
        }
        
        public func peerTonContext() -> StarsContext {
            return StarsContext(account: self.account, ton: true)
        }
        
        public func peerStarsRevenueContext(peerId: EnginePeer.Id, ton: Bool) -> StarsRevenueStatsContext {
            return StarsRevenueStatsContext(account: self.account, peerId: peerId, ton: ton)
        }
        
        public func peerStarsTransactionsContext(subject: StarsTransactionsContext.Subject, mode: StarsTransactionsContext.Mode) -> StarsTransactionsContext {
            return StarsTransactionsContext(account: self.account, subject: subject, mode: mode)
        }
        
        public func peerStarsSubscriptionsContext(starsContext: StarsContext?, missingBalance: Bool = false) -> StarsSubscriptionsContext {
            return StarsSubscriptionsContext(account: self.account, starsContext: starsContext, missingBalance: missingBalance)
        }
        
        public func sendStarsPaymentForm(formId: Int64, source: BotPaymentInvoiceSource) -> Signal<SendBotPaymentResult, SendBotPaymentFormError> {
            return _internal_sendStarsPaymentForm(account: self.account, formId: formId, source: source)
        }
        
        public func fulfillStarsSubscription(peerId: EnginePeer.Id, subscriptionId: String) -> Signal<Never, FulfillStarsSubsciptionError> {
            return _internal_fulfillStarsSubscription(account: self.account, peerId: peerId, subscriptionId: subscriptionId)
        }
        
        public func cachedStarGifts() -> Signal<[StarGift]?, NoError> {
            return _internal_cachedStarGifts(postbox: self.account.postbox)
            |> map { starGiftsList in
                return starGiftsList?.items
            }
        }
        
        public func keepStarGiftsUpdated() -> Signal<Never, NoError> {
            return _internal_keepCachedStarGiftsUpdated(postbox: self.account.postbox, network: self.account.network)
        }
        
        public func convertStarGift(reference: StarGiftReference) -> Signal<Never, NoError> {
            return _internal_convertStarGift(account: self.account, reference: reference)
        }
        
        public func updateStarGiftAddedToProfile(reference: StarGiftReference, added: Bool) -> Signal<Never, NoError> {
            return _internal_updateStarGiftAddedToProfile(account: self.account, reference: reference, added: added)
        }
        
        public func transferStarGift(prepaid: Bool, reference: StarGiftReference, peerId: EnginePeer.Id) -> Signal<Never, TransferStarGiftError> {
            return _internal_transferStarGift(account: self.account, prepaid: prepaid, reference: reference, peerId: peerId)
        }
        
        public func buyStarGift(slug: String, peerId: EnginePeer.Id, price: Int64?) -> Signal<Never, BuyStarGiftError> {
            return _internal_buyStarGift(account: self.account, slug: slug, peerId: peerId, price: price)
        }
        
        public func upgradeStarGift(formId: Int64?, reference: StarGiftReference, keepOriginalInfo: Bool) -> Signal<ProfileGiftsContext.State.StarGift, UpgradeStarGiftError> {
            return _internal_upgradeStarGift(account: self.account, formId: formId, reference: reference, keepOriginalInfo: keepOriginalInfo)
        }
        
        public func starGiftUpgradePreview(giftId: Int64) -> Signal<[StarGift.UniqueGift.Attribute], NoError> {
            return _internal_starGiftUpgradePreview(account: self.account, giftId: giftId)
        }
        
        public func getUniqueStarGift(slug: String) -> Signal<StarGift.UniqueGift?, NoError> {
            return _internal_getUniqueStarGift(account: self.account, slug: slug)
        }
        
        public func checkStarGiftWithdrawalAvailability(reference: StarGiftReference) -> Signal<Never, RequestStarGiftWithdrawalError> {
            return _internal_checkStarGiftWithdrawalAvailability(account: self.account, reference: reference)
        }
        
        public func requestStarGiftWithdrawalUrl(reference: StarGiftReference, password: String) -> Signal<String, RequestStarGiftWithdrawalError> {
            return _internal_requestStarGiftWithdrawalUrl(account: account, reference: reference, password: password)
        }
        
        public func toggleStarGiftsNotifications(peerId: EnginePeer.Id, enabled: Bool) -> Signal<Never, NoError> {
            return _internal_toggleStarGiftsNotifications(account: self.account, peerId: peerId, enabled: enabled)
        }
        
        public func updateStarGiftResalePrice(reference: StarGiftReference, price: Int64?) -> Signal<Never, UpdateStarGiftPriceError> {
            return _internal_updateStarGiftResalePrice(account: self.account, reference: reference, price: price)
        }
        
        public func getStarsTransaction(reference: StarsTransactionReference) -> Signal<StarsContext.State.Transaction?, NoError> {
            return _internal_getStarsTransaction(accountPeerId: self.account.peerId, postbox: self.account.postbox, network: self.account.network, transactionReference: reference)
        }
    }
}

public extension TelegramEngineUnauthorized {
    final class Payments {
        private let account: UnauthorizedAccount

        init(account: UnauthorizedAccount) {
            self.account = account
        }

        public func canPurchasePremium(purpose: AppStoreTransactionPurpose) -> Signal<Bool, NoError> {
            return _internal_canPurchasePremium(postbox: self.account.postbox, network: self.account.network, purpose: purpose)
        }
        
        public func sendAppStoreReceipt(receipt: Data, purpose: AppStoreTransactionPurpose) -> Signal<Never, AssignAppStoreTransactionError> {
            return _internal_sendAppStoreReceipt(postbox: self.account.postbox, network: self.account.network, stateManager: self.account.stateManager, receipt: receipt, purpose: purpose)
        }
    }
}
