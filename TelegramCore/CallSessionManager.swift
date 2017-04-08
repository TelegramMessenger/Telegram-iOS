import Foundation
#if os(macOS)
    import PostboxMac
    import MtProtoKitMac
    import SwiftSignalKitMac
#else
    import Postbox
    import MtProtoKitDynamic
    import SwiftSignalKit
#endif

private struct CallSessionId: Hashable {
    let id: Int64
    
    init(_ id: Int64) {
        self.id = id
    }
    
    var hashValue: Int {
        return self.id.hashValue
    }
    
    static func ==(lhs: CallSessionId, rhs: CallSessionId) -> Bool {
        return lhs.id == rhs.id
    }
}

private final class CallSessionContext {
    let peerId: PeerId
    var state: CallSessionState
    
    init(peerId: PeerId, state: CallSessionState) {
        self.peerId = peerId
        self.state = state
    }
}

private final class CallSessionManagerContext {
    private let queue: Queue
    
    private var contexts: [CallSessionId: CallSessionContext] = [:]
    
    init(queue: Queue) {
        self.queue = queue
    }
    
    deinit {
        assert(self.queue.isCurrent())
    }
    
    
}

final class CallSessionManager {
    private let queue = Queue()
    private var contextRef: Unmanaged<CallSessionManagerContext>?
    
    init() {
        self.queue.async {
            let context = CallSessionManagerContext(queue: self.queue)
            self.contextRef = Unmanaged.passRetained(context)
        }
    }
    
    deinit {
        let contextRef = self.contextRef
        self.queue.async {
            contextRef?.release()
        }
    }
    
    private func withContext(_ f: @escaping (CallSessionManagerContext) -> Void) {
        self.queue.async {
            if let contextRef = self.contextRef {
                let context = contextRef.takeUnretainedValue()
                f(context)
            }
        }
    }
}
