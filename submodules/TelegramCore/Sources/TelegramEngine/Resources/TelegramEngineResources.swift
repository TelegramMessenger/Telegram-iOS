import Foundation
import SwiftSignalKit
import Postbox

public final class EngineMediaResource: Equatable {
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
            case dataPart(resourceOffset: Int, data: Data, range: Range<Int>, complete: Bool)
            case resourceSizeUpdated(Int)
            case progressUpdated(Float)
            case replaceHeader(data: Data, range: Range<Int>)
            case moveLocalFile(path: String)
            case moveTempFile(file: TempBoxFile)
            case copyLocalItem(MediaResourceDataFetchCopyLocalItem)
            case reset
        }

        public enum Error {
            case generic
        }

        public let signal: (
            Signal<[EngineMediaResource.ByteRange], NoError>
        ) -> Signal<Result, Error>

        public init(_ signal: @escaping (
            Signal<[EngineMediaResource.ByteRange], NoError>
        ) -> Signal<Result, Error>) {
            self.signal = signal
        }
    }

    public final class ResourceData {
        public let path: String
        public let availableSize: Int
        public let isComplete: Bool

        public init(
            path: String,
            availableSize: Int,
            isComplete: Bool
        ) {
            self.path = path
            self.availableSize = availableSize
            self.isComplete = isComplete
        }
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

public extension MediaResource {
    func fetch(engine: TelegramEngine, parameters: MediaResourceFetchParameters?) -> EngineMediaResource.Fetch {
        return EngineMediaResource.Fetch { ranges in
            return Signal { subscriber in
                return engine.account.postbox.mediaBox.fetchResource!(
                    self,
                    ranges |> map { ranges -> [(Range<Int>, MediaBoxFetchPriority)] in
                        return ranges.map { range -> (Range<Int>, MediaBoxFetchPriority) in
                            let mappedPriority: MediaBoxFetchPriority
                            switch range.priority {
                            case .default:
                                mappedPriority = .default
                            case .elevated:
                                mappedPriority = .elevated
                            case .maximum:
                                mappedPriority = .maximum
                            }
                            return (range.range, mappedPriority)
                        }
                    },
                    parameters
                ).start(next: { result in
                    let mappedResult: EngineMediaResource.Fetch.Result
                    switch result {
                    case let .dataPart(resourceOffset, data, range, complete):
                        mappedResult = .dataPart(resourceOffset: resourceOffset, data: data, range: range, complete: complete)
                    case let .resourceSizeUpdated(size):
                        mappedResult = .resourceSizeUpdated(size)
                    case let .progressUpdated(progress):
                        mappedResult = .progressUpdated(progress)
                    case let .replaceHeader(data, range):
                        mappedResult = .replaceHeader(data: data, range: range)
                    case let .moveLocalFile(path):
                        mappedResult = .moveLocalFile(path: path)
                    case let .moveTempFile(file):
                        mappedResult = .moveTempFile(file: file)
                    case let .copyLocalItem(item):
                        mappedResult = .copyLocalItem(item)
                    case .reset:
                        mappedResult = .reset
                    }
                    subscriber.putNext(mappedResult)
                }, error: { _ in
                    subscriber.putError(.generic)
                }, completed: {
                    subscriber.putCompletion()
                })
            }
        }
    }
}

public extension TelegramEngine {
    final class Resources {
        private let account: Account

        init(account: Account) {
            self.account = account
        }

        public func preUpload(id: Int64, encrypt: Bool, tag: MediaResourceFetchTag?, source: Signal<MediaResourceData, NoError>, onComplete: (()->Void)? = nil) {
            return self.account.messageMediaPreuploadManager.add(network: self.account.network, postbox: self.account.postbox, id: id, encrypt: encrypt, tag: tag, source: source, onComplete: onComplete)
        }

        public func collectCacheUsageStats(peerId: PeerId? = nil, additionalCachePaths: [String] = [], logFilesPath: String? = nil) -> Signal<CacheUsageStatsResult, NoError> {
            return _internal_collectCacheUsageStats(account: self.account, peerId: peerId, additionalCachePaths: additionalCachePaths, logFilesPath: logFilesPath)
        }

        public func clearCachedMediaResources(mediaResourceIds: Set<MediaResourceId>) -> Signal<Void, NoError> {
            return _internal_clearCachedMediaResources(account: self.account, mediaResourceIds: mediaResourceIds)
        }

        public func data(id: String) -> Signal<EngineMediaResource.ResourceData, NoError> {
            preconditionFailure()
        }

        public func fetch(id: String, fetch: EngineMediaResource.Fetch) -> Signal<Never, NoError> {
            preconditionFailure()
        }

        public func cancelAllFetches(id: String) {
            preconditionFailure()
        }
    }
}
