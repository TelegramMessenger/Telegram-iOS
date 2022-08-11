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
            return _internal_fetchBotPaymentForm(postbox: self.account.postbox, network: self.account.network, source: source, themeParams: themeParams)
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
        
        public func sendAppStoreReceipt(receipt: Data, restore: Bool) -> Signal<Never, AssignAppStoreTransactionError> {
            return _internal_sendAppStoreReceipt(account: self.account, receipt: receipt, restore: restore)
        }
        
        public func canPurchasePremium() -> Signal<Bool, NoError> {
            return _internal_canPurchasePremium(account: self.account)
        }
    }
}
