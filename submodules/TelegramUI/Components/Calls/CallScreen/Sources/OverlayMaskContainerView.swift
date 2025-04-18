import Foundation
import UIKit

public protocol OverlayMaskContainerViewProtocol: UIView {
    var maskContents: UIView { get }
}

public class OverlayMaskContainerView: UIView, OverlayMaskContainerViewProtocol {
    override public static var layerClass: AnyClass {
        return MirroringLayer.self
    }
    
    public let maskContents: UIView
    
    override init(frame: CGRect) {
        self.maskContents = UIView()
        
        super.init(frame: frame)
        
        (self.layer as? MirroringLayer)?.targetLayer = self.maskContents.layer
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func addSubview(_ view: UIView) {
        super.addSubview(view)
        
        if let view = view as? OverlayMaskContainerViewProtocol {
            self.maskContents.addSubview(view.maskContents)
        }
    }
    
    override public func insertSubview(_ view: UIView, at index: Int) {
        super.insertSubview(view, at: index)
        
        if let view = view as? OverlayMaskContainerViewProtocol {
            self.maskContents.addSubview(view.maskContents)
        }
    }
    
    override public func insertSubview(_ view: UIView, aboveSubview siblingSubview: UIView) {
        super.insertSubview(view, aboveSubview: siblingSubview)
        
        if let view = view as? OverlayMaskContainerViewProtocol {
            self.maskContents.addSubview(view.maskContents)
        }
    }
    
    override public func insertSubview(_ view: UIView, belowSubview siblingSubview: UIView) {
        super.insertSubview(view, belowSubview: siblingSubview)
        
        if let view = view as? OverlayMaskContainerViewProtocol {
            self.maskContents.addSubview(view.maskContents)
        }
    }
    
    override public func willRemoveSubview(_ subview: UIView) {
        super.willRemoveSubview(subview)
        
        if let view = subview as? OverlayMaskContainerViewProtocol {
            if view.maskContents.superview === self.maskContents {
                view.maskContents.removeFromSuperview()
            }
        }
    }
}
