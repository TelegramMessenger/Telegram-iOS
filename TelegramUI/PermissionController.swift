import Foundation
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore

public final class PermissionController : ViewController {
    private let account: Account
    private let splitTest: PermissionUISplitTest
    private var state: PermissionState?
    
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
    
    private var allow: (() -> Void)?
    private var skip: (() -> Void)?
    public var proceed: ((Bool) -> Void)?
    
    public init(account: Account, splitTest: PermissionUISplitTest) {
        self.account = account
        self.splitTest = splitTest
        self.presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(theme: NavigationBarTheme(buttonColor: self.presentationData.theme.rootController.navigationBar.accentTextColor, disabledButtonColor: self.presentationData.theme.rootController.navigationBar.disabledButtonColor, primaryTextColor: self.presentationData.theme.rootController.navigationBar.primaryTextColor, backgroundColor: .clear, separatorColor: .clear, badgeBackgroundColor: .clear, badgeStrokeColor: .clear, badgeTextColor: .clear), strings: NavigationBarStrings(presentationStrings: self.presentationData.strings)))
        
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
        
        self.updateThemeAndStrings()
        
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
    
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if let presentationArguments = self.presentationArguments as? ViewControllerPresentationArguments, !self.didPlayPresentationAnimation {
            self.didPlayPresentationAnimation = true
            if case .modalSheet = presentationArguments.presentationAnimation {
                self.controllerNode.animateIn()
            }
        }
    }
    
    private func updateThemeAndStrings() {
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBar.style.style
        self.navigationBar?.updatePresentationData(NavigationBarPresentationData(theme: NavigationBarTheme(buttonColor: self.presentationData.theme.rootController.navigationBar.accentTextColor, disabledButtonColor: self.presentationData.theme.rootController.navigationBar.disabledButtonColor, primaryTextColor: self.presentationData.theme.rootController.navigationBar.primaryTextColor, backgroundColor: .clear, separatorColor: .clear, badgeBackgroundColor: .clear, badgeStrokeColor: .clear, badgeTextColor: .clear), strings: NavigationBarStrings(presentationStrings: self.presentationData.strings)))
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: nil, style: .plain, target: nil, action: nil)
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Permissions_Skip, style: .plain, target: self, action: #selector(PermissionController.nextPressed))
        self.controllerNode.updatePresentationData(self.presentationData)
    }
    
    private func openAppSettings() {
        self.account.telegramApplicationContext.applicationBindings.openSettings()
    }
    
    public func setState(_ state: PermissionState, animated: Bool) {
        guard state != self.state else {
            return
        }
        
        self.state = state
        switch state {
            case let .contacts(status):
                self.splitTest.addEvent(.ContactsModalRequest)
                
                self.allow = { [weak self] in
                    if let strongSelf = self {
                        switch status {
                            case .requestable:
                                strongSelf.splitTest.addEvent(.ContactsRequest)
                                DeviceAccess.authorizeAccess(to: .contacts, account: strongSelf.account, { [weak self] result in
                                    if let strongSelf = self {
                                        if result {
                                            strongSelf.splitTest.addEvent(.ContactsAllowed)
                                        } else {
                                            strongSelf.splitTest.addEvent(.ContactsDenied)
                                        }
                                        strongSelf.proceed?(true)
                                    }
                                })
                            case .denied:
                                strongSelf.openAppSettings()
                                strongSelf.proceed?(true)
                            default:
                                break
                        }
                    }
                }
            case let .notifications(status):
                self.splitTest.addEvent(.NotificationsModalRequest)
                
                self.allow = { [weak self] in
                    if let strongSelf = self {
                        switch status {
                            case .requestable:
                                strongSelf.splitTest.addEvent(.NotificationsRequest)
                                DeviceAccess.authorizeAccess(to: .notifications, account: strongSelf.account, { [weak self] result in
                                    if let strongSelf = self {
                                        if result {
                                            strongSelf.splitTest.addEvent(.NotificationsAllowed)
                                        } else {
                                            strongSelf.splitTest.addEvent(.NotificationsDenied)
                                        }
                                        strongSelf.proceed?(true)
                                    }
                                })
                            case .denied, .unreachable:
                                strongSelf.openAppSettings()
                                strongSelf.proceed?(true)
                            default:
                                break
                        }
                    }
                }
            case let .siri(status):
                self.allow = { [weak self] in
                    self?.proceed?(true)
                }
            case let .cellularData:
                self.allow = { [weak self] in
                    self?.proceed?(true)
                }
        }
        
        self.skip = { [weak self] in
            self?.proceed?(false)
        }
        self.controllerNode.setState(state, transition: animated ? .animated(duration: 0.4, curve: .spring) : .immediate)
    }
    
    public override func loadDisplayNode() {
        self.displayNode = PermissionControllerNode(account: self.account, splitTest: self.splitTest)
        self.displayNodeDidLoad()
        
        self.controllerNode.allow = { [weak self] in
            self?.allow?()
        }
        self.controllerNode.openPrivacyPolicy = { [weak self] in
            if let strongSelf = self {
                openExternalUrl(account: strongSelf.account, context: .generic, url: "https://telegram.org/privacy", forceExternal: true, presentationData: strongSelf.account.telegramApplicationContext.currentPresentationData.with { $0 }, applicationContext: strongSelf.account.telegramApplicationContext, navigationController: nil, dismissInput: {})
            }
        }
    }
    
    public override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition)
    }
    
    @objc private func nextPressed() {
        self.skip?()
    }
    
    override public func dismiss(completion: (() -> Void)? = nil) {
        self.controllerNode.animateOut(completion: { [weak self] in
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
            completion?()
        })
    }
}
