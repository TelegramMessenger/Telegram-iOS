import Foundation
import SwiftSignalKit
import CoreMedia
import AVFoundation
import TelegramCore
import TelegramAudio
import UniversalMediaPlayer
import AccountContext
import OpusBinding
import ChatPresentationInterfaceState

private let kOutputBus: UInt32 = 0
private let kInputBus: UInt32 = 1

private func audioRecorderNativeStreamDescription(sampleRate: Float64) -> AudioStreamBasicDescription {
    var canonicalBasicStreamDescription = AudioStreamBasicDescription()
    canonicalBasicStreamDescription.mSampleRate = sampleRate
    canonicalBasicStreamDescription.mFormatID = kAudioFormatLinearPCM
    canonicalBasicStreamDescription.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked
    canonicalBasicStreamDescription.mFramesPerPacket = 1
    canonicalBasicStreamDescription.mChannelsPerFrame = 1
    canonicalBasicStreamDescription.mBitsPerChannel = 16
    canonicalBasicStreamDescription.mBytesPerPacket = 2
    canonicalBasicStreamDescription.mBytesPerFrame = 2
    return canonicalBasicStreamDescription
}

private var nextRecorderContextId: Int32 = 0
private func getNextRecorderContextId() -> Int32 {
    return OSAtomicIncrement32(&nextRecorderContextId)
}

private final class RecorderContextHolder {
    weak var context: ManagedAudioRecorderContext?
    
    init(context: ManagedAudioRecorderContext?) {
        self.context = context
    }
}

private final class AudioUnitHolder {
    let queue: Queue
    let audioUnit: Atomic<AudioUnit?>
    
    init(queue: Queue, audioUnit: Atomic<AudioUnit?>) {
        self.queue = queue
        self.audioUnit = audioUnit
    }
}

private var audioRecorderContexts: [Int32: RecorderContextHolder] = [:]
private var audioUnitHolders = Atomic<[Int32: AudioUnitHolder]>(value: [:])

private func addAudioRecorderContext(_ id: Int32, _ context: ManagedAudioRecorderContext) {
    audioRecorderContexts[id] = RecorderContextHolder(context: context)
}

private func removeAudioRecorderContext(_ id: Int32) {
    audioRecorderContexts.removeValue(forKey: id)
}

private func addAudioUnitHolder(_ id: Int32, _ queue: Queue, _ audioUnit: Atomic<AudioUnit?>) {
    let _ = audioUnitHolders.modify { dict in
        var dict = dict
        dict[id] = AudioUnitHolder(queue: queue, audioUnit: audioUnit)
        return dict
    }
}

private func removeAudioUnitHolder(_ id: Int32) {
    let _ = audioUnitHolders.modify { dict in
        var dict = dict
        dict.removeValue(forKey: id)
        return dict
    }
}

private func withAudioRecorderContext(_ id: Int32, _ f: (ManagedAudioRecorderContext?) -> Void) {
    if let holder = audioRecorderContexts[id], let context = holder.context {
        f(context)
    } else {
        f(nil)
    }
}

private func withAudioUnitHolder(_ id: Int32, _ f: (Atomic<AudioUnit?>, Queue) -> Void) {
    let audioUnitAndQueue = audioUnitHolders.with { dict -> (Atomic<AudioUnit?>, Queue)? in
        if let record = dict[id] {
            return (record.audioUnit, record.queue)
        } else {
            return nil
        }
    }
    if let (audioUnit, queue) = audioUnitAndQueue {
        f(audioUnit, queue)
    }
}

