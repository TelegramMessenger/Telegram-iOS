import Foundation
import TelegramCore
import SwiftSignalKit

public protocol LiveLocationSummaryManager {
    func broadcastingToMessages() -> Signal<[EngineMessage.Id: EngineMessage], NoError>
    func peersBroadcastingTo(peerId: EnginePeer.Id) -> Signal<[(EnginePeer, EngineMessage)]?, NoError>
}

public protocol LiveLocationManager {
    var summaryManager: LiveLocationSummaryManager { get }
    var isPolling: Signal<Bool, NoError> { get }
    var hasBackgroundTasks: Signal<Bool, NoError> { get }
    
    func cancelLiveLocation(peerId: EnginePeer.Id)
    func pollOnce()
    func internalMessageForPeerId(_ peerId: EnginePeer.Id) -> EngineMessage.Id?
}
