import Foundation
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox

final public class PasscodeEntryControllerPresentationArguments {
    let animated: Bool
    let lockIconInitialFrame: () -> CGRect
    
    public init(animated: Bool = true, lockIconInitialFrame: @escaping () -> CGRect) {
        self.animated = animated
        self.lockIconInitialFrame = lockIconInitialFrame
    }
}

final public class PasscodeEntryController: ViewController {
    private var controllerNode: PasscodeEntryControllerNode {
        return self.displayNode as! PasscodeEntryControllerNode
    }
    
    private let context: AccountContext
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
        
    private let challengeData: PostboxAccessChallengeData
    private let enableBiometrics: Bool
    private let arguments: PasscodeEntryControllerPresentationArguments
    
    public var presentationCompleted: (() -> Void)?
    public var completed: (() -> Void)?
    
    private let biometricsDisposable = MetaDisposable()
    private var hasOngoingBiometricsRequest = false
    private var skipNextBiometricsRequest = false
    
    public init(context: AccountContext, challengeData: PostboxAccessChallengeData, enableBiometrics: Bool, arguments: PasscodeEntryControllerPresentationArguments) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.challengeData = challengeData
        self.enableBiometrics = enableBiometrics
        self.arguments = arguments
        
        super.init(navigationBarPresentationData: nil)
        
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
        self.statusBar.statusBarStyle = .White
        
