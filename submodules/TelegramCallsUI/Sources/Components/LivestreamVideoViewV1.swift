import Foundation
import UIKit
import AVFoundation
import SwiftSignalKit
import UniversalMediaPlayer
import Postbox
import TelegramCore
import AccountContext
import TelegramAudio
import Display
import TelegramVoip
import RangeSet
import ManagedFile
import FFMpegBinding
import TelegramUniversalVideoContent

final class LivestreamVideoViewV1: UIView {
    private final class PartContext {
        let part: DirectMediaStreamingContext.Playlist.Part
        let disposable = MetaDisposable()
        var resolvedTimeOffset: Double?
        var data: TempBoxFile?
        var info: FFMpegMediaInfo?
        
        init(part: DirectMediaStreamingContext.Playlist.Part) {
            self.part = part
        }
        
        deinit {
            self.disposable.dispose()
        }
    }
    
    private let context: AccountContext
    private let audioSessionManager: ManagedAudioSession
    private let call: PresentationGroupCall

    private let chunkPlayerPartsState = Promise<ChunkMediaPlayerPartsState>(ChunkMediaPlayerPartsState(duration: 10000000.0, content: .parts([])))
    private var parts: [ChunkMediaPlayerPart] = [] {
        didSet {
            self.chunkPlayerPartsState.set(.single(ChunkMediaPlayerPartsState(duration: 10000000.0, content: .parts(self.parts))))
        }
    }
    
    private let player: ChunkMediaPlayer
    private let playerNode: MediaPlayerNode
    
    private var playerStatus: MediaPlayerStatus?
    private var playerStatusDisposable: Disposable?
    
    private var streamingContextDisposable: Disposable?
    private var streamingContext: DirectMediaStreamingContext?
    private var playlistDisposable: Disposable?
    
    private var partContexts: [Int: PartContext] = [:]
    
    private var requestedSeekTimestamp: Double?
    
