import Foundation

enum Namespaces {
    struct Peer {
        static let CloudUser: PeerId.Namespace = 0
        static let CloudGroup: PeerId.Namespace = 1
        static let CloudChannel: PeerId.Namespace = 2
    }
}

struct PeerId {
    typealias Namespace = Int32
    typealias Id = Int32
    
    public let namespace: Namespace
    public let id: Id
    
    public init(namespace: Namespace, id: Id) {
        self.namespace = namespace
        self.id = id
    }
    
    public init(_ n: Int64) {
        self.namespace = Int32((n >> 32) & 0x7fffffff)
        self.id = Int32(bitPattern: UInt32(n & 0xffffffff))
    }
    
    public func toInt64() -> Int64 {
        return (Int64(self.namespace) << 32) | Int64(bitPattern: UInt64(UInt32(bitPattern: self.id)))
    }
}
