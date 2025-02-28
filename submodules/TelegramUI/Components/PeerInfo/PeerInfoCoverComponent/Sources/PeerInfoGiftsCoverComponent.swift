import Foundation
import AsyncDisplayKit
import Display
import ComponentFlow
import ComponentDisplayAdapters
import AnimationCache
import MultiAnimationRenderer
import TelegramCore
import AccountContext
import SwiftSignalKit
import EmojiTextAttachmentView
import LokiRng
import TextFormat

private final class PatternContentsTarget: MultiAnimationRenderTarget {
    private let imageUpdated: (Bool) -> Void
    
    init(imageUpdated: @escaping (Bool) -> Void) {
        self.imageUpdated = imageUpdated
        
        super.init()
    }
    
    required init(coder: NSCoder) {
        preconditionFailure()
    }
    
    override func transitionToContents(_ contents: AnyObject, didLoop: Bool) {
        let hadContents = self.contents != nil
        self.contents = contents
        self.imageUpdated(hadContents)
    }
}

private func windowFunction(t: CGFloat) -> CGFloat {
    return bezierPoint(0.6, 0.0, 0.4, 1.0, t)
}

private func patternScaleValueAt(fraction: CGFloat, t: CGFloat, reverse: Bool) -> CGFloat {
    let windowSize: CGFloat = 0.8

    let effectiveT: CGFloat
    let windowStartOffset: CGFloat
    let windowEndOffset: CGFloat
    if reverse {
        effectiveT = 1.0 - t
        windowStartOffset = 1.0
        windowEndOffset = -windowSize
    } else {
        effectiveT = t
        windowStartOffset = -windowSize
        windowEndOffset = 1.0
    }

    let windowPosition = (1.0 - fraction) * windowStartOffset + fraction * windowEndOffset
    let windowT = max(0.0, min(windowSize, effectiveT - windowPosition)) / windowSize
    let localT = 1.0 - windowFunction(t: windowT)

    return localT
}

public final class PeerInfoGiftsCoverComponent: Component {
    public let context: AccountContext
    public let peerId: EnginePeer.Id
    public let giftsContext: ProfileGiftsContext
    public let avatarCenter: CGPoint
    public let avatarScale: CGFloat
    public let defaultHeight: CGFloat
    public let avatarTransitionFraction: CGFloat
    public let patternTransitionFraction: CGFloat
    public let hasButtons: Bool
    
    public init(
        context: AccountContext,
        peerId: EnginePeer.Id,
        giftsContext: ProfileGiftsContext,
        avatarCenter: CGPoint,
        avatarScale: CGFloat,
        defaultHeight: CGFloat,
        avatarTransitionFraction: CGFloat,
        patternTransitionFraction: CGFloat,
        hasButtons: Bool
    ) {
        self.context = context
        self.peerId = peerId
        self.giftsContext = giftsContext
        self.avatarCenter = avatarCenter
        self.avatarScale = avatarScale
        self.defaultHeight = defaultHeight
        self.avatarTransitionFraction = avatarTransitionFraction
        self.patternTransitionFraction = patternTransitionFraction
        self.hasButtons = hasButtons
    }
    
