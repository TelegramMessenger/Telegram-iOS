import Foundation
import UIKit
import ComponentFlow
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import HierarchyTrackingLayer

public final class AnimatedStickerComponent: Component {
    public struct Animation: Equatable {
        public var name: String
        public var loop: Bool
        public var isAnimating: Bool
        
        public init(name: String, loop: Bool, isAnimating: Bool = true) {
            self.name = name
            self.loop = loop
            self.isAnimating = isAnimating
        }
    }
    
    public let animation: Animation
    public let size: CGSize
    
    public init(animation: Animation, size: CGSize) {
        self.animation = animation
        self.size = size
    }

    public static func ==(lhs: AnimatedStickerComponent, rhs: AnimatedStickerComponent) -> Bool {
        if lhs.animation != rhs.animation {
            return false
        }
        if lhs.size != rhs.size {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private var component: AnimatedStickerComponent?
        private var animationNode: AnimatedStickerNode?
        
        private let hierarchyTrackingLayer: HierarchyTrackingLayer
        private var isInHierarchy: Bool = false
        
        override init(frame: CGRect) {
            self.hierarchyTrackingLayer = HierarchyTrackingLayer()
            
            super.init(frame: frame)
            
            self.layer.addSublayer(self.hierarchyTrackingLayer)
            self.hierarchyTrackingLayer.didEnterHierarchy = { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.isInHierarchy = true
                strongSelf.animationNode?.visibility = true
            }
            
            self.hierarchyTrackingLayer.didExitHierarchy = { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.isInHierarchy = false
                strongSelf.animationNode?.visibility = false
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: AnimatedStickerComponent, availableSize: CGSize, transition: Transition) -> CGSize {
            if self.component?.animation != component.animation {
                self.component = component
                
                self.animationNode?.view.removeFromSuperview()
                
                let animationNode = AnimatedStickerNode()
                animationNode.setup(source: AnimatedStickerNodeLocalFileSource(name: component.animation.name), width: Int(component.size.width * 2.0), height: Int(component.size.height * 2.0), playbackMode: .loop, mode: .direct(cachePathPrefix: nil))
                animationNode.visibility = self.isInHierarchy
                
                self.animationNode = animationNode
                self.addSubnode(animationNode)
            }
            
            let animationSize = component.size
            
            let size = CGSize(width: min(animationSize.width, availableSize.width), height: min(animationSize.height, availableSize.height))
            
            if let animationNode = self.animationNode {
                animationNode.frame = CGRect(origin: CGPoint(x: floor((size.width - animationSize.width) / 2.0), y: floor((size.height - animationSize.height) / 2.0)), size: animationSize)
                animationNode.updateLayout(size: animationSize)
            }
            
            return size
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}
