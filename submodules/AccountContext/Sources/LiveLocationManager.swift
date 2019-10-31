import Foundation
import TelegramCore
import SyncCore
import Postbox
import SwiftSignalKit

public protocol LiveLocationSummaryManager {
    func broadcastingToMessages() -> Signal<[MessageId: Message], NoError>
    func peersBroadcastingTo(peerId: PeerId) -> Signal<[(Peer, Message)]?, NoError>
}

public protocol LiveLocationManager {
    var summaryManager: LiveLocationSummaryManager { get }
    var isPolling: Signal<Bool, NoError> { get }
    
    func cancelLiveLocation(peerId: PeerId)
    func pollOnce()
    func internalMessageForPeerId(_ peerId: PeerId) -> MessageId?
}
