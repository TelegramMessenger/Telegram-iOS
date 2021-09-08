import Foundation
import SwiftSignalKit
import Postbox
import TelegramCore

private final class ThreadTaskQueue: NSObject {
    private var mutex: pthread_mutex_t
    private var condition: pthread_cond_t
    private var tasks: [() -> Void] = []
    private var shouldExit = false
    
    override init() {
        self.mutex = pthread_mutex_t()
        self.condition = pthread_cond_t()
        pthread_mutex_init(&self.mutex, nil)
        pthread_cond_init(&self.condition, nil)
        
        super.init()
    }
    
    deinit {
        pthread_mutex_destroy(&self.mutex)
        pthread_cond_destroy(&self.condition)
    }
    
    func loop() {
        while !self.shouldExit {
            pthread_mutex_lock(&self.mutex)
            
            if tasks.isEmpty {
                pthread_cond_wait(&self.condition, &self.mutex)
            }
            
            var task: (() -> Void)?
            if !self.tasks.isEmpty {
                task = self.tasks.removeFirst()
            }
            
            pthread_mutex_unlock(&self.mutex)
            
            if let task = task {
                autoreleasepool {
                    task()
                }
            }
        }
    }
    
    func enqueue(_ task: @escaping () -> Void) {
        pthread_mutex_lock(&self.mutex)
        self.tasks.append(task)
        pthread_cond_broadcast(&self.condition)
        pthread_mutex_unlock(&self.mutex)
    }
    
    func terminate() {
        pthread_mutex_lock(&self.mutex)
        self.shouldExit = true
        pthread_cond_broadcast(&self.condition)
        pthread_mutex_unlock(&self.mutex)
    }
}

private func contextForCurrentThread() -> FFMpegMediaFrameSourceContext? {
    return Thread.current.threadDictionary["FFMpegMediaFrameSourceContext"] as? FFMpegMediaFrameSourceContext
}

public final class FFMpegMediaFrameSource: NSObject, MediaFrameSource {
    private let queue: Queue
    private let postbox: Postbox
    private let resourceReference: MediaResourceReference
    private let tempFilePath: String?
    private let streamable: Bool
    private let stallDuration: Double
    private let lowWaterDuration: Double
    private let highWaterDuration: Double
    private let video: Bool
    private let preferSoftwareDecoding: Bool
    private let fetchAutomatically: Bool
    private let maximumFetchSize: Int?
    
    private let taskQueue: ThreadTaskQueue
    private let thread: Thread
    
    private let eventSinkBag = Bag<(MediaTrackEvent) -> Void>()
    private var generatingFrames = false
    private var requestedFrameGenerationTimestamp: Double?
    
    @objc private static func threadEntry(_ taskQueue: ThreadTaskQueue) {
        autoreleasepool {
            let context = FFMpegMediaFrameSourceContext(thread: Thread.current)
            let localStorage = Thread.current.threadDictionary
            localStorage["FFMpegMediaFrameSourceContext"] = context

            taskQueue.loop()
            
            Thread.current.threadDictionary.removeObject(forKey: "FFMpegMediaFrameSourceContext")
        }
    }
   
