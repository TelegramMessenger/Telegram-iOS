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
private let zoomControlTag = GenericComponentViewTag()
private let captureControlsTag = GenericComponentViewTag()
private let modeControlTag = GenericComponentViewTag()

private final class CameraScreenComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let camera: Camera
    let changeMode: ActionSlot<CameraMode>
    let isDismissing: Bool
    let present: (ViewController) -> Void
    let push: (ViewController) -> Void
    let completion: ActionSlot<Signal<CameraScreen.Result, NoError>>
    
    init(
        context: AccountContext,
        camera: Camera,
        changeMode: ActionSlot<CameraMode>,
        isDismissing: Bool,
        present: @escaping (ViewController) -> Void,
        push: @escaping (ViewController) -> Void,
        completion: ActionSlot<Signal<CameraScreen.Result, NoError>>
    ) {
        self.context = context
        self.camera = camera
        self.changeMode = changeMode
        self.isDismissing = isDismissing
        self.present = present
        self.push = push
        self.completion = completion
    }
    
    static func ==(lhs: CameraScreenComponent, rhs: CameraScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.isDismissing != rhs.isDismissing {
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
        private let completion: ActionSlot<Signal<CameraScreen.Result, NoError>>
        
        private var cameraStateDisposable: Disposable?
        private var resultDisposable = MetaDisposable()
        
        private var mediaAssetsContext: MediaAssetsContext
        fileprivate var lastGalleryAsset: PHAsset?
        private var lastGalleryAssetsDisposable: Disposable?
        
        var cameraState = CameraState(mode: .photo, flashMode: .off, recording: .none, duration: 0.0)
        var swipeHint: CaptureControlsComponent.SwipeHint = .none
        
        init(context: AccountContext, camera: Camera, present: @escaping (ViewController) -> Void, completion: ActionSlot<Signal<CameraScreen.Result, NoError>>) {
            self.context = context
            self.camera = camera
            self.present = present
            self.completion = completion
            
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
            let takePhoto = self.camera.takePhoto()
            |> mapToSignal { value -> Signal<CameraScreen.Result, NoError> in
                switch value {
                case .began:
                    return .single(.pendingImage)
                case let .finished(image):
                    return .single(.image(image))
                case .failed:
                    return .complete()
                }
            }
            self.completion.invoke(takePhoto)
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
                    self.completion.invoke(.single(.video(path, PixelDimensions(width: 1080, height: 1920))))
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
        return State(context: self.context, camera: self.camera, present: self.present, completion: self.completion)
    }
    
    static var body: Body {
        let cancelButton = Child(CameraButton.self)
        let captureControls = Child(CaptureControlsComponent.self)
        let zoomControl = Child(ZoomComponent.self)
        let flashButton = Child(CameraButton.self)
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
            
            component.changeMode.connect({ [weak state] mode in
                state?.updateCameraMode(mode)
            })
            
            if case .none = state.cameraState.recording {
                let cancelButton = cancelButton.update(
                    component: CameraButton(
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
                    component: CameraButton(
                        content: AnyComponent(Image(
                            image: state.image(.flash)
                        )),
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
                    tag: captureControlsTag,
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
                            completion.invoke(.single(.asset(asset)))
                        })
                        dismissGalleryControllerImpl = { [weak controller] in
                            controller?.dismiss(animated: true)
                        }
                        push(controller)
                    },
                    swipeHintUpdated: { hint in
                        state.updateSwipeHint(hint)
                    }
                ),
                availableSize: availableSize,
                transition: context.transition
            )
            context.add(captureControls
                .position(CGPoint(x: availableSize.width / 2.0, y: availableSize.height - captureControls.size.height / 2.0 - environment.safeInsets.bottom - 5.0))
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
                        .position(CGPoint(x: availableSize.width / 2.0, y: environment.safeInsets.top + 40.0))
                        .appear(.default(alpha: true))
                        .disappear(.default(alpha: true))
                    )
                }
                
                context.add(timeLabel
                    .position(CGPoint(x: availableSize.width / 2.0, y:  environment.safeInsets.top + 40.0))
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
                            availableSize: availableSize,
                            transition: .immediate
                        )
                        context.add(hintLabel
                            .position(CGPoint(x: availableSize.width / 2.0, y: availableSize.height - environment.safeInsets.bottom + 14.0 + hintLabel.size.height / 2.0))
                            .appear(.default(alpha: true))
                            .disappear(.default(alpha: true))
                        )
                    }
                }
            }
            
            if case .none = state.cameraState.recording, !component.isDismissing {
                let modeControl = modeControl.update(
                    component: ModeComponent(
                        availableModes: [.photo, .video],
                        currentMode: state.cameraState.mode,
                        updatedMode: { [weak state] mode in
                            if let state {
                                state.updateCameraMode(mode)
                            }
                        },
                        tag: modeControlTag
                    ),
                    availableSize: availableSize,
                    transition: context.transition
                )
                context.add(modeControl
                    .clipsToBounds(true)
                    .position(CGPoint(x: availableSize.width / 2.0, y: availableSize.height - environment.safeInsets.bottom + modeControl.size.height / 2.0))
                    .appear(.default(alpha: true))
                    .disappear(.default(alpha: true))
                )
            }
            return availableSize
        }
    }
}

