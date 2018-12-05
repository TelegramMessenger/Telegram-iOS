import Foundation
import AVFoundation
import UIKit
import Display
import TelegramCore
import Postbox

import TelegramUIPrivateModule

func compressImageToJPEG(_ image: UIImage, quality: Float) -> Data? {
    let data = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(data as CFMutableData, "public.jpeg" as CFString, 1, nil) else {
        return nil
    }
    
    let options = NSMutableDictionary()
    options.setObject(quality as NSNumber, forKey: kCGImageDestinationLossyCompressionQuality as NSString)
    
    guard let cgImage = image.cgImage else {
        return nil
    }
    CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
    CGImageDestinationFinalize(destination)
    
    if data.length == 0 {
        return nil
    }
    
    return data as Data
}

@available(iOSApplicationExtension 11.0, *)
func compressImage(_ image: UIImage, quality: Float) -> Data? {
    let data = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(data as CFMutableData, AVFileType.heic as CFString, 1, nil) else {
        return nil
    }
    
    let options = NSMutableDictionary()
    options.setObject(quality as NSNumber, forKey: kCGImageDestinationLossyCompressionQuality as NSString)
    
    guard let cgImage = image.cgImage else {
        return nil
    }
    CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
    CGImageDestinationFinalize(destination)
    
    if data.length == 0 {
        return nil
    }
    
    return data as Data
}

public struct TinyThumbnailData: Equatable {
    let tablesDataHash: Int32
    let data: Data
}

func compressTinyThumbnail(_ image: UIImage) -> TinyThumbnailData? {
    let size = image.size.fitted(CGSize(width: 42.0, height: 42.0))
    let context = DrawingContext(size: size, scale: 1.0, clear: false)
    context.withFlippedContext({ c in
        if let image = image.cgImage {
            c.draw(image, in: CGRect(origin: CGPoint(), size: size))
        }
    })
    
    var cinfo = jpeg_compress_struct()
    var jerr = jpeg_error_mgr()
    
    cinfo.err = jpeg_std_error(&jerr)
    jpeg_CreateCompress(&cinfo, JPEG_LIB_VERSION, MemoryLayout.size(ofValue: cinfo))
    
    cinfo.input_components = 3
    cinfo.in_color_space = JCS_RGB
    
    jpeg_set_defaults(&cinfo)
    jpeg_set_quality(&cinfo, 20, 1)
    
    var outTablesBuffer: UnsafeMutablePointer<UInt8>?
    var outTablesSize: UInt = 0
    jpeg_mem_dest(&cinfo, &outTablesBuffer, &outTablesSize)
    jpeg_write_tables(&cinfo)
    
    var tablesDataHash: Int32 = 0
    if let outTablesBuffer = outTablesBuffer {
        let tablesData = Data(bytes: outTablesBuffer, count: Int(outTablesSize))
        tablesDataHash = murMurHash32Data(tablesData)
        //print("tablesData \(hexString(tablesData))")
    }
    
    var outBuffer: UnsafeMutablePointer<UInt8>?
    var outSize: UInt = 0
    jpeg_mem_dest(&cinfo, &outBuffer, &outSize)
    
    cinfo.image_width = UInt32(context.size.width)
    cinfo.image_height = UInt32(context.size.height)
    
    jpeg_suppress_tables(&cinfo, 1)
    jpeg_start_compress(&cinfo, 0)
    
    let rowStride = Int(cinfo.image_width) * 3
    var tempBuffer = malloc(rowStride)!.assumingMemoryBound(to: UInt8.self)
    defer {
        free(tempBuffer)
    }
    
    while cinfo.next_scanline < cinfo.image_height {
        let rowPointer = context.bytes.assumingMemoryBound(to: UInt8.self).advanced(by: Int(cinfo.next_scanline) * context.bytesPerRow)
        for x in 0 ..< Int(cinfo.image_width) {
            for i in 0 ..< 3 {
                tempBuffer[x * 3 + i] = rowPointer[x * 4 + i]
            }
        }
        var row: JSAMPROW? = UnsafeMutablePointer(tempBuffer)
        jpeg_write_scanlines(&cinfo, &row, 1)
    }
    
    jpeg_finish_compress(&cinfo)
    
    var result: Data?
    if let outBuffer = outBuffer {
        result = Data(bytes: outBuffer, count: Int(outSize))
        //print("result \(result.count)")
    }
    
    jpeg_destroy_compress(&cinfo)
    
    if let result = result {
        return TinyThumbnailData(tablesDataHash: tablesDataHash, data: result)
    } else {
        return nil
    }
}

