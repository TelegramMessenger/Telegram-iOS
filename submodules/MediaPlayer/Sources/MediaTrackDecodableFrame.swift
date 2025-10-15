import Foundation
import CoreMedia
import FFMpegBinding

public enum MediaTrackFrameType {
    case video
    case audio
}

public final class MediaTrackDecodableFrame {
    public let type: MediaTrackFrameType
    public let packet: FFMpegPacket
    public let pts: CMTime
    public let dts: CMTime
    public let duration: CMTime
    
    public init(type: MediaTrackFrameType, packet: FFMpegPacket, pts: CMTime, dts: CMTime, duration: CMTime) {
        self.type = type
        
        self.pts = pts
        self.dts = dts
        self.duration = duration
        
        self.packet = packet
    }
    
    public func copyPacketData() -> Data {
        return Data(bytes: self.packet.data, count: Int(self.packet.size))
    }
}
