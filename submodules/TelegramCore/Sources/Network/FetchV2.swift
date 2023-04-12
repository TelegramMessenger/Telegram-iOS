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
    
    private enum FetchLocation {
        case datacenter(Int)
        case cdn(CdnData)
    }
    
    private final class FetchingState {
        let fetchLocation: FetchLocation
        let partSize: Int64
        let minPartSize: Int64
        let maxPartSize: Int64
        let partAlignment: Int64
        let partDivision: Int64
        let maxPendingParts: Int
        
        var pendingParts: [PendingPart] = []
        var completedRanges = RangeSet<Int64>()
        var nextRangePriorityIndex: Int = 0
        
        init(
            fetchLocation: FetchLocation,
            partSize: Int64,
            minPartSize: Int64,
            maxPartSize: Int64,
            partAlignment: Int64,
            partDivision: Int64,
            maxPendingParts: Int
        ) {
            self.fetchLocation = fetchLocation
            self.partSize = partSize
            self.minPartSize = minPartSize
            self.maxPartSize = maxPartSize
            self.partAlignment = partAlignment
            self.partDivision = partDivision
            self.maxPendingParts = maxPendingParts
        }
        
        deinit {
            for peindingPart in self.pendingParts {
                peindingPart.disposable?.dispose()
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
        
        private var state: State?
        
        private let loggingIdentifier: String
        
        init(
            queue: Queue,
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
            |> deliverOn(self.queue)).start(next: { [weak self] intervals in
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
        }
        
        private func update() {
            if self.state == nil {
                Logger.shared.log("FetchV2", "\(self.loggingIdentifier): initializing to .datacenter(\(self.datacenterId))")
                
                self.state = .fetching(FetchingState(
                    fetchLocation: .datacenter(self.datacenterId),
                    partSize: 128 * 1024,
                    minPartSize: 4 * 1024,
                    maxPartSize: 1 * 1024 * 1024,
                    partAlignment: 4 * 1024,
                    partDivision: 1 * 1024 * 1024,
                    maxPendingParts: 6
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
                    
                    excludedInHigherPriorities.subtract(filteredRequiredRanges[i])
                }
                
                /*for _ in 0 ..< 1000000 {
                    let i = Int64.random(in: 0 ..< 1024 * 1024 + 500 * 1024)
                    let j = Int64.random(in: 1 ... state.partSize)
                    
                    let firstRange: Range<Int64> = Int64(i) ..< (Int64(i) + j)
                    
                    let partRange = firstRange.lowerBound ..< min(firstRange.upperBound, firstRange.lowerBound + state.partSize)
                    
                    let _ = alignPartFetchRange(
                        partRange: partRange,
                        minPartSize: state.minPartSize,
                        maxPartSize: state.maxPartSize,
                        alignment: state.partAlignment,
                        boundaryLimit: state.partDivision
                    )
                }*/
                
                if state.pendingParts.count < state.maxPendingParts {
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
                    
                    while state.pendingParts.count < state.maxPendingParts {
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
                            
                            Logger.shared.log("FetchV2", "\(self.loggingIdentifier): take part \(partRange) (aligned as \(alignedRange))")
                            
                            let pendingPart = PendingPart(
                                partRange: partRange,
                                fetchRange: alignedRange
                            )
                            state.pendingParts.append(pendingPart)
                            filteredRequiredRanges[priorityIndex].remove(contentsOf: partRange)
                            
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
            case let .reuploadingToCdn(state):
                if state.disposable == nil {
                    Logger.shared.log("FetchV2", "\(self.loggingIdentifier): refreshing CDN")
                    
                    let reuploadSignal = self.network.multiplexedRequestManager.request(
                        to: .main(state.cdnData.sourceDatacenterId),
                        consumerId: self.consumerId,
                        data: Api.functions.upload.reuploadCdnFile(
                            fileToken: Buffer(data: state.cdnData.fileToken),
                            requestToken: Buffer(data: state.refreshToken)
                        ),
                        tag: nil,
                        continueInBackground: self.continueInBackground
                    )
                    
                    let cdnData = state.cdnData
                    
                    state.disposable = (reuploadSignal
                    |> deliverOn(self.queue)).start(next: { [weak self] result in
                        guard let `self` = self else {
                            return
                        }
                        self.state = .fetching(FetchImpl.FetchingState(
                            fetchLocation: .cdn(cdnData),
                            partSize: 128 * 1024,
                            minPartSize: 4 * 1024,
                            maxPartSize: 128 * 1024,
                            partAlignment: 4 * 1024,
                            partDivision: 1 * 1024 * 1024,
                            maxPendingParts: 6
                        ))
                        self.update()
                    }, error: { [weak self] error in
                        guard let `self` = self else {
                            return
                        }
                        self.state = .failed
                    })
                }
            case let .refreshingFileReference(state):
                if state.disposable == nil {
                    Logger.shared.log("FetchV2", "\(self.loggingIdentifier): refreshing file reference")
                    
                    if let info = self.parameters?.info as? TelegramCloudMediaResourceFetchInfo, let mediaReferenceRevalidationContext = self.mediaReferenceRevalidationContext {
                        let fetchLocation = state.fetchLocation
                        
                        state.disposable = (revalidateMediaResourceReference(
                            postbox: self.postbox,
                            network: self.network,
                            revalidationContext: mediaReferenceRevalidationContext,
                            info: info,
                            resource: self.resource
                        )
                        |> deliverOn(self.queue)).start(next: { [weak self] validationResult in
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
                                partSize: 128 * 1024,
                                minPartSize: 4 * 1024,
                                maxPartSize: 128 * 1024,
                                partAlignment: 4 * 1024,
                                partDivision: 1 * 1024 * 1024,
                                maxPendingParts: 6
                            ))
                            
                            self.update()
                        }, error: { [weak self] _ in
                            guard let `self` = self else {
                                return
                            }
                            self.state = .failed
                            self.update()
                        })
                    }
                }
            case .failed:
                break
            }
        }
        
        private func fetchPart(state: FetchingState, part: PendingPart) {
            if part.disposable != nil {
                return
            }
            
            enum FilePartResult {
                case data(Data)
                case cdnRedirect(CdnData)
                case cdnRefresh(cdnData: CdnData, refreshToken: Data)
                case fileReferenceExpired
                case failure
            }
            
            let partRange = part.partRange
            let fetchRange = part.fetchRange
            let requestedLength = part.fetchRange.upperBound - part.fetchRange.lowerBound
            
            var filePartRequest: Signal<FilePartResult, NoError>?
            switch state.fetchLocation {
            case let .cdn(cdnData):
                let requestedOffset = part.fetchRange.lowerBound
                filePartRequest = self.network.multiplexedRequestManager.request(
                    to: .cdn(cdnData.id),
                    consumerId: self.consumerId,
                    data: Api.functions.upload.getCdnFile(
                        fileToken: Buffer(data: cdnData.fileToken),
                        offset: requestedOffset,
                        limit: Int32(requestedLength)
                    ),
                    tag: self.parameters?.tag,
                    continueInBackground: self.continueInBackground
                )
                |> map { result -> FilePartResult in
                    switch result {
                    case let .cdnFile(bytes):
                        if bytes.size == 0 {
                            return .data(Data())
                        } else {
                            var partIv = cdnData.encryptionIv
                            let partIvCount = partIv.count
                            partIv.withUnsafeMutableBytes { rawBytes -> Void in
                                let bytes = rawBytes.baseAddress!.assumingMemoryBound(to: UInt8.self)
                                var ivOffset: Int32 = Int32(clamping: (requestedOffset / 16)).bigEndian
                                memcpy(bytes.advanced(by: partIvCount - 4), &ivOffset, 4)
                            }
                            //TODO:check hashes
                            return .data(MTAesCtrDecrypt(bytes.makeData(), cdnData.encryptionKey, partIv)!)
                        }
                    case let .cdnFileReuploadNeeded(requestToken):
                        return .cdnRefresh(cdnData: cdnData, refreshToken: requestToken.makeData())
                    }
                }
                |> `catch` { _ -> Signal<FilePartResult, NoError> in
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
                        filePartRequest = self.network.multiplexedRequestManager.request(
                            to: .main(sourceDatacenterId),
                            consumerId: self.consumerId,
                            data: Api.functions.upload.getFile(
                                flags: 0,
                                location: inputLocation,
                                offset: part.fetchRange.lowerBound,
                                limit: Int32(requestedLength)),
                            tag: self.parameters?.tag,
                            continueInBackground: self.continueInBackground
                        )
                        |> map { result -> FilePartResult in
                            switch result {
                            case let .file(_, _, bytes):
                                return .data(bytes.makeData())
                            case let .fileCdnRedirect(dcId, fileToken, encryptionKey, encryptionIv, fileHashes):
                                let _ = fileHashes
                                return .cdnRedirect(CdnData(
                                    id: Int(dcId),
                                    sourceDatacenterId: sourceDatacenterId,
                                    fileToken: fileToken.makeData(),
                                    encryptionKey: encryptionKey.makeData(),
                                    encryptionIv: encryptionIv.makeData()
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
                
            if let filePartRequest = filePartRequest {
                part.disposable = (filePartRequest
                |> deliverOn(self.queue)).start(next: { [weak self, weak state, weak part] result in
                    guard let `self` = self, let state = state, case let .fetching(fetchingState) = self.state, fetchingState === state else {
                        return
                    }
                    
                    if let part = part {
                        if let index = state.pendingParts.firstIndex(where: { $0 === part }) {
                            state.pendingParts.remove(at: index)
                        }
                    }
                    
                    switch result {
                    case let .data(data):
                        let actualLength = Int64(data.count)
                        
                        var isComplete = false
                        if actualLength < requestedLength {
                            isComplete = true
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
                            Logger.shared.log("FetchV2", "\(self.loggingIdentifier): emitting data part \(partRange) (aligned as \(fetchRange)): \(actualData.count), isComplete: \(isComplete)")
                            
                            self.onNext(.dataPart(
                                resourceOffset: partRange.lowerBound,
                                data: actualData,
                                range: 0 ..< Int64(actualData.count),
                                complete: isComplete
                            ))
                        } else {
                            Logger.shared.log("FetchV2", "\(self.loggingIdentifier): not emitting data part \(partRange) (aligned as \(fetchRange))")
                        }
                    case let .cdnRedirect(cdnData):
                        self.state = .fetching(FetchImpl.FetchingState(
                            fetchLocation: .cdn(cdnData),
                            partSize: 128 * 1024,
                            minPartSize: 4 * 1024,
                            maxPartSize: 128 * 1024,
                            partAlignment: 4 * 1024,
                            partDivision: 1 * 1024 * 1024,
                            maxPendingParts: 6
                        ))
                    case let .cdnRefresh(cdnData, refreshToken):
                        self.state = .reuploadingToCdn(ReuploadingToCdnState(
                            cdnData: cdnData,
                            refreshToken: refreshToken
                        ))
                    case .fileReferenceExpired:
                        self.state = .refreshingFileReference(RefreshingFileReferenceState(fetchLocation: fetchingState.fetchLocation))
                    case .failure:
                        self.state = .failed
                    }
                    
                    self.update()
                })
            } else {
                //assertionFailure()
            }
        }
    }
    
    private static let sharedQueue = Queue(name: "FetchImpl")
    
    private let queue: Queue
    private let impl: QueueLocalObject<Impl>
    
    
    
    init(
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
