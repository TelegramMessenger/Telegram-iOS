import Foundation
import SwiftSignalKit
import CoreMedia
import AVFoundation
import TelegramCore
import TelegramAudio

private enum AudioPlayerRendererState {
    case paused
    case playing(rate: Double, didSetRate: Bool)
}

private final class AudioPlayerRendererBufferContext {
    var state: AudioPlayerRendererState = .paused
    let timebase: CMTimebase
    let buffer: RingByteBuffer
    var audioLevelPeak: Int16 = 0
    var audioLevelPeakCount: Int = 0
    var audioLevelPeakUpdate: Double = 0.0
    var bufferMaxChannelSampleIndex: Int64 = 0
    var lowWaterSize: Int
    var notifyLowWater: () -> Void
    var updatedRate: () -> Void
    var updatedLevel: (Float) -> Void
    var notifiedLowWater = false
    var overflowData = Data()
    var overflowDataMaxChannelSampleIndex: Int64 = 0
    var renderTimestampTick: Int64 = 0
    
    init(timebase: CMTimebase, buffer: RingByteBuffer, lowWaterSize: Int, notifyLowWater: @escaping () -> Void, updatedRate: @escaping () -> Void, updatedLevel: @escaping (Float) -> Void) {
        self.timebase = timebase
        self.buffer = buffer
        self.lowWaterSize = lowWaterSize
        self.notifyLowWater = notifyLowWater
        self.updatedRate = updatedRate
        self.updatedLevel = updatedLevel
    }
}

private let audioPlayerRendererBufferContextMap = Atomic<[Int32: Atomic<AudioPlayerRendererBufferContext>]>(value: [:])
private let audioPlayerRendererQueue = Queue()

private var _nextPlayerRendererBufferContextId: Int32 = 1
private func registerPlayerRendererBufferContext(_ context: Atomic<AudioPlayerRendererBufferContext>) -> Int32 {
    var id: Int32 = 0
    
    let _ = audioPlayerRendererBufferContextMap.modify { contextMap in
        id = _nextPlayerRendererBufferContextId
        _nextPlayerRendererBufferContextId += 1
        
        var contextMap = contextMap
        contextMap[id] = context
        return contextMap
    }
    return id
}

private func unregisterPlayerRendererBufferContext(_ id: Int32) {
    let _ = audioPlayerRendererBufferContextMap.modify { contextMap in
        var contextMap = contextMap
        let _ = contextMap.removeValue(forKey: id)
        return contextMap
    }
}

private func withPlayerRendererBuffer(_ id: Int32, _ f: (Atomic<AudioPlayerRendererBufferContext>) -> Void) {
    audioPlayerRendererBufferContextMap.with { contextMap in
        if let context = contextMap[id] {
            f(context)
        }
    }
}

private let kOutputBus: UInt32 = 0
private let kInputBus: UInt32 = 1

