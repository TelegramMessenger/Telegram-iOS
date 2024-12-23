import Foundation
import UIKit
import SwiftSignalKit
import Postbox
import TelegramCore
import FFMpegBinding
import RangeSet

private final class FFMpegMediaFrameExtractContext {
    let fd: Int32
    var readPosition: Int = 0
    let size: Int
    
    var accessedRanges = RangeSet<Int>()
    var maskRanges: RangeSet<Int>?
    var recordAccessedRanges = false
    
    init(fd: Int32, size: Int) {
        self.fd = fd
        self.size = size
    }
}

private func FFMpegMediaFrameExtractContextReadPacketCallback(userData: UnsafeMutableRawPointer?, buffer: UnsafeMutablePointer<UInt8>?, bufferSize: Int32) -> Int32 {
    let context = Unmanaged<FFMpegMediaFrameExtractContext>.fromOpaque(userData!).takeUnretainedValue()
    if context.recordAccessedRanges {
        context.accessedRanges.insert(contentsOf: context.readPosition ..< (context.readPosition + Int(bufferSize)))
    }
    
    let result: Int
    if let maskRanges = context.maskRanges {
        let readRange = context.readPosition ..< (context.readPosition + Int(bufferSize))
        let _ = maskRanges
        let _ = readRange
        result = read(context.fd, buffer, Int(bufferSize))
    } else {
        result = read(context.fd, buffer, Int(bufferSize))
    }
    context.readPosition += Int(bufferSize)
    if result == 0 {
        return FFMPEG_CONSTANT_AVERROR_EOF
    }
    return Int32(result)
}

private func FFMpegMediaFrameExtractContextSeekCallback(userData: UnsafeMutableRawPointer?, offset: Int64, whence: Int32) -> Int64 {
    let context = Unmanaged<FFMpegMediaFrameExtractContext>.fromOpaque(userData!).takeUnretainedValue()
    if (whence & FFMPEG_AVSEEK_SIZE) != 0 {
        return Int64(context.size)
    } else {
        context.readPosition = Int(offset)
        lseek(context.fd, off_t(offset), SEEK_SET)
        return offset
    }
}

private struct FFMpegFrameSegment {
    struct Stream {
        let index: Int
        let startPts: CMTime
        let startPosition: Int64
        var endPts: CMTime
        var endPosition: Int64
        var duration: Double
    }
    
    var audio: Stream?
    var video: Stream?
    
    init() {
    }
    
    mutating func addFrame(isVideo: Bool, index: Int, pts: CMTime, duration: Double, position: Int64, size: Int64) {
        if var stream = isVideo ? self.video : self.audio {
            stream.endPts = pts
            stream.duration += duration
            stream.endPosition = max(stream.endPosition, position + size)
            if isVideo {
                self.video = stream
            } else {
                self.audio = stream
            }
        } else {
            let stream = Stream(index: index, startPts: pts, startPosition: position, endPts: pts, endPosition: position + size, duration: duration)
            if isVideo {
                self.video = stream
            } else {
                self.audio = stream
            }
        }
    }
}

private final class FFMpegFrameSegmentInfo {
    let headerAccessRanges: RangeSet<Int>
    let segments: [FFMpegFrameSegment]
    
    init(headerAccessRanges: RangeSet<Int>, segments: [FFMpegFrameSegment]) {
        self.headerAccessRanges = headerAccessRanges
        self.segments = segments
    }
}

