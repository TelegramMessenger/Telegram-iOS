import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi
import MtProtoKit

public enum AddSavedMusicError {
    case generic
}

public func revalidatedMusic<T>(account: Account, file: FileMediaReference, signal: @escaping (CloudDocumentMediaResource) -> Signal<T, MTRpcError>) -> Signal<T, MTRpcError> {
    guard let resource = file.media.resource as? CloudDocumentMediaResource else {
        return .fail(MTRpcError(errorCode: 500, errorDescription: "Internal"))
    }
    return signal(resource)
    |> `catch` { error -> Signal<T, MTRpcError> in
        if error.errorDescription == "FILE_REFERENCE_EXPIRED" {
            return revalidateMediaResourceReference(accountPeerId: account.peerId, postbox: account.postbox, network: account.network, revalidationContext: account.mediaReferenceRevalidationContext, info: TelegramCloudMediaResourceFetchInfo(reference: file.resourceReference(resource), preferBackgroundReferenceRevalidation: false, continueInBackground: false), resource: resource)
            |> mapError { _ -> MTRpcError in
                return MTRpcError(errorCode: 500, errorDescription: "Internal")
            }
            |> mapToSignal { result -> Signal<T, MTRpcError> in
                guard let resource = result.updatedResource as? CloudDocumentMediaResource else {
                    return .fail(MTRpcError(errorCode: 500, errorDescription: "Internal"))
                }
                return signal(resource)
            }
        } else {
            return .fail(error)
        }
    }
}

public final class SavedMusicIdsList: Codable, Equatable {
    public let items: [Int64]

    public init(items: [Int64]) {
        self.items = items
    }

    public static func ==(lhs: SavedMusicIdsList, rhs: SavedMusicIdsList) -> Bool {
        if lhs === rhs {
            return true
        }
        if lhs.items != rhs.items {
            return false
        }
        return true
    }
}

func _internal_getSavedMusicById(postbox: Postbox, network: Network, peer: PeerReference, file: TelegramMediaFile) -> Signal<TelegramMediaFile?, NoError> {
    let inputUser = peer.inputUser
    guard let inputUser, let resource = file.resource as? CloudDocumentMediaResource else {
        return .single(nil)
    }
    return network.request(Api.functions.users.getSavedMusicByID(id: inputUser, documents: [.inputDocument(.init(id: resource.fileId, accessHash: resource.accessHash, fileReference: Buffer(data: resource.fileReference)))]))
    |> map(Optional.init)
    |> `catch` { _ -> Signal<Api.users.SavedMusic?, NoError> in
        return .single(nil)
    }
    |> map { result -> TelegramMediaFile? in
        if let result {
            switch result {
            case let .savedMusic(savedMusicData):
                if let file = savedMusicData.documents.first.flatMap({ telegramMediaFileFromApiDocument($0, altDocuments: nil) }) {
                    return file
                }
            default:
                break
            }
        }
        return nil
    }
}

func _internal_savedMusicIds(postbox: Postbox) -> Signal<Set<Int64>?, NoError> {
    let viewKey: PostboxViewKey = .preferences(keys: Set([PreferencesKeys.savedMusicIds()]))
    return postbox.combinedView(keys: [viewKey])
    |> map { views -> Set<Int64>? in
        guard let view = views.views[viewKey] as? PreferencesView else {
            return nil
        }
        guard let value = view.values[PreferencesKeys.savedMusicIds()]?.get(SavedMusicIdsList.self) else {
            return nil
        }
        return Set(value.items)
    }
}

func _internal_keepSavedMusicIdsUpdated(postbox: Postbox, network: Network, accountPeerId: EnginePeer.Id) -> Signal<Never, NoError> {
    let updateSignal = _internal_savedMusicIds(postbox: postbox)
    |> take(1)
    |> mapToSignal { list -> Signal<Never, NoError> in
        //TODO:release
        return network.request(Api.functions.account.getSavedMusicIds(hash: 0))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.account.SavedMusicIds?, NoError> in
            return .single(nil)
        }
        |> mapToSignal { result -> Signal<Never, NoError> in
            guard let result else {
                return .complete()
            }
            return postbox.transaction { transaction in
                switch result {
                case let .savedMusicIds(savedMusicIdsData):
                    let ids = savedMusicIdsData.ids
                    let savedMusicIdsList = SavedMusicIdsList(items: ids)
                    transaction.setPreferencesEntry(key: PreferencesKeys.savedMusicIds(), value: PreferencesEntry(savedMusicIdsList))
                case .savedMusicIdsNotModified:
                    break
                }
            }
            |> ignoreValues
        }
    }
    
    return updateSignal
}

