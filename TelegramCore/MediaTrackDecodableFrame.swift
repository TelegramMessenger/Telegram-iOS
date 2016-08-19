import Foundation
import CoreMedia
import TelegramCorePrivateModule

enum MediaTrackFrameType {
    case video
    case audio
}

final class MediaTrackDecodableFrame {
    let type: MediaTrackFrameType
    let packet: UnsafeMutablePointer<AVPacket>
    let pts: CMTime
    let dts: CMTime
    let duration: CMTime
    
    init(type: MediaTrackFrameType, packet: UnsafePointer<AVPacket>, pts: CMTime, dts: CMTime, duration: CMTime) {
        self.type = type
        
        self.pts = pts
        self.dts = dts
        self.duration = duration
        
        self.packet = UnsafeMutablePointer<AVPacket>.allocate(capacity: 1)
        av_init_packet(self.packet)
        av_packet_ref(self.packet, packet)
    }
    
    deinit {
        av_packet_unref(self.packet)
        self.packet.deallocate(capacity: 1)
    }
}