private func rendererInputProc(refCon: UnsafeMutableRawPointer, ioActionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>, inTimeStamp: UnsafePointer<AudioTimeStamp>, inBusNumber: UInt32, inNumberFrames: UInt32, ioData: UnsafeMutablePointer<AudioBufferList>?) -> OSStatus {
    let id = Int32(intptr_t(bitPattern: refCon))
    
    withAudioUnitHolder(id, { (holder, queue) in
        var buffer = AudioBuffer()
        buffer.mNumberChannels = 1;
        buffer.mDataByteSize = inNumberFrames * 2;
        buffer.mData = malloc(Int(inNumberFrames) * 2)
        
        var bufferList = AudioBufferList(mNumberBuffers: 1, mBuffers: buffer)
        
        var status = noErr
        holder.with { audioUnit in
            if let audioUnit = audioUnit {
                status = AudioUnitRender(audioUnit, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, &bufferList)
            } else {
                status = kAudioUnitErr_FailedInitialization
            }
        }
        
        if status == noErr {
            queue.async {
                withAudioRecorderContext(id, { context in
                    if let context = context {
                        context.processAndDisposeAudioBuffer(buffer)
                    } else {
                        free(buffer.mData)
                    }
                })
            }
        } else {
            free(buffer.mData)
            Logger.shared.log("ManagedAudioRecorder", "AudioUnitRender returned \(status)")
        }
    })
    
    return noErr
}

private let beginToneData: TonePlayerData? = {
    guard let url = Bundle.main.url(forResource: "begin_record", withExtension: "mp3") else {
        return nil
    }
    return loadTonePlayerData(path: url.path)
}()

final class ManagedAudioRecorderContext {
    private let id: Int32
    private let micLevel: ValuePromise<Float>
    private let recordingState: ValuePromise<AudioRecordingState>
    private let beginWithTone: Bool
    private let beganWithTone: (Bool) -> Void
    
    private var paused = true
    
    private let queue: Queue
    private let mediaManager: MediaManager
    private let oggWriter: TGOggOpusWriter
    private let dataItem: TGDataItem
    private var audioBuffer = Data()
    
    private let audioUnit = Atomic<AudioUnit?>(value: nil)
    
    private var compressedWaveformSamples = Data()
    private var currentPeak: Int64 = 0
    private var currentPeakCount: Int = 0
    private var peakCompressionFactor: Int = 1
    
    private var micLevelPeak: Int16 = 0
    private var micLevelPeakCount: Int = 0
    private var audioLevelPeakUpdate: Double = 0.0
    
    fileprivate var isPaused = false
    
    private var recordingStateUpdateTimestamp: Double?
    
    private var hasAudioSession = false
    private var audioSessionDisposable: Disposable?
    
    //private var tonePlayer: TonePlayer?
    private var toneRenderer: MediaPlayerAudioRenderer?
    private var toneRendererAudioSession: MediaPlayerAudioSessionCustomControl?
    private var toneRendererAudioSessionActivated = false
    
    private var processSamples = false
    
    private var toneTimer: SwiftSignalKit.Timer?
    private var idleTimerExtensionDisposable: Disposable?
    
