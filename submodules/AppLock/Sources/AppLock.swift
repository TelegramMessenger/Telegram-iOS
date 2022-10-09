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
import ImageBlur
import FastBlur
import AppLockState
import PassKit
import FakePasscode

private func isLocked(passcodeSettings: PresentationPasscodeSettings, state: LockState, isApplicationActive: Bool) -> Bool {
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

private func getCoveringViewSnaphot(window: Window1) -> UIImage? {
    let scale: CGFloat = 0.5
    let unscaledSize = window.hostView.containerView.frame.size
    return generateImage(CGSize(width: floor(unscaledSize.width * scale), height: floor(unscaledSize.height * scale)), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.scaleBy(x: scale, y: scale)
        UIGraphicsPushContext(context)

        window.badgeView.alpha = 0.0
        window.forEachViewController({ controller in
            if let controller = controller as? PasscodeEntryController {
                controller.displayNode.alpha = 0.0
            }
            return true
        })
        window.hostView.containerView.drawHierarchy(in: CGRect(origin: CGPoint(), size: unscaledSize), afterScreenUpdates: true)
        window.forEachViewController({ controller in
            if let controller = controller as? PasscodeEntryController {
                controller.displayNode.alpha = 1.0
            }
            return true
        })
        window.badgeView.alpha = 1.0
        
        UIGraphicsPopContext()
    }).flatMap(applyScreenshotEffectToImage)
}

public final class AppLockContextImpl: AppLockContext {
    private let rootPath: String
    private let syncQueue = Queue()
    
    private let applicationBindings: TelegramApplicationBindings
    private let accountManager: AccountManager<TelegramAccountManagerTypes>
    private let presentationDataSignal: Signal<PresentationData, NoError>
    private let window: Window1?
    private let rootController: UIViewController?
    
    private var coveringView: UIView?
    private var passcodeController: PasscodeEntryController?
    
    private var timestampRenewTimer: SwiftSignalKit.Timer?
    
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
        
