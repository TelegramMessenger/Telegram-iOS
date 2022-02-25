import Foundation
import UIKit
import ComponentFlow
import AccountContext
import AVKit

final class MediaStreamVideoComponent: Component {
    let call: PresentationGroupCallImpl
    let activatePictureInPicture: ActionSlot<Action<Void>>
    let bringBackControllerForPictureInPictureDeactivation: (@escaping () -> Void) -> Void
    
    init(call: PresentationGroupCallImpl, activatePictureInPicture: ActionSlot<Action<Void>>, bringBackControllerForPictureInPictureDeactivation: @escaping (@escaping () -> Void) -> Void) {
        self.call = call
        self.activatePictureInPicture = activatePictureInPicture
        self.bringBackControllerForPictureInPictureDeactivation = bringBackControllerForPictureInPictureDeactivation
    }
    
    public static func ==(lhs: MediaStreamVideoComponent, rhs: MediaStreamVideoComponent) -> Bool {
        if lhs.call !== rhs.call {
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
    
    public final class View: UIView, AVPictureInPictureControllerDelegate, AVPictureInPictureSampleBufferPlaybackDelegate {
        private let videoRenderingContext = VideoRenderingContext()
        private var videoView: VideoRenderingView?
        private let blurTintView: UIView
        private var videoBlurView: VideoRenderingView?
        
        private var pictureInPictureController: AVPictureInPictureController?
        
        private var component: MediaStreamVideoComponent?
        
        override init(frame: CGRect) {
            self.blurTintView = UIView()
            self.blurTintView.backgroundColor = UIColor(white: 0.0, alpha: 0.5)
            
            super.init(frame: frame)
            
            self.isUserInteractionEnabled = false
            self.clipsToBounds = true
            
            self.addSubview(self.blurTintView)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: MediaStreamVideoComponent, availableSize: CGSize, state: State, transition: Transition) -> CGSize {
            if self.videoView == nil {
                if let input = component.call.video(endpointId: "unified") {
                    if let videoBlurView = self.videoRenderingContext.makeView(input: input, blur: true) {
                        self.videoBlurView = videoBlurView
                        self.insertSubview(videoBlurView, belowSubview: self.blurTintView)
                    }
                    
                    if let videoView = self.videoRenderingContext.makeView(input: input, blur: false, forceSampleBufferDisplayLayer: true) {
                        self.videoView = videoView
                        self.addSubview(videoView)
                        
                        if #available(iOSApplicationExtension 15.0, iOS 15.0, *), AVPictureInPictureController.isPictureInPictureSupported(), let sampleBufferVideoView = videoView as? SampleBufferVideoRenderingView {
                            let pictureInPictureController = AVPictureInPictureController(contentSource: AVPictureInPictureController.ContentSource(sampleBufferDisplayLayer: sampleBufferVideoView.sampleBufferLayer, playbackDelegate: self))
                            self.pictureInPictureController = pictureInPictureController
                            
                            pictureInPictureController.canStartPictureInPictureAutomaticallyFromInline = true
                            pictureInPictureController.requiresLinearPlayback = true
                            pictureInPictureController.delegate = self
                        }
                        
                        videoView.setOnOrientationUpdated { [weak state] _, _ in
                            state?.updated(transition: .immediate)
                        }
                        videoView.setOnFirstFrameReceived { [weak state] _ in
                            state?.updated(transition: .immediate)
                        }
                    }
                }
            }
            
            if let videoView = self.videoView {
                videoView.updateIsEnabled(true)
                var aspect = videoView.getAspect()
                if aspect <= 0.01 {
                    aspect = 3.0 / 4.0
                }
                
                let videoSize = CGSize(width: aspect * 100.0, height: 100.0).aspectFitted(availableSize)
                let blurredVideoSize = videoSize.aspectFilled(availableSize)
                
                transition.withAnimation(.none).setFrame(view: videoView, frame: CGRect(origin: CGPoint(x: floor((availableSize.width - videoSize.width) / 2.0), y: floor((availableSize.height - videoSize.height) / 2.0)), size: videoSize), completion: nil)
                
                if let videoBlurView = self.videoBlurView {
                    videoBlurView.updateIsEnabled(true)
                    transition.withAnimation(.none).setFrame(view: videoBlurView, frame: CGRect(origin: CGPoint(x: floor((availableSize.width - blurredVideoSize.width) / 2.0), y: floor((availableSize.height - blurredVideoSize.height) / 2.0)), size: blurredVideoSize), completion: nil)
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
            
            return availableSize
        }
        
        public func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, setPlaying playing: Bool) {
        }

        public func pictureInPictureControllerTimeRangeForPlayback(_ pictureInPictureController: AVPictureInPictureController) -> CMTimeRange {
            return CMTimeRange(start: .zero, duration: .positiveInfinity)
        }

        public func pictureInPictureControllerIsPlaybackPaused(_ pictureInPictureController: AVPictureInPictureController) -> Bool {
            return false
        }

        public func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, didTransitionToRenderSize newRenderSize: CMVideoDimensions) {
        }

        public func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, skipByInterval skipInterval: CMTime, completion completionHandler: @escaping () -> Void) {
            completionHandler()
        }

        public func pictureInPictureControllerShouldProhibitBackgroundAudioPlayback(_ pictureInPictureController: AVPictureInPictureController) -> Bool {
            return false
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
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: State, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, transition: transition)
    }
}
