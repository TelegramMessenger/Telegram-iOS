import Foundation
import CoreMedia
import TelegramUIPrivateModule

final class FFMpegMediaFrameSourceContextHelpers {
    static let registerFFMpegGlobals: Void = {
        #if DEBUG
        av_log_set_level(AV_LOG_ERROR)
        #else
        av_log_set_level(AV_LOG_QUIET)
        #endif
        av_register_all()
        return
    }()
    
    static func createFormatDescriptionFromAVCCodecData(_ formatId: UInt32, _ width: Int32, _ height: Int32, _ extradata: UnsafePointer<UInt8>, _ extradata_size: Int32) -> CMFormatDescription? {
        let par = NSMutableDictionary()
        par.setObject(1 as NSNumber, forKey: "HorizontalSpacing" as NSString)
        par.setObject(1 as NSNumber, forKey: "VerticalSpacing" as NSString)
        
        let atoms = NSMutableDictionary()
        atoms.setObject(NSData(bytes: extradata, length: Int(extradata_size)), forKey: "avcC" as NSString)
        
        let extensions = NSMutableDictionary()
        extensions.setObject("left" as NSString, forKey: "CVImageBufferChromaLocationBottomField" as NSString)
        extensions.setObject("left" as NSString, forKey: "CVImageBufferChromaLocationTopField" as NSString)
        extensions.setObject(0 as NSNumber, forKey: "FullRangeVideo" as NSString)
        extensions.setObject(par, forKey: "CVPixelAspectRatio" as NSString)
        extensions.setObject(atoms, forKey: "SampleDescriptionExtensionAtoms" as NSString)
        extensions.setObject("avc1" as NSString, forKey: "FormatName" as NSString)
        extensions.setObject(0 as NSNumber, forKey: "SpatialQuality" as NSString)
        extensions.setObject(0 as NSNumber, forKey: "Version" as NSString)
        extensions.setObject(0 as NSNumber, forKey: "FullRangeVideo" as NSString)
        extensions.setObject(1 as NSNumber, forKey: "CVFieldCount" as NSString)
        extensions.setObject(24 as NSNumber, forKey: "Depth" as NSString)
        
        var formatDescription: CMFormatDescription?
        CMVideoFormatDescriptionCreate(nil, CMVideoCodecType(formatId), width, height, extensions, &formatDescription)
        
        return formatDescription
    }
    
    static func createFormatDescriptionFromMpeg4CodecData(_ formatId: UInt32, _ width: Int32, _ height: Int32, _ extradata: UnsafePointer<UInt8>, _ extradata_size: Int32) -> CMFormatDescription? {
        let par = NSMutableDictionary()
        par.setObject(1 as NSNumber, forKey: "HorizontalSpacing" as NSString)
        par.setObject(1 as NSNumber, forKey: "VerticalSpacing" as NSString)
        
        let atoms = NSMutableDictionary()
        atoms.setObject(NSData(bytes: extradata, length: Int(extradata_size)), forKey: "esds" as NSString)
        
        let extensions = NSMutableDictionary()
        extensions.setObject("left" as NSString, forKey: "CVImageBufferChromaLocationBottomField" as NSString)
        extensions.setObject("left" as NSString, forKey: "CVImageBufferChromaLocationTopField" as NSString)
        extensions.setObject(0 as NSNumber, forKey: "FullRangeVideo" as NSString)
        extensions.setObject(par, forKey: "CVPixelAspectRatio" as NSString)
        extensions.setObject(atoms, forKey: "SampleDescriptionExtensionAtoms" as NSString)
        extensions.setObject("mp4v" as NSString, forKey: "FormatName" as NSString)
        extensions.setObject(0 as NSNumber, forKey: "SpatialQuality" as NSString)
        //extensions.setObject(0 as NSNumber, forKey: "Version" as NSString)
        extensions.setObject(0 as NSNumber, forKey: "FullRangeVideo" as NSString)
        extensions.setObject(1 as NSNumber, forKey: "CVFieldCount" as NSString)
        extensions.setObject(24 as NSNumber, forKey: "Depth" as NSString)
        
        var formatDescription: CMFormatDescription?
        guard CMVideoFormatDescriptionCreate(nil, kCMVideoCodecType_MPEG4Video, width, height, extensions, &formatDescription) == noErr else {
            return nil
        }
        
        return formatDescription
    }
    