private func rendererInputProc(refCon: UnsafeMutableRawPointer, ioActionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>, inTimeStamp: UnsafePointer<AudioTimeStamp>, inBusNumber: UInt32, inNumberFrames: UInt32, ioData: UnsafeMutablePointer<AudioBufferList>?) -> OSStatus {
    guard let ioData = ioData else {
        return noErr
    }
    
    let bufferList = UnsafeMutableAudioBufferListPointer(ioData)
    
    var rendererFillOffset = (0, 0)
    var notifyLowWater: (() -> Void)?
    var updatedRate: (() -> Void)?
    
    withPlayerRendererBuffer(Int32(intptr_t(bitPattern: refCon)), { context in
        context.with { context in
            switch context.state {
                case let .playing(rate, didSetRate):
                    if context.buffer.availableBytes != 0 {
                        let sampleIndex = context.bufferMaxChannelSampleIndex - Int64(context.buffer.availableBytes / (2 *
                            2))
                        
                        if !didSetRate {
                            context.state = .playing(rate: rate, didSetRate: true)
                            let masterClock = CMTimebaseCopySource(context.timebase)
                            CMTimebaseSetRateAndAnchorTime(context.timebase, rate: rate, anchorTime: CMTimeMake(value: sampleIndex, timescale: 44100), immediateSourceTime: CMSyncGetTime(masterClock))
                            updatedRate = context.updatedRate
                        } else {
                            context.renderTimestampTick += 1
                            if context.renderTimestampTick % 1000 == 0 {
                                let delta = (Double(sampleIndex) / 44100.0) - CMTimeGetSeconds(CMTimebaseGetTime(context.timebase))
                                if delta > 0.01 {
                                    CMTimebaseSetTime(context.timebase, time: CMTimeMake(value: sampleIndex, timescale: 44100))
                                    updatedRate = context.updatedRate
                                }
                            }
                        }
                        
                        let rendererBuffer = context.buffer
                        
                        while rendererFillOffset.0 < bufferList.count {
                            if let bufferData = bufferList[rendererFillOffset.0].mData {
                                let bufferDataSize = Int(bufferList[rendererFillOffset.0].mDataByteSize)
                                
                                let dataOffset = rendererFillOffset.1
                                if dataOffset == bufferDataSize {
                                    rendererFillOffset = (rendererFillOffset.0 + 1, 0)
                                    continue
                                }
                                
                                let consumeCount = bufferDataSize - dataOffset
                                
                                let actualConsumedCount = rendererBuffer.dequeue(bufferData.advanced(by: dataOffset), count: consumeCount)
                                
                                var samplePtr = bufferData.advanced(by: dataOffset).assumingMemoryBound(to: Int16.self)
                                for _ in 0 ..< actualConsumedCount / 4 {
                                    var sample: Int16 = samplePtr.pointee
                                    if sample < 0 {
                                        if sample <= -32768 {
                                            sample = Int16.max
                                        } else {
                                            sample = -sample
                                        }
                                    }
                                    samplePtr = samplePtr.advanced(by: 2)
                                    
                                    if context.audioLevelPeak < sample {
                                        context.audioLevelPeak = sample
                                    }
                                    context.audioLevelPeakCount += 1
                                    
                                    if context.audioLevelPeakCount >= 1200 {
                                        let level = Float(context.audioLevelPeak) / (4000.0)
                                        /*let timestamp = CFAbsoluteTimeGetCurrent()
                                        if !context.audioLevelPeakUpdate.isZero {
                                            let delta = timestamp - context.audioLevelPeakUpdate
                                            print("level = \(level), delta = \(delta)")
                                        }
                                        context.audioLevelPeakUpdate = timestamp*/
                                        context.updatedLevel(level)
                                        context.audioLevelPeak = 0
                                        context.audioLevelPeakCount = 0
                                    }
                                }
                                
                                rendererFillOffset.1 += actualConsumedCount
                                
                                if actualConsumedCount == 0 {
                                    break
                                }
                            } else {
                                break
                            }
                        }
                    }
                
                    if !context.notifiedLowWater {
                        let availableBytes = context.buffer.availableBytes
                        if availableBytes <= context.lowWaterSize {
                            context.notifiedLowWater = true
                            notifyLowWater = context.notifyLowWater
                        }
                    }
                case .paused:
                    break
            }
        }
    })
    
    for i in rendererFillOffset.0 ..< bufferList.count {
        var dataOffset = 0
        if i == rendererFillOffset.0 {
            dataOffset = rendererFillOffset.1
        }
        if let data = bufferList[i].mData {
            memset(data.advanced(by: dataOffset), 0, Int(bufferList[i].mDataByteSize) - dataOffset)
        }
    }
    
    if let notifyLowWater = notifyLowWater {
        notifyLowWater()
    }
    
    if let updatedRate = updatedRate {
        updatedRate()
    }
    
    return noErr
}

private struct RequestingFramesContext {
    let queue: DispatchQueue
    let takeFrame: () -> MediaTrackFrameResult
}

private final class AudioPlayerRendererContext {
    let audioStreamDescription: AudioStreamBasicDescription
    let bufferSizeInSeconds: Int = 5
    let lowWaterSizeInSeconds: Int = 2
    
    let audioSession: MediaPlayerAudioSessionControl
    let useVoiceProcessingMode: Bool
    let controlTimebase: CMTimebase
    let updatedRate: () -> Void
    let audioPaused: () -> Void
    
    var paused = true
    var baseRate: Double
    
    let audioLevelPipe: ValuePipe<Float>
    
    var audioGraph: AUGraph?
    var timePitchAudioUnit: AudioComponentInstance?
    var mixerAudioUnit: AudioComponentInstance?
    var outputAudioUnit: AudioComponentInstance?
    