    init(
        context: AccountContext,
        audioSessionManager: ManagedAudioSession,
        call: PresentationGroupCall
    ) {
        self.context = context
        self.audioSessionManager = audioSessionManager
        self.call = call
        
        self.playerNode = MediaPlayerNode()
        
        var onSeeked: (() -> Void)?
        self.player = ChunkMediaPlayerV2(
            params: ChunkMediaPlayerV2.MediaDataReaderParams(context: context),
            audioSessionManager: audioSessionManager,
            source: .externalParts(self.chunkPlayerPartsState.get()),
            video: true,
            enableSound: true,
            baseRate: 1.0,
            onSeeked: {
                onSeeked?()
            },
            playerNode: self.playerNode
        )
        
        super.init(frame: CGRect())
        
        self.addSubview(self.playerNode.view)

        onSeeked = {
        }
        
        self.playerStatusDisposable = (self.player.status
        |> deliverOnMainQueue).startStrict(next: { [weak self] status in
            guard let self else {
                return
            }
            self.updatePlayerStatus(status: status)
        })
        
        var didProcessFramesToDisplay = false
        self.playerNode.isHidden = true
        self.playerNode.hasSentFramesToDisplay = { [weak self] in
            guard let self, !didProcessFramesToDisplay else {
                return
            }
            didProcessFramesToDisplay = true
            self.playerNode.isHidden = false
        }
        
        if let call = call as? PresentationGroupCallImpl {
            self.streamingContextDisposable = (call.externalMediaStream.get()
            |> deliverOnMainQueue).startStrict(next: { [weak self] externalMediaStream in
                guard let self else {
                    return
                }
                self.streamingContext = externalMediaStream
                self.resetPlayback()
            })
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.playerStatusDisposable?.dispose()
        self.streamingContextDisposable?.dispose()
        self.playlistDisposable?.dispose()
    }
    
    private func updatePlayerStatus(status: MediaPlayerStatus) {
        self.playerStatus = status
        
        self.updatePlaybackPositionIfNeeded()
    }
    
    private func resetPlayback() {
        self.parts = []
        
        self.playlistDisposable?.dispose()
        self.playlistDisposable = nil
        
        guard let streamingContext = self.streamingContext else {
            return
        }
        self.playlistDisposable = (streamingContext.playlistData()
        |> deliverOnMainQueue).startStrict(next: { [weak self] playlist in
            guard let self else {
                return
            }
            self.updatePlaylist(playlist: playlist)
        })
    }
    
    private func updatePlaylist(playlist: DirectMediaStreamingContext.Playlist) {
        var validPartIds: [Int] = []
        for part in playlist.parts.prefix(upTo: 4) {
            validPartIds.append(part.index)
            
            if self.partContexts[part.index] == nil {
                let partContext = PartContext(part: part)
                self.partContexts[part.index] = partContext
                
                if let streamingContext = self.streamingContext {
                    partContext.disposable.set((streamingContext.partData(index: part.index)
                    |> deliverOn(Queue.concurrentDefaultQueue())
                    |> map { data -> (file: TempBoxFile, info: FFMpegMediaInfo)? in
                        guard let data else {
                            return nil
                        }
                        let tempFile = TempBox.shared.tempFile(fileName: "part.mp4")
                        if let _ = try? data.write(to: URL(fileURLWithPath: tempFile.path), options: .atomic) {
                            if let info = extractFFMpegMediaInfo(path: tempFile.path) {
                                return (tempFile, info)
                            } else {
                                return nil
                            }
                        } else {
                            TempBox.shared.dispose(tempFile)
                            return nil
                        }
                    }
                    |> deliverOnMainQueue).startStrict(next: { [weak self, weak partContext] fileAndInfo in
                        guard let self, let partContext else {
                            return
                        }
                        if let (file, info) = fileAndInfo {
                            partContext.data = file
                            partContext.info = info
                        } else {
                            partContext.data = nil
                        }
                        self.updatePartContexts()
                    }))
                }
            }
        }
        
        var removedPartIds: [Int] = []
        for (id, _) in self.partContexts {
            if !validPartIds.contains(id) {
                removedPartIds.append(id)
            }
        }
        for id in removedPartIds {
            self.partContexts.removeValue(forKey: id)
        }
    }
    
    private func updatePartContexts() {
        var readyParts: [ChunkMediaPlayerPart] = []
        let sortedContexts = self.partContexts.values.sorted(by: { $0.part.timestamp < $1.part.timestamp })
        outer: for i in 0 ..< sortedContexts.count {
            let partContext = sortedContexts[i]
            
            if let data = partContext.data {
                let offsetTime: Double
                if i != 0 {
                    var foundOffset: Double?
                    inner: for j in 0 ..< i {
                        let previousContext = sortedContexts[j]
                        if previousContext.part.index == partContext.part.index - 1 {
                            if let previousInfo = previousContext.info {
                                if let previousResolvedOffset = previousContext.resolvedTimeOffset {
                                    if let audio = previousInfo.audio {
                                        foundOffset = previousResolvedOffset + audio.duration.seconds
                                    } else {
                                        foundOffset = partContext.part.timestamp
                                    }
                                }
                            }
                            break inner
                        }
                    }
                    if let foundOffset {
                        partContext.resolvedTimeOffset = foundOffset
                        offsetTime = foundOffset
                    } else {
                        continue outer
                    }
                } else {
                    if let resolvedOffset = partContext.resolvedTimeOffset {
                        offsetTime = resolvedOffset
                    } else {
                        offsetTime = partContext.part.timestamp
                        partContext.resolvedTimeOffset = offsetTime
                    }
                }
                
                readyParts.append(ChunkMediaPlayerPart(
                    startTime: partContext.part.timestamp,
                    endTime: partContext.part.timestamp + partContext.part.duration,
                    content: ChunkMediaPlayerPart.TempFile(file: data),
                    codecName: nil,
                    offsetTime: offsetTime
                ))
            }
        }
        readyParts.sort(by: { $0.startTime < $1.startTime })
        self.parts = readyParts
        self.updatePlaybackPositionIfNeeded()
    }
    
    private func updatePlaybackPositionIfNeeded() {
        if let part = self.parts.first {
            if let playerStatus = self.playerStatus, playerStatus.timestamp < part.startTime {
                if self.requestedSeekTimestamp != part.startTime {
                    self.requestedSeekTimestamp = part.startTime
                    self.player.seek(timestamp: part.startTime, play: true)
                }
            }
        }
    }
    
    public func update(size: CGSize, transition: ContainedViewLayoutTransition) {
        //transition.updateFrame(view: self.playerNode.view, frame: CGRect(origin: CGPoint(), size: size))
        self.playerNode.frame = CGRect(origin: CGPoint(), size: size)
    }
}
