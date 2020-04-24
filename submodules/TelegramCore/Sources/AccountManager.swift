import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

import SyncCore

private enum AccountKind {
    case authorized
    case unauthorized
}

private var declaredEncodables: Void = {
    declareEncodable(AuthAccountRecord.self, f: { AuthAccountRecord(decoder: $0) })
    declareEncodable(UnauthorizedAccountState.self, f: { UnauthorizedAccountState(decoder: $0) })
    declareEncodable(AuthorizedAccountState.self, f: { AuthorizedAccountState(decoder: $0) })
    declareEncodable(TelegramUser.self, f: { TelegramUser(decoder: $0) })
    declareEncodable(TelegramGroup.self, f: { TelegramGroup(decoder: $0) })
    declareEncodable(TelegramChannel.self, f: { TelegramChannel(decoder: $0) })
    declareEncodable(TelegramMediaImage.self, f: { TelegramMediaImage(decoder: $0) })
    declareEncodable(TelegramMediaImageRepresentation.self, f: { TelegramMediaImageRepresentation(decoder: $0) })
    declareEncodable(TelegramMediaContact.self, f: { TelegramMediaContact(decoder: $0) })
    declareEncodable(TelegramMediaMap.self, f: { TelegramMediaMap(decoder: $0) })
    declareEncodable(TelegramMediaFile.self, f: { TelegramMediaFile(decoder: $0) })
    declareEncodable(TelegramMediaFileAttribute.self, f: { TelegramMediaFileAttribute(decoder: $0) })
    declareEncodable(CloudFileMediaResource.self, f: { CloudFileMediaResource(decoder: $0) })
    declareEncodable(ChannelState.self, f: { ChannelState(decoder: $0) })
    declareEncodable(RegularChatState.self, f: { RegularChatState(decoder: $0) })
    declareEncodable(InlineBotMessageAttribute.self, f: { InlineBotMessageAttribute(decoder: $0) })
    declareEncodable(TextEntitiesMessageAttribute.self, f: { TextEntitiesMessageAttribute(decoder: $0) })
    declareEncodable(ReplyMessageAttribute.self, f: { ReplyMessageAttribute(decoder: $0) })
    declareEncodable(ReactionsMessageAttribute.self, f: { ReactionsMessageAttribute(decoder: $0) })
    declareEncodable(PendingReactionsMessageAttribute.self, f: { PendingReactionsMessageAttribute(decoder: $0) })
    declareEncodable(CloudDocumentMediaResource.self, f: { CloudDocumentMediaResource(decoder: $0) })
    declareEncodable(TelegramMediaWebpage.self, f: { TelegramMediaWebpage(decoder: $0) })
    declareEncodable(ViewCountMessageAttribute.self, f: { ViewCountMessageAttribute(decoder: $0) })
    declareEncodable(NotificationInfoMessageAttribute.self, f: { NotificationInfoMessageAttribute(decoder: $0) })
    declareEncodable(TelegramMediaAction.self, f: { TelegramMediaAction(decoder: $0) })
    declareEncodable(TelegramPeerNotificationSettings.self, f: { TelegramPeerNotificationSettings(decoder: $0) })
    declareEncodable(CachedUserData.self, f: { CachedUserData(decoder: $0) })
    declareEncodable(BotInfo.self, f: { BotInfo(decoder: $0) })
    declareEncodable(CachedGroupData.self, f: { CachedGroupData(decoder: $0) })
    declareEncodable(CachedChannelData.self, f: { CachedChannelData(decoder: $0) })
    declareEncodable(TelegramUserPresence.self, f: { TelegramUserPresence(decoder: $0) })
    declareEncodable(LocalFileMediaResource.self, f: { LocalFileMediaResource(decoder: $0) })
    declareEncodable(StickerPackCollectionInfo.self, f: { StickerPackCollectionInfo(decoder: $0) })
    declareEncodable(StickerPackItem.self, f: { StickerPackItem(decoder: $0) })
    declareEncodable(LocalFileReferenceMediaResource.self, f: { LocalFileReferenceMediaResource(decoder: $0) })
    declareEncodable(OutgoingMessageInfoAttribute.self, f: { OutgoingMessageInfoAttribute(decoder: $0) })
    declareEncodable(ForwardSourceInfoAttribute.self, f: { ForwardSourceInfoAttribute(decoder: $0) })
    declareEncodable(SourceReferenceMessageAttribute.self, f: { SourceReferenceMessageAttribute(decoder: $0) })
    declareEncodable(EditedMessageAttribute.self, f: { EditedMessageAttribute(decoder: $0) })
    declareEncodable(ReplyMarkupMessageAttribute.self, f: { ReplyMarkupMessageAttribute(decoder: $0) })
    declareEncodable(CachedResolvedByNamePeer.self, f: { CachedResolvedByNamePeer(decoder: $0) })
    declareEncodable(OutgoingChatContextResultMessageAttribute.self, f: { OutgoingChatContextResultMessageAttribute(decoder: $0) })
    declareEncodable(HttpReferenceMediaResource.self, f: { HttpReferenceMediaResource(decoder: $0) })
    declareEncodable(WebFileReferenceMediaResource.self, f: { WebFileReferenceMediaResource(decoder: $0) })
    declareEncodable(EmptyMediaResource.self, f: { EmptyMediaResource(decoder: $0) })
    declareEncodable(TelegramSecretChat.self, f: { TelegramSecretChat(decoder: $0) })
    declareEncodable(SecretChatState.self, f: { SecretChatState(decoder: $0) })
    declareEncodable(SecretChatIncomingEncryptedOperation.self, f: { SecretChatIncomingEncryptedOperation(decoder: $0) })
    declareEncodable(SecretChatIncomingDecryptedOperation.self, f: { SecretChatIncomingDecryptedOperation(decoder: $0) })
    declareEncodable(SecretChatOutgoingOperation.self, f: { SecretChatOutgoingOperation(decoder: $0) })
    declareEncodable(SecretFileMediaResource.self, f: { SecretFileMediaResource(decoder: $0) })
    declareEncodable(CloudChatRemoveMessagesOperation.self, f: { CloudChatRemoveMessagesOperation(decoder: $0) })
    declareEncodable(AutoremoveTimeoutMessageAttribute.self, f: { AutoremoveTimeoutMessageAttribute(decoder: $0) })
    declareEncodable(GlobalNotificationSettings.self, f: { GlobalNotificationSettings(decoder: $0) })
    declareEncodable(CloudChatRemoveChatOperation.self, f: { CloudChatRemoveChatOperation(decoder: $0) })
    declareEncodable(SynchronizePinnedChatsOperation.self, f: { SynchronizePinnedChatsOperation(decoder: $0) })
    declareEncodable(SynchronizeConsumeMessageContentsOperation.self, f: { SynchronizeConsumeMessageContentsOperation(decoder: $0) })
    declareEncodable(RecentMediaItem.self, f: { RecentMediaItem(decoder: $0) })
    declareEncodable(RecentPeerItem.self, f: { RecentPeerItem(decoder: $0) })
    declareEncodable(RecentHashtagItem.self, f: { RecentHashtagItem(decoder: $0) })
    declareEncodable(LoggedOutAccountAttribute.self, f: { LoggedOutAccountAttribute(decoder: $0) })
    declareEncodable(AccountEnvironmentAttribute.self, f: { AccountEnvironmentAttribute(decoder: $0) })
    declareEncodable(AccountSortOrderAttribute.self, f: { AccountSortOrderAttribute(decoder: $0) })
    declareEncodable(CloudChatClearHistoryOperation.self, f: { CloudChatClearHistoryOperation(decoder: $0) })
    declareEncodable(OutgoingContentInfoMessageAttribute.self, f: { OutgoingContentInfoMessageAttribute(decoder: $0) })
    declareEncodable(ConsumableContentMessageAttribute.self, f: { ConsumableContentMessageAttribute(decoder: $0) })
    declareEncodable(TelegramMediaGame.self, f: { TelegramMediaGame(decoder: $0) })
    declareEncodable(TelegramMediaInvoice.self, f: { TelegramMediaInvoice(decoder: $0) })
    declareEncodable(TelegramMediaWebFile.self, f: { TelegramMediaWebFile(decoder: $0) })
    declareEncodable(SynchronizeInstalledStickerPacksOperation.self, f: { SynchronizeInstalledStickerPacksOperation(decoder: $0) })
    declareEncodable(FeaturedStickerPackItem.self, f: { FeaturedStickerPackItem(decoder: $0) })
    declareEncodable(SynchronizeMarkFeaturedStickerPacksAsSeenOperation.self, f: { SynchronizeMarkFeaturedStickerPacksAsSeenOperation(decoder: $0) })
    declareEncodable(ArchivedStickerPacksInfo.self, f: { ArchivedStickerPacksInfo(decoder: $0) })
    declareEncodable(SynchronizeChatInputStateOperation.self, f: { SynchronizeChatInputStateOperation(decoder: $0) })
    declareEncodable(SynchronizeSavedGifsOperation.self, f: { SynchronizeSavedGifsOperation(decoder: $0) })
    declareEncodable(SynchronizeSavedStickersOperation.self, f: { SynchronizeSavedStickersOperation(decoder: $0) })
    declareEncodable(SynchronizeRecentlyUsedMediaOperation.self, f: { SynchronizeRecentlyUsedMediaOperation(decoder: $0) })
    declareEncodable(CacheStorageSettings.self, f: { CacheStorageSettings(decoder: $0) })
    declareEncodable(LocalizationSettings.self, f: { LocalizationSettings(decoder: $0) })
    declareEncodable(LocalizationListState.self, f: { LocalizationListState(decoder: $0) })
    declareEncodable(ProxySettings.self, f: { ProxySettings(decoder: $0) })
    declareEncodable(NetworkSettings.self, f: { NetworkSettings(decoder: $0) })
    declareEncodable(RemoteStorageConfiguration.self, f: { RemoteStorageConfiguration(decoder: $0) })
    declareEncodable(LimitsConfiguration.self, f: { LimitsConfiguration(decoder: $0) })
    declareEncodable(VoipConfiguration.self, f: { VoipConfiguration(decoder: $0) })
    declareEncodable(SuggestedLocalizationEntry.self, f: { SuggestedLocalizationEntry(decoder: $0) })
    declareEncodable(SynchronizeLocalizationUpdatesOperation.self, f: { SynchronizeLocalizationUpdatesOperation(decoder: $0) })
    declareEncodable(ChannelMessageStateVersionAttribute.self, f: { ChannelMessageStateVersionAttribute(decoder: $0) })
    declareEncodable(PeerGroupMessageStateVersionAttribute.self, f: { PeerGroupMessageStateVersionAttribute(decoder: $0) })
    declareEncodable(CachedSecretChatData.self, f: { CachedSecretChatData(decoder: $0) })
    declareEncodable(TemporaryTwoStepPasswordToken.self, f: { TemporaryTwoStepPasswordToken(decoder: $0) })
    declareEncodable(AuthorSignatureMessageAttribute.self, f: { AuthorSignatureMessageAttribute(decoder: $0) })
    declareEncodable(TelegramMediaExpiredContent.self, f: { TelegramMediaExpiredContent(decoder: $0) })
    declareEncodable(SavedStickerItem.self, f: { SavedStickerItem(decoder: $0) })
    declareEncodable(ConsumablePersonalMentionMessageAttribute.self, f: { ConsumablePersonalMentionMessageAttribute(decoder: $0) })
    declareEncodable(ConsumePersonalMessageAction.self, f: { ConsumePersonalMessageAction(decoder: $0) })
    declareEncodable(CachedStickerPack.self, f: { CachedStickerPack(decoder: $0) })
    declareEncodable(LoggingSettings.self, f: { LoggingSettings(decoder: $0) })
    declareEncodable(CachedLocalizationInfos.self, f: { CachedLocalizationInfos(decoder: $0) })
    declareEncodable(CachedSecureIdConfiguration.self, f: { CachedSecureIdConfiguration(decoder: $0) })
    declareEncodable(CachedWallpapersConfiguration.self, f: { CachedWallpapersConfiguration(decoder: $0) })
    declareEncodable(CachedThemesConfiguration.self, f: { CachedThemesConfiguration(decoder: $0) })
    declareEncodable(SynchronizeGroupedPeersOperation.self, f: { SynchronizeGroupedPeersOperation(decoder: $0) })
    declareEncodable(ContentPrivacySettings.self, f: { ContentPrivacySettings(decoder: $0) })
    declareEncodable(TelegramDeviceContactImportedData.self, f: { TelegramDeviceContactImportedData(decoder: $0) })
    declareEncodable(SecureFileMediaResource.self, f: { SecureFileMediaResource(decoder: $0) })
    declareEncodable(CachedStickerQueryResult.self, f: { CachedStickerQueryResult(decoder: $0) })
    declareEncodable(TelegramWallpaper.self, f: { TelegramWallpaper(decoder: $0) })
    declareEncodable(TelegramTheme.self, f: { TelegramTheme(decoder: $0) })
    declareEncodable(ThemeSettings.self, f: { ThemeSettings(decoder: $0) })
    declareEncodable(SynchronizeMarkAllUnseenPersonalMessagesOperation.self, f: { SynchronizeMarkAllUnseenPersonalMessagesOperation(decoder: $0) })
    declareEncodable(SynchronizeAppLogEventsOperation.self, f: { SynchronizeAppLogEventsOperation(decoder: $0) })
    declareEncodable(CachedRecentPeers.self, f: { CachedRecentPeers(decoder: $0) })
    declareEncodable(AppChangelogState.self, f: { AppChangelogState(decoder: $0) })
    declareEncodable(AppConfiguration.self, f: { AppConfiguration(decoder: $0) })
    declareEncodable(JSON.self, f: { JSON(decoder: $0) })
    declareEncodable(SearchBotsConfiguration.self, f: { SearchBotsConfiguration(decoder: $0) })
    declareEncodable(AutodownloadSettings.self, f: { AutodownloadSettings(decoder: $0 )})
    declareEncodable(TelegramMediaPoll.self, f: { TelegramMediaPoll(decoder: $0) })
    declareEncodable(TelegramMediaUnsupported.self, f: { TelegramMediaUnsupported(decoder: $0) })
    declareEncodable(ContactsSettings.self, f: { ContactsSettings(decoder: $0) })
    declareEncodable(SecretChatSettings.self, f: { SecretChatSettings(decoder: $0) })
    declareEncodable(EmojiKeywordCollectionInfo.self, f: { EmojiKeywordCollectionInfo(decoder: $0) })
    declareEncodable(EmojiKeywordItem.self, f: { EmojiKeywordItem(decoder: $0) })
    declareEncodable(SynchronizeEmojiKeywordsOperation.self, f: { SynchronizeEmojiKeywordsOperation(decoder: $0) })
    declareEncodable(CloudPhotoSizeMediaResource.self, f: { CloudPhotoSizeMediaResource(decoder: $0) })
    declareEncodable(CloudDocumentSizeMediaResource.self, f: { CloudDocumentSizeMediaResource(decoder: $0) })
    declareEncodable(CloudPeerPhotoSizeMediaResource.self, f: { CloudPeerPhotoSizeMediaResource(decoder: $0) })
    declareEncodable(CloudStickerPackThumbnailMediaResource.self, f: { CloudStickerPackThumbnailMediaResource(decoder: $0) })
    declareEncodable(AccountBackupDataAttribute.self, f: { AccountBackupDataAttribute(decoder: $0) })
    declareEncodable(ContentRequiresValidationMessageAttribute.self, f: { ContentRequiresValidationMessageAttribute(decoder: $0) })
    declareEncodable(WasScheduledMessageAttribute.self, f: { WasScheduledMessageAttribute(decoder: $0) })
    declareEncodable(OutgoingScheduleInfoMessageAttribute.self, f: { OutgoingScheduleInfoMessageAttribute(decoder: $0) })
    declareEncodable(UpdateMessageReactionsAction.self, f: { UpdateMessageReactionsAction(decoder: $0) })
    declareEncodable(RestrictedContentMessageAttribute.self, f: { RestrictedContentMessageAttribute(decoder: $0) })
    declareEncodable(SendScheduledMessageImmediatelyAction.self, f: { SendScheduledMessageImmediatelyAction(decoder: $0) })
    declareEncodable(WalletCollection.self, f: { WalletCollection(decoder: $0) })
    declareEncodable(EmbeddedMediaStickersMessageAttribute.self, f: { EmbeddedMediaStickersMessageAttribute(decoder: $0) })
    declareEncodable(TelegramMediaWebpageAttribute.self, f: { TelegramMediaWebpageAttribute(decoder: $0) })
    declareEncodable(CachedPollOptionResult.self, f: { CachedPollOptionResult(decoder: $0) })
    declareEncodable(ChatListFiltersState.self, f: { ChatListFiltersState(decoder: $0) })
    declareEncodable(PeersNearbyState.self, f: { PeersNearbyState(decoder: $0) })
    declareEncodable(TelegramMediaDice.self, f: { TelegramMediaDice(decoder: $0) })
    declareEncodable(ChatListFiltersFeaturedState.self, f: { ChatListFiltersFeaturedState(decoder: $0) })
    declareEncodable(SynchronizeChatListFiltersOperation.self, f: { SynchronizeChatListFiltersOperation(decoder: $0) })
    declareEncodable(PromoChatListItem.self, f: { PromoChatListItem(decoder: $0) })
    
    return
}()

