import Foundation
import UIKit
import AsyncDisplayKit
import Display
import AvatarNode
import ContextUI

private let normalFont = avatarPlaceholderFont(size: 16.0)
private let smallFont = avatarPlaceholderFont(size: 12.0)

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
    
    var tapped: (() -> Void)?
    
    override init() {
        self.containerNode = ContextControllerSourceNode()
        self.avatarNode = AvatarNode(font: normalFont)
        
        super.init()
        
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
