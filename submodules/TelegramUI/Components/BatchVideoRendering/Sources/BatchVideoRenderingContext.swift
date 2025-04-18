import Foundation
import UIKit
import Display
import UniversalMediaPlayer
import AccountContext
import SwiftSignalKit
import TelegramCore
import CoreMedia

public protocol BatchVideoRenderingContextTarget: AnyObject {
    var batchVideoRenderingTargetState: BatchVideoRenderingContext.TargetState? { get set }
    
    func setSampleBuffer(sampleBuffer: CMSampleBuffer)
}

public final class BatchVideoRenderingContext {
    public typealias Target = BatchVideoRenderingContextTarget
    
    public final class TargetHandle {
        private weak var context: BatchVideoRenderingContext?
        private let id: Int
        
        init(context: BatchVideoRenderingContext, id: Int) {
            self.context = context
            self.id = id
        }
        
        deinit {
            self.context?.targetRemoved(id: self.id)
        }
    }
    
    public final class TargetState {
        var currentFrameExpirationTimestamp: Double?
        
        init() {
        }
    }
    
    private final class ReadingContext {
        let dataPath: String
        
        var isFailed: Bool = false
        var reader: FFMpegFileReader?
        
        init(dataPath: String) {
            self.dataPath = dataPath
        }
        
        func advance() -> CMSampleBuffer? {
            outer: while true {
                if self.isFailed {
                    break outer
                }
                if self.reader == nil {
                    let reader = FFMpegFileReader(
                        source: .file(self.dataPath),
                        useHardwareAcceleration: false,
                        selectedStream: .mediaType(.video),
                        seek: nil,
                        maxReadablePts: nil
                    )
                    if reader == nil {
                        self.isFailed = true
                        break outer
                    }
                    self.reader = reader
                }
                
                guard let reader = self.reader else {
                    break outer
                }
                
                switch reader.readFrame() {
                case let .frame(frame):
                    return createSampleBuffer(fromSampleBuffer: frame.sampleBuffer, withTimeOffset: .zero, duration: nil, displayImmediately: true)
                case .error:
                    self.isFailed = true
                    break outer
                case .endOfStream:
                    self.reader = nil
                case .waitingForMoreData:
                    self.isFailed = true
                    break outer
                }
            }
            return nil
        }
    }
    
    private final class TargetContext {
        weak var target: Target?
        let file: FileMediaReference
        let userLocation: MediaResourceUserLocation
        
        var readingContext: QueueLocalObject<ReadingContext>?
        var fetchDisposable: Disposable?
        var dataDisposable: Disposable?
        var dataPath: String?
        
        init(
            target: Target,
            file: FileMediaReference,
            userLocation: MediaResourceUserLocation
        ) {
            self.target = target
            self.file = file
            self.userLocation = userLocation
        }
        
        deinit {
            self.fetchDisposable?.dispose()
            self.dataDisposable?.dispose()
        }
    }
    
    private static let sharedQueue = Queue(name: "BatchVideoRenderingContext", qos: .default)
    
    private let context: AccountContext
    
    private var targetContexts: [Int: TargetContext] = [:]
    private var nextId: Int = 0
    
    private var isRendering: Bool = false
    private var displayLink: SharedDisplayLinkDriver.Link?
    
    public init(context: AccountContext) {
        self.context = context
    }
    
    public func add(target: Target, file: FileMediaReference, userLocation: MediaResourceUserLocation) -> TargetHandle {
        let id = self.nextId
        self.nextId += 1
        
        self.targetContexts[id] = TargetContext(
            target: target,
            file: file,
            userLocation: userLocation
        )
        self.update()
        
        return TargetHandle(context: self, id: id)
    }
    
    private func targetRemoved(id: Int) {
        if self.targetContexts.removeValue(forKey: id) != nil {
            self.update()
        }
    }
    
    private func update() {
        var removeIds: [Int] = []
        for (id, targetContext) in self.targetContexts {
            if targetContext.target != nil {
                if targetContext.fetchDisposable == nil {
                    targetContext.fetchDisposable = fetchedMediaResource(
                        mediaBox: self.context.account.postbox.mediaBox,
                        userLocation: targetContext.userLocation,
                        userContentType: .sticker,
                        reference: targetContext.file.resourceReference(targetContext.file.media.resource)
                    ).startStrict()
                }
                if targetContext.dataDisposable == nil {
                    targetContext.dataDisposable = (self.context.account.postbox.mediaBox.resourceData(targetContext.file.media.resource)
                    |> deliverOnMainQueue).startStrict(next: { [weak self, weak targetContext] data in
                        guard let self, let targetContext else {
                            return
                        }
                        if data.complete && targetContext.dataPath == nil {
                            targetContext.dataPath = data.path
                            self.update()
                        }
                    })
                }
                if targetContext.readingContext == nil, let dataPath = targetContext.dataPath {
                    targetContext.readingContext = QueueLocalObject(queue: BatchVideoRenderingContext.sharedQueue, generate: {
                        return ReadingContext(dataPath: dataPath)
                    })
                }
            } else {
                removeIds.append(id)
            }
        }
        for id in removeIds {
            self.targetContexts.removeValue(forKey: id)
        }
        
        if !self.targetContexts.isEmpty {
            if self.displayLink == nil {
                self.displayLink = SharedDisplayLinkDriver.shared.add { [weak self] _ in
                    guard let self else {
                        return
                    }
                    self.updateRendering()
                }
            }
        } else {
            self.displayLink = nil
        }
    }
    
