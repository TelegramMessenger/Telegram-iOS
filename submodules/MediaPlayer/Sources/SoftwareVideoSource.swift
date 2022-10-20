import Foundation
#if !os(macOS)
import UIKit
#else
import AppKit
#endif
import CoreMedia
import SwiftSignalKit
import FFMpegBinding

private func readPacketCallback(userData: UnsafeMutableRawPointer?, buffer: UnsafeMutablePointer<UInt8>?, bufferSize: Int32) -> Int32 {
    let context = Unmanaged<SoftwareVideoSource>.fromOpaque(userData!).takeUnretainedValue()
    if let fd = context.fd {
        return Int32(read(fd, buffer, Int(bufferSize)))
    }
    return 0
}

private func seekCallback(userData: UnsafeMutableRawPointer?, offset: Int64, whence: Int32) -> Int64 {
    let context = Unmanaged<SoftwareVideoSource>.fromOpaque(userData!).takeUnretainedValue()
    if let fd = context.fd {
        if (whence & FFMPEG_AVSEEK_SIZE) != 0 {
            return Int64(context.size)
        } else {
            lseek(fd, off_t(offset), SEEK_SET)
            return offset
        }
    }
    return 0
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

public final class SoftwareVideoSource {
    private var readingError = false
    private var videoStream: SoftwareVideoStream?
    private var avIoContext: FFMpegAVIOContext?
    private var avFormatContext: FFMpegAVFormatContext?
    private let path: String
    fileprivate let fd: Int32?
    fileprivate let size: Int32
    
    private let hintVP9: Bool
    private let unpremultiplyAlpha: Bool
    
    private var enqueuedFrames: [(MediaTrackFrame, CGFloat, CGFloat, Bool)] = []
    private var hasReadToEnd: Bool = false
    
    public init(path: String, hintVP9: Bool, unpremultiplyAlpha: Bool) {
        let _ = FFMpegMediaFrameSourceContextHelpers.registerFFMpegGlobals
        
        self.hintVP9 = hintVP9
        self.unpremultiplyAlpha = unpremultiplyAlpha
        
        var s = stat()
        stat(path, &s)
        self.size = Int32(s.st_size)
        
        let fd = open(path, O_RDONLY, S_IRUSR)
        if fd >= 0 {
            self.fd = fd
        } else {
            self.fd = nil
        }
        
        self.path = path
        
        let avFormatContext = FFMpegAVFormatContext()
        if hintVP9 {
            avFormatContext.forceVideoCodecId(FFMpegCodecIdVP9)
        }
        let ioBufferSize = 64 * 1024
        
        let avIoContext = FFMpegAVIOContext(bufferSize: Int32(ioBufferSize), opaqueContext: Unmanaged.passUnretained(self).toOpaque(), readPacket: readPacketCallback, writePacket: nil, seek: seekCallback)
        self.avIoContext = avIoContext
        
        avFormatContext.setIO(self.avIoContext!)
        
        if !avFormatContext.openInput() {
            self.readingError = true
            return
        }
        
        if !avFormatContext.findStreamInfo() {
            self.readingError = true
            return
        }
        
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
        
        self.videoStream = videoStream
        
        if let videoStream = self.videoStream {
            avFormatContext.seekFrame(forStreamIndex: Int32(videoStream.index), pts: 0, positionOnKeyframe: true)
        }
    }
    
    deinit {
        if let fd = self.fd {
            close(fd)
        }
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
        
        while !self.readingError && frames.isEmpty {
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
                if endOfStream {
                    break
                } else {
                    if let _ = self.avFormatContext, let _ = self.videoStream {
                        endOfStream = true
                        break
                    } else {
                        endOfStream = true
                        break
                    }
                }
            }
        }
        
        return (frames.first, endOfStream)
    }
    
    public func getFramerate() -> Int {
        if let videoStream = self.videoStream {
            return Int(videoStream.fps.seconds)
        } else {
            return 0
        }
    }
    
    public func readFrame(maxPts: CMTime?) -> (MediaTrackFrame?, CGFloat, CGFloat, Bool) {
        guard let videoStream = self.videoStream, let avFormatContext = self.avFormatContext else {
            return (nil, 0.0, 1.0, false)
        }
        
        if !self.enqueuedFrames.isEmpty {
            let value = self.enqueuedFrames.removeFirst()
            return (value.0, value.1, value.2, value.3)
        }
        
        let (decodableFrame, loop) = self.readDecodableFrame()
        var result: (MediaTrackFrame?, CGFloat, CGFloat, Bool)
        if let decodableFrame = decodableFrame {
            var ptsOffset: CMTime?
            if let maxPts = maxPts, CMTimeCompare(decodableFrame.pts, maxPts) < 0 {
                ptsOffset = maxPts
            }
            result = (videoStream.decoder.decode(frame: decodableFrame, ptsOffset: ptsOffset, forceARGB: self.hintVP9, unpremultiplyAlpha: self.unpremultiplyAlpha), CGFloat(videoStream.rotationAngle), CGFloat(videoStream.aspect), loop)
        } else {
            result = (nil, CGFloat(videoStream.rotationAngle), CGFloat(videoStream.aspect), loop)
        }
        if loop {
            let _ = videoStream.decoder.sendEndToDecoder()
            let remainingFrames = videoStream.decoder.receiveRemainingFrames(ptsOffset: maxPts)
            for i in 0 ..< remainingFrames.count {
                self.enqueuedFrames.append((remainingFrames[i], CGFloat(videoStream.rotationAngle), CGFloat(videoStream.aspect), i == remainingFrames.count - 1))
            }
            videoStream.decoder.reset()
            avFormatContext.seekFrame(forStreamIndex: Int32(videoStream.index), pts: 0, positionOnKeyframe: true)
            
            if result.0 == nil && !self.enqueuedFrames.isEmpty {
                result = self.enqueuedFrames.removeFirst()
            }
        }
        return result
    }
    
    public func readImage() -> (UIImage?, CGFloat, CGFloat, Bool) {
        if let videoStream = self.videoStream {
            for _ in 0 ..< 10 {
                let (decodableFrame, loop) = self.readDecodableFrame()
                if let decodableFrame = decodableFrame {
                    if let renderedFrame = videoStream.decoder.render(frame: decodableFrame) {
                        return (renderedFrame, CGFloat(videoStream.rotationAngle), CGFloat(videoStream.aspect), loop)
                    }
                }
            }
            return (nil, CGFloat(videoStream.rotationAngle), CGFloat(videoStream.aspect), true)
        } else {
            return (nil, 0.0, 1.0, false)
        }
    }
    
    public func seek(timestamp: Double) {
        if let stream = self.videoStream, let avFormatContext = self.avFormatContext {
            let pts = CMTimeMakeWithSeconds(timestamp, preferredTimescale: stream.timebase.timescale)
            avFormatContext.seekFrame(forStreamIndex: Int32(stream.index), pts: pts.value, positionOnKeyframe: true)
            stream.decoder.reset()
        }
    }
}

