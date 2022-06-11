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

protocol ReactionItemNode: ASDisplayNode {
    var isExtracted: Bool { get }
    
    var maskNode: ASDisplayNode? { get }
    
    func appear(animated: Bool)
    func updateLayout(size: CGSize, isExpanded: Bool, largeExpanded: Bool, isPreviewing: Bool, transition: ContainedViewLayoutTransition)
}

public final class ReactionNode: ASDisplayNode, ReactionItemNode {
    let context: AccountContext
    let item: ReactionItem
    private let hasAppearAnimation: Bool
    private let useDirectRendering: Bool
    
    private var animateInAnimationNode: AnimatedStickerNode?
    private let staticAnimationNode: AnimatedStickerNode
    private var stillAnimationNode: AnimatedStickerNode?
    private var animationNode: AnimatedStickerNode?
    
    private var dismissedStillAnimationNodes: [AnimatedStickerNode] = []
    
    private var fetchStickerDisposable: Disposable?
    private var fetchFullAnimationDisposable: Disposable?
    
    private var validSize: CGSize?
    
    var isExtracted: Bool = false
    
    var didSetupStillAnimation: Bool = false
        
    var expandedAnimationDidBegin: (() -> Void)?
    
    public init(context: AccountContext, theme: PresentationTheme, item: ReactionItem, hasAppearAnimation: Bool = true, useDirectRendering: Bool = false) {
        self.context = context
        self.item = item
        self.hasAppearAnimation = hasAppearAnimation
        self.useDirectRendering = useDirectRendering
        
        self.staticAnimationNode = self.useDirectRendering ? DirectAnimatedStickerNode() : DefaultAnimatedStickerNodeImpl()
    
        if hasAppearAnimation {
            self.staticAnimationNode.isHidden = true
            self.animateInAnimationNode = self.useDirectRendering ? DirectAnimatedStickerNode() : DefaultAnimatedStickerNodeImpl()
        }
        
        super.init()
        
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
            }
            
            strongSelf.animateInAnimationNode?.removeFromSupernode()
            strongSelf.animateInAnimationNode = nil
        }
        
        self.fetchStickerDisposable = fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, reference: .standalone(resource: item.appearAnimation.resource)).start()
        self.fetchStickerDisposable = fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, reference: .standalone(resource: item.stillAnimation.resource)).start()
        self.fetchStickerDisposable = fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, reference: .standalone(resource: item.listAnimation.resource)).start()
        self.fetchFullAnimationDisposable = fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, reference: .standalone(resource: item.applicationAnimation.resource)).start()
    }
    
    deinit {
        self.fetchStickerDisposable?.dispose()
        self.fetchFullAnimationDisposable?.dispose()
    }
    
    var maskNode: ASDisplayNode? {
        return nil
    }
    
    func appear(animated: Bool) {
        if animated {
            self.animateInAnimationNode?.visibility = true
        } else {
            self.animateInAnimationNode?.completed(true)
        }
    }
    
    public var mainAnimationCompletion: (() -> Void)?
    
    public func updateLayout(size: CGSize, isExpanded: Bool, largeExpanded: Bool, isPreviewing: Bool, transition: ContainedViewLayoutTransition) {
        let intrinsicSize = size
        
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
            self.staticAnimationNode.completed = { [weak self] _ in
                self?.mainAnimationCompletion?()
            }
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
            animationNode.completed = { [weak self] _ in
                self?.mainAnimationCompletion?()
            }
            
            if largeExpanded {
                animationNode.setup(source: AnimatedStickerResourceSource(account: self.context.account, resource: self.item.largeListAnimation.resource), width: Int(expandedAnimationFrame.width * 2.0), height: Int(expandedAnimationFrame.height * 2.0), playbackMode: .once, mode: .direct(cachePathPrefix: self.context.account.postbox.mediaBox.shortLivedResourceCachePathPrefix(self.item.largeListAnimation.resource.id)))
            } else {
                animationNode.setup(source: AnimatedStickerResourceSource(account: self.context.account, resource: self.item.listAnimation.resource), width: Int(expandedAnimationFrame.width * 2.0), height: Int(expandedAnimationFrame.height * 2.0), playbackMode: .once, mode: .direct(cachePathPrefix: self.context.account.postbox.mediaBox.shortLivedResourceCachePathPrefix(self.item.listAnimation.resource.id)))
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
                    
                    stillAnimationNode.setup(source: AnimatedStickerResourceSource(account: self.context.account, resource: self.item.stillAnimation.resource), width: Int(animationDisplaySize.width * 2.0), height: Int(animationDisplaySize.height * 2.0), playbackMode: .loop, mode: .direct(cachePathPrefix: self.context.account.postbox.mediaBox.shortLivedResourceCachePathPrefix(self.item.stillAnimation.resource.id)))
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
        
        if !self.didSetupStillAnimation {
            if self.animationNode == nil {
                self.didSetupStillAnimation = true
                
                if !self.hasAppearAnimation {
                    self.staticAnimationNode.setup(source: AnimatedStickerResourceSource(account: self.context.account, resource: self.item.largeListAnimation.resource), width: Int(expandedAnimationFrame.width * 2.0), height: Int(expandedAnimationFrame.height * 2.0), playbackMode: .still(.start), mode: .direct(cachePathPrefix: self.context.account.postbox.mediaBox.shortLivedResourceCachePathPrefix(self.item.largeListAnimation.resource.id)))
                } else {
                    self.staticAnimationNode.setup(source: AnimatedStickerResourceSource(account: self.context.account, resource: self.item.stillAnimation.resource), width: Int(animationDisplaySize.width * 2.0), height: Int(animationDisplaySize.height * 2.0), playbackMode: .still(.start), mode: .direct(cachePathPrefix: self.context.account.postbox.mediaBox.shortLivedResourceCachePathPrefix(self.item.stillAnimation.resource.id)))
                }
                self.staticAnimationNode.position = animationFrame.center
                self.staticAnimationNode.bounds = CGRect(origin: CGPoint(), size: animationFrame.size)
                self.staticAnimationNode.updateLayout(size: animationFrame.size)
                self.staticAnimationNode.visibility = true
                
                if let animateInAnimationNode = self.animateInAnimationNode {
                    animateInAnimationNode.setup(source: AnimatedStickerResourceSource(account: self.context.account, resource: self.item.appearAnimation.resource), width: Int(animationDisplaySize.width * 2.0), height: Int(animationDisplaySize.height * 2.0), playbackMode: .once, mode: .direct(cachePathPrefix: self.context.account.postbox.mediaBox.shortLivedResourceCachePathPrefix(self.item.appearAnimation.resource.id)))
                    animateInAnimationNode.position = animationFrame.center
                    animateInAnimationNode.bounds = CGRect(origin: CGPoint(), size: animationFrame.size)
                    animateInAnimationNode.updateLayout(size: animationFrame.size)
                }
            }
        } else {
            transition.updatePosition(node: self.staticAnimationNode, position: animationFrame.center, beginWithCurrentState: true)
            transition.updateTransformScale(node: self.staticAnimationNode, scale: animationFrame.size.width / self.staticAnimationNode.bounds.width, beginWithCurrentState: true)
            
            if let animateInAnimationNode = self.animateInAnimationNode {
                transition.updatePosition(node: animateInAnimationNode, position: animationFrame.center, beginWithCurrentState: true)
                transition.updateTransformScale(node: animateInAnimationNode, scale: animationFrame.size.width / animateInAnimationNode.bounds.width, beginWithCurrentState: true)
            }
        }
    }
}

