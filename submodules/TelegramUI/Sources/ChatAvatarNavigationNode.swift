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
        
    override init() {
        self.containerNode = ContextControllerSourceNode()
        self.avatarNode = AvatarNode(font: normalFont)
        
        super.init()
        
        self.addSubnode(self.containerNode)
        self.containerNode.addSubnode(self.avatarNode)
        
        self.containerNode.activated = { [weak self] gesture, _ in
            guard let strongSelf = self else {
                return
            }
            strongSelf.contextAction?(strongSelf.containerNode, gesture)
        }
        
        self.containerNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: 37.0, height: 37.0)).offsetBy(dx: 10.0, dy: 1.0)
        self.avatarNode.frame = self.containerNode.bounds
    }
    
    override func didLoad() {
        super.didLoad()
        self.view.isOpaque = false
    }
    
    override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        return CGSize(width: 37.0, height: 37.0)
    }
    
    func onLayout() {
    }

    final class SnapshotState {
        fileprivate let snapshotView: UIView?

        fileprivate init(snapshotView: UIView?) {
            self.snapshotView = snapshotView
        }
    }

    func prepareSnapshotState() -> SnapshotState {
        let snapshotView = self.avatarNode.view.snapshotView(afterScreenUpdates: false)
        return SnapshotState(
            snapshotView: snapshotView
        )
    }

    func animateFromSnapshot(_ snapshotState: SnapshotState) {
        self.avatarNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
        self.avatarNode.layer.animateScale(from: 0.1, to: 1.0, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: true)

        if let snapshotView = snapshotState.snapshotView {
            snapshotView.frame = self.frame
            self.containerNode.view.addSubview(snapshotView)

            snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                snapshotView?.removeFromSuperview()
            })
            snapshotView.layer.animateScale(from: 1.0, to: 0.1, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
        }
    }
}
