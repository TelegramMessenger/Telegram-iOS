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
import AnimationCache
import MultiAnimationRenderer
import ShimmerEffect
import GenerateStickerPlaceholderImage
import EntityKeyboard

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

protocol ReactionItemNode: ASDisplayNode {
    var isExtracted: Bool { get }
    
    var selectionTintView: UIView? { get }
    var selectionView: UIView? { get }
    
    var maskNode: ASDisplayNode? { get }
    
    func willAppear(animated: Bool)
    func appear(animated: Bool)
    func updateLayout(size: CGSize, isExpanded: Bool, largeExpanded: Bool, isPreviewing: Bool, transition: ContainedViewLayoutTransition)
}

private let lockedBackgroundImage: UIImage = generateFilledCircleImage(diameter: 16.0, color: .white)!.withRenderingMode(.alwaysTemplate)
private let lockedBadgeIcon: UIImage? = generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Media/PanelBadgeLock"), color: .white)

private final class StarsButtonEffectLayer: SimpleLayer {
    let gradientLayer = SimpleGradientLayer()
    let emitterLayer = CAEmitterLayer()
    
    override init() {
        super.init()
        
        self.addSublayer(self.gradientLayer)
        self.addSublayer(self.emitterLayer)
    }
    
    override init(layer: Any) {
        super.init(layer: layer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setup(theme: PresentationTheme) {
        let color = UIColor(rgb: 0xffbe27, alpha: theme.overallDarkAppearance ? 0.2 : 1.0)
        
        let emitter = CAEmitterCell()
        emitter.name = "emitter"
        emitter.contents = UIImage(bundleImageName: "Premium/Stars/Particle")?.cgImage
        emitter.birthRate = 25.0
        emitter.lifetime = 2.0
        emitter.velocity = 12.0
        emitter.velocityRange = 3
        emitter.scale = 0.1
        emitter.scaleRange = 0.08
        emitter.alphaRange = 0.1
        emitter.emissionRange = .pi * 2.0
        emitter.setValue(3.0, forKey: "mass")
        emitter.setValue(2.0, forKey: "massRange")
        
        let staticColors: [Any] = [
            color.withAlphaComponent(0.0).cgColor,
            color.cgColor,
            color.cgColor,
            color.withAlphaComponent(0.0).cgColor
        ]
        let staticColorBehavior = CAEmitterCell.createEmitterBehavior(type: "colorOverLife")
        staticColorBehavior.setValue(staticColors, forKey: "colors")
        emitter.setValue([staticColorBehavior], forKey: "emitterBehaviors")
        
        self.emitterLayer.emitterCells = [emitter]
        
        let gradientColor = UIColor(rgb: 0xffbe27, alpha: theme.overallDarkAppearance ? 0.2 : 1.0)
        
        self.gradientLayer.type = .radial
        self.gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        self.gradientLayer.endPoint = CGPoint(x: 0.0, y: 1.0)
        self.gradientLayer.colors = [
            gradientColor.withMultipliedAlpha(0.4).cgColor,
            gradientColor.withMultipliedAlpha(0.4).cgColor,
            gradientColor.withMultipliedAlpha(0.25).cgColor,
            gradientColor.withMultipliedAlpha(0.0).cgColor
        ] as [CGColor]
    }
    
    func update(theme: PresentationTheme, size: CGSize, transition: ContainedViewLayoutTransition) {
        if self.emitterLayer.emitterCells == nil {
            self.setup(theme: theme)
        }
        self.emitterLayer.emitterShape = .circle
        self.emitterLayer.emitterSize = CGSize(width: size.width * 0.7, height: size.height * 0.7)
        self.emitterLayer.emitterMode = .surface
        self.emitterLayer.frame = CGRect(origin: .zero, size: size)
        self.emitterLayer.emitterPosition = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
        
        transition.updateFrame(layer: self.gradientLayer, frame: CGRect(origin: CGPoint(), size: size).insetBy(dx: -6.0, dy: -6.0).offsetBy(dx: 0.0, dy: 2.0))
    }
}

public final class ReactionNode: ASDisplayNode, ReactionItemNode {
    let context: AccountContext
    let theme: PresentationTheme
    let item: ReactionItem
    let icon: EmojiPagerContentComponent.Item.Icon
    private let loopIdle: Bool
    private let isLocked: Bool
    private let hasAppearAnimation: Bool
    private let useDirectRendering: Bool
    
    let selectionTintView: UIView?
    let selectionView: UIView?
    
    private var starsEffectLayer: StarsButtonEffectLayer?
    
    private var animateInAnimationNode: AnimatedStickerNode?
    private var staticAnimationPlaceholderView: UIImageView?
    private let staticAnimationNode: AnimatedStickerNode
    private var stillAnimationNode: AnimatedStickerNode?
    private var customContentsNode: ASDisplayNode?
    private var animationNode: AnimatedStickerNode?
    
    private var lockBackgroundView: UIImageView?
    private var lockIconView: UIImageView?
    
    private var dismissedStillAnimationNodes: [AnimatedStickerNode] = []
    
    private var fetchStickerDisposable: Disposable?
    private var fetchFullAnimationDisposable: Disposable?
    
    private var validSize: CGSize?
    
    var isExtracted: Bool = false
    
    var didSetupStillAnimation: Bool = false
        
    var expandedAnimationDidBegin: (() -> Void)?
    
    var currentFrameIndex: Int {
        return self.staticAnimationNode.currentFrameIndex
    }
    
    var currentFrameImage: UIImage? {
        return self.staticAnimationNode.currentFrameImage
    }
    
    var isAnimationLoaded: Bool {
        return self.staticAnimationNode.currentFrameImage != nil
    }
    
    public init(context: AccountContext, theme: PresentationTheme, item: ReactionItem, icon: EmojiPagerContentComponent.Item.Icon, animationCache: AnimationCache, animationRenderer: MultiAnimationRenderer, loopIdle: Bool, isLocked: Bool, hasAppearAnimation: Bool = true, useDirectRendering: Bool = false) {
        self.context = context
        self.theme = theme
        self.item = item
        self.icon = icon
        self.loopIdle = loopIdle
        self.isLocked = isLocked
        self.hasAppearAnimation = hasAppearAnimation
        self.useDirectRendering = useDirectRendering
        
        self.selectionTintView = UIView()
        self.selectionTintView?.backgroundColor = UIColor(white: 1.0, alpha: 0.2)
        
        self.selectionView = UIView()
        self.selectionView?.backgroundColor = theme.chat.inputMediaPanel.panelContentControlVibrantSelectionColor
        
        self.staticAnimationNode = self.useDirectRendering ? DirectAnimatedStickerNode() : DefaultAnimatedStickerNodeImpl()
    
        if hasAppearAnimation {
            self.staticAnimationNode.isHidden = true
            self.animateInAnimationNode = self.useDirectRendering ? DirectAnimatedStickerNode() : DefaultAnimatedStickerNodeImpl()
        }
        
        super.init()
        
        if case .stars = item.reaction.rawValue {
            let starsEffectLayer = StarsButtonEffectLayer()
            self.starsEffectLayer = starsEffectLayer
            self.layer.addSublayer(starsEffectLayer)
        }
        
        if item.stillAnimation.isCustomTemplateEmoji {
            if let animationNode = self.staticAnimationNode as? DefaultAnimatedStickerNodeImpl {
                animationNode.dynamicColor = theme.chat.inputPanel.panelControlAccentColor
            }
        }
        
        if let animateInAnimationNode = self.animateInAnimationNode {
            self.addSubnode(animateInAnimationNode)
        }
        self.addSubnode(self.staticAnimationNode)
        
        self.animateInAnimationNode?.completed = { [weak self] _ in
            guard let strongSelf = self else {
                return
            }
            if strongSelf.animationNode == nil {
                strongSelf.staticAnimationNode.isHidden = false
                if strongSelf.loopIdle {
                    strongSelf.staticAnimationNode.playLoop()
                }
            }
            
            strongSelf.animateInAnimationNode?.removeFromSupernode()
            strongSelf.animateInAnimationNode = nil
        }
        
        self.fetchStickerDisposable = fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, userLocation: .other, userContentType: .sticker, reference: .standalone(resource: item.appearAnimation._parse().resource)).start()
        self.fetchStickerDisposable = fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, userLocation: .other, userContentType: .sticker, reference: .standalone(resource: item.stillAnimation._parse().resource)).start()
        self.fetchStickerDisposable = fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, userLocation: .other, userContentType: .sticker, reference: .standalone(resource: item.listAnimation._parse().resource)).start()
        if let applicationAnimation = item.applicationAnimation {
            self.fetchFullAnimationDisposable = fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, userLocation: .other, userContentType: .sticker, reference: .standalone(resource: applicationAnimation._parse().resource)).start()
        }
        
        if self.isLocked {
            let lockBackgroundView = UIImageView(image: lockedBackgroundImage)
            self.lockBackgroundView = lockBackgroundView
            self.view.addSubview(lockBackgroundView)
            
            let lockIconView = UIImageView(image: lockedBadgeIcon)
            self.lockIconView = lockIconView
            self.view.addSubview(lockIconView)
            
            if let staticAnimationNode = self.staticAnimationNode as? DefaultAnimatedStickerNodeImpl {
                staticAnimationNode.frameColorUpdated = { [weak lockBackgroundView] color in
                    guard let lockBackgroundView else {
                        return
                    }
                    lockBackgroundView.tintColor = color
                }
            }
        }
    }
    
    deinit {
        self.fetchStickerDisposable?.dispose()
        self.fetchFullAnimationDisposable?.dispose()
    }
    
    var maskNode: ASDisplayNode? {
        return nil
    }
    
    func willAppear(animated: Bool) {
        
    }
    
    func appear(animated: Bool) {
        if animated {
            if self.item.isCustom {
                self.layer.animateSpring(from: 0.01 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.4)
                
                if self.animationNode == nil {
                    self.staticAnimationNode.isHidden = false
                    if self.loopIdle {
                        self.staticAnimationNode.playLoop()
                    }
                }
            } else {
                self.animateInAnimationNode?.visibility = true
            }
            
            self.selectionView?.layer.animateAlpha(from: 0.0, to: self.selectionView?.alpha ?? 1.0, duration: 0.2)
            self.selectionView?.layer.animateSpring(from: 0.01 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.4)
            
            self.selectionTintView?.layer.animateAlpha(from: 0.0, to: self.selectionTintView?.alpha ?? 1.0, duration: 0.2)
            self.selectionTintView?.layer.animateSpring(from: 0.01 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.4)
        } else {
            self.animateInAnimationNode?.completed(true)
        }
    }
    
    public func setCustomContents(contents: Any) {
        if self.customContentsNode == nil {
            let customContentsNode = ASDisplayNode()
            self.customContentsNode = customContentsNode
            self.addSubnode(customContentsNode)
        }
        self.customContentsNode?.contents = contents
    }
    
    public func animateHideEffects() {
        if let starsEffectLayer = self.starsEffectLayer {
            starsEffectLayer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
        }
    }
    
    public func updateLayout(size: CGSize, isExpanded: Bool, largeExpanded: Bool, isPreviewing: Bool, transition: ContainedViewLayoutTransition) {
        let intrinsicSize = size
        
        if let starsEffectLayer = self.starsEffectLayer {
            transition.updateFrame(layer: starsEffectLayer, frame: CGRect(origin: CGPoint(), size: size))
            starsEffectLayer.update(theme: self.theme, size: size, transition: transition)
        }
        
        let animationSize = self.item.stillAnimation.dimensions?.cgSize ?? CGSize(width: 512.0, height: 512.0)
        var animationDisplaySize = animationSize.aspectFitted(intrinsicSize)
        
        let scalingFactor: CGFloat = 1.0
        let offsetFactor: CGFloat = 0.0
        
        animationDisplaySize.width = floor(animationDisplaySize.width * scalingFactor)
        animationDisplaySize.height = floor(animationDisplaySize.height * scalingFactor)
        
        var animationFrame = CGRect(origin: CGPoint(x: floor((intrinsicSize.width - animationDisplaySize.width) / 2.0), y: floor((intrinsicSize.height - animationDisplaySize.height) / 2.0)), size: animationDisplaySize)
        animationFrame.origin.y = floor(animationFrame.origin.y + animationFrame.height * offsetFactor)
        
        let expandedAnimationFrame = animationFrame
        
        if isExpanded && !self.hasAppearAnimation {
            self.staticAnimationNode.play(firstFrame: false, fromIndex: 0)
        } else if isExpanded, self.animationNode == nil {
            let animationNode: AnimatedStickerNode = self.useDirectRendering ? DirectAnimatedStickerNode() : DefaultAnimatedStickerNodeImpl()
            animationNode.automaticallyLoadFirstFrame = true
            self.animationNode = animationNode
            self.addSubnode(animationNode)
            
            var didReportStarted = false
            animationNode.started = { [weak self] in
                if !didReportStarted {
                    didReportStarted = true
                    self?.expandedAnimationDidBegin?()
                }
            }
            
            if largeExpanded {
                let source = AnimatedStickerResourceSource(account: self.context.account, resource: self.item.largeListAnimation._parse().resource, isVideo: self.item.largeListAnimation.isVideoSticker || self.item.largeListAnimation.isVideoEmoji || self.item.largeListAnimation.isStaticSticker || self.item.largeListAnimation.isStaticEmoji)
                
                animationNode.setup(source: source, width: Int(expandedAnimationFrame.width * 2.0), height: Int(expandedAnimationFrame.height * 2.0), playbackMode: .once, mode: .direct(cachePathPrefix: self.context.account.postbox.mediaBox.shortLivedResourceCachePathPrefix(self.item.largeListAnimation._parse().resource.id)))
            } else {
                let source = AnimatedStickerResourceSource(account: self.context.account, resource: self.item.listAnimation._parse().resource, isVideo: self.item.listAnimation.isVideoSticker || self.item.listAnimation.isVideoEmoji || self.item.listAnimation.isVideoSticker || self.item.listAnimation.isStaticSticker || self.item.listAnimation.isStaticEmoji)
                animationNode.setup(source: source, width: Int(expandedAnimationFrame.width * 2.0), height: Int(expandedAnimationFrame.height * 2.0), playbackMode: .once, mode: .direct(cachePathPrefix: self.context.account.postbox.mediaBox.shortLivedResourceCachePathPrefix(self.item.listAnimation._parse().resource.id)))
            }
            animationNode.frame = expandedAnimationFrame
            animationNode.updateLayout(size: expandedAnimationFrame.size)
            
            if transition.isAnimated {
                if let stillAnimationNode = self.stillAnimationNode, !stillAnimationNode.frame.isEmpty {
                    stillAnimationNode.alpha = 0.0
                    stillAnimationNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, completion: { [weak self] _ in
                        guard let strongSelf = self, let stillAnimationNode = strongSelf.stillAnimationNode else {
                            return
                        }
                        strongSelf.stillAnimationNode = nil
                        stillAnimationNode.removeFromSupernode()
                    })
                }
                if let animateInAnimationNode = self.animateInAnimationNode {
                    animateInAnimationNode.alpha = 0.0
                    animateInAnimationNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, completion: { [weak self] _ in
                        guard let strongSelf = self, let animateInAnimationNode = strongSelf.animateInAnimationNode else {
                            return
                        }
                        strongSelf.animateInAnimationNode = nil
                        animateInAnimationNode.removeFromSupernode()
                    })
                }
                
                var referenceNode: ASDisplayNode?
                if let animateInAnimationNode = self.animateInAnimationNode {
                    referenceNode = animateInAnimationNode
                } else if !self.staticAnimationNode.isHidden {
                    referenceNode = self.staticAnimationNode
                }
                
                if let referenceNode = referenceNode {
                    transition.animateTransformScale(node: animationNode, from: referenceNode.bounds.width / animationFrame.width)
                    transition.animatePositionAdditive(node: animationNode, offset: CGPoint(x: referenceNode.frame.midX - animationFrame.midX, y: referenceNode.frame.midY - animationFrame.midY))
                }
                
                if !self.staticAnimationNode.isHidden {
                    transition.animateTransformScale(node: self.staticAnimationNode, from: self.staticAnimationNode.bounds.width / animationFrame.width)
                    transition.animatePositionAdditive(node: self.staticAnimationNode, offset: CGPoint(x: self.staticAnimationNode.frame.midX - animationFrame.midX, y: self.staticAnimationNode.frame.midY - animationFrame.midY))
                    
                    self.staticAnimationNode.alpha = 0.0
                    self.staticAnimationNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
                }
                
                if let customContentsNode = self.customContentsNode, !customContentsNode.isHidden {
                    transition.animateTransformScale(node: customContentsNode, from: customContentsNode.bounds.width / animationFrame.width)
                    transition.animatePositionAdditive(node: customContentsNode, offset: CGPoint(x: customContentsNode.frame.midX - animationFrame.midX, y: customContentsNode.frame.midY - animationFrame.midY))
                    
                    if self.item.listAnimation.isVideoEmoji || self.item.listAnimation.isVideoSticker || self.item.listAnimation.isAnimatedSticker || self.item.listAnimation.isStaticSticker || self.item.listAnimation.isStaticEmoji {
                        customContentsNode.alpha = 0.0
                        customContentsNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
                    }
                }
                
                animationNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
                
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.17, execute: {
                    animationNode.visibility = true
                })
            } else {
                if let stillAnimationNode = self.stillAnimationNode {
                    self.stillAnimationNode = nil
                    stillAnimationNode.removeFromSupernode()
                }
                self.staticAnimationNode.isHidden = true
                
                animationNode.visibility = true
            }
        }
        
        if self.validSize != size {
            self.validSize = size
        }
        
        if self.animationNode == nil {
            if isPreviewing {
                if self.stillAnimationNode == nil {
                    let stillAnimationNode: AnimatedStickerNode = self.useDirectRendering ? DirectAnimatedStickerNode() : DefaultAnimatedStickerNodeImpl()
                    self.stillAnimationNode = stillAnimationNode
                    self.addSubnode(stillAnimationNode)
                    
                    stillAnimationNode.setup(source: AnimatedStickerResourceSource(account: self.context.account, resource: self.item.stillAnimation._parse().resource, isVideo: self.item.stillAnimation.isVideoEmoji || self.item.stillAnimation.isVideoSticker || self.item.stillAnimation.isStaticSticker || self.item.stillAnimation.isStaticEmoji), width: Int(animationDisplaySize.width * 2.0), height: Int(animationDisplaySize.height * 2.0), playbackMode: self.loopIdle ? .loop : .still(.start), mode: .direct(cachePathPrefix: self.context.account.postbox.mediaBox.shortLivedResourceCachePathPrefix(self.item.stillAnimation._parse().resource.id)))
                    stillAnimationNode.position = animationFrame.center
                    stillAnimationNode.bounds = CGRect(origin: CGPoint(), size: animationFrame.size)
                    stillAnimationNode.updateLayout(size: animationFrame.size)
                    stillAnimationNode.started = { [weak self, weak stillAnimationNode] in
                        guard let strongSelf = self, let stillAnimationNode = stillAnimationNode, strongSelf.stillAnimationNode === stillAnimationNode, strongSelf.animationNode == nil else {
                            return
                        }
                        strongSelf.staticAnimationNode.alpha = 0.0
                        
                        if let animateInAnimationNode = strongSelf.animateInAnimationNode, !animateInAnimationNode.alpha.isZero {
                            animateInAnimationNode.alpha = 0.0
                            animateInAnimationNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.1)
                            
                            strongSelf.staticAnimationNode.isHidden = false
                            if strongSelf.loopIdle {
                                strongSelf.staticAnimationNode.playLoop()
                            }
                        }
                    }
                    stillAnimationNode.visibility = true
                    
                    transition.animateTransformScale(node: stillAnimationNode, from: self.staticAnimationNode.bounds.width / animationFrame.width)
                    transition.animatePositionAdditive(node: stillAnimationNode, offset: CGPoint(x: self.staticAnimationNode.frame.midX - animationFrame.midX, y: self.staticAnimationNode.frame.midY - animationFrame.midY))
                } else {
                    if let stillAnimationNode = self.stillAnimationNode {
                        transition.updatePosition(node: stillAnimationNode, position: animationFrame.center, beginWithCurrentState: true)
                        transition.updateTransformScale(node: stillAnimationNode, scale: animationFrame.size.width / stillAnimationNode.bounds.width, beginWithCurrentState: true)
                    }
                }
            } else if let stillAnimationNode = self.stillAnimationNode {
                self.stillAnimationNode = nil
                self.dismissedStillAnimationNodes.append(stillAnimationNode)
                
                transition.updatePosition(node: stillAnimationNode, position: animationFrame.center, beginWithCurrentState: true)
                transition.updateTransformScale(node: stillAnimationNode, scale: animationFrame.size.width / stillAnimationNode.bounds.width, beginWithCurrentState: true)
                
                stillAnimationNode.alpha = 0.0
                stillAnimationNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.1, completion: { [weak self, weak stillAnimationNode] _ in
                    guard let strongSelf = self, let stillAnimationNode = stillAnimationNode else {
                        return
                    }
                    stillAnimationNode.removeFromSupernode()
                    strongSelf.dismissedStillAnimationNodes.removeAll(where: { $0 === stillAnimationNode })
                })
                
                let previousAlpha = CGFloat(self.staticAnimationNode.layer.presentation()?.opacity ?? self.staticAnimationNode.layer.opacity)
                self.staticAnimationNode.alpha = 1.0
                self.staticAnimationNode.layer.animateAlpha(from: previousAlpha, to: 1.0, duration: 0.08)
            }
        }
        
        if !self.didSetupStillAnimation && self.customContentsNode == nil {
            if self.animationNode == nil {
                self.didSetupStillAnimation = true
                
                let staticFile: TelegramMediaFile
                if !self.hasAppearAnimation {
                    staticFile = self.item.largeListAnimation._parse()
                } else {
                    staticFile = self.item.stillAnimation._parse()
                }
                
                if self.staticAnimationPlaceholderView == nil, let immediateThumbnailData = staticFile.immediateThumbnailData {
                    let staticAnimationPlaceholderView = UIImageView()
                    self.view.addSubview(staticAnimationPlaceholderView)
                    self.staticAnimationPlaceholderView = staticAnimationPlaceholderView
                    
                    if let image = generateStickerPlaceholderImage(data: immediateThumbnailData, size: animationDisplaySize, scale: min(2.0, UIScreenScale), imageSize: staticFile.dimensions?.cgSize ?? CGSize(width: 512.0, height: 512.0), backgroundColor: nil, foregroundColor: self.theme.chat.inputPanel.primaryTextColor.withMultipliedAlpha(0.1)) {
                        staticAnimationPlaceholderView.image = image
                    }
                }
                
                self.staticAnimationNode.started = { [weak self] in
                    guard let strongSelf = self else {
                        return
                    }
                    if let staticAnimationPlaceholderView = strongSelf.staticAnimationPlaceholderView {
                        strongSelf.staticAnimationPlaceholderView = nil
                        staticAnimationPlaceholderView.removeFromSuperview()
                    }
                }
                
                self.staticAnimationNode.automaticallyLoadFirstFrame = true
                if !self.hasAppearAnimation {
                    self.staticAnimationNode.setup(source: AnimatedStickerResourceSource(account: self.context.account, resource: self.item.largeListAnimation._parse().resource, isVideo: self.item.largeListAnimation.isVideoEmoji || self.item.largeListAnimation.isVideoSticker || self.item.largeListAnimation.isStaticSticker || self.item.largeListAnimation.isStaticEmoji), width: Int(expandedAnimationFrame.width * 2.0), height: Int(expandedAnimationFrame.height * 2.0), playbackMode: .still(.start), mode: .direct(cachePathPrefix: self.context.account.postbox.mediaBox.shortLivedResourceCachePathPrefix(self.item.largeListAnimation._parse().resource.id)))
                } else {
                    self.staticAnimationNode.setup(source: AnimatedStickerResourceSource(account: self.context.account, resource: self.item.stillAnimation._parse().resource, isVideo: self.item.stillAnimation.isVideoEmoji || self.item.stillAnimation.isVideoSticker || self.item.stillAnimation.isStaticSticker || self.item.stillAnimation.isStaticEmoji), width: Int(animationDisplaySize.width * 2.0), height: Int(animationDisplaySize.height * 2.0), playbackMode: .still(.start), mode: .direct(cachePathPrefix: self.context.account.postbox.mediaBox.shortLivedResourceCachePathPrefix(self.item.stillAnimation._parse().resource.id)))
                }
                self.staticAnimationNode.position = animationFrame.center
                self.staticAnimationNode.bounds = CGRect(origin: CGPoint(), size: animationFrame.size)
                self.staticAnimationNode.updateLayout(size: animationFrame.size)
                self.staticAnimationNode.visibility = true
                
                if let staticAnimationPlaceholderView = self.staticAnimationPlaceholderView {
                    staticAnimationPlaceholderView.center = animationFrame.center
                    staticAnimationPlaceholderView.bounds = CGRect(origin: CGPoint(), size: animationFrame.size)
                }
                
                if let animateInAnimationNode = self.animateInAnimationNode {
                    animateInAnimationNode.setup(source: AnimatedStickerResourceSource(account: self.context.account, resource: self.item.appearAnimation._parse().resource, isVideo: self.item.appearAnimation.isVideoEmoji || self.item.appearAnimation.isVideoSticker || self.item.appearAnimation.isStaticSticker || self.item.appearAnimation.isStaticEmoji), width: Int(animationDisplaySize.width * 2.0), height: Int(animationDisplaySize.height * 2.0), playbackMode: .once, mode: .direct(cachePathPrefix: self.context.account.postbox.mediaBox.shortLivedResourceCachePathPrefix(self.item.appearAnimation._parse().resource.id)))
                    animateInAnimationNode.position = animationFrame.center
                    animateInAnimationNode.bounds = CGRect(origin: CGPoint(), size: animationFrame.size)
                    animateInAnimationNode.updateLayout(size: animationFrame.size)
                }
            }
        } else {
            transition.updatePosition(node: self.staticAnimationNode, position: animationFrame.center, beginWithCurrentState: true)
            transition.updateTransformScale(node: self.staticAnimationNode, scale: animationFrame.size.width / self.staticAnimationNode.bounds.width, beginWithCurrentState: true)
            
            if let staticAnimationPlaceholderView = self.staticAnimationPlaceholderView {
                transition.updatePosition(layer: staticAnimationPlaceholderView.layer, position: animationFrame.center)
                transition.updateTransformScale(layer: staticAnimationPlaceholderView.layer, scale: animationFrame.size.width / self.staticAnimationNode.bounds.width)
            }
            
            if let animateInAnimationNode = self.animateInAnimationNode {
                transition.updatePosition(node: animateInAnimationNode, position: animationFrame.center, beginWithCurrentState: true)
                transition.updateTransformScale(node: animateInAnimationNode, scale: animationFrame.size.width / animateInAnimationNode.bounds.width, beginWithCurrentState: true)
            }
        }
        
        if let customContentsNode = self.customContentsNode {
            transition.updateFrame(node: customContentsNode, frame: animationFrame)
        }
        
        if let lockBackgroundView = self.lockBackgroundView, let lockIconView = self.lockIconView, let iconImage = lockIconView.image {
            let lockSize: CGFloat = 16.0
            let iconBackgroundFrame = CGRect(origin: CGPoint(x: animationFrame.maxX - lockSize, y: animationFrame.maxY - lockSize), size: CGSize(width: lockSize, height: lockSize))
            transition.updateFrame(view: lockBackgroundView, frame: iconBackgroundFrame)
            
            let iconFactor: CGFloat = 1.0
            let iconImageSize = CGSize(width: floor(iconImage.size.width * iconFactor), height: floor(iconImage.size.height * iconFactor))
            
            transition.updateFrame(view: lockIconView, frame: CGRect(origin: CGPoint(x: iconBackgroundFrame.minX + floorToScreenPixels((iconBackgroundFrame.width - iconImageSize.width) * 0.5), y: iconBackgroundFrame.minY + floorToScreenPixels((iconBackgroundFrame.height - iconImageSize.height) * 0.5)), size: iconImageSize))
        }
    }
}

