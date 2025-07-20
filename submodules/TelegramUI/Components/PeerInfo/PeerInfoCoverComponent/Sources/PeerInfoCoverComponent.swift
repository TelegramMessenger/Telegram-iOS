import Foundation
import UIKit
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

public final class PeerInfoCoverComponent: Component {
    public enum Subject: Equatable {
        case peer(EnginePeer)
        case status(PeerEmojiStatus)
        case custom(UIColor?, UIColor?, UIColor?, Int64?)
        
        func colors(context: AccountContext, isDark: Bool) -> (UIColor, UIColor)? {
            switch self {
            case let .peer(peer):
                if let colors = peer._asPeer().profileColor.flatMap({ context.peerNameColors.getProfile($0, dark: isDark) }) {
                    let backgroundColor = colors.main
                    let secondaryBackgroundColor = colors.secondary ?? colors.main
                    return (backgroundColor, secondaryBackgroundColor)
                } else {
                    return nil
                }
            case let .status(status):
                if case let .starGift(_, _, _, _, _, innerColor, outerColor, _, _) = status.content {
                    return (UIColor(rgb: UInt32(bitPattern: innerColor)), UIColor(rgb: UInt32(bitPattern: outerColor)))
                }
                return nil
            case let .custom(color, secondColor, _, _):
                if let color {
                    if let secondColor {
                        return (color, secondColor)
                    } else {
                        return (color, color)
                    }
                } else {
                    return nil
                }
            }
        }
        
        var fileId: Int64? {
            switch self {
            case let .peer(peer):
                return peer.profileBackgroundEmojiId
            case let .status(status):
                if case let .starGift(_, _, _, _, patternFileId, _, _, _, _) = status.content {
                    return patternFileId
                }
                return nil
            case let .custom(_, _, _, fileId):
                return fileId
            }
        }
    }
    public let context: AccountContext
    public let subject: Subject?
    public let files: [Int64: TelegramMediaFile]
    public let isDark: Bool
    public let avatarCenter: CGPoint
    public let avatarSize: CGSize
    public let avatarScale: CGFloat
    public let defaultHeight: CGFloat
    public let gradientOnTop: Bool
    public let gradientCenter: CGPoint
    public let avatarTransitionFraction: CGFloat
    public let patternTransitionFraction: CGFloat
    
    public init(
        context: AccountContext,
        subject: Subject?,
        files: [Int64: TelegramMediaFile],
        isDark: Bool,
        avatarCenter: CGPoint,
        avatarSize: CGSize = CGSize(width: 100.0, height: 100.0),
        avatarScale: CGFloat,
        defaultHeight: CGFloat,
        gradientOnTop: Bool = false,
        gradientCenter: CGPoint = CGPoint(x: 0.5, y: 0.5),
        avatarTransitionFraction: CGFloat,
        patternTransitionFraction: CGFloat
    ) {
        self.context = context
        self.subject = subject
        self.files = files
        self.isDark = isDark
        self.avatarCenter = avatarCenter
        self.avatarSize = avatarSize
        self.avatarScale = avatarScale
        self.defaultHeight = defaultHeight
        self.gradientOnTop = gradientOnTop
        self.gradientCenter = gradientCenter
        self.avatarTransitionFraction = avatarTransitionFraction
        self.patternTransitionFraction = patternTransitionFraction
    }
    
