import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif

#if os(macOS)
    private typealias SignalKitTimer = SwiftSignalKitMac.Timer
#else
    private typealias SignalKitTimer = SwiftSignalKit.Timer
#endif

private final class MultipartFetchManager {
    let parallelParts: Int
    let defaultPartSize = 128 * 1024
    
    let queue = Queue()
    
    var committedOffset: Int
    let range: Range<Int>
    var completeSize: Int?
    let fetchPart: (Int, Int) -> Signal<Data, NoError>
    let partReady: (Data) -> Void
    let completed: () -> Void
    
    var fetchingParts: [Int: (Int, Disposable)] = [:]
    var fetchedParts: [Int: Data] = [:]
    
    var statsTimer: SignalKitTimer?
    var receivedSize = 0
    var lastStatReport: (timestamp: Double, receivedSize: Int)?
    
    init(size: Int?, range: Range<Int>, fetchPart: @escaping (Int, Int) -> Signal<Data, NoError>, partReady: @escaping (Data) -> Void, completed: @escaping () -> Void) {
        self.completeSize = size
        if let size = size {
            self.range = range.lowerBound ..< min(range.upperBound, size)
            self.parallelParts = 4
        } else {
            self.range = range
            self.parallelParts = 1
        }
        self.committedOffset = range.lowerBound
        self.fetchPart = fetchPart
        self.partReady = partReady
        self.completed = completed
        
        self.statsTimer = SignalKitTimer(timeout: 3.0, repeat: true, completion: { [weak self] in
            self?.reportStats()
        }, queue: self.queue)
    }
    
    deinit {
        let statsTimer = self.statsTimer
        self.queue.async {
            statsTimer?.invalidate()
        }
    }
    
    func start() {
        self.queue.async {
            self.checkState()
            
            self.lastStatReport = (CACurrentMediaTime(), self.receivedSize)
            self.statsTimer?.start()
        }
    }
    
    func cancel() {
        self.queue.async {
            for (_, (_, disposable)) in self.fetchingParts {
                disposable.dispose()
            }
            self.statsTimer?.invalidate()
        }
    }
    
    func checkState() {
        for offset in self.fetchedParts.keys.sorted() {
            if offset == self.committedOffset {
                let data = self.fetchedParts[offset]!
                self.committedOffset += data.count
                let _ = self.fetchedParts.removeValue(forKey: offset)
                self.partReady(data)
            }
        }
        
        if let completeSize = self.completeSize, self.committedOffset >= completeSize {
            self.completed()
        } else if self.committedOffset >= self.range.upperBound {
            self.completed()
        } else {
            while fetchingParts.count < self.parallelParts {
                var nextOffset = self.committedOffset
                for (offset, (size, _)) in self.fetchingParts {
                    nextOffset = max(nextOffset, offset + size)
                }
                for (offset, data) in self.fetchedParts {
                    nextOffset = max(nextOffset, offset + data.count)
                }
                
                if nextOffset < self.range.upperBound {
                    let partSize = min(self.range.upperBound - nextOffset, self.defaultPartSize)
                    let part = self.fetchPart(nextOffset, partSize)
                        |> deliverOn(self.queue)
                    let partOffset = nextOffset
                    self.fetchingParts[nextOffset] = (partSize, part.start(next: { [weak self] data in
                        if let strongSelf = self {
                            var data = data
                            if data.count > partSize {
                                data = data.subdata(in: 0 ..< partSize)
                            }
                            strongSelf.receivedSize += data.count
                            if let completeSize = strongSelf.completeSize {
                                assert(data.count == partSize)
                            } else if data.count < partSize {
                                strongSelf.completeSize = partOffset + data.count
                            }
                            let _ = strongSelf.fetchingParts.removeValue(forKey: partOffset)
                            strongSelf.fetchedParts[partOffset] = data
                            strongSelf.checkState()
                        }
                    }))
                } else {
                    break
                }
            }
        }
    }
    
    func reportStats() {
        if let lastStatReport = self.lastStatReport {
            let downloadSpeed = Double(self.receivedSize - lastStatReport.receivedSize) / (CACurrentMediaTime() - lastStatReport.timestamp)
            print("MultipartFetch speed \(downloadSpeed / 1024) KB/s")
        }
        self.lastStatReport = (CACurrentMediaTime(), self.receivedSize)
    }
}

func multipartFetch(account: Account, resource: TelegramCloudMediaResource, size: Int?, range: Range<Int>) -> Signal<MediaResourceDataFetchResult, NoError> {
    return account.network.download(datacenterId: resource.datacenterId)
        |> mapToSignal { download -> Signal<MediaResourceDataFetchResult, NoError> in
            return Signal { subscriber in
                let inputLocation = resource.apiInputLocation
                let manager = MultipartFetchManager(size: size, range: range, fetchPart: { offset, size in
                    return download.part(location: inputLocation, offset: offset, length: size)
                }, partReady: { data in
                    subscriber.putNext(MediaResourceDataFetchResult(data: data, complete: false))
                }, completed: {
                    subscriber.putNext(MediaResourceDataFetchResult(data: Data(), complete: true))
                    subscriber.putCompletion()
                })
                
                manager.start()
                
                return ActionDisposable {
                    manager.cancel()
                }
            }
        }
}
