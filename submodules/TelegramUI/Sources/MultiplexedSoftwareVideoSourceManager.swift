import Foundation
import UIKit
import Postbox
import TelegramCore
import SyncCore
import SwiftSignalKit
import CoreMedia
import UniversalMediaPlayer

private final class RunningSoftwareVideoSource {
    let fetchDisposable: Disposable
    let fetchStatusDisposable: Disposable
    
    var source: SoftwareVideoSource?
    var beginTime: Double?
    var frame: MediaTrackFrame?
    
    init(fetchDisposable: Disposable, fetchStatusDisposable: Disposable) {
        self.fetchDisposable = fetchDisposable
        self.fetchStatusDisposable = fetchStatusDisposable
    }
    
    deinit {
        self.fetchDisposable.dispose()
        self.fetchStatusDisposable.dispose()
    }
}

final class MultiplexedSoftwareVideoSourceManager {
    private let queue: Queue
    private let account: Account
    private var videoSources: [MediaId: RunningSoftwareVideoSource] = [:]
    private(set) var immediateVideoFrames: [MediaId: MediaTrackFrame] = [:]
    
    private var updatingAt: Double?
    
    var updateFrame: ((MediaId, MediaTrackFrame) -> Void)?
    
    init(queue: Queue, account: Account) {
        self.queue = queue
        self.account = account
    }
    
    func updateVisibleItems(_ media: [TelegramMediaFile]) {
        self.queue.async {
            var dict: [MediaId: TelegramMediaFile] = [:]
            for file in media {
                dict[file.fileId] = file
            }
            
            var removeIds: [MediaId] = []
            for id in self.videoSources.keys {
                if dict[id] == nil {
                    removeIds.append(id)
                }
            }
            
            for id in removeIds {
                self.videoSources.removeValue(forKey: id)
            }
            
            for (id, file) in dict {
                if self.videoSources[id] == nil {
                    self.videoSources[id] = RunningSoftwareVideoSource(fetchDisposable: (self.account.postbox.mediaBox.resourceData(file.resource) |> deliverOn(self.queue)).start(next: { [weak self] data in
                        if let strongSelf = self, let context = strongSelf.videoSources[id] {
                            if data.complete {
                                context.source = SoftwareVideoSource(path: data.path)
                            }
                        }
                    }), fetchStatusDisposable: fetchedMediaResource(mediaBox: self.account.postbox.mediaBox, reference: AnyMediaReference.standalone(media: file).resourceReference(file.resource)).start())
                }
            }
        }
    }
    
    func update(at timestamp: Double) {
        assert(Queue.mainQueue().isCurrent())
        let begin = self.updatingAt == nil
        self.updatingAt = timestamp
        if begin {
            self.queue.async {
                var immediateVideoFrames: [MediaId: MediaTrackFrame] = [:]
                loop: for (id, source) in self.videoSources {
                    if let context = source.source {
                        if let beginTime = source.beginTime, let currentFrame = source.frame {
                            let framePosition = currentFrame.position.seconds
                            let frameDuration = currentFrame.duration.seconds
                            
                            if false && beginTime + framePosition + frameDuration > timestamp {
                                immediateVideoFrames[id] = currentFrame
                                continue loop
                            }
                        }
                        
                        /*if let frame = context.readFrame(maxPts: nil) {
                            if source.frame == nil || CMTimeCompare(source.frame!.position, frame.position) > 0 {
                                source.beginTime = timestamp
                            }
                            source.frame = frame
                            immediateVideoFrames[id] = frame
                            self.updateFrame?(id, frame)
                        }*/
                    }
                }
                
                Queue.mainQueue().async {
                    self.immediateVideoFrames = immediateVideoFrames
                    if let updatingAt = self.updatingAt, !updatingAt.isEqual(to: timestamp) {
                        self.updatingAt = nil
                        self.update(at: updatingAt)
                    } else {
                        self.updatingAt = nil
                    }
                }
            }
        }
    }
}
