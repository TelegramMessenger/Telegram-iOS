import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import AccountContext
import TelegramUIPreferences
import TelegramPresentationData

public final class MediaNavigationAccessoryPanel: ASDisplayNode {
    public let containerNode: MediaNavigationAccessoryContainerNode
    
    public var close: (() -> Void)?
    public var setRate: ((AudioPlaybackRate) -> Void)?
    public var togglePlayPause: (() -> Void)?
    public var tapAction: (() -> Void)?
    public var playPrevious: (() -> Void)?
    public var playNext: (() -> Void)?
    
    public var getController: (() -> ViewController?)?
    public var presentInGlobalOverlay: ((ViewController) -> Void)?
    
    public init(context: AccountContext, presentationData: PresentationData, displayBackground: Bool = false) {
        self.containerNode = MediaNavigationAccessoryContainerNode(context: context, presentationData: presentationData, displayBackground: displayBackground)
        
        super.init()
        
        self.addSubnode(self.containerNode)
        
        self.containerNode.headerNode.close = { [weak self] in
            if let strongSelf = self, let close = strongSelf.close {
                close()
            }
        }
        self.containerNode.headerNode.setRate = { [weak self] rate in
            self?.setRate?(rate)
        }
        self.containerNode.headerNode.togglePlayPause = { [weak self] in
            if let strongSelf = self, let togglePlayPause = strongSelf.togglePlayPause {
                togglePlayPause()
            }
        }
        self.containerNode.headerNode.tapAction = { [weak self] in
            if let strongSelf = self, let tapAction = strongSelf.tapAction {
                tapAction()
            }
        }
        self.containerNode.headerNode.playPrevious = { [weak self] in
            if let strongSelf = self, let playPrevious = strongSelf.playPrevious {
                playPrevious()
            }
        }
        self.containerNode.headerNode.playNext = { [weak self] in
            if let strongSelf = self, let playNext = strongSelf.playNext {
                playNext()
            }
        }
        
        self.containerNode.headerNode.getController = { [weak self] in
            if let strongSelf = self, let getController = strongSelf.getController {
                return getController()
            } else {
                return nil
            }
        }
        
        self.containerNode.headerNode.presentInGlobalOverlay = { [weak self] c in
            if let strongSelf = self, let presentInGlobalOverlay = strongSelf.presentInGlobalOverlay {
                presentInGlobalOverlay(c)
            }
        }
    }
    
    public func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(node: self.containerNode, frame: CGRect(origin: CGPoint(), size: size))
        self.containerNode.updateLayout(size: size, leftInset: leftInset, rightInset: rightInset, transition: transition)
    }
    
    public func animateIn(transition: ContainedViewLayoutTransition) {
        self.clipsToBounds = true
        let contentPosition = self.containerNode.layer.position

        self.containerNode.animateIn(transition: transition)
        
        transition.animatePosition(node: self.containerNode, from: CGPoint(x: contentPosition.x, y: contentPosition.y - 37.0), completion: { [weak self] _ in
            self?.clipsToBounds = false
        })
    }
    
    public func animateOut(transition: ContainedViewLayoutTransition, completion: @escaping () -> Void) {
        self.clipsToBounds = true
        let contentPosition = self.containerNode.layer.position

        self.containerNode.animateOut(transition: transition)

        transition.animatePosition(node: self.containerNode, to: CGPoint(x: contentPosition.x, y: contentPosition.y - 37.0), removeOnCompletion: false, completion: { [weak self] _ in
            self?.clipsToBounds = false
            completion()
        })
    }
    
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        return self.containerNode.hitTest(point, with: event)
    }
}
