import Foundation
import UIKit
import Display
import AsyncDisplayKit
import ComponentFlow
import SwiftSignalKit
import ViewControllerComponent
import ComponentDisplayAdapters
import TelegramPresentationData
import AccountContext
import TelegramCore
import PresentationDataUtils
import Camera
import MultilineTextComponent
import BlurredBackgroundComponent
import Photos

let videoRedColor = UIColor(rgb: 0xff3b30)

enum CameraMode: Equatable {
    case photo
    case video
}

private struct CameraState {
    enum Recording: Equatable {
        case none
        case holding
        case handsFree
    }
    let mode: CameraMode
    let flashMode: Camera.FlashMode
    let recording: Recording
    let duration: Double
    
    func updatedMode(_ mode: CameraMode) -> CameraState {
        return CameraState(mode: mode, flashMode: self.flashMode, recording: self.recording, duration: self.duration)
    }
    
    func updatedFlashMode(_ flashMode: Camera.FlashMode) -> CameraState {
        return CameraState(mode: self.mode, flashMode: flashMode, recording: self.recording, duration: self.duration)
    }
    
    func updatedRecording(_ recording: Recording) -> CameraState {
        return CameraState(mode: self.mode, flashMode: self.flashMode, recording: recording, duration: self.duration)
    }
    
    func updatedDuration(_ duration: Double) -> CameraState {
        return CameraState(mode: self.mode, flashMode: self.flashMode, recording: self.recording, duration: duration)
    }
}

enum CameraScreenTransition {
    case animateIn
    case animateOut
}

private let cancelButtonTag = GenericComponentViewTag()
private let flashButtonTag = GenericComponentViewTag()
private let shutterButtonTag = GenericComponentViewTag()
private let flipButtonTag = GenericComponentViewTag()
private let zoomControlTag = GenericComponentViewTag()

