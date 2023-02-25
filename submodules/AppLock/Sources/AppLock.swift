import PtgSecretPasscodes

import Foundation
import UIKit
import TelegramCore
import Display
import SwiftSignalKit
import MonotonicTime
import AccountContext
import TelegramPresentationData
import PasscodeUI
import TelegramUIPreferences
import AppLockState
import PassKit

private func isLocked(passcodeSettings: PresentationPasscodeSettings, state: LockState) -> Bool {
    if state.isManuallyLocked {
        return true
    } else if let autolockTimeout = passcodeSettings.autolockTimeout {
        var bootTimestamp: Int32 = 0
        let uptime = getDeviceUptimeSeconds(&bootTimestamp)
        let timestamp = MonotonicTimestamp(bootTimestamp: bootTimestamp, uptime: uptime)
        
        let applicationActivityTimestamp = state.applicationActivityTimestamp
        
        if let applicationActivityTimestamp = applicationActivityTimestamp {
            if timestamp.bootTimestamp != applicationActivityTimestamp.bootTimestamp {
                return true
            }
            if timestamp.uptime >= applicationActivityTimestamp.uptime + autolockTimeout {
                return true
            }
        } else {
            return true
        }
    }
    return false
}

private func isSecretPasscodeTimedout(timeout: Int32, state: LockState) -> Bool {
    if let applicationActivityTimestamp = state.applicationActivityTimestamp {
        var bootTimestamp: Int32 = 0
        let uptime = getDeviceUptimeSeconds(&bootTimestamp)
        
        if bootTimestamp != applicationActivityTimestamp.bootTimestamp {
            return true
        }
        if uptime >= applicationActivityTimestamp.uptime + timeout {
            return true
        }
        
        return false
    } else {
        return true
    }
}

public final class AppLockContextImpl: AppLockContext {
    private let rootPath: String
    private let syncQueue = Queue()
    
    private let applicationBindings: TelegramApplicationBindings
    private let accountManager: AccountManager<TelegramAccountManagerTypes>
    private let presentationDataSignal: Signal<PresentationData, NoError>
    private let window: Window1?
    private let rootController: UIViewController?
    
    private var coveringView: LockedWindowCoveringView?
    private var passcodeController: PasscodeEntryController?
    
    private var timestampRenewTimer: SwiftSignalKit.Timer?
    private var secretPasscodesTimeoutCheckTimer: SwiftSignalKit.Timer?
    
    private var currentStateValue: LockState
    private let currentState = Promise<LockState>()
    
    private let autolockTimeout = ValuePromise<Int32?>(nil, ignoreRepeated: true)
    private let autolockReportTimeout = ValuePromise<Int32?>(nil, ignoreRepeated: true)
    
    private let isCurrentlyLockedPromise = Promise<Bool>()
    public var isCurrentlyLocked: Signal<Bool, NoError> {
        return self.isCurrentlyLockedPromise.get()
        |> distinctUntilChanged
    }
    
    private var lastActiveTimestamp: Double?
    private var lastActiveValue: Bool = false
    
    public weak var sharedAccountContext: SharedAccountContext?
    
    private var savedNativeViewController: UIViewController?
    
