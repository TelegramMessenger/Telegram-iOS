import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import SwiftSignalKit
import Postbox
import TelegramPresentationData
import AccountContext
import FakePasscode

public enum PasscodeSetupControllerMode {
    case setup(change: Bool, allowChangeType: Bool, PasscodeEntryFieldType)
    case entry(PostboxAccessChallengeData)
    case secretSetup(PasscodeEntryFieldType)
    case secretEntry(modal: Bool, PasscodeEntryFieldType)
}

public final class PasscodeSetupController: ViewController, ReactiveToPasscodeSwitch {
    private var controllerNode: PasscodeSetupControllerNode {
        return self.displayNode as! PasscodeSetupControllerNode
    }
    
    private let context: AccountContext
    private var mode: PasscodeSetupControllerMode
    
    public var complete: ((String, Bool) -> Void)?
    public var check: ((String) -> Bool)?
    public var validate: ((String) -> String?)?
    
    private let hapticFeedback = HapticFeedback()
    
    private var presentationData: PresentationData
    
    private var nextAction: UIBarButtonItem?
    
    public init(context: AccountContext, mode: PasscodeSetupControllerMode) {
        self.context = context
        self.mode = mode
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData))
        
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        
        self.nextAction = UIBarButtonItem(title: self.presentationData.strings.Common_Next, style: .done, target: self, action: #selector(self.nextPressed))
        
        switch self.mode {
        case .setup, .entry:
            self.title = self.presentationData.strings.PasscodeSettings_Title
        case .secretSetup, .secretEntry:
            self.title = self.presentationData.strings.SecretPasscodeSettings_Title
        }
        
        if case let .secretEntry(modal, _) = self.mode, modal {
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Cancel, style: .plain, target: self, action: #selector(self.cancelPressed))
        }
        
        self.isSensitiveUI = true
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func loadDisplayNode() {
        self.displayNode = PasscodeSetupControllerNode(presentationData: self.presentationData, mode: self.mode)
        self.displayNodeDidLoad()
        
        self.navigationBar?.updateBackgroundAlpha(0.0, transition: .immediate)
        self.controllerNode.updateMode(self.mode)
        
        self.controllerNode.selectPasscodeMode = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            let type: PasscodeEntryFieldType
            switch strongSelf.mode {
            case let .setup(_, _, fieldType), let .secretSetup(fieldType), let .secretEntry(_, fieldType):
                type = fieldType
            default:
                return
            }
            
            let controller = ActionSheetController(presentationData: strongSelf.presentationData)
            let dismissAction: () -> Void = { [weak controller] in
                self?.controllerNode.activateInput()
                controller?.dismissAnimated()
            }
            
            var items: [ActionSheetButtonItem] = []
            if case .digits6 = type {
            } else {
                items.append(ActionSheetButtonItem(title: strongSelf.presentationData.strings.PasscodeSettings_6DigitCode, action: { [weak self] in
                    if let strongSelf = self {
                        switch strongSelf.mode {
                        case let .setup(change, allowChange, _):
                            strongSelf.mode = .setup(change: change, allowChangeType: allowChange, .digits6)
                        case .secretSetup:
                            strongSelf.mode = .secretSetup(.digits6)
                        case let .secretEntry(modal, _):
                            strongSelf.mode = .secretEntry(modal: modal, .digits6)
                        default:
                            assertionFailure()
                        }
                        strongSelf.controllerNode.updateMode(strongSelf.mode)
                    }
                    dismissAction()
                }))
            }
            if case .digits4 = type {
            } else {
                items.append(ActionSheetButtonItem(title: strongSelf.presentationData.strings.PasscodeSettings_4DigitCode, action: {
                    if let strongSelf = self {
                        switch strongSelf.mode {
                        case let .setup(change, allowChange, _):
                            strongSelf.mode = .setup(change: change, allowChangeType: allowChange, .digits4)
                        case .secretSetup:
                            strongSelf.mode = .secretSetup(.digits4)
                        case let .secretEntry(modal, _):
                            strongSelf.mode = .secretEntry(modal: modal, .digits4)
                        default:
                            assertionFailure()
                        }
                        strongSelf.controllerNode.updateMode(strongSelf.mode)
                    }
                    dismissAction()
                }))
            }
            if case .alphanumeric = type {
            } else {
                items.append(ActionSheetButtonItem(title: strongSelf.presentationData.strings.PasscodeSettings_AlphanumericCode, action: {
                    if let strongSelf = self {
                        switch strongSelf.mode {
                        case let .setup(change, allowChange, _):
                            strongSelf.mode = .setup(change: change, allowChangeType: allowChange, .alphanumeric)
                        case .secretSetup:
                            strongSelf.mode = .secretSetup(.alphanumeric)
                        case let .secretEntry(modal, _):
                            strongSelf.mode = .secretEntry(modal: modal, .alphanumeric)
                        default:
                            assertionFailure()
                        }
                        strongSelf.controllerNode.updateMode(strongSelf.mode)
                    }
                    dismissAction()
                }))
            }
            controller.setItemGroups([
                ActionSheetItemGroup(items: items),
                ActionSheetItemGroup(items: [ActionSheetButtonItem(title: strongSelf.presentationData.strings.Common_Cancel, action: { dismissAction() })])
            ])
            controller.dismissed = { _ in
                self?.controllerNode.activateInput()
            }
            strongSelf.view.endEditing(true)
            strongSelf.present(controller, in: .window(.root))
        }
        self.controllerNode.updateNextAction = { [weak self] visible in
            guard let strongSelf = self else {
                return
            }
            
            if visible {
                strongSelf.navigationItem.rightBarButtonItem = strongSelf.nextAction
            } else {
                strongSelf.navigationItem.rightBarButtonItem = nil
            }
        }
        self.controllerNode.complete = { [weak self] passcode, numerical in
            if let strongSelf = self {
                strongSelf.complete?(passcode, numerical)
            }
        }
        self.controllerNode.checkPasscode = { [weak self] passcode in
            return self?.check?(passcode) ?? false
        }
        self.controllerNode.validatePasscode = { [weak self] passcode in
            return self?.validate?(passcode)
        }
    }
    
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.controllerNode.activateInput()
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        var flag = true
        if case let .secretEntry(modal, _) = self.mode, modal {
            flag = false
        }
        self.view.disablesInteractiveTransitionGestureRecognizer = flag
        
        self.controllerNode.activateInput()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
    
    @objc private func nextPressed() {
       self.controllerNode.activateNext()
    }
    
    @objc private func cancelPressed() {
        self.dismiss()
    }

    public func passcodeSwitched() {
        self.dismiss(animated: false)
    }
    
    public func activateInput() {
        self.controllerNode.activateInput()
    }
}
