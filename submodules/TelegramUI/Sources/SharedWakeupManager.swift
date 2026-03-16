import Foundation
import BackgroundTasks
import AVFAudio
import UIKit
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramCallsUI
import AccountContext
import UniversalMediaPlayer
import TelegramAudio
import TelegramPresentationData

private struct AccountTasks {
    let stateSynchronization: Bool
    let importantTasks: AccountRunningImportantTasks
    let backgroundLocation: Bool
    let backgroundDownloads: Bool
    let backgroundAudio: Bool
    let activeCalls: Bool
    let watchTasks: Bool
    let userInterfaceInUse: Bool
    
    var isEmpty: Bool {
        if self.stateSynchronization {
            return false
        }
        if !self.importantTasks.isEmpty {
            return false
        }
        if self.backgroundLocation {
            return false
        }
        if self.backgroundDownloads {
            return false
        }
        if self.backgroundAudio {
            return false
        }
        if self.activeCalls {
            return false
        }
        if self.watchTasks {
            return false
        }
        if self.userInterfaceInUse {
            return false
        }
        return true
    }
}

private let backgroundTaskSubmissionDelay: Double = 10.0

private struct PendingMediaUploadKey: Hashable {
    let accountId: AccountRecordId
    let messageId: MessageId
}

private struct PendingStoryUploadKey: Hashable {
    let accountId: AccountRecordId
    let stableId: Int32
}

public final class SharedWakeupManager {
    private let beginBackgroundTask: (String, @escaping () -> Void) -> UIBackgroundTaskIdentifier?
    private let endBackgroundTask: (UIBackgroundTaskIdentifier) -> Void
    private let backgroundTimeRemaining: () -> Double
    private let acquireIdleExtension: () -> Disposable?
    
    private var enableBackgroundTasks: Bool = false
    private let presentationData: () -> PresentationData?
    
    private var inForeground: Bool = false
    private var hasActiveAudioSession: Bool = false
    private var activeExplicitExtensionTimer: SwiftSignalKit.Timer?
    private var activeExplicitExtensionTask: UIBackgroundTaskIdentifier?
    private var allowBackgroundTimeExtensionDeadline: Double?
    private var allowBackgroundTimeExtensionDeadlineTimer: SwiftSignalKit.Timer?
    private var isInBackgroundExtension: Bool = false
    
    private var accountSettingsDisposable: Disposable?
    private var inForegroundDisposable: Disposable?
    private var hasActiveAudioSessionDisposable: Disposable?
    private var tasksDisposable: Disposable?
    private var pendingMediaUploadsDisposable: Disposable?
    private var pendingStoryUploadsDisposable: Disposable?
    private var currentTask: (UIBackgroundTaskIdentifier, Double, SwiftSignalKit.Timer)?
    private var currentExternalCompletion: (() -> Void, SwiftSignalKit.Timer)?
    private var currentExternalCompletionValidationTimer: SwiftSignalKit.Timer?
    
    private var managedPausedInBackgroundPlayer: Disposable?
    private var keepIdleDisposable: Disposable?
    private var silenceAudioRenderer: MediaPlayerAudioRenderer?
    
    private var accountsAndTasks: [(Account, Bool, AccountTasks)] = []
    
    private var pendingMediaUploadsByKey: [PendingMediaUploadKey: Float] = [:]
    private var backgroundProcessingTaskProgressByKey: [PendingMediaUploadKey: Float] = [:]
    private var nextBackgroundProcessingTaskId: Int = 0
    private var backgroundProcessingTaskId: String?
    private var backgroundProcessingTaskLaunched: Bool = false
    private var backgroundProcessingTaskCancellationRequestedByApp: Bool = false
    private var pendingBackgroundProcessingTaskTimer: SwiftSignalKit.Timer?

    private var pendingStoryUploadsByKey: [PendingStoryUploadKey: Float] = [:]
    private var pendingStoryUploadStatusesByKey: [PendingStoryUploadKey: PendingStoryUploadStatus] = [:]
    private var backgroundStoryProcessingTaskProgressByKey: [PendingStoryUploadKey: Float] = [:]
    private var nextBackgroundStoryProcessingTaskId: Int = 0
    private var backgroundStoryProcessingTaskId: String?
    private var backgroundStoryProcessingTaskLaunched: Bool = false
    private var backgroundStoryProcessingTaskCancellationRequestedByApp: Bool = false
    private var pendingBackgroundStoryProcessingTaskTimer: SwiftSignalKit.Timer?

