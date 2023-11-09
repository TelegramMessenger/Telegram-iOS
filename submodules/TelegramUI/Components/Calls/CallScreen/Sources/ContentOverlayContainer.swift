import Foundation
import UIKit

protocol ContentOverlayView: UIView {
    var overlayMaskLayer: CALayer { get }
}

final class ContentOverlayContainer: UIView {
    private let overlayLayer: ContentOverlayLayer
    
    init(overlayLayer: ContentOverlayLayer) {
        self.overlayLayer = overlayLayer
        
        super.init(frame: CGRect())
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func addSubview(_ view: UIView) {
        super.addSubview(view)
        
        if let view = view as? ContentOverlayView {
            self.overlayLayer.maskContentLayer.addSublayer(view.overlayMaskLayer)
        }
    }
    
    override func insertSubview(_ view: UIView, at index: Int) {
        super.insertSubview(view, at: index)
        
        if let view = view as? ContentOverlayView {
            self.overlayLayer.maskContentLayer.addSublayer(view.overlayMaskLayer)
        }
    }
    
    override func insertSubview(_ view: UIView, aboveSubview siblingSubview: UIView) {
        super.insertSubview(view, aboveSubview: siblingSubview)
        
        if let view = view as? ContentOverlayView {
            self.overlayLayer.maskContentLayer.addSublayer(view.overlayMaskLayer)
        }
    }
    
    override func insertSubview(_ view: UIView, belowSubview siblingSubview: UIView) {
        super.insertSubview(view, belowSubview: siblingSubview)
        
        if let view = view as? ContentOverlayView {
            self.overlayLayer.maskContentLayer.addSublayer(view.overlayMaskLayer)
        }
    }
    
    override func willRemoveSubview(_ subview: UIView) {
        super.willRemoveSubview(subview)
        
        if let view = subview as? ContentOverlayView {
            view.overlayMaskLayer.removeFromSuperlayer()
        }
    }
}
