import Foundation
import AVFoundation
import AsyncDisplayKit
import Display
import TelegramCore

public class VideoStickerNode: ASDisplayNode {
    private var layerHolder: SampleBufferLayer?
    private var manager: SoftwareVideoLayerFrameManager?
    
    private var displayLink: ConstantDisplayLinkAnimator?
    private var displayLinkTimestamp: Double = 0.0
    
    public var started: () -> Void = {}
    
    private var validLayout: CGSize?
    
    public func update(isPlaying: Bool) {
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
        self.displayLink?.isPaused = !isPlaying
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
