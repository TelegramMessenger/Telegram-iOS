import Foundation
import UIKit
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramUI

private struct AccountTasks {
    let stateSynchronization: Bool
    let importantTasks: AccountRunningImportantTasks
    let backgroundLocation: Bool
    let backgroundDownloads: Bool
    let backgroundAudio: Bool
    let activeCalls: Bool
    
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
        return true
    }
}

final class SharedWakeupManager {
    private var inForeground: Bool = false
    private var hasActiveAudioSession: Bool = false
    private var allowBackgroundTimeExtensionDeadline: Double?
    private var isInBackgroundExtension: Bool = false
    
    private var inForegroundDisposable: Disposable?
    private var hasActiveAudioSessionDisposable: Disposable?
    private var tasksDisposable: Disposable?
    private var currentTask: (UIBackgroundTaskIdentifier, Double, SwiftSignalKit.Timer)?
    
    private var accountsAndTasks: [(Account, Bool, AccountTasks)] = []
    
    init(activeAccounts: Signal<(primary: Account?, accounts: [AccountRecordId: Account]), NoError>, liveLocationPolling: Signal<AccountRecordId?, NoError>, inForeground: Signal<Bool, NoError>, hasActiveAudioSession: Signal<Bool, NoError>, notificationManager: SharedNotificationManager, mediaManager: MediaManager, callManager: PresentationCallManager?) {
        assert(Queue.mainQueue().isCurrent())
        
        self.inForegroundDisposable = (inForeground
        |> deliverOnMainQueue).start(next: { [weak self] value in
            guard let strongSelf = self else {
                return
            }
            strongSelf.inForeground = value
            strongSelf.checkTasks()
        })
        
        self.hasActiveAudioSessionDisposable = (hasActiveAudioSession
        |> deliverOnMainQueue).start(next: { [weak self] value in
            guard let strongSelf = self else {
                return
            }
            strongSelf.hasActiveAudioSession = value
            strongSelf.checkTasks()
        })
        
        self.tasksDisposable = (activeAccounts
        |> deliverOnMainQueue
        |> mapToSignal { primary, accounts -> Signal<[(Account, Bool, AccountTasks)], NoError> in
            let signals: [Signal<(Account, Bool, AccountTasks), NoError>] = accounts.values.map { account in
                let hasActiveMedia = mediaManager.activeGlobalMediaPlayerAccountId
                |> map { id -> Bool in
                    return id == account.id
                }
                |> distinctUntilChanged
                let isPlayingBackgroundAudio = combineLatest(queue: .mainQueue(), hasActiveMedia, hasActiveAudioSession)
                |> map { hasActiveMedia, hasActiveAudioSession -> Bool in
                    return hasActiveMedia && hasActiveAudioSession
                }
                |> distinctUntilChanged
                
                let hasActiveCalls = (callManager?.currentCallSignal ?? .single(nil))
                |> map { call in
                    return call?.account.id == account.id
                }
                |> distinctUntilChanged
                let isPlayingBackgroundActiveCall = combineLatest(queue: .mainQueue(), hasActiveCalls, hasActiveAudioSession)
                |> map { hasActiveCalls, hasActiveAudioSession -> Bool in
                    return hasActiveCalls && hasActiveAudioSession
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
                
                return combineLatest(queue: .mainQueue(), account.importantTasksRunning, notificationManager.isPollingState(accountId: account.id), hasActiveAudio, hasActiveCalls, hasActiveLiveLocationPolling)
                |> map { importantTasksRunning, isPollingState, hasActiveAudio, hasActiveCalls, hasActiveLiveLocationPolling -> (Account, Bool, AccountTasks) in
                    return (account, primary?.id == account.id, AccountTasks(stateSynchronization: isPollingState, importantTasks: importantTasksRunning, backgroundLocation: hasActiveLiveLocationPolling, backgroundDownloads: false, backgroundAudio: hasActiveAudio, activeCalls: hasActiveCalls))
                }
            }
            return combineLatest(signals)
        }
        |> deliverOnMainQueue).start(next: { [weak self] accountsAndTasks in
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
        if let (taskId, _, timer) = self.currentTask {
            timer.invalidate()
            UIApplication.shared.endBackgroundTask(taskId)
        }
    }
    
    func allowBackgroundTimeExtension(timeout: Double) {
        let shouldCheckTasks = self.allowBackgroundTimeExtensionDeadline == nil
        self.allowBackgroundTimeExtensionDeadline = CACurrentMediaTime() + timeout
        if shouldCheckTasks {
            self.checkTasks()
        }
    }
    
    func checkTasks() {
        if self.inForeground || self.hasActiveAudioSession {
            if let (taskId, _, timer) = self.currentTask {
                self.currentTask = nil
                timer.invalidate()
                UIApplication.shared.endBackgroundTask(taskId)
                self.isInBackgroundExtension = false
            }
        } else {
            var hasTasksForBackgroundExtension = false
            for (_, _, tasks) in self.accountsAndTasks {
                if !tasks.isEmpty {
                    hasTasksForBackgroundExtension = true
                    break
                }
            }
            
            let canBeginBackgroundExtensionTasks = self.allowBackgroundTimeExtensionDeadline.flatMap({ CACurrentMediaTime() < $0 }) ?? false
            if hasTasksForBackgroundExtension {
                if canBeginBackgroundExtensionTasks {
                    var endTaskId: UIBackgroundTaskIdentifier?
                    
                    let currentTime = CACurrentMediaTime()
                    if let (taskId, startTime, timer) = self.currentTask {
                        if startTime < currentTime + 1.0 {
                            self.currentTask = nil
                            timer.invalidate()
                            endTaskId = taskId
                        }
                    }
                    
                    if self.currentTask == nil {
                        let handleExpiration:() -> Void = { [weak self] in
                            guard let strongSelf = self else {
                                return
                            }
                            strongSelf.isInBackgroundExtension = false
                            strongSelf.checkTasks()
                        }
                        let taskId = UIApplication.shared.beginBackgroundTask(withName: "background-wakeup", expirationHandler: {
                            handleExpiration()
                        })
                        let timer = SwiftSignalKit.Timer(timeout: min(30.0, UIApplication.shared.backgroundTimeRemaining), repeat: false, completion: {
                            handleExpiration()
                        }, queue: Queue.mainQueue())
                        self.currentTask = (taskId, currentTime, timer)
                        timer.start()
                        
                        endTaskId.flatMap(UIApplication.shared.endBackgroundTask)
                        
                        self.isInBackgroundExtension = true
                    }
                }
            } else if let (taskId, _, timer) = self.currentTask {
                self.currentTask = nil
                timer.invalidate()
                UIApplication.shared.endBackgroundTask(taskId)
                self.isInBackgroundExtension = false
            }
        }
        self.updateAccounts()
    }
    
    private func updateAccounts() {
        if self.inForeground || self.hasActiveAudioSession || self.isInBackgroundExtension {
            for (account, primary, tasks) in self.accountsAndTasks {
                if (self.inForeground && primary) || !tasks.isEmpty {
                    account.shouldBeServiceTaskMaster.set(.single(.always))
                } else {
                    account.shouldBeServiceTaskMaster.set(.single(.never))
                }
                account.shouldExplicitelyKeepWorkerConnections.set(.single(tasks.backgroundAudio))
                account.shouldKeepOnlinePresence.set(.single(primary && self.inForeground))
                account.shouldKeepBackgroundDownloadConnections.set(.single(tasks.backgroundDownloads))
            }
        } else {
            for (account, _, _) in self.accountsAndTasks {
                account.shouldBeServiceTaskMaster.set(.single(.never))
                account.shouldKeepOnlinePresence.set(.single(false))
                account.shouldKeepBackgroundDownloadConnections.set(.single(false))
            }
        }
    }
}
