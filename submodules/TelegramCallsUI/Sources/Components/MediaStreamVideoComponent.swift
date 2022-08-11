import Foundation
import UIKit
import ComponentFlow
import ActivityIndicatorComponent
import AccountContext
import AVKit
import MultilineTextComponent
import Display

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
    
    init(
        call: PresentationGroupCallImpl,
        hasVideo: Bool,
        isVisible: Bool,
        isAdmin: Bool,
        peerTitle: String,
        activatePictureInPicture: ActionSlot<Action<Void>>,
        deactivatePictureInPicture: ActionSlot<Void>,
        bringBackControllerForPictureInPictureDeactivation: @escaping (@escaping () -> Void) -> Void,
        pictureInPictureClosed: @escaping () -> Void
    ) {
        self.call = call
        self.hasVideo = hasVideo
        self.isVisible = isVisible
        self.isAdmin = isAdmin
        self.peerTitle = peerTitle
        self.activatePictureInPicture = activatePictureInPicture
        self.deactivatePictureInPicture = deactivatePictureInPicture
        self.bringBackControllerForPictureInPictureDeactivation = bringBackControllerForPictureInPictureDeactivation
        self.pictureInPictureClosed = pictureInPictureClosed
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
    
    public final class View: UIScrollView, AVPictureInPictureControllerDelegate, ComponentTaggedView {
        public final class Tag {
        }
        
        private let videoRenderingContext = VideoRenderingContext()
        private let blurTintView: UIView
        private var videoBlurView: VideoRenderingView?
        private var videoView: VideoRenderingView?
        private var activityIndicatorView: ComponentHostView<Empty>?
        private var noSignalView: ComponentHostView<Empty>?
        
        private var pictureInPictureController: AVPictureInPictureController?
        
        private var component: MediaStreamVideoComponent?
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
        
        func update(component: MediaStreamVideoComponent, availableSize: CGSize, state: State, transition: Transition) -> CGSize {
            self.state = state
            
            if component.hasVideo, self.videoView == nil {
                if let input = component.call.video(endpointId: "unified") {
                    if let videoBlurView = self.videoRenderingContext.makeView(input: input, blur: true) {
                        self.videoBlurView = videoBlurView
                        self.insertSubview(videoBlurView, belowSubview: self.blurTintView)
                    }

                    
                    if let videoView = self.videoRenderingContext.makeView(input: input, blur: false, forceSampleBufferDisplayLayer: true) {
                        self.videoView = videoView
                        self.addSubview(videoView)
                        
                        if let sampleBufferVideoView = videoView as? SampleBufferVideoRenderingView {
                            if #available(iOS 13.0, *) {
                                sampleBufferVideoView.sampleBufferLayer.preventsDisplaySleepDuringVideoPlayback = true
                            }
                            
                            if #available(iOSApplicationExtension 15.0, iOS 15.0, *), AVPictureInPictureController.isPictureInPictureSupported() {
                                final class PlaybackDelegateImpl: NSObject, AVPictureInPictureSampleBufferPlaybackDelegate {
                                    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, setPlaying playing: Bool) {
                                        
                                    }

                                    func pictureInPictureControllerTimeRangeForPlayback(_ pictureInPictureController: AVPictureInPictureController) -> CMTimeRange {
                                        return CMTimeRange(start: .zero, duration: .positiveInfinity)
                                    }

                                    func pictureInPictureControllerIsPlaybackPaused(_ pictureInPictureController: AVPictureInPictureController) -> Bool {
                                        return false
                                    }

                                    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, didTransitionToRenderSize newRenderSize: CMVideoDimensions) {
                                    }

                                    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, skipByInterval skipInterval: CMTime, completion completionHandler: @escaping () -> Void) {
                                        completionHandler()
                                    }

                                    public func pictureInPictureControllerShouldProhibitBackgroundAudioPlayback(_ pictureInPictureController: AVPictureInPictureController) -> Bool {
                                        return false
                                    }
                                }
                                
                                let pictureInPictureController = AVPictureInPictureController(contentSource: AVPictureInPictureController.ContentSource(sampleBufferDisplayLayer: sampleBufferVideoView.sampleBufferLayer, playbackDelegate: PlaybackDelegateImpl()))
                                
                                pictureInPictureController.delegate = self
                                pictureInPictureController.canStartPictureInPictureAutomaticallyFromInline = true
                                pictureInPictureController.requiresLinearPlayback = true
                                
                                self.pictureInPictureController = pictureInPictureController
                            }
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
                            
                            //strongSelf.translatesAutoresizingMaskIntoConstraints = false
                            //strongSelf.maximumZoomScale = 4.0
                            
                            state?.updated(transition: .immediate)
                        }
                    }
                }
            }
            
            if let videoView = self.videoView {
                var isVideoVisible = component.isVisible
                if let pictureInPictureController = self.pictureInPictureController {
                    if pictureInPictureController.isPictureInPictureActive {
                        isVideoVisible = true
                    }
                }
                
                videoView.updateIsEnabled(isVideoVisible)
                
                var aspect = videoView.getAspect()
                if aspect <= 0.01 {
                    aspect = 3.0 / 4.0
                }
                
                let videoSize = CGSize(width: aspect * 100.0, height: 100.0).aspectFitted(availableSize)
                let blurredVideoSize = videoSize.aspectFilled(availableSize)
                
                transition.withAnimation(.none).setFrame(view: videoView, frame: CGRect(origin: CGPoint(x: floor((availableSize.width - videoSize.width) / 2.0), y: floor((availableSize.height - videoSize.height) / 2.0)), size: videoSize), completion: nil)
                
                if let videoBlurView = self.videoBlurView {
                    videoBlurView.updateIsEnabled(component.isVisible)
                    
                    transition.withAnimation(.none).setFrame(view: videoBlurView, frame: CGRect(origin: CGPoint(x: floor((availableSize.width - blurredVideoSize.width) / 2.0), y: floor((availableSize.height - blurredVideoSize.height) / 2.0)), size: blurredVideoSize), completion: nil)
                }
            }
            
            if !self.hadVideo {
                var activityIndicatorTransition = transition
                let activityIndicatorView: ComponentHostView<Empty>
                if let current = self.activityIndicatorView {
                    activityIndicatorView = current
                } else {
                    activityIndicatorTransition = transition.withAnimation(.none)
                    activityIndicatorView = ComponentHostView<Empty>()
                    self.activityIndicatorView = activityIndicatorView
                    self.addSubview(activityIndicatorView)
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
        }
        
        func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
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