func managedSavedMusicIdsUpdates(postbox: Postbox, network: Network, accountPeerId: EnginePeer.Id) -> Signal<Never, NoError> {
    let poll = _internal_keepSavedMusicIdsUpdated(postbox: postbox, network: network, accountPeerId: accountPeerId)
    return (poll |> then(.complete() |> suspendAwareDelay(0.5 * 60.0 * 60.0, queue: Queue.concurrentDefaultQueue()))) |> restart
}

private func updatedSavedMusicFiles(_ files: [TelegramMediaFile], file: TelegramMediaFile, afterFileId: MediaId?) -> [TelegramMediaFile] {
    var result = files
    if let index = result.firstIndex(where: { $0.fileId == file.fileId }), afterFileId == file.fileId {
        result[index] = file
        return result
    }
    result.removeAll(where: { $0.fileId == file.fileId })
    let index = afterFileId.flatMap { id in result.firstIndex(where: { $0.fileId == id }) }.map { $0 + 1 }
        ?? (afterFileId == nil ? 0 : result.count)
    result.insert(file, at: index)
    return result
}

func _internal_addSavedMusic(account: Account, file: FileMediaReference, afterFile: FileMediaReference?) -> Signal<Never, AddSavedMusicError> {
    if afterFile?.media.fileId == file.media.fileId {
        return .complete()
    }
    var flags: Int32 = 0
    var afterId: Api.InputDocument?
    if let afterFile {
        guard let resource = afterFile.media.resource as? CloudDocumentMediaResource else {
            return .fail(.generic)
        }
        flags = 1 << 1
        afterId = .inputDocument(.init(id: resource.fileId, accessHash: resource.accessHash, fileReference: Buffer(data: resource.fileReference)))
    }
    return revalidatedMusic(account: account, file: file, signal: { resource in
        return account.network.request(Api.functions.account.saveMusic(flags: flags, id: .inputDocument(.init(id: resource.fileId, accessHash: resource.accessHash, fileReference: Buffer(data: resource.fileReference))), afterId: afterId))
    })
    |> mapError { _ -> AddSavedMusicError in .generic }
    |> mapToSignal { result -> Signal<Never, AddSavedMusicError> in
        guard case .boolTrue = result else { return .fail(.generic) }
        return account.postbox.transaction { transaction in
            let savedIds = transaction.getPreferencesEntry(key: PreferencesKeys.savedMusicIds())?.get(SavedMusicIdsList.self)
            var firstFile: TelegramMediaFile?
            if let cached = transaction.retrieveItemCacheEntry(id: entryId(peerId: account.peerId))?.get(CachedProfileSavedMusic.self) {
                let wasSaved = cached.files.contains(where: { $0.fileId == file.media.fileId }) || savedIds?.items.contains(file.media.fileId.id) == true
                let files = updatedSavedMusicFiles(cached.files, file: file.media, afterFileId: afterFile?.media.fileId)
                firstFile = files.first
                let count = max(Int32(clamping: files.count), Int32(clamping: Int64(cached.count) + (wasSaved ? 0 : 1)))
                if let entry = CodableEntry(CachedProfileSavedMusic(files: files, count: count)) {
                    transaction.putItemCacheEntry(id: entryId(peerId: account.peerId), entry: entry)
                }
            }
            if let savedIds {
                var ids = Set(savedIds.items)
                ids.insert(file.media.fileId.id)
                transaction.setPreferencesEntry(key: PreferencesKeys.savedMusicIds(), value: PreferencesEntry(SavedMusicIdsList(items: Array(ids))))
            }
            if let firstFile = afterFile == nil ? file.media : firstFile {
                transaction.updatePeerCachedData(peerIds: Set([account.peerId]), update: { _, cachedData -> CachedPeerData? in
                    return (cachedData as? CachedUserData)?.withUpdatedSavedMusic(firstFile) ?? cachedData
                })
            }
        }
        |> castError(AddSavedMusicError.self)
        |> ignoreValues
    }
}

