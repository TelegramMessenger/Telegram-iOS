import Foundation
import BackgroundTasks
import AVFAudio
import UIKit
import SwiftSignalKit
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

private struct PendingMediaUploadKey: Hashable {
    let accountId: AccountRecordId
    let messageId: EngineMessage.Id
}

private struct PendingStoryUploadKey: Hashable {
    let accountId: AccountRecordId
    let stableId: Int32
}

/// Keeps uploads the user started running after the app moves to the background, using a
/// continued processing task (iOS 26+). The system shows the task as a Live Activity with the
/// title, subtitle and progress reported here, and offers a Stop button.
///
/// Apple's rules for this task type, which this class follows:
/// - the request is submitted from the foreground, as the result of a user action: here, when
///   an upload queued during this run of the app appears while the app is active, which happens
///   when the user sends something. Uploads resumed from an earlier run never start a task;
/// - the task keeps running when the app returns to the foreground, and ends when the work ends;
/// - progress is reported continuously, since the system stops tasks that make no progress first;
/// - expiration means the user tapped Stop or the system ended the task, and the app cannot tell
///   which (the API carries no reason). The uploads the task covered are stopped through `stopped`:
///   messages are left as failed, so they can be resent or deleted and nothing is lost silently.
private typealias MessageUploadTask = ContinuedUploadTask<PendingMediaUploadKey>
private typealias StoryUploadTask = ContinuedUploadTask<PendingStoryUploadKey>

private final class ContinuedUploadTask<Key: Hashable> {
    struct Item: Equatable {
        var progress: Float
        var needsForeground: Bool
        /// Queued during this run of the app, so by a tap on Send. Uploads resumed at launch
        /// from an earlier run never start a task: the user did not just ask for them.
        var isFresh: Bool
    }

    struct Texts {
        var title: String
        var subtitle: String
    }

    private let kind: String
    private let texts: ([Key: Item]) -> Texts
    private let finishedSubtitle: () -> String
    private let stopped: ([Key]) -> Void
    private let stateUpdated: () -> Void

    private var items: [Key: Item] = [:]
    private var knownKeys = Set<Key>()
    private var nextTaskIndex: Int = 0

    /// Set from submission until the task ends; the task may not have launched yet.
    private var taskId: String?
    /// The launched `BGContinuedProcessingTask`.
    private var task: AnyObject?
    private var progressByKey: [Key: Float] = [:]
    private var displayedTexts: Texts?
    private var progressTimer: SwiftSignalKit.Timer?

    /// True while the system runs the task, so the app is not suspended.
    var isRunning: Bool {
        return self.task != nil
    }

    init(kind: String, texts: @escaping ([Key: Item]) -> Texts, finishedSubtitle: @escaping () -> String, stopped: @escaping ([Key]) -> Void, stateUpdated: @escaping () -> Void) {
        self.kind = kind
        self.texts = texts
        self.finishedSubtitle = finishedSubtitle
        self.stopped = stopped
        self.stateUpdated = stateUpdated
    }

    deinit {
        self.progressTimer?.invalidate()
    }

