import Foundation
import UIKit
import ComponentFlow
import AccountContext
import AVKit
import MultilineTextComponent
import Display
import ShimmerEffect

import TelegramCore
import SwiftSignalKit
import AvatarNode
import Postbox

final class MediaStreamVideoComponent: Component {
    let call: PresentationGroupCallImpl
    let hasVideo: Bool
    let isVisible: Bool
    let isAdmin: Bool
    let peerTitle: String
    let activatePictureInPicture: ActionSlot<Action<Void>>
    let deactivatePictureInPicture: ActionSlot<Void>
    let bringBackControllerForPictureInPictureDeactivation: (@escaping () -> Void) -> Void
    let pictureInPictureClosed: () -> Void
    let isFullscreen: Bool
    let onVideoSizeRetrieved: (CGSize) -> Void
    let videoLoading: Bool
    let callPeer: Peer?
    let onVideoPlaybackLiveChange: (Bool) -> Void
    
    init(
        call: PresentationGroupCallImpl,
        hasVideo: Bool,
        isVisible: Bool,
        isAdmin: Bool,
        peerTitle: String,
        isFullscreen: Bool,
        videoLoading: Bool,
        callPeer: Peer?,
        activatePictureInPicture: ActionSlot<Action<Void>>,
        deactivatePictureInPicture: ActionSlot<Void>,
        bringBackControllerForPictureInPictureDeactivation: @escaping (@escaping () -> Void) -> Void,
        pictureInPictureClosed: @escaping () -> Void,
        onVideoSizeRetrieved: @escaping (CGSize) -> Void,
        onVideoPlaybackLiveChange: @escaping (Bool) -> Void
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
        self.onVideoPlaybackLiveChange = onVideoPlaybackLiveChange
        
        self.callPeer = callPeer
        self.isFullscreen = isFullscreen
        self.onVideoSizeRetrieved = onVideoSizeRetrieved
    }
    