    public init(rootPath: String, window: Window1?, rootController: UIViewController?, applicationBindings: TelegramApplicationBindings, accountManager: AccountManager<TelegramAccountManagerTypes>, presentationDataSignal: Signal<PresentationData, NoError>, lockIconInitialFrame: @escaping () -> CGRect?) {
        assert(Queue.mainQueue().isCurrent())
        
        self.applicationBindings = applicationBindings
        self.accountManager = accountManager
        self.presentationDataSignal = presentationDataSignal
        self.rootPath = rootPath
        self.window = window
        self.rootController = rootController
        
        if let data = try? Data(contentsOf: URL(fileURLWithPath: appLockStatePath(rootPath: self.rootPath))), let current = try? JSONDecoder().decode(LockState.self, from: data) {
            self.currentStateValue = current
        } else {
            self.currentStateValue = LockState()
        }
        self.autolockTimeout.set(self.currentStateValue.autolockTimeout)
        
        var lastIsActive = false
        var lastInForeground = false
        
        let _ = (combineLatest(queue: .mainQueue(),
            accountManager.accessChallengeData(),
            accountManager.sharedData(keys: Set([ApplicationSpecificSharedDataKeys.presentationPasscodeSettings])),
            presentationDataSignal,
            applicationBindings.applicationIsActive,
            applicationBindings.applicationInForeground,
            self.currentState.get()
        )
        |> deliverOnMainQueue).start(next: { [weak self] accessChallengeData, sharedData, presentationData, appInForeground, appInForegroundReal, state in
            guard let strongSelf = self else {
                return
            }
            
            let passcodeSettings: PresentationPasscodeSettings = sharedData.entries[ApplicationSpecificSharedDataKeys.presentationPasscodeSettings]?.get(PresentationPasscodeSettings.self) ?? .defaultSettings
            
            if strongSelf.applicationBindings.isMainApp {
                defer {
                    lastIsActive = appInForeground
                    lastInForeground = appInForegroundReal
                }
                
                if (!lastIsActive && appInForeground) || (!lastInForeground && appInForegroundReal) {
                    let _ = strongSelf.secretPasscodesTimeoutCheck(state: strongSelf.currentStateValue).start()
                }
                
                if !lastInForeground && appInForegroundReal {
                    // timeout = 10 has special meaning: it fires immediately if app goes to background.
                    // Actually firing when app comes FROM background so that user using Share extension has a chance to complete sharing in this case.
                    
                    let _ = strongSelf.secretPasscodesDeactivateOnCondition({ $0.timeout == 10 }).start()
                    
                    if accessChallengeData.data.isLockable && passcodeSettings.autolockTimeout == 10 && !state.isManuallyLocked {
                        strongSelf.updateLockState { state in
                            var state = state
                            state.isManuallyLocked = true
                            return state
                        }
                        return
                    }
                }
            }
            
            let timestamp = CFAbsoluteTimeGetCurrent()
            var becameActiveRecently = false
            if appInForeground {
                if !strongSelf.lastActiveValue {
                    strongSelf.lastActiveValue = true
                    strongSelf.lastActiveTimestamp = timestamp
                    
                    if let data = try? Data(contentsOf: URL(fileURLWithPath: appLockStatePath(rootPath: strongSelf.rootPath))), let current = try? JSONDecoder().decode(LockState.self, from: data) {
                        strongSelf.currentStateValue = current
                    }
                }
                
                if let lastActiveTimestamp = strongSelf.lastActiveTimestamp {
                    if lastActiveTimestamp + 0.5 > timestamp {
                        becameActiveRecently = true
                    }
                }
            } else {
                strongSelf.lastActiveValue = false
            }
            
            let shouldDisplayCoveringView = !appInForeground
            var isCurrentlyLocked = false
            var passcodeControllerToDismissAfterSavedNativeControllerPresented: ViewController?
            
            if !accessChallengeData.data.isLockable {
                if let passcodeController = strongSelf.passcodeController {
                    strongSelf.passcodeController = nil
                    passcodeController.dismiss()
                }
                
                strongSelf.autolockTimeout.set(nil)
                strongSelf.autolockReportTimeout.set(nil)
            } else {
                if !appInForeground {
                    if let autolockTimeout = passcodeSettings.autolockTimeout {
                        strongSelf.autolockReportTimeout.set(autolockTimeout)
                    } else if state.isManuallyLocked {
                        strongSelf.autolockReportTimeout.set(1)
                    } else {
                        strongSelf.autolockReportTimeout.set(nil)
                    }
                } else {
                    strongSelf.autolockReportTimeout.set(nil)
                }
                
                strongSelf.autolockTimeout.set(passcodeSettings.autolockTimeout)
                
                if isLocked(passcodeSettings: passcodeSettings, state: state) {
                    isCurrentlyLocked = true
                    
                    let biometrics: PasscodeEntryControllerBiometricsMode
                    if passcodeSettings.enableBiometrics {
                        biometrics = .enabled(passcodeSettings.biometricsDomainState)
                    } else {
                        biometrics = .none
                    }
                    
                    if let passcodeController = strongSelf.passcodeController {
                        if becameActiveRecently, case .enabled = biometrics, appInForeground {
                            passcodeController.requestBiometrics()
                        }
                        passcodeController.ensureInputFocused()
                    } else if let window = strongSelf.window {
                        let passcodeController = PasscodeEntryController(applicationBindings: strongSelf.applicationBindings, accountManager: strongSelf.accountManager, appLockContext: strongSelf, presentationData: presentationData, presentationDataSignal: strongSelf.presentationDataSignal, statusBarHost: window.statusBarHost, challengeData: accessChallengeData.data, biometrics: biometrics, arguments: PasscodeEntryControllerPresentationArguments(animated: strongSelf.rootController?.presentedViewController == nil, lockIconInitialFrame: {
                            if let lockViewFrame = lockIconInitialFrame() {
                                return lockViewFrame
                            } else {
                                return CGRect()
                            }
                        }), sharedAccountContext: strongSelf.sharedAccountContext)
                        if becameActiveRecently, appInForeground {
                            passcodeController.presentationCompleted = { [weak passcodeController] in
                                if case .enabled = biometrics {
                                    passcodeController?.requestBiometrics()
                                }
                                passcodeController?.ensureInputFocused()
                            }
                        }
                        passcodeController.presentedOverCoveringView = true
                        passcodeController.isOpaqueWhenInOverlay = true
                        strongSelf.passcodeController = passcodeController
                        var viewControllerToDismiss: UIViewController?
                        if let rootViewController = strongSelf.rootController {
                            if let _ = rootViewController.presentedViewController as? UIActivityViewController {
                            } else if let _ = rootViewController.presentedViewController as? PKPaymentAuthorizationViewController {
                            } else {
                                if let controller = rootViewController.presentedViewController {
                                    strongSelf.savedNativeViewController = controller
                                }
                                viewControllerToDismiss = rootViewController
                            }
                        }
                        UIView.performWithoutAnimation {
                            strongSelf.rootController?.view.endEditing(true)
                        }
                        if let controller = strongSelf.savedNativeViewController, window.keyboardHeight > 0.0 {
                            _hideSafariKeyboard(controller)
                        }
                        window.present(passcodeController, on: .passcode, completion: {
                            viewControllerToDismiss?.dismiss(animated: false, completion: nil)
                        })
                    }
                } else if let passcodeController = strongSelf.passcodeController {
                    strongSelf.passcodeController = nil
                    if strongSelf.savedNativeViewController != nil {
                        passcodeControllerToDismissAfterSavedNativeControllerPresented = passcodeController
                    } else {
                        passcodeController.dismiss()
                    }
                }
            }
            
            strongSelf.updateTimestampRenewTimer(shouldRun: appInForeground && !isCurrentlyLocked)
            strongSelf.isCurrentlyLockedPromise.set(.single(!appInForeground || isCurrentlyLocked))
            
            if shouldDisplayCoveringView {
                if strongSelf.coveringView == nil, let window = strongSelf.window {
                    if strongSelf.passcodeController == nil {
                        UIView.performWithoutAnimation {
                            strongSelf.rootController?.view.endEditing(true)
                        }
                        if let controller = strongSelf.rootController?.presentedViewController, window.keyboardHeight > 0.0 {
                            _hideSafariKeyboard(controller)
                        }
                    }
                    
                    let coveringView = LockedWindowCoveringView(theme: presentationData.theme, wallpaper: presentationData.chatWallpaper, accountManager: strongSelf.accountManager)
                    if let controller = strongSelf.rootController?.presentedViewController ?? strongSelf.savedNativeViewController {
                        coveringView.layer.allowsGroupOpacity = false
                        controller.view.addSubview(coveringView)
                        coveringView.frame = controller.view.bounds
                        coveringView.updateLayout(controller.view.bounds.size)
                        coveringView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                    } else {
                        window.coveringView = coveringView
                    }
                    strongSelf.coveringView = coveringView
                }
                
                if strongSelf.passcodeController == nil, let controller = strongSelf.savedNativeViewController {
                    strongSelf.rootController?.present(controller, animated: false, completion: {
                        passcodeControllerToDismissAfterSavedNativeControllerPresented?.dismiss(animated: false)
                    })
                    strongSelf.savedNativeViewController = nil
                }
            } else if strongSelf.passcodeController == nil {
                if strongSelf.coveringView != nil {
                    strongSelf.window?.hostView.containerView.windowHost?.forEachController { controller in
                        if let controller = controller as? PasscodeSetupController {
                            controller.activateInput()
                        }
                    }
                }
                
                let removeFromSuperviewAnimated: (UIView) -> Void = { coveringView in
                    coveringView.layer.allowsGroupOpacity = true
                    coveringView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak coveringView] _ in
                        coveringView?.removeFromSuperview()
                    })
                }
                
                if let controller = strongSelf.savedNativeViewController {
                    strongSelf.rootController?.present(controller, animated: false, completion: { [weak self] in
                        if let strongSelf = self, let coveringView = strongSelf.coveringView {
                            strongSelf.coveringView = nil
                            removeFromSuperviewAnimated(coveringView)
                        }
                        passcodeControllerToDismissAfterSavedNativeControllerPresented?.dismiss(animated: false)
                    })
                    strongSelf.savedNativeViewController = nil
                } else if let coveringView = strongSelf.coveringView {
                    strongSelf.coveringView = nil
                    if let _ = strongSelf.rootController?.presentedViewController {
                        removeFromSuperviewAnimated(coveringView)
                    } else {
                        strongSelf.window?.coveringView = nil
                    }
                }
            }
        })
        
        self.currentState.set(.single(self.currentStateValue))
        
        if applicationBindings.isMainApp {
            let _ = (self.autolockTimeout.get()
            |> deliverOnMainQueue).start(next: { [weak self] autolockTimeout in
                self?.updateLockState { state in
                    var state = state
                    state.autolockTimeout = autolockTimeout
                    return state
                }
            })
            
            let _ = self.secretPasscodesTimeoutCheck(state: self.currentStateValue).start()
        }
    }
    
    private func updateTimestampRenewTimer(shouldRun: Bool) {
        if shouldRun {
            if self.timestampRenewTimer == nil {
                self.updateApplicationActivityTimestamp()
                let timestampRenewTimer = SwiftSignalKit.Timer(timeout: 5.0, repeat: true, completion: { [weak self] in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.updateApplicationActivityTimestamp()
                }, queue: .mainQueue())
                self.timestampRenewTimer = timestampRenewTimer
                timestampRenewTimer.start()
            }
            
            if let secretPasscodesTimeoutCheckTimer = self.secretPasscodesTimeoutCheckTimer {
                self.secretPasscodesTimeoutCheckTimer = nil
                secretPasscodesTimeoutCheckTimer.invalidate()
            }
        } else {
            if let timestampRenewTimer = self.timestampRenewTimer {
                self.timestampRenewTimer = nil
                timestampRenewTimer.invalidate()
                self.updateApplicationActivityTimestamp()
            }
            
            if self.secretPasscodesTimeoutCheckTimer == nil && self.applicationBindings.isMainApp {
                let secretPasscodesTimeoutCheckTimer = SwiftSignalKit.Timer(timeout: 5.0, repeat: true, completion: { [weak self] in
                    guard let strongSelf = self else {
                        return
                    }
                    let _ = strongSelf.secretPasscodesTimeoutCheck(state: strongSelf.currentStateValue).start()
                }, queue: .mainQueue())
                self.secretPasscodesTimeoutCheckTimer = secretPasscodesTimeoutCheckTimer
                secretPasscodesTimeoutCheckTimer.start()
            }
        }
    }
    
    private func updateApplicationActivityTimestamp() {
        self.updateLockState { state in
            var bootTimestamp: Int32 = 0
            let uptime = getDeviceUptimeSeconds(&bootTimestamp)
            
            var state = state
            state.applicationActivityTimestamp = MonotonicTimestamp(bootTimestamp: bootTimestamp, uptime: uptime)
            return state
        }
    }
    
    private func updateLockState(_ f: @escaping (LockState) -> LockState) {
        assert(self.applicationBindings.isMainApp)
        Queue.mainQueue().async {
            let updatedState = f(self.currentStateValue)
            if updatedState != self.currentStateValue {
                self.currentStateValue = updatedState
                self.currentState.set(.single(updatedState))
                
                let path = appLockStatePath(rootPath: self.rootPath)
                
                self.syncQueue.async {
                    if let data = try? JSONEncoder().encode(updatedState) {
                        let _ = try? data.write(to: URL(fileURLWithPath: path), options: .atomic)
                    }
                }
            }
        }
    }
    
    public var invalidAttempts: Signal<AccessChallengeAttempts?, NoError> {
        return self.currentState.get()
        |> map { state in
            return state.unlockAttempts.flatMap { unlockAttempts in
                return AccessChallengeAttempts(count: unlockAttempts.count, bootTimestamp: unlockAttempts.timestamp.bootTimestamp, uptime: unlockAttempts.timestamp.uptime)
            }
        }
    }
    
    public var autolockDeadline: Signal<Int32?, NoError> {
        return self.autolockReportTimeout.get()
        |> distinctUntilChanged
        |> map { value -> Int32? in
            if let value = value {
                return Int32(Date().timeIntervalSince1970) + value
            } else {
                return nil
            }
        }
    }
    
    public func lock() {
        self.updateLockState { state in
            var state = state
            state.isManuallyLocked = true
            return state
        }
        
        // deactivating all secret passcodes on manual app lock
        let _ = self.secretPasscodesDeactivateOnCondition({ _ in return true }).start()
    }
    
    public func unlock() {
        assert(Queue.mainQueue().isCurrent())
        let _ = self.secretPasscodesTimeoutCheck(state: self.currentStateValue).start()
        
        self.updateLockState { state in
            var state = state
            
            state.unlockAttempts = nil
            
            state.isManuallyLocked = false
            
            var bootTimestamp: Int32 = 0
            let uptime = getDeviceUptimeSeconds(&bootTimestamp)
            let timestamp = MonotonicTimestamp(bootTimestamp: bootTimestamp, uptime: uptime)
            state.applicationActivityTimestamp = timestamp
            
            return state
        }
    }
    
    public func failedUnlockAttempt() {
        self.updateLockState { state in
            var state = state
            var unlockAttempts = state.unlockAttempts ?? UnlockAttempts(count: 0, timestamp: MonotonicTimestamp(bootTimestamp: 0, uptime: 0))
            
            unlockAttempts.count += 1
            
            var bootTimestamp: Int32 = 0
            let uptime = getDeviceUptimeSeconds(&bootTimestamp)
            let timestamp = MonotonicTimestamp(bootTimestamp: bootTimestamp, uptime: uptime)
            
            unlockAttempts.timestamp = timestamp
            state.unlockAttempts = unlockAttempts
            return state
        }
    }
    
    private func secretPasscodesDeactivateOnCondition(_ f: @escaping (PtgSecretPasscode) -> Bool) -> Signal<Void, NoError> {
        return self.accountManager.transaction { transaction in
            return PtgSecretPasscodes(transaction)
        }
        |> mapToSignal { [weak self] ptgSecretPasscodes -> Signal<Void, NoError> in
            guard let strongSelf = self else {
                return .never()
            }
            
            if ptgSecretPasscodes.secretPasscodes.contains(where: { $0.active && f($0) }) {
                return updatePtgSecretPasscodes(strongSelf.accountManager, { current in
                    return PtgSecretPasscodes(secretPasscodes: current.secretPasscodes.map { sp in
                        return sp.withUpdated(active: sp.active && !f(sp))
                    })
                })
            } else {
                return .complete()
            }
        }
    }
    
    // passing state (and not getting through self.currentState.get()) so we have value before it could be changed for instance by following updateApplicationActivityTimestamp() calls
    private func secretPasscodesTimeoutCheck(state: LockState) -> Signal<Void, NoError> {
        return self.secretPasscodesDeactivateOnCondition { sp in
            return sp.timeout != nil && isSecretPasscodeTimedout(timeout: sp.timeout!, state: state)
        }
    }
}

private func _hideSafariKeyboard(_ controller: UIViewController) {
    // hide keyboard inside SFSafariViewController
    UIView.performWithoutAnimation {
        let textview = UITextView(frame: CGRect())
        controller.view.addSubview(textview)
        textview.becomeFirstResponder()
        textview.resignFirstResponder()
        textview.removeFromSuperview()
    }
}