        self.presentationDataDisposable = (context.sharedContext.presentationData
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self, strongSelf.isNodeLoaded {
                strongSelf.controllerNode.updatePresentationData(presentationData)
            }
        })
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
        self.biometricsDisposable.dispose()
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func loadDisplayNode() {
        let passcodeType: PasscodeEntryFieldType
        switch self.challengeData {
            case let .numericalPassword(value, _, _):
                passcodeType = value.count == 6 ? .digits6 : .digits4
            default:
                passcodeType = .alphanumeric
        }
        let biometricsType: LocalAuthBiometricAuthentication?
        if self.enableBiometrics {
            biometricsType = LocalAuth.biometricAuthentication
        } else {
            biometricsType = nil
        }
        self.displayNode = PasscodeEntryControllerNode(context: self.context, theme: self.presentationData.theme, strings: self.presentationData.strings, wallpaper: self.presentationData.chatWallpaper, passcodeType: passcodeType, biometricsType: biometricsType, statusBar: self.statusBar)
        self.displayNodeDidLoad()
        
        let _ = (self.context.sharedContext.accountManager.transaction({ transaction -> AccessChallengeAttempts? in
            return transaction.getAccessChallengeData().attempts
        }) |> deliverOnMainQueue).start(next: { [weak self] attempts in
            guard let strongSelf = self else {
                return
            }
            strongSelf.controllerNode.updateInvalidAttempts(attempts)
        })
        
        self.controllerNode.checkPasscode = { [weak self] passcode in
            guard let strongSelf = self else {
                return
            }
    
            var succeed = false
            switch strongSelf.challengeData {
                case .none:
                    succeed = true
                case let .numericalPassword(code, _, _):
                    succeed = passcode == code
                case let .plaintextPassword(code, _, _):
                    succeed = passcode == code
            }
            
            if succeed {
                if let completed = strongSelf.completed {
                    completed()
                } else {
                    let _ = (strongSelf.context.sharedContext.accountManager.transaction { transaction -> Void in
                        var data = transaction.getAccessChallengeData().withUpdatedAutolockDeadline(nil)
                        switch data {
                            case .none:
                                break
                            case let .numericalPassword(value, timeout, _):
                                data = .numericalPassword(value: value, timeout: timeout, attempts: nil)
                            case let .plaintextPassword(value, timeout, _):
                                data = .plaintextPassword(value: value, timeout: timeout, attempts: nil)
                        }
                        transaction.setAccessChallengeData(data)
                    }).start()
                }
            } else {
                let _ = (strongSelf.context.sharedContext.accountManager.transaction({ transaction -> AccessChallengeAttempts in
                    var data = transaction.getAccessChallengeData()
                    let updatedAttempts: AccessChallengeAttempts
                    if let attempts = data.attempts {
                        var count = attempts.count + 1
                        if count > 6 {
                            count = 1
                        }
                        updatedAttempts = AccessChallengeAttempts(count: count, timestamp: Int32(CFAbsoluteTimeGetCurrent()))
                    } else {
                        updatedAttempts = AccessChallengeAttempts(count: 1, timestamp: Int32(CFAbsoluteTimeGetCurrent()))
                    }
                    switch data {
                        case .none:
                            break
                        case let .numericalPassword(value, timeout, _):
                            data = .numericalPassword(value: value, timeout: timeout, attempts: updatedAttempts)
                        case let .plaintextPassword(value, timeout, _):
                            data = .plaintextPassword(value: value, timeout: timeout, attempts: updatedAttempts)
                    }
                    transaction.setAccessChallengeData(data)
                    
                    return updatedAttempts
                })
                |> deliverOnMainQueue).start(next: { [weak self] attempts in
                    if let strongSelf = self {
                        strongSelf.controllerNode.updateInvalidAttempts(attempts, animated: true)
                    }
                })
                
                strongSelf.controllerNode.animateError()
            }
        }
        self.controllerNode.requestBiometrics = { [weak self] in
            if let strongSelf = self {
                strongSelf.requestBiometrics(force: true)
            }
        }
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.view.disablesInteractiveTransitionGestureRecognizer = true
        
        self.controllerNode.activateInput()
        if self.arguments.animated {
            let iconFrame = self.arguments.lockIconInitialFrame()
            if !iconFrame.isEmpty {
                Queue.mainQueue().after(0.5) {
                    serviceSoundManager.playLockSound()
                }
            }
            
            self.controllerNode.animateIn(iconFrame: iconFrame, completion: { [weak self] in
                self?.presentationCompleted?()
            })
        } else {
            self.controllerNode.initialAppearance()
            self.presentationCompleted?()
        }
    }
    
    public func requestBiometrics(force: Bool = false) {
        guard self.enableBiometrics, let _ = LocalAuth.biometricAuthentication else {
            return
        }
        
        if self.skipNextBiometricsRequest {
            self.skipNextBiometricsRequest = false
            if !force {
                return
            }
        }
        
        if self.hasOngoingBiometricsRequest {
            if !force {
                return
            }
        }
        
        self.hasOngoingBiometricsRequest = true
        
        self.biometricsDisposable.set((LocalAuth.auth(reason: self.presentationData.strings.EnterPasscode_TouchId) |> deliverOnMainQueue).start(next: { [weak self] result in
            guard let strongSelf = self else {
                return
            }
            if result {
                strongSelf.controllerNode.animateSuccess()
                
                if let completed = strongSelf.completed {
                    completed()
                    strongSelf.hasOngoingBiometricsRequest = false
                } else {
                    let _ = (strongSelf.context.sharedContext.accountManager.transaction { transaction -> Void in
                        let data = transaction.getAccessChallengeData().withUpdatedAutolockDeadline(nil)
                        transaction.setAccessChallengeData(data)
                    }).start(completed: { [weak self] in
                        if let strongSelf = self {
                            strongSelf.hasOngoingBiometricsRequest = false
                        }
                    })
                }
            } else {
                strongSelf.hasOngoingBiometricsRequest = false
                strongSelf.skipNextBiometricsRequest = true
            }
        }))
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition)
    }
    
    public override func dismiss(completion: (() -> Void)? = nil) {
        self.view.endEditing(true)
        self.controllerNode.animateOut { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.view.endEditing(true)
            strongSelf.presentingViewController?.dismiss(animated: false, completion: completion)
        }
    }
}
