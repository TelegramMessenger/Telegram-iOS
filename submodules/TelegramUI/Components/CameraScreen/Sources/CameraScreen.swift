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
import CameraButtonComponent
import VolumeButtons
import TelegramNotices
import DeviceAccess

let videoRedColor = UIColor(rgb: 0xff3b30)

enum CameraMode: Equatable {
    case photo
    case video
}

private struct CameraState: Equatable {
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
    let isDualCameraEnabled: Bool
    
    func updatedMode(_ mode: CameraMode) -> CameraState {
        return CameraState(mode: mode, position: self.position, flashMode: self.flashMode, flashModeDidChange: self.flashModeDidChange, recording: self.recording, duration: self.duration, isDualCameraEnabled: self.isDualCameraEnabled)
    }
    
    func updatedPosition(_ position: Camera.Position) -> CameraState {
        return CameraState(mode: self.mode, position: position, flashMode: self.flashMode, flashModeDidChange: self.flashModeDidChange, recording: self.recording, duration: self.duration, isDualCameraEnabled: self.isDualCameraEnabled)
    }
    
    func updatedFlashMode(_ flashMode: Camera.FlashMode) -> CameraState {
        return CameraState(mode: self.mode, position: self.position, flashMode: flashMode, flashModeDidChange: self.flashMode != flashMode, recording: self.recording, duration: self.duration, isDualCameraEnabled: self.isDualCameraEnabled)
    }
    
    func updatedRecording(_ recording: Recording) -> CameraState {
        return CameraState(mode: self.mode, position: self.position, flashMode: self.flashMode, flashModeDidChange: self.flashModeDidChange, recording: recording, duration: self.duration, isDualCameraEnabled: self.isDualCameraEnabled)
    }
    
    func updatedDuration(_ duration: Double) -> CameraState {
        return CameraState(mode: self.mode, position: self.position, flashMode: self.flashMode, flashModeDidChange: self.flashModeDidChange, recording: self.recording, duration: duration, isDualCameraEnabled: self.isDualCameraEnabled)
    }
    
