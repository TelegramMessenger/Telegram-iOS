import Foundation
import Postbox
import SwiftSignalKit
import MtProtoKit
import RangeSet
import TelegramApi

private let possiblePartLengths: [Int64] = [1, 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048, 4096, 8192, 16384, 32768, 65536, 131072, 262144, 524288, 1048576]

private func alignPartFetchRange(partRange: Range<Int64>, minPartSize: Int64, maxPartSize: Int64, alignment: Int64, boundaryLimit: Int64) -> (partRange: Range<Int64>, fetchRange: Range<Int64>) {
    var partRange = partRange
    
    let lowerPartitionIndex = partRange.lowerBound / boundaryLimit
    let upperPartitionIndex = (partRange.upperBound - 1) / boundaryLimit
    if lowerPartitionIndex != upperPartitionIndex {
        partRange = partRange.lowerBound ..< (upperPartitionIndex * boundaryLimit)
    }
    
    let absolutePartLowerBound = (partRange.lowerBound / boundaryLimit) * boundaryLimit
    let absolutePartUpperBound = absolutePartLowerBound + boundaryLimit
    let maxPartRange = absolutePartLowerBound ..< absolutePartUpperBound
    
    let alignedPartLowerBound = (partRange.lowerBound / alignment) * alignment
    let alignmentDifference = partRange.lowerBound - alignedPartLowerBound
    if (partRange.upperBound - alignmentDifference) > partRange.lowerBound {
        partRange = partRange.lowerBound ..< (partRange.upperBound - alignmentDifference)
    }
    
    var selectedPartLength: Int64?
    if minPartSize == maxPartSize {
        assert(possiblePartLengths.contains(minPartSize))
        selectedPartLength = minPartSize
    } else {
        for partLength in possiblePartLengths {
            if partLength >= minPartSize && partLength <= maxPartSize && partLength >= partRange.upperBound - alignedPartLowerBound {
                selectedPartLength = partLength
                break
            }
        }
    }
    
    guard let fetchPartLength = selectedPartLength else {
        preconditionFailure()
    }
    
    var fetchRange = alignedPartLowerBound ..< (alignedPartLowerBound + fetchPartLength)
    
    if fetchRange.upperBound > maxPartRange.upperBound {
        fetchRange = (maxPartRange.upperBound - fetchPartLength) ..< maxPartRange.upperBound
    }
    
    assert(fetchRange.lowerBound >= maxPartRange.lowerBound)
    assert(fetchRange.lowerBound % alignment == 0)
    assert(possiblePartLengths.contains(fetchRange.upperBound - fetchRange.lowerBound))
    assert(fetchRange.lowerBound <= partRange.lowerBound && fetchRange.upperBound >= partRange.upperBound)
    assert(fetchRange.lowerBound / boundaryLimit == (fetchRange.upperBound - 1) / boundaryLimit)
    
    return (partRange, fetchRange)
}

private let fastDownloadMasterPendingParts = 16
private let fastDownloadCdnPendingParts = 32
private let fastDownloadInitialWindow = 6
private let fastDownloadMinWindow = 2
private let fastDownloadFastPartLatency = 1.0
private let fastDownloadSlowPartLatency = 2.0
private let fastDownloadSmallPartSize: Int64 = 128 * 1024
private let fastDownloadLargePartSize: Int64 = 512 * 1024
private let fastDownloadLargePartThroughput: Double = 4.0 * 1024.0 * 1024.0
private let fastDownloadSmallPartThroughput: Double = 1.5 * 1024.0 * 1024.0
private let maxCdnFailuresBeforeFallback = 4
private let maxCdnReuploadsPerBlock = 3
private let maxCdnTokenRefreshes = 3

func cdnRedirectKeyMaterialIsValid(encryptionKey: Data, encryptionIv: Data) -> Bool {
    return encryptionKey.count == 32 && encryptionIv.count == 16
}

private let cdnHashBlockLength: Int64 = 128 * 1024

func cdnPartLengthIsAcceptable(offset: Int64, requestedLength: Int64, receivedLength: Int64, knownSize: Int64?) -> Bool {
    if receivedLength > requestedLength {
        return false
    }
    if let knownSize {
        if offset + receivedLength > knownSize {
            return false
        }
        return receivedLength == requestedLength || offset + receivedLength == knownSize
    }
    if receivedLength == requestedLength {
        return true
    }
    return (offset + receivedLength) % cdnHashBlockLength != 0
}

private final class FetchImpl {
    private final class PendingPart {
        let partRange: Range<Int64>
        let fetchRange: Range<Int64>
        var disposable: Disposable?
        
        init(
            partRange: Range<Int64>,
            fetchRange: Range<Int64>
        ) {
            self.partRange = partRange
            self.fetchRange = fetchRange
        }
        
        deinit {
            self.disposable?.dispose()
        }
    }
    
    private final class PendingReadyPart {
        let partRange: Range<Int64>
        let fetchRange: Range<Int64>
        let fetchedData: Data
        let cleanData: Data
        
        init(
            partRange: Range<Int64>,
            fetchRange: Range<Int64>,
            fetchedData: Data,
            cleanData: Data
        ) {
            self.partRange = partRange
            self.fetchRange = fetchRange
            self.fetchedData = fetchedData
            self.cleanData = cleanData
        }
    }
    
    private final class PendingHashRange {
        let range: Range<Int64>
        var disposable: Disposable?
        
        init(range: Range<Int64>) {
            self.range = range
        }
        
        deinit {
            self.disposable?.dispose()
        }
    }
    
    private final class PendingCdnReupload {
        let block: Int64
        var ranges: RangeSet<Int64>
        var disposable: Disposable?
        
        init(block: Int64, range: Range<Int64>) {
            self.block = block
            self.ranges = RangeSet<Int64>(range)
        }
        
        deinit {
            self.disposable?.dispose()
        }
    }
    
    private final class HashRangeData {
        let range: Range<Int64>
        let data: Data
        
        init(range: Range<Int64>, data: Data) {
            self.range = range
            self.data = data
        }
    }
    
    private final class CdnData {
        let id: Int
        let sourceDatacenterId: Int
        let fileToken: Data
        let encryptionKey: Data
        let encryptionIv: Data
        
        init(
            id: Int,
            sourceDatacenterId: Int,
            fileToken: Data,
            encryptionKey: Data,
            encryptionIv: Data
        ) {
            self.id = id
            self.sourceDatacenterId = sourceDatacenterId
            self.fileToken = fileToken
            self.encryptionKey = encryptionKey
            self.encryptionIv = encryptionIv
        }
    }
    
    private final class VerifyPartHashData {
        let fetchRange: Range<Int64>
        let fetchedData: Data
        
        init(fetchRange: Range<Int64>, fetchedData: Data) {
            self.fetchRange = fetchRange
            self.fetchedData = fetchedData
        }
    }
    
    private enum FetchLocation {
        case datacenter(Int)
        case cdn(CdnData)
    }
    
    private final class DecryptionState {
        let aesKey: Data
        var aesIv: Data
        let decryptedSize: Int64
        var offset: Int = 0
        
        init(aesKey: Data, aesIv: Data, decryptedSize: Int64) {
            self.aesKey = aesKey
            self.aesIv = aesIv
            self.decryptedSize = decryptedSize
        }
        
