import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import ComponentFlow
import TelegramCore
import AccountContext
import ReactionSelectionNode
import TelegramPresentationData
import AccountContext
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import ShimmerEffect
import StickerResources

final class StickersCarouselComponent: Component {
    public typealias EnvironmentType = DemoPageEnvironment
    
    let context: AccountContext
    let stickers: [TelegramMediaFile]
    
    public init(
        context: AccountContext,
        stickers: [TelegramMediaFile]
    ) {
        self.context = context
        self.stickers = stickers
    }
    
    public static func ==(lhs: StickersCarouselComponent, rhs: StickersCarouselComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.stickers != rhs.stickers {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private var component: StickersCarouselComponent?
        private var node: StickersCarouselNode?
                
        public func update(component: StickersCarouselComponent, availableSize: CGSize, environment: Environment<DemoPageEnvironment>, transition: Transition) -> CGSize {
            let isDisplaying = environment[DemoPageEnvironment.self].isDisplaying
            
            if self.node == nil && !component.stickers.isEmpty {
                let node = StickersCarouselNode(
                    context: component.context,
                    stickers: component.stickers
                )
                self.node = node
                self.addSubnode(node)
            }
            
            let isFirstTime = self.component == nil
            self.component = component
                        
            if let node = self.node {
                node.setVisible(isDisplaying)
                node.frame = CGRect(origin: .zero, size: availableSize)
                node.updateLayout(size: availableSize, transition: .immediate)
            }
            
            if isFirstTime {
                self.node?.animateIn()
            }
            
            return availableSize
        }
    }
    
    public func makeView() -> View {
        return View()
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<DemoPageEnvironment>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, environment: environment, transition: transition)
    }
}

private let itemSize = CGSize(width: 220.0, height: 220.0)

private class StickerNode: ASDisplayNode {
    private let context: AccountContext
    private let file: TelegramMediaFile
    
    public var imageNode: TransformImageNode
    public var animationNode: AnimatedStickerNode?
    public var additionalAnimationNode: AnimatedStickerNode?
    
    private var placeholderNode: StickerShimmerEffectNode
    
    private let disposable = MetaDisposable()
    private let effectDisposable = MetaDisposable()
    
    private var setupTimestamp: Double?
    
    init(context: AccountContext, file: TelegramMediaFile, forceIsPremium: Bool) {
        self.context = context
        self.file = file
        
        self.imageNode = TransformImageNode()
    
        if file.isPremiumSticker || forceIsPremium {
            let animationNode = DefaultAnimatedStickerNodeImpl()
            //let animationNode = DirectAnimatedStickerNode()
            animationNode.automaticallyLoadFirstFrame = true
            self.animationNode = animationNode
            
            let dimensions = file.dimensions ?? PixelDimensions(width: 512, height: 512)
            let fittedDimensions = dimensions.cgSize.aspectFitted(CGSize(width: 240.0, height: 240.0))
            
            let pathPrefix = context.account.postbox.mediaBox.shortLivedResourceCachePathPrefix(file.resource.id)
            animationNode.setup(source: AnimatedStickerResourceSource(account: self.context.account, resource: file.resource, isVideo: file.isVideoSticker), width: Int(fittedDimensions.width * 1.6), height: Int(fittedDimensions.height * 1.6), playbackMode: .loop, mode: .direct(cachePathPrefix: pathPrefix))
            
            self.imageNode.setSignal(chatMessageAnimatedSticker(postbox: context.account.postbox, file: file, small: false, size: fittedDimensions))
            
            self.disposable.set(freeMediaFileResourceInteractiveFetched(account: self.context.account, fileReference: .standalone(media: file), resource: file.resource).start())
            
            if let effect = file.videoThumbnails.first {
                self.effectDisposable.set(freeMediaFileResourceInteractiveFetched(account: self.context.account, fileReference: .standalone(media: file), resource: effect.resource).start())
                
                let source = AnimatedStickerResourceSource(account: self.context.account, resource: effect.resource, fitzModifier: nil)
                
                let additionalAnimationNode: AnimatedStickerNode
                
                additionalAnimationNode = DirectAnimatedStickerNode()
                
                var pathPrefix: String?
                pathPrefix = context.account.postbox.mediaBox.shortLivedResourceCachePathPrefix(effect.resource.id)
                pathPrefix = nil
                
                additionalAnimationNode.setup(source: source, width: Int(fittedDimensions.width * 1.5), height: Int(fittedDimensions.height * 1.5), playbackMode: .loop, mode: .direct(cachePathPrefix: pathPrefix))
                self.additionalAnimationNode = additionalAnimationNode
            }
        } else {
            self.animationNode = nil
        }
        
        self.placeholderNode = StickerShimmerEffectNode()
        
        super.init()
        
        self.isUserInteractionEnabled = false
        
        self.addSubnode(self.imageNode)
        if let animationNode = self.animationNode {
            self.addSubnode(animationNode)
        }
        
        if let additionalAnimationNode = self.additionalAnimationNode {
            self.addSubnode(additionalAnimationNode)
        }
        
        self.addSubnode(self.placeholderNode)
        
        var firstTime = true
        self.imageNode.imageUpdated = { [weak self] image in
            guard let strongSelf = self else {
                return
            }
            if image != nil {
                strongSelf.removePlaceholder(animated: !firstTime)
            }
            firstTime = false
        }
            
        if let animationNode = self.animationNode {
            animationNode.started = { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                
                strongSelf.imageNode.alpha = 0.0
                
                let current = CACurrentMediaTime()
                if let setupTimestamp = strongSelf.setupTimestamp, current - setupTimestamp > 0.3 {
                    if !strongSelf.placeholderNode.alpha.isZero {
                        strongSelf.removePlaceholder(animated: true)
                    }
                } else {
                    strongSelf.removePlaceholder(animated: false)
                }
            }
        }
    }
    
