import Foundation
import UIKit
import Display
import SwiftSignalKit
import ComponentFlow
import TelegramCore
import TelegramPresentationData
import AppBundle
import AccountContext
import EmojiTextAttachmentView
import TextFormat
import PeerInfoCoverComponent
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import EmojiStatusComponent
import UIKitRuntimeUtils

public final class GiftCompositionComponent: Component {
    public class ExternalState {
        public fileprivate(set) var previewPatternColor: UIColor?
        public init() {
            self.previewPatternColor = nil
        }
    }
    
    public enum Subject: Equatable {
        case generic(TelegramMediaFile)
        case unique([StarGift.UniqueGift.Attribute]?, StarGift.UniqueGift)
        case preview([StarGift.UniqueGift.Attribute])
    }
    
    let context: AccountContext
    let theme: PresentationTheme
    let subject: Subject
    let animationOffset: CGPoint?
    let animationScale: CGFloat?
    let displayAnimationStars: Bool
    let revealedAttributes: Set<StarGift.UniqueGift.Attribute.AttributeType>
    let externalState: ExternalState?
    let requestUpdate: (ComponentTransition) -> Void
    
    public init(
        context: AccountContext,
        theme: PresentationTheme,
        subject: Subject,
        animationOffset: CGPoint? = nil,
        animationScale: CGFloat? = nil,
        displayAnimationStars: Bool = false,
        revealedAttributes: Set<StarGift.UniqueGift.Attribute.AttributeType> = Set(),
        externalState: ExternalState? = nil,
        requestUpdate: @escaping (ComponentTransition) -> Void = { _ in }
    ) {
        self.context = context
        self.theme = theme
        self.subject = subject
        self.animationOffset = animationOffset
        self.animationScale = animationScale
        self.displayAnimationStars = displayAnimationStars
        self.revealedAttributes = revealedAttributes
        self.externalState = externalState
        self.requestUpdate = requestUpdate
    }

    public static func ==(lhs: GiftCompositionComponent, rhs: GiftCompositionComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.subject != rhs.subject {
            return false
        }
        if lhs.animationOffset != rhs.animationOffset {
            return false
        }
        if lhs.animationScale != rhs.animationScale {
            return false
        }
        if lhs.displayAnimationStars != rhs.displayAnimationStars {
            return false
        }
        if lhs.revealedAttributes != rhs.revealedAttributes {
            return false
        }
        return true
    }

    public final class View: UIView {
        private var component: GiftCompositionComponent?
        private weak var componentState: EmptyComponentState?
        
        private var starsLayer: StarsEffectLayer?
        
        private let background = ComponentView<Empty>()
        private var animationNode: AnimatedStickerNode?
        
        private var disposables = DisposableSet()
        private var fetchedFiles = Set<Int64>()
        
        private var previewTimer: SwiftSignalKit.Timer?
        
        private var currentFile: TelegramMediaFile?
        private var previewModels: [StarGift.UniqueGift.Attribute] = []
        private var previewBackdrops: [StarGift.UniqueGift.Attribute] = []
        private var previewPatterns: [StarGift.UniqueGift.Attribute] = []
        
        private var previewModelIndex: Int32 = 0
        private var previewBackdropIndex: Int32 = 0
        private var previewPatternIndex: Int32 = 0
        private var animatePreviewTransition = false
        private var animateBackdropSwipe = false
        
        private enum SpinState { case idle, spinning, decelerating, settled }
        private var spinState: SpinState = .idle
        private var spinLink: SharedDisplayLinkDriver.Link?
        private var lastSpawnTime: CFTimeInterval?
        private var lastPatternChangeTime: CFTimeInterval?
        private var lastBackdropChangeTime: CFTimeInterval?
        private var currentInterval: Double = 0.0

        private var deceleraionQueue: [StarGift.UniqueGift.Attribute] = []
        private var decelerationTotalSteps: Int = 0
        private var decelerationStepIndex: Int = 0
        private var decelContainer: UIView?
        private var decelItemHosts: [UIView] = []
        private let decelAnimationKey = "decel.container.move"
        
        private var activeWrappers: [UIView] = []

        private struct SpinGeom {
            var availableSize: CGSize
            var iconSize: CGSize
            var scale: CGFloat
            var centerX: CGFloat
            var centerY: CGFloat
        }
        private var spinGeom: SpinGeom?

        private var spinPool: [StarGift.UniqueGift.Attribute] = []
        private var spinPoolIndex: Int = 0

        private let baseAnimDuration: Double = 0.4
        private let maxAnimDuration:  Double = 1.3
        private let spacingX: CGFloat = 50.0
                