        func tryDecrypt(data: Data, offset: Int, loggingIdentifier: String) -> Data? {
            if offset == self.offset {
                var decryptedData = data
                if self.decryptedSize == 0 {
                    Logger.shared.log("FetchV2", "\(loggingIdentifier): not decrypting part \(offset) ..< \(offset + data.count) (decryptedSize == 0)")
                    return nil
                }
                if self.aesKey.count != 32 || self.aesIv.count != 32 {
                    Logger.shared.log("FetchV2", "\(loggingIdentifier): not decrypting part \(offset) ..< \(offset + data.count) (invalid key/iv length: key=\(self.aesKey.count) iv=\(self.aesIv.count))")
                    return nil
                }
                if decryptedData.count % 16 != 0 {
                    Logger.shared.log("FetchV2", "\(loggingIdentifier): not decrypting part \(offset) ..< \(offset + data.count) (decryptedData.count % 16 != 0)")
                }
                let decryptedDataCount = decryptedData.count
                decryptedData.withUnsafeMutableBytes { rawBytes -> Void in
                    let bytes = rawBytes.baseAddress!.assumingMemoryBound(to: UInt8.self)
                    self.aesIv.withUnsafeMutableBytes { rawIv -> Void in
                        let iv = rawIv.baseAddress!.assumingMemoryBound(to: UInt8.self)
                        MTAesDecryptBytesInplaceAndModifyIv(bytes, decryptedDataCount, self.aesKey, iv)
                    }
                }
                if self.offset + decryptedData.count > self.decryptedSize {
                    decryptedData.count = Int(self.decryptedSize) - self.offset
                }
                self.offset += decryptedData.count
                Logger.shared.log("FetchV2", "\(loggingIdentifier): decrypted part \(offset) ..< \(offset + data.count) (new offset is \(self.offset))")
                return decryptedData
            } else {
                return nil
            }
        }
    }
    
    private final class FetchingState {
        let fetchLocation: FetchLocation
        var partSize: Int64
        let minPartSize: Int64
        let maxPartSize: Int64
        let partAlignment: Int64
        let partDivision: Int64
        let maxPendingParts: Int
        
        var pendingParts: [PendingPart] = []
        var completedRanges = RangeSet<Int64>()
        
        var decryptionState: DecryptionState?
        var pendingReadyParts: [PendingReadyPart] = []
        var completedHashRanges = RangeSet<Int64>()
        var pendingHashRanges: [PendingHashRange] = []
        var hashRanges: [Int64: HashRangeData] = [:]
        var pendingCdnReuploads: [PendingCdnReupload] = []
        var window: Int = fastDownloadInitialWindow
        var lastWindowDecrease: Double = 0.0
        var recentParts: [(time: Double, bytes: Int64)] = []
        
        var nextRangePriorityIndex: Int = 0
        
        init(
            fetchLocation: FetchLocation,
            partSize: Int64,
            minPartSize: Int64,
            maxPartSize: Int64,
            partAlignment: Int64,
            partDivision: Int64,
            maxPendingParts: Int,
            decryptionState: DecryptionState?
        ) {
            self.fetchLocation = fetchLocation
            self.partSize = partSize
            self.minPartSize = minPartSize
            self.maxPartSize = maxPartSize
            self.partAlignment = partAlignment
            self.partDivision = partDivision
            self.maxPendingParts = maxPendingParts
            self.decryptionState = decryptionState
        }
        
        deinit {
            for pendingPart in self.pendingParts {
                pendingPart.disposable?.dispose()
            }
            for pendingHashRange in self.pendingHashRanges {
                pendingHashRange.disposable?.dispose()
            }
            for pendingCdnReupload in self.pendingCdnReuploads {
                pendingCdnReupload.disposable?.dispose()
            }
        }
    }
    
    private final class ReuploadingToCdnState {
        let cdnData: CdnData
        let refreshToken: Data
        var disposable: Disposable?
        
        init(cdnData: CdnData, refreshToken: Data) {
            self.cdnData = cdnData
            self.refreshToken = refreshToken
        }
        
        deinit {
            self.disposable?.dispose()
        }
    }
    
    private final class RefreshingFileReferenceState {
        let fetchLocation: FetchLocation
        var disposable: Disposable?
        
        init(
            fetchLocation: FetchLocation
        ) {
            self.fetchLocation = fetchLocation
        }
        
        deinit {
            self.disposable?.dispose()
        }
    }
    
    private enum State {
        case fetching(FetchingState)
        case reuploadingToCdn(ReuploadingToCdnState)
        case refreshingFileReference(RefreshingFileReferenceState)
        case failed
    }
    
    private struct RequiredRange: Equatable {
        let value: Range<Int64>
        let priority: MediaBoxFetchPriority
        
        init(
            value: Range<Int64>,
            priority: MediaBoxFetchPriority
        ) {
            self.value = value
            self.priority = priority
        }
    }
    
    private final class Impl {
        private let queue: Queue
        
        private let accountPeerId: PeerId
        private let postbox: Postbox
        private let network: Network
        private let mediaReferenceRevalidationContext: MediaReferenceRevalidationContext?
        private var resource: TelegramMediaResource
        private let datacenterId: Int
        private let size: Int64?
        private let parameters: MediaResourceFetchParameters?
        private let encryptionKey: SecretFileEncryptionKey?
        private let decryptedSize: Int64?
        private let continueInBackground: Bool
        private let useMainConnection: Bool
        private let onNext: (MediaResourceDataFetchResult) -> Void
        private let onError: (MediaResourceDataFetchError) -> Void
        
        private let consumerId: Int64
        
        private var knownSize: Int64?
        private var didReportKnownSize: Bool = false
        private var updatedFileReference: Data?
        
        private var requiredRangesDisposable: Disposable?
        private var requiredRanges: [RequiredRange] = []
        
        private let defaultPartSize: Int64
        private let cdnPartSize: Int64
        private let fastDownloads: Bool
        private let masterPendingParts: Int
        private let cdnPendingParts: Int
        private var cdnDisabled: Bool = false
        private var cdnHashFailures: Int = 0
        private var cdnVerificationFailures: Int = 0
        private var cdnTokenRefreshes: Int = 0
        private var cdnReuploadCounts: [Int64: Int] = [:]
        private var cdnReuploadGenerations: [Int64: Int] = [:]
        private var state: State?
        private var reportedFailure = false
        
        private let loggingIdentifier: String
        
