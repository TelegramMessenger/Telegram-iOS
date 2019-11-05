import Foundation
import UIKit
import AsyncDisplayKit
import Display
import AvatarNode

private let normalFont = UIFont(name: ".SFCompactRounded-Semibold", size: 16.0)!
private let smallFont = UIFont(name: ".SFCompactRounded-Semibold", size: 12.0)!

final class ChatAvatarNavigationNodeView: UIView, PreviewingHostView {
    var previewingDelegate: PreviewingHostViewDelegate? {
        return PreviewingHostViewDelegate(controllerForLocation: { [weak self] sourceView, point in
            return self?.chatController?.avatarPreviewingController(from: sourceView)
        }, commitController: { [weak self] controller in
            self?.chatController?.previewingCommit(controller)
        })
    }
    
    weak var chatController: ChatControllerImpl?
    weak var targetNode: ChatAvatarNavigationNode?
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        self.targetNode?.onLayout()
    }
}

final class ChatAvatarNavigationNode: ASDisplayNode {
    let avatarNode: AvatarNode
    weak var chatController: ChatControllerImpl? {
        didSet {
            if self.isNodeLoaded {
                (self.view as? ChatAvatarNavigationNodeView)?.chatController = self.chatController
            }
        }
    }
    
    override init() {
        self.avatarNode = AvatarNode(font: normalFont)
        
        super.init()
        
        self.setViewBlock({
            return ChatAvatarNavigationNodeView()
        })
        
        self.addSubnode(self.avatarNode)
    }
    
    override func didLoad() {
        super.didLoad()
        self.view.isOpaque = false
        (self.view as? ChatAvatarNavigationNodeView)?.targetNode = self
        (self.view as? ChatAvatarNavigationNodeView)?.chatController = self.chatController
    }
    
    override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        if constrainedSize.height.isLessThanOrEqualTo(32.0) {
            return CGSize(width: 26.0, height: 26.0)
        } else {
            return CGSize(width: 37.0, height: 37.0)
        }
    }
    
    func onLayout() {
        let bounds = self.bounds
        if self.bounds.size.height.isLessThanOrEqualTo(26.0) {
            if !self.avatarNode.bounds.size.equalTo(bounds.size) {
                self.avatarNode.font = smallFont
            }
            self.avatarNode.frame = bounds.offsetBy(dx: 8.0, dy: 0.0)
        } else {
            if !self.avatarNode.bounds.size.equalTo(bounds.size) {
                self.avatarNode.font = normalFont
            }
            self.avatarNode.frame = bounds.offsetBy(dx: 10.0, dy: 1.0)
        }
    }
}
