import Foundation
#if !os(macOS)
import UIKit
#else
import AppKit
#endif
import SwiftSignalKit
import Postbox
import TelegramCore
import FFMpegBinding

private func readPacketCallback(userData: UnsafeMutableRawPointer?, buffer: UnsafeMutablePointer<UInt8>?, bufferSize: Int32) -> Int32 {
    let context = Unmanaged<UniversalSoftwareVideoSourceImpl>.fromOpaque(userData!).takeUnretainedValue()
    
    let data: Signal<(Data, Bool), NoError>
    
    let readCount = min(256 * 1024, Int64(bufferSize))
    let requestRange: Range<Int64> = context.readingOffset ..< (context.readingOffset + readCount)
    
    context.currentNumberOfReads += 1
    context.currentReadBytes += readCount
    
    let semaphore = DispatchSemaphore(value: 0)
    data = context.mediaBox.resourceData(context.fileReference.media.resource, size: context.size, in: requestRange, mode: .partial)
    let requiredDataIsNotLocallyAvailable = context.requiredDataIsNotLocallyAvailable
    var fetchedData: Data?
    let fetchDisposable = MetaDisposable()
    let isInitialized = context.videoStream != nil || context.automaticallyFetchHeader
    let mediaBox = context.mediaBox
    let reference = context.fileReference.resourceReference(context.fileReference.media.resource)
    let disposable = data.start(next: { result in
        let (data, isComplete) = result
        if data.count == readCount || isComplete {
            fetchedData = data
            semaphore.signal()
        } else {
            if isInitialized {
                fetchDisposable.set(fetchedMediaResource(mediaBox: mediaBox, reference: reference, ranges: [(requestRange, .maximum)]).start())
            }
            requiredDataIsNotLocallyAvailable?()
        }
    })
    let cancelDisposable = context.cancelRead.start(next: { value in
        if value {
            semaphore.signal()
        }
    })
    semaphore.wait()
    
    disposable.dispose()
    cancelDisposable.dispose()
    fetchDisposable.dispose()
    
    if let fetchedData = fetchedData {
        fetchedData.withUnsafeBytes { byteBuffer -> Void in
            guard let bytes = byteBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return
            }
            memcpy(buffer, bytes, fetchedData.count)
        }
        let fetchedCount = Int32(fetchedData.count)
        context.readingOffset += Int64(fetchedCount)
        return fetchedCount
    } else {
        return 0
    }
}

private func seekCallback(userData: UnsafeMutableRawPointer?, offset: Int64, whence: Int32) -> Int64 {
    let context = Unmanaged<UniversalSoftwareVideoSourceImpl>.fromOpaque(userData!).takeUnretainedValue()
    if (whence & FFMPEG_AVSEEK_SIZE) != 0 {
        return Int64(context.size)
    } else {
        context.readingOffset = offset
        return offset
    }
}

private final class SoftwareVideoStream {
    let index: Int
    let fps: CMTime
    let timebase: CMTime
    let duration: CMTime
    let decoder: FFMpegMediaVideoFrameDecoder
    let rotationAngle: Double
    let aspect: Double
    
    init(index: Int, fps: CMTime, timebase: CMTime, duration: CMTime, decoder: FFMpegMediaVideoFrameDecoder, rotationAngle: Double, aspect: Double) {
        self.index = index
        self.fps = fps
        self.timebase = timebase
        self.duration = duration
        self.decoder = decoder
        self.rotationAngle = rotationAngle
        self.aspect = aspect
    }
}

private final class UniversalSoftwareVideoSourceImpl {
    fileprivate let mediaBox: MediaBox
    fileprivate let fileReference: FileMediaReference
    fileprivate let size: Int64
    fileprivate let automaticallyFetchHeader: Bool
    
    fileprivate let state: ValuePromise<UniversalSoftwareVideoSourceState>
    
    fileprivate var avIoContext: FFMpegAVIOContext!
    fileprivate var avFormatContext: FFMpegAVFormatContext!
    fileprivate var videoStream: SoftwareVideoStream!
    
    fileprivate var readingOffset: Int64 = 0
    
