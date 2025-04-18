import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import DeviceAccess
import AccountContext

public final class PermissionController: ViewController {
    private let context: AccountContext
    private let splitTest: PermissionUISplitTest?
    private var state: PermissionControllerContent?
    private var splashScreen = false
    
    private var locationManager: LocationManager?
    
    private var controllerNode: PermissionControllerNode {
        return self.displayNode as! PermissionControllerNode
    }
    
    private var didPlayPresentationAnimation = false
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    private var allow: (() -> Void)?
    private var skip: (() -> Void)?
    public var proceed: ((Bool) -> Void)?
    
    
    public init(context: AccountContext, splashScreen: Bool = true, splitTest: PermissionUISplitTest? = nil) {
        self.context = context
        self.splitTest = splitTest
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.splashScreen = splashScreen
        
        let navigationBarPresentationData: NavigationBarPresentationData
        if splashScreen {
            navigationBarPresentationData = NavigationBarPresentationData(theme: NavigationBarTheme(buttonColor: self.presentationData.theme.rootController.navigationBar.accentTextColor, disabledButtonColor: self.presentationData.theme.rootController.navigationBar.disabledButtonColor, primaryTextColor: self.presentationData.theme.rootController.navigationBar.primaryTextColor, backgroundColor: .clear, enableBackgroundBlur: false, separatorColor: .clear, badgeBackgroundColor: .clear, badgeStrokeColor: .clear, badgeTextColor: .clear), strings: NavigationBarStrings(presentationStrings: self.presentationData.strings))
        } else {
            navigationBarPresentationData = NavigationBarPresentationData(presentationData: self.presentationData)
        }
        
        super.init(navigationBarPresentationData: navigationBarPresentationData)
        
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
        
        self.updateThemeAndStrings()
        
        self.presentationDataDisposable = (context.sharedContext.presentationData
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
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        
        let navigationBarPresentationData: NavigationBarPresentationData
        if self.splashScreen {
            navigationBarPresentationData = NavigationBarPresentationData(theme: NavigationBarTheme(buttonColor: self.presentationData.theme.rootController.navigationBar.accentTextColor, disabledButtonColor: self.presentationData.theme.rootController.navigationBar.disabledButtonColor, primaryTextColor: self.presentationData.theme.rootController.navigationBar.primaryTextColor, backgroundColor: .clear, enableBackgroundBlur: false, separatorColor: .clear, badgeBackgroundColor: .clear, badgeStrokeColor: .clear, badgeTextColor: .clear), strings: NavigationBarStrings(presentationStrings: self.presentationData.strings))
        } else {
            navigationBarPresentationData = NavigationBarPresentationData(presentationData: self.presentationData)
        }
        
        self.navigationBar?.updatePresentationData(navigationBarPresentationData)
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: nil, style: .plain, target: nil, action: nil)
        if self.navigationItem.rightBarButtonItem != nil {
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Permissions_Skip, style: .plain, target: self, action: #selector(PermissionController.nextPressed))
        }
        self.controllerNode.updatePresentationData(self.presentationData)
    }
    
    private func openAppSettings() {
        self.context.sharedContext.applicationBindings.openSettings()
    }
    