    func updatedIsDualCameraEnabled(_ isDualCameraEnabled: Bool) -> CameraState {
        return CameraState(mode: self.mode, position: self.position, flashMode: self.flashMode, flashModeDidChange: self.flashModeDidChange, recording: self.recording, duration: self.duration, isDualCameraEnabled: isDualCameraEnabled)
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
private let dualButtonTag = GenericComponentViewTag()

private final class CameraScreenComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let cameraState: CameraState
    let cameraAuthorizationStatus: AccessType
    let microphoneAuthorizationStatus: AccessType
    let hasAppeared: Bool
    let isVisible: Bool
    let panelWidth: CGFloat
    let animateFlipAction: ActionSlot<Void>
    let animateShutter: () -> Void
    let toggleCameraPositionAction: ActionSlot<Void>
    let getController: () -> CameraScreen?
    let present: (ViewController) -> Void
    let push: (ViewController) -> Void
    let completion: ActionSlot<Signal<CameraScreen.Result, NoError>>
    
    init(
        context: AccountContext,
        cameraState: CameraState,
        cameraAuthorizationStatus: AccessType,
        microphoneAuthorizationStatus: AccessType,
        hasAppeared: Bool,
        isVisible: Bool,
        panelWidth: CGFloat,
        animateFlipAction: ActionSlot<Void>,
        animateShutter: @escaping () -> Void,
        toggleCameraPositionAction: ActionSlot<Void>,
        getController: @escaping () -> CameraScreen?,
        present: @escaping (ViewController) -> Void,
        push: @escaping (ViewController) -> Void,
        completion: ActionSlot<Signal<CameraScreen.Result, NoError>>
    ) {
        self.context = context
        self.cameraState = cameraState
        self.cameraAuthorizationStatus = cameraAuthorizationStatus
        self.microphoneAuthorizationStatus = microphoneAuthorizationStatus
        self.hasAppeared = hasAppeared
        self.isVisible = isVisible
        self.panelWidth = panelWidth
        self.animateFlipAction = animateFlipAction
        self.animateShutter = animateShutter
        self.toggleCameraPositionAction = toggleCameraPositionAction
        self.getController = getController
        self.present = present
        self.push = push
        self.completion = completion
    }
    
    static func ==(lhs: CameraScreenComponent, rhs: CameraScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.cameraState != rhs.cameraState {
            return false
        }
        if lhs.cameraAuthorizationStatus != rhs.cameraAuthorizationStatus {
            return false
        }
        if lhs.microphoneAuthorizationStatus != rhs.microphoneAuthorizationStatus {
            return false
        }
        if lhs.hasAppeared != rhs.hasAppeared {
            return false
        }
        if lhs.isVisible != rhs.isVisible {
            return false
        }
        if lhs.panelWidth != rhs.panelWidth {
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
        private let present: (ViewController) -> Void
        private let completion: ActionSlot<Signal<CameraScreen.Result, NoError>>
        private let animateShutter: () -> Void
        private let animateFlipAction: ActionSlot<Void>
        private let toggleCameraPositionAction: ActionSlot<Void>
        private let getController: () -> CameraScreen?
        
        private var resultDisposable = MetaDisposable()
                
        private var mediaAssetsContext: MediaAssetsContext?
        fileprivate var lastGalleryAsset: PHAsset?
        private var lastGalleryAssetsDisposable: Disposable?
        
        private var volumeButtonsListener: VolumeButtonsListener?
        private let volumeButtonsListenerShouldBeActive = ValuePromise<Bool>(false, ignoreRepeated: true)
        
        var cameraState: CameraState?
        var swipeHint: CaptureControlsComponent.SwipeHint = .none
        var isTransitioning = false
        
        private let hapticFeedback = HapticFeedback()
        
        init(
            context: AccountContext,
            present: @escaping (ViewController) -> Void,
            completion: ActionSlot<Signal<CameraScreen.Result, NoError>>,
            animateShutter: @escaping () -> Void = {},
            animateFlipAction: ActionSlot<Void>,
            toggleCameraPositionAction: ActionSlot<Void>,
            getController: @escaping () -> CameraScreen? = {
                return nil
            }
        ) {
            self.context = context
            self.present = present
            self.completion = completion
            self.animateShutter = animateShutter
            self.animateFlipAction = animateFlipAction
            self.toggleCameraPositionAction = toggleCameraPositionAction
            self.getController = getController
            
            super.init()
                        
            Queue.concurrentDefaultQueue().async {
                self.setupRecentAssetSubscription()
            }
            
            self.setupVolumeButtonsHandler()
            
            self.toggleCameraPositionAction.connect({ [weak self] in
                if let self {
                    self.togglePosition(self.animateFlipAction)
                }
            })
        }
        
        deinit {
            self.lastGalleryAssetsDisposable?.dispose()
            self.resultDisposable.dispose()
        }
        
        func setupRecentAssetSubscription() {
            let mediaAssetsContext = MediaAssetsContext()
            self.mediaAssetsContext = mediaAssetsContext
            
            self.lastGalleryAssetsDisposable = (
                mediaAssetsContext.mediaAccess()
                |> mapToSignal { [weak mediaAssetsContext] status in
                    if case .authorized = status, let mediaAssetsContext {
                        return mediaAssetsContext.recentAssets()
                    } else {
                        return .complete()
                    }
                }
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
        
        func requestMediaAccess(completion: @escaping () -> Void) {
            guard let mediaAssetsContext = self.mediaAssetsContext else {
                return
            }
            mediaAssetsContext.requestMediaAccess(completion: completion)
        }
        
        func setupVolumeButtonsHandler() {
            guard self.volumeButtonsListener == nil else {
                return
            }
            
            self.volumeButtonsListener = VolumeButtonsListener(
                shouldBeActive: self.volumeButtonsListenerShouldBeActive.get(),
                upPressed: { [weak self] in
                    if let self {
                        self.handleVolumePressed()
                    }
                },
                upReleased: { [weak self] in
                    if let self {
                        self.handleVolumeReleased()
                    }
                },
                downPressed: { [weak self] in
                    if let self {
                        self.handleVolumePressed()
                    }
                },
                downReleased: { [weak self] in
                    if let self {
                        self.handleVolumeReleased()
                    }
                }
            )
        }
        
        var volumeButtonsListenerActive = false {
            didSet {
                self.volumeButtonsListenerShouldBeActive.set(self.volumeButtonsListenerActive)
            }
        }
        
        private var buttonPressTimestamp: Double?
        private var buttonPressTimer: SwiftSignalKit.Timer?
        private var isPressingButton = false
        
        private func handleVolumePressed() {
            guard let controller = self.getController(), let _ = controller.camera else {
                return
            }
            self.isPressingButton = false
            self.buttonPressTimestamp = CACurrentMediaTime()
            
            self.buttonPressTimer = SwiftSignalKit.Timer(timeout: 0.3, repeat: false, completion: { [weak self] in
                if let self, let _ = self.buttonPressTimestamp {
                    if case .none = controller.cameraState.recording {
                        self.startVideoRecording(pressing: true)
                        self.isPressingButton = true
                    }
                    self.buttonPressTimestamp = nil
                    self.buttonPressTimer?.invalidate()
                    self.buttonPressTimer = nil
                }
            }, queue: Queue.mainQueue())
            self.buttonPressTimer?.start()
        }
        
        private func handleVolumeReleased() {
            guard let controller = self.getController(), let _ = controller.camera else {
                return
            }
            if case .none = controller.cameraState.recording {
                switch controller.cameraState.mode {
                case .photo:
                    self.animateShutter()
                    self.takePhoto()
                case .video:
                    self.startVideoRecording(pressing: false)
                }
            } else {
                if self.isPressingButton, case .handsFree = controller.cameraState.recording {
                    
                } else {
                    self.stopVideoRecording()
                }
            }
            
            self.buttonPressTimer?.invalidate()
            self.buttonPressTimer = nil
            self.buttonPressTimestamp = nil
        }
        
        func updateCameraMode(_ mode: CameraMode) {
            guard let controller = self.getController(), let _ = controller.camera else {
                return
            }
            controller.updateCameraState({ $0.updatedMode(mode) }, transition: .spring(duration: 0.3))
        }
        
        func toggleFlashMode() {
            guard let controller = self.getController(), let camera = controller.camera else {
                return
            }
            switch controller.cameraState.flashMode {
            case .off:
                camera.setFlashMode(.on)
            case .on:
                camera.setFlashMode(.auto)
            default:
                camera.setFlashMode(.off)
            }
            self.hapticFeedback.impact(.light)
        }
        
        private var lastFlipTimestamp: Double?
        func togglePosition(_ action: ActionSlot<Void>) {
            guard let controller = self.getController(), let camera = controller.camera else {
                return
            }
            let currentTimestamp = CACurrentMediaTime()
            if let lastFlipTimestamp = self.lastFlipTimestamp, currentTimestamp - lastFlipTimestamp < 1.0 {
                return
            }
            if let lastDualCameraTimestamp = self.lastDualCameraTimestamp, currentTimestamp - lastDualCameraTimestamp < 1.5 {
                return
            }
            self.lastFlipTimestamp = currentTimestamp
            
            camera.togglePosition()
            
            action.invoke(Void())
            
            self.hapticFeedback.impact(.light)
        }
        
        private var lastDualCameraTimestamp: Double?
        func toggleDualCamera() {
            guard let controller = self.getController(), let camera = controller.camera else {
                return
            }
            let currentTimestamp = CACurrentMediaTime()
            if let lastDualCameraTimestamp = self.lastDualCameraTimestamp, currentTimestamp - lastDualCameraTimestamp < 1.5 {
                return
            }
            if let lastFlipTimestamp = self.lastFlipTimestamp, currentTimestamp - lastFlipTimestamp < 1.0 {
                return
            }
            self.lastDualCameraTimestamp = currentTimestamp
            
            controller.node.dismissAllTooltips()
            let _ = ApplicationSpecificNotice.incrementStoriesDualCameraTip(accountManager: self.context.sharedContext.accountManager, count: 2).start()
            
            let isEnabled = !controller.cameraState.isDualCameraEnabled
            camera.setDualCameraEnabled(isEnabled)
            controller.updateCameraState({ $0.updatedIsDualCameraEnabled(isEnabled) }, transition: .easeInOut(duration: 0.1))
            
            self.hapticFeedback.impact(.light)
        }
        
        func updateSwipeHint(_ hint: CaptureControlsComponent.SwipeHint) {
            guard hint != self.swipeHint else {
                return
            }
            self.swipeHint = hint
            self.updated(transition: .easeInOut(duration: 0.2))
        }
        
        private var isTakingPhoto = false
        func takePhoto() {
            guard let controller = self.getController(), let camera = controller.camera else {
                return
            }
            guard !self.isTakingPhoto else {
                return
            }
            self.isTakingPhoto = true
            
            controller.node.dismissAllTooltips()
            
            let takePhoto = camera.takePhoto()
            |> mapToSignal { value -> Signal<CameraScreen.Result, NoError> in
                switch value {
                case .began:
                    return .single(.pendingImage)
                case let .finished(image, additionalImage, _):
                    return .single(.image(CameraScreen.Result.Image(image: image, additionalImage: additionalImage, additionalImagePosition: .topRight)))
                case .failed:
                    return .complete()
                }
            }
            self.completion.invoke(takePhoto)
            Queue.mainQueue().after(1.0) {
                self.isTakingPhoto = false
            }
        }
        
        func startVideoRecording(pressing: Bool) {
            guard let controller = self.getController(), let camera = controller.camera else {
                return
            }
            guard case .none = controller.cameraState.recording else {
                return
            }
            
            controller.node.dismissAllTooltips()
            
            self.resultDisposable.set((camera.startRecording()
            |> deliverOnMainQueue).start(next: { [weak self] duration in
                if let self, let controller = self.getController() {
                    controller.updateCameraState({ $0.updatedDuration(duration) }, transition: .easeInOut(duration: 0.1))
                    if duration > 59.0 {
                        self.stopVideoRecording()
                    }
                }
            }))
            
            controller.updateCameraState({ $0.updatedRecording(pressing ? .holding : .handsFree).updatedDuration(0.0) }, transition: .spring(duration: 0.4))
        }
        
        func stopVideoRecording() {
            guard let controller = self.getController(), let camera = controller.camera else {
                return
            }
            
            self.resultDisposable.set((camera.stopRecording()
            |> deliverOnMainQueue).start(next: { [weak self] result in
                if let self, case let .finished(mainResult, additionalResult, duration, positionChangeTimestamps, _) = result {
                    self.completion.invoke(.single(.video(CameraScreen.Result.Video(videoPath: mainResult.0, coverImage: mainResult.1, mirror: mainResult.2, additionalVideoPath: additionalResult?.0, additionalCoverImage: additionalResult?.1, dimensions: PixelDimensions(mainResult.3), duration: duration, positionChangeTimestamps: positionChangeTimestamps, additionalVideoPosition: .topRight))))
                }
            }))
            self.isTransitioning = true
            Queue.mainQueue().after(1.25, {
                self.isTransitioning = false
                self.updated(transition: .immediate)
            })
            
            controller.updateCameraState({ $0.updatedRecording(.none).updatedDuration(0.0) }, transition: .spring(duration: 0.4))
        }
        
        func lockVideoRecording() {
            guard let controller = self.getController() else {
                return
            }
            controller.updateCameraState({ $0.updatedRecording(.handsFree) }, transition: .spring(duration: 0.4))
        }
        
        func updateZoom(fraction: CGFloat) {
            guard let camera = self.getController()?.camera else {
                return
            }
            camera.setZoomLevel(fraction)
        }
    }
    
    func makeState() -> State {
        return State(context: self.context, present: self.present, completion: self.completion, animateShutter: self.animateShutter, animateFlipAction: self.animateFlipAction, toggleCameraPositionAction: self.toggleCameraPositionAction, getController: self.getController)
    }
    
    static var body: Body {
        let placeholder = Child(PlaceholderComponent.self)
        let cancelButton = Child(CameraButton.self)
        let captureControls = Child(CaptureControlsComponent.self)
        let zoomControl = Child(ZoomComponent.self)
        let flashButton = Child(CameraButton.self)
        let flipButton = Child(CameraButton.self)
        let dualButton = Child(CameraButton.self)
        let modeControl = Child(ModeComponent.self)
        let hintLabel = Child(HintLabelComponent.self)
        
        let timeBackground = Child(RoundedRectangle.self)
        let timeLabel = Child(MultilineTextComponent.self)
                
        return { context in
            let environment = context.environment[ViewControllerComponentContainer.Environment.self].value
            let component = context.component
            let state = context.state
            let controller = environment.controller
            let availableSize = context.availableSize
            
            state.cameraState = component.cameraState
            state.volumeButtonsListenerActive = component.hasAppeared && component.isVisible
            
            let isTablet: Bool
            if case .regular = environment.metrics.widthClass {
                isTablet = true
            } else {
                isTablet = false
            }
            
            let smallPanelWidth = min(component.panelWidth, 88.0)
            let panelWidth = min(component.panelWidth, 185.0)
            
            var controlsBottomInset: CGFloat = 0.0
            let previewHeight = floorToScreenPixels(availableSize.width * 1.77778)
            if !isTablet {
                if availableSize.height < previewHeight + 30.0 {
                    controlsBottomInset = -48.0
                }
            }
            
            let hasAllRequiredAccess: Bool
            switch component.cameraAuthorizationStatus {
            case .notDetermined:
                hasAllRequiredAccess = true
            case .allowed:
                switch component.microphoneAuthorizationStatus {
                case .notDetermined:
                    hasAllRequiredAccess = true
                case .allowed:
                    hasAllRequiredAccess = true
                default:
                    hasAllRequiredAccess = false
                }
            default:
                hasAllRequiredAccess = false
            }
                        
            if !hasAllRequiredAccess {
                let accountContext = component.context
                let placeholder = placeholder.update(
                    component: PlaceholderComponent(
                        context: component.context,
                        mode: .denied,
                        action: {
                            accountContext.sharedContext.applicationBindings.openSettings()
                        }
                    ),
                    availableSize: CGSize(width: availableSize.width, height: previewHeight),
                    transition: context.transition
                )
                context.add(placeholder
                    .position(CGPoint(x: availableSize.width / 2.0, y: environment.safeInsets.top + previewHeight / 2.0))
                    .clipsToBounds(true)
                    .cornerRadius(11.0)
                    .appear(.default(alpha: true))
                    .disappear(.default(alpha: true))
                )
            }
                        
            if case .holding = component.cameraState.recording {
                
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
            if state.isTransitioning {
                shutterState = .transition
            } else {
                switch component.cameraState.recording {
                case .handsFree:
                    shutterState = .stopRecording
                case .holding:
                    shutterState = .holdRecording(progress: min(1.0, Float(component.cameraState.duration / 60.0)))
                case .none:
                    switch component.cameraState.mode {
                    case .photo:
                        shutterState = .generic
                    case .video:
                        shutterState = .video
                    }
                }
            }
            
            let animateFlipAction = component.animateFlipAction
            let captureControlsAvailableSize: CGSize
            if isTablet {
                captureControlsAvailableSize = CGSize(width: panelWidth, height: availableSize.height)
            } else {
                captureControlsAvailableSize = availableSize
            }
            
            let animateShutter = component.animateShutter
            let captureControls = captureControls.update(
                component: CaptureControlsComponent(
                    isTablet: isTablet,
                    hasAppeared: component.hasAppeared && hasAllRequiredAccess,
                    hasAccess: hasAllRequiredAccess,
                    shutterState: shutterState,
                    lastGalleryAsset: state.lastGalleryAsset,
                    tag: captureControlsTag,
                    galleryButtonTag: galleryButtonTag,
                    shutterTapped: { [weak state] in
                        guard let state, let cameraState = state.cameraState else {
                            return
                        }
                        if case .none = cameraState.recording {
                            if cameraState.mode == .photo {
                                animateShutter()
                                state.takePhoto()
                            } else if cameraState.mode == .video {
                                state.startVideoRecording(pressing: false)
                            }
                        } else {
                            state.stopVideoRecording()
                        }
                    },
                    shutterPressed: { [weak state] in
                        guard let state, let cameraState = state.cameraState, case .none = cameraState.recording else {
                            return
                        }
                        state.startVideoRecording(pressing: true)
                    },
                    shutterReleased: { [weak state] in
                        guard let state, let cameraState = state.cameraState, cameraState.recording != .none else {
                            return
                        }
                        state.stopVideoRecording()
                    },
                    lockRecording: { [weak state] in
                        guard let state, let cameraState = state.cameraState, cameraState.recording != .none else {
                            return
                        }
                        state.lockVideoRecording()
                    },
                    flipTapped: { [weak state] in
                        guard let state else {
                            return
                        }
                        state.togglePosition(animateFlipAction)
                    },
                    galleryTapped: { [weak state] in
                        guard let controller = environment.controller() as? CameraScreen else {
                            return
                        }
                        state?.requestMediaAccess {
                            controller.presentGallery()
                        }
                    },
                    swipeHintUpdated: { [weak state] hint in
                        if let state {
                            state.updateSwipeHint(hint)
                        }
                    },
                    zoomUpdated: { [weak state] fraction in
                        if let state {
                            state.updateZoom(fraction: fraction)
                        }
                    },
                    flipAnimationAction: animateFlipAction
                ),
                availableSize: captureControlsAvailableSize,
                transition: context.transition
            )
            
            let captureControlsPosition: CGPoint
            if isTablet {
                captureControlsPosition = CGPoint(x: availableSize.width - panelWidth / 2.0, y: availableSize.height / 2.0)
            } else {
                captureControlsPosition = CGPoint(x: availableSize.width / 2.0, y: availableSize.height - captureControls.size.height / 2.0 - environment.safeInsets.bottom - 5.0 + floorToScreenPixels(controlsBottomInset * 0.66))
            }
            context.add(captureControls
                .position(captureControlsPosition)
            )
            
            let topControlInset: CGFloat = 20.0
            if case .none = component.cameraState.recording, !state.isTransitioning {
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
                    .position(CGPoint(x: isTablet ? smallPanelWidth / 2.0 : topControlInset + cancelButton.size.width / 2.0, y: max(environment.statusBarHeight + 5.0, environment.safeInsets.top + topControlInset) + cancelButton.size.height / 2.0))
                    .appear(.default(scale: true))
                    .disappear(.default(scale: true))
                )
                
                let flashContentComponent: AnyComponentWithIdentity<Empty>
                if component.hasAppeared {
                    let flashIconName: String
                    switch component.cameraState.flashMode {
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
                                    mode: !component.cameraState.flashModeDidChange ? .still(position: .end) : .animating(loop: false),
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
                
                if hasAllRequiredAccess {
                    let flashButton = flashButton.update(
                        component: CameraButton(
                            content: flashContentComponent,
                            action: { [weak state] in
                                if let state {
                                    state.toggleFlashMode()
                                }
                            }
                        ).tagged(flashButtonTag),
                        availableSize: CGSize(width: 40.0, height: 40.0),
                        transition: .immediate
                    )
                    context.add(flashButton
                        .position(CGPoint(x: isTablet ? availableSize.width - smallPanelWidth / 2.0 : availableSize.width - topControlInset - flashButton.size.width / 2.0 - 5.0, y: max(environment.statusBarHeight + 5.0, environment.safeInsets.top + topControlInset) + flashButton.size.height / 2.0))
                        .appear(.default(scale: true))
                        .disappear(.default(scale: true))
                    )
                    
                    if !isTablet && Camera.isDualCameraSupported {
                        let dualButton = dualButton.update(
                            component: CameraButton(
                                content: AnyComponentWithIdentity(
                                    id: "dual",
                                    component: AnyComponent(
                                        DualIconComponent(isSelected: component.cameraState.isDualCameraEnabled)
                                    )
                                ),
                                action: { [weak state] in
                                    if let state {
                                        state.toggleDualCamera()
                                    }
                                }
                            ).tagged(dualButtonTag),
                            availableSize: CGSize(width: 40.0, height: 40.0),
                            transition: .immediate
                        )
                        context.add(dualButton
                            .position(CGPoint(x: availableSize.width - topControlInset - flashButton.size.width / 2.0 - 58.0, y: max(environment.statusBarHeight + 5.0, environment.safeInsets.top + topControlInset) + dualButton.size.height / 2.0 + 2.0))
                            .appear(.default(scale: true))
                            .disappear(.default(scale: true))
                        )
                    }
                }
            }
            
            if isTablet && hasAllRequiredAccess {
                let flipButton = flipButton.update(
                    component: CameraButton(
                        content: AnyComponentWithIdentity(
                            id: "flip",
                            component: AnyComponent(
                                FlipButtonContentComponent(
                                    action: animateFlipAction,
                                    maskFrame: .zero
                                )
                            )
                        ),
                        minSize: CGSize(width: 44.0, height: 44.0),
                        action: { [weak state] in
                            if let state {
                                state.togglePosition(animateFlipAction)
                            }
                        }
                    ),
                    availableSize: availableSize,
                    transition: context.transition
                )
                context.add(flipButton
                    .position(CGPoint(x: smallPanelWidth / 2.0, y: availableSize.height / 2.0))
                    .appear(.default(scale: true))
                    .disappear(.default(scale: true))
                )
            }
            
            var isVideoRecording = false
            if case .video = component.cameraState.mode {
                isVideoRecording = true
            } else if component.cameraState.recording != .none {
                isVideoRecording = true
            }
            
            if isVideoRecording && !state.isTransitioning {
                let duration = Int(component.cameraState.duration)
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
                
                let timePosition: CGPoint
                if isTablet {
                    timePosition = CGPoint(x: availableSize.width - panelWidth / 2.0, y: availableSize.height / 2.0 - 97.0)
                } else {
                    timePosition = CGPoint(x: availableSize.width / 2.0, y:  max(environment.statusBarHeight + 5.0 + 20.0, environment.safeInsets.top + topControlInset + 20.0))
                }
                                
                if component.cameraState.recording != .none {
                    let timeBackground = timeBackground.update(
                        component: RoundedRectangle(color: videoRedColor, cornerRadius: 4.0),
                        availableSize: CGSize(width: timeLabel.size.width + 8.0, height: 28.0),
                        transition: context.transition
                    )
                    context.add(timeBackground
                        .position(timePosition)
                        .appear(.default(alpha: true))
                        .disappear(.default(alpha: true))
                    )
                }
                
                context.add(timeLabel
                    .position(timePosition)
                    .appear(.default(alpha: true))
                    .disappear(.default(alpha: true))
                )
                
                if case .holding = component.cameraState.recording, !isTablet {
                    let hintText: String?
                    switch state.swipeHint {
                    case .none:
                        hintText = " "
                    case .zoom:
                        hintText = environment.strings.Story_Camera_SwipeUpToZoom
                    case .lock:
                        hintText = environment.strings.Story_Camera_SwipeLeftToLock
                    case .releaseLock:
                        hintText = environment.strings.Story_Camera_SwipeLeftRelease
                    case .flip:
                        hintText = environment.strings.Story_Camera_SwipeRightToFlip
                    }
                    if let hintText {
                        let hintLabel = hintLabel.update(
                            component: HintLabelComponent(text: hintText),
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
            
            if case .none = component.cameraState.recording, !state.isTransitioning && hasAllRequiredAccess {
                let availableModeControlSize: CGSize
                if isTablet {
                    availableModeControlSize = CGSize(width: panelWidth, height: 120.0)
                } else {
                    availableModeControlSize = availableSize
                }
                let modeControl = modeControl.update(
                    component: ModeComponent(
                        isTablet: isTablet,
                        strings: environment.strings,
                        availableModes: [.photo, .video],
                        currentMode: component.cameraState.mode,
                        updatedMode: { [weak state] mode in
                            if let state {
                                state.updateCameraMode(mode)
                            }
                        },
                        tag: modeControlTag
                    ),
                    availableSize: availableModeControlSize,
                    transition: context.transition
                )
                let modeControlPosition: CGPoint
                if isTablet {
                    modeControlPosition = CGPoint(x: availableSize.width - panelWidth / 2.0, y: availableSize.height / 2.0 + modeControl.size.height + 26.0)
                } else {
                    modeControlPosition = CGPoint(x: availableSize.width / 2.0, y: availableSize.height - environment.safeInsets.bottom + modeControl.size.height / 2.0 + controlsBottomInset)
                }
                context.add(modeControl
                    .clipsToBounds(true)
                    .position(modeControlPosition)
                    .appear(.default(alpha: true))
                    .disappear(.default(alpha: true))
                )
            }
            return availableSize
        }
    }
}

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
    
    public enum PIPPosition: Int32 {
        case topLeft
        case topRight
        case bottomLeft
        case bottomRight
    }
    
    public enum Result {
        public struct Image {
            public let image: UIImage
            public let additionalImage: UIImage?
            public let additionalImagePosition: CameraScreen.PIPPosition
        }
        
        public struct Video {
            public let videoPath: String
            public let coverImage: UIImage?
            public let mirror: Bool
            public let additionalVideoPath: String?
            public let additionalCoverImage: UIImage?
            public let dimensions: PixelDimensions
            public let duration: Double
            public let positionChangeTimestamps: [(Bool, Double)]
            public let additionalVideoPosition: CameraScreen.PIPPosition
        }
        
        case pendingImage
        case image(Image)
        case video(Video)
        case asset(PHAsset)
        case draft(MediaEditorDraft)
        
        func withPIPPosition(_ position: CameraScreen.PIPPosition) -> Result {
            switch self {
            case let .image(result):
                return .image(Image(image: result.image, additionalImage: result.additionalImage, additionalImagePosition: position))
            case let .video(result):
                return .video(Video(videoPath: result.videoPath, coverImage: result.coverImage, mirror: result.mirror, additionalVideoPath: result.additionalVideoPath, additionalCoverImage: result.additionalCoverImage, dimensions: result.dimensions, duration: result.duration, positionChangeTimestamps: result.positionChangeTimestamps, additionalVideoPosition: position))
            default:
                return self
            }
        }
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

    fileprivate final class Node: ViewControllerTracingNode, UIGestureRecognizerDelegate {
        private weak var controller: CameraScreen?
        private let context: AccountContext
        fileprivate var camera: Camera?
        private let updateState: ActionSlot<CameraState>
        private let toggleCameraPositionAction: ActionSlot<Void>
        
        fileprivate let backgroundView: UIView
        fileprivate let containerView: UIView
        fileprivate let componentHost: ComponentView<ViewControllerComponentContainer.Environment>
        private let previewContainerView: UIView
        
        private let mainPreviewContainerView: UIView
        fileprivate var mainPreviewView: CameraSimplePreviewView
        
        private let additionalPreviewContainerView: UIView
        fileprivate var additionalPreviewView: CameraSimplePreviewView
        
        fileprivate let previewBlurView: BlurView
        private var mainPreviewSnapshotView: UIView?
        private var additionalPreviewSnapshotView: UIView?
        fileprivate let previewFrameLeftDimView: UIView
        fileprivate let previewFrameRightDimView: UIView
        fileprivate let transitionDimView: UIView
        fileprivate let transitionCornersView: UIImageView
        
        private var cameraStateDisposable: Disposable?
        private var changingPositionDisposable: Disposable?
        private var appliedDualCamera = false
        
        private var pipPosition: PIPPosition = .topRight
        
        fileprivate var previewBlurPromise = ValuePromise<Bool>(false)
        private let animateFlipAction = ActionSlot<Void>()
        
        private let idleTimerExtensionDisposable = MetaDisposable()
        
        fileprivate var cameraIsActive = true {
            didSet {
                if self.cameraIsActive {
                    self.idleTimerExtensionDisposable.set(self.context.sharedContext.applicationBindings.pushIdleTimerExtension())
                } else {
                    self.idleTimerExtensionDisposable.set(nil)
                }
            }
        }
        fileprivate var hasGallery = false
        fileprivate var postingAvailable = true
        
        private var presentationData: PresentationData
        private var validLayout: ContainerViewLayout?
        
        fileprivate var didAppear: () -> Void = {}
        
        private let completion = ActionSlot<Signal<CameraScreen.Result, NoError>>()
        
        var cameraState: CameraState {
            didSet {
                let previousPosition = oldValue.position
                let dualCamWasEnabled = oldValue.isDualCameraEnabled
                
                let isDualCameraEnabled = self.cameraState.isDualCameraEnabled
                let currentPosition = self.cameraState.position
                
                if case .front = currentPosition, isDualCameraEnabled != dualCamWasEnabled {
                    if isDualCameraEnabled {
                        if let cloneView = self.mainPreviewView.snapshotView(afterScreenUpdates: false) {
                            self.mainPreviewSnapshotView = cloneView
                            self.mainPreviewContainerView.addSubview(cloneView)
                        }
                    } else {
                        if let cloneView = self.mainPreviewView.snapshotView(afterScreenUpdates: false) {
                            cloneView.frame = self.mainPreviewView.frame
                            self.additionalPreviewSnapshotView = cloneView
                            self.additionalPreviewContainerView.addSubview(cloneView)
                        }
                        if let cloneView = self.additionalPreviewView.snapshotView(afterScreenUpdates: false) {
                            cloneView.frame = self.additionalPreviewView.frame
                            self.mainPreviewSnapshotView = cloneView
                            self.mainPreviewContainerView.addSubview(cloneView)
                        }
                    }
                }
                
                if isDualCameraEnabled && previousPosition != currentPosition {
                    self.animateDualCameraPositionSwitch()
                } else if dualCamWasEnabled != isDualCameraEnabled {
                    self.requestUpdateLayout(hasAppeared: self.hasAppeared, transition: .spring(duration: 0.4))
                    
                    UserDefaults.standard.set(isDualCameraEnabled as NSNumber, forKey: "TelegramStoryCameraIsDualEnabled")
                }
            }
        }
        
        private var cameraAuthorizationStatus: AccessType = .notDetermined
        private var microphoneAuthorizationStatus: AccessType = .notDetermined
        private var galleryAuthorizationStatus: AccessType = .notDetermined
        private var authorizationStatusDisposables = DisposableSet()
                
        init(controller: CameraScreen) {
            self.controller = controller
            self.context = controller.context
            self.updateState = ActionSlot<CameraState>()
            self.toggleCameraPositionAction = ActionSlot<Void>()
            
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
            
            var isDualCameraEnabled = Camera.isDualCameraSupported
            if isDualCameraEnabled {
                if let isDualCameraEnabledValue = UserDefaults.standard.object(forKey: "TelegramStoryCameraIsDualEnabled") as? NSNumber {
                    isDualCameraEnabled = isDualCameraEnabledValue.boolValue
                }
            }
            
            var dualCameraPosition: PIPPosition = .topRight
            if let dualCameraPositionValue = UserDefaults.standard.object(forKey: "TelegramStoryCameraDualPosition") as? NSNumber {
                dualCameraPosition = PIPPosition(rawValue: dualCameraPositionValue.int32Value) ?? .topRight
            }
            self.pipPosition = dualCameraPosition
        
            var cameraFrontPosition = false
            if let cameraFrontPositionValue = UserDefaults.standard.object(forKey: "TelegramStoryCameraUseFrontPosition") as? NSNumber, cameraFrontPositionValue.boolValue {
                cameraFrontPosition = true
            }
            
            self.mainPreviewContainerView = UIView()
            self.mainPreviewContainerView.clipsToBounds = true
            self.mainPreviewView = CameraSimplePreviewView(frame: .zero, main: true)
            
            self.additionalPreviewContainerView = UIView()
            self.additionalPreviewContainerView.clipsToBounds = true
            self.additionalPreviewView = CameraSimplePreviewView(frame: .zero, main: false)
            
            if isDualCameraEnabled {
                self.mainPreviewView.resetPlaceholder(front: false)
                self.additionalPreviewView.resetPlaceholder(front: true)
            } else {
                self.mainPreviewView.resetPlaceholder(front: cameraFrontPosition)
            }
            
            self.cameraState = CameraState(
                mode: .photo,
                position: cameraFrontPosition ? .front : .back,
                flashMode: .off,
                flashModeDidChange: false,
                recording: .none,
                duration: 0.0,
                isDualCameraEnabled: isDualCameraEnabled
            )
                        
            self.previewFrameLeftDimView = UIView()
            self.previewFrameLeftDimView.backgroundColor = UIColor(rgb: 0x000000, alpha: 0.6)
            self.previewFrameLeftDimView.isHidden = true
            
            self.previewFrameRightDimView = UIView()
            self.previewFrameRightDimView.backgroundColor = UIColor(rgb: 0x000000, alpha: 0.6)
            self.previewFrameRightDimView.isHidden = true
            
            self.transitionDimView = UIView()
            self.transitionDimView.backgroundColor = UIColor(rgb: 0x000000)
            self.transitionDimView.isUserInteractionEnabled = false
            
            self.transitionCornersView = UIImageView()

            super.init()
            
            self.backgroundColor = .clear
            
            self.view.addSubview(self.backgroundView)
            self.view.addSubview(self.containerView)
            
            self.containerView.addSubview(self.previewContainerView)
            self.previewContainerView.addSubview(self.mainPreviewContainerView)
            self.previewContainerView.addSubview(self.additionalPreviewContainerView)
            self.previewContainerView.addSubview(self.previewBlurView)
            self.previewContainerView.addSubview(self.previewFrameLeftDimView)
            self.previewContainerView.addSubview(self.previewFrameRightDimView)
            self.containerView.addSubview(self.transitionDimView)
            self.view.addSubview(self.transitionCornersView)
            
            self.mainPreviewContainerView.addSubview(self.mainPreviewView)
            self.additionalPreviewContainerView.addSubview(self.additionalPreviewView)
                        
            self.completion.connect { [weak self] result in
                if let self {
                    let pipPosition = self.pipPosition
                    self.animateOutToEditor()
                    self.controller?.completion(
                        result
                        |> map { result in
                            return result.withPIPPosition(pipPosition)
                        }
                        |> beforeNext { [weak self] value in
                            guard let self else {
                                return
                            }
                            if case .pendingImage = value {
                                Queue.mainQueue().async {
                                    self.mainPreviewView.isEnabled = false
                                    
                                    self.additionalPreviewView.isEnabled = false
                                }
                            } else {
                                Queue.mainQueue().async {
                                    if case .image = value {
                                        Queue.mainQueue().after(0.3) {
                                            self.previewBlurPromise.set(true)
                                        }
                                    }
                                    self.mainPreviewView.isEnabled = false
                                    self.additionalPreviewView.isEnabled = false
                                    self.camera?.stopCapture()
                                }
                            }
                        },
                        nil,
                        {}
                    )
                }
            }
            
            if #available(iOS 13.0, *) {
                if isDualCameraEnabled {
                    let _ = (combineLatest(
                        queue: Queue.mainQueue(),
                        self.mainPreviewView.isPreviewing,
                        self.additionalPreviewView.isPreviewing
                    )
                    |> filter { $0 && $1 }
                    |> take(1)).start(next: { [weak self] _, _ in
                        self?.mainPreviewView.removePlaceholder(delay: 0.35)
                        self?.additionalPreviewView.removePlaceholder(delay: 0.35)
                    })
                } else {
                    let _ = (self.mainPreviewView.isPreviewing
                    |> filter { $0 }
                    |> take(1)
                    |> deliverOnMainQueue).start(next: { [weak self] _ in
                        self?.mainPreviewView.removePlaceholder(delay: 0.35)
                    })
                }
            } else {
                Queue.mainQueue().after(0.35) {
                    self.mainPreviewView.removePlaceholder(delay: 0.15)
                    if isDualCameraEnabled {
                        self.additionalPreviewView.removePlaceholder(delay: 0.15)
                    }
                }
            }
            
            self.idleTimerExtensionDisposable.set(self.context.sharedContext.applicationBindings.pushIdleTimerExtension())
            
            self.authorizationStatusDisposables.add((DeviceAccess.authorizationStatus(subject: .camera(.video))
            |> deliverOnMainQueue).start(next: { [weak self] status in
                if let self {
                    self.cameraAuthorizationStatus = status
                    self.requestUpdateLayout(hasAppeared: self.hasAppeared, transition: .easeInOut(duration: 0.2))
                    
                    self.maybeSetupCamera()
                }
            }))
            
            self.authorizationStatusDisposables.add((DeviceAccess.authorizationStatus(subject: .microphone(.video))
            |> deliverOnMainQueue).start(next: { [weak self] status in
                if let self {
                    self.microphoneAuthorizationStatus = status
                    self.requestUpdateLayout(hasAppeared: self.hasAppeared, transition: .easeInOut(duration: 0.2))
                    
                    self.maybeSetupCamera()
                }
            }))
        }
        
        deinit {
            self.cameraStateDisposable?.dispose()
            self.changingPositionDisposable?.dispose()
            self.idleTimerExtensionDisposable.dispose()
            self.authorizationStatusDisposables.dispose()
        }
        
        private var panGestureRecognizer: UIPanGestureRecognizer?
        private var pipPanGestureRecognizer: UIPanGestureRecognizer?
        override func didLoad() {
            super.didLoad()
            
            self.view.disablesInteractiveModalDismiss = true
            self.view.disablesInteractiveKeyboardGestureRecognizer = true
            
            let pinchGestureRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(self.handlePinch(_:)))
            self.previewContainerView.addGestureRecognizer(pinchGestureRecognizer)
            
            let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.handlePan(_:)))
            panGestureRecognizer.delegate = self
            panGestureRecognizer.maximumNumberOfTouches = 1
            self.panGestureRecognizer = panGestureRecognizer
            self.previewContainerView.addGestureRecognizer(panGestureRecognizer)
            
            let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.handleTap(_:)))
            self.previewContainerView.addGestureRecognizer(tapGestureRecognizer)
            
            let doubleGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.handleDoubleTap(_:)))
            doubleGestureRecognizer.numberOfTapsRequired = 2
            self.previewContainerView.addGestureRecognizer(doubleGestureRecognizer)
            
            let pipPanGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.handlePipPan(_:)))
            pipPanGestureRecognizer.delegate = self
            self.previewContainerView.addGestureRecognizer(pipPanGestureRecognizer)
            self.pipPanGestureRecognizer = pipPanGestureRecognizer
        }
        
        private func maybeSetupCamera() {
            if case .allowed = self.cameraAuthorizationStatus, case .allowed = self.microphoneAuthorizationStatus {
                self.setupCamera()
            }
        }
        
        private func requestDeviceAccess() {
            DeviceAccess.authorizeAccess(to: .camera(.video), { granted in
                if granted {
                    DeviceAccess.authorizeAccess(to: .microphone(.video))
                }
            })
        }
        
        fileprivate var captureStartTimestamp: Double?
        private func setupCamera() {
            guard self.camera == nil else {
                return
            }
            
            let camera = Camera(
                configuration: Camera.Configuration(
                    preset: .hd1920x1080,
                    position: self.cameraState.position,
                    isDualEnabled: self.cameraState.isDualCameraEnabled,
                    audio: true,
                    photo: true,
                    metadata: false,
                    preferredFps: 60.0
                ),
                previewView: self.mainPreviewView,
                secondaryPreviewView: self.additionalPreviewView
            )
            
            self.cameraStateDisposable = combineLatest(
                queue: Queue.mainQueue(),
                camera.flashMode,
                camera.position
            ).start(next: { [weak self] flashMode, position in
                guard let self else {
                    return
                }
                let previousState = self.cameraState
                self.cameraState = self.cameraState.updatedPosition(position).updatedFlashMode(flashMode)
                if !self.animatingDualCameraPositionSwitch {
                    self.requestUpdateLayout(hasAppeared: self.hasAppeared, transition: .easeInOut(duration: 0.2))
                }
                
                if previousState.position != self.cameraState.position {
                    UserDefaults.standard.set((self.cameraState.position == .front) as NSNumber, forKey: "TelegramStoryCameraUseFrontPosition")
                }
            })
            
            var isFirstTime = true
            self.changingPositionDisposable = combineLatest(
                queue: Queue.mainQueue(),
                camera.modeChange,
                self.previewBlurPromise.get()
            ).start(next: { [weak self] modeChange, forceBlur in
                if let self {
                    if modeChange != .none {
                        if case .dualCamera = modeChange, case .front = self.cameraState.position {
                        } else {
                            if let snapshot = self.mainPreviewView.snapshotView(afterScreenUpdates: false) {
                                self.mainPreviewView.addSubview(snapshot)
                                self.mainPreviewSnapshotView = snapshot
                            }
                        }
                        if case .position = modeChange {
                            UIView.transition(with: self.previewContainerView, duration: 0.4, options: [.transitionFlipFromLeft, .curveEaseOut], animations: {
                                self.previewBlurView.effect = UIBlurEffect(style: .dark)
                            })
                        } else {
                            self.previewContainerView.insertSubview(self.previewBlurView, belowSubview: self.additionalPreviewContainerView)
                            
                            UIView.animate(withDuration: 0.4) {
                                self.previewBlurView.effect = UIBlurEffect(style: .dark)
                            }
                        }
                    } else if forceBlur {
                        UIView.animate(withDuration: 0.4) {
                            self.previewBlurView.effect = UIBlurEffect(style: .dark)
                        }
                    } else {
                        if self.previewBlurView.effect != nil {
                            UIView.animate(withDuration: 0.4, animations: {
                                self.previewBlurView.effect = nil
                            }, completion: { _ in
                                self.previewContainerView.insertSubview(self.previewBlurView, aboveSubview: self.additionalPreviewContainerView)
                            })
                        }
                        
                        if let previewSnapshotView = self.mainPreviewSnapshotView {
                            self.mainPreviewSnapshotView = nil
                            UIView.animate(withDuration: 0.25, animations: {
                                previewSnapshotView.alpha = 0.0
                            }, completion: { _ in
                                previewSnapshotView.removeFromSuperview()
                            })
                        }
                        
                        if let previewSnapshotView = self.additionalPreviewSnapshotView {
                            self.additionalPreviewSnapshotView = nil
                            UIView.animate(withDuration: 0.25, animations: {
                                previewSnapshotView.alpha = 0.0
                            }, completion: { _ in
                                previewSnapshotView.removeFromSuperview()
                            })
                        }
                        
                        if isFirstTime {
                            isFirstTime = false
                        } else {
                            if self.cameraState.isDualCameraEnabled {
                                self.mainPreviewView.removePlaceholder()
                                self.additionalPreviewView.removePlaceholder()
                            }
                        }
                    }
                }
            })
            
            camera.focus(at: CGPoint(x: 0.5, y: 0.5), autoFocus: true)
            camera.startCapture()
            self.captureStartTimestamp = CACurrentMediaTime()
            
            self.camera = camera
            
            if self.hasAppeared {
                self.maybePresentTooltips()
            }
        }
        
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            if gestureRecognizer is UIPanGestureRecognizer && otherGestureRecognizer is UIPanGestureRecognizer {
                return false
            }
            if gestureRecognizer is UIPinchGestureRecognizer && otherGestureRecognizer is UIPanGestureRecognizer {
                return false
            }
            return true
        }
        
