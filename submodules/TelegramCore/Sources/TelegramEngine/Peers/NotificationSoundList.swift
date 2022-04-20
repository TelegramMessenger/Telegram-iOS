import Foundation
import SwiftSignalKit
import Postbox
import TelegramApi
import MtProtoKit

public struct NotificationSoundSettings: Equatable {
    public private(set) var maxDuration: Int = 5
    public private(set) var maxSize: Int = 102400
    public private(set) var maxSavedCount: Int = 100
    
    private init(appConfiguration: AppConfiguration) {
        if let data = appConfiguration.data {
            let duration = data["ringtone_duration_max"] as? Double ?? 5
            let size = data["ringtone_size_max"] as? Double ?? 102400
            let count = data["ringtone_saved_count_max"] as? Double ?? 100
            
            self.maxDuration = Int(duration)
            self.maxSize = Int(size)
            self.maxSavedCount = Int(count)
        }
    }
    
    public static func extract(from appConfiguration: AppConfiguration) -> NotificationSoundSettings {
        return self.init(appConfiguration: appConfiguration)
    }
}

public final class NotificationSoundList: Equatable, Codable {
    public final class NotificationSound: Equatable, Codable {
        private enum CodingKeys: String, CodingKey {
            case file
        }
        
        public let file: TelegramMediaFile
        
        public init(
            file: TelegramMediaFile
        ) {
            self.file = file
        }
        
        public static func ==(lhs: NotificationSound, rhs: NotificationSound) -> Bool {
            if lhs.file != rhs.file {
                return false
            }
            return true
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            let fileData = try container.decode(AdaptedPostboxDecoder.RawObjectData.self, forKey: .file)
            self.file = TelegramMediaFile(decoder: PostboxDecoder(buffer: MemoryBuffer(data: fileData.data)))
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(PostboxEncoder().encodeObjectToRawData(self.file), forKey: .file)
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case hash
        case sounds
    }
    
    public let hash: Int64
    public let sounds: [NotificationSound]
    
    public init(
        hash: Int64,
        sounds: [NotificationSound]
    ) {
        self.hash = hash
        self.sounds = sounds
    }
    
    public static func ==(lhs: NotificationSoundList, rhs: NotificationSoundList) -> Bool {
        if lhs.hash != rhs.hash {
            return false
        }
        if lhs.sounds != rhs.sounds {
            return false
        }
        return true
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.hash = try container.decode(Int64.self, forKey: .hash)
        self.sounds = try container.decode([NotificationSound].self, forKey: .sounds)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(self.hash, forKey: .hash)
        try container.encode(self.sounds, forKey: .sounds)
    }
}

private extension NotificationSoundList.NotificationSound {
    convenience init?(apiDocument: Api.Document) {
        guard let file = telegramMediaFileFromApiDocument(apiDocument) else {
            return nil
        }
        self.init(file: file)
    }
}

func _internal_cachedNotificationSoundList(postbox: Postbox) -> Signal<NotificationSoundList?, NoError> {
    return postbox.transaction { transaction -> NotificationSoundList? in
        return _internal_cachedNotificationSoundList(transaction: transaction)
    }
}

func _internal_cachedNotificationSoundListCacheKey() -> ItemCacheEntryId {
    let key = ValueBoxKey(length: 8)
    key.setInt64(0, value: 0)
    
    return ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.notificationSoundList, key: key)
}

public func _internal_cachedNotificationSoundList(transaction: Transaction) -> NotificationSoundList? {
    let cached = transaction.retrieveItemCacheEntry(id: _internal_cachedNotificationSoundListCacheKey())?.get(NotificationSoundList.self)
    if let cached = cached {
        return cached
    } else {
        return nil
    }
}

func _internal_setCachedNotificationSoundList(transaction: Transaction, notificationSoundList: NotificationSoundList) {
    if let entry = CodableEntry(notificationSoundList) {
        transaction.putItemCacheEntry(id: _internal_cachedNotificationSoundListCacheKey(), entry: entry, collectionSpec: ItemCacheCollectionSpec(lowWaterItemCount: 10, highWaterItemCount: 10))
    }
}

public func ensureDownloadedNotificationSoundList(postbox: Postbox) -> Signal<Never, NoError> {
    return postbox.transaction { transaction -> Signal<Never, NoError> in
        var signals: [Signal<Never, NoError>] = []
        
        if let notificationSoundList = _internal_cachedNotificationSoundList(transaction: transaction) {
            var resources: [MediaResource] = []
            
            for sound in notificationSoundList.sounds {
                resources.append(sound.file.resource)
            }
            
            for resource in resources {
                signals.append(
                    fetchedMediaResource(mediaBox: postbox.mediaBox, reference: .soundList(resource: resource))
                    |> ignoreValues
                    |> `catch` { _ -> Signal<Never, NoError> in
                        return .complete()
                    }
                )
            }
        }
        
        return combineLatest(signals)
        |> ignoreValues
    }
    |> switchToLatest
    |> ignoreValues
}