private let fixedTablesData = dataWithHexString("ffd8ffdb004300281c1e231e19282321232d2b28303c64413c37373c7b585d4964918099968f808c8aa0b4e6c3a0aadaad8a8cc8ffcbdaeef5ffffff9bc1fffffffaffe6fdfff8ffdb0043012b2d2d3c353c76414176f8a58ca5f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8f8ffc4001f0000010501010101010100000000000000000102030405060708090a0bffc400b5100002010303020403050504040000017d01020300041105122131410613516107227114328191a1082342b1c11552d1f02433627282090a161718191a25262728292a3435363738393a434445464748494a535455565758595a636465666768696a737475767778797a838485868788898a92939495969798999aa2a3a4a5a6a7a8a9aab2b3b4b5b6b7b8b9bac2c3c4c5c6c7c8c9cad2d3d4d5d6d7d8d9dae1e2e3e4e5e6e7e8e9eaf1f2f3f4f5f6f7f8f9faffc4001f0100030101010101010101010000000000000102030405060708090a0bffc400b51100020102040403040705040400010277000102031104052131061241510761711322328108144291a1b1c109233352f0156272d10a162434e125f11718191a262728292a35363738393a434445464748494a535455565758595a636465666768696a737475767778797a82838485868788898a92939495969798999aa2a3a4a5a6a7a8a9aab2b3b4b5b6b7b8b9bac2c3c4c5c6c7c8c9cad2d3d4d5d6d7d8d9dae2e3e4e5e6e7e8e9eaf2f3f4f5f6f7f8f9faffd9")

private let fixedTablesDataHash: Int32 = murMurHash32Data(fixedTablesData)

private struct my_error_mgr {
    var pub = jpeg_error_mgr()
}

func decompressTinyThumbnail(data: TinyThumbnailData) -> UIImage? {
    if data.tablesDataHash != fixedTablesDataHash {
        return nil
    }
    
    var cinfo = jpeg_decompress_struct()
    var jerr = my_error_mgr()
    
    cinfo.err = jpeg_std_error(&jerr.pub)
    //jerr.pub.error_exit = my_error_exit
    
    /* Establish the setjmp return context for my_error_exit to use. */
    /*if (setjmp(jerr.setjmp_buffer)) {
        /* If we get here, the JPEG code has signaled an error.
         * We need to clean up the JPEG object, close the input file, and return.
         */
        jpeg_destroy_decompress(&cinfo);
        fclose(infile);
        return 0;
    }*/
    
    /* Now we can initialize the JPEG decompression object. */
    jpeg_CreateDecompress(&cinfo, JPEG_LIB_VERSION, MemoryLayout.size(ofValue: cinfo))
    
    /* Step 2: specify data source (eg, a file) */
    
    let fixedTablesDataLength = UInt(fixedTablesData.count)
    fixedTablesData.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) -> Void in
        jpeg_mem_src(&cinfo, bytes, fixedTablesDataLength)
        jpeg_read_header(&cinfo, 0)
    }
    
    let result = data.data.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) -> UIImage? in
        jpeg_mem_src(&cinfo, bytes, fixedTablesDataLength)
        jpeg_read_header(&cinfo, 1)
        jpeg_start_decompress(&cinfo)
        let rowStride = Int(cinfo.output_width) * 3
        var tempBuffer = malloc(rowStride)!.assumingMemoryBound(to: UInt8.self)
        defer {
            free(tempBuffer)
        }
        let context = DrawingContext(size: CGSize(width: CGFloat(cinfo.output_width), height: CGFloat(cinfo.output_height)), scale: 1.0, clear: false)
        while cinfo.output_scanline < cinfo.output_height {
            let rowPointer = context.bytes.assumingMemoryBound(to: UInt8.self).advanced(by: Int(cinfo.output_scanline) * context.bytesPerRow)
            var row: JSAMPROW? = UnsafeMutablePointer(tempBuffer)
            jpeg_read_scanlines(&cinfo, &row, 1)
            for x in 0 ..< Int(cinfo.output_width) {
                rowPointer[x * 4 + 3] = 255
                for i in 0 ..< 3 {
                    rowPointer[x * 4 + i] = tempBuffer[x * 3 + i]
                }
            }
        }
        return context.generateImage()
    }
    
    jpeg_finish_decompress(&cinfo)
    jpeg_destroy_decompress(&cinfo)
    
    return result
}

func serializeTinyThumbnail(_ data: TinyThumbnailData) -> String {
    var result = "TTh1 \(data.data.count) bytes\n"
    result.append(String(data.tablesDataHash, radix: 16))
    result.append(data.data.base64EncodedString())
    let parsed = parseTinyThumbnail(result)
    assert(parsed == data)
    return result
}

func parseTinyThumbnail(_ text: String) -> TinyThumbnailData? {
    if text.hasPrefix("TTh1") && text.count > 20 {
        guard let startIndex = text.range(of: "\n")?.upperBound else {
            return nil
        }
        let start = startIndex.encodedOffset
        guard let hash = Int32(String(text[text.index(text.startIndex, offsetBy: start) ..< text.index(text.startIndex, offsetBy: start + 8)]), radix: 16) else {
            return nil
        }
        guard let data = Data(base64Encoded: String(text[text.index(text.startIndex, offsetBy: start + 8)...])) else {
            return nil
        }
        return TinyThumbnailData(tablesDataHash: hash, data: data)
    }
    return nil
}
