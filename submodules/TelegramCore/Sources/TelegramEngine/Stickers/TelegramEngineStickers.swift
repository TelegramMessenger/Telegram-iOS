import SwiftSignalKit
import Postbox
import TelegramApi

public extension TelegramEngine {
    final class Stickers {
        private let account: Account

        init(account: Account) {
            self.account = account
        }

        public func archivedStickerPacks(namespace: ArchivedStickerPacksNamespace = .stickers) -> Signal<[ArchivedStickerPackItem], NoError> {
            return _internal_archivedStickerPacks(account: account, namespace: namespace)
        }

        public func removeArchivedStickerPack(info: StickerPackCollectionInfo) -> Signal<Void, NoError> {
            return _internal_removeArchivedStickerPack(account: self.account, info: info)
        }

        public func cachedStickerPack(reference: StickerPackReference, forceRemote: Bool) -> Signal<CachedStickerPackResult, NoError> {
            return _internal_cachedStickerPack(postbox: self.account.postbox, network: self.account.network, reference: reference, forceRemote: forceRemote)
        }

        public func loadedStickerPack(reference: StickerPackReference, forceActualized: Bool) -> Signal<LoadedStickerPack, NoError> {
            return _internal_loadedStickerPack(postbox: self.account.postbox, network: self.account.network, reference: reference, forceActualized: forceActualized)
        }

        public func randomGreetingSticker() -> Signal<FoundStickerItem?, NoError> {
            return _internal_randomGreetingSticker(account: self.account)
        }

        public func searchStickers(query: String, scope: SearchStickersScope = [.installed, .remote]) -> Signal<[FoundStickerItem], NoError> {
            return _internal_searchStickers(account: self.account, query: query, scope: scope)
        }

        public func searchStickerSetsRemotely(query: String) -> Signal<FoundStickerSets, NoError> {
            return _internal_searchStickerSetsRemotely(network: self.account.network, query: query)
        }

        public func searchStickerSets(query: String) -> Signal<FoundStickerSets, NoError> {
            return _internal_searchStickerSets(postbox: self.account.postbox, query: query)
        }

        public func searchGifs(query: String, nextOffset: String = "") -> Signal<ChatContextResultCollection?, NoError> {
            return _internal_searchGifs(account: self.account, query: query, nextOffset: nextOffset)
        }

        public func addStickerPackInteractively(info: StickerPackCollectionInfo, items: [StickerPackItem], positionInList: Int? = nil) -> Signal<Void, NoError> {
            return _internal_addStickerPackInteractively(postbox: self.account.postbox, info: info, items: items, positionInList: positionInList)
        }

        public func removeStickerPackInteractively(id: ItemCollectionId, option: RemoveStickerPackOption) -> Signal<(Int, [ItemCollectionItem])?, NoError> {
            return _internal_removeStickerPackInteractively(postbox: self.account.postbox, id: id, option: option)
        }

        public func removeStickerPacksInteractively(ids: [ItemCollectionId], option: RemoveStickerPackOption) -> Signal<(Int, [ItemCollectionItem])?, NoError> {
            return _internal_removeStickerPacksInteractively(postbox: self.account.postbox, ids: ids, option: option)
        }

        public func markFeaturedStickerPacksAsSeenInteractively(ids: [ItemCollectionId]) -> Signal<Void, NoError> {
            return _internal_markFeaturedStickerPacksAsSeenInteractively(postbox: self.account.postbox, ids: ids)
        }

        public func searchEmojiKeywords(inputLanguageCode: String, query: String, completeMatch: Bool) -> Signal<[EmojiKeywordItem], NoError> {
            return _internal_searchEmojiKeywords(postbox: self.account.postbox, inputLanguageCode: inputLanguageCode, query: query, completeMatch: completeMatch)
        }

        public func stickerPacksAttachedToMedia(media: AnyMediaReference) -> Signal<[StickerPackReference], NoError> {
            return _internal_stickerPacksAttachedToMedia(account: self.account, media: media)
        }
        
        public func uploadSticker(peer: Peer, resource: MediaResource, alt: String, dimensions: PixelDimensions, mimeType: String) -> Signal<UploadStickerStatus, UploadStickerError> {
            return _internal_uploadSticker(account: self.account, peer: peer, resource: resource, alt: alt, dimensions: dimensions, mimeType: mimeType)
        }
        
        public func createStickerSet(title: String, shortName: String, stickers: [ImportSticker], thumbnail: ImportSticker?, type: CreateStickerSetType, software: String?) -> Signal<CreateStickerSetStatus, CreateStickerSetError> {
            return _internal_createStickerSet(account: self.account, title: title, shortName: shortName, stickers: stickers, thumbnail: thumbnail, type: type, software: software)
        }
        
        public func getStickerSetShortNameSuggestion(title: String) -> Signal<String?, NoError> {
            return _internal_getStickerSetShortNameSuggestion(account: self.account, title: title)
        }
        
        public func toggleStickerSaved(file: TelegramMediaFile, saved: Bool) -> Signal<SavedStickerResult, AddSavedStickerError> {
            return _internal_toggleStickerSaved(postbox: self.account.postbox, network: self.account.network, accountPeerId: self.account.peerId, file: file, saved: saved)
        }
        