private let useSimplePreviewView = true

private class BlurView: UIVisualEffectView {
    private func setup() {
        for subview in self.subviews {
            if subview.description.contains("VisualEffectSubview") {
                subview.isHidden = true
            }
        }
        
        if let sublayer = self.layer.sublayers?[0], let filters = sublayer.filters {
            sublayer.backgroundColor = nil
            sublayer.isOpaque = false
            let allowedKeys: [String] = [
                "gaussianBlur"
            ]
            sublayer.filters = filters.filter { filter in
                guard let filter = filter as? NSObject else {
                    return true
                }
                let filterName = String(describing: filter)
                if !allowedKeys.contains(filterName) {
                    return false
                }
                return true
            }
        }
    }
    
    override var effect: UIVisualEffect? {
        get {
            return super.effect
        }
        set {
            super.effect = newValue
            self.setup()
        }
    }
    
    override func didAddSubview(_ subview: UIView) {
        super.didAddSubview(subview)
        self.setup()
    }
}

public class CameraScreen: ViewController {
    public enum Mode {
        case generic
        case story
        case instantVideo
    }
    
    public enum Result {
        case pendingImage
        case image(UIImage)
        case video(String, PixelDimensions)
        case asset(PHAsset)
    }
    
    public final class TransitionIn {
        public weak var sourceView: UIView?
        public let sourceRect: CGRect
        public let sourceCornerRadius: CGFloat
        
        public init(
            sourceView: UIView,
            sourceRect: CGRect,
            sourceCornerRadius: CGFloat
        ) {
            self.sourceView = sourceView
            self.sourceRect = sourceRect
            self.sourceCornerRadius = sourceCornerRadius
        }
    }
    
    public final class TransitionOut {
        public weak var destinationView: UIView?
        public let destinationRect: CGRect
        public let destinationCornerRadius: CGFloat
        
        public init(
            destinationView: UIView,
            destinationRect: CGRect,
            destinationCornerRadius: CGFloat
        ) {
            self.destinationView = destinationView
            self.destinationRect = destinationRect
            self.destinationCornerRadius = destinationCornerRadius
        }
    }

