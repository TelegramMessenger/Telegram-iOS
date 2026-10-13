import Foundation
import SwiftSignalKit
import Postbox
internal import TelegramApi
import RangeSet

public enum MediaResourceUserContentType: UInt8, Equatable {
    case other = 0
    case image = 1
    case video = 2
    case audio = 3
    case file = 4
    case sticker = 6
    case avatar = 7
    case audioVideoMessage = 8
    case story = 9
}

public extension MediaResourceUserContentType {
    init(file: TelegramMediaFile) {
        if file.isInstantVideo || file.isVoice {
            self = .audioVideoMessage
        } else if file.isMusic {
            self = .audio
        } else if file.isSticker || file.isAnimatedSticker {
            self = .sticker
        } else if file.isCustomEmoji {
            self = .sticker
        } else if file.isVideo {
            if file.isAnimated {
                self = .other
            } else {
                self = .video
            }
        } else {
            self = .file
        }
    }
}

public extension MediaResourceFetchParameters {
    init(tag: MediaResourceFetchTag?, info: MediaResourceFetchInfo?, location: MediaResourceStorageLocation?, contentType: MediaResourceUserContentType, isRandomAccessAllowed: Bool) {
        self.init(tag: tag, info: info, location: location, contentType: contentType.rawValue, isRandomAccessAllowed: isRandomAccessAllowed)
    }
}

func bufferedFetch(_ signal: Signal<EngineMediaResource.Fetch.Result, EngineMediaResource.Fetch.Error>) -> Signal<EngineMediaResource.Fetch.Result, EngineMediaResource.Fetch.Error> {
    return Signal { subscriber in
        final class State {
            var data = Data()
            var isCompleted: Bool = false
            
            init() {
            }
        }
        
        let state = Atomic<State>(value: State())
        return signal.start(next: { value in
            switch value {
            case let .dataPart(_, data, _, _):
                let _ = state.with { state in
                    state.data.append(data)
                }
            case let .moveTempFile(file):
                let _ = state.with { state in
                    state.isCompleted = true
                }
                subscriber.putNext(.moveTempFile(file: file))
            case let .resourceSizeUpdated(size):
                if size == 0 {
                    let _ = state.with { state in
                        state.data.removeAll()
                        state.isCompleted = true
                    }
                    let tempFile = TempBox.shared.tempFile(fileName: "file")
                    let _ = try? Data().write(to: URL(fileURLWithPath: tempFile.path), options: .atomic)
                    subscriber.putNext(.moveTempFile(file: tempFile))
                    subscriber.putCompletion()
                }
            default:
                assert(false)
                break
            }
        }, error: { error in
            subscriber.putError(error)
        }, completed: {
            let tempFile = state.with { state -> TempBoxFile? in
                if state.isCompleted {
                    return nil
                } else {
                    let tempFile = TempBox.shared.tempFile(fileName: "data")
                    let _ = try? state.data.write(to: URL(fileURLWithPath: tempFile.path), options: .atomic)
                    return tempFile
                }
            }
            if let tempFile = tempFile {
                subscriber.putNext(.moveTempFile(file: tempFile))
            }
            subscriber.putCompletion()
        })
    }
}

public final class EngineMediaResource: Equatable {
    public enum CacheTimeout {
        case `default`
        case shortLived
    }

    public struct ByteRange {
        public enum Priority {
            case `default`
            case elevated
            case maximum
        }

        public var range: Range<Int>
        public var priority: Priority

        public init(range: Range<Int>, priority: Priority) {
            self.range = range
            self.priority = priority
        }
    }

    public final class Fetch {
        public enum Result {
            case dataPart(resourceOffset: Int64, data: Data, range: Range<Int64>, complete: Bool)
            case resourceSizeUpdated(Int64)
            case progressUpdated(Float)
            case replaceHeader(data: Data, range: Range<Int64>)
            case moveLocalFile(path: String)
            case moveTempFile(file: TempBoxFile)
            case copyLocalItem(MediaResourceDataFetchCopyLocalItem)
            case reset
        }