    fileprivate var cancelRead: Signal<Bool, NoError>
    fileprivate var requiredDataIsNotLocallyAvailable: (() -> Void)?
    fileprivate var currentNumberOfReads: Int = 0
    fileprivate var currentReadBytes: Int64 = 0
    
    init?(mediaBox: MediaBox, fileReference: FileMediaReference, state: ValuePromise<UniversalSoftwareVideoSourceState>, cancelInitialization: Signal<Bool, NoError>, automaticallyFetchHeader: Bool, hintVP9: Bool = false) {
        guard let size = fileReference.media.size else {
            return nil
        }
        
        self.mediaBox = mediaBox
        self.fileReference = fileReference
        self.size = size
        self.automaticallyFetchHeader = automaticallyFetchHeader
        
        self.state = state
        state.set(.initializing)
        
        self.cancelRead = cancelInitialization
        
        let ioBufferSize = 1 * 1024
        
        guard let avIoContext = FFMpegAVIOContext(bufferSize: Int32(ioBufferSize), opaqueContext: Unmanaged.passUnretained(self).toOpaque(), readPacket: readPacketCallback, writePacket: nil, seek: seekCallback) else {
            return nil
        }
        self.avIoContext = avIoContext
        
        let avFormatContext = FFMpegAVFormatContext()
        if hintVP9 {
            avFormatContext.forceVideoCodecId(FFMpegCodecIdVP9)
        }
        avFormatContext.setIO(avIoContext)
        
        if !avFormatContext.openInput() {
            return nil
        }
        
        if !avFormatContext.findStreamInfo() {
            return nil
        }
        
        print("Header read in \(self.currentReadBytes) bytes")
        self.currentReadBytes = 0
        
        self.avFormatContext = avFormatContext
        
        var videoStream: SoftwareVideoStream?
        
        for streamIndexNumber in avFormatContext.streamIndices(for: FFMpegAVFormatStreamTypeVideo) {
            let streamIndex = streamIndexNumber.int32Value
            if avFormatContext.isAttachedPic(atStreamIndex: streamIndex) {
                continue
            }
            
            let codecId = avFormatContext.codecId(atStreamIndex: streamIndex)
            
            let fpsAndTimebase = avFormatContext.fpsAndTimebase(forStreamIndex: streamIndex, defaultTimeBase: CMTimeMake(value: 1, timescale: 40000))
            let (fps, timebase) = (fpsAndTimebase.fps, fpsAndTimebase.timebase)
            
            let duration = CMTimeMake(value: avFormatContext.duration(atStreamIndex: streamIndex), timescale: timebase.timescale)
            
            let metrics = avFormatContext.metricsForStream(at: streamIndex)
            
            let rotationAngle: Double = metrics.rotationAngle
            let aspect = Double(metrics.width) / Double(metrics.height)
            
            if let codec = FFMpegAVCodec.find(forId: codecId) {
                let codecContext = FFMpegAVCodecContext(codec: codec)
                if avFormatContext.codecParams(atStreamIndex: streamIndex, to: codecContext) {
                    if codecContext.open() {
                        videoStream = SoftwareVideoStream(index: Int(streamIndex), fps: fps, timebase: timebase, duration: duration, decoder: FFMpegMediaVideoFrameDecoder(codecContext: codecContext), rotationAngle: rotationAngle, aspect: aspect)
                        break
                    }
                }
            }
        }
        
        if let videoStream = videoStream {
            self.videoStream = videoStream
        } else {
            return nil
        }
        
        state.set(.ready)
    }
    
    private func readPacketInternal() -> FFMpegPacket? {
        guard let avFormatContext = self.avFormatContext else {
            return nil
        }
        
        let packet = FFMpegPacket()
        if avFormatContext.readFrame(into: packet) {
            return packet
        } else {
            return nil
        }
    }
    
