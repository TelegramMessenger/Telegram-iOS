import Foundation
import UIKit
import Display
import ComponentFlow
import MetalEngine
import SwiftSignalKit

private let shadowImage: UIImage? = {
    UIImage(named: "Call/VideoGradient")?.precomposed()
}()

public func resolveCallVideoRotationAngle(angle: Float, followsDeviceOrientation: Bool, interfaceOrientation: UIInterfaceOrientation) -> Float {
    if !followsDeviceOrientation {
        return angle
    }
    let interfaceAngle: Float
    switch interfaceOrientation {
    case .portrait, .unknown:
        interfaceAngle = 0.0
    case .landscapeLeft:
        interfaceAngle = Float.pi * 0.5
    case .landscapeRight:
        interfaceAngle = Float.pi * 3.0 / 2.0
    case .portraitUpsideDown:
        interfaceAngle = Float.pi
    @unknown default:
        interfaceAngle = 0.0
    }
    return (angle + interfaceAngle).truncatingRemainder(dividingBy: Float.pi * 2.0)
}

final class VideoContainerLayer: SimpleLayer {
    let contentsLayer: SimpleLayer
    
    override init() {
        self.contentsLayer = SimpleLayer()
        
        super.init()
        
        self.addSublayer(self.contentsLayer)
    }
    
