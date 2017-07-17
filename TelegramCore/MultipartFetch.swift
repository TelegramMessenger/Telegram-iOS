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
            if self.currentSize + Int32(decryptedData.count) > self.decryptedSize! {
                decryptedData.count = Int(self.decryptedSize! - self.currentSize)
            }
            self.currentSize += Int32(decryptedData.count)
            return decryptedData
        } else {
            return data
        }
    }
}

private enum MultipartFetchDownloadError {
    case generic
    case switchToCdn(id: Int32, token: Data, key: Data, iv: Data, partHashes: [Int32: Data])
    case reuploadToCdn(masterDatacenterId: Int32, token: Data)
    case hashesMissing
}

private enum MultipartFetchMasterLocation {
    case generic(Int32, Api.InputFileLocation)
    case web(Int32, Api.InputWebFileLocation)
    
    var datacenterId: Int32 {
        switch self {
            case let .generic(id, _):
                return id
            case let .web(id, _):
                return id
        }
    }
}

private final class DownloadWrapper {
    private let id: Int32
    private let cdn: Bool
    private let take: (Int32, Bool) -> Signal<Download, NoError>
    private let value = Atomic<Promise<Download>?>(value: nil)
    
    init(id: Int32, cdn: Bool, take: @escaping (Int32, Bool) -> Signal<Download, NoError>) {
        self.id = id
        self.cdn = cdn
        self.take = take
    }
    
    func get() -> Signal<Download, NoError> {
        return Signal { subscriber in
            var initialize = false
            let result = self.value.modify { current in
                if let current = current {
                    return current
                } else {
                    let value = Promise<Download>()
                    initialize = true
                    return value
                }
            }
            if let result = result {
                if initialize {
                    result.set(self.take(self.id, self.cdn))
                }
                return result.get().start(next: { next in
                    subscriber.putNext(next)
                    subscriber.putCompletion()
                })
            } else {
                return EmptyDisposable
            }
        }
    }
}

private func roundUp(_ value: Int, to multiple: Int) -> Int {
    if multiple == 0 {
        return value
    }
    
    let remainder = value % multiple
    if remainder == 0 {
        return value
    }
    
    return value + multiple - remainder
}

private let dataHashLength: Int32 = 128 * 1024

private final class MultipartCdnHashSource {
    private let queue: Queue
    
    private let fileToken: Data
    private let masterDownload: DownloadWrapper
    
    private var knownUpperBound: Int32
    private var hashes: [Int32: Data]
    private var requestOffsetAndDisposable: (Int32, Disposable)?
    private var requestedUpperBound: Int32?
    
    private var subscribers = Bag<(Int32, Int32, ([Int32: Data]) -> Void)>()
    
    init(queue: Queue, fileToken: Data, hashes: [Int32: Data], masterDownload: DownloadWrapper) {
        assert(queue.isCurrent())
        
        self.queue = queue
        self.fileToken = fileToken
        self.masterDownload = masterDownload
        
        self.hashes = hashes
        var knownUpperBound: Int32 = 0
        /*for (offset, _) in hashes {
            assert(offset % dataHashLength == 0)
            knownUpperBound = max(knownUpperBound, offset + dataHashLength)
        }*/
        self.knownUpperBound = knownUpperBound
    }
    
    deinit {
        assert(self.queue.isCurrent())
        
        self.requestOffsetAndDisposable?.1.dispose()
    }
    
    private func take(offset: Int32, limit: Int32) -> [Int32: Data]? {
        assert(offset % dataHashLength == 0)
        assert(limit % dataHashLength == 0)
        
        var result: [Int32: Data] = [:]
        
        var localOffset: Int32 = 0
        while localOffset < limit {
            if let hash = self.hashes[offset + localOffset] {
                result[offset + localOffset] = hash
            } else {
                return nil
            }
            localOffset += dataHashLength
        }
        
        return result
    }
    
    func get(offset: Int32, limit: Int32) -> Signal<[Int32: Data], MultipartFetchDownloadError> {
        assert(self.queue.isCurrent())
        
        let queue = self.queue
        return Signal { [weak self] subscriber in
            let disposable = MetaDisposable()
            
            queue.async {
                if let strongSelf = self {
                    if let result = strongSelf.take(offset: offset, limit: limit) {
                        subscriber.putNext(result)
                        subscriber.putCompletion()
                    } else {
                        let index = strongSelf.subscribers.add((offset, limit, { result in
                            subscriber.putNext(result)
                            subscriber.putCompletion()
                        }))
                        
                        disposable.set(ActionDisposable {
                            queue.async {
                                if let strongSelf = self {
                                    strongSelf.subscribers.remove(index)
                                }
                            }
                        })
                        
                        if let requestedUpperBound = strongSelf.requestedUpperBound {
                            strongSelf.requestedUpperBound = max(requestedUpperBound, offset + limit)
                        } else {
                            strongSelf.requestedUpperBound = offset + limit
                        }
                        
                        if strongSelf.requestOffsetAndDisposable == nil {
                            strongSelf.requestMore()
                        } else {
                            if let requestedUpperBound = strongSelf.requestedUpperBound {
                                strongSelf.requestedUpperBound = max(requestedUpperBound, offset + limit)
                            } else {
                                strongSelf.requestedUpperBound = offset + limit
                            }
                        }
                    }
                }
            }
            
            return disposable
        }
    }
    