        public enum Error {
            case generic
        }

        public let signal: () -> Signal<Result, Error>

        public init(_ signal: @escaping () -> Signal<Result, Error>) {
            self.signal = signal
        }
    }

    public final class ResourceData {
        public let path: String
        public let availableSize: Int64
        public let isComplete: Bool

        public init(
            path: String,
            availableSize: Int64,
            isComplete: Bool
        ) {
            self.path = path
            self.availableSize = availableSize
            self.isComplete = isComplete
        }
    }

    public enum FetchStatus: Equatable {
        case Remote(progress: Float)
        case Local
        case Fetching(isActive: Bool, progress: Float)
        case Paused(progress: Float)
    }

    public struct Id: Equatable, Hashable {
        public var stringRepresentation: String

        public init(_ stringRepresentation: String) {
            self.stringRepresentation = stringRepresentation
        }

        public init(_ id: MediaResourceId) {
            self.stringRepresentation = id.stringRepresentation
        }
    }

    private let resource: MediaResource

    public init(_ resource: MediaResource) {
        self.resource = resource
    }

    public func _asResource() -> MediaResource {
        return self.resource
    }

    public var id: Id {
        return Id(self.resource.id)
    }

    public static func ==(lhs: EngineMediaResource, rhs: EngineMediaResource) -> Bool {
        return lhs.resource.isEqual(to: rhs.resource)
    }
}

/// A cached representation of a media resource (a derived file such as a scaled image or a
/// video's first frame). The kinds are defined by the app; TelegramCore only stores and serves
/// them, so it declares this protocol and never enumerates them.
public protocol EngineMediaResourceRepresentation: CachedMediaResourceRepresentation {
}

public extension EngineMediaResource.ResourceData {
    convenience init(_ data: MediaResourceData) {
        self.init(path: data.path, availableSize: data.size, isComplete: data.complete)
    }
}

public extension EngineMediaResource.FetchStatus {
    init(_ status: MediaResourceStatus) {
        switch status {
        case let .Remote(progress):
            self = .Remote(progress: progress)
        case .Local:
            self = .Local
        case let .Fetching(isActive, progress):
            self = .Fetching(isActive: isActive, progress: progress)
        case let .Paused(progress):
            self = .Paused(progress: progress)
        }
    }

    func _asStatus() -> MediaResourceStatus {
        switch self {
        case let .Remote(progress):
            return .Remote(progress: progress)
        case .Local:
            return .Local
        case let .Fetching(isActive, progress):
            return .Fetching(isActive: isActive, progress: progress)
        case let .Paused(progress):
            return .Paused(progress: progress)
        }
    }
}

public extension TelegramEngine {
    final class Resources {
        private let account: Account

        init(account: Account) {
            self.account = account
        }

        @discardableResult
        public func preUpload(id: Int64, encrypt: Bool, tag: MediaResourceFetchTag?, source: Signal<EngineMediaResource.ResourceData, NoError>, onComplete: (()->Void)? = nil) -> Disposable {
            return self.account.messageMediaPreuploadManager.add(network: self.account.network, postbox: self.account.postbox, id: id, encrypt: encrypt, tag: tag, source: source, onComplete: onComplete)
        }

        public func collectCacheUsageStats(peerId: PeerId? = nil, additionalCachePaths: [String] = [], logFilesPath: String? = nil) -> Signal<CacheUsageStatsResult, NoError> {
            return _internal_collectCacheUsageStats(account: self.account, peerId: peerId, additionalCachePaths: additionalCachePaths, logFilesPath: logFilesPath)
        }
        
        public func collectStorageUsageStats() -> Signal<AllStorageUsageStats, NoError> {
            return _internal_collectStorageUsageStats(account: self.account)
        }

        public func renderStorageUsageStatsMessages(stats: StorageUsageStats, categories: [StorageUsageStats.CategoryKey], existingMessages: [EngineMessage.Id: EngineMessage]) -> Signal<[EngineMessage.Id: EngineMessage], NoError> {
            let rawExisting = existingMessages.mapValues { $0._asMessage() }
            return _internal_renderStorageUsageStatsMessages(account: self.account, stats: stats, categories: categories, existingMessages: rawExisting)
            |> map { rawResult -> [EngineMessage.Id: EngineMessage] in
                return rawResult.mapValues(EngineMessage.init)
            }
        }

