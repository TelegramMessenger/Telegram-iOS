import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi
import MtProtoKit
import EncryptionProvider

/// The steps of `ReplayContext.finalize`, after every operation, in its order.
extension ReplayContext {
    /// Adds each previous-state hole, from its start to just below the batch's top message there (to the end when the
    /// batch added none), and in the pinned tag from 1.
    func addHolesFromPreviousState() {
        for messageId in holesFromPreviousStateMessageIds {
            let upperId: MessageId.Id
            if let value = topUpperHistoryBlockMessages[PeerIdAndMessageNamespace(peerId: messageId.peerId, namespace: messageId.namespace)], value < Int32.max {
                upperId = value - 1
            } else {
                upperId = Int32.max
            }
            if upperId >= messageId.id {
                transaction.addHole(peerId: messageId.peerId, threadId: nil, namespace: messageId.namespace, space: .everywhere, range: messageId.id ... upperId)

                transaction.addHole(peerId: messageId.peerId, threadId: nil, namespace: messageId.namespace, space: .tag(.pinned), range: 1 ... upperId)

                Logger.shared.log("State", "adding hole for peer \(messageId.peerId), \(messageId.id) ... \(upperId)")
            } else {
                Logger.shared.log("State", "not adding hole for peer \(messageId.peerId), \(upperId) >= \(messageId.id) = false")
            }
        }
    }
    
    /// For each forum whose topic list was reset: re-opens every stored thread's history, then stores the reloaded
    /// topics, or clears the forum's thread state when the reload failed.
    func applyForumTopicListResets() {
        var resetForumTopicResults: [LoadMessageHistoryThreadsResult] = []
        for (peerId, result) in finalState.state.resetForumTopicLists {
            for item in transaction.getMessageHistoryThreadIndex(peerId: peerId, limit: 10000) {
                let holeLowerBound = transaction.holeLowerBoundForTopValidRange(peerId: peerId, threadId: item.threadId, namespace: Namespaces.Message.Cloud, space: .everywhere)

                transaction.addHole(peerId: peerId, threadId: item.threadId, namespace: Namespaces.Message.Cloud, space: .everywhere, range: holeLowerBound ... (Int32.max - 1))
                for tag in MessageTags.all {
                    transaction.addHole(peerId: peerId, threadId: item.threadId, namespace: Namespaces.Message.Cloud, space: .tag(tag), range: holeLowerBound ... (Int32.max - 1))
                }
            }

            switch result {
            case let .result(value):
                resetForumTopicResults.append(value)
            case .error:
                transaction.setPeerThreadCombinedState(peerId: peerId, state: nil)
            }
        }
        if !resetForumTopicResults.isEmpty {
            applyLoadMessageHistoryThreadsResults(accountPeerId: accountPeerId, transaction: transaction, results: resetForumTopicResults)
        }
    }
    
    /// Applies each thread's reply-count change collected by the operations.
    func applyMessageThreadStatsDifferences() {
        for (threadKey, difference) in messageThreadStatsDifferences {
            updateMessageThreadStats(transaction: transaction, threadKey: threadKey, removedCount: difference.removedCount, addedMessagePeers: difference.peers)
        }
    }
    
    /// Updates the last activity of the peers the replay saw active (authors of incoming messages, readers of outgoing
    /// ones).
    func applyPeerActivityTimestamps() {
        if !peerActivityTimestamps.isEmpty {
            updatePeerPresenceLastActivities(transaction: transaction, accountPeerId: accountPeerId, activities: peerActivityTimestamps)
        }
    }
    
