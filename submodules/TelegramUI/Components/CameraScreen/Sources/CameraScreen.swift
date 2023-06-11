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
import LottieAnimationComponent
import TooltipUI
import MediaEditor
import BundleIconComponent

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
    let position: Camera.Position
    let flashMode: Camera.FlashMode
    let flashModeDidChange: Bool
    let recording: Recording
    let duration: Double
    
    func updatedMode(_ mode: CameraMode) -> CameraState {
        return CameraState(mode: mode, position: self.position, flashMode: self.flashMode, flashModeDidChange: self.flashModeDidChange, recording: self.recording, duration: self.duration)
    }
    
    func updatedPosition(_ position: Camera.Position) -> CameraState {
        return CameraState(mode: self.mode, position: position, flashMode: self.flashMode, flashModeDidChange: self.flashModeDidChange, recording: self.recording, duration: self.duration)
    }
    
    func updatedFlashMode(_ flashMode: Camera.FlashMode) -> CameraState {
        return CameraState(mode: self.mode, position: self.position, flashMode: flashMode, flashModeDidChange: self.flashMode != flashMode, recording: self.recording, duration: self.duration)
    }
    
    func updatedRecording(_ recording: Recording) -> CameraState {
        return CameraState(mode: self.mode, position: self.position, flashMode: self.flashMode, flashModeDidChange: self.flashModeDidChange, recording: recording, duration: self.duration)
    }
    
    func updatedDuration(_ duration: Double) -> CameraState {
        return CameraState(mode: self.mode, position: self.position, flashMode: self.flashMode, flashModeDidChange: self.flashModeDidChange, recording: self.recording, duration: duration)
    }
}

enum CameraScreenTransition {
    case animateIn
    case animateOut
    case finishedAnimateIn
}

private let cancelButtonTag = GenericComponentViewTag()
private let flashButtonTag = GenericComponentViewTag()
private let zoomControlTag = GenericComponentViewTag()
private let captureControlsTag = GenericComponentViewTag()
private let modeControlTag = GenericComponentViewTag()
private let galleryButtonTag = GenericComponentViewTag()

