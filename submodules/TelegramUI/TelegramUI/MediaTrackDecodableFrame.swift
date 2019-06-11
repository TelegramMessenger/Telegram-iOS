import Foundation
import CoreMedia
import FFMpeg

enum MediaTrackFrameType {
    case video
    case audio
}

final class MediaTrackDecodableFrame {
    let type: MediaTrackFrameType
    let packet: FFMpegPacket
    let pts: CMTime
    let dts: CMTime
    let duration: CMTime
    
    init(type: MediaTrackFrameType, packet: FFMpegPacket, pts: CMTime, dts: CMTime, duration: CMTime) {
        self.type = type
        
        self.pts = pts
        self.dts = dts
        self.duration = duration
        
        self.packet = packet
    }
}