    private func requestMore() {
        assert(self.queue.isCurrent())
        
        let requestOffset = self.knownUpperBound
        let disposable = MetaDisposable()
        self.requestOffsetAndDisposable = (requestOffset, disposable)
        let queue = self.queue
        let fileToken = self.fileToken
        disposable.set((self.masterDownload.get() |> mapToSignal { download -> Signal<[Int32: Data], NoError> in
            return download.request(Api.functions.upload.getCdnFileHashes(fileToken: Buffer(data: fileToken), offset: requestOffset))
                |> map { partHashes -> [Int32: Data] in
                    var parsedPartHashes: [Int32: Data] = [:]
                    for part in partHashes {
                        switch part {
                        case let .cdnFileHash(offset, limit, bytes):
                            assert(limit == 128 * 1024)
                            parsedPartHashes[offset] = bytes.makeData()
                        }
                    }
                    return parsedPartHashes
                }
                |> `catch` { _ -> Signal<[Int32: Data], NoError> in
                    return .single([:])
                }
        } |> deliverOn(queue)).start(next: { [weak self] result in
            if let strongSelf = self {
                if strongSelf.requestOffsetAndDisposable?.0 == requestOffset {
                    strongSelf.requestOffsetAndDisposable = nil
                    
                    for (hashOffset, hashData) in result {
                        assert(hashOffset % dataHashLength == 0)
                        strongSelf.knownUpperBound = max(strongSelf.knownUpperBound, hashOffset + dataHashLength)
                        strongSelf.hashes[hashOffset] = hashData
                    }
                    
                    for (index, item) in strongSelf.subscribers.copyItemsWithIndices() {
                        let (offset, limit, subscriber) = item
                        if let data = strongSelf.take(offset: offset, limit: limit) {
                            strongSelf.subscribers.remove(index)
                            subscriber(data)
                        }
                    }
                    
                    if let requestedUpperBound = strongSelf.requestedUpperBound, requestedUpperBound > strongSelf.knownUpperBound {
                        strongSelf.requestMore()
                    }
                } else {
                    assertionFailure()
                }
            }
        }))
    }
}

private enum MultipartFetchSource {
    case none
    case master(location: MultipartFetchMasterLocation, download: DownloadWrapper)
    case cdn(masterDatacenterId: Int32, fileToken: Data, key: Data, iv: Data, download: DownloadWrapper, masterDownload: DownloadWrapper, hashSource: MultipartCdnHashSource)
    
