import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import AccountContext
import TelegramVoip
import AVFoundation

protocol VideoRenderingView: UIView {
    func setOnFirstFrameReceived(_ f: @escaping (Float) -> Void)
    func setOnOrientationUpdated(_ f: @escaping (PresentationCallVideoView.Orientation, CGFloat) -> Void)
    func getOrientation() -> PresentationCallVideoView.Orientation
    func getAspect() -> CGFloat
    func setOnIsMirroredUpdated(_ f: @escaping (Bool) -> Void)
    func updateIsEnabled(_ isEnabled: Bool)
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

    func makeView(input: Signal<OngoingGroupCallContext.VideoFrameData, NoError>, blur: Bool, forceSampleBufferDisplayLayer: Bool = false) -> VideoRenderingView? {
        #if targetEnvironment(simulator)
        if blur {
            #if DEBUG
            return SampleBufferVideoRenderingView(input: input)
            #else
            return nil
            #endif
        }
        return SampleBufferVideoRenderingView(input: input)
        #else
        if #available(iOS 13.0, *), !forceSampleBufferDisplayLayer {
            return MetalVideoRenderingView(renderingContext: self.metalContext, input: input, blur: blur)
        } else {
            if blur {
                return nil
            }
            return SampleBufferVideoRenderingView(input: input)
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
