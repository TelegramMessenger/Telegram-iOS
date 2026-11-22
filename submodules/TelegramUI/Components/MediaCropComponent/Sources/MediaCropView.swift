import Foundation
import UIKit
import Display
import ComponentFlow
import MediaEditor

private let mediaCropOverscreenSize: CGFloat = 1000.0
private let mediaCropContainerInset: CGFloat = 9.0
private let mediaCropBackdropDuration: Double = 0.16
private let mediaCropConfirmDelay: Double = 1.0
private let mediaCropInterfaceFadeDuration: Double = 0.2

public func mediaCropDialHitInsets(axis: MediaCropDialAxis) -> UIEdgeInsets {
    switch axis {
    case .horizontal:
        return mediaCropDialHitInsets
    case .vertical:
        return UIEdgeInsets(top: mediaCropControlHitInset - mediaCropContainerInset, left: mediaCropDialHitInsets.left, bottom: mediaCropDialHitInsets.bottom, right: mediaCropDialHitInsets.right)
    }
}

private final class MediaCropCompletionGroup {
    private var remaining: Int
    private let completion: (() -> Void)?

    init(count: Int, completion: (() -> Void)?) {
        self.remaining = count
        self.completion = completion
    }

    func leave() {
        self.remaining -= 1
        if self.remaining == 0 {
            self.completion?()
        }
    }
}

private final class MediaCropContentView: UIView {
    let imageView: UIImageView
    let overlayView: UIImageView?

    init(image: UIImage, overlayImage: UIImage?, size: CGSize) {
        self.imageView = UIImageView(image: image)
        self.imageView.contentMode = .scaleToFill
        self.imageView.layer.allowsEdgeAntialiasing = true

        if let overlayImage {
            let overlayView = UIImageView(image: overlayImage)
            overlayView.contentMode = .scaleToFill
            overlayView.layer.allowsEdgeAntialiasing = true
            self.overlayView = overlayView
        } else {
            self.overlayView = nil
        }

        super.init(frame: .zero)

        self.isUserInteractionEnabled = false
        self.imageView.bounds = CGRect(origin: .zero, size: size)
        self.imageView.layer.position = .zero
        self.addSubview(self.imageView)
        if let overlayView = self.overlayView {
            overlayView.bounds = CGRect(origin: .zero, size: size)
            overlayView.layer.position = .zero
            self.addSubview(overlayView)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private(set) var perspective = MediaEditorPerspectiveHomography.identity

    func apply(center: CGPoint, scale: CGFloat, angle: CGFloat, mirrored: Bool, perspective: MediaEditorPerspectiveHomography, transition: ContainedViewLayoutTransition, completion: (() -> Void)? = nil) {
        self.perspective = perspective
        let group = MediaCropCompletionGroup(count: 3, completion: completion)
        transition.updatePosition(layer: self.layer, position: center, completion: { _ in group.leave() })
        transition.updateTransform(layer: self.layer, transform: CGAffineTransform(rotationAngle: angle), completion: { _ in group.leave() })
        var imageTransform = CATransform3DMakeScale(mirrored ? -1.0 : 1.0, 1.0, 1.0)
        imageTransform = CATransform3DConcat(imageTransform, perspective.transform3D())
        imageTransform = CATransform3DConcat(imageTransform, CATransform3DMakeScale(scale, scale, 1.0))
        transition.updateTransform(layer: self.imageView.layer, transform: imageTransform, completion: { _ in group.leave() })
        if let overlayView = self.overlayView {
            transition.updateTransform(layer: overlayView.layer, transform: CGAffineTransform(scaleX: scale, y: scale))
        }
    }

    func freeze() {
        var layers: [CALayer] = [self.layer, self.imageView.layer]
        if let overlayView = self.overlayView {
            layers.append(overlayView.layer)
        }
        for layer in layers {
            if let presentation = layer.presentation(), layer.animationKeys() != nil {
                layer.position = presentation.position
                layer.transform = presentation.transform
            }
            layer.removeAllAnimations()
        }
    }

    var currentCenter: CGPoint {
        return self.layer.position
    }

    var currentScale: CGFloat {
        let transform = self.imageView.layer.transform
        let m = self.perspective.m
        let perspectiveDeterminant = max(CGFloat(abs(m[0, 0] * m[1, 1] - m[1, 0] * m[0, 1])), CGFloat(Float.ulpOfOne))
        return sqrt(abs(transform.m11 * transform.m22 - transform.m12 * transform.m21) / perspectiveDeterminant)
    }
}

public final class MediaCropView: UIView, UIGestureRecognizerDelegate {
    private let image: UIImage
    private let overlayImage: UIImage?
    private let hasRotationWheel: Bool

    public private(set) var state: MediaCropState
    public var stateUpdated: ((MediaCropState) -> Void)?
    public var resetMirrored = false
    public var interactionBegan: (() -> Void)?
    public var interactionEnded: (() -> Void)?

    private let frameBackgroundView: UIView
    private let contentView: MediaCropContentView
    private let blurView: UIVisualEffectView
    private let snapshotClipView: UIView
    private let snapshotContentView: MediaCropContentView
    private let overlayWrapperView: UIView
    private let topOverlayView: UIView
    private let leftOverlayView: UIView
    private let rightOverlayView: UIView
    private let bottomOverlayView: UIView
    private let gestureView: UIView
    private let areaView: MediaCropAreaView
    private let rotationDialView: MediaCropRotationDialView?
    private let adjustmentSelectorView: MediaCropAdjustmentSelectorView?
    private var disabledAdjustments: [MediaCropAdjustment: CGFloat] = [:]

    private var containerFrame: CGRect?
    private var laidOutContainerFrame: CGRect?
    private var areaFrame: CGRect = .zero
    private var placement = MediaCropContentPlacement(center: .zero, scale: 1.0)

    private var confirmWorkItem: DispatchWorkItem?
    private var isAnimatingSettle = false
    private var isContentAnimating = false
    private var cropAreaChanged = false
    private var animationGeneration = 0
    private var backdropVisible = false
    private var isInteracting = false
    private var rotationStartScale: CGFloat?

    private var isAnimatingRotation = false
    private var rotationGeneration = 0
    private var rotationSnapshotView: UIView?
    private var rotationSnapshotScaleView: UIView?
    private var rotationSnapshotBaseWidth: CGFloat = 1.0

    private var isAnimatingMirror = false
    private var mirrorGeneration = 0
    private var mirrorFlipView: UIView?
    private var mirrorFlipTarget: CGFloat = 1.0

    private var activeContentGestures = Set<ObjectIdentifier>()
    private var pinchStartScale: CGFloat = 1.0
    private var pinchMinimumScale: CGFloat = 1.0
    private var pinchAnchor: CGPoint = .zero

    public init(image: UIImage, overlayImage: UIImage? = nil, state: MediaCropState, hasRotationWheel: Bool, hasPerspective: Bool = false) {
        self.image = image
        self.overlayImage = overlayImage
        self.state = state
        self.hasRotationWheel = hasRotationWheel

        self.frameBackgroundView = UIView()
        self.frameBackgroundView.backgroundColor = .black
        self.frameBackgroundView.isUserInteractionEnabled = false

        self.contentView = MediaCropContentView(image: image, overlayImage: overlayImage, size: state.originalSize)

        self.blurView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
        self.blurView.isUserInteractionEnabled = false
        self.blurView.alpha = 0.0

        self.snapshotClipView = UIView()
        self.snapshotClipView.clipsToBounds = true
        self.snapshotClipView.isUserInteractionEnabled = false
        self.snapshotClipView.isHidden = true
        self.snapshotContentView = MediaCropContentView(image: image, overlayImage: overlayImage, size: state.originalSize)
        self.snapshotClipView.addSubview(self.snapshotContentView)

        self.overlayWrapperView = UIView()
        self.overlayWrapperView.isUserInteractionEnabled = false
        let overlayColor = UIColor(white: 0.0, alpha: 0.45)
        self.topOverlayView = UIView()
        self.leftOverlayView = UIView()
        self.rightOverlayView = UIView()
        self.bottomOverlayView = UIView()
        for overlay in [self.topOverlayView, self.leftOverlayView, self.rightOverlayView, self.bottomOverlayView] {
            overlay.backgroundColor = overlayColor
            self.overlayWrapperView.addSubview(overlay)
        }

        self.gestureView = UIView()
        self.gestureView.layer.contents = MediaCropAssets.transparentContents

        self.areaView = MediaCropAreaView(frame: .zero)

        self.rotationDialView = hasRotationWheel ? MediaCropRotationDialView(frame: .zero) : nil
        self.adjustmentSelectorView = hasRotationWheel && hasPerspective ? MediaCropAdjustmentSelectorView(frame: .zero) : nil

        super.init(frame: .zero)

        self.addSubview(self.frameBackgroundView)
        self.addSubview(self.contentView)
        self.addSubview(self.blurView)
        self.addSubview(self.snapshotClipView)
        self.addSubview(self.overlayWrapperView)
        self.addSubview(self.gestureView)
        self.addSubview(self.areaView)
        if let rotationDialView = self.rotationDialView {
            rotationDialView.setAngle(state.rotation)
            self.addSubview(rotationDialView)
        }
        if let adjustmentSelectorView = self.adjustmentSelectorView {
            self.addSubview(adjustmentSelectorView)
        }

        self.areaView.isAspectRatioLocked = mediaCropDisplayedLockedRatio(state) != nil

        let pressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(self.handleContentPress(_:)))
        pressGestureRecognizer.minimumPressDuration = 0.1
        pressGestureRecognizer.delegate = self
        self.gestureView.addGestureRecognizer(pressGestureRecognizer)

        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.handleContentPan(_:)))
        panGestureRecognizer.delegate = self
        self.gestureView.addGestureRecognizer(panGestureRecognizer)