    /// Applies the installed sticker pack operations in order, or queues a sync of each namespace it cannot apply them
    /// to.
    func applyStickerPackOperations() {
        if !stickerPackOperations.isEmpty {
            if stickerPackOperations.contains(where: {
                if case .sync = $0 {
                    return true
                } else {
                    return false
                }
            }) {
                addSynchronizeInstalledStickerPacksOperation(transaction: transaction, namespace: .stickers, content: .sync, noDelay: false)
                addSynchronizeInstalledStickerPacksOperation(transaction: transaction, namespace: .masks, content: .sync, noDelay: false)
                addSynchronizeInstalledStickerPacksOperation(transaction: transaction, namespace: .emoji, content: .sync, noDelay: false)
            } else {
                var syncStickers = false
                var syncMasks = false
                var syncEmoji = false
                loop: for operation in stickerPackOperations {
                    switch operation {
                        case let .add(apiSet):
                            let namespace: ItemCollectionId.Namespace
                            var items: [ItemCollectionItem] = []
                            let info: StickerPackCollectionInfo
                            if case let .stickerSet(stickerSetData) = apiSet {
                                let (set, packs, keywords, documents) = (stickerSetData.set, stickerSetData.packs, stickerSetData.keywords, stickerSetData.documents)
                                var indexKeysByFile: [MediaId: [MemoryBuffer]] = [:]
                                for pack in packs {
                                    switch pack {
                                    case let .stickerPack(stickerPackData):
                                        let (text, fileIds) = (stickerPackData.emoticon, stickerPackData.documents)
                                        let key = ValueBoxKey(text).toMemoryBuffer()
                                        for fileId in fileIds {
                                            let mediaId = MediaId(namespace: Namespaces.Media.CloudFile, id: fileId)
                                            if indexKeysByFile[mediaId] == nil {
                                                indexKeysByFile[mediaId] = [key]
                                            } else {
                                                indexKeysByFile[mediaId]!.append(key)
                                            }
                                        }
                                        break
                                    }
                                }
                                for keyword in keywords {
                                    switch keyword {
                                    case let .stickerKeyword(stickerKeywordData):
                                        let (documentId, texts) = (stickerKeywordData.documentId, stickerKeywordData.keyword)
                                        for text in texts {
                                            let key = ValueBoxKey(text).toMemoryBuffer()
                                            let mediaId = MediaId(namespace: Namespaces.Media.CloudFile, id: documentId)
                                            if indexKeysByFile[mediaId] == nil {
                                                indexKeysByFile[mediaId] = [key]
                                            } else {
                                                indexKeysByFile[mediaId]!.append(key)
                                            }
                                        }
                                    }
                                }

                                for apiDocument in documents {
                                    if let file = telegramMediaFileFromApiDocument(apiDocument, altDocuments: []), let id = file.id {
                                        let fileIndexKeys: [MemoryBuffer]
                                        if let indexKeys = indexKeysByFile[id] {
                                            fileIndexKeys = indexKeys
                                        } else {
                                            fileIndexKeys = []
                                        }
                                        items.append(StickerPackItem(index: ItemCollectionItemIndex(index: Int32(items.count), id: id.id), file: file, indexKeys: fileIndexKeys))
                                    }
                                }
                                switch set {
                                    case let .stickerSet(stickerSetData):
                                        let flags = stickerSetData.flags
                                        if (flags & (1 << 3)) != 0 {
                                            namespace = Namespaces.ItemCollection.CloudMaskPacks
                                        } else if (flags & (1 << 7)) != 0 {
                                            namespace = Namespaces.ItemCollection.CloudEmojiPacks
                                        } else {
                                            namespace = Namespaces.ItemCollection.CloudStickerPacks
                                        }
                                }

                                info = StickerPackCollectionInfo(apiSet: set, namespace: namespace)

                                if namespace == Namespaces.ItemCollection.CloudMaskPacks && syncMasks {
                                    continue loop
                                } else if namespace == Namespaces.ItemCollection.CloudStickerPacks && syncStickers {
                                    continue loop
                                } else if namespace == Namespaces.ItemCollection.CloudEmojiPacks && syncEmoji {
                                    continue loop
                                }

                                var updatedInfos = transaction.getItemCollectionsInfos(namespace: info.id.namespace).map { $0.1 as! StickerPackCollectionInfo }
                                if let index = updatedInfos.firstIndex(where: { $0.id == info.id }) {
                                    let currentInfo = updatedInfos[index]
                                    updatedInfos.remove(at: index)
                                    updatedInfos.insert(currentInfo, at: 0)
                                } else {
                                    updatedInfos.insert(info, at: 0)
                                    transaction.replaceItemCollectionItems(collectionId: info.id, items: items)
                                }
                                transaction.replaceItemCollectionInfos(namespace: info.id.namespace, itemCollectionInfos: updatedInfos.map { ($0.id, $0) })
                            }
                        case let .reorder(namespace, ids):
                            let collectionNamespace: ItemCollectionId.Namespace
                            switch namespace {
                                case .stickers:
                                    collectionNamespace = Namespaces.ItemCollection.CloudStickerPacks
                                case .masks:
                                    collectionNamespace = Namespaces.ItemCollection.CloudMaskPacks
                                case .emoji:
                                    collectionNamespace = Namespaces.ItemCollection.CloudEmojiPacks
                            }
                            let currentInfos = transaction.getItemCollectionsInfos(namespace: collectionNamespace).map { $0.1 as! StickerPackCollectionInfo }
                            if Set(currentInfos.map { $0.id.id }) != Set(ids) {
                                switch namespace {
                                    case .stickers:
                                        syncStickers = true
                                    case .masks:
                                        syncMasks = true
                                    case .emoji:
                                        syncEmoji = true
                                }
                            } else {
                                var currentDict: [ItemCollectionId: StickerPackCollectionInfo] = [:]
                                for info in currentInfos {
                                    currentDict[info.id] = info
                                }
                                var updatedInfos: [StickerPackCollectionInfo] = []
                                for id in ids {
                                    let currentInfo = currentDict[ItemCollectionId(namespace: collectionNamespace, id: id)]!
                                    updatedInfos.append(currentInfo)
                                }
                                transaction.replaceItemCollectionInfos(namespace: collectionNamespace, itemCollectionInfos: updatedInfos.map { ($0.id, $0) })
                            }
                        case let .reorderToTop(namespace, ids):
                            let collectionNamespace: ItemCollectionId.Namespace
                            switch namespace {
                            case .stickers:
                                collectionNamespace = Namespaces.ItemCollection.CloudStickerPacks
                            case .masks:
                                collectionNamespace = Namespaces.ItemCollection.CloudMaskPacks
                            case .emoji:
                                collectionNamespace = Namespaces.ItemCollection.CloudEmojiPacks
                            }
                            let currentInfos = transaction.getItemCollectionsInfos(namespace: collectionNamespace).map { $0.1 as! StickerPackCollectionInfo }

                            var currentDict: [ItemCollectionId: StickerPackCollectionInfo] = [:]
                            for info in currentInfos {
                                currentDict[info.id] = info
                            }
                            var updatedInfos: [StickerPackCollectionInfo] = []
                            for id in ids {
                                if let currentInfo = currentDict[ItemCollectionId(namespace: collectionNamespace, id: id)] {
                                    updatedInfos.append(currentInfo)
                                }
                            }
                            for info in currentInfos {
                                if !updatedInfos.contains(where: { $0.id == info.id }) {
                                    updatedInfos.append(info)
                                }
                            }
                            transaction.replaceItemCollectionInfos(namespace: collectionNamespace, itemCollectionInfos: updatedInfos.map { ($0.id, $0) })
                        case .sync:
                            syncStickers = true
                            syncMasks = true
                            syncEmoji = true
                            break loop
                    }
                }
                if syncStickers {
                    addSynchronizeInstalledStickerPacksOperation(transaction: transaction, namespace: .stickers, content: .sync, noDelay: false)
                }
                if syncMasks {
                    addSynchronizeInstalledStickerPacksOperation(transaction: transaction, namespace: .masks, content: .sync, noDelay: false)
                }
                if syncEmoji {
                    addSynchronizeInstalledStickerPacksOperation(transaction: transaction, namespace: .emoji, content: .sync, noDelay: false)
                }
            }
        }
    }
    