    func request(offset: Int32, limit: Int32) -> Signal<Data, MultipartFetchDownloadError> {
        switch self {
            case .none:
                return .never()
            case let .master(location, download):
                return download.get()
                    |> mapToSignalPromotingError { download -> Signal<Data, MultipartFetchDownloadError> in
                        var updatedLength = roundUp(Int(limit), to: 4096)
                        while updatedLength % 4096 != 0 || 1048576 % updatedLength != 0 {
                            updatedLength += 1
                        }
                        
                        switch location {
                            case let .generic(_, location):
                                return download.request(Api.functions.upload.getFile(location: location, offset: offset, limit: Int32(updatedLength)))
                                    |> mapError { _ -> MultipartFetchDownloadError in
                                        return .generic
                                    }
                                    |> mapToSignal { result -> Signal<Data, MultipartFetchDownloadError> in
                                        switch result {
                                            case let .file(_, _, bytes):
                                                var resultData = bytes.makeData()
                                                if resultData.count > Int(limit) {
                                                    resultData.count = Int(limit)
                                                }
                                                return .single(resultData)
                                            case let .fileCdnRedirect(dcId, fileToken, encryptionKey, encryptionIv, partHashes):
                                                var parsedPartHashes: [Int32: Data] = [:]
                                                for part in partHashes {
                                                    switch part {
                                                        case let .cdnFileHash(offset, limit, bytes):
                                                            assert(limit == 128 * 1024)
                                                            parsedPartHashes[offset] = bytes.makeData()
                                                    }
                                                }
                                                return .fail(.switchToCdn(id: dcId, token: fileToken.makeData(), key: encryptionKey.makeData(), iv: encryptionIv.makeData(), partHashes: parsedPartHashes))
                                        }
                                }
                            case let .web(_, location):
                                return download.request(Api.functions.upload.getWebFile(location: location, offset: offset, limit: Int32(updatedLength)))
                                    |> mapError { _ -> MultipartFetchDownloadError in
                                        return .generic
                                    }
                                    |> mapToSignal { result -> Signal<Data, MultipartFetchDownloadError> in
                                        switch result {
                                            case let .webFile(_, _, _, _, bytes):
                                                var resultData = bytes.makeData()
                                                if resultData.count > Int(limit) {
                                                    resultData.count = Int(limit)
                                                }
                                                return .single(resultData)
                                        }
                                }
                        }
                    }
            case let .cdn(masterDatacenterId, fileToken, key, iv, download, _, hashSource):
                let part = download.get()
                    |> mapToSignalPromotingError { download -> Signal<Data, MultipartFetchDownloadError> in
                        var updatedLength = roundUp(Int(limit), to: 4096)
                        while updatedLength % 4096 != 0 || 1048576 % updatedLength != 0 {
                            updatedLength += 1
                        }
                        
                        return download.request(Api.functions.upload.getCdnFile(fileToken: Buffer(data: fileToken), offset: offset, limit: Int32(updatedLength)))
                        |> mapError { _ -> MultipartFetchDownloadError in
                            return .generic
                        }
                        |> mapToSignal { result -> Signal<Data, MultipartFetchDownloadError> in
                            switch result {
                                case let .cdnFileReuploadNeeded(token):
                                    return .fail(.reuploadToCdn(masterDatacenterId: masterDatacenterId, token: token.makeData()))
                                case let .cdnFile(bytes):
                                    if bytes.size == 0 {
                                        return .single(bytes.makeData())
                                    } else {
                                        var partIv = iv
                                        partIv.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<Int8>) -> Void in
                                            var ivOffset: Int32 = (offset / 16).bigEndian
                                            memcpy(bytes.advanced(by: partIv.count - 4), &ivOffset, 4)
                                        }
                                        return .single(MTAesCtrDecrypt(bytes.makeData(), key, partIv))
                                    }
                            }
                        }
                    }
                return combineLatest(part, hashSource.get(offset: offset, limit: limit))
                    |> mapToSignal { partData, hashData -> Signal<Data, MultipartFetchDownloadError> in
                        return .single(partData)
                    }
        }
    }
}

private final class MultipartFetchManager {
    let parallelParts: Int
    let defaultPartSize = 128 * 1024
    let partAlignment = 128 * 1024
    
    let queue = Queue()
    
    var committedOffset: Int
    let range: Range<Int>
    var completeSize: Int?
    let takeDownloader: (Int32, Bool) -> Signal<Download, NoError>
    let partReady: (Data) -> Void
    let completed: () -> Void
    
    private var source: MultipartFetchSource
    
    var fetchingParts: [Int: (Int, Disposable)] = [:]
    var fetchedParts: [Int: Data] = [:]
    var cachedPartHashes: [Int: Data] = [:]
    
    var statsTimer: SignalKitTimer?
    var receivedSize = 0
    var lastStatReport: (timestamp: Double, receivedSize: Int)?
    
    var reuploadingToCdn = false
    let reuploadToCdnDisposable = MetaDisposable()
    
    var state: MultipartDownloadState
    