        init(
            queue: Queue,
            accountPeerId: PeerId,
            postbox: Postbox,
            network: Network,
            mediaReferenceRevalidationContext: MediaReferenceRevalidationContext?,
            resource: TelegramMediaResource,
            datacenterId: Int,
            size: Int64?,
            intervals: Signal<[(Range<Int64>, MediaBoxFetchPriority)], NoError>,
            parameters: MediaResourceFetchParameters?,
            encryptionKey: SecretFileEncryptionKey?,
            decryptedSize: Int64?,
            continueInBackground: Bool,
            useMainConnection: Bool,
            onNext: @escaping (MediaResourceDataFetchResult) -> Void,
            onError: @escaping (MediaResourceDataFetchError) -> Void
        ) {
            self.queue = queue
            
            self.accountPeerId = accountPeerId
            self.postbox = postbox
            self.network = network
            self.mediaReferenceRevalidationContext = mediaReferenceRevalidationContext
            self.resource = resource
            self.datacenterId = datacenterId
            self.size = size
            self.parameters = parameters
            self.encryptionKey = encryptionKey
            self.decryptedSize = decryptedSize
            self.continueInBackground = continueInBackground
            self.useMainConnection = useMainConnection
            
            self.onNext = onNext
            self.onError = onError
            
            self.consumerId = Int64.random(in: Int64.min ... Int64.max)
            
            self.knownSize = size
            
            /*#if DEBUG
            self.updatedFileReference = Data()
            #endif*/
            
            var isStory = false
            if let info = parameters?.info as? TelegramCloudMediaResourceFetchInfo {
                switch info.reference {
                case let .media(media, _):
                    if case .story = media {
                        isStory = true
                    }
                default:
                    break
                }
            }
            
            self.fastDownloads = network.engineKind == .rust
            if isStory {
                self.defaultPartSize = 512 * 1024
            } else {
                self.defaultPartSize = 128 * 1024
            }
            self.cdnPartSize = 128 * 1024
            self.masterPendingParts = self.fastDownloads ? fastDownloadMasterPendingParts : 6
            self.cdnPendingParts = self.fastDownloads ? fastDownloadCdnPendingParts : 6
            
            if let resource = resource as? TelegramCloudMediaResource {
                if let apiInputLocation = resource.apiInputLocation(fileReference: Data()) {
                    self.loggingIdentifier = "\(apiInputLocation)"
                } else {
                    self.loggingIdentifier = "unknown cloud"
                }
            } else {
                self.loggingIdentifier = "unknown"
            }
            
            self.update()
            
            self.requiredRangesDisposable = (intervals
            |> deliverOn(self.queue)).startStrict(next: { [weak self] intervals in
                guard let `self` = self else {
                    return
                }
                let requiredRanges = intervals.map { RequiredRange(value: $0.0, priority: $0.1) }
                if self.requiredRanges != requiredRanges {
                    self.requiredRanges = requiredRanges
                    self.update()
                }
            })
        }
        
        deinit {
            self.requiredRangesDisposable?.dispose()
        }
        
