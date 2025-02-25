import Foundation
#if !os(macOS)
import UIKit
#else
import AppKit
import TGUIKit
#endif
import CoreMedia
import SwiftSignalKit
import FFMpegBinding
import Postbox
import ManagedFile

private func FFMpegFileReader_readPacketCallback(userData: UnsafeMutableRawPointer?, buffer: UnsafeMutablePointer<UInt8>?, bufferSize: Int32) -> Int32 {
    guard let buffer else {
        return FFMPEG_CONSTANT_AVERROR_EOF
    }
    let context = Unmanaged<FFMpegFileReader>.fromOpaque(userData!).takeUnretainedValue()
    
    switch context.source {
    case let .file(file):
        let result = file.read(buffer, Int(bufferSize))
        if result == 0 {
            return FFMPEG_CONSTANT_AVERROR_EOF
        }
        return Int32(result)
    case let .resource(resource):
        let readCount = min(256 * 1024, Int64(bufferSize))
        
        var bufferOffset = 0
        let doRead: (Range<Int64>) -> Void = { range in
            //TODO:improve thread safe read if incomplete
            if let (file, readSize) = resource.mediaBox.internal_resourceData(id: resource.resource.id, size: resource.resourceSize, in: range) {
                let effectiveReadSize = max(0, min(Int(readCount) - bufferOffset, readSize))
                let count = file.read(buffer.advanced(by: bufferOffset), effectiveReadSize)
                bufferOffset += count
                resource.readingPosition += Int64(count)
            }
        }
        
        var mappedRangePosition: Int64 = 0
        for mappedRange in resource.mappedRanges {
            let bytesToRead = readCount - Int64(bufferOffset)
            if bytesToRead <= 0 {
                break
            }
            
            let mappedRangeSize = mappedRange.upperBound - mappedRange.lowerBound
            let mappedRangeReadingPosition = resource.readingPosition - mappedRangePosition
            
            if mappedRangeReadingPosition >= 0 && mappedRangeReadingPosition < mappedRangeSize {
                let mappedRangeAvailableBytesToRead = mappedRangeSize - mappedRangeReadingPosition
                let mappedRangeBytesToRead = min(bytesToRead, mappedRangeAvailableBytesToRead)
                if mappedRangeBytesToRead > 0 {
                    let mappedReadRange = (mappedRange.lowerBound + mappedRangeReadingPosition) ..< (mappedRange.lowerBound + mappedRangeReadingPosition + mappedRangeBytesToRead)
                    doRead(mappedReadRange)
                }
            }
            
            mappedRangePosition += mappedRangeSize
        }
        if bufferOffset != 0 {
            return Int32(bufferOffset)
        } else {
            return FFMPEG_CONSTANT_AVERROR_EOF
        }
    }
}

private func FFMpegFileReader_seekCallback(userData: UnsafeMutableRawPointer?, offset: Int64, whence: Int32) -> Int64 {
    let context = Unmanaged<FFMpegFileReader>.fromOpaque(userData!).takeUnretainedValue()
    if (whence & FFMPEG_AVSEEK_SIZE) != 0 {
        switch context.source {
        case let .file(file):
            return file.getSize() ?? 0
        case let .resource(resource):
            return resource.size
        }
    } else {
        switch context.source {
        case let .file(file):
            let _ = file.seek(position: offset)
        case let .resource(resource):
            resource.readingPosition = offset
        }
        return offset
    }
}

public final class FFMpegFileReader {
    public enum SourceDescription {
        case file(String)
        case resource(mediaBox: MediaBox, resource: MediaResource, resourceSize: Int64, mappedRanges: [Range<Int64>])
    }
    
    public final class StreamInfo: Equatable {
        public let index: Int
        public let codecId: Int32
        public let startTime: CMTime
        public let duration: CMTime
        public let timeBase: CMTimeValue
        public let timeScale: CMTimeScale
        public let fps: CMTime
        
        public init(index: Int, codecId: Int32, startTime: CMTime, duration: CMTime, timeBase: CMTimeValue, timeScale: CMTimeScale, fps: CMTime) {
            self.index = index
            self.codecId = codecId
            self.startTime = startTime
            self.duration = duration
            self.timeBase = timeBase
            self.timeScale = timeScale
            self.fps = fps
        }
        
        public static func ==(lhs: StreamInfo, rhs: StreamInfo) -> Bool {
            if lhs.index != rhs.index {
                return false
            }
            if lhs.codecId != rhs.codecId {
                return false
            }
            if lhs.startTime != rhs.startTime {
                return false
            }
            if lhs.duration != rhs.duration {
                return false
            }
            if lhs.timeBase != rhs.timeBase {
                return false
            }
            if lhs.timeScale != rhs.timeScale {
                return false
            }
            if lhs.fps != rhs.fps {
                return false
            }
            return true
        }
    }
    
