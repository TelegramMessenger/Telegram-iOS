import Foundation

public struct PeerGroupId: Hashable, Equatable, RawRepresentable {
    public var rawValue: Int32
    
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
}

struct WrappedPeerGroupId: Hashable, Equatable {
    let groupId: PeerGroupId?
    
    init(groupId: PeerGroupId?) {
        self.groupId = groupId
    }
}
