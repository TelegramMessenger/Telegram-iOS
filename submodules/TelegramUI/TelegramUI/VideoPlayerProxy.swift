import Foundation
import SwiftSignalKit
import AVFoundation

private final class VideoPlayerProxyContext {
    private let queue: Queue
    
    var updateVideoInHierarchy: ((Bool) -> Void)?
    
    var node: MediaPlayerNode? {
        didSet {
            self.node?.takeFrameAndQueue = self.takeFrameAndQueue
            self.node?.state = state
            self.updateVideoInHierarchy?(node?.videoInHierarchy ?? false)
            self.node?.updateVideoInHierarchy = { [weak self] value in
                self?.updateVideoInHierarchy?(value)
            }
        }
    }
    
    var takeFrameAndQueue: (Queue, () -> MediaTrackFrameResult)? {
        didSet {
            self.node?.takeFrameAndQueue = self.takeFrameAndQueue
        }
    }
    
    var state: (timebase: CMTimebase, requestFrames: Bool, rotationAngle: Double, aspect: Double)? {
        didSet {
            self.node?.state = self.state
        }
    }
    
    init(queue: Queue) {
        self.queue = queue
    }
    
    deinit {
        assert(self.queue.isCurrent())
    }
}

final class VideoPlayerProxy {
    var takeFrameAndQueue: (Queue, () -> MediaTrackFrameResult)? {
        didSet {
            let updatedTakeFrameAndQueue = self.takeFrameAndQueue
            self.withContext { context in
                context?.takeFrameAndQueue = updatedTakeFrameAndQueue
            }
        }
    }
    
    var state: (timebase: CMTimebase, requestFrames: Bool, rotationAngle: Double, aspect: Double)? {
        didSet {
            let updatedState = self.state
            self.withContext { context in
                context?.state = updatedState
            }
        }
    }
    
    private let queue: Queue
    private let contextQueue = Queue.mainQueue()
    private var contextRef: Unmanaged<VideoPlayerProxyContext>?
    
    var visibility: Bool = false
    var visibilityUpdated: ((Bool) -> Void)?
    
    init(queue: Queue) {
        self.queue = queue
        
        self.contextQueue.async {
            let context = VideoPlayerProxyContext(queue: self.contextQueue)
            context.updateVideoInHierarchy = { [weak self] value in
                queue.async {
                    if let strongSelf = self {
                        if strongSelf.visibility != value {
                            strongSelf.visibility = value
                            strongSelf.visibilityUpdated?(value)
                        }
                    }
                }
            }
            self.contextRef = Unmanaged.passRetained(context)
        }
    }
    
    deinit {
        let contextRef = self.contextRef
        self.contextQueue.async {
            if let contextRef = contextRef {
                let context = contextRef.takeUnretainedValue()
                context.state = nil
                contextRef.release()
            }
        }
    }
    
    private func withContext(_ f: @escaping (VideoPlayerProxyContext?) -> Void) {
        self.contextQueue.async {
            if let contextRef = self.contextRef {
                let context = contextRef.takeUnretainedValue()
                f(context)
            } else {
                f(nil)
            }
        }
    }
    
    func attachNodeAndRelease(_ nodeRef: Unmanaged<MediaPlayerNode>) {
        self.withContext { context in
            if let context = context {
                context.node = nodeRef.takeUnretainedValue()
            }
            nodeRef.release()
        }
    }
}
