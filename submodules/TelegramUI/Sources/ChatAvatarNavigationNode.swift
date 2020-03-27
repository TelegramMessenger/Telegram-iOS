import Foundation
import UIKit
import AsyncDisplayKit
import Display
import AvatarNode
import ContextUI

private let normalFont = avatarPlaceholderFont(size: 16.0)
private let smallFont = avatarPlaceholderFont(size: 12.0)

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
    private let containerNode: ContextControllerSourceNode
    let avatarNode: AvatarNode
    
    var contextAction: ((ASDisplayNode, ContextGesture?) -> Void)?
    var contextActionIsEnabled: Bool = true {
        didSet {
            if self.contextActionIsEnabled != oldValue {
                self.containerNode.isGestureEnabled = self.contextActionIsEnabled
            }
        }
    }
    
    weak var chatController: ChatControllerImpl? {
        didSet {
            if self.isNodeLoaded {
                (self.view as? ChatAvatarNavigationNodeView)?.chatController = self.chatController
            }
        }
    }
    
    var tapped: (() -> Void)?
    
    override init() {
        self.containerNode = ContextControllerSourceNode()
        self.avatarNode = AvatarNode(font: normalFont)
        
        super.init()
        
        self.setViewBlock({
            return ChatAvatarNavigationNodeView()
        })
        
        self.containerNode.addSubnode(self.avatarNode)
        self.addSubnode(self.containerNode)
        
        self.containerNode.activated = { [weak self] gesture, _ in
            guard let strongSelf = self else {
                return
            }
            strongSelf.contextAction?(strongSelf.containerNode, gesture)
        }
        
        self.containerNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: 37.0, height: 37.0)).offsetBy(dx: 10.0, dy: 1.0)
        self.avatarNode.frame = self.containerNode.bounds
        
        /*self.containerNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: 37.0, height: 37.0))
        self.avatarNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: 37.0, height: 37.0))*/
    }
    
    override func didLoad() {
        super.didLoad()
        self.view.isOpaque = false
        (self.view as? ChatAvatarNavigationNodeView)?.targetNode = self
        (self.view as? ChatAvatarNavigationNodeView)?.chatController = self.chatController
        
        /*let tapRecognizer = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.avatarTapGesture(_:)))
        self.avatarNode.view.addGestureRecognizer(tapRecognizer)*/
    }
    
    @objc private func avatarTapGesture(_ recognizer: TapLongTapOrDoubleTapGestureRecognizer) {
        if case .ended = recognizer.state {
            if let (gesture, location) = recognizer.lastRecognizedGestureAndLocation {
                switch gesture {
                case .tap:
                    self.tapped?()
                default:
                    break
                }
            }
        }
    }
    
    override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        return CGSize(width: 37.0, height: 37.0)
    }
    
    func onLayout() {
    }
}
