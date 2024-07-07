import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import AccountContext
import TelegramVoip
import AVFoundation
import CallScreen
import MetalEngine

protocol VideoRenderingView: UIView {
    func setOnFirstFrameReceived(_ f: @escaping (Float) -> Void)
    func setOnOrientationUpdated(_ f: @escaping (PresentationCallVideoView.Orientation, CGFloat) -> Void)
    func getOrientation() -> PresentationCallVideoView.Orientation
    func getAspect() -> CGFloat
    func setOnIsMirroredUpdated(_ f: @escaping (Bool) -> Void)
    func updateIsEnabled(_ isEnabled: Bool)
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition)
}

class VideoRenderingContext {
    private var metalContextImpl: Any?

    #if targetEnvironment(simulator)
    #else
    @available(iOS 13.0, *)
    var metalContext: MetalVideoRenderingContext {
        if let value = self.metalContextImpl as? MetalVideoRenderingContext {
            return value
        } else {
            let value = MetalVideoRenderingContext()!
            self.metalContextImpl = value
            return value
        }
    }
    #endif

    func makeView(input: Signal<OngoingGroupCallContext.VideoFrameData, NoError>, forceSampleBufferDisplayLayer: Bool = false) -> VideoRenderingView? {
        if !forceSampleBufferDisplayLayer {
            return CallScreenVideoView(input: input)
        }
        
        #if targetEnvironment(simulator)
        return SampleBufferVideoRenderingView(input: input)
        #else
        if #available(iOS 13.0, *), !forceSampleBufferDisplayLayer {
            return MetalVideoRenderingView(renderingContext: self.metalContext, input: input, blur: false)
        } else {
            return SampleBufferVideoRenderingView(input: input)
        }
        #endif
    }
    
    func makeBlurView(input: Signal<OngoingGroupCallContext.VideoFrameData, NoError>, mainView: VideoRenderingView?, forceSampleBufferDisplayLayer: Bool = false) -> VideoRenderingView? {
        if let mainView = mainView as? CallScreenVideoView {
            return CallScreenVideoBlurView(mainView: mainView)
        }
        
        #if targetEnvironment(simulator)
        #if DEBUG
        return SampleBufferVideoRenderingView(input: input)
        #else
        return nil
        #endif
        #else
        if #available(iOS 13.0, *), !forceSampleBufferDisplayLayer {
            return MetalVideoRenderingView(renderingContext: self.metalContext, input: input, blur: true)
        } else {
            return nil
        }
        #endif
    }

    func updateVisibility(isVisible: Bool) {
        #if targetEnvironment(simulator)
        #else
        if #available(iOS 13.0, *) {
            self.metalContext.updateVisibility(isVisible: isVisible)
        }
        #endif
    }
}

extension PresentationCallVideoView.Orientation {
    init(_ orientation: OngoingCallVideoOrientation) {
        switch orientation {
        case .rotation0:
            self = .rotation0
        case .rotation90:
            self = .rotation90
        case .rotation180:
            self = .rotation180
        case .rotation270:
            self = .rotation270
        }
    }
}

private final class CallScreenVideoView: UIView, VideoRenderingView {
    private var isEnabled: Bool = false

    private var onFirstFrameReceived: ((Float) -> Void)?
    private var onOrientationUpdated: ((PresentationCallVideoView.Orientation, CGFloat) -> Void)?
    private var onIsMirroredUpdated: ((Bool) -> Void)?

    private var didReportFirstFrame: Bool = false
    private var currentIsMirrored: Bool = false
    private var currentOrientation: PresentationCallVideoView.Orientation = .rotation0
    private var currentAspect: CGFloat = 1.0

    fileprivate let videoSource: AdaptedCallVideoSource
    private var disposable: Disposable?
    
    fileprivate let videoLayer: PrivateCallVideoLayer