        private func update() {
            if self.state == nil {
                Logger.shared.log("FetchV2", "\(self.loggingIdentifier): initializing to .datacenter(\(self.datacenterId))")
                
                var decryptionState: DecryptionState?
                if let encryptionKey = self.encryptionKey, let decryptedSize = self.decryptedSize {
                    decryptionState = DecryptionState(aesKey: encryptionKey.aesKey, aesIv: encryptionKey.aesIv, decryptedSize: decryptedSize)
                    self.onNext(.reset)
                }
                
                self.state = .fetching(FetchingState(
                    fetchLocation: .datacenter(self.datacenterId),
                    partSize: self.defaultPartSize,
                    minPartSize: 4 * 1024,
                    maxPartSize: 1 * 1024 * 1024,
                    partAlignment: 4 * 1024,
                    partDivision: 1 * 1024 * 1024,
                    maxPendingParts: self.masterPendingParts,
                    decryptionState: decryptionState
                ))
            }
            guard let state = self.state else {
                return
            }
            
            switch state {
            case let .fetching(state):
                if let knownSize = self.knownSize, !self.didReportKnownSize {
                    self.didReportKnownSize = true
                    self.onNext(.resourceSizeUpdated(knownSize))
                }
                
                do {
                    var removedPendingReadyPartIndices: [Int] = []
                    if let decryptionState = state.decryptionState {
                        while true {
                            var removedSomePendingReadyPart = false
                            for i in 0 ..< state.pendingReadyParts.count {
                                if removedPendingReadyPartIndices.contains(i) {
                                    continue
                                }
                                let pendingReadyPart = state.pendingReadyParts[i]
                                if let resultData = decryptionState.tryDecrypt(data: pendingReadyPart.cleanData, offset: Int(pendingReadyPart.fetchRange.lowerBound), loggingIdentifier: self.loggingIdentifier) {
                                    removedPendingReadyPartIndices.append(i)
                                    removedSomePendingReadyPart = true
                                    self.commitPendingReadyPart(state: state, partRange: pendingReadyPart.partRange, fetchRange: pendingReadyPart.fetchRange, data: resultData)
                                }
                            }
                            if !removedSomePendingReadyPart {
                                break
                            }
                        }
                    } else {
                        for i in 0 ..< state.pendingReadyParts.count {
                            let pendingReadyPart = state.pendingReadyParts[i]
                            if state.completedHashRanges.isSuperset(of: RangeSet<Int64>(pendingReadyPart.fetchRange)) {
                                removedPendingReadyPartIndices.append(i)
                                
                                var checkOffset: Int64 = 0
                                var checkFailed = false
                                while checkOffset < pendingReadyPart.fetchedData.count {
                                    if let hashRange = state.hashRanges[pendingReadyPart.fetchRange.lowerBound + checkOffset] {
                                        var clippedHashRange = hashRange.range
                                        
                                        if pendingReadyPart.fetchRange.lowerBound + Int64(pendingReadyPart.fetchedData.count) < clippedHashRange.lowerBound {
                                            Logger.shared.log("FetchV2", "\(self.loggingIdentifier): unable to check \(pendingReadyPart.fetchRange): data range \(clippedHashRange) out of bounds (0 ..< \(pendingReadyPart.fetchedData.count))")
                                            checkFailed = true
                                            break
                                        }
                                        clippedHashRange = clippedHashRange.lowerBound ..< min(clippedHashRange.upperBound, pendingReadyPart.fetchRange.lowerBound + Int64(pendingReadyPart.fetchedData.count))
                                        
                                        let partLocalHashRange = (clippedHashRange.lowerBound - pendingReadyPart.fetchRange.lowerBound) ..< (clippedHashRange.upperBound - pendingReadyPart.fetchRange.lowerBound)
                                        
                                        if partLocalHashRange.lowerBound < 0 || partLocalHashRange.upperBound > pendingReadyPart.fetchedData.count {
                                            Logger.shared.log("FetchV2", "\(self.loggingIdentifier): unable to check \(pendingReadyPart.fetchRange): data range \(partLocalHashRange) out of bounds (0 ..< \(pendingReadyPart.fetchedData.count))")
                                            checkFailed = true
                                            break
                                        }
                                        
                                        let dataToHash = pendingReadyPart.cleanData.subdata(in: Int(partLocalHashRange.lowerBound) ..< Int(partLocalHashRange.upperBound))
                                        let localHash = MTSha256(dataToHash)
                                        if localHash != hashRange.data {
                                            Logger.shared.log("FetchV2", "\(self.loggingIdentifier): failed to verify \(pendingReadyPart.fetchRange): hash mismatch")
                                            checkFailed = true
                                            break
                                        }
                                        
                                        checkOffset += partLocalHashRange.upperBound - partLocalHashRange.lowerBound
                                    } else {
                                        Logger.shared.log("FetchV2", "\(self.loggingIdentifier): unable to find \(pendingReadyPart.fetchRange) hash range despite it being marked as ready")
                                        checkFailed = true
                                        break
                                    }
                                }
                                if !checkFailed {
                                    self.commitPendingReadyPart(state: state, partRange: pendingReadyPart.partRange, fetchRange: pendingReadyPart.fetchRange, data: pendingReadyPart.cleanData)
                                } else {
                                    Logger.shared.log("FetchV2", "\(self.loggingIdentifier): unable to find \(pendingReadyPart.fetchRange) hash check failed")
                                    if self.fastDownloads {
                                        self.cdnVerificationFailures += 1
                                    }
                                }
                            }
                        }
                    }
                    for index in removedPendingReadyPartIndices.sorted(by: >) {
                        state.pendingReadyParts.remove(at: index)
                    }
                }
                
                if self.fastDownloads, self.cdnVerificationFailures >= maxCdnFailuresBeforeFallback, case let .cdn(cdnData) = state.fetchLocation {
                    self.fallBackToMaster(sourceDatacenterId: cdnData.sourceDatacenterId, reason: "\(self.cdnVerificationFailures) parts failed hash verification")
                    self.update()
                    return
                }
                
                var requiredHashRanges = RangeSet<Int64>()
                for pendingReadyPart in state.pendingReadyParts {
                    //TODO:check if already have hashes
                    if state.decryptionState == nil {
                        requiredHashRanges.formUnion(RangeSet<Int64>(pendingReadyPart.fetchRange))
                    }
                }
                requiredHashRanges.subtract(state.completedHashRanges)
                for pendingHashRange in state.pendingHashRanges {
                    requiredHashRanges.subtract(RangeSet<Int64>(pendingHashRange.range))
                }
                
                let expectedHashRangeLength: Int64 = 1 * 1024 * 1024
                while state.pendingHashRanges.count < state.maxPendingParts {
                    guard let requiredHashRange = requiredHashRanges.ranges.first else {
                        break
                    }
                    let hashRange: Range<Int64> = requiredHashRange.lowerBound ..< (requiredHashRange.lowerBound + expectedHashRangeLength)
                    requiredHashRanges.subtract(RangeSet<Int64>(hashRange))
                    
                    state.pendingHashRanges.append(FetchImpl.PendingHashRange(range: hashRange))
                }
                
                var filteredRequiredRanges: [RangeSet<Int64>] = []
                for _ in 0 ..< 3 {
                    filteredRequiredRanges.append(RangeSet<Int64>())
                }
                
                for range in self.requiredRanges {
                    filteredRequiredRanges[Int(range.priority.rawValue)].formUnion(RangeSet<Int64>(range.value))
                }
                var excludedInHigherPriorities = RangeSet<Int64>()
                for i in (0 ..< filteredRequiredRanges.count).reversed() {
                    if let knownSize = self.knownSize {
                        for i in 0 ..< filteredRequiredRanges.count {
                            filteredRequiredRanges[i].remove(contentsOf: knownSize ..< Int64.max)
                        }
                    }
                    filteredRequiredRanges[i].subtract(excludedInHigherPriorities)
                    filteredRequiredRanges[i].subtract(state.completedRanges)
                    for pendingPart in state.pendingParts {
                        filteredRequiredRanges[i].remove(contentsOf: pendingPart.partRange)
                    }
                    for pendingReadyPart in state.pendingReadyParts {
                        filteredRequiredRanges[i].remove(contentsOf: pendingReadyPart.partRange)
                    }
                    for pendingCdnReupload in state.pendingCdnReuploads {
                        filteredRequiredRanges[i].subtract(pendingCdnReupload.ranges)
                    }
                    
                    excludedInHigherPriorities.subtract(filteredRequiredRanges[i])
                }
                
                var maxPendingParts = state.maxPendingParts
                if self.fastDownloads {
                    maxPendingParts = min(maxPendingParts, state.window)
                }
                if self.knownSize == nil && state.completedRanges.isEmpty {
                    maxPendingParts = 1
                }
                
                if state.pendingParts.count < maxPendingParts && state.pendingReadyParts.count < state.maxPendingParts {
                    var debugRangesString = ""
                    for priorityIndex in 0 ..< 3 {
                        if filteredRequiredRanges[priorityIndex].isEmpty {
                            continue
                        }
                        
                        if !debugRangesString.isEmpty {
                            debugRangesString.append(", ")
                        }
                        debugRangesString.append("priority: \(priorityIndex): [")
                        
                        var isFirst = true
                        for range in filteredRequiredRanges[priorityIndex].ranges {
                            if isFirst {
                                isFirst = false
                            } else {
                                debugRangesString.append(", ")
                            }
                            debugRangesString.append("\(range.lowerBound)..<\(range.upperBound)")
                        }
                        debugRangesString.append("]")
                    }
                    
                    if !debugRangesString.isEmpty {
                        Logger.shared.log("FetchV2", "\(self.loggingIdentifier): will fetch \(debugRangesString)")
                    }
                    
                    while state.pendingParts.count < maxPendingParts && state.pendingReadyParts.count < state.maxPendingParts {
                        var found = false
                        inner: for i in 0 ..< filteredRequiredRanges.count {
                            let priorityIndex = (state.nextRangePriorityIndex + i) % filteredRequiredRanges.count
                            
                            guard let firstRange = filteredRequiredRanges[priorityIndex].ranges.first else {
                                continue
                            }
                            
                            state.nextRangePriorityIndex += 1
                            
                            let (partRange, alignedRange) = alignPartFetchRange(
                                partRange: firstRange.lowerBound ..< min(firstRange.upperBound, firstRange.lowerBound + state.partSize),
                                minPartSize: state.minPartSize,
                                maxPartSize: state.maxPartSize,
                                alignment: state.partAlignment,
                                boundaryLimit: state.partDivision
                            )
                            
                            var storePartRange = partRange
                            do {
                                storePartRange = alignedRange
                                Logger.shared.log("FetchV2", "\(self.loggingIdentifier): take part \(partRange) (store aligned as \(storePartRange)")
                            }
                            /*if case .cdn = state.fetchLocation {
                                storePartRange = alignedRange
                                Logger.shared.log("FetchV2", "\(self.loggingIdentifier): take part \(partRange) (store aligned as \(storePartRange)")
                            } else {
                                Logger.shared.log("FetchV2", "\(self.loggingIdentifier): take part \(partRange) (aligned as \(alignedRange))")
                            }*/
                            
                            let pendingPart = PendingPart(
                                partRange: storePartRange,
                                fetchRange: alignedRange
                            )
                            state.pendingParts.append(pendingPart)
                            filteredRequiredRanges[priorityIndex].remove(contentsOf: storePartRange)
                            
                            found = true
                            break inner
                        }
                        if !found {
                            break
                        }
                    }
                }
                
                for pendingPart in state.pendingParts {
                    if pendingPart.disposable == nil {
                        self.fetchPart(state: state, part: pendingPart)
                    }
                }
                for pendingHashRange in state.pendingHashRanges {
                    if pendingHashRange.disposable == nil {
                        self.fetchHashRange(state: state, hashRange: pendingHashRange)
                    }
                }
            case let .reuploadingToCdn(state):
                if state.disposable == nil {
                    Logger.shared.log("FetchV2", "\(self.loggingIdentifier): refreshing CDN")
                    
                    let reuploadSignal = self.network.multiplexedRequestManager.request(
                        to: .main(state.cdnData.sourceDatacenterId),
                        consumerId: self.consumerId,
                        resourceId: self.resource.id.stringRepresentation,
                        data: Api.functions.upload.reuploadCdnFile(
                            fileToken: Buffer(data: state.cdnData.fileToken),
                            requestToken: Buffer(data: state.refreshToken)
                        ),
                        tag: nil,
                        continueInBackground: self.continueInBackground,
                        expectedResponseSize: nil
                    )
                    
                    let cdnData = state.cdnData
                    
                    state.disposable = (reuploadSignal
                    |> deliverOn(self.queue)).startStrict(next: { [weak self] result in
                        guard let `self` = self else {
                            return
                        }
                        self.state = .fetching(FetchImpl.FetchingState(
                            fetchLocation: .cdn(cdnData),
                            partSize: self.cdnPartSize,
                            minPartSize: self.cdnPartSize,
                            maxPartSize: self.cdnPartSize * 2,
                            partAlignment: self.cdnPartSize,
                            partDivision: 1 * 1024 * 1024,
                            maxPendingParts: self.cdnPendingParts,
                            decryptionState: nil
                        ))
                        self.update()
                    }, error: { [weak self] error in
                        guard let `self` = self else {
                            return
                        }
                        self.state = .failed
                        self.update()
                    })
                }
            case let .refreshingFileReference(state):
                if state.disposable == nil {
                    Logger.shared.log("FetchV2", "\(self.loggingIdentifier): refreshing file reference")
                    
                    if let info = self.parameters?.info as? TelegramCloudMediaResourceFetchInfo, let mediaReferenceRevalidationContext = self.mediaReferenceRevalidationContext {
                        let fetchLocation = state.fetchLocation
                        
                        state.disposable = (revalidateMediaResourceReference(
                            accountPeerId: self.accountPeerId,
                            postbox: self.postbox,
                            network: self.network,
                            revalidationContext: mediaReferenceRevalidationContext,
                            info: info,
                            resource: self.resource
                        )
                        |> deliverOn(self.queue)).startStrict(next: { [weak self] validationResult in
                            guard let `self` = self else {
                                return
                            }
                            
                            if let validatedResource = validationResult.updatedResource as? TelegramCloudMediaResourceWithFileReference, let reference = validatedResource.fileReference {
                                self.updatedFileReference = reference
                            }
                            self.resource = validationResult.updatedResource
                            
                            /*if let reference = validationResult.updatedReference {
                             strongSelf.resourceReference = .reference(reference)
                             } else {
                             strongSelf.resourceReference = .empty
                             }*/
                            
                            self.state = .fetching(FetchingState(
                                fetchLocation: fetchLocation,
                                partSize: self.defaultPartSize,
                                minPartSize: 4 * 1024,
                                maxPartSize: self.defaultPartSize,
                                partAlignment: 4 * 1024,
                                partDivision: 1 * 1024 * 1024,
                                maxPendingParts: self.masterPendingParts,
                                decryptionState: nil
                            ))
                            
                            self.update()
                        }, error: { [weak self] _ in
                            guard let `self` = self else {
                                return
                            }
                            self.state = .failed
                            self.update()
                        })
                    } else {
                        Logger.shared.log("FetchV2", "\(self.loggingIdentifier): no way to refresh the file reference")
                        self.state = .failed
                        self.update()
                    }
                }
            case .failed:
                if !self.reportedFailure {
                    self.reportedFailure = true
                    Logger.shared.log("FetchV2", "\(self.loggingIdentifier): failed")
                    self.onError(.generic)
                }
            }
        }
        