    deinit {
        self.disposable.dispose()
        self.effectDisposable.dispose()
    }
    
    private func removePlaceholder(animated: Bool) {
        if !animated {
            self.placeholderNode.removeFromSupernode()
        } else {
            self.placeholderNode.alpha = 0.0
            self.placeholderNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, completion: { [weak self] _ in
                self?.placeholderNode.removeFromSupernode()
            })
        }
    }
    
    private var visibility: Bool = false
    private var centrality: Bool = false
    
    public func setCentral(_ central: Bool) {
        self.centrality = central
        self.updatePlayback()
    }
    
    public func setVisible(_ visible: Bool) {
        self.visibility = visible
        self.updatePlayback()
        
        self.setupTimestamp = CACurrentMediaTime()
    }
    
    func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize) {
        if self.placeholderNode.supernode != nil {
            self.placeholderNode.updateAbsoluteRect(rect, within: containerSize)
        }
    }
    
    private func updatePlayback() {
        self.animationNode?.visibility = self.visibility
        if let additionalAnimationNode = self.additionalAnimationNode {
            let wasVisible = additionalAnimationNode.visibility
            let isVisible = self.visibility && self.centrality
            if wasVisible && !isVisible {
                additionalAnimationNode.alpha = 0.0
                additionalAnimationNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, completion: { [weak additionalAnimationNode] _ in
                    additionalAnimationNode?.visibility = isVisible
                })
            } else if isVisible {
                additionalAnimationNode.visibility = isVisible
                if !wasVisible {
                    additionalAnimationNode.play(firstFrame: false, fromIndex: 0)
                    Queue.mainQueue().after(0.05, {
                        additionalAnimationNode.alpha = 1.0
                    })
                }
            }
        }
    }
    
    public func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        let boundingSize = itemSize
            
        if let dimensitons = self.file.dimensions {
            let imageSize = dimensitons.cgSize.aspectFitted(boundingSize)
            self.imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: UIEdgeInsets()))()
            let imageFrame = CGRect(origin: CGPoint(x: floor((size.width - imageSize.width) / 2.0), y: 0.0), size: imageSize)
            
            self.imageNode.frame = imageFrame
            if let animationNode = self.animationNode {
                animationNode.frame = imageFrame
                animationNode.updateLayout(size: imageSize)
                
                if let additionalAnimationNode = self.additionalAnimationNode {
                    additionalAnimationNode.frame = imageFrame.offsetBy(dx: -imageFrame.width * 0.245 + 21, dy: -1.0).insetBy(dx: -imageFrame.width * 0.245, dy: -imageFrame.height * 0.245)
                    additionalAnimationNode.updateLayout(size: additionalAnimationNode.frame.size)
                }
            }
            
            if self.placeholderNode.supernode != nil {
                let placeholderFrame = CGRect(origin: CGPoint(x: -10.0, y: 0.0), size: imageSize)
                let thumbnailDimensions = PixelDimensions(width: 512, height: 512)
                self.placeholderNode.update(backgroundColor: nil, foregroundColor: UIColor(rgb: 0xffffff, alpha: 0.2), shimmeringColor: UIColor(rgb: 0xffffff, alpha: 0.3), data: self.file.immediateThumbnailData, size: placeholderFrame.size, imageSize: thumbnailDimensions.cgSize)
                self.placeholderNode.frame = placeholderFrame
            }
        }
    }
}

