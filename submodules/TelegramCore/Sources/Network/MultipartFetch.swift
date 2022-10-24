import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit
import RangeSet

private typealias SignalKitTimer = SwiftSignalKit.Timer

private final class MultipartDownloadState {
    let aesKey: Data
    var aesIv: Data
    let decryptedSize: Int64?
    
    var currentSize: Int64 = 0
    
    init(encryptionKey: SecretFileEncryptionKey?, decryptedSize: Int64?) {
        if let encryptionKey = encryptionKey {
            self.aesKey = encryptionKey.aesKey
            self.aesIv = encryptionKey.aesIv
        } else {
            self.aesKey = Data()
            self.aesIv = Data()
        }
        self.decryptedSize = decryptedSize
    }
    
    func transform(offset: Int64, data: Data) -> Data {
        if self.aesKey.count != 0 {
            var decryptedData = data
            assert(decryptedSize != nil)
            assert(decryptedData.count % 16 == 0)
            let decryptedDataCount = decryptedData.count
            assert(offset == self.currentSize)
            decryptedData.withUnsafeMutableBytes { rawBytes -> Void in
                let bytes = rawBytes.baseAddress!.assumingMemoryBound(to: UInt8.self)
                self.aesIv.withUnsafeMutableBytes { rawIv -> Void in
                    let iv = rawIv.baseAddress!.assumingMemoryBound(to: UInt8.self)
                    MTAesDecryptBytesInplaceAndModifyIv(bytes, decryptedDataCount, self.aesKey, iv)
                }
            }
            if self.currentSize + Int64(decryptedData.count) > self.decryptedSize! {
                decryptedData.count = Int(self.decryptedSize! - self.currentSize)
            }
            self.currentSize += Int64(decryptedData.count)
            return decryptedData
        } else {
            return data
        }
    }
}

private enum MultipartFetchDownloadError {
    case generic
    case switchToCdn(id: Int32, token: Data, key: Data, iv: Data, partHashes: [Int64: Data])
    case reuploadToCdn(masterDatacenterId: Int32, token: Data)
    case revalidateMediaReference
    case hashesMissing
    case fatal
}

private enum MultipartFetchGenericLocationResult {
    case none
    case location(Api.InputFileLocation)
    case revalidate
}

private enum MultipartFetchMasterLocation {
    case generic(Int32, (TelegramMediaResource, MediaResourceReference?, Data?) -> MultipartFetchGenericLocationResult)
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

private struct DownloadWrapper {
    let consumerId: Int64
    let datacenterId: Int32
    let isCdn: Bool
    let network: Network
    let useMainConnection: Bool
    
    func request<T>(_ data: (FunctionDescription, Buffer, DeserializeFunctionResponse<T>), tag: MediaResourceFetchTag?, continueInBackground: Bool) -> Signal<T, MTRpcError> {
        let target: MultiplexedRequestTarget
        if self.isCdn {
            target = .cdn(Int(self.datacenterId))
        } else {
            target = .main(Int(self.datacenterId))
        }
        return network.multiplexedRequestManager.request(to: target, consumerId: self.consumerId, data: data, tag: tag, continueInBackground: continueInBackground)
    }
}

private func roundUp(_ value: Int64, to multiple: Int64) -> Int64 {
    if multiple == 0 {
        return value
    }
    
    let remainder = value % multiple
    if remainder == 0 {
        return value
    }
    
    return value + multiple - remainder
}

private let dataHashLength: Int64 = 128 * 1024

private final class MultipartCdnHashSource {
    private final class ClusterContext {
        final class Subscriber {
            let completion: ([Int64: Data]) -> Void
            let error: (MultipartFetchDownloadError) -> Void

            init(completion: @escaping ([Int64: Data]) -> Void, error: @escaping (MultipartFetchDownloadError) -> Void) {
                self.completion = completion
                self.error = error
            }
        }

        let disposable: Disposable
        let subscribers = Bag<Subscriber>()

        var result: [Int64: Data]?
        var error: MultipartFetchDownloadError?

        init(disposable: Disposable) {
            self.disposable = disposable
        }

        deinit {
            self.disposable.dispose()
        }
    }

    private let queue: Queue
    