    public init(beginBackgroundTask: @escaping (String, @escaping () -> Void) -> UIBackgroundTaskIdentifier?, endBackgroundTask: @escaping (UIBackgroundTaskIdentifier) -> Void, backgroundTimeRemaining: @escaping () -> Double, acquireIdleExtension: @escaping () -> Disposable?, activeAccounts: Signal<(primary: Account?, accounts: [(AccountRecordId, Account)]), NoError>, liveLocationPolling: Signal<AccountRecordId?, NoError>, watchTasks: Signal<AccountRecordId?, NoError>, inForeground: Signal<Bool, NoError>, hasActiveAudioSession: Signal<Bool, NoError>, notificationManager: SharedNotificationManager?, mediaManager: MediaManager, callManager: PresentationCallManager?, accountUserInterfaceInUse: @escaping (AccountRecordId) -> Signal<Bool, NoError>, presentationData: @escaping () -> PresentationData?) {
        assert(Queue.mainQueue().isCurrent())
        
        self.beginBackgroundTask = beginBackgroundTask
        self.endBackgroundTask = endBackgroundTask
        self.backgroundTimeRemaining = backgroundTimeRemaining
        self.acquireIdleExtension = acquireIdleExtension
        self.presentationData = presentationData
        
        self.accountSettingsDisposable = (activeAccounts
        |> mapToSignal { activeAccounts -> Signal<Bool, NoError> in
            guard let account = activeAccounts.primary else {
                return .single(false)
            }
            return account.postbox.transaction { transaction -> Bool in
                guard let data = currentAppConfiguration(transaction: transaction).data else {
                    return false
                }
                if data["ios_killswitch_disable_bgtasks"] != nil {
                    return false
                }
                return true
            }
        }
        |> deliverOnMainQueue
        |> distinctUntilChanged).startStrict(next: { [weak self] isEnabled in
            guard let self else {
                return
            }
            self.enableBackgroundTasks = isEnabled
        })
        
        self.inForegroundDisposable = (inForeground
        |> deliverOnMainQueue).startStrict(next: { [weak self] value in
            guard let strongSelf = self else {
                return
            }
            strongSelf.inForeground = value
            if value {
                strongSelf.activeExplicitExtensionTimer?.invalidate()
                strongSelf.activeExplicitExtensionTimer = nil
                if let activeExplicitExtensionTask = strongSelf.activeExplicitExtensionTask {
                    strongSelf.activeExplicitExtensionTask = nil
                    strongSelf.endBackgroundTask(activeExplicitExtensionTask)
                }
                strongSelf.allowBackgroundTimeExtensionDeadlineTimer?.invalidate()
                strongSelf.allowBackgroundTimeExtensionDeadlineTimer = nil
                strongSelf.pendingBackgroundProcessingTaskTimer?.invalidate()
                strongSelf.pendingBackgroundProcessingTaskTimer = nil
                strongSelf.pendingBackgroundStoryProcessingTaskTimer?.invalidate()
                strongSelf.pendingBackgroundStoryProcessingTaskTimer = nil
            }
            strongSelf.updateBackgroundProcessingTaskStateFromPendingMediaUploads()
            strongSelf.updateBackgroundProcessingTaskStateFromPendingStoryUploads()
            strongSelf.checkTasks()
        })
        
        self.hasActiveAudioSessionDisposable = (hasActiveAudioSession
        |> deliverOnMainQueue).startStrict(next: { [weak self] value in
            guard let strongSelf = self else {
                return
            }
            strongSelf.hasActiveAudioSession = value
            strongSelf.checkTasks()
        })
        
        self.managedPausedInBackgroundPlayer = combineLatest(queue: .mainQueue(), mediaManager.activeGlobalMediaPlayerAccountId, inForeground).startStrict(next: { [weak mediaManager] accountAndActive, inForeground in
            guard let mediaManager = mediaManager else {
                return
            }
            if !inForeground, let accountAndActive = accountAndActive, !accountAndActive.1 {
                mediaManager.audioSession.dropAll()
            }
        })
        
        self.tasksDisposable = (activeAccounts
        |> deliverOnMainQueue
        |> mapToSignal { primary, accounts -> Signal<[(Account, Bool, AccountTasks)], NoError> in
            let signals: [Signal<(Account, Bool, AccountTasks), NoError>] = accounts.map { _, account in
                let hasActiveMedia = mediaManager.activeGlobalMediaPlayerAccountId
                |> map { idAndStatus -> Bool in
                    if let (id, isPlaying) = idAndStatus {
                        return id == account.id && isPlaying
                    } else {
                        return false
                    }
                }
                |> distinctUntilChanged
                let isPlayingBackgroundAudio = combineLatest(queue: .mainQueue(), hasActiveMedia, hasActiveAudioSession)
                |> map { hasActiveMedia, hasActiveAudioSession -> Bool in
                    return hasActiveMedia && hasActiveAudioSession
                }
                |> distinctUntilChanged
                
                let hasActiveCalls = (callManager?.currentCallSignal ?? .single(nil))
                |> map { call in
                    return call?.context.account.id == account.id
                }
                |> distinctUntilChanged
                
                let hasActiveGroupCalls = (callManager?.currentGroupCallSignal ?? .single(nil))
                |> map { call -> Bool in
                    guard let call else {
                        return false
                    }
                    switch call {
                    case let .conferenceSource(conferenceSource):
                        return conferenceSource.context.account.id == account.id
                    case let .group(groupCall):
                        return groupCall.accountContext.account.id == account.id
                    }
                }
                |> distinctUntilChanged
                
                let keepUpdatesForCalls = combineLatest(queue: .mainQueue(), hasActiveCalls, hasActiveGroupCalls)
                |> map { hasActiveCalls, hasActiveGroupCalls -> Bool in
                    return hasActiveCalls || hasActiveGroupCalls
                }
                |> distinctUntilChanged
                
                let isPlayingBackgroundActiveCall = combineLatest(queue: .mainQueue(), hasActiveCalls, hasActiveGroupCalls, hasActiveAudioSession)
                |> map { hasActiveCalls, hasActiveGroupCalls, hasActiveAudioSession -> Bool in
                    return (hasActiveCalls || hasActiveGroupCalls) && hasActiveAudioSession
                }
                |> distinctUntilChanged
                
                let hasActiveAudio = combineLatest(queue: .mainQueue(), isPlayingBackgroundAudio, isPlayingBackgroundActiveCall)
                |> map { isPlayingBackgroundAudio, isPlayingBackgroundActiveCall in
                    return isPlayingBackgroundAudio || isPlayingBackgroundActiveCall
                }
                |> distinctUntilChanged
                
                let hasActiveLiveLocationPolling = liveLocationPolling
                |> map { id in
                    return id == account.id
                }
                |> distinctUntilChanged
                
                let hasWatchTasks = watchTasks
                |> map { id in
                    return id == account.id
                }
                |> distinctUntilChanged
                
                let userInterfaceInUse = accountUserInterfaceInUse(account.id)
                
                return combineLatest(queue: .mainQueue(), account.importantTasksRunning, notificationManager?.isPollingState(accountId: account.id) ?? .single(false), hasActiveAudio, keepUpdatesForCalls, hasActiveLiveLocationPolling, hasWatchTasks, userInterfaceInUse)
                |> map { importantTasksRunning, isPollingState, hasActiveAudio, keepUpdatesForCalls, hasActiveLiveLocationPolling, hasWatchTasks, userInterfaceInUse -> (Account, Bool, AccountTasks) in
                    return (account, primary?.id == account.id, AccountTasks(stateSynchronization: isPollingState, importantTasks: importantTasksRunning, backgroundLocation: hasActiveLiveLocationPolling, backgroundDownloads: false, backgroundAudio: hasActiveAudio, activeCalls: keepUpdatesForCalls, watchTasks: hasWatchTasks, userInterfaceInUse: userInterfaceInUse))
                }
            }
            return combineLatest(signals)
        }
        |> deliverOnMainQueue).startStrict(next: { [weak self] accountsAndTasks in
            guard let strongSelf = self else {
                return
            }
            strongSelf.accountsAndTasks = accountsAndTasks
            strongSelf.checkTasks()
        })
        
        self.pendingMediaUploadsDisposable = (activeAccounts
        |> deliverOnMainQueue
        |> mapToSignal { _, accounts -> Signal<[PendingMediaUploadKey: Float], NoError> in
            if accounts.isEmpty {
                return .single([:])
            }
            let signals: [Signal<[PendingMediaUploadKey: Float], NoError>] = accounts.map { accountId, account in
                return account.pendingMessageManager.pendingMediaUploads
                |> map { pendingMediaUploads in
                    var result: [PendingMediaUploadKey: Float] = [:]
                    result.reserveCapacity(pendingMediaUploads.count)
                    for (messageId, progress) in pendingMediaUploads {
                        result[PendingMediaUploadKey(accountId: accountId, messageId: messageId)] = progress
                    }
                    return result
                }
            }
            return combineLatest(signals)
            |> map { values in
                var result: [PendingMediaUploadKey: Float] = [:]
                for value in values {
                    for (key, progress) in value {
                        result[key] = progress
                    }
                }
                return result
            }
        }
        |> distinctUntilChanged
        |> deliverOnMainQueue).startStrict(next: { [weak self] pendingMediaUploadsByKey in
            guard let strongSelf = self else {
                return
            }
            strongSelf.pendingMediaUploadsByKey = pendingMediaUploadsByKey
            strongSelf.updateBackgroundProcessingTaskStateFromPendingMediaUploads()
        })
        
        self.pendingStoryUploadsDisposable = (activeAccounts
        |> deliverOnMainQueue
        |> mapToSignal { _, accounts -> Signal<[PendingStoryUploadKey: PendingStoryUploadStatus], NoError> in
            if accounts.isEmpty {
                return .single([:])
            }
            let signals: [Signal<[PendingStoryUploadKey: PendingStoryUploadStatus], NoError>] = accounts.map { accountId, account in
                return TelegramEngine(account: account).messages.pendingStoryUploadStatuses()
                |> map { pendingStoryUploadStatuses in
                    var result: [PendingStoryUploadKey: PendingStoryUploadStatus] = [:]
                    result.reserveCapacity(pendingStoryUploadStatuses.count)
                    for (stableId, status) in pendingStoryUploadStatuses {
                        result[PendingStoryUploadKey(accountId: accountId, stableId: stableId)] = status
                    }
                    return result
                }
            }
            return combineLatest(signals)
            |> map { values in
                var result: [PendingStoryUploadKey: PendingStoryUploadStatus] = [:]
                for value in values {
                    for (key, status) in value {
                        result[key] = status
                    }
                }
                return result
            }
        }
        |> distinctUntilChanged
        |> deliverOnMainQueue).startStrict(next: { [weak self] pendingStoryUploadStatusesByKey in
            guard let strongSelf = self else {
                return
            }
            strongSelf.pendingStoryUploadStatusesByKey = pendingStoryUploadStatusesByKey
            
            var pendingStoryUploadsByKey: [PendingStoryUploadKey: Float] = [:]
            pendingStoryUploadsByKey.reserveCapacity(pendingStoryUploadStatusesByKey.count)
            for (key, status) in pendingStoryUploadStatusesByKey {
                pendingStoryUploadsByKey[key] = status.progress
            }
            strongSelf.pendingStoryUploadsByKey = pendingStoryUploadsByKey
            strongSelf.updateBackgroundProcessingTaskStateFromPendingStoryUploads()
        })
    }
    
