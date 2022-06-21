import SwiftSignalKit
import Postbox

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

        public func addStickerPackInteractively(info: StickerPackCollectionInfo, items: [ItemCollectionItem], positionInList: Int? = nil) -> Signal<Void, NoError> {
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
        
        public func updateQuickReaction(reaction: String) -> Signal<Never, NoError> {
            let _ = updateReactionSettingsInteractively(postbox: self.account.postbox, { settings in
                var settings = settings
                settings.quickReaction = reaction
                return settings
            }).start()
            return _internal_updateDefaultReaction(account: self.account, reaction: reaction)
        }
    }
}
