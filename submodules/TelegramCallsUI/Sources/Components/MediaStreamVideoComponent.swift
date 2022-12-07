import Foundation
import UIKit
import ComponentFlow
import ActivityIndicatorComponent
import AccountContext
import AVKit
import MultilineTextComponent
import Display
import ShimmerEffect

import TelegramCore
typealias MediaStreamVideoComponent = _MediaStreamVideoComponent

class CustomIntensityVisualEffectView: UIVisualEffectView {

    /// Create visual effect view with given effect and its intensity
    ///
    /// - Parameters:
    ///   - effect: visual effect, eg UIBlurEffect(style: .dark)
    ///   - intensity: custom intensity from 0.0 (no effect) to 1.0 (full effect) using linear scale
    init(effect: UIVisualEffect, intensity: CGFloat) {
        super.init(effect: nil)
        animator = UIViewPropertyAnimator(duration: 1, curve: .linear) { [unowned self] in self.effect = effect }
        animator.fractionComplete = intensity
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError()
    }

    // MARK: Private
    private var animator: UIViewPropertyAnimator!

}

final class _MediaStreamVideoComponent: Component {
    let call: PresentationGroupCallImpl
    let hasVideo: Bool
    let isVisible: Bool
    let isAdmin: Bool
    let peerTitle: String
    let activatePictureInPicture: ActionSlot<Action<Void>>
    let deactivatePictureInPicture: ActionSlot<Void>
    let bringBackControllerForPictureInPictureDeactivation: (@escaping () -> Void) -> Void
    let pictureInPictureClosed: () -> Void
    let peerImage: Any?
    let isFullscreen: Bool
    let onVideoSizeRetrieved: (CGSize) -> Void
    let videoLoading: Bool
    init(
        call: PresentationGroupCallImpl,
        hasVideo: Bool,
        isVisible: Bool,
        isAdmin: Bool,
        peerTitle: String,
        peerImage: Any?,
        isFullscreen: Bool,
        videoLoading: Bool,
        activatePictureInPicture: ActionSlot<Action<Void>>,
        deactivatePictureInPicture: ActionSlot<Void>,
        bringBackControllerForPictureInPictureDeactivation: @escaping (@escaping () -> Void) -> Void,
        pictureInPictureClosed: @escaping () -> Void,
        onVideoSizeRetrieved: @escaping (CGSize) -> Void
    ) {
        self.call = call
        self.hasVideo = hasVideo
        self.isVisible = isVisible
        self.isAdmin = isAdmin
        self.peerTitle = peerTitle
        self.videoLoading = videoLoading
        self.activatePictureInPicture = activatePictureInPicture
        self.deactivatePictureInPicture = deactivatePictureInPicture
        self.bringBackControllerForPictureInPictureDeactivation = bringBackControllerForPictureInPictureDeactivation
        self.pictureInPictureClosed = pictureInPictureClosed
        
        self.peerImage = peerImage
        self.isFullscreen = isFullscreen
        self.onVideoSizeRetrieved = onVideoSizeRetrieved
    }
    
    public static func ==(lhs: _MediaStreamVideoComponent, rhs: _MediaStreamVideoComponent) -> Bool {
        if lhs.call !== rhs.call {
            return false
        }
        if lhs.hasVideo != rhs.hasVideo {
            return false
        }
        if lhs.isVisible != rhs.isVisible {
            return false
        }
        if lhs.isAdmin != rhs.isAdmin {
            return false
        }
        if lhs.peerTitle != rhs.peerTitle {
            return false
        }
        
        if lhs.isFullscreen != rhs.isFullscreen {
            return false
        }
        
        return true
    }
    
    public final class State: ComponentState {
        override init() {
            super.init()
        }
    }
    
    public func makeState() -> State {
        return State()
    }
    
    public final class View: UIView, AVPictureInPictureControllerDelegate, ComponentTaggedView {
        public final class Tag {
        }
        
        private let videoRenderingContext = VideoRenderingContext()
        private let blurTintView: UIView
        private var videoBlurView: VideoRenderingView?
        private var videoView: VideoRenderingView?
        private var activityIndicatorView: ComponentHostView<Empty>?
        private var loadingView: ComponentHostView<Empty>?
        