    init(input: Signal<OngoingGroupCallContext.VideoFrameData, NoError>) {
        self.videoLayer = PrivateCallVideoLayer()
        self.videoLayer.masksToBounds = true
        
        self.videoSource = AdaptedCallVideoSource(videoStreamSignal: input)
        
        super.init(frame: CGRect())
        
        self.layer.addSublayer(self.videoLayer)

        self.disposable = self.videoSource.addOnUpdated { [weak self] in
            guard let self else {
                return
            }
            
            self.videoLayer.video = self.videoSource.currentOutput
            
            var notifyOrientationUpdated = false
            var notifyIsMirroredUpdated = false
            
            if !self.didReportFirstFrame {
                notifyOrientationUpdated = true
                notifyIsMirroredUpdated = true
            }
            
            if let currentOutput = self.videoSource.currentOutput {
                let currentAspect: CGFloat
                if currentOutput.resolution.height > 0.0 {
                    currentAspect = currentOutput.resolution.width / currentOutput.resolution.height
                } else {
                    currentAspect = 1.0
                }
                if self.currentAspect != currentAspect {
                    self.currentAspect = currentAspect
                    notifyOrientationUpdated = true
                }
                
                let currentOrientation: PresentationCallVideoView.Orientation
                if abs(currentOutput.rotationAngle - 0.0) < .ulpOfOne {
                    currentOrientation = .rotation0
                } else if abs(currentOutput.rotationAngle - Float.pi * 0.5) < .ulpOfOne {
                    currentOrientation = .rotation90
                } else if abs(currentOutput.rotationAngle - Float.pi) < .ulpOfOne {
                    currentOrientation = .rotation180
                } else if abs(currentOutput.rotationAngle - Float.pi * 3.0 / 2.0) < .ulpOfOne {
                    currentOrientation = .rotation270
                } else {
                    currentOrientation = .rotation0
                }
                if self.currentOrientation != currentOrientation {
                    self.currentOrientation = currentOrientation
                    notifyOrientationUpdated = true
                }
                
                let currentIsMirrored = !currentOutput.mirrorDirection.isEmpty
                if self.currentIsMirrored != currentIsMirrored {
                    self.currentIsMirrored = currentIsMirrored
                    notifyIsMirroredUpdated = true
                }
            }
            
            if !self.didReportFirstFrame {
                self.didReportFirstFrame = true
                self.onFirstFrameReceived?(Float(self.currentAspect))
            }
            
            if notifyOrientationUpdated {
                self.onOrientationUpdated?(self.currentOrientation, self.currentAspect)
            }
            
            if notifyIsMirroredUpdated {
                self.onIsMirroredUpdated?(self.currentIsMirrored)
            }
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.disposable?.dispose()
    }

    func setOnFirstFrameReceived(_ f: @escaping (Float) -> Void) {
        self.onFirstFrameReceived = f
        self.didReportFirstFrame = false
    }

    func setOnOrientationUpdated(_ f: @escaping (PresentationCallVideoView.Orientation, CGFloat) -> Void) {
        self.onOrientationUpdated = f
    }

    func getOrientation() -> PresentationCallVideoView.Orientation {
        return self.currentOrientation
    }

    func getAspect() -> CGFloat {
        return self.currentAspect
    }

    func setOnIsMirroredUpdated(_ f: @escaping (Bool) -> Void) {
        self.onIsMirroredUpdated = f
    }

    func updateIsEnabled(_ isEnabled: Bool) {
        self.isEnabled = isEnabled
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        if let currentOutput = self.videoSource.currentOutput {
            let rotatedResolution = currentOutput.resolution
            let videoSize = size
            
            let videoResolution = rotatedResolution.aspectFittedOrSmaller(CGSize(width: 1280, height: 1280)).aspectFittedOrSmaller(CGSize(width: videoSize.width * 3.0, height: videoSize.height * 3.0))
            let rotatedVideoResolution = videoResolution
            
            transition.updateFrame(layer: self.videoLayer, frame: CGRect(origin: CGPoint(), size: size))
            self.videoLayer.renderSpec = RenderLayerSpec(size: RenderSize(width: Int(rotatedVideoResolution.width), height: Int(rotatedVideoResolution.height)), edgeInset: 2)
        }
    }
}

private final class CallScreenVideoBlurView: UIView, VideoRenderingView {
    private weak var mainView: CallScreenVideoView?
    
    private let blurredLayer: MetalEngineSubjectLayer

    init(mainView: CallScreenVideoView) {
        self.mainView = mainView
        self.blurredLayer = mainView.videoLayer.blurredLayer
        
        super.init(frame: CGRect())
        
        self.layer.addSublayer(self.blurredLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
    }

    func setOnFirstFrameReceived(_ f: @escaping (Float) -> Void) {
    }

    func setOnOrientationUpdated(_ f: @escaping (PresentationCallVideoView.Orientation, CGFloat) -> Void) {
    }

    func getOrientation() -> PresentationCallVideoView.Orientation {
        return .rotation0
    }

    func getAspect() -> CGFloat {
        return 1.0
    }

    func setOnIsMirroredUpdated(_ f: @escaping (Bool) -> Void) {
    }

    func updateIsEnabled(_ isEnabled: Bool) {
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(layer: self.blurredLayer, frame: CGRect(origin: CGPoint(), size: size))
    }
}
