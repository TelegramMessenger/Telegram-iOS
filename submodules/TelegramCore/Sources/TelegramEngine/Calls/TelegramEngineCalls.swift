import SwiftSignalKit

public extension TelegramEngine {
    final class Calls {
        private let account: Account

        init(account: Account) {
            self.account = account
        }

        public func rateCall(callId: CallId, starsCount: Int32, comment: String = "", userInitiated: Bool) -> Signal<Void, NoError> {
            return _internal_rateCall(account: self.account, callId: callId, starsCount: starsCount, comment: comment, userInitiated: userInitiated)
        }

        public func saveCallDebugLog(callId: CallId, log: String) -> Signal<Void, NoError> {
            return _internal_saveCallDebugLog(network: self.account.network, callId: callId, log: log)
        }
    }
}