func _internal_removeSavedMusic(account: Account, file: FileMediaReference) -> Signal<Never, NoError> {
    return revalidatedMusic(account: account, file: file, signal: { resource in
        return account.network.request(Api.functions.account.saveMusic(flags: 1 << 0, id: .inputDocument(.init(id: resource.fileId, accessHash: resource.accessHash, fileReference: Buffer(data: resource.fileReference))), afterId: nil))
    })
    |> `catch` { _ -> Signal<Api.Bool, NoError> in .complete() }
    |> mapToSignal { result -> Signal<Never, NoError> in
        guard case .boolTrue = result else { return .complete() }
        return account.postbox.transaction { transaction in
            let savedIds = transaction.getPreferencesEntry(key: PreferencesKeys.savedMusicIds())?.get(SavedMusicIdsList.self)
            var nextFile: TelegramMediaFile?
            if let cached = transaction.retrieveItemCacheEntry(id: entryId(peerId: account.peerId))?.get(CachedProfileSavedMusic.self) {
                let wasSaved = cached.files.contains(where: { $0.fileId == file.media.fileId }) || savedIds?.items.contains(file.media.fileId.id) == true
                let files = cached.files.filter { $0.fileId != file.media.fileId }
                let count = max(Int32(clamping: files.count), Int32(clamping: Int64(cached.count) - (wasSaved ? 1 : 0)))
                nextFile = files.first
                if let entry = CodableEntry(CachedProfileSavedMusic(files: files, count: count)) {
                    transaction.putItemCacheEntry(id: entryId(peerId: account.peerId), entry: entry)
                }
            }
            if let savedIds {
                var ids = Set(savedIds.items)
                ids.remove(file.media.fileId.id)
                transaction.setPreferencesEntry(key: PreferencesKeys.savedMusicIds(), value: PreferencesEntry(SavedMusicIdsList(items: Array(ids))))
            }
            transaction.updatePeerCachedData(peerIds: Set([account.peerId]), update: { _, cachedData -> CachedPeerData? in
                guard let cached = cachedData as? CachedUserData, cached.savedMusic?.fileId == file.media.fileId else { return cachedData }
                return cached.withUpdatedSavedMusic(nextFile)
            })
        }
        |> ignoreValues
    }
}

private final class CachedProfileSavedMusic: Codable {
    enum CodingKeys: String, CodingKey {
        case files
        case count
    }
    
    let files: [TelegramMediaFile]
    let count: Int32
    
    init(files: [TelegramMediaFile], count: Int32) {
        self.files = files
        self.count = count
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.files = try container.decode([TelegramMediaFile].self, forKey: .files)
        self.count = try container.decode(Int32.self, forKey: .count)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(self.files, forKey: .files)
        try container.encode(self.count, forKey: .count)
    }
}

private func entryId(peerId: EnginePeer.Id) -> ItemCacheEntryId {
    let cacheKey = ValueBoxKey(length: 8)
    cacheKey.setInt64(0, value: peerId.toInt64())
    return ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedProfileSavedMusic, key: cacheKey)
}

public final class ProfileSavedMusicContext {
    public struct State: Equatable {
        public enum DataState: Equatable {
            case loading
            case ready(canLoadMore: Bool)
        }
        
        public var files: [TelegramMediaFile]
        public var count: Int32?
        public var dataState: DataState
    }
    
    private let queue: Queue = .mainQueue()
    private let account: Account
    public let peerId: EnginePeer.Id
    
    private let disposable = MetaDisposable()
    private let cacheDisposable = MetaDisposable()
    private let cacheReadDisposable = MetaDisposable()
    
    private var files: [TelegramMediaFile] = []
    private var count: Int32?
    private var needsFirstPageRetry = false
    private var nextOffset: Int32 = 0
    private var requestGeneration: UInt64 = 0
    private var pendingMutations: Set<UUID> = []
    private var mutationStarts: [() -> Void] = []
    private var mutationUpdateDepth = 0
    private var isStartingMutations = false
    private var dataState: ProfileSavedMusicContext.State.DataState = .ready(canLoadMore: true)
    
    private let stateValue = Promise<State>()
    public var state: Signal<State, NoError> {
        return self.stateValue.get()
    }
    