    var bufferContextId: Int32!
    let bufferContext: Atomic<AudioPlayerRendererBufferContext>
    
    var requestingFramesContext: RequestingFramesContext?
    
    let audioSessionDisposable = MetaDisposable()
    var audioSessionControl: ManagedAudioSessionControl?
    let playAndRecord: Bool
    let ambient: Bool
    var forceAudioToSpeaker: Bool {
        didSet {
            if self.forceAudioToSpeaker != oldValue {
                if let audioSessionControl = self.audioSessionControl {
                    audioSessionControl.setOutputMode(self.forceAudioToSpeaker ? .speakerIfNoHeadphones : .system)
                }
            }
        }
    }
    
    init(controlTimebase: CMTimebase, audioSession: MediaPlayerAudioSessionControl, playAndRecord: Bool, useVoiceProcessingMode: Bool, ambient: Bool, forceAudioToSpeaker: Bool, baseRate: Double, audioLevelPipe: ValuePipe<Float>, updatedRate: @escaping () -> Void, audioPaused: @escaping () -> Void) {
        assert(audioPlayerRendererQueue.isCurrent())
        
        self.audioSession = audioSession
        self.forceAudioToSpeaker = forceAudioToSpeaker
        self.baseRate = baseRate
        self.audioLevelPipe = audioLevelPipe
        
        self.controlTimebase = controlTimebase
        self.updatedRate = updatedRate
        self.audioPaused = audioPaused
        
        self.playAndRecord = playAndRecord
        self.useVoiceProcessingMode = useVoiceProcessingMode
        self.ambient = ambient
        
        self.audioStreamDescription = audioRendererNativeStreamDescription()
        
        let bufferSize = Int(self.audioStreamDescription.mSampleRate) * self.bufferSizeInSeconds * Int(self.audioStreamDescription.mBytesPerFrame)
        let lowWaterSize = Int(self.audioStreamDescription.mSampleRate) * self.lowWaterSizeInSeconds * Int(self.audioStreamDescription.mBytesPerFrame)
        
        var notifyLowWater: () -> Void = { }
        
        self.bufferContext = Atomic(value: AudioPlayerRendererBufferContext(timebase: controlTimebase, buffer: RingByteBuffer(size: bufferSize), lowWaterSize: lowWaterSize, notifyLowWater: {
            notifyLowWater()
        }, updatedRate: {
            updatedRate()
        }, updatedLevel: { level in
            audioLevelPipe.putNext(level)
        }))
        self.bufferContextId = registerPlayerRendererBufferContext(self.bufferContext)
        
        notifyLowWater = { [weak self] in
            audioPlayerRendererQueue.async {
                if let strongSelf = self {
                    strongSelf.checkBuffer()
                }
            }
        }
    }
    
    deinit {
        assert(audioPlayerRendererQueue.isCurrent())
        
        self.audioSessionDisposable.dispose()
        
        unregisterPlayerRendererBufferContext(self.bufferContextId)
        
        self.closeAudioUnit()
    }
    
    fileprivate func setBaseRate(_ baseRate: Double) {
        if let timePitchAudioUnit = self.timePitchAudioUnit, !self.baseRate.isEqual(to: baseRate) {
            self.baseRate = baseRate
            AudioUnitSetParameter(timePitchAudioUnit, kTimePitchParam_Rate, kAudioUnitScope_Global, 0, Float32(baseRate), 0)
            self.bufferContext.with { context in
                if case .playing = context.state {
                    context.state = .playing(rate: baseRate, didSetRate: false)
                }
            }
        }
    }
    
    fileprivate func setVolume(_ volume: Double) {
        if let mixerAudioUnit = self.mixerAudioUnit {
            AudioUnitSetParameter(mixerAudioUnit, kMultiChannelMixerParam_Volume, kAudioUnitScope_Input, 0, Float32(volume), 0)
        }
    }
    
    fileprivate func setRate(_ rate: Double) {
        assert(audioPlayerRendererQueue.isCurrent())
        
        if !rate.isZero && self.paused {
            self.start()
        }
        
        let baseRate = self.baseRate
        
        self.bufferContext.with { context in
            if !rate.isZero {
                if case .playing = context.state {
                } else {
                    context.state = .playing(rate: baseRate, didSetRate: false)
                }
            } else {
                context.state = .paused
                CMTimebaseSetRate(context.timebase, rate: 0.0)
            }
        }
    }
    