        override init(frame: CGRect) {
            super.init(frame: frame)
            self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.handleTap)))
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.disposables.dispose()
            self.previewTimer?.invalidate()
        }
        
        @objc private func handleTap() {
            guard let animationNode = animationNode as? DefaultAnimatedStickerNodeImpl else { return }
            if case .once = animationNode.playbackMode, !animationNode.isPlaying {
                animationNode.playOnce()
            }
        }
        
        private func stopSpinIfNeeded() {
            self.spinState = .idle
            self.spinLink?.invalidate()
            self.spinLink = nil
            self.lastSpawnTime = nil
            self.currentInterval = 0.0
            self.deceleraionQueue.removeAll()
            self.decelerationTotalSteps = 0
            self.decelerationStepIndex = 0
            self.spinPool.removeAll()
            self.spinPoolIndex = 0
            self.spinGeom = nil

            for wrapper in self.activeWrappers {
                wrapper.layer.removeAllAnimations()
                wrapper.removeFromSuperview()
            }
            self.activeWrappers.removeAll()

            if let c = self.decelContainer {
                c.layer.removeAllAnimations()
                c.removeFromSuperview()
            }
            self.decelContainer = nil
            self.decelItemHosts.removeAll()
        }

        private func ensureDisplayLink() {
            if self.spinLink != nil { return }
            self.spinLink = SharedDisplayLinkDriver.shared.add(framesPerSecond: .max, { [weak self] _ in
                self?.tick()
            })
        }

        private func spawnModelItem(
            _ attribute: StarGift.UniqueGift.Attribute,
            animDuration: Double
        ) {
            guard let geom = self.spinGeom, case let .model(_, file, _) = attribute else {
                return
            }

            let node = DefaultAnimatedStickerNodeImpl()
            node.isUserInteractionEnabled = false
            let pathPrefix = self.component!.context.account.postbox.mediaBox.shortLivedResourceCachePathPrefix(file.resource.id)
            node.setup(
                source: AnimatedStickerResourceSource(account: self.component!.context.account, resource: file.resource, isVideo: file.isVideoSticker),
                width: Int(geom.iconSize.width * 1.6),
                height: Int(geom.iconSize.height * 1.6),
                playbackMode: .still(.start),
                mode: .direct(cachePathPrefix: pathPrefix)
            )
            node.updateLayout(size: geom.iconSize)

            let scaleValue = geom.scale
            let visualSize = CGSize(width: geom.iconSize.width * scaleValue, height: geom.iconSize.height * scaleValue)
            let wrapper = UIView(frame: CGRect(origin: .zero, size: visualSize))
            wrapper.clipsToBounds = false

            let host = node.view
            host.frame = CGRect(origin: .zero, size: geom.iconSize)
            host.layer.bounds = CGRect(origin: .zero, size: geom.iconSize)
            host.layer.position = CGPoint(x: geom.iconSize.width / 2.0, y: geom.iconSize.height / 2.0)
            host.layer.transform = CATransform3DMakeScale(scaleValue, scaleValue, 1.0)
            wrapper.addSubview(host)

            self.addSubview(wrapper)
            self.activeWrappers.append(wrapper)

            let centerY = geom.centerY - visualSize.height / 2.0
            let startX = -visualSize.width * 1.5
            let endX = geom.availableSize.width + visualSize.width

            wrapper.frame.origin = CGPoint(x: endX, y: centerY)

            let travelDistance = abs(startX - endX)
            let pitch = visualSize.width + self.spacingX

            wrapper.layer.animatePosition(
                from: CGPoint(x: -travelDistance, y: 0.0),
                to: .zero,
                duration: animDuration,
                timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue,
                additive: true,
                completion: { [weak self, weak wrapper] _ in
                    if let self, let w = wrapper {
                        self.activeWrappers.removeAll { $0 === w }
                        w.removeFromSuperview()
                    }
                }
            )

            self.currentInterval = Double(pitch / travelDistance) * animDuration * 0.6
        }

        private func finishSettled() {
            guard self.spinState != .settled else { return }
            self.spinState = .settled
            self.spinLink?.invalidate()
            self.spinLink = nil

            for v in self.activeWrappers {
                v.layer.removeAllAnimations()
                v.removeFromSuperview()
            }
            self.activeWrappers.removeAll()
        }

        private func startSpinningUnique(
            availableSize: CGSize,
            iconSize: CGSize,
            scale: CGFloat,
            pool: [StarGift.UniqueGift.Attribute]
        ) {
            self.stopSpinIfNeeded()

            self.spinPool = pool
            self.spinPoolIndex = 0
            let centerY = 88.0 + (self.component?.animationOffset?.y ?? 0.0)

            self.spinGeom = SpinGeom(
                availableSize: availableSize,
                iconSize: iconSize,
                scale: scale,
                centerX: availableSize.width / 2.0 + (self.component?.animationOffset?.x ?? 0.0),
                centerY: centerY
            )

            self.spinState = .spinning
            self.lastSpawnTime = nil
            self.currentInterval = 0
            self.ensureDisplayLink()
        }

        private func beginDecelerationWithQueue(
            tail: [StarGift.UniqueGift.Attribute],
            availableSize: CGSize,
            iconSize: CGSize,
            scale: CGFloat
        ) {
            guard let geom = self.spinGeom, !tail.isEmpty else { return }

            let visualSize = CGSize(width: iconSize.width * scale, height: iconSize.height * scale)
            let pitch = visualSize.width + self.spacingX
            let count = tail.count
            let containerWidth = CGFloat(count) * visualSize.width + CGFloat(max(count - 1, 0)) * self.spacingX
            let containerHeight = visualSize.height

            let container = UIView(frame: CGRect(origin: .zero, size: CGSize(width: containerWidth, height: containerHeight)))
            container.isUserInteractionEnabled = false
            container.clipsToBounds = false

            let containerY = geom.centerY - containerHeight / 2.0
            container.frame.origin.y = containerY
            self.addSubview(container)
            self.decelContainer = container
            self.decelItemHosts.removeAll()
            
            for (i, attribute) in tail.reversed().enumerated() {
                guard case let .model(_, file, _) = attribute else { continue }

                let node = DefaultAnimatedStickerNodeImpl()
                node.isUserInteractionEnabled = false
                let pathPrefix = self.component!.context.account.postbox.mediaBox.shortLivedResourceCachePathPrefix(file.resource.id)
                node.setup(
                    source: AnimatedStickerResourceSource(account: self.component!.context.account, resource: file.resource, isVideo: file.isVideoSticker),
                    width: Int(iconSize.width * 1.6),
                    height: Int(iconSize.height * 1.6),
                    playbackMode: .still(.start),
                    mode: .direct(cachePathPrefix: pathPrefix)
                )
                node.updateLayout(size: iconSize)
                node.visibility = true
                if i < 4 {
                    node.playOnce();
                }
                
                let host = node.view
                host.bounds = CGRect(origin: .zero, size: iconSize)
                host.layer.transform = CATransform3DMakeScale(scale, scale, 1.0)

                let hostView = UIView(frame: CGRect(origin: CGPoint(x: CGFloat(i) * pitch, y: 0), size: visualSize))
                host.center = CGPoint(x: visualSize.width / 2.0, y: visualSize.height / 2.0)
                hostView.addSubview(host)
                container.addSubview(hostView)
                self.decelItemHosts.append(hostView)

                if i == 0 {
                    self.animationNode = node
                    
                    let factors: [CGFloat] = [1.0, 1.3, 0.92, 1.18, 0.98, 1.0]
                    let values = factors.map { NSNumber(value: Double($0)) }
                    let scaleAnim = CAKeyframeAnimation(keyPath: "transform.scale")
                    scaleAnim.beginTime = CACurrentMediaTime() + 0.6
                    scaleAnim.values = values
                    scaleAnim.keyTimes = [0.0, 0.35, 0.55, 0.75, 0.9, 1.0].map(NSNumber.init)
                    scaleAnim.timingFunctions = [
                        CAMediaTimingFunction(name: .easeOut),
                        CAMediaTimingFunction(name: .easeIn),
                        CAMediaTimingFunction(name: .easeOut),
                        CAMediaTimingFunction(name: .easeIn),
                        CAMediaTimingFunction(name: .easeOut)
                    ]
                    scaleAnim.duration = 0.85
                    scaleAnim.isRemovedOnCompletion = true
                    host.layer.add(scaleAnim, forKey: "bounce")
                }
                
                if i == 1 {
                    hostView.alpha = 0.0
                    hostView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, delay: 0.7)
                }
            }
            
            container.frame.origin.x = floor((availableSize.width - visualSize.width) / 2.0)

            container.layer.animatePosition(
                from: CGPoint(x: -containerWidth - visualSize.width * 0.5 + containerWidth / 2.0 - self.spacingX - 120.0, y: container.frame.center.y),
                to: CGPoint(x: container.frame.center.x, y: container.frame.center.y),
                duration: self.maxAnimDuration,
                delay: 0.05,
                timingFunction: kCAMediaTimingFunctionSpring,
                completion: { [weak self] _ in
                    guard let self, let container = self.decelContainer else {
                        return
                    }
                    let _ = container
                    //self.handleDecelArrived(container: container, iconSize: iconSize, visualSize: visualSize)
                }
            )

            self.spinState = .decelerating
            self.ensureDisplayLink()
        }

        private func handleDecelArrived(container: UIView, iconSize: CGSize, visualSize: CGSize) {
            let isFinalIndex = self.decelItemHosts.count - 1
            guard isFinalIndex >= 0, let finalHostView = self.decelItemHosts.last else { return }

            guard let node = self.animationNode as? DefaultAnimatedStickerNodeImpl else { return }
            node.playbackMode = .once
            node.visibility = true

            let finalCenterInSelf = container.convert(finalHostView.center, to: self)

            let host = node.view
            if host.superview !== self { self.addSubview(host) }
            node.updateLayout(size: iconSize)
            host.bounds = CGRect(origin: .zero, size: iconSize)
            host.layer.position = finalCenterInSelf

            container.removeFromSuperview()
            self.decelContainer = nil
            self.decelItemHosts.removeAll()
            
            let factors: [CGFloat] = [1.0, 1.3, 0.92, 1.18, 0.98, 1.0]
            let values = factors.map { NSNumber(value: Double($0)) }
            let scaleAnim = CAKeyframeAnimation(keyPath: "transform.scale")
            scaleAnim.values = values
            scaleAnim.keyTimes = [0.0, 0.35, 0.55, 0.75, 0.9, 1.0].map(NSNumber.init)
            scaleAnim.timingFunctions = [
                CAMediaTimingFunction(name: .easeOut),
                CAMediaTimingFunction(name: .easeIn),
                CAMediaTimingFunction(name: .easeOut),
                CAMediaTimingFunction(name: .easeIn),
                CAMediaTimingFunction(name: .easeOut)
            ]
            scaleAnim.duration = 0.85
            scaleAnim.isRemovedOnCompletion = true
            host.layer.add(scaleAnim, forKey: "bounce")

            node.playOnce()
            self.finishSettled()
        }

        private func tick() {
            guard let component = self.component else { return }
            let now = CACurrentMediaTime()

            switch self.spinState {
            case .spinning:
                if self.lastSpawnTime == nil || now - (self.lastSpawnTime ?? now) >= self.currentInterval {
                    self.lastSpawnTime = now

                    guard !self.spinPool.isEmpty else { return }

                    if self.spinPoolIndex >= self.spinPool.count { self.spinPoolIndex = 0 }
                    let next = self.spinPool[self.spinPoolIndex]
                    self.spinPoolIndex += 1

                    self.spawnModelItem(next, animDuration: self.baseAnimDuration)
                }
                
                var updateNeeded = false
                if self.lastPatternChangeTime == nil || now - (self.lastPatternChangeTime ?? now) >= self.currentInterval * 6.0 {
                    self.lastPatternChangeTime = now
                    
                    if component.revealedAttributes.contains(.pattern) {
                        if self.previewPatternIndex != -1 {
                            self.previewPatternIndex = -1
                            self.animatePreviewTransition = true
                            updateNeeded = true
                        }
                    } else {
                        let previousPatternIndex = self.previewPatternIndex
                        var randomPatternIndex = previousPatternIndex
                        while randomPatternIndex == previousPatternIndex && !self.previewPatterns.isEmpty {
                            randomPatternIndex = Int32.random(in: 0 ..< Int32(self.previewPatterns.count))
                        }
                        if !self.previewPatterns.isEmpty { self.previewPatternIndex = randomPatternIndex }
                        
                        self.animatePreviewTransition = true
                        updateNeeded = true
                    }
                }
                if self.lastBackdropChangeTime == nil || now - (self.lastBackdropChangeTime ?? now) >= self.currentInterval * 3.55 {
                    self.lastBackdropChangeTime = now
                    
                    if component.revealedAttributes.contains(.backdrop) {
                        if self.previewBackdropIndex != -1 {
                            self.previewBackdropIndex = -1
                            self.animateBackdropSwipe = true
                            updateNeeded = true
                        }
                    } else {
                        let previousBackdropIndex = self.previewBackdropIndex
                        var randomBackdropIndex = previousBackdropIndex
                        while randomBackdropIndex == previousBackdropIndex && !self.previewBackdrops.isEmpty {
                            randomBackdropIndex = Int32.random(in: 0 ..< Int32(self.previewBackdrops.count))
                        }
                        if !self.previewBackdrops.isEmpty { self.previewBackdropIndex = randomBackdropIndex }
                        
                        self.animateBackdropSwipe = true
                        updateNeeded = true
                    }
                }
                
                if updateNeeded {
                    self.componentState?.updated(transition: .easeInOut(duration: 0.25))
                    self.component?.requestUpdate(.easeInOut(duration: 0.25))
                }
                self.applyEdge3DHorizontal()
            case .decelerating:
                self.applyEdge3DHorizontal()
            case .idle, .settled:
                self.spinLink?.invalidate()
                self.spinLink = nil
            }
        }
        
        private let minScaleAtEdgeX: CGFloat = 0.7
        private let yawAtEdgeDegrees: CGFloat = 25.0
        private let edgeFalloffX: CGFloat = 0.25

        @inline(__always)
        private func smoothstep01(_ x: CGFloat) -> CGFloat {
            let t = max(0.0, min(1.0, x))
            return t * t * (3.0 - 2.0 * t)
        }

        @inline(__always)
        private func liveMidX(in container: UIView, of view: UIView) -> CGFloat {
            if let pres = view.layer.presentation() {
                let p = container.layer.convert(pres.position, from: view.layer.superlayer)
                return p.x
            }
            return view.center.x
        }
        
        @inline(__always)
        private func midXInsideAnimatedContainer(in selfView: UIView, container: UIView, hostView: UIView) -> CGFloat {
            let contPres = container.layer.presentation() ?? container.layer
            let hostPres = hostView.layer.presentation() ?? hostView.layer
            
            let hostOffsetFromContainerCenter = hostPres.position.x - container.bounds.midX
            return contPres.position.x + hostOffsetFromContainerCenter
        }

        private func edge3DTransformFor(midX: CGFloat, containerWidth: CGFloat, baseScale: CGFloat = 1.0) -> CATransform3D {
            guard containerWidth > 0 else {
                return CATransform3DMakeScale(baseScale, baseScale, 1.0)
            }
            let d = abs((midX - containerWidth * 0.5) / (containerWidth * 0.5))
            
            let uRaw = (d - edgeFalloffX) / (1.0 - edgeFalloffX)
            let u = smoothstep01(max(0.0, min(1.0, uRaw)))
        
            let scale = (1.0 - u) * baseScale + (minScaleAtEdgeX * baseScale) * u
            let yawSign: CGFloat = (midX < containerWidth * 0.5) ? 1.0 : -1.0
            let yawRadians = (yawAtEdgeDegrees * .pi / 180.0) * u * yawSign
            
            var t = CATransform3DIdentity
            t = CATransform3DRotate(t, yawRadians, 0.0, 1.0, 0.0)
            t = CATransform3DScale(t, scale, scale, 1.0)
            return t
        }
        
        private func applyEdge3DHorizontal() {
            let containerWidth = self.bounds.width
            guard containerWidth > 0.0 else { return }

            CATransaction.begin()
            CATransaction.setDisableActions(true)

            for w in self.activeWrappers {
                guard w.superview === self else { continue }
                let midX = liveMidX(in: self, of: w)
                if let host = w.subviews.first {
                    let baseScale = max(0.01, w.bounds.width / max(host.bounds.width, 0.01))
                    host.layer.transform = edge3DTransformFor(midX: midX, containerWidth: containerWidth, baseScale: baseScale)
                }
            }

            for hostView in self.decelItemHosts {
                guard let container = self.decelContainer, hostView.superview === container && hostView !== self.decelItemHosts.first else {
                    continue
                }
                let midX = midXInsideAnimatedContainer(in: self, container: container, hostView: hostView)
                if let host = hostView.subviews.first {
                    let baseScale = max(0.01, hostView.bounds.width / max(host.bounds.width, 0.01))
                    host.layer.transform = edge3DTransformFor(midX: midX, containerWidth: containerWidth, baseScale: baseScale)
                }
            }

            CATransaction.commit()
        }
        
        public func update(component: GiftCompositionComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let previousComponent = self.component
            
            self.component = component
            self.componentState = state
            
            var animationFile: TelegramMediaFile?
            var backgroundColor: UIColor?
            var secondBackgroundColor: UIColor?
            var patternColor: UIColor?
            var patternFile: TelegramMediaFile?
            var files: [Int64: TelegramMediaFile] = [:]
                        
            var loop = false
            
            var uniqueSpinContext: (previewAttributes: [StarGift.UniqueGift.Attribute], mainGift: StarGift.UniqueGift)? = nil
            
            switch component.subject {
            case let .generic(file):
                animationFile = file
                self.currentFile = file
                self.stopSpinIfNeeded()
                
                if let previewTimer = self.previewTimer {
                    previewTimer.invalidate()
                    self.previewTimer = nil
                }
                if !self.fetchedFiles.contains(file.fileId.id) {
                    self.disposables.add(freeMediaFileResourceInteractiveFetched(account: component.context.account, userLocation: .other, fileReference: .standalone(media: file), resource: file.resource).start())
                    self.fetchedFiles.insert(file.fileId.id)
                }
                
            case let .unique(previewAttributesOpt, gift):
                if let previewTimer = self.previewTimer {
                    previewTimer.invalidate()
                    self.previewTimer = nil
                }

                for attribute in gift.attributes {
                    switch attribute {
                    case let .model(_, file, _):
                        animationFile = file
                        if !self.fetchedFiles.contains(file.fileId.id) {
                            self.disposables.add(freeMediaFileResourceInteractiveFetched(account: component.context.account, userLocation: .other, fileReference: .standalone(media: file), resource: file.resource).start())
                            self.fetchedFiles.insert(file.fileId.id)
                        }
                    case let .pattern(_, file, _):
                        patternFile = file
                        files[file.fileId.id] = file
                    case let .backdrop(_, _, innerColorValue, outerColorValue, patternColorValue, _, _):
                        backgroundColor = UIColor(rgb: UInt32(bitPattern: outerColorValue))
                        secondBackgroundColor = UIColor(rgb: UInt32(bitPattern: innerColorValue))
                        patternColor = UIColor(rgb: UInt32(bitPattern: patternColorValue))
                    default:
                        break
                    }
                }
                if let previewAttributes = previewAttributesOpt, !previewAttributes.isEmpty {
                    if self.previewPatternIndex != -1, case let .pattern(_, file, _) = self.previewPatterns[Int(self.previewPatternIndex)] {
                        patternFile = file
                        files[file.fileId.id] = file
                    }
                    if self.previewBackdropIndex != -1, case let .backdrop(_, _, innerColorValue, outerColorValue, patternColorValue, _, _) = self.previewBackdrops[Int(self.previewBackdropIndex)] {
                        backgroundColor = UIColor(rgb: UInt32(bitPattern: outerColorValue))
                        secondBackgroundColor = UIColor(rgb: UInt32(bitPattern: innerColorValue))
                        patternColor = UIColor(rgb: UInt32(bitPattern: patternColorValue))
                    }
                    uniqueSpinContext = (previewAttributes, gift)
                } else {
                    self.stopSpinIfNeeded()
                }
            case let .preview(sampleAttributes):
                loop = true
                self.stopSpinIfNeeded()
                
                if self.previewModels.isEmpty {
                    var models: [StarGift.UniqueGift.Attribute] = []
                    var patterns: [StarGift.UniqueGift.Attribute] = []
                    var backdrops: [StarGift.UniqueGift.Attribute] = []
                    for attribute in sampleAttributes {
                        switch attribute {
                        case .model:   models.append(attribute)
                        case .pattern: patterns.append(attribute)
                        case .backdrop: backdrops.append(attribute)
                        default: break
                        }
                    }
                    self.previewModels = models
                    self.previewPatterns = patterns
                    self.previewBackdrops = backdrops
                }
                
                for case let .model(_, file, _) in self.previewModels where !self.fetchedFiles.contains(file.fileId.id) {
                    self.disposables.add(freeMediaFileResourceInteractiveFetched(account: component.context.account, userLocation: .other, fileReference: .standalone(media: file), resource: file.resource).start())
                    self.fetchedFiles.insert(file.fileId.id)
                }
                
                for case let .pattern(_, file, _) in self.previewPatterns where !self.fetchedFiles.contains(file.fileId.id) {
                    self.disposables.add(freeMediaFileResourceInteractiveFetched(account: component.context.account, userLocation: .other, fileReference: .standalone(media: file), resource: file.resource).start())
                    self.fetchedFiles.insert(file.fileId.id)
                }
                
                if !self.previewModels.isEmpty {
                    if self.previewPatternIndex < 0 {
                        self.previewPatternIndex = 0
                    }
                    if self.previewBackdropIndex < 0 {
                        self.previewBackdropIndex = 0
                    }
                    if case let .model(_, file, _) = self.previewModels[Int(self.previewModelIndex)] {
                        animationFile = file
                    }
                    if case let .pattern(_, file, _) = self.previewPatterns[Int(self.previewPatternIndex)] {
                        patternFile = file
                        files[file.fileId.id] = file
                    }
                    if case let .backdrop(_, _, innerColorValue, outerColorValue, patternColorValue, _, _) = self.previewBackdrops[Int(self.previewBackdropIndex)] {
                        backgroundColor = UIColor(rgb: UInt32(bitPattern: outerColorValue))
                        secondBackgroundColor = UIColor(rgb: UInt32(bitPattern: innerColorValue))
                        patternColor = UIColor(rgb: UInt32(bitPattern: patternColorValue))
                    }
                }
                
                if self.previewTimer == nil {
                    self.previewTimer = SwiftSignalKit.Timer(timeout: 2.0, repeat: true, completion: { [weak self] in
                        guard let self, !self.previewModels.isEmpty else { return }
                        self.previewModelIndex = (self.previewModelIndex + 1) % Int32(self.previewModels.count)
                        
                        let previousPatternIndex = self.previewPatternIndex
                        var randomPatternIndex = previousPatternIndex
                        while randomPatternIndex == previousPatternIndex && !self.previewPatterns.isEmpty {
                            randomPatternIndex = Int32.random(in: 0 ..< Int32(self.previewPatterns.count))
                        }
                        if !self.previewPatterns.isEmpty { self.previewPatternIndex = randomPatternIndex }
                        
                        let previousBackdropIndex = self.previewBackdropIndex
                        var randomBackdropIndex = previousBackdropIndex
                        while randomBackdropIndex == previousBackdropIndex && !self.previewBackdrops.isEmpty {
                            randomBackdropIndex = Int32.random(in: 0 ..< Int32(self.previewBackdrops.count))
                        }
                        if !self.previewBackdrops.isEmpty { self.previewBackdropIndex = randomBackdropIndex }
                        
                        self.animatePreviewTransition = true
                        self.componentState?.updated(transition: .easeInOut(duration: 0.25))
                        self.component?.requestUpdate(.easeInOut(duration: 0.25))
                    }, queue: Queue.mainQueue())
                    self.previewTimer?.start()
                }
            }
            
            component.externalState?.previewPatternColor = secondBackgroundColor
            
            var animateBackdropSwipe = false
            if self.animateBackdropSwipe {
                animateBackdropSwipe = true
                self.animateBackdropSwipe = false
            }
            
            var animateTransition = false
            if self.animatePreviewTransition {
                animateTransition = true
                self.animatePreviewTransition = false
            } else if let previousComponent, case .preview = previousComponent.subject, case .unique = component.subject {
                animateTransition = true
            } else if let previousComponent, case .generic = previousComponent.subject, case .preview = component.subject {
                animateTransition = true
            } else if let previousComponent, case .preview = previousComponent.subject, case .generic = component.subject {
                animateTransition = true
            }
            
            if let backgroundColor {
                var backgroundTransition = transition
                if let backgroundView = self.background.view as? PeerInfoCoverComponent.View {
                    if animateTransition {
                        var bounce = true
                        var background = true
                        if case .unique = component.subject {
                            bounce = self.previewPatternIndex == -1
                            background = false
                        }
                        backgroundView.animateTransition(background: background, bounce: bounce)
                    }
                    if animateBackdropSwipe {
                        backgroundView.animateSwipeTransition()
                    }
                }
                var avatarCenter = CGPoint(x: availableSize.width / 2.0, y: 104.0)
                if let _ = component.animationScale {
                    avatarCenter = CGPoint(x: avatarCenter.x, y: 67.0)
                }
                let _ = self.background.update(
                    transition: backgroundTransition,
                    component: AnyComponent(PeerInfoCoverComponent(
                        context: component.context,
                        subject: .custom(backgroundColor, secondBackgroundColor, patternColor, patternFile?.fileId.id),
                        files: files,
                        isDark: false,
                        avatarCenter: avatarCenter,
                        avatarScale: 1.0,
                        defaultHeight: 300.0,
                        gradientOnTop: true,
                        avatarTransitionFraction: 0.0,
                        patternTransitionFraction: 0.0
                    )),
                    environment: {},
                    containerSize: availableSize
                )
                if let backgroundView = self.background.view {
                    if backgroundView.superview == nil {
                        backgroundTransition = .immediate
                        backgroundView.clipsToBounds = true
                        backgroundView.isUserInteractionEnabled = false
                        self.insertSubview(backgroundView, at: 0)
                        if previousComponent != nil {
                            backgroundView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                        }
                    }
                    backgroundTransition.setFrame(view: backgroundView, frame: CGRect(origin: .zero, size: availableSize))
                }
            } else if let backgroundView = self.background.view, backgroundView.superview != nil {
                backgroundView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { _ in
                    backgroundView.removeFromSuperview()
                })
            }
            
            let iconSize = CGSize(width: 136.0, height: 136.0)
            
            if let (previewAttributes, mainGift) = uniqueSpinContext {
                var mainModelFile: TelegramMediaFile?
                for attribute in mainGift.attributes {
                    if case let .model(_, file, _) = attribute { mainModelFile = file; break }
                }

                var models: [StarGift.UniqueGift.Attribute] = []
                for attribute in previewAttributes {
                    if case let .model(_, file, _) = attribute,
                       file.fileId.id != mainModelFile?.fileId.id {
                        models.append(attribute)
                    }
                }

                if models.isEmpty, let _ = mainModelFile {
                    return availableSize
                }

                for case let .model(_, file, _) in models where !self.fetchedFiles.contains(file.fileId.id) {
                    self.disposables.add(freeMediaFileResourceInteractiveFetched(
                        account: component.context.account,
                        userLocation: .other,
                        fileReference: .standalone(media: file),
                        resource: file.resource
                    ).start())
                    self.fetchedFiles.insert(file.fileId.id)
                }
                if let mainModelFile, !self.fetchedFiles.contains(mainModelFile.fileId.id) {
                    self.disposables.add(freeMediaFileResourceInteractiveFetched(
                        account: component.context.account,
                        userLocation: .other,
                        fileReference: .standalone(media: mainModelFile),
                        resource: mainModelFile.resource
                    ).start())
                    self.fetchedFiles.insert(mainModelFile.fileId.id)
                }
                
                let wasAnimatingModel = previousComponent != nil && !(previousComponent!.revealedAttributes.contains(.model))
                let isAnimatingModel = !component.revealedAttributes.contains(.model)
                
                let wasAnimating = wasAnimatingModel
                let nowAnimating = isAnimatingModel

                if nowAnimating {
                    if let disappearing = self.animationNode {
                        self.animationNode = nil
                        disappearing.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.12, removeOnCompletion: false, completion: { _ in
                            disappearing.view.removeFromSuperview()
                        })
                    }
                }

                let scaleValue: CGFloat = component.animationScale ?? 1.0

                if nowAnimating && (!wasAnimating || self.spinState != .spinning) {
                    self.startSpinningUnique(
                        availableSize: availableSize,
                        iconSize: iconSize,
                        scale: scaleValue,
                        pool: models
                    )
                } else if !nowAnimating && wasAnimating {
                    var tail = Array(models.shuffled().prefix(6))
                    if let mainModelFile {
                        tail.append(.model(name: "", file: mainModelFile, rarity: 0))
                    }
                    self.beginDecelerationWithQueue(
                        tail: tail,
                        availableSize: availableSize,
                        iconSize: iconSize,
                        scale: scaleValue
                    )
                } else if self.spinState == .spinning {
                    let centerY = 88.0 + (component.animationOffset?.y ?? 0.0)
                    self.spinGeom = SpinGeom(
                        availableSize: availableSize,
                        iconSize: iconSize,
                        scale: scaleValue,
                        centerX: availableSize.width / 2.0 + (component.animationOffset?.x ?? 0.0),
                        centerY: centerY
                    )
                }

                return availableSize
            }

            if self.spinState != .idle && self.spinState != .settled {
                self.stopSpinIfNeeded()
            }
            
            var startFromIndex: Int?
            var animationTransition = transition
            if animateTransition, let disappearingAnimationNode = self.animationNode {
                self.animationNode = nil
                startFromIndex = disappearingAnimationNode.currentFrameIndex
                disappearingAnimationNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { _ in
                    disappearingAnimationNode.view.removeFromSuperview()
                })
                animationTransition = .immediate
            }
            
            if let file = animationFile, self.animationNode == nil {
                animationTransition = .immediate
                let node = DefaultAnimatedStickerNodeImpl()
                node.isUserInteractionEnabled = false
                self.animationNode = node
                self.addSubview(node.view)
                let pathPrefix = component.context.account.postbox.mediaBox.shortLivedResourceCachePathPrefix(file.resource.id)
                node.setup(source: AnimatedStickerResourceSource(account: component.context.account, resource: file.resource, isVideo: file.isVideoSticker),
                           width: Int(iconSize.width * 1.6), height: Int(iconSize.height * 1.6),
                           playbackMode: loop ? .loop : .once,
                           mode: .direct(cachePathPrefix: pathPrefix))
                if let startFromIndex {
                    node.play(firstFrame: false, fromIndex: startFromIndex)
                } else {
                    if loop { node.playLoop() } else { node.playOnce() }
                }
                node.visibility = true
                node.updateLayout(size: iconSize)
                if animateTransition {
                    node.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                }
            }
            
            if let animationNode = self.animationNode {
                let offset = component.animationOffset ?? .zero
                var size = CGSize(width: iconSize.width, height: iconSize.height)
                if let scale = component.animationScale {
                    size = CGSize(width: size.width * scale, height: size.height * scale)
                }
                let animationFrame = CGRect(
                    origin: CGPoint(x: availableSize.width / 2.0 + offset.x - size.width / 2.0, y: 88.0 + offset.y - size.height / 2.0),
                    size: size
                )
                animationNode.layer.bounds = CGRect(origin: .zero, size: iconSize)
                animationTransition.setPosition(layer: animationNode.layer, position: animationFrame.center)
                animationTransition.setScale(layer: animationNode.layer, scale: size.width / iconSize.width)
                
                if component.displayAnimationStars {
                    var starsTransition = transition
                    let starsLayer: StarsEffectLayer
                    if let current = self.starsLayer {
                        starsLayer = current
                    } else {
                        starsTransition = .immediate
                        starsLayer = StarsEffectLayer()
                        self.layer.insertSublayer(starsLayer, below: animationNode.layer)
                        self.starsLayer = starsLayer
                        starsLayer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                    }
                    let starsSize = CGSize(width: 36.0, height: 36.0)
                    starsLayer.update(color: .white, size: starsSize)
                    starsLayer.bounds = CGRect(origin: .zero, size: starsSize)
                    starsTransition.setPosition(layer: starsLayer, position: animationFrame.center)
                } else if let starsLayer = self.starsLayer {
                    self.starsLayer = nil
                    transition.setPosition(layer: starsLayer, position: animationFrame.center)
                    starsLayer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { _ in
                        starsLayer.removeFromSuperlayer()
                    })
                }
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

