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
        public var scale: CGFloat
        public var loop: Bool
        
        public init(source: Source, scale: CGFloat = 2.0, loop: Bool) {
            self.source = source
            self.scale = scale
            self.loop = loop
        }
    }
    
    public let account: Account
    public let animation: Animation
    public var tintColor: UIColor?
    public let isAnimating: Bool
    public let size: CGSize
    
    public init(account: Account, animation: Animation, tintColor: UIColor? = nil, isAnimating: Bool = true, size: CGSize) {
        self.account = account
        self.animation = animation
        self.tintColor = tintColor
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
        if lhs.tintColor != rhs.tintColor {
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
                
                var playbackMode: AnimatedStickerPlaybackMode = .still(.start)
                if component.animation.loop {
                    playbackMode = .loop
                } else if component.isAnimating {
                    playbackMode = .once
                } else {
                    animationNode.autoplay = true
                }
                animationNode.setup(source: source, width: Int(component.size.width * component.animation.scale), height: Int(component.size.height * component.animation.scale), playbackMode: playbackMode, mode: .direct(cachePathPrefix: nil))
                animationNode.visibility = self.isInHierarchy
                
                self.animationNode = animationNode
                self.addSubnode(animationNode)
            }
            
            self.animationNode?.setOverlayColor(component.tintColor, replace: true, animated: false)
            
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
