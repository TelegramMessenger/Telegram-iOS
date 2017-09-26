import Foundation
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SwiftSignalKit

import LegacyComponents

private let selectionBackgroundImage = generateImage(CGSize(width: 60.0 + 4.0, height: 60.0 + 4.0), rotatedContext: { size, context in
    context.clear(CGRect(origin: CGPoint(), size: size))
    context.setFillColor(UIColor(rgb: 0x007ee5).cgColor)
    context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
    context.setFillColor(UIColor.white.cgColor)
    context.fillEllipse(in: CGRect(origin: CGPoint(x: 2.0, y: 2.0), size: CGSize(width: size.width - 4.0, height: size.height - 4.0)))
})

private let avatarFont: UIFont = UIFont(name: "ArialRoundedMTBold", size: 24.0)!
private let textFont = Font.regular(11.0)

final class SelectablePeerNode: ASDisplayNode {
    private let avatarSelectionNode: ASImageNode
    private let avatarNodeContainer: ASDisplayNode
    private let avatarNode: AvatarNode
    private var checkView: TGCheckButtonView?
    private let textNode: ASTextNode
    
    var toggleSelection: (() -> Void)?
    
    private var currentSelected = false
    
    private var peer: Peer?
    private var chatPeer: Peer?
    
    var textColor: UIColor = .black
    var selectedColor: UIColor = UIColor(rgb: 0x007ee5)
    
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
        
        super.init()
        
        self.avatarNodeContainer.addSubnode(self.avatarSelectionNode)
        self.avatarNodeContainer.addSubnode(self.avatarNode)
        self.addSubnode(self.avatarNodeContainer)
        self.addSubnode(self.textNode)
    }
    
    func setup(account: Account, peer: Peer, chatPeer: Peer?, numberOfLines: Int = 2) {
        self.peer = peer
        self.chatPeer = chatPeer
        
        var defaultColor: UIColor = .black
        if let chatPeer = chatPeer, chatPeer.id.namespace == Namespaces.Peer.SecretChat {
            defaultColor = UIColor(rgb: 0x149a1f)
        }
        
        let text = peer.displayTitle
        self.textNode.maximumNumberOfLines = UInt(numberOfLines)
        self.textNode.attributedText = NSAttributedString(string: text, font: textFont, textColor: self.currentSelected ? UIColor(rgb: 0x007ee5) : defaultColor, paragraphAlignment: .center)
        self.avatarNode.setPeer(account: account, peer: peer)
        self.setNeedsLayout()
    }
    
    func updateSelection(selected: Bool, animated: Bool) {
        if selected != self.currentSelected {
            self.currentSelected = selected
            
            if let peer = self.peer {
                self.textNode.attributedText = NSAttributedString(string: peer.displayTitle, font: textFont, textColor: selected ? self.selectedColor : textColor, paragraphAlignment: .center)
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
            
            self.checkView?.setSelected(selected, animated: animated)
        }
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
        
        let checkView = TGCheckButtonView(style: TGCheckButtonStyleShare)!
        self.checkView = checkView
        checkView.isUserInteractionEnabled = false
        checkView.setSelected(self.currentSelected, animated: false)
        self.view.addSubview(checkView)
        
        let avatarFrame = self.avatarNode.frame
        let checkSize = checkView.bounds.size
        checkView.frame = CGRect(origin: CGPoint(x: avatarFrame.maxX - 14.0, y: avatarFrame.maxY - 22.0), size: checkSize)
    }
    
    @objc func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.toggleSelection?()
        }
    }
    
    override func layout() {
        super.layout()
        
        let bounds = self.bounds
        
        self.avatarNodeContainer.frame = CGRect(origin: CGPoint(x: floor((bounds.size.width - 60.0) / 2.0), y: 4.0), size: CGSize(width: 60.0, height: 60.0))
        
        self.textNode.frame = CGRect(origin: CGPoint(x: 2.0, y: 4.0 + 60.0 + 4.0), size: CGSize(width: bounds.size.width - 4.0, height: 34.0))
        
        let avatarFrame = self.avatarNode.frame
        if let checkView = self.checkView {
            let checkSize = checkView.bounds.size
            checkView.frame = CGRect(origin: CGPoint(x: avatarFrame.maxX - 14.0, y: avatarFrame.maxY - 22.0), size: checkSize)
        }
    }
}
