import Foundation
import ReplayKit
import CoreVideo
import TelegramVoip
import SwiftSignalKit
import BuildConfig
import BroadcastUploadHelpers

private func rootPathForBasePath(_ appGroupPath: String) -> String {
    return appGroupPath + "/telegram-data"
}

@available(iOS 10.0, *)
@objc(BroadcastUploadSampleHandler) class BroadcastUploadSampleHandler: RPBroadcastSampleHandler {
    /*private var ipcContext: IpcGroupCallBroadcastContext?
    private var callContext: OngoingGroupCallContext?
    private var videoCapturer: OngoingCallVideoCapturer?
    private var requestDisposable: Disposable?
    private var joinPayloadDisposable: Disposable?
    private var joinResponsePayloadDisposable: Disposable?*/

    private var screencastBufferClientContext: IpcGroupCallBufferBroadcastContext?
    private var statusDisposable: Disposable?

    deinit {
        /*self.requestDisposable?.dispose()
        self.joinPayloadDisposable?.dispose()
        self.joinResponsePayloadDisposable?.dispose()
        self.callContext?.stop()*/

        self.statusDisposable?.dispose()
    }

    public override func beginRequest(with context: NSExtensionContext) {
        super.beginRequest(with: context)
    }

    private func finish(with reason: IpcGroupCallBufferBroadcastContext.Status.FinishReason) {
        var errorString: String?
        switch reason {
            case .callEnded:
                errorString = "You're not in a voice chat"
            case .error:
                errorString = "Finished"
            case .screencastEnded:
                break
        }
        if let errorString = errorString {
            let error = NSError(domain: "BroadcastUploadExtension", code: 1, userInfo: [
                NSLocalizedDescriptionKey: errorString
            ])
            finishBroadcastWithError(error)
        } else {
            finishBroadcastGracefully(self)
        }
    }

    override public func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
        guard let appBundleIdentifier = Bundle.main.bundleIdentifier, let lastDotRange = appBundleIdentifier.range(of: ".", options: [.backwards]) else {
            self.finish(with: .error)
            return
        }

        let baseAppBundleId = String(appBundleIdentifier[..<lastDotRange.lowerBound])

        let appGroupName = "group.\(baseAppBundleId)"
        let maybeAppGroupUrl = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupName)

        guard let appGroupUrl = maybeAppGroupUrl else {
            self.finish(with: .error)
            return
        }

        let rootPath = rootPathForBasePath(appGroupUrl.path)

        let logsPath = rootPath + "/broadcast-logs"
        let _ = try? FileManager.default.createDirectory(atPath: logsPath, withIntermediateDirectories: true, attributes: nil)

        let screencastBufferClientContext = IpcGroupCallBufferBroadcastContext(basePath: rootPath + "/broadcast-coordination")
        self.screencastBufferClientContext = screencastBufferClientContext

        self.statusDisposable = (screencastBufferClientContext.status
        |> deliverOnMainQueue).start(next: { [weak self] status in
            guard let strongSelf = self else {
                return
            }
            switch status {
                case let .finished(reason):
                    strongSelf.finish(with: reason)
            }
        })

        /*let ipcContext = IpcGroupCallBroadcastContext(basePath: rootPath + "/broadcast-coordination")
        self.ipcContext = ipcContext

        self.requestDisposable = (ipcContext.request
        |> timeout(3.0, queue: .mainQueue(), alternate: .single(.failed))
        |> take(1)
        |> deliverOnMainQueue).start(next: { [weak self] request in
            guard let strongSelf = self else {
                return
            }
            switch request {
            case .request:
                strongSelf.beginWithRequest()
            case .failed:
                strongSelf.finishWithGenericError()
            }
        })*/
    }

    /*private func beginWithRequest() {
        let videoCapturer = OngoingCallVideoCapturer(isCustom: true)
        self.videoCapturer = videoCapturer

        let callContext = OngoingGroupCallContext(video: videoCapturer, requestMediaChannelDescriptions: { _, _ in return EmptyDisposable }, audioStreamData: nil, rejoinNeeded: {
        }, outgoingAudioBitrateKbit: nil, videoContentType: .screencast, enableNoiseSuppression: false)
        self.callContext = callContext

        self.joinPayloadDisposable = (callContext.joinPayload
        |> take(1)
        |> deliverOnMainQueue).start(next: { [weak self] joinPayload in
            guard let strongSelf = self, let ipcContext = strongSelf.ipcContext else {
                return
            }
            ipcContext.setJoinPayload(joinPayload.0)

            strongSelf.joinResponsePayloadDisposable = (ipcContext.joinResponsePayload
            |> take(1)
            |> deliverOnMainQueue).start(next: { joinResponsePayload in
                guard let strongSelf = self, let callContext = strongSelf.callContext, let ipcContext = strongSelf.ipcContext else {
                    return
                }

                callContext.setConnectionMode(.rtc, keepBroadcastConnectedIfWasEnabled: false)
                callContext.setJoinResponse(payload: joinResponsePayload)

                ipcContext.beginActiveIndication()
            })
        })
    }*/

    override public func broadcastPaused() {
    }

    override public func broadcastResumed() {
    }

    override public func broadcastFinished() {
    }

    override public func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        switch sampleBufferType {
        case RPSampleBufferType.video:
            processVideoSampleBuffer(sampleBuffer: sampleBuffer)
        case RPSampleBufferType.audioApp:
            break
        case RPSampleBufferType.audioMic:
            break
        @unknown default:
            break
        }
    }

    private func processVideoSampleBuffer(sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        var orientation = CGImagePropertyOrientation.up
        if #available(iOS 11.0, *) {
            if let orientationAttachment = CMGetAttachment(sampleBuffer, key: RPVideoSampleOrientationKey as CFString, attachmentModeOut: nil) as? NSNumber {
                orientation = CGImagePropertyOrientation(rawValue: orientationAttachment.uint32Value) ?? .up
            }
        }
        if let data = serializePixelBuffer(buffer: pixelBuffer) {
            self.screencastBufferClientContext?.setCurrentFrame(data: data, orientation: orientation)
        }

        //self.videoCapturer?.injectSampleBuffer(sampleBuffer)
        /*if CMSampleBufferGetNumSamples(sampleBuffer) != 1 {
            return
        }
        if !CMSampleBufferIsValid(sampleBuffer) {
            return
        }
        if !CMSampleBufferDataIsReady(sampleBuffer) {
            return
        }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        let pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)

        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)

        CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)*/
    }
}
