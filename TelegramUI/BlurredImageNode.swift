import Foundation
import UIKit
import AsyncDisplayKit
import Accelerate

private class BlurLayer: CALayer {
    private static let blurRadiusKey = "blurRadius"
    private static let blurLayoutKey = "blurLayout"
    @NSManaged var blurRadius: CGFloat
    @NSManaged private var blurLayout: CGFloat
    
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
        if key == blurRadiusKey || key == blurLayoutKey {
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
        
        if event == BlurLayer.blurLayoutKey, let action = super.action(forKey: "opacity") as? CABasicAnimation {
            action.keyPath = event
            action.fromValue = 0
            action.toValue = 1
            return action
        }
        
        return super.action(forKey: event)
    }
    
    func draw(_ image: UIImage) {
        self.contents = image.cgImage
        self.contentsScale = image.scale
        self.contentsGravity = kCAGravityResizeAspectFill
    }
    
    func refresh() {
        self.fromBlurRadius = nil
    }
    
    func animate() {
        UIView.performWithoutAnimation {
            self.blurLayout = 0
        }
        self.blurLayout = 1
    }
    
    func render(in context: CGContext, for layer: CALayer) {
        layer.render(in: context)
    }
}

class BlurView: UIView {
    override class var layerClass : AnyClass {
        return BlurLayer.self
    }
    
    private var displayLink: CADisplayLink?
    private var blurLayer: BlurLayer {
        return self.layer as! BlurLayer
    }
    
    var image: UIImage?
    
    private let mainQueue = DispatchQueue.main
    private let globalQueue: DispatchQueue = {
        if #available (iOS 8.0, *) {
            return .global(qos: .userInteractive)
        } else {
            return .global(priority: .high)
        }
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
    
    open override func didMoveToSuperview() {
        super.didMoveToSuperview()
        
        if self.superview == nil {
            self.displayLink?.invalidate()
            self.displayLink = nil
        } else {
            self.linkForDisplay()
        }
    }
    
    private func async(on queue: DispatchQueue, actions: @escaping () -> Void) {
        queue.async(execute: actions)
    }
    
    private func sync(on queue: DispatchQueue, actions: () -> Void) {
        queue.sync(execute: actions)
    }
    
    private func draw(_ image: UIImage, blurRadius: CGFloat) {
        async(on: globalQueue) { [weak self] in
            if let strongSelf = self, let blurredImage = blurredImage(image, radius: blurRadius) {
                strongSelf.sync(on: strongSelf.mainQueue) {
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
    
    private func linkForDisplay() {
        self.displayLink?.invalidate()
        self.displayLink = UIScreen.main.displayLink(withTarget: self, selector: #selector(BlurView.displayDidRefresh(_:)))
        self.displayLink?.add(to: .main, forMode: RunLoop.Mode(rawValue: ""))
    }
    
    @objc private func displayDidRefresh(_ displayLink: CADisplayLink) {
        self.display(self.layer)
    }
}

final class BlurredImageNode: ASDisplayNode {
    var image: UIImage? {
        didSet {
            self.blurView.image = self.image
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