private func extractFFMpegFrameSegmentInfo(path: String) -> FFMpegFrameSegmentInfo? {
    let _ = FFMpegMediaFrameSourceContextHelpers.registerFFMpegGlobals
    
    var s = stat()
    stat(path, &s)
    let size = Int32(s.st_size)
    
    let fd = open(path, O_RDONLY, S_IRUSR)
    if fd < 0 {
        return nil
    }
    defer {
        close(fd)
    }
    
    let avFormatContext = FFMpegAVFormatContext()
    let ioBufferSize = 32 * 1024
    
    let context = FFMpegMediaFrameExtractContext(fd: fd, size: Int(size))
    context.recordAccessedRanges = true
    
    guard let avIoContext = FFMpegAVIOContext(bufferSize: Int32(ioBufferSize), opaqueContext: Unmanaged.passUnretained(context).toOpaque(), readPacket: FFMpegMediaFrameExtractContextReadPacketCallback, writePacket: nil, seek: FFMpegMediaFrameExtractContextSeekCallback, isSeekable: true) else {
        return nil
    }
    
    avFormatContext.setIO(avIoContext)
    
    if !avFormatContext.openInput(withDirectFilePath: nil) {
        return nil
    }
    
    if !avFormatContext.findStreamInfo() {
        return nil
    }
    
    var audioStream: FFMpegMediaInfo.Info?
    var videoStream: FFMpegMediaInfo.Info?
    
    for typeIndex in 0 ..< 2 {
        let isVideo = typeIndex == 0
        
        for streamIndexNumber in avFormatContext.streamIndices(for: isVideo ? FFMpegAVFormatStreamTypeVideo : FFMpegAVFormatStreamTypeAudio) {
            let streamIndex = streamIndexNumber.int32Value
            if avFormatContext.isAttachedPic(atStreamIndex: streamIndex) {
                continue
            }
            
            let fpsAndTimebase = avFormatContext.fpsAndTimebase(forStreamIndex: streamIndex, defaultTimeBase: CMTimeMake(value: 1, timescale: 40000))
            let (fps, timebase) = (fpsAndTimebase.fps, fpsAndTimebase.timebase)
            
            let startTime: CMTime
            let rawStartTime = avFormatContext.startTime(atStreamIndex: streamIndex)
            if rawStartTime == Int64(bitPattern: 0x8000000000000000 as UInt64) {
                startTime = CMTime(value: 0, timescale: timebase.timescale)
            } else {
                startTime = CMTimeMake(value: rawStartTime, timescale: timebase.timescale)
            }
            var duration = CMTimeMake(value: avFormatContext.duration(atStreamIndex: streamIndex), timescale: timebase.timescale)
            duration = CMTimeMaximum(CMTime(value: 0, timescale: duration.timescale), CMTimeSubtract(duration, startTime))
            
            var codecName: String?
            let codecId = avFormatContext.codecId(atStreamIndex: streamIndex)
            if codecId == FFMpegCodecIdMPEG4 {
                codecName = "mpeg4"
            } else if codecId == FFMpegCodecIdH264 {
                codecName = "h264"
            } else if codecId == FFMpegCodecIdHEVC {
                codecName = "hevc"
            } else if codecId == FFMpegCodecIdAV1 {
                codecName = "av1"
            } else if codecId == FFMpegCodecIdVP9 {
                codecName = "vp9"
            } else if codecId == FFMpegCodecIdVP8 {
                codecName = "vp8"
            }
            
            let info = FFMpegMediaInfo.Info(
                index: Int(streamIndex),
                timescale: timebase.timescale,
                startTime: startTime,
                duration: duration,
                fps: fps,
                codecName: codecName
            )
            
            if isVideo {
                videoStream = info
            } else {
                audioStream = info
            }
        }
    }
    
    var segments: [FFMpegFrameSegment] = []
    let maxSegmentDuration: Double = 5.0
    
    if let videoStream {
        let indexEntryCount = avFormatContext.numberOfIndexEntries(atStreamIndex: Int32(videoStream.index))
        
        if indexEntryCount > 0 {
            let frameDuration = 1.0 / videoStream.fps.seconds
            
            var indexEntry = FFMpegAVIndexEntry()
            for i in 0 ..< indexEntryCount {
                if !avFormatContext.fillIndexEntry(atStreamIndex: Int32(videoStream.index), entryIndex: Int32(i), outEntry: &indexEntry) {
                    continue
                }
                
                let packetPts = CMTime(value: indexEntry.timestamp, timescale: videoStream.timescale)
                //print("index: \(packetPts.seconds), isKeyframe: \(indexEntry.isKeyframe), position: \(indexEntry.pos), size: \(indexEntry.size)")
                
                var startNewSegment = segments.isEmpty
                if indexEntry.isKeyframe {
                    if segments.isEmpty {
                        startNewSegment = true
                    } else if let video = segments[segments.count - 1].video {
                        if packetPts.seconds - video.startPts.seconds > maxSegmentDuration {
                            startNewSegment = true
                        }
                    }
                }
                
                if startNewSegment {
                    segments.append(FFMpegFrameSegment())
                }
                segments[segments.count - 1].addFrame(isVideo: true, index: videoStream.index, pts: packetPts, duration: frameDuration, position: indexEntry.pos, size: Int64(indexEntry.size))
            }
            if !segments.isEmpty, let video = segments[segments.count - 1].video {
                if video.endPts.seconds + 1.0 / videoStream.fps.seconds + 0.001 < videoStream.duration.seconds {
                    segments[segments.count - 1].video?.duration = videoStream.duration.seconds - video.startPts.seconds
                    segments[segments.count - 1].video?.endPts = videoStream.duration
                }
            }
        }
    }
    if let audioStream {
        let indexEntryCount = avFormatContext.numberOfIndexEntries(atStreamIndex: Int32(audioStream.index))
        if indexEntryCount > 0 {
            var minSegmentIndex = 0
            var minSegmentStartTime: Double = -100000.0
            
            let frameDuration = 1.0 / audioStream.fps.seconds
            
            var indexEntry = FFMpegAVIndexEntry()
            for i in 0 ..< indexEntryCount {
                if !avFormatContext.fillIndexEntry(atStreamIndex: Int32(audioStream.index), entryIndex: Int32(i), outEntry: &indexEntry) {
                    continue
                }
                
                let packetPts = CMTime(value: indexEntry.timestamp, timescale: audioStream.timescale)
                //print("index: \(packetPts.value), timestamp: \(packetPts.seconds), isKeyframe: \(indexEntry.isKeyframe), position: \(indexEntry.pos), size: \(indexEntry.size)")
                
                if videoStream != nil {
                    for i in minSegmentIndex ..< segments.count {
                        if let video = segments[i].video {
                            if minSegmentStartTime <= packetPts.seconds && video.endPts.seconds >= packetPts.seconds {
                                segments[i].addFrame(isVideo: false, index: audioStream.index, pts: packetPts, duration: frameDuration, position: indexEntry.pos, size: Int64(indexEntry.size))
                                if minSegmentIndex != i {
                                    minSegmentIndex = i
                                    minSegmentStartTime = video.startPts.seconds
                                }
                                break
                            }
                        }
                    }
                } else {
                    if segments.isEmpty {
                        segments.append(FFMpegFrameSegment())
                    }
                    segments[segments.count - 1].addFrame(isVideo: false, index: audioStream.index, pts: packetPts, duration: frameDuration, position: indexEntry.pos, size: Int64(indexEntry.size))
                }
            }
        }
        if !segments.isEmpty, let audio = segments[segments.count - 1].audio {
            if audio.endPts.seconds + 0.001 < audioStream.duration.seconds {
                segments[segments.count - 1].audio?.duration = audioStream.duration.seconds - audio.startPts.seconds
                segments[segments.count - 1].audio?.endPts = audioStream.duration
            }
        }
    }
    
    let headerAccessRanges = context.accessedRanges
    
    for i in 1 ..< segments.count {
        let segment = segments[i]
        
        if let video = segment.video {
            context.maskRanges = headerAccessRanges
            context.maskRanges?.insert(contentsOf: Int(video.startPosition) ..< Int(video.endPosition))
            
            context.accessedRanges = RangeSet()
            context.recordAccessedRanges = true
            
            avFormatContext.seekFrame(forStreamIndex: Int32(video.index), byteOffset: video.startPosition)
            
            let packet = FFMpegPacket()
            while true {
                if !avFormatContext.readFrame(into: packet) {
                    break
                }
                
                if Int(packet.streamIndex) == video.index {
                    let packetPts = CMTime(value: packet.pts, timescale: video.startPts.timescale)
                    if packetPts.value >= video.endPts.value {
                        break
                    }
                }
            }
            
            print("Segment \(i): \(video.startPosition) ..< \(video.endPosition) accessed \(context.accessedRanges.ranges)")
        }
    }
    
    /*{
        if let videoStream {
            avFormatContext.seekFrame(forStreamIndex: Int32(videoStream.index), pts: 0, positionOnKeyframe: true)
            
            let packet = FFMpegPacket()
            while true {
                if !avFormatContext.readFrame(into: packet) {
                    break
                }
                
                if Int(packet.streamIndex) == videoStream.index {
                    let packetPts = CMTime(value: packet.pts, timescale: videoStream.timescale)
                    let packetDuration = CMTime(value: packet.duration, timescale: videoStream.timescale)
                    
                    var startNewSegment = segments.isEmpty
                    if packet.isKeyframe {
                        if segments.isEmpty {
                            startNewSegment = true
                        } else if let video = segments[segments.count - 1].video {
                            if packetPts.seconds - video.startPts.seconds > maxSegmentDuration {
                                startNewSegment = true
                            }
                        }
                    }
                    
                    if startNewSegment {
                        segments.append(FFMpegFrameSegment())
                    }
                    segments[segments.count - 1].addFrame(isVideo: true, index: Int(packet.streamIndex), pts: packetPts, duration: packetDuration.seconds)
                }
            }
        }
        if let audioStream {
            avFormatContext.seekFrame(forStreamIndex: Int32(audioStream.index), pts: 0, positionOnKeyframe: true)
            
            var minSegmentIndex = 0
            
            let packet = FFMpegPacket()
            while true {
                if !avFormatContext.readFrame(into: packet) {
                    break
                }
                
                if Int(packet.streamIndex) == audioStream.index {
                    let packetPts = CMTime(value: packet.pts, timescale: audioStream.timescale)
                    let packetDuration = CMTime(value: packet.duration, timescale: audioStream.timescale)
                    
                    if videoStream != nil {
                        for i in minSegmentIndex ..< segments.count {
                            if let video = segments[i].video {
                                if video.startPts.seconds <= packetPts.seconds && video.endPts.seconds >= packetPts.seconds {
                                    segments[i].addFrame(isVideo: false, index: Int(audioStream.index), pts: packetPts, duration: packetDuration.seconds)
                                    minSegmentIndex = i
                                    break
                                }
                            }
                        }
                    } else {
                        if segments.isEmpty {
                            segments.append(FFMpegFrameSegment())
                        }
                        segments[segments.count - 1].addFrame(isVideo: false, index: Int(packet.streamIndex), pts: packetPts, duration: packetDuration.seconds)
                    }
                }
            }
        }
    }*/
    
    /*for i in 0 ..< segments.count {
        print("Segment \(i):\n  video \(segments[i].video?.startPts.seconds ?? -1.0) ... \(segments[i].video?.endPts.seconds ?? -1.0)\n  audio \(segments[i].audio?.startPts.seconds ?? -1.0) ... \(segments[i].audio?.endPts.seconds ?? -1.0)")
    }*/
    
    return FFMpegFrameSegmentInfo(
        headerAccessRanges: context.accessedRanges,
        segments: segments
    )
}

