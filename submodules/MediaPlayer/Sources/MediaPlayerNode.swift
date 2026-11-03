import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import AVFoundation

private final class MediaPlayerNodeLayerNullAction: NSObject, CAAction {
    @objc func run(forKey event: String, object anObject: Any, arguments dict: [AnyHashable : Any]?) {
    }
}

private final class MediaPlayerNodeLayer: AVSampleBufferDisplayLayer {
    override init() {
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        assert(Queue.mainQueue().isCurrent())
    }
    
    override func action(forKey event: String) -> CAAction? {
        return MediaPlayerNodeLayerNullAction()
    }
}

private final class MediaPlayerNodeDisplayNode: ASDisplayNode {
    var updateInHierarchy: ((Bool) -> Void)?
    
    override init() {
        super.init()
        self.isLayerBacked = true
    }
    
    override func willEnterHierarchy() {
        super.willEnterHierarchy()
        
        self.updateInHierarchy?(true)
    }
    
    override func didExitHierarchy() {
        super.didExitHierarchy()
        
        self.updateInHierarchy?(false)
    }
}

private enum PollStatus: CustomStringConvertible {
    case delay(Double)
    case finished
    
    var description: String {
        switch self {
            case let .delay(value):
                return "delay(\(value))"
            case .finished:
                return "finished"
        }
    }
}

public final class MediaPlayerNode: ASDisplayNode {
    public var videoInHierarchy: Bool = false
    var canPlaybackWithoutHierarchy: Bool = false
    public var updateVideoInHierarchy: ((Bool) -> Void)?
    
    private var videoNode: MediaPlayerNodeDisplayNode
    
    public private(set) var videoLayer: AVSampleBufferDisplayLayer?
    private var videoLayerReadyForDisplayObserver: NSObjectProtocol?
    private var didNotifyVideoLayerReadyForDisplay: Bool = false
    
    private let videoQueue: Queue
    