private final class CameraScreenComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let camera: Camera
    let changeMode: ActionSlot<CameraMode>
    let hasAppeared: Bool
    let present: (ViewController) -> Void
    let push: (ViewController) -> Void
    let completion: ActionSlot<Signal<CameraScreen.Result, NoError>>
    
    init(
        context: AccountContext,
        camera: Camera,
        changeMode: ActionSlot<CameraMode>,
        hasAppeared: Bool,
        present: @escaping (ViewController) -> Void,
        push: @escaping (ViewController) -> Void,
        completion: ActionSlot<Signal<CameraScreen.Result, NoError>>
    ) {
        self.context = context
        self.camera = camera
        self.changeMode = changeMode
        self.hasAppeared = hasAppeared
        self.present = present
        self.push = push
        self.completion = completion
    }
    
    static func ==(lhs: CameraScreenComponent, rhs: CameraScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.hasAppeared != rhs.hasAppeared {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        enum ImageKey: Hashable {
            case cancel
            case flip
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
        
        private var mediaAssetsContext: MediaAssetsContext?
        fileprivate var lastGalleryAsset: PHAsset?
        private var lastGalleryAssetsDisposable: Disposable?
        
        var cameraState = CameraState(mode: .photo, position: .unspecified, flashMode: .off, flashModeDidChange: false, recording: .none, duration: 0.0)
        var swipeHint: CaptureControlsComponent.SwipeHint = .none
        
        private let hapticFeedback = HapticFeedback()
        
        init(context: AccountContext, camera: Camera, present: @escaping (ViewController) -> Void, completion: ActionSlot<Signal<CameraScreen.Result, NoError>>) {
            self.context = context
            self.camera = camera
            self.present = present
            self.completion = completion
            
            super.init()
            
            self.cameraStateDisposable = combineLatest(queue: Queue.mainQueue(), camera.flashMode, camera.position)
            .start(next: { [weak self] flashMode, position in
                guard let self else {
                    return
                }
                let previousState = self.cameraState
                self.cameraState = self.cameraState.updatedPosition(position).updatedFlashMode(flashMode)
                self.updated(transition: .easeInOut(duration: 0.2))
                
                if previousState.position != self.cameraState.position {
                    UserDefaults.standard.set((self.cameraState.position == .front) as NSNumber, forKey: "TelegramStoryCameraUseFrontPosition")
                }
            })
            
            Queue.mainQueue().async {
                self.setupRecentAssetSubscription()
            }
        }
        
        deinit {
            self.cameraStateDisposable?.dispose()
            self.lastGalleryAssetsDisposable?.dispose()
            self.resultDisposable.dispose()
        }
        
        func setupRecentAssetSubscription() {
            let mediaAssetsContext = MediaAssetsContext()
            self.mediaAssetsContext = mediaAssetsContext
            self.lastGalleryAssetsDisposable = (mediaAssetsContext.recentAssets()
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
        
        func updateCameraMode(_ mode: CameraMode) {
            self.cameraState = self.cameraState.updatedMode(mode)
            self.updated(transition: .spring(duration: 0.3))
        }
        
        func toggleFlashMode() {
            if self.cameraState.flashMode == .off {
                self.camera.setFlashMode(.on)
            } else if self.cameraState.flashMode == .on {
                self.camera.setFlashMode(.auto)
            } else {
                self.camera.setFlashMode(.off)
            }
            self.hapticFeedback.impact(.light)
        }
        
        func togglePosition() {
            self.camera.togglePosition()
            self.hapticFeedback.impact(.light)
        }
        
        func updateSwipeHint(_ hint: CaptureControlsComponent.SwipeHint) {
            guard hint != self.swipeHint else {
                return
            }
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
                    if duration > 59.0 {
                        self.stopVideoRecording()
                    }
                }
            }))
            self.updated(transition: .spring(duration: 0.4))
        }
        
        func stopVideoRecording() {
            self.cameraState = self.cameraState.updatedRecording(.none).updatedDuration(0.0)
            self.resultDisposable.set((self.camera.stopRecording()
            |> deliverOnMainQueue).start(next: { [weak self] pathAndTransitionImage in
                if let self, let (path, transitionImage) = pathAndTransitionImage {
                    self.completion.invoke(.single(.video(path, transitionImage, PixelDimensions(width: 1080, height: 1920))))
                }
            }))
            self.updated(transition: .spring(duration: 0.4))
        }
        
        func lockVideoRecording() {
            self.cameraState = self.cameraState.updatedRecording(.handsFree)
            self.updated(transition: .spring(duration: 0.4))
        }
        
        func updateZoom(fraction: CGFloat) {
            self.camera.setZoomLevel(fraction)
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

            let topControlInset: CGFloat = 20.0
            
            component.changeMode.connect({ [weak state] mode in
                state?.updateCameraMode(mode)
            })
            
            if case .none = state.cameraState.recording {
                let cancelButton = cancelButton.update(
                    component: CameraButton(
                        content: AnyComponentWithIdentity(
                            id: "cancel",
                            component: AnyComponent(
                                Image(
                                    image: state.image(.cancel),
                                    size: CGSize(width: 40.0, height: 40.0)
                                )
                            )
                        ),
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
                        
                let flashContentComponent: AnyComponentWithIdentity<Empty>
                if component.hasAppeared {
                    let flashIconName: String
                    switch state.cameraState.flashMode {
                    case .off:
                        flashIconName = "flash_off"
                    case .on:
                        flashIconName = "flash_on"
                    case .auto:
                        flashIconName = "flash_auto"
                    @unknown default:
                        flashIconName = "flash_off"
                    }
                    
                    flashContentComponent = AnyComponentWithIdentity(
                        id: "animatedIcon",
                        component: AnyComponent(
                            LottieAnimationComponent(
                                animation: LottieAnimationComponent.AnimationItem(
                                    name: flashIconName,
                                    mode: !state.cameraState.flashModeDidChange ? .still(position: .end) : .animating(loop: false),
                                    range: nil,
                                    waitForCompletion: false
                                ),
                                colors: [:],
                                size: CGSize(width: 40.0, height: 40.0)
                            )
                        )
                    )
                } else {
                    flashContentComponent = AnyComponentWithIdentity(
                        id: "staticIcon",
                        component: AnyComponent(
                            BundleIconComponent(
                                name: "Camera/FlashOffIcon",
                                tintColor: nil
                            )
                        )
                    )
                }
                                        
                let flashButton = flashButton.update(
                    component: CameraButton(
                        content: flashContentComponent,
                        action: { [weak state] in
                            guard let state else {
                                return
                            }
                            state.toggleFlashMode()
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
//                    .position(CGPoint(x: context.availableSize.width / 2.0, y: availableSize.height - zoomControl.size.height / 2.0 - 114.0 - environment.safeInsets.bottom))
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
                    galleryButtonTag: galleryButtonTag,
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
                        state.togglePosition()
                    },
                    galleryTapped: {
                        guard let controller = environment.controller() as? CameraScreen else {
                            return
                        }
                        controller.presentGallery()
                    },
                    swipeHintUpdated: { hint in
                        state.updateSwipeHint(hint)
                    },
                    zoomUpdated: { fraction in
                        state.updateZoom(fraction: fraction)
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
                            .position(CGPoint(x: availableSize.width / 2.0, y: availableSize.height - environment.safeInsets.bottom - 136.0))
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
        case video(String, UIImage?, PixelDimensions)
        case asset(PHAsset)
        case draft(MediaEditorDraft)
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

        fileprivate let backgroundView: UIView
        fileprivate let containerView: UIView
        fileprivate let componentHost: ComponentView<ViewControllerComponentContainer.Environment>
        private let previewContainerView: UIView
        fileprivate let previewView: CameraPreviewView?
        fileprivate let simplePreviewView: CameraSimplePreviewView?
        fileprivate let previewBlurView: BlurView
        private var previewSnapshotView: UIView?
        fileprivate let transitionDimView: UIView
        fileprivate let transitionCornersView: UIImageView
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
        
        fileprivate var previewBlurPromise = ValuePromise<Bool>(false)
        
        init(controller: CameraScreen) {
            self.controller = controller
            self.context = controller.context
            self.updateState = ActionSlot<CameraState>()

            self.presentationData = self.context.sharedContext.currentPresentationData.with { $0 }

            self.backgroundView = UIView()
            self.backgroundView.backgroundColor = UIColor(rgb: 0x000000)
            
            self.containerView = UIView()
            self.containerView.clipsToBounds = true
            
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
                
                var cameraFrontPosition = false
                if let useCameraFrontPosition = UserDefaults.standard.object(forKey: "TelegramStoryCameraUseFrontPosition") as? NSNumber, useCameraFrontPosition.boolValue {
                    cameraFrontPosition = true
                }
                
                self.camera = Camera(configuration: Camera.Configuration(preset: .hd1920x1080, position: cameraFrontPosition ? .front : .back, audio: true, photo: true, metadata: false, preferredFps: 60.0), previewView: self.simplePreviewView)
                if !useSimplePreviewView {
#if targetEnvironment(simulator)
#else
                    self.camera.attachPreviewView(self.previewView!)
#endif
                }
            }
            
            self.transitionDimView = UIView()
            self.transitionDimView.backgroundColor = UIColor(rgb: 0x000000)
            self.transitionDimView.isUserInteractionEnabled = false
            
            self.transitionCornersView = UIImageView()

            super.init()
            
            self.backgroundColor = .clear
            
            self.view.addSubview(self.backgroundView)
            self.view.addSubview(self.containerView)
            
            self.containerView.addSubview(self.previewContainerView)
            self.previewContainerView.addSubview(self.effectivePreviewView)
            self.previewContainerView.addSubview(self.previewBlurView)
            self.containerView.addSubview(self.transitionDimView)
            self.view.addSubview(self.transitionCornersView)
            
            self.changingPositionDisposable = combineLatest(
                queue: Queue.mainQueue(),
                self.camera.changingPosition,
                self.previewBlurPromise.get()
            ).start(next: { [weak self] changingPosition, forceBlur in
                if let self {
                    if changingPosition {
                        if let snapshot = self.simplePreviewView?.snapshotView(afterScreenUpdates: false) {
                            self.simplePreviewView?.addSubview(snapshot)
                            self.previewSnapshotView = snapshot
                        }
                        UIView.transition(with: self.previewContainerView, duration: 0.4, options: [.transitionFlipFromLeft, .curveEaseOut], animations: {
                            self.previewBlurView.effect = UIBlurEffect(style: .dark)
                        })
                    } else if forceBlur {
                        UIView.animate(withDuration: 0.4) {
                            self.previewBlurView.effect = UIBlurEffect(style: .dark)
                        }
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
                        },
                        nil,
                        {}
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
            panGestureRecognizer.maximumNumberOfTouches = 1
            self.effectivePreviewView.addGestureRecognizer(panGestureRecognizer)
            
            let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.handleTap(_:)))
            self.effectivePreviewView.addGestureRecognizer(tapGestureRecognizer)
            
            self.camera.focus(at: CGPoint(x: 0.5, y: 0.5), autoFocus: true)
            self.camera.startCapture()
        }
        
        @objc private func handlePinch(_ gestureRecognizer: UIPinchGestureRecognizer) {
            switch gestureRecognizer.state {
            case .changed:
                let scale = gestureRecognizer.scale
                self.camera.setZoomDelta(scale)
                gestureRecognizer.scale = 1.0
            default:
                break
            }
        }
        
        private var isDismissing = false
        @objc private func handlePan(_ gestureRecognizer: UIPanGestureRecognizer) {
            guard let controller = self.controller else {
                return
            }
            let translation = gestureRecognizer.translation(in: gestureRecognizer.view)
            switch gestureRecognizer.state {
            case .began:
                break
            case .changed:
                if !"".isEmpty {
                    
                } else {
                    if translation.x < -10.0 || self.isDismissing {
                        self.isDismissing = true
                        let transitionFraction = 1.0 - max(0.0, translation.x * -1.0) / self.frame.width
                        controller.updateTransitionProgress(transitionFraction, transition: .immediate)
                    } else if translation.y < -10.0 {
                        controller.presentGallery(fromGesture: true)
                        gestureRecognizer.isEnabled = false
                        gestureRecognizer.isEnabled = true
                    }
                }
            case .ended:
                let velocity = gestureRecognizer.velocity(in: self.view)
                let transitionFraction = 1.0 - max(0.0, translation.x * -1.0) / self.frame.width
                controller.completeWithTransitionProgress(transitionFraction, velocity: abs(velocity.x), dismissing: true)
                
                self.isDismissing = false
            default:
                break
            }
        }
        
        @objc private func handleTap(_ gestureRecognizer: UITapGestureRecognizer) {
            guard let previewView = self.simplePreviewView else {
                return
            }
            let location = gestureRecognizer.location(in: previewView)
            let point = previewView.cameraPoint(for: location)
            self.camera.focus(at: point, autoFocus: false)
        }

        func animateIn() {
            self.backgroundView.alpha = 0.0
            UIView.animate(withDuration: 0.4, animations: {
                self.backgroundView.alpha = 1.0
            })
            
            if let transitionIn = self.controller?.transitionIn, let sourceView = transitionIn.sourceView {
                let sourceLocalFrame = sourceView.convert(transitionIn.sourceRect, to: self.view)

                let sourceScale = sourceLocalFrame.width / self.previewContainerView.frame.width
                self.previewContainerView.layer.animatePosition(from: sourceLocalFrame.center, to: self.previewContainerView.center, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
                self.previewContainerView.layer.animateScale(from: sourceScale, to: 1.0, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
                self.previewContainerView.layer.animateBounds(from: CGRect(origin: CGPoint(x: 0.0, y: (self.previewContainerView.bounds.height - self.previewContainerView.bounds.width) / 2.0), size: CGSize(width: self.previewContainerView.bounds.width, height: self.previewContainerView.bounds.width)), to: self.previewContainerView.bounds, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
                self.previewContainerView.layer.animate(
                    from: self.previewContainerView.bounds.width / 2.0 as NSNumber,
                    to: self.previewContainerView.layer.cornerRadius as NSNumber,
                    keyPath: "cornerRadius",
                    timingFunction: kCAMediaTimingFunctionSpring,
                    duration: 0.3
                )
                
                if let view = self.componentHost.view {
                    view.layer.animatePosition(from: sourceLocalFrame.center, to: view.center, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
                    view.layer.animateScale(from: 0.1, to: 1.0, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
                }
            }
        }

        func animateOut(completion: @escaping () -> Void) {
            self.camera.stopCapture(invalidate: true)
                        
            UIView.animate(withDuration: 0.25, animations: {
                self.backgroundView.alpha = 0.0
            })
            
            if let transitionOut = self.controller?.transitionOut(false), let destinationView = transitionOut.destinationView {
                let destinationLocalFrame = destinationView.convert(transitionOut.destinationRect, to: self.view)
                
                let targetScale = destinationLocalFrame.width / self.previewContainerView.frame.width
                self.previewContainerView.layer.animatePosition(from: self.previewContainerView.center, to: destinationLocalFrame.center, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { _ in
                    completion()
                })
                self.previewContainerView.layer.animateScale(from: 1.0, to: targetScale, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
                self.previewContainerView.layer.animateBounds(from: self.previewContainerView.bounds, to: CGRect(origin: CGPoint(x: 0.0, y: (self.previewContainerView.bounds.height - self.previewContainerView.bounds.width) / 2.0), size: CGSize(width: self.previewContainerView.bounds.width, height: self.previewContainerView.bounds.width)), duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
                self.previewContainerView.layer.animate(
                    from: self.previewContainerView.layer.cornerRadius as NSNumber,
                    to: self.previewContainerView.bounds.width / 2.0 as NSNumber,
                    keyPath: "cornerRadius",
                    timingFunction: kCAMediaTimingFunctionSpring,
                    duration: 0.3,
                    removeOnCompletion: false
                )
                
                if let view = self.componentHost.view {
                    view.layer.animatePosition(from: view.center, to: destinationLocalFrame.center, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
                    view.layer.animateScale(from: 1.0, to: targetScale, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
                }
            }
            
            self.componentHost.view?.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
            self.previewContainerView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.35, removeOnCompletion: false)
        }
        
        func animateOutToEditor() {
            let transition = Transition(animation: .curve(duration: 0.2, curve: .easeInOut))
            if let view = self.componentHost.findTaggedView(tag: cancelButtonTag) {
                view.layer.animateScale(from: 1.0, to: 0.1, duration: 0.2)
                transition.setAlpha(view: view, alpha: 0.0)
            }
            if let view = self.componentHost.findTaggedView(tag: flashButtonTag) {
                view.layer.animateScale(from: 1.0, to: 0.1, duration: 0.2)
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
        
        func pauseCameraCapture() {
            self.simplePreviewView?.isEnabled = false
            Queue.mainQueue().after(0.3) {
                self.previewBlurPromise.set(true)
            }
            self.camera.stopCapture()
        }
        
        func resumeCameraCapture() {
            if self.simplePreviewView?.isEnabled == false {
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
            }
        }
        
        func animateInFromEditor(toGallery: Bool) {
            if !toGallery {
                self.resumeCameraCapture()
                
                let transition = Transition(animation: .curve(duration: 0.2, curve: .easeInOut))
                if let view = self.componentHost.findTaggedView(tag: cancelButtonTag) {
                    view.layer.animateScale(from: 0.1, to: 1.0, duration: 0.2)
                    transition.setAlpha(view: view, alpha: 1.0)
                }
                if let view = self.componentHost.findTaggedView(tag: flashButtonTag) {
                    view.layer.animateScale(from: 0.1, to: 1.0, duration: 0.2)
                    transition.setAlpha(view: view, alpha: 1.0)
                }
                if let view = self.componentHost.findTaggedView(tag: zoomControlTag) {
                    view.layer.animateScale(from: 0.1, to: 1.0, duration: 0.2)
                    transition.setAlpha(view: view, alpha: 1.0)
                }
                if let view = self.componentHost.findTaggedView(tag: captureControlsTag) as? CaptureControlsComponent.View {
                    view.animateInFromEditor(transition: transition)
                }
                if let view = self.componentHost.findTaggedView(tag: modeControlTag) as? ModeComponent.View {
                    view.animateInFromEditor(transition: transition)
                }
            }
        }
        
        func updateModalTransitionFactor(_ value: CGFloat, transition: ContainedViewLayoutTransition) {
            guard let layout = self.validLayout else {
                return
            }
            
            let progress = 1.0 - value
            let maxScale = (layout.size.width - 16.0 * 2.0) / layout.size.width
            
            let topInset: CGFloat = (layout.statusBarHeight ?? 0.0) + 12.0
            let targetTopInset = ceil((layout.statusBarHeight ?? 0.0) - (layout.size.height - layout.size.height * maxScale) / 2.0)
            let deltaOffset = (targetTopInset - topInset)
            
            let scale = 1.0 * progress + (1.0 - progress) * maxScale
            let offset = (1.0 - progress) * deltaOffset
            transition.updateSublayerTransformScaleAndOffset(layer: self.containerView.layer, scale: scale, offset: CGPoint(x: 0.0, y: offset), beginWithCurrentState: true)
        }
        
        func presentDraftTooltip() {
            guard let sourceView = self.componentHost.findTaggedView(tag: galleryButtonTag) else {
                return
            }
            
            let parentFrame = self.view.convert(self.bounds, to: nil)
            let absoluteFrame = sourceView.convert(sourceView.bounds, to: nil).offsetBy(dx: -parentFrame.minX, dy: 0.0)
            let location = CGRect(origin: CGPoint(x: absoluteFrame.midX, y: absoluteFrame.minY - 25.0), size: CGSize())
                        
            let controller = TooltipScreen(account: self.context.account, sharedContext: self.context.sharedContext, text: "Draft Saved", location: .point(location, .bottom), displayDuration: .default, inset: 16.0, shouldDismissOnTouch: { _ in
                return .ignore
            })
            self.controller?.present(controller, in: .current)
        }

        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            let result = super.hitTest(point, with: event)
            if result == self.componentHost.view {
                return self.effectivePreviewView
            }
            return result
        }
        
        func requestUpdateLayout(hasAppeared: Bool, transition: Transition) {
            if let layout = self.validLayout {
                self.containerLayoutUpdated(layout: layout, forceUpdate: true, hasAppeared: hasAppeared, transition: transition)
                
                if let view = self.componentHost.findTaggedView(tag: flashButtonTag) {
                    view.layer.shadowOffset = CGSize(width: 0.0, height: 0.0)
                    view.layer.shadowRadius = 3.0
                    view.layer.shadowColor = UIColor.black.cgColor
                    view.layer.shadowOpacity = 0.35
                }
            }
        }

        fileprivate var hasAppeared = false
        func containerLayoutUpdated(layout: ContainerViewLayout, forceUpdate: Bool = false, hasAppeared: Bool = false, transition: Transition) {
            guard let _ = self.controller else {
                return
            }
            let isFirstTime = self.validLayout == nil
            self.validLayout = layout
            
            let previewSize = CGSize(width: layout.size.width, height: floorToScreenPixels(layout.size.width * 1.77778))
            let topInset: CGFloat = (layout.statusBarHeight ?? 0.0) + 12.0
            let bottomInset = layout.size.height - previewSize.height - topInset
            
            let environment = ViewControllerComponentContainer.Environment(
                statusBarHeight: layout.statusBarHeight ?? 0.0,
                navigationHeight: 0.0,
                safeInsets: UIEdgeInsets(
                    top: topInset,
                    left: layout.safeInsets.left,
                    bottom: bottomInset,
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
            } else if hasAppeared && !self.hasAppeared {
                self.hasAppeared = hasAppeared
                transition = transition.withUserData(CameraScreenTransition.finishedAnimateIn)
            }

            let componentSize = self.componentHost.update(
                transition: transition,
                component: AnyComponent(
                    CameraScreenComponent(
                        context: self.context,
                        camera: self.camera,
                        changeMode: self.changeMode,
                        hasAppeared: self.hasAppeared,
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
                forceUpdate: forceUpdate,
                containerSize: layout.size
            )
            if let componentView = self.componentHost.view {
                if componentView.superview == nil {
                    self.containerView.insertSubview(componentView, belowSubview: transitionDimView)
                    componentView.clipsToBounds = true
                }
            
                let componentFrame = CGRect(origin: .zero, size: componentSize)
                transition.setFrame(view: componentView, frame: componentFrame)
            }
            
            transition.setPosition(view: self.backgroundView, position: CGPoint(x: layout.size.width / 2.0, y: layout.size.height / 2.0))
            transition.setBounds(view: self.backgroundView, bounds: CGRect(origin: .zero, size: layout.size))
            
            transition.setPosition(view: self.containerView, position: CGPoint(x: layout.size.width / 2.0, y: layout.size.height / 2.0))
            transition.setBounds(view: self.containerView, bounds: CGRect(origin: .zero, size: layout.size))
            
            transition.setFrame(view: self.transitionDimView, frame: CGRect(origin: .zero, size: layout.size))
            
            
            let previewFrame = CGRect(origin: CGPoint(x: 0.0, y: topInset), size: previewSize)
            transition.setFrame(view: self.previewContainerView, frame: previewFrame)
            transition.setFrame(view: self.effectivePreviewView, frame: CGRect(origin: .zero, size: previewFrame.size))
            transition.setFrame(view: self.previewBlurView, frame: CGRect(origin: .zero, size: previewFrame.size))
            
            let screenCornerRadius = layout.deviceMetrics.screenCornerRadius
            if screenCornerRadius > 0.0, self.transitionCornersView.image == nil {
                self.transitionCornersView.image = generateImage(CGSize(width: screenCornerRadius, height: screenCornerRadius * 3.0), rotatedContext: { size, context in
                    context.setFillColor(UIColor.black.cgColor)
                    context.fill(CGRect(origin: .zero, size: size))
                    context.setBlendMode(.clear)
                    
                    let path = UIBezierPath(roundedRect: CGRect(origin: .zero, size: CGSize(width: size.width * 2.0, height: size.height)), cornerRadius: size.width)
                    context.addPath(path.cgPath)
                    context.fillPath()
                })?.stretchableImage(withLeftCapWidth: 0, topCapHeight: Int(screenCornerRadius))
            }
        
            transition.setPosition(view: self.transitionCornersView, position: CGPoint(x: layout.size.width + screenCornerRadius / 2.0, y: layout.size.height / 2.0))
            transition.setBounds(view: self.transitionCornersView, bounds: CGRect(origin: .zero, size: CGSize(width: screenCornerRadius, height: layout.size.height)))
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

    public final class ResultTransition {
        public weak var sourceView: UIView?
        public let sourceRect: CGRect
        public let sourceImage: UIImage?
        public let transitionOut: () -> (UIView, CGRect)?
    
        public init(
            sourceView: UIView,
            sourceRect: CGRect,
            sourceImage: UIImage?,
            transitionOut: @escaping () -> (UIView, CGRect)?
        ) {
            self.sourceView = sourceView
            self.sourceRect = sourceRect
            self.sourceImage = sourceImage
            self.transitionOut = transitionOut
        }
    }
    fileprivate let completion: (Signal<CameraScreen.Result, NoError>, ResultTransition?, @escaping () -> Void) -> Void
    public var transitionedIn: () -> Void = {}
    
    private var audioSessionDisposable: Disposable?
    
    private let hapticFeedback = HapticFeedback()
    
    public init(
        context: AccountContext,
        mode: Mode,
        holder: CameraHolder? = nil,
        transitionIn: TransitionIn?,
        transitionOut: @escaping (Bool) -> TransitionOut?,
        completion: @escaping (Signal<CameraScreen.Result, NoError>, ResultTransition?, @escaping () -> Void) -> Void
    ) {
        self.context = context
        self.mode = mode
        self.holder = holder
        self.transitionIn = transitionIn
        self.transitionOut = transitionOut
        self.completion = completion

        super.init(navigationBarPresentationData: nil)

        self.statusBar.statusBarStyle = .Ignore
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
        
        self.navigationPresentation = .flatModal
        
        self.requestAudioSession()
    }

    required public init(coder: NSCoder) {
        preconditionFailure()
    }
    
    deinit {
        self.audioSessionDisposable?.dispose()
    }

    override public func loadDisplayNode() {
        self.displayNode = Node(controller: self)

        super.displayNodeDidLoad()
    }
    
    private func requestAudioSession() {
        self.audioSessionDisposable = self.context.sharedContext.mediaManager.audioSession.push(audioSessionType: .recordWithOthers, activate: { _ in }, deactivate: { _ in
            return .single(Void())
        })
    }
    
    private var galleryController: ViewController?
    public func returnFromEditor() {
        self.node.animateInFromEditor(toGallery: self.galleryController?.displayNode.supernode != nil)
    }
    
    func presentGallery(fromGesture: Bool = false) {
        if !fromGesture {
            self.hapticFeedback.impact(.light)
        }
        
        var didStopCameraCapture = false
        let stopCameraCapture = { [weak self] in
            guard !didStopCameraCapture, let self else {
                return
            }
            didStopCameraCapture = true
            
            self.node.pauseCameraCapture()
        }
        
        let controller: ViewController
        if let current = self.galleryController {
            controller = current
        } else {
            controller = self.context.sharedContext.makeMediaPickerScreen(context: self.context, completion: { [weak self] result, transitionView, transitionRect, transitionImage, transitionOut, dismissed in
                if let self {
                    stopCameraCapture()
                    
                    let resultTransition = ResultTransition(
                        sourceView: transitionView,
                        sourceRect: transitionRect,
                        sourceImage: transitionImage,
                        transitionOut: transitionOut
                    )
                    if let asset = result as? PHAsset {
                        self.completion(.single(.asset(asset)), resultTransition, dismissed)
                    } else if let draft = result as? MediaEditorDraft {
                        self.completion(.single(.draft(draft)), resultTransition, dismissed)
                    }
                }
            }, dismissed: { [weak self] in
                if let self {
                    self.node.resumeCameraCapture()
                }
            })
            self.galleryController = controller
        }
        controller.customModalStyleOverlayTransitionFactorUpdated = { [weak self, weak controller] transition in
            if let self, let controller {
                let transitionFactor = controller.modalStyleOverlayTransitionFactor
                if transitionFactor > 0.1 {
                    stopCameraCapture()
                }
                self.node.updateModalTransitionFactor(transitionFactor, transition: transition)
            }
        }
        self.push(controller)
    }
    
    public func presentDraftTooltip() {
        self.node.presentDraftTooltip()
    }

    private var isDismissed = false
    fileprivate func requestDismiss(animated: Bool, interactive: Bool = false) {
        guard !self.isDismissed else {
            return
        }
        
        self.dismissAllTooltips()
        
        if !interactive {
            self.hapticFeedback.impact(.light)
        }
        
        self.node.camera.stopCapture(invalidate: true)
        self.isDismissed = true
        if animated {
            self.statusBar.updateStatusBarStyle(.Ignore, animated: true)
            if !interactive {
                if let navigationController = self.navigationController as? NavigationController {
                    navigationController.updateRootContainerTransitionOffset(self.node.frame.width, transition: .immediate)
                }
            }
            self.updateTransitionProgress(0.0, transition: .animated(duration: 0.4, curve: .spring), completion: { [weak self] in
                self?.dismiss(animated: false)
            })
        } else {
            self.dismiss(animated: false)
        }
    }
    
    private func dismissAllTooltips() {
        self.window?.forEachController({ controller in
            if let controller = controller as? TooltipScreen {
                controller.dismiss()
            }
        })
        self.forEachController({ controller in
            if let controller = controller as? TooltipScreen {
                controller.dismiss()
            }
            return true
        })
    }
    
    public func updateTransitionProgress(_ transitionFraction: CGFloat, transition: ContainedViewLayoutTransition, completion: @escaping () -> Void = {}) {
        let offsetX = floorToScreenPixels((1.0 - transitionFraction) * self.node.frame.width * -1.0)
        transition.updateTransform(layer: self.node.backgroundView.layer, transform: CGAffineTransform(translationX: offsetX, y: 0.0))
        transition.updateTransform(layer: self.node.containerView.layer, transform: CGAffineTransform(translationX: offsetX, y: 0.0))
        let scale: CGFloat = max(0.8, min(1.0, 0.8 + 0.2 * transitionFraction))
        transition.updateSublayerTransformScaleAndOffset(layer: self.node.containerView.layer, scale: scale, offset: CGPoint(x: -offsetX * 1.0 / scale * 0.5, y: 0.0), completion: { _ in
            completion()
        })
        
        let dimAlpha = 0.6 * (1.0 - transitionFraction)
        transition.updateAlpha(layer: self.node.transitionDimView.layer, alpha: dimAlpha)
        transition.updateTransform(layer: self.node.transitionCornersView.layer, transform: CGAffineTransform(translationX: offsetX, y: 0.0))
                
        if let navigationController = self.navigationController as? NavigationController {
            let offsetX = floorToScreenPixels(transitionFraction * self.node.frame.width)
            navigationController.updateRootContainerTransitionOffset(offsetX, transition: transition)
        }
    }
    
    public func completeWithTransitionProgress(_ transitionFraction: CGFloat, velocity: CGFloat, dismissing: Bool) {
        if dismissing {
            if transitionFraction < 0.7 || velocity < -1000.0 {
                self.statusBar.updateStatusBarStyle(.Ignore, animated: true)
                self.requestDismiss(animated: true, interactive: true)
            } else {
                self.statusBar.updateStatusBarStyle(.White, animated: true)
                self.updateTransitionProgress(1.0, transition: .animated(duration: 0.4, curve: .spring), completion: { [weak self] in
                    if let self, let navigationController = self.navigationController as? NavigationController {
                        navigationController.updateRootContainerTransitionOffset(0.0, transition: .immediate)
                    }
                })
            }
        } else {
            if transitionFraction > 0.33 || velocity > 1000.0 {
                self.statusBar.updateStatusBarStyle(.White, animated: true)
                self.updateTransitionProgress(1.0, transition: .animated(duration: 0.4, curve: .spring), completion: { [weak self] in
                    if let self, let navigationController = self.navigationController as? NavigationController {
                        navigationController.updateRootContainerTransitionOffset(0.0, transition: .immediate)
                        self.node.requestUpdateLayout(hasAppeared: true, transition: .immediate)
                        self.transitionedIn()
                    }
                })
            } else {
                self.statusBar.updateStatusBarStyle(.Ignore, animated: true)
                self.requestDismiss(animated: true, interactive: true)
            }
        }
    }
    
    public override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        if !flag {
            self.galleryController?.dismiss(animated: false)
        }
        super.dismiss(animated: flag, completion: completion)
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)

        if !self.isDismissed {
            (self.displayNode as! Node).containerLayoutUpdated(layout: layout, transition: Transition(transition))
        }
    }
}
