import Foundation
import Darwin
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
import PasscodeCore

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
        window.hostView.containerView.drawHierarchy(in: CGRect(origin: CGPoint(), size: unscaledSize), afterScreenUpdates: false)
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

private struct AppLockBiometricAuthenticationState {
    private var isApplicationActive = false
    private var isApplicationInForeground = false
    private var pendingRequests = Set<UUID>()
    private(set) var suppressCoveringView = false

    mutating func update(isApplicationActive: Bool, isApplicationInForeground: Bool) {
        if !isApplicationInForeground {
            self.pendingRequests.removeAll()
            self.suppressCoveringView = false
        } else if isApplicationActive {
            self.suppressCoveringView = false
        } else if self.isApplicationActive && self.isApplicationInForeground {
            self.suppressCoveringView = !self.pendingRequests.isEmpty
            self.pendingRequests.removeAll()
        }
        self.isApplicationActive = isApplicationActive
        self.isApplicationInForeground = isApplicationInForeground
    }

    mutating func begin() -> UUID? {
        guard self.isApplicationActive && self.isApplicationInForeground else { return nil }
        let id = UUID()
        self.pendingRequests.insert(id)
        return id
    }

    mutating func end(_ id: UUID) {
        self.pendingRequests.remove(id)
    }
}

public final class AppLockContextImpl: AppLockContext {
    private let rootPath: String
    private let syncQueue = Queue()
    
    private var disposable: Disposable?
    private var autolockTimeoutDisposable: Disposable?
    
    private let applicationBindings: TelegramApplicationBindings
    private let accountManager: AccountManager<TelegramAccountManagerTypes>
    private let presentationDataSignal: Signal<PresentationData, NoError>
    private let window: Window1?
    private let rootController: UIViewController?
    
    private var coveringView: LockedWindowCoveringView?
    private var passcodeController: PasscodeEntryController?
    
    private var timestampRenewTimer: SwiftSignalKit.Timer?
    
    private var currentStateValue: LockState
    private let currentState = Promise<LockState>()
    
    private let autolockTimeout = ValuePromise<Int32?>(nil, ignoreRepeated: true)
    private let autolockReportTimeout = ValuePromise<Int32?>(nil, ignoreRepeated: true)
    
    private let lockStatus = AppLockStatus()
    public var isPasscodeLocked: Signal<Bool, NoError> {
        return self.lockStatus.isPasscodeLocked
    }

    public var isCurrentlyLocked: Signal<Bool, NoError> {
        return self.lockStatus.isCurrentlyLocked
    }
    
    private var lastActiveTimestamp: Double?
    private var lastActiveValue: Bool = false
    private var biometricAuthenticationState = AppLockBiometricAuthenticationState()
    private var suppressAutomaticBiometrics = false
    
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
        