private final class SoftwareAudioStream {
    let index: Int
    let fps: CMTime
    let timebase: CMTime
    let duration: CMTime
    let decoder: FFMpegAudioFrameDecoder
    
    init(index: Int, fps: CMTime, timebase: CMTime, duration: CMTime, decoder: FFMpegAudioFrameDecoder) {
        self.index = index
        self.fps = fps
        self.timebase = timebase
        self.duration = duration
        self.decoder = decoder
    }
}

public final class SoftwareAudioSource {
    private var readingError = false
    private var audioStream: SoftwareAudioStream?
    private var avIoContext: FFMpegAVIOContext?
    private var avFormatContext: FFMpegAVFormatContext?
    private let path: String
    fileprivate let fd: Int32?
    fileprivate let size: Int32
    
    private var hasReadToEnd: Bool = false
    
    public init(path: String) {
        let _ = FFMpegMediaFrameSourceContextHelpers.registerFFMpegGlobals
        
        var s = stat()
        stat(path, &s)
        self.size = Int32(s.st_size)
        
        let fd = open(path, O_RDONLY, S_IRUSR)
        if fd >= 0 {
            self.fd = fd
        } else {
            self.fd = nil
        }
        
        self.path = path
        
        let avFormatContext = FFMpegAVFormatContext()
        
        let ioBufferSize = 64 * 1024
        
        let avIoContext = FFMpegAVIOContext(bufferSize: Int32(ioBufferSize), opaqueContext: Unmanaged.passUnretained(self).toOpaque(), readPacket: readPacketCallback, writePacket: nil, seek: seekCallback)
        self.avIoContext = avIoContext
        
        avFormatContext.setIO(self.avIoContext!)
        
        if !avFormatContext.openInput() {
            self.readingError = true
            return
        }
        
        if !avFormatContext.findStreamInfo() {
            self.readingError = true
            return
        }
        
        self.avFormatContext = avFormatContext
        
        var audioStream: SoftwareAudioStream?
        
        for streamIndexNumber in avFormatContext.streamIndices(for: FFMpegAVFormatStreamTypeAudio) {
            let streamIndex = streamIndexNumber.int32Value
            if avFormatContext.isAttachedPic(atStreamIndex: streamIndex) {
                continue
            }
            
            let codecId = avFormatContext.codecId(atStreamIndex: streamIndex)
            
            let fpsAndTimebase = avFormatContext.fpsAndTimebase(forStreamIndex: streamIndex, defaultTimeBase: CMTimeMake(value: 1, timescale: 40000))
            let (fps, timebase) = (fpsAndTimebase.fps, fpsAndTimebase.timebase)
            
            let duration = CMTimeMake(value: avFormatContext.duration(atStreamIndex: streamIndex), timescale: timebase.timescale)
            
            let codec = FFMpegAVCodec.find(forId: codecId)
            
            if let codec = codec {
                let codecContext = FFMpegAVCodecContext(codec: codec)
                if avFormatContext.codecParams(atStreamIndex: streamIndex, to: codecContext) {
                    if codecContext.open() {
                        audioStream = SoftwareAudioStream(index: Int(streamIndex), fps: fps, timebase: timebase, duration: duration, decoder: FFMpegAudioFrameDecoder(codecContext: codecContext, sampleRate: 48000, channelCount: 1))
                        break
                    }
                }
            }
        }
        
        self.audioStream = audioStream
        
        if let audioStream = self.audioStream {
            avFormatContext.seekFrame(forStreamIndex: Int32(audioStream.index), pts: 0, positionOnKeyframe: false)
        }
    }
    
