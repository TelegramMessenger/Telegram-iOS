import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
    import MtProtoKitMac
#else
    import Postbox
    import SwiftSignalKit
    import MtProtoKitDynamic
#endif

#if os(macOS)
    private typealias SignalKitTimer = SwiftSignalKitMac.Timer
#else
    private typealias SignalKitTimer = SwiftSignalKit.Timer
#endif

private final class MultipartDownloadState {
    let aesKey: Data
    var aesIv: Data
    let decryptedSize: Int32?
    
    var currentSize: Int32 = 0
    
    init(encryptionKey: SecretFileEncryptionKey?, decryptedSize: Int32?) {
        if let encryptionKey = encryptionKey {
            self.aesKey = encryptionKey.aesKey
            self.aesIv = encryptionKey.aesIv
        } else {
            self.aesKey = Data()
            self.aesIv = Data()
        }
        self.decryptedSize = decryptedSize
    }
    
    func transform(data: Data) -> Data {
        if self.aesKey.count != 0 {
            var decryptedData = data
            assert(decryptedSize != nil)
            assert(decryptedData.count % 16 == 0)
            decryptedData.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<UInt8>) -> Void in
                self.aesIv.withUnsafeMutableBytes { (iv: UnsafeMutablePointer<UInt8>) -> Void in
                    MTAesDecryptBytesInplaceAndModifyIv(bytes, decryptedData.count, self.aesKey, iv)
                }
            }
            if currentSize + decryptedData.count > self.decryptedSize! {
                decryptedData.count = self.decryptedSize! - currentSize
            }
            currentSize += decryptedData.count
            return decryptedData
        } else {
            return data
        }
    }
}

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
    
    var state: MultipartDownloadState
    
    init(size: Int?, range: Range<Int>, encryptionKey: SecretFileEncryptionKey?, decryptedSize: Int32?, fetchPart: @escaping (Int, Int) -> Signal<Data, NoError>, partReady: @escaping (Data) -> Void, completed: @escaping () -> Void) {
        self.completeSize = size
        if let size = size {
            if size <= range.lowerBound {
                //assertionFailure()
                self.range = range
                self.parallelParts = 0
            } else {
                self.range = range.lowerBound ..< min(range.upperBound, size)
                self.parallelParts = 4
            }
        } else {
            self.range = range
            self.parallelParts = 1
        }
        self.state = MultipartDownloadState(encryptionKey: encryptionKey, decryptedSize: decryptedSize)
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
                self.partReady(self.state.transform(data: data))
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
                            if let _ = strongSelf.completeSize {
                                if data.count != partSize {
                                    assertionFailure()
                                    return
                                }
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

func multipartFetch(account: Account, resource: TelegramMultipartFetchableResource, size: Int?, range: Range<Int>, tag: MediaResourceFetchTag?, encryptionKey: SecretFileEncryptionKey? = nil, decryptedSize: Int32? = nil) -> Signal<MediaResourceDataFetchResult, NoError> {
    return account.network.download(datacenterId: resource.datacenterId, tag: tag)
        |> mapToSignal { download -> Signal<MediaResourceDataFetchResult, NoError> in
            return Signal { subscriber in
                
                let manager = MultipartFetchManager(size: size, range: range, encryptionKey: encryptionKey, decryptedSize: decryptedSize, fetchPart: { offset, size in
                    if let resource = resource as? TelegramCloudMediaResource {
                        return download.part(location: resource.apiInputLocation, offset: offset, length: size)
                    } else if let resource = resource as? WebFileReferenceMediaResource {
                        return download.webFilePart(location: resource.apiInputLocation, offset: offset, length: size)
                    } else {
                        fatalError("multipart fetch allos only TelegramCloudMediaResource and WebFileReferenceMediaResource")
                    }
                }, partReady: { data in
                    subscriber.putNext(.dataPart(data: data, range: 0 ..< data.count, complete: false))
                }, completed: {
                    subscriber.putNext(.dataPart(data: Data(), range: 0 ..< 0, complete: true))
                    subscriber.putCompletion()
                })
                
                manager.start()
                
                return ActionDisposable {
                    manager.cancel()
                }
            }
        }
}