public func initializeAccountManagement() {
    let _ = declaredEncodables
}

public func rootPathForBasePath(_ appGroupPath: String) -> String {
    return appGroupPath + "/telegram-data"
}

public func performAppGroupUpgrades(appGroupPath: String, rootPath: String) {
    let _ = try? FileManager.default.createDirectory(at: URL(fileURLWithPath: rootPath), withIntermediateDirectories: true, attributes: nil)
    
    do {
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        var mutableUrl = URL(fileURLWithPath: rootPath)
        try mutableUrl.setResourceValues(resourceValues)
    } catch let e {
        print("\(e)")
    }
}

public final class TemporaryAccount {
    public let id: AccountRecordId
    public let basePath: String
    public let postbox: Postbox
    
    init(id: AccountRecordId, basePath: String, postbox: Postbox) {
        self.id = id
        self.basePath = basePath
        self.postbox = postbox
    }
}

public func temporaryAccount(manager: AccountManager, rootPath: String, encryptionParameters: ValueBoxEncryptionParameters) -> Signal<TemporaryAccount, NoError> {
    return manager.allocatedTemporaryAccountId()
    |> mapToSignal { id -> Signal<TemporaryAccount, NoError> in
        let path = "\(rootPath)/\(accountRecordIdPathName(id))"
        return openPostbox(basePath: path + "/postbox", seedConfiguration: telegramPostboxSeedConfiguration, encryptionParameters: encryptionParameters)
        |> mapToSignal { result -> Signal<TemporaryAccount, NoError> in
            switch result {
                case .upgrading:
                    return .complete()
                case let .postbox(postbox):
                    return .single(TemporaryAccount(id: id, basePath: path, postbox: postbox))
            }
        }
    }
}

