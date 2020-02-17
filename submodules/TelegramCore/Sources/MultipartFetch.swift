import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

import SyncCore

private typealias SignalKitTimer = SwiftSignalKit.Timer

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
    
    func transform(offset: Int, data: Data) -> Data {
        if self.aesKey.count != 0 {
            var decryptedData = data
            assert(decryptedSize != nil)
            assert(decryptedData.count % 16 == 0)
            let decryptedDataCount = decryptedData.count
            assert(offset == Int(self.currentSize))
            decryptedData.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<UInt8>) -> Void in
                self.aesIv.withUnsafeMutableBytes { (iv: UnsafeMutablePointer<UInt8>) -> Void in
                    MTAesDecryptBytesInplaceAndModifyIv(bytes, decryptedDataCount, self.aesKey, iv)
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
    case revalidateMediaReference
    case hashesMissing
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
    private let continueInBackground: Bool
    
    private var knownUpperBound: Int32
    private var hashes: [Int32: Data] = [:]
    private var requestOffsetAndDisposable: (Int32, Disposable)?
    private var requestedUpperBound: Int32?
    
    private var subscribers = Bag<(Int32, Int32, ([Int32: Data]) -> Void)>()
    
    init(queue: Queue, fileToken: Data, hashes: [Int32: Data], masterDownload: DownloadWrapper, continueInBackground: Bool) {
        assert(queue.isCurrent())
        
        self.queue = queue
        self.fileToken = fileToken
        self.masterDownload = masterDownload
        self.continueInBackground = continueInBackground
        
        let knownUpperBound: Int32 = 0
        /*self.hashes = hashes
        for (offset, _) in hashes {
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
        disposable.set((self.masterDownload.request(Api.functions.upload.getCdnFileHashes(fileToken: Buffer(data: fileToken), offset: requestOffset), tag: nil, continueInBackground: self.continueInBackground)
        |> map { partHashes -> [Int32: Data] in
            var parsedPartHashes: [Int32: Data] = [:]
            for part in partHashes {
                switch part {
                    case let .fileHash(offset, limit, bytes):
                        assert(limit == 128 * 1024)
                        parsedPartHashes[offset] = bytes.makeData()
                }
            }
            return parsedPartHashes
        }
        |> `catch` { _ -> Signal<[Int32: Data], NoError> in
            return .single([:])
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
                    //assertionFailure()
                }
            }
        }))
    }
}

private enum MultipartFetchSource {
    case none
    case master(location: MultipartFetchMasterLocation, download: DownloadWrapper)
    case cdn(masterDatacenterId: Int32, fileToken: Data, key: Data, iv: Data, download: DownloadWrapper, masterDownload: DownloadWrapper, hashSource: MultipartCdnHashSource)
    
    func request(offset: Int32, limit: Int32, tag: MediaResourceFetchTag?, resource: TelegramMediaResource, resourceReference: MediaResourceReference?, fileReference: Data?, continueInBackground: Bool) -> Signal<Data, MultipartFetchDownloadError> {
        switch self {
            case .none:
                return .never()
            case let .master(location, download):
                assert(limit % 4096 == 0)
                assert(1048576 % limit == 0)
                
                switch location {
                    case let .generic(_, location):
                        switch location(resource, resourceReference, fileReference) {
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
                                            var parsedPartHashes: [Int32: Data] = [:]
                                            for part in partHashes {
                                                switch part {
                                                    case let .fileHash(offset, limit, bytes):
                                                        assert(limit == 128 * 1024)
                                                        parsedPartHashes[offset] = bytes.makeData()
                                                }
                                            }
                                            return .fail(.switchToCdn(id: dcId, token: fileToken.makeData(), key: encryptionKey.makeData(), iv: encryptionIv.makeData(), partHashes: parsedPartHashes))
                                    }
                                }
                        }
                    case let .web(_, location):
                        return download.request(Api.functions.upload.getWebFile(location: location, offset: offset, limit: Int32(limit)), tag: tag, continueInBackground: continueInBackground)
                        |> mapError { error -> MultipartFetchDownloadError in
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
            case let .cdn(masterDatacenterId, fileToken, key, iv, download, _, hashSource):
                var updatedLength = roundUp(Int(limit), to: 4096)
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
                                partIv.withUnsafeMutableBytes { (bytes: UnsafeMutablePointer<Int8>) -> Void in
                                    var ivOffset: Int32 = (offset / 16).bigEndian
                                    memcpy(bytes.advanced(by: partIvCount - 4), &ivOffset, 4)
                                }
                                return .single(MTAesCtrDecrypt(bytes.makeData(), key, partIv))
                            }
                    }
                }
                
                return combineLatest(part, hashSource.get(offset: offset, limit: limit))
                    |> mapToSignal { partData, hashData -> Signal<Data, MultipartFetchDownloadError> in
                        var localOffset = 0
                        while localOffset < partData.count {
                            let dataToHash = partData.subdata(in: localOffset ..< min(partData.count, localOffset + Int(dataHashLength)))
                            if let hash = hashData[offset + Int32(localOffset)] {
                                let localHash = MTSha256(dataToHash)
                                if localHash != hash {
                                    return .fail(.generic)
                                }
                            } else {
                                return .fail(.generic)
                            }
                            
                            localOffset += Int(dataHashLength)
                        }
                        return .single(partData)
                    }
        }
    }
}

private final class MultipartFetchManager {
    let parallelParts: Int
    let defaultPartSize = 128 * 1024
    var partAlignment = 4 * 1024
    
    var resource: TelegramMediaResource
    var resourceReference: MediaResourceReference?
    var fileReference: Data?
    let parameters: MediaResourceFetchParameters?
    let consumerId: Int64
    
    let queue = Queue()
    
    var currentIntervals: [(Range<Int>, MediaBoxFetchPriority)]?
    var currentFilledRanges = IndexSet()
    
    var completeSize: Int?
    var completeSizeReported = false
    
    let postbox: Postbox
    let network: Network
    let revalidationContext: MediaReferenceRevalidationContext
    let continueInBackground: Bool
    let partReady: (Int, Data) -> Void
    let reportCompleteSize: (Int) -> Void
    
    private var source: MultipartFetchSource
    
    var fetchingParts: [Int: (Int, Disposable)] = [:]
    var nextFetchingPartId = 0
    var fetchedParts: [Int: (Int, Data)] = [:]
    var cachedPartHashes: [Int: Data] = [:]
    
    var reuploadingToCdn = false
    let reuploadToCdnDisposable = MetaDisposable()
    
    var revalidatedMediaReference = false
    var revalidatingMediaReference = false
    let revalidateMediaReferenceDisposable = MetaDisposable()
    
    var state: MultipartDownloadState
    
    var rangesDisposable: Disposable?
    
    init(resource: TelegramMediaResource, parameters: MediaResourceFetchParameters?, size: Int?, intervals: Signal<[(Range<Int>, MediaBoxFetchPriority)], NoError>, encryptionKey: SecretFileEncryptionKey?, decryptedSize: Int32?, location: MultipartFetchMasterLocation, postbox: Postbox, network: Network, revalidationContext: MediaReferenceRevalidationContext, partReady: @escaping (Int, Data) -> Void, reportCompleteSize: @escaping (Int) -> Void) {
        self.resource = resource
        self.parameters = parameters
        self.consumerId = arc4random64()
        
        self.completeSize = size
        if let _ = size {
            self.parallelParts = 4
        } else {
            self.parallelParts = 1
        }
        
        if let info = parameters?.info as? TelegramCloudMediaResourceFetchInfo {
            self.fileReference = info.reference.apiFileReference
            self.continueInBackground = info.continueInBackground
            self.resourceReference = info.reference
        } else {
            self.continueInBackground = false
            self.resourceReference = nil
        }
        
        self.state = MultipartDownloadState(encryptionKey: encryptionKey, decryptedSize: decryptedSize)
        self.postbox = postbox
        self.network = network
        self.revalidationContext = revalidationContext
        self.source = .master(location: location, download: DownloadWrapper(consumerId: self.consumerId, datacenterId: location.datacenterId, isCdn: false, network: network))
        self.partReady = partReady
        self.reportCompleteSize = reportCompleteSize
        
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
    }
    
    deinit {
        let rangesDisposable = self.rangesDisposable
        self.queue.async {
            rangesDisposable?.dispose()
        }
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
    
    func checkState() {
        guard let currentIntervals = self.currentIntervals else {
            return
        }
        
        var removeFromFetchIntervals = self.currentFilledRanges
        
        let isSingleContiguousRange = currentIntervals.count == 1
        for offset in self.fetchedParts.keys.sorted() {
            if let (_, data) = self.fetchedParts[offset] {
                let partRange = offset ..< (offset + data.count)
                removeFromFetchIntervals.insert(integersIn: partRange)
                
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
                    self.currentFilledRanges.insert(integersIn: partRange)
                    self.fetchedParts.removeValue(forKey: offset)
                    self.partReady(offset, self.state.transform(offset: offset, data: data))
                }
            }
        }
        
        for (offset, (size, _)) in self.fetchingParts {
            removeFromFetchIntervals.insert(integersIn: offset ..< (offset + size))
        }
        
        if let completeSize = self.completeSize {
            self.currentFilledRanges.insert(integersIn: completeSize ..< Int.max)
            removeFromFetchIntervals.insert(integersIn: completeSize ..< Int.max)
        }
        
        var intervalsToFetch: [(Range<Int>, MediaBoxFetchPriority)] = []
        for (interval, priority) in currentIntervals {
            var intervalIndexSet = IndexSet(integersIn: interval)
            intervalIndexSet.subtract(removeFromFetchIntervals)
            for cleanInterval in intervalIndexSet.rangeView {
                assert(!cleanInterval.isEmpty)
                intervalsToFetch.append((cleanInterval, priority))
            }
        }
        
        if let completeSize = self.completeSize {
            if intervalsToFetch.isEmpty && self.fetchingParts.isEmpty && !self.completeSizeReported {
                self.completeSizeReported = true
                assert(self.fetchedParts.isEmpty)
                if let decryptedSize = self.state.decryptedSize {
                    self.reportCompleteSize(Int(decryptedSize))
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
            var downloadRange: Range<Int> = firstInterval.lowerBound ..< min(firstInterval.lowerBound + self.defaultPartSize, firstInterval.upperBound)
            let rawRange: Range<Int> = downloadRange
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
            
            var intervalIndexSet = IndexSet(integersIn: intervalsToFetch[currentIntervalIndex].0)
            intervalIndexSet.remove(integersIn: downloadRange)
            intervalsToFetch.remove(at: currentIntervalIndex)
            var insertIndex = currentIntervalIndex
            for interval in intervalIndexSet.rangeView {
                intervalsToFetch.insert((interval, priority), at: insertIndex)
                insertIndex += 1
            }
            
            let part = self.source.request(offset: Int32(downloadRange.lowerBound), limit: Int32(downloadRange.count), tag: self.parameters?.tag, resource: self.resource, resourceReference: self.resourceReference, fileReference: self.fileReference, continueInBackground: self.continueInBackground)
            |> deliverOn(self.queue)
            let partDisposable = MetaDisposable()
            self.fetchingParts[downloadRange.lowerBound] = (downloadRange.count, partDisposable)
            
            partDisposable.set(part.start(next: { [weak self] data in
                guard let strongSelf = self else {
                    return
                }
                var data = data
                if data.count < downloadRange.count {
                    strongSelf.completeSize = downloadRange.lowerBound + data.count
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
                    case .revalidateMediaReference:
                        if !strongSelf.revalidatingMediaReference && !strongSelf.revalidatedMediaReference {
                            strongSelf.revalidatingMediaReference = true
                            if let info = strongSelf.parameters?.info as? TelegramCloudMediaResourceFetchInfo {
                                strongSelf.revalidateMediaReferenceDisposable.set((revalidateMediaResourceReference(postbox: strongSelf.postbox, network: strongSelf.network, revalidationContext: strongSelf.revalidationContext, info: info, resource: strongSelf.resource)
                                |> deliverOn(strongSelf.queue)).start(next: { validationResult in
                                    if let strongSelf = self {
                                        strongSelf.revalidatingMediaReference = false
                                        strongSelf.revalidatedMediaReference = true
                                        if let validatedResource = validationResult.updatedResource as? TelegramCloudMediaResourceWithFileReference, let reference = validatedResource.fileReference {
                                            strongSelf.fileReference = reference
                                        }
                                        strongSelf.resource = validationResult.updatedResource
                                        strongSelf.resourceReference = validationResult.updatedReference
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
                                strongSelf.partAlignment = Int(dataHashLength)
                                strongSelf.source = .cdn(masterDatacenterId: location.datacenterId, fileToken: token, key: key, iv: iv, download: DownloadWrapper(consumerId: strongSelf.consumerId, datacenterId: id, isCdn: true, network: strongSelf.network), masterDownload: download, hashSource: MultipartCdnHashSource(queue: strongSelf.queue, fileToken: token, hashes: partHashes, masterDownload: download, continueInBackground: strongSelf.continueInBackground))
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

func multipartFetch(postbox: Postbox, network: Network, mediaReferenceRevalidationContext: MediaReferenceRevalidationContext, resource: TelegramMediaResource, datacenterId: Int, size: Int?, intervals: Signal<[(Range<Int>, MediaBoxFetchPriority)], NoError>, parameters: MediaResourceFetchParameters?, encryptionKey: SecretFileEncryptionKey? = nil, decryptedSize: Int32? = nil, continueInBackground: Bool = false) -> Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError> {
    return Signal { subscriber in
        let location: MultipartFetchMasterLocation
        if let resource = resource as? WebFileReferenceMediaResource {
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
                                return .none
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
                                return .none
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
            subscriber.putNext(.dataPart(resourceOffset: dataOffset, data: data, range: 0 ..< data.count, complete: false))
        }, reportCompleteSize: { size in
            subscriber.putNext(.resourceSizeUpdated(size))
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
