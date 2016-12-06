import Foundation
import UIKit
import AsyncDisplayKit
import SwiftSignalKit

private final class MediaPlayerNodeDisplayView: UIView {
    override class var layerClass: AnyClass {
        return AVSampleBufferDisplayLayer.self
    }
}

final class MediaPlayerNode: ASDisplayNode {
    private var displayView: MediaPlayerNodeDisplayView?
    var snapshotNode: ASDisplayNode? {
        didSet {
            if let snapshotNode = oldValue {
                snapshotNode.removeFromSupernode()
            }
            
            if let snapshotNode = self.snapshotNode {
                snapshotNode.frame = self.bounds
                self.insertSubnode(snapshotNode, at: 0)
            }
        }
    }
    
    var controlTimebase: CMTimebase? {
        get {
            return (self.displayView?.layer as? AVSampleBufferDisplayLayer)?.controlTimebase
        } set(value) {
            (self.displayView?.layer as? AVSampleBufferDisplayLayer)?.controlTimebase = value
        }
    }
    var queue: Queue?
    private var isRequestingFrames = false
    
    var transformArguments: TransformImageArguments? {
        didSet {
            self.updateLayout()
        }
    }
    
    override init() {
        super.init()
        
        self.displayView = MediaPlayerNodeDisplayView()
        self.view.addSubview(self.displayView!)
    }
    
    deinit {
        //assert(Queue.mainQueue().isCurrent())
    }
    
    override var frame: CGRect {
        didSet {
            if !oldValue.size.equalTo(self.frame.size) {
                self.updateLayout()
            }
        }
    }
    
    private func updateLayout() {
        let bounds = self.bounds
        
        let fittedRect: CGRect
        if let arguments = self.transformArguments {
            let drawingRect = bounds
            var fittedSize = arguments.imageSize
            if abs(fittedSize.width - bounds.size.width).isLessThanOrEqualTo(CGFloat(1.0)) {
                fittedSize.width = bounds.size.width
            }
            if abs(fittedSize.height - bounds.size.height).isLessThanOrEqualTo(CGFloat(1.0)) {
                fittedSize.height = bounds.size.height
            }
            
            fittedRect = CGRect(origin: CGPoint(x: drawingRect.origin.x + (drawingRect.size.width - fittedSize.width) / 2.0, y: drawingRect.origin.y + (drawingRect.size.height - fittedSize.height) / 2.0), size: fittedSize)
        } else {
            fittedRect = bounds
        }
        
        self.displayView?.frame = fittedRect
        self.snapshotNode?.frame = fittedRect
    }
    
    func reset() {
        (self.displayView?.layer as? AVSampleBufferDisplayLayer)?.flush()
    }
    
    func beginRequestingFrames(queue: DispatchQueue, takeFrame: @escaping () -> MediaTrackFrameResult) {
        assert(self.queue != nil && self.queue!.isCurrent())
        
        if isRequestingFrames {
            return
        }
        isRequestingFrames = true
        //print("begin requesting")
        
        (self.displayView?.layer as? AVSampleBufferDisplayLayer)?.requestMediaDataWhenReady(on: queue, using: { [weak self] in
            if let strongSelf = self, let layer = strongSelf.displayView?.layer as? AVSampleBufferDisplayLayer {
                loop: while layer.isReadyForMoreMediaData {
                    switch takeFrame() {
                        case let .frame(frame):
                            if frame.resetDecoder {
                                layer.flush()
                            }
                            layer.enqueue(frame.sampleBuffer)
                        case .skipFrame:
                            break
                        case .noFrames:
                            if let strongSelf = self, strongSelf.isRequestingFrames {
                                strongSelf.isRequestingFrames = false
                                if let layer = (strongSelf.displayView?.layer as? AVSampleBufferDisplayLayer) {
                                    layer.stopRequestingMediaData()
                                }
                                //print("stop requesting")
                            }
                            break loop
                    }
                }
            }
        })
    }
}