        private func fetchPart(state: FetchingState, part: PendingPart) {
            if part.disposable != nil {
                return
            }
            
            enum FilePartResult {
                case data(data: Data, verifyPartHashData: VerifyPartHashData?)
                case cdnRedirect(CdnData)
                case cdnRefresh(cdnData: CdnData, refreshToken: Data)
                case cdnFailure(sourceDatacenterId: Int, error: String)
                case fileReferenceExpired
                case failure
            }
            
            let partRange = part.partRange
            let fetchRange = part.fetchRange
            let requestedLength = part.fetchRange.upperBound - part.fetchRange.lowerBound
            let cdnBlock = fetchRange.lowerBound / (1 * 1024 * 1024)
            let cdnReuploadGeneration = self.cdnReuploadGenerations[cdnBlock] ?? 0
            
            var filePartRequest: Signal<FilePartResult, NoError>?
            switch state.fetchLocation {
            case let .cdn(cdnData):
                let requestedOffset = part.fetchRange.lowerBound
                
                filePartRequest = self.network.multiplexedRequestManager.request(
                    to: .cdn(cdnData.id),
                    consumerId: self.consumerId,
                    resourceId: self.resource.id.stringRepresentation,
                    data: Api.functions.upload.getCdnFile(
                        fileToken: Buffer(data: cdnData.fileToken),
                        offset: requestedOffset,
                        limit: Int32(requestedLength)
                    ),
                    tag: self.parameters?.tag,
                    continueInBackground: self.continueInBackground,
                    expectedResponseSize: Int32(requestedLength)
                )
                |> map { result -> FilePartResult in
                    switch result {
                    case let .cdnFile(cdnFileData):
                        let bytes = cdnFileData.bytes
                        if bytes.size == 0 {
                            return .data(data: Data(), verifyPartHashData: nil)
                        } else {
                            var partIv = cdnData.encryptionIv
                            let partIvCount = partIv.count
                            partIv.withUnsafeMutableBytes { rawBytes -> Void in
                                let bytes = rawBytes.baseAddress!.assumingMemoryBound(to: UInt8.self)
                                var ivOffset: Int32 = Int32(clamping: (requestedOffset / 16)).bigEndian
                                memcpy(bytes.advanced(by: partIvCount - 4), &ivOffset, 4)
                            }
                            
                            let fetchedData = bytes.makeData()
                            guard let decryptedData = MTAesCtrDecrypt(fetchedData, cdnData.encryptionKey, partIv) else {
                                return .failure
                            }
                            return .data(
                                data: decryptedData,
                                verifyPartHashData: VerifyPartHashData(fetchRange: fetchRange, fetchedData: fetchedData)
                            )
                        }
                    case let .cdnFileReuploadNeeded(cdnFileReuploadNeededData):
                        let requestToken = cdnFileReuploadNeededData.requestToken
                        return .cdnRefresh(cdnData: cdnData, refreshToken: requestToken.makeData())
                    }
                }
                |> `catch` { [fastDownloads = self.fastDownloads] error -> Signal<FilePartResult, NoError> in
                    if fastDownloads {
                        return .single(.cdnFailure(sourceDatacenterId: cdnData.sourceDatacenterId, error: error.errorDescription ?? ""))
                    }
                    return .single(.failure)
                }
            case let .datacenter(sourceDatacenterId):
                if let cloudResource = self.resource as? TelegramCloudMediaResource {
                    var fileReference: Data?
                    if let updatedFileReference = self.updatedFileReference {
                        fileReference = updatedFileReference
                    } else if let info = self.parameters?.info as? TelegramCloudMediaResourceFetchInfo {
                        fileReference = info.reference.apiFileReference
                    }
                    if let inputLocation = cloudResource.apiInputLocation(fileReference: fileReference) {
                        let queue = self.queue
                        filePartRequest = self.network.multiplexedRequestManager.request(
                            to: .main(sourceDatacenterId),
                            consumerId: self.consumerId,
                            resourceId: self.resource.id.stringRepresentation,
                            data: Api.functions.upload.getFile(
                                flags: self.fastDownloads && !self.cdnDisabled ? (1 << 1) : 0,
                                location: inputLocation,
                                offset: part.fetchRange.lowerBound,
                                limit: Int32(requestedLength)),
                            tag: self.parameters?.tag,
                            continueInBackground: self.continueInBackground,
                            onFloodWaitError: { [weak self] error in
                                queue.async {
                                    guard let self else {
                                        return
                                    }
                                    self.processFloodWaitError(error: error)
                                }
                            }, expectedResponseSize: Int32(requestedLength)
                        )
                        |> map { result -> FilePartResult in
                            switch result {
                            case let .file(fileData):
                                let bytes = fileData.bytes
                                return .data(data: bytes.makeData(), verifyPartHashData: nil)
                            case let .fileCdnRedirect(fileCdnRedirectData):
                                let (dcId, fileToken, encryptionKey, encryptionIv, fileHashes) = (fileCdnRedirectData.dcId, fileCdnRedirectData.fileToken, fileCdnRedirectData.encryptionKey.makeData(), fileCdnRedirectData.encryptionIv.makeData(), fileCdnRedirectData.fileHashes)
                                let _ = fileHashes
                                if !cdnRedirectKeyMaterialIsValid(encryptionKey: encryptionKey, encryptionIv: encryptionIv) {
                                    return .cdnFailure(sourceDatacenterId: sourceDatacenterId, error: "CDN_REDIRECT_KEY_INVALID")
                                }
                                return .cdnRedirect(CdnData(
                                    id: Int(dcId),
                                    sourceDatacenterId: sourceDatacenterId,
                                    fileToken: fileToken.makeData(),
                                    encryptionKey: encryptionKey,
                                    encryptionIv: encryptionIv
                                ))
                            }
                        }
                        |> `catch` { error -> Signal<FilePartResult, NoError> in
                            if error.errorDescription.hasPrefix("FILEREF_INVALID") || error.errorDescription.hasPrefix("FILE_REFERENCE_")  {
                                return .single(.fileReferenceExpired)
                            } else {
                                return .single(.failure)
                            }
                        }
                    }
                }
            }
                
            if let filePartRequest {
                let requestStarted = CFAbsoluteTimeGetCurrent()
                part.disposable = (filePartRequest
                |> deliverOn(self.queue)).startStrict(next: { [weak self, weak state, weak part] result in
                    guard let self, let state, self.isCurrent(state) else {
                        return
                    }
                    
                    if let part {
                        if let index = state.pendingParts.firstIndex(where: { $0 === part }) {
                            state.pendingParts.remove(at: index)
                        }
                    }
                    
                    switch result {
                    case let .data(data, verifyPartHashData):
                        if case let .cdn(cdnData) = state.fetchLocation, !cdnPartLengthIsAcceptable(offset: fetchRange.lowerBound, requestedLength: requestedLength, receivedLength: Int64(data.count), knownSize: self.knownSize) {
                            self.fallBackToMaster(sourceDatacenterId: cdnData.sourceDatacenterId, reason: "\(data.count) of \(requestedLength) bytes at \(fetchRange.lowerBound), known size \(String(describing: self.knownSize))")
                            break
                        }
                        if self.fastDownloads {
                            self.adaptWindow(state: state, latency: CFAbsoluteTimeGetCurrent() - requestStarted, bytes: Int64(data.count))
                        }
                        if let verifyPartHashData {
                            Logger.shared.log("FetchV2", "\(self.loggingIdentifier): stashing data part \(partRange) (aligned as \(fetchRange)) for hash verification")
                            
                            state.pendingReadyParts.append(FetchImpl.PendingReadyPart(
                                partRange: partRange,
                                fetchRange: fetchRange,
                                fetchedData: verifyPartHashData.fetchedData,
                                cleanData: data
                            ))
                        } else if state.decryptionState != nil {
                            Logger.shared.log("FetchV2", "\(self.loggingIdentifier): stashing data part \(partRange) (aligned as \(fetchRange)) for decryption")
                            
                            state.pendingReadyParts.append(FetchImpl.PendingReadyPart(
                                partRange: partRange,
                                fetchRange: fetchRange,
                                fetchedData: data,
                                cleanData: data
                            ))
                        } else {
                            self.commitPendingReadyPart(
                                state: state,
                                partRange: partRange,
                                fetchRange: fetchRange,
                                data: data
                            )
                        }
                    case let .cdnRedirect(cdnData):
                        self.cdnReuploadCounts.removeAll()
                        self.cdnReuploadGenerations.removeAll()
                        let cdnState = FetchImpl.FetchingState(
                            fetchLocation: .cdn(cdnData),
                            partSize: self.cdnPartSize,
                            minPartSize: self.cdnPartSize,
                            maxPartSize: self.cdnPartSize * 2,
                            partAlignment: self.cdnPartSize,
                            partDivision: 1 * 1024 * 1024,
                            maxPendingParts: self.cdnPendingParts,
                            decryptionState: nil
                        )
                        if self.fastDownloads {
                            cdnState.completedRanges = state.completedRanges
                        }
                        self.state = .fetching(cdnState)
                    case let .cdnRefresh(cdnData, refreshToken):
                        if self.fastDownloads {
                            if (self.cdnReuploadGenerations[cdnBlock] ?? 0) <= cdnReuploadGeneration {
                                self.reuploadCdnPart(state: state, cdnData: cdnData, refreshToken: refreshToken, partRange: partRange)
                            }
                        } else {
                            self.state = .reuploadingToCdn(ReuploadingToCdnState(
                                cdnData: cdnData,
                                refreshToken: refreshToken
                            ))
                        }
                    case let .cdnFailure(sourceDatacenterId, error):
                        if error == "CDN_REDIRECT_KEY_INVALID" && self.cdnDisabled {
                            self.state = .failed
                            break
                        }
                        let tokenExpired = error == "FILE_TOKEN_INVALID" && self.cdnTokenRefreshes < maxCdnTokenRefreshes
                        if tokenExpired {
                            self.cdnTokenRefreshes += 1
                        }
                        self.fallBackToMaster(sourceDatacenterId: sourceDatacenterId, reason: error, allowRedirect: tokenExpired)
                    case .fileReferenceExpired:
                        self.state = .refreshingFileReference(RefreshingFileReferenceState(fetchLocation: state.fetchLocation))
                    case .failure:
                        self.state = .failed
                    }
                    
                    self.update()
                })
            } else {
                //assertionFailure()
            }
        }
        
