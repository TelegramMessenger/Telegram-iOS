import Foundation
import CoreMedia
import FFMpegBinding

final class MediaEditorFFMpegWriter: MediaEditorVideoExportWriter {
    public static let registerFFMpegGlobals: Void = {
        FFMpegGlobals.initializeGlobals()
        return
    }()
    
    let ffmpegWriter = FFMpegVideoWriter()
    
    func setup(configuration: MediaEditorVideoExport.Configuration, outputPath: String) {
        let _ = MediaEditorFFMpegWriter.registerFFMpegGlobals
        
        self.ffmpegWriter.setup(
            withOutputPath: outputPath,
            width: Int32(configuration.dimensions.width),
            height: Int32(configuration.dimensions.height)
        )
    }
    
    func setupVideoInput(configuration: MediaEditorVideoExport.Configuration, preferredTransform: CGAffineTransform?, sourceFrameRate: Float) {
        
    }
    
    func setupAudioInput(configuration: MediaEditorVideoExport.Configuration) {
        
    }
    
    func startWriting() -> Bool {
        return false
    }
    
    func startSession(atSourceTime time: CMTime) {
        
    }
    
    func finishWriting(completion: @escaping () -> Void) {
        self.ffmpegWriter.finalizeVideo()
        completion()
    }
    
    func cancelWriting() {
        
    }
    
    func requestVideoDataWhenReady(on queue: DispatchQueue, using block: @escaping () -> Void) {
        
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
        
        return false
    }
    
    func markVideoAsFinished() {
        
    }
    
    var pixelBufferPool: CVPixelBufferPool?
    
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