func requestNotificationSoundList(network: Network, hash: Int64) -> Signal<NotificationSoundList?, NoError> {
    return network.request(Api.functions.account.getSavedRingtones(hash: hash))
    |> map(Optional.init)
    |> `catch` { _ -> Signal<Api.account.SavedRingtones?, NoError> in
        return .single(nil)
    }
    |> map { result -> NotificationSoundList? in
        guard let result = result else {
            return nil
        }
        
        switch result {
        case let .savedRingtones(hash, ringtones):
            let notificationSoundList = NotificationSoundList(
                hash: hash,
                sounds: ringtones.compactMap(NotificationSoundList.NotificationSound.init(apiDocument:))
            )
            return notificationSoundList
        case .savedRingtonesNotModified:
            return nil
        }
    }
}

private func pollNotificationSoundList(postbox: Postbox, network: Network) -> Signal<Never, NoError> {
    return Signal<Never, NoError> { subscriber in
        let signal: Signal<Never, NoError> = _internal_cachedNotificationSoundList(postbox: postbox)
        |> mapToSignal { current in
            return (network.request(Api.functions.account.getSavedRingtones(hash: current?.hash ?? 0))
            |> map(Optional.init)
            |> `catch` { _ -> Signal<Api.account.SavedRingtones?, NoError> in
                return .single(nil)
            }
            |> mapToSignal { result -> Signal<Never, NoError> in
                return postbox.transaction { transaction -> Signal<Never, NoError> in
                    guard let result = result else {
                        return .complete()
                    }
                    switch result {
                    case let .savedRingtones(hash, ringtones):
                        let notificationSoundList = NotificationSoundList(
                            hash: hash,
                            sounds: ringtones.compactMap(NotificationSoundList.NotificationSound.init(apiDocument:))
                        )
                        _internal_setCachedNotificationSoundList(transaction: transaction, notificationSoundList: notificationSoundList)
                    case .savedRingtonesNotModified:
                        break
                    }
                    
                    var signals: [Signal<Never, NoError>] = []
                    
                    if let notificationSoundList = _internal_cachedNotificationSoundList(transaction: transaction) {
                        var resources: [MediaResource] = []
                        
                        for sound in notificationSoundList.sounds {
                            resources.append(sound.file.resource)
                        }
                        
                        for resource in resources {
                            signals.append(
                                fetchedMediaResource(mediaBox: postbox.mediaBox, reference: .soundList(resource: resource))
                                |> ignoreValues
                                |> `catch` { _ -> Signal<Never, NoError> in
                                    return .complete()
                                }
                            )
                        }
                    }
                    
                    return combineLatest(signals)
                    |> ignoreValues
                }
                |> switchToLatest
            })
        }
                
        return signal.start(completed: {
            subscriber.putCompletion()
        })
    }
}

func managedSynchronizeNotificationSoundList(postbox: Postbox, network: Network) -> Signal<Never, NoError> {
    let poll = pollNotificationSoundList(postbox: postbox, network: network)
    
    return (
        poll
        |> then(
            .complete()
            |> suspendAwareDelay(1.0 * 60.0 * 60.0, queue: Queue.concurrentDefaultQueue())
        )
    )
    |> restart
}


func _internal_saveNotificationSound(account: Account, file: FileMediaReference, unsave: Bool = false) -> Signal<Never, UploadNotificationSoundError> {
    guard let resource = file.media.resource as? CloudDocumentMediaResource else {
        return .fail(.generic)
    }
    return account.network.request(Api.functions.account.saveRingtone(id: .inputDocument(id: resource.fileId, accessHash: resource.accessHash, fileReference: Buffer(data: resource.fileReference)), unsave: unsave ? .boolTrue : .boolFalse))
    |> `catch` { error -> Signal<Api.account.SavedRingtone, MTRpcError> in
        if error.errorDescription == "FILE_REFERENCE_EXPIRED" {
            return revalidateMediaResourceReference(postbox: account.postbox, network: account.network, revalidationContext: account.mediaReferenceRevalidationContext, info: TelegramCloudMediaResourceFetchInfo(reference: file.abstract.resourceReference(file.media.resource), preferBackgroundReferenceRevalidation: false, continueInBackground: false), resource: file.media.resource)
            |> mapError { _ -> MTRpcError in
                return MTRpcError(errorCode: 500, errorDescription: "Internal")
            }
            |> mapToSignal { result -> Signal<Api.account.SavedRingtone, MTRpcError> in
                guard let resource = result.updatedResource as? CloudDocumentMediaResource else {
                    return .fail(MTRpcError(errorCode: 500, errorDescription: "Internal"))
                }
                
                return account.network.request(Api.functions.account.saveRingtone(id: .inputDocument(id: resource.fileId, accessHash: resource.accessHash, fileReference: Buffer(data: resource.fileReference)), unsave: unsave ? .boolTrue : .boolFalse))
            }
        } else {
            return .fail(error)
        }
    }
    |> mapError { _ -> UploadNotificationSoundError in
        return .generic
    }
    |> mapToSignal { _ -> Signal<Never, UploadNotificationSoundError> in
        return pollNotificationSoundList(postbox: account.postbox, network: account.network)
        |> castError(UploadNotificationSoundError.self)
    }
}

