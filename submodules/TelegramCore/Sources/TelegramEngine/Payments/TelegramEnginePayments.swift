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

        public func fetchBotPaymentForm(messageId: MessageId, themeParams: [String: Any]?) -> Signal<BotPaymentForm, BotPaymentFormRequestError> {
            return _internal_fetchBotPaymentForm(postbox: self.account.postbox, network: self.account.network, messageId: messageId, themeParams: themeParams)
        }

        public func validateBotPaymentForm(saveInfo: Bool, messageId: MessageId, formInfo: BotPaymentRequestedInfo) -> Signal<BotPaymentValidatedFormInfo, ValidateBotPaymentFormError> {
            return _internal_validateBotPaymentForm(account: self.account, saveInfo: saveInfo, messageId: messageId, formInfo: formInfo)
        }

        public func sendBotPaymentForm(messageId: MessageId, formId: Int64, validatedInfoId: String?, shippingOptionId: String?, tipAmount: Int64?, credentials: BotPaymentCredentials) -> Signal<SendBotPaymentResult, SendBotPaymentFormError> {
            return _internal_sendBotPaymentForm(account: self.account, messageId: messageId, formId: formId, validatedInfoId: validatedInfoId, shippingOptionId: shippingOptionId, tipAmount: tipAmount, credentials: credentials)
        }

        public func requestBotPaymentReceipt(messageId: MessageId) -> Signal<BotPaymentReceipt, RequestBotPaymentReceiptError> {
            return _internal_requestBotPaymentReceipt(account: self.account, messageId: messageId)
        }

        public func clearBotPaymentInfo(info: BotPaymentInfo) -> Signal<Void, NoError> {
            return _internal_clearBotPaymentInfo(network: self.account.network, info: info)
        }
    }
}