private final class CameraScreenComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let camera: Camera
    let present: (ViewController) -> Void
    let push: (ViewController) -> Void
    let completion: (CameraScreen.Result) -> Void
    let shootAction: ActionSlot<Void>
    
    init(
        context: AccountContext,
        camera: Camera,
        present: @escaping (ViewController) -> Void,
        push: @escaping (ViewController) -> Void,
        completion: @escaping (CameraScreen.Result) -> Void,
        shootAction: ActionSlot<Void>
    ) {
        self.context = context
        self.camera = camera
        self.present = present
        self.push = push
        self.completion = completion
        self.shootAction = shootAction
    }
    
    static func ==(lhs: CameraScreenComponent, rhs: CameraScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        enum ImageKey: Hashable {
            case cancel
            case flip
            case flash
        }
        private var cachedImages: [ImageKey: UIImage] = [:]
        func image(_ key: ImageKey) -> UIImage {
            if let image = self.cachedImages[key] {
                return image
            } else {
                var image: UIImage
                switch key {
                case .cancel:
                    image = UIImage(bundleImageName: "Camera/CloseIcon")!
                case .flip:
                    image = UIImage(bundleImageName: "Camera/FlipIcon")!
                case .flash:
                    image = UIImage(bundleImageName: "Camera/FlashIcon")!
                }
                cachedImages[key] = image
                return image
            }
        }
        
        private let context: AccountContext
        fileprivate let camera: Camera
        private let present: (ViewController) -> Void
        private let completion: (CameraScreen.Result) -> Void
        private let shootAction: ActionSlot<Void>
        
        private var cameraStateDisposable: Disposable?
        private var resultDisposable = MetaDisposable()
        
        private var mediaAssetsContext: MediaAssetsContext
        fileprivate var lastGalleryAsset: PHAsset?
        private var lastGalleryAssetsDisposable: Disposable?
        
        var cameraState = CameraState(mode: .photo, flashMode: .off, recording: .none, duration: 0.0)
        var swipeHint: CaptureControlsComponent.SwipeHint = .none
        
        init(context: AccountContext, camera: Camera, present: @escaping (ViewController) -> Void, completion: @escaping (CameraScreen.Result) -> Void, shootAction: ActionSlot<Void>) {
            self.context = context
            self.camera = camera
            self.present = present
            self.completion = completion
            self.shootAction = shootAction
            
            self.mediaAssetsContext = MediaAssetsContext()
            
            super.init()
            
            self.cameraStateDisposable = (camera.flashMode
            |> deliverOnMainQueue).start(next: { [weak self] flashMode in
                guard let self else {
                    return
                }
                self.cameraState = self.cameraState.updatedFlashMode(flashMode)
                self.updated(transition: .easeInOut(duration: 0.2))
            })
            
            self.lastGalleryAssetsDisposable = (self.mediaAssetsContext.recentAssets()
            |> map { fetchResult in
                return fetchResult?.lastObject
            }
            |> deliverOnMainQueue).start(next: { [weak self] asset in
                guard let self else {
                    return
                }
                self.lastGalleryAsset = asset
                self.updated(transition: .easeInOut(duration: 0.2))
            })
        }
        
        deinit {
            self.cameraStateDisposable?.dispose()
            self.lastGalleryAssetsDisposable?.dispose()
            self.resultDisposable.dispose()
        }
        
        func updateCameraMode(_ mode: CameraMode) {
            self.cameraState = self.cameraState.updatedMode(mode)
            self.updated(transition: .spring(duration: 0.3))
        }
        
        func updateSwipeHint(_ hint: CaptureControlsComponent.SwipeHint) {
            self.swipeHint = hint
            self.updated(transition: .easeInOut(duration: 0.2))
        }
        
        func takePhoto() {
            self.resultDisposable.set((self.camera.takePhoto()
            |> deliverOnMainQueue).start(next: { [weak self] value in
                if let self {
                    switch value {
                    case .began:
                        self.shootAction.invoke(Void())
                    case let .finished(image):
                        self.completion(.image(image))
                    case .failed:
                        break
                    }
                }
            }))
        }
        
        func startVideoRecording(pressing: Bool) {
            self.cameraState = self.cameraState.updatedDuration(0.0).updatedRecording(pressing ? .holding : .handsFree)
            self.resultDisposable.set((self.camera.startRecording()
            |> deliverOnMainQueue).start(next: { [weak self] duration in
                if let self {
                    self.cameraState = self.cameraState.updatedDuration(duration)
                    self.updated(transition: .easeInOut(duration: 0.1))
                }
            }))
            self.updated(transition: .spring(duration: 0.4))
        }
        
        func stopVideoRecording() {
            self.cameraState = self.cameraState.updatedRecording(.none).updatedDuration(0.0)
            self.resultDisposable.set((self.camera.stopRecording()
            |> deliverOnMainQueue).start(next: { [weak self] path in
                if let self, let path {
                    self.completion(.video(path))
                }
            }))
            self.updated(transition: .spring(duration: 0.4))
        }
        
        func lockVideoRecording() {
            self.cameraState = self.cameraState.updatedRecording(.handsFree)
            self.updated(transition: .spring(duration: 0.4))
        }
    }
    
    func makeState() -> State {
        return State(context: self.context, camera: self.camera, present: self.present, completion: self.completion, shootAction: self.shootAction)
    }
    
    static var body: Body {
        let cancelButton = Child(Button.self)
        let captureControls = Child(CaptureControlsComponent.self)
        let zoomControl = Child(ZoomComponent.self)
        let flashButton = Child(Button.self)
        let modeControl = Child(ModeComponent.self)
        let hintLabel = Child(MultilineTextComponent.self)
        
        let timeBackground = Child(RoundedRectangle.self)
        let timeLabel = Child(MultilineTextComponent.self)
        
        return { context in
            let environment = context.environment[ViewControllerComponentContainer.Environment.self].value
            let component = context.component
            let state = context.state
            let controller = environment.controller
            let availableSize = context.availableSize

            let accountContext = component.context
            let push = component.push
            let completion = component.completion
            
            let topControlInset: CGFloat = 20.0
            
            if case .none = state.cameraState.recording {
                let cancelButton = cancelButton.update(
                    component: Button(
                        content: AnyComponent(Image(
                            image: state.image(.cancel),
                            size: CGSize(width: 40.0, height: 40.0)
                        )),
                        action: {
                            guard let controller = controller() as? CameraScreen else {
                                return
                            }
                            controller.requestDismiss(animated: true)
                        }
                    ).tagged(cancelButtonTag),
                    availableSize: CGSize(width: 40.0, height: 40.0),
                    transition: .immediate
                )
                context.add(cancelButton
                    .position(CGPoint(x: topControlInset + cancelButton.size.width / 2.0, y: environment.safeInsets.top + topControlInset + cancelButton.size.height / 2.0))
                    .appear(.default(scale: true))
                    .disappear(.default(scale: true))
                    .cornerRadius(20.0)
                )
                
                let flashButton = flashButton.update(
                    component: Button(
                        content: AnyComponent(Image(image: state.image(.flash))),
                        action: { [weak state] in
                            guard let state else {
                                return
                            }
                            if state.cameraState.flashMode == .off {
                                state.camera.setFlashMode(.on)
                            } else {
                                state.camera.setFlashMode(.off)
                            }
                        }
                    ).tagged(flashButtonTag),
                    availableSize: CGSize(width: 40.0, height: 40.0),
                    transition: .immediate
                )
                context.add(flashButton
                    .position(CGPoint(x: availableSize.width - topControlInset - flashButton.size.width / 2.0, y: environment.safeInsets.top + topControlInset + flashButton.size.height / 2.0))
                    .appear(.default(scale: true))
                    .disappear(.default(scale: true))
                    .cornerRadius(20.0)
                )
            }
            
            if case .holding = state.cameraState.recording {
                
            } else {
                let _ = zoomControl
//                let zoomControl = zoomControl.update(
//                    component: ZoomComponent(
//                        availableValues: state.camera.metrics.zoomLevels,
//                        value: 1.0,
//                        tag: zoomControlTag
//                    ),
//                    availableSize: context.availableSize,
//                    transition: context.transition
//                )
//                context.add(zoomControl
//                    .position(CGPoint(x: context.availableSize.width / 2.0, y: availableSize.height - zoomControl.size.height / 2.0 - 187.0 - environment.safeInsets.bottom))
//                    .appear(.default(alpha: true))
//                    .disappear(.default(alpha: true))
//                )
            }
            
            let shutterState: ShutterButtonState
            switch state.cameraState.recording {
            case .handsFree:
                shutterState = .stopRecording
            case .holding:
                shutterState = .holdRecording(progress: min(1.0, Float(state.cameraState.duration / 60.0)))
            case .none:
                switch state.cameraState.mode {
                case .photo:
                    shutterState = .generic
                case .video:
                    shutterState = .video
                }
            }
            
            let captureControls = captureControls.update(
                component: CaptureControlsComponent(
                    shutterState: shutterState,
                    lastGalleryAsset: state.lastGalleryAsset,
                    tag: shutterButtonTag,
                    shutterTapped: { [weak state] in
                        guard let state else {
                            return
                        }
                        if case .none = state.cameraState.recording {
                            if state.cameraState.mode == .photo {
                                state.takePhoto()
                            } else if state.cameraState.mode == .video {
                                state.startVideoRecording(pressing: false)
                            }
                        } else {
                            state.stopVideoRecording()
                        }
                    },
                    shutterPressed: { [weak state] in
                        guard let state, case .none = state.cameraState.recording else {
                            return
                        }
                        state.startVideoRecording(pressing: true)
                    },
                    shutterReleased: { [weak state] in
                        guard let state, state.cameraState.recording != .none else {
                            return
                        }
                        state.stopVideoRecording()
                    },
                    lockRecording: { [weak state] in
                        guard let state, state.cameraState.recording != .none else {
                            return
                        }
                        state.lockVideoRecording()
                    },
                    flipTapped: { [weak state] in
                        guard let state else {
                            return
                        }
                        state.camera.togglePosition()
                    },
                    galleryTapped: {
                        var dismissGalleryControllerImpl: (() -> Void)?
                        let controller = accountContext.sharedContext.makeMediaPickerScreen(context: accountContext, completion: { asset in
                            dismissGalleryControllerImpl?()
                            completion(.asset(asset))
                        })
                        dismissGalleryControllerImpl = { [weak controller] in
                            controller?.dismiss(animated: false)
                        }
                        push(controller)
                    },
                    swipeHintUpdated: { hint in
                        state.updateSwipeHint(hint)
                    }
                ),
                availableSize: context.availableSize,
                transition: context.transition
            )
            context.add(captureControls
                .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height - captureControls.size.height / 2.0 - 77.0 - environment.safeInsets.bottom))
            )
            
            var isVideoRecording = false
            if case .video = state.cameraState.mode {
                isVideoRecording = true
            } else if state.cameraState.recording != .none {
                isVideoRecording = true
            }
            
            if isVideoRecording {
                let duration = Int(state.cameraState.duration)
                let durationString =  String(format: "%02d:%02d", (duration / 60) % 60, duration % 60)
                let timeLabel = timeLabel.update(
                    component: MultilineTextComponent(
                        text: .plain(NSAttributedString(string: durationString, font: Font.with(size: 21.0, design: .camera), textColor: .white)),
                        horizontalAlignment: .center,
                        textShadowColor: UIColor(rgb: 0x000000, alpha: 0.2)
                    ),
                    availableSize: context.availableSize,
                    transition: context.transition
                )
                
                if state.cameraState.recording != .none {
                    let timeBackground = timeBackground.update(
                        component: RoundedRectangle(color: videoRedColor, cornerRadius: 4.0),
                        availableSize: CGSize(width: timeLabel.size.width + 8.0, height: 28.0),
                        transition: context.transition
                    )
                    context.add(timeBackground
                        .position(CGPoint(x: context.availableSize.width / 2.0, y: environment.safeInsets.top + 40.0))
                        .appear(.default(alpha: true))
                        .disappear(.default(alpha: true))
                    )
                }
                
                context.add(timeLabel
                    .position(CGPoint(x: context.availableSize.width / 2.0, y:  environment.safeInsets.top + 40.0))
                    .appear(.default(alpha: true))
                    .disappear(.default(alpha: true))
                )
                
                if case .holding = state.cameraState.recording {
                    let hintText: String?
                    switch state.swipeHint {
                    case .none:
                        hintText = nil
                    case .zoom:
                        hintText = "Swipe up to zoom"
                    case .lock:
                        hintText = "Swipe left to lock"
                    case .releaseLock:
                        hintText = "Release to lock"
                    case .flip:
                        hintText = "Swipe right to flip"
                    }
                    if let hintText {
                        let hintLabel = hintLabel.update(
                            component: MultilineTextComponent(
                                text: .plain(NSAttributedString(string: hintText.uppercased(), font: Font.with(size: 14.0, design: .camera, weight: .semibold), textColor: .white)),
                                horizontalAlignment: .center
                            ),
                            availableSize: context.availableSize,
                            transition: .immediate
                        )
                        context.add(hintLabel
                            .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height - 35.0 - hintLabel.size.height - environment.safeInsets.bottom))
                            .appear(.default(alpha: true))
                            .disappear(.default(alpha: true))
                        )
                    }
                }
            }
            
            if case .none = state.cameraState.recording {
                let modeControl = modeControl.update(
                    component: ModeComponent(
                        availableModes: [.photo, .video],
                        currentMode: state.cameraState.mode,
                        updatedMode: { [weak state] mode in
                            if let state {
                                state.updateCameraMode(mode)
                            }
                        }
                    ),
                    availableSize: context.availableSize,
                    transition: context.transition
                )
                context.add(modeControl
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height - 7.0 - modeControl.size.height - environment.safeInsets.bottom))
                    .appear(.default(alpha: true))
                    .disappear(.default(alpha: true))
                )
            }
            return context.availableSize
        }
    }
}