        private func fetchHashRange(state: FetchingState, hashRange: PendingHashRange) {
            let fetchRequest: Signal<[Api.FileHash]?, NoError>
            
            switch state.fetchLocation {
            case let .cdn(cdnData):
                Logger.shared.log("FetchV2", "\(self.loggingIdentifier): will fetch hashes for \(hashRange.range)")
                
                fetchRequest = self.network.multiplexedRequestManager.request(
                    to: .main(cdnData.sourceDatacenterId),
                    consumerId: self.consumerId,
                    resourceId: self.resource.id.stringRepresentation,
                    data: Api.functions.upload.getCdnFileHashes(fileToken: Buffer(data: cdnData.fileToken), offset: hashRange.range.lowerBound),
                    tag: self.parameters?.tag,
                    continueInBackground: self.continueInBackground,
                    expectedResponseSize: nil
                )
                |> map(Optional.init)
                |> `catch` { _ -> Signal<[Api.FileHash]?, NoError> in
                    return .single(nil)
                }
            case .datacenter:
                fetchRequest = .single(nil)
            }
            
            let queue = self.queue
            hashRange.disposable?.dispose()
            hashRange.disposable = (fetchRequest
            |> deliverOn(self.queue)).startStrict(next: { [weak self, weak state, weak hashRange] result in
                queue.async {
                    guard let self, let state, self.isCurrent(state) else {
                        return
                    }
                    
                    if self.fastDownloads, case let .cdn(cdnData) = state.fetchLocation {
                        let filledRange = result.map { self.storeHashes($0, into: state) } ?? RangeSet<Int64>()
                        if let hashRange, let index = state.pendingHashRanges.firstIndex(where: { $0 === hashRange }) {
                            if filledRange.contains(hashRange.range.lowerBound) {
                                self.cdnHashFailures = 0
                                state.pendingHashRanges.remove(at: index)
                            } else {
                                self.cdnHashFailures += 1
                                if self.cdnHashFailures >= maxCdnFailuresBeforeFallback {
                                    self.fallBackToMaster(sourceDatacenterId: cdnData.sourceDatacenterId, reason: "no usable hashes for \(hashRange.range)")
                                    self.update()
                                    return
                                }
                                let delay = min(8.0, 0.5 * pow(2.0, Double(self.cdnHashFailures - 1)))
                                queue.after(delay, { [weak self, weak state, weak hashRange] in
                                    guard let self, let state, let hashRange, self.isCurrent(state) else {
                                        return
                                    }
                                    if let index = state.pendingHashRanges.firstIndex(where: { $0 === hashRange }) {
                                        state.pendingHashRanges.remove(at: index)
                                    }
                                    self.update()
                                })
                            }
                        }
                        self.update()
                        return
                    }
                    
                    if let result {
                        if let hashRange {
                            if let index = state.pendingHashRanges.firstIndex(where: { $0 === hashRange }) {
                                state.pendingHashRanges.remove(at: index)
                            }
                        }
                        
                        var filledRange = RangeSet<Int64>()
                        for hashItem in result {
                            switch hashItem {
                            case let .fileHash(fileHashData):
                                let (offset, limit, hash) = (fileHashData.offset, fileHashData.limit, fileHashData.hash)
                                let rangeValue: Range<Int64> = offset ..< (offset + Int64(limit))
                                filledRange.formUnion(RangeSet<Int64>(rangeValue))
                                state.hashRanges[rangeValue.lowerBound] = HashRangeData(
                                    range: rangeValue,
                                    data: hash.makeData()
                                )
                                state.completedHashRanges.formUnion(RangeSet<Int64>(rangeValue))
                            }
                        }
                        Logger.shared.log("FetchV2", "\(self.loggingIdentifier): received hashes for \(filledRange)")
                    }
                    
                    self.update()
                }
            })
        }
        