    public static func ==(lhs: PeerInfoGiftsCoverComponent, rhs: PeerInfoGiftsCoverComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.peerId != rhs.peerId {
            return false
        }
        if lhs.avatarCenter != rhs.avatarCenter {
            return false
        }
        if lhs.avatarScale != rhs.avatarScale {
            return false
        }
        if lhs.defaultHeight != rhs.defaultHeight {
            return false
        }
        if lhs.avatarTransitionFraction != rhs.avatarTransitionFraction {
            return false
        }
        if lhs.patternTransitionFraction != rhs.patternTransitionFraction {
            return false
        }
        if lhs.hasButtons != rhs.hasButtons {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private let avatarBackgroundPatternContentsLayer: SimpleGradientLayer
        private let avatarBackgroundPatternMaskLayer: SimpleLayer
        private let avatarBackgroundGradientLayer: SimpleGradientLayer
        private let backgroundPatternContainer: UIView
        
        private var currentSize: CGSize?
        private var component: PeerInfoGiftsCoverComponent?
        private var state: EmptyComponentState?
                
        private var giftsDisposable: Disposable?
        private var gifts: [ProfileGiftsContext.State.StarGift] = []
        
        private var iconLayers: [AnyHashable: GiftIconLayer] = [:]
        
        private var iconPositions: [PositionGenerator.Position] = []
        private let seed = UInt(Date().timeIntervalSince1970)
        
        override public init(frame: CGRect) {
            self.avatarBackgroundGradientLayer = SimpleGradientLayer()
            self.avatarBackgroundGradientLayer.opacity = 0.0
          
            self.avatarBackgroundGradientLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
            self.avatarBackgroundGradientLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
            self.avatarBackgroundGradientLayer.type = .radial
            
            self.avatarBackgroundPatternContentsLayer = SimpleGradientLayer()
            self.avatarBackgroundPatternContentsLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
            self.avatarBackgroundPatternContentsLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
            self.avatarBackgroundPatternContentsLayer.type = .radial
            
            self.avatarBackgroundPatternMaskLayer = SimpleLayer()
            self.backgroundPatternContainer = UIView()
            
            super.init(frame: frame)
            
            self.clipsToBounds = true
                        
            self.avatarBackgroundPatternContentsLayer.mask = self.avatarBackgroundPatternMaskLayer
            self.layer.addSublayer(self.avatarBackgroundPatternContentsLayer)
            
            self.addSubview(self.backgroundPatternContainer)
        }
        
        required public init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.giftsDisposable?.dispose()
        }
        
        private var isUpdating = false
        func update(component: PeerInfoGiftsCoverComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            self.component = component
            self.state = state
            
            let previousCurrentSize = self.currentSize
            self.currentSize = availableSize
                    
            let iconSize = CGSize(width: 32.0, height: 32.0)
            
            if previousCurrentSize?.width != availableSize.width {
                var excludeRects: [CGRect] = []
                excludeRects.append(CGRect(origin: .zero, size: CGSize(width: 50.0, height: 90.0)))
                excludeRects.append(CGRect(origin: CGPoint(x: availableSize.width - 105.0, y: 0.0), size: CGSize(width: 105.0, height: 90.0)))
                excludeRects.append(CGRect(origin: CGPoint(x: floor((availableSize.width - 390.0) / 2.0), y: 0.0), size: CGSize(width: 390.0, height: 50.0)))
                excludeRects.append(CGRect(origin: CGPoint(x: floor((availableSize.width - 280.0) / 2.0), y: component.avatarCenter.y + 56.0), size: CGSize(width: 280.0, height: 65.0)))
                if component.hasButtons {
                    excludeRects.append(CGRect(origin: CGPoint(x: 0.0, y: availableSize.height - 81.0), size: CGSize(width: availableSize.width, height: 81.0)))
                }
                
                let positionGenerator = PositionGenerator(
                    containerSize: availableSize,
                    avatarFrame: CGSize(width: 100, height: 100).centered(around: component.avatarCenter),
                    minDistance: 75.0,
                    maxDistance: availableSize.width / 2.0,
                    padding: 16.0,
                    seed: self.seed,
                    excludeRects: excludeRects
                )
                self.iconPositions = positionGenerator.generatePositions(count: 6, viewSize: iconSize)
            }
            
            if self.giftsDisposable == nil {
                self.giftsDisposable = combineLatest(
                    queue: Queue.mainQueue(),
                    component.giftsContext.state,
                    component.context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: component.peerId))
                    |> map { peer -> Int64? in
                        if case let .user(user) = peer, case let .starGift(id, _, _, _, _, _, _, _, _) = user.emojiStatus?.content {
                            return id
                        }
                        return nil
                    }
                    |> distinctUntilChanged
                ).start(next: { [weak self] state, giftStatusId in
                    guard let self else {
                        return
                    }
                    
                    let pinnedGifts = state.gifts.filter { gift in
                        if gift.pinnedToTop {
                            if case let .unique(uniqueGift) = gift.gift {
                                return uniqueGift.id != giftStatusId
                            }
                        }
                        return false
                    }
                    self.gifts = pinnedGifts
                    
                    if !self.isUpdating {
                        self.state?.updated(transition: .immediate)
                    }
                })
            }
                                              