    public init(queue: Queue, postbox: Postbox, resourceReference: MediaResourceReference, tempFilePath: String?, streamable: Bool, video: Bool, preferSoftwareDecoding: Bool, fetchAutomatically: Bool, maximumFetchSize: Int? = nil, stallDuration: Double = 1.0, lowWaterDuration: Double = 2.0, highWaterDuration: Double = 3.0) {
        self.queue = queue
        self.postbox = postbox
        self.resourceReference = resourceReference
        self.tempFilePath = tempFilePath
        self.streamable = streamable
        self.video = video
        self.preferSoftwareDecoding = preferSoftwareDecoding
        self.fetchAutomatically = fetchAutomatically
        self.maximumFetchSize = maximumFetchSize
        self.stallDuration = stallDuration
        self.lowWaterDuration = lowWaterDuration
        self.highWaterDuration = highWaterDuration
        
        self.taskQueue = ThreadTaskQueue()
        
        self.thread = Thread(target: FFMpegMediaFrameSource.self, selector: #selector(FFMpegMediaFrameSource.threadEntry(_:)), object: taskQueue)
        self.thread.name = "FFMpegMediaFrameSourceContext"
        self.thread.start()
        
        super.init()
    }
    
    deinit {
        assert(self.queue.isCurrent())
        
        self.taskQueue.terminate()
    }
    
    public func addEventSink(_ f: @escaping (MediaTrackEvent) -> Void) -> Int {
        assert(self.queue.isCurrent())
        
        return self.eventSinkBag.add(f)
    }
    
    public func removeEventSink(_ index: Int) {
        assert(self.queue.isCurrent())
        
        self.eventSinkBag.remove(index)
    }
    
    public func generateFrames(until timestamp: Double) {
        assert(self.queue.isCurrent())
        
        if self.requestedFrameGenerationTimestamp == nil || !self.requestedFrameGenerationTimestamp!.isEqual(to: timestamp) {
            self.requestedFrameGenerationTimestamp = timestamp
            
            self.internalGenerateFrames(until: timestamp)
        }
    }
    
    public func ensureHasFrames(until timestamp: Double) -> Signal<Never, NoError> {
        assert(self.queue.isCurrent())
        
        return Signal { subscriber in
            let disposable = MetaDisposable()
            let currentSemaphore = Atomic<Atomic<DispatchSemaphore?>?>(value: nil)
            
            disposable.set(ActionDisposable {
                currentSemaphore.with({ $0 })?.with({ $0 })?.signal()
            })
            self.performWithContext({ context in
                let _ = currentSemaphore.swap(context.currentSemaphore)
                let _ = context.takeFrames(until: timestamp)
                subscriber.putCompletion()
            })
            return disposable
        }
        |> runOn(self.queue)
    }
    
    private func internalGenerateFrames(until timestamp: Double) {
        if self.generatingFrames {
            return
        }
        
        self.generatingFrames = true
        
        let postbox = self.postbox
        let resourceReference = self.resourceReference
        let tempFilePath = self.tempFilePath
        let queue = self.queue
        let streamable = self.streamable
        let video = self.video
        let preferSoftwareDecoding = self.preferSoftwareDecoding
        let fetchAutomatically = self.fetchAutomatically
        let maximumFetchSize = self.maximumFetchSize
        
        self.performWithContext { [weak self] context in
            context.initializeState(postbox: postbox, resourceReference: resourceReference, tempFilePath: tempFilePath, streamable: streamable, video: video, preferSoftwareDecoding: preferSoftwareDecoding, fetchAutomatically: fetchAutomatically, maximumFetchSize: maximumFetchSize)
            
            let (frames, endOfStream) = context.takeFrames(until: timestamp)
            
            queue.async { [weak self] in
                if let strongSelf = self {
                    strongSelf.generatingFrames = false
                    
                    for sink in strongSelf.eventSinkBag.copyItems() {
                        sink(.frames(frames))
                        if endOfStream {
                            sink(.endOfStream)
                        }
                    }
                    
                    if strongSelf.requestedFrameGenerationTimestamp != nil && !strongSelf.requestedFrameGenerationTimestamp!.isEqual(to: timestamp) {
                        strongSelf.internalGenerateFrames(until: strongSelf.requestedFrameGenerationTimestamp!)
                    }
                }
            }
        }
    }
    
    func performWithContext(_ f: @escaping (FFMpegMediaFrameSourceContext) -> Void) {
        assert(self.queue.isCurrent())
        
        taskQueue.enqueue {
            if let context = contextForCurrentThread() {
                f(context)
            }
        }
    }
    
    public func seek(timestamp: Double) -> Signal<QueueLocalObject<MediaFrameSourceSeekResult>, MediaFrameSourceSeekError> {
        assert(self.queue.isCurrent())
        
        return Signal { subscriber in
            let disposable = MetaDisposable()
            
            let queue = self.queue
            let postbox = self.postbox
            let resourceReference = self.resourceReference
            let tempFilePath = self.tempFilePath
            let streamable = self.streamable
            let video = self.video
            let preferSoftwareDecoding = self.preferSoftwareDecoding
            let fetchAutomatically = self.fetchAutomatically
            let maximumFetchSize = self.maximumFetchSize
            
            let currentSemaphore = Atomic<Atomic<DispatchSemaphore?>?>(value: nil)
            
            disposable.set(ActionDisposable {
                currentSemaphore.with({ $0 })?.with({ $0 })?.signal()
            })
            
            self.performWithContext { [weak self] context in
                let _ = currentSemaphore.swap(context.currentSemaphore)
                
                context.initializeState(postbox: postbox, resourceReference: resourceReference, tempFilePath: tempFilePath, streamable: streamable, video: video, preferSoftwareDecoding: preferSoftwareDecoding, fetchAutomatically: fetchAutomatically, maximumFetchSize: maximumFetchSize)
                
                context.seek(timestamp: timestamp, completed: { streamDescriptionsAndTimestamp in
                    queue.async {
                        if let strongSelf = self {
                            if let (streamDescriptions, timestamp) = streamDescriptionsAndTimestamp {
                                strongSelf.requestedFrameGenerationTimestamp = nil
                                subscriber.putNext(QueueLocalObject(queue: queue, generate: {
                                    if let strongSelf = self {
                                        var audioBuffer: MediaTrackFrameBuffer?
                                        var videoBuffer: MediaTrackFrameBuffer?
                                        
                                        if let audio = streamDescriptions.audio {
                                            audioBuffer = MediaTrackFrameBuffer(frameSource: strongSelf, decoder: audio.decoder, type: .audio, duration: audio.duration, rotationAngle: 0.0, aspect: 1.0, stallDuration: strongSelf.stallDuration, lowWaterDuration: strongSelf.lowWaterDuration, highWaterDuration: strongSelf.highWaterDuration)
                                        }
                                        
                                        var extraDecodedVideoFrames: [MediaTrackFrame] = []
                                        if let video = streamDescriptions.video {
                                            videoBuffer = MediaTrackFrameBuffer(frameSource: strongSelf, decoder: video.decoder, type: .video, duration: video.duration, rotationAngle: video.rotationAngle, aspect: video.aspect, stallDuration: strongSelf.stallDuration, lowWaterDuration: strongSelf.lowWaterDuration, highWaterDuration: strongSelf.highWaterDuration)
                                            for videoFrame in streamDescriptions.extraVideoFrames {
                                                if let decodedFrame = video.decoder.decode(frame: videoFrame) {
                                                    extraDecodedVideoFrames.append(decodedFrame)
                                                }
                                            }
                                        }
                                        
                                        return MediaFrameSourceSeekResult(buffers: MediaPlaybackBuffers(audioBuffer: audioBuffer, videoBuffer: videoBuffer), extraDecodedVideoFrames: extraDecodedVideoFrames, timestamp: timestamp)
                                    } else {
                                        return MediaFrameSourceSeekResult(buffers: MediaPlaybackBuffers(audioBuffer: nil, videoBuffer: nil), extraDecodedVideoFrames: [], timestamp: timestamp)
                                    }
                                }))
                                let _ = currentSemaphore.swap(nil)
                                subscriber.putCompletion()
                            } else {
                                let _ = currentSemaphore.swap(nil)
                                subscriber.putError(.generic)
                            }
                        } else {
                            let _ = currentSemaphore.swap(nil)
                            subscriber.putError(.generic)
                        }
                    }
                })
            }
            
            return disposable
        }
    }
}