        public func clearStorage(peerId: EnginePeer.Id?, categories: [StorageUsageStats.CategoryKey], includeMessages: [EngineMessage], excludeMessages: [EngineMessage]) -> Signal<Float, NoError> {
            return _internal_clearStorage(account: self.account, peerId: peerId, categories: categories, includeMessages: includeMessages.map { $0._asMessage() }, excludeMessages: excludeMessages.map { $0._asMessage() })
        }

        public func clearStorage(peerIds: Set<EnginePeer.Id>, includeMessages: [EngineMessage], excludeMessages: [EngineMessage]) -> Signal<Float, NoError> {
            _internal_clearStorage(account: self.account, peerIds: peerIds, includeMessages: includeMessages.map { $0._asMessage() }, excludeMessages: excludeMessages.map { $0._asMessage() })
        }

        public func clearStorage(messages: [EngineMessage]) -> Signal<Never, NoError> {
            _internal_clearStorage(account: self.account, messages: messages.map { $0._asMessage() })
        }

        public func clearCachedMediaResources(mediaResourceIds: Set<EngineMediaResource.Id>) -> Signal<Float, NoError> {
            return _internal_clearCachedMediaResources(account: self.account, mediaResourceIds: Set(mediaResourceIds.map { MediaResourceId($0.stringRepresentation) }))
        }
        
        public func reindexCacheInBackground(lowImpact: Bool) -> Signal<Never, NoError> {
            let mediaBox = self.account.postbox.mediaBox
            
            return _internal_reindexCacheInBackground(account: self.account, lowImpact: lowImpact)
            |> then(Signal { subscriber in
                return mediaBox.updateResourceIndex(otherResourceContentType: MediaResourceUserContentType.other.rawValue, lowImpact: lowImpact, completion: {
                    subscriber.putCompletion()
                })
            })
        }

        public func data(id: EngineMediaResource.Id, attemptSynchronously: Bool = false) -> Signal<EngineMediaResource.ResourceData, NoError> {
            return self.account.postbox.mediaBox.resourceData(
                id: MediaResourceId(id.stringRepresentation),
                pathExtension: nil,
                option: .complete(waitUntilFetchStatus: false),
                attemptSynchronously: attemptSynchronously
            )
            |> map { data in
                return EngineMediaResource.ResourceData(data)
            }
        }

        public func custom(
            id: String,
            fetch: EngineMediaResource.Fetch?,
            cacheTimeout: EngineMediaResource.CacheTimeout = .default,
            attemptSynchronously: Bool = false
        ) -> Signal<EngineMediaResource.ResourceData, NoError> {
            let mappedKeepDuration: CachedMediaRepresentationKeepDuration
            switch cacheTimeout {
            case .default:
                mappedKeepDuration = .general
            case .shortLived:
                mappedKeepDuration = .shortLived
            }
            return self.account.postbox.mediaBox.customResourceData(
                id: id,
                baseResourceId: nil,
                pathExtension: nil,
                complete: true,
                fetch: fetch.flatMap { fetch in
                    return {
                        return Signal { subscriber in
                            return fetch.signal().start(next: { result in
                                let mappedResult: CachedMediaResourceRepresentationResult
                                switch result {
                                case let .moveTempFile(file):
                                    mappedResult = .tempFile(file)
                                default:
                                    assert(false)
                                    return
                                }
                                subscriber.putNext(mappedResult)
                            }, completed: {
                                subscriber.putCompletion()
                            })
                        }
                    }
                },
                keepDuration: mappedKeepDuration,
                attemptSynchronously: attemptSynchronously
            )
            |> map { data in
                return EngineMediaResource.ResourceData(data)
            }
        }

