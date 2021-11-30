import Foundation
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import TelegramPresentationData
import AppBundle
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import SwiftSignalKit
import StickerResources
import AccountContext

private func generateBubbleImage(foreground: UIColor, diameter: CGFloat, shadowBlur: CGFloat) -> UIImage? {
    return generateImage(CGSize(width: diameter + shadowBlur * 2.0, height: diameter + shadowBlur * 2.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setFillColor(foreground.cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(x: shadowBlur, y: shadowBlur), size: CGSize(width: diameter, height: diameter)))
    })?.stretchableImage(withLeftCapWidth: Int(diameter / 2.0 + shadowBlur / 2.0), topCapHeight: Int(diameter / 2.0 + shadowBlur / 2.0))
}

private func generateBubbleShadowImage(shadow: UIColor, diameter: CGFloat, shadowBlur: CGFloat) -> UIImage? {
    return generateImage(CGSize(width: diameter + shadowBlur * 2.0, height: diameter + shadowBlur * 2.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setFillColor(UIColor.white.cgColor)
        context.setShadow(offset: CGSize(), blur: shadowBlur, color: shadow.cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(x: shadowBlur, y: shadowBlur), size: CGSize(width: diameter, height: diameter)))
        context.setShadow(offset: CGSize(), blur: 1.0, color: shadow.cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(x: shadowBlur, y: shadowBlur), size: CGSize(width: diameter, height: diameter)))
        context.setFillColor(UIColor.clear.cgColor)
        context.setBlendMode(.copy)
        context.fillEllipse(in: CGRect(origin: CGPoint(x: shadowBlur, y: shadowBlur), size: CGSize(width: diameter, height: diameter)))
    })?.stretchableImage(withLeftCapWidth: Int(diameter / 2.0 + shadowBlur / 2.0), topCapHeight: Int(diameter / 2.0 + shadowBlur / 2.0))
}

private let font = Font.medium(13.0)

final class ReactionNode: ASDisplayNode {
    let context: AccountContext
    let item: ReactionContextItem
    private let staticImageNode: TransformImageNode
    private let stillAnimationNode: AnimatedStickerNode
    private var animationNode: AnimatedStickerNode?
    
    private var fetchStickerDisposable: Disposable?
    private var fetchFullAnimationDisposable: Disposable?
    
    private var validSize: CGSize?
    
    var isExtracted: Bool = false
    
    var didSetupStillAnimation: Bool = false
    
    init(context: AccountContext, theme: PresentationTheme, item: ReactionContextItem) {
        self.context = context
        self.item = item
        
        self.staticImageNode = TransformImageNode()
        self.stillAnimationNode = AnimatedStickerNode()
        
        super.init()
        
        //self.backgroundColor = UIColor(white: 0.0, alpha: 0.1)
        
        self.addSubnode(self.staticImageNode)
        
        self.addSubnode(self.stillAnimationNode)
        
        self.stillAnimationNode.started = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.staticImageNode.isHidden = true
        }
        
        self.fetchStickerDisposable = fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, reference: .standalone(resource: item.stillAnimation.resource)).start()
        self.fetchStickerDisposable = fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, reference: .standalone(resource: item.listAnimation.resource)).start()
        self.fetchFullAnimationDisposable = fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, reference: .standalone(resource: item.applicationAnimation.resource)).start()
    }
    
    deinit {
        self.fetchStickerDisposable?.dispose()
        self.fetchFullAnimationDisposable?.dispose()
    }
    
    func updateLayout(size: CGSize, isExpanded: Bool, transition: ContainedViewLayoutTransition) {
        let intrinsicSize = size
        
        let animationSize = self.item.listAnimation.dimensions?.cgSize ?? CGSize(width: 512.0, height: 512.0)
        var animationDisplaySize = animationSize.aspectFitted(intrinsicSize)
        
        let scalingFactor: CGFloat = 1.0
        let offsetFactor: CGFloat = 0.0
        
        animationDisplaySize.width = floor(animationDisplaySize.width * scalingFactor)
        animationDisplaySize.height = floor(animationDisplaySize.height * scalingFactor)
        
        var animationFrame = CGRect(origin: CGPoint(x: floor((intrinsicSize.width - animationDisplaySize.width) / 2.0), y: floor((intrinsicSize.height - animationDisplaySize.height) / 2.0)), size: animationDisplaySize)
        animationFrame.origin.y = floor(animationFrame.origin.y + animationFrame.height * offsetFactor)
        
        if isExpanded, self.animationNode == nil {
            let animationNode = AnimatedStickerNode()
            self.animationNode = animationNode
            self.addSubnode(animationNode)
            
            animationNode.started = { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.staticImageNode.isHidden = true
            }
            
            animationNode.setup(source: AnimatedStickerResourceSource(account: self.context.account, resource: self.item.listAnimation.resource), width: Int(animationDisplaySize.width * 2.0), height: Int(animationDisplaySize.height * 2.0), playbackMode: .once, mode: .direct(cachePathPrefix: self.context.account.postbox.mediaBox.shortLivedResourceCachePathPrefix(self.item.listAnimation.resource.id)))
            animationNode.frame = animationFrame
            animationNode.updateLayout(size: animationFrame.size)
            if transition.isAnimated, !self.staticImageNode.frame.isEmpty {
                transition.animateTransformScale(node: animationNode, from: self.staticImageNode.bounds.width / animationFrame.width)
                transition.animatePositionAdditive(node: animationNode, offset: CGPoint(x: self.staticImageNode.frame.midX - animationFrame.midX, y: self.staticImageNode.frame.midY - animationFrame.midY))
            }
            animationNode.visibility = true
            
            self.stillAnimationNode.alpha = 0.0
            self.stillAnimationNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, completion: { [weak self] _ in
                self?.stillAnimationNode.visibility = false
            })
            
            animationNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
        }
        
        if self.validSize != size {
            self.validSize = size
            
            self.staticImageNode.setSignal(chatMessageAnimatedSticker(postbox: self.context.account.postbox, file: item.stillAnimation, small: false, size: CGSize(width: animationDisplaySize.width * UIScreenScale, height: animationDisplaySize.height * UIScreenScale), fitzModifier: nil, fetched: false, onlyFullSize: false, thumbnail: false, synchronousLoad: false))
            let imageApply = self.staticImageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: animationDisplaySize, boundingSize: animationDisplaySize, intrinsicInsets: UIEdgeInsets()))
            imageApply()
            transition.updateFrame(node: self.staticImageNode, frame: animationFrame)
        }
        
        if !self.didSetupStillAnimation {
            self.didSetupStillAnimation = true
            
            self.stillAnimationNode.setup(source: AnimatedStickerResourceSource(account: self.context.account, resource: self.item.stillAnimation.resource), width: Int(animationDisplaySize.width * 2.0), height: Int(animationDisplaySize.height * 2.0), playbackMode: .loop, mode: .direct(cachePathPrefix: self.context.account.postbox.mediaBox.shortLivedResourceCachePathPrefix(self.item.stillAnimation.resource.id)))
            self.stillAnimationNode.position = animationFrame.center
            self.stillAnimationNode.bounds = CGRect(origin: CGPoint(), size: animationFrame.size)
            self.stillAnimationNode.updateLayout(size: animationFrame.size)
            self.stillAnimationNode.visibility = true
        } else {
            transition.updatePosition(node: self.stillAnimationNode, position: animationFrame.center)
            transition.updateTransformScale(node: self.stillAnimationNode, scale: animationFrame.size.width / self.stillAnimationNode.bounds.width)
        }
    }
    
    func didAppear() {
    }
}
