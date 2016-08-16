import Foundation
import SwiftSignalKit
import CoreMedia
import AVFoundation

private final class AudioPlayerRendererBufferContext {
    let buffer: RingByteBuffer
    var lowWaterSize: Int
    var notifyLowWater: () -> Void
    var notifiedLowWater = false
    
    init(buffer: RingByteBuffer, lowWaterSize: Int, notifyLowWater: () -> Void) {
        self.buffer = buffer
        self.lowWaterSize = lowWaterSize
        self.notifyLowWater = notifyLowWater
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

private func withPlayerRendererBuffer(_ id: Int32, _ f: @noescape(Atomic<AudioPlayerRendererBufferContext>) -> Void) {
    audioPlayerRendererBufferContextMap.with { contextMap in
        if let context = contextMap[id] {
            f(context)
        }
    }
}

private let kOutputBus: UInt32 = 0
private let kInputBus: UInt32 = 1

private func rendererInputProc(refCon: UnsafeMutablePointer<Void>, ioActionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>, inTimeStamp: UnsafePointer<AudioTimeStamp>, inBusNumber: UInt32, inNumberFrames: UInt32, ioData: UnsafeMutablePointer<AudioBufferList>?) -> OSStatus {
    guard let ioData = ioData else {
        return noErr
    }
    
    let bufferList = UnsafeMutableAudioBufferListPointer(ioData)
    
    var rendererFillOffset = (0, 0)
    var notifyLowWater: (() -> Void)?
    
    withPlayerRendererBuffer(Int32(unsafeBitCast(refCon, to: intptr_t.self)), { context in
        context.with { context in
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
                    rendererFillOffset.1 += actualConsumedCount
                    
                    if actualConsumedCount == 0 {
                        break
                    }
                } else {
                    break
                }
            }
            
            if !context.notifiedLowWater {
                let availableBytes = rendererBuffer.availableBytes
                if availableBytes <= context.lowWaterSize {
                    context.notifiedLowWater = true
                    notifyLowWater = context.notifyLowWater
                }
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

    return noErr
}

private final class AudioPlayerRendererContext {
    let audioStreamDescription: AudioStreamBasicDescription
    let bufferSizeInSeconds: Int = 5
    let lowWaterSizeInSeconds: Int = 2
    
    var audioUnit: AudioComponentInstance?
    
    var bufferContextId: Int32!
    let bufferContext: Atomic<AudioPlayerRendererBufferContext>
    
    let requestSamples: (Int) -> Signal<Data, Void>
    let requestSamplesDisposable = MetaDisposable()
    
    init(audioStreamDescription: AudioStreamBasicDescription, requestSamples: (Int) -> Signal<Data, Void>) {
        assert(audioPlayerRendererQueue.isCurrent())
        
        self.audioStreamDescription = audioStreamDescription
        self.requestSamples = requestSamples
        
        let bufferSize = Int(self.audioStreamDescription.mSampleRate) * self.bufferSizeInSeconds * Int(self.audioStreamDescription.mBytesPerFrame)
        let lowWaterSize = Int(self.audioStreamDescription.mSampleRate) * self.lowWaterSizeInSeconds * Int(self.audioStreamDescription.mBytesPerFrame)
        
        var notifyLowWater: () -> Void = { }
        
        self.bufferContext = Atomic(value: AudioPlayerRendererBufferContext(buffer: RingByteBuffer(size: bufferSize), lowWaterSize: lowWaterSize, notifyLowWater: {
            notifyLowWater()
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
        
        unregisterPlayerRendererBufferContext(self.bufferContextId)
        
        self.closeAudioUnit()
        self.requestSamplesDisposable.dispose()
    }
    
    private func startAudioUnit() {
        if self.audioUnit == nil {
            guard let _ = try? AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback) else {
                return
            }
            guard let _ = try? AVAudioSession.sharedInstance().setActive(true) else {
                return
            }
            
            var desc = AudioComponentDescription()
            desc.componentType = kAudioUnitType_Output
            desc.componentSubType = kAudioUnitSubType_RemoteIO
            desc.componentFlags = 0
            desc.componentFlagsMask = 0
            desc.componentManufacturer = kAudioUnitManufacturer_Apple
            guard let inputComponent = AudioComponentFindNext(nil, &desc) else {
                return
            }
            
            var maybeAudioUnit: AudioComponentInstance?
            
            guard AudioComponentInstanceNew(inputComponent, &maybeAudioUnit) == noErr else {
                return
            }
            
            guard let audioUnit = maybeAudioUnit else {
                return
            }
            
            var one: UInt32 = 1
            guard AudioUnitSetProperty(audioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, kOutputBus, &one, 4) == noErr else {
                AudioComponentInstanceDispose(audioUnit)
                return
            }
            
            var audioStreamDescription = self.audioStreamDescription
            guard AudioUnitSetProperty(audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, kOutputBus, &audioStreamDescription, UInt32(sizeof(AudioStreamBasicDescription.self))) == noErr else {
                AudioComponentInstanceDispose(audioUnit)
                return
            }
            
            var callbackStruct = AURenderCallbackStruct()
            callbackStruct.inputProc = rendererInputProc
            callbackStruct.inputProcRefCon = unsafeBitCast(intptr_t(self.bufferContextId), to: UnsafeMutablePointer<Void>.self)
            guard AudioUnitSetProperty(audioUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Global, kOutputBus, &callbackStruct, UInt32(sizeof(AURenderCallbackStruct.self))) == noErr else {
                AudioComponentInstanceDispose(audioUnit)
                return
            }
            
            guard AudioUnitInitialize(audioUnit) == noErr else {
                AudioComponentInstanceDispose(audioUnit)
                return
            }
            
            guard AudioOutputUnitStart(audioUnit) == noErr else {
                AudioComponentInstanceDispose(audioUnit)
                return
            }
            
            self.audioUnit = audioUnit
        }
    }
    
    private func closeAudioUnit() {
        assert(audioPlayerRendererQueue.isCurrent())
        
        if let audioUnit = self.audioUnit {
            var status = noErr
            
            self.bufferContext.with { context in
                context.buffer.clear()
            }
            
            status = AudioOutputUnitStop(audioUnit)
            if status != noErr {
                trace("AudioPlayerRenderer", what: "AudioOutputUnitStop error \(status)")
            }
            
            status = AudioComponentInstanceDispose(audioUnit);
            if status != noErr {
                trace("AudioPlayerRenderer", what: "AudioComponentInstanceDispose error \(status)")
            }
            self.audioUnit = nil
        }
    }
    
    func checkBuffer() {
        assert(audioPlayerRendererQueue.isCurrent())
        
        self.bufferContext.with { context in
            let availableBytes = context.buffer.availableBytes
            if availableBytes <= context.lowWaterSize {
                let bytesToRequest = context.buffer.size - availableBytes
                let bytes = self.requestSamples(bytesToRequest)
                    |> deliverOn(audioPlayerRendererQueue)
                self.requestSamplesDisposable.set(bytes.start(next: { [weak self] data in
                    audioPlayerRendererQueue.justDispatch {
                        self?.enqueueSamples(data)
                    }
                }, completed: { [weak self] in
                    audioPlayerRendererQueue.justDispatch {
                        let _ = self?.bufferContext.with { context in
                            context.notifiedLowWater = false
                        }
                    }
                }))
            }
        }
    }
    
    private func enqueueSamples(_ data: Data) {
        assert(audioPlayerRendererQueue.isCurrent())
        
        self.bufferContext.with { context in
            let bytesToCopy = min(context.buffer.size - context.buffer.availableBytes, data.count)
            data.withUnsafeBytes { (bytes: UnsafePointer<Void>) -> Void in
                let _ = context.buffer.enqueue(bytes, count: bytesToCopy)
            }
        }
    }
}

final class AudioPlayerRenderer {
    private var contextRef: Unmanaged<AudioPlayerRendererContext>?
    
    init(audioStreamDescription: AudioStreamBasicDescription, requestSamples: (Int) -> Signal<Data, Void>) {
        audioPlayerRendererQueue.async {
            let context = AudioPlayerRendererContext(audioStreamDescription: audioStreamDescription, requestSamples: requestSamples)
            self.contextRef = Unmanaged.passRetained(context)
        }
    }
    
    deinit {
        let contextRef = self.contextRef
        audioPlayerRendererQueue.async {
            contextRef?.release()
        }
    }
    
    func render() {
        audioPlayerRendererQueue.async {
            if let contextRef = self.contextRef {
                let context = contextRef.takeUnretainedValue()
                context.startAudioUnit()
            }
        }
    }
    
    func stop() {
        audioPlayerRendererQueue.async {
            if let contextRef = self.contextRef {
                let context = contextRef.takeUnretainedValue()
                context.closeAudioUnit()
            }
        }
    }
}
