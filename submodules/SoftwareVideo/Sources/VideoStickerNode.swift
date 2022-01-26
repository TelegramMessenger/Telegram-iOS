import Foundation
import AVFoundation
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramCore

private class VideoStickerNodeDisplayEvents: ASDisplayNode {
    private var value: Bool = false
    var updated: ((Bool) -> Void)?
    
    override init() {
        super.init()
        
        self.isLayerBacked = true
    }
    
    override func didEnterHierarchy() {
        super.didEnterHierarchy()
        
        if !self.value {
            self.value = true
            self.updated?(true)
        }
    }
    
    override func didExitHierarchy() {
        super.didExitHierarchy()
        
        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self else {
                return
            }
            if !strongSelf.isInHierarchy {
                if strongSelf.value {
                    strongSelf.value = false
                    strongSelf.updated?(false)
                }
            }
        }
    }
}

public class VideoStickerNode: ASDisplayNode {
    private let eventsNode: VideoStickerNodeDisplayEvents
    
    private var layerHolder: SampleBufferLayer?
    private var manager: SoftwareVideoLayerFrameManager?
    
    private var displayLink: ConstantDisplayLinkAnimator?
    private var displayLinkTimestamp: Double = 0.0
    
    public var started: () -> Void = {}
    
    private var validLayout: CGSize?
    
    private var isDisplaying: Bool = false {
        didSet {
            self.updateIsPlaying()
        }
    }
    private var isPlaying: Bool = false
    
    public override init() {
        self.eventsNode = VideoStickerNodeDisplayEvents()
        
        super.init()
        
        self.eventsNode.updated = { [weak self] value in
            guard let strongSelf = self else {
                return
            }
            strongSelf.isDisplaying = value
        }
        self.addSubnode(self.eventsNode)
    }
    
    private func updateIsPlaying() {
        let isPlaying = self.isPlaying && self.isDisplaying
        if isPlaying {
            let displayLink: ConstantDisplayLinkAnimator
            if let current = self.displayLink {
                displayLink = current
            } else {
                displayLink = ConstantDisplayLinkAnimator { [weak self] in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.manager?.tick(timestamp: strongSelf.displayLinkTimestamp)
                    strongSelf.displayLinkTimestamp += 1.0 / 30.0
                }
                displayLink.frameInterval = 2
                self.displayLink = displayLink
            }
            displayLink.isPaused = !isPlaying
        } else {
            self.displayLink?.isPaused = true
        }
    }
    
    public func update(isPlaying: Bool) {
        self.isPlaying = isPlaying
        self.updateIsPlaying()
    }
    
    public func update(account: Account, fileReference: FileMediaReference) {
        let layerHolder = takeSampleBufferLayer()
        layerHolder.layer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        if let size = self.validLayout {
            layerHolder.layer.frame = CGRect(origin: CGPoint(), size: size)
        }
        self.layer.addSublayer(layerHolder.layer)
        self.layerHolder = layerHolder
        
        let manager = SoftwareVideoLayerFrameManager(account: account, fileReference: fileReference, layerHolder: layerHolder, hintVP9: true)
        manager.started = self.started
        self.manager = manager
        manager.start()
    }
    
    public func updateLayout(size: CGSize) {
        self.validLayout = size
        
        self.layerHolder?.layer.frame = CGRect(origin: CGPoint(), size: size)
    }
}