    /// Moves the stickers the account sent to the top of the recent stickers, oldest first.
    func addRecentlyUsedStickers() {
        if !recentlyUsedStickers.isEmpty {
            let stickerFiles: [TelegramMediaFile] = recentlyUsedStickers.values.sorted(by: {
                return $0.0 < $1.0
            }).map({ $0.1 })
            for file in stickerFiles {
                if let entry = CodableEntry(RecentMediaItem(file)) {
                    transaction.addOrMoveToFirstPositionOrderedItemListItem(collectionId: Namespaces.OrderedItemList.CloudRecentStickers, item: OrderedItemListEntry(id: RecentMediaItemId(file.fileId).rawValue, contents: entry), removeTailIfCountExceeds: 20)
                }
            }
        }
    }
    
    /// Stores, for each slow-mode group the account sent to without admin rights, until when it may send again.
    func applySlowModeTimeouts() {
        if !slowModeLastMessageTimeouts.isEmpty {
            var peerIds:Set<PeerId> = Set()
            var cachedDatas:[PeerId : CachedChannelData] = [:]
            for (peerId, timeout) in slowModeLastMessageTimeouts {
                if let peer = transaction.getPeer(peerId) {
                    if let peer = peer as? TelegramChannel {
                        inner: switch peer.info {
                        case let .group(info):
                            if info.flags.contains(.slowModeEnabled), peer.adminRights == nil && !peer.flags.contains(.isCreator)  {
                                var cachedData = transaction.getPeerCachedData(peerId: peerId) as? CachedChannelData ?? CachedChannelData()
                                if let slowModeTimeout = cachedData.slowModeTimeout {
                                    cachedData = cachedData.withUpdatedSlowModeValidUntilTimestamp(timeout + slowModeTimeout)
                                    peerIds.insert(peerId)
                                    cachedDatas[peerId] = cachedData
                                }
                            }
                        default:
                            break inner
                        }
                    }
                }
            }
            transaction.updatePeerCachedData(peerIds: peerIds, update: { peerId, current in
                return cachedDatas[peerId] ?? current
            })
        }
    }
    
