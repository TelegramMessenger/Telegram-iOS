import SwiftSignalKit

public extension TelegramEngine {
    final class SecureId {
        private let account: Account

        init(account: Account) {
            self.account = account
        }

        public func accessSecureId(password: String) -> Signal<(context: SecureIdAccessContext, settings: TwoStepVerificationSettings), SecureIdAccessError> {
            return _internal_accessSecureId(network: self.account.network, password: password)
        }
    }
}
