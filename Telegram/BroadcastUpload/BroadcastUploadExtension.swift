import Foundation
import ReplayKit
import CoreVideo
import TelegramVoip
import SwiftSignalKit
import BuildConfig
import BroadcastUploadHelpers
import AudioToolbox
import Postbox
import CoreMedia
import AVFoundation

private func rootPathForBasePath(_ appGroupPath: String) -> String {
    return appGroupPath + "/telegram-data"
}

private protocol BroadcastUploadImpl: AnyObject {
    func initialize(rootPath: String)
    func processVideoSampleBuffer(sampleBuffer: CMSampleBuffer)
    func processAudioSampleBuffer(data: Data)
}

private final class InProcessBroadcastUploadImpl: BroadcastUploadImpl {
    private weak var extensionContext: RPBroadcastSampleHandler?
    private var screencastBufferClientContext: IpcGroupCallBufferBroadcastContext?
    private var statusDisposable: Disposable?
    
    init(extensionContext: RPBroadcastSampleHandler) {
        self.extensionContext = extensionContext
    }
    
    deinit {
        self.statusDisposable?.dispose()
    }
    
    func initialize(rootPath: String) {
        let screencastBufferClientContext = IpcGroupCallBufferBroadcastContext(basePath: rootPath + "/broadcast-coordination")
        self.screencastBufferClientContext = screencastBufferClientContext

        var wasRunning = false
        self.statusDisposable = (screencastBufferClientContext.status
        |> deliverOnMainQueue).start(next: { [weak self] status in
            guard let self else {
                return
            }
            switch status {
            case .active:
                wasRunning = true
            case let .finished(reason):
                if wasRunning {
                    self.finish(with: .screencastEnded)
                } else {
                    self.finish(with: reason)
                }
            }
        })
    }
    
    private func finish(with reason: IpcGroupCallBufferBroadcastContext.Status.FinishReason) {
        guard let extensionContext = self.extensionContext else {
            return
        }
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
            extensionContext.finishBroadcastWithError(error)
        } else {
            finishBroadcastGracefully(extensionContext)
        }
    }
    
    func processVideoSampleBuffer(sampleBuffer: CMSampleBuffer) {
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
    }
    
    func processAudioSampleBuffer(data: Data) {
        self.screencastBufferClientContext?.writeAudioData(data: data)
    }
}

private final class EmbeddedBroadcastUploadImpl: BroadcastUploadImpl {
    private weak var extensionContext: RPBroadcastSampleHandler?
    
    private var clientContext: IpcGroupCallEmbeddedBroadcastContext?
    private var statusDisposable: Disposable?
    
    private var callContextId: UInt32?
    private var callContextDidSetJoinResponse: Bool = false
    private var callContext: OngoingGroupCallContext?
    private let screencastCapturer: OngoingCallVideoCapturer
    
    private var joinPayloadDisposable: Disposable?
    
    private var sampleBuffers: [CMSampleBuffer] = []
    private var lastAcceptedTimestamp: Double?
    
    init(extensionContext: RPBroadcastSampleHandler) {
        self.extensionContext = extensionContext
        
        self.screencastCapturer = OngoingCallVideoCapturer(isCustom: true)
    }
    
    deinit {
        self.joinPayloadDisposable?.dispose()
    }
    
