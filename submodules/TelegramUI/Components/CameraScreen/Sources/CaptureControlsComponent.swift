import Foundation
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit
import Photos
import LocalMediaResources

enum ShutterButtonState: Equatable {
    case generic
    case video
    case stopRecording
    case holdRecording(progress: Float)
}

private let maximumShutterSize = CGSize(width: 96.0, height: 96.0)

private extension SimpleShapeLayer {
    func animateStrokeStart(from: CGFloat, to: CGFloat, duration: Double, delay: Double = 0.0, timingFunction: String = CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: Bool = true, completion: ((Bool) -> ())? = nil) {
        self.animate(from: NSNumber(value: Float(from)), to: NSNumber(value: Float(to)), keyPath: "strokeStart", timingFunction: timingFunction, duration: duration, delay: delay, removeOnCompletion: removeOnCompletion, completion: completion)
    }
    
    func animateStrokeEnd(from: CGFloat, to: CGFloat, duration: Double, delay: Double = 0.0, timingFunction: String = CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: Bool = true, completion: ((Bool) -> ())? = nil) {
        self.animate(from: NSNumber(value: Float(from)), to: NSNumber(value: Float(to)), keyPath: "strokeEnd", timingFunction: timingFunction, duration: duration, delay: delay, removeOnCompletion: removeOnCompletion, completion: completion)
    }
}

private final class ShutterButtonContentComponent: Component {
    let shutterState: ShutterButtonState
    let blobState: ShutterBlobView.BlobState
    let highlightedAction: ActionSlot<Bool>
    let updateOffset: ActionSlot<(CGFloat, Transition)>
    
    init(
        shutterState: ShutterButtonState,
        blobState: ShutterBlobView.BlobState,
        highlightedAction: ActionSlot<Bool>,
        updateOffset: ActionSlot<(CGFloat, Transition)>
    ) {
        self.shutterState = shutterState
        self.blobState = blobState
        self.highlightedAction = highlightedAction
        self.updateOffset = updateOffset
    }
    
