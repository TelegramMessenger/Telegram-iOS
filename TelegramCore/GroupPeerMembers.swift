import Foundation
#if os(macOS)
import PostboxMac
import SwiftSignalKitMac
#else
import Postbox
import SwiftSignalKit
#endif

public final class GroupPeerMembersContext {
    private let postbox: Postbox
    private let network: Network
    private let peerId: PeerId
    
    public init(postbox: Postbox, network: Network, peerId: PeerId) {
        self.postbox = postbox
        self.network = network
        self.peerId = peerId
    }
}