public class CameraScreen: ViewController {
    public enum Mode {
        case generic
        case story
        case instantVideo
    }
    
    public enum Result {
        case image(UIImage)
        case video(String)
        case asset(PHAsset)
    }

    fileprivate final class Node: ViewControllerTracingNode {
        private weak var controller: CameraScreen?
        private let context: AccountContext
        private let updateState: ActionSlot<CameraState>

        private let backgroundEffectView: UIVisualEffectView
        private let backgroundDimView: UIView
        fileprivate let componentHost: ComponentView<ViewControllerComponentContainer.Environment>
        private let previewContainerView: UIView
        fileprivate let previewView: CameraPreviewView
        fileprivate let previewBlurView: UIVisualEffectView
        fileprivate let camera: Camera

        private var presentationData: PresentationData
        private let hapticFeedback = HapticFeedback()
        private var validLayout: ContainerViewLayout?
        
        private var changingPositionDisposable: Disposable?

        private let shootAction: ActionSlot<Void>
        
        init(controller: CameraScreen) {
            self.controller = controller
            self.context = controller.context
            self.updateState = ActionSlot<CameraState>()
            self.shootAction = ActionSlot<Void>()

            self.presentationData = self.context.sharedContext.currentPresentationData.with { $0 }

            self.backgroundEffectView = UIVisualEffectView(effect: nil)
            self.backgroundDimView = UIView()
            self.backgroundDimView.backgroundColor = UIColor(rgb: 0x000000)
            
            self.componentHost = ComponentView<ViewControllerComponentContainer.Environment>()
            
            self.previewContainerView = UIView()
            self.previewContainerView.clipsToBounds = true
            self.previewContainerView.layer.cornerRadius = 12.0
            
            self.previewBlurView = UIVisualEffectView(effect: nil)
            self.previewBlurView.isUserInteractionEnabled = false
            
            if let holder = controller.holder {
                self.previewView = holder.previewView
                self.camera = holder.camera
            } else {
                self.previewView = CameraPreviewView(test: false)!
                self.camera = Camera(configuration: Camera.Configuration(preset: .hd1920x1080, position: .back, audio: true, photo: true, metadata: false))
                self.camera.attachPreviewView(self.previewView)
            }
            self.previewView.clipsToBounds = true

            super.init()
            
            self.backgroundColor = .clear
            
            self.view.addSubview(self.backgroundEffectView)
            self.view.addSubview(self.backgroundDimView)
            
            self.view.addSubview(self.previewContainerView)
            self.previewContainerView.addSubview(self.previewView)
            self.previewContainerView.addSubview(self.previewBlurView)
            
            self.changingPositionDisposable = (self.camera.changingPosition
            |> deliverOnMainQueue).start(next: { [weak self] value in
                if let self {
                    UIView.animate(withDuration: 0.5) {
                        if value {
                            if #available(iOS 13.0, *) {
                                self.previewBlurView.effect = UIBlurEffect(style: .systemThinMaterialDark)
                            }
                        } else {
                            self.previewBlurView.effect = nil
                        }
                    }
                }
            })
            
            self.shootAction.connect { [weak self] _ in
                self?.previewView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
            }
        }
        