    deinit {
        if let fd = self.fd {
            close(fd)
        }
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
        
        while !self.readingError && frames.isEmpty {
            if let packet = self.readPacketInternal() {
                if let audioStream = audioStream, Int(packet.streamIndex) == audioStream.index {
                    let packetPts = packet.pts
                    
                    let pts = CMTimeMake(value: packetPts, timescale: audioStream.timebase.timescale)
                    let dts = CMTimeMake(value: packet.dts, timescale: audioStream.timebase.timescale)
                    
                    let duration: CMTime
                    
                    let frameDuration = packet.duration
                    if frameDuration != 0 {
                        duration = CMTimeMake(value: frameDuration * audioStream.timebase.value, timescale: audioStream.timebase.timescale)
                    } else {
                        duration = audioStream.fps
                    }
                    
                    let frame = MediaTrackDecodableFrame(type: .audio, packet: packet, pts: pts, dts: dts, duration: duration)
                    frames.append(frame)
                }
            } else {
                if endOfStream {
                    break
                } else {
                    if let _ = self.avFormatContext, let _ = self.audioStream {
                        endOfStream = true
                        break
                    } else {
                        endOfStream = true
                        break
                    }
                }
            }
        }
        
        return (frames.first, endOfStream)
    }
    
    public func readFrame() -> Data? {
        guard let audioStream = self.audioStream, let _ = self.avFormatContext else {
            return nil
        }
        
        let (decodableFrame, _) = self.readDecodableFrame()
        if let decodableFrame = decodableFrame {
            return audioStream.decoder.decodeRaw(frame: decodableFrame)
        } else {
            return nil
        }
    }
    
    public func readSampleBuffer() -> CMSampleBuffer? {
        guard let audioStream = self.audioStream, let _ = self.avFormatContext else {
            return nil
        }
        
        let (decodableFrame, _) = self.readDecodableFrame()
        if let decodableFrame = decodableFrame {
            return audioStream.decoder.decode(frame: decodableFrame)?.sampleBuffer
        } else {
            return nil
        }
    }
    
    public func readEncodedFrame() -> (Data, Int)? {
        guard let _ = self.audioStream, let _ = self.avFormatContext else {
            return nil
        }
        
        let (decodableFrame, _) = self.readDecodableFrame()
        if let decodableFrame = decodableFrame {
            return (decodableFrame.copyPacketData(), Int(decodableFrame.packet.duration))
        } else {
            return nil
        }
    }
    
    public func seek(timestamp: Double) {
        if let stream = self.audioStream, let avFormatContext = self.avFormatContext {
            let pts = CMTimeMakeWithSeconds(timestamp, preferredTimescale: stream.timebase.timescale)
            avFormatContext.seekFrame(forStreamIndex: Int32(stream.index), pts: pts.value, positionOnKeyframe: false)
        }
    }
}
