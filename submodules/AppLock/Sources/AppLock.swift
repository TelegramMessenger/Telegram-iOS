import PtgSecretPasscodes
import QuickLook

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
    if state.isLocked {
        return true
    } else if let autolockTimeout = passcodeSettings.autolockTimeout {
        let timestamp = MonotonicTimestamp()
        
        let applicationActivityTimestamp = state.applicationActivityTimestamp
        
        if let applicationActivityTimestamp = applicationActivityTimestamp {
            if timestamp.bootTimestamp.absDiff(with: applicationActivityTimestamp.bootTimestamp) > 0.1 {
                return true
            }
            if timestamp.uptime < applicationActivityTimestamp.uptime {
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
    
    private var lastActiveValue: Bool = false
    
    public weak var sharedAccountContext: SharedAccountContext?
    
    private var savedNativeViewController: UIViewController?
    private let syncingWait = ValuePromise<Bool>(false, ignoreRepeated: true)
    
    public private(set) var animationsTemporarilyDisabledForCoverUp: Bool = false
    private var temporarilyDisableAnimationsTimer: SwiftSignalKit.Timer?
    
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
            self.currentState.get(),
            self.syncingWait.get()
        )
        |> filter { _, _, _, _, _, _, syncingWait in
            return !syncingWait
        }
        |> deliverOnMainQueue).start(next: { [weak self] accessChallengeData, sharedData, presentationData, appInForeground, appInForegroundReal, state, _ in
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
                    let becameActive = !lastIsActive && appInForeground
                    let becameForeground = !lastInForeground && appInForegroundReal
                    
                    strongSelf.temporarilyDisableAnimations()
                    
                    if becameActive {
                        strongSelf.syncingWait.set(true)
                    }
                    let state = strongSelf.currentStateValue
                    let _ = strongSelf.secretPasscodesDeactivateOnCondition({ sp in
                        if becameForeground && sp.timeout == 10 {
                            return true
                        }
                        return sp.timeout != nil && isSecretPasscodeTimedout(timeout: sp.timeout!, state: state)
                    }).start(completed: {
                        if becameActive {
                            Queue.mainQueue().justDispatch {
                                strongSelf.syncingWait.set(false)
                            }
                        }
                    })
                    
                    if becameForeground {
                        // timeout = 10 has special meaning: it fires immediately if app goes to background.
                        // Actually firing when app comes FROM background so that user using Share extension has a chance to complete sharing in this case.
                        
                        if accessChallengeData.data.isLockable && passcodeSettings.autolockTimeout == 10 && !state.isLocked {
                            strongSelf.updateLockState { state in
                                var state = state
                                state.isLocked = true
                                return state
                            }
                            return
                        }
                    }
                    
                    if becameActive {
                        return
                    }
                }
            }
            
            var becameActiveRecently = false
            if appInForeground {
                if !strongSelf.lastActiveValue {
                    strongSelf.lastActiveValue = true
                    becameActiveRecently = true
                }
            } else if !appInForegroundReal {
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
                    } else if state.isLocked {
                        strongSelf.autolockReportTimeout.set(1)
                    } else {
                        strongSelf.autolockReportTimeout.set(nil)
                    }
                } else {
                    strongSelf.autolockReportTimeout.set(nil)
                }
                
                strongSelf.autolockTimeout.set(passcodeSettings.autolockTimeout)
                
                if isLocked(passcodeSettings: passcodeSettings, state: state) {
                    if !state.isLocked {
                        // save locked state to prevent bypassing lock by tampering with device time
                        Queue.mainQueue().justDispatch {
                            self?.updateLockState { state in
                                var state = state
                                state.isLocked = true
                                return state
                            }
                        }
                    }
                    
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
                        var nonFullscreenVCToDismiss: UIViewController?
                        if let rootViewController = strongSelf.rootController {
                            if let _ = rootViewController.presentedViewController as? PKPaymentAuthorizationViewController {
                            } else {
                                var vc = rootViewController
                                while let presentedVC = vc.presentedViewController, !presentedVC.isBeingDismissed {
                                    if presentedVC.view.bounds != window.hostView.eventView.bounds {
                                        // can't reliably cover saved non-fullscreen views, just dismiss them
                                        nonFullscreenVCToDismiss = presentedVC
                                        break
                                    }
                                    vc = presentedVC
                                }
                                
                                if let controller = rootViewController.presentedViewController, !controller.isBeingDismissed, controller !== nonFullscreenVCToDismiss {
                                    strongSelf.savedNativeViewController = controller
                                }
                            }
                        }
                        UIView.performWithoutAnimation {
                            strongSelf.rootController?.view.endEditing(true)
                        }
                        if let controller = strongSelf.savedNativeViewController, window.keyboardHeight > 0.0 {
                            _hideSafariKeyboard(controller)
                        }
                        
                        var pendingTasks = (strongSelf.savedNativeViewController != nil || nonFullscreenVCToDismiss != nil) ? 2 : 1
                        
                        let completed = {
                            pendingTasks -= 1
                            if pendingTasks == 0 {
                                if strongSelf.coveringView !== window.coveringView {
                                    strongSelf.coveringView?.removeFromSuperview()
                                }
                                Queue.mainQueue().justDispatch {
                                    strongSelf.syncingWait.set(false)
                                }
                            }
                        }
                        
                        // if CompactDocumentPreviewController quickly presented after being dismissed, the app crashes (reproduced on iOS 16.3 when using Face ID); reloadData() seems to fix it.
                        var documentPreviewWorkaround: (() -> Void)?
                        if let controller = strongSelf.savedNativeViewController as? QLPreviewController {
                            documentPreviewWorkaround = { [weak controller] in
                                controller?.reloadData()
                            }
                        }
                        
                        strongSelf.syncingWait.set(true)
                        
                        if let nonFullscreenVCToDismiss {
                            nonFullscreenVCToDismiss.dismiss(animated: false, completion: {
                                if let _ = strongSelf.savedNativeViewController {
                                    strongSelf.rootController!.dismiss(animated: false, completion: {
                                        documentPreviewWorkaround?()
                                        completed()
                                    })
                                } else {
                                    completed()
                                }
                            })
                        } else if let _ = strongSelf.savedNativeViewController {
                            strongSelf.rootController!.dismiss(animated: false, completion: {
                                documentPreviewWorkaround?()
                                completed()
                            })
                        }
                        
                        window.present(passcodeController, on: .passcode, completion: completed)
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
            
            func topPresentedVC(_ startFromVC: UIViewController) -> UIViewController {
                var topViewController = startFromVC
                while let presentedVC = topViewController.presentedViewController, !presentedVC.isBeingDismissed {
                    topViewController = presentedVC
                }
                return topViewController
            }
            
            if shouldDisplayCoveringView {
                if strongSelf.coveringView == nil, let window = strongSelf.window {
                    if strongSelf.passcodeController == nil {
                        UIView.performWithoutAnimation {
                            strongSelf.rootController?.view.endEditing(true)
                        }
                        if let controller = strongSelf.rootController?.presentedViewController, !controller.isBeingDismissed, window.keyboardHeight > 0.0 {
                            _hideSafariKeyboard(controller)
                        }
                    }
                    
                    let coveringView = LockedWindowCoveringView(theme: presentationData.theme, wallpaper: presentationData.chatWallpaper, accountManager: strongSelf.accountManager)
                    
                    if let controller = strongSelf.savedNativeViewController ?? strongSelf.rootController?.presentedViewController, !controller.isBeingDismissed {
                        coveringView.layer.allowsGroupOpacity = false
                        coveringView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                        window.hostView.eventView.addSubview(coveringView)
                        coveringView.frame = window.hostView.eventView.bounds
                        coveringView.updateLayout(coveringView.frame.size)
                        
                        // if screen manually turned off while safari/pdf is open, cover view is not visible first moment when screen turned back on; flush() seems to fix it.
                        CATransaction.flush()
                    } else {
                        window.coveringView = coveringView
                    }
                    
                    strongSelf.coveringView = coveringView
                }
                
                if strongSelf.passcodeController == nil, let controller = strongSelf.savedNativeViewController {
                    let coveringView = strongSelf.coveringView
                    
                    // need tempDupCoveringView bc saved controller presented over existing coveringView
                    let tempDupCoveringView = coveringView?.duplicate()
                    if let tempDupCoveringView {
                        topPresentedVC(controller).view.addSubview(tempDupCoveringView)
                    }
                    
                    strongSelf.rootController?.present(controller, animated: false, completion: {
                        if let coveringView {
                            self?.window?.hostView.eventView.addSubview(coveringView)
                            tempDupCoveringView?.removeFromSuperview()
                        }
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
                    let coveringView = strongSelf.coveringView
                    strongSelf.coveringView = nil
                    
                    let tempDupCoveringView = coveringView?.duplicate()
                    if let tempDupCoveringView {
                        topPresentedVC(controller).view.addSubview(tempDupCoveringView)
                    }
                    
                    strongSelf.rootController?.present(controller, animated: false, completion: {
                        if let coveringView {
                            self?.window?.hostView.eventView.addSubview(coveringView)
                            tempDupCoveringView?.removeFromSuperview()
                            removeFromSuperviewAnimated(coveringView)
                        }
                        passcodeControllerToDismissAfterSavedNativeControllerPresented?.dismiss(animated: false)
                    })
                    strongSelf.savedNativeViewController = nil
                } else if let coveringView = strongSelf.coveringView {
                    strongSelf.coveringView = nil
                    if let controller = strongSelf.rootController?.presentedViewController, !controller.isBeingDismissed {
                        removeFromSuperviewAnimated(coveringView)
                    } else {
                        strongSelf.window?.coveringView = nil
                    }
                }
            }
        })
        
        self.window?.secondaryCoveringViewLayoutSizeUpdate = { [weak self] layoutSize in
            if let strongSelf = self, let coveringView = strongSelf.coveringView, coveringView !== strongSelf.window?.coveringView {
                coveringView.frame = CGRect(origin: CGPoint(), size: layoutSize)
                coveringView.updateLayout(layoutSize)
            }
        }
        
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
            
            self.temporarilyDisableAnimations()
            
            let _ = self.secretPasscodesTimeoutCheck(state: self.currentStateValue).start()
        }
    }
    
    public func dismissPresentedViewController() {
        let _ = (self.syncingWait.get()
        |> filter { !$0 }
        |> take(1)
        |> deliverOnMainQueue).start(next: { _ in
            var presentedVC: UIViewController?
            
            if let _ = self.savedNativeViewController {
            } else if let controller = self.rootController?.presentedViewController, !controller.isBeingDismissed {
                presentedVC = controller
            }
            
            let oldCoveringView = self.coveringView
            
            if self.savedNativeViewController != nil || presentedVC != nil {
                if let window = self.window, self.coveringView != nil {
                    assert(window.coveringView == nil)
                    let coveringView = self.coveringView!.duplicate()
                    window.coveringView = coveringView
                    self.coveringView = coveringView
                }
            }
            
            if let _ = self.savedNativeViewController {
                self.savedNativeViewController = nil
                oldCoveringView?.removeFromSuperview()
            } else if let _ = presentedVC {
                // hide child view controllers, e.g. Share inside pdf viewer, otherwise its dismissal is visible
                var vc = self.rootController!.presentedViewController
                while let pvc = vc?.presentedViewController {
                    pvc.view.isHidden = true
                    vc = pvc
                }
                
                self.syncingWait.set(true)
                self.rootController!.dismiss(animated: false, completion: {
                    oldCoveringView?.removeFromSuperview()
                    Queue.mainQueue().justDispatch {
                        self.syncingWait.set(false)
                    }
                })
            }
        })
    }
    
    private func updateTimestampRenewTimer(shouldRun: Bool) {
        if shouldRun {
            if self.timestampRenewTimer == nil {
                Queue.mainQueue().justDispatch {
                    self.updateApplicationActivityTimestamp()
                }
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
                Queue.mainQueue().justDispatch {
                    self.updateApplicationActivityTimestamp()
                }
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
            var state = state
            state.applicationActivityTimestamp = MonotonicTimestamp()
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
            state.isLocked = true
            return state
        }
        
        // deactivating all secret passcodes on manual app lock
        let _ = self.secretPasscodesDeactivateOnCondition({ _ in return true }).start()
    }
    
    public func unlock() {
        assert(Queue.mainQueue().isCurrent())
        assert(self.applicationBindings.isMainApp)
        
        self.temporarilyDisableAnimations()
        
        let _ = self.secretPasscodesTimeoutCheck(state: self.currentStateValue).start(completed: {
            self.updateLockState { state in
                var state = state
                
                state.unlockAttempts = nil
                
                state.isLocked = false
                
                state.applicationActivityTimestamp = MonotonicTimestamp()
                
                return state
            }
        })
    }
    
    public func failedUnlockAttempt() {
        self.updateLockState { state in
            var state = state
            var unlockAttempts = state.unlockAttempts ?? UnlockAttempts(count: 0, timestamp: MonotonicTimestamp())
            
            unlockAttempts.count += 1
            
            unlockAttempts.timestamp = MonotonicTimestamp()
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
                return .complete()
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
    
    private func temporarilyDisableAnimations() {
        assert(Queue.mainQueue().isCurrent())
        assert(self.applicationBindings.isMainApp)
        
        self.temporarilyDisableAnimationsTimer?.invalidate()
        self.animationsTemporarilyDisabledForCoverUp = true
        self.temporarilyDisableAnimationsTimer = SwiftSignalKit.Timer(timeout: 1.0, repeat: false, completion: { [weak self] in
            self?.animationsTemporarilyDisabledForCoverUp = false
            self?.temporarilyDisableAnimationsTimer = nil
        }, queue: .mainQueue())
        self.temporarilyDisableAnimationsTimer?.start()
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