public func currentAccount(allocateIfNotExists: Bool, networkArguments: NetworkInitializationArguments, supplementary: Bool, manager: AccountManager, rootPath: String, auxiliaryMethods: AccountAuxiliaryMethods, encryptionParameters: ValueBoxEncryptionParameters) -> Signal<AccountResult?, NoError> {
    return manager.currentAccountRecord(allocateIfNotExists: allocateIfNotExists)
    |> distinctUntilChanged(isEqual: { lhs, rhs in
        return lhs?.0 == rhs?.0
    })
    |> mapToSignal { record -> Signal<AccountResult?, NoError> in
        if let record = record {
            let reload = ValuePromise<Bool>(true, ignoreRepeated: false)
            return reload.get()
            |> mapToSignal { _ -> Signal<AccountResult?, NoError> in
                let beginWithTestingEnvironment = record.1.contains(where: { attribute in
                    if let attribute = attribute as? AccountEnvironmentAttribute, case .test = attribute.environment {
                        return true
                    } else {
                        return false
                    }
                })
                return accountWithId(accountManager: manager, networkArguments: networkArguments, id: record.0, encryptionParameters: encryptionParameters, supplementary: supplementary, rootPath: rootPath, beginWithTestingEnvironment: beginWithTestingEnvironment, backupData: nil, auxiliaryMethods: auxiliaryMethods)
                |> mapToSignal { accountResult -> Signal<AccountResult?, NoError> in
                    let postbox: Postbox
                    let initialKind: AccountKind
                    switch accountResult {
                        case .upgrading:
                            return .complete()
                        case let .unauthorized(account):
                            postbox = account.postbox
                            initialKind = .unauthorized
                        case let .authorized(account):
                            postbox = account.postbox
                            initialKind = .authorized
                    }
                    let updatedKind = postbox.stateView()
                    |> map { view -> Bool in
                        let kind: AccountKind
                        if view.state is AuthorizedAccountState {
                            kind = .authorized
                        } else {
                            kind = .unauthorized
                        }
                        if kind != initialKind {
                            return true
                        } else {
                            return false
                        }
                    }
                    |> distinctUntilChanged
                    
                    return Signal { subscriber in
                        subscriber.putNext(accountResult)
                        
                        return updatedKind.start(next: { value in
                            if value {
                                reload.set(true)
                            }
                        })
                    }
                }
            }
        } else {
            return .single(nil)
        }
    }
}

