import Foundation
import SwiftSignalKit
import Postbox

public extension TelegramEngine {
    final class Notices {
        private let account: Account

        init(account: Account) {
            self.account = account
        }

        public func set<T: Codable>(id: NoticeEntryKey, item: T?) -> Signal<Never, NoError> {
            return self.account.postbox.transaction { transaction -> Void in
                if let item = item, let entry = CodableEntry(item) {
                    transaction.setNoticeEntry(key: id, value: entry)
                } else {
                    transaction.setNoticeEntry(key: id, value: nil)
                }
            }
            |> ignoreValues
        }
    }
}