    static func ==(lhs: ShutterButtonContentComponent, rhs: ShutterButtonContentComponent) -> Bool {
        if lhs.shutterState != rhs.shutterState {
            return false
        }
        if lhs.blobState != rhs.blobState {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private var component: ShutterButtonContentComponent?
        
        private let ringLayer = SimpleShapeLayer()
        var blobView: ShutterBlobView!
        //private let innerLayer = SimpleLayer()
        private let progressLayer = SimpleShapeLayer()
        
        init() {
            super.init(frame: CGRect())
            
            self.blobView = ShutterBlobView(test: false)
            
            self.layer.allowsGroupOpacity = true
            
            self.progressLayer.strokeEnd = 0.0
            
            self.layer.addSublayer(self.ringLayer)
            self.layer.addSublayer(self.progressLayer)
            self.addSubview(self.blobView)
        }

        required init?(coder aDecoder: NSCoder) {
            preconditionFailure()
        }
        
        func updateIsHighlighted(_ isHighlighted: Bool) {
            let scale: CGFloat = isHighlighted ? 0.8 : 1.0
            let transition = Transition(animation: .curve(duration: 0.3, curve: .easeInOut))
            transition.setTransform(view: self.blobView, transform: CATransform3DMakeScale(scale, scale, 1.0))
        }
        
        func update(component: ShutterButtonContentComponent, availableSize: CGSize, transition: Transition) -> CGSize {
            self.component = component
            
            component.highlightedAction.connect { [weak self] highlighted in
                self?.updateIsHighlighted(highlighted)
            }
            
            component.updateOffset.connect { [weak self] offset, transition in
                if let self {
                    self.blobView.updateSecondaryOffset(offset, transition: transition)
                    if abs(offset) < 60.0 {
                        func rubberBandingOffset(offset: CGFloat, bandingStart: CGFloat) -> CGFloat {
                            let bandedOffset = offset - bandingStart
                            let range: CGFloat = 60.0
                            let coefficient: CGFloat = 0.1
                            return bandingStart + (1.0 - (1.0 / ((bandedOffset * coefficient / range) + 1.0))) * range
                        }
                        var bandedOffset = rubberBandingOffset(offset: abs(offset), bandingStart: 0.0)
                        if offset < 0.0 {
                            bandedOffset *= -1.0
                        }
                        self.blobView.updatePrimaryOffset(bandedOffset, transition: transition)
                    } else {
                        self.blobView.updatePrimaryOffset(0.0, transition: .spring(duration: 0.15))
                    }
                }
            }
            
            let innerColor: UIColor
            let innerSize: CGSize
            let innerCornerRadius: CGFloat
            let ringSize: CGSize
            let ringWidth: CGFloat = 3.0
            var recordingProgress: Float?
            switch component.shutterState {
            case .generic:
                innerColor = .white
                innerSize = CGSize(width: 60.0, height: 60.0)
                innerCornerRadius = innerSize.height / 2.0
                ringSize = CGSize(width: 68.0, height: 68.0)
            case .video:
                innerColor = videoRedColor
                innerSize = CGSize(width: 60.0, height: 60.0)
                innerCornerRadius = innerSize.height / 2.0
                ringSize = CGSize(width: 68.0, height: 68.0)
            case .stopRecording:
                innerColor = videoRedColor
                innerSize = CGSize(width: 26.0, height: 26.0)
                innerCornerRadius = 9.0
                ringSize = CGSize(width: 68.0, height: 68.0)
            case let .holdRecording(progress):
                innerColor = videoRedColor
                innerSize = CGSize(width: 60.0, height: 60.0)
                innerCornerRadius = innerSize.height / 2.0
                ringSize = CGSize(width: 92.0, height: 92.0)
                recordingProgress = progress
            }
            
            self.ringLayer.fillColor = UIColor.clear.cgColor
            self.ringLayer.strokeColor = UIColor.white.cgColor
            self.ringLayer.lineWidth = ringWidth
            let ringPath = CGPath(
                ellipseIn: CGRect(
                    origin: CGPoint(
                        x: (maximumShutterSize.width - ringSize.width) / 2.0,
                        y: (maximumShutterSize.height - ringSize.height) / 2.0),
                    size: ringSize
                ),
                transform: nil
            )
            transition.setShapeLayerPath(layer: self.ringLayer, path: ringPath)
            self.ringLayer.bounds = CGRect(origin: .zero, size: maximumShutterSize)
            self.ringLayer.position = CGPoint(x: maximumShutterSize.width / 2.0, y: maximumShutterSize.height / 2.0)
            
            self.blobView.updateState(component.blobState, transition: transition)
            self.blobView.bounds = CGRect(origin: .zero, size: CGSize(width: availableSize.width, height: maximumShutterSize.height))
            self.blobView.center = CGPoint(x: maximumShutterSize.width / 2.0, y: maximumShutterSize.height / 2.0)
            
            let _ = innerColor
            let _ = innerSize
            let _ = innerCornerRadius
            
            self.progressLayer.bounds = CGRect(origin: .zero, size: maximumShutterSize)
            self.progressLayer.position = CGPoint(x: maximumShutterSize.width / 2.0, y: maximumShutterSize.height / 2.0)
            transition.setShapeLayerPath(layer: self.progressLayer, path: ringPath)
            self.progressLayer.fillColor = UIColor.clear.cgColor
            self.progressLayer.strokeColor = videoRedColor.cgColor
            self.progressLayer.lineWidth = ringWidth + UIScreenPixel
            self.progressLayer.lineCap = .round
            self.progressLayer.transform = CATransform3DMakeRotation(-.pi / 2.0, 0.0, 0.0, 1.0)
            
            let previousValue = self.progressLayer.strokeEnd
            self.progressLayer.strokeEnd = CGFloat(recordingProgress ?? 0.0)
            self.progressLayer.animateStrokeEnd(from: previousValue, to: self.progressLayer.strokeEnd, duration: 0.33)
            
            return maximumShutterSize
        }
    }
    
    func makeView() -> View {
        return View()
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}

private final class FlipButtonContentComponent: Component {
    private let action: ActionSlot<Void>
    
    init(action: ActionSlot<Void>) {
        self.action = action
    }
    
    static func ==(lhs: FlipButtonContentComponent, rhs: FlipButtonContentComponent) -> Bool {
        return true
    }
    
    final class View: UIView {
        private var component: FlipButtonContentComponent?
        
        private let icon = SimpleLayer()
        
        init() {
            super.init(frame: CGRect())
            
            self.layer.addSublayer(self.icon)
            
            self.icon.contents = UIImage(bundleImageName: "Camera/FlipIcon")?.cgImage
        }

        required init?(coder aDecoder: NSCoder) {
            preconditionFailure()
        }
        
        func playAnimation() {
            let animation = CASpringAnimation(keyPath: "transform.rotation.z")
            animation.fromValue = 0.0 as NSNumber
            animation.toValue = CGFloat.pi as NSNumber
            animation.mass = 5.0
            animation.stiffness = 900.0
            animation.damping = 90.0
            animation.duration = animation.settlingDuration
            if #available(iOS 15.0, *) {
                let maxFps = Float(UIScreen.main.maximumFramesPerSecond)
                animation.preferredFrameRateRange = CAFrameRateRange(minimum: 30.0, maximum: maxFps, preferred: maxFps)
            }
            self.icon.add(animation, forKey: "transform.rotation.z")
        }
        
        func update(component: FlipButtonContentComponent, availableSize: CGSize, transition: Transition) -> CGSize {
            self.component = component
            
            component.action.connect { [weak self] _ in
                self?.playAnimation()
            }
            
            let size = CGSize(width: 48.0, height: 48.0)
            
            self.icon.position = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
            self.icon.bounds = CGRect(origin: .zero, size: size)
            
            return size
        }
    }
    
    func makeView() -> View {
        return View()
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}

final class CaptureControlsComponent: Component {
    enum SwipeHint {
        case none
        case zoom
        case lock
        case releaseLock
        case flip
    }
    
    let shutterState: ShutterButtonState
    let lastGalleryAsset: PHAsset?
    let tag: AnyObject?
    let shutterTapped: () -> Void
    let shutterPressed: () -> Void
    let shutterReleased: () -> Void
    let lockRecording: () -> Void
    let flipTapped: () -> Void
    let galleryTapped: () -> Void
    let swipeHintUpdated: (SwipeHint) -> Void
    
    init(
        shutterState: ShutterButtonState,
        lastGalleryAsset: PHAsset?,
        tag: AnyObject?,
        shutterTapped: @escaping () -> Void,
        shutterPressed: @escaping () -> Void,
        shutterReleased: @escaping () -> Void,
        lockRecording: @escaping () -> Void,
        flipTapped: @escaping () -> Void,
        galleryTapped: @escaping () -> Void,
        swipeHintUpdated: @escaping (SwipeHint) -> Void
    ) {
        self.shutterState = shutterState
        self.lastGalleryAsset = lastGalleryAsset
        self.tag = tag
        self.shutterTapped = shutterTapped
        self.shutterPressed = shutterPressed
        self.shutterReleased = shutterReleased
        self.lockRecording = lockRecording
        self.flipTapped = flipTapped
        self.galleryTapped = galleryTapped
        self.swipeHintUpdated = swipeHintUpdated
    }
    
    static func ==(lhs: CaptureControlsComponent, rhs: CaptureControlsComponent) -> Bool {
        if lhs.shutterState != rhs.shutterState {
            return false
        }
        if lhs.lastGalleryAsset?.localIdentifier != rhs.lastGalleryAsset?.localIdentifier {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        var cachedAssetImage: (String, UIImage)?
        
        private let assetDisposable = MetaDisposable()
        var lastGalleryAsset: PHAsset? {
            didSet {
                if self.cachedAssetImage?.0 != self.lastGalleryAsset?.localIdentifier {
                    self.cachedAssetImage = nil
                    if let lastGalleryAsset = self.lastGalleryAsset {
                        self.assetDisposable.set((fetchPhotoLibraryImage(localIdentifier: lastGalleryAsset.localIdentifier, thumbnail: true)
                        |> deliverOnMainQueue).start(next: { [weak self] imageAndDegraded in
                            if let self, let (image, _) = imageAndDegraded {
                                self.cachedAssetImage = (lastGalleryAsset.localIdentifier, image)
                                self.updated(transition: .easeInOut(duration: 0.2))
                            }
                        }))
                    }
                }
            }
        }
        
        deinit {
            self.assetDisposable.dispose()
        }
    }
    
    func makeState() -> State {
        return State()
    }

    final class View: UIView, ComponentTaggedView, UIGestureRecognizerDelegate {
        private var component: CaptureControlsComponent?
        private var state: State?
        private var availableSize: CGSize?
        
        private let lockView = ComponentView<Empty>()
        private let galleryButtonView = ComponentView<Empty>()
        private let shutterButtonView = ComponentView<Empty>()
        private let flipButtonView = ComponentView<Empty>()
        
        private let leftGuide = SimpleLayer()
        private let rightGuide = SimpleLayer()
        
        private let shutterUpdateOffset = ActionSlot<(CGFloat, Transition)>()
        private let shutterHightlightedAction = ActionSlot<Bool>()
        private let flipAnimationAction = ActionSlot<Void>()
        
        private let lockImage = UIImage(bundleImageName: "Camera/LockIcon")
        
        public func matches(tag: Any) -> Bool {
            if let component = self.component, let componentTag = component.tag {
                let tag = tag as AnyObject
                if componentTag === tag {
                    return true
                }
            }
            return false
        }
        
        init() {
            super.init(frame: CGRect())
            
            self.leftGuide.backgroundColor = UIColor(rgb: 0xffffff, alpha: 0.2).cgColor
            self.rightGuide.backgroundColor = UIColor(rgb: 0xffffff, alpha: 0.2).cgColor
            
            self.layer.addSublayer(self.leftGuide)
            self.layer.addSublayer(self.rightGuide)
        }

        required init?(coder aDecoder: NSCoder) {
            preconditionFailure()
        }
        
        @objc private func handlePress(_ gestureRecognizer: UILongPressGestureRecognizer) {
            let location = gestureRecognizer.location(in: self)
            switch gestureRecognizer.state {
            case .began:
                self.hapticFeedback.impact(.click05)
                self.component?.shutterPressed()
                self.component?.swipeHintUpdated(.zoom)
                self.shutterUpdateOffset.invoke((0.0, .immediate))
            case .ended, .cancelled:
                if location.x < self.frame.width / 2.0 - 60.0 {
                    self.component?.lockRecording()

                    var blobOffset: CGFloat = 0.0
                    if let galleryButton = self.galleryButtonView.view {
                        blobOffset = galleryButton.center.x - self.frame.width / 2.0
                    }
                    self.shutterUpdateOffset.invoke((blobOffset, .spring(duration: 0.5)))
                } else {
                    self.hapticFeedback.impact(.light)
                    self.component?.shutterReleased()
                    self.shutterUpdateOffset.invoke((0.0, .spring(duration: 0.3)))
                }
            default:
                break
            }
        }
        
        private let hapticFeedback = HapticFeedback()
        
        private var didFlip = false
        private var wasBanding: Bool?
        private var panBlobState: ShutterBlobView.BlobState?
        @objc private func handlePan(_ gestureRecognizer: UIPanGestureRecognizer) {
            func rubberBandingOffset(offset: CGFloat, bandingStart: CGFloat) -> CGFloat {
                let bandedOffset = offset - bandingStart
                let range: CGFloat = 60.0
                let coefficient: CGFloat = 0.4
                return bandingStart + (1.0 - (1.0 / ((bandedOffset * coefficient / range) + 1.0))) * range
            }
            
            let previousPanBlobState = self.panBlobState
            let location = gestureRecognizer.location(in: self)
            switch gestureRecognizer.state {
            case .changed:
                var blobOffset: CGFloat = 0.0
                if let galleryButton = self.galleryButtonView.view, let flipButton = self.flipButtonView.view {
                    blobOffset = max(galleryButton.center.x, min(flipButton.center.x, location.x))
                }
                blobOffset -= self.frame.width / 2.0
                var isBanding = false
                if location.x < self.frame.width / 2.0 - 20.0 {
                    if location.x < self.frame.width / 2.0 - 60.0 {
                        self.component?.swipeHintUpdated(.releaseLock)
                        if location.x < 75.0 {
                            self.panBlobState = .lock
                        } else {
                            self.panBlobState = .transientToLock
                        }
                    } else {
                        self.component?.swipeHintUpdated(.lock)
                        self.panBlobState = .video
                        blobOffset = rubberBandingOffset(offset: blobOffset, bandingStart: 0.0)
                        isBanding = true
                    }
                } else if location.x > self.frame.width / 2.0 + 20.0 {
                    self.component?.swipeHintUpdated(.flip)
                    if location.x > self.frame.width / 2.0 + 60.0 {
                        self.panBlobState = .transientToFlip
                        if !self.didFlip && location.x > self.frame.width - 80.0 {
                            self.didFlip = true
                            self.hapticFeedback.impact(.light)
                            self.flipAnimationAction.invoke(Void())
                            self.component?.flipTapped()
                        }
                    } else {
                        self.didFlip = false
                        self.panBlobState = .video
                        blobOffset = rubberBandingOffset(offset: -blobOffset, bandingStart: 0.0) * -1.0
                        isBanding = true
                    }
                } else {
                    blobOffset = rubberBandingOffset(offset: blobOffset, bandingStart: 0.0)
                    self.component?.swipeHintUpdated(.zoom)
                    self.panBlobState = .video
                    isBanding = true
                }
                var transition: Transition = .immediate
                if let wasBanding = self.wasBanding, wasBanding != isBanding {
                    self.hapticFeedback.impact(.light)
                    transition = .spring(duration: 0.3)
                }
                self.wasBanding = isBanding
                self.shutterUpdateOffset.invoke((blobOffset, transition))
            default:
                self.panBlobState = nil
                self.wasBanding = nil
                self.didFlip = false
            }
            if previousPanBlobState != self.panBlobState, let component = self.component, let state = self.state, let availableSize = self.availableSize {
                let _ = self.update(component: component, state: state, availableSize: availableSize, transition: .spring(duration: 0.5))
            }
        }
        
        override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
        }
        
        private var animatedOut = false
        func animateOutToEditor(transition: Transition) {
            self.animatedOut = true
            
            if let view = self.galleryButtonView.view {
                transition.setScale(view: view, scale: 0.1)
                transition.setAlpha(view: view, alpha: 0.0)
            }
            
            if let view = self.flipButtonView.view {
                transition.setScale(view: view, scale: 0.1)
                transition.setAlpha(view: view, alpha: 0.0)
            }
            
            if let view = self.shutterButtonView.view {
                transition.setScale(view: view, scale: 0.1)
                transition.setAlpha(view: view, alpha: 0.0)
            }
        }
        
        func animateInFromEditor(transition: Transition) {
            self.animatedOut = false

            if let view = self.galleryButtonView.view {
                transition.setScale(view: view, scale: 1.0)
                transition.setAlpha(view: view, alpha: 1.0)
            }
            
            if let view = self.flipButtonView.view {
                transition.setScale(view: view, scale: 1.0)
                transition.setAlpha(view: view, alpha: 1.0)
            }
            
            if let view = self.shutterButtonView.view {
                transition.setScale(view: view, scale: 1.0)
                transition.setAlpha(view: view, alpha: 1.0)
            }
        }

        func update(component: CaptureControlsComponent, state: State, availableSize: CGSize, transition: Transition) -> CGSize {
            let previousShutterState = self.component?.shutterState ?? .generic
            self.component = component
            self.state = state
            self.availableSize = availableSize
            state.lastGalleryAsset = component.lastGalleryAsset
            
            let size = CGSize(width: availableSize.width, height: maximumShutterSize.height)
            let buttonSideInset: CGFloat = 28.0
            //let buttonMaxOffset: CGFloat = 100.0
            
            var isRecording = false
            var isHolding = false
            if case .stopRecording = component.shutterState {
                isRecording = true
            } else if case .holdRecording = component.shutterState {
                isRecording = true
                isHolding = true
            }
                        
            let galleryButtonSize = self.galleryButtonView.update(
                transition: .immediate,
                component: AnyComponent(
                    CameraButton(
                        content: AnyComponent(
                            Image(
                                image: state.cachedAssetImage?.1,
                                size: CGSize(width: 50.0, height: 50.0),
                                contentMode: .scaleAspectFill
                            )
                        ),
                        action: {
                            component.galleryTapped()
                        }
                    )
                ),
                environment: {},
                containerSize: CGSize(width: 50.0, height: 50.0)
            )
            let galleryButtonFrame = CGRect(origin: CGPoint(x: buttonSideInset, y: (size.height - galleryButtonSize.height) / 2.0), size: galleryButtonSize)
            if let galleryButtonView = self.galleryButtonView.view {
                galleryButtonView.clipsToBounds = true
                galleryButtonView.layer.cornerRadius = 10.0
                if galleryButtonView.superview == nil {
                    self.addSubview(galleryButtonView)
                }
                transition.setBounds(view: galleryButtonView, bounds: CGRect(origin: .zero, size: galleryButtonFrame.size))
                transition.setPosition(view: galleryButtonView, position: galleryButtonFrame.center)
                
                transition.setScale(view: galleryButtonView, scale: isRecording ? 0.1 : 1.0)
                transition.setAlpha(view: galleryButtonView, alpha: isRecording ? 0.0 : 1.0)
            }
            
            let _ = self.lockView.update(
                transition: .immediate,
                component: AnyComponent(
                    Image(
                        image: self.lockImage,
                        size: CGSize(width: 30.0, height: 30.0)
                    )
                ),
                environment: {},
                containerSize: CGSize(width: 30.0, height: 30.0)
            )
            let lockFrame = galleryButtonFrame.insetBy(dx: 10.0, dy: 10.0)
            if let lockView = self.lockView.view {
                if lockView.superview == nil {
                    self.addSubview(lockView)
                }
                transition.setBounds(view: lockView, bounds: CGRect(origin: .zero, size: lockFrame.size))
                transition.setPosition(view: lockView, position: lockFrame.center)
                
                transition.setScale(view: lockView, scale: isHolding ? 1.0 : 0.1)
                transition.setAlpha(view: lockView, alpha: isHolding ? 1.0 : 0.0)
            }
            
            let flipAnimationAction = self.flipAnimationAction
            let flipButtonSize = self.flipButtonView.update(
                transition: .immediate,
                component: AnyComponent(
                    CameraButton(
                        content: AnyComponent(
                            FlipButtonContentComponent(action: flipAnimationAction)
                        ),
                        minSize: CGSize(width: 44.0, height: 44.0),
                        action: {
                            component.flipTapped()
                            flipAnimationAction.invoke(Void())
                        }
                    )
                ),
                environment: {},
                containerSize: availableSize
            )
            let flipButtonFrame = CGRect(origin: CGPoint(x: availableSize.width - flipButtonSize.width - buttonSideInset, y: (size.height - flipButtonSize.height) / 2.0), size: flipButtonSize)
            if let flipButtonView = self.flipButtonView.view {
                if flipButtonView.superview == nil {
                    self.addSubview(flipButtonView)
                }
                transition.setFrame(view: flipButtonView, frame: flipButtonFrame)
            }
            
            var blobState: ShutterBlobView.BlobState
            switch component.shutterState {
            case .generic:
                blobState = .generic
            case .video:
                blobState = .video
            case .stopRecording:
                blobState = .stopVideo
            case .holdRecording:
                blobState = self.panBlobState ?? .video
            }
            
            let shutterButtonSize = self.shutterButtonView.update(
                transition: transition,
                component: AnyComponent(
                    Button(
                        content: AnyComponent(
                            ShutterButtonContentComponent(
                                shutterState: component.shutterState,
                                blobState: blobState,
                                highlightedAction: self.shutterHightlightedAction,
                                updateOffset: self.shutterUpdateOffset
                            )
                        ),
                        automaticHighlight: false,
                        action: { [weak self] in
                            self?.shutterUpdateOffset.invoke((0.0, .immediate))
                            component.shutterTapped()
                        },
                        highlightedAction: self.shutterHightlightedAction
                    ).minSize(maximumShutterSize)
                ),
                environment: {},
                containerSize: availableSize
            )
            let shutterButtonFrame = CGRect(origin: CGPoint(x: (availableSize.width - shutterButtonSize.width) / 2.0, y: (size.height - shutterButtonSize.height) / 2.0), size: shutterButtonSize)
            if let shutterButtonView = self.shutterButtonView.view {
                if shutterButtonView.superview == nil {
                    let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.handlePan(_:)))
                    panGestureRecognizer.delegate = self
                    shutterButtonView.addGestureRecognizer(panGestureRecognizer)
                    
                    let pressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(self.handlePress(_:)))
                    pressGestureRecognizer.minimumPressDuration = 0.3
                    pressGestureRecognizer.delegate = self
                    shutterButtonView.addGestureRecognizer(pressGestureRecognizer)
                    
                    self.addSubview(shutterButtonView)
                }
                transition.setFrame(view: shutterButtonView, frame: shutterButtonFrame)
            }
            
            let guideSpacing: CGFloat = 9.0
            let guideSize = CGSize(width: isHolding ? 60.0 : 0.0, height: 1.0 + UIScreenPixel)
            let guideAlpha: CGFloat = isHolding ? 1.0 : 0.0
            
            let leftGuideFrame = CGRect(origin: CGPoint(x: shutterButtonFrame.minX - guideSpacing - guideSize.width, y: (size.height - guideSize.height) / 2.0), size: guideSize)
            let rightGuideFrame = CGRect(origin: CGPoint(x: shutterButtonFrame.maxX + guideSpacing, y: (size.height - guideSize.height) / 2.0), size: guideSize)
            
            transition.setFrame(layer: self.leftGuide, frame: leftGuideFrame)
            transition.setFrame(layer: self.rightGuide, frame: rightGuideFrame)
            
            if previousShutterState == .generic || previousShutterState == .video {
                self.leftGuide.opacity = Float(guideAlpha)
                self.rightGuide.opacity = Float(guideAlpha)
            } else {
                transition.setAlpha(layer: self.leftGuide, alpha: guideAlpha)
                transition.setAlpha(layer: self.rightGuide, alpha: guideAlpha)
            }
            
            self.leftGuide.cornerRadius = guideSize.height / 2.0
            self.rightGuide.cornerRadius = guideSize.height / 2.0
            
            return size
        }
    }

    func makeView() -> View {
        return View()
    }

    func update(view: View, availableSize: CGSize, state: State, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, state: state, availableSize: availableSize, transition: transition)
    }
}