    fileprivate final class Node: ViewControllerTracingNode {
        private weak var controller: CameraScreen?
        private let context: AccountContext
        private let updateState: ActionSlot<CameraState>

        private let backgroundEffectView: UIVisualEffectView
        private let backgroundDimView: UIView
        fileprivate let componentHost: ComponentView<ViewControllerComponentContainer.Environment>
        private let previewContainerView: UIView
        fileprivate let previewView: CameraPreviewView?
        fileprivate let simplePreviewView: CameraSimplePreviewView?
        fileprivate let previewBlurView: BlurView
        fileprivate let camera: Camera

        private var presentationData: PresentationData
        private var validLayout: ContainerViewLayout?
        
        private var changingPositionDisposable: Disposable?

        private let changeMode = ActionSlot<CameraMode>()
        private let completion = ActionSlot<Signal<CameraScreen.Result, NoError>>()
        
        private var effectivePreviewView: UIView {
            if let simplePreviewView = self.simplePreviewView {
                return simplePreviewView
            } else if let previewView = self.previewView {
                return previewView
            } else {
                fatalError()
            }
        }
        
        private var previewBlurPromise = ValuePromise<Bool>(false)
        
        init(controller: CameraScreen) {
            self.controller = controller
            self.context = controller.context
            self.updateState = ActionSlot<CameraState>()

            self.presentationData = self.context.sharedContext.currentPresentationData.with { $0 }

            self.backgroundEffectView = UIVisualEffectView(effect: nil)
            self.backgroundDimView = UIView()
            self.backgroundDimView.backgroundColor = UIColor(rgb: 0x000000)
            
            self.componentHost = ComponentView<ViewControllerComponentContainer.Environment>()
            
            self.previewContainerView = UIView()
            self.previewContainerView.clipsToBounds = true
            self.previewContainerView.layer.cornerRadius = 12.0
            if #available(iOS 13.0, *) {
                self.previewContainerView.layer.cornerCurve = .continuous
            }
            
            self.previewBlurView = BlurView()
            self.previewBlurView.isUserInteractionEnabled = false
            
            if let holder = controller.holder {
                self.simplePreviewView = nil
                self.previewView = holder.previewView
                self.camera = holder.camera
            } else {
                if useSimplePreviewView {
                    self.simplePreviewView = CameraSimplePreviewView()
                    self.previewView = nil
                } else {
                    self.previewView = CameraPreviewView(test: false)!
                    self.simplePreviewView = nil
                }
                self.camera = Camera(configuration: Camera.Configuration(preset: .hd1920x1080, position: .back, audio: true, photo: true, metadata: false, preferredFps: 60.0), previewView: self.simplePreviewView)
                if !useSimplePreviewView {
                    self.camera.attachPreviewView(self.previewView!)
                }
            }

            super.init()
            
            self.backgroundColor = .clear
            
            self.view.addSubview(self.backgroundEffectView)
            self.view.addSubview(self.backgroundDimView)
            
            self.view.addSubview(self.previewContainerView)
            self.previewContainerView.addSubview(self.effectivePreviewView)
            self.previewContainerView.addSubview(self.previewBlurView)
            
            self.changingPositionDisposable = combineLatest(
                queue: Queue.mainQueue(),
                self.camera.changingPosition,
                self.previewBlurPromise.get()
            ).start(next: { [weak self] changingPosition, forceBlur in
                if let self {
                    if changingPosition {
                        UIView.transition(with: self.previewContainerView, duration: 0.4, options: [.transitionFlipFromLeft, .curveEaseOut], animations: {
                            self.previewBlurView.effect = UIBlurEffect(style: .dark)
                        })
                    } else if forceBlur {
                        self.previewBlurView.effect = UIBlurEffect(style: .dark)
                    } else {
                        UIView.animate(withDuration: 0.4) {
                            self.previewBlurView.effect = nil
                        }
                        
                        if let previewSnapshotView = self.previewSnapshotView {
                            self.previewSnapshotView = nil
                            UIView.animate(withDuration: 0.25, animations: {
                                previewSnapshotView.alpha = 0.0
                            }, completion: { _ in
                                previewSnapshotView.removeFromSuperview()
                            })
                        }
                    }
                }
            })
            
            self.completion.connect { [weak self] result in
                if let self {
                    self.animateOutToEditor()
                    self.controller?.completion(
                        result
                        |> beforeNext { [weak self] value in
                            guard let self else {
                                return
                            }
                            if case .pendingImage = value {
                                Queue.mainQueue().async {
                                    self.effectivePreviewView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                                    self.simplePreviewView?.isEnabled = false
                                }
                            } else {
                                Queue.mainQueue().async {
                                    if case .image = value {
                                        Queue.mainQueue().after(0.3) {
                                            self.previewBlurPromise.set(true)
                                        }
                                    }
                                    self.simplePreviewView?.isEnabled = false
                                    self.camera.stopCapture()
                                }
                            }
                        }
                    )
                }
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
            self.effectivePreviewView.addGestureRecognizer(pinchGestureRecognizer)
            
            let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.handlePan(_:)))
            self.effectivePreviewView.addGestureRecognizer(panGestureRecognizer)
            
            self.camera.focus(at: CGPoint(x: 0.5, y: 0.5))
            self.camera.startCapture()
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
        