    /// Queues a saved-GIFs sync when one was asked for, or else moves the GIFs the account sent to the top of the
    /// recent GIFs.
    func applyRecentGifs() {
        if syncRecentGifs {
            addSynchronizeSavedGifsOperation(transaction: transaction, operation: .sync)
        } else {
            let gifFiles: [TelegramMediaFile] = recentlyUsedGifs.values.sorted(by: {
                return $0.0 < $1.0
            }).map({ $0.1 })
            for file in gifFiles {
                if !file.hasLinkedStickers {
                    if let entry = CodableEntry(RecentMediaItem(file)) {
                        transaction.addOrMoveToFirstPositionOrderedItemListItem(collectionId: Namespaces.OrderedItemList.CloudRecentGifs, item: OrderedItemListEntry(id: RecentMediaItemId(file.fileId).rawValue, contents: entry), removeTailIfCountExceeds: 200)
                    }
                }
            }
        }
    }
    
    /// Records the authors of incoming guest-chat messages to the account as recently used inline bots.
    func addRecentlyUsedGuestChatBots() {
        for peerId in recentlyUsedGuestChatBots {
            _internal_addRecentlyUsedInlineBot(transaction: transaction, peerId: peerId)
        }
    }
    
    /// Marks the peer groups whose message stats changed for synchronization.
    func invalidatePeerGroupStats() {
        for groupId in invalidateGroupStats {
            transaction.setNeedsPeerGroupMessageStatsSynchronization(groupId: groupId, namespace: Namespaces.Message.Cloud)
        }
    }
    
    /// Turns each secret chat's typing notification into a typing activity of the chat's peer.
    func addSecretChatTypingActivities() {
        for chatPeerId in updatedSecretChatTypingActivities {
            if let peer = transaction.getPeer(chatPeerId) as? TelegramSecretChat {
                let authorId = peer.regularPeerId
                let activityValue: PeerInputActivity? = .typingText
                if updatedTypingActivities[PeerActivitySpace(peerId: chatPeerId, category: .global)] == nil {
                    updatedTypingActivities[PeerActivitySpace(peerId: chatPeerId, category: .global)] = [authorId: activityValue]
                } else {
                    updatedTypingActivities[PeerActivitySpace(peerId: chatPeerId, category: .global)]![authorId] = activityValue
                }
            }
        }
    }
    