public func logoutFromAccount(id: AccountRecordId, accountManager: AccountManager, alreadyLoggedOutRemotely: Bool) -> Signal<Void, NoError> {
    Logger.shared.log("AccountManager", "logoutFromAccount \(id)")
    return accountManager.transaction { transaction -> Void in
        transaction.updateRecord(id, { current in
            if alreadyLoggedOutRemotely {
                return nil
            } else if let current = current {
                var found = false
                for attribute in current.attributes {
                    if attribute is LoggedOutAccountAttribute {
                        found = true
                        break
                    }
                }
                if found {
                    return current
                } else {
                    return AccountRecord(id: current.id, attributes: current.attributes + [LoggedOutAccountAttribute()], temporarySessionId: nil)
                }
            } else {
                return nil
            }
        })
    }
}

public func managedCleanupAccounts(networkArguments: NetworkInitializationArguments, accountManager: AccountManager, rootPath: String, auxiliaryMethods: AccountAuxiliaryMethods, encryptionParameters: ValueBoxEncryptionParameters) -> Signal<Void, NoError> {
    let currentTemporarySessionId = accountManager.temporarySessionId
    return Signal { subscriber in
        let loggedOutAccounts = Atomic<[AccountRecordId: MetaDisposable]>(value: [:])
        let _ = (accountManager.transaction { transaction -> Void in
            for record in transaction.getRecords() {
                if let temporarySessionId = record.temporarySessionId, temporarySessionId != currentTemporarySessionId {
                    transaction.updateRecord(record.id, { _ in
                        return nil
                    })
                }
            }
        }).start()
        let disposable = accountManager.accountRecords().start(next: { view in
            var disposeList: [(AccountRecordId, MetaDisposable)] = []
            var beginList: [(AccountRecordId, [AccountRecordAttribute], MetaDisposable)] = []
            let _ = loggedOutAccounts.modify { disposables in
                var validIds: [AccountRecordId: [AccountRecordAttribute]] = [:]
                outer: for record in view.records {
                    for attribute in record.attributes {
                        if attribute is LoggedOutAccountAttribute {
                            validIds[record.id] = record.attributes
                            continue outer
                        }
                    }
                }
                
                var disposables = disposables
                
                for id in disposables.keys {
                    if validIds[id] == nil {
                        disposeList.append((id, disposables[id]!))
                    }
                }
                
                for (id, _) in disposeList {
                    disposables.removeValue(forKey: id)
                }
                
                for (id, attributes) in validIds {
                    if disposables[id] == nil {
                        let disposable = MetaDisposable()
                        beginList.append((id, attributes, disposable))
                        disposables[id] = disposable
                    }
                }
                
                return disposables
            }
            for (_, disposable) in disposeList {
                disposable.dispose()
            }
            for (id, attributes, disposable) in beginList {
                Logger.shared.log("managedCleanupAccounts", "cleanup \(id), current is \(String(describing: view.currentRecord?.id))")
                disposable.set(cleanupAccount(networkArguments: networkArguments, accountManager: accountManager, id: id, encryptionParameters: encryptionParameters, attributes: attributes, rootPath: rootPath, auxiliaryMethods: auxiliaryMethods).start())
            }
            
            var validPaths = Set<String>()
            for record in view.records {
                if let temporarySessionId = record.temporarySessionId, temporarySessionId != currentTemporarySessionId {
                    continue
                }
                validPaths.insert("\(accountRecordIdPathName(record.id))")
            }
            if let record = view.currentAuthAccount {
                validPaths.insert("\(accountRecordIdPathName(record.id))")
            }
            
            if let files = try? FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: rootPath), includingPropertiesForKeys: [], options: []) {
                for url in files {
                    if url.lastPathComponent.hasPrefix("account-") {
                        if !validPaths.contains(url.lastPathComponent) {
                            try? FileManager.default.removeItem(at: url)
                        }
                    }
                }
            }
        })
        
        return ActionDisposable {
            disposable.dispose()
        }
    }
}