    public init(account: Account, peerId: EnginePeer.Id) {
        self.account = account
        self.peerId = peerId
                
        self.loadMore()
    }
    
    deinit {
        self.disposable.dispose()
        self.cacheDisposable.dispose()
        self.cacheReadDisposable.dispose()
    }
    
    public func reload() {
        self.dataState = .ready(canLoadMore: true)
        self.loadMore(reload: true)
    }
    
    public func loadMore(reload: Bool = false) {
        let peerId = self.peerId
        let network = self.account.network
        let postbox = self.account.postbox
        let dataState = self.dataState
        let offset = reload || self.needsFirstPageRetry ? 0 : self.nextOffset
        
        guard case .ready(true) = dataState, self.pendingMutations.isEmpty else {
            return
        }
        self.requestGeneration &+= 1
        let generation = self.requestGeneration
        let requestDisposable = MetaDisposable()
        self.disposable.set(requestDisposable)
        self.cacheReadDisposable.set(nil)
        guard self.requestGeneration == generation else { return }
        if self.files.isEmpty, offset == 0, !reload {
            let cacheDisposable = MetaDisposable()
            self.cacheReadDisposable.set(cacheDisposable)
            cacheDisposable.set((postbox.transaction { transaction -> CachedProfileSavedMusic? in
                return transaction.retrieveItemCacheEntry(id: entryId(peerId: peerId))?.get(CachedProfileSavedMusic.self)
            } |> deliverOn(self.queue)).start(next: { [weak self] cachedSavedMusic in
                guard let self, self.requestGeneration == generation, let cachedSavedMusic else {
                    return
                }
                self.files = cachedSavedMusic.files
                self.count = cachedSavedMusic.count
                if self.dataState == .loading || self.needsFirstPageRetry {
                    self.pushState()
                }
            }))
        }
        
        guard self.requestGeneration == generation else { return }
        self.dataState = .loading
        self.pushState()
        guard self.requestGeneration == generation else { return }
        
        let signal = postbox.loadedPeerWithId(peerId)
        |> castError(MTRpcError.self)
        |> mapToSignal { peer -> Signal<([TelegramMediaFile], Int32, Int32), MTRpcError> in
            guard let inputUser = apiInputUser(peer) else {
                return .complete()
            }
            return network.request(Api.functions.users.getSavedMusic(id: inputUser, offset: offset, limit: 32, hash: 0))
            |> mapToSignal { result -> Signal<([TelegramMediaFile], Int32, Int32), MTRpcError> in
                switch result {
                case let .savedMusic(savedMusicData):
                    return .single((savedMusicData.documents.compactMap { telegramMediaFileFromApiDocument($0, altDocuments: nil) }, savedMusicData.count, Int32(clamping: savedMusicData.documents.count)))
                case .savedMusicNotModified:
                    return .complete()
                }
            }
        }
        
        var receivedResult = false
        let finishWithoutResult: () -> Void = { [weak self] in
            guard let self, self.requestGeneration == generation, !receivedResult else {
                return
            }
            self.needsFirstPageRetry = offset == 0
            self.dataState = .ready(canLoadMore: true)
            self.pushState()
        }
        requestDisposable.set((signal
        |> deliverOn(self.queue)).start(next: { [weak self] files, count, receivedCount in
            guard let self, self.requestGeneration == generation else {
                return
            }
            receivedResult = true
            self.cacheReadDisposable.set(nil)
            self.needsFirstPageRetry = false
            self.nextOffset = Int32(clamping: Int64(offset) + Int64(receivedCount))
            var mergedFiles: [TelegramMediaFile] = []
            var indices: [MediaId: Int] = [:]
            let previousFiles = offset == 0 ? [] : self.files
            for file in previousFiles + files {
                if let index = indices[file.fileId] {
                    mergedFiles[index] = file
                } else {
                    indices[file.fileId] = mergedFiles.count
                    mergedFiles.append(file)
                }
            }
            self.files = mergedFiles
            if offset == 0 || reload {
                self.cacheDisposable.set(self.account.postbox.transaction { transaction in
                    if let entry = CodableEntry(CachedProfileSavedMusic(files: mergedFiles, count: count)) {
                        transaction.putItemCacheEntry(id: entryId(peerId: peerId), entry: entry)
                    }
                }.start())
            }
            
            let updatedCount = max(Int32(self.files.count), count)
            self.count = updatedCount
            self.dataState = .ready(canLoadMore: receivedCount > 0 && self.nextOffset < count)
            self.pushState()
        }, error: { _ in
            finishWithoutResult()
        }, completed: finishWithoutResult))
    }
        
