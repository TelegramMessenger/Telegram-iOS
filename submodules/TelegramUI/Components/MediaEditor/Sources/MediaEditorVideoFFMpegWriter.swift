import Foundation
import UIKit
import CoreMedia
import FFMpegBinding
import YuvConversion

final class MediaEditorVideoFFMpegWriter: MediaEditorVideoExportWriter {
    public static let registerFFMpegGlobals: Void = {
        FFMpegGlobals.initializeGlobals()
        return
    }()
    
    var ffmpegWriter: FFMpegVideoWriter?
    var pool: CVPixelBufferPool?
    var secondPool: CVPixelBufferPool?
        
    func setup(configuration: MediaEditorVideoExport.Configuration, outputPath: String) {
        let _ = MediaEditorVideoFFMpegWriter.registerFFMpegGlobals
        
        let width = Int32(configuration.dimensions.width)
        let height = Int32(configuration.dimensions.height)
        
        let bufferOptions: [String: Any] = [
            kCVPixelBufferPoolMinimumBufferCountKey as String: 3 as NSNumber
        ]
        let pixelBufferOptions: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA as NSNumber,
            kCVPixelBufferWidthKey as String: UInt32(width),
            kCVPixelBufferHeightKey as String: UInt32(height)//,
//            kCVPixelBufferIOSurfacePropertiesKey as String: [:] as NSDictionary
        ]
        
        var pool: CVPixelBufferPool?
        CVPixelBufferPoolCreate(nil, bufferOptions as CFDictionary, pixelBufferOptions as CFDictionary, &pool)
        guard let pool else {
            self.status = .failed
            return
        }
        self.pool = pool
        
        let secondPixelBufferOptions: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8VideoRange_8A_TriPlanar as NSNumber,
            kCVPixelBufferWidthKey as String: UInt32(width),
            kCVPixelBufferHeightKey as String: UInt32(height)//,
//            kCVPixelBufferIOSurfacePropertiesKey as String: [:] as NSDictionary
        ]
        
        var secondPool: CVPixelBufferPool?
        CVPixelBufferPoolCreate(nil, bufferOptions as CFDictionary, secondPixelBufferOptions as CFDictionary, &secondPool)
        guard let secondPool else {
            self.status = .failed
            return
        }
        self.secondPool = secondPool
        
        let ffmpegWriter = FFMpegVideoWriter()
        self.ffmpegWriter = ffmpegWriter
        
        if !ffmpegWriter.setup(withOutputPath: outputPath, width: width, height: height) {
            self.status = .failed
        }
    }
    
    func setupVideoInput(configuration: MediaEditorVideoExport.Configuration, preferredTransform: CGAffineTransform?, sourceFrameRate: Float) {
        
    }
    
    func setupAudioInput(configuration: MediaEditorVideoExport.Configuration) {
        
    }
    
    func startWriting() -> Bool {
        if self.status != .failed {
            self.status = .writing
            return true
        } else {
            return false
        }
    }
    
    func startSession(atSourceTime time: CMTime) {
        
    }
    
    func finishWriting(completion: @escaping () -> Void) {
        guard let ffmpegWriter = self.ffmpegWriter else {
            return
        }
        ffmpegWriter.finalizeVideo()
        self.status = .completed
        completion()
    }
    
    func cancelWriting() {
        
    }
    
    func requestVideoDataWhenReady(on queue: DispatchQueue, using block: @escaping () -> Void) {
        queue.async {
            block()
        }
    }
    
    func requestAudioDataWhenReady(on queue: DispatchQueue, using block: @escaping () -> Void) {
        
    }
    
    var isReadyForMoreVideoData: Bool {
        return true
    }
    
    func appendVideoBuffer(_ buffer: CMSampleBuffer) -> Bool {
        return false
    }
    
    var isFirst = true
    func appendPixelBuffer(_ buffer: CVPixelBuffer, at time: CMTime) -> Bool {
        guard let ffmpegWriter = self.ffmpegWriter, let secondPool = self.secondPool else {
            return false
        }
        
        let width = Int32(CVPixelBufferGetWidth(buffer))
        let height = Int32(CVPixelBufferGetHeight(buffer))
        let bytesPerRow = Int32(CVPixelBufferGetBytesPerRow(buffer))
        
        var convertedBuffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, secondPool, &convertedBuffer)
        guard let convertedBuffer else {
            return false
        }
        
        CVPixelBufferLockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
        let src = CVPixelBufferGetBaseAddress(buffer)
        
        CVPixelBufferLockBaseAddress(convertedBuffer, CVPixelBufferLockFlags(rawValue: 0))
        let dst = CVPixelBufferGetBaseAddress(convertedBuffer)
                
        encodeRGBAToYUVA(dst, src, width, height, bytesPerRow, false, false)
                
        CVPixelBufferUnlockBaseAddress(convertedBuffer, CVPixelBufferLockFlags(rawValue: 0))
        CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags(rawValue: 0))
        
        if self.isFirst {
            let path = NSTemporaryDirectory() + "test.png"
            let image = self.imageFromCVPixelBuffer(convertedBuffer, orientation: .up)
            let data = image?.pngData()
            try? data?.write(to: URL(fileURLWithPath: path))
            self.isFirst = false
        }
                
        return ffmpegWriter.encodeFrame(convertedBuffer)
    }
    
    func imageFromCVPixelBuffer(_ pixelBuffer: CVPixelBuffer, orientation: UIImage.Orientation) -> UIImage? {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        guard let context = CGContext(
            data: baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
            return nil
        }
        
        guard let cgImage = context.makeImage() else {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
            return nil
        }
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
            
        return UIImage(cgImage: cgImage, scale: 1.0, orientation: orientation)
    }
    
    func markVideoAsFinished() {
        
    }
    
    var pixelBufferPool: CVPixelBufferPool? {
        return self.pool
    }
    
    var isReadyForMoreAudioData: Bool {
        return false
    }
    
    func appendAudioBuffer(_ buffer: CMSampleBuffer) -> Bool {
        return false
    }
    
    func markAudioAsFinished() {
        
    }
    
    var status: ExportWriterStatus = .unknown
    
    var error: Error?
}
