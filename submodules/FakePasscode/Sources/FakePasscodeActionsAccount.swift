import Foundation
import UIKit
import Postbox
import TelegramCore
import AccountContext

public struct FakePasscodeActionsAccount: Equatable {
    public let peerId: PeerId
    public let recordId: AccountRecordId
    public let displayName: String
    public let avatar: UIImage?

    public init(peerId: PeerId, recordId: AccountRecordId, displayName: String, avatar: UIImage?) {
        self.peerId = peerId
        self.recordId = recordId
        self.displayName = displayName
        self.avatar = avatar
    }
}