    fileprivate enum Source {
        final class Resource {
            let mediaBox: MediaBox
            let resource: MediaResource
            let resourceSize: Int64
            let mappedRanges: [Range<Int64>]
            let size: Int64
            var readingPosition: Int64 = 0
            
            init(mediaBox: MediaBox, resource: MediaResource, resourceSize: Int64, mappedRanges: [Range<Int64>]) {
                self.mediaBox = mediaBox
                self.resource = resource
                self.resourceSize = resourceSize
                self.mappedRanges = mappedRanges
                
                var size: Int64 = 0
                for range in mappedRanges {
                    size += range.upperBound - range.lowerBound
                }
                self.size = size
            }
        }
        
        case file(ManagedFile)
        case resource(Resource)
    }
    
    private enum Decoder {
        case videoPassthrough(FFMpegMediaPassthroughVideoFrameDecoder)
        case video(FFMpegMediaVideoFrameDecoder)
        case audio(FFMpegAudioFrameDecoder)
        
        func send(frame: MediaTrackDecodableFrame) -> Bool {
            switch self {
            case let .videoPassthrough(decoder):
                decoder.send(frame: frame)
            case let .video(decoder):
                decoder.send(frame: frame)
            case let .audio(decoder):
                decoder.send(frame: frame)
            }
        }
        
        func sendEnd() -> Bool {
            switch self {
            case let .videoPassthrough(decoder):
                return decoder.sendEndToDecoder()
            case let .video(decoder):
                return decoder.sendEndToDecoder()
            case let .audio(decoder):
                return decoder.sendEndToDecoder()
            }
        }
    }
    
    private final class Stream {
        let info: StreamInfo
        let decoder: Decoder
        
        init(info: StreamInfo, decoder: Decoder) {
            self.info = info
            self.decoder = decoder
        }
    }
    
    public  enum SelectedStream {
        public enum MediaType {
            case audio
            case video
        }
        
        case mediaType(MediaType)
        case index(Int)
    }
    
    public enum Seek {
        case stream(streamIndex: Int, pts: Int64)
        case direct(position: Double)
    }
    
    public enum ReadFrameResult {
        case frame(MediaTrackFrame)
        case waitingForMoreData
        case endOfStream
        case error
    }
    
    private(set) var readingError = false
    private var stream: Stream?
    private var avIoContext: FFMpegAVIOContext?
    private var avFormatContext: FFMpegAVFormatContext?

    fileprivate let source: Source
    
    private var didSendEndToDecoder: Bool = false
    private var hasReadToEnd: Bool = false
    
    private var maxReadablePts: (streamIndex: Int, pts: Int64, isEnded: Bool)?
    private var lastReadPts: (streamIndex: Int, pts: Int64)?
    private var isWaitingForMoreData: Bool = false
    