final class PremiumReactionsNode: ASDisplayNode, ReactionItemNode {
    var isExtracted: Bool = false
    
    private var backgroundView: UIVisualEffectView?
    private let backgroundMaskNode: ASImageNode
    private let backgroundOverlayNode: ASImageNode
    private let imageNode: ASImageNode
    private var starsNode: PremiumStarsNode?
    
    private let maskContainerNode: ASDisplayNode
    private let maskImageNode: ASImageNode
    
    let selectionView: UIView? = nil
    let selectionTintView: UIView? = nil
    
    init(theme: PresentationTheme) {
        self.backgroundMaskNode = ASImageNode()
        self.backgroundMaskNode.contentMode = .center
        self.backgroundMaskNode.displaysAsynchronously = false
        self.backgroundMaskNode.isUserInteractionEnabled = false
        self.backgroundMaskNode.image = UIImage(bundleImageName: "Premium/ReactionsBackground")
        
        self.backgroundOverlayNode = ASImageNode()
        self.backgroundOverlayNode.alpha = 0.1
        self.backgroundOverlayNode.contentMode = .center
        self.backgroundOverlayNode.displaysAsynchronously = false
        self.backgroundOverlayNode.isUserInteractionEnabled = false
        self.backgroundOverlayNode.image = generateTintedImage(image: UIImage(bundleImageName: "Premium/ReactionsBackground"), color: theme.overallDarkAppearance ? .white : .black)
          
        self.imageNode = ASImageNode()
        self.imageNode.contentMode = .center
        self.imageNode.displaysAsynchronously = false
        self.imageNode.isUserInteractionEnabled = false
        self.imageNode.image = UIImage(bundleImageName: "Premium/ReactionsForeground")
        
        self.maskContainerNode = ASDisplayNode()
        
        self.maskImageNode = ASImageNode()
        if let backgroundImage = UIImage(bundleImageName: "Premium/ReactionsBackground") {
            self.maskImageNode.image = generateImage(CGSize(width: 40.0 * 4.0, height: 52.0 * 4.0), contextGenerator: { size, context in
                context.setFillColor(UIColor.black.cgColor)
                context.fill(CGRect(origin: .zero, size: size))
                
                if let cgImage = backgroundImage.cgImage {
                    let maskFrame = CGRect(origin: .zero, size: size).insetBy(dx: 4.0 + 40.0 * 2.0 - 16.0, dy: 10.0 + 52.0 * 2.0 - 16.0)
                    context.clip(to: maskFrame, mask: cgImage)
                }
                context.setBlendMode(.clear)
                context.fill(CGRect(origin: .zero, size: size))
            })
        }
        self.maskImageNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((40.0 - 40.0 * 4.0) / 2.0), y: floorToScreenPixels((52.0 - 52.0 * 4.0) / 2.0)), size: CGSize(width: 40.0 * 4.0, height: 52.0 * 4.0))
        self.maskContainerNode.addSubnode(self.maskImageNode)
        
        super.init()
        
        self.addSubnode(self.backgroundOverlayNode)
        self.addSubnode(self.imageNode)
    }
    
    override func didLoad() {
        super.didLoad()
        
        let blurEffect: UIBlurEffect
        if #available(iOS 13.0, *) {
            blurEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        } else {
            blurEffect = UIBlurEffect(style: .light)
        }
        let backgroundView = UIVisualEffectView(effect: blurEffect)
        backgroundView.mask = self.backgroundMaskNode.view
        self.view.insertSubview(backgroundView, at: 0)
        self.backgroundView = backgroundView
        
        let starsNode = PremiumStarsNode()
        starsNode.frame = CGRect(origin: .zero, size: CGSize(width: 32.0, height: 32.0))
        self.backgroundView?.contentView.addSubview(starsNode.view)
        self.starsNode = starsNode
    }
    
    func willAppear(animated: Bool) {
        
    }
    
    func appear(animated: Bool) {
        if animated {
            let delay: Double = 0.1
            let duration: Double = 0.85
            let damping: CGFloat = 60.0
            
            let initialScale: CGFloat = 0.25
            self.maskImageNode.layer.animateSpring(from: initialScale as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: duration, delay: delay, damping: damping)
            self.backgroundView?.layer.animateSpring(from: initialScale as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: duration, delay: delay, damping: damping)
            self.backgroundOverlayNode.layer.animateSpring(from: initialScale as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: duration, delay: delay, damping: damping)
            self.imageNode.layer.animateSpring(from: initialScale as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: duration, delay: delay, damping: damping)
            
            Queue.mainQueue().after(0.25, {
                let shimmerNode = ASImageNode()
                shimmerNode.displaysAsynchronously = false
                shimmerNode.image = generateGradientImage(size: CGSize(width: 32.0, height: 32.0), colors: [UIColor(rgb: 0xffffff, alpha: 0.0), UIColor(rgb: 0xffffff, alpha: 0.24), UIColor(rgb: 0xffffff, alpha: 0.0)], locations: [0.0, 0.5, 1.0], direction: .horizontal)
                shimmerNode.frame = CGRect(origin: .zero, size: CGSize(width: 32.0, height: 32.0))
                self.backgroundView?.contentView.addSubview(shimmerNode.view)
                
                shimmerNode.layer.animatePosition(from: CGPoint(x: -60.0, y: 0.0), to: CGPoint(x: 60.0, y: 0.0), duration: 0.75, removeOnCompletion: false, additive: true, completion: { [weak shimmerNode] _ in
                    shimmerNode?.view.removeFromSuperview()
                })
            })
        }
    }
    
    func updateLayout(size: CGSize, isExpanded: Bool, largeExpanded: Bool, isPreviewing: Bool, transition: ContainedViewLayoutTransition) {
        let bounds = CGRect(origin: CGPoint(), size: size)
        self.backgroundView?.frame = bounds
        self.backgroundMaskNode.frame = bounds
        self.backgroundOverlayNode.frame = bounds
        self.imageNode.frame = bounds
    }
    
    var maskNode: ASDisplayNode? {
        return self.maskContainerNode
    }
}