    private let fileToken: Data
    private let masterDownload: DownloadWrapper
    private let continueInBackground: Bool

    private var clusterContexts: [Int64: ClusterContext] = [:]
    
    init(queue: Queue, fileToken: Data, hashes: [Int64: Data], masterDownload: DownloadWrapper, continueInBackground: Bool) {
        assert(queue.isCurrent())
        
        self.queue = queue
        self.fileToken = fileToken
        self.masterDownload = masterDownload
        self.continueInBackground = continueInBackground
    }
    
    deinit {
        assert(self.queue.isCurrent())
    }

    func getCluster(offset: Int64, completion: @escaping ([Int64: Data]) -> Void, error: @escaping (MultipartFetchDownloadError) -> Void) -> Disposable {
        precondition(offset % (1 * 1024 * 1024) == 0)

        let clusterContext: ClusterContext
        if let current = self.clusterContexts[offset] {
            clusterContext = current
        } else {
            let disposable = MetaDisposable()
            clusterContext = ClusterContext(disposable: disposable)
            self.clusterContexts[offset] = clusterContext

            disposable.set((self.masterDownload.request(Api.functions.upload.getCdnFileHashes(fileToken: Buffer(data: self.fileToken), offset: offset), tag: nil, continueInBackground: self.continueInBackground)
            |> map { partHashes -> [Int64: Data] in
                var parsedPartHashes: [Int64: Data] = [:]
                for part in partHashes {
                    switch part {
                        case let .fileHash(offset, limit, bytes):
                            assert(limit == 128 * 1024)
                            parsedPartHashes[offset] = bytes.makeData()
                    }
                }
                return parsedPartHashes
            }
            |> deliverOn(self.queue)).start(next: { [weak self, weak clusterContext] result in
                guard let _ = self, let clusterContext = clusterContext else {
                    return
                }
                clusterContext.result = result
                for subscriber in clusterContext.subscribers.copyItems() {
                    subscriber.completion(result)
                }
            }, error: { [weak self, weak clusterContext] _ in
                guard let _ = self, let clusterContext = clusterContext else {
                    return
                }
                clusterContext.error = .generic
                for subscriber in clusterContext.subscribers.copyItems() {
                    subscriber.error(.generic)
                }
            }))
        }

        if let result = clusterContext.result {
            completion(result)

            return EmptyDisposable
        } else if let errorValue = clusterContext.error {
            error(errorValue)

            return EmptyDisposable
        } else {
            let index = clusterContext.subscribers.add(ClusterContext.Subscriber(completion: completion, error: error))
            let queue = self.queue
            return ActionDisposable { [weak self, weak clusterContext] in
                queue.async {
                    guard let strongSelf = self, let clusterContext = clusterContext else {
                        return
                    }
                    clusterContext.subscribers.remove(index)
                    if clusterContext.subscribers.isEmpty {
                        if strongSelf.clusterContexts[offset] === clusterContext {
                            strongSelf.clusterContexts.removeValue(forKey: offset)
                        }
                    }
                }
            }
        }
    }

    private func cluster(offset: Int64) -> Signal<[Int64: Data], MultipartFetchDownloadError> {
        let queue = self.queue
        return Signal { [weak self] subscriber in
            let disposable = MetaDisposable()

            queue.async {
                guard let strongSelf = self else {
                    subscriber.putError(.generic)
                    return
                }

                disposable.set(strongSelf.getCluster(offset: offset, completion: { result in
                    subscriber.putNext(result)
                    subscriber.putCompletion()
                }, error: { error in
                    subscriber.putError(error)
                }))
            }

            return disposable
        }
    }