        public func validateStickerSetShortNameInteractive(shortName: String) -> Signal<AddressNameValidationStatus, NoError> {
            if let error = _internal_checkAddressNameFormat(shortName) {
                return .single(.invalidFormat(error))
            } else {
                return .single(.checking)
                |> then(
                    _internal_stickerSetShortNameAvailability(account: self.account, shortName: shortName)
                    |> delay(0.3, queue: Queue.concurrentDefaultQueue())
                    |> map { result -> AddressNameValidationStatus in
                        .availability(result)
                    }
                )
            }
        }
        
        public func availableReactions() -> Signal<AvailableReactions?, NoError> {
            return _internal_cachedAvailableReactions(postbox: self.account.postbox)
        }
        
        public func updateQuickReaction(reaction: MessageReaction.Reaction) -> Signal<Never, NoError> {
            let _ = updateReactionSettingsInteractively(postbox: self.account.postbox, { settings in
                var settings = settings
                settings.quickReaction = reaction
                return settings
            }).start()
            return _internal_updateDefaultReaction(account: self.account, reaction: reaction)
        }
        
        public func isStickerSaved(id: EngineMedia.Id) -> Signal<Bool, NoError> {
            return self.account.postbox.transaction { transaction -> Bool in
                return getIsStickerSaved(transaction: transaction, fileId: id)
            }
        }
        
        public func isGifSaved(id: EngineMedia.Id) -> Signal<Bool, NoError> {
            return self.account.postbox.transaction { transaction -> Bool in
                return getIsGifSaved(transaction: transaction, mediaId: id)
            }
        }
        
        public func clearRecentlyUsedStickers() -> Signal<Never, NoError> {
            return self.account.postbox.transaction { transaction -> Void in
                _internal_clearRecentlyUsedStickers(transaction: transaction)
            }
            |> ignoreValues
        }
        
        public func clearRecentlyUsedEmoji() -> Signal<Never, NoError> {
            return self.account.postbox.transaction { transaction -> Void in
                _internal_clearRecentlyUsedEmoji(transaction: transaction)
            }
            |> ignoreValues
        }
        
        public func clearRecentlyUsedReactions() -> Signal<Never, NoError> {
            let _ = self.account.postbox.transaction({ transaction -> Void in
                transaction.replaceOrderedItemListItems(collectionId: Namespaces.OrderedItemList.CloudRecentReactions, items: [])
            }).start()
            
            return self.account.network.request(Api.functions.messages.clearRecentReactions())
            |> `catch` { _ -> Signal<Api.Bool, NoError> in
                return .single(.boolFalse)
            }
            |> ignoreValues
        }
        
        public func reorderStickerPacks(namespace: ItemCollectionId.Namespace, itemIds: [ItemCollectionId]) -> Signal<Never, NoError> {
            return self.account.postbox.transaction { transaction -> Void in
                let infos = transaction.getItemCollectionsInfos(namespace: namespace)
                
                var packDict: [ItemCollectionId: Int] = [:]
                for i in 0 ..< infos.count {
                    packDict[infos[i].0] = i
                }
                var tempSortedPacks: [(ItemCollectionId, ItemCollectionInfo)] = []
                var processedPacks = Set<ItemCollectionId>()
                for id in itemIds {
                    if let index = packDict[id] {
                        tempSortedPacks.append(infos[index])
                        processedPacks.insert(id)
                    }
                }
                let restPacks = infos.filter { !processedPacks.contains($0.0) }
                let sortedPacks = restPacks + tempSortedPacks
                addSynchronizeInstalledStickerPacksOperation(transaction: transaction, namespace: namespace, content: .sync, noDelay: false)
                transaction.replaceItemCollectionInfos(namespace: namespace, itemCollectionInfos: sortedPacks)
            }
            |> ignoreValues
        }
        
        public func resolveInlineStickers(fileIds: [Int64]) -> Signal<[Int64: TelegramMediaFile], NoError> {
            return _internal_resolveInlineStickers(postbox: self.account.postbox, network: self.account.network, fileIds: fileIds)
        }
    }
}

func _internal_resolveInlineStickers(postbox: Postbox, network: Network, fileIds: [Int64]) -> Signal<[Int64: TelegramMediaFile], NoError> {
    return postbox.transaction { transaction -> [Int64: TelegramMediaFile] in
        var cachedFiles: [Int64: TelegramMediaFile] = [:]
        for fileId in fileIds {
            if let file = transaction.getMedia(MediaId(namespace: Namespaces.Media.CloudFile, id: fileId)) as? TelegramMediaFile {
                cachedFiles[fileId] = file
            }
        }
        return cachedFiles
    }
    |> mapToSignal { cachedFiles -> Signal<[Int64: TelegramMediaFile], NoError> in
        if cachedFiles.count == fileIds.count {
            return .single(cachedFiles)
        }
        
        var unknownIds = Set<Int64>()
        for fileId in fileIds {
            if cachedFiles[fileId] == nil {
                unknownIds.insert(fileId)
            }
        }
        
        return network.request(Api.functions.messages.getCustomEmojiDocuments(documentId: Array(unknownIds)))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<[Api.Document]?, NoError> in
            return .single(nil)
        }
        |> mapToSignal { result -> Signal<[Int64: TelegramMediaFile], NoError> in
            guard let result = result else {
                return .single(cachedFiles)
            }
            return postbox.transaction { transaction -> [Int64: TelegramMediaFile] in
                var resultFiles: [Int64: TelegramMediaFile] = cachedFiles
                for document in result {
                    if let file = telegramMediaFileFromApiDocument(document) {
                        resultFiles[file.fileId.id] = file
                        transaction.storeMediaIfNotPresent(media: file)
                    }
                }
                return resultFiles
            }
        }
    }
}
