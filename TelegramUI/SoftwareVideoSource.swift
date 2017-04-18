import Foundation
import CoreMedia
import TelegramUIPrivateModule
import SwiftSignalKit

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
        if (whence & AVSEEK_SIZE) != 0 {
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
    
    init(index: Int, fps: CMTime, timebase: CMTime, duration: CMTime, decoder: FFMpegMediaVideoFrameDecoder, rotationAngle: Double) {
        self.index = index
        self.fps = fps
        self.timebase = timebase
        self.duration = duration
        self.decoder = decoder
        self.rotationAngle = rotationAngle
    }
}

final class SoftwareVideoSource {
    private var readingError = false
    private var videoStream: SoftwareVideoStream?
    private var avIoContext: UnsafeMutablePointer<AVIOContext>?
    private var avFormatContext: UnsafeMutablePointer<AVFormatContext>?
    private let path: String
    fileprivate let fd: Int32?
    fileprivate let size: Int32
    
    init(path: String) {
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
        
        var avFormatContextRef = avformat_alloc_context()
        guard let avFormatContext = avFormatContextRef else {
            self.readingError = true
            return
        }
        
        let ioBufferSize = 64 * 1024
        let avIoBuffer = av_malloc(ioBufferSize)!
        let avIoContextRef = avio_alloc_context(avIoBuffer.assumingMemoryBound(to: UInt8.self), Int32(ioBufferSize), 0, Unmanaged.passUnretained(self).toOpaque(), readPacketCallback, nil, seekCallback)
        self.avIoContext = avIoContextRef
        
        avFormatContext.pointee.pb = self.avIoContext
        
        guard avformat_open_input(&avFormatContextRef, nil, nil, nil) >= 0 else {
            self.readingError = true
            return
        }
        
        guard avformat_find_stream_info(avFormatContext, nil) >= 0 else {
            self.readingError = true
            return
        }
        
        self.avFormatContext = avFormatContext
        
        var videoStream: SoftwareVideoStream?
        
        for streamIndex in FFMpegMediaFrameSourceContextHelpers.streamIndices(formatContext: avFormatContext, codecType: AVMEDIA_TYPE_VIDEO) {
            if (avFormatContext.pointee.streams.advanced(by: streamIndex).pointee!.pointee.disposition & Int32(AV_DISPOSITION_ATTACHED_PIC)) == 0 {
                
                let codecPar = avFormatContext.pointee.streams.advanced(by: streamIndex).pointee!.pointee.codecpar!
                
                if let codec = avcodec_find_decoder(codecPar.pointee.codec_id) {
                    if let codecContext = avcodec_alloc_context3(codec) {
                        if avcodec_parameters_to_context(codecContext, avFormatContext.pointee.streams[streamIndex]!.pointee.codecpar) >= 0 {
                            if avcodec_open2(codecContext, codec, nil) >= 0 {
                                let (fps, timebase) = FFMpegMediaFrameSourceContextHelpers.streamFpsAndTimeBase(stream: avFormatContext.pointee.streams.advanced(by: streamIndex).pointee!, defaultTimeBase: CMTimeMake(1, 24))
                                
                                let duration = CMTimeMake(avFormatContext.pointee.streams.advanced(by: streamIndex).pointee!.pointee.duration, timebase.timescale)
                                
                                var rotationAngle: Double = 0.0
                                if let rotationInfo = av_dict_get(avFormatContext.pointee.streams.advanced(by: streamIndex).pointee!.pointee.metadata, "rotate", nil, 0), let value = rotationInfo.pointee.value {
                                    if strcmp(value, "0") != 0 {
                                        if let angle = Double(String(cString: value)) {
                                            rotationAngle = angle * Double.pi / 180.0
                                        }
                                    }
                                }
                                
                                videoStream = SoftwareVideoStream(index: streamIndex, fps: fps, timebase: timebase, duration: duration, decoder: FFMpegMediaVideoFrameDecoder(codecContext: codecContext), rotationAngle: rotationAngle)
                                break
                            } else {
                                var codecContextRef: UnsafeMutablePointer<AVCodecContext>? = codecContext
                                avcodec_free_context(&codecContextRef)
                            }
                        } else {
                            var codecContextRef: UnsafeMutablePointer<AVCodecContext>? = codecContext
                            avcodec_free_context(&codecContextRef)
                        }
                    }
                }
            }
        }
        
        self.videoStream = videoStream
    }
    
    deinit {
        if let avFormatContext = self.avFormatContext {
            avformat_free_context(avFormatContext)
        }
        if let fd = self.fd {
            close(fd)
        }
    }
    
    private func readPacketInternal() -> FFMpegPacket? {
        guard let avFormatContext = self.avFormatContext else {
            return nil
        }
        
        let packet = FFMpegPacket()
        if av_read_frame(avFormatContext, &packet.packet) < 0 {
            return nil
        } else {
            return packet
        }
    }
    
    func readDecodableFrame() -> (MediaTrackDecodableFrame?, Bool) {
        var frames: [MediaTrackDecodableFrame] = []
        var endOfStream = false
        
        while !self.readingError && frames.isEmpty {
            if let packet = self.readPacketInternal() {
                if let videoStream = videoStream, Int(packet.packet.stream_index) == videoStream.index {
                    let avNoPtsRawValue: UInt64 = 0x8000000000000000
                    let avNoPtsValue = Int64(bitPattern: avNoPtsRawValue)
                    let packetPts = packet.packet.pts == avNoPtsValue ? packet.packet.dts : packet.packet.pts
                    
                    let pts = CMTimeMake(packetPts, videoStream.timebase.timescale)
                    let dts = CMTimeMake(packet.packet.dts, videoStream.timebase.timescale)
                    
                    let duration: CMTime
                    
                    let frameDuration = packet.packet.duration
                    if frameDuration != 0 {
                        duration = CMTimeMake(frameDuration * videoStream.timebase.value, videoStream.timebase.timescale)
                    } else {
                        duration = videoStream.fps
                    }
                    
                    let frame = MediaTrackDecodableFrame(type: .video, packet: &packet.packet, pts: pts, dts: dts, duration: duration)
                    frames.append(frame)
                }
            } else {
                if endOfStream {
                    break
                } else {
                    if let avFormatContext = self.avFormatContext, let videoStream = self.videoStream {
                        endOfStream = true
                        av_seek_frame(avFormatContext, Int32(videoStream.index), 0, AVSEEK_FLAG_BACKWARD | AVSEEK_FLAG_FRAME)
                    } else {
                        endOfStream = true
                        break
                    }
                }
            }
        }
        
        if endOfStream {
            if let videoStream = self.videoStream {
                videoStream.decoder.reset()
            }
        }
        
        return (frames.first, endOfStream)
    }
    
    func readFrame(maxPts: CMTime?) -> (MediaTrackFrame?, Bool) {
        if let videoStream = self.videoStream {
            let (decodableFrame, loop) = self.readDecodableFrame()
            if let decodableFrame = decodableFrame {
                var ptsOffset: CMTime?
                if let maxPts = maxPts, CMTimeCompare(decodableFrame.pts, maxPts) < 0 {
                    ptsOffset = maxPts
                }
                return (videoStream.decoder.decode(frame: decodableFrame, ptsOffset: ptsOffset), loop)
            } else {
                return (nil, loop)
            }
        } else {
            return (nil, false)
        }
    }
}
