import Foundation
import CoreMedia
import FFMpegBinding

public final class FFMpegMediaFrameSourceContextHelpers {
    public static let registerFFMpegGlobals: Void = {
        FFMpegGlobals.initializeGlobals()
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
        CMVideoFormatDescriptionCreate(allocator: nil, codecType: CMVideoCodecType(formatId), width: width, height: height, extensions: extensions, formatDescriptionOut: &formatDescription)
        
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
        guard CMVideoFormatDescriptionCreate(allocator: nil, codecType: kCMVideoCodecType_MPEG4Video, width: width, height: height, extensions: extensions, formatDescriptionOut: &formatDescription) == noErr else {
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
        CMVideoFormatDescriptionCreate(allocator: nil, codecType: CMVideoCodecType(formatId), width: width, height: height, extensions: extensions, formatDescriptionOut: &formatDescription)
        
        return formatDescription
    }
}
