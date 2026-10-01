import Foundation
import SwiftSignalKit

public extension SupportAccount {
    /// Whether an account record is marked as a support account.
    static func isSupportUser(attributes: [TelegramAccountRecordAttribute]) -> Bool {
        return attributes.contains { attribute in
            if case .supportUserInfo = attribute {
                return true
            }
            return false
        }
    }

    /// Reconciles the persisted `.supportUserInfo` attribute with `isSupportUser`.
    ///
    /// The attribute is what makes support status readable *synchronously* at launch, before
    /// the `Account` object exists. Detection at authorisation is the primary writer; this is
    /// the safety net for accounts that authorised before support detection existed, or by a
    /// route that could not see a phone number.
    ///
    /// A no-op when the record already agrees, so it is safe to call on every resolution.
    static func updateAttribute(
        accountManager: AccountManager<TelegramAccountManagerTypes>,
        id: AccountRecordId,
        isSupportUser: Bool
    ) -> Signal<Never, NoError> {
        return accountManager.transaction { transaction -> Void in
            transaction.updateRecord(id, { current in
                guard let current else {
                    return nil
                }
                if self.isSupportUser(attributes: current.attributes) == isSupportUser {
                    return current
                }
                var attributes = current.attributes.filter { attribute in
                    if case .supportUserInfo = attribute {
                        return false
                    }
                    return true
                }
                if isSupportUser {
                    attributes.append(.supportUserInfo(AccountSupportUserInfo()))
                }
                return AccountRecord(
                    id: current.id,
                    attributes: attributes,
                    temporarySessionId: current.temporarySessionId
                )
            })
        }
        |> ignoreValues
    }
}