        private func adaptWindow(state: FetchingState, latency: Double, bytes: Int64) {
            let now = CFAbsoluteTimeGetCurrent()
            if latency > fastDownloadSlowPartLatency {
                if now - state.lastWindowDecrease > latency {
                    state.window = max(fastDownloadMinWindow, state.window / 2)
                    state.lastWindowDecrease = now
                }
            } else if latency < fastDownloadFastPartLatency {
                state.window = min(state.maxPendingParts, state.window + 1)
            }
            
            state.recentParts.append((now, bytes))
            state.recentParts.removeAll(where: { now - $0.time > 2.0 })
            guard case .datacenter = state.fetchLocation, state.recentParts.count >= 4 else {
                return
            }
            let span = max(0.25, now - state.recentParts[0].time)
            let throughput = Double(state.recentParts.reduce(Int64(0), { $0 + $1.bytes })) / span
            if throughput >= fastDownloadLargePartThroughput {
                state.partSize = min(state.maxPartSize, fastDownloadLargePartSize)
            } else if throughput < fastDownloadSmallPartThroughput {
                state.partSize = max(state.minPartSize, fastDownloadSmallPartSize)
            }
        }
        
        private func isCurrent(_ state: FetchingState) -> Bool {
            if case let .fetching(current) = self.state {
                return current === state
            }
            return false
        }
        
        private func reuploadCdnPart(state: FetchingState, cdnData: CdnData, refreshToken: Data, partRange: Range<Int64>) {
            let block = partRange.lowerBound / (1 * 1024 * 1024)
            if let existing = state.pendingCdnReuploads.first(where: { $0.block == block }) {
                existing.ranges.formUnion(RangeSet<Int64>(partRange))
                return
            }
            let attempts = (self.cdnReuploadCounts[block] ?? 0) + 1
            self.cdnReuploadCounts[block] = attempts
            if attempts > maxCdnReuploadsPerBlock {
                self.fallBackToMaster(sourceDatacenterId: cdnData.sourceDatacenterId, reason: "block \(block) still needs reupload after \(attempts - 1) reuploads")
                return
            }
            
            Logger.shared.log("FetchV2", "\(self.loggingIdentifier): reuploading CDN block \(block)")
            let reupload = PendingCdnReupload(block: block, range: partRange)
            state.pendingCdnReuploads.append(reupload)
            reupload.disposable = (self.network.multiplexedRequestManager.request(
                to: .main(cdnData.sourceDatacenterId),
                consumerId: self.consumerId,
                resourceId: self.resource.id.stringRepresentation,
                data: Api.functions.upload.reuploadCdnFile(
                    fileToken: Buffer(data: cdnData.fileToken),
                    requestToken: Buffer(data: refreshToken)
                ),
                tag: nil,
                continueInBackground: self.continueInBackground,
                expectedResponseSize: nil
            )
            |> deliverOn(self.queue)).startStrict(next: { [weak self, weak state, weak reupload] hashes in
                guard let self, let state, let reupload, self.isCurrent(state) else {
                    return
                }
                self.storeHashes(hashes, into: state)
                self.cdnReuploadGenerations[reupload.block, default: 0] += 1
                state.pendingCdnReuploads.removeAll(where: { $0 === reupload })
                self.update()
            }, error: { [weak self, weak state] error in
                guard let self, let state, self.isCurrent(state) else {
                    return
                }
                self.fallBackToMaster(sourceDatacenterId: cdnData.sourceDatacenterId, reason: "reupload failed: \(error.errorDescription ?? "")")
                self.update()
            })
        }
        