            let avatarPatternFrame = CGSize(width: 380.0, height: floor(component.defaultHeight * 1.0)).centered(around: component.avatarCenter)
            transition.setFrame(layer: self.avatarBackgroundPatternContentsLayer, frame: avatarPatternFrame)
            
            self.avatarBackgroundPatternContentsLayer.colors = [
                UIColor.red.withAlphaComponent(0.6).cgColor,
                UIColor.red.withAlphaComponent(0.0).cgColor
            ]
                
            let backgroundPatternContainerFrame = CGRect(origin: CGPoint(x: 0.0, y: availableSize.height), size: CGSize(width: availableSize.width, height: 0.0))
            transition.containedViewLayoutTransition.updateFrameAdditive(view: self.backgroundPatternContainer, frame: backgroundPatternContainerFrame)
            transition.setAlpha(view: self.backgroundPatternContainer, alpha: component.patternTransitionFraction)
            
            var validIds = Set<AnyHashable>()
            var index = 0
            for gift in self.gifts.prefix(6) {
                let id: AnyHashable
                if case let .unique(uniqueGift) = gift.gift {
                    id = uniqueGift.slug
                } else {
                    id = index
                }
                validIds.insert(id)
                
                let iconPosition = self.iconPositions[index]
                let iconLayer: GiftIconLayer
                if let current = self.iconLayers[id] {
                    iconLayer = current
                } else {
                    iconLayer = GiftIconLayer(context: component.context, gift: gift, size: iconSize)
                    iconLayer.startHovering()
                    self.iconLayers[id] = iconLayer
                    self.layer.addSublayer(iconLayer)
                    
                    iconLayer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    iconLayer.animateScale(from: 0.01, to: 1.0, duration: 0.2)
                }
                
                let zeroPosition = component.avatarCenter
                let finalPosition = iconPosition.center
                let itemScaleFraction = patternScaleValueAt(fraction: component.avatarTransitionFraction, t: 0.0, reverse: false)
               
                func interpolateRect(from: CGPoint, to: CGPoint, t: CGFloat) -> CGPoint {
                    let clampedT = max(0, min(1, t))
                    
                    let interpolatedX = from.x + (to.x - from.x) * clampedT
                    let interpolatedY = from.y + (to.y - from.y) * clampedT
                    
                    return CGPoint(
                        x: interpolatedX,
                        y: interpolatedY
                    )
                }
                
                let effectivePosition = interpolateRect(from: finalPosition, to: zeroPosition, t: itemScaleFraction)
                                
                transition.setBounds(layer: iconLayer, bounds: CGRect(origin: .zero, size: iconSize))
                transition.setPosition(layer: iconLayer, position: effectivePosition)
                transition.setScale(layer: iconLayer, scale: iconPosition.scale)
                transition.setAlpha(layer: iconLayer, alpha: 1.0 - itemScaleFraction)
                
                index += 1
            }
            
            var removeIds: [AnyHashable] = []
            for (id, layer) in self.iconLayers {
                if !validIds.contains(id) {
                    removeIds.append(id)
                    layer.animateScale(from: 1.0, to: 0.01, duration: 0.25, removeOnCompletion: false)
                    layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { _ in
                        layer.removeFromSuperlayer()
                    })
                }
            }
            for id in removeIds {
                self.iconLayers.removeValue(forKey: id)
            }
            return availableSize
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}


private class PositionGenerator {
    private let containerSize: CGSize
    private let avatarFrame: CGRect
    private let padding: CGFloat
    private let minDistance: CGFloat
    private let maxDistance: CGFloat
    private let rng: LokiRng
    