    /// Reads the archive privacy setting, then decrypts each secret chat's queued messages, pass after pass until a
    /// pass leaves its keychain unchanged. After a pass that adds messages, a chat in the archive moves to the root
    /// chat list when `keepArchivedUnmuted` is off, its peer is a `TelegramSecretChat` and it counts toward the total
    /// unread count (`resolvedIsRemovedFromTotalUnreadCount`, read with the regular peer's notification settings, is
    /// false). The added messages' ids and each chat's first author are recorded.
    func processAddedSecretMessages() {
        let keepArchivedUnmuted = fetchGlobalPrivacySettings(transaction: transaction).keepArchivedUnmuted

        for peerId in peerIdsWithAddedSecretMessages {
            inner: while true {
                let keychain = (transaction.getPeerChatState(peerId) as? SecretChatState)?.keychain
                if processSecretChatIncomingEncryptedOperations(transaction: transaction, peerId: peerId) {
                    let processResult = processSecretChatIncomingDecryptedOperations(encryptionProvider: encryptionProvider, mediaBox: mediaBox, transaction: transaction, peerId: peerId)
                    if !processResult.addedMessages.isEmpty {
                        let currentInclusion = transaction.getPeerChatListInclusion(peerId)
                        if let groupId = currentInclusion.groupId, groupId == Namespaces.PeerGroup.archive, !keepArchivedUnmuted {
                            if let peer = transaction.getPeer(peerId) as? TelegramSecretChat {
                                let isRemovedFromTotalUnreadCount = resolvedIsRemovedFromTotalUnreadCount(globalSettings: transaction.getGlobalNotificationSettings(), peer: peer, peerSettings: transaction.getPeerNotificationSettings(id: peer.regularPeerId))

                                if !isRemovedFromTotalUnreadCount {
                                    transaction.updatePeerChatListInclusion(peerId, inclusion: currentInclusion.withGroupId(groupId: .root))
                                }
                            }
                        }
                        for message in processResult.addedMessages {
                            if case let .Id(id) = message.id {
                                addedSecretMessageIds.append(id)
                                if let authorId = message.authorId {
                                    if addedSecretMessageAuthorIds[peerId] == nil {
                                        addedSecretMessageAuthorIds[peerId] = authorId
                                    }
                                }
                            }
                        }
                    }
                }
                let updatedKeychain = (transaction.getPeerChatState(peerId) as? SecretChatState)?.keychain
                if updatedKeychain == keychain {
                    break inner
                }
            }
        }
    }
    
    /// Clears the typing activity of each author of a decrypted secret message.
    func clearTypingOfSecretMessageAuthors() {
        for (chatPeerId, authorId) in addedSecretMessageAuthorIds {
            let activityValue: PeerInputActivity? = nil
            if updatedTypingActivities[PeerActivitySpace(peerId: chatPeerId, category: .global)] == nil {
                updatedTypingActivities[PeerActivitySpace(peerId: chatPeerId, category: .global)] = [authorId: activityValue]
            } else {
                updatedTypingActivities[PeerActivitySpace(peerId: chatPeerId, category: .global)]![authorId] = activityValue
            }
        }
    }
    
    /// Fire-and-forget: queues a localization sync when a pack must be polled; otherwise applies the differences,
    /// oldest first, in an account-manager transaction.
    func applyLangPackDifferences() {
        if !pollLangPacks.isEmpty {
            addSynchronizeLocalizationUpdatesOperation(transaction: transaction)
        } else {
            let _ = (accountManager.transaction { [langPackDifferences = self.langPackDifferences, postbox = self.postbox] transaction -> Void in
                outer: for (langCode, langPackDifference) in langPackDifferences {
                    if !langPackDifference.isEmpty {
                        let sortedLangPackDifference = langPackDifference.sorted(by: { lhs, rhs in
                            let lhsVersion: Int32
                            switch lhs {
                                case let .langPackDifference(langPackDifferenceData):
                                    let (fromVersion) = (langPackDifferenceData.fromVersion)
                                    lhsVersion = fromVersion
                            }
                            let rhsVersion: Int32
                            switch rhs {
                                case let .langPackDifference(langPackDifferenceData):
                                    let (fromVersion) = (langPackDifferenceData.fromVersion)
                                    rhsVersion = fromVersion
                            }
                            return lhsVersion < rhsVersion
                        })

                        for difference in sortedLangPackDifference {
                            if !tryApplyingLanguageDifference(transaction: transaction, langCode: langCode, difference: difference) {
                                let _ = (postbox.transaction { transaction -> Void in
                                    addSynchronizeLocalizationUpdatesOperation(transaction: transaction)
                                }).start()
                                break outer
                            }
                        }
                    }
                }
            }).start()
        }
    }
    
    /// Stores the updated cloud themes and, fire-and-forget in an account-manager transaction, the current theme when
    /// it is one of them.
    func applyUpdatedThemes() {
        if !updatedThemes.isEmpty {
            let entries = transaction.getOrderedListItems(collectionId: Namespaces.OrderedItemList.CloudThemes)
            let themes = entries.map { entry -> TelegramTheme in
                let theme = entry.contents.get(TelegramThemeNativeCodable.self)!
                if let updatedTheme = updatedThemes[theme.value.id] {
                    return updatedTheme
                } else {
                    return theme.value
                }
            }
            var updatedEntries: [OrderedItemListEntry] = []
            for theme in themes {
                var intValue = Int32(updatedEntries.count)
                let id = MemoryBuffer(data: Data(bytes: &intValue, count: 4))
                if let entry = CodableEntry(TelegramThemeNativeCodable(theme)) {
                    updatedEntries.append(OrderedItemListEntry(id: id, contents: entry))
                }
            }
            transaction.replaceOrderedItemListItems(collectionId: Namespaces.OrderedItemList.CloudThemes, items: updatedEntries)
            let _ = accountManager.transaction { [updatedThemes = self.updatedThemes] transaction in
                transaction.updateSharedData(SharedDataKeys.themeSettings, { current in
                    if let current = current?.get(ThemeSettings.self), let theme = current.currentTheme, let updatedTheme = updatedThemes[theme.id] {
                        return PreferencesEntry(ThemeSettings(currentTheme: updatedTheme))
                    }
                    return current
                })
            }.start()
        }
    }
    