public enum UploadNotificationSoundError {
    case generic
}

func _internal_uploadNotificationSound(account: Account, title: String, data: Data) -> Signal<NotificationSoundList.NotificationSound, UploadNotificationSoundError> {
    return multipartUpload(network: account.network, postbox: account.postbox, source: .data(data), encrypt: false, tag: nil, hintFileSize: data.count, hintFileIsLarge: false, forceNoBigParts: true, useLargerParts: false, increaseParallelParts: false, useMultiplexedRequests: false, useCompression: false)
    |> mapError { _ -> UploadNotificationSoundError in
        return .generic
    }
    |> mapToSignal { value -> Signal<NotificationSoundList.NotificationSound, UploadNotificationSoundError> in
        switch value {
        case let .inputFile(file):
            return account.network.request(Api.functions.account.uploadRingtone(file: file, fileName: title, mimeType: "audio/mpeg"))
            |> mapError { _ -> UploadNotificationSoundError in
                return .generic
            }
            |> mapToSignal { result -> Signal<NotificationSoundList.NotificationSound, UploadNotificationSoundError> in
                guard let file = telegramMediaFileFromApiDocument(result) else {
                    return .fail(.generic)
                }
                return account.postbox.transaction { transaction -> NotificationSoundList.NotificationSound in
                    let item = NotificationSoundList.NotificationSound(file: file)
                    
                    account.postbox.mediaBox.storeResourceData(file.resource.id, data: data, synchronous: true)
                    
                    let notificationSoundList = _internal_cachedNotificationSoundList(transaction: transaction) ?? NotificationSoundList(hash: 0, sounds: [])
                    let updatedNotificationSoundList = NotificationSoundList(hash: notificationSoundList.hash, sounds: [item] + notificationSoundList.sounds)
                    _internal_setCachedNotificationSoundList(transaction: transaction, notificationSoundList: updatedNotificationSoundList)
                    
                    return item
                }
                |> castError(UploadNotificationSoundError.self)
            }
        default:
            return .never()
        }
    }
}

public enum DeleteNotificationSoundError {
    case generic
}

func _internal_deleteNotificationSound(account: Account, fileId: Int64) -> Signal<Never, DeleteNotificationSoundError> {
    return account.postbox.transaction { transaction -> NotificationSoundList.NotificationSound? in
        return _internal_cachedNotificationSoundList(transaction: transaction).flatMap { list -> NotificationSoundList.NotificationSound? in
            return list.sounds.first(where: { $0.file.fileId.id == fileId })
        }
    }
    |> castError(DeleteNotificationSoundError.self)
    |> mapToSignal { sound -> Signal<Never, DeleteNotificationSoundError> in
        guard let sound = sound else {
            return .fail(.generic)
        }
        guard let resource = sound.file.resource as? CloudDocumentMediaResource else {
            return .fail(.generic)
        }
        
        return account.network.request(Api.functions.account.saveRingtone(id: .inputDocument(id: resource.fileId, accessHash: resource.accessHash, fileReference: Buffer(data: resource.fileReference)), unsave: .boolTrue))
        |> mapError { _ -> DeleteNotificationSoundError in
            return .generic
        }
        |> mapToSignal { _ -> Signal<Never, DeleteNotificationSoundError> in
            return account.postbox.transaction { transaction -> Void in
                if let notificationSoundList = _internal_cachedNotificationSoundList(transaction: transaction) {
                    let updatedNotificationSoundList = NotificationSoundList(hash: notificationSoundList.hash, sounds: notificationSoundList.sounds.filter { item in
                        return item.file.fileId.id != fileId
                    })
                    _internal_setCachedNotificationSoundList(transaction: transaction, notificationSoundList: updatedNotificationSoundList)
                }
            }
            |> castError(DeleteNotificationSoundError.self)
            |> ignoreValues
        }
    }
}

public func resolvedNotificationSound(sound: PeerMessageSound, notificationSoundList: NotificationSoundList?) -> PeerMessageSound {
    switch sound {
    case let .cloud(fileId):
        if let notificationSoundList = notificationSoundList {
            for listSound in notificationSoundList.sounds {
                if listSound.file.fileId.id == fileId {
                    return sound
                }
            }
            return defaultCloudPeerNotificationSound
        } else {
            return .default
        }
    default:
        return sound
    }
}