        let pinchGestureRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(self.handleContentPinch(_:)))
        pinchGestureRecognizer.delegate = self
        self.gestureView.addGestureRecognizer(pinchGestureRecognizer)

        self.areaView.shouldBeginResizing = { [weak self] in
            guard let self else {
                return true
            }
            return !self.isAnimatingSettle && !self.isAnimatingRotation && !self.isAnimatingMirror && !self.isContentTracking && !(self.rotationDialView?.isTracking ?? false)
        }
        self.areaView.resizeBegan = { [weak self] _ in
            self?.resizeBegan()
        }
        self.areaView.resizeChanged = { [weak self] handle, translation in
            self?.resizeChanged(handle: handle, translation: translation)
        }
        self.areaView.resizeEnded = { [weak self] _ in
            self?.startConfirmCountdown()
        }

        if let rotationDialView = self.rotationDialView {
            rotationDialView.shouldBeginChanging = { [weak self] in
                guard let self else {
                    return true
                }
                return !self.isAnimatingSettle && !self.isAnimatingRotation && !self.isAnimatingMirror && !self.isContentTracking && !self.areaView.isTracking
            }
            rotationDialView.didBeginChanging = { [weak self] in
                self?.dialBegan()
            }
            rotationDialView.angleChanged = { [weak self] angle in
                self?.dialChanged(angle: angle)
            }
            rotationDialView.didEndChanging = { [weak self] in
                self?.dialEnded()
            }
        }

        if let adjustmentSelectorView = self.adjustmentSelectorView {
            adjustmentSelectorView.selectionChanged = { [weak self] _ in
                self?.refreshAdjustmentControls(updateDial: true)
            }
            adjustmentSelectorView.selectedTapped = { [weak self] adjustment in
                self?.toggleAdjustment(adjustment)
            }
            self.refreshAdjustmentControls(updateDial: true)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.confirmWorkItem?.cancel()
    }

    public var hasPendingConfirmation: Bool {
        return self.confirmWorkItem != nil || self.cropAreaChanged
    }

    public var cropFrameInSelf: CGRect {
        return self.areaFrame
    }

    private var isContentTracking: Bool {
        return !self.activeContentGestures.isEmpty || self.isContentAnimating
    }

    public var isAnimating: Bool {
        return self.isAnimatingSettle || self.isAnimatingRotation || self.isAnimatingMirror || self.isContentAnimating
    }

    public var isTracking: Bool {
        return self.areaView.isTracking || !self.activeContentGestures.isEmpty || (self.rotationDialView?.isTracking ?? false)
    }

    private func beginInteraction() {
        if self.isInteracting {
            return
        }
        self.isInteracting = true
        self.interactionBegan?()
    }

    private var canLayoutToContainer: Bool {
        return !self.areaView.isTracking && !self.isAnimatingSettle && !self.isAnimatingRotation && !self.isAnimatingMirror && self.activeContentGestures.isEmpty && !(self.rotationDialView?.isTracking ?? false)
    }

    private func endInteractionIfIdle() {
        if let containerFrame = self.containerFrame, containerFrame != self.laidOutContainerFrame, self.confirmWorkItem == nil, self.canLayoutToContainer {
            self.layoutToState(transition: mediaCropSettleTransition)
        }
        if !self.isInteracting || self.isTracking {
            return
        }
        self.isInteracting = false
        self.interactionEnded?()
    }

    private var capBounds: CGRect {
        guard let containerFrame = self.containerFrame else {
            return .zero
        }
        return containerFrame.insetBy(dx: mediaCropContainerInset, dy: mediaCropContainerInset)
    }

    public override func layoutSubviews() {
        super.layoutSubviews()

        self.blurView.frame = self.bounds
    }

    public func update(containerFrame: CGRect, rotationDialFrame: CGRect, rotationDialScale: CGFloat = 1.0, rotationDialAxis: MediaCropDialAxis = .horizontal, selectorFrame: CGRect? = nil, transition: ComponentTransition) {
        let previousContainerFrame = self.containerFrame
        self.containerFrame = containerFrame

        if let adjustmentSelectorView = self.adjustmentSelectorView, let selectorFrame {
            adjustmentSelectorView.layoutAxis = rotationDialAxis
            if previousContainerFrame == nil {
                adjustmentSelectorView.frame = selectorFrame
            } else {
                transition.setFrame(view: adjustmentSelectorView, frame: selectorFrame)
            }
        }

        if let rotationDialView = self.rotationDialView {
            rotationDialView.rulerScale = rotationDialScale
            rotationDialView.hitInsets = mediaCropDialHitInsets(axis: rotationDialAxis)
            if case .horizontal = rotationDialAxis, rotationDialView.transform.isIdentity {
                if previousContainerFrame == nil {
                    rotationDialView.frame = rotationDialFrame
                } else {
                    transition.setFrame(view: rotationDialView, frame: rotationDialFrame)
                }
            } else {
                let placement = mediaCropDialPlacement(frame: rotationDialFrame, axis: rotationDialAxis)
                let axisChanged = rotationDialView.transform != placement.transform
                rotationDialView.transform = placement.transform
                if previousContainerFrame == nil || axisChanged {
                    rotationDialView.bounds = placement.bounds
                    rotationDialView.center = placement.center
                } else {
                    transition.setBounds(view: rotationDialView, bounds: placement.bounds)
                    transition.setPosition(view: rotationDialView, position: placement.center)
                }
            }
        }

        let capBounds = self.capBounds
        self.gestureView.frame = CGRect(x: capBounds.minX - 100.0, y: capBounds.minY - 16.0, width: capBounds.width + 200.0, height: capBounds.height + 116.0)

        if previousContainerFrame == nil {
            self.layoutToState(transition: .immediate)
            self.setBackdropVisible(true, animated: false)
            return
        }
        if previousContainerFrame == containerFrame {
            return
        }
        if self.confirmWorkItem != nil {
            self.performConfirm(animated: false)
        }
        if self.canLayoutToContainer {
            self.layoutToState(transition: mediaCropContainedTransition(transition))
        }
    }

    private func layoutToState(transition: ContainedViewLayoutTransition, completion: (() -> Void)? = nil) {
        guard let containerFrame = self.containerFrame else {
            completion?()
            return
        }
        self.laidOutContainerFrame = containerFrame
        let frame = mediaCropAreaFrame(cropSize: self.state.cropRect.size, orientation: self.state.orientation, container: containerFrame)
        let placement = mediaCropContentPlacement(cropRect: self.state.cropRect, state: self.state, frame: frame)
        let group = MediaCropCompletionGroup(count: 2, completion: completion)
        self.applyAreaFrame(frame, transition: transition, completion: { group.leave() })
        self.applyPlacement(placement, transition: transition, completion: { group.leave() })
    }

    private func applyAreaFrame(_ frame: CGRect, transition: ContainedViewLayoutTransition, completion: (() -> Void)? = nil) {
        self.areaFrame = frame

        transition.updateFrame(view: self.frameBackgroundView, frame: frame)
        transition.updateFrame(view: self.areaView, frame: frame, completion: { _ in completion?() })
        self.areaView.update(size: frame.size, transition: transition)

        transition.updateFrame(view: self.overlayWrapperView, frame: frame)
        transition.updateFrame(view: self.topOverlayView, frame: CGRect(x: 0.0, y: -mediaCropOverscreenSize, width: frame.width, height: mediaCropOverscreenSize))
        transition.updateFrame(view: self.leftOverlayView, frame: CGRect(x: -mediaCropOverscreenSize, y: -mediaCropOverscreenSize, width: mediaCropOverscreenSize, height: frame.height + 2.0 * mediaCropOverscreenSize))
        transition.updateFrame(view: self.rightOverlayView, frame: CGRect(x: frame.width, y: -mediaCropOverscreenSize, width: mediaCropOverscreenSize, height: frame.height + 2.0 * mediaCropOverscreenSize))
        transition.updateFrame(view: self.bottomOverlayView, frame: CGRect(x: 0.0, y: frame.height, width: frame.width, height: mediaCropOverscreenSize))

        transition.updateFrame(view: self.snapshotClipView, frame: frame)
        self.applySnapshotContent(transition: transition)
    }

    private func contentPerspective(_ perspective: MediaEditorCropPerspective? = nil) -> MediaEditorPerspectiveHomography {
        return MediaEditorPerspectiveHomography(perspective: perspective ?? self.state.perspective, size: self.state.originalSize)
    }

    private func applyPlacement(_ placement: MediaCropContentPlacement, angle: CGFloat? = nil, perspective: MediaEditorCropPerspective? = nil, transition: ContainedViewLayoutTransition, completion: (() -> Void)? = nil) {
        self.placement = placement
        let angle = angle ?? mediaCropContentAngle(self.state)
        let homography = self.contentPerspective(perspective)
        self.contentView.apply(center: placement.center, scale: placement.scale, angle: angle, mirrored: self.state.mirrored, perspective: homography, transition: transition, completion: completion)
        self.applySnapshotContent(angle: angle, perspective: homography, transition: transition)
    }

    private func applySnapshotContent(angle: CGFloat? = nil, perspective: MediaEditorPerspectiveHomography? = nil, transition: ContainedViewLayoutTransition) {
        let center = CGPoint(x: self.placement.center.x - self.areaFrame.minX, y: self.placement.center.y - self.areaFrame.minY)
        self.snapshotContentView.apply(center: center, scale: self.placement.scale, angle: angle ?? mediaCropContentAngle(self.state), mirrored: self.state.mirrored, perspective: perspective ?? self.contentPerspective(), transition: transition)
    }

    private func areaFrameViews() -> [UIView] {
        return [self.frameBackgroundView, self.areaView, self.overlayWrapperView, self.topOverlayView, self.leftOverlayView, self.rightOverlayView, self.bottomOverlayView, self.snapshotClipView]
    }

    private func freezeAreaFrame() {
        let frame = self.areaView.layer.presentation()?.frame ?? self.areaView.frame
        func removeFrameAnimations(_ view: UIView) {
            view.layer.removeAnimation(forKey: "position")
            view.layer.removeAnimation(forKey: "bounds")
            if view === self.snapshotClipView {
                return
            }
            for subview in view.subviews {
                removeFrameAnimations(subview)
            }
        }
        for view in self.areaFrameViews() {
            removeFrameAnimations(view)
        }
        self.applyAreaFrame(frame, transition: .immediate)
    }

    private func interruptSettle() {
        guard self.isAnimatingSettle || self.isContentAnimating else {
            return
        }
        self.freezeContent()
        self.freezeAreaFrame()
        self.isAnimatingSettle = false
    }

    private func setView(_ view: UIView, hidden: Bool, animated: Bool) {
        if animated {
            view.isHidden = false
            UIView.animate(withDuration: mediaCropInterfaceFadeDuration, delay: 0.0, options: [.curveEaseInOut], animations: {
                view.alpha = hidden ? 0.0 : 1.0
            }, completion: { finished in
                if finished {
                    view.isHidden = hidden
                }
            })
        } else {
            view.layer.removeAnimation(forKey: "opacity")
            view.isHidden = hidden
            view.alpha = hidden ? 0.0 : 1.0
        }
    }

    private func setInterfaceHidden(_ hidden: Bool, animated: Bool) {
        if let rotationDialView = self.rotationDialView {
            self.setView(rotationDialView, hidden: hidden, animated: animated)
        }
        if let adjustmentSelectorView = self.adjustmentSelectorView {
            self.setView(adjustmentSelectorView, hidden: hidden, animated: animated)
        }
    }

    private func setCropAreaHidden(_ hidden: Bool, animated: Bool) {
        self.setView(self.areaView, hidden: hidden, animated: animated)
    }

    private func freezeContent() {
        self.contentView.freeze()
        self.snapshotContentView.freeze()
        self.placement = MediaCropContentPlacement(center: self.contentView.currentCenter, scale: self.contentView.currentScale)
        self.isContentAnimating = false
        self.animationGeneration += 1
    }

    private func currentCropRect() -> CGRect {
        return mediaCropRect(frame: self.areaFrame, placement: self.placement, state: self.state)
    }

    private func publishState() {
        self.stateUpdated?(self.state)
    }

    private func setBackdropVisible(_ visible: Bool, animated: Bool) {
        self.backdropVisible = visible
        if visible {
            self.applySnapshotContent(transition: .immediate)
            self.snapshotClipView.isHidden = false
            if animated {
                UIView.animate(withDuration: mediaCropBackdropDuration, delay: 0.0, options: [.curveEaseOut], animations: {
                    self.blurView.alpha = 1.0
                })
            } else {
                self.blurView.layer.removeAllAnimations()
                self.blurView.alpha = 1.0
            }
        } else {
            if animated {
                if self.blurView.alpha == 0.0 {
                    self.snapshotClipView.isHidden = true
                    return
                }
                UIView.animate(withDuration: mediaCropBackdropDuration, delay: 0.0, options: [.curveEaseInOut], animations: {
                    self.blurView.alpha = 0.0
                }, completion: { [weak self] finished in
                    guard let self, finished, !self.backdropVisible else {
                        return
                    }
                    self.snapshotClipView.isHidden = true
                })
            } else {
                self.blurView.layer.removeAllAnimations()
                self.blurView.alpha = 0.0
                self.snapshotClipView.isHidden = true
            }
        }
    }

    private func startConfirmCountdown() {
        if self.areaView.isTracking {
            return
        }
        self.confirmWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else {
                return
            }
            self.confirmWorkItem = nil
            self.performConfirm(animated: true)
        }
        self.confirmWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + mediaCropConfirmDelay, execute: workItem)
    }

    private func cancelConfirmCountdown() {
        self.confirmWorkItem?.cancel()
        self.confirmWorkItem = nil
    }

    private var cropRectEpsilon: CGFloat {
        return max(self.state.originalSize.width, self.state.originalSize.height) * 0.005
    }

    private func cropRectsEqual(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
        let epsilon = self.cropRectEpsilon
        return abs(lhs.minX - rhs.minX) < epsilon && abs(lhs.minY - rhs.minY) < epsilon && abs(lhs.width - rhs.width) < epsilon * 2.0 && abs(lhs.height - rhs.height) < epsilon * 2.0
    }

    private func performConfirm(animated: Bool, updateInterface: Bool = true) {
        if self.areaView.isTracking || self.isAnimatingSettle || self.isAnimatingRotation || self.isAnimatingMirror {
            return
        }
        self.cancelConfirmCountdown()

        let currentRect = self.currentCropRect()
        let clampedRect = mediaCropClampedCropRect(currentRect, state: self.state)
        self.state.cropRect = clampedRect

        self.areaView.setGridMode(.none, animated: animated)

        if updateInterface {
            self.setInterfaceHidden(false, animated: animated)
        } else if let rotationDialView = self.rotationDialView, rotationDialView.isHidden {
            self.setCropAreaHidden(true, animated: false)
        }

        if !self.cropAreaChanged && self.cropRectsEqual(currentRect, clampedRect) {
            self.setBackdropVisible(true, animated: animated)
            self.publishState()
            self.endInteractionIfIdle()
            return
        }

        self.cropAreaChanged = false
        self.evenlyFill(animated: animated, completion: { [weak self] in
            self?.endInteractionIfIdle()
        })
        self.publishState()
    }

    private func evenlyFill(animated: Bool, completion: (() -> Void)?) {
        guard animated else {
            self.freezeContent()
            self.layoutToState(transition: .immediate)
            self.setBackdropVisible(true, animated: true)
            completion?()
            return
        }

        self.freezeContent()
        self.isAnimatingSettle = true
        self.animationGeneration += 1
        let generation = self.animationGeneration
        self.layoutToState(transition: mediaCropSettleTransition, completion: { [weak self] in
            guard let self, self.animationGeneration == generation else {
                return
            }
            self.isAnimatingSettle = false
            self.fitContent(allowScale: false, animated: true, completion: { [weak self] in
                self?.setBackdropVisible(true, animated: true)
                completion?()
            })
        })
    }

    private func fitContent(allowScale: Bool, animated: Bool, completion: (() -> Void)? = nil) {
        let fitted = mediaCropCoverFit(self.placement, frame: self.areaFrame, state: self.state, allowScale: allowScale)
        if fitted == self.placement {
            completion?()
            return
        }
        if !animated {
            self.applyPlacement(fitted, transition: .immediate)
            completion?()
            return
        }
        self.isContentAnimating = true
        self.animationGeneration += 1
        let generation = self.animationGeneration
        self.applyPlacement(fitted, transition: mediaCropSettleTransition, completion: { [weak self] in
            guard let self, self.animationGeneration == generation else {
                return
            }
            self.isContentAnimating = false
            completion?()
        })
    }

    private func resizeBegan() {
        self.freezeContent()
        self.setBackdropVisible(false, animated: false)
        self.cancelConfirmCountdown()
        self.areaView.setGridMode(.major, animated: true)
        self.setInterfaceHidden(true, animated: true)
        self.rotationStartScale = nil
        self.beginInteraction()
    }

    private func resizeChanged(handle: MediaCropHandle, translation: CGPoint) {
        self.cropAreaChanged = true

        var currentState = self.state
        currentState.cropRect = self.currentCropRect()
        let resized = mediaCropResized(currentState, corner: handle, translation: translation, scale: self.placement.scale)
        let resizedFrame = mediaCropDisplayedFrame(cropRect: resized.cropRect, placement: self.placement, state: self.state)
        let frame = mediaCropCappedFrame(resizedFrame, bounds: self.capBounds, aspectRatio: mediaCropDisplayedLockedRatio(self.state))

        self.applyAreaFrame(frame, transition: .immediate)
        self.fitContent(allowScale: true, animated: false)
    }

    public override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer.view === self.gestureView {
            return !self.isAnimatingSettle && !self.isAnimatingRotation && !self.isAnimatingMirror && !self.areaView.isTracking && !(self.rotationDialView?.isTracking ?? false)
        }
        return super.gestureRecognizerShouldBegin(gestureRecognizer)
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }

    private func contentGestureBegan(_ gestureRecognizer: UIGestureRecognizer) {
        let wasEmpty = self.activeContentGestures.isEmpty
        self.activeContentGestures.insert(ObjectIdentifier(gestureRecognizer))
        guard wasEmpty else {
            return
        }
        self.freezeContent()
        self.setBackdropVisible(false, animated: true)
        self.cancelConfirmCountdown()
        self.areaView.setGridMode(.major, animated: true)
        self.rotationStartScale = nil
        self.beginInteraction()
    }

    private func contentGestureEnded(_ gestureRecognizer: UIGestureRecognizer) {
        guard self.activeContentGestures.remove(ObjectIdentifier(gestureRecognizer)) != nil, self.activeContentGestures.isEmpty else {
            return
        }
        self.startConfirmCountdown()
        self.fitContent(allowScale: true, animated: true)
    }

    @objc private func handleContentPress(_ gestureRecognizer: UILongPressGestureRecognizer) {
        switch gestureRecognizer.state {
        case .began:
            self.contentGestureBegan(gestureRecognizer)
        case .ended, .cancelled, .failed:
            self.contentGestureEnded(gestureRecognizer)
        default:
            break
        }
    }

    @objc private func handleContentPan(_ gestureRecognizer: UIPanGestureRecognizer) {
        switch gestureRecognizer.state {
        case .began, .changed:
            if gestureRecognizer.state == .began {
                self.contentGestureBegan(gestureRecognizer)
            }
            let translation = gestureRecognizer.translation(in: self)
            gestureRecognizer.setTranslation(.zero, in: self)
            var placement = self.placement
            placement.center = CGPoint(x: placement.center.x + translation.x, y: placement.center.y + translation.y)
            self.applyPlacement(placement, transition: .immediate)
        case .ended, .cancelled, .failed:
            self.contentGestureEnded(gestureRecognizer)
        default:
            break
        }
    }

    @objc private func handleContentPinch(_ gestureRecognizer: UIPinchGestureRecognizer) {
        switch gestureRecognizer.state {
        case .began, .changed:
            if gestureRecognizer.state == .began {
                self.contentGestureBegan(gestureRecognizer)
                let location = gestureRecognizer.location(in: self)
                self.pinchStartScale = self.placement.scale
                self.pinchMinimumScale = mediaCropMinimumZoomScale(frameSize: self.areaFrame.size, state: self.state)
                self.pinchAnchor = CGPoint(x: (location.x - self.placement.center.x) / self.placement.scale, y: (location.y - self.placement.center.y) / self.placement.scale)
            }
            let scale = mediaCropPinchScale(startScale: self.pinchStartScale, gestureScale: gestureRecognizer.scale, minimumScale: self.pinchMinimumScale, contentWidth: self.state.originalSize.width)
            let anchor = CGPoint(x: self.placement.center.x + self.pinchAnchor.x * self.placement.scale, y: self.placement.center.y + self.pinchAnchor.y * self.placement.scale)
            let ratio = scale / self.placement.scale
            let placement = MediaCropContentPlacement(
                center: CGPoint(x: anchor.x - (anchor.x - self.placement.center.x) * ratio, y: anchor.y - (anchor.y - self.placement.center.y) * ratio),
                scale: scale
            )
            self.applyPlacement(placement, transition: .immediate)
        case .ended, .cancelled, .failed:
            self.contentGestureEnded(gestureRecognizer)
        default:
            break
        }
    }

    public func confirmImmediately() {
        self.finishMirror(animated: false)
        self.performConfirm(animated: false, updateInterface: false)
    }

    public func confirm(animated: Bool) {
        self.performConfirm(animated: animated)
    }

    private func dialBegan() {
        self.adjustmentSelectorView?.isUserInteractionEnabled = false
        if let adjustmentSelectorView = self.adjustmentSelectorView, self.disabledAdjustments.removeValue(forKey: adjustmentSelectorView.selected) != nil {
            self.refreshAdjustmentControls(updateDial: false)
        }
        self.freezeContent()
        self.setBackdropVisible(false, animated: true)
        self.cancelConfirmCountdown()
        self.areaView.setGridMode(.minor, animated: true)
        if self.rotationStartScale == nil {
            self.rotationStartScale = self.placement.scale
        }
        self.beginInteraction()
    }

    private func dialChanged(angle: CGFloat) {
        let adjustment = self.adjustmentSelectorView?.selected ?? .straighten
        self.applyAdjustment(adjustment, value: angle, transition: .immediate)
        self.refreshAdjustmentControls(updateDial: false)
    }

    private func adjustmentValue(_ adjustment: MediaCropAdjustment) -> CGFloat {
        switch adjustment {
        case .straighten:
            return self.state.rotation
        case .vertical:
            return mediaCropScreenPerspective(self.state).vertical
        case .horizontal:
            return mediaCropScreenPerspective(self.state).horizontal
        }
    }

    private func applyAdjustment(_ adjustment: MediaCropAdjustment, value: CGFloat, transition: ContainedViewLayoutTransition, completion: (() -> Void)? = nil) {
        var placement = self.placement
        switch adjustment {
        case .straighten:
            let delta = value - self.state.rotation
            self.state.rotation = value
            placement = mediaCropPlacementRotated(placement, around: CGPoint(x: self.areaFrame.midX, y: self.areaFrame.midY), by: delta)
        case .vertical, .horizontal:
            var screen = mediaCropScreenPerspective(self.state)
            if adjustment == .vertical {
                screen.vertical = value
            } else {
                screen.horizontal = value
            }
            self.state = mediaCropSettingScreenPerspective(self.state, screen)
        }
        let fitted = mediaCropAdjustmentFit(placement, frame: self.areaFrame, state: self.state, rotationStartScale: self.rotationStartScale)
        self.applyPlacement(fitted, transition: transition, completion: completion)
    }

    private func refreshAdjustmentControls(updateDial: Bool) {
        guard let adjustmentSelectorView = self.adjustmentSelectorView else {
            return
        }
        var values: [MediaCropAdjustment: CGFloat] = [:]
        for adjustment in MediaCropAdjustment.allCases {
            values[adjustment] = self.adjustmentValue(adjustment) * 180.0 / .pi
        }
        adjustmentSelectorView.setValues(values, disabled: Set(self.disabledAdjustments.keys))
        let selected = adjustmentSelectorView.selected
        if let rotationDialView = self.rotationDialView {
            if updateDial && !rotationDialView.isTracking {
                rotationDialView.setAngle(self.adjustmentValue(selected), limit: mediaCropAdjustmentLimit(selected))
            }
            rotationDialView.setDimmed(self.disabledAdjustments[selected] != nil)
        }
    }

    private func toggleAdjustment(_ adjustment: MediaCropAdjustment) {
        if self.isAnimatingSettle || self.isAnimatingRotation || self.isAnimatingMirror || self.isTracking {
            return
        }
        let value: CGFloat
        if let disabledValue = self.disabledAdjustments.removeValue(forKey: adjustment) {
            value = disabledValue
        } else {
            let current = self.adjustmentValue(adjustment)
            if abs(current) < CGFloat(Float.ulpOfOne) {
                return
            }
            self.disabledAdjustments[adjustment] = current
            value = 0.0
        }
        self.freezeContent()
        self.cancelConfirmCountdown()
        self.setBackdropVisible(false, animated: true)
        if self.rotationStartScale == nil {
            self.rotationStartScale = self.placement.scale
        }
        self.beginInteraction()
        self.isContentAnimating = true
        self.animationGeneration += 1
        let generation = self.animationGeneration
        self.applyAdjustment(adjustment, value: value, transition: mediaCropSettleTransition, completion: { [weak self] in
            guard let self, self.animationGeneration == generation else {
                return
            }
            self.isContentAnimating = false
            self.startConfirmCountdown()
            self.endInteractionIfIdle()
        })
        self.refreshAdjustmentControls(updateDial: true)
        self.publishState()
    }

    private func dialEnded() {
        self.adjustmentSelectorView?.isUserInteractionEnabled = true
        self.startConfirmCountdown()
        self.areaView.setGridMode(.none, animated: true)
        self.publishState()
        self.endInteractionIfIdle()
    }

    private func refreshRotationControls() {
        if self.adjustmentSelectorView != nil {
            self.refreshAdjustmentControls(updateDial: true)
        } else {
            self.rotationDialView?.setAngle(self.state.rotation)
        }
    }

    private func applyCommandState(_ state: MediaCropState, updateDial: Bool = true) {
        self.cancelConfirmCountdown()
        self.cropAreaChanged = false
        self.freezeContent()
        self.state = state
        self.areaView.isAspectRatioLocked = mediaCropDisplayedLockedRatio(state) != nil
        self.refreshAdjustmentControls(updateDial: updateDial)
    }

    private func makeRotationSnapshot() -> (UIView, UIView) {
        let frame = self.areaFrame
        let orientation = self.state.orientation
        let unrotatedSize = orientation.isSideward ? CGSize(width: frame.height, height: frame.width) : frame.size

        let outerView = UIView()
        outerView.isUserInteractionEnabled = false
        outerView.bounds = CGRect(origin: .zero, size: unrotatedSize)
        outerView.center = CGPoint(x: frame.midX, y: frame.midY)
        outerView.transform = CGAffineTransform(rotationAngle: mediaCropOrientationScreenAngle(orientation))

        let scaleView = UIView()
        scaleView.isUserInteractionEnabled = false
        scaleView.clipsToBounds = true
        scaleView.bounds = outerView.bounds
        scaleView.center = CGPoint(x: unrotatedSize.width / 2.0, y: unrotatedSize.height / 2.0)
        outerView.addSubview(scaleView)

        let contentView = MediaCropContentView(image: self.image, overlayImage: self.overlayImage, size: self.state.originalSize)
        let offset = mediaCropPlacementRotated(self.placement, around: CGPoint(x: frame.midX, y: frame.midY), by: orientation.rotation).center
        contentView.apply(
            center: CGPoint(x: offset.x - frame.midX + unrotatedSize.width / 2.0, y: offset.y - frame.midY + unrotatedSize.height / 2.0),
            scale: self.placement.scale,
            angle: self.state.rotation,
            mirrored: self.state.mirrored,
            perspective: self.contentPerspective(),
            transition: .immediate
        )
        scaleView.addSubview(contentView)

        self.rotationSnapshotBaseWidth = max(1.0, unrotatedSize.width)
        return (outerView, scaleView)
    }

    public func rotate90(animated: Bool) {
        if self.isAnimatingSettle || self.isContentTracking || self.isTracking {
            return
        }
        self.finishMirror(animated: false)
        self.cancelConfirmCountdown()

        var snapshot: (UIView, UIView)?
        if let rotationSnapshotView = self.rotationSnapshotView, let rotationSnapshotScaleView = self.rotationSnapshotScaleView {
            snapshot = (rotationSnapshotView, rotationSnapshotScaleView)
        } else {
            if animated {
                let created = self.makeRotationSnapshot()
                self.insertSubview(created.0, aboveSubview: self.gestureView)
                self.rotationSnapshotView = created.0
                self.rotationSnapshotScaleView = created.1
                snapshot = created
            }
            self.state.cropRect = self.currentCropRect()
        }

        let previousOrientation = self.state.orientation
        self.applyCommandState(mediaCropRotatedCCW(self.state))
        self.rotationStartScale = nil

        self.contentView.isHidden = true
        self.setBackdropVisible(false, animated: false)
        self.setInterfaceHidden(true, animated: false)
        self.setCropAreaHidden(true, animated: false)

        if animated, let snapshot, let containerFrame = self.containerFrame {
            let (outerView, scaleView) = snapshot
            self.isAnimatingRotation = true
            self.rotationGeneration += 1
            let generation = self.rotationGeneration

            let targetFrame = mediaCropAreaFrame(cropSize: self.state.cropRect.size, orientation: self.state.orientation, container: containerFrame)
            let targetUnrotatedWidth = self.state.orientation.isSideward ? targetFrame.height : targetFrame.width
            let targetScale = targetUnrotatedWidth / self.rotationSnapshotBaseWidth
            let targetCenter = CGPoint(x: targetFrame.midX, y: targetFrame.midY)

            let fromCenter = outerView.layer.presentation()?.position ?? outerView.layer.position
            let fromAngle: CGFloat
            if let presentation = outerView.layer.presentation(), outerView.layer.animationKeys() != nil {
                fromAngle = atan2(presentation.transform.m12, presentation.transform.m11)
            } else {
                fromAngle = mediaCropOrientationScreenAngle(previousOrientation)
            }
            let fromScale: CGFloat
            if let presentation = scaleView.layer.presentation(), scaleView.layer.animationKeys() != nil {
                let transform = presentation.transform
                fromScale = sqrt(transform.m11 * transform.m11 + transform.m12 * transform.m12)
            } else {
                let transform = scaleView.layer.transform
                fromScale = sqrt(transform.m11 * transform.m11 + transform.m12 * transform.m12)
            }
            let targetAngle = mediaCropQuarterTurnTargetAngle(current: fromAngle, target: mediaCropOrientationScreenAngle(self.state.orientation))

            outerView.layer.removeAllAnimations()
            scaleView.layer.removeAllAnimations()
            outerView.layer.position = targetCenter
            outerView.layer.transform = CATransform3DMakeRotation(targetAngle, 0.0, 0.0, 1.0)
            scaleView.layer.transform = CATransform3DMakeScale(targetScale, targetScale, 1.0)

            let group = MediaCropCompletionGroup(count: 3, completion: { [weak self] in
                guard let self, self.rotationGeneration == generation else {
                    return
                }
                self.finishRotation()
            })
            let timingFunction = mediaCropSettleCurve.timingFunction
            outerView.layer.animate(from: NSValue(cgPoint: fromCenter), to: NSValue(cgPoint: targetCenter), keyPath: "position", timingFunction: timingFunction, duration: mediaCropSettleDuration, completion: { _ in group.leave() })
            outerView.layer.animate(from: NSNumber(value: Double(fromAngle)), to: NSNumber(value: Double(targetAngle)), keyPath: "transform.rotation.z", timingFunction: timingFunction, duration: mediaCropSettleDuration, completion: { _ in group.leave() })
            scaleView.layer.animate(from: NSNumber(value: Double(fromScale)), to: NSNumber(value: Double(targetScale)), keyPath: "transform.scale", timingFunction: timingFunction, duration: mediaCropSettleDuration, completion: { _ in group.leave() })
        } else {
            self.removeRotationSnapshot()
            self.isAnimatingRotation = false
            self.rotationGeneration += 1
            self.layoutToState(transition: .immediate)
            self.contentView.isHidden = false
            self.contentView.alpha = 1.0
            self.setInterfaceHidden(false, animated: false)
            self.setCropAreaHidden(false, animated: false)
            self.setBackdropVisible(true, animated: false)
            self.endInteractionIfIdle()
        }

        self.publishState()
    }

    private func removeRotationSnapshot() {
        self.rotationSnapshotView?.removeFromSuperview()
        self.rotationSnapshotView = nil
        self.rotationSnapshotScaleView = nil
    }

    private func finishRotation() {
        self.isAnimatingRotation = false
        self.removeRotationSnapshot()

        self.evenlyFill(animated: false, completion: nil)

        self.contentView.isHidden = false
        self.setInterfaceHidden(false, animated: true)
        self.setCropAreaHidden(false, animated: true)

        self.setBackdropVisible(true, animated: false)
        self.blurView.alpha = 0.0
        self.contentView.alpha = 0.0
        UIView.animate(withDuration: mediaCropBackdropDuration, delay: 0.0, options: [.curveEaseOut], animations: {
            self.blurView.alpha = 1.0
        }, completion: { [weak self] _ in
            self?.contentView.alpha = 1.0
        })

        self.endInteractionIfIdle()
    }

    private func makeMirrorFlipView() -> UIView {
        let frame = self.areaFrame
        let clipView = UIView()
        clipView.isUserInteractionEnabled = false
        clipView.clipsToBounds = true
        clipView.bounds = CGRect(origin: .zero, size: frame.size)
        clipView.center = CGPoint(x: frame.midX, y: frame.midY)

        let contentView = MediaCropContentView(image: self.image, overlayImage: self.overlayImage, size: self.state.originalSize)
        contentView.apply(
            center: CGPoint(x: self.placement.center.x - frame.minX, y: self.placement.center.y - frame.minY),
            scale: self.placement.scale,
            angle: mediaCropContentAngle(self.state),
            mirrored: self.state.mirrored,
            perspective: self.contentPerspective(),
            transition: .immediate
        )
        clipView.addSubview(contentView)
        return clipView
    }

    public func toggleMirror() {
        if self.isAnimatingSettle || self.isContentTracking || self.isTracking {
            return
        }
        if self.isAnimatingRotation {
            self.state = mediaCropMirrored(self.state)
            self.refreshRotationControls()
            self.publishState()
            return
        }

        let flipView: UIView
        if let mirrorFlipView = self.mirrorFlipView {
            flipView = mirrorFlipView
        } else {
            self.state.cropRect = self.currentCropRect()
            flipView = self.makeMirrorFlipView()
            self.insertSubview(flipView, aboveSubview: self.gestureView)
            self.mirrorFlipView = flipView
            self.mirrorFlipTarget = 1.0
        }

        self.applyCommandState(mediaCropMirrored(self.state))
        self.rotationStartScale = nil
        self.refreshRotationControls()
        self.areaView.setGridMode(.none, animated: false)
        self.layoutToState(transition: .immediate)

        self.contentView.isHidden = true
        self.setBackdropVisible(false, animated: false)
        self.setInterfaceHidden(true, animated: false)
        self.setCropAreaHidden(true, animated: false)

        let fromScale: CGFloat
        if let presentation = flipView.layer.presentation(), flipView.layer.animationKeys() != nil {
            fromScale = presentation.transform.m11
        } else {
            fromScale = flipView.layer.transform.m11
        }
        let targetScale = -self.mirrorFlipTarget
        self.mirrorFlipTarget = targetScale

        self.isAnimatingMirror = true
        self.mirrorGeneration += 1
        let generation = self.mirrorGeneration

        let stepCount = 60
        var values: [AnyObject] = []
        for step in 0 ... stepCount {
            let progress = mediaCropMirrorFlipProgress(time: mediaCropMirrorDuration * Double(step) / Double(stepCount))
            values.append(NSNumber(value: Double(fromScale + (targetScale - fromScale) * progress)))
        }
        flipView.layer.removeAllAnimations()
        flipView.layer.transform = CATransform3DMakeScale(targetScale, 1.0, 1.0)
        flipView.layer.animateKeyframes(values: values, duration: mediaCropMirrorDuration, keyPath: "transform.scale.x", completion: { [weak self] _ in
            guard let self, self.mirrorGeneration == generation else {
                return
            }
            self.finishMirror(animated: true)
        })

        self.publishState()
    }

    private func finishMirror(animated: Bool) {
        guard self.isAnimatingMirror else {
            return
        }
        self.isAnimatingMirror = false
        self.mirrorGeneration += 1
        self.mirrorFlipView?.layer.removeAllAnimations()
        self.mirrorFlipView?.removeFromSuperview()
        self.mirrorFlipView = nil
        self.mirrorFlipTarget = 1.0

        self.contentView.isHidden = false
        self.setInterfaceHidden(false, animated: animated)
        self.setCropAreaHidden(false, animated: animated)
        self.setBackdropVisible(true, animated: false)
        if animated {
            self.blurView.alpha = 0.0
            self.contentView.alpha = 0.0
            UIView.animate(withDuration: mediaCropBackdropDuration, delay: 0.0, options: [.curveEaseOut], animations: {
                self.blurView.alpha = 1.0
            }, completion: { [weak self] _ in
                self?.contentView.alpha = 1.0
            })
        } else {
            self.contentView.alpha = 1.0
        }
        self.endInteractionIfIdle()
    }

    public func setLockedAspectRatio(_ ratio: CGFloat?, animated: Bool) {
        self.finishMirror(animated: false)
        guard let ratio else {
            self.state.lockedAspectRatio = nil
            self.areaView.isAspectRatioLocked = false
            self.publishState()
            return
        }
        if self.isAnimatingRotation {
            self.applyCommandState(mediaCropApplyingLockedRatio(ratio, to: self.state))
            self.publishState()
            return
        }
        self.interruptSettle()

        var state = self.state
        state.cropRect = mediaCropClampedCropRect(self.currentCropRect(), state: state)
        let updated = mediaCropApplyingLockedRatio(ratio, to: state)
        self.applyCommandState(updated)
        self.areaView.setGridMode(.none, animated: animated)
        self.setInterfaceHidden(false, animated: animated)
        if !self.cropRectsEqual(updated.cropRect, state.cropRect) {
            self.setBackdropVisible(false, animated: false)
        }
        self.evenlyFill(animated: animated, completion: { [weak self] in
            self?.endInteractionIfIdle()
        })
        self.publishState()
    }

    public func reset(animated: Bool) {
        if self.isAnimatingSettle || self.isAnimatingRotation || self.isTracking {
            return
        }
        self.finishMirror(animated: false)
        let previous = self.state
        let epsilon = CGFloat(Float.ulpOfOne)
        let rectIsFull = mediaCropRectsEqual(previous.cropRect, CGRect(origin: .zero, size: previous.originalSize), epsilon: epsilon)
        var animated = animated
        if previous.orientation != .up && (previous.mirrored || abs(previous.rotation) > epsilon || !rectIsFull) {
            animated = false
        }
        let needsBackdropReset = !rectIsFull || abs(previous.rotation) > 0.0 || previous.orientation != .up || !previous.perspective.isZero
        self.disabledAdjustments = [:]

        self.rotationStartScale = nil
        var resetState = MediaCropState(originalSize: previous.originalSize)
        resetState.mirrored = self.resetMirrored
        self.applyCommandState(resetState, updateDial: false)
        if needsBackdropReset {
            self.setBackdropVisible(false, animated: false)
        }

        self.rotationDialView?.reset(animated: animated)
        self.areaView.setGridMode(.none, animated: animated)

        if animated {
            let frameCenter = CGPoint(x: self.areaFrame.midX, y: self.areaFrame.midY)
            if previous.orientation != .up {
                let size = self.areaFrame.size
                let snappedFrame = CGRect(x: frameCenter.x - size.height / 2.0, y: frameCenter.y - size.width / 2.0, width: size.height, height: size.width)
                let snappedFrameForOrientation = previous.orientation.isSideward ? snappedFrame : self.areaFrame
                self.applyAreaFrame(snappedFrameForOrientation, transition: .immediate)
            }
            let snapped = mediaCropPlacementRotated(self.placement, around: frameCenter, by: previous.orientation.rotation)
            self.applyPlacement(snapped, angle: previous.rotation, perspective: previous.perspective, transition: .immediate)
        }

        self.evenlyFill(animated: animated, completion: { [weak self] in
            guard let self else {
                return
            }
            self.setInterfaceHidden(false, animated: true)
            self.setCropAreaHidden(false, animated: true)
            self.endInteractionIfIdle()
        })
        self.publishState()
    }
}

