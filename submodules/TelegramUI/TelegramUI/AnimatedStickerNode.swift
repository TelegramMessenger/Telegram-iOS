import Foundation
import SwiftSignalKit
import Postbox
import TelegramCore
import Compression
import Display
import AsyncDisplayKit

private final class AnimationFrameCache {
    private var cache: [Int: NSPurgeableData] = [:]
    
    func get(index: Int, _ f: (NSPurgeableData?) -> Void) {
        guard let data = self.cache[index] else {
            f(nil)
            return
        }
        if data.beginContentAccess() {
            f(data)
            data.endContentAccess()
        } else {
            self.cache.removeValue(forKey: index)
            f(nil)
        }
    }
    
    func set(index: Int, bytes: UnsafeRawPointer, length: Int) {
        let data = NSPurgeableData(bytes: bytes, length: length)
        data.endContentAccess()
        self.cache[index] = data
    }
    
    func removeAll() {
        self.cache.removeAll()
    }
}

private let sharedQueue = Queue()

private class AnimatedStickerNodeDisplayEvents: ASDisplayNode {
    private var value: Bool = false
    var updated: ((Bool) -> Void)?
    
    override init() {
        super.init()
        
        self.isLayerBacked = true
    }
    
    override func didEnterHierarchy() {
        super.didEnterHierarchy()
        
        if !self.value {
            self.value = true
            self.updated?(true)
        }
    }
    
    override func didExitHierarchy() {
        super.didExitHierarchy()
        
        if self.value {
            self.value = false
            self.updated?(false)
        }
    }
}

final class AnimatedStickerNode: ASDisplayNode {
    private let queue: Queue
    private var account: Account?
    private var fileReference: FileMediaReference?
    private let disposable = MetaDisposable()
    private let fetchDisposable = MetaDisposable()
    private let eventsNode: AnimatedStickerNodeDisplayEvents
    
    var started: () -> Void = {}
    var reportedStarted = false
    
    private let timer = Atomic<SwiftSignalKit.Timer?>(value: nil)
    
    private var data: Data?
    
    private var renderer: (AnimationRenderer & ASDisplayNode)?
    
    private var isPlaying: Bool = false
    
    var visibility = false {
        didSet {
            if self.visibility != oldValue {
                self.updateIsPlaying()
            }
        }
    }
    
    private var isDisplaying = false {
        didSet {
            if self.isDisplaying != oldValue {
                self.updateIsPlaying()
            }
        }
    }
    
    override init() {
        self.queue = sharedQueue
        self.eventsNode = AnimatedStickerNodeDisplayEvents()
        
        super.init()
        
        self.eventsNode.updated = { [weak self] value in
            guard let strongSelf = self else {
                return
            }
            strongSelf.isDisplaying = value
        }
        self.addSubnode(self.eventsNode)
    }
    
    deinit {
        self.disposable.dispose()
        self.fetchDisposable.dispose()
        self.timer.swap(nil)?.invalidate()
    }
    
    override func didLoad() {
        super.didLoad()
        
        #if targetEnvironment(simulator)
        self.renderer = SoftwareAnimationRenderer()
        #else
        self.renderer = SoftwareAnimationRenderer()
        //self.renderer = MetalAnimationRenderer()
        #endif
        self.renderer?.frame = CGRect(origin: CGPoint(), size: self.bounds.size)
        self.addSubnode(self.renderer!)
    }
    
    func setup(account: Account, fileReference: FileMediaReference, width: Int, height: Int) {
        self.disposable.set(chatMessageAnimationData(postbox: account.postbox, fileReference: fileReference, width: width, height: height, synchronousLoad: false).start(next: { [weak self] data in
            if let strongSelf = self, data.complete {
                strongSelf.data = try? Data(contentsOf: URL(fileURLWithPath: data.path), options: [.mappedRead])
                if strongSelf.isPlaying {
                    strongSelf.play()
                }
            }
        }))
        self.fetchDisposable.set(fetchedMediaResource(postbox: account.postbox, reference: fileReference.resourceReference(fileReference.media.resource)).start())
    }
    
    func reset() {
        self.disposable.set(nil)
        self.fetchDisposable.set(nil)
    }
    
