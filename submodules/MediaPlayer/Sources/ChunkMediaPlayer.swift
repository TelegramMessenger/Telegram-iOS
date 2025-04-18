import Foundation

import SwiftSignalKit
import Postbox
import CoreMedia
import TelegramCore


public final class ChunkMediaPlayerPart {
    public enum Id: Hashable {
        case tempFile(path: String)
        case directStream
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
    
    public final class TempFile {
        public let file: TempBoxFile
        
        public init(file: TempBoxFile) {
            self.file = file
        }
        
        deinit {
            //TempBox.shared.dispose(self.file)
        }
    }
    
    public let startTime: Double
    public let endTime: Double
    public let content: TempFile
    public let clippedStartTime: Double?
    public let codecName: String?
    public let offsetTime: Double
    
    public var id: Id {
        return .tempFile(path: self.content.file.path)
    }
    
    public init(startTime: Double, clippedStartTime: Double? = nil, endTime: Double, content: TempFile, codecName: String?, offsetTime: Double) {
        self.startTime = startTime
        self.clippedStartTime = clippedStartTime
        self.endTime = endTime
        self.content = content
        self.codecName = codecName
        self.offsetTime = offsetTime
    }
}

public final class ChunkMediaPlayerPartsState {
    public final class DirectReader {
        public struct Stream {
            public let mediaBox: MediaBox
            public let resource: MediaResource
            public let size: Int64
            public let index: Int
            public let seek: (streamIndex: Int, pts: Int64)
            public let maxReadablePts: (streamIndex: Int, pts: Int64, isEnded: Bool)?
            public let codecName: String?
            
            public init(mediaBox: MediaBox, resource: MediaResource, size: Int64, index: Int, seek: (streamIndex: Int, pts: Int64), maxReadablePts: (streamIndex: Int, pts: Int64, isEnded: Bool)?, codecName: String?) {
                self.mediaBox = mediaBox
                self.resource = resource
                self.size = size
                self.index = index
                self.seek = seek
                self.maxReadablePts = maxReadablePts
                self.codecName = codecName
            }
        }
        
        public final class Impl {
            public let video: Stream?
            public let audio: Stream?
            
            public init(video: Stream?, audio: Stream?) {
                self.video = video
                self.audio = audio
            }
        }
        
        public let id: Int
        public let seekPosition: Double
        public let availableUntilPosition: Double
        public let bufferedUntilEnd: Bool
        public let impl: Impl?
        
        public init(id: Int, seekPosition: Double, availableUntilPosition: Double, bufferedUntilEnd: Bool, impl: Impl?) {
            self.id = id
            self.seekPosition = seekPosition
            self.availableUntilPosition = availableUntilPosition
            self.bufferedUntilEnd = bufferedUntilEnd
            self.impl = impl
        }
    }
    
    public enum Content {
        case parts([ChunkMediaPlayerPart])
        case directReader(DirectReader)
    }
    
    public let duration: Double?
    public let content: Content
    
    public init(duration: Double?, content: Content) {
        self.duration = duration
        self.content = content
    }
}

#if os(iOS)

import UIKit
import TelegramAudio

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

#endif
