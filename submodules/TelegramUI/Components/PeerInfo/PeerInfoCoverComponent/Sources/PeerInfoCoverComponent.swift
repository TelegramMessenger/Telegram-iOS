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

private final class PatternContentsTarget: MultiAnimationRenderTarget {
    private let imageUpdated: () -> Void
    
    init(imageUpdated: @escaping () -> Void) {
        self.imageUpdated = imageUpdated
        
        super.init()
    }
    
    required init(coder: NSCoder) {
        preconditionFailure()
    }
    
    override func transitionToContents(_ contents: AnyObject, didLoop: Bool) {
        self.contents = contents
        self.imageUpdated()
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
    public let context: AccountContext
    public let peer: EnginePeer?
    public let avatarCenter: CGPoint
    public let avatarScale: CGFloat
    public let avatarTransitionFraction: CGFloat
    public let patternTransitionFraction: CGFloat
    
    public init(
        context: AccountContext,
        peer: EnginePeer?,
        avatarCenter: CGPoint,
        avatarScale: CGFloat,
        avatarTransitionFraction: CGFloat,
        patternTransitionFraction: CGFloat
    ) {
        self.context = context
        self.peer = peer
        self.avatarCenter = avatarCenter
        self.avatarScale = avatarScale
        self.avatarTransitionFraction = avatarTransitionFraction
        self.patternTransitionFraction = patternTransitionFraction
    }
    
    public static func ==(lhs: PeerInfoCoverComponent, rhs: PeerInfoCoverComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.peer != rhs.peer {
            return false
        }
        if lhs.avatarCenter != rhs.avatarCenter {
            return false
        }
        if lhs.avatarScale != rhs.avatarScale {
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
        private let avatarBackgroundPatternContainer: UIView
        private let avatarBackgroundGradientLayer: SimpleGradientLayer
        private let avatarBackgroundPatternView: UIView
        private let backgroundPatternContainer: UIView
        
        private var component: PeerInfoCoverComponent?
        private var state: EmptyComponentState?
        
        private var patternContentsTarget: PatternContentsTarget?
        private var avatarPatternContentLayers: [SimpleLayer] = []
        private var patternFile: TelegramMediaFile?
        private var patternFileDisposable: Disposable?
        private var patternImage: UIImage?
        private var patternImageDisposable: Disposable?
        
        override public init(frame: CGRect) {
            self.backgroundView = UIView()
            self.avatarBackgroundPatternContainer = UIView()
            self.avatarBackgroundGradientLayer = SimpleGradientLayer()
            self.avatarBackgroundPatternView = UIView()
            self.backgroundPatternContainer = UIView()
            
            super.init(frame: frame)
            
            self.addSubview(self.backgroundView)
            self.addSubview(self.avatarBackgroundPatternContainer)
            self.avatarBackgroundPatternContainer.layer.addSublayer(self.avatarBackgroundGradientLayer)
            self.avatarBackgroundPatternContainer.addSubview(self.avatarBackgroundPatternView)
            
            self.addSubview(self.backgroundPatternContainer)
        }
        
        required public init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.patternFileDisposable?.dispose()
            self.patternImageDisposable?.dispose()
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
            self.patternImageDisposable = component.context.animationRenderer.loadFirstFrame(
                target: patternContentsTarget,
                cache: component.context.animationCache, itemId: "reply-pattern-\(patternFile.fileId)",
                size: CGSize(width: 64, height: 64),
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
                    self.updatePatternLayerImages()
                }
            )
        }
        
        private func updatePatternLayerImages() {
            let image = self.patternContentsTarget?.contents
            for patternContentLayer in self.avatarPatternContentLayers {
                patternContentLayer.contents = image
            }
        }
        
        func update(component: PeerInfoCoverComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            if self.component?.peer?.backgroundEmojiId != component.peer?.backgroundEmojiId {
                if let backgroundEmojiId = component.peer?.backgroundEmojiId, backgroundEmojiId != 0 {
                    if self.patternContentsTarget == nil {
                        self.patternContentsTarget = PatternContentsTarget(imageUpdated: { [weak self] in
                            guard let self else {
                                return
                            }
                            self.updatePatternLayerImages()
                        })
                    }
                    
                    self.patternFile = nil
                    self.patternFileDisposable?.dispose()
                    self.patternFileDisposable = nil
                    self.patternImageDisposable?.dispose()
                    
                    let fileId = backgroundEmojiId
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
                } else {
                    self.patternContentsTarget = nil
                    self.patternFileDisposable?.dispose()
                    self.patternFileDisposable = nil
                    self.patternFile = nil
                }
            }
            
            self.component = component
            self.state = state
            
            let backgroundColor: UIColor
            let patternColor: UIColor
            if let peer = component.peer, let colors = peer._asPeer().nameColor.flatMap({ component.context.peerNameColors.get($0) }) {
                backgroundColor = colors.main.withMultiplied(hue: 1.0, saturation: 0.9, brightness: 0.9)
                patternColor = colors.main.withMultiplied(hue: 1.0, saturation: 1.0, brightness: 0.8).withMultipliedAlpha(0.8)
            } else {
                backgroundColor = .clear
                patternColor = .clear
            }
            
            self.backgroundView.backgroundColor = backgroundColor
            let backgroundFrame = CGRect(origin: CGPoint(x: 0.0, y: -1000.0 + availableSize.height), size: CGSize(width: availableSize.width, height: 1000.0))
            transition.containedViewLayoutTransition.updateFrameAdditive(view: self.backgroundView, frame: backgroundFrame)
            
            let avatarBackgroundPatternContainerFrame = CGSize(width: 0.0, height: 0.0).centered(around: component.avatarCenter)
            transition.containedViewLayoutTransition.updateFrameAdditive(view: self.avatarBackgroundPatternContainer, frame: avatarBackgroundPatternContainerFrame)
            transition.containedViewLayoutTransition.updateSublayerTransformScaleAdditive(layer: self.avatarBackgroundPatternContainer.layer, scale: component.avatarScale)
            //transition.containedViewLayoutTransition.updateAlpha(layer: self.avatarBackgroundPatternContainer.layer, alpha: 1.0 - component.avatarTransitionFraction)
            
            //self.avatarBackgroundPatternView.backgroundColor = .yellow
            transition.setFrame(view: self.avatarBackgroundPatternView, frame: CGSize(width: 200.0, height: 200.0).centered(around: CGPoint()))
            
            
            let baseAvatarGradientAlpha: CGFloat = 0.8
            let numSteps = 10
            self.avatarBackgroundGradientLayer.colors = (0 ..< 10).map { i in
                let step: CGFloat = 1.0 - CGFloat(i) / CGFloat(numSteps - 1)
                return UIColor(white: 1.0, alpha: baseAvatarGradientAlpha * pow(step, 3.0)).cgColor
            }
            self.avatarBackgroundGradientLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
            self.avatarBackgroundGradientLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
            self.avatarBackgroundGradientLayer.type = .radial
            transition.setFrame(layer: self.avatarBackgroundGradientLayer, frame: CGSize(width: 260.0, height: 260.0).centered(around: CGPoint()))
            transition.setAlpha(layer: self.avatarBackgroundGradientLayer, alpha: 1.0 - component.avatarTransitionFraction)
            
            let backgroundPatternContainerFrame = CGRect(origin: CGPoint(x: 0.0, y: availableSize.height), size: CGSize(width: availableSize.width, height: 0.0))
            transition.containedViewLayoutTransition.updateFrameAdditive(view: self.backgroundPatternContainer, frame: backgroundPatternContainerFrame)
            if component.peer?.id == component.context.account.peerId {
                transition.setAlpha(view: self.backgroundPatternContainer, alpha: 0.0)
            } else {
                transition.setAlpha(view: self.backgroundPatternContainer, alpha: component.patternTransitionFraction)
            }
            
            var avatarBackgroundPatternLayerCount = 0
            let lokiRng = LokiRng(seed0: 123, seed1: 0, seed2: 0)
            for row in 0 ..< 4 {
                let avatarPatternCount = row % 2 == 0 ? 9 : 9
                let avatarPatternAngleSpan: CGFloat = CGFloat.pi * 2.0 / CGFloat(avatarPatternCount - 1)
                
                for i in 0 ..< avatarPatternCount - 1 {
                    let baseItemDistance: CGFloat = 72.0 + CGFloat(row) * 28.0
                    
                    let itemDistanceFraction = max(0.0, min(1.0, baseItemDistance / 140.0))
                    let itemScaleFraction = patternScaleValueAt(fraction: component.avatarTransitionFraction, t: itemDistanceFraction, reverse: false)
                    let itemDistance = baseItemDistance * (1.0 - itemScaleFraction) + 20.0 * itemScaleFraction
                    
                    var itemAngle = -CGFloat.pi * 0.5 + CGFloat(i) * avatarPatternAngleSpan
                    if row % 2 != 0 {
                        itemAngle += avatarPatternAngleSpan * 0.5
                    }
                    let itemPosition = CGPoint(x: cos(itemAngle) * itemDistance, y: sin(itemAngle) * itemDistance)
                    
                    let itemScale: CGFloat = 0.7 + CGFloat(lokiRng.next()) * (1.0 - 0.7)
                    let itemSize: CGFloat = floor(26.0 * itemScale)
                    let itemFrame = CGSize(width: itemSize, height: itemSize).centered(around: itemPosition)
                    
                    let itemLayer: SimpleLayer
                    if self.avatarPatternContentLayers.count > avatarBackgroundPatternLayerCount {
                        itemLayer = self.avatarPatternContentLayers[avatarBackgroundPatternLayerCount]
                    } else {
                        itemLayer = SimpleLayer()
                        itemLayer.contents = self.patternContentsTarget?.contents
                        self.avatarBackgroundPatternContainer.layer.addSublayer(itemLayer)
                        self.avatarPatternContentLayers.append(itemLayer)
                    }
                    
                    itemLayer.frame = itemFrame
                    itemLayer.layerTintColor = patternColor.cgColor
                    transition.setAlpha(layer: itemLayer, alpha: (1.0 - CGFloat(row) / 5.0) * (1.0 - itemScaleFraction))
                    
                    avatarBackgroundPatternLayerCount += 1
                }
            }
            if avatarBackgroundPatternLayerCount > self.avatarPatternContentLayers.count {
                for i in avatarBackgroundPatternLayerCount ..< self.avatarPatternContentLayers.count {
                    self.avatarPatternContentLayers[i].removeFromSuperlayer()
                }
                self.avatarPatternContentLayers.removeSubrange(avatarBackgroundPatternLayerCount ..< self.avatarPatternContentLayers.count)
            }
            
            /*let patternSpanX: CGFloat = 82.0
            let patternSpanY: CGFloat = 71.0
            let patternHeight: CGFloat = 86.0
            
            var backgroundPatternCount = 0
            var patternY: CGFloat = -patternHeight
            var patternRowIndex = 0
            while true {
                if patternY >= 50.0 {
                    break
                }
                
                var offsetFromCenter: CGFloat = patternRowIndex % 2 == 0 ? 0.0 : patternSpanX * 0.5
                while true {
                    if offsetFromCenter >= availableSize.width * 0.5 + 50.0 {
                        break
                    }
                    
                    for i in 0 ..< (offsetFromCenter == 0.0 ? 1 : 2) {
                        let itemPosition = CGPoint(x: availableSize.width * 0.5 + (i == 0 ? -1.0 : 1.0) * offsetFromCenter, y: patternY)
                        let itemLayer: SimpleLayer
                        if self.backgroundPatternContentLayers.count > backgroundPatternCount {
                            itemLayer = self.backgroundPatternContentLayers[backgroundPatternCount]
                        } else {
                            itemLayer = SimpleLayer()
                            itemLayer.contents = self.patternContentsTarget?.contents
                            self.backgroundPatternContainer.layer.addSublayer(itemLayer)
                            self.backgroundPatternContentLayers.append(itemLayer)
                        }
                        
                        let itemFrame = CGSize(width: 24.0, height: 24.0).centered(around: itemPosition)
                        itemLayer.frame = itemFrame
                        itemLayer.layerTintColor = patternColor.cgColor
                        
                        backgroundPatternCount += 1
                    }
                    
                    offsetFromCenter += patternSpanX
                }
                patternY += patternSpanY
                patternRowIndex += 1
            }
            if backgroundPatternCount > self.backgroundPatternContentLayers.count {
                for i in backgroundPatternCount ..< self.backgroundPatternContentLayers.count {
                    self.backgroundPatternContentLayers[i].removeFromSuperlayer()
                }
                self.backgroundPatternContentLayers.removeSubrange(backgroundPatternCount ..< self.backgroundPatternContentLayers.count)
            }*/
            
            return availableSize
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