    func get(offset: Int64, limit: Int64) -> Signal<[Int64: Data], MultipartFetchDownloadError> {
        precondition(offset % dataHashLength == 0)
        precondition((offset + limit) % dataHashLength == 0)

        var clusterOffsets = Set<Int64>()
        for partOffset in stride(from: offset, to: offset + limit, by: Int(dataHashLength)) {
            clusterOffsets.insert(partOffset - (partOffset % (1 * 1024 * 1024)))
        }

        return combineLatest(clusterOffsets.map { clusterOffset in
            return self.cluster(offset: clusterOffset)
        })
        |> mapToSignal { clusterResults -> Signal<[Int64: Data], MultipartFetchDownloadError> in
            var result: [Int64: Data] = [:]

            for partOffset in stride(from: offset, to: offset + limit, by: Int64.Stride(dataHashLength)) {
                var found = false
                for cluster in clusterResults {
                    if let data = cluster[partOffset] {
                        result[partOffset] = data
                        found = true
                    }
                }
                if !found {
                    return .fail(.generic)
                }
            }

            return .single(result)
        }
    }
}

private enum MultipartFetchSource {
    case none
    case master(location: MultipartFetchMasterLocation, download: DownloadWrapper)
    case cdn(masterDatacenterId: Int32, fileToken: Data, key: Data, iv: Data, download: DownloadWrapper, masterDownload: DownloadWrapper, hashSource: MultipartCdnHashSource)
    
    func request(offset: Int64, limit: Int64, tag: MediaResourceFetchTag?, resource: TelegramMediaResource, resourceReference: FetchResourceReference, fileReference: Data?, continueInBackground: Bool) -> Signal<Data, MultipartFetchDownloadError> {
        var resourceReferenceValue: MediaResourceReference?
        switch resourceReference {
        case .forceRevalidate:
            return .fail(.revalidateMediaReference)
        case .empty:
            resourceReferenceValue = nil
        case let .reference(value):
            resourceReferenceValue = value
        }
        
        switch self {
            case .none:
                return .never()
            case let .master(location, download):
                assert(limit % 4096 == 0)
                assert(1048576 % limit == 0)
                
                switch location {
                    case let .generic(_, location):
                        switch location(resource, resourceReferenceValue, fileReference) {
                            case .none:
                                return .fail(.revalidateMediaReference)
                            case .revalidate:
                                return .fail(.revalidateMediaReference)
                            case let .location(parsedLocation):                            
                                return download.request(Api.functions.upload.getFile(flags: 0, location: parsedLocation, offset: offset, limit: Int32(limit)), tag: tag, continueInBackground: continueInBackground)
                                |> mapError { error -> MultipartFetchDownloadError in
                                    if error.errorDescription.hasPrefix("FILEREF_INVALID") || error.errorDescription.hasPrefix("FILE_REFERENCE_")  {
                                        return .revalidateMediaReference
                                    }
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
                                            var parsedPartHashes: [Int64: Data] = [:]
                                            for part in partHashes {
                                                switch part {
                                                    case let .fileHash(offset, limit, bytes):
                                                        assert(limit == 128 * 1024)
                                                        parsedPartHashes[offset] = bytes.makeData()
                                                }
                                            }
                                            parsedPartHashes.removeAll()
                                            return .fail(.switchToCdn(id: dcId, token: fileToken.makeData(), key: encryptionKey.makeData(), iv: encryptionIv.makeData(), partHashes: parsedPartHashes))
                                    }
                                }
                        }
                    case let .web(_, location):
                        return download.request(Api.functions.upload.getWebFile(location: location, offset: Int32(offset), limit: Int32(limit)), tag: tag, continueInBackground: continueInBackground)
                        |> mapError { error -> MultipartFetchDownloadError in
                            return .fatal
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
            case let .cdn(masterDatacenterId, fileToken, key, iv, download, _, hashSource):
                var updatedLength = roundUp(Int64(limit), to: 4096)
                while updatedLength % 4096 != 0 || 1048576 % updatedLength != 0 {
                    updatedLength += 1
                }
                
                let part = download.request(Api.functions.upload.getCdnFile(fileToken: Buffer(data: fileToken), offset: offset, limit: Int32(updatedLength)), tag: nil, continueInBackground: continueInBackground)
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
                                let partIvCount = partIv.count
                                partIv.withUnsafeMutableBytes { rawBytes -> Void in
                                    let bytes = rawBytes.baseAddress!.assumingMemoryBound(to: UInt8.self)
                                    var ivOffset: Int32 = Int32(clamping: (offset / 16)).bigEndian
                                    memcpy(bytes.advanced(by: partIvCount - 4), &ivOffset, 4)
                                }
                                return .single(MTAesCtrDecrypt(bytes.makeData(), key, partIv)!)
                            }
                    }
                }
                