    public func setState(_ state: PermissionControllerContent, animated: Bool) {
        guard state != self.state else {
            return
        }
        
        self.state = state
        if case let .permission(permission) = state, let state = permission {
            if case .nearbyLocation = state {
            } else {
                self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Permissions_Skip, style: .plain, target: self, action: #selector(PermissionController.nextPressed))
            }
            
            switch state {
                case let .contacts(status):
                    self.splitTest?.addEvent(.ContactsModalRequest)
                    
                    self.allow = { [weak self] in
                        if let strongSelf = self {
                            switch status {
                                case .requestable:
                                    strongSelf.splitTest?.addEvent(.ContactsRequest)
                                    DeviceAccess.authorizeAccess(to: .contacts, { [weak self] result in
                                        if let strongSelf = self {
                                            if result {
                                                strongSelf.splitTest?.addEvent(.ContactsAllowed)
                                            } else {
                                                strongSelf.splitTest?.addEvent(.ContactsDenied)
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
                    self.splitTest?.addEvent(.NotificationsModalRequest)
                    
                    self.allow = { [weak self] in
                        if let strongSelf = self {
                            switch status {
                                case .requestable:
                                    strongSelf.splitTest?.addEvent(.NotificationsRequest)
                                    let context = strongSelf.context
                                    DeviceAccess.authorizeAccess(to: .notifications, registerForNotifications: { [weak context] result in
                                        context?.sharedContext.applicationBindings.registerForNotifications(result)
                                    }, { [weak self] result in
                                        if let strongSelf = self {
                                            if result {
                                                strongSelf.splitTest?.addEvent(.NotificationsAllowed)
                                            } else {
                                                strongSelf.splitTest?.addEvent(.NotificationsDenied)
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
                case .siri:
                    self.allow = { [weak self] in
                        self?.proceed?(true)
                    }
                case .cellularData:
                    self.allow = { [weak self] in
                        if let strongSelf = self {
                            strongSelf.openAppSettings()
                            strongSelf.proceed?(true)
                        }
                    }
                case let .nearbyLocation(status):
                    self.title = self.presentationData.strings.Permissions_PeopleNearbyTitle_v0
                    
                    if self.locationManager == nil {
                        self.locationManager = LocationManager()
                    }
                    
                    self.allow = { [weak self] in
                        if let strongSelf = self {
                            switch status {
                                case .requestable:
                                    DeviceAccess.authorizeAccess(to: .location(.tracking), locationManager: strongSelf.locationManager, presentationData: strongSelf.context.sharedContext.currentPresentationData.with { $0 }, { [weak self] result in
                                        self?.proceed?(result)
                                    })
                            case .denied, .unreachable:
                                strongSelf.openAppSettings()
                                strongSelf.proceed?(false)
                            default:
                                break
                            }
                        }
                    }
            }
        } else if case let .custom(icon, _, _, _, _, _, _) = state {
            if case .animation = icon, case .modal = self.navigationPresentation {
                self.navigationItem.leftBarButtonItem = UIBarButtonItem(customDisplayNode: ASDisplayNode())
            }
            self.allow = { [weak self] in
                if let strongSelf = self {
                    strongSelf.proceed?(true)
                }
            }
        }
        
        self.skip = { [weak self] in
            self?.proceed?(false)
        }
        self.controllerNode.setState(state, transition: animated ? .animated(duration: 0.4, curve: .spring) : .immediate)
    }
    
    public override func loadDisplayNode() {
        self.displayNode = PermissionControllerNode(context: self.context, splitTest: self.splitTest)
        self.displayNodeDidLoad()
        
        self.navigationBar?.updateBackgroundAlpha(0.0, transition: .immediate)
        
        self.controllerNode.allow = { [weak self] in
            self?.allow?()
        }
        self.controllerNode.dismiss = { [weak self] in
            self?.dismiss()
        }
        self.controllerNode.openPrivacyPolicy = { [weak self] in
            if let strongSelf = self {
                strongSelf.context.sharedContext.openExternalUrl(context: strongSelf.context, urlContext: .generic, url: "https://telegram.org/privacy", forceExternal: true, presentationData: strongSelf.context.sharedContext.currentPresentationData.with { $0 }, navigationController: nil, dismissInput: {})
            }
        }
    }
    
    @objc private func cancelPressed() {
        self.dismiss()
    }
    
    public override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        if let state = self.state, case .custom(.animation, _, _, _, _, _, _) = state, layout.size.width <= 320.0 {
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Cancel, style: .plain, target: self, action: #selector(self.cancelPressed))
        }
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.splashScreen ? 0.0 : self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
    
    @objc private func nextPressed() {
        self.skip?()
    }
}
