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
    
    private var isLongPressing: Bool = false
    private var longPressAnimator: DisplayLinkAnimator?
    
    var expandedAnimationDidBegin: (() -> Void)?
    
    init(context: AccountContext, theme: PresentationTheme, item: ReactionContextItem) {
        self.context = context
        self.item = item
        
        self.staticAnimationNode = AnimatedStickerNode()
        self.staticAnimationNode.isHidden = true
        
        self.animateInAnimationNode = AnimatedStickerNode()
        
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
    
    func appear(animated: Bool) {
        if animated {
            self.animateInAnimationNode?.visibility = true
        } else {
            self.animateInAnimationNode?.completed(true)
        }
    }
    
    func updateLayout(size: CGSize, isExpanded: Bool, largeExpanded: Bool, isPreviewing: Bool, transition: ContainedViewLayoutTransition) {
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
        
        if isExpanded, self.animationNode == nil {
            let animationNode = AnimatedStickerNode()
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
                    let stillAnimationNode = AnimatedStickerNode()
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
                
                self.staticAnimationNode.setup(source: AnimatedStickerResourceSource(account: self.context.account, resource: self.item.stillAnimation.resource), width: Int(animationDisplaySize.width * 2.0), height: Int(animationDisplaySize.height * 2.0), playbackMode: .still(.start), mode: .direct(cachePathPrefix: self.context.account.postbox.mediaBox.shortLivedResourceCachePathPrefix(self.item.stillAnimation.resource.id)))
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
    
    func updateIsLongPressing(isLongPressing: Bool) {
        if self.isLongPressing == isLongPressing {
            return
        }
        self.isLongPressing = isLongPressing
        
        if isLongPressing {
            if self.longPressAnimator == nil {
                let longPressAnimator = DisplayLinkAnimator(duration: 2.0, from: 1.0, to: 2.0, update: { [weak self] value in
                    guard let strongSelf = self else {
                        return
                    }
                    let transition: ContainedViewLayoutTransition = .immediate
                    transition.updateSublayerTransformScale(node: strongSelf, scale: value)
                }, completion: {
                })
                self.longPressAnimator = longPressAnimator
            }
        } else if let longPressAnimator = self.longPressAnimator {
            self.longPressAnimator = nil
            
            let transition: ContainedViewLayoutTransition = .animated(duration: 0.2, curve: .easeInOut)
            transition.updateSublayerTransformScale(node: self, scale: 1.0)
            
            longPressAnimator.invalidate()
        }
    }
}
