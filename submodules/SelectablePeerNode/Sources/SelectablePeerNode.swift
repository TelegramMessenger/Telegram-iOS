import Foundation
import UIKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SyncCore
import SwiftSignalKit
import TelegramPresentationData
import AvatarNode
import PeerOnlineMarkerNode
import LegacyComponents
import ContextUI
import LocalizedPeerData
import AccountContext

private let avatarFont = avatarPlaceholderFont(size: 24.0)
private let textFont = Font.regular(11.0)

public final class SelectablePeerNodeTheme {
    let textColor: UIColor
    let secretTextColor: UIColor
    let selectedTextColor: UIColor
    let checkBackgroundColor: UIColor
    let checkFillColor: UIColor
    let checkColor: UIColor
    let avatarPlaceholderColor: UIColor
    
    public init(textColor: UIColor, secretTextColor: UIColor, selectedTextColor: UIColor, checkBackgroundColor: UIColor, checkFillColor: UIColor, checkColor: UIColor, avatarPlaceholderColor: UIColor) {
        self.textColor = textColor
        self.secretTextColor = secretTextColor
        self.selectedTextColor = selectedTextColor
        self.checkBackgroundColor = checkBackgroundColor
        self.checkFillColor = checkFillColor
        self.checkColor = checkColor
        self.avatarPlaceholderColor = avatarPlaceholderColor
    }
    
    public func isEqual(to: SelectablePeerNodeTheme) -> Bool {
        if self === to {
            return true
        }
        if !self.textColor.isEqual(to.textColor) {
            return false
        }
        if !self.secretTextColor.isEqual(to.secretTextColor) {
            return false
        }
        if !self.selectedTextColor.isEqual(to.selectedTextColor) {
            return false
        }
        if !self.checkBackgroundColor.isEqual(to.checkBackgroundColor) {
            return false
        }
        if !self.checkFillColor.isEqual(to.checkFillColor) {
            return false
        }
        if !self.checkColor.isEqual(to.checkColor) {
            return false
        }
        if !self.avatarPlaceholderColor.isEqual(to.avatarPlaceholderColor) {
            return false
        }
        return true
    }
}

public final class SelectablePeerNode: ASDisplayNode {
    private let contextContainer: ContextControllerSourceNode
    private let avatarSelectionNode: ASImageNode
    private let avatarNodeContainer: ASDisplayNode
    private let avatarNode: AvatarNode
    private let onlineNode: PeerOnlineMarkerNode
    private var checkView: TGCheckButtonView?
    private let textNode: ASTextNode

    public var toggleSelection: (() -> Void)?
    public var contextAction: ((ASDisplayNode, ContextGesture?) -> Void)? {
        didSet {
            self.contextContainer.isGestureEnabled = self.contextAction != nil
        }
    }
    
    private var currentSelected = false
    
    private var peer: RenderedPeer?
    
    public var theme: SelectablePeerNodeTheme = SelectablePeerNodeTheme(textColor: .black, secretTextColor: .green, selectedTextColor: .blue, checkBackgroundColor: .white, checkFillColor: .blue, checkColor: .white, avatarPlaceholderColor: .white) {
        didSet {
            if !self.theme.isEqual(to: oldValue) {
                if let peer = self.peer, let mainPeer = peer.chatMainPeer {
                    self.textNode.attributedText = NSAttributedString(string: mainPeer.debugDisplayTitle, font: textFont, textColor: self.currentSelected ? self.theme.selectedTextColor : (peer.peerId.namespace == Namespaces.Peer.SecretChat ? self.theme.secretTextColor : self.theme.textColor), paragraphAlignment: .center)
                }
            }
        }
    }
    
