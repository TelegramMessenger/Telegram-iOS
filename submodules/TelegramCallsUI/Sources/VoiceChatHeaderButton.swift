import Foundation
import UIKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import AccountContext
import TelegramPresentationData
import AvatarNode
import AnimationUI

func optionsBackgroundImage(dark: Bool) -> UIImage? {
    return generateImage(CGSize(width: 28.0, height: 28.0), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        
        context.setFillColor(UIColor(rgb: dark ? 0x1c1c1e : 0x2c2c2e).cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
    })?.stretchableImage(withLeftCapWidth: 14, topCapHeight: 14)
}

func optionsCircleImage(dark: Bool) -> UIImage? {
    return generateImage(CGSize(width: 28.0, height: 28.0), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        
        context.setFillColor(UIColor(rgb: dark ? 0x1c1c1e : 0x2c2c2e).cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
    })
}

func panelButtonImage(dark: Bool) -> UIImage? {
    return generateImage(CGSize(width: 38.0, height: 28.0), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        
        context.addPath(UIBezierPath(roundedRect: CGRect(origin: CGPoint(), size: size), cornerRadius: 14.0).cgPath)
        context.setFillColor(UIColor(rgb: dark ? 0x1c1c1e : 0x2c2c2e).cgColor)
        context.fillPath()
        
        context.setFillColor(UIColor.white.cgColor)
        
        if let image = UIImage(bundleImageName: "Call/PanelIcon") {
            let imageSize = image.size
            let imageRect = CGRect(origin: CGPoint(), size: imageSize)
            context.saveGState()
            context.translateBy(x: 7.0, y: 2.0)
            context.clip(to: imageRect, mask: image.cgImage!)
            context.fill(imageRect)
            context.restoreGState()
        }
    })
}

func closeButtonImage(dark: Bool) -> UIImage? {
    return generateImage(CGSize(width: 28.0, height: 28.0), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        
        context.setFillColor(UIColor(rgb: dark ? 0x1c1c1e : 0x2c2c2e).cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
        
        context.setLineWidth(2.0)
        context.setLineCap(.round)
        context.setStrokeColor(UIColor.white.cgColor)
        
        context.move(to: CGPoint(x: 7.0 + UIScreenPixel, y: 16.0 + UIScreenPixel))
        context.addLine(to: CGPoint(x: 14.0, y: 10.0))
        context.addLine(to: CGPoint(x: 21.0 - UIScreenPixel, y: 16.0 + UIScreenPixel))
        context.strokePath()
    })
}

final class VoiceChatHeaderButton: HighlightableButtonNode {
    enum Content {
        case image(UIImage?)
        case more(UIImage?)
        case avatar(Peer)
    }
    
    private let context: AccountContext
    private var theme: PresentationTheme
    
    let referenceNode: ContextReferenceContentNode
    let containerNode: ContextControllerSourceNode
    private let iconNode: ASImageNode
    private var animationNode: AnimationNode?
    private let avatarNode: AvatarNode
    
    var contextAction: ((ASDisplayNode, ContextGesture?) -> Void)?
    
    private let wide: Bool
    
    init(context: AccountContext, wide: Bool = false) {
        self.context = context
        self.theme = context.sharedContext.currentPresentationData.with { $0 }.theme
        self.wide = wide
        
        self.referenceNode = ContextReferenceContentNode()
        self.containerNode = ContextControllerSourceNode()
        self.containerNode.animateScale = false
        self.iconNode = ASImageNode()
        self.iconNode.displaysAsynchronously = false
        self.iconNode.displayWithoutProcessing = true
        self.iconNode.contentMode = .scaleToFill
        
        self.avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 17.0))
        self.avatarNode.isHidden = true
        
        super.init()
        
        self.containerNode.addSubnode(self.referenceNode)
        self.referenceNode.addSubnode(self.iconNode)
        self.referenceNode.addSubnode(self.avatarNode)
        self.addSubnode(self.containerNode)
        
        self.containerNode.shouldBegin = { [weak self] location in
            guard let strongSelf = self, let _ = strongSelf.contextAction else {
                return false
            }
            return true
        }
        self.containerNode.activated = { [weak self] gesture, _ in
            guard let strongSelf = self else {
                return
            }
            strongSelf.contextAction?(strongSelf.containerNode, gesture)
        }
        
        self.iconNode.image = optionsCircleImage(dark: false)
        
        self.containerNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: wide ? 38.0 : 28.0, height: 28.0))
        self.referenceNode.frame = self.containerNode.bounds
        self.iconNode.frame = self.containerNode.bounds
        self.avatarNode.frame = self.containerNode.bounds
    }
    
    private var content: Content?
    func setContent(_ content: Content, animated: Bool = false) {
        if case .more = content, self.animationNode == nil {
            let iconColor = UIColor(rgb: 0xffffff)
            let animationNode = AnimationNode(animation: "anim_profilemore", colors: ["Point 2.Group 1.Fill 1": iconColor,
                                                                                      "Point 3.Group 1.Fill 1": iconColor,
                                                                                      "Point 1.Group 1.Fill 1": iconColor], scale: 1.0)
            animationNode.frame = self.containerNode.bounds
            self.addSubnode(animationNode)
            self.animationNode = animationNode
        }
        if animated {
            switch content {
                case let .image(image):
                    if let snapshotView = self.referenceNode.view.snapshotContentTree() {
                        snapshotView.frame = self.referenceNode.frame
                        self.view.addSubview(snapshotView)
                        
                        snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                            snapshotView?.removeFromSuperview()
                        })
                    }
                    self.iconNode.image = image
                    self.iconNode.isHidden = false
                    self.avatarNode.isHidden = true
                case let .avatar(peer):
                    self.avatarNode.setPeer(context: self.context, theme: self.theme, peer: EnginePeer(peer))
                    self.iconNode.isHidden = true
                    self.avatarNode.isHidden = false
                    self.animationNode?.isHidden = true
                case let .more(image):
                    self.iconNode.image = image
                    self.iconNode.isHidden = false
                    self.avatarNode.isHidden = true
                    self.animationNode?.isHidden = false
            }
        } else {
            self.content = content
            switch content {
                case let .image(image):
                    self.iconNode.image = image
                    self.iconNode.isHidden = false
                    self.avatarNode.isHidden = true
                case let .avatar(peer):
                    self.avatarNode.setPeer(context: self.context, theme: self.theme, peer: EnginePeer(peer))
                    self.iconNode.isHidden = true
                    self.avatarNode.isHidden = false
                    self.animationNode?.isHidden = true
                case let .more(image):
                    self.iconNode.image = image
                    self.iconNode.isHidden = false
                    self.avatarNode.isHidden = true
                    self.animationNode?.isHidden = false
            }
        }
    }
        
    override func didLoad() {
        super.didLoad()
        self.view.isOpaque = false
    }
    
    override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        return CGSize(width: wide ? 38.0 : 28.0, height: 28.0)
    }
        
    func onLayout() {
    }
    
    func play() {
        self.animationNode?.playOnce()
    }
}