    private let excludeRects: [CGRect]
    
    struct Position {
        let center: CGPoint
        let scale: CGFloat
    }
    
    init(
        containerSize: CGSize,
        avatarFrame: CGRect,
        minDistance: CGFloat = 20,
        maxDistance: CGFloat = 100,
        padding: CGFloat = 10,
        seed: UInt = UInt.random(in: 0 ..< 10),
        excludeRects: [CGRect] = []
    ) {
        self.containerSize = containerSize
        self.avatarFrame = avatarFrame
        self.minDistance = minDistance
        self.maxDistance = maxDistance
        self.padding = padding
        self.rng = LokiRng(seed0: seed, seed1: 0, seed2: 0)
        self.excludeRects = excludeRects
    }
    
    func generatePositions(count: Int, viewSize: CGSize) -> [Position] {
        let safeCount = min(max(count, 1), 12) // Ensure between 1 and 12
        var positions: [Position] = []
        
        let distanceRanges = calculateDistanceRanges(count: safeCount)
        
        for i in 0..<safeCount {
            let minDist = distanceRanges[i].0
            let maxDist = distanceRanges[i].1
            let isEven = i % 2 == 0
            
            // Try to generate a valid position with multiple attempts
            var attempts = 0
            let maxAttempts = 20
            var foundPosition = false
            var currentMaxDist = maxDist
            
            while !foundPosition && attempts < maxAttempts {
                attempts += 1
                
                if let position = generateSinglePosition(
                    viewSize: viewSize,
                    minDist: minDist,
                    maxDist: currentMaxDist,
                    rightSide: !isEven
                ) {
                    // Skip distance check if this is the first position
                    let isFarEnough = positions.isEmpty || positions.allSatisfy { existingPosition in
                        let distance = hypot(position.x - existingPosition.center.x, position.y - existingPosition.center.y)
                        return distance > (viewSize.width + padding)
                    }
                    
                    let distance = hypot(position.x - self.avatarFrame.center.x, position.y - self.avatarFrame.center.y)
                    var scale = max(1.0, min(0.55, 1.0 - (distance - 50.0) / 100.0))
                    scale = scale * scale
                    
                    if isFarEnough {
                        positions.append(Position(center: position, scale: scale))
                        foundPosition = true
                        break
                    }
                }
                
                if attempts % 5 == 0 && !foundPosition {
                    currentMaxDist *= 1.2
                }
            }
            
            if !foundPosition {
                if let lastChancePosition = generateSinglePosition(
                    viewSize: viewSize,
                    minDist: minDist,
                    maxDist: maxDist * 2.0, // Try with a much larger distance
                    rightSide: !isEven
                ) {
                    let distance = hypot(lastChancePosition.x - self.avatarFrame.center.x,
                                        lastChancePosition.y - self.avatarFrame.center.y)
                    var scale = max(1.0, min(0.55, 1.0 - (distance - 50.0) / 100.0))
                    scale = scale * scale
                    
                    positions.append(Position(center: lastChancePosition, scale: scale))
                } else {
                    // If all else fails, create a position with default values to ensure we don't return fewer positions than requested
                    let defaultX = self.avatarFrame.center.x + (isEven ? -1 : 1) * (minDist + CGFloat(i * 20))
                    let defaultY = self.avatarFrame.center.y + CGFloat(i * 15)
                    let defaultPosition = CGPoint(x: defaultX, y: defaultY)
                    
                    // Use a smaller scale for these fallback positions
                    positions.append(Position(center: defaultPosition, scale: 0.5))
                }
            }
        }
        
        return positions
    }
    
    private func calculateDistanceRanges(count: Int) -> [(CGFloat, CGFloat)] {
        var ranges: [(CGFloat, CGFloat)] = []
        
        let totalRange = self.maxDistance - self.minDistance
        for _ in 0..<4 {
            let min = self.minDistance
            let max = self.minDistance + (totalRange * 0.12)
            ranges.append((min, max))
        }
        
        for _ in 0..<4 {
            let min = self.minDistance + (totalRange * 0.16)
            let max = self.minDistance + (totalRange * 0.6)
            ranges.append((min, max))
        }
        
        return ranges
    }
    