    fileprivate func flushBuffers(at timestamp: CMTime, completion: () -> Void) {
        assert(audioPlayerRendererQueue.isCurrent())
        
        self.bufferContext.with { context in
            context.buffer.clear()
            context.bufferMaxChannelSampleIndex = 0
            context.notifiedLowWater = false
            context.overflowData = Data()
            context.overflowDataMaxChannelSampleIndex = 0
            CMTimebaseSetTime(context.timebase, time: timestamp)
            
            switch context.state {
                case let .playing(rate, _):
                    context.state = .playing(rate: rate, didSetRate: false)
                case .paused:
                    break
            }
        }
        
        completion()
    }
    
    fileprivate func start() {
        assert(audioPlayerRendererQueue.isCurrent())
        
        if self.paused {
            self.paused = false
            self.startAudioUnit()
        }
    }
    
    fileprivate func stop() {
        assert(audioPlayerRendererQueue.isCurrent())
        
        if !self.paused {
            self.paused = true
            self.setRate(0.0)
            self.closeAudioUnit()
        }
    }
    
    private func startAudioUnit() {
        assert(audioPlayerRendererQueue.isCurrent())
        
        if self.audioGraph == nil {
            let startTime = CFAbsoluteTimeGetCurrent()
            
            var maybeAudioGraph: AUGraph?
            guard NewAUGraph(&maybeAudioGraph) == noErr, let audioGraph = maybeAudioGraph else {
                return
            }
            
            var converterNode: AUNode = 0
            var converterDescription = AudioComponentDescription()
            converterDescription.componentType = kAudioUnitType_FormatConverter
            converterDescription.componentSubType = kAudioUnitSubType_AUConverter
            converterDescription.componentManufacturer = kAudioUnitManufacturer_Apple
            guard AUGraphAddNode(audioGraph, &converterDescription, &converterNode) == noErr else {
                return
            }
            
            var timePitchNode: AUNode = 0
            var timePitchDescription = AudioComponentDescription()
            timePitchDescription.componentType = kAudioUnitType_FormatConverter
            timePitchDescription.componentSubType = kAudioUnitSubType_AUiPodTimeOther
            timePitchDescription.componentManufacturer = kAudioUnitManufacturer_Apple
            guard AUGraphAddNode(audioGraph, &timePitchDescription, &timePitchNode) == noErr else {
                return
            }
            
            var mixerNode: AUNode = 0
            var mixerDescription = AudioComponentDescription()
            mixerDescription.componentType = kAudioUnitType_Mixer
            mixerDescription.componentSubType = kAudioUnitSubType_MultiChannelMixer
            mixerDescription.componentManufacturer = kAudioUnitManufacturer_Apple
            guard AUGraphAddNode(audioGraph, &mixerDescription, &mixerNode) == noErr else {
                return
            }
            
            var outputNode: AUNode = 0
            var outputDesc = AudioComponentDescription()
            outputDesc.componentType = kAudioUnitType_Output
            if self.useVoiceProcessingMode {
                outputDesc.componentSubType = kAudioUnitSubType_VoiceProcessingIO
            } else {
                outputDesc.componentSubType = kAudioUnitSubType_RemoteIO
            }
            outputDesc.componentFlags = 0
            outputDesc.componentFlagsMask = 0
            outputDesc.componentManufacturer = kAudioUnitManufacturer_Apple
            guard AUGraphAddNode(audioGraph, &outputDesc, &outputNode) == noErr else {
                return
            }
            
            guard AUGraphOpen(audioGraph) == noErr else {
                return
            }
            
            guard AUGraphConnectNodeInput(audioGraph, converterNode, 0, timePitchNode, 0) == noErr else {
                return
            }
            
            guard AUGraphConnectNodeInput(audioGraph, timePitchNode, 0, mixerNode, 0) == noErr else {
                return
            }
            
            guard AUGraphConnectNodeInput(audioGraph, mixerNode, 0, outputNode, 0) == noErr else {
                return
            }
            
            var maybeConverterAudioUnit: AudioComponentInstance?
            guard AUGraphNodeInfo(audioGraph, converterNode, &converterDescription, &maybeConverterAudioUnit) == noErr, let converterAudioUnit = maybeConverterAudioUnit else {
                return
            }
            
            var maybeTimePitchAudioUnit: AudioComponentInstance?
            guard AUGraphNodeInfo(audioGraph, timePitchNode, &timePitchDescription, &maybeTimePitchAudioUnit) == noErr, let timePitchAudioUnit = maybeTimePitchAudioUnit else {
                return
            }
            AudioUnitSetParameter(timePitchAudioUnit, kTimePitchParam_Rate, kAudioUnitScope_Global, 0, Float32(self.baseRate), 0)
            
            var maybeMixerAudioUnit: AudioComponentInstance?
            guard AUGraphNodeInfo(audioGraph, mixerNode, &mixerDescription, &maybeMixerAudioUnit) == noErr, let mixerAudioUnit = maybeMixerAudioUnit else {
                return
            }
            
            var maybeOutputAudioUnit: AudioComponentInstance?
            guard AUGraphNodeInfo(audioGraph, outputNode, &outputDesc, &maybeOutputAudioUnit) == noErr, let outputAudioUnit = maybeOutputAudioUnit else {
                return
            }
            
            var outputAudioFormat = audioRendererNativeStreamDescription()
            
            AudioUnitSetProperty(converterAudioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &outputAudioFormat, UInt32(MemoryLayout<AudioStreamBasicDescription>.size))
            
            var streamFormat = AudioStreamBasicDescription()
            AudioUnitSetProperty(converterAudioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &streamFormat, UInt32(MemoryLayout<AudioStreamBasicDescription>.size))
            AudioUnitSetProperty(timePitchAudioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &streamFormat, UInt32(MemoryLayout<AudioStreamBasicDescription>.size))
            AudioUnitSetProperty(mixerAudioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &streamFormat, UInt32(MemoryLayout<AudioStreamBasicDescription>.size))
            
            var callbackStruct = AURenderCallbackStruct()
            callbackStruct.inputProc = rendererInputProc
            callbackStruct.inputProcRefCon = UnsafeMutableRawPointer(bitPattern: intptr_t(self.bufferContextId))
            
            guard AUGraphSetNodeInputCallback(audioGraph, converterNode, 0, &callbackStruct) == noErr else {
                return
            }
            
            var one: UInt32 = 1
            guard AudioUnitSetProperty(outputAudioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, kOutputBus, &one, 4) == noErr else {
                return
            }
            
            var maximumFramesPerSlice: UInt32 = 4096
            AudioUnitSetProperty(converterAudioUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &maximumFramesPerSlice, 4)
            AudioUnitSetProperty(timePitchAudioUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &maximumFramesPerSlice, 4)
            AudioUnitSetProperty(mixerAudioUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &maximumFramesPerSlice, 4)
            AudioUnitSetProperty(outputAudioUnit, kAudioUnitProperty_MaximumFramesPerSlice, kAudioUnitScope_Global, 0, &maximumFramesPerSlice, 4)
                        
            guard AUGraphInitialize(audioGraph) == noErr else {
                return
            }
            
            print("\(CFAbsoluteTimeGetCurrent()) MediaPlayerAudioRenderer initialize audio unit: \((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0) ms")
            
            self.audioGraph = audioGraph
            self.timePitchAudioUnit = timePitchAudioUnit
            self.mixerAudioUnit = mixerAudioUnit
            self.outputAudioUnit = outputAudioUnit
        }
        
        switch self.audioSession {
            case let .manager(manager):
                self.audioSessionDisposable.set(manager.push(audioSessionType: self.ambient ? .ambient : (self.playAndRecord ? .playWithPossiblePortOverride : .play), outputMode: self.forceAudioToSpeaker ? .speakerIfNoHeadphones : .system, once: self.ambient, manualActivate: { [weak self] control in
                    audioPlayerRendererQueue.async {
                        if let strongSelf = self {
                            strongSelf.audioSessionControl = control
                            if !strongSelf.paused {
                                control.setup()
                                control.setOutputMode(strongSelf.forceAudioToSpeaker ? .speakerIfNoHeadphones : .system)
                                control.activate({ _ in
                                    audioPlayerRendererQueue.async {
                                        if let strongSelf = self, !strongSelf.paused {
                                            strongSelf.audioSessionAcquired()
                                        }
                                    }
                                })
                            }
                        }
                    }
                }, deactivate: { [weak self] temporary in
                    return Signal { subscriber in
                        audioPlayerRendererQueue.async {
                            if let strongSelf = self {
                                strongSelf.audioSessionControl = nil
                                if !temporary {
                                    strongSelf.audioPaused()
                                    strongSelf.stop()
                                }
                                subscriber.putCompletion()
                            }
                        }
                        
                        return EmptyDisposable
                    }
                }, headsetConnectionStatusChanged: { [weak self] value in
                    audioPlayerRendererQueue.async {
                        if let strongSelf = self, !value {
                            strongSelf.audioPaused()
                        }
                    }
                }))
            case let .custom(request):
                self.audioSessionDisposable.set(request(MediaPlayerAudioSessionCustomControl(activate: { [weak self] in
                    audioPlayerRendererQueue.async {
                        if let strongSelf = self {
                            if !strongSelf.paused {
                                strongSelf.audioSessionAcquired()
                            }
                        }
                    }
                }, deactivate: { [weak self] in
                    audioPlayerRendererQueue.async {
                        if let strongSelf = self {
                            strongSelf.audioSessionControl = nil
                            strongSelf.audioPaused()
                            strongSelf.stop()
                        }
                    }
                })))
        }
    }
    
