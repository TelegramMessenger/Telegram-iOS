import Foundation
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore

final class PermissionController : ViewController {
    private let account: Account
    
    private var controllerNode: PermissionControllerNode {
        return self.displayNode as! PermissionControllerNode
    }
    
    private var _ready = Promise<Bool>()
    override public var ready: Promise<Bool> {
        return self._ready
    }
    
    private var didPlayPresentationAnimation = false
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    init(account: Account) {
        self.account = account
        self.presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: NavigationBarTheme(buttonColor: self.presentationData.theme.rootController.navigationBar.accentTextColor, disabledButtonColor: self.presentationData.theme.rootController.navigationBar.disabledButtonColor, primaryTextColor: self.presentationData.theme.rootController.navigationBar.primaryTextColor, backgroundColor: .clear, separatorColor: .clear, badgeBackgroundColor: .clear, badgeStrokeColor: .clear, badgeTextColor: .clear), strings: NavigationBarStrings(presentationStrings: self.presentationData.strings)))
        
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBar.style.style
        
        self.presentationDataDisposable = (account.telegramApplicationContext.presentationData
            |> deliverOnMainQueue).start(next: { [weak self] presentationData in
                if let strongSelf = self {
                    let previousTheme = strongSelf.presentationData.theme
                    let previousStrings = strongSelf.presentationData.strings
                    
                    strongSelf.presentationData = presentationData
                    
                    if previousTheme !== presentationData.theme || previousStrings !== presentationData.strings {
                        strongSelf.updateThemeAndStrings()
                    }
                }
            })
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if let presentationArguments = self.presentationArguments as? ViewControllerPresentationArguments, !self.didPlayPresentationAnimation {
            self.didPlayPresentationAnimation = true
            if case .modalSheet = presentationArguments.presentationAnimation {
                self.controllerNode.animateIn()
            }
        }
    }
    
    override func dismiss(completion: (() -> Void)? = nil) {
        self.controllerNode.animateOut(completion: { [weak self] in
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
            completion?()
        })
        self.view.endEditing(true)
    }
    
    private func updateThemeAndStrings() {
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBar.style.style
        self.navigationBar?.updatePresentationData(NavigationBarPresentationData(presentationData: self.presentationData))
        self.title = self.presentationData.strings.Settings_AppLanguage
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: nil, style: .plain, target: nil, action: nil)
        //self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Permissions_Skip, style: .plain, target: self, action: #selector(PermissionController.nextPressed))
        self.controllerNode.updatePresentationData(self.presentationData)
    }
    
    override func loadDisplayNode() {
        self.displayNode = PermissionControllerNode(account: self.account)
        self.displayNodeDidLoad()
        
        self.controllerNode.allow = { [weak self] in
            //self?.allow?()
        }
        self.controllerNode.openPrivacyPolicy = { [weak self] in
            if let strongSelf = self {
                openExternalUrl(account: strongSelf.account, context: .generic, url: "https://telegram.org/privacy", forceExternal: true, presentationData: strongSelf.account.telegramApplicationContext.currentPresentationData.with { $0 }, applicationContext: strongSelf.account.telegramApplicationContext, navigationController: nil, dismissInput: {})
            }
        }
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition)
    }
    
    @objc private func nextPressed() {
        //self.controllerNode.activateNextAction()
    }
}