final class ChunkMediaPlayerDirectFetchSourceImpl: ChunkMediaPlayerSourceImpl {
    private let resource: ChunkMediaPlayerV2.SourceDescription.ResourceDescription
    
    private let partsStateValue = Promise<ChunkMediaPlayerPartsState>()
    var partsState: Signal<ChunkMediaPlayerPartsState, NoError> {
        return self.partsStateValue.get()
    }
    
    private var completeFetchDisposable: Disposable?
    private var dataDisposable: Disposable?
    
    init(resource: ChunkMediaPlayerV2.SourceDescription.ResourceDescription) {
        self.resource = resource
        
        if resource.fetchAutomatically {
            self.completeFetchDisposable = fetchedMediaResource(
                mediaBox: resource.postbox.mediaBox,
                userLocation: resource.userLocation,
                userContentType: resource.userContentType,
                reference: resource.reference,
                statsCategory: resource.statsCategory,
                preferBackgroundReferenceRevalidation: true
            ).startStrict()
        }
        
        self.dataDisposable = (resource.postbox.mediaBox.resourceData(resource.reference.resource)
        |> deliverOnMainQueue).startStrict(next: { [weak self] data in
            guard let self else {
                return
            }
            if data.complete {
                if let mediaInfo = extractFFMpegMediaInfo(path: data.path), let mainTrack = mediaInfo.audio ?? mediaInfo.video, let segmentInfo = extractFFMpegFrameSegmentInfo(path: data.path) {
                    var parts: [ChunkMediaPlayerPart] = []
                    for segment in segmentInfo.segments {
                        guard let mainStream = segment.video ?? segment.audio else {
                            assertionFailure()
                            continue
                        }
                        parts.append(ChunkMediaPlayerPart(
                            startTime: mainStream.startPts.seconds,
                            endTime: mainStream.startPts.seconds + mainStream.duration,
                            content: .directFile(ChunkMediaPlayerPart.Content.FFMpegDirectFile(
                                path: data.path,
                                audio: segment.audio.flatMap { stream in
                                    return ChunkMediaPlayerPart.DirectStream(
                                        index: stream.index,
                                        startPts: stream.startPts,
                                        endPts: stream.endPts,
                                        duration: stream.duration
                                    )
                                },
                                video: segment.video.flatMap { stream in
                                    return ChunkMediaPlayerPart.DirectStream(
                                        index: stream.index,
                                        startPts: stream.startPts,
                                        endPts: stream.endPts,
                                        duration: stream.duration
                                    )
                                }
                            )),
                            codecName: mediaInfo.video?.codecName
                        ))
                    }
                    
                    self.partsStateValue.set(.single(ChunkMediaPlayerPartsState(
                        duration: mainTrack.duration.seconds,
                        parts: parts
                    )))
                } else {
                    self.partsStateValue.set(.single(ChunkMediaPlayerPartsState(
                        duration: nil,
                        parts: []
                    )))
                }
            } else {
                self.partsStateValue.set(.single(ChunkMediaPlayerPartsState(
                    duration: nil,
                    parts: []
                )))
            }
        })
    }
    
    deinit {
        self.completeFetchDisposable?.dispose()
        self.dataDisposable?.dispose()
    }
    
    func updatePlaybackState(position: Double, isPlaying: Bool) {
        
    }
}