    override init(layer: Any) {
        self.contentsLayer = SimpleLayer()
        
        super.init(layer: layer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(size: CGSize, transition: ComponentTransition) {
        transition.setFrame(layer: self.contentsLayer, frame: CGRect(origin: CGPoint(), size: size))
    }
}

final class VideoContainerView: HighlightTrackingButton {
    enum Key {
        case background
        case foreground
    }
    
    private struct Params: Equatable {
        var size: CGSize
        var insets: UIEdgeInsets
        var interfaceOrientation: UIInterfaceOrientation
        var cornerRadius: CGFloat
        var controlsHidden: Bool
        var isMinimized: Bool
        var isAnimatedOut: Bool
        
        init(size: CGSize, insets: UIEdgeInsets, interfaceOrientation: UIInterfaceOrientation, cornerRadius: CGFloat, controlsHidden: Bool, isMinimized: Bool, isAnimatedOut: Bool) {
            self.size = size
            self.insets = insets
            self.interfaceOrientation = interfaceOrientation
            self.cornerRadius = cornerRadius
            self.controlsHidden = controlsHidden
            self.isMinimized = isMinimized
            self.isAnimatedOut = isAnimatedOut
        }
    }
    
    struct VideoMetrics: Equatable {
        var resolution: CGSize
        var rotationAngle: Float
        var followsDeviceOrientation: Bool
        var sourceId: Int
        
        init(resolution: CGSize, rotationAngle: Float, followsDeviceOrientation: Bool, sourceId: Int) {
            self.resolution = resolution
            self.rotationAngle = rotationAngle
            self.followsDeviceOrientation = followsDeviceOrientation
            self.sourceId = sourceId
        }
    }
    
    private final class FlipAnimationInfo {
        let isForward: Bool
        let previousRotationAngle: Float
        let followsDeviceOrientation: Bool
        
        init(isForward: Bool, previousRotationAngle: Float, followsDeviceOrientation: Bool) {
            self.isForward = isForward
            self.previousRotationAngle = previousRotationAngle
            self.followsDeviceOrientation = followsDeviceOrientation
        }
    }
    
    private final class DisappearingVideo {
        let flipAnimationInfo: FlipAnimationInfo?
        let videoLayer: PrivateCallVideoLayer
        let videoMetrics: VideoMetrics
        var isAlphaAnimationInitiated: Bool = false
        
        init(flipAnimationInfo: FlipAnimationInfo?, videoLayer: PrivateCallVideoLayer, videoMetrics: VideoMetrics) {
            self.flipAnimationInfo = flipAnimationInfo
            self.videoLayer = videoLayer
            self.videoMetrics = videoMetrics
        }
    }
    
    private enum MinimizedPosition: CaseIterable {
        case topLeft
        case topRight
        case bottomLeft
        case bottomRight
    }
    
    let key: Key
    
    let videoContainerLayer: VideoContainerLayer
    var videoContainerLayerTaken: Bool = false
    
    private var videoLayer: PrivateCallVideoLayer
    private var disappearingVideoLayer: DisappearingVideo?
    
    var currentVideoOutput: VideoSource.Output? {
        return self.videoLayer.video
    }
    
    let blurredContainerLayer: SimpleLayer
    
    private let shadowContainer: SimpleLayer
    private let topShadowLayer: SimpleLayer
    private let bottomShadowLayer: SimpleLayer
    
    private var params: Params?
    private var videoMetrics: VideoMetrics?
    private var appliedVideoMetrics: VideoMetrics?
    
    private var highlightedState: Bool = false
    
    private(set) var isFillingBounds: Bool = false
    
    private var minimizedPosition: MinimizedPosition = .bottomRight
    private var initialDragPosition: CGPoint?
    private var dragPosition: CGPoint?
    private var dragVelocity: CGPoint = CGPoint()
    private var dragPositionAnimatorLink: SharedDisplayLinkDriver.Link?
    
    private var videoOnUpdatedListener: Disposable?
    var video: VideoSource? {
        didSet {
            if self.video !== oldValue {
                self.videoOnUpdatedListener?.dispose()
                
                self.videoOnUpdatedListener = self.video?.addOnUpdated { [weak self] in
                    guard let self else {
                        return
                    }
                    var videoMetrics: VideoMetrics?
                    if let currentOutput = self.video?.currentOutput {
                        if let previousVideo = self.videoLayer.video, previousVideo.sourceId != currentOutput.sourceId {
                            self.initiateVideoSourceSwitch(flipAnimationInfo: FlipAnimationInfo(isForward: previousVideo.sourceId < currentOutput.sourceId, previousRotationAngle: previousVideo.rotationAngle, followsDeviceOrientation: previousVideo.followsDeviceOrientation))
                        }
                        
                        self.videoLayer.video = currentOutput
                        videoMetrics = VideoMetrics(resolution: currentOutput.resolution, rotationAngle: currentOutput.rotationAngle, followsDeviceOrientation: currentOutput.followsDeviceOrientation, sourceId: currentOutput.sourceId)
                    } else {
                        self.videoLayer.video = nil
                    }
                    self.videoLayer.setNeedsUpdate()
                    
                    if self.videoMetrics != videoMetrics {
                        self.videoMetrics = videoMetrics
                        self.update(transition: .easeInOut(duration: 0.2))
                    }
                }
                
                if oldValue != nil {
                    self.initiateVideoSourceSwitch(flipAnimationInfo: nil)
                }
                
                var videoMetrics: VideoMetrics?
                if let currentOutput = self.video?.currentOutput {
                    self.videoLayer.video = currentOutput
                    videoMetrics = VideoMetrics(resolution: currentOutput.resolution, rotationAngle: currentOutput.rotationAngle, followsDeviceOrientation: currentOutput.followsDeviceOrientation, sourceId: currentOutput.sourceId)
                } else {
                    self.videoLayer.video = nil
                }
                self.videoLayer.setNeedsUpdate()
                
                if self.videoMetrics != videoMetrics || oldValue != nil {
                    self.videoMetrics = videoMetrics
                    self.update(transition: .easeInOut(duration: 0.2))
                }
            }
        }
    }
    
    var pressAction: (() -> Void)?
    
    init(key: Key) {
        self.key = key
        
        self.videoContainerLayer = VideoContainerLayer()
        self.videoContainerLayer.backgroundColor = nil
        self.videoContainerLayer.isOpaque = false
        self.videoContainerLayer.contentsLayer.backgroundColor = nil
        self.videoContainerLayer.contentsLayer.isOpaque = false
        if #available(iOS 13.0, *) {
            self.videoContainerLayer.contentsLayer.cornerCurve = .circular
        }
        
        self.videoLayer = PrivateCallVideoLayer()
        self.videoLayer.masksToBounds = true
        self.videoLayer.isDoubleSided = false
        if #available(iOS 13.0, *) {
            self.videoLayer.cornerCurve = .circular
        }
        
        self.blurredContainerLayer = SimpleLayer()
        
        self.shadowContainer = SimpleLayer()
        self.topShadowLayer = SimpleLayer()
        self.topShadowLayer.transform = CATransform3DMakeScale(1.0, -1.0, 1.0)
        self.bottomShadowLayer = SimpleLayer()
        
        super.init(frame: CGRect())
        
        self.videoContainerLayer.contentsLayer.addSublayer(self.videoLayer)
        self.layer.addSublayer(self.videoContainerLayer)
        self.blurredContainerLayer.addSublayer(self.videoLayer.blurredLayer)
        
        self.topShadowLayer.contents = shadowImage?.cgImage
        self.bottomShadowLayer.contents = shadowImage?.cgImage
        self.shadowContainer.addSublayer(self.topShadowLayer)
        self.shadowContainer.addSublayer(self.bottomShadowLayer)
        self.layer.addSublayer(self.shadowContainer)
        
        self.highligthedChanged = { [weak self] highlighted in
            guard let self, let params = self.params, !self.videoContainerLayer.bounds.isEmpty, !self.videoContainerLayerTaken else {
                return
            }
            var highlightedState = false
            if highlighted {
                if params.isMinimized {
                    highlightedState = true
                }
            } else {
                highlightedState = false
            }
            
            if self.highlightedState == highlightedState {
                return
            }
            self.highlightedState = highlightedState
            
            let measurementSide = min(self.videoContainerLayer.bounds.width, self.videoContainerLayer.bounds.height)
            let topScale: CGFloat = (measurementSide - 8.0) / measurementSide
            let maxScale: CGFloat = (measurementSide + 2.0) / measurementSide
            
            if highlightedState {
                self.videoContainerLayer.removeAnimation(forKey: "sublayerTransform")
                let transition = ComponentTransition(animation: .curve(duration: 0.15, curve: .easeInOut))
                transition.setSublayerTransform(layer: self.videoContainerLayer, transform: CATransform3DMakeScale(topScale, topScale, 1.0))
            } else {
                let t = self.videoContainerLayer.presentation()?.sublayerTransform ?? self.videoContainerLayer.sublayerTransform
                let currentScale = sqrt((t.m11 * t.m11) + (t.m12 * t.m12) + (t.m13 * t.m13))
                
                let transition = ComponentTransition(animation: .none)
                transition.setSublayerTransform(layer: self.videoContainerLayer, transform: CATransform3DIdentity)
                
                self.videoContainerLayer.animateSublayerScale(from: currentScale, to: maxScale, duration: 0.13, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, removeOnCompletion: false, completion: { [weak self] completed in
                    guard let self, completed else {
                        return
                    }
                    
                    self.videoContainerLayer.animateSublayerScale(from: maxScale, to: 1.0, duration: 0.1, timingFunction: CAMediaTimingFunctionName.easeIn.rawValue)
                })
            }
        }
        self.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
        
        self.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(self.panGesture(_:))))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let params = self.params else {
            return nil
        }
        if params.isMinimized {
            let videoContainerPoint = self.layer.convert(point, to: self.videoContainerLayer)
            if self.videoContainerLayer.bounds.contains(videoContainerPoint) {
                return self
            } else {
                return nil
            }
        } else {
            return nil
        }
    }
    
    @objc private func pressed() {
        self.pressAction?()
    }
    
    @objc private func panGesture(_ recognizer: UIPanGestureRecognizer) {
        if self.videoContainerLayerTaken {
            return
        }
        
        switch recognizer.state {
        case .began, .changed:
            self.dragVelocity = CGPoint()
            if let dragPositionAnimatorLink = self.dragPositionAnimatorLink {
                self.dragPositionAnimatorLink = nil
                dragPositionAnimatorLink.invalidate()
            }
            let translation = recognizer.translation(in: self)
            
            let initialDragPosition: CGPoint
            if let current = self.initialDragPosition {
                initialDragPosition = current
            } else {
                initialDragPosition = self.videoContainerLayer.position
                self.initialDragPosition = initialDragPosition
            }
            self.dragPosition = initialDragPosition.offsetBy(dx: translation.x, dy: translation.y)
            self.update(transition: .immediate)
        case .ended, .cancelled:
            self.initialDragPosition = nil
            self.dragVelocity = recognizer.velocity(in: self)
            
            if let params = self.params, let dragPosition = self.dragPosition {
                let endPosition = CGPoint(
                    x: dragPosition.x - self.dragVelocity.x / (1000.0 * log(0.99)),
                    y: dragPosition.y - self.dragVelocity.y / (1000.0 * log(0.99))
                )
                
                var minCornerDistance: (corner: MinimizedPosition, distance: CGFloat)?
                for corner in MinimizedPosition.allCases {
                    let cornerPosition: CGPoint
                    switch corner {
                    case .topLeft:
                        cornerPosition = CGPoint(x: params.insets.left, y: params.insets.top)
                    case .topRight:
                        cornerPosition = CGPoint(x: params.size.width - params.insets.right, y: params.insets.top)
                    case .bottomLeft:
                        cornerPosition = CGPoint(x: params.insets.left, y: params.size.height - params.insets.bottom)
                    case .bottomRight:
                        cornerPosition = CGPoint(x: params.size.width - params.insets.right, y: params.size.height - params.insets.bottom)
                    }
                    
                    let distance = CGPoint(x: endPosition.x - cornerPosition.x, y: endPosition.y - cornerPosition.y)
                    let scalarDistance = sqrt(distance.x * distance.x + distance.y * distance.y)
                    if let (_, minDistance) = minCornerDistance {
                        if scalarDistance < minDistance {
                            minCornerDistance = (corner, scalarDistance)
                        }
                    } else {
                        minCornerDistance = (corner, scalarDistance)
                    }
                }
                if let minCornerDistance {
                    self.minimizedPosition = minCornerDistance.corner
                }
            }
            
            self.dragPositionAnimatorLink = SharedDisplayLinkDriver.shared.add(framesPerSecond: .max, { [weak self] deltaTime in
                guard let self else {
                    return
                }
                self.updateDragPositionAnimation(deltaTime: deltaTime)
            })
        default:
            break
        }
    }
    
    private func updateVelocityUsingSpring(currentVelocity: CGPoint, currentPosition: CGPoint, attractor: CGPoint, springConstant: CGFloat, damping: CGFloat, deltaTime: CGFloat) -> CGPoint {
        let displacement = CGPoint(x: attractor.x - currentPosition.x, y: attractor.y - currentPosition.y)
        let springForce = CGPoint(x: -springConstant * displacement.x, y: -springConstant * displacement.y)
        var newVelocity = CGPoint(x: currentVelocity.x + springForce.x * deltaTime, y: currentVelocity.y + springForce.y * deltaTime)
        newVelocity = CGPoint(x: newVelocity.x * exp(-damping * deltaTime), y: newVelocity.y * exp(-damping * deltaTime))
        return newVelocity
    }
    
    private func updateDragPositionAnimation(deltaTime: Double) {
        guard let params = self.params, let videoMetrics = self.videoMetrics else {
            self.dragPosition = nil
            self.dragPositionAnimatorLink = nil
            return
        }
        if !params.isMinimized {
            self.dragPosition = nil
            self.dragPositionAnimatorLink = nil
            return
        }
        guard var dragPosition = self.dragPosition else {
            self.dragPosition = nil
            self.dragPositionAnimatorLink = nil
            return
        }
        let videoLayout = self.calculateMinimizedLayout(params: params, videoMetrics: videoMetrics, resolvedRotationAngle: resolveCallVideoRotationAngle(angle: videoMetrics.rotationAngle, followsDeviceOrientation: videoMetrics.followsDeviceOrientation, interfaceOrientation: params.interfaceOrientation), applyDragPosition: false)
        let targetPosition = videoLayout.rotatedVideoFrame.center
        
        self.dragVelocity = self.updateVelocityUsingSpring(
            currentVelocity: self.dragVelocity,
            currentPosition: dragPosition,
            attractor: targetPosition,
            springConstant: -130.0,
            damping: 17.0,
            deltaTime: CGFloat(deltaTime)
        )
        
        if sqrt(self.dragVelocity.x * self.dragVelocity.x + self.dragVelocity.y * self.dragVelocity.y) <= 0.1 {
            self.dragVelocity = CGPoint()
            self.dragPosition = nil
            self.dragPositionAnimatorLink = nil
        } else {
            dragPosition.x += self.dragVelocity.x * CGFloat(deltaTime)
            dragPosition.y += self.dragVelocity.y * CGFloat(deltaTime)
            
            self.dragPosition = dragPosition
        }
        
        self.update(transition: .immediate)
    }
    
    private func initiateVideoSourceSwitch(flipAnimationInfo: FlipAnimationInfo?) {
        guard let videoMetrics = self.videoMetrics else {
            return
        }
        if let disappearingVideoLayer = self.disappearingVideoLayer {
            disappearingVideoLayer.videoLayer.removeFromSuperlayer()
            disappearingVideoLayer.videoLayer.blurredLayer.removeFromSuperlayer()
        }
        let previousVideoLayer = self.videoLayer
        self.disappearingVideoLayer = DisappearingVideo(flipAnimationInfo: flipAnimationInfo, videoLayer: self.videoLayer, videoMetrics: videoMetrics)
        
        self.videoLayer = PrivateCallVideoLayer()
        self.videoLayer.opacity = previousVideoLayer.opacity
        self.videoLayer.masksToBounds = true
        self.videoLayer.isDoubleSided = false
        if #available(iOS 13.0, *) {
            self.videoLayer.cornerCurve = .circular
        }
        self.videoLayer.cornerRadius = previousVideoLayer.cornerRadius
        self.videoLayer.blurredLayer.opacity = previousVideoLayer.blurredLayer.opacity
        
        self.videoContainerLayer.contentsLayer.addSublayer(self.videoLayer)
        self.blurredContainerLayer.addSublayer(self.videoLayer.blurredLayer)
        
        self.dragPosition = nil
        self.dragPositionAnimatorLink = nil
    }
    
    private func update(transition: ComponentTransition) {
        guard let params = self.params else {
            return
        }
        self.update(previousParams: params, params: params, transition: transition)
    }
    
    func update(size: CGSize, insets: UIEdgeInsets, interfaceOrientation: UIInterfaceOrientation, cornerRadius: CGFloat, controlsHidden: Bool, isMinimized: Bool, isAnimatedOut: Bool, transition: ComponentTransition) {
        let params = Params(size: size, insets: insets, interfaceOrientation: interfaceOrientation, cornerRadius: cornerRadius, controlsHidden: controlsHidden, isMinimized: isMinimized, isAnimatedOut: isAnimatedOut)
        if self.params == params {
            return
        }
        
        let previousParams = self.params
        self.params = params
        
        if let previousParams, previousParams.controlsHidden != params.controlsHidden {
            self.dragPosition = nil
            self.dragPositionAnimatorLink = nil
        }
        
        self.update(previousParams: previousParams, params: params, transition: transition)
    }
    
    private struct MinimizedLayout {
        var videoIsRotated: Bool
        var videoSize: CGSize
        var rotatedVideoSize: CGSize
        var rotatedVideoResolution: CGSize
        var rotatedVideoFrame: CGRect
        var videoTransform: CATransform3D
        var effectiveVideoFrame: CGRect
    }
    
    private func calculateMinimizedLayout(params: Params, videoMetrics: VideoMetrics, resolvedRotationAngle: Float, applyDragPosition: Bool) -> MinimizedLayout {
        var rotatedResolution = videoMetrics.resolution
        var videoIsRotated = false
        if resolvedRotationAngle == Float.pi * 0.5 || resolvedRotationAngle == Float.pi * 3.0 / 2.0 {
            rotatedResolution = CGSize(width: rotatedResolution.height, height: rotatedResolution.width)
            videoIsRotated = true
        }
        
        let minimizedBoundingSize: CGFloat = params.controlsHidden ? 140.0 : 240.0
        let videoSize = rotatedResolution.aspectFitted(CGSize(width: minimizedBoundingSize, height: minimizedBoundingSize))
        
        let videoResolution = rotatedResolution.aspectFittedOrSmaller(CGSize(width: 1280, height: 1280)).aspectFittedOrSmaller(CGSize(width: videoSize.width * 3.0, height: videoSize.height * 3.0))
        let rotatedVideoResolution = videoIsRotated ? CGSize(width: videoResolution.height, height: videoResolution.width) : videoResolution
        
        let rotatedVideoSize = videoIsRotated ? CGSize(width: videoSize.height, height: videoSize.width) : videoSize
        
        let rotatedVideoFrame: CGRect
        if applyDragPosition, let dragPosition = self.dragPosition {
            rotatedVideoFrame = videoSize.centered(around: dragPosition)
        } else {
            switch self.minimizedPosition {
            case .topLeft:
                rotatedVideoFrame = CGRect(origin: CGPoint(x: params.insets.left, y: params.insets.top), size: videoSize)
            case .topRight:
                rotatedVideoFrame = CGRect(origin: CGPoint(x: params.size.width - params.insets.right - videoSize.width, y: params.insets.top), size: videoSize)
            case .bottomLeft:
                rotatedVideoFrame = CGRect(origin: CGPoint(x: params.insets.left, y: params.size.height - params.insets.bottom - videoSize.height), size: videoSize)
            case .bottomRight:
                rotatedVideoFrame = CGRect(origin: CGPoint(x: params.size.width - params.insets.right - videoSize.width, y: params.size.height - params.insets.bottom - videoSize.height), size: videoSize)
            }
        }
        
        let effectiveVideoFrame = videoSize.centered(around: rotatedVideoFrame.center)
        
        var videoTransform = CATransform3DIdentity
        videoTransform.m34 = 1.0 / 600.0
        videoTransform = CATransform3DRotate(videoTransform, CGFloat(resolvedRotationAngle), 0.0, 0.0, 1.0)
        if params.isAnimatedOut {
            videoTransform = CATransform3DScale(videoTransform, 0.6, 0.6, 1.0)
        }
        
        return MinimizedLayout(
            videoIsRotated: videoIsRotated,
            videoSize: videoSize,
            rotatedVideoSize: rotatedVideoSize,
            rotatedVideoResolution: rotatedVideoResolution,
            rotatedVideoFrame: rotatedVideoFrame,
            videoTransform: videoTransform,
            effectiveVideoFrame: effectiveVideoFrame
        )
    }
    
    private func update(previousParams: Params?, params: Params, transition: ComponentTransition) {
        if self.videoContainerLayerTaken {
            return
        }
        guard let videoMetrics = self.videoMetrics else {
            return
        }
        var transition = transition
        if self.appliedVideoMetrics == nil {
            transition = .immediate
        }
        self.appliedVideoMetrics = videoMetrics
        
        let resolvedRotationAngle = resolveCallVideoRotationAngle(angle: videoMetrics.rotationAngle, followsDeviceOrientation: videoMetrics.followsDeviceOrientation, interfaceOrientation: params.interfaceOrientation)
        
        if params.isMinimized {
            self.isFillingBounds = false
            
            let videoLayout = self.calculateMinimizedLayout(params: params, videoMetrics: videoMetrics, resolvedRotationAngle: resolvedRotationAngle, applyDragPosition: true)
            
            transition.setPosition(layer: self.videoContainerLayer, position: videoLayout.effectiveVideoFrame.center)
            
            self.videoContainerLayer.contentsLayer.masksToBounds = true
            if self.disappearingVideoLayer != nil {
                self.videoContainerLayer.contentsLayer.backgroundColor = UIColor.black.cgColor
            }
            transition.setBounds(layer: self.videoContainerLayer, bounds: CGRect(origin: CGPoint(), size: videoLayout.effectiveVideoFrame.size), completion: { [weak self] completed in
                guard let self, completed else {
                    return
                }
                self.videoContainerLayer.contentsLayer.masksToBounds = false
                self.videoContainerLayer.contentsLayer.backgroundColor = nil
            })
            self.videoContainerLayer.update(size: videoLayout.effectiveVideoFrame.size, transition: transition)
            
            var videoTransition = transition
            if self.videoLayer.bounds.isEmpty {
                videoTransition = .immediate
            }
            var animateFlipDisappearingVideo: DisappearingVideo?
            if let disappearingVideoLayer = self.disappearingVideoLayer {
                self.disappearingVideoLayer = nil
                
                let disappearingVideoLayout = self.calculateMinimizedLayout(params: params, videoMetrics: disappearingVideoLayer.videoMetrics, resolvedRotationAngle: resolveCallVideoRotationAngle(angle: disappearingVideoLayer.videoMetrics.rotationAngle, followsDeviceOrientation: disappearingVideoLayer.videoMetrics.followsDeviceOrientation, interfaceOrientation: params.interfaceOrientation), applyDragPosition: true)
                let initialDisappearingVideoSize = disappearingVideoLayout.effectiveVideoFrame.size
                
                if !disappearingVideoLayer.isAlphaAnimationInitiated {
                    disappearingVideoLayer.isAlphaAnimationInitiated = true
                    
                    if let flipAnimationInfo = disappearingVideoLayer.flipAnimationInfo {
                        var videoTransform = self.videoContainerLayer.transform
                        var axis: (x: CGFloat, y: CGFloat, z: CGFloat) = (0.0, 0.0, 0.0)
                        let previousVideoScale: CGPoint
                        
                        axis.y = 1.0
                        previousVideoScale = CGPoint(x: -1.0, y: 1.0)
                        
                        videoTransform = CATransform3DRotate(videoTransform, (flipAnimationInfo.isForward ? 1.0 : -1.0) * CGFloat.pi * 0.9999, axis.x, axis.y, axis.z)
                        self.videoContainerLayer.transform = videoTransform
                        
                        disappearingVideoLayer.videoLayer.zPosition = 1.0
                        transition.setZPosition(layer: disappearingVideoLayer.videoLayer, zPosition: -1.0)
                        
                        disappearingVideoLayer.videoLayer.transform = CATransform3DConcat(disappearingVideoLayout.videoTransform, CATransform3DMakeScale(previousVideoScale.x, previousVideoScale.y, 1.0))
                        
                        animateFlipDisappearingVideo = disappearingVideoLayer
                        disappearingVideoLayer.videoLayer.blurredLayer.removeFromSuperlayer()
                    } else {
                        let alphaTransition: ComponentTransition = .easeInOut(duration: 0.2)
                        let disappearingVideoLayerValue = disappearingVideoLayer.videoLayer
                        alphaTransition.setAlpha(layer: disappearingVideoLayerValue, alpha: 0.0, completion: { [weak self, weak disappearingVideoLayerValue] _ in
                            guard let self, let disappearingVideoLayerValue else {
                                return
                            }
                            disappearingVideoLayerValue.removeFromSuperlayer()
                            if self.disappearingVideoLayer?.videoLayer === disappearingVideoLayerValue {
                                self.disappearingVideoLayer = nil
                                self.update(transition: .immediate)
                            }
                        })
                        disappearingVideoLayer.videoLayer.blurredLayer.removeFromSuperlayer()
                        
                        self.videoLayer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    }
                    
                    let mappedDisappearingSize: CGSize
                    if videoLayout.videoIsRotated {
                        mappedDisappearingSize = CGSize(width: initialDisappearingVideoSize.height, height: initialDisappearingVideoSize.width)
                    } else {
                        mappedDisappearingSize = initialDisappearingVideoSize
                    }
                    
                    self.videoLayer.position = disappearingVideoLayer.videoLayer.position
                    self.videoLayer.bounds = CGRect(origin: CGPoint(), size: videoLayout.rotatedVideoSize.aspectFilled(mappedDisappearingSize))
                    self.videoLayer.blurredLayer.position = disappearingVideoLayer.videoLayer.blurredLayer.position
                    self.videoLayer.blurredLayer.bounds = CGRect(origin: CGPoint(), size: videoLayout.rotatedVideoSize.aspectFilled(mappedDisappearingSize))
                }
                
                let disappearingFitVideoSize: CGSize
                if disappearingVideoLayout.videoIsRotated {
                    disappearingFitVideoSize = CGSize(width: videoLayout.effectiveVideoFrame.size.height, height: videoLayout.effectiveVideoFrame.size.width)
                } else {
                    disappearingFitVideoSize = videoLayout.effectiveVideoFrame.size
                }
                
                let disappearingVideoSize = disappearingVideoLayout.rotatedVideoSize.aspectFilled(disappearingFitVideoSize)
                transition.setPosition(layer: disappearingVideoLayer.videoLayer, position: CGPoint(x: videoLayout.effectiveVideoFrame.width * 0.5, y: videoLayout.effectiveVideoFrame.height * 0.5))
                transition.setBounds(layer: disappearingVideoLayer.videoLayer, bounds: CGRect(origin: CGPoint(), size: disappearingVideoSize))
                transition.setPosition(layer: disappearingVideoLayer.videoLayer.blurredLayer, position: videoLayout.rotatedVideoFrame.center)
                transition.setBounds(layer: disappearingVideoLayer.videoLayer.blurredLayer, bounds: CGRect(origin: CGPoint(), size: disappearingVideoSize))
            }
            
            let animateFlipDisappearingVideoLayer = animateFlipDisappearingVideo?.videoLayer
            transition.setTransform(layer: self.videoContainerLayer, transform: CATransform3DIdentity, completion: { [weak animateFlipDisappearingVideoLayer] _ in
                animateFlipDisappearingVideoLayer?.removeFromSuperlayer()
            })
            
            transition.setPosition(layer: self.videoLayer, position: CGPoint(x: videoLayout.videoSize.width * 0.5, y: videoLayout.videoSize.height * 0.5))
            transition.setBounds(layer: self.videoLayer, bounds: CGRect(origin: CGPoint(), size: videoLayout.rotatedVideoSize))
            videoTransition.setTransform(layer: self.videoLayer, transform: videoLayout.videoTransform)
            
            transition.setPosition(layer: self.videoLayer.blurredLayer, position: videoLayout.rotatedVideoFrame.center)
            transition.setAlpha(layer: self.videoLayer.blurredLayer, alpha: 0.0)
            transition.setBounds(layer: self.videoLayer.blurredLayer, bounds: CGRect(origin: CGPoint(), size: videoLayout.rotatedVideoSize))
            videoTransition.setTransform(layer: self.videoLayer.blurredLayer, transform: videoLayout.videoTransform)
            
            if let previousParams, !previousParams.isMinimized {
                self.videoContainerLayer.contentsLayer.cornerRadius = previousParams.cornerRadius
            }
            transition.setCornerRadius(layer: self.videoContainerLayer.contentsLayer, cornerRadius: 18.0, completion: { [weak self] completed in
                guard let self, completed, let params = self.params else {
                    return
                }
                if params.isMinimized {
                    self.videoLayer.cornerRadius = 18.0
                }
            })
            
            self.videoLayer.renderSpec = RenderLayerSpec(size: RenderSize(width: Int(videoLayout.rotatedVideoResolution.width), height: Int(videoLayout.rotatedVideoResolution.height)), edgeInset: 2)
        } else {
            var rotatedResolution = videoMetrics.resolution
            var videoIsRotated = false
            if resolvedRotationAngle == Float.pi * 0.5 || resolvedRotationAngle == Float.pi * 3.0 / 2.0 {
                rotatedResolution = CGSize(width: rotatedResolution.height, height: rotatedResolution.width)
                videoIsRotated = true
            }
            
            var videoSize: CGSize
            if params.isAnimatedOut {
                self.isFillingBounds = true
                videoSize = rotatedResolution.aspectFilled(params.size)
            } else {
                videoSize = rotatedResolution.aspectFitted(params.size)
                let boundingAspectRatio = params.size.width / params.size.height
                let videoAspectRatio = videoSize.width / videoSize.height
                self.isFillingBounds = abs(boundingAspectRatio - videoAspectRatio) < 0.15
                if self.isFillingBounds {
                    videoSize = rotatedResolution.aspectFilled(params.size)
                }
            }
            
            let videoResolution = rotatedResolution.aspectFittedOrSmaller(CGSize(width: 1280, height: 1280)).aspectFittedOrSmaller(CGSize(width: videoSize.width * 3.0, height: videoSize.height * 3.0))
            let rotatedVideoResolution = videoIsRotated ? CGSize(width: videoResolution.height, height: videoResolution.width) : videoResolution
            
            let rotatedVideoSize = videoIsRotated ? CGSize(width: videoSize.height, height: videoSize.width) : videoSize
            let rotatedVideoBoundingSize = params.size
            let rotatedVideoFrame = CGRect(origin: CGPoint(x: floor((rotatedVideoBoundingSize.width - rotatedVideoSize.width) * 0.5), y: floor((rotatedVideoBoundingSize.height - rotatedVideoSize.height) * 0.5)), size: rotatedVideoSize)

            self.videoContainerLayer.contentsLayer.masksToBounds = true
            if let previousParams, self.videoContainerLayer.contentsLayer.animation(forKey: "cornerRadius") == nil {
                if previousParams.isMinimized {
                    self.videoContainerLayer.contentsLayer.cornerRadius = self.videoLayer.cornerRadius
                } else {
                    self.videoContainerLayer.contentsLayer.cornerRadius = previousParams.cornerRadius
                }
            }
            self.videoLayer.cornerRadius = 0.0
            transition.setCornerRadius(layer: self.videoContainerLayer.contentsLayer, cornerRadius: params.cornerRadius, completion: { [weak self] completed in
                guard let self, completed, let params = self.params else {
                    return
                }
                if !params.isMinimized && !params.isAnimatedOut {
                    self.videoContainerLayer.contentsLayer.cornerRadius = 0.0
                }
            })
            
            transition.setPosition(layer: self.videoContainerLayer, position: CGPoint(x: params.size.width * 0.5, y: params.size.height * 0.5))
            transition.setBounds(layer: self.videoContainerLayer, bounds: CGRect(origin: CGPoint(), size: params.size))
            self.videoContainerLayer.update(size: params.size, transition: transition)
            
            var videoTransition = transition
            if self.videoLayer.bounds.isEmpty {
                videoTransition = .immediate
                if !transition.animation.isImmediate {
                    self.videoLayer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    self.videoLayer.blurredLayer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                }
            }
            
            let videoFrame = rotatedVideoSize.centered(around: CGPoint(x: params.size.width * 0.5, y: params.size.height * 0.5))
            
            if let disappearingVideoLayer = self.disappearingVideoLayer {
                self.disappearingVideoLayer = nil
                
                if !disappearingVideoLayer.isAlphaAnimationInitiated {
                    disappearingVideoLayer.isAlphaAnimationInitiated = true
                    
                    self.videoLayer.position = disappearingVideoLayer.videoLayer.position
                    self.videoLayer.blurredLayer.position = disappearingVideoLayer.videoLayer.blurredLayer.position
                    
                    transition.setPosition(layer: disappearingVideoLayer.videoLayer, position: videoFrame.center)
                    transition.setPosition(layer: disappearingVideoLayer.videoLayer.blurredLayer, position: videoFrame.center)
                    
                    let alphaTransition: ComponentTransition = .easeInOut(duration: 0.2)
                    let disappearingVideoLayerValue = disappearingVideoLayer.videoLayer
                    alphaTransition.setAlpha(layer: disappearingVideoLayerValue, alpha: 0.0, completion: { [weak disappearingVideoLayerValue] _ in
                        disappearingVideoLayerValue?.removeFromSuperlayer()
                    })
                    let disappearingVideoLayerBlurredLayerValue = disappearingVideoLayer.videoLayer.blurredLayer
                    alphaTransition.setAlpha(layer: disappearingVideoLayerBlurredLayerValue, alpha: 0.0, completion: { [weak disappearingVideoLayerBlurredLayerValue] _ in
                        disappearingVideoLayerBlurredLayerValue?.removeFromSuperlayer()
                    })
                }
            }
            
            transition.setPosition(layer: self.videoLayer, position: videoFrame.center)
            videoTransition.setBounds(layer: self.videoLayer, bounds: CGRect(origin: CGPoint(), size: videoFrame.size))
            videoTransition.setTransform(layer: self.videoLayer, transform: CATransform3DMakeRotation(CGFloat(resolvedRotationAngle), 0.0, 0.0, 1.0))
            
            transition.setPosition(layer: self.videoLayer.blurredLayer, position: rotatedVideoFrame.center)
            videoTransition.setBounds(layer: self.videoLayer.blurredLayer, bounds: CGRect(origin: CGPoint(), size: rotatedVideoFrame.size))
            videoTransition.setAlpha(layer: self.videoLayer.blurredLayer, alpha: 1.0)
            videoTransition.setTransform(layer: self.videoLayer.blurredLayer, transform: CATransform3DMakeRotation(CGFloat(resolvedRotationAngle), 0.0, 0.0, 1.0))
            
            if !params.isAnimatedOut {
                self.videoLayer.renderSpec = RenderLayerSpec(size: RenderSize(width: Int(rotatedVideoResolution.width), height: Int(rotatedVideoResolution.height)), edgeInset: 2)
            }
        }
        
        self.shadowContainer.masksToBounds = true
        transition.setCornerRadius(layer: self.shadowContainer, cornerRadius: params.cornerRadius, completion: { [weak self] completed in
            guard let self, completed else {
                return
            }
            self.shadowContainer.masksToBounds = false
        })
        transition.setFrame(layer: self.shadowContainer, frame: CGRect(origin: CGPoint(), size: params.size))
        
        let shadowAlpha: CGFloat = (params.controlsHidden || params.isMinimized || params.isAnimatedOut) ? 0.0 : 1.0
        
        let topShadowHeight: CGFloat = 200.0
        let topShadowFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: params.size.width, height: topShadowHeight))
        transition.setPosition(layer: self.topShadowLayer, position: topShadowFrame.center)
        transition.setBounds(layer: self.topShadowLayer, bounds: CGRect(origin: CGPoint(), size: topShadowFrame.size))
        transition.setAlpha(layer: self.topShadowLayer, alpha: shadowAlpha)
        
        let bottomShadowHeight: CGFloat = 200.0
        transition.setFrame(layer: self.bottomShadowLayer, frame: CGRect(origin: CGPoint(x: 0.0, y: params.size.height - bottomShadowHeight), size: CGSize(width: params.size.width, height: bottomShadowHeight)))
        transition.setAlpha(layer: self.bottomShadowLayer, alpha: shadowAlpha)
    }
}