    /// Applies the in-app browser settings changes in order.
    func applyWebBrowserSettingsUpdates() {
        if !webBrowserSettingsUpdates.isEmpty {
            transaction.updatePreferencesEntry(key: PreferencesKeys.webBrowserSettings, { current in
                var settings = current?.get(AccountWebBrowserSettings.self) ?? AccountWebBrowserSettings.defaultSettings
                for update in webBrowserSettingsUpdates {
                    settings = update(settings)
                }
                return PreferencesEntry(settings)
            })
        }
    }
    
    /// Stores each peer's updated wallpaper in its cached user data.
    func applyUpdatedWallpapers() {
        if !updatedWallpapers.isEmpty {
            for (peerId, wallpaper) in updatedWallpapers {
                transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { _, current in
                    if let current = current as? CachedUserData {
                        return current.withUpdatedWallpaper(wallpaper)
                    } else {
                        var cachedData = CachedUserData()
                        cachedData = cachedData.withUpdatedWallpaper(wallpaper)
                        return cachedData
                    }
                })
            }
        }
    }
    
    /// Adds the decrypted secret messages to the incoming messages the result reports.
    func addSecretMessagesToIncomingIds() {
        addedIncomingMessageIds.append(contentsOf: addedSecretMessageIds)
    }
    
    /// Reconciles each pending wallet transfer whose message id the final state resolved.
    func reconcileWalletTransferMessages() {
        for id in mappedWalletMessageIds {
            if let pending = transaction.getPendingMessageAction(type: .walletTransfer, id: id) as? PendingWalletTransferMessageAttribute {
                reconcileStoredWalletTransferMessage(transaction: transaction, id: id, pending: pending)
            }
        }
    }
    
    /// Deletes for everyone the confirmed outgoing messages the caller asked to remove if possibly delivered.
    func deletePossiblyDeliveredMessages() {
        for (uniqueId, messageIdValue) in finalState.state.updatedOutgoingUniqueMessageIds {
            if let peerId = removePossiblyDeliveredMessagesUniqueIds[uniqueId] {
                let messageId = MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: messageIdValue)
                deleteMessagesInteractively(transaction: transaction, stateManager: nil, postbox: postbox, messageIds: [messageId], type: .forEveryone, deleteAllInGroup: false, removeIfPossiblyDelivered: false)
            }
        }
    }
    
    /// Requests a chat folder sync when an operation asked for one or could not apply a folder change.
    func requestChatListFiltersSyncIfNeeded() {
        if syncChatListFilters {
            requestChatListFiltersSync(transaction: transaction)
        }
    }
    
    /// Queues a stories sync for each peer with an added story that the feed shows: a contact or member, neither hidden
    /// nor filtered.
    func synchronizeStoriesOfFeedPeers() {
        for update in storyUpdates {
            switch update {
            case let .added(peerId, _):
                var isContactOrMember = false
                if transaction.isPeerContact(peerId: peerId) {
                    isContactOrMember = true
                } else if let peer = transaction.getPeer(peerId) as? TelegramChannel {
                    if peer.participationStatus == .member {
                        isContactOrMember = true
                    }
                } else if let peer = transaction.getPeer(peerId) as? TelegramGroup {
                    if case .Member = peer.membership {
                        isContactOrMember = true
                    }
                }

                if shouldKeepUserStoriesInFeed(peerId: peerId, isContactOrMember: isContactOrMember) {
                    if !transaction.storySubscriptionsContains(key: .hidden, peerId: peerId) && !transaction.storySubscriptionsContains(key: .filtered, peerId: peerId) {
                        _internal_addSynchronizePeerStoriesOperation(peerId: peerId, transaction: transaction)
                    }
                }
            default:
                break
            }
        }
    }
    
    /// Stores the paid-reaction default privacy when an operation changed it.
    func applyStarsReactionsDefaultPrivacy() {
        if let updatedStarsReactionsDefaultPrivacy {
            _internal_setStarsReactionDefaultPrivacy(privacy: updatedStarsReactionsDefaultPrivacy, transaction: transaction)
        }
    }
    
    /// Applies the live typing drafts: a real message cancels its chat's draft, the latest update replaces it, a stop
    /// ends it.
    func applyLiveTypingDraftUpdates() {
        if !liveTypingDraftUpdates.isEmpty {
            for (key, updates) in liveTypingDraftUpdates {
                if key.threadId == nil {
                    var maxCancelledTimestamp: Int32?
                    for update in updates {
                        if case let .cancel(updatedTimestamp) = update {
                            if let current = maxCancelledTimestamp {
                                maxCancelledTimestamp = max(current, updatedTimestamp)
                            } else {
                                maxCancelledTimestamp = updatedTimestamp
                            }
                        }
                    }
                    if let maxCancelledTimestamp {
                        transaction.offsetPendingMessagesTimestamps(lowerBound: MessageId(peerId: key.peerId, namespace: Namespaces.Message.Local, id: 1), excludeIds: Set(), timestamp: maxCancelledTimestamp)
                    }
                }
            }
            transaction.combineTypingDrafts(locations: Set(liveTypingDraftUpdates.keys), update: { key, current in
                guard let updates = liveTypingDraftUpdates[key], !updates.isEmpty else {
                    return current
                }

                // A real message arrived: the draft is gone regardless of anything else in the batch.
                for update in updates {
                    if case .cancel = update {
                        return nil
                    }
                }

                // A stop applies on top of the latest update in the same batch, which is why this
                // is a reduction rather than a single max-by pick.
                var latestUpdate: LiveTypingDraftUpdate.Update?
                var latestStop: (randomId: Int64, timestamp: Int32)?
                for update in updates {
                    switch update {
                    case let .update(updateValue):
                        if let latestUpdateValue = latestUpdate {
                            if latestUpdateValue.timestamp < updateValue.timestamp {
                                latestUpdate = updateValue
                            }
                        } else {
                            latestUpdate = updateValue
                        }
                    case let .stop(randomId, timestamp):
                        if let latestStopValue = latestStop {
                            if latestStopValue.timestamp < timestamp {
                                latestStop = (randomId, timestamp)
                            }
                        } else {
                            latestStop = (randomId, timestamp)
                        }
                    case .cancel:
                        break
                    }
                }

                var result = current

                if let update = latestUpdate {
                    // A draft whose random_id differs from the current one is a *replacement*,
                    // not an edit — random_ids are opaque, so there is no ordering to defend.
                    // (This previously began `if let current, current.id > update.id { return current }`,
                    // which silently dropped a legitimately newer draft that happened to sort lower.)
                    let isSameDraft = current?.id == update.id

                    var timestamp = update.timestamp
                    if let current, isSameDraft {
                        timestamp = current.timestamp
                    }
                    if !isSameDraft {
                        if let index = transaction.getTopPeerMessageIndex(peerId: key.peerId) {
                            timestamp = max(timestamp, index.timestamp)
                        }
                    }

                    let draftText: String
                    let draftAttributes: [MessageAttribute]
                    let draftAttribute = TypingDraftMessageAttribute(randomId: update.id, canStop: update.canStop, keepOnStop: update.keepOnStop, isStopped: false)
                    switch update.content {
                    case let .plain(text, entities):
                        draftText = text
                        draftAttributes = [
                            draftAttribute,
                            TextEntitiesMessageAttribute(entities: entities)
                        ]
                    case let .rich(richData):
                        draftText = ""
                        draftAttributes = [
                            draftAttribute,
                            richData
                        ]
                    }

                    result = (
                        update.id,
                        Namespaces.Message.Cloud,
                        update.threadId,
                        update.authorId,
                        timestamp,
                        draftText,
                        draftAttributes,
                        false
                    )
                }

                if let latestStop, let value = result, value.id == latestStop.randomId {
                    if typingDraftKeepOnStop(value.attributes) {
                        result = stoppedTypingDraft(value)
                    } else {
                        result = nil
                    }
                }

                return result
            })
        }
    }
}
