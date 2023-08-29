import Foundation
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit
import Photos
import LocalMediaResources
import CameraButtonComponent

enum ShutterButtonState: Equatable {
    case disabled
    case generic
    case video
    case stopRecording
    case holdRecording(progress: Float)
    case transition
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
    let isTablet: Bool
    let hasAppeared: Bool
    let shutterState: ShutterButtonState
    let blobState: ShutterBlobView.BlobState
    let highlightedAction: ActionSlot<Bool>
    let updateOffsetX: ActionSlot<(CGFloat, Transition)>
    let updateOffsetY: ActionSlot<(CGFloat, Transition)>
    
    init(
        isTablet: Bool,
        hasAppeared: Bool,
        shutterState: ShutterButtonState,
        blobState: ShutterBlobView.BlobState,
        highlightedAction: ActionSlot<Bool>,
        updateOffsetX: ActionSlot<(CGFloat, Transition)>,
        updateOffsetY: ActionSlot<(CGFloat, Transition)>
    ) {
        self.isTablet = isTablet
        self.hasAppeared = hasAppeared
        self.shutterState = shutterState
        self.blobState = blobState
        self.highlightedAction = highlightedAction
        self.updateOffsetX = updateOffsetX
        self.updateOffsetY = updateOffsetY
    }
    