final class EmojiItemNode: ASDisplayNode, ReactionItemNode {
    var isExtracted: Bool = false
    let emoji: String
    
    let selectionTintView: UIView?
    let selectionView: UIView?
    
    private let imageNode: ASImageNode

    init(theme: PresentationTheme, emoji: String) {
        self.emoji = emoji
        
        self.selectionTintView = UIView()
        self.selectionTintView?.backgroundColor = UIColor(white: 1.0, alpha: 0.2)
        
        self.selectionView = UIView()
        self.selectionView?.backgroundColor = theme.chat.inputMediaPanel.panelContentControlVibrantSelectionColor
        
        self.imageNode = ASImageNode()
        self.imageNode.contentMode = .scaleAspectFit
        self.imageNode.displaysAsynchronously = false
        self.imageNode.isUserInteractionEnabled = false
        
        super.init()
        
        self.addSubnode(self.imageNode)
    }
    
    func willAppear(animated: Bool) {
        if animated {
            let initialScale: CGFloat = 0.25
            self.imageNode.transform = CATransform3DMakeScale(initialScale, initialScale, 1.0)
        }
    }
    
    func appear(animated: Bool) {
        if animated {
            let delay: Double = 0.1
            let duration: Double = 0.85
            let damping: CGFloat = 60.0
            
            let initialScale: CGFloat = 0.25
            self.imageNode.transform = CATransform3DIdentity
            self.imageNode.layer.animateSpring(from: initialScale as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: duration, delay: delay, damping: damping)
            
            self.selectionView?.layer.animateAlpha(from: 0.0, to: self.selectionView?.alpha ?? 1.0, duration: 0.2)
            self.selectionView?.layer.animateSpring(from: 0.01 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.4)
            
            self.selectionTintView?.layer.animateAlpha(from: 0.0, to: self.selectionTintView?.alpha ?? 1.0, duration: 0.2)
            self.selectionTintView?.layer.animateSpring(from: 0.01 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.4)
        }
    }
    