private final class StarsEffectLayer: SimpleLayer {
    private let emitterLayer = CAEmitterLayer()
    
    override init() {
        super.init()
        self.addSublayer(self.emitterLayer)
    }
    
    override init(layer: Any) {
        super.init(layer: layer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setup(color: UIColor) {
        let emitter = CAEmitterCell()
        emitter.name = "emitter"
        emitter.contents = UIImage(bundleImageName: "Premium/Stars/Particle")?.cgImage
        emitter.birthRate = 8.0
        emitter.lifetime = 2.0
        emitter.velocity = 0.1
        emitter.scale = 0.12
        emitter.scaleRange = 0.02
        emitter.alphaRange = 0.1
        emitter.emissionRange = .pi * 2.0
        
        let staticColors: [Any] = [
            color.withAlphaComponent(0.0).cgColor,
            color.withAlphaComponent(0.55).cgColor,
            color.withAlphaComponent(0.55).cgColor,
            color.withAlphaComponent(0.0).cgColor
        ]
        let staticColorBehavior = CAEmitterCell.createEmitterBehavior(type: "colorOverLife")
        staticColorBehavior.setValue(staticColors, forKey: "colors")
        emitter.setValue([staticColorBehavior], forKey: "emitterBehaviors")
        self.emitterLayer.emitterCells = [emitter]
    }
    
    func update(color: UIColor, size: CGSize) {
        if self.emitterLayer.emitterCells == nil {
            self.setup(color: color)
        }
        self.emitterLayer.emitterShape = .circle
        self.emitterLayer.emitterSize = size
        self.emitterLayer.emitterMode = .surface
        self.emitterLayer.frame = CGRect(origin: .zero, size: size)
        self.emitterLayer.emitterPosition = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
    }
}