    public init?(source: SourceDescription, passthroughDecoder: Bool = false, useHardwareAcceleration: Bool, selectedStream: SelectedStream, seek: Seek?, maxReadablePts: (streamIndex: Int, pts: Int64, isEnded: Bool)?) {
        let _ = FFMpegMediaFrameSourceContextHelpers.registerFFMpegGlobals
        
        switch source {
        case let .file(path):
            guard let file = ManagedFile(queue: nil, path: path, mode: .read) else {
                return nil
            }
            self.source = .file(file)
        case let .resource(mediaBox, resource, resourceSize, mappedRanges):
            self.source = .resource(Source.Resource(mediaBox: mediaBox, resource: resource, resourceSize: resourceSize, mappedRanges: mappedRanges))
        }
        
        self.maxReadablePts = maxReadablePts
        
        let avFormatContext = FFMpegAVFormatContext()
        /*if hintVP9 {
            avFormatContext.forceVideoCodecId(FFMpegCodecIdVP9)
        }*/
        let ioBufferSize = 64 * 1024
        
        let avIoContext = FFMpegAVIOContext(bufferSize: Int32(ioBufferSize), opaqueContext: Unmanaged.passUnretained(self).toOpaque(), readPacket: FFMpegFileReader_readPacketCallback, writePacket: nil, seek: FFMpegFileReader_seekCallback, isSeekable: true)
        self.avIoContext = avIoContext
        
        avFormatContext.setIO(self.avIoContext!)
        
        if !avFormatContext.openInput(withDirectFilePath: nil) {
            self.readingError = true
            return nil
        }
        
        if !avFormatContext.findStreamInfo() {
            self.readingError = true
            return nil
        }
        
        self.avFormatContext = avFormatContext
        
        var stream: Stream?
        outer: for mediaType in [.audio, .video] as [SelectedStream.MediaType] {
            streamSearch: for streamIndexNumber in avFormatContext.streamIndices(for: mediaType == .video ? FFMpegAVFormatStreamTypeVideo : FFMpegAVFormatStreamTypeAudio) {
                let streamIndex = Int(streamIndexNumber.int32Value)
                if avFormatContext.isAttachedPic(atStreamIndex: Int32(streamIndex)) {
                    continue
                }
                
                switch selectedStream {
                case let .mediaType(selectedMediaType):
                    if mediaType != selectedMediaType {
                        continue streamSearch
                    }
                case let .index(index):
                    if streamIndex != index {
                        continue streamSearch
                    }
                }
                
                let codecId = avFormatContext.codecId(atStreamIndex: Int32(streamIndex))
                
                let fpsAndTimebase = avFormatContext.fpsAndTimebase(forStreamIndex: Int32(streamIndex), defaultTimeBase: CMTimeMake(value: 1, timescale: 40000))
                let (fps, timebase) = (fpsAndTimebase.fps, fpsAndTimebase.timebase)
                
                let startTime: CMTime
                let rawStartTime = avFormatContext.startTime(atStreamIndex: Int32(streamIndex))
                if rawStartTime == Int64(bitPattern: 0x8000000000000000 as UInt64) {
                    startTime = CMTime(value: 0, timescale: timebase.timescale)
                } else {
                    startTime = CMTimeMake(value: rawStartTime, timescale: timebase.timescale)
                }
                let duration = CMTimeMake(value: avFormatContext.duration(atStreamIndex: Int32(streamIndex)), timescale: timebase.timescale)
                
                let metrics = avFormatContext.metricsForStream(at: Int32(streamIndex))
                
                let rotationAngle: Double = metrics.rotationAngle
                //let aspect = Double(metrics.width) / Double(metrics.height)
                
                let info = StreamInfo(
                    index: streamIndex,
                    codecId: codecId,
                    startTime: startTime,
                    duration: duration,
                    timeBase: timebase.value,
                    timeScale: timebase.timescale,
                    fps: fps
                )
                
                switch mediaType {
                case .video:
                    if passthroughDecoder {
                        var videoFormatData: FFMpegMediaPassthroughVideoFrameDecoder.VideoFormatData?
                        if codecId == FFMpegCodecIdMPEG4 {
                            videoFormatData = FFMpegMediaPassthroughVideoFrameDecoder.VideoFormatData(codecType: kCMVideoCodecType_MPEG4Video, width: metrics.width, height: metrics.height, extraData: Data(bytes: metrics.extradata, count: Int(metrics.extradataSize)))
                        } else if codecId == FFMpegCodecIdH264 {
                            videoFormatData = FFMpegMediaPassthroughVideoFrameDecoder.VideoFormatData(codecType: kCMVideoCodecType_H264, width: metrics.width, height: metrics.height, extraData: Data(bytes: metrics.extradata, count: Int(metrics.extradataSize)))
                        } else if codecId == FFMpegCodecIdHEVC {
                            videoFormatData = FFMpegMediaPassthroughVideoFrameDecoder.VideoFormatData(codecType: kCMVideoCodecType_HEVC, width: metrics.width, height: metrics.height, extraData: Data(bytes: metrics.extradata, count: Int(metrics.extradataSize)))
                        } else if codecId == FFMpegCodecIdAV1 {
                            videoFormatData = FFMpegMediaPassthroughVideoFrameDecoder.VideoFormatData(codecType: kCMVideoCodecType_AV1, width: metrics.width, height: metrics.height, extraData: Data(bytes: metrics.extradata, count: Int(metrics.extradataSize)))
                        }
                        
                        if let videoFormatData {
                            stream = Stream(
                                info: info,
                                decoder: .videoPassthrough(FFMpegMediaPassthroughVideoFrameDecoder(videoFormatData: videoFormatData, rotationAngle: rotationAngle))
                            )
                            break outer
                        }
                    } else {
                        if let codec = FFMpegAVCodec.find(forId: codecId, preferHardwareAccelerationCapable: useHardwareAcceleration) {
                            let codecContext = FFMpegAVCodecContext(codec: codec)
                            if avFormatContext.codecParams(atStreamIndex: Int32(streamIndex), to: codecContext) {
                                if useHardwareAcceleration {
                                    codecContext.setupHardwareAccelerationIfPossible()
                                }
                                
                                if codecContext.open() {
                                    stream = Stream(
                                        info: info,
                                        decoder: .video(FFMpegMediaVideoFrameDecoder(codecContext: codecContext))
                                    )
                                    break outer
                                }
                            }
                        }
                    }
                case .audio:
                    if let codec = FFMpegAVCodec.find(forId: codecId, preferHardwareAccelerationCapable: false) {
                        let codecContext = FFMpegAVCodecContext(codec: codec)
                        if avFormatContext.codecParams(atStreamIndex: Int32(streamIndex), to: codecContext) {
                            if codecContext.open() {
                                stream = Stream(
                                    info: info,
                                    decoder: .audio(FFMpegAudioFrameDecoder(codecContext: codecContext, sampleRate: 48000, channelCount: 1))
                                )
                                break outer
                            }
                        }
                    }
                }
            }
        }
        
        guard let stream else {
            self.readingError = true
            return nil
        }
        
        self.stream = stream
        
        if let seek {
            switch seek {
            case let .stream(streamIndex, pts):
                avFormatContext.seekFrame(forStreamIndex: Int32(streamIndex), pts: pts, positionOnKeyframe: true)
            case let .direct(position):
                avFormatContext.seekFrame(forStreamIndex: Int32(stream.info.index), pts: CMTimeMakeWithSeconds(Float64(position), preferredTimescale: stream.info.timeScale).value, positionOnKeyframe: true)
            }
        } else {
            avFormatContext.seekFrame(forStreamIndex: Int32(stream.info.index), pts: 0, positionOnKeyframe: true)
        }
    }
    