    private func generateSinglePosition(viewSize: CGSize, minDist: CGFloat, maxDist: CGFloat, rightSide: Bool) -> CGPoint? {
        let avatarCenter = avatarFrame.center

        for _ in 0..<50 {
            let baseAngle: CGFloat
            let angleSpread: CGFloat
            
            if rightSide {
                baseAngle = 0
                angleSpread = .pi / 2
            } else {
                baseAngle = .pi
                angleSpread = .pi / 2
            }
            
            let angleOffset = (CGFloat(rng.next()) * 2.0 - 1.0) * angleSpread
            let angle = baseAngle + angleOffset
            
            let distance = minDist + CGFloat(rng.next()) * (maxDist - minDist)
            
            let x = avatarCenter.x + cos(angle) * distance
            let y = avatarCenter.y + sin(angle) * distance
            
            let position = CGPoint(x: x, y: y)
            
            let viewFrame = CGRect(
                x: position.x - viewSize.width / 2,
                y: position.y - viewSize.height / 2,
                width: viewSize.width,
                height: viewSize.height
            )
            
            if isFrameWithinBounds(viewFrame) && !isFrameInExclusionZone(viewFrame) {
                return CGPoint(x: round(position.x), y: round(position.y))
            }
        }
        
        return nil
    }
    
    private func isFrameWithinBounds(_ frame: CGRect) -> Bool {
        return frame.minX >= self.padding &&
        frame.minY >= self.padding &&
        frame.maxX <= self.containerSize.width - self.padding &&
        frame.maxY <= self.containerSize.height - self.padding
    }
    
    private func isFrameInExclusionZone(_ frame: CGRect) -> Bool {
        if frame.intersects(avatarFrame) {
            return true
        }
        let padding: CGFloat = -8.0
        for excludeRect in self.excludeRects {
            if frame.intersects(excludeRect.insetBy(dx: padding, dy: padding)) {
                return true
            }
        }
        return false
    }
}

private var shadowImage: UIImage? = {
    return generateImage(CGSize(width: 44.0, height: 44.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: .zero, size: size))
        
        var locations: [CGFloat] = [0.0, 0.3, 1.0]
        let colors: [CGColor] = [UIColor(rgb: 0xffffff, alpha: 0.65).cgColor, UIColor(rgb: 0xffffff, alpha: 0.65).cgColor, UIColor(rgb: 0xffffff, alpha: 0.0).cgColor]
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
        context.drawRadialGradient(gradient, startCenter: CGPoint(x: size.width / 2.0, y: size.height / 2.0), startRadius: 0.0, endCenter: CGPoint(x: size.width / 2.0, y: size.height / 2.0), endRadius: size.width / 2.0, options: .drawsAfterEndLocation)
    })
}()

private class GiftIconLayer: SimpleLayer {
    private let context: AccountContext
    private let gift: ProfileGiftsContext.State.StarGift
    private let size: CGSize
    
    let shadowLayer = SimpleLayer()
    let animationLayer: InlineStickerItemLayer
    