                return combineLatest(part, hashSource.get(offset: offset, limit: limit))
                |> mapToSignal { partData, hashData -> Signal<Data, MultipartFetchDownloadError> in
                    var localOffset: Int64 = 0
                    while localOffset < partData.count {
                        let dataToHash = partData.subdata(in: Int(localOffset) ..< min(partData.count, Int(localOffset + Int64(dataHashLength))))
                        if let hash = hashData[offset + localOffset] {
                            let localHash = MTSha256(dataToHash)
                            if localHash != hash {
                                return .fail(.generic)
                            }
                        } else {
                            return .fail(.generic)
                        }
                        
                        localOffset += Int64(dataHashLength)
                    }
                    return .single(partData)
                }
        }
    }
}

private enum FetchResourceReference {
    case empty
    case forceRevalidate
    case reference(MediaResourceReference)
}

private final class MultipartFetchManager {
    private struct FetchSpeedRecord {
        var timestamp: Double
        var byteCount: Int
    }
    
    let parallelParts: Int
    let defaultPartSize: Int64
    var partAlignment: Int64 = 4 * 1024
    
    var resource: TelegramMediaResource
    var resourceReference: FetchResourceReference
    var fileReference: Data?
    let parameters: MediaResourceFetchParameters?
    let consumerId: Int64
    
    let queue = Queue()
    
    var currentIntervals: [(Range<Int64>, MediaBoxFetchPriority)]?
    var currentFilledRanges = RangeSet<Int64>()
    
    var completeSize: Int64?
    var completeSizeReported = false
    
    let postbox: Postbox
    let network: Network
    let revalidationContext: MediaReferenceRevalidationContext?
    let continueInBackground: Bool
    let partReady: (Int64, Data) -> Void
    let reportCompleteSize: (Int64) -> Void
    let finishWithError: (MediaResourceDataFetchError) -> Void

    private let useMainConnection: Bool
    private var source: MultipartFetchSource
    
    var fetchingParts: [Int64: (Int64, Disposable)] = [:]
    var nextFetchingPartId = 0
    var fetchedParts: [Int64: (Int64, Data)] = [:]
    var cachedPartHashes: [Int64: Data] = [:]
    
    var reuploadingToCdn = false
    let reuploadToCdnDisposable = MetaDisposable()
    
    var revalidatedMediaReference = false
    var revalidatingMediaReference = false
    let revalidateMediaReferenceDisposable = MetaDisposable()
    
    var state: MultipartDownloadState
    
    var rangesDisposable: Disposable?
    
    private var speedTimer: SwiftSignalKit.Timer?
    private var fetchSpeedRecords: [FetchSpeedRecord] = []
    private var totalFetchedByteCount: Int = 0
    