    static func createFormatDescriptionFromHEVCCodecData(_ formatId: UInt32, _ width: Int32, _ height: Int32, _ extradata: UnsafePointer<UInt8>, _ extradata_size: Int32) -> CMFormatDescription? {
        let par = NSMutableDictionary()
        par.setObject(1 as NSNumber, forKey: "HorizontalSpacing" as NSString)
        par.setObject(1 as NSNumber, forKey: "VerticalSpacing" as NSString)
        
        let atoms = NSMutableDictionary()
        atoms.setObject(NSData(bytes: extradata, length: Int(extradata_size)), forKey: "hvcC" as NSString)
        
        let extensions = NSMutableDictionary()
        extensions.setObject("left" as NSString, forKey: "CVImageBufferChromaLocationBottomField" as NSString)
        extensions.setObject("left" as NSString, forKey: "CVImageBufferChromaLocationTopField" as NSString)
        extensions.setObject(0 as NSNumber, forKey: "FullRangeVideo" as NSString)
        extensions.setObject(par, forKey: "CVPixelAspectRatio" as NSString)
        extensions.setObject(atoms, forKey: "SampleDescriptionExtensionAtoms" as NSString)
        extensions.setObject("hevc" as NSString, forKey: "FormatName" as NSString)
        extensions.setObject(0 as NSNumber, forKey: "SpatialQuality" as NSString)
        extensions.setObject(0 as NSNumber, forKey: "Version" as NSString)
        extensions.setObject(0 as NSNumber, forKey: "FullRangeVideo" as NSString)
        extensions.setObject(1 as NSNumber, forKey: "CVFieldCount" as NSString)
        extensions.setObject(24 as NSNumber, forKey: "Depth" as NSString)
        
        var formatDescription: CMFormatDescription?
        CMVideoFormatDescriptionCreate(nil, CMVideoCodecType(formatId), width, height, extensions, &formatDescription)
        
        return formatDescription
    }

    static func streamIndices(formatContext: UnsafeMutablePointer<AVFormatContext>, codecType: AVMediaType) -> [Int] {
        var indices: [Int] = []
        for i in 0 ..< Int(formatContext.pointee.nb_streams) {
            if codecType == formatContext.pointee.streams.advanced(by: i).pointee!.pointee.codecpar!.pointee.codec_type {
                indices.append(i)
            }
        }
        return indices
    }
    
    static func streamFpsAndTimeBase(stream: UnsafePointer<AVStream>, defaultTimeBase: CMTime) -> (fps: CMTime, timebase: CMTime) {
        let timebase: CMTime
        var fps: CMTime
        
        if stream.pointee.time_base.den != 0 && stream.pointee.time_base.num != 0 {
            timebase = CMTimeMake(Int64(stream.pointee.time_base.num), stream.pointee.time_base.den)
        } else if stream.pointee.codec.pointee.time_base.den != 0 && stream.pointee.codec.pointee.time_base.num != 0 {
            timebase = CMTimeMake(Int64(stream.pointee.codec.pointee.time_base.num), stream.pointee.codec.pointee.time_base.den)
        } else {
            timebase = defaultTimeBase
        }
        
        if stream.pointee.avg_frame_rate.den != 0 && stream.pointee.avg_frame_rate.num != 0 {
            fps = CMTimeMake(Int64(stream.pointee.avg_frame_rate.num), stream.pointee.avg_frame_rate.den)
        } else if stream.pointee.r_frame_rate.den != 0 && stream.pointee.r_frame_rate.num != 0 {
            fps = CMTimeMake(Int64(stream.pointee.r_frame_rate.num), stream.pointee.r_frame_rate.den)
        } else {
            fps = CMTimeMake(1, 24)
        }
        
        return (fps, timebase)
    }
}