private class StickersCarouselNode: ASDisplayNode, UIScrollViewDelegate {
    private let context: AccountContext
    private let stickers: [TelegramMediaFile]
    private var itemContainerNodes: [ASDisplayNode] = []
    private var itemNodes: [Int: StickerNode] = [:]
    private let scrollNode: ASScrollNode
    private let tapNode: ASDisplayNode
    
    private var animator: DisplayLinkAnimator?
    private var currentPosition: CGFloat = 0.0
    private var currentIndex: Int = 0
    
    private var validLayout: CGSize?
    
    private var playingIndices = Set<Int>()
    
    private let positionDelta: Double
    
    private var previousInteractionTimestamp: Double = 0.0
    private var timer: SwiftSignalKit.Timer?
    
    init(context: AccountContext, stickers: [TelegramMediaFile]) {
        self.context = context
        self.stickers = stickers
        
        self.scrollNode = ASScrollNode()
        self.tapNode = ASDisplayNode()
        
        self.positionDelta = 1.0 / CGFloat(self.stickers.count)
        
        super.init()
        
        self.clipsToBounds = true
        
        self.addSubnode(self.scrollNode)
        self.scrollNode.addSubnode(self.tapNode)
        
        for _ in self.stickers {
            let containerNode = ASDisplayNode()
            containerNode.isUserInteractionEnabled = false
            self.addSubnode(containerNode)
                        
            self.itemContainerNodes.append(containerNode)
        }
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.scrollNode.view.delegate = self
        self.scrollNode.view.showsHorizontalScrollIndicator = false
        self.scrollNode.view.showsVerticalScrollIndicator = false
        self.scrollNode.view.canCancelContentTouches = true
        
        self.tapNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.stickerTapped(_:))))
    }
    
    @objc private func stickerTapped(_ gestureRecognizer: UITapGestureRecognizer) {
        self.previousInteractionTimestamp = CACurrentMediaTime() + 1.0
        
        guard self.animator == nil, self.scrollStartPosition == nil else {
            return
        }
        
        let point = gestureRecognizer.location(in: self.view)
        guard let index = self.itemContainerNodes.firstIndex(where: { $0.frame.contains(point) }) else {
            return
        }
        
        self.scrollTo(index, playAnimation: true, immediately: true, duration: 0.4)
    }
    
    func animateIn() {
        self.scrollTo(1, playAnimation: true, immediately: true, duration: 0.5, clockwise: true)
        
        if self.timer == nil {
            self.previousInteractionTimestamp = CACurrentMediaTime()
            self.timer = SwiftSignalKit.Timer(timeout: 0.2, repeat: true, completion: { [weak self] in
                if let strongSelf = self {
                    let currentTimestamp = CACurrentMediaTime()
                    if currentTimestamp > strongSelf.previousInteractionTimestamp + 2.0 {
                        var nextIndex = strongSelf.currentIndex - 1
                        if nextIndex < 0 {
                            nextIndex = strongSelf.stickers.count + nextIndex
                        }
                        strongSelf.scrollTo(nextIndex, playAnimation: true, immediately: true, duration: 0.85, clockwise: true)
                        strongSelf.previousInteractionTimestamp = currentTimestamp
                    }
                }
            }, queue: Queue.mainQueue())
            self.timer?.start()
        }
    }
    
    func scrollTo(_ index: Int, playAnimation: Bool, immediately: Bool, duration: Double, clockwise: Bool? = nil) {
        guard index >= 0 && index < self.stickers.count else {
            return
        }
        self.currentIndex = index
        let delta = self.positionDelta
        
        let startPosition = self.currentPosition
        let newPosition = delta * CGFloat(index)
        var change = newPosition - startPosition
        if let clockwise = clockwise {
            if clockwise {
                if change > 0.0 {
                    change = change - 1.0
                }
            } else {
                if change < 0.0 {
                    change = 1.0 + change
                }
            }
        } else {
            if change > 0.5 {
                change = change - 1.0
            } else if change < -0.5 {
                change = 1.0 + change
            }
        }
        
        if immediately {
            self.playSelectedSticker(index: index)
        }
        
        self.animator = DisplayLinkAnimator(duration: duration * UIView.animationDurationFactor(), from: 0.0, to: 1.0, update: { [weak self] t in
            let t = listViewAnimationCurveSystem(t)
            var updatedPosition = startPosition + change * t
            while updatedPosition >= 1.0 {
                updatedPosition -= 1.0
            }
            while updatedPosition < 0.0 {
                updatedPosition += 1.0
            }
            self?.currentPosition = updatedPosition
            if let size = self?.validLayout {
                self?.updateLayout(size: size, transition: .immediate)
            }
        }, completion: { [weak self] in
            self?.animator = nil
            if playAnimation && !immediately {
                self?.playSelectedSticker(index: index)
            }
        })
    }
    
    private var visibility = false
    func setVisible(_ visible: Bool) {
        guard self.visibility != visible else {
            return
        }
        self.visibility = visible
        
        if let size = self.validLayout {
            self.updateLayout(size: size, transition: .immediate)
        }
    }
    
    private var ignoreContentOffsetChange = false
    private func resetScrollPosition() {
        self.scrollStartPosition = nil
        self.ignoreContentOffsetChange = true
        self.scrollNode.view.contentOffset = CGPoint(x: 0.0, y: 5000.0 - self.scrollNode.frame.height * 0.5)
        self.ignoreContentOffsetChange = false
    }
    
    func playSelectedSticker(index: Int?) {
        let index = index ?? max(0, Int(round(self.currentPosition / self.positionDelta)) % self.stickers.count)
        
        guard !self.playingIndices.contains(index) else {
            return
        }
        
        for (i, itemNode) in self.itemNodes {
            let containerNode = self.itemContainerNodes[i]
            let isCentral = i == index
            itemNode.setCentral(isCentral)
            if !isCentral {
                itemNode.setVisible(false)
            }
            
            if isCentral {
                containerNode.view.superview?.bringSubviewToFront(containerNode.view)
            }
        }
    }
    
    private var scrollStartPosition: (contentOffset: CGFloat, position: CGFloat)?
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        if self.scrollStartPosition == nil {
            self.scrollStartPosition = (scrollView.contentOffset.y, self.currentPosition)
        }
        
        for (_, itemNode) in self.itemNodes {
            itemNode.setCentral(false)
        }
    }
        
    private let hapticFeedback = HapticFeedback()
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView.isTracking {
            self.previousInteractionTimestamp = CACurrentMediaTime() + 1.0
        }
        
        if let animator = self.animator {
            animator.invalidate()
            self.animator = nil
        }
        
        guard !self.ignoreContentOffsetChange, let (startContentOffset, startPosition) = self.scrollStartPosition else {
            return
        }

        let delta = scrollView.contentOffset.y - startContentOffset
        let positionDelta = delta * 0.0005
        var updatedPosition = startPosition + positionDelta
        while updatedPosition >= 1.0 {
            updatedPosition -= 1.0
        }
        while updatedPosition < 0.0 {
            updatedPosition += 1.0
        }
        self.currentPosition = updatedPosition
        
        let indexDelta = self.positionDelta
        let index = max(0, Int(round(self.currentPosition / indexDelta)) % self.stickers.count)
        if index != self.currentIndex {
            self.currentIndex = index
            if self.scrollNode.view.isTracking || self.scrollNode.view.isDecelerating {
                self.hapticFeedback.tap()
            }
        }
        
        if let size = self.validLayout {
            self.updateLayout(size: size, transition: .immediate)
        }
    }
    
    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        guard let (startContentOffset, _) = self.scrollStartPosition, abs(velocity.y) > 0.0 else {
            return
        }
        
        let delta = self.positionDelta
        let scrollDelta = targetContentOffset.pointee.y - startContentOffset
        let positionDelta = scrollDelta * 0.0005
        let positionCounts = round(positionDelta / delta)
        let adjustedPositionDelta = delta * positionCounts
        let adjustedScrollDelta = adjustedPositionDelta * 2000.0
                
        targetContentOffset.pointee = CGPoint(x: 0.0, y: startContentOffset + adjustedScrollDelta)
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            self.previousInteractionTimestamp = CACurrentMediaTime() + 1.0
            
            self.resetScrollPosition()
            
            let delta = self.positionDelta
            let index = max(0, Int(round(self.currentPosition / delta)) % self.stickers.count)
            self.scrollTo(index, playAnimation: true, immediately: true, duration: 0.2)
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        self.previousInteractionTimestamp = CACurrentMediaTime() + 1.0
        
        self.resetScrollPosition()
        self.playSelectedSticker(index: nil)
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        self.validLayout = size
        
        self.scrollNode.frame = CGRect(origin: CGPoint(), size: size)
        if self.scrollNode.view.contentSize.width.isZero {
            self.scrollNode.view.contentSize = CGSize(width: size.width, height: 10000000.0)
            self.tapNode.frame = CGRect(origin: CGPoint(), size: self.scrollNode.view.contentSize)
            self.resetScrollPosition()
        }
        
        let delta = self.positionDelta
    
        let bounds = CGRect(origin: .zero, size: size)
        let areaSize = CGSize(width: floor(size.width * 4.0), height: size.height * 2.2)
        
        for i in 0 ..< self.stickers.count {
            let containerNode = self.itemContainerNodes[i]
            
            var angle = CGFloat.pi * 0.5 + CGFloat(i) * delta * CGFloat.pi * 2.0 - self.currentPosition * CGFloat.pi * 2.0 - CGFloat.pi * 0.5
            if angle < 0.0 {
                angle = CGFloat.pi * 2.0 + angle
            }
            if angle > CGFloat.pi * 2.0 {
                angle = angle - CGFloat.pi * 2.0
            }
            
            func calculateRelativeAngle(_ angle: CGFloat) -> CGFloat {
                var relativeAngle = angle
                if relativeAngle > CGFloat.pi {
                    relativeAngle = (2.0 * CGFloat.pi - relativeAngle) * -1.0
                }
                return relativeAngle
            }
            
            let relativeAngle = calculateRelativeAngle(angle)
            let distance = abs(relativeAngle)
            
            let point = CGPoint(
                x: cos(angle),
                y: sin(angle)
            )
                        
            let itemFrame = CGRect(origin: CGPoint(x: -size.width - 0.5 * itemSize.width - 30.0 + point.x * areaSize.width * 0.5 - itemSize.width * 0.5, y: size.height * 0.5 + point.y * areaSize.height * 0.5 - itemSize.height * 0.5), size: itemSize)
            containerNode.bounds = CGRect(origin: CGPoint(), size: itemFrame.size)
            containerNode.position = CGPoint(x: itemFrame.midX, y: itemFrame.midY)
            transition.updateTransformScale(node: containerNode, scale: 1.0 - distance * 0.75)
            transition.updateAlpha(node: containerNode, alpha: 1.0 - distance * 0.6)
            
            let isVisible = self.visibility && itemFrame.intersects(bounds)
            if isVisible {
                let itemNode: StickerNode
                if let current = self.itemNodes[i] {
                    itemNode = current
                } else {
                    itemNode = StickerNode(context: self.context, file: self.stickers[i], forceIsPremium: true)
                    containerNode.addSubnode(itemNode)
                    self.itemNodes[i] = itemNode
                }
                itemNode.updateAbsoluteRect(itemFrame, within: size)
                itemNode.setVisible(isVisible)
                
                let isCentral = self.scrollNode.view.isTracking || i == self.currentIndex
                itemNode.setCentral(isCentral)
                
                itemNode.frame = CGRect(origin: CGPoint(), size: itemFrame.size)
                itemNode.updateLayout(size: itemFrame.size, transition: transition)
            } else {
                if let itemNode = self.itemNodes[i] {
                    itemNode.removeFromSupernode()
                    self.itemNodes[i] = nil
                }
            }
        }
    }
}