private let mediaCropSettleSpring = mediaCropPopSpring(speed: 7.0, bounciness: 1.0)

public func mediaCropSpringTransition(_ spring: MediaCropSpring) -> ContainedViewLayoutTransition {
    let animation = CASpringAnimation()
    animation.mass = spring.mass
    animation.stiffness = spring.stiffness
    animation.damping = spring.damping
    return .animated(duration: animation.settlingDuration, curve: .customSpring(mass: spring.mass, stiffness: spring.stiffness, damping: spring.damping, initialVelocity: 0.0))
}

private let mediaCropSettleTransition = mediaCropSpringTransition(mediaCropSettleSpring)

private let mediaCropSettleDuration: Double = {
    if case let .animated(duration, _) = mediaCropSettleTransition {
        return duration
    }
    return 0.0
}()

private let mediaCropSettleCurve: ContainedViewLayoutTransitionCurve = .customSpring(mass: mediaCropSettleSpring.mass, stiffness: mediaCropSettleSpring.stiffness, damping: mediaCropSettleSpring.damping, initialVelocity: 0.0)

private func mediaCropContainedTransition(_ transition: ComponentTransition) -> ContainedViewLayoutTransition {
    switch transition.animation {
    case .none:
        return .immediate
    case let .curve(duration, curve):
        switch curve {
        case .easeInOut:
            return .animated(duration: duration, curve: .easeInOut)
        case .easeIn:
            return .animated(duration: duration, curve: .easeIn)
        case .linear:
            return .animated(duration: duration, curve: .linear)
        case .spring, .bounce:
            return .animated(duration: duration, curve: .spring)
        case let .custom(a, b, c, d):
            return .animated(duration: duration, curve: .custom(a, b, c, d))
        }
    }
}