        public func httpData(url: String, preserveExactUrl: Bool = false) -> Signal<Data, EngineMediaResource.Fetch.Error> {
            return fetchHttpResource(url: url, preserveExactUrl: preserveExactUrl)
            |> mapError { _ -> EngineMediaResource.Fetch.Error in
                return .generic
            }
            |> mapToSignal { value -> Signal<Data, EngineMediaResource.Fetch.Error> in
                switch value {
                case let .dataPart(_, data, _, _):
                    return .single(data)
                default:
                    return .complete()
                }
            }
        }
        
        public func fetchAlbumCover(file: FileMediaReference?, title: String, performer: String, isThumbnail: Bool) -> Signal<EngineMediaResource.Fetch.Result, EngineMediaResource.Fetch.Error> {
            let signal = currentWebDocumentsHostDatacenterId(postbox: self.account.postbox, isTestingEnvironment: self.account.testingEnvironment)
            |> castError(EngineMediaResource.Fetch.Error.self)
            |> take(1)
            |> mapToSignal { datacenterId -> Signal<EngineMediaResource.Fetch.Result, EngineMediaResource.Fetch.Error> in
                let resource = AlbumCoverResource(datacenterId: Int(datacenterId), file: file, title: title, performer: performer, isThumbnail: isThumbnail)
                return multipartFetch(accountPeerId: self.account.peerId, postbox: self.account.postbox, network: self.account.network, mediaReferenceRevalidationContext: self.account.mediaReferenceRevalidationContext, networkStatsContext: self.account.networkStatsContext, resource: resource, datacenterId: Int(datacenterId), size: nil, intervals: .single([(0 ..< Int64.max, .default)]), parameters: MediaResourceFetchParameters(
                    tag: nil,
                    info: TelegramCloudMediaResourceFetchInfo(
                        reference: file?.resourceReference(resource) ?? MediaResourceReference.standalone(resource: resource),
                        preferBackgroundReferenceRevalidation: false,
                        continueInBackground: false
                    ),
                    location: nil,
                    contentType: .image,
                    isRandomAccessAllowed: true
                ))
                |> map { result -> EngineMediaResource.Fetch.Result in
                    switch result {
                    case let .dataPart(resourceOffset, data, range, complete):
                        return .dataPart(resourceOffset: resourceOffset, data: data, range: range, complete: complete)
                    case let .resourceSizeUpdated(size):
                        return .resourceSizeUpdated(size)
                    case let .progressUpdated(value):
                        return .progressUpdated(value)
                    case let .replaceHeader(data, range):
                        return .replaceHeader(data: data, range: range)
                    case let .moveLocalFile(path):
                        return .moveLocalFile(path: path)
                    case let .moveTempFile(file):
                        return .moveTempFile(file: file)
                    case let .copyLocalItem(item):
                        return .copyLocalItem(item)
                    case .reset:
                        return .reset
                    }
                }
                |> mapError { error -> EngineMediaResource.Fetch.Error in
                    switch error {
                    case .generic:
                        return .generic
                    }
                }
            }
            
            return bufferedFetch(signal)
        }

        public func cancelAllFetches(id: String) {
            preconditionFailure()
        }
        
        public func pushPriorityDownload(resourceId: String, priority: Int = 1) -> Disposable {
            return self.account.network.multiplexedRequestManager.pushPriority(resourceId: resourceId, priority: priority)
        }
        
        public func applicationIcons() -> Signal<TelegramApplicationIcons, NoError> {
            return _internal_applicationIcons(account: account)
        }

        public func fetch(
            reference: MediaResourceReference,
            userLocation: MediaResourceUserLocation,
            userContentType: MediaResourceUserContentType,
            range: (Range<Int64>, EngineMediaBoxFetchPriority)? = nil,
            statsCategory: MediaResourceStatsCategory = .generic,
            reportResultStatus: Bool = false,
            preferBackgroundReferenceRevalidation: Bool = false,
            continueInBackground: Bool = false
        ) -> Signal<FetchResourceSourceType, FetchResourceError> {
            return fetchedMediaResource(
                mediaBox: self.account.postbox.mediaBox,
                userLocation: userLocation,
                userContentType: userContentType,
                reference: reference,
                range: range,
                statsCategory: statsCategory,
                reportResultStatus: reportResultStatus,
                preferBackgroundReferenceRevalidation: preferBackgroundReferenceRevalidation,
                continueInBackground: continueInBackground
            )
        }

