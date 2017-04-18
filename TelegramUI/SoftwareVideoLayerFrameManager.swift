import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit
import CoreMedia

private let applyQueue = Queue()
private let workers = ThreadPool(threadCount: 2, threadPriority: 0.09)
private var nextWorker = 0

final class SoftwareVideoLayerFrameManager {
    private let fetchDisposable: Disposable
    private var dataDisposable = MetaDisposable()
    private var source: SoftwareVideoSource?
    
    private var baseTimestamp: Double?
    private var frames: [MediaTrackFrame] = []
    private var minPts: CMTime?
    private var maxPts: CMTime?
    
    private let account: Account
    private let resource: MediaResource
    private let queue: ThreadPoolQueue
    private let layerHolder: SampleBufferLayer
    
    init(account: Account, resource: MediaResource, layerHolder: SampleBufferLayer) {
        nextWorker += 1
        self.account = account
        self.resource = resource
        self.queue = ThreadPoolQueue(threadPool: workers)
        self.layerHolder = layerHolder
        self.fetchDisposable = account.postbox.mediaBox.fetchedResource(resource, tag: TelegramMediaResourceFetchTag(statsCategory: .video)).start()
    }
    
    deinit {
        self.fetchDisposable.dispose()
        self.dataDisposable.dispose()
    }
    
    func start() {
        self.dataDisposable.set((self.account.postbox.mediaBox.resourceData(self.resource, option: .complete(waitUntilFetchStatus: false)) |> deliverOn(applyQueue)).start(next: { [weak self] data in
            if let strongSelf = self, data.complete {
                strongSelf.source = SoftwareVideoSource(path: data.path)
            }
        }))
    }
    
    func tick(timestamp: Double) {
        applyQueue.async {
            
            
            if self.baseTimestamp == nil && !self.frames.isEmpty {
                self.baseTimestamp = timestamp
            }
            
            if let baseTimestamp = self.baseTimestamp {
                var index = 0
                var latestFrameIndex: Int?
                while index < self.frames.count {
                    if baseTimestamp + self.frames[index].position.seconds + self.frames[index].duration.seconds <= timestamp {
                        latestFrameIndex = index
                    }
                    index += 1
                }
                if let latestFrameIndex = latestFrameIndex {
                    let frame = self.frames[latestFrameIndex]
                    for i in (0 ... latestFrameIndex).reversed() {
                        self.frames.remove(at: i)
                    }
                    if self.layerHolder.layer.status == .failed {
                        self.layerHolder.layer.flush()
                    }
                    self.layerHolder.layer.enqueue(frame.sampleBuffer)
                }
            }
            
            self.poll()
        }
    }
    
    private var polling = false
    
    private func poll() {
        if self.frames.count < 3 && !self.polling {
            self.polling = true
            let maxPts = self.maxPts
            self.queue.addTask(ThreadPoolTask { [weak self] state in
                if state.cancelled {
                    return
                }
                if let strongSelf = self {
                    let frameAndLoop = strongSelf.source?.readFrame(maxPts: maxPts)
                    
                    applyQueue.async {
                        if let strongSelf = self {
                            strongSelf.polling = false
                            if let frame = frameAndLoop?.0 {
                                if strongSelf.minPts == nil || CMTimeCompare(strongSelf.minPts!, frame.position) < 0 {
                                    strongSelf.minPts = frame.position
                                }
                                strongSelf.frames.append(frame)
                            }
                            if let loop = frameAndLoop?.1, loop {
                                strongSelf.maxPts = strongSelf.minPts
                                strongSelf.minPts = nil
                            }
                            strongSelf.poll()
                        }
                    }
                }
            })
        }
    }
}