        private var videoPlaceholderView: UIView?
        private var noSignalView: ComponentHostView<Empty>?
        private let loadingBlurView = CustomIntensityVisualEffectView(effect: UIBlurEffect(style: .light), intensity: 0.4)
        private let shimmerOverlayView = CALayer()
        private var pictureInPictureController: AVPictureInPictureController?
        
        private var component: _MediaStreamVideoComponent?
        private var hadVideo: Bool = false
        
        private var requestedExpansion: Bool = false
        
        private var noSignalTimer: Timer?
        private var noSignalTimeout: Bool = false
        
        private weak var state: State?
        
        override init(frame: CGRect) {
            self.blurTintView = UIView()
            self.blurTintView.backgroundColor = UIColor(white: 0.0, alpha: 0.55)
            super.init(frame: frame)
            
            self.isUserInteractionEnabled = false
            self.clipsToBounds = true
            
            self.addSubview(self.blurTintView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        public func matches(tag: Any) -> Bool {
            if let _ = tag as? Tag {
                return true
            }
            return false
        }
        
        func expandFromPictureInPicture() {
            if let pictureInPictureController = self.pictureInPictureController, pictureInPictureController.isPictureInPictureActive {
                self.requestedExpansion = true
                self.pictureInPictureController?.stopPictureInPicture()
            }
        }
        let maskGradientLayer = CAGradientLayer()
        private var wasVisible = true
        let shimmer = StandaloneShimmerEffect()
        let borderShimmer = StandaloneShimmerEffect()
        let shimmerOverlayLayer = CALayer()
        let shimmerBorderLayer = CALayer()
        let placeholderView = UIImageView()
        
        func update(component: _MediaStreamVideoComponent, availableSize: CGSize, state: State, transition: Transition) -> CGSize {
            self.state = state
//            placeholderView.alpha = 0.7
//            placeholderView.image = lastFrame[component.call.peerId.id.description]
            if let frame = lastFrame[component.call.peerId.id.description] {
                placeholderView.subviews.forEach { $0.removeFromSuperview() }
                placeholderView.addSubview(frame)
                frame.frame = placeholderView.bounds
//                placeholderView.backgroundColor = .green
            } else {
//                placeholderView.subviews.forEach { $0.removeFromSuperview() }
//                placeholderView.backgroundColor = .red
            }
            placeholderView.backgroundColor = .red
            if component.videoLoading {
                if placeholderView.superview == nil {
                    addSubview(placeholderView)
                }
                if loadingBlurView.superview == nil {
                    addSubview(loadingBlurView)
                }
                if shimmerOverlayLayer.superlayer == nil {
                    loadingBlurView.layer.addSublayer(shimmerOverlayLayer)
                    loadingBlurView.layer.addSublayer(shimmerBorderLayer)
                }
                loadingBlurView.clipsToBounds = true
                shimmer.layer = shimmerOverlayLayer
                shimmerOverlayView.compositingFilter = "softLightBlendMode"
                shimmer.testUpdate(background: .clear, foreground: .white.withAlphaComponent(0.4))
                loadingBlurView.layer.cornerRadius = 10
                shimmerOverlayLayer.opacity = 0.6
                
                shimmerBorderLayer.cornerRadius = 10
                shimmerBorderLayer.masksToBounds = true
                shimmerBorderLayer.compositingFilter = "softLightBlendMode"
                shimmerBorderLayer.borderWidth = 2
                shimmerBorderLayer.borderColor = UIColor.white.cgColor
                
                let borderMask = CALayer()
                shimmerBorderLayer.mask = borderMask
                borderShimmer.layer = borderMask
                borderShimmer.testUpdate(background: .clear, foreground: .white)
                loadingBlurView.alpha = 1
            } else {
                UIView.animate(withDuration: 0.2, animations: {
                    self.loadingBlurView.alpha = 0
                }, completion: { _ in
                    self.loadingBlurView.removeFromSuperview()
                })
                placeholderView.removeFromSuperview()
            }
            
            if component.hasVideo, self.videoView == nil {
                if let input = component.call.video(endpointId: "unified") {
                    if let videoBlurView = self.videoRenderingContext.makeView(input: input, blur: true) {
                        self.videoBlurView = videoBlurView
                        self.insertSubview(videoBlurView, belowSubview: self.blurTintView)
                        videoBlurView.alpha = 0
                        UIView.animate(withDuration: 0.3) {
                            videoBlurView.alpha = 1
                        }
                        
                        self.maskGradientLayer.type = .radial
                        self.maskGradientLayer.colors = [UIColor(rgb: 0x000000, alpha: 0.5).cgColor, UIColor(rgb: 0xffffff, alpha: 0.0).cgColor]
                        self.maskGradientLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
                        self.maskGradientLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
                    }

                    if let videoView = self.videoRenderingContext.makeView(input: input, blur: false, forceSampleBufferDisplayLayer: true) {
                        self.videoView = videoView
                        self.addSubview(videoView)
                        videoView.alpha = 0
                        UIView.animate(withDuration: 0.3) {
                            videoView.alpha = 1
                        }
                        if let sampleBufferVideoView = videoView as? SampleBufferVideoRenderingView {
                            sampleBufferVideoView.sampleBufferLayer.masksToBounds = true
                            sampleBufferVideoView.sampleBufferLayer.cornerRadius = 20
                            
                            if #available(iOS 13.0, *) {
                                sampleBufferVideoView.sampleBufferLayer.preventsDisplaySleepDuringVideoPlayback = true
                            }
//                            if #available(iOSApplicationExtension 15.0, iOS 15.0, *), AVPictureInPictureController.isPictureInPictureSupported() {
                                final class PlaybackDelegateImpl: NSObject, AVPictureInPictureSampleBufferPlaybackDelegate {
                                    var onTransitionFinished: (() -> Void)?
                                    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, setPlaying playing: Bool) {
                                        
                                    }

                                    func pictureInPictureControllerTimeRangeForPlayback(_ pictureInPictureController: AVPictureInPictureController) -> CMTimeRange {
                                        return CMTimeRange(start: .zero, duration: .positiveInfinity)
                                    }

                                    func pictureInPictureControllerIsPlaybackPaused(_ pictureInPictureController: AVPictureInPictureController) -> Bool {
                                        return false
                                    }

                                    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, didTransitionToRenderSize newRenderSize: CMVideoDimensions) {
                                        onTransitionFinished?()
                                        print("pip finished")
                                    }

                                    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, skipByInterval skipInterval: CMTime, completion completionHandler: @escaping () -> Void) {
                                        completionHandler()
                                    }

                                    public func pictureInPictureControllerShouldProhibitBackgroundAudioPlayback(_ pictureInPictureController: AVPictureInPictureController) -> Bool {
                                        return false
                                    }
                                }
                            var pictureInPictureController: AVPictureInPictureController? = nil
                            if #available(iOS 15.0, *) {
                                pictureInPictureController = AVPictureInPictureController(contentSource: AVPictureInPictureController.ContentSource(sampleBufferDisplayLayer: sampleBufferVideoView.sampleBufferLayer, playbackDelegate: {
                                    let delegate = PlaybackDelegateImpl()
                                    delegate.onTransitionFinished = { [weak self] in
                                        if self?.videoView?.alpha == 0 {
//                                            self?.videoView?.alpha = 1
                                        }
                                    }
                                    return delegate
                                }()))
                                pictureInPictureController?.playerLayer.masksToBounds = false
                                pictureInPictureController?.playerLayer.cornerRadius = 30
                            } else if AVPictureInPictureController.isPictureInPictureSupported() {
                                // TODO: support PiP for iOS < 15.0
                                // sampleBufferVideoView.sampleBufferLayer
                                pictureInPictureController = AVPictureInPictureController.init(playerLayer: AVPlayerLayer(player: AVPlayer()))
                            }
                                
                                pictureInPictureController?.delegate = self
                            if #available(iOS 14.2, *) {
                                pictureInPictureController?.canStartPictureInPictureAutomaticallyFromInline = true
                            }
                            if #available(iOS 14.0, *) {
                                pictureInPictureController?.requiresLinearPlayback = true
                            }
                                