        public func fetch(
            reference: MediaResourceReference,
            userLocation: MediaResourceUserLocation,
            userContentType: MediaResourceUserContentType,
            ranges: [(Range<Int64>, EngineMediaBoxFetchPriority)]?,
            statsCategory: MediaResourceStatsCategory = .generic,
            reportResultStatus: Bool = false,
            preferBackgroundReferenceRevalidation: Bool = false,
            continueInBackground: Bool = false
        ) -> Signal<FetchResourceSourceType, FetchResourceError> {
            return fetchedMediaResource(
                mediaBox: self.account.postbox.mediaBox,
                userLocation: userLocation,
                userContentType: userContentType,
                reference: reference,
                ranges: ranges,
                statsCategory: statsCategory,
                reportResultStatus: reportResultStatus,
                preferBackgroundReferenceRevalidation: preferBackgroundReferenceRevalidation,
                continueInBackground: continueInBackground
            )
        }

        public func status(
            resource: EngineMediaResource,
            approximateSynchronousValue: Bool = false
        ) -> Signal<EngineMediaResource.FetchStatus, NoError> {
            return self.account.postbox.mediaBox.resourceStatus(resource._asResource(), approximateSynchronousValue: approximateSynchronousValue)
            |> map { EngineMediaResource.FetchStatus($0) }
        }

        public func status(
            id: EngineMediaResource.Id,
            resourceSize: Int64
        ) -> Signal<EngineMediaResource.FetchStatus, NoError> {
            return self.account.postbox.mediaBox.resourceStatus(MediaResourceId(id.stringRepresentation), resourceSize: resourceSize)
            |> map { EngineMediaResource.FetchStatus($0) }
        }

        public func data(
            resource: EngineMediaResource,
            pathExtension: String? = nil,
            waitUntilFetchStatus: Bool = false,
            incremental: Bool = false,
            attemptSynchronously: Bool = false
        ) -> Signal<EngineMediaResource.ResourceData, NoError> {
            let option: ResourceDataRequestOption = incremental
                ? .incremental(waitUntilFetchStatus: waitUntilFetchStatus)
                : .complete(waitUntilFetchStatus: waitUntilFetchStatus)
            return self.account.postbox.mediaBox.resourceData(
                resource._asResource(),
                pathExtension: pathExtension,
                option: option,
                attemptSynchronously: attemptSynchronously
            )
            |> map { EngineMediaResource.ResourceData($0) }
        }

        public func rangeData(resource: EngineMediaResource, size: Int64, range: Range<Int64>) -> Signal<(Data, Bool), NoError> {
            return self.account.postbox.mediaBox.resourceData(resource._asResource(), size: size, in: range)
        }

        public func cachedRepresentation(resource: EngineMediaResource, representation: EngineMediaResourceRepresentation, pathExtension: String? = nil, complete: Bool, fetch: Bool = true, attemptSynchronously: Bool = false) -> Signal<EngineMediaResource.ResourceData, NoError> {
            return self.account.postbox.mediaBox.cachedResourceRepresentation(resource._asResource(), representation: representation, pathExtension: pathExtension, complete: complete, fetch: fetch, attemptSynchronously: attemptSynchronously)
            |> map { EngineMediaResource.ResourceData($0) }
        }

        public func cachedRepresentationCompletePath(id: EngineMediaResource.Id, representation: EngineMediaResourceRepresentation) -> String {
            return self.account.postbox.mediaBox.cachedRepresentationCompletePath(MediaResourceId(id.stringRepresentation), representation: representation)
        }

        public func storeCachedRepresentation(resource: EngineMediaResource, representation: EngineMediaResourceRepresentation, data: Data) {
            self.account.postbox.mediaBox.storeCachedResourceRepresentation(resource._asResource(), representation: representation, data: data)
        }