    func readDecodableFrame() -> (MediaTrackDecodableFrame?, Bool) {
        var frames: [MediaTrackDecodableFrame] = []
        var endOfStream = false
        
        while frames.isEmpty {
            if let packet = self.readPacketInternal() {
                if let videoStream = videoStream, Int(packet.streamIndex) == videoStream.index {
                    let packetPts = packet.pts
                    
                    let pts = CMTimeMake(value: packetPts, timescale: videoStream.timebase.timescale)
                    let dts = CMTimeMake(value: packet.dts, timescale: videoStream.timebase.timescale)
                    
                    let duration: CMTime
                    
                    let frameDuration = packet.duration
                    if frameDuration != 0 {
                        duration = CMTimeMake(value: frameDuration * videoStream.timebase.value, timescale: videoStream.timebase.timescale)
                    } else {
                        duration = videoStream.fps
                    }
                    
                    let frame = MediaTrackDecodableFrame(type: .video, packet: packet, pts: pts, dts: dts, duration: duration)
                    frames.append(frame)
                }
            } else {
                endOfStream = true
                break
            }
        }
        
        if endOfStream {
            if let videoStream = self.videoStream {
                videoStream.decoder.reset()
            }
        }
        
        return (frames.first, endOfStream)
    }
    
    private func seek(timestamp: Double) {
        if let stream = self.videoStream, let avFormatContext = self.avFormatContext {
            let pts = CMTimeMakeWithSeconds(timestamp, preferredTimescale: stream.timebase.timescale)
            avFormatContext.seekFrame(forStreamIndex: Int32(stream.index), pts: pts.value, positionOnKeyframe: true)
            stream.decoder.reset()
        }
    }
    
    func readImage(at timestamp: Double) -> (UIImage?, CGFloat, CGFloat, Bool) {
        guard let videoStream = self.videoStream, let _ = self.avFormatContext else {
            return (nil, 0.0, 1.0, false)
        }
        
        self.seek(timestamp: timestamp)
    
        self.currentNumberOfReads = 0
        self.currentReadBytes = 0
        for i in 0 ..< 10 {
            let _ = i
            let (decodableFrame, loop) = self.readDecodableFrame()
            if let decodableFrame = decodableFrame {
                if let renderedFrame = videoStream.decoder.render(frame: decodableFrame) {
                    print("Frame rendered in \(self.currentNumberOfReads) reads, \(self.currentReadBytes) bytes, total frames read: \(i + 1)")
                    return (renderedFrame, CGFloat(videoStream.rotationAngle), CGFloat(videoStream.aspect), loop)
                }
            }
        }
        print("No frame in \(self.currentReadBytes / 1024) KB")
        return (nil, CGFloat(videoStream.rotationAngle), CGFloat(videoStream.aspect), true)
    }
}

private enum UniversalSoftwareVideoSourceState {
    case initializing
    case failed
    case ready
    case generatingFrame
}

private final class UniversalSoftwareVideoSourceThreadParams: NSObject {
    let mediaBox: MediaBox
    let fileReference: FileMediaReference
    let state: ValuePromise<UniversalSoftwareVideoSourceState>
    let cancelInitialization: Signal<Bool, NoError>
    let automaticallyFetchHeader: Bool
    let hintVP9: Bool
    
    init(
        mediaBox: MediaBox,
        fileReference: FileMediaReference,
        state: ValuePromise<UniversalSoftwareVideoSourceState>,
        cancelInitialization: Signal<Bool, NoError>,
        automaticallyFetchHeader: Bool,
        hintVP9: Bool
    ) {
        self.mediaBox = mediaBox
        self.fileReference = fileReference
        self.state = state
        self.cancelInitialization = cancelInitialization
        self.automaticallyFetchHeader = automaticallyFetchHeader
        self.hintVP9 = hintVP9
    }
}

private final class UniversalSoftwareVideoSourceTakeFrameParams: NSObject {
    let timestamp: Double
    let completion: (UIImage?) -> Void
    let cancel: Signal<Bool, NoError>
    let requiredDataIsNotLocallyAvailable: () -> Void
    
    init(timestamp: Double, completion: @escaping (UIImage?) -> Void, cancel: Signal<Bool, NoError>, requiredDataIsNotLocallyAvailable: @escaping () -> Void) {
        self.timestamp = timestamp
        self.completion = completion
        self.cancel = cancel
        self.requiredDataIsNotLocallyAvailable = requiredDataIsNotLocallyAvailable
    }
}