    init(queue: Queue, mediaManager: MediaManager, pushIdleTimerExtension: @escaping () -> Disposable, micLevel: ValuePromise<Float>, recordingState: ValuePromise<AudioRecordingState>, beginWithTone: Bool, beganWithTone: @escaping (Bool) -> Void) {
        assert(queue.isCurrent())
        
        self.id = getNextRecorderContextId()
        self.micLevel = micLevel
        self.beginWithTone = beginWithTone
        self.beganWithTone = beganWithTone
        
        self.recordingState = recordingState
        
        self.queue = queue
        self.mediaManager = mediaManager
        self.dataItem = TGDataItem()
        self.oggWriter = TGOggOpusWriter()
        
        if beginWithTone, let toneData = audioRecordingToneData {
            self.processSamples = false
            let toneRenderer = MediaPlayerAudioRenderer(audioSession: .custom({ [weak self] control in
                queue.async {
                    if let strongSelf = self {
                        strongSelf.toneRendererAudioSession = control
                        if !strongSelf.paused && strongSelf.hasAudioSession {
                            strongSelf.toneRendererAudioSessionActivated = true
                            control.activate()
                        }
                    }
                }
                return ActionDisposable {
                }
            }), playAndRecord: true, ambient: false, forceAudioToSpeaker: false, baseRate: 1.0, audioLevelPipe: ValuePipe<Float>(), updatedRate: {
            }, audioPaused: {})
            self.toneRenderer = toneRenderer
            
            let toneDataOffset = Atomic<Int>(value: 0)
            toneRenderer.beginRequestingFrames(queue: DispatchQueue.global(), takeFrame: {
                let frameSize = 44100
                
                var takeRange: Range<Int>?
                let _ = toneDataOffset.modify { current in
                    let count = min(toneData.count - current, frameSize)
                    if count > 0 {
                        takeRange = current ..< (current + count)
                    }
                    return current + count
                }
                
                if let takeRange = takeRange {
                    var blockBuffer: CMBlockBuffer?
                    
                    let bytes = malloc(takeRange.count)!
                    toneData.withUnsafeBytes { rawDataBytes -> Void in
                        let dataBytes = rawDataBytes.baseAddress!.assumingMemoryBound(to: UInt8.self)

                        memcpy(bytes, dataBytes.advanced(by: takeRange.lowerBound), takeRange.count)
                    }
                    let status = CMBlockBufferCreateWithMemoryBlock(allocator: nil, memoryBlock: bytes, blockLength: takeRange.count, blockAllocator: nil, customBlockSource: nil, offsetToData: 0, dataLength: takeRange.count, flags: 0, blockBufferOut: &blockBuffer)
                    if status != noErr {
                        return .finished
                    }
                    
                    let sampleCount = takeRange.count / 2
                    
                    let pts = CMTime(value: Int64(takeRange.lowerBound / 2), timescale: 44100)
                    var timingInfo = CMSampleTimingInfo(duration: CMTime(value: Int64(sampleCount), timescale: 44100), presentationTimeStamp: pts, decodeTimeStamp: pts)
                    var sampleBuffer: CMSampleBuffer?
                    var sampleSize = takeRange.count
                    guard CMSampleBufferCreate(allocator: nil, dataBuffer: blockBuffer, dataReady: true, makeDataReadyCallback: nil, refcon: nil, formatDescription: nil, sampleCount: 1, sampleTimingEntryCount: 1, sampleTimingArray: &timingInfo, sampleSizeEntryCount: 1, sampleSizeArray: &sampleSize, sampleBufferOut: &sampleBuffer) == noErr else {
                        return .finished
                    }
                    
                    if let sampleBuffer = sampleBuffer {
                        return .frame(MediaTrackFrame(type: .audio, sampleBuffer: sampleBuffer, resetDecoder: false, decoded: true))
                    } else {
                        return .finished
                    }
                } else {
                    return .finished
                }
            })
            toneRenderer.start()
            let toneTimer = SwiftSignalKit.Timer(timeout: 0.05, repeat: true, completion: { [weak self] in
                if let strongSelf = self {
                    var wait = false
                    
                    if let toneRenderer = strongSelf.toneRenderer {
                        let toneTime = CMTimebaseGetTime(toneRenderer.audioTimebase)
                        let endTime = CMTime(value: Int64(toneData.count / 2), timescale: 44100)
                        if CMTimeCompare(toneTime, endTime) >= 0 {
                            strongSelf.processSamples = true
                        } else {
                            wait = true
                        }
                    }
                    
                    if !wait {
                        strongSelf.toneTimer?.invalidate()
                    }
                }
                }, queue: queue)
            self.toneTimer = toneTimer
            toneTimer.start()
        } else {
            self.processSamples = true
        }
        
        /*if beginWithTone, let beginToneData = beginToneData {
         self.tonePlayer = TonePlayer()
         self.tonePlayer?.play(data: beginToneData, completed: { [weak self] in
         queue.async {
         guard let strongSelf = self else {
         return
         }
         let toneTimer = SwiftSignalKit.Timer(timeout: 0.3, repeat: false, completion: { [weak self] in
         guard let strongSelf = self else {
         return
         }
         strongSelf.processSamples = true
         }, queue: queue)
         strongSelf.toneTimer = toneTimer
         toneTimer.start()
         }
         })
         } else {
         self.processSamples = true
         }*/
        
        addAudioRecorderContext(self.id, self)
        addAudioUnitHolder(self.id, queue, self.audioUnit)
        
        self.oggWriter.begin(with: self.dataItem)
        
        self.idleTimerExtensionDisposable = (Signal<Void, NoError> { subscriber in
            return pushIdleTimerExtension()
        } |> delay(5.0, queue: queue)).start()
    }
    