    /// - Parameter canSubmit: whether a new task may be submitted now (feature enabled, app
    ///   active in the foreground, Background App Refresh available).
    func update(items: [Key: Item], canSubmit: Bool) {
        assert(Queue.mainQueue().isCurrent())

        let hasNewKeys = items.contains(where: { key, item in
            return item.isFresh && !self.knownKeys.contains(key)
        })
        self.knownKeys = Set(items.keys)
        self.items = items

        if let taskId = self.taskId {
            if items.isEmpty {
                if self.task != nil {
                    self.finish()
                } else {
                    // Submitted but not launched yet: withdraw the request.
                    Logger.shared.log("Wakeup", "Continued \(self.kind) task: no uploads left before launch, cancelling \(taskId)")
                    if #available(iOS 26.0, *) {
                        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskId)
                    }
                    self.reset()
                }
            } else if self.task != nil {
                self.reportProgress()
            }
        } else if hasNewKeys && canSubmit && !items.isEmpty {
            self.submit()
        }
    }

    private func submit() {
        guard #available(iOS 26.0, *) else {
            return
        }

        let baseAppBundleId = Bundle.main.bundleIdentifier!
        // Every task needs an identifier of its own: a second submission under one that was
        // already used does not run. The prefix is covered by the `<bundle id>.upload.*`
        // wildcard in BGTaskSchedulerPermittedIdentifiers.
        let taskId = "\(baseAppBundleId).upload.\(self.kind).\(Int64(Date().timeIntervalSince1970 * 1000.0)).\(self.nextTaskIndex)"
        self.nextTaskIndex += 1
        self.taskId = taskId
        self.progressByKey = [:]
        self.displayedTexts = nil

        let kind = self.kind
        let registered = BGTaskScheduler.shared.register(forTaskWithIdentifier: taskId, using: nil, launchHandler: { [weak self] task in
            guard let task = task as? BGContinuedProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }
            // Set right away, before the hop to the main queue, so that a stop arriving at any
            // point after launch is seen. Stop on the Live Activity can arrive either way: as an
            // expiration, or as a cancellation of the task's progress.
            task.expirationHandler = { [weak self] in
                Logger.shared.log("Wakeup", "Continued \(kind) task: expiration handler called for \(taskId)")
                Queue.mainQueue().async {
                    self?.expired(taskId: taskId)
                }
            }
            task.progress.cancellationHandler = { [weak self] in
                Logger.shared.log("Wakeup", "Continued \(kind) task: progress cancelled for \(taskId)")
                Queue.mainQueue().async {
                    self?.expired(taskId: taskId)
                }
            }
            Queue.mainQueue().async {
                guard let self else {
                    task.setTaskCompleted(success: true)
                    return
                }
                self.launched(task: task, taskId: taskId)
            }
        })
        if !registered {
            Logger.shared.log("Wakeup", "Continued \(self.kind) task: could not register \(taskId)")
            self.reset()
            return
        }

        let texts = self.texts(self.items)
        let request = BGContinuedProcessingTaskRequest(identifier: taskId, title: texts.title, subtitle: texts.subtitle)
        // Queue rather than fail: if the system cannot start the task right away, it starts it
        // as soon as it can. Until then the app keeps its regular background time.
        request.strategy = .queue

        Logger.shared.log("Wakeup", "Continued \(self.kind) task: submitting \(taskId) for \(self.items.count) uploads")

        let submissionFailed: (Error) -> Void = { [weak self] error in
            Queue.mainQueue().async {
                Logger.shared.log("Wakeup", "Continued \(taskId) submission failed: \(error)")
                guard let self, self.taskId == taskId else {
                    return
                }
                self.reset()
            }
        }
        if #available(iOS 27.0, *) {
            // Reports every submission error; must not be called on the main thread.
            DispatchQueue.global(qos: .userInitiated).async {
                BGTaskScheduler.shared.submitTaskRequest(request, completionHandler: { error in
                    if let error {
                        submissionFailed(error)
                    } else {
                        Logger.shared.log("Wakeup", "Continued \(kind) task: \(taskId) submission accepted")
                    }
                })
            }
        } else {
            do {
                try BGTaskScheduler.shared.submit(request)
            } catch let error {
                submissionFailed(error)
            }
        }
    }

    @available(iOS 26.0, *)
    private func launched(task: BGContinuedProcessingTask, taskId: String) {
        guard self.taskId == taskId, self.task == nil else {
            // Already stopped (or replaced) before this launch reached the main queue.
            Logger.shared.log("Wakeup", "Continued \(self.kind) task: \(taskId) launched after it was stopped")
            task.setTaskCompleted(success: false)
            return
        }
        guard !self.items.isEmpty else {
            Logger.shared.log("Wakeup", "Continued \(self.kind) task: \(taskId) launched with nothing to do")
            task.updateTitle(task.title, subtitle: self.finishedSubtitle())
            task.setTaskCompleted(success: true)
            self.reset()
            return
        }
        Logger.shared.log("Wakeup", "Continued \(self.kind) task: launched \(taskId)")

        self.task = task

        let progressTimer = SwiftSignalKit.Timer(timeout: 1.0, repeat: true, completion: { [weak self] in
            self?.reportProgress()
        }, queue: Queue.mainQueue())
        self.progressTimer = progressTimer
        progressTimer.start()

        self.reportProgress()
        self.stateUpdated()
    }

    private func reportProgress() {
        guard #available(iOS 26.0, *), let task = self.task as? BGContinuedProcessingTask else {
            return
        }
        if self.items.isEmpty {
            self.finish()
            return
        }
        if task.progress.isCancelled, let taskId = self.taskId {
            // Covers a cancellation whose handler did not reach us.
            Logger.shared.log("Wakeup", "Continued \(self.kind) task: progress found cancelled")
            self.expired(taskId: taskId)
            return
        }

        // An item's progress never goes back, and an item that left the list (sent, failed or
        // deleted) counts as done, so the bar only moves forward for a fixed set of items.
        for (key, item) in self.items {
            let progress = min(1.0, max(0.0, item.progress))
            self.progressByKey[key] = max(self.progressByKey[key] ?? 0.0, progress)
        }
        for key in self.progressByKey.keys where self.items[key] == nil {
            self.progressByKey[key] = 1.0
        }

        let precision: Int64 = 1000
        let totalUnitCount = Int64(max(1, self.progressByKey.count)) * precision
        var completedUnitCount: Int64 = 0
        for progress in self.progressByKey.values {
            completedUnitCount += Int64((progress * Float(precision)).rounded(.down))
        }
        task.progress.totalUnitCount = totalUnitCount
        task.progress.completedUnitCount = min(totalUnitCount, max(0, completedUnitCount))

        let texts = self.texts(self.items)
        if self.displayedTexts?.title != texts.title || self.displayedTexts?.subtitle != texts.subtitle {
            self.displayedTexts = texts
            task.updateTitle(texts.title, subtitle: texts.subtitle)
        }
    }

    private func finish() {
        guard #available(iOS 26.0, *), let task = self.task as? BGContinuedProcessingTask else {
            self.reset()
            return
        }
        Logger.shared.log("Wakeup", "Continued \(self.kind) task: uploads finished, completing \(self.taskId ?? "")")
        task.progress.completedUnitCount = task.progress.totalUnitCount
        task.updateTitle(task.title, subtitle: self.finishedSubtitle())
        task.setTaskCompleted(success: true)
        self.reset()
    }

    private func expired(taskId: String) {
        guard self.taskId == taskId else {
            return
        }
        // The user tapped Stop, or the system ended the task.
        let keys = Array(self.items.keys)
        Logger.shared.log("Wakeup", "Continued \(self.kind) task: \(taskId) expired, stopping \(keys.count) uploads")
        if #available(iOS 26.0, *), let task = self.task as? BGContinuedProcessingTask {
            task.setTaskCompleted(success: false)
        }
        self.reset()
        if !keys.isEmpty {
            self.stopped(keys)
        }
    }

    private func reset() {
        let wasRunning = self.task != nil
        self.taskId = nil
        self.task = nil
        self.progressByKey = [:]
        self.displayedTexts = nil
        self.progressTimer?.invalidate()
        self.progressTimer = nil
        if wasRunning {
            self.stateUpdated()
        }
    }
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
    
    private var messageUploadTask: MessageUploadTask!
    /// Pending message uploads, and when each message was queued (0 while being looked up).
    private var pendingMediaUploadsByKey: [PendingMediaUploadKey: Float] = [:]
    private var pendingMediaUploadTimestamps: [PendingMediaUploadKey: Int32] = [:]
    private var pendingMediaUploadTimestampLookups = Set<PendingMediaUploadKey>()
    /// The start of this run of the app, per account in the clock messages are stamped with.
    private var sessionStartTimestampByAccount: [AccountRecordId: Int32] = [:]
    /// The start of this run of the app in the device clock, which pending stories are stamped with.
    private let sessionStartTimestamp = Int32(Date().timeIntervalSince1970)
    /// Writes that store stopped uploads as failed; the database stays writable until they finish.
    private var pendingUploadStopWrites: Int = 0
    private var storyUploadTask: StoryUploadTask!

    public init(beginBackgroundTask: @escaping (String, @escaping () -> Void) -> UIBackgroundTaskIdentifier?, endBackgroundTask: @escaping (UIBackgroundTaskIdentifier) -> Void, backgroundTimeRemaining: @escaping () -> Double, acquireIdleExtension: @escaping () -> Disposable?, activeAccounts: Signal<(primary: Account?, accounts: [(AccountRecordId, Account)]), NoError>, liveLocationPolling: Signal<AccountRecordId?, NoError>, watchTasks: Signal<AccountRecordId?, NoError>, inForeground: Signal<Bool, NoError>, hasActiveAudioSession: Signal<Bool, NoError>, notificationManager: SharedNotificationManager?, mediaManager: MediaManager, callManager: PresentationCallManager?, accountUserInterfaceInUse: @escaping (AccountRecordId) -> Signal<Bool, NoError>, presentationData: @escaping () -> PresentationData?) {
        assert(Queue.mainQueue().isCurrent())
        
        self.beginBackgroundTask = beginBackgroundTask
        self.endBackgroundTask = endBackgroundTask
        self.backgroundTimeRemaining = backgroundTimeRemaining
        self.acquireIdleExtension = acquireIdleExtension
        self.presentationData = presentationData

        self.messageUploadTask = MessageUploadTask(kind: "message", texts: { [weak self] items in
            guard let strings = self?.presentationData()?.strings else {
                return MessageUploadTask.Texts(title: "", subtitle: "")
            }
            return MessageUploadTask.Texts(title: strings.BackgroundTasks_UploadingMedia(Int32(items.count)), subtitle: strings.BackgroundTasks_MediaSubtitle)
        }, finishedSubtitle: { [weak self] in
            return self?.presentationData()?.strings.BackgroundTasks_MediaFinished ?? ""
        }, stopped: { [weak self] keys in
            self?.stopMessageUploads(keys: keys)
        }, stateUpdated: { [weak self] in
            self?.checkTasks()
        })
        self.storyUploadTask = StoryUploadTask(kind: "story", texts: { [weak self] items in
            guard let self, let strings = self.presentationData()?.strings else {
                return StoryUploadTask.Texts(title: "", subtitle: "")
            }
            let subtitle: String
            if !self.inForeground && items.values.contains(where: { $0.needsForeground }) {
                // A story's video is still being prepared, which only continues in the app.
                subtitle = strings.BackgroundTasks_StoryOpenAppToContinue
            } else {
                subtitle = strings.BackgroundTasks_StorySubtitle
            }
            return StoryUploadTask.Texts(title: strings.BackgroundTasks_UploadingStories(Int32(items.count)), subtitle: subtitle)
        }, finishedSubtitle: { [weak self] in
            return self?.presentationData()?.strings.BackgroundTasks_StoryFinished ?? ""
        }, stopped: { [weak self] keys in
            self?.stopStoryUploads(keys: keys)
        }, stateUpdated: { [weak self] in
            self?.checkTasks()
        })

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
            Logger.shared.log("Wakeup", "Continued upload tasks enabled: \(isEnabled) (ios_killswitch_disable_bgtasks)")
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
            }
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
            for (account, _, _) in accountsAndTasks where strongSelf.sessionStartTimestampByAccount[account.id] == nil {
                strongSelf.sessionStartTimestampByAccount[account.id] = account.network.getApproximateRemoteTimestamp()
            }
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
            strongSelf.lookUpPendingMediaUploadTimestamps()
            strongSelf.updateMessageUploadTask()
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
            let sessionStartTimestamp = strongSelf.sessionStartTimestamp
            strongSelf.storyUploadTask.update(items: pendingStoryUploadStatusesByKey.mapValues { status in
                return StoryUploadTask.Item(progress: status.progress, needsForeground: status.phase == .processing, isFresh: status.timestamp >= sessionStartTimestamp)
            }, canSubmit: strongSelf.canSubmitContinuedUploadTask())
        })
    }

    private func updateMessageUploadTask() {
        // A message whose queue time is still being looked up is left out until it is known, so
        // that a fresh send is never mistaken for a resumed one.
        var items: [PendingMediaUploadKey: MessageUploadTask.Item] = [:]
        for (key, progress) in self.pendingMediaUploadsByKey {
            guard let timestamp = self.pendingMediaUploadTimestamps[key] else {
                continue
            }
            let isFresh: Bool
            if let sessionStartTimestamp = self.sessionStartTimestampByAccount[key.accountId] {
                isFresh = timestamp >= sessionStartTimestamp
            } else {
                isFresh = false
            }
            items[key] = MessageUploadTask.Item(progress: progress, needsForeground: false, isFresh: isFresh)
        }
        self.messageUploadTask.update(items: items, canSubmit: self.canSubmitContinuedUploadTask())
    }
    
    private func lookUpPendingMediaUploadTimestamps() {
        for key in self.pendingMediaUploadTimestamps.keys where self.pendingMediaUploadsByKey[key] == nil {
            self.pendingMediaUploadTimestamps.removeValue(forKey: key)
        }
        
        var missingByAccount: [AccountRecordId: [EngineMessage.Id]] = [:]
        for key in self.pendingMediaUploadsByKey.keys {
            if self.pendingMediaUploadTimestamps[key] == nil && !self.pendingMediaUploadTimestampLookups.contains(key) {
                missingByAccount[key.accountId, default: []].append(key.messageId)
            }
        }
        for (accountId, messageIds) in missingByAccount {
            guard let account = self.accountsAndTasks.first(where: { $0.0.id == accountId })?.0 else {
                continue
            }
            for messageId in messageIds {
                self.pendingMediaUploadTimestampLookups.insert(PendingMediaUploadKey(accountId: accountId, messageId: messageId))
            }
            let _ = (TelegramEngine(account: account).data.get(EngineDataMap(
                messageIds.map(TelegramEngine.EngineData.Item.Messages.Message.init(id:))
            ))
            |> deliverOnMainQueue).startStandalone(next: { [weak self] messages in
                guard let self else {
                    return
                }
                for messageId in messageIds {
                    let key = PendingMediaUploadKey(accountId: accountId, messageId: messageId)
                    self.pendingMediaUploadTimestampLookups.remove(key)
                    if self.pendingMediaUploadsByKey[key] != nil {
                        let message: EngineMessage? = messages[messageId] ?? nil
                        self.pendingMediaUploadTimestamps[key] = message?.timestamp ?? 0
                    }
                }
                self.updateMessageUploadTask()
            })
        }
    }
    
    /// The upload Live Activity was stopped: the messages it covered stop sending and are left as
    /// failed, from where the user can resend or delete them.
    private func stopMessageUploads(keys: [PendingMediaUploadKey]) {
        var messageIdsByAccount: [AccountRecordId: [EngineMessage.Id]] = [:]
        for key in keys {
            messageIdsByAccount[key.accountId, default: []].append(key.messageId)
        }
        var signals: [Signal<Void, NoError>] = []
        for (accountId, messageIds) in messageIdsByAccount {
            guard let account = self.accountsAndTasks.first(where: { $0.0.id == accountId })?.0 else {
                Logger.shared.log("Wakeup", "Continued message task stopped: missing account \(accountId.int64), skip \(messageIds.count) messages")
                continue
            }
            Logger.shared.log("Wakeup", "Continued message task stopped: failing \(messageIds.count) messages in account \(accountId.int64)")
            signals.append(TelegramEngine(account: account).messages.failPendingMessages(ids: messageIds))
        }
        if signals.isEmpty {
            return
        }
        
        // The system suspends the app right after the task ends: hold a short background task
        // until the messages are stored as failed, or they would resume sending on the next launch.
        final class BackgroundTaskBox {
            var id: UIBackgroundTaskIdentifier?
            var isFinished = false
        }
        let backgroundTask = BackgroundTaskBox()
        self.pendingUploadStopWrites += 1
        self.checkTasks()
        let finish: () -> Void = { [weak self] in
            Queue.mainQueue().async {
                guard let self, !backgroundTask.isFinished else {
                    return
                }
                backgroundTask.isFinished = true
                self.pendingUploadStopWrites -= 1
                self.checkTasks()
                if let id = backgroundTask.id {
                    backgroundTask.id = nil
                    self.endBackgroundTask(id)
                }
            }
        }
        backgroundTask.id = self.beginBackgroundTask("continued-upload-stop", {
            finish()
        })
        let _ = (combineLatest(signals)
        |> deliverOnMainQueue).startStandalone(completed: {
            Logger.shared.log("Wakeup", "Continued message task stopped: messages stored as failed")
            finish()
        })
    }
    
    /// The upload Live Activity was stopped: the stories it covered are cancelled, as before.
    private func stopStoryUploads(keys: [PendingStoryUploadKey]) {
        for key in keys {
            guard let account = self.accountsAndTasks.first(where: { $0.0.id == key.accountId })?.0 else {
                Logger.shared.log("Wakeup", "Continued story task stopped: missing account \(key.accountId.int64)")
                continue
            }
            Logger.shared.log("Wakeup", "Continued story task stopped: cancelling story \(key.stableId) in account \(key.accountId.int64)")
            TelegramEngine(account: account).messages.cancelStoryUpload(stableId: key.stableId)
        }
    }
    
    /// A continued processing task may only be submitted from the foreground, in response to a
    /// user action. An upload that appears while the app is active comes from the user sending
    /// something (or from the app resuming the user's earlier send at launch).
    private func canSubmitContinuedUploadTask() -> Bool {
        guard #available(iOS 26.0, *) else {
            return false
        }
        guard self.enableBackgroundTasks, self.inForeground, self.presentationData() != nil else {
            return false
        }
        guard UIApplication.shared.applicationState == .active else {
            return false
        }
        // Background App Refresh off makes continued processing unavailable: the system would
        // show the task as failed.
        guard UIApplication.shared.backgroundRefreshStatus == .available else {
            return false
        }
        return true
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
        if let (taskId, _, timer) = self.currentTask {
            timer.invalidate()
            self.endBackgroundTask(taskId)
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
        let hasBackgroundLocationTask = self.accountsAndTasks.contains(where: { $0.2.backgroundLocation })
        
        if self.inForeground || self.hasActiveAudioSession || self.isInBackgroundExtension || self.messageUploadTask.isRunning || self.storyUploadTask.isRunning || self.pendingUploadStopWrites != 0 || hasBackgroundLocationTask || (hasTasks && self.currentExternalCompletion != nil) || self.activeExplicitExtensionTimer != nil || self.silenceAudioRenderer != nil {
            Logger.shared.log("Wakeup", "enableBeginTransactions: true (active)")
            
            for (account, primary, tasks) in self.accountsAndTasks {
                account.postbox.setCanBeginTransactions(true)
                
                if (self.inForeground && primary) || !tasks.isEmpty || (self.activeExplicitExtensionTimer != nil && primary) {
                    account.shouldBeServiceTaskMaster.set(.single(.always))
                } else {
                    account.shouldBeServiceTaskMaster.set(.single(.never))
                }
                account.shouldExplicitelyKeepWorkerConnections.set(.single(tasks.backgroundAudio || tasks.backgroundLocation || tasks.importantTasks.pendingStoryCount != 0 || tasks.importantTasks.pendingMessageCount != 0))
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