    private func audioSessionAcquired() {
        assert(audioPlayerRendererQueue.isCurrent())
        
        if let audioGraph = self.audioGraph {
            let startTime = CFAbsoluteTimeGetCurrent()
            
            guard AUGraphStart(audioGraph) == noErr else {
                self.closeAudioUnit()
                return
            }
            
            print("\(CFAbsoluteTimeGetCurrent()) MediaPlayerAudioRenderer start audio unit: \((CFAbsoluteTimeGetCurrent() - startTime) * 1000.0) ms")
        }
    }
    
    private func closeAudioUnit() {
        assert(audioPlayerRendererQueue.isCurrent())
        
        if let audioGraph = self.audioGraph {
            var status = noErr
            
            self.bufferContext.with { context in
                context.buffer.clear()
            }
            
            status = AUGraphStop(audioGraph)
            if status != noErr {
                Logger.shared.log("AudioPlayerRenderer", "AUGraphStop error \(status)")
            }
            
            status = AUGraphUninitialize(audioGraph)
            if status != noErr {
                Logger.shared.log("AudioPlayerRenderer", "AUGraphUninitialize error \(status)")
            }
            
            status = AUGraphClose(audioGraph)
            if status != noErr {
                Logger.shared.log("AudioPlayerRenderer", "AUGraphClose error \(status)")
            }
            
            status = DisposeAUGraph(audioGraph)
            if status != noErr {
                Logger.shared.log("AudioPlayerRenderer", "DisposeAUGraph error \(status)")
            }
            
            self.audioGraph = nil
            self.outputAudioUnit = nil
            self.timePitchAudioUnit = nil
        }
    }
    