    public static func ==(lhs: PeerInfoCoverComponent, rhs: PeerInfoCoverComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.subject != rhs.subject {
            return false
        }
        if lhs.files != rhs.files {
            return false
        }
        if lhs.isDark != rhs.isDark {
            return false
        }
        if lhs.avatarCenter != rhs.avatarCenter {
            return false
        }
        if lhs.avatarSize != rhs.avatarSize {
            return false
        }
        if lhs.avatarScale != rhs.avatarScale {
            return false
        }
        if lhs.defaultHeight != rhs.defaultHeight {
            return false
        }
        if lhs.gradientOnTop != rhs.gradientOnTop {
            return false
        }
        if lhs.gradientCenter != rhs.gradientCenter {
            return false
        }
        if lhs.avatarTransitionFraction != rhs.avatarTransitionFraction {
            return false
        }
        if lhs.patternTransitionFraction != rhs.patternTransitionFraction {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private let backgroundView: UIView
        private let backgroundGradientLayer: SimpleGradientLayer
        private let avatarBackgroundPatternContentsLayer: SimpleGradientLayer
        private let avatarBackgroundPatternMaskLayer: SimpleLayer
        private let avatarBackgroundGradientLayer: SimpleGradientLayer
        private let backgroundPatternContainer: UIView
        
        private var currentSize: CGSize?
        private var component: PeerInfoCoverComponent?
        private var state: EmptyComponentState?
        
        private var patternContentsTarget: PatternContentsTarget?
        private var avatarPatternContentLayers: [SimpleLayer] = []
        private var patternFile: TelegramMediaFile?
        private var patternFileDisposable: Disposable?
        private var patternImageDisposable: Disposable?
        
        override public init(frame: CGRect) {
            self.backgroundView = UIView()
            self.backgroundGradientLayer = SimpleGradientLayer()
            
            self.avatarBackgroundGradientLayer = SimpleGradientLayer()
            self.avatarBackgroundGradientLayer.opacity = 0.0
            let baseAvatarGradientAlpha: CGFloat = 0.4
            let numSteps = 6
            self.avatarBackgroundGradientLayer.colors = (0 ..< numSteps).map { i in
                let step: CGFloat = 1.0 - CGFloat(i) / CGFloat(numSteps - 1)
                return UIColor(white: 1.0, alpha: baseAvatarGradientAlpha * pow(step, 2.0)).cgColor
            }
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
            
            self.addSubview(self.backgroundView)
            self.layer.addSublayer(self.backgroundGradientLayer)
            self.layer.addSublayer(self.avatarBackgroundGradientLayer)
            
            self.avatarBackgroundPatternContentsLayer.mask = self.avatarBackgroundPatternMaskLayer
            self.layer.addSublayer(self.avatarBackgroundPatternContentsLayer)
            
            self.addSubview(self.backgroundPatternContainer)
            
            self.layer.allowsGroupOpacity = true
            self.backgroundView.layer.allowsGroupOpacity = true
        }
        
        required public init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.patternFileDisposable?.dispose()
            self.patternImageDisposable?.dispose()
        }
        
        public func willAnimateIn() {
            for layer in self.avatarPatternContentLayers {
                layer.opacity = 0.0
            }
        }
        
        public func animateIn() {
            guard let _ = self.currentSize, let component = self.component else {
                return
            }
            
            for layer in self.avatarPatternContentLayers {
                layer.opacity = 1.0
                layer.animatePosition(
                    from: component.avatarCenter,
                    to: layer.position,
                    duration: 0.4,
                    timingFunction: kCAMediaTimingFunctionSpring
                )
            }
        }
        
        public func animateTransition() {
            if let gradientSnapshotLayer = self.backgroundGradientLayer.snapshotContentTree() {
                let backgroundSnapshotLayer = SimpleLayer()
                backgroundSnapshotLayer.allowsGroupOpacity = true
                backgroundSnapshotLayer.backgroundColor = self.backgroundView.backgroundColor?.cgColor
                backgroundSnapshotLayer.frame = self.backgroundView.frame
                self.layer.insertSublayer(backgroundSnapshotLayer, above: self.backgroundGradientLayer)
               
                backgroundSnapshotLayer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { _ in
                    backgroundSnapshotLayer.removeFromSuperlayer()
                })
                gradientSnapshotLayer.frame = self.backgroundGradientLayer.convert(self.backgroundGradientLayer.bounds, to: self.backgroundView.layer)
                backgroundSnapshotLayer.addSublayer(gradientSnapshotLayer)
            }
            for layer in self.avatarPatternContentLayers {
                if let _ = layer.contents, let snapshot = layer.snapshotContentTree() {
                    layer.superlayer?.addSublayer(snapshot)
                    snapshot.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { _ in
                        snapshot.removeFromSuperlayer()
                    })
                }
                layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
            }
            let values: [NSNumber] = [1.0, 1.08, 1.0]
            self.avatarBackgroundPatternContentsLayer.animateKeyframes(values: values, duration: 0.25, keyPath: "sublayerTransform.scale")
        }
        
        private func loadPatternFromFile() {
            guard let component = self.component else {
                return
            }
            guard let patternContentsTarget = self.patternContentsTarget else {
                return
            }
            guard let patternFile = self.patternFile else {
                return
            }
            
            if component.context.animationRenderer.loadFirstFrameSynchronously(target: patternContentsTarget, cache: component.context.animationCache, itemId: patternFile.resource.id.stringRepresentation, size: CGSize(width: 96, height: 96)) {
                self.updatePatternLayerImages(animated: false)
            } else {
                let animated = self.patternContentsTarget?.contents == nil
                self.patternImageDisposable = component.context.animationRenderer.loadFirstFrame(
                    target: patternContentsTarget,
                    cache: component.context.animationCache,
                    itemId: patternFile.resource.id.stringRepresentation,
                    size: CGSize(width: 96, height: 96),
                    fetch: animationCacheFetchFile(
                        postbox: component.context.account.postbox,
                        userLocation: .other,
                        userContentType: .sticker,
                        resource: .media(media: .standalone(media: patternFile), resource: patternFile.resource),
                        type: AnimationCacheAnimationType(file: patternFile),
                        keyframeOnly: false,
                        customColor: .white
                    ),
                    completion: { [weak self] _, _ in
                        guard let self else {
                            return
                        }
                        self.updatePatternLayerImages(animated: animated)
                    }
                )
            }
        }
        
        private func updatePatternLayerImages(animated: Bool) {
            let image = self.patternContentsTarget?.contents
            for patternContentLayer in self.avatarPatternContentLayers {
                patternContentLayer.contents = image
                
                if image != nil && animated {
                    patternContentLayer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                }
            }
        }
        
        func update(component: PeerInfoCoverComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let previousComponent = self.component
            self.component = component
            self.currentSize = availableSize
                        
            if previousComponent?.subject?.fileId != component.subject?.fileId {
                if let fileId = component.subject?.fileId, fileId != 0 {
                    if self.patternContentsTarget == nil {
                        self.patternContentsTarget = PatternContentsTarget(imageUpdated: { [weak self] hadContents in
                            guard let self else {
                                return
                            }
                            self.updatePatternLayerImages(animated: !hadContents)
                        })
                    }
                    
                    self.patternFile = nil
                    self.patternFileDisposable?.dispose()
                    self.patternFileDisposable = nil
                    self.patternImageDisposable?.dispose()
                    
                    if let file = component.files[fileId] {
                        self.patternFile = file
                        self.loadPatternFromFile()
                    } else {
                        self.patternFileDisposable = (component.context.engine.stickers.resolveInlineStickers(fileIds: [fileId])
                        |> deliverOnMainQueue).startStrict(next: { [weak self] files in
                            guard let self else {
                                return
                            }
                            if let file = files[fileId] {
                                self.patternFile = file
                                self.loadPatternFromFile()
                            }
                        })
                    }
                } else {
                    self.patternContentsTarget = nil
                    self.patternFileDisposable?.dispose()
                    self.patternFileDisposable = nil
                    self.patternFile = nil
                    self.updatePatternLayerImages(animated: false)
                }
            }
        
            self.state = state
            
            let backgroundColor: UIColor
            let secondaryBackgroundColor: UIColor
            
            if let subject = component.subject, let colors = subject.colors(context: component.context, isDark: component.isDark) {
                backgroundColor = colors.0
                secondaryBackgroundColor = colors.1
            } else {
                backgroundColor = .clear
                secondaryBackgroundColor = .clear
            }
            
            let gradientWidth: CGFloat
            let gradientHeight: CGFloat = component.defaultHeight
            if case .custom = component.subject {
                gradientWidth = gradientHeight
                self.backgroundView.backgroundColor = backgroundColor
                self.backgroundGradientLayer.startPoint = CGPoint(x: 0.5, y: component.avatarCenter.y / gradientHeight)
                self.backgroundGradientLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
                self.backgroundGradientLayer.type = .radial
                self.backgroundGradientLayer.colors = [secondaryBackgroundColor.cgColor, backgroundColor.cgColor]
            } else if case .status = component.subject {
                gradientWidth = availableSize.width
                self.backgroundView.backgroundColor = secondaryBackgroundColor
                self.backgroundGradientLayer.startPoint = component.gradientCenter
                self.backgroundGradientLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
                self.backgroundGradientLayer.type = .radial
                self.backgroundGradientLayer.colors = [backgroundColor.cgColor, secondaryBackgroundColor.cgColor]
            } else {
                gradientWidth = availableSize.width
                self.backgroundView.backgroundColor = secondaryBackgroundColor
                self.backgroundGradientLayer.startPoint = CGPoint(x: 0.5, y: 1.0)
                self.backgroundGradientLayer.endPoint = CGPoint(x: 0.5, y: 0.0)
                self.backgroundGradientLayer.type = .axial
                self.backgroundGradientLayer.colors = [backgroundColor.cgColor, secondaryBackgroundColor.cgColor]
            }
            self.backgroundGradientLayer.anchorPoint = CGPoint(x: 0.0, y: 1.0)
            
            let backgroundGradientFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - gradientWidth) / 2.0), y: component.gradientOnTop ? 0.0 : availableSize.height - gradientHeight), size: CGSize(width: gradientWidth, height: gradientHeight))
            if !transition.animation.isImmediate {
                let previousPosition = self.backgroundGradientLayer.position
                let updatedPosition = CGPoint(x: backgroundGradientFrame.minX, y: backgroundGradientFrame.maxY)
                self.backgroundGradientLayer.bounds = CGRect(origin: CGPoint(), size: backgroundGradientFrame.size)
                self.backgroundGradientLayer.position = updatedPosition
                transition.containedViewLayoutTransition.animatePositionAdditive(layer: self.backgroundGradientLayer, offset: CGPoint(x: previousPosition.x - updatedPosition.x, y: previousPosition.y - updatedPosition.y))
            } else {
                self.backgroundGradientLayer.frame = backgroundGradientFrame
            }
            
            let backgroundFrame = CGRect(origin: CGPoint(x: 0.0, y: -1000.0 + availableSize.height), size: CGSize(width: availableSize.width, height: 1000.0))
            transition.containedViewLayoutTransition.updateFrameAdditive(view: self.backgroundView, frame: backgroundFrame)
                        
            let avatarPatternFrame = CGSize(width: 380.0, height: floor(component.defaultHeight * 1.0)).centered(around: component.avatarCenter)
            transition.setFrame(layer: self.avatarBackgroundPatternContentsLayer, frame: avatarPatternFrame)
            
            if case let .custom(_, _, patternColor, _) = component.subject, let patternColor {
                self.avatarBackgroundPatternContentsLayer.compositingFilter = nil
                self.avatarBackgroundPatternContentsLayer.colors = [
                    patternColor.withAlphaComponent(0.6).cgColor,
                    patternColor.withAlphaComponent(0.0).cgColor
                ]
            } else if case let .status(status) = component.subject, case let .starGift(_, _, _, _, _, _, _, patternColorValue, _) = status.content {
                let patternColor = UIColor(rgb: UInt32(bitPattern: patternColorValue))
                self.avatarBackgroundPatternContentsLayer.compositingFilter = nil
                self.avatarBackgroundPatternContentsLayer.colors = [
                    patternColor.withAlphaComponent(0.6).cgColor,
                    patternColor.withAlphaComponent(0.0).cgColor
                ]
            } else {
                if component.subject?.colors(context: component.context, isDark: component.isDark) != nil {
                    self.avatarBackgroundPatternContentsLayer.compositingFilter = "overlayBlendMode"
                    self.avatarBackgroundPatternContentsLayer.colors = [
                        UIColor(white: 0.0, alpha: 0.6).cgColor,
                        UIColor(white: 0.0, alpha: 0.0).cgColor
                    ]
                } else {
                    self.avatarBackgroundPatternContentsLayer.compositingFilter = nil
                    let baseWhite: CGFloat = component.isDark ? 0.5 : 0.3
                    self.avatarBackgroundPatternContentsLayer.colors = [
                        UIColor(white: baseWhite, alpha: 0.6).cgColor,
                        UIColor(white: baseWhite, alpha: 0.0).cgColor
                    ]
                }
            }
            
            switch component.subject {
            case .custom, .status:
                self.avatarBackgroundGradientLayer.isHidden = true
            default:
                self.avatarBackgroundGradientLayer.isHidden = component.subject?.colors(context: component.context, isDark: component.isDark) == nil
            }
            transition.setFrame(layer: self.avatarBackgroundGradientLayer, frame: CGSize(width: 300.0, height: 300.0).centered(around: component.avatarCenter))
            transition.setAlpha(layer: self.avatarBackgroundGradientLayer, alpha: 1.0 - component.avatarTransitionFraction)
            
            let backgroundPatternContainerFrame = CGRect(origin: CGPoint(x: 0.0, y: availableSize.height), size: CGSize(width: availableSize.width, height: 0.0))
            transition.containedViewLayoutTransition.updateFrameAdditive(view: self.backgroundPatternContainer, frame: backgroundPatternContainerFrame)
            transition.setAlpha(view: self.backgroundPatternContainer, alpha: component.patternTransitionFraction)
            
            var baseDistance: CGFloat = component.avatarSize.width / 2.0 + 22.0
            var baseRowDistance: CGFloat = 28.0
            var baseItemSize: CGFloat = 26.0
            if availableSize.width <= 60.0 {
                baseDistance *= 0.35
                baseRowDistance *= 0.3
                baseItemSize *= 0.4
            } else if availableSize.width < 150.0 {
                baseDistance *= 0.6
                baseRowDistance *= 0.6
                baseItemSize *= 0.83
            }
            
            var avatarBackgroundPatternLayerCount = 0
            let lokiRng = LokiRng(seed0: 123, seed1: 0, seed2: 0)
            let numRows = 5
            for row in 0 ..< numRows {
                let avatarPatternCount: Int = 7
                let avatarPatternAngleSpan: CGFloat = CGFloat.pi * 2.0 / CGFloat(avatarPatternCount - 1)
                
                for i in 0 ..< avatarPatternCount - 1 {
                    let baseItemDistance: CGFloat = baseDistance + CGFloat(row) * baseRowDistance
                    
                    let itemDistanceFraction = max(0.0, min(1.0, baseItemDistance / (baseDistance * 2.0)))
                    let itemScaleFraction = patternScaleValueAt(fraction: component.avatarTransitionFraction * 1.6, t: itemDistanceFraction, reverse: false)
                    let itemDistance = baseItemDistance * (1.0 - itemScaleFraction) + 20.0 * itemScaleFraction
                    
                    var itemAngle: CGFloat
                    itemAngle = -CGFloat.pi * 0.5 + CGFloat(i) * avatarPatternAngleSpan
                    if row % 2 != 0 {
                        itemAngle += avatarPatternAngleSpan * 0.5
                    }
                    let itemPosition = CGPoint(x: avatarPatternFrame.width * 0.5 + cos(itemAngle) * itemDistance, y: avatarPatternFrame.height * 0.5 + sin(itemAngle) * itemDistance)
                    
                    var itemScale: CGFloat
                    itemScale = 0.7 + CGFloat(lokiRng.next()) * (1.0 - 0.7)
                    
                    let itemSize: CGFloat = floor(baseItemSize * itemScale)
                    let itemFrame = CGSize(width: itemSize, height: itemSize).centered(around: itemPosition)
                    
                    let itemLayer: SimpleLayer
                    if self.avatarPatternContentLayers.count > avatarBackgroundPatternLayerCount {
                        itemLayer = self.avatarPatternContentLayers[avatarBackgroundPatternLayerCount]
                    } else {
                        itemLayer = SimpleLayer()
                        itemLayer.contents = self.patternContentsTarget?.contents
                        self.avatarBackgroundPatternMaskLayer.addSublayer(itemLayer)
                        self.avatarPatternContentLayers.append(itemLayer)
                    }
                    
                    itemLayer.frame = itemFrame
                    itemLayer.layerTintColor = UIColor(white: 0.0, alpha: 0.8).cgColor
                    transition.setAlpha(layer: itemLayer, alpha: 1.0 - itemScaleFraction)
                    
                    avatarBackgroundPatternLayerCount += 1
                }
            }
            if avatarBackgroundPatternLayerCount > self.avatarPatternContentLayers.count {
                for i in avatarBackgroundPatternLayerCount ..< self.avatarPatternContentLayers.count {
                    self.avatarPatternContentLayers[i].removeFromSuperlayer()
                }
                self.avatarPatternContentLayers.removeSubrange(avatarBackgroundPatternLayerCount ..< self.avatarPatternContentLayers.count)
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