    deinit {
        assert(self.queue.isCurrent())
        
        self.idleTimerExtensionDisposable?.dispose()
        
        removeAudioRecorderContext(self.id)
        removeAudioUnitHolder(self.id)
        
        self.stop()
        
        self.audioSessionDisposable?.dispose()
        
        self.toneRenderer?.stop()
        self.toneTimer?.invalidate()
    }
    
    func start() {
        assert(self.queue.isCurrent())
        
        self.paused = false
        
        var desc = AudioComponentDescription()
        desc.componentType = kAudioUnitType_Output
        desc.componentSubType = kAudioUnitSubType_RemoteIO
        desc.componentFlags = 0
        desc.componentFlagsMask = 0
        desc.componentManufacturer = kAudioUnitManufacturer_Apple
        guard let inputComponent = AudioComponentFindNext(nil, &desc) else {
            return
        }
        var maybeAudioUnit: AudioUnit? = nil
        AudioComponentInstanceNew(inputComponent, &maybeAudioUnit)
        
        guard let audioUnit = maybeAudioUnit else {
            return
        }
        
        var one: UInt32 = 1
        guard AudioUnitSetProperty(audioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, &one, 4) == noErr else {
            AudioComponentInstanceDispose(audioUnit)
            return
        }
        
        var audioStreamDescription = audioRecorderNativeStreamDescription(sampleRate: 48000)
        guard AudioUnitSetProperty(audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &audioStreamDescription, UInt32(MemoryLayout<AudioStreamBasicDescription>.size)) == noErr else {
            AudioComponentInstanceDispose(audioUnit)
            return
        }
        
        guard AudioUnitSetProperty(audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &audioStreamDescription, UInt32(MemoryLayout<AudioStreamBasicDescription>.size)) == noErr else {
            AudioComponentInstanceDispose(audioUnit)
            return
        }
        
        var callbackStruct = AURenderCallbackStruct()
        callbackStruct.inputProc = rendererInputProc
        callbackStruct.inputProcRefCon = UnsafeMutableRawPointer(bitPattern: intptr_t(self.id))
        guard AudioUnitSetProperty(audioUnit, kAudioOutputUnitProperty_SetInputCallback, kAudioUnitScope_Global, 0, &callbackStruct, UInt32(MemoryLayout<AURenderCallbackStruct>.size)) == noErr else {
            AudioComponentInstanceDispose(audioUnit)
            return
        }
        
        var zero: UInt32 = 1
        guard AudioUnitSetProperty(audioUnit, kAudioUnitProperty_ShouldAllocateBuffer, kAudioUnitScope_Output, 0, &zero, 4) == noErr else {
            AudioComponentInstanceDispose(audioUnit)
            return
        }
        
        guard AudioUnitInitialize(audioUnit) == noErr else {
            AudioComponentInstanceDispose(audioUnit)
            return
        }
        
        let _ = self.audioUnit.swap(audioUnit)
        
        if self.audioSessionDisposable == nil {
            let queue = self.queue
            self.audioSessionDisposable = self.mediaManager.audioSession.push(audioSessionType: .record(speaker: self.beginWithTone), activate: { [weak self] state in
                queue.async {
                    if let strongSelf = self, !strongSelf.paused {
                        strongSelf.hasAudioSession = true
                        strongSelf.audioSessionAcquired(headset: state.isHeadsetConnected)
                    }
                }
            }, deactivate: { [weak self] _ in
                return Signal { subscriber in
                    queue.async {
                        if let strongSelf = self {
                            strongSelf.hasAudioSession = false
                            strongSelf.stop()
                            strongSelf.recordingState.set(.stopped)
                            subscriber.putCompletion()
                        }
                    }
                    
                    return EmptyDisposable
                }
            })
        }
    }
    