private let starsCount = 7
private final class StarsNode: ASDisplayNode {
    private let starNodes: [ASImageNode]
    private var timer: SwiftSignalKit.Timer?
    
    override init() {
        let image = UIImage(bundleImageName: "Premium/ReactionsStar")
        var starNodes: [ASImageNode] = []
        for _ in 0 ..< starsCount {
            let node = ASImageNode()
            node.alpha = 0.0
            node.image = image
            node.displaysAsynchronously = false
            starNodes.append(node)
        }
        self.starNodes = starNodes
        
        super.init()
        
        for node in starNodes {
            self.addSubnode(node)
        }
        
        self.setup(firstTime: true)
        
        self.timer = SwiftSignalKit.Timer(timeout: 0.5, repeat: true, completion: { [weak self] in
            self?.setup()
        }, queue: Queue.mainQueue())
        self.timer?.start()
    }
    
    deinit {
        self.timer?.invalidate()
    }
    
    func setup(firstTime: Bool = false) {
        let size = CGSize(width: 32.0, height: 32.0)
        let starSize = CGSize(width: 6.0, height: 8.0)
        
        for node in self.starNodes {
            if node.layer.animation(forKey: "transform.scale") == nil && node.layer.animation(forKey: "opacity") == nil {
                let x = CGFloat.random(in: 0 ..< size.width)
                let y = CGFloat.random(in: 0 ..< size.width)
                
                let randomTargetScale = CGFloat.random(in: 0.8 ..< 1.0)
                node.bounds = CGRect(origin: .zero, size: starSize)
                node.position = CGPoint(x: x, y: y)
                
                node.alpha = 1.0
                
                let duration =  CGFloat.random(in: 0.4 ..< 0.65)
                let delay = firstTime ? CGFloat.random(in: 0.0 ..< 0.25) : 0.0
                node.layer.animateScale(from: 0.001, to: randomTargetScale, duration: duration, delay: delay, removeOnCompletion: false, completion: { [weak self, weak node] _ in
                    let duration =  CGFloat.random(in: 0.3 ..< 0.35)
                    node?.alpha = 0.0
                    node?.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration, removeOnCompletion: false, completion: { [weak self, weak node] _ in
                        node?.layer.removeAllAnimations()
                        self?.setup()
                    })
                })
            }
        }
    }
}

final class PremiumReactionsNode: ASDisplayNode, ReactionItemNode {
    var isExtracted: Bool = false
    
    private var backgroundView: UIVisualEffectView?
    private let backgroundMaskNode: ASImageNode
    private let backgroundOverlayNode: ASImageNode
    private let imageNode: ASImageNode
    private var starsNode: StarsNode?
    
    private let maskContainerNode: ASDisplayNode
    private let maskImageNode: ASImageNode
    
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
        
        let starsNode = StarsNode()
        starsNode.frame = CGRect(origin: .zero, size: CGSize(width: 32.0, height: 32.0))
        self.backgroundView?.contentView.addSubview(starsNode.view)
        self.starsNode = starsNode
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