    func checkBuffer() {
        assert(audioPlayerRendererQueue.isCurrent())
        
        while true {
            let bytesToRequest = self.bufferContext.with { context -> Int in
                let availableBytes = context.buffer.availableBytes
                if availableBytes <= context.lowWaterSize {
                    return context.buffer.size - availableBytes
                } else {
                    return 0
                }
            }
            
            if bytesToRequest == 0 {
                self.bufferContext.with { context in
                    context.notifiedLowWater = false
                }
                break
            }
            
            let overflowTakenLength = self.bufferContext.with { context -> Int in
                let takeLength = min(context.overflowData.count, bytesToRequest)
                if takeLength != 0 {
                    if takeLength == context.overflowData.count {
                        let data = context.overflowData
                        context.overflowData = Data()
                        self.enqueueSamples(data, sampleIndex: context.overflowDataMaxChannelSampleIndex - Int64(data.count / (2 * 2)))
                    } else {
                        let data = context.overflowData.subdata(in: 0 ..< takeLength)
                        self.enqueueSamples(data, sampleIndex: context.overflowDataMaxChannelSampleIndex - Int64(context.overflowData.count / (2 * 2)))
                        context.overflowData.replaceSubrange(0 ..< takeLength, with: Data())
                    }
                }
                return takeLength
            }
            
            if overflowTakenLength != 0 {
                continue
            }
            
            if let requestingFramesContext = self.requestingFramesContext {
                requestingFramesContext.queue.async { [weak self] in
                    let takenFrame = requestingFramesContext.takeFrame()
                    audioPlayerRendererQueue.async {
                        guard let strongSelf = self else {
                            return
                        }
                        switch takenFrame {
                            case let .frame(frame):
                                if let dataBuffer = CMSampleBufferGetDataBuffer(frame.sampleBuffer) {
                                    let dataLength = CMBlockBufferGetDataLength(dataBuffer)
                                    let takeLength = min(dataLength, bytesToRequest)
                                    
                                    let pts = CMSampleBufferGetPresentationTimeStamp(frame.sampleBuffer)
                                    let bufferSampleIndex = CMTimeConvertScale(pts, timescale: 44100, method: .roundAwayFromZero).value
                                    
                                    let bytes = malloc(takeLength)!
                                    CMBlockBufferCopyDataBytes(dataBuffer, atOffset: 0, dataLength: takeLength, destination: bytes)
                                    strongSelf.enqueueSamples(Data(bytesNoCopy: bytes.assumingMemoryBound(to: UInt8.self), count: takeLength, deallocator: .free), sampleIndex: bufferSampleIndex)
                                    
                                    if takeLength < dataLength {
                                        strongSelf.bufferContext.with { context in
                                            let copyOffset = context.overflowData.count
                                            context.overflowData.count += dataLength - takeLength
                                            context.overflowData.withUnsafeMutableBytes { buffer -> Void in
                                                guard let bytes = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                                                    return
                                                }
                                                CMBlockBufferCopyDataBytes(dataBuffer, atOffset: takeLength, dataLength: dataLength - takeLength, destination: bytes.advanced(by: copyOffset))
                                            }
                                        }
                                    }
                                    
                                    strongSelf.checkBuffer()
                                } else {
                                    assertionFailure()
                                }
                            case .restoreState:
                                assertionFailure()
                                strongSelf.checkBuffer()
                                break
                            case .skipFrame:
                                strongSelf.checkBuffer()
                                break
                            case .noFrames, .finished:
                                strongSelf.requestingFramesContext = nil
                        }
                    }
                }
            } else {
                self.bufferContext.with { context in
                    context.notifiedLowWater = false
                }
            }
            
            break
        }
    }
    
    private func enqueueSamples(_ data: Data, sampleIndex: Int64) {
        assert(audioPlayerRendererQueue.isCurrent())
        
        self.bufferContext.with { context in
            let bytesToCopy = min(context.buffer.size - context.buffer.availableBytes, data.count)
            data.withUnsafeBytes { buffer -> Void in
                guard let bytes = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                    return
                }
                let _ = context.buffer.enqueue(UnsafeRawPointer(bytes), count: bytesToCopy)
                context.bufferMaxChannelSampleIndex = sampleIndex + Int64(data.count / (2 * 2))
            }
        }
    }
    
    fileprivate func beginRequestingFrames(queue: DispatchQueue, takeFrame: @escaping () -> MediaTrackFrameResult) {
        assert(audioPlayerRendererQueue.isCurrent())
        
        if let _ = self.requestingFramesContext {
            return
        }
        
        self.requestingFramesContext = RequestingFramesContext(queue: queue, takeFrame: takeFrame)
        
        self.checkBuffer()
    }
    
    func endRequestingFrames() {
        assert(audioPlayerRendererQueue.isCurrent())
        
        self.requestingFramesContext = nil
    }
}