        deinit {
            self.changingPositionDisposable?.dispose()
        }
        
        override func didLoad() {
            super.didLoad()
            
            self.view.disablesInteractiveModalDismiss = true
            self.view.disablesInteractiveKeyboardGestureRecognizer = true
            
            let pinchGestureRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(self.handlePinch(_:)))
            self.previewView.addGestureRecognizer(pinchGestureRecognizer)
            
            let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.handlePan(_:)))
            self.previewView.addGestureRecognizer(panGestureRecognizer)
        }
        
        @objc private func handlePinch(_ gestureRecognizer: UIPinchGestureRecognizer) {
            switch gestureRecognizer.state {
            case .began:
                gestureRecognizer.scale = 1.0
            case .changed:
                let scale = gestureRecognizer.scale
                self.camera.setZoomLevel(scale)
            default:
                break
            }
        }
        
        private var panStartLocation: CGPoint?
        @objc private func handlePan(_ gestureRecognizer: UIPanGestureRecognizer) {
            let location = gestureRecognizer.location(in: self.view)
            switch gestureRecognizer.state {
            case .began:
                self.panStartLocation = location
            case .changed:
                guard let _ = self.panStartLocation else {
                    return
                }
               // let translation = location.y - panStartLocation.y
                
            default:
                break
            }
        }

        func animateIn() {
            guard let layout = self.validLayout else {
                return
            }
            self.backgroundDimView.alpha = 0.0
            UIView.animate(withDuration: 0.4, animations: {
                self.backgroundEffectView.effect = UIBlurEffect(style: .dark)
                self.backgroundDimView.alpha = 1.0
                
            }, completion: { _ in
                self.backgroundEffectView.isHidden = true
            })

            self.camera.focus(at: CGPoint(x: 0.5, y: 0.5))
            self.camera.startCapture()
            
            self.previewContainerView.layer.animatePosition(from: CGPoint(x: 0.0, y: layout.size.height / 2.0 - layout.intrinsicInsets.bottom - 22.0), to: .zero, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            self.componentHost.view?.layer.animatePosition(from: CGPoint(x: 0.0, y: layout.size.height / 2.0 - layout.intrinsicInsets.bottom - 22.0), to: .zero, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
            self.previewContainerView.layer.animateScale(from: 0.2, to: 1.0, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring)
            self.componentHost.view?.layer.animateScale(from: 0.2, to: 1.0, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring)
        }

        func animateOut(completion: @escaping () -> Void) {
            guard let layout = self.validLayout else {
                return
            }
            self.backgroundEffectView.isHidden = false
            
            UIView.animate(withDuration: 0.25, animations: {
                self.backgroundEffectView.effect = nil
                self.backgroundDimView.alpha = 0.0
            })
            
            self.previewContainerView.layer.animatePosition(from: .zero, to: CGPoint(x: 0.0, y: layout.size.height / 2.0 - layout.intrinsicInsets.bottom - 8.0), duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, additive: true)
            self.componentHost.view?.layer.animatePosition(from: .zero, to: CGPoint(x: 0.0, y: layout.size.height / 2.0 - layout.intrinsicInsets.bottom - 8.0), duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, additive: true, completion: { _ in
                completion()
            })
            self.previewContainerView.layer.animateScale(from: 1.0, to: 0.01, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
            self.previewContainerView.layer.animateBounds(from: self.previewContainerView.bounds, to: CGRect(origin: .zero, size: CGSize(width: self.previewContainerView.bounds.width, height: self.previewContainerView.bounds.width)), duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
            let transition = ContainedViewLayoutTransition.animated(duration: 0.4, curve: .spring)
            transition.updateCornerRadius(layer: self.previewContainerView.layer, cornerRadius: self.previewContainerView.bounds.width / 2.0)
            self.componentHost.view?.layer.animateScale(from: 1.0, to: 0.2, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
            self.componentHost.view?.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
            self.previewContainerView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.35, removeOnCompletion: false)
        }

        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            let result = super.hitTest(point, with: event)
            if result == self.componentHost.view {
                return self.previewView
            }
            return result
        }

        func containerLayoutUpdated(layout: ContainerViewLayout, forceUpdate: Bool = false, animateOut: Bool = false, transition: Transition) {
            guard let controller = self.controller else {
                return
            }
            let isFirstTime = self.validLayout == nil
            self.validLayout = layout

            let topInset: CGFloat = 60.0 //layout.intrinsicInsets.top + layout.safeInsets.top
            
            let environment = ViewControllerComponentContainer.Environment(
                statusBarHeight: layout.statusBarHeight ?? 0.0,
                navigationHeight: 0.0,
                safeInsets: UIEdgeInsets(
                    top: topInset,
                    left: layout.safeInsets.left,
                    bottom: layout.intrinsicInsets.bottom + layout.safeInsets.bottom,
                    right: layout.safeInsets.right
                ),
                inputHeight: layout.inputHeight ?? 0.0,
                metrics: layout.metrics,
                deviceMetrics: layout.deviceMetrics,
                orientation: nil,
                isVisible: true,
                theme: self.presentationData.theme,
                strings: self.presentationData.strings,
                dateTimeFormat: self.presentationData.dateTimeFormat,
                controller: { [weak self] in
                    return self?.controller
                }
            )

            var transition = transition
            if isFirstTime {
                transition = transition.withUserData(CameraScreenTransition.animateIn)
            } else if animateOut {
                transition = transition.withUserData(CameraScreenTransition.animateOut)
            }

            let componentSize = self.componentHost.update(
                transition: transition,
                component: AnyComponent(
                    CameraScreenComponent(
                        context: self.context,
                        camera: self.camera,
                        present: { [weak self] c in
                            self?.controller?.present(c, in: .window(.root))
                        },
                        push: { [weak self] c in
                            self?.controller?.push(c)
                        },
                        completion: controller.completion,
                        shootAction: self.shootAction
                    )
                ),
                environment: {
                    environment
                },
                forceUpdate: forceUpdate || animateOut,
                containerSize: layout.size
            )
            if let componentView = self.componentHost.view {
                if componentView.superview == nil {
                    self.view.insertSubview(componentView, at: 3)
                    componentView.clipsToBounds = true
                }

                let componentFrame = CGRect(origin: .zero, size: componentSize)
                transition.setFrame(view: componentView, frame: CGRect(origin: componentFrame.origin, size: CGSize(width: componentFrame.width, height: componentFrame.height)))

                if isFirstTime {
                    self.animateIn()
                }
            }
            
            transition.setFrame(view: self.backgroundDimView, frame: CGRect(origin: .zero, size: layout.size))
            transition.setFrame(view: self.backgroundEffectView, frame: CGRect(origin: .zero, size: layout.size))
            
            let previewSize = CGSize(width: layout.size.width, height: floorToScreenPixels(layout.size.width * 1.77778))
            let previewFrame = CGRect(origin: CGPoint(x: 0.0, y: 60.0), size: previewSize)
            transition.setFrame(view: self.previewContainerView, frame: previewFrame)
            transition.setFrame(view: self.previewView, frame: CGRect(origin: .zero, size: previewFrame.size))
            transition.setFrame(view: self.previewBlurView, frame: CGRect(origin: .zero, size: previewFrame.size))
        }
    }

    fileprivate var node: Node {
        return self.displayNode as! Node
    }

    private let context: AccountContext
    fileprivate let mode: Mode
    fileprivate let holder: CameraHolder?
    fileprivate let completion: (CameraScreen.Result) -> Void

    public init(context: AccountContext, mode: Mode, holder: CameraHolder? = nil, completion: @escaping (CameraScreen.Result) -> Void) {
        self.context = context
        self.mode = mode
        self.holder = holder
        self.completion = completion

        super.init(navigationBarPresentationData: nil)

        self.statusBar.statusBarStyle = .White
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
        
        self.navigationPresentation = .flatModal
    }

    required public init(coder: NSCoder) {
        preconditionFailure()
    }

    override public func loadDisplayNode() {
        self.displayNode = Node(controller: self)

        super.displayNodeDidLoad()
    }

    private var isDismissed = false
    fileprivate func requestDismiss(animated: Bool) {
        guard !self.isDismissed else {
            return
        }
        self.statusBar.statusBarStyle = .Ignore
        self.isDismissed = true
        if animated {
            self.node.animateOut(completion: {
                self.dismiss(animated: false)
            })
        } else {
            self.dismiss(animated: false)
        }
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)

        (self.displayNode as! Node).containerLayoutUpdated(layout: layout, transition: Transition(transition))
    }
}
