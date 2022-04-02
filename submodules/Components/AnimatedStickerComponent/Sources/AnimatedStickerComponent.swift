import Foundation
import UIKit
import ComponentFlow
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import HierarchyTrackingLayer
import TelegramCore

public final class AnimatedStickerComponent: Component {
    public struct Animation: Equatable {
        public enum Source: Equatable {
            case bundle(name: String)
            case file(media: TelegramMediaFile)
        }
        
        public var source: Source
        public var loop: Bool
        public var tintColor: UIColor?
        
        public init(source: Source, loop: Bool, tintColor: UIColor? = nil) {
            self.source = source
            self.loop = loop
            self.tintColor = tintColor
        }
    }
    
    public let account: Account
    public let animation: Animation
    public let isAnimating: Bool
    public let size: CGSize
    
    public init(account: Account, animation: Animation, isAnimating: Bool = true, size: CGSize) {
        self.account = account
        self.animation = animation
        self.isAnimating = isAnimating
        self.size = size
    }

    public static func ==(lhs: AnimatedStickerComponent, rhs: AnimatedStickerComponent) -> Bool {
        if lhs.account !== rhs.account {
            return false
        }
        if lhs.animation != rhs.animation {
            return false
        }
        if lhs.isAnimating != rhs.isAnimating {
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
                self.animationNode?.view.removeFromSuperview()
                
                let animationNode = AnimatedStickerNode()
                let source: AnimatedStickerNodeSource
                switch component.animation.source {
                    case let .bundle(name):
                        source = AnimatedStickerNodeLocalFileSource(name: name)
                    case let .file(media):
                        source = AnimatedStickerResourceSource(account: component.account, resource: media.resource, fitzModifier: nil, isVideo: false)
                }
                animationNode.setOverlayColor(component.animation.tintColor, replace: true, animated: false)
                
                var playbackMode: AnimatedStickerPlaybackMode = .still(.start)
                if component.animation.loop {
                    playbackMode = .loop
                } else if component.isAnimating {
                    playbackMode = .once
                }
                animationNode.setup(source: source, width: Int(component.size.width * 2.0), height: Int(component.size.height * 2.0), playbackMode: playbackMode, mode: .direct(cachePathPrefix: nil))
                animationNode.visibility = self.isInHierarchy
                
                self.animationNode = animationNode
                self.addSubnode(animationNode)
            }
            
            if !component.animation.loop && component.isAnimating != self.component?.isAnimating {
                if component.isAnimating {
                    let _ = self.animationNode?.playIfNeeded()
                }
            }
            
            self.component = component
                
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
