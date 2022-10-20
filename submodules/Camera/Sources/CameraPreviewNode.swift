import Foundation
import AsyncDisplayKit
import Display
import AVFoundation
import SwiftSignalKit

private final class CameraPreviewNodeLayerNullAction: NSObject, CAAction {
    @objc func run(forKey event: String, object anObject: Any, arguments dict: [AnyHashable : Any]?) {
    }
}

private final class CameraPreviewNodeLayer: AVSampleBufferDisplayLayer {
    override func action(forKey event: String) -> CAAction? {
        return CameraPreviewNodeLayerNullAction()
    }
}

public final class CameraPreviewNode: ASDisplayNode {
    private var displayLayer: AVSampleBufferDisplayLayer
    
    private let fadeNode: ASDisplayNode
    private var fadedIn = false

    public override init() {
        self.displayLayer = AVSampleBufferDisplayLayer()
        self.displayLayer.videoGravity = .resizeAspectFill
        
        self.fadeNode = ASDisplayNode()
        self.fadeNode.backgroundColor = .black
        self.fadeNode.isUserInteractionEnabled = false
        
        super.init()
        
        self.clipsToBounds = true
        
        self.layer.addSublayer(self.displayLayer)
        
        self.addSubnode(self.fadeNode)
    }
    
    func prepare() {
        DispatchQueue.main.async {
            self.displayLayer.flushAndRemoveImage()
        }
    }
    
    func enqueue(_ sampleBuffer: CMSampleBuffer) {
        self.displayLayer.enqueue(sampleBuffer)
        
        if !self.fadedIn {
            self.fadedIn = true
            Queue.mainQueue().after(0.2) {
                self.fadeNode.alpha = 0.0
                self.fadeNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3)
            }
        }
    }
    
    override public func layout() {
        super.layout()
        
        var transform = CGAffineTransform(rotationAngle: CGFloat.pi / 2.0)
        transform = transform.scaledBy(x: 1.0, y: 1.0)
        self.displayLayer.setAffineTransform(transform)
        
        self.displayLayer.frame = self.bounds
        self.fadeNode.frame = self.bounds
    }
}