    public func addMusic(file: FileMediaReference, afterFile: FileMediaReference? = nil, apply: Bool = true) -> Signal<Never, AddSavedMusicError> {
        if afterFile?.media.fileId == file.media.fileId { return .complete() }
        guard self.peerId == self.account.peerId else {
            return apply ? _internal_addSavedMusic(account: self.account, file: file, afterFile: afterFile) : .complete()
        }
        let update: (ProfileSavedMusicContext) -> Void = { context in
            let wasPresent = context.files.contains(where: { $0.fileId == file.media.fileId })
            context.files = updatedSavedMusicFiles(context.files, file: file.media, afterFileId: afterFile?.media.fileId)
            if !wasPresent, let count = context.count {
                context.count = max(Int32(clamping: context.files.count), Int32(clamping: Int64(count) + 1))
            }
        }
        if !apply {
            self.invalidatePage()
            update(self)
            self.pushState()
            return .complete()
        }
        return self.performMutation(signal: _internal_addSavedMusic(account: self.account, file: file, afterFile: afterFile), update: update)
    }

    public func removeMusic(file: FileMediaReference) -> Signal<Never, NoError> {
        let signal = _internal_removeSavedMusic(account: self.account, file: file)
        guard self.peerId == self.account.peerId else { return signal }
        return self.performMutation(signal: signal, update: { context in
            let wasPresent = context.files.contains(where: { $0.fileId == file.media.fileId })
            context.files.removeAll(where: { $0.fileId == file.media.fileId })
            if wasPresent, let count = context.count {
                context.count = max(Int32(clamping: context.files.count), Int32(clamping: Int64(count) - 1))
            }
        })
    }

    private func invalidatePage() {
        self.requestGeneration &+= 1
        self.disposable.set(nil)
        self.cacheReadDisposable.set(nil)
        self.cacheDisposable.set(nil)
        self.needsFirstPageRetry = true
        self.nextOffset = 0
        self.dataState = .ready(canLoadMore: true)
    }

    private func finishMutation(_ id: UUID) {
        guard self.pendingMutations.remove(id) != nil else { return }
        if self.pendingMutations.isEmpty {
            self.reload()
        }
    }

    private func performMutation<E>(signal: Signal<Never, E>, update: @escaping (ProfileSavedMusicContext) -> Void) -> Signal<Never, E> {
        let queue = self.queue
        return Signal { [weak self] subscriber in
            let id = UUID()
            let disposable = MetaDisposable()
            let cancelled = Atomic<Bool>(value: false)
            let start: () -> Void = { [weak self] in
                guard !cancelled.with({ $0 }) else { return }
                disposable.set((signal |> deliverOn(queue)).start(error: { [weak self] error in
                    self?.finishMutation(id)
                    subscriber.putError(error)
                }, completed: { [weak self] in
                    self?.finishMutation(id)
                    subscriber.putCompletion()
                }))
            }
            if let self {
                self.pendingMutations.insert(id)
                self.mutationStarts.append(start)
                self.mutationUpdateDepth += 1
                self.invalidatePage()
                update(self)
                self.pushState()
                self.mutationUpdateDepth -= 1
                self.startPendingMutations()
            } else {
                start()
            }
            return ActionDisposable { [weak self] in
                _ = cancelled.swap(true)
                disposable.dispose()
                queue.async { [weak self] in self?.finishMutation(id) }
            }
        }
        |> runOn(queue)
    }

    private func startPendingMutations() {
        guard self.mutationUpdateDepth == 0, !self.isStartingMutations else { return }
        self.isStartingMutations = true
        while !self.mutationStarts.isEmpty {
            let start = self.mutationStarts.removeFirst()
            start()
        }
        self.isStartingMutations = false
    }

    private func pushState() {
        let state = State(
            files: self.files,
            count: self.count,
            dataState: self.dataState
        )
        self.stateValue.set(.single(state))
    }
}