        @discardableResult
        private func storeHashes(_ hashes: [Api.FileHash], into state: FetchingState) -> RangeSet<Int64> {
            var filledRange = RangeSet<Int64>()
            for hashItem in hashes {
                switch hashItem {
                case let .fileHash(fileHashData):
                    let rangeValue: Range<Int64> = fileHashData.offset ..< (fileHashData.offset + Int64(fileHashData.limit))
                    if rangeValue.isEmpty {
                        continue
                    }
                    filledRange.formUnion(RangeSet<Int64>(rangeValue))
                    state.hashRanges[rangeValue.lowerBound] = HashRangeData(range: rangeValue, data: fileHashData.hash.makeData())
                    state.completedHashRanges.formUnion(RangeSet<Int64>(rangeValue))
                }
            }
            Logger.shared.log("FetchV2", "\(self.loggingIdentifier): received hashes for \(filledRange)")
            return filledRange
        }
        
        private func fallBackToMaster(sourceDatacenterId: Int, reason: String, allowRedirect: Bool = false) {
            Logger.shared.log("FetchV2", "\(self.loggingIdentifier): CDN unusable (\(reason)), downloading from datacenter \(sourceDatacenterId)")
            self.cdnDisabled = !allowRedirect
            let masterState = FetchingState(
                fetchLocation: .datacenter(sourceDatacenterId),
                partSize: self.defaultPartSize,
                minPartSize: 4 * 1024,
                maxPartSize: 1 * 1024 * 1024,
                partAlignment: 4 * 1024,
                partDivision: 1 * 1024 * 1024,
                maxPendingParts: self.masterPendingParts,
                decryptionState: nil
            )
            if case let .fetching(previous) = self.state {
                masterState.completedRanges = previous.completedRanges
            }
            self.state = .fetching(masterState)
        }
        
        private func commitPendingReadyPart(state: FetchingState, partRange: Range<Int64>, fetchRange: Range<Int64>, data: Data) {
            let requestedLength = fetchRange.upperBound - fetchRange.lowerBound
            let actualLength = Int64(data.count)
            
            if actualLength < requestedLength {
                let resultingSize = fetchRange.lowerBound + actualLength
                if let currentKnownSize = self.knownSize {
                    Logger.shared.log("FetchV2", "\(self.loggingIdentifier): setting known size to min(\(currentKnownSize), \(resultingSize)) = \(min(currentKnownSize, resultingSize))")
                    self.knownSize = min(currentKnownSize, resultingSize)
                } else {
                    Logger.shared.log("FetchV2", "\(self.loggingIdentifier): setting known size to \(resultingSize)")
                    self.knownSize = resultingSize
                }
                Logger.shared.log("FetchV2", "\(self.loggingIdentifier): reporting resource size \(resultingSize)")
                self.onNext(.resourceSizeUpdated(resultingSize))
            }
            
            state.completedRanges.formUnion(RangeSet<Int64>(partRange))
            
            var actualData = data
            if partRange != fetchRange {
                precondition(partRange.lowerBound >= fetchRange.lowerBound)
                precondition(partRange.upperBound <= fetchRange.upperBound)
                let innerOffset = partRange.lowerBound - fetchRange.lowerBound
                var innerLength = partRange.upperBound - partRange.lowerBound
                innerLength = min(innerLength, Int64(actualData.count - Int(innerOffset)))
                if innerLength > 0 {
                    actualData = actualData.subdata(in: Int(innerOffset) ..< Int(innerOffset + innerLength))
                } else {
                    actualData = Data()
                }
                
                Logger.shared.log("FetchV2", "\(self.loggingIdentifier): extracting aligned part \(partRange) (\(fetchRange)): \(actualData.count)")
            }
            
            if !actualData.isEmpty {
                Logger.shared.log("FetchV2", "\(self.loggingIdentifier): emitting data part \(partRange) (aligned as \(fetchRange)): \(actualData.count)")
                
                self.onNext(.dataPart(
                    resourceOffset: partRange.lowerBound,
                    data: actualData,
                    range: 0 ..< Int64(actualData.count),
                    complete: false
                ))
            } else {
                Logger.shared.log("FetchV2", "\(self.loggingIdentifier): not emitting data part \(partRange) (aligned as \(fetchRange))")
            }
        }
        
        private func processFloodWaitError(error: String) {
            var networkSpeedLimitSubject: NetworkSpeedLimitedEvent.DownloadSubject?
            if let location = self.parameters?.location {
                if let messageId = location.messageId {
                    networkSpeedLimitSubject = .message(messageId)
                }
            }
            if let subject = networkSpeedLimitSubject {
                if error.hasPrefix("FLOOD_PREMIUM_WAIT") {
                    self.network.addNetworkSpeedLimitedEvent(event: .download(subject))
                }
            }
        }
    }
    
    private static let sharedQueue = Queue(name: "FetchImpl")
    
    private let queue: Queue
    private let impl: QueueLocalObject<Impl>
    
    
    
    init(
        accountPeerId: PeerId,
        postbox: Postbox,
        network: Network,
        mediaReferenceRevalidationContext: MediaReferenceRevalidationContext?,
        resource: TelegramMediaResource,
        datacenterId: Int,
        size: Int64?,
        intervals: Signal<[(Range<Int64>, MediaBoxFetchPriority)], NoError>,
        parameters: MediaResourceFetchParameters?,
        encryptionKey: SecretFileEncryptionKey?,
        decryptedSize: Int64?,
        continueInBackground: Bool,
        useMainConnection: Bool,
        onNext: @escaping (MediaResourceDataFetchResult) -> Void,
        onError: @escaping (MediaResourceDataFetchError) -> Void
    ) {
        let queue = FetchImpl.sharedQueue
        self.queue = queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return Impl(
                queue: queue,
                accountPeerId: accountPeerId,
                postbox: postbox,
                network: network,
                mediaReferenceRevalidationContext: mediaReferenceRevalidationContext,
                resource: resource,
                datacenterId: datacenterId,
                size: size,
                intervals: intervals,
                parameters: parameters,
                encryptionKey: encryptionKey,
                decryptedSize: decryptedSize,
                continueInBackground: continueInBackground,
                useMainConnection: useMainConnection,
                onNext: onNext,
                onError: onError
            )
        })
    }
}

func multipartFetchV2(
    accountPeerId: PeerId,
    postbox: Postbox,
    network: Network,
    mediaReferenceRevalidationContext: MediaReferenceRevalidationContext?,
    resource: TelegramMediaResource,
    datacenterId: Int,
    size: Int64?,
    intervals: Signal<[(Range<Int64>, MediaBoxFetchPriority)], NoError>,
    parameters: MediaResourceFetchParameters?,
    encryptionKey: SecretFileEncryptionKey?,
    decryptedSize: Int64?,
    continueInBackground: Bool,
    useMainConnection: Bool
) -> Signal<MediaResourceDataFetchResult, MediaResourceDataFetchError> {
    return Signal { subscriber in
        let impl = FetchImpl(
            accountPeerId: accountPeerId,
            postbox: postbox,
            network: network,
            mediaReferenceRevalidationContext: mediaReferenceRevalidationContext,
            resource: resource,
            datacenterId: datacenterId,
            size: size,
            intervals: intervals,
            parameters: parameters,
            encryptionKey: encryptionKey,
            decryptedSize: decryptedSize,
            continueInBackground: continueInBackground,
            useMainConnection: useMainConnection,
            onNext: subscriber.putNext,
            onError: subscriber.putError
        )
        
        return ActionDisposable {
            withExtendedLifetime(impl, {
            })
        }
    }
}