    func updateLayout(size: CGSize, isExpanded: Bool, largeExpanded: Bool, isPreviewing: Bool, transition: ContainedViewLayoutTransition) {
        let bounds = CGRect(origin: CGPoint(), size: size)
        
        let pointSize = CGSize(width: 36.0, height: 36.0)
        if self.imageNode.image == nil {
            let image = generateImage(pointSize, opaque: false, scale: min(UIScreenScale, 3.0), rotatedContext: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                
                let preScaleFactor: CGFloat = 1.0
                let scaledSize = CGSize(width: floor(size.width * preScaleFactor), height: floor(size.height * preScaleFactor))
                let scaleFactor = scaledSize.width / size.width
                
                context.scaleBy(x: 1.0 / scaleFactor, y: 1.0 / scaleFactor)
                
                let string = NSAttributedString(string: self.emoji, font: Font.regular(floor(32.0 * scaleFactor)), textColor: .black)
                let boundingRect = string.boundingRect(with: scaledSize, options: .usesLineFragmentOrigin, context: nil)
                UIGraphicsPushContext(context)
                string.draw(at: CGPoint(x: floorToScreenPixels((scaledSize.width - boundingRect.width) / 2.0 + boundingRect.minX), y: floorToScreenPixels((scaledSize.height - boundingRect.height) / 2.0 + boundingRect.minY)))
                UIGraphicsPopContext()
            })
            self.imageNode.image = image
        }
        transition.updateFrameAsPositionAndBounds(node: self.imageNode, frame: bounds)
    }
    
    var maskNode: ASDisplayNode? {
        return nil
    }
}
