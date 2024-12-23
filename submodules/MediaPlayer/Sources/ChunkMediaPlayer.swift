import Foundation
import UIKit
import SwiftSignalKit
import Postbox
import CoreMedia
import TelegramCore
import TelegramAudio

public final class ChunkMediaPlayerPart {
    public enum Id: Hashable {
        case tempFile(path: String)
        case directFile(path: String, audio: DirectStream?, video: DirectStream?)
    }
    
    public struct DirectStream: Hashable {
        public let index: Int
        public let startPts: CMTime
        public let endPts: CMTime
        public let duration: Double
        
        public init(index: Int, startPts: CMTime, endPts: CMTime, duration: Double) {
            self.index = index
            self.startPts = startPts
            self.endPts = endPts
            self.duration = duration
        }
    }
    
    public enum Content {
        public final class TempFile {
            public let file: TempBoxFile
            
            public init(file: TempBoxFile) {
                self.file = file
            }
            
            deinit {
                TempBox.shared.dispose(self.file)
            }
        }
        
        public final class FFMpegDirectFile {
            public let path: String
            public let audio: DirectStream?
            public let video: DirectStream?
            
            public init(path: String, audio: DirectStream?, video: DirectStream?) {
                self.path = path
                self.audio = audio
                self.video = video
            }
        }
        
        case tempFile(TempFile)
        case directFile(FFMpegDirectFile)
    }
    
    public let startTime: Double
    public let endTime: Double
    public let content: Content
    public let clippedStartTime: Double?
    public let codecName: String?
    
    public var id: Id {
        switch self.content {
        case let .tempFile(tempFile):
            return .tempFile(path: tempFile.file.path)
        case let .directFile(directFile):
            return .directFile(path: directFile.path, audio: directFile.audio, video: directFile.video)
        }
    }
    
    public init(startTime: Double, clippedStartTime: Double? = nil, endTime: Double, content: Content, codecName: String?) {
        self.startTime = startTime
        self.clippedStartTime = clippedStartTime
        self.endTime = endTime
        self.content = content
        self.codecName = codecName
    }
}

public final class ChunkMediaPlayerPartsState {
    public let duration: Double?
    public let parts: [ChunkMediaPlayerPart]
    
    public init(duration: Double?, parts: [ChunkMediaPlayerPart]) {
        self.duration = duration
        self.parts = parts
    }
}

public protocol ChunkMediaPlayer: AnyObject {
    var status: Signal<MediaPlayerStatus, NoError> { get }
    var audioLevelEvents: Signal<Float, NoError> { get }
    var actionAtEnd: MediaPlayerActionAtEnd { get set }
    
    func play()
    func playOnceWithSound(playAndRecord: Bool, seek: MediaPlayerSeek)
    func setSoundMuted(soundMuted: Bool)
    func continueWithOverridingAmbientMode(isAmbient: Bool)
    func continuePlayingWithoutSound(seek: MediaPlayerSeek)
    func setContinuePlayingWithoutSoundOnLostAudioSession(_ value: Bool)
    func setForceAudioToSpeaker(_ value: Bool)
    func setKeepAudioSessionWhilePaused(_ value: Bool)
    func pause()
    func togglePlayPause(faded: Bool)
    func seek(timestamp: Double, play: Bool?)
    func setBaseRate(_ baseRate: Double)
}
