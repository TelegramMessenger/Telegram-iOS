import Foundation
import SwiftSignalKit
import CoreMedia

enum MediaTrackFrameBufferStatus {
    case buffering
    case full(until: Double)
    case finished(at: Double)
}

enum MediaTrackFrameResult {
    case noFrames
    case skipFrame
    case restoreState([MediaTrackFrame], CMTime)
    case frame(MediaTrackFrame)
    case finished
}

private let traceEvents = false

final class MediaTrackFrameBuffer {
    private let stallDuration: Double = 1.0
    private let lowWaterDuration: Double = 2.0
    private let highWaterDuration: Double = 3.0
    
    private let frameSource: MediaFrameSource
    private let decoder: MediaTrackFrameDecoder
    private let type: MediaTrackFrameType
    let duration: CMTime
    let rotationAngle: Double
    let aspect: Double
    
    var statusUpdated: () -> Void = { }
    
    private var frameSourceSinkIndex: Int?
    
    private var frames: [MediaTrackDecodableFrame] = []
    private var endOfStream = false
    private var bufferedUntilTime: CMTime?
    
    init(frameSource: MediaFrameSource, decoder: MediaTrackFrameDecoder, type: MediaTrackFrameType, duration: CMTime, rotationAngle: Double, aspect: Double) {
        self.frameSource = frameSource
        self.type = type
        self.decoder = decoder
        self.duration = duration
        self.rotationAngle = rotationAngle
        self.aspect = aspect
        
        self.frameSourceSinkIndex = self.frameSource.addEventSink { [weak self] event in
            if let strongSelf = self {
                switch event {
                    case let .frames(frames):
                        var filteredFrames: [MediaTrackDecodableFrame] = []
                        for frame in frames {
                            if frame.type == type {
                                filteredFrames.append(frame)
                            }
                        }
                        if !filteredFrames.isEmpty {
                            strongSelf.addFrames(filteredFrames)
                        }
                    case .endOfStream:
                        strongSelf.endOfStreamReached()
                }
            }
        }
    }
    
    deinit {
        if let frameSourceSinkIndex = self.frameSourceSinkIndex {
            self.frameSource.removeEventSink(frameSourceSinkIndex)
        }
    }
    
    private func addFrames(_ frames: [MediaTrackDecodableFrame]) {
        self.frames.append(contentsOf: frames)
        var maxUntilTime: CMTime?
        for frame in frames {
            let frameEndTime = CMTimeAdd(frame.pts, frame.duration)
            if self.bufferedUntilTime == nil || CMTimeCompare(self.bufferedUntilTime!, frameEndTime) < 0 {
                self.bufferedUntilTime = frameEndTime
                maxUntilTime = frameEndTime
            }
        }
        
        if let maxUntilTime = maxUntilTime {
            if traceEvents {
                print("added \(frames.count) frames until \(CMTimeGetSeconds(maxUntilTime)), \(self.frames.count) total")
            }
        }
        
        self.statusUpdated()
    }
    
    private func endOfStreamReached() {
        self.endOfStream = true
        self.statusUpdated()
    }
    
    func status(at timestamp: Double) -> MediaTrackFrameBufferStatus {
        var bufferedDuration = 0.0
        if let bufferedUntilTime = bufferedUntilTime {
            if CMTimeCompare(bufferedUntilTime, self.duration) >= 0 || self.endOfStream {
                return .finished(at: CMTimeGetSeconds(bufferedUntilTime))
            }
            
            bufferedDuration = CMTimeGetSeconds(bufferedUntilTime) - timestamp
        }
        
        let minTimestamp = timestamp - 1.0
        for i in (0 ..< self.frames.count).reversed() {
            if CMTimeGetSeconds(self.frames[i].pts) < minTimestamp {
                self.frames.remove(at: i)
            }
        }
        
        if bufferedDuration < self.lowWaterDuration {
            if traceEvents {
                print("buffered duration: \(bufferedDuration), requesting until \(timestamp) + \(self.highWaterDuration - bufferedDuration)")
            }
            self.frameSource.generateFrames(until: timestamp + self.highWaterDuration)
            
            if bufferedDuration > self.stallDuration {
                if traceEvents {
                    print("buffered1 duration: \(bufferedDuration), wait until \(timestamp) + \(self.highWaterDuration - bufferedDuration)")
                }
                return .full(until: timestamp + self.highWaterDuration)
            } else {
                return .buffering
            }
        } else {
            if traceEvents {
                print("buffered2 duration: \(bufferedDuration), wait until \(timestamp) + \(bufferedDuration - self.lowWaterDuration)")
            }
            return .full(until: timestamp + max(0.0, bufferedDuration - self.lowWaterDuration))
        }
    }
    
    var hasFrames: Bool {
        return !self.frames.isEmpty
    }
    
    func takeFrame() -> MediaTrackFrameResult {
        if !self.frames.isEmpty {
            let frame = self.frames.removeFirst()
            if let decodedFrame = self.decoder.decode(frame: frame) {
                return .frame(decodedFrame)
            } else {
                return .skipFrame
            }
        } else {
            if self.endOfStream, let decodedFrame = self.decoder.takeRemainingFrame() {
                return .frame(decodedFrame)
            } else {
                if let bufferedUntilTime = bufferedUntilTime {
                    if CMTimeCompare(bufferedUntilTime, self.duration) >= 0 || self.endOfStream {
                        return .finished
                    }
                }
            }
        }
        return .noFrames
    }
}
