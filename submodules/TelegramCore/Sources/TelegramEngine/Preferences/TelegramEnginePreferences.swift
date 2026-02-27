import Foundation
import SwiftSignalKit
import Postbox

public extension TelegramEngine {
    final class Preferences {
        private let account: Account

        init(account: Account) {
            self.account = account
        }

        public func update(id: ValueBoxKey, _ f: @escaping (PreferencesEntry?) -> PreferencesEntry?) -> Signal<Never, NoError> {
            return self.account.postbox.transaction { transaction -> Void in
                transaction.updatePreferencesEntry(key: id, { entry in
                    return f(entry)
                })
            }
            |> ignoreValues
        }
    }
}