private final class UniversalSoftwareVideoSourceThread: NSObject {
    @objc static func entryPoint(_ params: UniversalSoftwareVideoSourceThreadParams) {
        let runLoop = RunLoop.current
        
        let timer = Timer(fireAt: .distantFuture, interval: 0.0, target: UniversalSoftwareVideoSourceThread.self, selector: #selector(UniversalSoftwareVideoSourceThread.none), userInfo: nil, repeats: false)
        runLoop.add(timer, forMode: .common)
        
        let source = UniversalSoftwareVideoSourceImpl(mediaBox: params.mediaBox, fileReference: params.fileReference, state: params.state, cancelInitialization: params.cancelInitialization, automaticallyFetchHeader: params.automaticallyFetchHeader)
        Thread.current.threadDictionary["source"] = source
        
        while true {
            runLoop.run(mode: .default, before: .distantFuture)
            if Thread.current.threadDictionary["UniversalSoftwareVideoSourceThread_stop"] != nil {
                break
            }
        }
        
        Thread.current.threadDictionary.removeObject(forKey: "source")
    }
    
    @objc static func none() {
    }
    
    @objc static func stop() {
        Thread.current.threadDictionary["UniversalSoftwareVideoSourceThread_stop"] = "true"
    }
    
    @objc static func takeFrame(_ params: UniversalSoftwareVideoSourceTakeFrameParams) {
        guard let source = Thread.current.threadDictionary["source"] as? UniversalSoftwareVideoSourceImpl else {
            params.completion(nil)
            return
        }
        source.cancelRead = params.cancel
        source.requiredDataIsNotLocallyAvailable = params.requiredDataIsNotLocallyAvailable
        source.state.set(.generatingFrame)
        let image = source.readImage(at: params.timestamp).0
        source.cancelRead = .single(false)
        source.requiredDataIsNotLocallyAvailable = nil
        source.state.set(.ready)
        params.completion(image)
    }
}

public enum UniversalSoftwareVideoSourceTakeFrameResult {
    case waitingForData
    case image(UIImage?)
}

public final class UniversalSoftwareVideoSource {
    private let thread: Thread
    private let stateValue: ValuePromise<UniversalSoftwareVideoSourceState> = ValuePromise(.initializing, ignoreRepeated: true)
    private let cancelInitialization: ValuePromise<Bool> = ValuePromise(false)
    
    public var ready: Signal<Bool, NoError> {
        return self.stateValue.get()
        |> map { value -> Bool in
            switch value {
            case .ready:
                return true
            default:
                return false
            }
        }
    }
    
    public init(mediaBox: MediaBox, fileReference: FileMediaReference, automaticallyFetchHeader: Bool = false, hintVP9: Bool = false) {
        self.thread = Thread(target: UniversalSoftwareVideoSourceThread.self, selector: #selector(UniversalSoftwareVideoSourceThread.entryPoint(_:)), object: UniversalSoftwareVideoSourceThreadParams(mediaBox: mediaBox, fileReference: fileReference, state: self.stateValue, cancelInitialization: self.cancelInitialization.get(), automaticallyFetchHeader: automaticallyFetchHeader, hintVP9: hintVP9))
        self.thread.name = "UniversalSoftwareVideoSource"
        self.thread.start()
    }
    
    deinit {
        UniversalSoftwareVideoSourceThread.self.perform(#selector(UniversalSoftwareVideoSourceThread.stop), on: self.thread, with: nil, waitUntilDone: false)
        self.cancelInitialization.set(true)
    }
    
    public func takeFrame(at timestamp: Double) -> Signal<UniversalSoftwareVideoSourceTakeFrameResult, NoError> {
        return Signal { subscriber in
            let cancel = ValuePromise<Bool>(false)
            UniversalSoftwareVideoSourceThread.self.perform(#selector(UniversalSoftwareVideoSourceThread.takeFrame(_:)), on: self.thread, with: UniversalSoftwareVideoSourceTakeFrameParams(timestamp: timestamp, completion: { image in
                subscriber.putNext(.image(image))
                subscriber.putCompletion()
            }, cancel: cancel.get(), requiredDataIsNotLocallyAvailable: {
                subscriber.putNext(.waitingForData)
            }), waitUntilDone: false)
            
            return ActionDisposable {
                cancel.set(true)
            }
        }
    }
}
