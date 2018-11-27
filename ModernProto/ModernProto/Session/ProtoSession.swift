import Foundation
import SwiftSignalKit

final class ProtoSessionState {
    let authData: [ProtoTarget: ProtoAuthData] = [:]
    let paths: [ProtoTarget: Set<ProtoPath>] = [:]
}

private final class ProtoSessionImpl {
    private let queue: Queue
    private let configuration: ProtoSessionConfiguration
    
    init(queue: Queue, configuration: ProtoSessionConfiguration) {
        self.queue = queue
        self.configuration = configuration
    }
    
    deinit {
        assert(self.queue.isCurrent())
    }
    
    
}

public struct ProtoSessionConfiguration {
    public let seedPaths: [ProtoTarget: ProtoPath]
    
    public init(seedPaths: [ProtoTarget: ProtoPath]) {
        self.seedPaths = seedPaths
    }
}

public final class ProtoSession {
    private let queue = Queue()
    private let impl: QueueLocalObject<ProtoSessionImpl>
    
    init(configuration: ProtoSessionConfiguration) {
        let queue = self.queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return ProtoSessionImpl(queue: queue, configuration: configuration)
        })
    }
    
    
}