    public static func ==(lhs: MediaStreamVideoComponent, rhs: MediaStreamVideoComponent) -> Bool {
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
        if lhs.videoLoading != rhs.videoLoading {
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
        
        private var videoPlaceholderView: UIView?
        private var noSignalView: ComponentHostView<Empty>?
        private let loadingBlurView = CustomIntensityVisualEffectView(effect: UIBlurEffect(style: .light), intensity: 0.4)
        private let shimmerOverlayView = CALayer()
        private var pictureInPictureController: AVPictureInPictureController?
        
        private var component: MediaStreamVideoComponent?
        private var hadVideo: Bool = false
        
        private var requestedExpansion: Bool = false
        
        private var noSignalTimer: Foundation.Timer?
        private var noSignalTimeout: Bool = false
        
        private let videoBlurGradientMask = CAGradientLayer()
        private let videoBlurSolidMask = CALayer()
        
        private var wasVisible = true
        private var borderShimmer = StandaloneShimmerEffect()
        private let shimmerBorderLayer = CALayer()
        private let placeholderView = UIImageView()
        
        private var videoStalled = false {
            didSet {
                if videoStalled != oldValue {
                    self.updateVideoStalled(isStalled: self.videoStalled, transition: nil)
//                    state?.updated()
                }
            }
        }
        var onVideoPlaybackChange: ((Bool) -> Void) = { _ in }
        
        private var frameInputDisposable: Disposable?
        
        private var stallTimer: Foundation.Timer?
        private let fullScreenBackgroundPlaceholder = UIVisualEffectView(effect: UIBlurEffect(style: .regular))
        
        private var avatarDisposable: Disposable?
        private var didBeginLoadingAvatar = false
        private var timeLastFrameReceived: CFAbsoluteTime?
        
        private var isFullscreen: Bool = false
        private let videoLoadingThrottler = Throttler<Bool>(duration: 1, queue: .main)
        private var wasFullscreen: Bool = false
        private var isAnimating = false
        private var didRequestBringBack = false
        
        private weak var state: State?
        
        private var lastPresentation: UIView?
        private var pipTrackDisplayLink: CADisplayLink?
        
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
        
        deinit {
            avatarDisposable?.dispose()
            frameInputDisposable?.dispose()
            self.pipTrackDisplayLink?.invalidate()
            self.pipTrackDisplayLink = nil
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
        
        private func updateVideoStalled(isStalled: Bool, transition: Transition?) {
            if isStalled {
                guard let component = self.component else { return }
                
                if let frameView = lastFrame[component.call.peerId.id.description] {
                    frameView.removeFromSuperview()
                    placeholderView.subviews.forEach { $0.removeFromSuperview() }
                    placeholderView.addSubview(frameView)
                    frameView.frame = placeholderView.bounds
                }
                
                if !hadVideo && placeholderView.superview == nil {
                    addSubview(placeholderView)
                }
                
                let needsFadeInAnimation = hadVideo
                
                if loadingBlurView.superview == nil {
                    addSubview(loadingBlurView)
                    if needsFadeInAnimation {
                        let anim = CABasicAnimation(keyPath: "opacity")
                        anim.duration = 0.5
                        anim.fromValue = 0
                        anim.toValue = 1
                        loadingBlurView.layer.opacity = 1
                        anim.fillMode = .forwards
                        anim.isRemovedOnCompletion = false
                        loadingBlurView.layer.add(anim, forKey: "opacity")
                    }
                }
                loadingBlurView.layer.zPosition = 998
                self.noSignalView?.layer.zPosition = loadingBlurView.layer.zPosition + 1
                if shimmerBorderLayer.superlayer == nil {
                    loadingBlurView.contentView.layer.addSublayer(shimmerBorderLayer)
                }
                loadingBlurView.clipsToBounds = true
                
                let cornerRadius = loadingBlurView.layer.cornerRadius
                shimmerBorderLayer.cornerRadius = cornerRadius
                shimmerBorderLayer.masksToBounds = true
                shimmerBorderLayer.compositingFilter = "softLightBlendMode"
                
                let borderMask = CAShapeLayer()
                
                shimmerBorderLayer.mask = borderMask
                
                if let transition, shimmerBorderLayer.mask != nil {
                    let initialPath = CGPath(roundedRect: .init(x: 0, y: 0, width: shimmerBorderLayer.bounds.width, height: shimmerBorderLayer.bounds.height), cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
                    borderMask.path = initialPath
                    transition.setFrame(layer: shimmerBorderLayer, frame: loadingBlurView.bounds)
                    
                    let borderMaskPath = CGPath(roundedRect: .init(x: 0, y: 0, width: shimmerBorderLayer.bounds.width, height: shimmerBorderLayer.bounds.height), cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
                    transition.setShapeLayerPath(layer: borderMask, path: borderMaskPath)
                } else {
                    shimmerBorderLayer.frame = loadingBlurView.bounds
                    let borderMaskPath = CGPath(roundedRect: .init(x: 0, y: 0, width: shimmerBorderLayer.bounds.width, height: shimmerBorderLayer.bounds.height), cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
                    borderMask.path = borderMaskPath
                }
                
                borderMask.fillColor = UIColor.white.withAlphaComponent(0.4).cgColor
                borderMask.strokeColor = UIColor.white.withAlphaComponent(0.7).cgColor
                borderMask.lineWidth = 3
                borderMask.compositingFilter = "softLightBlendMode"
                
                borderShimmer = StandaloneShimmerEffect()
                borderShimmer.layer = shimmerBorderLayer
                borderShimmer.updateHorizontal(background: .clear, foreground: .white)
                loadingBlurView.alpha = 1
            } else {
                if hadVideo && !isAnimating && loadingBlurView.layer.opacity == 1 {
                    let anim = CABasicAnimation(keyPath: "opacity")
                    anim.duration = 0.4
                    anim.fromValue = 1.0
                    anim.toValue = 0.0
                    self.loadingBlurView.layer.opacity = 0
                    anim.fillMode = .forwards
                    anim.isRemovedOnCompletion = false
                    isAnimating = true
                    anim.completion = { [weak self] _ in
                        guard self?.videoStalled == false else { return }
                        self?.loadingBlurView.removeFromSuperview()
                        self?.placeholderView.removeFromSuperview()
                        self?.isAnimating = false
                    }
                    loadingBlurView.layer.add(anim, forKey: "opacity")
                }
            }
        }
        
        func update(component: MediaStreamVideoComponent, availableSize: CGSize, state: State, transition: Transition) -> CGSize {
            self.state = state
            self.component = component
            self.onVideoPlaybackChange = component.onVideoPlaybackLiveChange
            self.isFullscreen = component.isFullscreen
            
            if let peer = component.callPeer, !didBeginLoadingAvatar {
                didBeginLoadingAvatar = true
                
                avatarDisposable = peerAvatarCompleteImage(account: component.call.account, peer: EnginePeer(peer), size: CGSize(width: 250.0, height: 250.0), round: false, font: Font.regular(16.0), drawLetters: false, fullSize: false, blurred: true).start(next: { [weak self] image in
                    DispatchQueue.main.async {
                        self?.placeholderView.contentMode = .scaleAspectFill
                        self?.placeholderView.image = image
                    }
                })
            }
            
            if !component.hasVideo || component.videoLoading || self.videoStalled {
                updateVideoStalled(isStalled: true, transition: transition)
            } else {
                updateVideoStalled(isStalled: false, transition: transition)
            }
            
            if component.hasVideo, self.videoView == nil {
                if let input = component.call.video(endpointId: "unified") {
                    var _stallTimer: Foundation.Timer { Foundation.Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
                        guard let strongSelf = self else { return timer.invalidate() }
                        
                        let currentTime = CFAbsoluteTimeGetCurrent()
                        if let lastFrameTime = strongSelf.timeLastFrameReceived,
                           currentTime - lastFrameTime > 0.5 {
                            strongSelf.videoLoadingThrottler.publish(true, includingLatest: true) { isStalled in
                                strongSelf.videoStalled = isStalled
                                strongSelf.onVideoPlaybackChange(!isStalled)
                            }
                        }
                    } }
                    
                    // TODO: use mapToThrottled (?)
                    frameInputDisposable = input.start(next: { [weak self] input in
                        guard let strongSelf = self else { return }
                        
                        strongSelf.timeLastFrameReceived = CFAbsoluteTimeGetCurrent()
                        strongSelf.videoLoadingThrottler.publish(false, includingLatest: true) { isStalled in
                            strongSelf.videoStalled = isStalled
                            strongSelf.onVideoPlaybackChange(!isStalled)
                        }
                    })
                    stallTimer = _stallTimer
                    self.clipsToBounds = component.isFullscreen // or just true
                    if let videoBlurView = self.videoRenderingContext.makeView(input: input, blur: true) {
                        self.videoBlurView = videoBlurView
                        self.insertSubview(videoBlurView, belowSubview: self.blurTintView)
                        videoBlurView.alpha = 0
                        UIView.animate(withDuration: 0.3) {
                            videoBlurView.alpha = 1
                        }
                        self.videoBlurGradientMask.type = .radial
                        self.videoBlurGradientMask.colors = [UIColor(rgb: 0x000000, alpha: 0.5).cgColor, UIColor(rgb: 0xffffff, alpha: 0.0).cgColor]
                        self.videoBlurGradientMask.startPoint = CGPoint(x: 0.5, y: 0.5)
                        self.videoBlurGradientMask.endPoint = CGPoint(x: 1.0, y: 1.0)
                        
                        self.videoBlurSolidMask.backgroundColor = UIColor.black.cgColor
                        self.videoBlurGradientMask.addSublayer(videoBlurSolidMask)
                        
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
                            
                            if #available(iOS 13.0, *) {
                                sampleBufferVideoView.sampleBufferLayer.preventsDisplaySleepDuringVideoPlayback = true
                            }
                            
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
                                    delegate.onTransitionFinished = {
                                    }
                                    return delegate
                                }()))
                                pictureInPictureController?.playerLayer.masksToBounds = false
                                pictureInPictureController?.playerLayer.cornerRadius = 10
                            } else if AVPictureInPictureController.isPictureInPictureSupported() {
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
                        }
                        
                        videoView.setOnOrientationUpdated { [weak state] _, _ in
                            state?.updated(transition: .immediate)
                        }
                        videoView.setOnFirstFrameReceived { [weak self, weak state] _ in
                            guard let strongSelf = self else {
                                return
                            }
                            
                            strongSelf.hadVideo = true
                            
                            strongSelf.noSignalTimer?.invalidate()
                            strongSelf.noSignalTimer = nil
                            strongSelf.noSignalTimeout = false
                            strongSelf.noSignalView?.removeFromSuperview()
                            strongSelf.noSignalView = nil
                            
                            state?.updated(transition: .immediate)
                        }
                    }
                }
            } else if component.isFullscreen {
                if fullScreenBackgroundPlaceholder.superview == nil {
                    insertSubview(fullScreenBackgroundPlaceholder, at: 0)
                    transition.setAlpha(view: self.fullScreenBackgroundPlaceholder, alpha: 1)
                }
                fullScreenBackgroundPlaceholder.backgroundColor = UIColor.black.withAlphaComponent(0.5)
            } else {
                transition.setAlpha(view: self.fullScreenBackgroundPlaceholder, alpha: 0, completion: { didComplete in
                    if didComplete {
                        self.fullScreenBackgroundPlaceholder.removeFromSuperview()
                    }
                })
            }
            fullScreenBackgroundPlaceholder.frame = .init(origin: .zero, size: availableSize)
            
            let videoInset: CGFloat
            if !component.isFullscreen {
                videoInset = 16
            } else {
                videoInset = 0
            }
            
            let videoSize: CGSize
            let videoCornerRadius: CGFloat = component.isFullscreen ? 0 : 10
            
            let videoFrameUpdateTransition: Transition
            if self.wasFullscreen != component.isFullscreen {
                videoFrameUpdateTransition = transition
            } else {
                videoFrameUpdateTransition = transition.withAnimation(.none)
            }
            
            if let videoView = self.videoView {
                if videoView.bounds.size.width > 0,
                    videoView.alpha > 0,
                    self.hadVideo,
                    let snapshot = videoView.snapshotView(afterScreenUpdates: false) ?? videoView.snapshotView(afterScreenUpdates: true) {
                    lastFrame[component.call.peerId.id.description] = snapshot
                }
                
                var aspect = videoView.getAspect()
                if component.isFullscreen && self.hadVideo {
                    if aspect <= 0.01 {
                        aspect = 16.0 / 9
                    }
                } else if !self.hadVideo {
                    aspect = 16.0 / 9
                }
                
                if component.isFullscreen {
                    videoSize = CGSize(width: aspect * 100.0, height: 100.0).aspectFitted(.init(width: availableSize.width - videoInset * 2, height: availableSize.height))
                } else {
                    // Limiting by smallest side -- redundant if passing precalculated availableSize
                    let availableVideoWidth = min(availableSize.width, availableSize.height) - videoInset * 2
                    let availableVideoHeight = availableVideoWidth * 9.0 / 16
                    
                    videoSize = CGSize(width: aspect * 100.0, height: 100.0).aspectFitted(.init(width: availableVideoWidth, height: availableVideoHeight))
                }
                let blurredVideoSize = component.isFullscreen ? availableSize : videoSize.aspectFilled(availableSize)
                
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
                videoView.layer.cornerRadius = videoCornerRadius
                
                self.wasFullscreen = component.isFullscreen
                let newVideoFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - videoSize.width) / 2.0), y: floor((availableSize.height - videoSize.height) / 2.0)), size: videoSize)
                
                videoFrameUpdateTransition.setFrame(view: videoView, frame: newVideoFrame, completion: nil)
                
                if let videoBlurView = self.videoBlurView {
                    
                    videoBlurView.updateIsEnabled(component.isVisible)
                    if component.isFullscreen {
                        videoFrameUpdateTransition.setFrame(view: videoBlurView, frame: CGRect(
                            origin: CGPoint(x: floor((availableSize.width - blurredVideoSize.width) / 2.0), y: floor((availableSize.height - blurredVideoSize.height) / 2.0)),
                            size: blurredVideoSize
                        ), completion: nil)
                    } else {
                        videoFrameUpdateTransition.setFrame(view: videoBlurView, frame: videoView.frame.insetBy(dx: -70.0 * aspect, dy: -70.0))
                    }
                    
                    videoBlurView.layer.mask = videoBlurGradientMask
                    
                    if !component.isFullscreen {
                        transition.setAlpha(layer: videoBlurSolidMask, alpha: 0)
                    } else {
                        transition.setAlpha(layer: videoBlurSolidMask, alpha: 1)
                    }
                    
                    videoFrameUpdateTransition.setFrame(layer: self.videoBlurGradientMask, frame: videoBlurView.bounds)
                    videoFrameUpdateTransition.setFrame(layer: self.videoBlurSolidMask, frame: self.videoBlurGradientMask.bounds)
                }
            } else {
                videoSize = CGSize(width: 16 / 9 * 100.0, height: 100.0).aspectFitted(.init(width: availableSize.width - videoInset * 2, height: availableSize.height))
            }
            
            let loadingBlurViewFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - videoSize.width) / 2.0), y: floor((availableSize.height - videoSize.height) / 2.0)), size: videoSize)
            
            if loadingBlurView.frame == .zero {
                loadingBlurView.frame = loadingBlurViewFrame
            } else {
                // Using Transition.setFrame on UIVisualEffectView causes instant update of sublayers
                switch videoFrameUpdateTransition.animation {
                case let .curve(duration, curve):
                    UIView.animate(withDuration: duration, delay: 0, options: curve.containedViewLayoutTransitionCurve.viewAnimationOptions, animations: { [self] in
                        loadingBlurView.frame = loadingBlurViewFrame
                    })
                    
                default:
                    loadingBlurView.frame = loadingBlurViewFrame
                }
            }
            videoFrameUpdateTransition.setCornerRadius(layer: loadingBlurView.layer, cornerRadius: videoCornerRadius)
            videoFrameUpdateTransition.setFrame(view: placeholderView, frame: loadingBlurViewFrame)
            videoFrameUpdateTransition.setCornerRadius(layer: placeholderView.layer, cornerRadius: videoCornerRadius)
            placeholderView.clipsToBounds = true
            placeholderView.subviews.forEach {
                videoFrameUpdateTransition.setFrame(view: $0, frame: placeholderView.bounds)
            }
            
            let initialShimmerBounds = shimmerBorderLayer.bounds
            videoFrameUpdateTransition.setFrame(layer: shimmerBorderLayer, frame: loadingBlurView.bounds)
            
            let borderMask = CAShapeLayer()
            let initialPath = CGPath(roundedRect: .init(x: 0, y: 0, width: initialShimmerBounds.width, height: initialShimmerBounds.height), cornerWidth: videoCornerRadius, cornerHeight: videoCornerRadius, transform: nil)
            borderMask.path = initialPath
            
            videoFrameUpdateTransition.setShapeLayerPath(layer: borderMask, path: CGPath(roundedRect: .init(x: 0, y: 0, width: shimmerBorderLayer.bounds.width, height: shimmerBorderLayer.bounds.height), cornerWidth: videoCornerRadius, cornerHeight: videoCornerRadius, transform: nil))
            
            borderMask.fillColor = UIColor.white.withAlphaComponent(0.4).cgColor
            borderMask.strokeColor = UIColor.white.withAlphaComponent(0.7).cgColor
            borderMask.lineWidth = 3
            shimmerBorderLayer.mask = borderMask
            shimmerBorderLayer.cornerRadius = videoCornerRadius
            
            if !self.hadVideo {
                
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
                        noSignalView.layer.zPosition = loadingBlurView.layer.zPosition + 1
                        
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
                    noSignalTransition.setFrame(view: noSignalView, frame: CGRect(origin: CGPoint(x: floor((availableSize.width - noSignalSize.width) / 2.0), y: (availableSize.height - noSignalSize.height) / 2.0), size: noSignalSize), completion: nil)
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
            if let videoView = self.videoView, let presentation = videoView.snapshotView(afterScreenUpdates: false) {
                let presentationParent = self.window ?? self
                presentationParent.addSubview(presentation)
                presentation.frame = presentationParent.convert(videoView.frame, from: self)
                
                if let callId = self.component?.call.peerId.id.description {
                    lastFrame[callId] = presentation
                }
                
                videoView.alpha = 0
                lastPresentation?.removeFromSuperview()
                lastPresentation = presentation
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    self.lastPresentation?.removeFromSuperview()
                    self.lastPresentation = nil
                    self.pipTrackDisplayLink?.invalidate()
                    self.pipTrackDisplayLink = nil
                }
            }
            UIView.animate(withDuration: 0.1) { [self] in
                videoBlurView?.alpha = 0
            }
            // TODO: assure player window
            UIApplication.shared.windows.first?.layer.cornerRadius = 10.0
            UIApplication.shared.windows.first?.layer.masksToBounds = true
            
            self.pipTrackDisplayLink?.invalidate()
            self.pipTrackDisplayLink = CADisplayLink(target: self, selector: #selector(observePiPWindow))
            self.pipTrackDisplayLink?.add(to: .main, forMode: .default)
        }
        
        @objc func observePiPWindow() {
            let pipViewDidBecomeVisible = (UIApplication.shared.windows.first?.layer.animationKeys()?.count ?? 0) > 0
            if pipViewDidBecomeVisible {
                lastPresentation?.removeFromSuperview()
                lastPresentation = nil
                self.pipTrackDisplayLink?.invalidate()
                self.pipTrackDisplayLink = nil
            }
        }
        
        public func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
            guard let component = self.component else {
                completionHandler(false)
                return
            }
            didRequestBringBack = true
            component.bringBackControllerForPictureInPictureDeactivation {
                completionHandler(true)
            }
        }
        
        func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
            self.didRequestBringBack = false
            self.state?.updated(transition: .immediate)
        }
        
        func pictureInPictureControllerWillStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
            if self.requestedExpansion {
                self.requestedExpansion = false
            } else if !didRequestBringBack {
                self.component?.pictureInPictureClosed()
            }
            didRequestBringBack = false
            // TODO: extract precise animation timing or observe window changes
            // Handle minimized case separatelly (can we detect minimized?)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
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
fileprivate var lastFrame: [String: UIView] = [:]

private final class CustomIntensityVisualEffectView: UIVisualEffectView {
    private var animator: UIViewPropertyAnimator!
    
    init(effect: UIVisualEffect, intensity: CGFloat) {
        super.init(effect: nil)
        animator = UIViewPropertyAnimator(duration: 1, curve: .linear) { [weak self] in self?.effect = effect }
        animator.startAnimation()
        animator.pauseAnimation()
        animator.fractionComplete = intensity
        animator.pausesOnCompletion = true
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError()
    }
    
    deinit {
        animator.stopAnimation(true)
    }
}
