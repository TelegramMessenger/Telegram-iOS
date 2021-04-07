import SwiftSignalKit

public extension TelegramEngine {
    final class Payments {
        private let account: Account

        init(account: Account) {
            self.account = account
        }

        public func getBankCardInfo(cardNumber: String) -> Signal<BankCardInfo?, NoError> {
            return _internal_getBankCardInfo(account: self.account, cardNumber: cardNumber)
        }
    }
}