    static func ==(lhs: ShutterButtonContentComponent, rhs: ShutterButtonContentComponent) -> Bool {
        if lhs.isTablet != rhs.isTablet {
            return false
        }
        if lhs.hasAppeared != rhs.hasAppeared {
            return false
        }
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
        var blobView: ShutterBlobView?
        private let innerLayer = SimpleShapeLayer()
        private let progressLayer = SimpleShapeLayer()
        
        init() {
            super.init(frame: CGRect())
                        
            self.layer.allowsGroupOpacity = true
            
            self.progressLayer.strokeEnd = 0.0
            
            self.layer.addSublayer(self.innerLayer)
            self.layer.addSublayer(self.ringLayer)
            self.layer.addSublayer(self.progressLayer)
        }

        required init?(coder aDecoder: NSCoder) {
            preconditionFailure()
        }
        
        func updateIsHighlighted(_ isHighlighted: Bool) {
            guard let blobView = self.blobView else {
                return
            }
            let scale: CGFloat = isHighlighted ? 0.8 : 1.0
            let transition = Transition(animation: .curve(duration: 0.3, curve: .easeInOut))
            transition.setTransform(view: blobView, transform: CATransform3DMakeScale(scale, scale, 1.0))
        }
        
        func update(component: ShutterButtonContentComponent, availableSize: CGSize, transition: Transition) -> CGSize {
            self.component = component
            
            if component.hasAppeared && self.blobView == nil {
                self.blobView = ShutterBlobView(test: false)
                self.addSubview(self.blobView!)
                
                Queue.mainQueue().after(0.2) {
                    self.innerLayer.removeFromSuperlayer()
                }
            }
            
            component.highlightedAction.connect { [weak self] highlighted in
                self?.updateIsHighlighted(highlighted)
            }
            
            func rubberBandingOffset(offset: CGFloat, bandingStart: CGFloat) -> CGFloat {
                let bandedOffset = offset - bandingStart
                let range: CGFloat = 60.0
                let coefficient: CGFloat = 0.1
                return bandingStart + (1.0 - (1.0 / ((bandedOffset * coefficient / range) + 1.0))) * range
            }
            
            component.updateOffsetX.connect { [weak self] offset, transition in
                if let self, let blobView = self.blobView {
                    blobView.updateSecondaryOffsetX(offset, transition: transition)
                    if abs(offset) < 60.0 {
                        var bandedOffset = rubberBandingOffset(offset: abs(offset), bandingStart: 0.0)
                        if offset < 0.0 {
                            bandedOffset *= -1.0
                        }
                        blobView.updatePrimaryOffsetX(bandedOffset, transition: transition)
                    } else {
                        blobView.updatePrimaryOffsetX(0.0, transition: .spring(duration: 0.2))
                    }
                }
            }
            
            component.updateOffsetY.connect { [weak self] offset, transition in
                if let self, let blobView = self.blobView {
                    blobView.updateSecondaryOffsetY(offset, transition: transition)
                    if abs(offset) < 60.0 {
                        var bandedOffset = rubberBandingOffset(offset: abs(offset), bandingStart: 0.0)
                        if offset < 0.0 {
                            bandedOffset *= -1.0
                        }
                        blobView.updatePrimaryOffsetY(bandedOffset, transition: transition)
                    } else {
                        blobView.updatePrimaryOffsetY(0.0, transition: .spring(duration: 0.2))
                    }
                }
            }
            
            let innerColor: UIColor
            let innerSize: CGSize
            let ringSize: CGSize
            let ringWidth: CGFloat = 3.0
            var recordingProgress: Float?
            switch component.shutterState {
            case .generic, .disabled:
                innerColor = .white
                innerSize = CGSize(width: 60.0, height: 60.0)
                ringSize = CGSize(width: 68.0, height: 68.0)
            case .video:
                innerColor = videoRedColor
                innerSize = CGSize(width: 60.0, height: 60.0)
                ringSize = CGSize(width: 68.0, height: 68.0)
            case .stopRecording:
                innerColor = videoRedColor
                innerSize = CGSize(width: 26.0, height: 26.0)
                ringSize = CGSize(width: 68.0, height: 68.0)
            case let .holdRecording(progress):
                innerColor = videoRedColor
                innerSize = CGSize(width: 60.0, height: 60.0)
                ringSize = CGSize(width: 92.0, height: 92.0)
                recordingProgress = progress
            case .transition:
                innerColor = videoRedColor
                innerSize = CGSize(width: 60.0, height: 60.0)
                ringSize = CGSize(width: 68.0, height: 68.0)
                recordingProgress = 0.0
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
            
            if let blobView = self.blobView {
                blobView.updateState(component.blobState, transition: transition)
                if component.isTablet {
                    blobView.bounds = CGRect(origin: .zero, size: CGSize(width: maximumShutterSize.width, height: 440.0))
                } else {
                    blobView.bounds = CGRect(origin: .zero, size: CGSize(width: availableSize.width, height: maximumShutterSize.height))
                }
                blobView.center = CGPoint(x: maximumShutterSize.width / 2.0, y: maximumShutterSize.height / 2.0)
            }
            
            self.innerLayer.backgroundColor = innerColor.cgColor
            self.innerLayer.cornerRadius = innerSize.width / 2.0
            self.innerLayer.bounds = CGRect(origin: .zero, size: innerSize)
            self.innerLayer.position = CGPoint(x: maximumShutterSize.width / 2.0, y: maximumShutterSize.height / 2.0)
            
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

final class FlipButtonContentComponent: Component {
    private let action: ActionSlot<Void>
    private let maskFrame: CGRect
    
    init(action: ActionSlot<Void>, maskFrame: CGRect) {
        self.action = action
        self.maskFrame = maskFrame
    }
    
    static func ==(lhs: FlipButtonContentComponent, rhs: FlipButtonContentComponent) -> Bool {
        return lhs.maskFrame == rhs.maskFrame
    }
    
    final class View: UIView {
        private var component: FlipButtonContentComponent?
        
        private let icon = SimpleLayer()
        
        let maskContainerView = UIView()
        private let maskLayer = SimpleLayer()
        private let darkIcon = SimpleLayer()
        
        init() {
            super.init(frame: CGRect())
            
            self.layer.addSublayer(self.icon)
            
            self.maskContainerView.isUserInteractionEnabled = false
            self.maskContainerView.clipsToBounds = true
            
            self.maskContainerView.layer.addSublayer(self.maskLayer)
            self.maskLayer.addSublayer(self.darkIcon)
                        
            self.maskLayer.masksToBounds = true
            self.maskLayer.cornerRadius = 16.0
            
            self.icon.contents = UIImage(bundleImageName: "Camera/FlipIcon")?.cgImage
            self.darkIcon.contents = UIImage(bundleImageName: "Camera/FlipIcon")?.cgImage
            self.darkIcon.layerTintColor = UIColor.black.cgColor
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
            
            let darkAnimation = CASpringAnimation(keyPath: "transform.rotation.z")
            darkAnimation.fromValue = 0.0 as NSNumber
            darkAnimation.toValue = CGFloat.pi as NSNumber
            darkAnimation.mass = 5.0
            darkAnimation.stiffness = 900.0
            darkAnimation.damping = 90.0
            darkAnimation.duration = darkAnimation.settlingDuration
            if #available(iOS 15.0, *) {
                let maxFps = Float(UIScreen.main.maximumFramesPerSecond)
                darkAnimation.preferredFrameRateRange = CAFrameRateRange(minimum: 30.0, maximum: maxFps, preferred: maxFps)
            }
            self.darkIcon.add(darkAnimation, forKey: "transform.rotation.z")
        }
        
        func update(component: FlipButtonContentComponent, availableSize: CGSize, transition: Transition) -> CGSize {
            self.component = component
            
            component.action.connect { [weak self] _ in
                self?.playAnimation()
            }
            
            let size = CGSize(width: 48.0, height: 48.0)
            
            self.icon.position = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
            self.icon.bounds = CGRect(origin: .zero, size: size)
            
            transition.setFrame(layer: self.maskLayer, frame: component.maskFrame)
            
            self.darkIcon.bounds = CGRect(origin: .zero, size: size)
            
            transition.setPosition(layer: self.darkIcon, position: CGPoint(x: -component.maskFrame.minX + size.width / 2.0, y: -component.maskFrame.minY + size.height / 2.0))
            
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

final class LockContentComponent: Component {
    private let maskFrame: CGRect
    
    init(maskFrame: CGRect) {
        self.maskFrame = maskFrame
    }
    
    static func ==(lhs: LockContentComponent, rhs: LockContentComponent) -> Bool {
        return lhs.maskFrame == rhs.maskFrame
    }
    
    final class View: UIView {
        private var component: LockContentComponent?
        
        private let icon = SimpleLayer()
        
        let maskContainerView = UIView()
        private let maskLayer = SimpleLayer()
        private let darkIcon = SimpleLayer()
        
        init() {
            super.init(frame: CGRect())
            
            self.layer.addSublayer(self.icon)
            
            self.maskContainerView.isUserInteractionEnabled = false
            self.maskContainerView.clipsToBounds = true
            
            self.maskContainerView.bounds = CGRect(origin: .zero, size: CGSize(width: 30.0, height: 30.0))
            self.maskContainerView.layer.addSublayer(self.maskLayer)
            self.maskLayer.addSublayer(self.darkIcon)
                        
            self.maskLayer.masksToBounds = true
            self.maskLayer.cornerRadius = 24.0
            
            self.icon.contents = UIImage(bundleImageName: "Camera/LockIcon")?.cgImage
            self.darkIcon.contents = UIImage(bundleImageName: "Camera/LockedIcon")?.cgImage
            self.darkIcon.layerTintColor = UIColor.black.cgColor
        }

        required init?(coder aDecoder: NSCoder) {
            preconditionFailure()
        }
        
        func update(component: LockContentComponent, availableSize: CGSize, transition: Transition) -> CGSize {
            self.component = component
            
            let size = CGSize(width: 30.0, height: 30.0)
            
            self.icon.position = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
            self.icon.bounds = CGRect(origin: .zero, size: size)
            
            transition.setFrame(layer: self.maskLayer, frame: component.maskFrame)
            
            self.darkIcon.bounds = CGRect(origin: .zero, size: size)
            
            transition.setPosition(layer: self.darkIcon, position: CGPoint(x: -component.maskFrame.minX + size.width / 2.0, y: -component.maskFrame.minY + size.height / 2.0))
            
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

private func lastStateImage() -> UIImage {
    let imagePath = NSTemporaryDirectory() + "galleryImage.jpg"
    if let data = try? Data(contentsOf: URL(fileURLWithPath: imagePath)), let image = UIImage(data: data) {
        return image
    } else {
        return UIImage(bundleImageName: "Camera/Placeholder")!
    }
}

private func saveLastStateImage(_ image: UIImage) {
    let imagePath = NSTemporaryDirectory() + "galleryImage.jpg"
    if let data = image.jpegData(compressionQuality: 0.6) {
        try? data.write(to: URL(fileURLWithPath: imagePath))
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
    
    let isTablet: Bool
    let hasAppeared: Bool
    let hasAccess: Bool
    let shutterState: ShutterButtonState
    let lastGalleryAsset: PHAsset?
    let tag: AnyObject?
    let galleryButtonTag: AnyObject?
    let shutterTapped: () -> Void
    let shutterPressed: () -> Void
    let shutterReleased: () -> Void
    let lockRecording: () -> Void
    let flipTapped: () -> Void
    let galleryTapped: () -> Void
    let swipeHintUpdated: (SwipeHint) -> Void
    let zoomUpdated: (CGFloat) -> Void
    let flipAnimationAction: ActionSlot<Void>
    
    init(
        isTablet: Bool,
        hasAppeared: Bool,
        hasAccess: Bool,
        shutterState: ShutterButtonState,
        lastGalleryAsset: PHAsset?,
        tag: AnyObject?,
        galleryButtonTag: AnyObject?,
        shutterTapped: @escaping () -> Void,
        shutterPressed: @escaping () -> Void,
        shutterReleased: @escaping () -> Void,
        lockRecording: @escaping () -> Void,
        flipTapped: @escaping () -> Void,
        galleryTapped: @escaping () -> Void,
        swipeHintUpdated: @escaping (SwipeHint) -> Void,
        zoomUpdated: @escaping (CGFloat) -> Void,
        flipAnimationAction: ActionSlot<Void>
    ) {
        self.isTablet = isTablet
        self.hasAppeared = hasAppeared
        self.hasAccess = hasAccess
        self.shutterState = shutterState
        self.lastGalleryAsset = lastGalleryAsset
        self.tag = tag
        self.galleryButtonTag = galleryButtonTag
        self.shutterTapped = shutterTapped
        self.shutterPressed = shutterPressed
        self.shutterReleased = shutterReleased
        self.lockRecording = lockRecording
        self.flipTapped = flipTapped
        self.galleryTapped = galleryTapped
        self.swipeHintUpdated = swipeHintUpdated
        self.zoomUpdated = zoomUpdated
        self.flipAnimationAction = flipAnimationAction
    }
    
    static func ==(lhs: CaptureControlsComponent, rhs: CaptureControlsComponent) -> Bool {
        if lhs.isTablet != rhs.isTablet {
            return false
        }
        if lhs.hasAppeared != rhs.hasAppeared {
            return false
        }
        if lhs.hasAccess != rhs.hasAccess {
            return false
        }
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
                    if self.cachedAssetImage?.0 != "" {
                        self.cachedAssetImage = nil
                    }
                    if let lastGalleryAsset = self.lastGalleryAsset {
                        self.assetDisposable.set((fetchPhotoLibraryImage(localIdentifier: lastGalleryAsset.localIdentifier, thumbnail: true)
                        |> deliverOnMainQueue).start(next: { [weak self] imageAndDegraded in
                            if let self, let (image, _) = imageAndDegraded {
                                let updated = self.cachedAssetImage?.0 != lastGalleryAsset.localIdentifier
                                self.cachedAssetImage = (lastGalleryAsset.localIdentifier, image)
                                self.updated(transition: .easeInOut(duration: 0.2))
                                
                                if updated {
                                    saveLastStateImage(image)
                                }
                            }
                        }))
                    }
                }
            }
        }
        
        override init() {
            self.cachedAssetImage = ("", lastStateImage())
            
            super.init()
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
        
        private let zoomView = ComponentView<Empty>()
        private let lockView = ComponentView<Empty>()
        private let galleryButtonView = ComponentView<Empty>()
        private let shutterButtonView = ComponentView<Empty>()
        private let flipButtonView = ComponentView<Empty>()
        
        private let leftGuide = SimpleLayer()
        private let rightGuide = SimpleLayer()
        
        private let shutterUpdateOffsetX = ActionSlot<(CGFloat, Transition)>()
        private let shutterUpdateOffsetY = ActionSlot<(CGFloat, Transition)>()
        
        private let shutterHightlightedAction = ActionSlot<Bool>()
        
        private let lockImage = UIImage(bundleImageName: "Camera/LockIcon")
        private let zoomImage = UIImage(bundleImageName: "Camera/ZoomIcon")
        
        private var didFlip = false
        
        private var wasBanding: Bool?
        private var panBlobState: ShutterBlobView.BlobState?
        
        private let hapticFeedback = HapticFeedback()
        
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
            guard let component = self.component else {
                return
            }
            let location = gestureRecognizer.location(in: self)
            switch gestureRecognizer.state {
            case .began:
                component.shutterPressed()
                component.swipeHintUpdated(.zoom)
                if component.isTablet {
                    self.shutterUpdateOffsetY.invoke((0.0, .immediate))
                } else {
                    self.shutterUpdateOffsetX.invoke((0.0, .immediate))
                }
            case .ended, .cancelled:
                if component.isTablet {
                    if location.y > self.frame.height / 2.0 + 60.0 {
                        component.lockRecording()
                        
                        var blobOffset: CGFloat = 0.0
                        if let lockView = self.lockView.view {
                            blobOffset = lockView.center.y - self.frame.height / 2.0
                        }
                        self.updateShutterOffsetY(blobOffset, transition: .spring(duration: 0.35))
                        
                        Queue.mainQueue().after(0.4) {
                            self.updateShutterOffsetY(0.0, transition: .immediate)
                        }
                    } else {
                        self.hapticFeedback.impact(.light)
                        component.shutterReleased()
                        self.updateShutterOffsetY(0.0, transition: .spring(duration: 0.25))
                    }
                } else {
                    if location.x < self.frame.width / 2.0 - 60.0 {
                        component.lockRecording()
                        
                        var blobOffset: CGFloat = 0.0
                        if let galleryButton = self.galleryButtonView.view {
                            blobOffset = galleryButton.center.x - self.frame.width / 2.0
                        }
                        self.updateShutterOffsetX(blobOffset, transition: .spring(duration: 0.35))
                        
                        Queue.mainQueue().after(0.4) {
                            self.updateShutterOffsetX(0.0, transition: .immediate)
                        }
                    } else {
                        self.hapticFeedback.impact(.light)
                        component.shutterReleased()
                        self.updateShutterOffsetX(0.0, transition: .spring(duration: 0.25))
                    }
                }
            default:
                break
            }
        }
        
        private var shutterOffsetX: CGFloat = 0.0
        private var shutterOffsetY: CGFloat = 0.0
        
        private func updateShutterOffsetX(_ offsetX: CGFloat, transition: Transition) {
            self.shutterOffsetX = offsetX
            self.shutterUpdateOffsetX.invoke((offsetX, transition))
            self.state?.updated(transition: transition)
        }
        
        private func updateShutterOffsetY(_ offsetY: CGFloat, transition: Transition) {
            self.shutterOffsetY = offsetY
            self.shutterUpdateOffsetY.invoke((offsetY, transition))
            self.state?.updated(transition: transition)
        }
        
        @objc private func handlePan(_ gestureRecognizer: UIPanGestureRecognizer) {
            guard let component = self.component else {
                return
            }
            func rubberBandingOffset(offset: CGFloat, bandingStart: CGFloat) -> CGFloat {
                let bandedOffset = offset - bandingStart
                let range: CGFloat = 60.0
                let coefficient: CGFloat = 0.4
                return bandingStart + (1.0 - (1.0 / ((bandedOffset * coefficient / range) + 1.0))) * range
            }
            
            var scheduledXOffsetUpdate: (CGFloat, Transition)?
            var scheduledYOffsetUpdate: (CGFloat, Transition)?
            
            let previousPanBlobState = self.panBlobState
            let location = gestureRecognizer.location(in: self)
            switch gestureRecognizer.state {
            case .changed:
                guard case .holdRecording = component.shutterState else {
                    return
                }
                
                var blobOffset: CGFloat = 0.0
                if component.isTablet {
                    if let shutterButton = self.shutterButtonView.view, let lockView = self.lockView.view {
                        blobOffset = max(shutterButton.center.y - 10.0, min(lockView.center.y, location.y))
                    }
                    blobOffset -= self.frame.height / 2.0
                
                    var isBanding = false
                    if location.x < -10.0 {
                        let fraction = 1.0 + min(8.0, ((abs(location.x) - 10.0) / 60.0))
                        component.zoomUpdated(fraction)
                    } else {
                        component.zoomUpdated(1.0)
                    }
                    
                    if location.y > self.frame.height / 2.0 + 30.0 {
                        if location.y > self.frame.height / 2.0 + 60.0 {
                            component.swipeHintUpdated(.releaseLock)
                            if location.y > self.frame.height / 2.0 + 130.0 {
                                self.panBlobState = .lock
                            } else {
                                self.panBlobState = .transientToLock
                            }
                        } else {
                            component.swipeHintUpdated(.lock)
                            self.panBlobState = .video
                            blobOffset = rubberBandingOffset(offset: -blobOffset, bandingStart: 0.0) * -1.0
                            isBanding = true
                        }
                    } else {
                        blobOffset = rubberBandingOffset(offset: -blobOffset, bandingStart: 0.0) * -1.0
                        component.swipeHintUpdated(.zoom)
                        self.panBlobState = .video
                        isBanding = true
                    }
                    var transition: Transition = .immediate
                    if let wasBanding = self.wasBanding, wasBanding != isBanding {
                        //self.hapticFeedback.impact(.light)
                        transition = .spring(duration: 0.35)
                    }
                    self.wasBanding = isBanding
                    scheduledYOffsetUpdate = (blobOffset, transition)
                } else {
                    if let galleryButton = self.galleryButtonView.view, let flipButton = self.flipButtonView.view {
                        blobOffset = max(galleryButton.center.x, min(flipButton.center.x, location.x))
                    }
                    blobOffset -= self.frame.width / 2.0
                    var isBanding = false
                    if location.y < -10.0 {
                        let fraction = min(8.0, ((abs(location.y) - 10.0) / 60.0))
                        component.zoomUpdated(fraction)
                    } else {
                        component.zoomUpdated(0.0)
                    }
                    
                    if location.x < self.frame.width / 2.0 - 30.0 {
                        if location.x < self.frame.width / 2.0 - 60.0 {
                            component.swipeHintUpdated(.releaseLock)
                            if location.x < 85.0 {
                                self.panBlobState = .lock
                            } else {
                                self.panBlobState = .transientToLock
                            }
                        } else {
                            component.swipeHintUpdated(.lock)
                            self.panBlobState = .video
                            blobOffset = rubberBandingOffset(offset: blobOffset, bandingStart: 0.0)
                            isBanding = true
                        }
                    } else if location.x > self.frame.width / 2.0 + 30.0 {
                        self.component?.swipeHintUpdated(.flip)
                        if location.x > self.frame.width / 2.0 + 60.0 {
                            self.panBlobState = .transientToFlip
                            if self.didFlip && location.x < self.frame.width - 100.0 {
                                self.didFlip = false
                            }
                            if !self.didFlip && location.x > self.frame.width - 70.0 {
                                self.didFlip = true
                                self.hapticFeedback.impact(.light)
                                component.flipTapped()
                            }
                        } else {
                            self.didFlip = false
                            self.panBlobState = .video
                            blobOffset = rubberBandingOffset(offset: -blobOffset, bandingStart: 0.0) * -1.0
                            isBanding = true
                        }
                    } else {
                        blobOffset = rubberBandingOffset(offset: blobOffset, bandingStart: 0.0)
                        component.swipeHintUpdated(.zoom)
                        self.panBlobState = .video
                        isBanding = true
                    }
                    var transition: Transition = .immediate
                    if let wasBanding = self.wasBanding, wasBanding != isBanding {
                        //self.hapticFeedback.impact(.light)
                        transition = .spring(duration: 0.35)
                    }
                    self.wasBanding = isBanding
                    scheduledXOffsetUpdate = (blobOffset, transition)
                }
            default:
                self.panBlobState = nil
                self.wasBanding = nil
                self.didFlip = false
            }
            if previousPanBlobState != self.panBlobState, let component = self.component, let state = self.state, let availableSize = self.availableSize {
                let _ = self.update(component: component, state: state, availableSize: availableSize, transition: .spring(duration: 0.5))
            }
            if let (offset, transition) = scheduledXOffsetUpdate {
                self.updateShutterOffsetX(offset, transition: transition)
            }
            if let (offset, transition) = scheduledYOffsetUpdate {
                self.updateShutterOffsetY(offset, transition: transition)
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
            
            let size = component.isTablet ? availableSize : CGSize(width: availableSize.width, height: maximumShutterSize.height)
            let buttonSideInset: CGFloat = 28.0
            //let buttonMaxOffset: CGFloat = 100.0
            
            var isTransitioning = false
            var isRecording = false
            var isHolding = false
            if case .stopRecording = component.shutterState {
                isRecording = true
            } else if case .holdRecording = component.shutterState {
                isRecording = true
                isHolding = true
            } else if case .transition = component.shutterState {
                isTransitioning = true
            }
                     
            let gallerySize: CGSize
            let galleryCornerRadius: CGFloat
            if component.isTablet {
                gallerySize = CGSize(width: 72.0, height: 72.0)
                galleryCornerRadius = 16.0
            } else {
                gallerySize = CGSize(width: 50.0, height: 50.0)
                galleryCornerRadius = 10.0
            }
            let galleryButtonId: String
            if let (identifier, _) = state.cachedAssetImage, identifier == "" {
                galleryButtonId = "placeholder"
            } else {
                galleryButtonId = "gallery"
            }
            let galleryButtonSize = self.galleryButtonView.update(
                transition: transition,
                component: AnyComponent(
                    CameraButton(
                        content: AnyComponentWithIdentity(
                            id: galleryButtonId,
                            component: AnyComponent(
                                Image(
                                    image: state.cachedAssetImage?.1,
                                    size: gallerySize,
                                    contentMode: .scaleAspectFill
                                )
                            )
                        ),
                        tag: component.galleryButtonTag,
                        action: {
                            component.galleryTapped()
                        }
                    )
                ),
                environment: {},
                containerSize: gallerySize
            )
            let galleryButtonFrame: CGRect
            if component.isTablet {
                galleryButtonFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - galleryButtonSize.width) / 2.0), y: size.height - galleryButtonSize.height - 56.0), size: galleryButtonSize)
            } else {
                galleryButtonFrame = CGRect(origin: CGPoint(x: buttonSideInset, y: floorToScreenPixels((size.height - galleryButtonSize.height) / 2.0)), size: galleryButtonSize)
            }
            if let galleryButtonView = self.galleryButtonView.view {
                galleryButtonView.clipsToBounds = true
                galleryButtonView.layer.cornerRadius = galleryCornerRadius
                if galleryButtonView.superview == nil {
                    self.addSubview(galleryButtonView)
                }
                transition.setBounds(view: galleryButtonView, bounds: CGRect(origin: .zero, size: galleryButtonFrame.size))
                transition.setPosition(view: galleryButtonView, position: galleryButtonFrame.center)
                
                transition.setScale(view: galleryButtonView, scale: isRecording || isTransitioning ? 0.1 : 1.0)
                transition.setAlpha(view: galleryButtonView, alpha: isRecording || isTransitioning ? 0.0 : 1.0)
            }
                        
            if !component.isTablet && component.hasAccess {
                let flipButtonOriginX = availableSize.width - 48.0 - buttonSideInset
                let flipButtonMaskFrame: CGRect = CGRect(origin: CGPoint(x: availableSize.width / 2.0 - (flipButtonOriginX + 22.0) + 6.0 + self.shutterOffsetX, y: 8.0), size: CGSize(width: 32.0, height: 32.0))
                
                let flipButtonSize = self.flipButtonView.update(
                    transition: .immediate,
                    component: AnyComponent(
                        CameraButton(
                            content: AnyComponentWithIdentity(
                                id: "flip",
                                component: AnyComponent(
                                    FlipButtonContentComponent(
                                        action: component.flipAnimationAction,
                                        maskFrame: flipButtonMaskFrame
                                    )
                                )
                            ),
                            minSize: CGSize(width: 44.0, height: 44.0),
                            action: {
                                component.flipTapped()
                            }
                        )
                    ),
                    environment: {},
                    containerSize: availableSize
                )
                let flipButtonFrame = CGRect(origin: CGPoint(x: flipButtonOriginX, y: (size.height - flipButtonSize.height) / 2.0), size: flipButtonSize)
                if let flipButtonView = self.flipButtonView.view {
                    if flipButtonView.superview == nil {
                        self.addSubview(flipButtonView)
                    }
                    transition.setBounds(view: flipButtonView, bounds: CGRect(origin: .zero, size: flipButtonFrame.size))
                    transition.setPosition(view: flipButtonView, position: flipButtonFrame.center)
                    
                    transition.setScale(view: flipButtonView, scale: isTransitioning ? 0.01 : 1.0)
                    transition.setAlpha(view: flipButtonView, alpha: isTransitioning ? 0.0 : 1.0)
                }
            } else if let flipButtonView = self.flipButtonView.view {
                flipButtonView.removeFromSuperview()
            }
            
            var blobState: ShutterBlobView.BlobState
            switch component.shutterState {
            case .generic, .disabled:
                blobState = .generic
            case .video, .transition:
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
                                isTablet: component.isTablet,
                                hasAppeared: component.hasAppeared,
                                shutterState: component.shutterState,
                                blobState: blobState,
                                highlightedAction: self.shutterHightlightedAction,
                                updateOffsetX: self.shutterUpdateOffsetX,
                                updateOffsetY: self.shutterUpdateOffsetY
                            )
                        ),
                        automaticHighlight: false,
                        action: { [weak self] in
                            self?.hapticFeedback.impact(.light)
                            self?.shutterUpdateOffsetX.invoke((0.0, .immediate))
                            component.shutterTapped()
                        },
                        highlightedAction: self.shutterHightlightedAction
                    ).minSize(maximumShutterSize)
                ),
                environment: {},
                containerSize: availableSize
            )
            let shutterButtonFrame = CGRect(origin: CGPoint(x: (availableSize.width - shutterButtonSize.width) / 2.0, y: (size.height - shutterButtonSize.height) / 2.0), size: shutterButtonSize)

            let guideSpacing: CGFloat = 9.0
            let guideSize = CGSize(width: isHolding ? component.isTablet ? 84.0 : 60.0 : 0.0, height: 1.0 + UIScreenPixel)
            let guideAlpha: CGFloat = isHolding ? 1.0 : 0.0
            
            let leftGuideFrame = CGRect(origin: CGPoint(x: shutterButtonFrame.minX - guideSpacing - guideSize.width, y: floorToScreenPixels((size.height - guideSize.height) / 2.0)), size: guideSize)
            
            let rightGuideFrame: CGRect
            if component.isTablet {
                rightGuideFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - guideSize.height) / 2.0), y: shutterButtonFrame.maxY + guideSpacing), size: CGSize(width: guideSize.height, height: guideSize.width))
            } else {
                rightGuideFrame = CGRect(origin: CGPoint(x: shutterButtonFrame.maxX + guideSpacing, y: (size.height - guideSize.height) / 2.0), size: guideSize)
            }
            
            transition.setFrame(layer: self.leftGuide, frame: leftGuideFrame)
            transition.setFrame(layer: self.rightGuide, frame: rightGuideFrame)
            
            var leftGuideAlpha = guideAlpha
            let rightGuideAlpha = guideAlpha
            if component.isTablet, availableSize.width < 185.0 {
                leftGuideAlpha = 0.0
            }
            
            if previousShutterState == .generic || previousShutterState == .video {
                self.leftGuide.opacity = Float(leftGuideAlpha)
                self.rightGuide.opacity = Float(rightGuideAlpha)
            } else {
                transition.setAlpha(layer: self.leftGuide, alpha: leftGuideAlpha)
                transition.setAlpha(layer: self.rightGuide, alpha: rightGuideAlpha)
            }
            
            self.leftGuide.cornerRadius = guideSize.height / 2.0
            self.rightGuide.cornerRadius = guideSize.height / 2.0
            
            let hintIconSize = CGSize(width: 30.0, height: 30.0)
            if component.isTablet {
                let _ = self.zoomView.update(
                    transition: .immediate,
                    component: AnyComponent(
                        Image(
                            image: self.zoomImage,
                            size: hintIconSize
                        )
                    ),
                    environment: {},
                    containerSize: hintIconSize
                )
                let zoomFrame = CGRect(origin: CGPoint(x: availableSize.width / 2.0 - 150.0 - hintIconSize.width, y: floorToScreenPixels((availableSize.height - hintIconSize.height) / 2.0)), size: hintIconSize)
                if let zoomView = self.zoomView.view {
                    if zoomView.superview == nil {
                        self.addSubview(zoomView)
                    }
                    transition.setBounds(view: zoomView, bounds: CGRect(origin: .zero, size: zoomFrame.size))
                    transition.setPosition(view: zoomView, position: zoomFrame.center)
                    
                    transition.setScale(view: zoomView, scale: isHolding ? 1.0 : 0.1)
                    transition.setAlpha(view: zoomView, alpha: isHolding && leftGuideAlpha > 0.0 ? 1.0 : 0.0)
                }
            } else if let zoomView = self.zoomView.view {
                zoomView.removeFromSuperview()
            }
            
            let lockFrame: CGRect
            var lockMaskFrame: CGRect
            if component.isTablet {
                lockFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - hintIconSize.width) / 2.0), y: availableSize.height / 2.0 + 152.0), size: hintIconSize)
                lockMaskFrame = CGRect(origin: CGPoint(x: -9.0, y: availableSize.height / 2.0 - lockFrame.midY - 9.0 + self.shutterOffsetY), size: CGSize(width: 48.0, height: 48.0))
                if self.panBlobState == .transientToLock {
                    lockMaskFrame = lockMaskFrame.offsetBy(dx: 0.0, dy: -8.0)
                }
            } else {
                lockFrame = galleryButtonFrame.insetBy(dx: (gallerySize.width - hintIconSize.width) / 2.0, dy: (gallerySize.height - hintIconSize.height) / 2.0)
                lockMaskFrame = CGRect(origin: CGPoint(x: availableSize.width / 2.0 - lockFrame.midX - 9.0 + self.shutterOffsetX, y: -9.0), size: CGSize(width: 48.0, height: 48.0))
                if self.panBlobState == .transientToLock {
                    lockMaskFrame = lockMaskFrame.offsetBy(dx: 8.0, dy: 0.0)
                }
            }
            
            let _ = self.lockView.update(
                transition: .immediate,
                component: AnyComponent(
                    CameraButton(
                        content: AnyComponentWithIdentity(
                            id: "lock",
                            component: AnyComponent(
                                LockContentComponent(
                                    maskFrame: lockMaskFrame
                                )
                            )
                        ),
                        minSize: hintIconSize,
                        action: {
                            component.lockRecording()
                        }
                    )
                ),
                environment: {},
                containerSize: hintIconSize
            )
            if let lockView = self.lockView.view {
                if lockView.superview == nil {
                    self.addSubview(lockView)
                }
                transition.setBounds(view: lockView, bounds: CGRect(origin: .zero, size: lockFrame.size))
                transition.setPosition(view: lockView, position: lockFrame.center)
                
                transition.setScale(view: lockView, scale: isHolding ? 1.0 : 0.1)
                transition.setAlpha(view: lockView, alpha: isHolding ? 1.0 : 0.0)
                
                if let buttonView = lockView as? CameraButton.View, let lockMaskView = buttonView.contentView.componentView as? LockContentComponent.View {
                    transition.setAlpha(view: lockMaskView.maskContainerView, alpha: isHolding ? 1.0 : 0.0)
                    transition.setSublayerTransform(layer: lockMaskView.maskContainerView.layer, transform: isHolding ? CATransform3DIdentity : CATransform3DMakeScale(0.1, 0.1, 1.0))
                }
            }
            
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
                let alpha: CGFloat = component.hasAccess ? 1.0 : 0.3
                transition.setBounds(view: shutterButtonView, bounds: CGRect(origin: .zero, size: shutterButtonFrame.size))
                transition.setPosition(view: shutterButtonView, position: shutterButtonFrame.center)
                transition.setScale(view: shutterButtonView, scale: isTransitioning ? 0.01 : 1.0)
                transition.setAlpha(view: shutterButtonView, alpha: isTransitioning ? 0.0 : alpha)
                
                shutterButtonView.isUserInteractionEnabled = component.hasAccess
            }
            
            if let buttonView = self.flipButtonView.view as? CameraButton.View, let contentView = buttonView.contentView.componentView as? FlipButtonContentComponent.View {
                if contentView.maskContainerView.superview == nil {
                    self.addSubview(contentView.maskContainerView)
                }
                contentView.maskContainerView.frame = contentView.convert(contentView.bounds, to: self)
            }
            
            if let buttonView = self.lockView.view as? CameraButton.View, let contentView = buttonView.contentView.componentView as? LockContentComponent.View {
                if contentView.maskContainerView.superview == nil {
                    self.addSubview(contentView.maskContainerView)
                }
                contentView.maskContainerView.center = buttonView.center
            }
            
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