    private func updateRendering() {
        if self.isRendering {
            return
        }
        
        let timestamp = CACurrentMediaTime()
        
        var removeIds: [Int] = []
        var renderIds: [Int] = []
        for (id, targetContext) in self.targetContexts {
            guard let target = targetContext.target else {
                removeIds.append(id)
                continue
            }
            let targetState: TargetState
            if let current = target.batchVideoRenderingTargetState {
                targetState = current
            } else {
                targetState = TargetState()
                target.batchVideoRenderingTargetState = targetState
            }
            
            if let currentFrameExpirationTimestamp = targetState.currentFrameExpirationTimestamp {
                if timestamp >= currentFrameExpirationTimestamp {
                    renderIds.append(id)
                }
            } else {
                renderIds.append(id)
            }
        }
        
        for id in removeIds {
            self.targetContexts.removeValue(forKey: id)
        }
        
        if !renderIds.isEmpty {
            self.isRendering = true
            
            var readingContexts: [Int: QueueLocalObject<ReadingContext>] = [:]
            for id in renderIds {
                guard let targetContext = self.targetContexts[id] else {
                    continue
                }
                if let readingContext = targetContext.readingContext {
                    readingContexts[id] = readingContext
                }
            }
            BatchVideoRenderingContext.sharedQueue.async { [weak self] in
                var sampleBuffers: [Int: CMSampleBuffer?] = [:]
                for (id, readingContext) in readingContexts {
                    guard let readingContext = readingContext.unsafeGet() else {
                        sampleBuffers[id] = nil
                        continue
                    }
                    if let sampleBuffer = readingContext.advance() {
                        sampleBuffers[id] = sampleBuffer
                    } else {
                        sampleBuffers[id] = nil
                    }
                }
                
                Queue.mainQueue().async {
                    guard let self else {
                        return
                    }
                    self.isRendering = false
                    
                    for (id, sampleBuffer) in sampleBuffers {
                        guard let targetContext = self.targetContexts[id], let target = targetContext.target, let targetState = target.batchVideoRenderingTargetState else {
                            return
                        }
                        if let sampleBuffer {
                            target.setSampleBuffer(sampleBuffer: sampleBuffer)
                            if let targetState = target.batchVideoRenderingTargetState {
                                targetState.currentFrameExpirationTimestamp = CACurrentMediaTime() + CMSampleBufferGetDuration(sampleBuffer).seconds
                            }
                        } else {
                            targetState.currentFrameExpirationTimestamp = CACurrentMediaTime() + 1.0 / 30.0
                        }
                    }
                }
            }
        }
        
        if !self.targetContexts.isEmpty {
            if self.displayLink == nil {
                self.displayLink = SharedDisplayLinkDriver.shared.add { [weak self] _ in
                    guard let self else {
                        return
                    }
                    self.updateRendering()
                }
            }
        } else {
            self.displayLink = nil
        }
    }
}

private func createSampleBuffer(fromSampleBuffer sampleBuffer: CMSampleBuffer, withTimeOffset timeOffset: CMTime, duration: CMTime?, displayImmediately: Bool) -> CMSampleBuffer? {
    var itemCount: CMItemCount = 0
    var status = CMSampleBufferGetSampleTimingInfoArray(sampleBuffer, entryCount: 0, arrayToFill: nil, entriesNeededOut: &itemCount)
    if status != 0 {
        return nil
    }
    
    var timingInfo = [CMSampleTimingInfo](repeating: CMSampleTimingInfo(duration: CMTimeMake(value: 0, timescale: 0), presentationTimeStamp: CMTimeMake(value: 0, timescale: 0), decodeTimeStamp: CMTimeMake(value: 0, timescale: 0)), count: itemCount)
    status = CMSampleBufferGetSampleTimingInfoArray(sampleBuffer, entryCount: itemCount, arrayToFill: &timingInfo, entriesNeededOut: &itemCount)
    if status != 0 {
        return nil
    }
    
    if let dur = duration {
        for i in 0 ..< itemCount {
            timingInfo[i].decodeTimeStamp = CMTimeAdd(timingInfo[i].decodeTimeStamp, timeOffset)
            timingInfo[i].presentationTimeStamp = CMTimeAdd(timingInfo[i].presentationTimeStamp, timeOffset)
            timingInfo[i].duration = dur
        }
    } else {
        for i in 0 ..< itemCount {
            timingInfo[i].decodeTimeStamp = CMTimeAdd(timingInfo[i].decodeTimeStamp, timeOffset)
            timingInfo[i].presentationTimeStamp = CMTimeAdd(timingInfo[i].presentationTimeStamp, timeOffset)
        }
    }
    
    var sampleBufferOffset: CMSampleBuffer?
    CMSampleBufferCreateCopyWithNewTiming(allocator: kCFAllocatorDefault, sampleBuffer: sampleBuffer, sampleTimingEntryCount: itemCount, sampleTimingArray: &timingInfo, sampleBufferOut: &sampleBufferOffset)
    guard let sampleBufferOffset else {
        return nil
    }
    
    if displayImmediately {
        let attachments: NSArray = CMSampleBufferGetSampleAttachmentsArray(sampleBufferOffset, createIfNecessary: true)! as NSArray
        let dict: NSMutableDictionary = attachments[0] as! NSMutableDictionary
        dict[kCMSampleAttachmentKey_DisplayImmediately as NSString] = true as NSNumber
    }
    
    return sampleBufferOffset
}