    func audioSessionAcquired(headset: Bool) {
        if let toneRenderer = self.toneRenderer, headset || self.beginWithTone {
            self.beganWithTone(true)
            if !self.toneRendererAudioSessionActivated {
                self.toneRendererAudioSessionActivated = true
                self.toneRendererAudioSession?.activate()
            }
            toneRenderer.setRate(1.0)
        } else {
            self.processSamples = true
            self.beganWithTone(false)
        }
        
        if let audioUnit = self.audioUnit.with({ $0 }) {
            guard AudioOutputUnitStart(audioUnit) == noErr else {
                self.stop()
                return
            }
        }
    }
    
    func stop() {
        assert(self.queue.isCurrent())
        
        self.paused = true
        
        if let audioUnit = self.audioUnit.swap(nil) {
            var status = noErr
            
            status = AudioOutputUnitStop(audioUnit)
            if status != noErr {
                Logger.shared.log("ManagedAudioRecorder", "AudioOutputUnitStop returned \(status)")
            }
            
            status = AudioUnitUninitialize(audioUnit)
            if status != noErr {
                Logger.shared.log("ManagedAudioRecorder", "AudioUnitUninitialize returned \(status)")
            }
            
            status = AudioComponentInstanceDispose(audioUnit)
            if status != noErr {
                Logger.shared.log("ManagedAudioRecorder", "AudioComponentInstanceDispose returned \(status)")
            }
        }
        
        if let toneRenderer = self.toneRenderer, self.toneRendererAudioSessionActivated {
            self.toneRendererAudioSessionActivated = false
            toneRenderer.stop()
        }
        
        let audioSessionDisposable = self.audioSessionDisposable
        self.audioSessionDisposable = nil
        audioSessionDisposable?.dispose()
    }
    
    func processAndDisposeAudioBuffer(_ buffer: AudioBuffer) {
        assert(self.queue.isCurrent())
        
        defer {
            free(buffer.mData)
        }
        
        if !self.processSamples {
            return
        }
        
        let millisecondsPerPacket = 60
        let encoderPacketSizeInBytes = 16000 / 1000 * millisecondsPerPacket * 2
        
        let currentEncoderPacket = malloc(encoderPacketSizeInBytes)!
        defer {
            free(currentEncoderPacket)
        }
        
        var bufferOffset = 0
        
        while true {
            var currentEncoderPacketSize = 0
            
            while currentEncoderPacketSize < encoderPacketSizeInBytes {
                if audioBuffer.count != 0 {
                    let takenBytes = min(self.audioBuffer.count, encoderPacketSizeInBytes - currentEncoderPacketSize)
                    if takenBytes != 0 {
                        self.audioBuffer.withUnsafeBytes { rawBytes -> Void in
                            let bytes = rawBytes.baseAddress!.assumingMemoryBound(to: Int8.self)

                            memcpy(currentEncoderPacket.advanced(by: currentEncoderPacketSize), bytes, takenBytes)
                        }
                        self.audioBuffer.replaceSubrange(0 ..< takenBytes, with: Data())
                        currentEncoderPacketSize += takenBytes
                    }
                } else if bufferOffset < Int(buffer.mDataByteSize) {
                    let takenBytes = min(Int(buffer.mDataByteSize) - bufferOffset, encoderPacketSizeInBytes - currentEncoderPacketSize)
                    if takenBytes != 0 {
                        memcpy(currentEncoderPacket.advanced(by: currentEncoderPacketSize), buffer.mData?.advanced(by: bufferOffset), takenBytes)

                        bufferOffset += takenBytes
                        currentEncoderPacketSize += takenBytes
                    }
                } else {
                    break
                }
            }
            
            if currentEncoderPacketSize < encoderPacketSizeInBytes {
                self.audioBuffer.append(currentEncoderPacket.assumingMemoryBound(to: UInt8.self), count: currentEncoderPacketSize)
                break
            } else {
                self.processWaveformPreview(samples: currentEncoderPacket.assumingMemoryBound(to: Int16.self), count: currentEncoderPacketSize / 2)
                
                self.oggWriter.writeFrame(currentEncoderPacket.assumingMemoryBound(to: UInt8.self), frameByteCount: UInt(currentEncoderPacketSize))
                
                let timestamp = CACurrentMediaTime()
                if self.recordingStateUpdateTimestamp == nil || self.recordingStateUpdateTimestamp! < timestamp + 0.1 {
                    self.recordingStateUpdateTimestamp = timestamp
                    self.recordingState.set(.recording(duration: oggWriter.encodedDuration(), durationMediaTimestamp: timestamp))
                }
            }
        }
    }
    