    func initialize(rootPath: String) {
        let clientContext = IpcGroupCallEmbeddedBroadcastContext(basePath: rootPath + "/embedded-broadcast-coordination")
        self.clientContext = clientContext
        
        var wasRunning = false
        self.statusDisposable = (clientContext.status
        |> deliverOnMainQueue).start(next: { [weak self] status in
            guard let self else {
                return
            }
            switch status {
            case let .active(id, joinResponse):
                wasRunning = true
                
                if self.callContextId != id {
                    if let callContext = self.callContext {
                        self.callContext = nil
                        self.callContextId = nil
                        self.callContextDidSetJoinResponse = false
                        self.joinPayloadDisposable?.dispose()
                        self.joinPayloadDisposable = nil
                        callContext.stop(account: nil, reportCallId: nil, debugLog: Promise())
                    }
                }
                
                if let id {
                    if self.callContext == nil {
                        self.callContextId = id
                        let callContext = OngoingGroupCallContext(
                            audioSessionActive: .single(true),
                            video: self.screencastCapturer,
                            requestMediaChannelDescriptions: { _, _ in EmptyDisposable },
                            rejoinNeeded: { },
                            outgoingAudioBitrateKbit: nil,
                            videoContentType: .screencast,
                            enableNoiseSuppression: false,
                            disableAudioInput: true,
                            enableSystemMute: false,
                            preferX264: false,
                            logPath: "",
                            onMutedSpeechActivityDetected: { _ in },
                            encryptionKey: nil,
                            isConference: false,
                            isStream: false,
                            sharedAudioDevice: nil
                        )
                        self.callContext = callContext
                        self.joinPayloadDisposable = (callContext.joinPayload
                        |> deliverOnMainQueue).start(next: { [weak self] joinPayload in
                            guard let self else {
                                return
                            }
                            if self.callContextId != id {
                                return
                            }
                            self.clientContext?.joinPayload = IpcGroupCallEmbeddedAppContext.JoinPayload(
                                id: id,
                                data: joinPayload.0,
                                ssrc: joinPayload.1
                            )
                        })
                    }
                    
                    if let callContext = self.callContext {
                        if let joinResponse, !self.callContextDidSetJoinResponse {
                            self.callContextDidSetJoinResponse = true
                            callContext.setConnectionMode(.rtc, keepBroadcastConnectedIfWasEnabled: false, isUnifiedBroadcast: false)
                            callContext.setJoinResponse(payload: joinResponse.data)
                        }
                    }
                }
            case let .finished(reason):
                if wasRunning {
                    self.finish(with: .screencastEnded)
                } else {
                    self.finish(with: reason)
                }
            }
        })
    }
    
    private func finish(with reason: IpcGroupCallEmbeddedBroadcastContext.Status.FinishReason) {
        guard let extensionContext = self.extensionContext else {
            return
        }
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
            extensionContext.finishBroadcastWithError(error)
        } else {
            finishBroadcastGracefully(extensionContext)
        }
    }
    
    func processVideoSampleBuffer(sampleBuffer: CMSampleBuffer) {
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
        if let lastAcceptedTimestamp = self.lastAcceptedTimestamp {
            if lastAcceptedTimestamp + 1.0 / 30.0 > timestamp {
                return
            }
        }
        self.lastAcceptedTimestamp = timestamp
        
        guard let sourceImageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        let sourcePixelBuffer: CVPixelBuffer = sourceImageBuffer as CVPixelBuffer
        
        let width = CVPixelBufferGetWidth(sourcePixelBuffer)
        let height = CVPixelBufferGetHeight(sourcePixelBuffer)
        let sourceBytesPerRow = CVPixelBufferGetBytesPerRow(sourcePixelBuffer)
        
        var outputPixelBuffer: CVPixelBuffer?
        let pixelFormat = CVPixelBufferGetPixelFormatType(sourcePixelBuffer)
        CVPixelBufferCreate(nil, width, height, pixelFormat, nil, &outputPixelBuffer)
        guard let outputPixelBuffer else {
            return
        }
        CVPixelBufferLockBaseAddress(sourcePixelBuffer, [])
        CVPixelBufferLockBaseAddress(outputPixelBuffer, [])
        
        let outputBytesPerRow = CVPixelBufferGetBytesPerRow(outputPixelBuffer)
        
        let sourceBaseAddress = CVPixelBufferGetBaseAddress(sourcePixelBuffer)
        let outputBaseAddress = CVPixelBufferGetBaseAddress(outputPixelBuffer)
        
        if outputBytesPerRow == sourceBytesPerRow {
            memcpy(outputBaseAddress!, sourceBaseAddress!, height * outputBytesPerRow)
        } else {
            for y in 0 ..< height {
                memcpy(outputBaseAddress!.advanced(by: y * outputBytesPerRow), sourceBaseAddress!.advanced(by: y * sourceBytesPerRow), min(sourceBytesPerRow, outputBytesPerRow))
            }
        }
        
        defer {
            CVPixelBufferUnlockBaseAddress(sourcePixelBuffer, [])
            CVPixelBufferUnlockBaseAddress(outputPixelBuffer, [])
        }
        
        var orientation = CGImagePropertyOrientation.up
        if #available(iOS 11.0, *) {
            if let orientationAttachment = CMGetAttachment(sampleBuffer, key: RPVideoSampleOrientationKey as CFString, attachmentModeOut: nil) as? NSNumber {
                orientation = CGImagePropertyOrientation(rawValue: orientationAttachment.uint32Value) ?? .up
            }
        }
        
        if let outputSampleBuffer = sampleBufferFromPixelBuffer(pixelBuffer: outputPixelBuffer) {
            let semaphore = DispatchSemaphore(value: 0)
            self.screencastCapturer.injectSampleBuffer(outputSampleBuffer, rotation: orientation, completion: {
                //semaphore.signal()
            })
            let _ = semaphore.wait(timeout: DispatchTime.now() + 1.0 / 30.0)
        }
    }
    
    func processAudioSampleBuffer(data: Data) {
        self.callContext?.addExternalAudioData(data: data)
    }
}

