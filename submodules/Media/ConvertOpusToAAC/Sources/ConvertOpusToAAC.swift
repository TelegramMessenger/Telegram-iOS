import Foundation
import UniversalMediaPlayer
import AVFoundation
import SwiftSignalKit

public func convertOpusToAAC(sourcePath: String, allocateTempFile: @escaping () -> String) -> Signal<String?, NoError> {
    return Signal { subscriber in
        var isCancelled = false
        let queue = Queue()
        
        queue.async {
            do {
                let audioSource = SoftwareAudioSource(path: sourcePath)
                
                let outputPath = allocateTempFile()
                
                let assetWriter = try AVAssetWriter(outputURL: URL(fileURLWithPath: outputPath), fileType: .m4a)
                
                var channelLayout = AudioChannelLayout()
                memset(&channelLayout, 0, MemoryLayout<AudioChannelLayout>.size)
                channelLayout.mChannelLayoutTag = kAudioChannelLayoutTag_Mono
                
                let outputSettings: [String: Any] = [
                    AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                    AVSampleRateKey: 48000,
                    AVEncoderBitRateKey: 32000,
                    AVNumberOfChannelsKey: 1,
                    AVChannelLayoutKey: NSData(bytes: &channelLayout, length: MemoryLayout<AudioChannelLayout>.size)
                ]
                
                let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: outputSettings)
                assetWriter.add(audioInput)
                
                assetWriter.startWriting()
                assetWriter.startSession(atSourceTime: .zero)
                
                let finishWriting: () -> Void = {
                    assetWriter.finishWriting(completionHandler: {
                        subscriber.putNext(outputPath)
                        subscriber.putCompletion()
                    })
                }
                
                audioInput.requestMediaDataWhenReady(on: queue.queue, using: {
                    if audioInput.isReadyForMoreMediaData {
                        if !isCancelled, let sampleBuffer = audioSource.readSampleBuffer() {
                            if !audioInput.append(sampleBuffer) {
                                audioInput.markAsFinished()
                                finishWriting()
                                return
                            }
                        } else {
                            audioInput.markAsFinished()
                            finishWriting()
                        }
                    }
                })
            } catch let e {
                print("Error: \(e)")
                subscriber.putNext(nil)
                subscriber.putCompletion()
            }
        }
        
        return ActionDisposable {
            isCancelled = true
        }
    }
}