private func cleanupAccount(networkArguments: NetworkInitializationArguments, accountManager: AccountManager, id: AccountRecordId, encryptionParameters: ValueBoxEncryptionParameters, attributes: [AccountRecordAttribute], rootPath: String, auxiliaryMethods: AccountAuxiliaryMethods) -> Signal<Void, NoError> {
    let beginWithTestingEnvironment = attributes.contains(where: { attribute in
        if let attribute = attribute as? AccountEnvironmentAttribute, case .test = attribute.environment {
            return true
        } else {
            return false
        }
    })
    return accountWithId(accountManager: accountManager, networkArguments: networkArguments, id: id, encryptionParameters: encryptionParameters, supplementary: true, rootPath: rootPath, beginWithTestingEnvironment: beginWithTestingEnvironment, backupData: nil, auxiliaryMethods: auxiliaryMethods)
    |> mapToSignal { account -> Signal<Void, NoError> in
        switch account {
            case .upgrading:
                return .complete()
            case .unauthorized:
                return .complete()
            case let .authorized(account):
                account.shouldBeServiceTaskMaster.set(.single(.always))
                return account.network.request(Api.functions.auth.logOut())
                |> map(Optional.init)
                |> `catch` { _ -> Signal<Api.Bool?, NoError> in
                    return .single(.boolFalse)
                }
                |> mapToSignal { _ -> Signal<Void, NoError> in
                    account.shouldBeServiceTaskMaster.set(.single(.never))
                    return accountManager.transaction { transaction -> Void in
                        transaction.updateRecord(id, { _ in
                            return nil
                        })
                    }
                }
        }
    }
}