        public func cachedRepresentationPath(id: String, representationId: String, keepDuration: EngineCachedMediaRepresentationKeepDuration) -> String {
            return self.account.postbox.mediaBox.cachedRepresentationPathForId(id, representationId: representationId, keepDuration: keepDuration)
        }

        public func fetchedResource(resource: EngineMediaResource) -> Signal<FetchResourceSourceType, FetchResourceError> {
            return self.account.postbox.mediaBox.fetchedResource(resource._asResource(), parameters: nil)
        }

        public func storageTotalSize() -> Signal<Int64, NoError> {
            return self.account.postbox.mediaBox.storageBox.totalSize()
        }

        public func cacheStorageTotalSize() -> Signal<Int64, NoError> {
            return self.account.postbox.mediaBox.cacheStorageBox.totalSize()
        }

        public func resetStorageIndex() {
            self.account.postbox.mediaBox.storageBox.reset()
        }

        public var mediaBasePath: String {
            return self.account.postbox.mediaBox.basePath
        }

        public func resourcePath(resource: EngineMediaResource) -> String {
            return self.account.postbox.mediaBox.resourcePath(resource._asResource())
        }

        public func shortLivedResourceCachePathPrefix(id: EngineMediaResource.Id) -> String {
            return self.account.postbox.mediaBox.shortLivedResourceCachePathPrefix(MediaResourceId(id.stringRepresentation))
        }

        public func completedResourcePath(id: EngineMediaResource.Id, pathExtension: String? = nil) -> String? {
            return self.account.postbox.mediaBox.completedResourcePath(id: MediaResourceId(id.stringRepresentation), pathExtension: pathExtension)
        }

        public func storeResourceData(id: EngineMediaResource.Id, data: Data, synchronous: Bool = false) {
            self.account.postbox.mediaBox.storeResourceData(MediaResourceId(id.stringRepresentation), data: data, synchronous: synchronous)
        }

        public func cancelInteractiveResourceFetch(id: EngineMediaResource.Id) {
            self.account.postbox.mediaBox.cancelInteractiveResourceFetch(resourceId: MediaResourceId(id.stringRepresentation))
        }

        public func moveResourceData(id: EngineMediaResource.Id, toTempPath: String) {
            self.account.postbox.mediaBox.moveResourceData(MediaResourceId(id.stringRepresentation), toTempPath: toTempPath)
        }

        public func moveResourceData(id: EngineMediaResource.Id, fromTempPath: String) {
            self.account.postbox.mediaBox.moveResourceData(MediaResourceId(id.stringRepresentation), fromTempPath: fromTempPath)
        }

        public func moveResourceData(from: EngineMediaResource.Id, to: EngineMediaResource.Id, synchronous: Bool = false) {
            self.account.postbox.mediaBox.moveResourceData(from: MediaResourceId(from.stringRepresentation), to: MediaResourceId(to.stringRepresentation), synchronous: synchronous)
        }

        public func copyResourceData(id: EngineMediaResource.Id, fromTempPath: String) {
            self.account.postbox.mediaBox.copyResourceData(MediaResourceId(id.stringRepresentation), fromTempPath: fromTempPath)
        }

        public func copyResourceData(from: EngineMediaResource.Id, to: EngineMediaResource.Id, synchronous: Bool = false) {
            self.account.postbox.mediaBox.copyResourceData(from: MediaResourceId(from.stringRepresentation), to: MediaResourceId(to.stringRepresentation), synchronous: synchronous)
        }

        public func resourceRangesStatus(resource: EngineMediaResource) -> Signal<RangeSet<Int64>, NoError> {
            return self.account.postbox.mediaBox.resourceRangesStatus(resource._asResource())
        }

        public func removeCachedResources(ids: [EngineMediaResource.Id], force: Bool = false, notify: Bool = false) -> Signal<Float, NoError> {
            return self.account.postbox.mediaBox.removeCachedResources(ids.map { MediaResourceId($0.stringRepresentation) }, force: force, notify: notify)
        }
    }
}