    private func updateIsPlaying() {
        let isPlaying = self.visibility && self.isDisplaying
        if self.isPlaying != isPlaying {
            self.isPlaying = isPlaying
            if isPlaying {
                self.play()
            } else{
                self.stop()
            }
        }
    }
    
    func play() {
        guard let data = self.data else {
            return
        }
        let queue = self.queue
        let timerHolder = self.timer
        self.queue.async { [weak self] in
            if #available(iOS 9.0, *) {
                let dataCount = data.count
                timerHolder.swap(nil)?.invalidate()
                var scratchBuffer = Data(count: compression_decode_scratch_buffer_size(COMPRESSION_LZ4))
                
                var offset = 0
                var width = 0
                var height = 0
                
                var fps: Int32 = 0
                data.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) -> Void in
                    memcpy(&fps, bytes.advanced(by: offset), 4)
                    offset += 4
                    var widthValue: Int32 = 0
                    var heightValue: Int32 = 0
                    memcpy(&widthValue, bytes.advanced(by: offset), 4)
                    offset += 4
                    memcpy(&heightValue, bytes.advanced(by: offset), 4)
                    offset += 4
                    width = Int(widthValue)
                    height = Int(heightValue)
                }
                
                let initialOffset = offset
                
                var decodeBuffer = Data(count: width * 4 * height)
                var frameBuffer = Data(count: width * 4 * height)
                let decodeBufferLength = decodeBuffer.count
                frameBuffer.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<UInt8>) -> Void in
                    memset(bytes, 0, decodeBufferLength)
                }
                
                var frameIndex = 0
                let timer = SwiftSignalKit.Timer(timeout: 1.0 / Double(fps), repeat: true, completion: {
                    data.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) -> Void in
                        var frameLength: Int32 = 0
                        memcpy(&frameLength, bytes.advanced(by: offset), 4)
                        
                        scratchBuffer.withUnsafeMutableBytes { (scratchBytes: UnsafeMutablePointer<UInt8>) -> Void in
                            decodeBuffer.withUnsafeMutableBytes { (decodeBytes: UnsafeMutablePointer<UInt8>) -> Void in
                                frameBuffer.withUnsafeMutableBytes { (frameBytes: UnsafeMutablePointer<UInt8>) -> Void in
                                    compression_decode_buffer(decodeBytes, decodeBufferLength, bytes.advanced(by: offset + 4), Int(frameLength), UnsafeMutableRawPointer(scratchBytes), COMPRESSION_LZ4)
                                    
                                    var lhs = UnsafeMutableRawPointer(frameBytes).assumingMemoryBound(to: UInt64.self)
                                    var rhs = UnsafeRawPointer(decodeBytes).assumingMemoryBound(to: UInt64.self)
                                    for _ in 0 ..< decodeBufferLength / 8 {
                                        lhs.pointee = lhs.pointee ^ rhs.pointee
                                        lhs = lhs.advanced(by: 1)
                                        rhs = rhs.advanced(by: 1)
                                    }
                                    
                                    let frameData = Data(bytes: frameBytes, count: decodeBufferLength)
                                    
                                    Queue.mainQueue().async {
                                        guard let strongSelf = self else {
                                            return
                                        }
                                        strongSelf.renderer?.render(queue: strongSelf.queue, width: width, height: height, data: frameData, completion: {
                                            guard let strongSelf = self else {
                                                return
                                            }
                                            if !strongSelf.reportedStarted {
                                                strongSelf.started()
                                            }
                                        })
                                    }
                                }
                            }
                        }
                        
                        offset += 4 + Int(frameLength)
                        frameIndex += 1
                        if offset == dataCount {
                            offset = initialOffset
                            frameIndex = 0
                            frameBuffer.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<UInt8>) -> Void in
                                memset(bytes, 0, decodeBufferLength)
                            }
                        }
                    }
                }, queue: queue)
                let _ = timerHolder.swap(timer)
                timer.start()
            }
        }
    }
    
    func stop() {
        self.reportedStarted = false
        self.timer.swap(nil)?.invalidate()
    }
    
    func updateLayout(size: CGSize) {
        self.renderer?.frame = CGRect(origin: CGPoint(), size: size)
    }
}