    public var snapshotNode: ASDisplayNode? {
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
    
    public var hasSentFramesToDisplay: (() -> Void)?
    
    var takeFrameAndQueue: (Queue, () -> MediaTrackFrameResult)?
    var timer: SwiftSignalKit.Timer?
    var polling = false
    
    var currentRotationAngle = 0.0
    var currentAspect = 1.0
    
    public var state: (timebase: CMTimebase, requestFrames: Bool, rotationAngle: Double, aspect: Double)? {
        didSet {
            self.updateState()
        }
    }
    
    private func updateState() {
        if let (timebase, requestFrames, rotationAngle, aspect) = self.state {
            if let videoLayer = self.videoLayer {
                videoQueue.async {
                    if videoLayer.controlTimebase !== timebase || videoLayer.status == .failed {
                        videoLayer.flush()
                        videoLayer.controlTimebase = timebase
                    }
                }
                
                if !self.currentRotationAngle.isEqual(to: rotationAngle) || !self.currentAspect.isEqual(to: aspect) {
                    self.currentRotationAngle = rotationAngle
                    self.currentAspect = aspect
                    var transform = CGAffineTransform(rotationAngle: CGFloat(rotationAngle))
                    if abs(rotationAngle).remainder(dividingBy: Double.pi) > 0.1 {
                        transform = transform.scaledBy(x: CGFloat(aspect), y: CGFloat(1.0 / aspect))
                    }
                    if videoLayer.affineTransform() != transform {
                        videoLayer.setAffineTransform(transform)
                    }
                }
                
                if self.videoInHierarchy || self.canPlaybackWithoutHierarchy {
                    if requestFrames {
                        self.startPolling()
                    }
                }
            }
        }
    }
    
    private func startPolling() {
        if !self.polling {
            self.polling = true
            MediaPlayerNode.poll(node: self, completion: { [weak self] status in
                self?.polling = false
                
                if let strongSelf = self, let (_, requestFrames, _, _) = strongSelf.state, requestFrames {
                    strongSelf.timer?.invalidate()
                    switch status {
                        case let .delay(delay):
                            strongSelf.timer = SwiftSignalKit.Timer( timeout: delay, repeat: true, completion: {
                                if let strongSelf = self, let videoLayer = strongSelf.videoLayer, let (_, requestFrames, _, _) = strongSelf.state, requestFrames, (strongSelf.videoInHierarchy || strongSelf.canPlaybackWithoutHierarchy) {
                                    if videoLayer.isReadyForMoreMediaData {
                                        strongSelf.timer?.invalidate()
                                        strongSelf.timer = nil
                                        strongSelf.startPolling()
                                    }
                                }
                            }, queue: Queue.mainQueue())
                            strongSelf.timer?.start()
                        case .finished:
                            break
                    }
                }
            })
        }
    }
    
    private struct PollState {
        var numFrames: Int
        var maxTakenTime: Double
    }
    
    private static func pollInner(node: MediaPlayerNode, layerTime: Double, state: PollState, completion: @escaping (PollStatus) -> Void) {
        assert(Queue.mainQueue().isCurrent())
        
        guard let (takeFrameQueue, takeFrame) = node.takeFrameAndQueue else {
            return
        }
        guard let videoLayer = node.videoLayer else {
            return
        }
        if !videoLayer.isReadyForMoreMediaData {
            completion(.delay(max(1.0 / 30.0, state.maxTakenTime - layerTime)))
            return
        }
        
        var state = state
        
        takeFrameQueue.async { [weak node] in
            let takeFrameResult = takeFrame()
            switch takeFrameResult {
            case let .restoreState(frames, atTime, soft):
                if !soft {
                    Queue.mainQueue().async {
                        guard let strongSelf = node, let videoLayer = strongSelf.videoLayer else {
                            return
                        }
                        videoLayer.flush()
                    }
                }
                for i in 0 ..< frames.count {
                    let frame = frames[i]
                    let frameTime = CMTimeGetSeconds(frame.position)
                    state.maxTakenTime = frameTime
                    let attachments = CMSampleBufferGetSampleAttachmentsArray(frame.sampleBuffer, createIfNecessary: true)! as NSArray
                    let dict = attachments[0] as! NSMutableDictionary
                    if i == 0 && !soft {
                        CMSetAttachment(frame.sampleBuffer, key: kCMSampleBufferAttachmentKey_ResetDecoderBeforeDecoding as NSString, value: kCFBooleanTrue as AnyObject, attachmentMode: kCMAttachmentMode_ShouldPropagate)
                        CMSetAttachment(frame.sampleBuffer, key: kCMSampleBufferAttachmentKey_EndsPreviousSampleDuration as NSString, value: kCFBooleanTrue as AnyObject, attachmentMode: kCMAttachmentMode_ShouldPropagate)
                    }
                    if !soft {
                        if CMTimeCompare(frame.position, atTime) < 0 {
                            dict.setValue(kCFBooleanTrue as AnyObject, forKey: kCMSampleAttachmentKey_DoNotDisplay as NSString as String)
                        } else if CMTimeCompare(frame.position, atTime) == 0 {
                            dict.setValue(kCFBooleanTrue as AnyObject, forKey: kCMSampleAttachmentKey_DisplayImmediately as NSString as String)
                            dict.setValue(kCFBooleanTrue as AnyObject, forKey: kCMSampleBufferAttachmentKey_EndsPreviousSampleDuration as NSString as String)
                        }
                    }
                    Queue.mainQueue().async {
                        guard let strongSelf = node, let videoLayer = strongSelf.videoLayer else {
                            return
                        }
                        videoLayer.enqueue(frame.sampleBuffer)
                        if #available(iOS 17.4, *) {
                        } else {
                            if !strongSelf.didNotifyVideoLayerReadyForDisplay {
                                strongSelf.didNotifyVideoLayerReadyForDisplay = true
                                strongSelf.hasSentFramesToDisplay?()
                            }
                        }
                    }
                }
                Queue.mainQueue().async {
                    guard let node else {
                        return
                    }
                    MediaPlayerNode.pollInner(node: node, layerTime: layerTime, state: state, completion: completion)
                }
            case let .frame(frame):
                state.numFrames += 1
                let frameTime = CMTimeGetSeconds(frame.position)
                if frame.resetDecoder {
                    Queue.mainQueue().async {
                        guard let strongSelf = node, let videoLayer = strongSelf.videoLayer else {
                            return
                        }
                        videoLayer.flush()
                    }
                }
                
                if frame.decoded && frameTime < layerTime {
                    Queue.mainQueue().async {
                        guard let node else {
                            return
                        }
                        MediaPlayerNode.pollInner(node: node, layerTime: layerTime, state: state, completion: completion)
                    }
                } else {
                    state.maxTakenTime = frameTime
                    Queue.mainQueue().async {
                        guard let strongSelf = node, let videoLayer = strongSelf.videoLayer else {
                            return
                        }
                        videoLayer.enqueue(frame.sampleBuffer)
                        if !strongSelf.didNotifyVideoLayerReadyForDisplay {
                            strongSelf.didNotifyVideoLayerReadyForDisplay = true
                            strongSelf.hasSentFramesToDisplay?()
                        }
                    }
                    
                    Queue.mainQueue().async {
                        guard let node else {
                            return
                        }
                        MediaPlayerNode.pollInner(node: node, layerTime: layerTime, state: state, completion: completion)
                    }
                }
            case .skipFrame:
                Queue.mainQueue().async {
                    guard let node else {
                        return
                    }
                    MediaPlayerNode.pollInner(node: node, layerTime: layerTime, state: state, completion: completion)
                }
            case .noFrames:
                DispatchQueue.main.async {
                    completion(.finished)
                }
            case .finished:
                DispatchQueue.main.async {
                    completion(.finished)
                }
            }
        }
    }
    