    func processWaveformPreview(samples: UnsafePointer<Int16>, count: Int) {
        for i in 0 ..< count {
            var sample = samples.advanced(by: i).pointee
            if sample < 0 {
                if sample == Int16.min {
                    sample = Int16.max
                } else {
                    sample = -sample
                }
            }
            
            self.currentPeak = max(Int64(sample), self.currentPeak)
            self.currentPeakCount += 1
            if self.currentPeakCount == self.peakCompressionFactor {
                var compressedPeak = self.currentPeak
                withUnsafeBytes(of: &compressedPeak, { buffer in
                    self.compressedWaveformSamples.append(buffer.bindMemory(to: UInt8.self))
                })
                self.currentPeak = 0
                self.currentPeakCount = 0
                
                let compressedSampleCount = self.compressedWaveformSamples.count / 2
                if compressedSampleCount == 200 {
                    self.compressedWaveformSamples.withUnsafeMutableBytes { rawCompressedSamples -> Void in
                        let compressedSamples = rawCompressedSamples.baseAddress!.assumingMemoryBound(to: Int16.self)

                        for i in 0 ..< 100 {
                            let maxSample = Int64(max(compressedSamples[i * 2 + 0], compressedSamples[i * 2 + 1]))
                            compressedSamples[i] = Int16(maxSample)
                        }
                    }
                    self.compressedWaveformSamples.count = 100 * 2
                    self.peakCompressionFactor *= 2
                }
            }
            
            if self.micLevelPeak < sample {
                self.micLevelPeak = sample
            }
            self.micLevelPeakCount += 1
            
            if self.micLevelPeakCount >= 1200 {
                let level = Float(self.micLevelPeak) / 4000.0
                /*let timestamp = CFAbsoluteTimeGetCurrent()
                if !self.audioLevelPeakUpdate.isZero {
                    let delta = timestamp - self.audioLevelPeakUpdate
                    print("level = \(level), delta = \(delta)")
                }
                self.audioLevelPeakUpdate = timestamp*/
                self.micLevel.set(level)
                self.micLevelPeak = 0
                self.micLevelPeakCount = 0
            }
        }
    }
    