@available(iOS 10.0, *)
@objc(BroadcastUploadSampleHandler) class BroadcastUploadSampleHandler: RPBroadcastSampleHandler {
    private var impl: BroadcastUploadImpl?
    private var audioConverter: CustomAudioConverter?

    public override func beginRequest(with context: NSExtensionContext) {
        super.beginRequest(with: context)
    }
    
    private func finishWithError() {
        let errorString = "Finished"
        let error = NSError(domain: "BroadcastUploadExtension", code: 1, userInfo: [
            NSLocalizedDescriptionKey: errorString
        ])
        self.finishBroadcastWithError(error)
    }

    override public func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
        guard let appBundleIdentifier = Bundle.main.bundleIdentifier, let lastDotRange = appBundleIdentifier.range(of: ".", options: [.backwards]) else {
            self.finishWithError()
            return
        }

        let baseAppBundleId = String(appBundleIdentifier[..<lastDotRange.lowerBound])

        let appGroupName = "group.\(baseAppBundleId)"
        let maybeAppGroupUrl = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupName)

        guard let appGroupUrl = maybeAppGroupUrl else {
            self.finishWithError()
            return
        }

        let rootPath = rootPathForBasePath(appGroupUrl.path)
        
        TempBox.initializeShared(basePath: rootPath, processType: "share", launchSpecificId: Int64.random(in: Int64.min ... Int64.max))

        let logsPath = rootPath + "/logs/broadcast-logs"
        let _ = try? FileManager.default.createDirectory(atPath: logsPath, withIntermediateDirectories: true, attributes: nil)

        let embeddedBroadcastImplementationTypePath = rootPath + "/broadcast-coordination-type"
        
        var useIPCContext = false
        if let typeData = try? Data(contentsOf: URL(fileURLWithPath: embeddedBroadcastImplementationTypePath)), let type = String(data: typeData, encoding: .utf8) {
            useIPCContext = type == "ipc"
        }
        
        let impl: BroadcastUploadImpl
        if useIPCContext {
            impl = EmbeddedBroadcastUploadImpl(extensionContext: self)
        } else {
            impl = InProcessBroadcastUploadImpl(extensionContext: self)
        }
        self.impl = impl
        impl.initialize(rootPath: rootPath)
    }

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
            processAudioSampleBuffer(sampleBuffer: sampleBuffer)
        case RPSampleBufferType.audioMic:
            break
        @unknown default:
            break
        }
    }

    private func processVideoSampleBuffer(sampleBuffer: CMSampleBuffer) {
        self.impl?.processVideoSampleBuffer(sampleBuffer: sampleBuffer)
    }

    private func processAudioSampleBuffer(sampleBuffer: CMSampleBuffer) {
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else {
            return
        }
        guard let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription) else {
            return
        }

        let format = CustomAudioConverter.Format(
            numChannels: Int(asbd.pointee.mChannelsPerFrame),
            sampleRate: Int(asbd.pointee.mSampleRate)
        )
        if self.audioConverter?.format != format {
            self.audioConverter = CustomAudioConverter(asbd: asbd)
        }
        if let audioConverter = self.audioConverter {
            if let data = audioConverter.convert(sampleBuffer: sampleBuffer), !data.isEmpty {
                self.impl?.processAudioSampleBuffer(data: data)
            }
        }
    }
}

private final class CustomAudioConverter {
    struct Format: Equatable {
        let numChannels: Int
        let sampleRate: Int
    }

    let format: Format

    var currentInputDescription: UnsafePointer<AudioStreamBasicDescription>?
    var currentBuffer: AudioBuffer?
    var currentBufferOffset: UInt32 = 0

    init(asbd: UnsafePointer<AudioStreamBasicDescription>) {
        self.format = Format(
            numChannels: Int(asbd.pointee.mChannelsPerFrame),
            sampleRate: Int(asbd.pointee.mSampleRate)
        )
    }

    func convert(sampleBuffer: CMSampleBuffer) -> Data? {
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else {
            return nil
        }
        guard let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription) else {
            return nil
        }