private func audioRendererNativeStreamDescription() -> AudioStreamBasicDescription {
    var canonicalBasicStreamDescription = AudioStreamBasicDescription()
    canonicalBasicStreamDescription.mSampleRate = 44100.00
    canonicalBasicStreamDescription.mFormatID = kAudioFormatLinearPCM
    canonicalBasicStreamDescription.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked
    canonicalBasicStreamDescription.mFramesPerPacket = 1
    canonicalBasicStreamDescription.mChannelsPerFrame = 2
    canonicalBasicStreamDescription.mBytesPerFrame = 2 * 2
    canonicalBasicStreamDescription.mBitsPerChannel = 8 * 2
    canonicalBasicStreamDescription.mBytesPerPacket = 2 * 2
    return canonicalBasicStreamDescription
}

public final class MediaPlayerAudioSessionCustomControl {
    public let activate: () -> Void
    public let deactivate: () -> Void
    
    public init(activate: @escaping () -> Void, deactivate: @escaping () -> Void) {
        self.activate = activate
        self.deactivate = deactivate
    }
}

public enum MediaPlayerAudioSessionControl {
    case manager(ManagedAudioSession)
    case custom((MediaPlayerAudioSessionCustomControl) -> Disposable)
}

public final class MediaPlayerAudioRenderer {
    private var contextRef: Unmanaged<AudioPlayerRendererContext>?
    