        private var panTranslation: CGFloat?
        private var previewInitialPosition: CGPoint?
        private var controlsInitialPosition: CGPoint?
        @objc private func handlePan(_ gestureRecognizer: UIPanGestureRecognizer) {
            switch gestureRecognizer.state {
            case .began:
                self.panTranslation = nil
                self.previewInitialPosition = self.previewContainerView.center
                self.controlsInitialPosition = self.componentHost.view?.center
            case .changed:
                let translation = gestureRecognizer.translation(in: gestureRecognizer.view)
                if !"".isEmpty {
                    
                } else {
                    if abs(translation.x) > 50.0 && abs(translation.y) < 50.0, self.panTranslation == nil {
                        self.changeMode.invoke(translation.x > 0.0 ? .photo : .video)
                        gestureRecognizer.isEnabled = false
                        gestureRecognizer.isEnabled = true
                    } else if translation.y > 10.0 {
                        let isFirstPanChange = self.panTranslation == nil
                        self.panTranslation = translation.y
                        if let previewInitialPosition = self.previewInitialPosition {
                            self.previewContainerView.center = CGPoint(x: previewInitialPosition.x, y: previewInitialPosition.y + translation.y)
                        }
                        if let controlsInitialPosition = self.controlsInitialPosition, let view = self.componentHost.view {
                            view.center = CGPoint(x: controlsInitialPosition.x, y: controlsInitialPosition.y + translation.y)
                        }
                        
                        if self.backgroundEffectView.isHidden {
                            self.backgroundEffectView.isHidden = false
                            
                            UIView.animate(withDuration: 0.25, animations: {
                                self.backgroundEffectView.effect = nil
                                self.backgroundDimView.alpha = 0.0
                            })
                        }
                        
                        if isFirstPanChange {
                            if let layout = self.validLayout {
                                self.containerLayoutUpdated(layout: layout, transition: .easeInOut(duration: 0.2))
                            }
                        }
                    }
                }
            case .ended:
                let velocity = gestureRecognizer.velocity(in: self.view)
                if velocity.y > 1000.0 {
                    self.controller?.requestDismiss(animated: true)
                } else if let panTranslation = self.panTranslation, abs(panTranslation) > 300.0 {
                    self.controller?.requestDismiss(animated: true)
                } else {
                    let transition = Transition(animation: .curve(duration: 0.3, curve: .spring))
                    if let previewInitialPosition = self.previewInitialPosition {
                        transition.setPosition(view: self.previewContainerView, position: previewInitialPosition)
                    }
                    if let controlsInitialPosition = self.controlsInitialPosition, let view = self.componentHost.view {
                        transition.setPosition(view: view, position: controlsInitialPosition)
                    }
                    if !self.backgroundEffectView.isHidden {
                        UIView.animate(withDuration: 0.25, animations: {
                            self.backgroundEffectView.effect = UIBlurEffect(style: .dark)
                            self.backgroundDimView.alpha = 1.0
                        }, completion: { _ in
                            self.backgroundEffectView.isHidden = true
                        })
                    }
                }
                if let _ = self.panTranslation {
                    self.panTranslation = nil
                    if let layout = self.validLayout {
                        self.containerLayoutUpdated(layout: layout, transition: .easeInOut(duration: 0.2))
                    }
                }
            default:
                break
            }
        }

