import Foundation
import UIKit
import Postbox
import TelegramCore
import SwiftSignalKit
import CoreMedia
import UniversalMediaPlayer

public let softwareVideoApplyQueue = Queue()
public let softwareVideoWorkers = ThreadPool(threadCount: 3, threadPriority: 0.2)
private var nextWorker = 0

public final class SoftwareVideoLayerFrameManager {
    private let fetchDisposable: Disposable
    private var dataDisposable = MetaDisposable()
    private let source = Atomic<SoftwareVideoSource?>(value: nil)
    private let hintVP9: Bool
    
    private var baseTimestamp: Double?
    private var frames: [MediaTrackFrame] = []
    private var minPts: CMTime?
    private var maxPts: CMTime?
    
    private let account: Account
    private let resource: MediaResource
    private let secondaryResource: MediaResource?
    private let queue: ThreadPoolQueue
    private let layerHolder: SampleBufferLayer
    
    private var rotationAngle: CGFloat = 0.0
    private var aspect: CGFloat = 1.0
    
    private var layerRotationAngleAndAspect: (CGFloat, CGFloat)?
    
    private var didStart = false
    var started: () -> Void = { }
    
    public init(account: Account, fileReference: FileMediaReference, layerHolder: SampleBufferLayer, hintVP9: Bool = false) {
        var resource = fileReference.media.resource
        var secondaryResource: MediaResource?
        for attribute in fileReference.media.attributes {
            if case .Video = attribute {
                if let thumbnail = fileReference.media.videoThumbnails.first {
                    resource = thumbnail.resource
                    secondaryResource = fileReference.media.resource
                }
            }
        }
        
        nextWorker += 1
        self.account = account
        self.resource = resource
        self.hintVP9 = hintVP9
        self.secondaryResource = secondaryResource
        self.queue = ThreadPoolQueue(threadPool: softwareVideoWorkers)
        self.layerHolder = layerHolder
        layerHolder.layer.videoGravity = .resizeAspectFill
        layerHolder.layer.masksToBounds = true
        self.fetchDisposable = fetchedMediaResource(mediaBox: account.postbox.mediaBox, reference: fileReference.resourceReference(resource)).start()
    }
    
    deinit {
        self.fetchDisposable.dispose()
        self.dataDisposable.dispose()
    }
    
    public func start() {
        func stringForResource(_ resource: MediaResource?) -> String {
            guard let resource = resource else {
                return "<none>"
            }
            if let resource = resource as? WebFileReferenceMediaResource {
                return resource.url
            } else {
                return resource.id.stringRepresentation
            }
        }
        Logger.shared.log("SoftwareVideo", "load video from \(stringForResource(self.resource)) or \(stringForResource(self.secondaryResource))")
        let secondarySignal: Signal<(String, MediaResource)?, NoError>
        if let secondaryResource = self.secondaryResource {
            secondarySignal = self.account.postbox.mediaBox.resourceData(secondaryResource, option: .complete(waitUntilFetchStatus: false))
            |> map { data -> (String, MediaResource)? in
                if data.complete {
                    return (data.path, secondaryResource)
                } else {
                    return nil
                }
            }
        } else {
            secondarySignal = .single(nil)
        }
        
        let firstResource = self.resource
        
        let firstReady: Signal<(String, MediaResource), NoError> = combineLatest(
            self.account.postbox.mediaBox.resourceData(self.resource, option: .complete(waitUntilFetchStatus: false)),
            secondarySignal
        )
        |> mapToSignal { first, second -> Signal<(String, MediaResource), NoError> in
            if first.complete {
                return .single((first.path, firstResource))
            } else if let second = second {
                return .single(second)
            } else {
                return .complete()
            }
        }
        |> take(1)
        
        self.dataDisposable.set((firstReady
        |> deliverOn(softwareVideoApplyQueue)).start(next: { [weak self] path, resource in
            if let strongSelf = self {
                let size = fileSize(path)
                Logger.shared.log("SoftwareVideo", "loaded video from \(stringForResource(resource)) (file size: \(String(describing: size))")
                
                let _ = strongSelf.source.swap(SoftwareVideoSource(path: path, hintVP9: strongSelf.hintVP9))
            }
        }))
    }
    
    public func tick(timestamp: Double) {
        softwareVideoApplyQueue.async {
            if self.baseTimestamp == nil && !self.frames.isEmpty {
                self.baseTimestamp = timestamp
            }
            
            if let baseTimestamp = self.baseTimestamp {
                var index = 0
                var latestFrameIndex: Int?
                while index < self.frames.count {
                    if baseTimestamp + self.frames[index].position.seconds + self.frames[index].duration.seconds <= timestamp {
                        latestFrameIndex = index
                        //print("latestFrameIndex = \(index)")
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
                    
                    if !self.didStart {
                        self.didStart = true
                        Queue.mainQueue().async {
                            self.started()
                        }
                    }
                }
            }
            
            self.poll()
        }
    }
    
    private var polling = false
    
    private func poll() {
        if self.frames.count < 2 && !self.polling {
            self.polling = true
            let minPts = self.minPts
            let maxPts = self.maxPts
            self.queue.addTask(ThreadPoolTask { [weak self] state in
                if state.cancelled.with({ $0 }) {
                    return
                }
                if let strongSelf = self {
                    var frameAndLoop: (MediaTrackFrame?, CGFloat, CGFloat, Bool)?
                        
                    var hadLoop = false
                    for _ in 0 ..< 1 {
                        frameAndLoop = (strongSelf.source.with { $0 })?.readFrame(maxPts: maxPts)
                        if let frameAndLoop = frameAndLoop {
                            if frameAndLoop.0 != nil || minPts != nil {
                                break
                            } else {
                                if frameAndLoop.3 {
                                    hadLoop = true
                                }
                                //print("skip nil frame loop: \(frameAndLoop.3)")
                            }
                        } else {
                            break
                        }
                    }
                    if let loop = frameAndLoop?.3, loop {
                        hadLoop = true
                    }
                    
                    softwareVideoApplyQueue.async {
                        if let strongSelf = self {
                            strongSelf.polling = false
                            if let (_, rotationAngle, aspect, _) = frameAndLoop {
                                strongSelf.rotationAngle = rotationAngle
                                strongSelf.aspect = aspect
                            }
                            if let frame = frameAndLoop?.0 {
                                if strongSelf.minPts == nil || CMTimeCompare(strongSelf.minPts!, frame.position) < 0 {
                                    var position = CMTimeAdd(frame.position, frame.duration)
                                    for _ in 0 ..< 1 {
                                        position = CMTimeAdd(position, frame.duration)
                                    }
                                    strongSelf.minPts = position
                                }
                                strongSelf.frames.append(frame)
                                strongSelf.frames.sort(by: { lhs, rhs in
                                    if CMTimeCompare(lhs.position, rhs.position) < 0 {
                                        return true
                                    } else {
                                        return false
                                    }
                                })
                                //print("add frame at \(CMTimeGetSeconds(frame.position))")
                                //let positions = strongSelf.frames.map { CMTimeGetSeconds($0.position) }
                                //print("frames: \(positions)")
                            } else {
                                //print("not adding frames")
                            }
                            if hadLoop {
                                strongSelf.maxPts = strongSelf.minPts
                                strongSelf.minPts = nil
                                //print("loop at \(strongSelf.minPts)")
                            }
                            strongSelf.poll()
                        }
                    }
                }
            })
        }
    }
}