                                self.pictureInPictureController = pictureInPictureController
//                            }
                        }
                        
                        videoView.setOnOrientationUpdated { [weak state] _, _ in
                            state?.updated(transition: .immediate)
                        }
                        videoView.setOnFirstFrameReceived { [weak self, weak state] _ in
                            guard let strongSelf = self else {
                                return
                            }
                            
                            strongSelf.hadVideo = true
                            
                            strongSelf.activityIndicatorView?.removeFromSuperview()
                            strongSelf.activityIndicatorView = nil
                            
                            strongSelf.noSignalTimer?.invalidate()
                            strongSelf.noSignalTimer = nil
                            strongSelf.noSignalTimeout = false
                            strongSelf.noSignalView?.removeFromSuperview()
                            strongSelf.noSignalView = nil
                            
                            let snapshot = strongSelf.videoView?.snapshotView(afterScreenUpdates: true)
                            strongSelf.addSubview(snapshot ?? UIVisualEffectView(effect: UIBlurEffect(style: .dark)))
                            state?.updated(transition: .immediate)
                        }
                    }
                }
            }
            
//            sheetView.frame = .init(x: 0, y: sheetTop, width: availableSize.width, height: sheetHeight)
           // var aspect = videoView.getAspect()
//                if aspect <= 0.01 {
            // let aspect = !component.isFullscreen ? 16.0 / 9.0 : // 3.0 / 4.0
