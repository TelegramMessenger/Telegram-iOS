import Foundation
import Postbox
import SwiftSignalKit
import MtProtoKit
import TelegramApi

final class AccountTaskManager {
    private final class Impl {
        private let queue: Queue
        private let stateManager: AccountStateManager
        private let accountManager: AccountManager<TelegramAccountManagerTypes>
        private let networkArguments: NetworkInitializationArguments
        private let viewTracker: AccountViewTracker
        private let mediaReferenceRevalidationContext: MediaReferenceRevalidationContext
        private let isMainApp: Bool
        private let testingEnvironment: Bool
        
        private var stateDisposable: Disposable?
        private let tasksDisposable = MetaDisposable()
        
        private let managedTopReactionsDisposable = MetaDisposable()
        
        private var isUpdating: Bool = false
        
        init(queue: Queue, stateManager: AccountStateManager, accountManager: AccountManager<TelegramAccountManagerTypes>,
             networkArguments: NetworkInitializationArguments, viewTracker: AccountViewTracker, mediaReferenceRevalidationContext: MediaReferenceRevalidationContext, isMainApp: Bool, testingEnvironment: Bool) {
            self.queue = queue
            self.stateManager = stateManager
            self.accountManager = accountManager
            self.networkArguments = networkArguments
            self.viewTracker = viewTracker
            self.mediaReferenceRevalidationContext = mediaReferenceRevalidationContext
            self.isMainApp = isMainApp
            self.testingEnvironment = testingEnvironment
            
            stateManager.isPremiumUpdated = { [weak self] in
                guard let self = self else {
                    return
                }
                if !self.isUpdating {
                    self.managedTopReactionsDisposable.set(managedTopReactions(postbox: self.stateManager.postbox, network: self.stateManager.network).start())
                }
            }
            
            self.stateDisposable = (stateManager.isUpdating
            |> filter { !$0 }
            |> take(1)
            |> deliverOn(self.queue)).start(next: { [weak self] value in
                guard let self = self else {
                    return
                }
                self.stateManagerUpdated(isUpdating: value)
            })
        }
        
