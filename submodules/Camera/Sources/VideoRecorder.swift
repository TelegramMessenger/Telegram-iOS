import Foundation
import AVFoundation
import SwiftSignalKit

struct MediaPreset {
    var videoSettings: [String: Any]
    var audioSettings: [String: Any]
    
    init(videoSettings: [String: Any], audioSettings: [String: Any]) {
        self.videoSettings = videoSettings
        self.audioSettings = audioSettings
    }
    
    var hasAudio: Bool {
        return !self.audioSettings.isEmpty
    }
}

final class VideoRecorder {
    enum Result {
        enum Error {
            case generic
        }
        
        case success
        case writeError(Error)
        case finishError(Error)
    }
    
    private let completion: (Result) -> Void
    
    private let queue = Queue()
    private var assetWriter: AVAssetWriter?
    
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    
    private let preset: MediaPreset
    private let videoTransform: CGAffineTransform
    private let fileUrl: URL
    
    private (set) var isRecording = false
    private (set) var isStopping = false
    private var finishedWriting = false
    
    private var captureStartTimestamp: Double?
    private var firstVideoTimestamp: CMTime?
    private var lastVideoTimestamp: CMTime?
    private var lastAudioTimestamp: CMTime?
    
    private var pendingAudioBuffers: [CMSampleBuffer] = []
    
    init(preset: MediaPreset, videoTransform: CGAffineTransform, fileUrl: URL, completion: @escaping (Result) -> Void) {
        self.preset = preset
        self.videoTransform = videoTransform
        self.fileUrl = fileUrl
        self.completion = completion
    }
    
    func start() {
        self.queue.async {
            guard self.assetWriter == nil else {
                return
            }
            
            self.captureStartTimestamp = CFAbsoluteTimeGetCurrent()
            
            guard let assetWriter = try? AVAssetWriter(url: self.fileUrl, fileType: .mp4) else {
                return
            }
            
            let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: self.preset.videoSettings)
            videoInput.expectsMediaDataInRealTime = true
            videoInput.transform = self.videoTransform
            if assetWriter.canAdd(videoInput) {
                assetWriter.add(videoInput)
            }
            
            let audioInput: AVAssetWriterInput?
            if self.preset.hasAudio {
                audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: self.preset.audioSettings)
                audioInput!.expectsMediaDataInRealTime = true
                if assetWriter.canAdd(audioInput!) {
                    assetWriter.add(audioInput!)
                }
            } else {
                audioInput = nil
            }
            
            self.assetWriter = assetWriter
            self.videoInput = videoInput
            self.audioInput = audioInput
            
            self.isRecording = true
            
            assetWriter.startWriting()
        }
    }
    
    func stop() {
        self.queue.async {
            guard let captureStartTimestamp = self.captureStartTimestamp, abs(CFAbsoluteTimeGetCurrent() - captureStartTimestamp) > 0.5 else {
                return
            }
            
            self.isStopping = true
            
            if self.audioInput == nil {
                self.finish()
            }
        }
    }
    
    private func finish() {
        guard let assetWriter = self.assetWriter else {
            return
        }
        
        self.queue.async {
            self.isRecording = false
            self.isStopping = false
            
            assetWriter.finishWriting {
                self.finishedWriting = true
                
                if case .completed = assetWriter.status {
                    self.completion(.success)
                } else {
                    self.completion(.finishError(.generic))
                }
            }
        }
    }
    
    private var skippedCount = 0
    func appendVideo(sampleBuffer: CMSampleBuffer) {
        if self.skippedCount < 2 {
            self.skippedCount += 1
            return
        }
        self.queue.async {
            guard let assetWriter = self.assetWriter, let videoInput = self.videoInput, (self.isRecording || self.isStopping) && !self.finishedWriting else {
                return
            }
            let timestamp = sampleBuffer.presentationTimestamp

            switch assetWriter.status {
            case .unknown:
               break
            case .writing:
                if self.firstVideoTimestamp == nil {
                    self.firstVideoTimestamp = timestamp
                    assetWriter.startSession(atSourceTime: timestamp)
                }
                while !videoInput.isReadyForMoreMediaData {
                    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
                }
                
                if videoInput.append(sampleBuffer) {
                    self.lastVideoTimestamp = timestamp
                }
                
                if self.audioInput != nil && self.isStopping, let lastVideoTimestamp = self.lastAudioTimestamp, let lastAudioTimestamp = self.lastAudioTimestamp, lastVideoTimestamp >= lastAudioTimestamp {
                    self.finish()
                }
            case .failed:
                self.isRecording = false
                self.completion(.writeError(.generic))
            default:
                break
            }
        }
    }
    
    func appendAudio(sampleBuffer: CMSampleBuffer) {
        self.queue.async {
            guard let _ = self.assetWriter, let audioInput = self.audioInput, !self.isStopping && !self.finishedWriting else {
                return
            }
            let timestamp = sampleBuffer.presentationTimestamp
            
            if let _ = self.firstVideoTimestamp {
                if !self.pendingAudioBuffers.isEmpty {
                    for buffer in self.pendingAudioBuffers {
                        audioInput.append(buffer)
                    }
                    self.pendingAudioBuffers.removeAll()
                }
                
                while !audioInput.isReadyForMoreMediaData {
                    RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
                }
                
                if audioInput.append(sampleBuffer) {
                    self.lastAudioTimestamp = timestamp
                }
            } else {
                self.pendingAudioBuffers.append(sampleBuffer)
            }
        }
    }
    
    var duration: Double? {
        guard let firstTimestamp = self.firstVideoTimestamp, let lastTimestamp = self.lastVideoTimestamp else {
            return nil
        }
        return (lastTimestamp - firstTimestamp).seconds
    }
}