    private let audioClock: CMClock
    public let audioTimebase: CMTimebase
    
    public init(audioSession: MediaPlayerAudioSessionControl, playAndRecord: Bool, useVoiceProcessingMode: Bool = false, ambient: Bool, forceAudioToSpeaker: Bool, baseRate: Double, audioLevelPipe: ValuePipe<Float>, updatedRate: @escaping () -> Void, audioPaused: @escaping () -> Void) {
        var audioClock: CMClock?
        CMAudioClockCreate(allocator: nil, clockOut: &audioClock)
        if audioClock == nil {
            audioClock = CMClockGetHostTimeClock()
        }
        self.audioClock = audioClock!
        
        var audioTimebase: CMTimebase?
        CMTimebaseCreateWithSourceClock(allocator: nil, sourceClock: audioClock!, timebaseOut: &audioTimebase)
        self.audioTimebase = audioTimebase!
        
        audioPlayerRendererQueue.async {
            let context = AudioPlayerRendererContext(controlTimebase: audioTimebase!, audioSession: audioSession, playAndRecord: playAndRecord, useVoiceProcessingMode: useVoiceProcessingMode, ambient: ambient, forceAudioToSpeaker: forceAudioToSpeaker, baseRate: baseRate, audioLevelPipe: audioLevelPipe, updatedRate: updatedRate, audioPaused: audioPaused)
            self.contextRef = Unmanaged.passRetained(context)
        }
    }
    
    deinit {
        let contextRef = self.contextRef
        audioPlayerRendererQueue.async {
            contextRef?.release()
        }
    }
    
    public func start() {
        audioPlayerRendererQueue.async {
            if let contextRef = self.contextRef {
                let context = contextRef.takeUnretainedValue()
                context.start()
            }
        }
    }
    
    public func stop() {
        audioPlayerRendererQueue.async {
            if let contextRef = self.contextRef {
                let context = contextRef.takeUnretainedValue()
                context.stop()
            }
        }
    }
    
    public func setRate(_ rate: Double) {
        audioPlayerRendererQueue.async {
            if let contextRef = self.contextRef {
                let context = contextRef.takeUnretainedValue()
                context.setRate(rate)
            }
        }
    }
    
    public func setBaseRate(_ baseRate: Double) {
        audioPlayerRendererQueue.async {
            if let contextRef = self.contextRef {
                let context = contextRef.takeUnretainedValue()
                context.setBaseRate(baseRate)
            }
        }
    }
    
    public func setVolume(_ volume: Double) {
        audioPlayerRendererQueue.async {
            if let contextRef = self.contextRef {
                let context = contextRef.takeUnretainedValue()
                context.setVolume(volume)
            }
        }
    }
    
    public func beginRequestingFrames(queue: DispatchQueue, takeFrame: @escaping () -> MediaTrackFrameResult) {
        audioPlayerRendererQueue.async {
            if let contextRef = self.contextRef {
                let context = contextRef.takeUnretainedValue()
                context.beginRequestingFrames(queue: queue, takeFrame: takeFrame)
            }
        }
    }
    
    public func flushBuffers(at timestamp: CMTime, completion: @escaping () -> Void) {
        audioPlayerRendererQueue.async {
            if let contextRef = self.contextRef {
                let context = contextRef.takeUnretainedValue()
                context.flushBuffers(at: timestamp, completion: completion)
            }
        }
    }
    
    public func setForceAudioToSpeaker(_ value: Bool) {
        audioPlayerRendererQueue.async {
            if let contextRef = self.contextRef {
                let context = contextRef.takeUnretainedValue()
                context.forceAudioToSpeaker = value
            }
        }
    }
}