        override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            let location = gestureRecognizer.location(in: gestureRecognizer.view)
            if gestureRecognizer === self.pipPanGestureRecognizer {
                if !self.cameraState.isDualCameraEnabled {
                    return false
                }
                return self.additionalPreviewContainerView.frame.contains(location)
            } else if gestureRecognizer === self.panGestureRecognizer {
                return true
            }
            return self.hasAppeared
        }
        
        @objc private func handlePinch(_ gestureRecognizer: UIPinchGestureRecognizer) {
            guard let camera = self.camera else {
                return
            }
            switch gestureRecognizer.state {
            case .changed:
                let scale = gestureRecognizer.scale
                camera.setZoomDelta(scale)
                gestureRecognizer.scale = 1.0
            default:
                break
            }
        }

        private var isDismissing = false
        @objc private func handlePan(_ gestureRecognizer: UIPanGestureRecognizer) {
            guard let controller = self.controller, let layout = self.validLayout else {
                return
            }
            let translation = gestureRecognizer.translation(in: gestureRecognizer.view)
            switch gestureRecognizer.state {
            case .began:
                break
            case .changed:
                if case .none = self.cameraState.recording {
                    if case .compact = layout.metrics.widthClass {
                        if (translation.x < -10.0 || self.isDismissing) && self.hasAppeared {
                            self.isDismissing = true
                            let transitionFraction = 1.0 - max(0.0, translation.x * -1.0) / self.frame.width
                            controller.updateTransitionProgress(transitionFraction, transition: .immediate)
                        } else if translation.y < -10.0 && abs(translation.y) > abs(translation.x) {
                            controller.presentGallery(fromGesture: true)
                            gestureRecognizer.isEnabled = false
                            gestureRecognizer.isEnabled = true
                        }
                    }
                }
            case .ended, .cancelled:
                if self.isDismissing {
                    let velocity = gestureRecognizer.velocity(in: self.view)
                    let transitionFraction = 1.0 - max(0.0, translation.x * -1.0) / self.frame.width
                    controller.completeWithTransitionProgress(transitionFraction, velocity: abs(velocity.x), dismissing: true)
                    
                    self.isDismissing = false
                }
            default:
                break
            }
        }
        
        @objc private func handleTap(_ gestureRecognizer: UITapGestureRecognizer) {
            guard let camera = self.camera else {
                return
            }
            
            let location = gestureRecognizer.location(in: gestureRecognizer.view)
            if self.cameraState.isDualCameraEnabled && self.additionalPreviewContainerView.frame.contains(location) {
                self.toggleCameraPositionAction.invoke(Void())
            } else {
                let location = gestureRecognizer.location(in: self.mainPreviewView)
                let point = self.mainPreviewView.cameraPoint(for: location)
                camera.focus(at: point, autoFocus: false)
            }
        }

        @objc private func handleDoubleTap(_ gestureRecognizer: UITapGestureRecognizer) {
            self.toggleCameraPositionAction.invoke(Void())
        }
        
        private var pipTranslation: CGPoint?
        @objc private func handlePipPan(_ gestureRecognizer: UIPanGestureRecognizer) {
            guard let layout = self.validLayout else {
                return
            }
            let translation = gestureRecognizer.translation(in: self.view)
            let location = gestureRecognizer.location(in: self.view)
            let velocity = gestureRecognizer.velocity(in: self.view)
            
            switch gestureRecognizer.state {
            case .began, .changed:
                self.pipTranslation = translation
                self.containerLayoutUpdated(layout: layout, transition: .immediate)
            case .ended, .cancelled:
                self.pipTranslation = nil
                self.pipPosition = pipPositionForLocation(layout: layout, position: location, velocity: velocity)
                self.containerLayoutUpdated(layout: layout, transition: .spring(duration: 0.4))
                
                UserDefaults.standard.set(self.pipPosition.rawValue as NSNumber, forKey: "TelegramStoryCameraDualPosition")
            default:
                break
            }
        }
        
        private var animatingDualCameraPositionSwitch = false
        func animateDualCameraPositionSwitch() {
            let duration: Double = 0.5
            let timingFunction = kCAMediaTimingFunctionSpring
            
            var snapshotView: UIView?
            if let mainSnapshot = self.mainPreviewContainerView.snapshotView(afterScreenUpdates: false) {
                mainSnapshot.frame = self.mainPreviewContainerView.frame
                self.mainPreviewContainerView.superview?.insertSubview(mainSnapshot, belowSubview: self.mainPreviewContainerView)
                
                snapshotView = mainSnapshot
            }
            
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            self.requestUpdateLayout(hasAppeared: self.hasAppeared, transition: .immediate)
            CATransaction.commit()
            
            self.additionalPreviewContainerView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
            self.additionalPreviewContainerView.layer.animateScale(from: 0.01, to: 1.0, duration: duration, timingFunction: timingFunction)
                        
            self.mainPreviewContainerView.layer.animate(
                from: self.additionalPreviewContainerView.layer.cornerRadius as NSNumber,
                to: 12.0 as NSNumber,
                keyPath: "cornerRadius",
                timingFunction: timingFunction,
                duration: duration
            )
            
            self.mainPreviewContainerView.layer.animatePosition(
                from: self.additionalPreviewContainerView.center,
                to: self.mainPreviewContainerView.center,
                duration: duration,
                timingFunction: timingFunction
            )
            
            let scale = self.additionalPreviewContainerView.frame.width / self.mainPreviewContainerView.frame.width
            self.mainPreviewContainerView.layer.animateScale(
                from: scale,
                to: 1.0,
                duration: duration,
                timingFunction: timingFunction
            )
            
            self.animatingDualCameraPositionSwitch = true
            self.mainPreviewContainerView.layer.animateBounds(
                from: CGRect(origin: CGPoint(x: 0.0, y: floorToScreenPixels((self.mainPreviewContainerView.bounds.height - self.mainPreviewContainerView.bounds.width) / 2.0)), size: CGSize(width: self.mainPreviewContainerView.bounds.width, height: self.mainPreviewContainerView.bounds.width)),
                to: self.mainPreviewContainerView.bounds,
                duration: duration,
                timingFunction: timingFunction,
                completion: { [weak snapshotView] _ in
                    snapshotView?.removeFromSuperview()
                    self.animatingDualCameraPositionSwitch = false
                }
            )
        }
        
        func animateIn() {
            self.transitionDimView.alpha = 0.0
            self.backgroundView.alpha = 0.0
            UIView.animate(withDuration: 0.4, animations: {
                self.backgroundView.alpha = 1.0
            })
            
            if let layout = self.validLayout, layout.metrics.isTablet {
                self.controller?.statusBar.updateStatusBarStyle(.Hide, animated: true)
            }
            
            if let transitionIn = self.controller?.transitionIn, let sourceView = transitionIn.sourceView {
                let sourceLocalFrame = sourceView.convert(transitionIn.sourceRect, to: self.view)

                let sourceScale = sourceLocalFrame.width / self.previewContainerView.frame.width
                self.previewContainerView.layer.animatePosition(from: sourceLocalFrame.center, to: self.previewContainerView.center, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, completion: { _ in
                    self.requestUpdateLayout(hasAppeared: true, transition: .immediate)
                })
                self.previewContainerView.layer.animateScale(from: sourceScale, to: 1.0, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
                
                let minSide = min(self.previewContainerView.bounds.width, self.previewContainerView.bounds.height)
                self.previewContainerView.layer.animateBounds(from: CGRect(origin: CGPoint(x: (self.previewContainerView.bounds.width - minSide) / 2.0, y: (self.previewContainerView.bounds.height - minSide) / 2.0), size: CGSize(width: minSide, height: minSide)), to: self.previewContainerView.bounds, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
                self.previewContainerView.layer.animate(
                    from: minSide / 2.0 as NSNumber,
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
            self.camera?.stopCapture(invalidate: true)
                                    
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
                
                let minSide = min(self.previewContainerView.bounds.width, self.previewContainerView.bounds.height)
                self.previewContainerView.layer.animateBounds(from: self.previewContainerView.bounds, to: CGRect(origin: CGPoint(x: (self.previewContainerView.bounds.width - minSide) / 2.0, y: (self.previewContainerView.bounds.height - minSide) / 2.0), size: CGSize(width: minSide, height: minSide)), duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
                self.previewContainerView.layer.animate(
                    from: self.previewContainerView.layer.cornerRadius as NSNumber,
                    to: minSide / 2.0 as NSNumber,
                    keyPath: "cornerRadius",
                    timingFunction: kCAMediaTimingFunctionSpring,
                    duration: 0.3,
                    removeOnCompletion: false
                )
                
                if let view = self.componentHost.view {
                    view.layer.animatePosition(from: view.center, to: destinationLocalFrame.center, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
                    view.layer.animateScale(from: 1.0, to: targetScale, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
                }
            } else {
                completion()
            }

            self.componentHost.view?.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
            self.previewContainerView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.35, removeOnCompletion: false)
        }
        
        func animateOutToEditor() {
            self.cameraIsActive = false
            self.requestUpdateLayout(hasAppeared: self.hasAppeared, transition: .immediate)
            
            let transition = Transition(animation: .curve(duration: 0.2, curve: .easeInOut))
            if let view = self.componentHost.findTaggedView(tag: cancelButtonTag) {
                view.layer.animateScale(from: 1.0, to: 0.1, duration: 0.2)
                transition.setAlpha(view: view, alpha: 0.0)
            }
            if let view = self.componentHost.findTaggedView(tag: dualButtonTag) {
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
            self.mainPreviewView.isEnabled = false
            self.additionalPreviewView.isEnabled = false
            Queue.mainQueue().after(0.3) {
                self.previewBlurPromise.set(true)
            }
            self.camera?.stopCapture()
            
            self.cameraIsActive = false
            self.requestUpdateLayout(hasAppeared: self.hasAppeared, transition: .immediate)
        }
        
        func resumeCameraCapture() {
            if !self.mainPreviewView.isEnabled {
                if let snapshot = self.mainPreviewView.snapshotView(afterScreenUpdates: false) {
                    self.mainPreviewView.addSubview(snapshot)
                    self.mainPreviewSnapshotView = snapshot
                }
                if let snapshot = self.additionalPreviewView.snapshotView(afterScreenUpdates: false) {
                    self.additionalPreviewView.addSubview(snapshot)
                    self.additionalPreviewSnapshotView = snapshot
                }
                self.mainPreviewView.isEnabled = true
                self.additionalPreviewView.isEnabled = true
                self.camera?.startCapture()
                
                if #available(iOS 13.0, *) {
                    let _ = (self.mainPreviewView.isPreviewing
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
                
                self.cameraIsActive = true
                self.requestUpdateLayout(hasAppeared: self.hasAppeared, transition: .immediate)
            }
        }
        
        func animateInFromEditor(toGallery: Bool) {
            if !toGallery {
                self.resumeCameraCapture()
                
                self.cameraIsActive = true
                self.requestUpdateLayout(hasAppeared: self.hasAppeared, transition: .immediate)
                
                let transition = Transition(animation: .curve(duration: 0.2, curve: .easeInOut))
                if let view = self.componentHost.findTaggedView(tag: cancelButtonTag) {
                    view.layer.animateScale(from: 0.1, to: 1.0, duration: 0.2)
                    transition.setAlpha(view: view, alpha: 1.0)
                }
                if let view = self.componentHost.findTaggedView(tag: dualButtonTag) {
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
            guard let layout = self.validLayout, case .compact = layout.metrics.widthClass else {
                return
            }
            
            let progress = 1.0 - value
            let maxScale = (layout.size.width - 16.0 * 2.0) / layout.size.width
            
            let topInset: CGFloat = (layout.statusBarHeight ?? 0.0) + 5.0
            let targetTopInset = ceil((layout.statusBarHeight ?? 0.0) - (layout.size.height - layout.size.height * maxScale) / 2.0)
            let deltaOffset = (targetTopInset - topInset)
            
            let scale = 1.0 * progress + (1.0 - progress) * maxScale
            let offset = (1.0 - progress) * deltaOffset
            transition.updateSublayerTransformScaleAndOffset(layer: self.containerView.layer, scale: scale, offset: CGPoint(x: 0.0, y: offset), beginWithCurrentState: true)
        }
        
        func presentDraftTooltip() {
            guard let sourceView = self.componentHost.findTaggedView(tag: galleryButtonTag), let absoluteLocation = sourceView.superview?.convert(sourceView.center, to: self.view) else {
                return
            }
            
            let location = CGRect(origin: CGPoint(x: absoluteLocation.x, y: absoluteLocation.y - 29.0), size: CGSize())
                        
            let controller = TooltipScreen(account: self.context.account, sharedContext: self.context.sharedContext, text: .plain(text: self.presentationData.strings.Story_Camera_TooltipDraftSaved), location: .point(location, .bottom), displayDuration: .default, inset: 16.0, shouldDismissOnTouch: { _, _ in
                return .ignore
            })
            self.controller?.present(controller, in: .current)
        }
        
        func presentDualCameraTooltip() {
            guard let sourceView = self.componentHost.findTaggedView(tag: dualButtonTag), self.cameraState.isDualCameraEnabled else {
                return
            }
            
            let parentFrame = self.view.convert(self.bounds, to: nil)
            let location = sourceView.convert(sourceView.bounds, to: nil).offsetBy(dx: -parentFrame.minX, dy: 0.0)
            
            let accountManager = self.context.sharedContext.accountManager
            let tooltipController = TooltipScreen(account: self.context.account, sharedContext: self.context.sharedContext, text: .plain(text: self.presentationData.strings.Story_Camera_TooltipDisableDual), textAlignment: .center, location: .point(location, .right), displayDuration: .custom(5.0), inset: 16.0, shouldDismissOnTouch: { point, containerFrame in
                if containerFrame.contains(point) {
                    let _ = ApplicationSpecificNotice.incrementStoriesDualCameraTip(accountManager: accountManager, count: 2).start()
                    return .dismiss(consume: true)
                }
                return .ignore
            })
            self.controller?.present(tooltipController, in: .current)
        }
        
        func presentCameraTooltip() {
            guard let sourceView = self.componentHost.findTaggedView(tag: captureControlsTag) else {
                return
            }
            
            let parentFrame = self.view.convert(self.bounds, to: nil)
            let absoluteFrame = sourceView.convert(sourceView.bounds, to: nil).offsetBy(dx: -parentFrame.minX, dy: 0.0)
            let location = CGRect(origin: CGPoint(x: absoluteFrame.midX, y: absoluteFrame.minY + 3.0), size: CGSize())
            
            let accountManager = self.context.sharedContext.accountManager
            let tooltipController = TooltipScreen(account: self.context.account, sharedContext: self.context.sharedContext, text: .plain(text: self.presentationData.strings.Story_Camera_TooltipTakePhotos), textAlignment: .center, location: .point(location, .bottom), displayDuration: .custom(4.5), inset: 16.0, shouldDismissOnTouch: { [weak self] point, containerFrame in
                if containerFrame.contains(point) {
                    let _ = ApplicationSpecificNotice.incrementStoriesCameraTip(accountManager: accountManager).start()
                    Queue.mainQueue().justDispatch {
                        self?.maybePresentTooltips()
                    }
                    return .dismiss(consume: true)
                }
                return .ignore
            })
            self.controller?.present(tooltipController, in: .current)
        }
        
        func maybePresentTooltips() {
            guard let layout = self.validLayout, case .compact = layout.metrics.widthClass else {
                return
            }
            let _ = (ApplicationSpecificNotice.incrementStoriesCameraTip(accountManager: self.context.sharedContext.accountManager)
            |> deliverOnMainQueue).start(next: { [weak self] count in
                guard let self else {
                    return
                }
                if count > 1 {
                    let _ = (ApplicationSpecificNotice.getStoriesDualCameraTip(accountManager: self.context.sharedContext.accountManager)
                    |> deliverOnMainQueue).start(next: { [weak self] count in
                        guard let self else {
                            return
                        }
                        if count < 2 {
                            self.presentDualCameraTooltip()
                        }
                    })
                    return
                } else {
                    self.presentCameraTooltip()
                }
            })
        }

        fileprivate func dismissAllTooltips() {
            guard let controller = self.controller else {
                return
            }
            controller.window?.forEachController({ controller in
                if let controller = controller as? TooltipScreen {
                    controller.dismiss()
                }
            })
            controller.forEachController({ controller in
                if let controller = controller as? TooltipScreen {
                    controller.dismiss()
                }
                return true
            })
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            let result = super.hitTest(point, with: event)
            if result == self.componentHost.view {
                if self.additionalPreviewContainerView.bounds.contains(self.view.convert(point, to: self.additionalPreviewContainerView)) {
                    return self.additionalPreviewContainerView
                } else {
                    return self.mainPreviewView
                }
            }
            return result
        }
        
        func requestUpdateLayout(hasAppeared: Bool, transition: Transition) {
            if let layout = self.validLayout {
                self.containerLayoutUpdated(layout: layout, forceUpdate: true, hasAppeared: hasAppeared, transition: transition)
            }
        }

        fileprivate var hasAppeared = false
        func containerLayoutUpdated(layout: ContainerViewLayout, forceUpdate: Bool = false, hasAppeared: Bool = false, transition: Transition) {
            guard let _ = self.controller else {
                return
            }
            let isFirstTime = self.validLayout == nil
            self.validLayout = layout
            
            let isTablet = layout.metrics.isTablet
            
            var topInset: CGFloat = (layout.statusBarHeight ?? 0.0) + 5.0
            let previewSize: CGSize
            if isTablet {
                previewSize = CGSize(width: floorToScreenPixels(layout.size.height / 1.77778), height: layout.size.height)
            } else {
                previewSize = CGSize(width: layout.size.width, height: floorToScreenPixels(layout.size.width * 1.77778))
                if layout.size.height < previewSize.height + 30.0 {
                    topInset = 0.0
                }
            }
            let bottomInset = layout.size.height - previewSize.height - topInset
            
            let panelWidth: CGFloat
            let previewFrame: CGRect
            let viewfinderFrame: CGRect
            if isTablet {
                previewFrame = CGRect(origin: .zero, size: layout.size)
                viewfinderFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((layout.size.width - previewSize.width) / 2.0), y: 0.0), size: previewSize)
                panelWidth = viewfinderFrame.minX
            } else {
                previewFrame = CGRect(origin: CGPoint(x: 0.0, y: topInset), size: previewSize)
                viewfinderFrame = previewFrame
                panelWidth = 0.0
            }
            
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
                
                if self.camera != nil {
                    self.maybePresentTooltips()
                } else if case .notDetermined = self.cameraAuthorizationStatus {
                    self.requestDeviceAccess()
                } else if case .notDetermined = self.microphoneAuthorizationStatus {
                    self.requestDeviceAccess()
                }
                self.didAppear()
            }

            let componentSize = self.componentHost.update(
                transition: transition,
                component: AnyComponent(
                    CameraScreenComponent(
                        context: self.context,
                        cameraState: self.cameraState,
                        cameraAuthorizationStatus: self.cameraAuthorizationStatus,
                        microphoneAuthorizationStatus: self.microphoneAuthorizationStatus,
                        hasAppeared: self.hasAppeared,
                        isVisible: self.cameraIsActive && !self.hasGallery && self.postingAvailable,
                        panelWidth: panelWidth,
                        animateFlipAction: self.animateFlipAction,
                        animateShutter: { [weak self] in
                            self?.mainPreviewContainerView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                        },
                        toggleCameraPositionAction: self.toggleCameraPositionAction,
                        getController: { [weak self] in
                            return self?.controller
                        },
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
            
            if let view = self.componentHost.findTaggedView(tag: flashButtonTag), view.layer.shadowOpacity.isZero {
                view.layer.shadowOffset = CGSize(width: 0.0, height: 0.0)
                view.layer.shadowRadius = 3.0
                view.layer.shadowColor = UIColor.black.cgColor
                view.layer.shadowOpacity = 0.25
            }
            
            transition.setPosition(view: self.backgroundView, position: CGPoint(x: layout.size.width / 2.0, y: layout.size.height / 2.0))
            transition.setBounds(view: self.backgroundView, bounds: CGRect(origin: .zero, size: layout.size))
            
            if !self.hasGallery {
                transition.setPosition(view: self.containerView, position: CGPoint(x: layout.size.width / 2.0, y: layout.size.height / 2.0))
            }
            transition.setBounds(view: self.containerView, bounds: CGRect(origin: .zero, size: layout.size))
            
            transition.setFrame(view: self.transitionDimView, frame: CGRect(origin: .zero, size: layout.size))
            
            let previewContainerFrame: CGRect
            if isTablet {
                previewContainerFrame = CGRect(origin: .zero, size: layout.size)
            } else {
                previewContainerFrame = previewFrame
            }
            
            transition.setFrame(view: self.previewContainerView, frame: previewContainerFrame)
            transition.setFrame(view: self.mainPreviewContainerView, frame: CGRect(origin: .zero, size: previewContainerFrame.size))
            
            transition.setFrame(view: self.previewBlurView, frame: CGRect(origin: .zero, size: previewContainerFrame.size))
            
            let isDualCameraEnabled = self.cameraState.isDualCameraEnabled
            let dualCamUpdated = self.appliedDualCamera != isDualCameraEnabled
            self.appliedDualCamera = isDualCameraEnabled
            
            let dualCameraSize: CGFloat = 160.0
            let circleSide = floorToScreenPixels(previewSize.width * dualCameraSize / 393.0)
            let circleOffset = CGPoint(x: previewSize.width * (dualCameraSize + 107.0) / 1080.0, y: previewSize.width * (dualCameraSize + 278.0) / 1080.0)
            
            var origin: CGPoint
            switch self.pipPosition {
            case .topLeft:
                origin = CGPoint(x: circleOffset.x, y: circleOffset.y)
                if !isDualCameraEnabled {
                    origin = origin.offsetBy(dx: -180.0, dy: 0.0)
                }
            case .topRight:
                origin = CGPoint(x: previewFrame.width - circleOffset.x, y: circleOffset.y)
                if !isDualCameraEnabled {
                    origin = origin.offsetBy(dx: 180.0, dy: 0.0)
                }
            case .bottomLeft:
                origin = CGPoint(x: circleOffset.x, y: previewFrame.height - circleOffset.y)
                if !isDualCameraEnabled {
                    origin = origin.offsetBy(dx: -180.0, dy: 0.0)
                }
            case .bottomRight:
                origin = CGPoint(x: previewFrame.width - circleOffset.x, y: previewFrame.height - circleOffset.y)
                if !isDualCameraEnabled {
                    origin = origin.offsetBy(dx: 180.0, dy: 0.0)
                }
            }
            
            if let pipTranslation = self.pipTranslation {
                origin = origin.offsetBy(dx: pipTranslation.x, dy: pipTranslation.y)
            }
            
            let additionalPreviewInnerSize = previewFrame.size.aspectFilled(CGSize(width: circleSide, height: circleSide))
    
            let additionalPreviewFrame = CGRect(origin: CGPoint(x: origin.x - circleSide / 2.0, y: origin.y - circleSide / 2.0), size: CGSize(width: circleSide, height: circleSide))
            
            transition.setPosition(view: self.additionalPreviewContainerView, position: additionalPreviewFrame.center)
            transition.setBounds(view: self.additionalPreviewContainerView, bounds: CGRect(origin: .zero, size: additionalPreviewFrame.size))
            self.additionalPreviewContainerView.layer.cornerRadius = additionalPreviewFrame.width / 2.0
            
            transition.setScale(view: self.additionalPreviewContainerView, scale: isDualCameraEnabled ? 1.0 : 0.1)
            transition.setAlpha(view: self.additionalPreviewContainerView, alpha: isDualCameraEnabled ? 1.0 : 0.0)
            
            if dualCamUpdated && isDualCameraEnabled {
                if case .back = self.cameraState.position {
                    self.additionalPreviewView.resetPlaceholder(front: true)
                } else {
                    self.mainPreviewView.resetPlaceholder(front: false)
                }
            }
            
            var mainPreviewInnerSize = previewFrame.size
            
            let mainPreviewView: CameraSimplePreviewView
            let additionalPreviewView: CameraSimplePreviewView
            if case .front = self.cameraState.position, isDualCameraEnabled {
                mainPreviewView = self.additionalPreviewView
                additionalPreviewView = self.mainPreviewView
                
                mainPreviewInnerSize = CGSize(width: floorToScreenPixels(mainPreviewInnerSize.height / 3.0 * 4.0), height: mainPreviewInnerSize.height)
            } else {
                mainPreviewView = self.mainPreviewView
                additionalPreviewView = self.additionalPreviewView
            }
            
            let mainPreviewInnerFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((previewFrame.width - mainPreviewInnerSize.width) / 2.0), y: floorToScreenPixels((previewFrame.height - mainPreviewInnerSize.height) / 2.0)), size: mainPreviewInnerSize)
            let additionalPreviewInnerFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((circleSide - additionalPreviewInnerSize.width) / 2.0), y: floorToScreenPixels((circleSide - additionalPreviewInnerSize.height) / 2.0)), size: additionalPreviewInnerSize)
            
            if mainPreviewView.superview != self.mainPreviewContainerView {
                self.mainPreviewContainerView.insertSubview(mainPreviewView, at: 0)
            }
            if additionalPreviewView.superview != self.additionalPreviewContainerView {
                self.additionalPreviewContainerView.insertSubview(additionalPreviewView, at: 0)
            }
            
            mainPreviewView.frame = mainPreviewInnerFrame
            additionalPreviewView.frame = additionalPreviewInnerFrame
                              
            self.previewFrameLeftDimView.isHidden = !isTablet
            transition.setFrame(view: self.previewFrameLeftDimView, frame: CGRect(origin: .zero, size: CGSize(width: viewfinderFrame.minX, height: viewfinderFrame.height)))
            
            self.previewFrameRightDimView.isHidden = !isTablet
            transition.setFrame(view: self.previewFrameRightDimView, frame: CGRect(origin: CGPoint(x: viewfinderFrame.maxX, y: 0.0), size: CGSize(width: viewfinderFrame.minX + 1.0, height: viewfinderFrame.height)))
            
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
            self.transitionCornersView.isHidden = isTablet
        
            transition.setPosition(view: self.transitionCornersView, position: CGPoint(x: layout.size.width + screenCornerRadius / 2.0, y: layout.size.height / 2.0))
            transition.setBounds(view: self.transitionCornersView, bounds: CGRect(origin: .zero, size: CGSize(width: screenCornerRadius, height: layout.size.height)))
            
            if isTablet && isFirstTime {
                self.animateIn()
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

    public final class ResultTransition {
        public weak var sourceView: UIView?
        public let sourceRect: CGRect
        public let sourceImage: UIImage?
        public let transitionOut: (Bool?) -> (UIView, CGRect)?
    
        public init(
            sourceView: UIView,
            sourceRect: CGRect,
            sourceImage: UIImage?,
            transitionOut: @escaping (Bool?) -> (UIView, CGRect)?
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
    
    private let postingAvailabilityPromise = Promise<StoriesUploadAvailability>()
    private var postingAvailabilityDisposable: Disposable?
    
    private let hapticFeedback = HapticFeedback()
    
    private var validLayout: ContainerViewLayout?
    
    fileprivate var camera: Camera? {
        return self.node.camera
    }
    
    fileprivate var cameraState: CameraState {
        return self.node.cameraState
    }
    
    fileprivate func updateCameraState(_ f: (CameraState) -> CameraState, transition: Transition) {
        self.node.cameraState = f(self.node.cameraState)
        self.node.requestUpdateLayout(hasAppeared: self.node.hasAppeared, transition: transition)
    }
    
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
        
        self.postingAvailabilityPromise.set(self.context.engine.messages.checkStoriesUploadAvailability())
    }

    required public init(coder: NSCoder) {
        preconditionFailure()
    }
    
    deinit {
        self.audioSessionDisposable?.dispose()
        self.postingAvailabilityDisposable?.dispose()
        if #available(iOS 13.0, *) {
            try? AVAudioSession.sharedInstance().setAllowHapticsAndSystemSoundsDuringRecording(false)
        }
    }

    override public func loadDisplayNode() {
        self.displayNode = Node(controller: self)

        super.displayNodeDidLoad()
        
        self.node.didAppear = { [weak self] in
            guard let self else {
                return
            }
            self.postingAvailabilityDisposable = (self.postingAvailabilityPromise.get()
            |> deliverOnMainQueue).start(next: { [weak self] availability in
                guard let self, availability != .available else {
                    return
                }
                self.node.postingAvailable = false
                
                let subject: PremiumLimitSubject
                switch availability {
                case .expiringLimit:
                    subject = .expiringStories
                case .weeklyLimit:
                    subject = .storiesWeekly
                case .monthlyLimit:
                    subject = .storiesMonthly
                default:
                    subject = .expiringStories
                }
                
                let context = self.context
                var replaceImpl: ((ViewController) -> Void)?
                let controller = self.context.sharedContext.makePremiumLimitController(context: self.context, subject: subject, count: 10, forceDark: true, cancel: { [weak self] in
                    self?.requestDismiss(animated: true)
                }, action: { [weak self] in
                    let controller = context.sharedContext.makePremiumIntroController(context: context, source: .stories, forceDark: true, dismissed: { [weak self] in
                        guard let self else {
                            return
                        }
                        let _ = (self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: self.context.account.peerId))
                        |> deliverOnMainQueue).start(next: { [weak self] peer in
                            guard let self else {
                                return
                            }
                            let isPremium = peer?.isPremium ?? false
                            if isPremium {
                                self.node.postingAvailable = true
                            } else {
                                self.requestDismiss(animated: true)
                            }
                        })
                    })
                    replaceImpl?(controller)
                })
                replaceImpl = { [weak controller] c in
                    controller?.replace(with: c)
                }
                if let navigationController = self.context.sharedContext.mainWindow?.viewController as? NavigationController {
                    navigationController.pushViewController(controller)
                }
            })
        }
    }
    
    private func requestAudioSession() {
        self.audioSessionDisposable = self.context.sharedContext.mediaManager.audioSession.push(audioSessionType: .recordWithOthers, activate: { _ in
            if #available(iOS 13.0, *) {
                try? AVAudioSession.sharedInstance().setAllowHapticsAndSystemSoundsDuringRecording(true)
            }
        }, deactivate: { _ in
            return .single(Void())
        })
    }
    
    private var galleryController: ViewController?
    public func returnFromEditor() {
        self.node.animateInFromEditor(toGallery: self.galleryController?.displayNode.supernode != nil)
    }
    
    private var didStopCameraCapture = false
    func presentGallery(fromGesture: Bool = false) {
        if !fromGesture {
            self.hapticFeedback.impact(.light)
        }
        
        self.node.dismissAllTooltips()
        
        self.node.hasGallery = true
        
        self.didStopCameraCapture = false
        let stopCameraCapture = { [weak self] in
            guard let self, !self.didStopCameraCapture else {
                return
            }
            let currentTimestamp = CACurrentMediaTime()
            if let startTimestamp = self.node.captureStartTimestamp {
                let difference = currentTimestamp - startTimestamp
                if difference < 2.0 {
                    Queue.mainQueue().after(2.0 - difference) {
                        self.didStopCameraCapture = true
                        self.node.pauseCameraCapture()
                    }
                } else {
                    self.didStopCameraCapture = true
                    self.node.pauseCameraCapture()
                }
            }
        }
        
        let resumeCameraCapture = { [weak self] in
            guard let self, self.didStopCameraCapture else {
                return
            }
            self.didStopCameraCapture = false
            self.node.resumeCameraCapture()
        }
        
        let controller: ViewController
        if let current = self.galleryController {
            controller = current
        } else {
            controller = self.context.sharedContext.makeStoryMediaPickerScreen(context: self.context, getSourceRect: { [weak self] in
                if let self {
                    if let galleryButton = self.node.componentHost.findTaggedView(tag: galleryButtonTag) {
                        return galleryButton.convert(galleryButton.bounds, to: self.view).offsetBy(dx: 0.0, dy: -15.0)
                    } else {
                        return .zero
                    }
                } else {
                    return .zero
                }
            }, completion: { [weak self] result, transitionView, transitionRect, transitionImage, transitionOut, dismissed in
                if let self {
                    stopCameraCapture()
                    
                    let resultTransition = ResultTransition(
                        sourceView: transitionView,
                        sourceRect: transitionRect,
                        sourceImage: transitionImage,
                        transitionOut: transitionOut
                    )
                    if let asset = result as? PHAsset {
                        if asset.mediaType == .video && asset.duration < 1.0 {
                            let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
                            let alertController = textAlertController(
                                context: self.context,
                                forceTheme: defaultDarkColorPresentationTheme,
                                title: nil,
                                text: presentationData.strings.Story_Editor_VideoTooShort,
                                actions: [
                                    TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})
                                ],
                                actionLayout: .vertical
                            )
                            self.present(alertController, in: .window(.root))
                        } else {
                            self.completion(.single(.asset(asset)), resultTransition, dismissed)
                        }
                    } else if let draft = result as? MediaEditorDraft {
                        self.completion(.single(.draft(draft)), resultTransition, dismissed)
                    }
                }
            }, dismissed: { [weak self] in
                resumeCameraCapture()
                if let self {
                    self.node.hasGallery = false
                    self.node.requestUpdateLayout(hasAppeared: self.node.hasAppeared, transition: .immediate)
                }
            }, groupsPresented: {
                stopCameraCapture()
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
        
        self.requestLayout(transition: .immediate)
    }
    
    public func presentDraftTooltip() {
        self.node.presentDraftTooltip()
    }

    private var isDismissed = false
    fileprivate func requestDismiss(animated: Bool, interactive: Bool = false) {
        guard !self.isDismissed else {
            return
        }
        
        self.node.dismissAllTooltips()
        
        if !interactive {
            self.hapticFeedback.impact(.light)
        }
        
        self.node.camera?.stopCapture(invalidate: true)
        self.isDismissed = true
        if animated {
            if let layout = self.validLayout, layout.metrics.isTablet {
                self.statusBar.updateStatusBarStyle(.Ignore, animated: true)
                self.node.animateOut(completion: {
                    self.dismiss(animated: false)
                })
            } else {
                self.statusBar.updateStatusBarStyle(.Ignore, animated: true)
                if !interactive {
                    if let navigationController = self.navigationController as? NavigationController {
                        navigationController.updateRootContainerTransitionOffset(self.node.frame.width, transition: .immediate)
                    }
                }
                self.updateTransitionProgress(0.0, transition: .animated(duration: 0.4, curve: .spring), completion: { [weak self] in
                    self?.dismiss(animated: false)
                })
            }
        } else {
            self.dismiss(animated: false)
        }
    }
        
    public func updateTransitionProgress(_ transitionFraction: CGFloat, transition: ContainedViewLayoutTransition, completion: @escaping () -> Void = {}) {
        if let layout = self.validLayout, layout.metrics.isTablet {
            return
        }
        
        if self.node.hasAppeared {
            self.node.dismissAllTooltips()
        }
        
        let transitionFraction = max(0.0, min(1.0, transitionFraction))
        let offsetX = floorToScreenPixels((1.0 - transitionFraction) * self.node.frame.width * -1.0)
        transition.updateTransform(layer: self.node.backgroundView.layer, transform: CGAffineTransform(translationX: offsetX, y: 0.0))
        
        let scale: CGFloat = max(0.8, min(1.0, 0.8 + 0.2 * transitionFraction))
        if !self.node.hasGallery {
            transition.updateTransform(layer: self.node.containerView.layer, transform: CGAffineTransform(translationX: offsetX, y: 0.0))
            transition.updateSublayerTransformScaleAndOffset(layer: self.node.containerView.layer, scale: scale, offset: CGPoint(x: -offsetX * 1.0 / scale * 0.5, y: 0.0), completion: { _ in
                completion()
            })
        } else {
            completion()
        }
        
        let dimAlpha = 0.6 * (1.0 - transitionFraction)
        transition.updateAlpha(layer: self.node.transitionDimView.layer, alpha: dimAlpha)
        transition.updateTransform(layer: self.node.transitionCornersView.layer, transform: CGAffineTransform(translationX: offsetX, y: 0.0))
        
        let sublayerOffsetX = offsetX * 1.0 / scale * 0.5
        self.window?.forEachController({ controller in
            if let controller = controller as? TooltipScreen {
                controller.view.layer.sublayerTransform = CATransform3DMakeTranslation(sublayerOffsetX, 0.0, 0.0)
            }
        })
        self.forEachController({ controller in
            if let controller = controller as? TooltipScreen {
                controller.view.layer.sublayerTransform = CATransform3DMakeTranslation(sublayerOffsetX, 0.0, 0.0)
            }
            return true
        })
                
        if let navigationController = self.navigationController as? NavigationController {
            let offsetX = floorToScreenPixels(transitionFraction * self.node.frame.width)
            navigationController.updateRootContainerTransitionOffset(offsetX, transition: transition)
        }
    }
    
    public func completeWithTransitionProgress(_ transitionFraction: CGFloat, velocity: CGFloat, dismissing: Bool) {
        if let layout = self.validLayout, layout.metrics.isTablet {
            return
        }
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
        self.validLayout = layout
        
        super.containerLayoutUpdated(layout, transition: transition)

        if !self.isDismissed {
            (self.displayNode as! Node).containerLayoutUpdated(layout: layout, transition: Transition(transition))
        }
    }
}

private final class DualIconComponent: Component {
    typealias EnvironmentType = Empty
    
    let isSelected: Bool
    
    init(
        isSelected: Bool
    ) {
        self.isSelected = isSelected
    }
    
    static func ==(lhs: DualIconComponent, rhs: DualIconComponent) -> Bool {
        if lhs.isSelected != rhs.isSelected {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let iconView = UIImageView()
                
        private var component: DualIconComponent?
        private weak var state: EmptyComponentState?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
         
            let image = generateImage(CGSize(width: 36.0, height: 36.0), rotatedContext: { size, context in
                context.clear(CGRect(origin: .zero, size: size))
                
                if let image = UIImage(bundleImageName: "Camera/DualIcon"), let cgImage = image.cgImage {
                    context.draw(cgImage, in: CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - image.size.width) / 2.0), y: floorToScreenPixels((size.height - image.size.height) / 2.0) - 1.0), size: image.size))
                }
            })
            
            let selectedImage = generateImage(CGSize(width: 36.0, height: 36.0), rotatedContext: { size, context in
                context.clear(CGRect(origin: .zero, size: size))
                context.setFillColor(UIColor.white.cgColor)
                context.fillEllipse(in: CGRect(origin: .zero, size: size))
                
                if let image = UIImage(bundleImageName: "Camera/DualIcon"), let cgImage = image.cgImage {
                    context.setBlendMode(.clear)
                    context.clip(to: CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - image.size.width) / 2.0), y: floorToScreenPixels((size.height - image.size.height) / 2.0) - 1.0), size: image.size), mask: cgImage)
                    context.fill(CGRect(origin: .zero, size: size))
                }
            })
            
            self.iconView.image = image
            self.iconView.highlightedImage = selectedImage
            
            self.iconView.layer.shadowOffset = CGSize(width: 0.0, height: 0.0)
            self.iconView.layer.shadowRadius = 3.0
            self.iconView.layer.shadowColor = UIColor.black.cgColor
            self.iconView.layer.shadowOpacity = 0.25
            
            self.addSubview(self.iconView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
                
        func update(component: DualIconComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
            self.component = component
            self.state = state
                        
            let size = CGSize(width: 36.0, height: 36.0)
            self.iconView.frame = CGRect(origin: .zero, size: size)
            self.iconView.isHighlighted = component.isSelected
            
            return size
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: State, environment: Environment<EnvironmentType>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private func pipPositionForLocation(layout: ContainerViewLayout, position: CGPoint, velocity: CGPoint) -> CameraScreen.PIPPosition {
    var layoutInsets = layout.insets(options: [.input])
    layoutInsets.bottom += 48.0
    var result = CGPoint()
    if position.x < layout.size.width / 2.0 {
        result.x = 0.0
    } else {
        result.x = 1.0
    }
    if position.y < layoutInsets.top + (layout.size.height - layoutInsets.bottom - layoutInsets.top) / 2.0 {
        result.y = 0.0
    } else {
        result.y = 1.0
    }
    
    let currentPosition = result
    
    let angleEpsilon: CGFloat = 30.0
    var shouldHide = false
    
    if (velocity.x * velocity.x + velocity.y * velocity.y) >= 500.0 * 500.0 {
        let x = velocity.x
        let y = velocity.y
        
        var angle = atan2(y, x) * 180.0 / CGFloat.pi * -1.0
        if angle < 0.0 {
            angle += 360.0
        }
        
        if currentPosition.x.isZero && currentPosition.y.isZero {
            if ((angle > 0 && angle < 90 - angleEpsilon) || angle > 360 - angleEpsilon) {
                result.x = 1.0
                result.y = 0.0
            } else if (angle > 180 + angleEpsilon && angle < 270 + angleEpsilon) {
                result.x = 0.0
                result.y = 1.0
            } else if (angle > 270 + angleEpsilon && angle < 360 - angleEpsilon) {
                result.x = 1.0
                result.y = 1.0
            } else {
                shouldHide = true
            }
        } else if !currentPosition.x.isZero && currentPosition.y.isZero {
            if (angle > 90 + angleEpsilon && angle < 180 + angleEpsilon) {
                result.x = 0.0
                result.y = 0.0
            }
            else if (angle > 270 - angleEpsilon && angle < 360 - angleEpsilon) {
                result.x = 1.0
                result.y = 1.0
            }
            else if (angle > 180 + angleEpsilon && angle < 270 - angleEpsilon) {
                result.x = 0.0
                result.y = 1.0
            }
            else {
                shouldHide = true
            }
        } else if currentPosition.x.isZero && !currentPosition.y.isZero {
            if (angle > 90 - angleEpsilon && angle < 180 - angleEpsilon) {
                result.x = 0.0
                result.y = 0.0
            }
            else if (angle < angleEpsilon || angle > 270 + angleEpsilon) {
                result.x = 1.0
                result.y = 1.0
            }
            else if (angle > angleEpsilon && angle < 90 - angleEpsilon) {
                result.x = 1.0
                result.y = 0.0
            }
            else if (!shouldHide) {
                shouldHide = true
            }
        } else if !currentPosition.x.isZero && !currentPosition.y.isZero {
            if (angle > angleEpsilon && angle < 90 + angleEpsilon) {
                result.x = 1.0
                result.y = 0.0
            }
            else if (angle > 180 - angleEpsilon && angle < 270 - angleEpsilon) {
                result.x = 0.0
                result.y = 1.0
            }
            else if (angle > 90 + angleEpsilon && angle < 180 - angleEpsilon) {
                result.x = 0.0
                result.y = 0.0
            }
            else if (!shouldHide) {
                shouldHide = true
            }
        }
    }
    
    var position: CameraScreen.PIPPosition = .topRight
    if result.x == 0.0 && result.y == 0.0 {
        position = .topLeft
    } else if result.x == 1.0 && result.y == 0.0 {
        position = .topRight
    } else if result.x == 0.0 && result.y == 1.0 {
        position = .bottomLeft
    } else if result.x == 1.0 && result.y == 1.0 {
        position = .bottomRight
    }
    return position
}