    override public init() {
        self.contextContainer = ContextControllerSourceNode()
        self.contextContainer.isGestureEnabled = false
        
        self.avatarNodeContainer = ASDisplayNode()
        
        self.avatarSelectionNode = ASImageNode()
        self.avatarSelectionNode.isLayerBacked = true
        self.avatarSelectionNode.displayWithoutProcessing = true
        self.avatarSelectionNode.displaysAsynchronously = false
        self.avatarSelectionNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: 60.0, height: 60.0))
        self.avatarSelectionNode.alpha = 0.0
        
        self.avatarNode = AvatarNode(font: avatarFont)
        self.avatarNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: 60.0, height: 60.0))
        self.avatarNode.isLayerBacked = !smartInvertColorsEnabled()
        
        self.textNode = ASTextNode()
        self.textNode.isUserInteractionEnabled = false
        self.textNode.displaysAsynchronously = true
        
        self.onlineNode = PeerOnlineMarkerNode()
        
        super.init()
        
        self.addSubnode(self.contextContainer)
        self.avatarNodeContainer.addSubnode(self.avatarSelectionNode)
        self.avatarNodeContainer.addSubnode(self.avatarNode)
        self.contextContainer.addSubnode(self.avatarNodeContainer)
        self.contextContainer.addSubnode(self.textNode)
        self.contextContainer.addSubnode(self.onlineNode)
        
        self.contextContainer.activated = { [weak self] gesture, _ in
            guard let strongSelf = self, let contextAction = strongSelf.contextAction else {
                gesture.cancel()
                return
            }
            contextAction(strongSelf.contextContainer, gesture)
        }
    }
    
    public func setup(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings, peer: RenderedPeer, online: Bool = false, numberOfLines: Int = 2, synchronousLoad: Bool) {
        self.peer = peer
        guard let mainPeer = peer.chatMainPeer else {
            return
        }
        
        let defaultColor: UIColor = peer.peerId.namespace == Namespaces.Peer.SecretChat ? self.theme.secretTextColor : self.theme.textColor
        
        let text: String
        var overrideImage: AvatarNodeImageOverride?
        if peer.peerId == context.account.peerId {
            text = strings.DialogList_SavedMessages
            overrideImage = .savedMessagesIcon
        } else {
            text = mainPeer.compactDisplayTitle
            if mainPeer.isDeleted {
                overrideImage = .deletedIcon
            }
        }
        self.textNode.maximumNumberOfLines = numberOfLines
        self.textNode.attributedText = NSAttributedString(string: text, font: textFont, textColor: self.currentSelected ? self.theme.selectedTextColor : defaultColor, paragraphAlignment: .center)
        self.avatarNode.setPeer(context: context, theme: theme, peer: mainPeer, overrideImage: overrideImage, emptyColor: self.theme.avatarPlaceholderColor, synchronousLoad: synchronousLoad)
        
        let onlineLayout = self.onlineNode.asyncLayout()
        let (onlineSize, onlineApply) = onlineLayout(online)
        let _ = onlineApply(false)
        
        self.onlineNode.setImage(PresentationResourcesChatList.recentStatusOnlineIcon(theme, state: .panel))
        self.onlineNode.frame = CGRect(origin: CGPoint(), size: onlineSize)
        
        self.setNeedsLayout()
    }
    
    public func updateSelection(selected: Bool, animated: Bool) {
        if selected != self.currentSelected {
            self.currentSelected = selected
            
            if let attributedText = self.textNode.attributedText {
                self.textNode.attributedText = NSAttributedString(string: attributedText.string, font: textFont, textColor: selected ? self.theme.selectedTextColor : (self.peer?.peerId.namespace == Namespaces.Peer.SecretChat ? self.theme.secretTextColor : self.theme.textColor), paragraphAlignment: .center)
            }
            
            if selected {
                self.avatarNode.transform = CATransform3DMakeScale(0.866666, 0.866666, 1.0)
                self.avatarSelectionNode.alpha = 1.0
                self.avatarSelectionNode.image = generateImage(CGSize(width: 60.0 + 4.0, height: 60.0 + 4.0), rotatedContext: { size, context in
                    context.clear(CGRect(origin: CGPoint(), size: size))
                    context.setFillColor(self.theme.selectedTextColor.cgColor)
                    context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
                    context.setBlendMode(.copy)
                    context.setFillColor(UIColor.clear.cgColor)
                    context.fillEllipse(in: CGRect(origin: CGPoint(x: 2.0, y: 2.0), size: CGSize(width: size.width - 4.0, height: size.height - 4.0)))
                })
                if animated {
                    self.avatarNode.layer.animateScale(from: 1.0, to: 0.866666, duration: 0.2, timingFunction: kCAMediaTimingFunctionSpring)
                    self.avatarSelectionNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
                }
            } else {
                self.avatarNode.transform = CATransform3DIdentity
                self.avatarSelectionNode.alpha = 0.0
                if animated {
                    self.avatarNode.layer.animateScale(from: 0.866666, to: 1.0, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring)
                    self.avatarSelectionNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.28, completion: { [weak avatarSelectionNode] _ in
                        avatarSelectionNode?.image = nil
                    })
                } else {
                    self.avatarSelectionNode.image = nil
                }
            }
            
            if selected {
                if self.checkView == nil {
                    let checkView = TGCheckButtonView(style: TGCheckButtonStyleShare, pallete: TGCheckButtonPallete(defaultBackgroundColor: self.theme.checkBackgroundColor, accentBackgroundColor: self.theme.checkFillColor, defaultBorderColor: .clear, mediaBorderColor: .clear, chatBorderColor: .clear, check: self.theme.checkColor, blueColor: self.theme.checkFillColor, barBackgroundColor: self.theme.checkBackgroundColor))!
                    
                    self.checkView = checkView
                    checkView.isUserInteractionEnabled = false
                    self.view.addSubview(checkView)
                    
                    let avatarFrame = self.avatarNode.frame
                    let checkSize = checkView.bounds.size
                    checkView.frame = CGRect(origin: CGPoint(x: avatarFrame.maxX - 14.0, y: avatarFrame.maxY - 22.0), size: checkSize)
                    checkView.setSelected(true, animated: animated)
                }
            } else if let checkView = self.checkView {
                self.checkView = nil
                checkView.setSelected(false, animated: animated, bump: false, completion: { [weak checkView] in
                    checkView?.removeFromSuperview()
                })
            }
        }
    }
    
    override public func didLoad() {
        super.didLoad()
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
    }
    
    @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.toggleSelection?()
        }
    }
    
    override public func layout() {
        super.layout()
        
        let bounds = self.bounds
        
        self.contextContainer.frame = bounds
        
        self.avatarNodeContainer.frame = CGRect(origin: CGPoint(x: floor((bounds.size.width - 60.0) / 2.0), y: 4.0), size: CGSize(width: 60.0, height: 60.0))
        self.textNode.frame = CGRect(origin: CGPoint(x: 2.0, y: 4.0 + 60.0 + 4.0), size: CGSize(width: bounds.size.width - 4.0, height: 34.0))
        
        let avatarFrame = self.avatarNode.frame
        let avatarContainerFrame = self.avatarNodeContainer.frame
        
        self.onlineNode.frame = CGRect(origin: CGPoint(x: avatarContainerFrame.maxX - self.onlineNode.frame.width - 2.0, y: avatarContainerFrame.maxY - self.onlineNode.frame.height - 2.0), size: self.onlineNode.frame.size)
        
        if let checkView = self.checkView {
            let checkSize = checkView.bounds.size
            checkView.frame = CGRect(origin: CGPoint(x: avatarFrame.maxX - 14.0, y: avatarFrame.maxY - 22.0), size: checkSize)
        }
    }
}