    deinit {
        self.accountSettingsDisposable?.dispose()
        self.inForegroundDisposable?.dispose()
        self.hasActiveAudioSessionDisposable?.dispose()
        self.tasksDisposable?.dispose()
        self.pendingMediaUploadsDisposable?.dispose()
        self.pendingStoryUploadsDisposable?.dispose()
        self.managedPausedInBackgroundPlayer?.dispose()
        self.keepIdleDisposable?.dispose()
        self.pendingBackgroundProcessingTaskTimer?.invalidate()
        self.pendingBackgroundStoryProcessingTaskTimer?.invalidate()
        if let (taskId, _, timer) = self.currentTask {
            timer.invalidate()
            self.endBackgroundTask(taskId)
        }
    }
    
    private func updateBackgroundProcessingTaskStateFromPendingMediaUploads() {
        if !self.enableBackgroundTasks {
            return
        }
        
        let shouldHaveTask = !self.pendingMediaUploadsByKey.isEmpty && !self.inForeground
        let hadTask = self.backgroundProcessingTaskId != nil

        if shouldHaveTask {
            if !hadTask && self.pendingBackgroundProcessingTaskTimer == nil {
                let timer = SwiftSignalKit.Timer(timeout: backgroundTaskSubmissionDelay, repeat: false, completion: { [weak self] in
                    guard let self else {
                        return
                    }
                    self.pendingBackgroundProcessingTaskTimer = nil
                    self.startBackgroundProcessingTaskIfNeeded()
                }, queue: .mainQueue())
                self.pendingBackgroundProcessingTaskTimer = timer
                timer.start()
            }
        } else {
            self.pendingBackgroundProcessingTaskTimer?.invalidate()
            self.pendingBackgroundProcessingTaskTimer = nil

            if let backgroundProcessingTaskId = self.backgroundProcessingTaskId {
                if !self.backgroundProcessingTaskCancellationRequestedByApp {
                    self.backgroundProcessingTaskCancellationRequestedByApp = true
                    BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: backgroundProcessingTaskId)
                    Logger.shared.log("Wakeup", "Requested BG task cancellation by app: \(backgroundProcessingTaskId)")
                }

                if !self.backgroundProcessingTaskLaunched {
                    self.backgroundProcessingTaskId = nil
                    self.backgroundProcessingTaskProgressByKey = [:]
                    self.backgroundProcessingTaskCancellationRequestedByApp = false
                    self.checkTasks()
                }
            }
        }
    }
    
    private func updateBackgroundProcessingTaskStateFromPendingStoryUploads() {
        if !self.enableBackgroundTasks {
            return
        }
        
        let shouldHaveTask = !self.pendingStoryUploadStatusesByKey.isEmpty && !self.inForeground
        let hadTask = self.backgroundStoryProcessingTaskId != nil

        if shouldHaveTask {
            if !hadTask && self.pendingBackgroundStoryProcessingTaskTimer == nil {
                let timer = SwiftSignalKit.Timer(timeout: backgroundTaskSubmissionDelay, repeat: false, completion: { [weak self] in
                    guard let self else {
                        return
                    }
                    self.pendingBackgroundStoryProcessingTaskTimer = nil
                    self.startBackgroundStoryProcessingTaskIfNeeded()
                }, queue: .mainQueue())
                self.pendingBackgroundStoryProcessingTaskTimer = timer
                timer.start()
            }
        } else {
            self.pendingBackgroundStoryProcessingTaskTimer?.invalidate()
            self.pendingBackgroundStoryProcessingTaskTimer = nil

            if let backgroundStoryProcessingTaskId = self.backgroundStoryProcessingTaskId {
                if !self.backgroundStoryProcessingTaskCancellationRequestedByApp {
                    self.backgroundStoryProcessingTaskCancellationRequestedByApp = true
                    BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: backgroundStoryProcessingTaskId)
                    Logger.shared.log("Wakeup", "Requested story BG task cancellation by app: \(backgroundStoryProcessingTaskId)")
                }

                if !self.backgroundStoryProcessingTaskLaunched {
                    self.backgroundStoryProcessingTaskId = nil
                    self.backgroundStoryProcessingTaskProgressByKey = [:]
                    self.backgroundStoryProcessingTaskCancellationRequestedByApp = false
                    self.checkTasks()
                }
            }
        }
    }
    
    private func cancelUploadingMessagesForCurrentTask() {
        let keys = Array(self.pendingMediaUploadsByKey.keys)
        if keys.isEmpty {
            Logger.shared.log("Wakeup", "BG task external cancel: no pending uploads to delete")
            return
        }
        
        var messageIdsByAccount: [AccountRecordId: [MessageId]] = [:]
        for key in keys {
            if messageIdsByAccount[key.accountId] == nil {
                messageIdsByAccount[key.accountId] = []
            }
            messageIdsByAccount[key.accountId]?.append(key.messageId)
        }
        
        for key in keys {
            self.pendingMediaUploadsByKey.removeValue(forKey: key)
        }
        
        Logger.shared.log("Wakeup", "BG task external cancel: deleting \(keys.count) uploading messages across \(messageIdsByAccount.count) accounts")
        
        for (accountId, messageIds) in messageIdsByAccount {
            guard let account = self.accountsAndTasks.first(where: { $0.0.id == accountId })?.0 else {
                Logger.shared.log("Wakeup", "BG task external cancel: missing account \(accountId.int64), skip \(messageIds.count) messages")
                continue
            }
            Logger.shared.log("Wakeup", "BG task external cancel: deleting \(messageIds.count) messages in account \(accountId.int64)")
            let _ = TelegramEngine(account: account).messages.deleteMessagesInteractively(messageIds: messageIds, type: .forLocalPeer).startStandalone()
        }
    }
    
    private func cancelUploadingStoriesForCurrentTask() {
        let keys = Array(self.pendingStoryUploadsByKey.keys)
        if keys.isEmpty {
            Logger.shared.log("Wakeup", "Story BG task external cancel: no pending uploads to cancel")
            return
        }
        
        var stableIdsByAccount: [AccountRecordId: [Int32]] = [:]
        for key in keys {
            if stableIdsByAccount[key.accountId] == nil {
                stableIdsByAccount[key.accountId] = []
            }
            stableIdsByAccount[key.accountId]?.append(key.stableId)
        }
        
        for key in keys {
            self.pendingStoryUploadsByKey.removeValue(forKey: key)
            self.pendingStoryUploadStatusesByKey.removeValue(forKey: key)
        }
        
        Logger.shared.log("Wakeup", "Story BG task external cancel: cancelling \(keys.count) uploading stories across \(stableIdsByAccount.count) accounts")
        
        for (accountId, stableIds) in stableIdsByAccount {
            guard let account = self.accountsAndTasks.first(where: { $0.0.id == accountId })?.0 else {
                Logger.shared.log("Wakeup", "Story BG task external cancel: missing account \(accountId.int64), skip \(stableIds.count) stories")
                continue
            }
            Logger.shared.log("Wakeup", "Story BG task external cancel: cancelling \(stableIds.count) stories in account \(accountId.int64)")
            let engineMessages = TelegramEngine(account: account).messages
            for stableId in stableIds {
                engineMessages.cancelStoryUpload(stableId: stableId)
            }
        }
    }
    
    private func startBackgroundProcessingTaskIfNeeded() {
        guard #available(iOS 26.0, *) else {
            return
        }
        guard !self.inForeground else {
            return
        }
        guard self.backgroundProcessingTaskId == nil else {
            return
        }
        guard let presentationData = self.presentationData() else {
            return
        }
        
        let baseAppBundleId = Bundle.main.bundleIdentifier!
        let uploadTaskId = "\(baseAppBundleId).upload.message\(self.nextBackgroundProcessingTaskId)"
        self.nextBackgroundProcessingTaskId += 1
        self.backgroundProcessingTaskProgressByKey = [:]
        self.backgroundProcessingTaskLaunched = false
        self.backgroundProcessingTaskCancellationRequestedByApp = false
        
        BGTaskScheduler.shared.register(forTaskWithIdentifier: uploadTaskId, using: nil, launchHandler: { [weak self] task in
            guard let task = task as? BGContinuedProcessingTask else {
                return
            }
            guard let self else {
                task.updateTitle(task.title, subtitle: presentationData.strings.BackgroundTasks_MediaFinished)
                task.setTaskCompleted(success: true)
                return
            }
            
            Task { @MainActor [weak self] in
                guard let self else {
                    return
                }
                if self.backgroundProcessingTaskId == task.identifier {
                    self.backgroundProcessingTaskLaunched = true
                }
            }
            
            var wasExpired = false
            
            task.expirationHandler = { [weak self] in
                wasExpired = true
                
                Queue.mainQueue().async {
                    guard let self else {
                        return
                    }
                    if self.backgroundProcessingTaskId == task.identifier {
                        let cancelledByApp = self.backgroundProcessingTaskCancellationRequestedByApp
                        self.backgroundProcessingTaskCancellationRequestedByApp = false
                        if cancelledByApp {
                            Logger.shared.log("Wakeup", "BG task expired after app cancellation: \(task.identifier)")
                        } else {
                            Logger.shared.log("Wakeup", "BG task expired externally, will delete uploading messages: \(task.identifier)")
                            self.cancelUploadingMessagesForCurrentTask()
                        }
                        self.backgroundProcessingTaskId = nil
                        self.backgroundProcessingTaskProgressByKey = [:]
                        self.backgroundProcessingTaskLaunched = false
                        self.checkTasks()
                        self.updateBackgroundProcessingTaskStateFromPendingMediaUploads()
                    } else if !self.backgroundProcessingTaskCancellationRequestedByApp {
                        Logger.shared.log("Wakeup", "Non-current BG task expired externally, will delete uploading messages: \(task.identifier)")
                        self.cancelUploadingMessagesForCurrentTask()
                        self.checkTasks()
                        self.updateBackgroundProcessingTaskStateFromPendingMediaUploads()
                    }
                }
            }
            
            Task { @MainActor [weak self] in
                guard let self else {
                    task.updateTitle(task.title, subtitle: presentationData.strings.BackgroundTasks_MediaFinished)
                    task.setTaskCompleted(success: true)
                    return
                }
                
                var foregroundCancellationRequested = false
                
                while true {
                    if wasExpired {
                        break
                    }
                    
                    if self.backgroundProcessingTaskId != task.identifier || self.pendingMediaUploadsByKey.isEmpty {
                        self.backgroundProcessingTaskProgressByKey = [:]
                        task.updateTitle(task.title, subtitle: presentationData.strings.BackgroundTasks_MediaFinished)
                        task.setTaskCompleted(success: true)
                        if self.backgroundProcessingTaskId == task.identifier {
                            self.backgroundProcessingTaskId = nil
                            self.backgroundProcessingTaskLaunched = false
                            self.backgroundProcessingTaskCancellationRequestedByApp = false
                            self.checkTasks()
                            self.updateBackgroundProcessingTaskStateFromPendingMediaUploads()
                        }
                        return
                    }
                    
                    if self.inForeground {
                        if !foregroundCancellationRequested {
                            foregroundCancellationRequested = true
                            if !self.backgroundProcessingTaskCancellationRequestedByApp {
                                self.backgroundProcessingTaskCancellationRequestedByApp = true
                                BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: task.identifier)
                                Logger.shared.log("Wakeup", "Requested BG task cancellation due to foreground: \(task.identifier)")
                            }
                            self.backgroundProcessingTaskProgressByKey = [:]
                        }
                        try await Task.sleep(for: .seconds(1.0))
                        continue
                    } else {
                        foregroundCancellationRequested = false
                    }
                    
                    if self.backgroundProcessingTaskId != task.identifier {
                        return
                    }
                    
                    var currentKeys = Set<PendingMediaUploadKey>()
                    for (key, progress) in self.pendingMediaUploadsByKey {
                        currentKeys.insert(key)
                        let clampedProgress = min(1.0, max(0.0, progress))
                        if let currentProgress = self.backgroundProcessingTaskProgressByKey[key] {
                            self.backgroundProcessingTaskProgressByKey[key] = max(currentProgress, clampedProgress)
                        } else {
                            self.backgroundProcessingTaskProgressByKey[key] = clampedProgress
                        }
                    }
                    for key in self.backgroundProcessingTaskProgressByKey.keys where !currentKeys.contains(key) {
                        self.backgroundProcessingTaskProgressByKey[key] = 1.0
                    }
                    
                    let progressPrecision: Int64 = 1000
                    let totalItemCount = max(1, self.backgroundProcessingTaskProgressByKey.count)
                    let totalUnitCount = Int64(totalItemCount) * progressPrecision
                    
                    var completedUnitCount: Int64 = 0
                    for progress in self.backgroundProcessingTaskProgressByKey.values {
                        completedUnitCount += Int64((progress * Float(progressPrecision)).rounded(.down))
                    }
                    completedUnitCount = min(totalUnitCount, max(0, completedUnitCount))
                    
                    task.progress.totalUnitCount = totalUnitCount
                    task.progress.completedUnitCount = completedUnitCount
                    
                    let title: String = presentationData.strings.BackgroundTasks_UploadingMedia(Int32(self.pendingMediaUploadsByKey.count))
                    if task.title != title {
                        task.updateTitle(title, subtitle: presentationData.strings.BackgroundTasks_MediaSubtitle)
                    }
                    
                    try await Task.sleep(for: .seconds(1.0))
                }
            }
        })
        
        let title: String = presentationData.strings.BackgroundTasks_UploadingMedia(Int32(self.pendingMediaUploadsByKey.count))
        
        let request = BGContinuedProcessingTaskRequest(
            identifier: uploadTaskId,
            title: title,
            subtitle: presentationData.strings.BackgroundTasks_MediaSubtitle
        )
        request.strategy = .fail
        
        do {
            try BGTaskScheduler.shared.submit(request)
            self.backgroundProcessingTaskId = uploadTaskId
            self.backgroundProcessingTaskLaunched = false
            self.checkTasks()
        } catch let e {
            Logger.shared.log("Wakeup", "BGTaskScheduler submit error: \(e)")
        }
    }
    
    private func startBackgroundStoryProcessingTaskIfNeeded() {
        guard #available(iOS 26.0, *) else {
            return
        }
        guard !self.inForeground else {
            return
        }
        guard self.backgroundStoryProcessingTaskId == nil else {
            return
        }
        guard let presentationData = self.presentationData() else {
            return
        }
        
        let baseAppBundleId = Bundle.main.bundleIdentifier!
        let uploadTaskId = "\(baseAppBundleId).upload.story\(self.nextBackgroundStoryProcessingTaskId)"
        self.nextBackgroundStoryProcessingTaskId += 1
        self.backgroundStoryProcessingTaskProgressByKey = [:]
        self.backgroundStoryProcessingTaskLaunched = false
        self.backgroundStoryProcessingTaskCancellationRequestedByApp = false
        
        BGTaskScheduler.shared.register(forTaskWithIdentifier: uploadTaskId, using: nil, launchHandler: { [weak self] task in
            guard let task = task as? BGContinuedProcessingTask else {
                return
            }
            guard let self else {
                task.updateTitle(task.title, subtitle: presentationData.strings.BackgroundTasks_StoryFinished)
                task.setTaskCompleted(success: true)
                return
            }
            
            Task { @MainActor [weak self] in
                guard let self else {
                    return
                }
                if self.backgroundStoryProcessingTaskId == task.identifier {
                    self.backgroundStoryProcessingTaskLaunched = true
                }
            }
            
            var wasExpired = false
            
            task.expirationHandler = { [weak self] in
                wasExpired = true
                
                Queue.mainQueue().async {
                    guard let self else {
                        return
                    }
                    if self.backgroundStoryProcessingTaskId == task.identifier {
                        let cancelledByApp = self.backgroundStoryProcessingTaskCancellationRequestedByApp
                        self.backgroundStoryProcessingTaskCancellationRequestedByApp = false
                        if cancelledByApp {
                            Logger.shared.log("Wakeup", "Story BG task expired after app cancellation: \(task.identifier)")
                        } else {
                            Logger.shared.log("Wakeup", "Story BG task expired externally, will cancel uploading stories: \(task.identifier)")
                            self.cancelUploadingStoriesForCurrentTask()
                        }
                        self.backgroundStoryProcessingTaskId = nil
                        self.backgroundStoryProcessingTaskProgressByKey = [:]
                        self.backgroundStoryProcessingTaskLaunched = false
                        self.checkTasks()
                        self.updateBackgroundProcessingTaskStateFromPendingStoryUploads()
                    } else if !self.backgroundStoryProcessingTaskCancellationRequestedByApp {
                        Logger.shared.log("Wakeup", "Non-current story BG task expired externally, will cancel uploading stories: \(task.identifier)")
                        self.cancelUploadingStoriesForCurrentTask()
                        self.checkTasks()
                        self.updateBackgroundProcessingTaskStateFromPendingStoryUploads()
                    }
                }
            }
            
            Task { @MainActor [weak self] in
                guard let self else {
                    task.updateTitle(task.title, subtitle: presentationData.strings.BackgroundTasks_StoryFinished)
                    task.setTaskCompleted(success: true)
                    return
                }
                
                var foregroundCancellationRequested = false
                var currentDisplayedTitle: String?
                var currentDisplayedSubtitle: String?
                
                while true {
                    if wasExpired {
                        break
                    }
                    
                    if self.backgroundStoryProcessingTaskId != task.identifier || self.pendingStoryUploadStatusesByKey.isEmpty {
                        self.backgroundStoryProcessingTaskProgressByKey = [:]
                        task.updateTitle(task.title, subtitle: presentationData.strings.BackgroundTasks_StoryFinished)
                        task.setTaskCompleted(success: true)
                        if self.backgroundStoryProcessingTaskId == task.identifier {
                            self.backgroundStoryProcessingTaskId = nil
                            self.backgroundStoryProcessingTaskLaunched = false
                            self.backgroundStoryProcessingTaskCancellationRequestedByApp = false
                            self.checkTasks()
                            self.updateBackgroundProcessingTaskStateFromPendingStoryUploads()
                        }
                        return
                    }
                    
                    if self.inForeground {
                        if !foregroundCancellationRequested {
                            foregroundCancellationRequested = true
                            if !self.backgroundStoryProcessingTaskCancellationRequestedByApp {
                                self.backgroundStoryProcessingTaskCancellationRequestedByApp = true
                                BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: task.identifier)
                                Logger.shared.log("Wakeup", "Requested story BG task cancellation due to foreground: \(task.identifier)")
                            }
                            self.backgroundStoryProcessingTaskProgressByKey = [:]
                        }
                        try await Task.sleep(for: .seconds(1.0))
                        continue
                    } else {
                        foregroundCancellationRequested = false
                    }
                    
                    if self.backgroundStoryProcessingTaskId != task.identifier {
                        return
                    }
                    
                    var currentKeys = Set<PendingStoryUploadKey>()
                    for (key, status) in self.pendingStoryUploadStatusesByKey {
                        currentKeys.insert(key)
                        let clampedProgress = min(1.0, max(0.0, status.progress))
                        if let currentProgress = self.backgroundStoryProcessingTaskProgressByKey[key] {
                            self.backgroundStoryProcessingTaskProgressByKey[key] = max(currentProgress, clampedProgress)
                        } else {
                            self.backgroundStoryProcessingTaskProgressByKey[key] = clampedProgress
                        }
                    }
                    for key in self.backgroundStoryProcessingTaskProgressByKey.keys where !currentKeys.contains(key) {
                        self.backgroundStoryProcessingTaskProgressByKey[key] = 1.0
                    }
                    
                    let progressPrecision: Int64 = 1000
                    let totalItemCount = max(1, self.backgroundStoryProcessingTaskProgressByKey.count)
                    let totalUnitCount = Int64(totalItemCount) * progressPrecision
                    
                    var completedUnitCount: Int64 = 0
                    for progress in self.backgroundStoryProcessingTaskProgressByKey.values {
                        completedUnitCount += Int64((progress * Float(progressPrecision)).rounded(.down))
                    }
                    completedUnitCount = min(totalUnitCount, max(0, completedUnitCount))
                    
                    task.progress.totalUnitCount = totalUnitCount
                    task.progress.completedUnitCount = completedUnitCount
                    
                    let title: String = presentationData.strings.BackgroundTasks_UploadingStories(Int32(self.pendingStoryUploadsByKey.count))
                    let subtitle: String
                    if self.pendingStoryUploadStatusesByKey.values.contains(where: { $0.phase == .processing }) {
                        subtitle = presentationData.strings.BackgroundTasks_StoryOpenAppToContinue
                    } else {
                        subtitle = presentationData.strings.BackgroundTasks_StorySubtitle
                    }
                    if currentDisplayedTitle != title || currentDisplayedSubtitle != subtitle {
                        task.updateTitle(title, subtitle: subtitle)
                        currentDisplayedTitle = title
                        currentDisplayedSubtitle = subtitle
                    }
                    
                    try await Task.sleep(for: .seconds(1.0))
                }
            }
        })
        
        let title: String = presentationData.strings.BackgroundTasks_UploadingStories(Int32(self.pendingStoryUploadsByKey.count))
        let subtitle: String
        if self.pendingStoryUploadStatusesByKey.values.contains(where: { $0.phase == .processing }) {
            subtitle = presentationData.strings.BackgroundTasks_StoryOpenAppToContinue
        } else {
            subtitle = presentationData.strings.BackgroundTasks_StorySubtitle
        }
        
        let request = BGContinuedProcessingTaskRequest(
            identifier: uploadTaskId,
            title: title,
            subtitle: subtitle
        )
        request.strategy = .fail
        /*if BGTaskScheduler.supportedResources.contains(.gpu) {
            request.requiredResources = .gpu
        }*/
        
        do {
            try BGTaskScheduler.shared.submit(request)
            self.backgroundStoryProcessingTaskId = uploadTaskId
            self.backgroundStoryProcessingTaskLaunched = false
            self.checkTasks()
        } catch let e {
            Logger.shared.log("Wakeup", "Story BGTaskScheduler submit error: \(e)")
        }
    }
    
    func allowBackgroundTimeExtension(timeout: Double, extendNow: Bool = false) {
        let shouldCheckTasks = self.allowBackgroundTimeExtensionDeadline == nil
        self.allowBackgroundTimeExtensionDeadline = CFAbsoluteTimeGetCurrent() + timeout
        
        self.allowBackgroundTimeExtensionDeadlineTimer?.invalidate()
        self.allowBackgroundTimeExtensionDeadlineTimer = SwiftSignalKit.Timer(timeout: timeout, repeat: false, completion: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.allowBackgroundTimeExtensionDeadlineTimer?.invalidate()
            strongSelf.allowBackgroundTimeExtensionDeadlineTimer = nil
            strongSelf.checkTasks()
        }, queue: .mainQueue())
        self.allowBackgroundTimeExtensionDeadlineTimer?.start()
        
        if extendNow {
            if self.activeExplicitExtensionTimer == nil {
                let activeExplicitExtensionTimer = SwiftSignalKit.Timer(timeout: 20.0, repeat: false, completion: { [weak self] in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.activeExplicitExtensionTimer?.invalidate()
                    strongSelf.activeExplicitExtensionTimer = nil
                    if let activeExplicitExtensionTask = strongSelf.activeExplicitExtensionTask {
                        strongSelf.activeExplicitExtensionTask = nil
                        strongSelf.endBackgroundTask(activeExplicitExtensionTask)
                    }
                    strongSelf.checkTasks()
                }, queue: .mainQueue())
                self.activeExplicitExtensionTimer = activeExplicitExtensionTimer
                activeExplicitExtensionTimer.start()
                
                self.activeExplicitExtensionTask = self.beginBackgroundTask("explicit-extension") { [weak self, weak activeExplicitExtensionTimer] in
                    guard let self, let activeExplicitExtensionTimer else {
                        return
                    }
                    if self.activeExplicitExtensionTimer === activeExplicitExtensionTimer {
                        self.activeExplicitExtensionTimer?.invalidate()
                        self.activeExplicitExtensionTimer = nil
                        if let activeExplicitExtensionTask = self.activeExplicitExtensionTask {
                            self.activeExplicitExtensionTask = nil
                            self.endBackgroundTask(activeExplicitExtensionTask)
                        }
                        self.checkTasks()
                    }
                }
            }
        }
        if shouldCheckTasks || extendNow {
            self.checkTasks()
        }
    }
    
    func replaceCurrentExtensionWithExternalTime(completion: @escaping () -> Void, timeout: Double) {
        if let (currentCompletion, timer) = self.currentExternalCompletion {
            currentCompletion()
            timer.invalidate()
            self.currentExternalCompletion = nil
        }
        let timer = SwiftSignalKit.Timer(timeout: timeout - 5.0, repeat: false, completion: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.currentExternalCompletionValidationTimer?.invalidate()
            strongSelf.currentExternalCompletionValidationTimer = nil
            if let (completion, timer) = strongSelf.currentExternalCompletion {
                strongSelf.currentExternalCompletion = nil
                timer.invalidate()
                completion()
            }
            strongSelf.checkTasks()
        }, queue: Queue.mainQueue())
        self.currentExternalCompletion = (completion, timer)
        timer.start()
        
        self.currentExternalCompletionValidationTimer?.invalidate()
        let validationTimer = SwiftSignalKit.Timer(timeout: 1.0, repeat: false, completion: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.currentExternalCompletionValidationTimer?.invalidate()
            strongSelf.currentExternalCompletionValidationTimer = nil
            strongSelf.checkTasks()
        }, queue: Queue.mainQueue())
        self.currentExternalCompletionValidationTimer = validationTimer
        validationTimer.start()
        self.checkTasks()
    }
    
    func checkTasks() {
        var hasTasksForBackgroundExtension = false
        
        var hasActiveCalls = false
        var pendingMessageCount = 0
        for (_, _, tasks) in self.accountsAndTasks {
            if tasks.activeCalls {
                hasActiveCalls = true
            }
            pendingMessageCount += tasks.importantTasks.pendingMessageCount
        }
        
        var endTaskAfterTransactionsComplete: UIBackgroundTaskIdentifier?
        
        if self.inForeground || self.hasActiveAudioSession || hasActiveCalls {
            if let (completion, timer) = self.currentExternalCompletion {
                self.currentExternalCompletion = nil
                completion()
                timer.invalidate()
            }
            
            if let (taskId, _, timer) = self.currentTask {
                self.currentTask = nil
                timer.invalidate()
                self.endBackgroundTask(taskId)
                self.isInBackgroundExtension = false
            }
        } else {
            for (_, _, tasks) in self.accountsAndTasks {
                if !tasks.isEmpty {
                    hasTasksForBackgroundExtension = true
                    break
                }
            }
            
            if !hasTasksForBackgroundExtension && self.currentExternalCompletionValidationTimer == nil {
                if let (completion, timer) = self.currentExternalCompletion {
                    self.currentExternalCompletion = nil
                    completion()
                    timer.invalidate()
                }
            }
            
            if self.activeExplicitExtensionTimer != nil {
                hasTasksForBackgroundExtension = true
            }
            
            let canBeginBackgroundExtensionTasks = self.allowBackgroundTimeExtensionDeadline.flatMap({ CFAbsoluteTimeGetCurrent() < $0 }) ?? false
            if hasTasksForBackgroundExtension {
                if canBeginBackgroundExtensionTasks {
                    var endTaskId: UIBackgroundTaskIdentifier?
                    
                    let currentTime = CFAbsoluteTimeGetCurrent()
                    if let (taskId, startTime, timer) = self.currentTask {
                        if startTime < currentTime + 1.0 {
                            self.currentTask = nil
                            timer.invalidate()
                            endTaskId = taskId
                        }
                    }
                    
                    if self.currentTask == nil {
                        var actualTaskId: UIBackgroundTaskIdentifier?
                        let handleExpiration: () -> Void = { [weak self] in
                            guard let strongSelf = self else {
                                return
                            }
                            
                            if let actualTaskId {
                                strongSelf.endBackgroundTask(actualTaskId)
                                
                                if let (taskId, _, timer) = strongSelf.currentTask, taskId == actualTaskId {
                                    timer.invalidate()
                                    strongSelf.currentTask = nil
                                }
                            }
                            
                            strongSelf.isInBackgroundExtension = false
                            strongSelf.checkTasks()
                        }
                        if let taskId = self.beginBackgroundTask("background-wakeup", {
                            handleExpiration()
                        }) {
                            actualTaskId = taskId
                            let timer = SwiftSignalKit.Timer(timeout: min(30.0, max(0.0, self.backgroundTimeRemaining() - 5.0)), repeat: false, completion: {
                                handleExpiration()
                            }, queue: Queue.mainQueue())
                            self.currentTask = (taskId, currentTime, timer)
                            timer.start()
                            
                            endTaskId.flatMap(self.endBackgroundTask)
                            
                            self.isInBackgroundExtension = true
                        }
                    }
                }
            } else if let (taskId, _, timer) = self.currentTask {
                self.currentTask = nil
                
                timer.invalidate()
                
                endTaskAfterTransactionsComplete = taskId
                
                self.isInBackgroundExtension = false
            }
        }
        
        if pendingMessageCount != 0 && !self.inForeground {
            if self.keepIdleDisposable == nil {
                self.keepIdleDisposable = self.acquireIdleExtension()
            }
        } else {
            if let keepIdleDisposable = self.keepIdleDisposable {
                self.keepIdleDisposable = nil
                keepIdleDisposable.dispose()
            }
        }
        
        self.updateAccounts(hasTasks: hasTasksForBackgroundExtension, endTaskAfterTransactionsComplete: endTaskAfterTransactionsComplete)
        
        /*if !self.inForeground && pendingMessageCount != 0 && !self.hasActiveAudioSession {
            if self.silenceAudioRenderer == nil {
                let audioSession = AVAudioSession()
                let _ = try? audioSession.setCategory(.ambient)
                let _ = try? audioSession.setMode(.default)
                let silenceAudioRenderer = MediaPlayerAudioRenderer(
                    audioSession: .custom({ control in
                        let _ = try? audioSession.setActive(true)
                        control.activate()
                        
                        return EmptyDisposable
                    }),
                    forAudioVideoMessage: false,
                    playAndRecord: false,
                    useVoiceProcessingMode: false,
                    soundMuted: false,
                    ambient: true,
                    mixWithOthers: true,
                    forceAudioToSpeaker: false,
                    baseRate: 1.0,
                    audioLevelPipe: ValuePipe(),
                    updatedRate: {},
                    audioPaused: {}
                )
                self.silenceAudioRenderer = silenceAudioRenderer
                silenceAudioRenderer.start()
            }
        } else if let silenceAudioRenderer = self.silenceAudioRenderer {
            self.silenceAudioRenderer = nil
            silenceAudioRenderer.stop()
        }*/
    }
    
    private func updateAccounts(hasTasks: Bool, endTaskAfterTransactionsComplete: UIBackgroundTaskIdentifier?) {
        if self.inForeground || self.hasActiveAudioSession || self.isInBackgroundExtension || self.backgroundProcessingTaskId != nil || self.backgroundStoryProcessingTaskId != nil || (hasTasks && self.currentExternalCompletion != nil) || self.activeExplicitExtensionTimer != nil || self.silenceAudioRenderer != nil {
            Logger.shared.log("Wakeup", "enableBeginTransactions: true (active)")
            
            for (account, primary, tasks) in self.accountsAndTasks {
                account.postbox.setCanBeginTransactions(true)
                
                if (self.inForeground && primary) || !tasks.isEmpty || (self.activeExplicitExtensionTimer != nil && primary) {
                    account.shouldBeServiceTaskMaster.set(.single(.always))
                } else {
                    account.shouldBeServiceTaskMaster.set(.single(.never))
                }
                account.shouldExplicitelyKeepWorkerConnections.set(.single(tasks.backgroundAudio || tasks.importantTasks.pendingStoryCount != 0 || tasks.importantTasks.pendingMessageCount != 0))
                account.shouldKeepOnlinePresence.set(.single(primary && self.inForeground))
                account.shouldKeepBackgroundDownloadConnections.set(.single(tasks.backgroundDownloads))
            }
            
            if let endTaskAfterTransactionsComplete {
                self.endBackgroundTask(endTaskAfterTransactionsComplete)
            }
        } else {
            var enableBeginTransactions = false
            if self.allowBackgroundTimeExtensionDeadlineTimer != nil {
                enableBeginTransactions = true
            }
            Logger.shared.log("Wakeup", "enableBeginTransactions: \(enableBeginTransactions)")
            
            final class CompletionObservationState {
                var isCompleted: Bool = false
                var remainingAccounts: [AccountRecordId]
                
                init(remainingAccounts: [AccountRecordId]) {
                    self.remainingAccounts = remainingAccounts
                }
            }
            let completionState = Atomic<CompletionObservationState>(value: CompletionObservationState(remainingAccounts: self.accountsAndTasks.map(\.0.id)))
            let checkCompletionState: (AccountRecordId?) -> Void = { id in
                Queue.mainQueue().async {
                    var shouldComplete = false
                    completionState.with { state in
                        if let id {
                            state.remainingAccounts.removeAll(where: { $0 == id })
                        }
                        if state.remainingAccounts.isEmpty && !state.isCompleted {
                            state.isCompleted = true
                            shouldComplete = true
                        }
                    }
                    if shouldComplete, let endTaskAfterTransactionsComplete {
                        self.endBackgroundTask(endTaskAfterTransactionsComplete)
                    }
                }
            }
            
            for (account, _, _) in self.accountsAndTasks {
                let accountId = account.id
                account.postbox.setCanBeginTransactions(enableBeginTransactions, afterTransactionIfRunning: {
                    checkCompletionState(accountId)
                })
                account.shouldBeServiceTaskMaster.set(.single(.never))
                account.shouldKeepOnlinePresence.set(.single(false))
                account.shouldKeepBackgroundDownloadConnections.set(.single(false))
            }
            
            checkCompletionState(nil)
        }
    }
}
