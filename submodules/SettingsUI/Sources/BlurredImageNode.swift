import Foundation
import UIKit
import SwiftSignalKit
import AsyncDisplayKit
import Accelerate
import ImageBlur

private class BlurLayer: CALayer {
    private static let blurRadiusKey = "blurRadius"
    @NSManaged var blurRadius: CGFloat
    
    private var fromBlurRadius: CGFloat?
    var presentationRadius: CGFloat {
        if let radius = self.fromBlurRadius {
            if let layer = presentation() {
                return layer.blurRadius
            } else {
                return radius
            }
        } else {
            return self.blurRadius
        }
    }
    
    override class func needsDisplay(forKey key: String) -> Bool {
        if key == blurRadiusKey {
            return true
        }
        return super.needsDisplay(forKey: key)
    }
    
    open override func action(forKey event: String) -> CAAction? {
        if event == BlurLayer.blurRadiusKey {
            self.fromBlurRadius = nil
            
            if let action = super.action(forKey: "opacity") as? CABasicAnimation {
                self.fromBlurRadius = (presentation() ?? self).blurRadius
                
                action.keyPath = event
                action.fromValue = self.fromBlurRadius
                return action
            }
        }
        
        return super.action(forKey: event)
    }
    
    func draw(_ image: UIImage) {
        self.contents = image.cgImage
        self.contentsScale = image.scale
        self.contentsGravity = .resizeAspectFill
    }
    
    func render(in context: CGContext, for layer: CALayer) {
        layer.render(in: context)
    }
}

class BlurView: UIView {
    override class var layerClass : AnyClass {
        return BlurLayer.self
    }
    
    private var blurLayer: BlurLayer {
        return self.layer as! BlurLayer
    }
    
    var image: UIImage?
    
    private let queue: Queue = {
        return Queue(name: nil, qos: .userInteractive)
    }()
    
    open var blurRadius: CGFloat {
        set { self.blurLayer.blurRadius = newValue }
        get { return self.blurLayer.blurRadius }
    }
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        self.isUserInteractionEnabled = false
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.isUserInteractionEnabled = false
    }
    
    private func async(on queue: DispatchQueue, actions: @escaping () -> Void) {
        queue.async(execute: actions)
    }
    
    private func sync(on queue: DispatchQueue, actions: () -> Void) {
        queue.sync(execute: actions)
    }
    
    private func draw(_ image: UIImage, blurRadius: CGFloat) {
        self.queue.async { [weak self] in
            if let strongSelf = self, let blurredImage = blurredImage(image, radius: blurRadius) {
                Queue.mainQueue().sync {
                    strongSelf.blurLayer.draw(blurredImage)
                }
            }
        }
    }
    
    override func display(_ layer: CALayer) {
        let blurRadius = self.blurLayer.presentationRadius
        if let image = self.image {
            self.draw(image, blurRadius: blurRadius)
        }
    }
}

final class BlurredImageNode: ASDisplayNode {
    var image: UIImage? {
        didSet {
            self.blurView.image = self.image
            self.blurView.layer.setNeedsDisplay()
        }
    }
    
    var blurView: BlurView {
        return (self.view as? BlurView)!
    }
    
    override init() {
        super.init()
        
        self.setViewBlock({
            return BlurView()
        })
    }
}