    func takeData() -> RecordedAudioData? {
        if self.oggWriter.writeFrame(nil, frameByteCount: 0) {
            let scaledSamplesMemory = malloc(100 * 2)!
            let scaledSamples: UnsafeMutablePointer<Int16> = scaledSamplesMemory.assumingMemoryBound(to: Int16.self)
            defer {
                free(scaledSamplesMemory)
            }
            memset(scaledSamples, 0, 100 * 2);
            var waveform: Data?
            
            let count = self.compressedWaveformSamples.count / 2
            self.compressedWaveformSamples.withUnsafeMutableBytes { rawSamples -> Void in
                let samples = rawSamples.baseAddress!.assumingMemoryBound(to: Int16.self)

                for i in 0 ..< count {
                    let sample = samples[i]
                    let index = i * 100 / count
                    if (scaledSamples[index] < sample) {
                        scaledSamples[index] = sample;
                    }
                }
                
                var peak: Int16 = 0
                var sumSamples: Int64 = 0
                for i in 0 ..< 100 {
                    let sample = scaledSamples[i]
                    if peak < sample {
                        peak = sample
                    }
                    sumSamples += Int64(sample)
                }
                var calculatedPeak: UInt16 = 0
                calculatedPeak = UInt16((Double(sumSamples) * 1.8 / 100.0))
                
                if calculatedPeak < 2500 {
                    calculatedPeak = 2500
                }
                
                for i in 0 ..< 100 {
                    let sample: UInt16 = UInt16(Int64(scaledSamples[i]))
                    let minPeak = min(Int64(sample), Int64(calculatedPeak))
                    let resultPeak = minPeak * 31 / Int64(calculatedPeak)
                    scaledSamples[i] = Int16(clamping: min(31, resultPeak))
                }
                
                let resultWaveform = AudioWaveform(samples: Data(bytes: scaledSamplesMemory, count: 100 * 2), peak: 31)
                let bitstream = resultWaveform.makeBitstream()
                waveform = AudioWaveform(bitstream: bitstream, bitsPerSample: 5).makeBitstream()
            }
            
            return RecordedAudioData(compressedData: self.dataItem.data(), duration: self.oggWriter.encodedDuration(), waveform: waveform)
        } else {
            return nil
        }
    }
}

final class ManagedAudioRecorderImpl: ManagedAudioRecorder {
    private let queue = Queue()
    private var contextRef: Unmanaged<ManagedAudioRecorderContext>?
    private let micLevelValue = ValuePromise<Float>(0.0)
    private let recordingStateValue = ValuePromise<AudioRecordingState>(.paused(duration: 0.0))
    
    let beginWithTone: Bool
    
    var micLevel: Signal<Float, NoError> {
        return self.micLevelValue.get()
    }
    
    var recordingState: Signal<AudioRecordingState, NoError> {
        return self.recordingStateValue.get()
    }
    
    init(mediaManager: MediaManager, pushIdleTimerExtension: @escaping () -> Disposable, beginWithTone: Bool, beganWithTone: @escaping (Bool) -> Void) {
        self.beginWithTone = beginWithTone
        self.queue.async {
            let context = ManagedAudioRecorderContext(queue: self.queue, mediaManager: mediaManager, pushIdleTimerExtension: pushIdleTimerExtension, micLevel: self.micLevelValue, recordingState: self.recordingStateValue, beginWithTone: beginWithTone, beganWithTone: beganWithTone)
            self.contextRef = Unmanaged.passRetained(context)
        }
    }
    
    deinit {
        let contextRef = self.contextRef
        self.queue.async {
            contextRef?.release()
        }
    }
    
    func start() {
        self.queue.async {
            if let context = self.contextRef?.takeUnretainedValue() {
                context.start()
            }
        }
    }
    
    func stop() {
        self.queue.async {
            if let context = self.contextRef?.takeUnretainedValue() {
                context.stop()
            }
        }
    }
    
    func takenRecordedData() -> Signal<RecordedAudioData?, NoError> {
        return Signal { subscriber in
            self.queue.async {
                if let context = self.contextRef?.takeUnretainedValue() {
                    subscriber.putNext(context.takeData())
                    subscriber.putCompletion()
                } else {
                    subscriber.putNext(nil)
                    subscriber.putCompletion()
                }
            }
            return EmptyDisposable
        }
    }
}