//                }
            
            let videoInset: CGFloat
            if !component.isFullscreen {
                videoInset = 16
            } else {
                videoInset = 0
            }
            
            if let videoView = self.videoView {
                // TODO: REMOVE FROM HERE and move to call end (or at least to background)
//                if let presentation = videoView.snapshotView(afterScreenUpdates: false) {
                if videoView.bounds.size.width > 0, let snapshot = videoView.snapshotView(afterScreenUpdates: false) ?? videoView.snapshotView(afterScreenUpdates: true) {
                    lastFrame[component.call.peerId.id.description] = snapshot// ()!
                }
//                }
                var aspect = videoView.getAspect()
                // saveAspect(aspect)
                if component.isFullscreen {
                    if aspect <= 0.01 {
                        aspect = 3.0 / 4.0
                    }
                } else {
                    aspect = 16.0 / 9
                }
                
                let videoSize = CGSize(width: aspect * 100.0, height: 100.0).aspectFitted(.init(width: availableSize.width - videoInset * 2, height: availableSize.height))
                let blurredVideoSize = videoSize.aspectFilled(availableSize)
                
                component.onVideoSizeRetrieved(videoSize)
                
                var isVideoVisible = component.isVisible
                
                if !wasVisible && component.isVisible {
                    videoView.layer.animateAlpha(from: 0, to: 1, duration: 0.2)
                } else if wasVisible && !component.isVisible {
                    videoView.layer.animateAlpha(from: 1, to: 0, duration: 0.2)
                }
                
                if let pictureInPictureController = self.pictureInPictureController {
                    if pictureInPictureController.isPictureInPictureActive {
                        isVideoVisible = true
                    }
                }
                
                videoView.updateIsEnabled(isVideoVisible)
                videoView.clipsToBounds = true
                videoView.layer.cornerRadius = component.isFullscreen ? 0 : 10
              //  var aspect = videoView.getAspect()
//                if aspect <= 0.01 {
                // TODO: remove debug
//                if component.videoLoading {
//                    videoView.alpha = 0.5
//                } else {
//                    videoView.alpha = 1
//                }
                
                transition.withAnimation(.none).setFrame(view: videoView, frame: CGRect(origin: CGPoint(x: floor((availableSize.width - videoSize.width) / 2.0), y: floor((availableSize.height - videoSize.height) / 2.0)), size: videoSize), completion: nil)
                
                if let videoBlurView = self.videoBlurView {
                    videoBlurView.updateIsEnabled(component.isVisible)
//                    videoBlurView.isHidden = component.isFullscreen
                    if component.isFullscreen {
                        transition.withAnimation(.none).setFrame(view: videoBlurView, frame: CGRect(origin: CGPoint(x: floor((availableSize.width - blurredVideoSize.width) / 2.0), y: floor((availableSize.height - blurredVideoSize.height) / 2.0)), size: blurredVideoSize), completion: nil)
                    } else {
                        videoBlurView.frame = videoView.frame.insetBy(dx: -69 * aspect, dy: -69)
                    }
                    
                    if !component.isFullscreen {
                        videoBlurView.layer.mask = maskGradientLayer
                    } else {
                        videoBlurView.layer.mask = nil
                    }
                    
                    self.maskGradientLayer.frame = videoBlurView.bounds
                }
            }
            
            let videoSize = CGSize(width: 16 / 9 * 100.0, height: 100.0).aspectFitted(.init(width: availableSize.width - videoInset * 2, height: availableSize.height))
            loadingBlurView.frame = CGRect(origin: CGPoint(x: floor((availableSize.width - videoSize.width) / 2.0), y: floor((availableSize.height - videoSize.height) / 2.0)), size: videoSize)
            loadingBlurView.layer.cornerRadius = 10
            
            placeholderView.frame = loadingBlurView.frame
            placeholderView.layer.cornerRadius = 10
            placeholderView.clipsToBounds = true
            
            shimmerOverlayLayer.frame = loadingBlurView.bounds
            shimmerBorderLayer.frame = loadingBlurView.bounds
            shimmerBorderLayer.mask?.frame = loadingBlurView.bounds
            if component.isFullscreen {
                loadingBlurView.removeFromSuperview()
            }
            if !self.hadVideo {
                // TODO: hide fullscreen button without video
                let aspect: CGFloat = 16.0 / 9
                let videoSize = CGSize(width: aspect * 100.0, height: 100.0).aspectFitted(.init(width: availableSize.width - videoInset * 2, height: availableSize.height))
                // loadingpreview.frame = .init(, videoSize)
                print(videoSize)
                // TODO: remove activity indicator
                var activityIndicatorTransition = transition
                let activityIndicatorView: ComponentHostView<Empty>
                if let current = self.activityIndicatorView {
                    activityIndicatorView = current
                } else {
                    activityIndicatorTransition = transition.withAnimation(.none)
                    activityIndicatorView = ComponentHostView<Empty>()
                    self.activityIndicatorView = activityIndicatorView
//                    self.addSubview(activityIndicatorView)
                }
                
                let activityIndicatorSize = activityIndicatorView.update(
                    transition: transition,
                    component: AnyComponent(ActivityIndicatorComponent(color: .white)),
                    environment: {},
                    containerSize: CGSize(width: 100.0, height: 100.0)
                )
                let activityIndicatorFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - activityIndicatorSize.width) / 2.0), y: floor((availableSize.height - activityIndicatorSize.height) / 2.0)), size: activityIndicatorSize)
                activityIndicatorTransition.setFrame(view: activityIndicatorView, frame: activityIndicatorFrame, completion: nil)
                
                if self.noSignalTimer == nil {
                    if #available(iOS 10.0, *) {
                        let noSignalTimer = Timer(timeInterval: 20.0, repeats: false, block: { [weak self] _ in
                            guard let strongSelf = self else {
                                return
                            }
                            strongSelf.noSignalTimeout = true
                            strongSelf.state?.updated(transition: .immediate)
                        })
                        self.noSignalTimer = noSignalTimer
                        RunLoop.main.add(noSignalTimer, forMode: .common)
                    }
                }
                
                if self.noSignalTimeout {
                    var noSignalTransition = transition
                    let noSignalView: ComponentHostView<Empty>
                    if let current = self.noSignalView {
                        noSignalView = current
                    } else {
                        noSignalTransition = transition.withAnimation(.none)
                        noSignalView = ComponentHostView<Empty>()
                        self.noSignalView = noSignalView
                        self.addSubview(noSignalView)
                        noSignalView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
                    }
                    
                    let presentationData = component.call.accountContext.sharedContext.currentPresentationData.with { $0 }
                    let noSignalSize = noSignalView.update(
                        transition: transition,
                        component: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(string: component.isAdmin ? presentationData.strings.LiveStream_NoSignalAdminText :  presentationData.strings.LiveStream_NoSignalUserText(component.peerTitle).string, font: Font.regular(16.0), textColor: .white, paragraphAlignment: .center)),
                            horizontalAlignment: .center,
                            maximumNumberOfLines: 0
                        )),
                        environment: {},
                        containerSize: CGSize(width: availableSize.width - 16.0 * 2.0, height: 1000.0)
                    )
                    noSignalTransition.setFrame(view: noSignalView, frame: CGRect(origin: CGPoint(x: floor((availableSize.width - noSignalSize.width) / 2.0), y: activityIndicatorFrame.maxY + 24.0), size: noSignalSize), completion: nil)
                }
            }
            
            self.component = component
            
            component.activatePictureInPicture.connect { [weak self] completion in
                guard let strongSelf = self, let pictureInPictureController = strongSelf.pictureInPictureController else {
                    return
                }
                
                pictureInPictureController.startPictureInPicture()
                
                completion(Void())
            }
            
            component.deactivatePictureInPicture.connect { [weak self] _ in
                guard let strongSelf = self else {
                    return
                }
                
                strongSelf.expandFromPictureInPicture()
            }
            
            return availableSize
        }
        
        func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
            // Fading to make
            let presentation = self.videoView!.snapshotView(afterScreenUpdates: false)! // (self.videoView?.layer.presentation())!
            self.addSubview(presentation)
            presentation.frame = self.videoView!.frame