    deinit {
    }
    
    private func readPacketInternal() -> FFMpegPacket? {
        guard let avFormatContext = self.avFormatContext else {
            return nil
        }
        
        if let maxReadablePts = self.maxReadablePts, !maxReadablePts.isEnded, let lastReadPts = self.lastReadPts, lastReadPts.streamIndex == maxReadablePts.streamIndex, lastReadPts.pts == maxReadablePts.pts {
            self.isWaitingForMoreData = true
            return nil
        }
        
        let packet = FFMpegPacket()
        if avFormatContext.readFrame(into: packet) {
            self.lastReadPts = (Int(packet.streamIndex), packet.pts)
            return packet
        } else {
            self.hasReadToEnd = true
            return nil
        }
    }
    
    func readDecodableFrame() -> MediaTrackDecodableFrame? {
        while !self.readingError && !self.hasReadToEnd && !self.isWaitingForMoreData {
            if let packet = self.readPacketInternal() {
                if let stream = self.stream, Int(packet.streamIndex) == stream.info.index {
                    let packetPts = packet.pts
                    
                    let pts = CMTimeMake(value: packetPts, timescale: stream.info.timeScale)
                    let dts = CMTimeMake(value: packet.dts, timescale: stream.info.timeScale)
                    
                    let duration: CMTime
                    
                    let frameDuration = packet.duration
                    if frameDuration != 0 {
                        duration = CMTimeMake(value: frameDuration * stream.info.timeBase, timescale: stream.info.timeScale)
                    } else {
                        duration = CMTimeConvertScale(CMTimeMakeWithSeconds(1.0 / stream.info.fps.seconds, preferredTimescale: stream.info.timeScale), timescale: stream.info.timeScale, method: .quickTime)
                    }
                    
                    let frame = MediaTrackDecodableFrame(type: .video, packet: packet, pts: pts, dts: dts, duration: duration)
                    return frame
                }
            } else {
                break
            }
        }
        
        return nil
    }
    
    public func readFrame() -> ReadFrameResult {
        guard let stream = self.stream else {
            return .error
        }
        
        while true {
            var result: MediaTrackFrame?
            switch stream.decoder {
            case let .video(decoder):
                result = decoder.decode(ptsOffset: nil, forceARGB: false, unpremultiplyAlpha: false, displayImmediately: false)
            case let .videoPassthrough(decoder):
                result = decoder.decode()
            case let .audio(decoder):
                result = decoder.decode()
            }
            if let result {
                if self.didSendEndToDecoder {
                    assert(true)
                }
                return .frame(result)
            }
            
            if !self.isWaitingForMoreData && !self.readingError && !self.hasReadToEnd {
                if let decodableFrame = self.readDecodableFrame() {
                    let _ = stream.decoder.send(frame: decodableFrame)
                }
            } else if self.hasReadToEnd && !self.didSendEndToDecoder {
                self.didSendEndToDecoder = true
                let _ = stream.decoder.sendEnd()
            } else {
                break
            }
        }
        
        if self.isWaitingForMoreData {
            return .waitingForMoreData
        } else {
            return .endOfStream
        }
    }
    
    public func updateMaxReadablePts(pts: (streamIndex: Int, pts: Int64, isEnded: Bool)?) {
        if self.maxReadablePts?.streamIndex != pts?.streamIndex || self.maxReadablePts?.pts != pts?.pts {
            self.maxReadablePts = pts
            
            if let pts {
                if pts.isEnded {
                    self.isWaitingForMoreData = false
                } else {
                    if self.lastReadPts?.streamIndex != pts.streamIndex || self.lastReadPts?.pts != pts.pts {
                        self.isWaitingForMoreData = false
                    }
                }
            } else {
                self.isWaitingForMoreData = false
            }
        }
    }
}