    private static func poll(node: MediaPlayerNode, completion: @escaping (PollStatus) -> Void) {
        if let _ = node.videoLayer, let (timebase, _, _, _) = node.state {
            let layerTime = CMTimeGetSeconds(CMTimebaseGetTime(timebase))
            
            let loopImpl: (PollState) -> Void = { [weak node] state in
                guard let node else {
                    return
                }
                MediaPlayerNode.pollInner(node: node, layerTime: layerTime, state: state, completion: completion)
            }
            loopImpl(PollState(numFrames: 0, maxTakenTime: layerTime + 0.1))
        }
    }
    
    public var transformArguments: TransformImageArguments? {
        didSet {
            var cornerRadius: CGFloat = 0.0
            if let transformArguments = self.transformArguments {
                cornerRadius = transformArguments.corners.bottomLeft.radius
            }
            if !self.cornerRadius.isEqual(to: cornerRadius) {
                self.cornerRadius = cornerRadius
                self.clipsToBounds = !cornerRadius.isZero
            } else {
                if let transformArguments = self.transformArguments {
                    self.clipsToBounds = !cornerRadius.isZero || (transformArguments.imageSize.width > transformArguments.boundingSize.width || transformArguments.imageSize.height > transformArguments.boundingSize.height)
                }
            }
            self.updateLayout()
        }
    }
    
    public init(backgroundThread: Bool = false, captureProtected: Bool = false) {
        self.videoNode = MediaPlayerNodeDisplayNode()
        
        if false && backgroundThread {
            self.videoQueue = Queue()
        } else {
            self.videoQueue = Queue.mainQueue()
        }
        
        super.init()
        
        self.videoNode.updateInHierarchy = { [weak self] value in
            if let strongSelf = self {
                if strongSelf.videoInHierarchy != value {
                    strongSelf.videoInHierarchy = value
                    if value {
                        strongSelf.updateState()
                    }
                }
                strongSelf.updateVideoInHierarchy?(strongSelf.videoInHierarchy || strongSelf.canPlaybackWithoutHierarchy)
            }
        }
        self.addSubnode(self.videoNode)
        
        self.videoQueue.async { [weak self] in
            let videoLayer = MediaPlayerNodeLayer()
            videoLayer.videoGravity = .resize
            Queue.mainQueue().async {
                if let strongSelf = self {
                    strongSelf.videoLayer = videoLayer
                    if #available(iOS 13.0, *) {
                        videoLayer.preventsCapture = captureProtected
                    }
                    strongSelf.updateLayout()
                    
                    strongSelf.layer.addSublayer(videoLayer)
                    
                    if #available(iOS 17.4, *) {
                        strongSelf.videoLayerReadyForDisplayObserver = NotificationCenter.default.addObserver(forName: NSNotification.Name.AVSampleBufferDisplayLayerReadyForDisplayDidChange, object: videoLayer, queue: .main, using: { [weak strongSelf] _ in
                            guard let strongSelf else {
                                return
                            }
                            if !strongSelf.didNotifyVideoLayerReadyForDisplay {
                                strongSelf.didNotifyVideoLayerReadyForDisplay = true
                                strongSelf.hasSentFramesToDisplay?()
                            }
                        })
                    }
                    
                    strongSelf.updateState()
                }
            }
        }
    }
    
    deinit {
        assert(Queue.mainQueue().isCurrent())
        self.videoLayer?.removeFromSuperlayer()
        
        if let _ = self.takeFrameAndQueue {
            if let videoLayer = self.videoLayer {
                videoLayer.flushAndRemoveImage()
                
                Queue.mainQueue().after(1.0, {
                    videoLayer.flushAndRemoveImage()
                })
            }
        }
    }
    
    override public var frame: CGRect {
        didSet {
            if !oldValue.size.equalTo(self.frame.size) {
                self.updateLayout()
            }
        }
    }
    
    public func updateLayout() {
        let bounds = self.bounds
        if bounds.isEmpty {
            return
        }
        
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
        
        if let videoLayer = self.videoLayer {
            videoLayer.position = CGPoint(x: fittedRect.midX, y: fittedRect.midY)
            videoLayer.bounds = CGRect(origin: CGPoint(), size: fittedRect.size)
        }
        self.snapshotNode?.frame = fittedRect
    }
    
    public func reset() {
        self.videoLayer?.flush()
    }

    public func setCanPlaybackWithoutHierarchy(_ canPlaybackWithoutHierarchy: Bool) {
        if self.canPlaybackWithoutHierarchy != canPlaybackWithoutHierarchy {
            self.canPlaybackWithoutHierarchy = canPlaybackWithoutHierarchy
            if canPlaybackWithoutHierarchy {
                self.updateState()
            }
        }
        self.updateVideoInHierarchy?(self.videoInHierarchy || self.canPlaybackWithoutHierarchy)
    }
}
