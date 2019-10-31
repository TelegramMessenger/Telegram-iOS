import Foundation
import Buffers
import PostboxCoding

public protocol Peer: class, PostboxCoding {
    var id: PeerId { get }
    var associatedPeerId: PeerId? { get }
    var notificationSettingsPeerId: PeerId? { get }
    
    func isEqual(_ other: Peer) -> Bool
}