    init(resource: TelegramMediaResource, parameters: MediaResourceFetchParameters?, size: Int64?, intervals: Signal<[(Range<Int64>, MediaBoxFetchPriority)], NoError>, encryptionKey: SecretFileEncryptionKey?, decryptedSize: Int64?, location: MultipartFetchMasterLocation, postbox: Postbox, network: Network, revalidationContext: MediaReferenceRevalidationContext?, partReady: @escaping (Int64, Data) -> Void, reportCompleteSize: @escaping (Int64) -> Void, finishWithError: @escaping (MediaResourceDataFetchError) -> Void, useMainConnection: Bool) {
        self.resource = resource
        self.parameters = parameters
        self.consumerId = Int64.random(in: Int64.min ... Int64.max)
        self.useMainConnection = useMainConnection
        
        self.completeSize = size
        if let size = size {
            if size <= 512 * 1024 {
                self.defaultPartSize = 16 * 1024
                self.parallelParts = 4 * 4
            } else {
                self.defaultPartSize = 512 * 1024
                self.parallelParts = 8
            }
        } else {
            self.parallelParts = 1
            self.defaultPartSize = 128 * 1024
        }
        
        if let info = parameters?.info as? TelegramCloudMediaResourceFetchInfo {
            self.fileReference = info.reference.apiFileReference
            self.continueInBackground = info.continueInBackground
            self.resourceReference = .reference(info.reference)
            switch info.reference {
            case let .media(media, _):
                if let file = media.media as? TelegramMediaFile {
                    for attribute in file.attributes {
                        switch attribute {
                        case let .Sticker(_, packReference, _):
                            switch packReference {
                            case .name?:
                                self.resourceReference = .forceRevalidate
                            default:
                                break
                            }
                        default:
                            break
                        }
                    }
                }
            default:
                break
            }
        } else {
            self.continueInBackground = false
            self.resourceReference = .empty
        }
        
        self.state = MultipartDownloadState(encryptionKey: encryptionKey, decryptedSize: decryptedSize)
        self.postbox = postbox
        self.network = network
        self.revalidationContext = revalidationContext
        self.source = .master(location: location, download: DownloadWrapper(consumerId: self.consumerId, datacenterId: location.datacenterId, isCdn: false, network: network, useMainConnection: self.useMainConnection))
        self.partReady = partReady
        self.reportCompleteSize = reportCompleteSize
        self.finishWithError = finishWithError
        
        self.rangesDisposable = (intervals
        |> deliverOn(self.queue)).start(next: { [weak self] intervals in
            if let strongSelf = self {
                if let _ = strongSelf.currentIntervals {
                    strongSelf.currentIntervals = intervals
                    strongSelf.checkState()
                } else {
                    strongSelf.currentIntervals = intervals
                    strongSelf.checkState()
                }
            }
        })
        
        /*self.markSpeedRecord()
        self.speedTimer = SwiftSignalKit.Timer(timeout: 1.0, repeat: true, completion: { [weak self] in
            self?.markSpeedRecord()
        }, queue: self.queue)
        self.speedTimer?.start()*/
    }
    
    deinit {
        let rangesDisposable = self.rangesDisposable
        self.queue.async {
            rangesDisposable?.dispose()
        }
        self.speedTimer?.invalidate()
    }
    
    func start() {
        self.queue.async {
            self.checkState()
        }
    }
    
    func cancel() {
        self.queue.async {
            self.source = .none
            for (_, (_, disposable)) in self.fetchingParts {
                disposable.dispose()
            }
            self.reuploadToCdnDisposable.dispose()
            self.revalidateMediaReferenceDisposable.dispose()
        }
    }
    
    private func addSpeedRecord(byteCount: Int) {
        self.totalFetchedByteCount += byteCount
    }
    
    private func markSpeedRecord() {
        self.fetchSpeedRecords.append(FetchSpeedRecord(timestamp: CFAbsoluteTimeGetCurrent(), byteCount: self.totalFetchedByteCount))
        if self.fetchSpeedRecords.count > 10 {
            self.fetchSpeedRecords.removeFirst(self.fetchSpeedRecords.count - 10)
        }
        
        if !self.fetchSpeedRecords.isEmpty {
            let totalByteCount = self.fetchSpeedRecords[self.fetchSpeedRecords.count - 1].byteCount - self.fetchSpeedRecords[0].byteCount
            let totalTime = self.fetchSpeedRecords[self.fetchSpeedRecords.count - 1].timestamp - self.fetchSpeedRecords[0].timestamp
            
            if totalTime > 0.0 {
                let speed = Double(totalByteCount) / totalTime
                Logger.shared.log("MultipartFetch", "\(self.resource.id.stringRepresentation) \(speed) bytes/s")
                
                #if DEBUG
                self.checkState()
                #endif
            }
        }
    }
    