        var bufferList = AudioBufferList()
        var blockBuffer: CMBlockBuffer? = nil
        CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: nil,
            bufferListOut: &bufferList,
            bufferListSize: MemoryLayout<AudioBufferList>.size,
            blockBufferAllocator: nil,
            blockBufferMemoryAllocator: nil,
            flags: kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment,
            blockBufferOut: &blockBuffer
        )
        let size = bufferList.mBuffers.mDataByteSize
        guard size != 0, let mData = bufferList.mBuffers.mData else {
            return nil
        }

        var outputDescription = AudioStreamBasicDescription(
            mSampleRate: 48000.0,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked,
            mBytesPerPacket: 2,
            mFramesPerPacket: 1,
            mBytesPerFrame: 2,
            mChannelsPerFrame: 1,
            mBitsPerChannel: 16,
            mReserved: 0
        )
        var maybeAudioConverter: AudioConverterRef?
        let _ = AudioConverterNew(asbd, &outputDescription, &maybeAudioConverter)
        guard let audioConverter = maybeAudioConverter else {
            return nil
        }

        self.currentBuffer = AudioBuffer(
            mNumberChannels: asbd.pointee.mChannelsPerFrame,
            mDataByteSize: UInt32(size),
            mData: mData
        )
        self.currentBufferOffset = 0
        self.currentInputDescription = asbd

        var numPackets: UInt32?
        let outputSize = 32768 * 2
        var outputBuffer = Data(count: outputSize)
        outputBuffer.withUnsafeMutableBytes { (outputBytes: UnsafeMutableRawBufferPointer) -> Void in
            var outputBufferList = AudioBufferList()
            outputBufferList.mNumberBuffers = 1
            outputBufferList.mBuffers.mNumberChannels = outputDescription.mChannelsPerFrame
            outputBufferList.mBuffers.mDataByteSize = UInt32(outputSize)
            outputBufferList.mBuffers.mData = outputBytes.baseAddress!

            var outputDataPacketSize = UInt32(outputSize) / outputDescription.mBytesPerPacket

            let result = AudioConverterFillComplexBuffer(
                audioConverter,
                converterComplexInputDataProc,
                Unmanaged.passUnretained(self).toOpaque(),
                &outputDataPacketSize,
                &outputBufferList,
                nil
            )
            if result == noErr {
                numPackets = outputDataPacketSize
            }
        }

        AudioConverterDispose(audioConverter)

        if let numPackets = numPackets {
            outputBuffer.count = Int(numPackets * outputDescription.mBytesPerPacket)
            return outputBuffer
        } else {
            return nil
        }
    }
}

private func converterComplexInputDataProc(inAudioConverter: AudioConverterRef, ioNumberDataPackets: UnsafeMutablePointer<UInt32>, ioData: UnsafeMutablePointer<AudioBufferList>, ioDataPacketDescription: UnsafeMutablePointer<UnsafeMutablePointer<AudioStreamPacketDescription>?>?, inUserData: UnsafeMutableRawPointer?) -> Int32 {
    guard let inUserData = inUserData else {
        ioNumberDataPackets.pointee = 0
        return 0
    }
    let instance = Unmanaged<CustomAudioConverter>.fromOpaque(inUserData).takeUnretainedValue()
    guard let currentBuffer = instance.currentBuffer else {
        ioNumberDataPackets.pointee = 0
        return 0
    }
    guard let currentInputDescription = instance.currentInputDescription else {
        ioNumberDataPackets.pointee = 0
        return 0
    }

    let numPacketsInBuffer = currentBuffer.mDataByteSize / currentInputDescription.pointee.mBytesPerPacket
    let numPacketsAvailable = numPacketsInBuffer - instance.currentBufferOffset / currentInputDescription.pointee.mBytesPerPacket

    let numPacketsToRead = min(ioNumberDataPackets.pointee, numPacketsAvailable)
    ioNumberDataPackets.pointee = numPacketsToRead

    ioData.pointee.mNumberBuffers = 1
    ioData.pointee.mBuffers.mData = currentBuffer.mData?.advanced(by: Int(instance.currentBufferOffset))
    ioData.pointee.mBuffers.mDataByteSize = currentBuffer.mDataByteSize - instance.currentBufferOffset
    ioData.pointee.mBuffers.mNumberChannels = currentBuffer.mNumberChannels

    instance.currentBufferOffset += numPacketsToRead * currentInputDescription.pointee.mBytesPerPacket

    return 0
}

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
