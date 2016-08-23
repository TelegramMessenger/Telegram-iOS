import Foundation
import TelegramUIPrivateModule

final class FFMpegPacket {
    var packet = AVPacket()
    
    deinit {
        av_packet_unref(&self.packet)
    }
    
    var pts: Int64 {
        let avNoPtsRawValue: UInt64 = 0x8000000000000000
        let avNoPtsValue = unsafeBitCast(avNoPtsRawValue, to: Int64.self)
        let packetPts = self.packet.pts == avNoPtsValue ? self.packet.dts : self.packet.pts
        
        return packetPts
    }
}