//            let image = UIGraphicsImageRenderer(size: presentation.bounds.size).image { context in
//                presentation.render(in: context.cgContext)
//            }
//            print(image)
            self.videoView?.alpha = 0
//            self.videoView?.alpha = 0.5
//            presentation.animateAlpha(from: 1, to: 0, duration: 0.1, completion: { _ in presentation.removeFromSuperlayer() })
            UIView.animate(withDuration: 0.1, animations: {
                presentation.alpha = 0
            }, completion: { _ in
                presentation.removeFromSuperview()
            })
//            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
//                presentation.removeFromSuperlayer()
//            }
            UIView.animate(withDuration: 0.1) { [self] in
                videoBlurView?.alpha = 0
            }
            // TODO: make safe
            UIApplication.shared.windows.first?/*(where: { $0.layer !== (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.keyWindow?.layer })?*/.layer.cornerRadius = 10// (where: { !($0 is NativeWindow)*/ })
            UIApplication.shared.windows.first?.layer.masksToBounds = true
        }
        
        public func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
            guard let component = self.component else {
                completionHandler(false)
                return
            }

            component.bringBackControllerForPictureInPictureDeactivation {
                completionHandler(true)
            }
        }
        
        func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
            self.state?.updated(transition: .immediate)
        }
        
        func pictureInPictureControllerWillStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
            if self.requestedExpansion {
                self.requestedExpansion = false
            } else {
                self.component?.pictureInPictureClosed()
            }
            // TODO: extract precise animation or observe window changes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.videoView?.alpha = 1
            }
            UIView.animate(withDuration: 0.3) { [self] in
                self.videoBlurView?.alpha = 1
            }
        }
        
        func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
            self.videoView?.alpha = 1
            self.state?.updated(transition: .immediate)
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: State, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, transition: transition)
    }
}

// TODO: move to appropriate place
var lastFrame: [String: UIView] = [:]

extension UIView {
    func snapshot() -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(bounds.size, true, UIScreen.main.scale)

        guard let currentContext = UIGraphicsGetCurrentContext() else {
            UIGraphicsEndImageContext()
            return nil
        }

        layer.render(in: currentContext)

        let image = UIGraphicsGetImageFromCurrentImageContext()

        UIGraphicsEndImageContext()

        return image
    }
}
