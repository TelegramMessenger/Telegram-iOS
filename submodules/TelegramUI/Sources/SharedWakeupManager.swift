import Foundation
import UIKit
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramCallsUI
import AccountContext

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

public final class SharedWakeupManager {
    private let beginBackgroundTask: (String, @escaping () -> Void) -> UIBackgroundTaskIdentifier?
    private let endBackgroundTask: (UIBackgroundTaskIdentifier) -> Void
    private let backgroundTimeRemaining: () -> Double
    private let acquireIdleExtension: () -> Disposable?
    
    private var inForeground: Bool = false
    private var hasActiveAudioSession: Bool = false
    private var activeExplicitExtensionTimer: SwiftSignalKit.Timer?
    private var activeExplicitExtensionTask: UIBackgroundTaskIdentifier?
    private var allowBackgroundTimeExtensionDeadline: Double?
    private var allowBackgroundTimeExtensionDeadlineTimer: SwiftSignalKit.Timer?
    private var isInBackgroundExtension: Bool = false
    
    private var inForegroundDisposable: Disposable?
    private var hasActiveAudioSessionDisposable: Disposable?
    private var tasksDisposable: Disposable?
    private var currentTask: (UIBackgroundTaskIdentifier, Double, SwiftSignalKit.Timer)?
    private var currentExternalCompletion: (() -> Void, SwiftSignalKit.Timer)?
    private var currentExternalCompletionValidationTimer: SwiftSignalKit.Timer?
    
    private var managedPausedInBackgroundPlayer: Disposable?
    private var keepIdleDisposable: Disposable?
    
    private var accountsAndTasks: [(Account, Bool, AccountTasks)] = []
    
    public init(beginBackgroundTask: @escaping (String, @escaping () -> Void) -> UIBackgroundTaskIdentifier?, endBackgroundTask: @escaping (UIBackgroundTaskIdentifier) -> Void, backgroundTimeRemaining: @escaping () -> Double, acquireIdleExtension: @escaping () -> Disposable?, activeAccounts: Signal<(primary: Account?, accounts: [(AccountRecordId, Account)]), NoError>, liveLocationPolling: Signal<AccountRecordId?, NoError>, watchTasks: Signal<AccountRecordId?, NoError>, inForeground: Signal<Bool, NoError>, hasActiveAudioSession: Signal<Bool, NoError>, notificationManager: SharedNotificationManager?, mediaManager: MediaManager, callManager: PresentationCallManager?, accountUserInterfaceInUse: @escaping (AccountRecordId) -> Signal<Bool, NoError>) {
        assert(Queue.mainQueue().isCurrent())
        
        self.beginBackgroundTask = beginBackgroundTask
        self.endBackgroundTask = endBackgroundTask
        self.backgroundTimeRemaining = backgroundTimeRemaining
        self.acquireIdleExtension = acquireIdleExtension
        
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
                
                return combineLatest(queue: .mainQueue(), account.importantTasksRunning, notificationManager?.isPollingState(accountId: account.id) ?? .single(false), hasActiveAudio, hasActiveCalls, hasActiveLiveLocationPolling, hasWatchTasks, userInterfaceInUse)
                |> map { importantTasksRunning, isPollingState, hasActiveAudio, hasActiveCalls, hasActiveLiveLocationPolling, hasWatchTasks, userInterfaceInUse -> (Account, Bool, AccountTasks) in
                    return (account, primary?.id == account.id, AccountTasks(stateSynchronization: isPollingState, importantTasks: importantTasksRunning, backgroundLocation: hasActiveLiveLocationPolling, backgroundDownloads: false, backgroundAudio: hasActiveAudio, activeCalls: hasActiveCalls, watchTasks: hasWatchTasks, userInterfaceInUse: userInterfaceInUse))
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
    }
    
    deinit {
        self.inForegroundDisposable?.dispose()
        self.hasActiveAudioSessionDisposable?.dispose()
        self.tasksDisposable?.dispose()
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
        var hasPendingMessages = false
        for (_, _, tasks) in self.accountsAndTasks {
            if tasks.activeCalls {
                hasActiveCalls = true
                break
            }
            if tasks.importantTasks.contains(.pendingMessages) {
                hasPendingMessages = true
            }
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
        self.updateAccounts(hasTasks: hasTasksForBackgroundExtension, endTaskAfterTransactionsComplete: endTaskAfterTransactionsComplete)
        
        if hasPendingMessages {
            if self.keepIdleDisposable == nil {
                self.keepIdleDisposable = self.acquireIdleExtension()
            }
        } else {
            if let keepIdleDisposable = self.keepIdleDisposable {
                self.keepIdleDisposable = nil
                keepIdleDisposable.dispose()
            }
        }
    }
    
    private func updateAccounts(hasTasks: Bool, endTaskAfterTransactionsComplete: UIBackgroundTaskIdentifier?) {
        if self.inForeground || self.hasActiveAudioSession || self.isInBackgroundExtension || (hasTasks && self.currentExternalCompletion != nil) || self.activeExplicitExtensionTimer != nil {
            Logger.shared.log("Wakeup", "enableBeginTransactions: true (active)")
            
            for (account, primary, tasks) in self.accountsAndTasks {
                account.postbox.setCanBeginTransactions(true)
                
                if (self.inForeground && primary) || !tasks.isEmpty || (self.activeExplicitExtensionTimer != nil && primary) {
                    account.shouldBeServiceTaskMaster.set(.single(.always))
                } else {
                    account.shouldBeServiceTaskMaster.set(.single(.never))
                }
                account.shouldExplicitelyKeepWorkerConnections.set(.single(tasks.backgroundAudio))
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
