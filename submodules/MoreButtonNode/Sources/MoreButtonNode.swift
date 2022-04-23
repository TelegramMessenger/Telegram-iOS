import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import ManagedAnimationNode
import ContextUI

public final class MoreButtonNode: ASDisplayNode {
    public class MoreIconNode: ManagedAnimationNode {
        public enum State: Equatable {
            case more
            case search
        }
        
        private let duration: Double = 0.21
        public var iconState: State = .search
        
        init() {
            super.init(size: CGSize(width: 30.0, height: 30.0))
            
            self.trackTo(item: ManagedAnimationItem(source: .local("anim_moretosearch"), frames: .range(startFrame: 90, endFrame: 90), duration: 0.0))
        }
            
        func play() {
            if case .more = self.iconState {
                self.trackTo(item: ManagedAnimationItem(source: .local("anim_moredots"), frames: .range(startFrame: 0, endFrame: 46), duration: 0.76))
            }
        }
        
        public func enqueueState(_ state: State, animated: Bool) {
            guard self.iconState != state else {
                return
            }
            
            let previousState = self.iconState
            self.iconState = state
            
            let source = ManagedAnimationSource.local("anim_moretosearch")
            
            let totalLength: Int = 90
            if animated {
                switch previousState {
                    case .more:
                        switch state {
                            case .more:
                                break
                            case .search:
                                self.trackTo(item: ManagedAnimationItem(source: source, frames: .range(startFrame: 0, endFrame: totalLength), duration: self.duration))
                        }
                    case .search:
                        switch state {
                            case .more:
                                self.trackTo(item: ManagedAnimationItem(source: source, frames: .range(startFrame: totalLength, endFrame: 0), duration: self.duration))
                            case .search:
                                break
                        }
                }
            } else {
                switch state {
                    case .more:
                        self.trackTo(item: ManagedAnimationItem(source: source, frames: .range(startFrame: 0, endFrame: 0), duration: 0.0))
                    case .search:
                        self.trackTo(item: ManagedAnimationItem(source: source, frames: .range(startFrame: totalLength, endFrame: totalLength), duration: 0.0))
                }
            }
        }
    }

    public var action: ((ASDisplayNode, ContextGesture?) -> Void)?
    
    private let containerNode: ContextControllerSourceNode
    public let contextSourceNode: ContextReferenceContentNode
    private let buttonNode: HighlightableButtonNode
    public let iconNode: MoreIconNode
    
    public var theme: PresentationTheme {
        didSet {
            self.iconNode.customColor = self.theme.rootController.navigationBar.buttonColor
        }
    }
    
    public init(theme: PresentationTheme) {
        self.theme = theme
        
        self.contextSourceNode = ContextReferenceContentNode()
        self.containerNode = ContextControllerSourceNode()
        self.containerNode.animateScale = false
        
        self.buttonNode = HighlightableButtonNode()
        self.iconNode = MoreIconNode()
        self.iconNode.customColor = self.theme.rootController.navigationBar.buttonColor
        
        super.init()
        
        self.addSubnode(self.buttonNode)
        
        self.buttonNode.addSubnode(self.containerNode)
        self.containerNode.addSubnode(self.contextSourceNode)
        self.contextSourceNode.addSubnode(self.iconNode)
        
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
        
        self.containerNode.activated = { [weak self] gesture, _ in
            guard let strongSelf = self else {
                return
            }
            if case .more = strongSelf.iconNode.iconState {
                strongSelf.action?(strongSelf.contextSourceNode, gesture)
            }
        }
    }
    
    @objc public func buttonPressed() {
        self.action?(self.contextSourceNode, nil)
        if case .more = self.iconNode.iconState {
            self.iconNode.play()
        }
    }
        
    override public func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        let animationSize = CGSize(width: 30.0, height: 30.0)
        let inset: CGFloat = 0.0
        self.iconNode.frame = CGRect(origin: CGPoint(x: inset + 6.0, y: floor((constrainedSize.height - animationSize.height) / 2.0) + 1.0), size: animationSize)
        
        let size = CGSize(width: animationSize.width + inset * 2.0, height: constrainedSize.height)
        let bounds = CGRect(origin: CGPoint(), size: size)
        self.buttonNode.frame = bounds
        self.containerNode.frame = bounds
        self.contextSourceNode.frame = bounds
        return size
    }
}
