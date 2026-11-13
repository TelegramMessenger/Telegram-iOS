import Foundation
import Postbox
import SwiftSignalKit

func isSupportAccount(transaction: Transaction, accountPeerId: PeerId) -> Bool {
    guard let user = transaction.getPeer(accountPeerId) as? TelegramUser else {
        return false
    }
    return isSupportAccountPhone(user.phone)
}

