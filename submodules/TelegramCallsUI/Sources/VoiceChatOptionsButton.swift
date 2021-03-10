import Foundation
import UIKit
import AsyncDisplayKit
import Display
import Postbox
import AccountContext
import TelegramPresentationData
import AvatarNode

func optionsBackgroundImage(dark: Bool) -> UIImage? {
    return generateImage(CGSize(width: 28.0, height: 28.0), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        
        context.setFillColor(UIColor(rgb: dark ? 0x1c1c1e : 0x2c2c2e).cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
    })?.stretchableImage(withLeftCapWidth: 14, topCapHeight: 14)
}

func optionsButtonImage(dark: Bool) -> UIImage? {
    return generateImage(CGSize(width: 28.0, height: 28.0), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        
        context.setFillColor(UIColor(rgb: dark ? 0x1c1c1e : 0x2c2c2e).cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
        
        context.setFillColor(UIColor.white.cgColor)
        context.fillEllipse(in: CGRect(x: 6.0, y: 12.0, width: 4.0, height: 4.0))
        context.fillEllipse(in: CGRect(x: 12.0, y: 12.0, width: 4.0, height: 4.0))
        context.fillEllipse(in: CGRect(x: 18.0, y: 12.0, width: 4.0, height: 4.0))
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
        case avatar(Peer)
    }
    
    private let context: AccountContext
    private var theme: PresentationTheme
    
    let referenceNode: ContextReferenceContentNode
    let containerNode: ContextControllerSourceNode
    private let iconNode: ASImageNode
    private let avatarNode: AvatarNode
    
    var contextAction: ((ASDisplayNode, ContextGesture?) -> Void)?
    
    init(context: AccountContext) {
        self.context = context
        self.theme = context.sharedContext.currentPresentationData.with { $0 }.theme
        
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
        
        self.iconNode.image = optionsButtonImage(dark: false)
        
        self.containerNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: 28.0, height: 28.0))
        self.referenceNode.frame = self.containerNode.bounds
        self.iconNode.frame = self.containerNode.bounds
        self.avatarNode.frame = self.containerNode.bounds
    }
    
    private var content: Content?
    func setContent(_ content: Content, animated: Bool = false) {
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
                    self.avatarNode.setPeer(context: self.context, theme: self.theme, peer: peer)
                    self.iconNode.isHidden = true
                    self.avatarNode.isHidden = false
                    
            }
        } else {
            self.content = content
            switch content {
                case let .image(image):
                    self.iconNode.image = image
                    self.iconNode.isHidden = false
                    self.avatarNode.isHidden = true
                case let .avatar(peer):
                    self.avatarNode.setPeer(context: self.context, theme: self.theme, peer: peer)
                    self.iconNode.isHidden = true
                    self.avatarNode.isHidden = false
            }
        }
    }
        
    override func didLoad() {
        super.didLoad()
        self.view.isOpaque = false
    }
    
    override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        return CGSize(width: 28.0, height: 28.0)
    }
        
    func onLayout() {
    }
}