        self.disposable = (combineLatest(queue: .mainQueue(),
            accountManager.accessChallengeData(),
            accountManager.sharedData(keys: Set([ApplicationSpecificSharedDataKeys.presentationPasscodeSettings])),
            presentationDataSignal,
            applicationBindings.applicationIsActive,
            applicationBindings.applicationInForeground,
            self.currentState.get()
        )
        |> deliverOnMainQueue).startStrict(next: { [weak self] accessChallengeData, sharedData, presentationData, isApplicationActive, isApplicationInForeground, state in
            guard let strongSelf = self else {
                return
            }

            strongSelf.biometricAuthenticationState.update(isApplicationActive: isApplicationActive, isApplicationInForeground: isApplicationInForeground)
            
            let passcodeSettings: PresentationPasscodeSettings = sharedData.entries[ApplicationSpecificSharedDataKeys.presentationPasscodeSettings]?.get(PresentationPasscodeSettings.self) ?? .defaultSettings

            if !isApplicationInForeground {
                strongSelf.suppressAutomaticBiometrics = false
            }
            
            let timestamp = CFAbsoluteTimeGetCurrent()
            var becameActiveRecently = false
            if isApplicationActive {
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

            var shouldDisplayCoveringView = false
            var isCurrentlyLocked = false
            
            if !accessChallengeData.data.isLockable {
                if let passcodeController = strongSelf.passcodeController {
                    strongSelf.passcodeController = nil
                    passcodeController.dismiss()
                }
                
                strongSelf.autolockTimeout.set(nil)
                strongSelf.autolockReportTimeout.set(nil)
            } else {
                if let _ = passcodeSettings.autolockTimeout, !isApplicationActive, !strongSelf.biometricAuthenticationState.suppressCoveringView {
                    shouldDisplayCoveringView = true
                }
                
                if !isApplicationActive {
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
                        if becameActiveRecently, !strongSelf.suppressAutomaticBiometrics, case .enabled = biometrics, isApplicationActive {
                            passcodeController.requestBiometrics()
                        }
                        passcodeController.ensureInputFocused()
                    } else {
                        let passcodeController = PasscodeEntryController(applicationBindings: strongSelf.applicationBindings, accountManager: strongSelf.accountManager, appLockContext: strongSelf, presentationData: presentationData, presentationDataSignal: strongSelf.presentationDataSignal, statusBarHost: window?.statusBarHost, challengeData: accessChallengeData.data, biometrics: biometrics, arguments: PasscodeEntryControllerPresentationArguments(animated: !becameActiveRecently || strongSelf.suppressAutomaticBiometrics, lockIconInitialFrame: {
                            if let lockViewFrame = lockIconInitialFrame() {
                                return lockViewFrame
                            } else {
                                return CGRect()
                            }
                        }))
                        if becameActiveRecently, !strongSelf.suppressAutomaticBiometrics, isApplicationActive {
                            passcodeController.presentationCompleted = { [weak self, weak passcodeController] in
                                if case .enabled = biometrics, self?.suppressAutomaticBiometrics == false {
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
                                rootViewController.dismiss(animated: false, completion: nil)
                            }
                        }
                        strongSelf.window?.present(passcodeController, on: .passcode)
                    }
                } else if let passcodeController = strongSelf.passcodeController {
                    strongSelf.passcodeController = nil
                    passcodeController.dismiss()
                }
            }
            
            strongSelf.updateTimestampRenewTimer(shouldRun: isApplicationActive && !isCurrentlyLocked)
            strongSelf.lockStatus.update(isPasscodeLocked: isCurrentlyLocked, isApplicationActive: isApplicationActive, isApplicationInForeground: isApplicationInForeground)
            
            if shouldDisplayCoveringView {
                if strongSelf.coveringView == nil, let window = strongSelf.window {
                    let coveringView = LockedWindowCoveringView(theme: presentationData.theme)
                    coveringView.updateSnapshot(getCoveringViewSnaphot(window: window))
                    strongSelf.coveringView = coveringView
                    window.coveringView = coveringView
                    
                    if let rootViewController = strongSelf.rootController {
                        if let _ = rootViewController.presentedViewController as? UIActivityViewController {
                        } else if let _ = rootViewController.presentedViewController as? PKPaymentAuthorizationViewController {
                        } else {
                            rootViewController.dismiss(animated: false, completion: nil)
                        }
                    }
                }
            } else {
                if let _ = strongSelf.coveringView {
                    strongSelf.coveringView = nil
                    strongSelf.window?.coveringView = nil
                }
            }
        })
        
        self.currentState.set(.single(self.currentStateValue))
        
        self.autolockTimeoutDisposable = (self.autolockTimeout.get()
        |> deliverOnMainQueue).startStrict(next: { [weak self] autolockTimeout in
            self?.updateLockState { state in
                var state = state
                state.autolockTimeout = autolockTimeout
                return state
            }
        })
    }
    
    deinit {
        self.disposable?.dispose()
        self.autolockTimeoutDisposable?.dispose()
    }

    public func beginBiometricAuthentication() -> Disposable {
        assert(Queue.mainQueue().isCurrent())
        guard let id = self.biometricAuthenticationState.begin() else { return EmptyDisposable }
        return ActionDisposable { [weak self] in
            if Queue.mainQueue().isCurrent() {
                self?.biometricAuthenticationState.end(id)
            } else {
                Queue.mainQueue().async { [weak self] in
                    self?.biometricAuthenticationState.end(id)
                }
            }
        }
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
    
    public func _internalCrashForPasscodeMigrationTest(isLocked: Bool) throws -> Never {
        var writeError: Error?
        self.syncQueue.sync {
            do {
                let data = try JSONEncoder().encode(LockState(isManuallyLocked: isLocked))
                try data.write(to: URL(fileURLWithPath: appLockStatePath(rootPath: self.rootPath)), options: .atomic)
                abort()
            } catch {
                writeError = error
            }
        }
        throw writeError!
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
        PasscodeSession.setApplicationAvailable(false)
        self.updateLockState { state in
            // Face ID may still send active events after the user manually locks.
            self.suppressAutomaticBiometrics = true
            var state = state
            state.isManuallyLocked = true
            return state
        }
    }
    
    public func unlock() {
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
}
