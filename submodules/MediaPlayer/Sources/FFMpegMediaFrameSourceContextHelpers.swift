import Foundation
import CoreMedia
import FFMpegBinding

public final class FFMpegMediaFrameSourceContextHelpers {
    public static let registerFFMpegGlobals: Void = {
        FFMpegGlobals.initializeGlobals()
        return
    }()
    
    static func createFormatDescriptionFromAVCCodecData(_ formatId: UInt32, _ width: Int32, _ height: Int32, _ extradata: Data) -> CMFormatDescription? {
        let par = NSMutableDictionary()
        par.setObject(1 as NSNumber, forKey: "HorizontalSpacing" as NSString)
        par.setObject(1 as NSNumber, forKey: "VerticalSpacing" as NSString)
        
        let atoms = NSMutableDictionary()
        atoms.setObject(extradata as NSData, forKey: "avcC" as NSString)
        
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
    
    static func createFormatDescriptionFromMpeg4CodecData(_ formatId: UInt32, _ width: Int32, _ height: Int32, _ extradata: Data) -> CMFormatDescription? {
        let par = NSMutableDictionary()
        par.setObject(1 as NSNumber, forKey: "HorizontalSpacing" as NSString)
        par.setObject(1 as NSNumber, forKey: "VerticalSpacing" as NSString)
        
        let atoms = NSMutableDictionary()
        atoms.setObject(extradata as NSData, forKey: "esds" as NSString)
        
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
    
    static func createFormatDescriptionFromHEVCCodecData(_ formatId: UInt32, _ width: Int32, _ height: Int32, _ extradata: Data) -> CMFormatDescription? {
        let par = NSMutableDictionary()
        par.setObject(1 as NSNumber, forKey: "HorizontalSpacing" as NSString)
        par.setObject(1 as NSNumber, forKey: "VerticalSpacing" as NSString)
        
        let atoms = NSMutableDictionary()
        atoms.setObject(extradata as NSData, forKey: "hvcC" as NSString)
        
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
    
    static func createFormatDescriptionFromAV1CodecData(_ formatId: UInt32, _ width: Int32, _ height: Int32, _ extradata: Data, frameData: Data) -> CMFormatDescription? {
        return createAV1FormatDescription(frameData)
        
        /*let par = NSMutableDictionary()
        par.setObject(1 as NSNumber, forKey: "HorizontalSpacing" as NSString)
        par.setObject(1 as NSNumber, forKey: "VerticalSpacing" as NSString)
        
        let atoms = NSMutableDictionary()
        atoms.setObject(extradata as NSData, forKey: "av1C" as NSString)
        
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
        
        return formatDescription*/
    }
}

private func getSequenceHeaderOBU(data: Data) -> (Data, Data)? {
    let originalData = data
    return data.withUnsafeBytes { buffer -> (Data, Data)? in
        let data = buffer.baseAddress!.assumingMemoryBound(to: UInt8.self)
        
        var index = 0
        while true {
            if index >= buffer.count {
                return nil
            }

            let startIndex = index
            let value = data[index]
            index += 1
            if (value >> 7) != 0 {
                return nil
            }
            let headerType = value >> 3
            let hasPayloadSize = value & 0x02
            if hasPayloadSize == 0 {
                return nil
            }

            let hasExtension = value & 0x04
            if hasExtension != 0 {
                index += 1
            }

            let payloadSize = readULEBSize(data: data, dataSize: buffer.count, index: &index)
            if index + payloadSize >= buffer.count {
                return nil
            }

            if headerType == 1 {
                let fullObu = originalData.subdata(in: startIndex ..< (startIndex + payloadSize + index - startIndex))
                let obuData = originalData.subdata(in: index ..< (index + payloadSize))
                return (fullObu, obuData)
            }

            index += payloadSize
        }
        
        return nil
    }
}

private func readULEBSize(data: UnsafePointer<UInt8>, dataSize: Int, index: inout Int) -> Int {
    var value = 0
    for cptr in 0 ..< 8 {
        if index >= dataSize {
            return 0
        }

        let dataByte = data[index]
        index += 1
        let decodedByte = dataByte & 0x7f
        value |= Int(decodedByte << (7 * cptr))
        if value >= Int(Int32.max) {
            return 0
        }
        if (dataByte & 0x80) == 0 {
            break;
        }
    }
    return value
}

private struct ParsedSequenceHeaderParameters {
    var height: Int32 = 0
    var width: Int32 = 0

    var profile: UInt8 = 0
    var level: UInt8 = 0
    
    var high_bitdepth: UInt8 = 0
    var twelve_bit: UInt8 = 0
    var chroma_type: UInt8 = 0
}

private func parseSequenceHeaderOBU(data: Data) -> ParsedSequenceHeaderParameters? {
    var parameters = ParsedSequenceHeaderParameters()

    let bitReader = LsbBitReader(data: data)
    var value: UInt32 = 0
    
    // Read three bits, profile
    if bitReader.bitsLeft < 3 {
        return nil
    }
    value = bitReader.uint32(fromBits: 3)
    bitReader.advance(by: 3)
    parameters.profile = UInt8(bitPattern: Int8(clamping: value))

    // Read one bit, still picture
    if bitReader.bitsLeft < 1 {
        return nil
    }
    value = bitReader.uint32(fromBits: 1)
    bitReader.advance(by: 1)

    // Read one bit, hdr still picture
    if bitReader.bitsLeft < 1 {
        return nil
    }
    value = bitReader.uint32(fromBits: 1)
    bitReader.advance(by: 1)
    // We only support hdr still picture = 0 for now.
    if value != 0 {
        return nil
    }

    parameters.high_bitdepth = 0
    parameters.twelve_bit = 0
    parameters.chroma_type = 3

    // Read one bit, timing info
    if bitReader.bitsLeft < 1 {
        return nil
    }
    value = bitReader.uint32(fromBits: 1)
    bitReader.advance(by: 1)
    // We only support no timing info for now.
    if value != 0 {
        return nil
    }

    // Read one bit, display mode
    if bitReader.bitsLeft < 1 {
        return nil
    }
    value = bitReader.uint32(fromBits: 1)
    bitReader.advance(by: 1)

    // Read 5 bits, operating_points_cnt_minus_1
    if bitReader.bitsLeft < 5 {
        return nil
    }
    value = bitReader.uint32(fromBits: 5)
    bitReader.advance(by: 5)
    // We only support operating_points_cnt_minus_1 = 0 for now.
    if value != 0 {
        return nil
    }

    // Read 12 bits, operating_point_idc
    if bitReader.bitsLeft < 12 {
        return nil
    }
    value = bitReader.uint32(fromBits: 12)
    bitReader.advance(by: 12)

    // Read 5 bits, level
    if bitReader.bitsLeft < 5 {
        return nil
    }
    value = bitReader.uint32(fromBits: 5)
    bitReader.advance(by: 5)
    parameters.level = UInt8(value)

    // If level >= 4.0, read one bit
    if parameters.level > 7 {
        if bitReader.bitsLeft < 1 {
            return nil
        }
        value = bitReader.uint32(fromBits: 1)
        bitReader.advance(by: 1)
    }

    // Read width num bits
    if bitReader.bitsLeft < 4 {
        return nil
    }
    value = bitReader.uint32(fromBits: 4)
    bitReader.advance(by: 4)
    let widthNumBits = value + 1

    // Read height num bits
    if bitReader.bitsLeft < 4 {
        return nil
    }
    value = bitReader.uint32(fromBits: 4)
    bitReader.advance(by: 4)
    let heightNumBits = value + 1

    // Read width according with num bits
    if bitReader.bitsLeft < Int(widthNumBits) {
        return nil
    }
    value = bitReader.uint32(fromBits: Int(widthNumBits))
    bitReader.advance(by: Int(widthNumBits))
    parameters.width = Int32(value + 1)

    // Read height according with num bits
    if bitReader.bitsLeft < Int(heightNumBits) {
        return nil
    }
    value = bitReader.uint32(fromBits: Int(heightNumBits))
    bitReader.advance(by: Int(heightNumBits))
    parameters.height = Int32(value + 1)

    return parameters
}
