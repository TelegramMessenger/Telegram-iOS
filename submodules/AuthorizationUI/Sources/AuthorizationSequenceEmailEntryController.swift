import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import ProgressNavigationButtonNode
import AccountContext

public final class AuthorizationSequenceEmailEntryController: ViewController {
    public enum Mode {
        case setup
        case change
    }
    
    private let mode: Mode
    private let blocking: Bool
    
    private var controllerNode: AuthorizationSequenceEmailEntryControllerNode {
        return self.displayNode as! AuthorizationSequenceEmailEntryControllerNode
    }
    
    private var validLayout: ContainerViewLayout?
    
    private let presentationData: PresentationData
    
    public var proceedWithEmail: ((String) -> Void)?
    public var signInWithApple: (() -> Void)?
        
    private let hapticFeedback = HapticFeedback()
    
    private var appleSignInAllowed = false
    
    public var inProgress: Bool = false {
        didSet {
            self.updateNavigationItems()
            self.controllerNode.inProgress = self.inProgress
        }
    }
    
    public var authorization: Any?
    public var authorizationDelegate: Any?
    
    private var inBackground = false
    private var inBackgroundDisposable: Disposable?
    
    public init(context: AccountContext? = nil, presentationData: PresentationData, mode: Mode, blocking: Bool = false, back: @escaping () -> Void) {
        self.presentationData = presentationData
        self.mode = mode
        self.blocking = blocking
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: AuthorizationSequenceController.navigationBarTheme(presentationData.theme), strings: NavigationBarStrings(presentationStrings: presentationData.strings)))
        
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
        
        self.hasActiveInput = true
        
        self.statusBar.statusBarStyle = presentationData.theme.intro.statusBarStyle.style
        
        self.attemptNavigation = { _ in
            return false
        }
        self.navigationBar?.backPressed = {
            back()
        }
        
        if self.blocking {
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(customView: UIView())
        }
        
        if let context {
            self.inBackgroundDisposable = (context.sharedContext.applicationBindings.applicationInForeground
            |> deliverOnMainQueue).start(next: { [weak self] value in
                guard let self else {
                    return
                }
                let previousValue = self.inBackground
                self.inBackground = value
                
                if !value && previousValue {
                    let _ = (context.engine.notices.getServerProvidedSuggestions(reload: true)
                    |> deliverOnMainQueue).start(next: { [weak self] currentValues in
                        guard let self else {
                            return
                        }
                        if !currentValues.contains(.setupLoginEmail) && !currentValues.contains(.setupLoginEmailBlocking) {
                            self.dismiss()
                        }
                    })
                }
            })
        }
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.inBackgroundDisposable?.dispose()
    }
    
    override public func loadDisplayNode() {
        self.displayNode = AuthorizationSequenceEmailEntryControllerNode(strings: self.presentationData.strings, theme: self.presentationData.theme, mode: self.mode)
        self.displayNodeDidLoad()
        
        self.controllerNode.view.disableAutomaticKeyboardHandling = [.forward, .backward]
        
        self.controllerNode.proceedWithEmail = { [weak self] _ in
            self?.nextPressed()
        }
        
        self.controllerNode.signInWithApple = { [weak self] in
            self?.signInWithApple?()
        }
        
        self.controllerNode.updateData(appleSignInAllowed: self.appleSignInAllowed)
    }
    
    override public  func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.controllerNode.activateInput()
    }
    
    func updateNavigationItems() {
        guard let layout = self.validLayout, layout.size.width < 360.0 else {
            return
        }
                        
        if self.inProgress {
            let item = UIBarButtonItem(customDisplayNode: ProgressNavigationButtonNode(color: self.presentationData.theme.rootController.navigationBar.accentTextColor))
            self.navigationItem.rightBarButtonItem = item
        } else {
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Next, style: .done, target: self, action: #selector(self.nextPressed))
        }
    }
    
    public func updateData(appleSignInAllowed: Bool) {
        var appleSignInAllowed = appleSignInAllowed
        if #available(iOS 13.0, *) {
        } else {
            appleSignInAllowed = false
        }
        if self.appleSignInAllowed != appleSignInAllowed {
            self.appleSignInAllowed = appleSignInAllowed
            if self.isNodeLoaded {
                self.controllerNode.updateData(appleSignInAllowed: appleSignInAllowed)
            }
        }
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        let hadLayout = self.validLayout != nil
        self.validLayout = layout
        
        if !hadLayout {
            self.updateNavigationItems()
        }
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
    
    @objc private func nextPressed() {
        if self.controllerNode.currentEmail.isEmpty {
            if self.appleSignInAllowed {
                self.signInWithApple?()
            } else {
                self.hapticFeedback.error()
                self.controllerNode.animateError()
            }
        } else {
            self.proceedWithEmail?(self.controllerNode.currentEmail)
        }
    }
}
