import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import AccountContext
import TelegramVoip
import AVFoundation

private func sampleBufferFromPixelBuffer(pixelBuffer: CVPixelBuffer) -> CMSampleBuffer? {
    var maybeFormat: CMVideoFormatDescription?
    let status = CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: pixelBuffer, formatDescriptionOut: &maybeFormat)
    if status != noErr {
        return nil
    }
    guard let format = maybeFormat else {
        return nil
    }

    var timingInfo = CMSampleTimingInfo(
        duration: CMTimeMake(value: 1, timescale: 30),
        presentationTimeStamp: CMTimeMake(value: 0, timescale: 30),
        decodeTimeStamp: CMTimeMake(value: 0, timescale: 30)
    )

    var maybeSampleBuffer: CMSampleBuffer?
    let bufferStatus = CMSampleBufferCreateReadyWithImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: pixelBuffer, formatDescription: format, sampleTiming: &timingInfo, sampleBufferOut: &maybeSampleBuffer)

    if (bufferStatus != noErr) {
        return nil
    }
    guard let sampleBuffer = maybeSampleBuffer else {
        return nil
    }

    let attachments: NSArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: true)! as NSArray
    let dict: NSMutableDictionary = attachments[0] as! NSMutableDictionary
    dict[kCMSampleAttachmentKey_DisplayImmediately as NSString] = true as NSNumber

    return sampleBuffer
}

final class SampleBufferVideoRenderingView: UIView, VideoRenderingView {
    static override var layerClass: AnyClass {
        return AVSampleBufferDisplayLayer.self
    }

    private var sampleBufferLayer: AVSampleBufferDisplayLayer {
        return self.layer as! AVSampleBufferDisplayLayer
    }

    private var isEnabled: Bool = false

    private var onFirstFrameReceived: ((Float) -> Void)?
    private var onOrientationUpdated: ((PresentationCallVideoView.Orientation, CGFloat) -> Void)?
    private var onIsMirroredUpdated: ((Bool) -> Void)?

    private var didReportFirstFrame: Bool = false
    private var currentOrientation: PresentationCallVideoView.Orientation = .rotation0
    private var currentAspect: CGFloat = 1.0

    private var disposable: Disposable?

    init(input: Signal<OngoingGroupCallContext.VideoFrameData, NoError>) {
        super.init(frame: CGRect())

        self.disposable = input.start(next: { [weak self] videoFrameData in
            Queue.mainQueue().async {
                self?.addFrame(videoFrameData)
            }
        })

        self.sampleBufferLayer.videoGravity = .resize
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.disposable?.dispose()
    }

    private func addFrame(_ videoFrameData: OngoingGroupCallContext.VideoFrameData) {
        let aspect = CGFloat(videoFrameData.width) / CGFloat(videoFrameData.height)
        var isAspectUpdated = false
        if self.currentAspect != aspect {
            self.currentAspect = aspect
            isAspectUpdated = true
        }

        let videoFrameOrientation = PresentationCallVideoView.Orientation(videoFrameData.orientation)
        var isOrientationUpdated = false
        if self.currentOrientation != videoFrameOrientation {
            self.currentOrientation = videoFrameOrientation
            isOrientationUpdated = true
        }

        if isAspectUpdated || isOrientationUpdated {
            self.onOrientationUpdated?(self.currentOrientation, self.currentAspect)
        }

        if !self.didReportFirstFrame {
            self.didReportFirstFrame = true
            self.onFirstFrameReceived?(Float(self.currentAspect))
        }

        if self.isEnabled {
            switch videoFrameData.buffer {
            case let .native(buffer):
                if let sampleBuffer = sampleBufferFromPixelBuffer(pixelBuffer: buffer.pixelBuffer) {
                    self.sampleBufferLayer.enqueue(sampleBuffer)
                }
            default:
                break
            }
        }
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
}
