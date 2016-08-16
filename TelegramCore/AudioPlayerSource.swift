import Foundation
import Postbox
import SwiftSignalKit
import CoreMedia

func audioPlayerCanonicalStreamDescription() -> AudioStreamBasicDescription {
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

private final class WeakAudioPlayerSourceContext {
    weak var context: AudioPlayerSourceContext?
    
    init(context: AudioPlayerSourceContext) {
        self.context = context
    }
}

private var audioStreamPlayerContextMap: [Int32: WeakAudioPlayerSourceContext] = [:]
private let audioPlayerSourceQueue = Queue()

private var _nextPlayerContextId: Int32 = 0
private func registerPlayerContext(_ context: AudioPlayerSourceContext) -> Int32 {
    let id = _nextPlayerContextId
    _nextPlayerContextId += 1
    
    audioStreamPlayerContextMap[id] = WeakAudioPlayerSourceContext(context: context)
    return id
}

private func unregisterPlayerContext(_ id: Int32) {
    let _ = audioStreamPlayerContextMap.removeValue(forKey: id)
}

private func withPlayerContextOnQueue(_ id: Int32, _ f: (AudioPlayerSourceContext) -> Void) {
    audioPlayerSourceQueue.async {
        if let context = audioStreamPlayerContextMap[id]?.context {
            f(context)
        }
    }
}

private func audioConverterProc(converter: AudioConverterRef, ioNumberOfDataPackets: UnsafeMutablePointer<UInt32>, ioData: UnsafeMutablePointer<AudioBufferList>, outDataPacketDescription: UnsafeMutablePointer<UnsafeMutablePointer<AudioStreamPacketDescription>?>?, inUserData: UnsafeMutablePointer<Void>?) -> OSStatus {
    assert(audioPlayerSourceQueue.isCurrent())
    
    let audioConverterData = UnsafeMutablePointer<AudioConverterData>(inUserData!)
    
    if audioConverterData.pointee.done {
        ioNumberOfDataPackets.pointee = 0
        return 100
    } else {
        ioData.pointee.mNumberBuffers = 1
        ioData.pointee.mBuffers = audioConverterData.pointee.audioBuffer
        outDataPacketDescription?.pointee = audioConverterData.pointee.packetDescriptions
        ioNumberOfDataPackets.pointee = audioConverterData.pointee.numberOfPackets
        audioConverterData.pointee.done = true
    }
    
    return noErr
}

private struct AudioConverterData {
    var done: Bool
    var numberOfPackets: UInt32
    var packetDescriptions: UnsafeMutablePointer<AudioStreamPacketDescription>
    var audioBuffer: AudioBuffer
}

private func packetsProc(refCon: UnsafeMutablePointer<Void>, numberOfBytes: UInt32, numberOfPackets: UInt32, inputData: UnsafePointer<Void>, packetDescriptionsIn: UnsafeMutablePointer<AudioStreamPacketDescription>) -> Void {
    withPlayerContextOnQueue(Int32(unsafeBitCast(refCon, to: intptr_t.self)), { context in
        context.withOpenedConverter { converter in
            guard let streamBasicDescription = context.streamBasicDescription else {
                return
            }
            
            var converterDataAudioBuffer = AudioBuffer()
            converterDataAudioBuffer.mData = UnsafeMutablePointer(inputData)
            converterDataAudioBuffer.mDataByteSize = numberOfBytes
            converterDataAudioBuffer.mNumberChannels = streamBasicDescription.mChannelsPerFrame
            
            var converterData = AudioConverterData(done: false, numberOfPackets: numberOfPackets, packetDescriptions: packetDescriptionsIn, audioBuffer: converterDataAudioBuffer)
            
            if context.processedPacketsCount < 4096 {
                let count = min(Int(numberOfPackets), 4096 - context.processedPacketsCount)
                for i in 0 ..< count {
                    let packetSize: Int64 = Int64(packetDescriptionsIn.advanced(by: i).pointee.mDataByteSize)
                    context.processedPacketsSizeTotal += packetSize
                    context.processedPacketsCount += 1
                }
            }
            
            var status = noErr
            
            context.dataOverflowBuffer.withMutableHeadBytes { bytes, availableCount in
                var buffer = AudioBuffer()
                buffer.mNumberChannels = context.canonicalBasicStreamDescription.mChannelsPerFrame
                buffer.mDataByteSize = UInt32(availableCount)
                buffer.mData = bytes
                
                var localPcmBufferList = AudioBufferList()
                localPcmBufferList.mNumberBuffers = 1
                localPcmBufferList.mBuffers = buffer
                
                var framesToDecode: UInt32 = UInt32(availableCount) / context.canonicalBasicStreamDescription.mBytesPerFrame
                
                status = AudioConverterFillComplexBuffer(converter, audioConverterProc, &converterData, &framesToDecode, &localPcmBufferList, nil)
                
                return Int(framesToDecode * context.canonicalBasicStreamDescription.mBytesPerFrame)
            }
            
            context.processBuffer()
        }
    })
}

private func propertyProc(refCon: UnsafeMutablePointer<Void>, streamId: AudioFileStreamID, propertyId: AudioFileStreamPropertyID, flags: UnsafeMutablePointer<AudioFileStreamPropertyFlags>) -> Void {
    withPlayerContextOnQueue(Int32(unsafeBitCast(refCon, to: intptr_t.self)), { context in
        switch propertyId {
            case kAudioFileStreamProperty_DataOffset:
                var offset: Int64 = 0
                var offsetSize: UInt32 = 8
                
                AudioFileStreamGetProperty(streamId, kAudioFileStreamProperty_DataOffset, &offsetSize, &offset);
                
                context.audioDataOffset = offset
                context.parsedHeader = true
            case kAudioFileStreamProperty_DataFormat:
                if !context.parsedHeader {
                    var basicDescription = AudioStreamBasicDescription()
                    var basicDescriptionSize = UInt32(sizeof(AudioStreamBasicDescription.self))
                    AudioFileStreamGetProperty(streamId, kAudioFileStreamProperty_DataFormat, &basicDescriptionSize, &basicDescription)
                    
                    context.streamBasicDescription = basicDescription
                    
                    context.sampleRate = basicDescription.mSampleRate
                    context.packetDuration = Float64(basicDescription.mFramesPerPacket) / basicDescription.mSampleRate
                    
                    var packetBufferSize: UInt32 = 0
                    var sizeOfPacketBufferSize: UInt32 = 4
                    
                    var status = AudioFileStreamGetProperty(streamId, kAudioFileStreamProperty_PacketSizeUpperBound, &sizeOfPacketBufferSize, &packetBufferSize)
                    
                    if status != noErr || packetBufferSize == 0 {
                        status = AudioFileStreamGetProperty(streamId, kAudioFileStreamProperty_MaximumPacketSize, &sizeOfPacketBufferSize, &packetBufferSize)
                        
                        if status != noErr || packetBufferSize == 0 {
                            context.packetBufferSize = 2048
                        } else {
                            context.packetBufferSize = Int(packetBufferSize)
                        }
                    } else {
                        context.packetBufferSize = Int(packetBufferSize)
                    }
                    
                    context.withOpenedConverter { converter in
                        
                    }
                }
                
                break
            case kAudioFileStreamProperty_AudioDataByteCount:
                print("kAudioFileStreamProperty_AudioDataByteCount")
                
                /*UInt64 audioDataByteCount;
                 UInt32 byteCountSize = sizeof(audioDataByteCount);
                 
                 AudioFileStreamGetProperty(inAudioFileStream, kAudioFileStreamProperty_AudioDataByteCount, &byteCountSize, &audioDataByteCount);
                 
                 currentlyReadingEntry->audioDataByteCount = audioDataByteCount;*/
                
                break
            case kAudioFileStreamProperty_ReadyToProducePackets:
                print("kAudioFileStreamProperty_ReadyToProducePackets")
                /*if (audioConverterAudioStreamBasicDescription.mFormatID != kAudioFormatLinearPCM) {
                 discontinuous = YES;
                 }*/
                
                break
            case kAudioFileStreamProperty_FormatList:
                var outWriteable: DarwinBoolean = false
                var formatListSize: UInt32 = 0
                
                var status = AudioFileStreamGetPropertyInfo(streamId, kAudioFileStreamProperty_FormatList, &formatListSize, &outWriteable)
                
                if status != noErr {
                    return
                }
                
                var formatList: [AudioFormatListItem] = Array(repeatElement(AudioFormatListItem(), count: Int(formatListSize)))
                
                status = formatList.withUnsafeMutableBufferPointer { buffer -> OSStatus in
                    return AudioFileStreamGetProperty(streamId, kAudioFileStreamProperty_FormatList, &formatListSize, buffer.baseAddress!)
                }
                
                if status != noErr {
                    return
                }
                
                for item in formatList {
                    if item.mASBD.mFormatID == kAudioFormatMPEG4AAC_HE || item.mASBD.mFormatID == kAudioFormatMPEG4AAC_HE_V2 {
                        context.streamBasicDescription = item.mASBD
                        break
                    }
                }
            default:
                break
        }
    })
}

private func getHardwareCodecClassDesc(formatId: UInt32, classDesc: inout AudioClassDescription) -> Bool {
    var formatId = formatId
    var size: UInt32 = 0
        
    if (AudioFormatGetPropertyInfo(kAudioFormatProperty_Decoders, 4, &formatId, &size) != 0) {
        return false
    }
    
    let decoderCount = size / UInt32(sizeof(AudioClassDescription.self))
    
    var encoderDescriptions: [AudioClassDescription] = Array(repeatElement(AudioClassDescription(), count: Int(decoderCount)))
    
    if encoderDescriptions.withUnsafeMutableBufferPointer({ buffer -> OSStatus in
        return AudioFormatGetProperty(kAudioFormatProperty_Decoders, 4, &formatId, &size, buffer.baseAddress)
    }) != 0 {
        return false
    }
    
    for decoder in encoderDescriptions {
        if decoder.mManufacturer == kAppleHardwareAudioCodecManufacturer {
            classDesc = decoder
            return true
        }
    }
    
    return false
}

private final class AudioPlayerSourceDataRequest {
    var remainingCount: Int
    let notify: (Data) -> Void
    
    init(count: Int, notify: (Data) -> Void) {
        self.remainingCount = count
        self.notify = notify
    }
}

private final class AudioPlayerSourceContext {
    private var id: Int32!
    
    private let account: Account
    private let resource: MediaResource
    
    private let canonicalBasicStreamDescription: AudioStreamBasicDescription
    
    private var streamId: AudioFileStreamID?
    private var dataDisposable = MetaDisposable()
    private var fetchDisposable = MetaDisposable()
    
    private var currentDataOffset: Int = 0
    
    private var parsedHeader = false
    private var audioDataOffset: Int64?
    private var streamBasicDescription: AudioStreamBasicDescription?
    private var sampleRate: Float64?
    private var packetDuration: Float64?
    
    private var packetBufferSize: Int?
    private var processedPacketsCount: Int = 0
    private var processedPacketsSizeTotal: Int64 = 0
    
    private var converter: AudioConverterRef?
    
    private var dataOverflowBuffer = RingByteBuffer(size: 512 * 1024)
    private var dataRequests = Bag<AudioPlayerSourceDataRequest>()
    
    private var currentDataRequest: Disposable?
    
    init(account: Account, resource: MediaResource) {
        self.account = account
        self.resource = resource
        
        self.canonicalBasicStreamDescription = audioPlayerCanonicalStreamDescription()
        
        
        
        assert(audioPlayerSourceQueue.isCurrent())
        
        self.id = registerPlayerContext(self)
    }
    
    deinit {
        assert(audioPlayerSourceQueue.isCurrent())
        
        self.dataDisposable.dispose()
        self.fetchDisposable.dispose()
        
        unregisterPlayerContext(self.id)
        
        self.closeConverter()
        self.closeStream()
    }
    
    func withOpenedStreamId(_ f: @noescape(AudioFileStreamID) -> Void) {
        if let streamId = self.streamId {
            f(streamId)
        } else {
            let status = AudioFileStreamOpen(unsafeBitCast(intptr_t(self.id), to: UnsafeMutablePointer<Void>.self), propertyProc, packetsProc, kAudioFileMP3Type, &self.streamId)
            if let streamId = self.streamId, status == noErr {
                f(streamId)
            }
        }
    }
    
    func withOpenedConverter(_ f: @noescape(AudioConverterRef) -> Void) {
        withOpenedStreamId { streamId in
            if let converter = self.converter {
                f(converter)
            } else {
                guard var streamBasicDescription = self.streamBasicDescription else {
                    return
                }
                
                var classDesc = AudioClassDescription()
                var canonicalBasicStreamDescription = self.canonicalBasicStreamDescription
                var converter: AudioConverterRef?
                
                if getHardwareCodecClassDesc(formatId: streamBasicDescription.mFormatID, classDesc: &classDesc) {
                    AudioConverterNewSpecific(&streamBasicDescription, &canonicalBasicStreamDescription, 1, &classDesc, &converter)
                }
                
                if converter == nil {
                    AudioConverterNew(&streamBasicDescription, &canonicalBasicStreamDescription, &converter)
                }
                
                if let converter = converter {
                    let audioFileTypeHint = kAudioFileMP3Type
                    
                    if audioFileTypeHint != kAudioFileAAC_ADTSType {
                        var cookieSize: UInt32 = 0
                        var writable: DarwinBoolean = false
                        
                        let status = AudioFileStreamGetPropertyInfo(streamId, kAudioFileStreamProperty_MagicCookieData, &cookieSize, &writable)
                        if status == noErr {
                            var cookieData = malloc(Int(cookieSize))!
                            if AudioFileStreamGetProperty(streamId, kAudioFileStreamProperty_MagicCookieData, &cookieSize, cookieData) != noErr {
                                free(cookieData)
                                AudioConverterDispose(converter)
                                return
                            }
                            
                            if AudioConverterSetProperty(converter, kAudioConverterDecompressionMagicCookie, cookieSize, &cookieData) != noErr {
                                free(cookieData)
                                AudioConverterDispose(converter)
                                return
                            }
                            
                            free(cookieData)
                        }
                    }
                
                    self.converter = converter
                    f(converter)
                }
            }
        }
    }
    
    func closeStream() {
        if let streamId = self.streamId {
            AudioFileStreamClose(streamId)
            self.streamId = nil
        }
    }
    
    func closeConverter() {
        if let converter = self.converter {
            AudioConverterDispose(converter)
            self.converter = nil
        }
    }
    
    func prefetch() {
        assert(audioPlayerSourceQueue.isCurrent())
        
        self.fetchDisposable.set(self.account.postbox.mediaBox.fetchedResource(self.resource).start())
    }
    
    func play() {
        assert(audioPlayerSourceQueue.isCurrent())
        
        let status = AudioFileStreamOpen(unsafeBitCast(intptr_t(self.id), to: UnsafeMutablePointer<Void>.self), propertyProc, packetsProc, kAudioFileMP3Type, &self.streamId)
        if status != noErr {
            print("status \(status)")
        }
        
        let disposable = DisposableSet()
        self.dataDisposable.set(disposable)
        
        let data = account.postbox.mediaBox.resourceData(self.resource, complete: false)
            |> deliverOn(audioPlayerSourceQueue)
        
        var previousSize = 0
        disposable.add(data.start(next: { [weak self] data in
            if let strongSelf = self, let streamId = strongSelf.streamId, data.size > previousSize {
                print("data size \(data.size)")
                let file = fopen(data.path, "rb")
                fseek(file, previousSize, SEEK_SET)
                let currentSize = data.size - previousSize
                previousSize = data.size
                let bytes = malloc(currentSize)!
                fread(bytes, currentSize, 1, file)
                fclose(file)
                
                var offset = 0
                while offset < currentSize {
                    let blockSize = min(64 * 1024, currentSize - offset)
                    
                    let status = AudioFileStreamParseBytes(streamId, UInt32(blockSize), bytes.advanced(by: offset), [])
                    if status != noErr {
                        print("status = \(status)")
                    }
                    
                    offset += 64 * 1024
                }
                
                
                free(bytes)
            }
        }))
    }
    
    private func requestSampleBytes(count: Int, data: (Data) -> Void) -> Bag<AudioPlayerSourceDataRequest>.Index {
        assert(audioPlayerSourceQueue.isCurrent())
        
        let index = dataRequests.add(AudioPlayerSourceDataRequest(count: count, notify: { bytes in
            data(bytes)
        }))
        
        self.processDataRequests()
        
        return index
    }
    
    private func cancelSampleBytesRequest(_ index: Bag<AudioPlayerSourceDataRequest>.Index) {
        assert(audioPlayerSourceQueue.isCurrent())
        
        self.dataRequests.remove(index)
    }
    
    private func processDataRequests() {
        assert(audioPlayerSourceQueue.isCurrent())
        
        if self.currentDataRequest != nil {
            return
        }
        
        if !self.dataRequests.isEmpty {
            self.processBuffer()
        }
        
        if !self.dataRequests.isEmpty {
            let data = account.postbox.mediaBox.resourceData(self.resource, complete: false)
                |> deliverOn(audioPlayerSourceQueue)
            self.currentDataRequest = data.start(next: { [weak self] data in
                if let strongSelf = self {
                    let availableBytes = data.size - strongSelf.currentDataOffset
                    let blockSize = min(availableBytes, 10 * 1024)
                    
                    if blockSize != 0 {
                        strongSelf.withOpenedStreamId { streamId in
                            let file = fopen(data.path, "rb")
                            fseek(file, strongSelf.currentDataOffset, SEEK_SET)
                            strongSelf.currentDataOffset += blockSize
                            let bytes = malloc(blockSize)!
                            fread(bytes, blockSize, 1, file)
                            fclose(file)
                            
                            let status = AudioFileStreamParseBytes(streamId, UInt32(blockSize), bytes, [])
                            if status != noErr {
                                print("status = \(status)")
                            }
                        }
                        
                        strongSelf.currentDataRequest?.dispose()
                        strongSelf.currentDataRequest = nil
                        strongSelf.processDataRequests()
                    }
                }
            })
        }
    }
    
    private func processBuffer() {
        assert(audioPlayerSourceQueue.isCurrent())
        
        var availableBytes = self.dataOverflowBuffer.availableBytes
        
        while availableBytes > 0 {
            if let (index, dataRequest) = self.dataRequests.first {
                let blockSize = min(dataRequest.remainingCount, availableBytes)
                if blockSize == 0 {
                    break
                }
                
                let data = self.dataOverflowBuffer.dequeue(count: blockSize)
                
                dataRequest.remainingCount -= blockSize
                availableBytes -= blockSize
                
                if dataRequest.remainingCount == 0 {
                    self.dataRequests.remove(index)
                }
                
                dataRequest.notify(data)
            } else {
                break
            }
        }
    }
}

final class AudioPlayerSource {
    private var contextRef: Unmanaged<AudioPlayerSourceContext>?
    
    init(account: Account, resource: MediaResource) {
        audioPlayerSourceQueue.async {
            let context = AudioPlayerSourceContext(account: account, resource: resource)
            self.contextRef = Unmanaged.passRetained(context)
            context.prefetch()
            //context.play()
        }
    }
    
    deinit {
        let contextRef = self.contextRef
        audioPlayerSourceQueue.async {
            contextRef?.release()
        }
    }
    
    func requestSampleBytes(count: Int) -> Signal<Data, NoError> {
        return Signal { [weak self] subscriber in
            let disposable = MetaDisposable()
            if let strongSelf = self {
                audioPlayerSourceQueue.async {
                    if let context = strongSelf.contextRef?.takeUnretainedValue() {
                        var enqueuedCount = 0
                        let index = context.requestSampleBytes(count: count, data: { data in
                            enqueuedCount += data.count
                            subscriber.putNext(data)
                            if enqueuedCount >= count {
                                subscriber.putCompletion()
                            }
                        })
                        disposable.set(ActionDisposable { [weak strongSelf] in
                            audioPlayerSourceQueue.async {
                                strongSelf?.cancelSampleBytesRequest(index)
                            }
                        })
                    }
                }
            }
            return disposable
        }
    }
    
    private func cancelSampleBytesRequest(_ index: Bag<AudioPlayerSourceDataRequest>.Index) {
        assert(audioPlayerSourceQueue.isCurrent())
        
        if let context = self.contextRef?.takeUnretainedValue() {
            context.cancelSampleBytesRequest(index)
        }
    }
}