        let _ = (combineLatest(queue: .mainQueue(),
            accountManager.accessChallengeData(),
            accountManager.sharedData(keys: Set([ApplicationSpecificSharedDataKeys.presentationPasscodeSettings, ApplicationSpecificSharedDataKeys.fakePasscodeSettings])),
            presentationDataSignal,
            applicationBindings.applicationIsActive,
            self.currentState.get()
        )
        |> deliverOnMainQueue).start(next: { [weak self] accessChallengeData, sharedData, presentationData, appInForeground, state in
            guard let strongSelf = self else {
                return
            }
            
            var passcodeSettings: PresentationPasscodeSettings = sharedData.entries[ApplicationSpecificSharedDataKeys.presentationPasscodeSettings]?.get(PresentationPasscodeSettings.self) ?? .defaultSettings
            
            let fakePasscodeHolder = FakePasscodeSettingsHolder(sharedData.entries[ApplicationSpecificSharedDataKeys.fakePasscodeSettings])
            
            var correctedAutolockTimeout = fakePasscodeHolder.correctAutolockTimeout(passcodeSettings.autolockTimeout)
            if correctedAutolockTimeout == 1 && appInForeground && strongSelf.passcodeController == nil {
                // prevent auto-lock when app in foreground because of 5-second precision in timeout calculation
                correctedAutolockTimeout = 6
            }
            if correctedAutolockTimeout != passcodeSettings.autolockTimeout {
                passcodeSettings = passcodeSettings.withUpdatedAutolockTimeout(correctedAutolockTimeout)
            }
            
            let timestamp = CFAbsoluteTimeGetCurrent()
            var becameActiveRecently = false
            if appInForeground {
                if !strongSelf.lastActiveValue {
                    strongSelf.lastActiveValue = true
                    strongSelf.lastActiveTimestamp = timestamp
                }
                
                if let lastActiveTimestamp = strongSelf.lastActiveTimestamp {
                    if lastActiveTimestamp + 0.5 > timestamp {
                        becameActiveRecently = true
                    }
                }
            } else {
                strongSelf.lastActiveValue = false
            }
            
            var shouldDisplayCoveringView = false
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
                if let _ = passcodeSettings.autolockTimeout, !appInForeground {
                    shouldDisplayCoveringView = true
                }
                
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
                
                if isLocked(passcodeSettings: passcodeSettings, state: state, isApplicationActive: appInForeground) {
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
                    } else {
                        let passcodeController = PasscodeEntryController(applicationBindings: strongSelf.applicationBindings, accountManager: strongSelf.accountManager, appLockContext: strongSelf, presentationData: presentationData, presentationDataSignal: strongSelf.presentationDataSignal, statusBarHost: window?.statusBarHost, challengeData: accessChallengeData.data, biometrics: biometrics, arguments: PasscodeEntryControllerPresentationArguments(animated: strongSelf.rootController?.presentedViewController == nil, lockIconInitialFrame: {
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
                        if let rootViewController = strongSelf.rootController {
                            if let _ = rootViewController.presentedViewController as? UIActivityViewController {
                            } else if let _ = rootViewController.presentedViewController as? PKPaymentAuthorizationViewController {
                            } else {
                                if let controller = rootViewController.presentedViewController {
                                    strongSelf.savedNativeViewController = controller
                                }
                                rootViewController.dismiss(animated: false, completion: nil)
                            }
                        }
                        strongSelf.window?.present(passcodeController, on: .passcode)
                    }
                } else if let passcodeController = strongSelf.passcodeController {
                    strongSelf.passcodeController = nil
                    shouldDisplayCoveringView = false
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
                if strongSelf.coveringView == nil, let window = strongSelf.window, strongSelf.passcodeController == nil {
                    if let controller = strongSelf.rootController?.presentedViewController {
                        let blurStyle: UIBlurEffect.Style
                        if #available(iOS 13.0, *) {
                            blurStyle = .systemUltraThinMaterial
                        } else if #available(iOS 10.0, *) {
                            blurStyle = .regular
                        } else {
                            blurStyle = .dark
                        }
                        let blurView = UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
                        blurView.frame = controller.view.bounds
                        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                        controller.view.addSubview(blurView)
                        strongSelf.coveringView = blurView
                    } else {
                        let coveringView = LockedWindowCoveringView(theme: presentationData.theme)
                        coveringView.updateSnapshot(getCoveringViewSnaphot(window: window))
                        strongSelf.coveringView = coveringView
                        window.coveringView = coveringView
                    }
                }
            } else if strongSelf.passcodeController == nil {
                if let controller = strongSelf.savedNativeViewController {
                    if let coveringView = strongSelf.coveringView {
                        strongSelf.coveringView = nil
                        coveringView.removeFromSuperview()
                    }
                    strongSelf.rootController?.present(controller, animated: false, completion: {
                        passcodeControllerToDismissAfterSavedNativeControllerPresented?.dismiss(animated: false)
                    })
                    strongSelf.savedNativeViewController = nil
                } else if let coveringView = strongSelf.coveringView {
                    strongSelf.coveringView = nil
                    if let _ = strongSelf.rootController?.presentedViewController {
                        coveringView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak coveringView] _ in
                            coveringView?.removeFromSuperview()
                        })
                    } else {
                        strongSelf.window?.coveringView = nil
                    }
                }
            }
        })
        
        self.currentState.set(.single(self.currentStateValue))
        
        let _ = (self.autolockTimeout.get()
        |> deliverOnMainQueue).start(next: { [weak self] autolockTimeout in
            self?.updateLockState { state in
                var state = state
                state.autolockTimeout = autolockTimeout
                return state
            }
        })
    }
    
    private func updateTimestampRenewTimer(shouldRun: Bool) {
        if shouldRun {
            if self.timestampRenewTimer == nil {
                let timestampRenewTimer = SwiftSignalKit.Timer(timeout: 5.0, repeat: true, completion: { [weak self] in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.updateApplicationActivityTimestamp()
                }, queue: .mainQueue())
                self.timestampRenewTimer = timestampRenewTimer
                timestampRenewTimer.start()
            }
        } else {
            if let timestampRenewTimer = self.timestampRenewTimer {
                self.timestampRenewTimer = nil
                timestampRenewTimer.invalidate()
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
            return state.unlockAttemts.flatMap { unlockAttemts in
                return AccessChallengeAttempts(count: unlockAttemts.count, bootTimestamp: unlockAttemts.timestamp.bootTimestamp, uptime: unlockAttemts.timestamp.uptime)
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
    }
    
    public func unlock() {
        self.updateLockState { state in
            var state = state
            
            state.unlockAttemts = nil
            
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
            var unlockAttemts = state.unlockAttemts ?? UnlockAttempts(count: 0, timestamp: MonotonicTimestamp(bootTimestamp: 0, uptime: 0))
            
            unlockAttemts.count += 1
            
            var bootTimestamp: Int32 = 0
            let uptime = getDeviceUptimeSeconds(&bootTimestamp)
            let timestamp = MonotonicTimestamp(bootTimestamp: bootTimestamp, uptime: uptime)
            
            unlockAttemts.timestamp = timestamp
            state.unlockAttemts = unlockAttemts
            return state
        }
    }
}