        func animateIn() {
            self.backgroundDimView.alpha = 0.0
            UIView.animate(withDuration: 0.4, animations: {
                self.backgroundEffectView.effect = UIBlurEffect(style: .dark)
                self.backgroundDimView.alpha = 1.0
                
            }, completion: { _ in
                self.backgroundEffectView.isHidden = true
            })
            
            if let transitionIn = self.controller?.transitionIn, let sourceView = transitionIn.sourceView {
                let sourceLocalFrame = sourceView.convert(transitionIn.sourceRect, to: self.view)
                let innerSourceLocalFrame = CGRect(origin: CGPoint(x: sourceLocalFrame.minX - self.previewContainerView.frame.minX, y: sourceLocalFrame.minY - self.previewContainerView.frame.minY), size: sourceLocalFrame.size)
                
                self.previewContainerView.layer.animatePosition(from: sourceLocalFrame.center, to: self.previewContainerView.center, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
                self.previewContainerView.layer.animateBounds(from: CGRect(origin: CGPoint(x: innerSourceLocalFrame.minX, y: innerSourceLocalFrame.minY), size: sourceLocalFrame.size), to: self.previewContainerView.bounds, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
                self.previewContainerView.layer.animate(
                    from: transitionIn.sourceCornerRadius as NSNumber,
                    to: self.previewContainerView.layer.cornerRadius as NSNumber,
                    keyPath: "cornerRadius",
                    timingFunction: kCAMediaTimingFunctionSpring,
                    duration: 0.3
                )
                
                if let view = self.componentHost.view {
                    view.layer.animatePosition(from: sourceLocalFrame.center, to: view.center, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
                    view.layer.animateBounds(from: CGRect(origin: CGPoint(x: innerSourceLocalFrame.minX, y: innerSourceLocalFrame.minY), size: sourceLocalFrame.size), to: view.bounds, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
                }
            }
        }

        func animateOut(completion: @escaping () -> Void) {
            self.camera.stopCapture(invalidate: true)
            
            self.backgroundEffectView.isHidden = false
            
            UIView.animate(withDuration: 0.25, animations: {
                self.backgroundEffectView.effect = nil
                self.backgroundDimView.alpha = 0.0
            })
            
            if let transitionOut = self.controller?.transitionOut(false), let destinationView = transitionOut.destinationView {
                let sourceLocalFrame = destinationView.convert(transitionOut.destinationRect, to: self.view)
                let innerSourceLocalFrame = CGRect(origin: CGPoint(x: sourceLocalFrame.minX - self.previewContainerView.frame.minX, y: sourceLocalFrame.minY - self.previewContainerView.frame.minY), size: sourceLocalFrame.size)
                
                self.previewContainerView.layer.animatePosition(from: self.previewContainerView.center, to: sourceLocalFrame.center, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { _ in
                    completion()
                })
                self.previewContainerView.layer.animateBounds(from: self.previewContainerView.bounds, to: CGRect(origin: CGPoint(x: innerSourceLocalFrame.minX, y: innerSourceLocalFrame.minY), size: sourceLocalFrame.size), duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
                self.previewContainerView.layer.animate(
                    from: self.previewContainerView.layer.cornerRadius as NSNumber,
                    to: transitionOut.destinationCornerRadius as NSNumber,
                    keyPath: "cornerRadius",
                    timingFunction: kCAMediaTimingFunctionSpring,
                    duration: 0.3,
                    removeOnCompletion: false
                )
                
                if let view = self.componentHost.view {
                    view.layer.animatePosition(from: view.center, to: sourceLocalFrame.center, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
                    view.layer.animateBounds(from: view.bounds, to: CGRect(origin: CGPoint(x: innerSourceLocalFrame.minX, y: innerSourceLocalFrame.minY), size: sourceLocalFrame.size), duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
                }
            }
            
            self.componentHost.view?.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
            self.previewContainerView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.35, removeOnCompletion: false)
        }
        
        func animateOutToEditor() {
            let transition = Transition(animation: .curve(duration: 0.2, curve: .easeInOut))
            if let view = self.componentHost.findTaggedView(tag: cancelButtonTag) {
                transition.setScale(view: view, scale: 0.1)
                transition.setAlpha(view: view, alpha: 0.0)
            }
            if let view = self.componentHost.findTaggedView(tag: flashButtonTag) {
                transition.setScale(view: view, scale: 0.1)
                transition.setAlpha(view: view, alpha: 0.0)
            }
            if let view = self.componentHost.findTaggedView(tag: zoomControlTag) {
                transition.setAlpha(view: view, alpha: 0.0)
            }
            if let view = self.componentHost.findTaggedView(tag: captureControlsTag) as? CaptureControlsComponent.View {
                view.animateOutToEditor(transition: transition)
            }
            if let view = self.componentHost.findTaggedView(tag: modeControlTag) as? ModeComponent.View {
                view.animateOutToEditor(transition: transition)
            }
        }
        
        private var previewSnapshotView: UIView?
        func animateInFromEditor() {
            if let snapshot = self.simplePreviewView?.snapshotView(afterScreenUpdates: false) {
                self.simplePreviewView?.addSubview(snapshot)
                self.previewSnapshotView = snapshot
            }
            self.simplePreviewView?.isEnabled = true
            self.camera.startCapture()
            
            if #available(iOS 13.0, *), let isPreviewing = self.simplePreviewView?.isPreviewing {
                let _ = (isPreviewing
                |> filter {
                    $0
                }
                |> take(1)).start(next: { [weak self] _ in
                    if let self {
                        self.previewBlurPromise.set(false)
                    }
                })
            } else {
                Queue.mainQueue().after(1.0) {
                    self.previewBlurPromise.set(false)
                }
            }
            
            let transition = Transition(animation: .curve(duration: 0.2, curve: .easeInOut))
            if let view = self.componentHost.findTaggedView(tag: cancelButtonTag) {
                transition.setScale(view: view, scale: 1.0)
                transition.setAlpha(view: view, alpha: 1.0)
            }
            if let view = self.componentHost.findTaggedView(tag: flashButtonTag) {
                transition.setScale(view: view, scale: 1.0)
                transition.setAlpha(view: view, alpha: 1.0)
            }
            if let view = self.componentHost.findTaggedView(tag: zoomControlTag) {
                transition.setScale(view: view, scale: 1.0)
                transition.setAlpha(view: view, alpha: 1.0)
            }
            if let view = self.componentHost.findTaggedView(tag: captureControlsTag) as? CaptureControlsComponent.View {
                view.animateInFromEditor(transition: transition)
            }
            if let view = self.componentHost.findTaggedView(tag: modeControlTag) as? ModeComponent.View {
                view.animateInFromEditor(transition: transition)
            }
        }

        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            let result = super.hitTest(point, with: event)
            if result == self.componentHost.view {
                return self.effectivePreviewView
            }
            return result
        }

        func containerLayoutUpdated(layout: ContainerViewLayout, forceUpdate: Bool = false, animateOut: Bool = false, transition: Transition) {
            guard let _ = self.controller else {
                return
            }
            let isFirstTime = self.validLayout == nil
            self.validLayout = layout
            
            let previewSize = CGSize(width: layout.size.width, height: floorToScreenPixels(layout.size.width * 1.77778))
            let topInset: CGFloat = floor(layout.size.height - previewSize.height) / 2.0
            
            let environment = ViewControllerComponentContainer.Environment(
                statusBarHeight: layout.statusBarHeight ?? 0.0,
                navigationHeight: 0.0,
                safeInsets: UIEdgeInsets(
                    top: topInset,
                    left: layout.safeInsets.left,
                    bottom: topInset,
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
                        changeMode: self.changeMode,
                        isDismissing: self.panTranslation != nil,
                        present: { [weak self] c in
                            self?.controller?.present(c, in: .window(.root))
                        },
                        push: { [weak self] c in
                            self?.controller?.push(c)
                        },
                        completion: self.completion
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

                if self.panTranslation == nil {
                    let componentFrame = CGRect(origin: .zero, size: componentSize)
                    transition.setFrame(view: componentView, frame: componentFrame)
                }
                
                if isFirstTime {
                    self.animateIn()
                }
            }
            
            transition.setFrame(view: self.backgroundDimView, frame: CGRect(origin: .zero, size: layout.size))
            transition.setFrame(view: self.backgroundEffectView, frame: CGRect(origin: .zero, size: layout.size))
            
            if self.panTranslation == nil {
                let previewFrame = CGRect(origin: CGPoint(x: 0.0, y: topInset), size: previewSize)
                transition.setFrame(view: self.previewContainerView, frame: previewFrame)
                transition.setFrame(view: self.effectivePreviewView, frame: CGRect(origin: .zero, size: previewFrame.size))
                transition.setFrame(view: self.previewBlurView, frame: CGRect(origin: .zero, size: previewFrame.size))
            }
        }
    }

    fileprivate var node: Node {
        return self.displayNode as! Node
    }

    private let context: AccountContext
    fileprivate let mode: Mode
    fileprivate let holder: CameraHolder?
    fileprivate let transitionIn: TransitionIn?
    fileprivate let transitionOut: (Bool) -> TransitionOut?
    fileprivate let completion: (Signal<CameraScreen.Result, NoError>) -> Void

    public init(
        context: AccountContext,
        mode: Mode,
        holder: CameraHolder? = nil,
        transitionIn: TransitionIn?,
        transitionOut: @escaping (Bool) -> TransitionOut?,
        completion: @escaping (Signal<CameraScreen.Result, NoError>) -> Void
    ) {
        self.context = context
        self.mode = mode
        self.holder = holder
        self.transitionIn = transitionIn
        self.transitionOut = transitionOut
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
    
    public func returnFromEditor() {
        self.node.animateInFromEditor()
    }

    private var isDismissed = false
    fileprivate func requestDismiss(animated: Bool) {
        guard !self.isDismissed else {
            return
        }
        self.isDismissed = true
        self.statusBar.statusBarStyle = .Ignore
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

        if !self.isDismissed {
            (self.displayNode as! Node).containerLayoutUpdated(layout: layout, transition: Transition(transition))
        }
    }
}
