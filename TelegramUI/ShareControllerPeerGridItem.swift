import Foundation
import Display
import TelegramCore
import SwiftSignalKit
import AsyncDisplayKit
import Postbox

final class ShareControllerInteraction {
    var selectedPeerIds = Set<PeerId>()
    let togglePeer: (Peer) -> Void
    
    init(togglePeer: @escaping (Peer) -> Void) {
        self.togglePeer = togglePeer
    }
}

private let selectionBackgroundImage = generateImage(CGSize(width: 60.0 + 4.0, height: 60.0 + 4.0), rotatedContext: { size, context in
    context.clear(CGRect(origin: CGPoint(), size: size))
    context.setFillColor(UIColor(0x007ee5).cgColor)
    context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
    context.setFillColor(UIColor.white.cgColor)
    context.fillEllipse(in: CGRect(origin: CGPoint(x: 2.0, y: 2.0), size: CGSize(width: size.width - 4.0, height: size.height - 4.0)))
})

final class ShareControllerPeerGridItem: GridItem {
    let account: Account
    let peer: Peer
    let controllerInteraction: ShareControllerInteraction
    
    let section: GridSection? = nil
    
    init(account: Account, peer: Peer, controllerInteraction: ShareControllerInteraction) {
        self.account = account
        self.peer = peer
        self.controllerInteraction = controllerInteraction
    }
    
    func node(layout: GridNodeLayout) -> GridItemNode {
        let node = ShareControllerPeerGridItemNode()
        node.controllerInteraction = self.controllerInteraction
        node.setup(account: self.account, peer: self.peer)
        return node
    }
    
    func update(node: GridItemNode) {
        guard let node = node as? ShareControllerPeerGridItemNode else {
            assertionFailure()
            return
        }
        node.controllerInteraction = self.controllerInteraction
        node.setup(account: self.account, peer: self.peer)
    }
}

private let avatarFont = Font.medium(18.0)
private let textFont = Font.regular(11.0)

final class ShareControllerPeerGridItemNode: GridItemNode {
    private var currentState: (Account, Peer)?
    private let avatarSelectionNode: ASImageNode
    private let avatarNodeContainer: ASDisplayNode
    private let avatarNode: AvatarNode
    private let textNode: ASTextNode
    
    var controllerInteraction: ShareControllerInteraction?
    
    var currentSelected = false
    
    override init() {
        self.avatarNodeContainer = ASDisplayNode()
        
        self.avatarSelectionNode = ASImageNode()
        self.avatarSelectionNode.image = selectionBackgroundImage
        self.avatarSelectionNode.isLayerBacked = true
        self.avatarSelectionNode.displayWithoutProcessing = true
        self.avatarSelectionNode.displaysAsynchronously = false
        self.avatarSelectionNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: 60.0, height: 60.0))
        self.avatarSelectionNode.alpha = 0.0
        
        self.avatarNode = AvatarNode(font: avatarFont)
        self.avatarNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: 60.0, height: 60.0))
        self.avatarNode.isLayerBacked = true
        
        self.textNode = ASTextNode()
        self.textNode.isLayerBacked = true
        self.textNode.displaysAsynchronously = true
        self.textNode.maximumNumberOfLines = 2
        
        super.init()
        
        self.avatarNodeContainer.addSubnode(self.avatarSelectionNode)
        self.avatarNodeContainer.addSubnode(self.avatarNode)
        self.addSubnode(self.avatarNodeContainer)
        self.addSubnode(self.textNode)
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
    }
    
    func setup(account: Account, peer: Peer) {
        if self.currentState == nil || self.currentState!.0 !== account || !arePeersEqual(self.currentState!.1, peer) {
            let text = peer.displayTitle
            self.textNode.attributedText = NSAttributedString(string: text, font: textFont, textColor: self.currentSelected ? UIColor(0x007ee5) : UIColor.black, paragraphAlignment: .center)
            self.avatarNode.setPeer(account: account, peer: peer)
            self.currentState = (account, peer)
            self.setNeedsLayout()
        }
        self.updateSelection(animated: false)
    }
    
    @objc func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            if let (_, peer) = self.currentState {
                self.controllerInteraction?.togglePeer(peer)
            }
        }
    }
    
    func updateSelection(animated: Bool) {
        var selected = false
        if let controllerInteraction = self.controllerInteraction, let (_, peer) = self.currentState {
            selected = controllerInteraction.selectedPeerIds.contains(peer.id)
        }
        
        if selected != self.currentSelected {
            self.currentSelected = selected
            
            if let (_, peer) = self.currentState {
                self.textNode.attributedText = NSAttributedString(string: peer.displayTitle, font: textFont, textColor: selected ? UIColor(0x007ee5) : UIColor.black, paragraphAlignment: .center)
            }
            
            if selected {
                self.avatarNode.transform = CATransform3DMakeScale(0.866666, 0.866666, 1.0)
                self.avatarSelectionNode.alpha = 1.0
                if animated {
                    //self.avatarNode.layer.animateSpring(from: 1.0 as NSNumber, to: 0.866666 as NSNumber, keyPath: "transform.scale", duration: 0.5, initialVelocity: 10.0)
                    self.avatarNode.layer.animateScale(from: 1.0, to: 0.866666, duration: 0.2, timingFunction: kCAMediaTimingFunctionSpring)
                    self.avatarSelectionNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
                }
            } else {
                self.avatarNode.transform = CATransform3DIdentity
                self.avatarSelectionNode.alpha = 0.0
                if animated {
                    //self.avatarNode.layer.animateSpring(from: 0.866666 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.6, initialVelocity: 10.0)
                    self.avatarNode.layer.animateScale(from: 0.866666, to: 1.0, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring)
                    self.avatarSelectionNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.28)
                }
            }
        }
    }
    
    override func layout() {
        super.layout()
        
        let bounds = self.bounds
        
        self.avatarNodeContainer.frame = CGRect(origin: CGPoint(x: floor((bounds.size.width - 60.0) / 2.0), y: 4.0), size: CGSize(width: 60.0, height: 60.0))
        
        self.textNode.frame = CGRect(origin: CGPoint(x: 2.0, y: 4.0 + 60.0 + 4.0), size: CGSize(width: bounds.size.width - 4.0, height: 34.0))
    }
    
    func animateIn() {
        self.textNode.layer.animatePosition(from: CGPoint(x: 0.0, y: 60.0), to: CGPoint(), duration: 0.42, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
    }
}
