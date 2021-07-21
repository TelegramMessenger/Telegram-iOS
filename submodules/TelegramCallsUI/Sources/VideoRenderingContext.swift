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

    func makeView(input: Signal<OngoingGroupCallContext.VideoFrameData, NoError>, blur: Bool) -> VideoRenderingView? {
        if #available(iOS 13.0, *) {
            return MetalVideoRenderingView(renderingContext: self.metalContext, input: input, blur: blur)
        } else {
            return SampleBufferVideoRenderingView(input: input)
        }
    }

    func updateVisibility(isVisible: Bool) {
        if #available(iOS 13.0, *) {
            self.metalContext.updateVisibility(isVisible: isVisible)
        }
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