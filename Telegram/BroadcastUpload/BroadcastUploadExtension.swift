import Foundation
import ReplayKit
import CoreVideo
import TelegramVoip
import SwiftSignalKit
import BuildConfig
import BroadcastUploadHelpers
import AudioToolbox

private func rootPathForBasePath(_ appGroupPath: String) -> String {
    return appGroupPath + "/telegram-data"
}

@available(iOS 10.0, *)
@objc(BroadcastUploadSampleHandler) class BroadcastUploadSampleHandler: RPBroadcastSampleHandler {
    private var screencastBufferClientContext: IpcGroupCallBufferBroadcastContext?
    private var statusDisposable: Disposable?
    private var audioConverter: CustomAudioConverter?

    deinit {
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

        let logsPath = rootPath + "/logs/broadcast-logs"
        let _ = try? FileManager.default.createDirectory(atPath: logsPath, withIntermediateDirectories: true, attributes: nil)

        let screencastBufferClientContext = IpcGroupCallBufferBroadcastContext(basePath: rootPath + "/broadcast-coordination")
        self.screencastBufferClientContext = screencastBufferClientContext

        var wasRunning = false
        self.statusDisposable = (screencastBufferClientContext.status
        |> deliverOnMainQueue).start(next: { [weak self] status in
            guard let strongSelf = self else {
                return
            }
            switch status {
            case .active:
                wasRunning = true
            case let .finished(reason):
                if wasRunning {
                    strongSelf.finish(with: .screencastEnded)
                } else {
                    strongSelf.finish(with: reason)
                }
            }
        })
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

    private func processAudioSampleBuffer(sampleBuffer: CMSampleBuffer) {
        guard let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else {
            return
        }
        guard let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription) else {
            return
        }
        /*guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
            return
        }*/

        let format = CustomAudioConverter.Format(
            numChannels: Int(asbd.pointee.mChannelsPerFrame),
            sampleRate: Int(asbd.pointee.mSampleRate)
        )
        if self.audioConverter?.format != format {
            self.audioConverter = CustomAudioConverter(asbd: asbd)
        }
        if let audioConverter = self.audioConverter {
            if let data = audioConverter.convert(sampleBuffer: sampleBuffer), !data.isEmpty {
                self.screencastBufferClientContext?.writeAudioData(data: data)
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