        private func stateManagerUpdated(isUpdating: Bool) {
            self.isUpdating = isUpdating
            
            if isUpdating {
                self.tasksDisposable.set(nil)
                self.managedTopReactionsDisposable.set(nil)
            } else {
                let tasks = DisposableSet()
                
                if self.isMainApp {
                    tasks.add(managedSynchronizePeerReadStates(network: self.stateManager.network, postbox: self.stateManager.postbox, stateManager: self.stateManager).start())
                    tasks.add(managedSynchronizeGroupMessageStats(network: self.stateManager.network, postbox: self.stateManager.postbox, stateManager: self.stateManager).start())
                    
                    tasks.add(managedGlobalNotificationSettings(postbox: self.stateManager.postbox, network: self.stateManager.network).start())
                    tasks.add(managedSynchronizePinnedChatsOperations(postbox: self.stateManager.postbox, network: self.stateManager.network, accountPeerId: self.stateManager.accountPeerId, stateManager: self.stateManager).start())
                    tasks.add(managedSynchronizeGroupedPeersOperations(postbox: self.stateManager.postbox, network: self.stateManager.network, stateManager: self.stateManager).start())
                    tasks.add(managedSynchronizeInstalledStickerPacksOperations(postbox: self.stateManager.postbox, network: self.stateManager.network, stateManager: self.stateManager, namespace: .stickers).start())
                    tasks.add(managedSynchronizeInstalledStickerPacksOperations(postbox: self.stateManager.postbox, network: self.stateManager.network, stateManager: self.stateManager, namespace: .masks).start())
                    tasks.add(managedSynchronizeInstalledStickerPacksOperations(postbox: self.stateManager.postbox, network: self.stateManager.network, stateManager: self.stateManager, namespace: .emoji).start())
                    tasks.add(managedSynchronizeMarkFeaturedStickerPacksAsSeenOperations(postbox: self.stateManager.postbox, network: self.stateManager.network).start())
                    tasks.add(managedSynchronizeRecentlyUsedMediaOperations(postbox: self.stateManager.postbox, network: self.stateManager.network, category: .stickers, revalidationContext: self.mediaReferenceRevalidationContext).start())
                    tasks.add(managedSynchronizeSavedGifsOperations(postbox: self.stateManager.postbox, network: self.stateManager.network, revalidationContext: self.mediaReferenceRevalidationContext).start())
                    tasks.add(managedSynchronizeSavedStickersOperations(postbox: self.stateManager.postbox, network: self.stateManager.network, revalidationContext: self.mediaReferenceRevalidationContext).start())
                    tasks.add(_internal_managedRecentlyUsedInlineBots(postbox: self.stateManager.postbox, network: self.stateManager.network, accountPeerId: self.stateManager.accountPeerId).start())
                    tasks.add(managedSynchronizeConsumeMessageContentOperations(postbox: self.stateManager.postbox, network: self.stateManager.network, stateManager: self.stateManager).start())
                    tasks.add(managedConsumePersonalMessagesActions(postbox: self.stateManager.postbox, network: self.stateManager.network, stateManager: self.stateManager).start())
                    tasks.add(managedReadReactionActions(postbox: self.stateManager.postbox, network: self.stateManager.network, stateManager: self.stateManager).start())
                    tasks.add(managedSynchronizeMarkAllUnseenPersonalMessagesOperations(postbox: self.stateManager.postbox, network: self.stateManager.network, stateManager: self.stateManager).start())
                    tasks.add(managedSynchronizeMarkAllUnseenReactionsOperations(postbox: self.stateManager.postbox, network: self.stateManager.network, stateManager: self.stateManager).start())
                    tasks.add(managedApplyPendingMessageReactionsActions(postbox: self.stateManager.postbox, network: self.stateManager.network, stateManager: self.stateManager).start())
                    tasks.add(managedSynchronizeEmojiKeywordsOperations(postbox: self.stateManager.postbox, network: self.stateManager.network).start())
                    tasks.add(managedApplyPendingScheduledMessagesActions(postbox: self.stateManager.postbox, network: self.stateManager.network, stateManager: self.stateManager).start())
                    tasks.add(managedSynchronizeAvailableReactions(postbox: self.stateManager.postbox, network: self.stateManager.network).start())
                    tasks.add(managedSynchronizeEmojiSearchCategories(postbox: self.stateManager.postbox, network: self.stateManager.network, kind: .emoji).start())
                    tasks.add(managedSynchronizeEmojiSearchCategories(postbox: self.stateManager.postbox, network: self.stateManager.network, kind: .status).start())
                    tasks.add(managedSynchronizeEmojiSearchCategories(postbox: self.stateManager.postbox, network: self.stateManager.network, kind: .avatar).start())
                    tasks.add(managedSynchronizeAttachMenuBots(postbox: self.stateManager.postbox, network: self.stateManager.network, force: true).start())
                    tasks.add(managedSynchronizeNotificationSoundList(postbox: self.stateManager.postbox, network: self.stateManager.network).start())
                    tasks.add(managedChatListFilters(postbox: self.stateManager.postbox, network: self.stateManager.network, accountPeerId: self.stateManager.accountPeerId).start())
                    tasks.add(managedAnimatedEmojiUpdates(postbox: self.stateManager.postbox, network: self.stateManager.network).start())
                    tasks.add(managedAnimatedEmojiAnimationsUpdates(postbox: self.stateManager.postbox, network: self.stateManager.network).start())
                    tasks.add(managedGenericEmojiEffects(postbox: self.stateManager.postbox, network: self.stateManager.network).start())
                    tasks.add(managedGreetingStickers(postbox: self.stateManager.postbox, network: self.stateManager.network).start())
                    tasks.add(managedPremiumStickers(postbox: self.stateManager.postbox, network: self.stateManager.network).start())
                    tasks.add(managedAllPremiumStickers(postbox: self.stateManager.postbox, network: self.stateManager.network).start())
                    tasks.add(managedRecentStatusEmoji(postbox: self.stateManager.postbox, network: self.stateManager.network).start())
                    tasks.add(managedFeaturedStatusEmoji(postbox: self.stateManager.postbox, network: self.stateManager.network).start())
                    tasks.add(managedProfilePhotoEmoji(postbox: self.stateManager.postbox, network: self.stateManager.network).start())
                    tasks.add(managedGroupPhotoEmoji(postbox: self.stateManager.postbox, network: self.stateManager.network).start())
                    tasks.add(managedRecentReactions(postbox: self.stateManager.postbox, network: self.stateManager.network).start())
                    tasks.add(_internal_loadedStickerPack(postbox: self.stateManager.postbox, network: self.stateManager.network, reference: .iconStatusEmoji, forceActualized: true).start())
                    tasks.add(_internal_loadedStickerPack(postbox: self.stateManager.postbox, network: self.stateManager.network, reference: .iconTopicEmoji, forceActualized: true).start())
                    
                    self.managedTopReactionsDisposable.set(managedTopReactions(postbox: self.stateManager.postbox, network: self.stateManager.network).start())
                    
                    //tasks.add(managedVoipConfigurationUpdates(postbox: self.stateManager.postbox, network: self.stateManager.network).start())
                    tasks.add(managedAppConfigurationUpdates(postbox: self.stateManager.postbox, network: self.stateManager.network).start())
                    tasks.add(managedPremiumPromoConfigurationUpdates(postbox: self.stateManager.postbox, network: self.stateManager.network).start())
                    tasks.add(managedAutodownloadSettingsUpdates(accountManager: self.accountManager, network: self.stateManager.network).start())
                    tasks.add(managedTermsOfServiceUpdates(postbox: self.stateManager.postbox, network: self.stateManager.network, stateManager: self.stateManager).start())
                    tasks.add(managedAppUpdateInfo(network: self.stateManager.network, stateManager: self.stateManager).start())
                    tasks.add(managedAppChangelog(postbox: self.stateManager.postbox, network: self.stateManager.network, stateManager: self.stateManager, appVersion: self.networkArguments.appVersion).start())
                    tasks.add(managedPromoInfoUpdates(postbox: self.stateManager.postbox, network: self.stateManager.network, viewTracker: self.viewTracker).start())
                    tasks.add(managedLocalizationUpdatesOperations(accountManager: self.accountManager, postbox: self.stateManager.postbox, network: self.stateManager.network).start())
                    tasks.add(managedPendingPeerNotificationSettings(postbox: self.stateManager.postbox, network: self.stateManager.network).start())
                    tasks.add(managedSynchronizeAppLogEventsOperations(postbox: self.stateManager.postbox, network: self.stateManager.network).start())
                    tasks.add(managedNotificationSettingsBehaviors(postbox: self.stateManager.postbox).start())
                    tasks.add(managedThemesUpdates(accountManager: self.accountManager, postbox: self.stateManager.postbox, network: self.stateManager.network).start())
                    
                    if !self.testingEnvironment {
                        tasks.add(managedChatThemesUpdates(accountManager: self.accountManager, network: self.stateManager.network).start())
                    }
                }
                
                self.tasksDisposable.set(tasks)
            }
        }
        
        deinit {
            self.stateDisposable?.dispose()
            self.tasksDisposable.dispose()
            self.managedTopReactionsDisposable.dispose()
        }
    }
    
    private let queue: Queue
    private let impl: QueueLocalObject<Impl>
    
    init(stateManager: AccountStateManager, accountManager: AccountManager<TelegramAccountManagerTypes>,
         networkArguments: NetworkInitializationArguments, viewTracker: AccountViewTracker, mediaReferenceRevalidationContext: MediaReferenceRevalidationContext, isMainApp: Bool, testingEnvironment: Bool) {
        let queue = Account.sharedQueue
        self.queue = queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return Impl(queue: queue, stateManager: stateManager, accountManager: accountManager, networkArguments: networkArguments, viewTracker: viewTracker, mediaReferenceRevalidationContext: mediaReferenceRevalidationContext, isMainApp: isMainApp, testingEnvironment: testingEnvironment)
        })
    }
}
