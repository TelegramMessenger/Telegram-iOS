import AudioToolbox
import AVFAudio
import AVFoundation
import CoreMedia
import TelegramCore

final class HLSPlayerAudioOutput {

    private(set) var volume: Double = 1.0

    private var audioQueue: AudioQueueRef?
    private var audioQueueBuffer: AudioQueueBufferRef?
    private var streamFormat: AudioStreamBasicDescription

    init() {
        streamFormat = AudioStreamBasicDescription()

        congigure()
    }

    deinit {
        if let audioQueue = audioQueue {
            AudioQueueStop(audioQueue, false)
        }
        audioQueueBuffer?.deallocate()
    }

    func play() {
        guard let audioQueue = audioQueue else { return }
        AudioQueueStart(audioQueue, nil)
    }

    func pause() {
        guard let audioQueue = audioQueue else { return }
        AudioQueueStop(audioQueue, true)
    }

    func stop() {
        if let audioQueue = audioQueue {
            AudioQueueStop(audioQueue, false)
        }
        audioQueueBuffer?.deallocate()
    }

    func volume(at newValue: Double) {
        guard let audioQueue = audioQueue else { return }
        let errorSetVolume = AudioQueueSetParameter(audioQueue, kAudioQueueParam_Volume, Float32(newValue))
        if errorSetVolume != noErr {
            Logger.shared.log("HLSPlayer", "Error AudioQueueSetParameterVolume \(errorSetVolume)")
            return
        }
        self.volume = newValue
    }

    func rendering(at sampleBuffer: CMSampleBuffer) -> Bool {
        var bufferListSize = 0
        let errorBlockBufferInit = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(sampleBuffer, bufferListSizeNeededOut: &bufferListSize, bufferListOut: nil, bufferListSize: 0, blockBufferAllocator: nil, blockBufferMemoryAllocator: nil, flags: kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment, blockBufferOut: nil)
        if errorBlockBufferInit != noErr {
            Logger.shared.log("HLSPlayer", "Error AudioBufferListWithRetainedBlockBuffer \(errorBlockBufferInit)")
            return false
        }

        var blockBuffer: CMBlockBuffer?
        let mData = UnsafeMutablePointer<AudioBuffer>.allocate(capacity: 1024)
        var bufferList = AudioBufferList(mNumberBuffers: UInt32(bufferListSize), mBuffers: AudioBuffer(mNumberChannels: 2, mDataByteSize: 1024, mData: mData))
        let errorBlockBuffer = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(sampleBuffer, bufferListSizeNeededOut: &bufferListSize, bufferListOut: &bufferList, bufferListSize: bufferListSize, blockBufferAllocator: kCFAllocatorDefault, blockBufferMemoryAllocator: kCFAllocatorDefault, flags: kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment, blockBufferOut: &blockBuffer)
        if errorBlockBuffer != noErr {
            Logger.shared.log("HLSPlayer", "Error AudioBufferListWithRetainedBlockBuffer \(errorBlockBuffer)")
            return false
        }

        guard let audioQueueBuffer = audioQueueBuffer, let audioQueue = audioQueue else { return false }

        if nil == memcpy(self.audioQueueBuffer?.pointee.mAudioData, bufferList.mBuffers.mData, Int(bufferList.mBuffers.mDataByteSize)) {
            Logger.shared.log("HLSPlayer", "Error memcpy audioQueueBuffer")
        }

        let errorEnqueue = AudioQueueEnqueueBuffer(audioQueue, audioQueueBuffer, 0, nil)
        if errorEnqueue != noErr {
            Logger.shared.log("HLSPlayer", "Error AudioQueueEnqueueBuffer \(errorEnqueue)")
            return false
        }
        return true
    }

    func track(at asset: AVAsset) -> AVAssetReaderTrackOutput? {
        guard let track = asset.tracks(withMediaType: .audio).first else {
            return nil
        }
        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 48000.0,
            AVNumberOfChannelsKey: 2,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
        ]
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings)
        output.alwaysCopiesSampleData = false
        return output
    }
}

// MARK: - Configuration

private extension HLSPlayerAudioOutput {

    func congigure() {
        streamFormat.mSampleRate = 48000.0
        streamFormat.mFormatID = kAudioFormatLinearPCM
        streamFormat.mFormatFlags = kAudioFormatFlagIsNonInterleaved | kAudioFormatFlagIsSignedInteger
        streamFormat.mBytesPerPacket = 4
        streamFormat.mFramesPerPacket = 1
        streamFormat.mBytesPerFrame = 4
        streamFormat.mChannelsPerFrame = 2
        streamFormat.mBitsPerChannel = 16
        streamFormat.mReserved = 0

        congigureAudioQueue()
    }

    func congigureAudioQueue() {
        let errorNewOutput = AudioQueueNewOutput(&streamFormat, { _, _, _ in }, nil, nil, nil, 0, &audioQueue)
        if errorNewOutput != noErr {
            Logger.shared.log("HLSPlayer", "Error AudioQueueNewOutput \(errorNewOutput)")
        }

        guard let audioQueue = audioQueue else { return }

        let errorAllocate = AudioQueueAllocateBuffer(audioQueue, 4096, &self.audioQueueBuffer)
        if errorAllocate != noErr {
            Logger.shared.log("HLSPlayer", "Error AudioQueueAllocateBuffer \(errorAllocate)")
        }
    }
}
