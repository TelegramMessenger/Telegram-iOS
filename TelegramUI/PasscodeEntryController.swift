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
    
    private let biometricsDisposable = MetaDisposable()
    
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
                if value.count == 6 {
                    passcodeType = .digits6
                } else {
                    passcodeType = .digits4
                }
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
                let _ = (strongSelf.context.sharedContext.accountManager.transaction { transaction -> Void in
                    let data = transaction.getAccessChallengeData().withUpdatedAutolockDeadline(nil)
                    transaction.setAccessChallengeData(data)
                }).start()
            } else {
//                let _ = strongSelf.context.sharedContext.accountManager.transaction({ transaction -> Void in
//                    var attempts: AccessChallengeAttempts?
//                    if let attemptData = attemptData {
//                        attempts = AccessChallengeAttempts(count: Int32(attemptData.numberOfInvalidAttempts), timestamp: Int32(attemptData.dateOfLastInvalidAttempt))
//                    }
//                    var data = transaction.getAccessChallengeData()
//                    switch data {
//                        case .none:
//                            break
//                        case let .numericalPassword(value, timeout, _):
//                            data = .numericalPassword(value: value, timeout: timeout, attempts: attempts)
//                        case let .plaintextPassword(value, timeout, _):
//                            data = .plaintextPassword(value: value, timeout: timeout, attempts: attempts)
//                    }
//                    transaction.setAccessChallengeData(data)
//                }).start()
                
                strongSelf.controllerNode.animateError()
            }
        }
        self.controllerNode.requestBiometrics = { [weak self] in
            if let strongSelf = self {
                strongSelf.requestBiometrics()
            }
        }
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.controllerNode.activateInput()
        if self.arguments.animated {
            Queue.mainQueue().after(0.5) {
                serviceSoundManager.playLockSound()
            }
            
            self.controllerNode.animateIn(completion: { [weak self] in
                self?.presentationCompleted?()
            })
        } else {
            self.controllerNode.initialAppearance()
            self.presentationCompleted?()
        }
    }
    
    public func requestBiometrics() {
        guard self.enableBiometrics, let _ = LocalAuth.biometricAuthentication else {
            return
        }
        self.biometricsDisposable.set(LocalAuth.auth(reason: self.presentationData.strings.EnterPasscode_TouchId).start(next: { [weak self] result in
            guard let strongSelf = self else {
                return
            }
            if result {
                let _ = (strongSelf.context.sharedContext.accountManager.transaction { transaction -> Void in
                    let data = transaction.getAccessChallengeData().withUpdatedAutolockDeadline(nil)
                    transaction.setAccessChallengeData(data)
                }).start()
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