    init(size: Int?, range: Range<Int>, encryptionKey: SecretFileEncryptionKey?, decryptedSize: Int32?, location: MultipartFetchMasterLocation, takeDownloader: @escaping (Int32, Bool) -> Signal<Download, NoError>, partReady: @escaping (Data) -> Void, completed: @escaping () -> Void) {
        self.completeSize = size
        if let size = size {
            if size <= range.lowerBound {
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
        self.takeDownloader = takeDownloader
        self.source = .master(location: location, download: DownloadWrapper(id: location.datacenterId, cdn: false, take: takeDownloader))
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
            self.source = .none
            for (_, (_, disposable)) in self.fetchingParts {
                disposable.dispose()
            }
            self.statsTimer?.invalidate()
            self.reuploadToCdnDisposable.dispose()
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
            while fetchingParts.count < self.parallelParts && !self.reuploadingToCdn {
                var processedParts: [(Int, Int)] = []
                for (offset, (size, _)) in self.fetchingParts {
                    processedParts.append((offset, size))
                }
                for (offset, data) in self.fetchedParts {
                    processedParts.append((offset, data.count))
                }
                processedParts.sort(by: { $0.0 < $1.0 })
                var nextOffset = self.committedOffset
                for (offset, size) in processedParts {
                    if offset >= self.committedOffset {
                        if offset == nextOffset {
                            nextOffset = offset + size
                        } else {
                            break
                        }
                    }
                }
                
                if nextOffset < self.range.upperBound {
                    let partSize = min(self.range.upperBound - nextOffset, self.defaultPartSize)
                    let part = self.source.request(offset: Int32(nextOffset), limit: Int32(partSize))
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
                    }, error: { [weak self] error in
                        if let strongSelf = self {
                            let _ = strongSelf.fetchingParts.removeValue(forKey: partOffset)
                            switch error {
                                case .generic:
                                    break
                                case let .switchToCdn(id, token, key, iv, partHashes):
                                    switch strongSelf.source {
                                        case let .master(location, download):
                                            strongSelf.source = .cdn(masterDatacenterId: location.datacenterId, fileToken: token, key: key, iv: iv, download: DownloadWrapper(id: id, cdn: true, take: strongSelf.takeDownloader), masterDownload: download, hashSource: MultipartCdnHashSource(queue: strongSelf.queue, fileToken: token, hashes: partHashes, masterDownload: download))
                                            strongSelf.checkState()
                                        case .cdn, .none:
                                            break
                                    }
                                case let .reuploadToCdn(_, token):
                                    switch strongSelf.source {
                                        case .master, .none:
                                            break
                                        case let .cdn(_, fileToken, _, _, _, masterDownload, _):
                                            if !strongSelf.reuploadingToCdn {
                                                strongSelf.reuploadingToCdn = true
                                                let reupload: Signal<[Api.CdnFileHash], NoError> = masterDownload.get() |> mapToSignal { download -> Signal<[Api.CdnFileHash], NoError> in
                                                    return download.request(Api.functions.upload.reuploadCdnFile(fileToken: Buffer(data: fileToken), requestToken: Buffer(data: token)))
                                                        |> `catch` { _ -> Signal<[Api.CdnFileHash], NoError> in
                                                            return .single([])
                                                        }
                                                }
                                                strongSelf.reuploadToCdnDisposable.set((reupload |> deliverOn(strongSelf.queue)).start(next: { _ in
                                                    if let strongSelf = self {
                                                        strongSelf.reuploadingToCdn = false
                                                        strongSelf.checkState()
                                                    }
                                                }))
                                            }
                                    }
                                case .hashesMissing:
                                    break
                            }
                        }
                    }))
                } else {
                    break
                }
            }
        }
    }
    
    func reportStats() {
        /*if let lastStatReport = self.lastStatReport {
            let downloadSpeed = Double(self.receivedSize - lastStatReport.receivedSize) / (CACurrentMediaTime() - lastStatReport.timestamp)
            print("MultipartFetch speed \(downloadSpeed / 1024) KB/s")
        }
        self.lastStatReport = (CACurrentMediaTime(), self.receivedSize)*/
    }
}

func multipartFetch(account: Account, resource: TelegramMultipartFetchableResource, size: Int?, range: Range<Int>, tag: MediaResourceFetchTag?, encryptionKey: SecretFileEncryptionKey? = nil, decryptedSize: Int32? = nil) -> Signal<MediaResourceDataFetchResult, NoError> {
    return Signal { subscriber in
        let datacenterId = resource.datacenterId
        let location: MultipartFetchMasterLocation
        if let resource = resource as? TelegramCloudMediaResource {
            location = .generic(Int32(datacenterId), resource.apiInputLocation)
        } else if let resource = resource as? WebFileReferenceMediaResource {
            location = .web(Int32(datacenterId), resource.apiInputLocation)
        } else {
            assertionFailure("multipartFetch: unsupported resource type \(resource)")
            return EmptyDisposable
        }
        
        let manager = MultipartFetchManager(size: size, range: range, encryptionKey: encryptionKey, decryptedSize: decryptedSize, location: location, takeDownloader: { id, cdn in
            return account.network.download(datacenterId: Int(id), isCdn: cdn, tag: tag)
        }, partReady: { data in
            subscriber.putNext(.dataPart(data: data, range: 0 ..< data.count, complete: false))
        }, completed: {
            subscriber.putNext(.dataPart(data: Data(), range: 0 ..< 0, complete: true))
            subscriber.putCompletion()
        })
        
        manager.start()
        
        var managerRef: MultipartFetchManager? = manager
        
        return ActionDisposable {
            managerRef?.cancel()
            managerRef = nil
        }
    }
}