    override init(layer: Any) {
        guard let layer = layer as? GiftIconLayer else {
            fatalError()
        }
        
        let context = layer.context
        let gift = layer.gift
        let size = layer.size
                
        var file: TelegramMediaFile?
        var color: UIColor?
        switch gift.gift {
        case let .generic(gift):
            file = gift.file
        case let .unique(gift):
            for attribute in gift.attributes {
                if case let .model(_, fileValue, _) = attribute {
                    file = fileValue
                } else if case let .backdrop(_, innerColor, _, _, _, _) = attribute {
                    color = UIColor(rgb: UInt32(bitPattern: innerColor))
                }
            }
        }
        
        let emoji = ChatTextInputTextCustomEmojiAttribute(
            interactivelySelectedFromPackId: nil,
            fileId: file?.fileId.id ?? 0,
            file: file
        )
        self.animationLayer = InlineStickerItemLayer(
            context: .account(context),
            userLocation: .other,
            attemptSynchronousLoad: false,
            emoji: emoji,
            file: file,
            cache: context.animationCache,
            renderer: context.animationRenderer,
            unique: true,
            placeholderColor: UIColor.white.withAlphaComponent(0.2),
            pointSize: CGSize(width: size.width * 2.0, height: size.height * 2.0),
            loopCount: 1
        )
        
        self.shadowLayer.contents = shadowImage?.cgImage
        self.shadowLayer.layerTintColor = color?.cgColor
        
        self.context = context
        self.gift = gift
        self.size = size
        
        super.init()
        
        self.addSublayer(self.shadowLayer)
        self.addSublayer(self.animationLayer)
    }
    
    init(
        context: AccountContext,
        gift: ProfileGiftsContext.State.StarGift,
        size: CGSize
    ) {
        self.context = context
        self.gift = gift
        self.size = size
        
        var file: TelegramMediaFile?
        var color: UIColor?
        switch gift.gift {
        case let .generic(gift):
            file = gift.file
        case let .unique(gift):
            for attribute in gift.attributes {
                if case let .model(_, fileValue, _) = attribute {
                    file = fileValue
                } else if case let .backdrop(_, innerColor, _, _, _, _) = attribute {
                    color = UIColor(rgb: UInt32(bitPattern: innerColor))
                }
            }
        }
        
        let emoji = ChatTextInputTextCustomEmojiAttribute(
            interactivelySelectedFromPackId: nil,
            fileId: file?.fileId.id ?? 0,
            file: file
        )
        self.animationLayer = InlineStickerItemLayer(
            context: .account(context),
            userLocation: .other,
            attemptSynchronousLoad: false,
            emoji: emoji,
            file: file,
            cache: context.animationCache,
            renderer: context.animationRenderer,
            unique: true,
            placeholderColor: UIColor.white.withAlphaComponent(0.2),
            pointSize: CGSize(width: size.width * 2.0, height: size.height * 2.0),
            loopCount: 1
        )
        
        self.shadowLayer.contents = shadowImage?.cgImage
        self.shadowLayer.layerTintColor = color?.cgColor
        
        super.init()
        
        self.addSublayer(self.shadowLayer)
        self.addSublayer(self.animationLayer)
    }
    
    required init?(coder: NSCoder) {
        preconditionFailure()
    }
    
    override func layoutSublayers() {
        self.shadowLayer.frame = CGRect(origin: .zero, size: self.bounds.size).insetBy(dx: -4.0, dy: -4.0)
        self.animationLayer.frame = CGRect(origin: .zero, size: self.bounds.size)
    }
    
    func startHovering(
            distance: CGFloat = 3.0,
            duration: TimeInterval = 4.0,
            timingFunction: CAMediaTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        ) {
            let hoverAnimation = CABasicAnimation(keyPath: "transform.translation.y")
            hoverAnimation.duration = duration
            hoverAnimation.fromValue = -distance
            hoverAnimation.toValue = distance
            hoverAnimation.autoreverses = true
            hoverAnimation.repeatCount = .infinity
            hoverAnimation.timingFunction = timingFunction
            hoverAnimation.beginTime = Double.random(in: 0.0 ..< 12.0)
            hoverAnimation.isAdditive = true
            self.add(hoverAnimation, forKey: "hover")
            
            let glowAnimation = CABasicAnimation(keyPath: "transform.scale")
            glowAnimation.duration = duration
            glowAnimation.fromValue = 1.0
            glowAnimation.toValue = 1.2
            glowAnimation.autoreverses = true
            glowAnimation.repeatCount = .infinity
            glowAnimation.timingFunction = timingFunction
            glowAnimation.beginTime = Double.random(in: 0.0 ..< 12.0)
            self.shadowLayer.add(glowAnimation, forKey: "glow")
        }
}
