import Foundation
import UIKit
import CoreMedia
import FFMpegBinding
import ImageDCT
import Accelerate

final class MediaEditorVideoFFMpegWriter: MediaEditorVideoExportWriter {
    public static let registerFFMpegGlobals: Void = {
        FFMpegGlobals.initializeGlobals()
        return
    }()
    
    let ffmpegWriter = FFMpegVideoWriter()
    var pool: CVPixelBufferPool?
    
    let conversionInfo: vImage_ARGBToYpCbCr
    
    init() {
        var pixelRange = vImage_YpCbCrPixelRange( Yp_bias: 16, CbCr_bias: 128, YpRangeMax: 235, CbCrRangeMax: 240, YpMax: 235, YpMin: 16, CbCrMax: 240, CbCrMin: 16)
        var conversionInfo = vImage_ARGBToYpCbCr()
        let _ = vImageConvert_ARGBToYpCbCr_GenerateConversion(kvImage_ARGBToYpCbCrMatrix_ITU_R_709_2, &pixelRange, &conversionInfo, kvImageARGB8888, kvImage420Yp8_Cb8_Cr8, vImage_Flags(kvImageNoFlags))
        self.conversionInfo = conversionInfo
    }
        
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
            kCVPixelBufferHeightKey as String: UInt32(height)
        ]
        
        var pool: CVPixelBufferPool?
        CVPixelBufferPoolCreate(nil, bufferOptions as CFDictionary, pixelBufferOptions as CFDictionary, &pool)
        guard let pool else {
            self.status = .failed
            return
        }
        self.pool = pool
        
        if !self.ffmpegWriter.setup(withOutputPath: outputPath, width: width, height: height, bitrate: 240 * 1000, framerate: 30) {
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
        self.ffmpegWriter.finalizeVideo()
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
    
    func appendPixelBuffer(_ buffer: CVPixelBuffer, at time: CMTime) -> Bool {
        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        
        let frame = FFMpegAVFrame(pixelFormat: .YUVA, width: Int32(width), height: Int32(height))
        
        CVPixelBufferLockBaseAddress(buffer, CVPixelBufferLockFlags.readOnly)
        let src = CVPixelBufferGetBaseAddress(buffer)
        
        var srcBuffer = vImage_Buffer(data: src, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: bytesPerRow)

        var yBuffer = vImage_Buffer(data: frame.data[0], height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: width)
        var uBuffer = vImage_Buffer(data: frame.data[1], height: vImagePixelCount(height / 2), width: vImagePixelCount(width / 2), rowBytes: width / 2)
        var vBuffer = vImage_Buffer(data: frame.data[2], height: vImagePixelCount(height / 2), width: vImagePixelCount(width / 2), rowBytes: width / 2)
        var aBuffer = vImage_Buffer(data: frame.data[3], height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: width)
        
        var outInfo = self.conversionInfo
        let _ = vImageConvert_ARGB8888To420Yp8_Cb8_Cr8(&srcBuffer, &yBuffer, &uBuffer, &vBuffer, &outInfo, [ 3, 2, 1, 0 ], vImage_Flags(kvImageDoNotTile))
        vImageExtractChannel_ARGB8888(&srcBuffer, &aBuffer, 3, vImage_Flags(kvImageDoNotTile))
        
        CVPixelBufferUnlockBaseAddress(buffer, CVPixelBufferLockFlags.readOnly)
        
        return self.ffmpegWriter.encode(frame)
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
