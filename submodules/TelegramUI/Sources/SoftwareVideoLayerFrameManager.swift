import Foundation
import UIKit
import Postbox
import TelegramCore
import SyncCore
import SwiftSignalKit
import CoreMedia
import UniversalMediaPlayer

private let applyQueue = Queue()
private let workers = ThreadPool(threadCount: 2, threadPriority: 0.09)
private var nextWorker = 0

final class SoftwareVideoLayerFrameManager {
    private let fetchDisposable: Disposable
    private var dataDisposable = MetaDisposable()
    private let source = Atomic<SoftwareVideoSource?>(value: nil)
    
    private var baseTimestamp: Double?
    private var frames: [MediaTrackFrame] = []
    private var minPts: CMTime?
    private var maxPts: CMTime?
    
    private let account: Account
    private let resource: MediaResource
    private let queue: ThreadPoolQueue
    private let layerHolder: SampleBufferLayer
    
    private var rotationAngle: CGFloat = 0.0
    private var aspect: CGFloat = 1.0
    
    private var layerRotationAngleAndAspect: (CGFloat, CGFloat)?
    
    init(account: Account, fileReference: FileMediaReference, resource: MediaResource, layerHolder: SampleBufferLayer) {
        nextWorker += 1
        self.account = account
        self.resource = resource
        self.queue = ThreadPoolQueue(threadPool: workers)
        self.layerHolder = layerHolder
        layerHolder.layer.videoGravity = .resizeAspectFill
        layerHolder.layer.masksToBounds = true
        self.fetchDisposable = fetchedMediaResource(mediaBox: account.postbox.mediaBox, reference: fileReference.resourceReference(resource)).start()
    }
    
    deinit {
        self.fetchDisposable.dispose()
        self.dataDisposable.dispose()
    }
    
    func start() {
        self.dataDisposable.set((self.account.postbox.mediaBox.resourceData(self.resource, option: .complete(waitUntilFetchStatus: false)) |> deliverOn(applyQueue)).start(next: { [weak self] data in
            if let strongSelf = self, data.complete {
                let _ = strongSelf.source.swap(SoftwareVideoSource(path: data.path))
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
                    /*if self.layerRotationAngleAndAspect?.0 != self.rotationAngle || self.layerRotationAngleAndAspect?.1 != self.aspect {
                        self.layerRotationAngleAndAspect = (self.rotationAngle, self.aspect)
                        var transform = CGAffineTransform(rotationAngle: CGFloat(self.rotationAngle))
                        if !self.rotationAngle.isZero {
                            transform = transform.scaledBy(x: CGFloat(self.aspect), y: CGFloat(1.0 / self.aspect))
                        }
                        self.layerHolder.layer.setAffineTransform(transform)
                    }*/
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
                if state.cancelled.with({ $0 }) {
                    return
                }
                if let strongSelf = self {
                    let frameAndLoop = (strongSelf.source.with { $0 })?.readFrame(maxPts: maxPts)
                    
                    applyQueue.async {
                        if let strongSelf = self {
                            strongSelf.polling = false
                            if let (_, rotationAngle, aspect, _) = frameAndLoop {
                                strongSelf.rotationAngle = rotationAngle
                                strongSelf.aspect = aspect
                            }
                            if let frame = frameAndLoop?.0 {
                                if strongSelf.minPts == nil || CMTimeCompare(strongSelf.minPts!, frame.position) < 0 {
                                    strongSelf.minPts = frame.position
                                }
                                strongSelf.frames.append(frame)
                            }
                            if let loop = frameAndLoop?.3, loop {
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