    func checkState() {
        guard let currentIntervals = self.currentIntervals else {
            return
        }
        
        var removeFromFetchIntervals = self.currentFilledRanges
        
        let isSingleContiguousRange = currentIntervals.count == 1
        for offset in self.fetchedParts.keys.sorted() {
            if let (_, data) = self.fetchedParts[offset] {
                let partRange = offset ..< (offset + Int64(data.count))
                removeFromFetchIntervals.formUnion(RangeSet<Int64>(partRange))
                
                var hasEarlierFetchingPart = false
                if isSingleContiguousRange {
                    inner: for key in self.fetchingParts.keys {
                        if key < offset {
                            hasEarlierFetchingPart = true
                            break inner
                        }
                    }
                }
                
                if !hasEarlierFetchingPart {
                    self.currentFilledRanges.formUnion(RangeSet<Int64>(partRange))
                    self.fetchedParts.removeValue(forKey: offset)
                    
                    self.addSpeedRecord(byteCount: Int(partRange.upperBound - partRange.lowerBound))
                    
                    self.partReady(offset, self.state.transform(offset: offset, data: data))
                }
            }
        }
        
        for (offset, (size, _)) in self.fetchingParts {
            removeFromFetchIntervals.formUnion(RangeSet<Int64>(offset ..< (offset + size)))
        }
        
        if let completeSize = self.completeSize {
            self.currentFilledRanges.formUnion(RangeSet<Int64>(completeSize ..< Int64.max))
            removeFromFetchIntervals.formUnion(RangeSet<Int64>(completeSize ..< Int64.max))
        }
        
        var intervalsToFetch: [(Range<Int64>, MediaBoxFetchPriority)] = []
        for (interval, priority) in currentIntervals {
            var intervalIndexSet = RangeSet<Int64>(interval)
            intervalIndexSet.subtract(removeFromFetchIntervals)
            for cleanInterval in intervalIndexSet.ranges {
                assert(!cleanInterval.isEmpty)
                intervalsToFetch.append((Int64(cleanInterval.lowerBound) ..< Int64(cleanInterval.upperBound), priority))
            }
        }
        
        if let completeSize = self.completeSize {
            if intervalsToFetch.isEmpty && self.fetchingParts.isEmpty && !self.completeSizeReported {
                self.completeSizeReported = true
                assert(self.fetchedParts.isEmpty)
                if let decryptedSize = self.state.decryptedSize {
                    self.reportCompleteSize(decryptedSize)
                } else {
                    self.reportCompleteSize(completeSize)
                }
            }
        }
        
        while !intervalsToFetch.isEmpty && self.fetchingParts.count < self.parallelParts && !self.reuploadingToCdn && !self.revalidatingMediaReference {
            
            var indicesByPriority: [MediaBoxFetchPriority: [Int]] = [:]
            for i in 0 ..< intervalsToFetch.count {
                if indicesByPriority[intervalsToFetch[i].1] == nil {
                    indicesByPriority[intervalsToFetch[i].1] = []
                }
                indicesByPriority[intervalsToFetch[i].1]!.append(i)
            }
            
            let currentIntervalIndex: Int
            if let maxIndices = indicesByPriority[.maximum], !maxIndices.isEmpty {
                currentIntervalIndex = maxIndices[self.nextFetchingPartId % maxIndices.count]
            } else if let elevatedIndices = indicesByPriority[.elevated], !elevatedIndices.isEmpty {
                currentIntervalIndex = elevatedIndices[self.nextFetchingPartId % elevatedIndices.count]
            } else {
                currentIntervalIndex = self.nextFetchingPartId % intervalsToFetch.count
            }
            self.nextFetchingPartId += 1
            let (firstInterval, priority) = intervalsToFetch[currentIntervalIndex]
            var downloadRange: Range<Int64> = firstInterval.lowerBound ..< min(firstInterval.lowerBound + self.defaultPartSize, firstInterval.upperBound)
            let rawRange: Range<Int64> = downloadRange
            if downloadRange.lowerBound % self.partAlignment != 0 {
                let previousBoundary = (downloadRange.lowerBound / self.partAlignment) * self.partAlignment
                downloadRange = previousBoundary ..< downloadRange.upperBound
            }
            if downloadRange.upperBound % self.partAlignment != 0 {
                let nextBoundary = (downloadRange.upperBound / self.partAlignment + 1) * self.partAlignment
                downloadRange = downloadRange.lowerBound ..< nextBoundary
            }
            if downloadRange.lowerBound / (1024 * 1024) != (downloadRange.upperBound - 1) / (1024 * 1024) {
                let nextBoundary = (downloadRange.lowerBound / (1024 * 1024) + 1) * (1024 * 1024)
                downloadRange = downloadRange.lowerBound ..< nextBoundary
            }
            while 1024 * 1024 % downloadRange.count != 0 {
                downloadRange = downloadRange.lowerBound ..< (downloadRange.upperBound - 1)
            }
            
            var intervalIndexSet = RangeSet<Int64>(intervalsToFetch[currentIntervalIndex].0)
            intervalIndexSet.remove(contentsOf: downloadRange)
            intervalsToFetch.remove(at: currentIntervalIndex)
            var insertIndex = currentIntervalIndex
            for interval in intervalIndexSet.ranges {
                intervalsToFetch.insert((interval, priority), at: insertIndex)
                insertIndex += 1
            }
            
            let part = self.source.request(offset: downloadRange.lowerBound, limit: downloadRange.upperBound - downloadRange.lowerBound, tag: self.parameters?.tag, resource: self.resource, resourceReference: self.resourceReference, fileReference: self.fileReference, continueInBackground: self.continueInBackground)
            //|> delay(5.0, queue: self.queue)
            |> deliverOn(self.queue)
            let partDisposable = MetaDisposable()
            self.fetchingParts[downloadRange.lowerBound] = (Int64(downloadRange.count), partDisposable)
            
            partDisposable.set(part.start(next: { [weak self] data in
                guard let strongSelf = self else {
                    return
                }
                if data.count < downloadRange.count {
                    strongSelf.completeSize = downloadRange.lowerBound + Int64(data.count)
                }
                let _ = strongSelf.fetchingParts.removeValue(forKey: downloadRange.lowerBound)
                strongSelf.fetchedParts[downloadRange.lowerBound] = (rawRange.lowerBound, data)
                strongSelf.checkState()
            }, error: { [weak self] error in
                guard let strongSelf = self else {
                    return
                }
                let _ = strongSelf.fetchingParts.removeValue(forKey: downloadRange.lowerBound)
                switch error {
                    case .generic:
                        break
                    case .fatal:
                        strongSelf.finishWithError(.generic)
                    case .revalidateMediaReference:
                        if !strongSelf.revalidatingMediaReference && !strongSelf.revalidatedMediaReference {
                            strongSelf.revalidatingMediaReference = true
                            if let info = strongSelf.parameters?.info as? TelegramCloudMediaResourceFetchInfo, let revalidationContext = strongSelf.revalidationContext {
                                strongSelf.revalidateMediaReferenceDisposable.set((revalidateMediaResourceReference(postbox: strongSelf.postbox, network: strongSelf.network, revalidationContext: revalidationContext, info: info, resource: strongSelf.resource)
                                |> deliverOn(strongSelf.queue)).start(next: { validationResult in
                                    if let strongSelf = self {
                                        strongSelf.revalidatingMediaReference = false
                                        strongSelf.revalidatedMediaReference = true
                                        if let validatedResource = validationResult.updatedResource as? TelegramCloudMediaResourceWithFileReference, let reference = validatedResource.fileReference {
                                            strongSelf.fileReference = reference
                                        }
                                        strongSelf.resource = validationResult.updatedResource
                                        if let reference = validationResult.updatedReference {
                                            strongSelf.resourceReference = .reference(reference)
                                        } else {
                                            strongSelf.resourceReference = .empty
                                        }
                                        strongSelf.checkState()
                                    }
                                }, error: { _ in
                                }))
                            } else {
                                Logger.shared.log("MultipartFetch", "reference invalidation requested, but no valid reference given")
                            }
                        }
                    case let .switchToCdn(id, token, key, iv, partHashes):
                        switch strongSelf.source {
                            case let .master(location, download):
                                strongSelf.partAlignment = dataHashLength
                                strongSelf.source = .cdn(masterDatacenterId: location.datacenterId, fileToken: token, key: key, iv: iv, download: DownloadWrapper(consumerId: strongSelf.consumerId, datacenterId: id, isCdn: true, network: strongSelf.network, useMainConnection: strongSelf.useMainConnection), masterDownload: download, hashSource: MultipartCdnHashSource(queue: strongSelf.queue, fileToken: token, hashes: partHashes, masterDownload: download, continueInBackground: strongSelf.continueInBackground))
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
                                    let reupload: Signal<[Api.FileHash], NoError> = masterDownload.request(Api.functions.upload.reuploadCdnFile(fileToken: Buffer(data: fileToken), requestToken: Buffer(data: token)), tag: nil, continueInBackground: strongSelf.continueInBackground)
                                    |> `catch` { _ -> Signal<[Api.FileHash], NoError> in
                                        return .single([])
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
            }))
        }
    }
}

public func standaloneMultipartFetch(postbox: Postbox, network: Network, resource: TelegramMediaResource, datacenterId: Int, size: Int64?, intervals: Signal<[(Range<Int64>, MediaBoxFetchPriority)], NoError>, parameters: MediaResourceFetchParameters?, encryptionKey: SecretFileEncryptionKey? = nil, decryptedSize: Int32? = nil, continueInBackground: Bool = false, useMainConnection: Bool = false) -> Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError> {
    return multipartFetch(
        postbox: postbox,
        network: network,
        mediaReferenceRevalidationContext: nil,
        resource: resource,
        datacenterId: datacenterId,
        size: size,
        intervals: intervals,
        parameters: parameters,
        useMainConnection: useMainConnection
    )
}

public func resourceFetchInfo(resource: TelegramMediaResource) -> MediaResourceFetchInfo? {
    return TelegramCloudMediaResourceFetchInfo(
        reference: MediaResourceReference.standalone(resource: resource),
        preferBackgroundReferenceRevalidation: false,
        continueInBackground: false
    )
}

func multipartFetch(postbox: Postbox, network: Network, mediaReferenceRevalidationContext: MediaReferenceRevalidationContext?, resource: TelegramMediaResource, datacenterId: Int, size: Int64?, intervals: Signal<[(Range<Int64>, MediaBoxFetchPriority)], NoError>, parameters: MediaResourceFetchParameters?, encryptionKey: SecretFileEncryptionKey? = nil, decryptedSize: Int64? = nil, continueInBackground: Bool = false, useMainConnection: Bool = false) -> Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError> {
    return Signal { subscriber in
        let location: MultipartFetchMasterLocation
        if let resource = resource as? MediaResourceWithWebFileReference {
            location = .web(Int32(datacenterId), resource.apiInputLocation)
        } else {
            location = .generic(Int32(datacenterId), { resource, resourceReference, fileReference in
                if let resource = resource as? TelegramCloudMediaResource {
                    if let location = resource.apiInputLocation(fileReference: fileReference) {
                        return .location(location)
                    } else {
                        return .none
                    }
                } else if let resource = resource as? CloudPeerPhotoSizeMediaResource {
                    guard let info = parameters?.info as? TelegramCloudMediaResourceFetchInfo else {
                        return .none
                    }
                    switch resourceReference ?? info.reference {
                        case let .avatar(peer, _):
                            if let location = resource.apiInputLocation(peerReference: peer) {
                                return .location(location)
                            } else {
                                return .revalidate
                            }
                        case .messageAuthorAvatar:
                            return .revalidate
                        default:
                            return .none
                    }
                } else if let resource = resource as? CloudStickerPackThumbnailMediaResource {
                    guard let info = parameters?.info as? TelegramCloudMediaResourceFetchInfo else {
                        return .none
                    }
                    switch info.reference {
                        case let .stickerPackThumbnail(stickerPack, _):
                            if let location = resource.apiInputLocation(packReference: stickerPack) {
                                return .location(location)
                            } else {
                                return .revalidate
                            }
                        default:
                            return .none
                    }
                } else {
                    return .none
                }
            })
        }
        
        if encryptionKey != nil {
            subscriber.putNext(.reset)
        }
        
        let manager = MultipartFetchManager(resource: resource, parameters: parameters, size: size, intervals: intervals, encryptionKey: encryptionKey, decryptedSize: decryptedSize, location: location, postbox: postbox, network: network, revalidationContext: mediaReferenceRevalidationContext, partReady: { dataOffset, data in
            subscriber.putNext(.dataPart(resourceOffset: dataOffset, data: data, range: 0 ..< Int64(data.count), complete: false))
        }, reportCompleteSize: { size in
            subscriber.putNext(.resourceSizeUpdated(size))
            subscriber.putCompletion()
        }, finishWithError: { error in
            subscriber.putError(error)
        }, useMainConnection: useMainConnection)
        
        manager.start()
        
        var managerRef: MultipartFetchManager? = manager
        
        return ActionDisposable {
            managerRef?.cancel()
            managerRef = nil
        }
    }
}
