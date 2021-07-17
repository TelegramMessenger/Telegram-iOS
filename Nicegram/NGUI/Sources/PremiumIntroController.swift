import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import DeviceAccess
import AccountContext
import NGData
import NGStrings
import NGIAP
import UndoUI

public final class PremiumIntroController : ViewController {
    private let context: AccountContext
    private let splitTest: PremiumIntroUISplitTest?
    private var state: PremiumIntroControllerContent?
    private var splashScreen = false
    
    private var controllerNode: PremiumIntroControllerNode {
        return self.displayNode as! PremiumIntroControllerNode
    }
    
    private var didPlayPresentationAnimation = false
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    private var allow: (() -> Void)?
    private var skip: (() -> Void)?
    public var proceed: ((Bool) -> Void)?
    
    public init(context: AccountContext, splashScreen: Bool = true, splitTest: PremiumIntroUISplitTest? = nil) {
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
            self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Permissions_Skip, style: .plain, target: self, action: #selector(PremiumIntroController.nextPressed))
        }
        self.controllerNode.updatePresentationData(self.presentationData)
    }
    
    private func openAppSettings() {
        self.context.sharedContext.applicationBindings.openSettings()
    }
    
    public func setState(_ state: PremiumIntroControllerContent, animated: Bool) {
        guard state != self.state else {
            return
        }
        
        self.state = state
        if case let .permission(permission) = state, let state = permission {
            if case .nearbyLocation = state {
            } else {
                self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Permissions_Skip, style: .plain, target: self, action: #selector(PremiumIntroController.nextPressed))
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
                    
                    self.allow = { [weak self] in
                        if let strongSelf = self {
                            switch status {
                                case .requestable:
                                    DeviceAccess.authorizeAccess(to: .location(.tracking), presentationData: strongSelf.context.sharedContext.currentPresentationData.with { $0 }, { [weak self] result in
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
        } else {
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
        self.displayNode = PremiumIntroControllerNode(context: self.context, splitTest: self.splitTest)
        self.displayNodeDidLoad()
        
        self.controllerNode.allow = { [weak self] in
            self?.allow?()
        }
        self.controllerNode.openPrivacyPolicy = { [weak self] in
            if let strongSelf = self {
                let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                let locale = presentationData.strings.baseLanguageCode
                strongSelf.present(UndoOverlayController(presentationData: strongSelf.presentationData, content: .info(text: l("IAP.Common.Connecting", locale)), elevatedLayout: false, animateInAsReplacement: true, action: { _ in
                    return false
                }), in: .current)
            }
            let observer = NotificationCenter.default.addObserver(forName: .IAPHelperPurchaseNotification, object: nil, queue: .main, using: { notification in
                let productID = notification.object as? String
                if productID == NicegramProducts.Premium {
                    NGSettings.premium = true
                    validatePremium(isPremium(), forceValid: true)
                    if (isPremium()) {
                        if let strongSelf = self {
                            let c = premiumController(context: strongSelf.context)
                            
                            (strongSelf.navigationController as? NavigationController)?.replaceAllButRootController(c, animated: true)
                        }
                    } else {
                        if let strongSelf = self {
                            let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                            let c = getIAPErrorController(context: strongSelf.context, "IAP.Common.ValidateError", presentationData)
                            strongSelf.present(c, in: .window(.root))
                        }
                    }
                }
                })
              NicegramProducts.store.restorePurchases()
        }
    }
    
    public override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.splashScreen ? 0.0 : self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
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


// MARK: CONTROLLER NODE
import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import AccountContext
import TelegramPermissions

public struct PremiumIntroControllerCustomIcon: Equatable {
    let light: UIImage?
    let dark: UIImage?
    
    public init(light: UIImage?, dark: UIImage?) {
        self.light = light
        self.dark = dark
    }
}

public enum PremiumIntroControllerContent: Equatable {
    case permission(PermissionState?)
    case custom(icon: PremiumIntroControllerCustomIcon, title: String, subtitle: String?, text: String, buttonTitle: String, footerText: String?)
}

private struct PremiumIntroControllerDataState: Equatable {
    var state: PremiumIntroControllerContent?
}

private struct PremiumIntroControllerLayoutState: Equatable {
    let layout: ContainerViewLayout
    let navigationHeight: CGFloat
}

private struct PremiumIntroControllerInnerState: Equatable {
    var layout: PremiumIntroControllerLayoutState?
    var data: PremiumIntroControllerDataState
}

private struct PremiumIntroControllerState: Equatable {
    var layout: PremiumIntroControllerLayoutState
    var data: PremiumIntroControllerDataState
}

extension PremiumIntroControllerState {
    init?(_ state: PremiumIntroControllerInnerState) {
        guard let layout = state.layout else {
            return nil
        }
        self.init(layout: layout, data: state.data)
    }
}

private func localizedString(for key: String, strings: PresentationStrings, fallback: String = "") -> String {
    if let string = strings.primaryComponent.dict[key] {
        return string
    } else if let string = strings.secondaryComponent?.dict[key] {
        return string
    } else {
        return fallback
    }
}

final class PremiumIntroControllerNode: ASDisplayNode {
    private let context: AccountContext
    private var presentationData: PresentationData
    private let splitTest: PremiumIntroUISplitTest?
    
    private var innerState: PremiumIntroControllerInnerState
    
    private var contentNode: PremiumIntroContentNode?
    
    var allow: (() -> Void)?
    var openPrivacyPolicy: (() -> Void)?
    var dismiss: (() -> Void)?
    
    init(context: AccountContext, splitTest: PremiumIntroUISplitTest?) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.splitTest = splitTest
        self.innerState = PremiumIntroControllerInnerState(layout: nil, data: PremiumIntroControllerDataState(state: nil))
        
        super.init()
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        self.updatePresentationData(self.presentationData)
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
        self.presentationData = presentationData
        
        self.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
        self.contentNode?.updatePresentationData(self.presentationData)
    }
    
    func animateIn(completion: (() -> Void)? = nil) {
        self.layer.animatePosition(from: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), to: self.layer.position, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring)
    }
    
    func animateOut(completion: (() -> Void)? = nil) {
        self.layer.animatePosition(from: self.layer.position, to: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), duration: 0.2, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, completion: { _ in
            completion?()
        })
    }
    
    public func setState(_ state: PremiumIntroControllerContent, transition: ContainedViewLayoutTransition) {
        self.updateState({ currentState -> PremiumIntroControllerInnerState in
            return PremiumIntroControllerInnerState(layout: currentState.layout, data: PremiumIntroControllerDataState(state: state))
        }, transition: transition)
    }
    
    private func updateState(_ f: (PremiumIntroControllerInnerState) -> PremiumIntroControllerInnerState, transition: ContainedViewLayoutTransition) {
        let updatedState = f(self.innerState)
        if updatedState != self.innerState {
            self.innerState = updatedState
            if let state = PremiumIntroControllerState(updatedState) {
                self.transition(state: state, transition: transition)
            }
        }
    }
    
    private func transition(state: PremiumIntroControllerState, transition: ContainedViewLayoutTransition) {
        let insets = state.layout.layout.insets(options: [.statusBar])
        let contentFrame = CGRect(origin: CGPoint(x: 0.0, y: state.layout.navigationHeight), size: CGSize(width: state.layout.layout.size.width, height: state.layout.layout.size.height))
        
        if let state = state.data.state {
            switch state {
                case let .permission(permission):
                    if permission?.kind.rawValue != self.contentNode?.kind {
                        if let dataState = permission {
                            let icon: UIImage?
                            let title: String
                            let text: String
                            let buttonTitle: String
                            let hasPrivacyPolicy: Bool
                            
                            switch dataState {
                                case let .contacts(status):
                                    icon = UIImage(bundleImageName: "Settings/Permissions/Contacts")
                                    if let splitTest = self.splitTest, case let .modal(titleKey, textKey, allowTitleKey, allowInSettingsTitleKey) = splitTest.configuration.contacts {
                                        title = localizedString(for: titleKey, strings: self.presentationData.strings)
                                        text = localizedString(for: textKey, strings: self.presentationData.strings)
                                        if status == .denied {
                                            buttonTitle = localizedString(for: allowInSettingsTitleKey, strings: self.presentationData.strings)
                                        } else {
                                            buttonTitle = localizedString(for: allowTitleKey, strings: self.presentationData.strings)
                                        }
                                    } else {
                                        title = self.presentationData.strings.Permissions_ContactsTitle_v0
                                        text = self.presentationData.strings.Permissions_ContactsText_v0
                                        if status == .denied {
                                            buttonTitle = self.presentationData.strings.Permissions_ContactsAllowInSettings_v0
                                        } else {
                                            buttonTitle = self.presentationData.strings.Permissions_ContactsAllow_v0
                                        }
                                    }
                                    hasPrivacyPolicy = true
                                case let .notifications(status):
                                    icon = UIImage(bundleImageName: "Settings/Permissions/Notifications")
                                    if let splitTest = self.splitTest, case let .modal(titleKey, textKey, allowTitleKey, allowInSettingsTitleKey) = splitTest.configuration.notifications {
                                        title = localizedString(for: titleKey, strings: self.presentationData.strings, fallback: self.presentationData.strings.Permissions_NotificationsTitle_v0)
                                        text = localizedString(for: textKey, strings: self.presentationData.strings, fallback: self.presentationData.strings.Permissions_NotificationsText_v0)
                                        if status == .denied {
                                            buttonTitle = localizedString(for: allowInSettingsTitleKey, strings: self.presentationData.strings, fallback: self.presentationData.strings.Permissions_NotificationsAllowInSettings_v0)
                                        } else {
                                            buttonTitle = localizedString(for: allowTitleKey, strings: self.presentationData.strings, fallback: self.presentationData.strings.Permissions_NotificationsAllow_v0)
                                        }
                                    } else {
                                        title = self.presentationData.strings.Permissions_NotificationsTitle_v0
                                        text = self.presentationData.strings.Permissions_NotificationsText_v0
                                        if status == .denied {
                                            buttonTitle = self.presentationData.strings.Permissions_NotificationsAllowInSettings_v0
                                        } else {
                                            buttonTitle = self.presentationData.strings.Permissions_NotificationsAllow_v0
                                        }
                                    }
                                    hasPrivacyPolicy = false
                                case let .siri(status):
                                    icon = UIImage(bundleImageName: "Settings/Permissions/Siri")
                                    title = self.presentationData.strings.Permissions_SiriTitle_v0
                                    text = self.presentationData.strings.Permissions_SiriText_v0
                                    if status == .denied {
                                        buttonTitle = self.presentationData.strings.Permissions_SiriAllowInSettings_v0
                                    } else {
                                        buttonTitle = self.presentationData.strings.Permissions_SiriAllow_v0
                                    }
                                    hasPrivacyPolicy = false
                                case .cellularData:
                                    icon = UIImage(bundleImageName: "Settings/Permissions/CellularData")
                                    title = self.presentationData.strings.Permissions_CellularDataTitle_v0
                                    text = self.presentationData.strings.Permissions_CellularDataText_v0
                                    buttonTitle = self.presentationData.strings.Permissions_CellularDataAllowInSettings_v0
                                    hasPrivacyPolicy = false
                                case let .nearbyLocation(status):
                                    icon = nil
                                    title = self.presentationData.strings.Permissions_PeopleNearbyTitle_v0
                                    text = self.presentationData.strings.Permissions_PeopleNearbyText_v0
                                    if status == .denied {
                                        buttonTitle = self.presentationData.strings.Permissions_PeopleNearbyAllowInSettings_v0
                                    } else {
                                        buttonTitle = self.presentationData.strings.Permissions_PeopleNearbyAllow_v0
                                    }
                                    hasPrivacyPolicy = false
                            }
                            
                            let contentNode = PremiumIntroContentNode(theme: self.presentationData.theme, strings: self.presentationData.strings, kind: dataState.kind.rawValue, icon: .image(icon), title: title, text: text, buttonTitle: buttonTitle, buttonAction: { [weak self] in
                                self?.allow?()
                                }, openPrivacyPolicy: hasPrivacyPolicy ? self.openPrivacyPolicy : nil)
                            self.insertSubnode(contentNode, at: 0)
                            contentNode.updateLayout(size: contentFrame.size, insets: insets, transition: .immediate)
                            contentNode.frame = contentFrame
                            if let currentContentNode = self.contentNode {
                                transition.updatePosition(node: currentContentNode, position: CGPoint(x: -contentFrame.size.width / 2.0, y: contentFrame.midY), completion: { [weak currentContentNode] _ in
                                    currentContentNode?.removeFromSupernode()
                                })
                                transition.animateHorizontalOffsetAdditive(node: contentNode, offset: -contentFrame.width)
                            } else if transition.isAnimated {
                                contentNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
                            }
                            self.contentNode = contentNode
                        } else if let currentContentNode = self.contentNode {
                            transition.updateAlpha(node: currentContentNode, alpha: 0.0, completion: { [weak currentContentNode] _ in
                                currentContentNode?.removeFromSupernode()
                            })
                            self.contentNode = nil
                        }
                    } else if let contentNode = self.contentNode {
                        transition.updateFrame(node: contentNode, frame: contentFrame)
                        contentNode.updateLayout(size: contentFrame.size, insets: insets, transition: transition)
                    }
                case let .custom(icon, title, subtitle, text, buttonTitle, footerText):
                    if let contentNode = self.contentNode {
                        transition.updateFrame(node: contentNode, frame: contentFrame)
                        contentNode.updateLayout(size: contentFrame.size, insets: insets, transition: transition)
                    } else {
                        let contentNode = PremiumIntroContentNode(theme: self.presentationData.theme, strings: self.presentationData.strings, kind: 0, icon: .icon(icon), title: title, subtitle: subtitle, text: text, buttonTitle: buttonTitle, footerText: footerText, buttonAction: { [weak self] in
                            self?.allow?()
                        }, openPrivacyPolicy: self.openPrivacyPolicy)
                        self.insertSubnode(contentNode, at: 0)
                        contentNode.updateLayout(size: contentFrame.size, insets: insets, transition: .immediate)
                        contentNode.frame = contentFrame
                        self.contentNode = contentNode
                    }
            }
        }
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.updateState({ state in
            var state = state
            state.layout = PremiumIntroControllerLayoutState(layout: layout, navigationHeight: navigationBarHeight)
            return state
        }, transition: transition)
    }
    
    @objc func privacyPolicyPressed() {
        self.openPrivacyPolicy?()
    }
}


// MARK: Split TEST

import Foundation
import UIKit
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPermissions
import SyncCore

extension PermissionKind {
    fileprivate static var defaultOrder: [PermissionKind] {
        return [.contacts, .notifications]
    }
}

public enum PremiumIntroUIRequestVariation {
    case `default`
    case modal(title: String, text: String, allowTitle: String, allowInSettingsTitle: String)
}

public struct PremiumIntroUISplitTest: SplitTest {
    public typealias Configuration = PremiumIntroUIConfiguration
    public typealias Event = PremiumIntroUIEvent
    
    public let postbox: Postbox
    public let bucket: String?
    public let configuration: Configuration
    
    public init(postbox: Postbox, bucket: String?, configuration: Configuration) {
        self.postbox = postbox
        self.bucket = bucket
        self.configuration = configuration
    }
    
    public struct PremiumIntroUIConfiguration: SplitTestConfiguration {
        public static var defaultValue: PremiumIntroUIConfiguration {
            return PremiumIntroUIConfiguration(contacts: .default, notifications: .default, order: PermissionKind.defaultOrder)
        }
        
        public let contacts: PremiumIntroUIRequestVariation
        public let notifications: PremiumIntroUIRequestVariation
        public let order: [PermissionKind]
        
        fileprivate init(contacts: PremiumIntroUIRequestVariation, notifications: PremiumIntroUIRequestVariation, order: [PermissionKind]) {
            self.contacts = contacts
            self.notifications = notifications
            self.order = order
        }
        
        static func with(appConfiguration: AppConfiguration) -> (PremiumIntroUIConfiguration, String?) {
            if let data = appConfiguration.data, let permissions = data["ui_permissions_modals"] as? [String: Any] {
                let contacts: PremiumIntroUIRequestVariation
                if let modal = permissions["phonebook_modal"] as? [String: Any] {
                    contacts = .modal(title: modal["popup_title_lang"] as? String ?? "", text: modal["popup_text_lang"] as? String ?? "", allowTitle: modal["popup_allowbtn_lang"] as? String ?? "", allowInSettingsTitle: modal["popup_allowbtn_settings_lang"] as? String ?? "")
                } else {
                    contacts = .default
                }
                
                let notifications: PremiumIntroUIRequestVariation
                if let modal = permissions["notifications_modal"] as? [String: Any] {
                    notifications = .modal(title: modal["popup_title_lang"] as? String ?? "", text: modal["popup_text_lang"] as? String ?? "", allowTitle: modal["popup_allowbtn_lang"] as? String ?? "", allowInSettingsTitle: modal["popup_allowbtn_settings_lang"] as? String ?? "")
                } else {
                    notifications = .default
                }
                
                let order: [PermissionKind]
                if let values = permissions["order"] as? [String] {
                    order = values.compactMap { value in
                        switch value {
                            case "phonebook":
                                return .contacts
                            case "notifications":
                                return .notifications
                            default:
                                return nil
                        }
                    }
                } else {
                    order = PermissionKind.defaultOrder
                }

                return (PremiumIntroUIConfiguration(contacts: contacts, notifications: notifications, order: order), permissions["bucket"] as? String)
            } else {
                return (.defaultValue, nil)
            }
        }
    }
    
    public enum PremiumIntroUIEvent: String, SplitTestEvent {
        case ContactsModalRequest = "phbmodal_request"
        case ContactsRequest = "phbperm_request"
        case ContactsAllowed = "phbperm_allow"
        case ContactsDenied = "phbperm_disallow"
        case NotificationsModalRequest = "ntfmodal_request"
        case NotificationsRequest = "ntfperm_request"
        case NotificationsAllowed = "ntfperm_allow"
        case NotificationsDenied = "ntfperm_disallow"
    }
}

public func premiumIntroUISplitTest(postbox: Postbox) -> Signal<PremiumIntroUISplitTest, NoError> {
    return postbox.preferencesView(keys: [PreferencesKeys.appConfiguration])
    |> mapToSignal { view -> Signal<PremiumIntroUISplitTest, NoError> in
        if let appConfiguration = view.values[PreferencesKeys.appConfiguration] as? AppConfiguration, appConfiguration.data != nil {
            let (config, bucket) = PremiumIntroUISplitTest.Configuration.with(appConfiguration: appConfiguration)
            return .single(PremiumIntroUISplitTest(postbox: postbox, bucket: bucket, configuration: config))
        } else {
            return .never()
        }
    } |> take(1)
}


// MARK: CONTENT NODE

import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramPresentationData
import TextFormat
import TelegramPermissions
import PeersNearbyIconNode
import SolidRoundedButtonNode
import Markdown
import NGData
import NGStrings

public enum PremiumIntroContentIcon {
    case image(UIImage?)
    case icon(PremiumIntroControllerCustomIcon)
    
    public func imageForTheme(_ theme: PresentationTheme) -> UIImage? {
        switch self {
            case let .image(image):
                return image
            case let .icon(icon):
                return theme.overallDarkAppearance ? (icon.dark ?? icon.light) : icon.light
        }
    }
}

public final class PremiumIntroContentNode: ASDisplayNode {
    private var theme: PresentationTheme
    public let kind: Int32

    private let iconNode: ASImageNode
    private let nearbyIconNode: PeersNearbyIconNode?
    private let titleNode: ImmediateTextNode
    private let subtitleNode: ImmediateTextNode
    private let textNode: ImmediateTextNode
    private let actionButton: SolidRoundedButtonNode
    private let footerNode: ImmediateTextNode
    private let privacyPolicyButton: HighlightableButtonNode
    
    private let icon: PremiumIntroContentIcon
    private var title: String
    private var text: String
    
    public var buttonAction: (() -> Void)?
    public var openPrivacyPolicy: (() -> Void)?
    
    public var validLayout: (CGSize, UIEdgeInsets)?
    
    public init(theme: PresentationTheme, strings: PresentationStrings, kind: Int32, icon: PremiumIntroContentIcon, title: String, subtitle: String? = nil, text: String, buttonTitle: String, footerText: String? = nil, buttonAction: @escaping () -> Void, openPrivacyPolicy: (() -> Void)?) {
        self.theme = theme
        self.kind = kind
        
        self.buttonAction = buttonAction
        self.openPrivacyPolicy = openPrivacyPolicy
        
        self.icon = icon
        self.title = title
        self.text = text
        
        self.iconNode = ASImageNode()
        self.iconNode.isLayerBacked = true
        self.iconNode.displayWithoutProcessing = true
        self.iconNode.displaysAsynchronously = false
        
        if kind == PermissionKind.nearbyLocation.rawValue {
            self.nearbyIconNode = PeersNearbyIconNode(theme: theme)
        } else {
            self.nearbyIconNode = nil
        }
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.maximumNumberOfLines = 0
        self.titleNode.textAlignment = .center
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.displaysAsynchronously = false
        
        self.subtitleNode = ImmediateTextNode()
        self.subtitleNode.maximumNumberOfLines = 1
        self.subtitleNode.textAlignment = .center
        self.subtitleNode.isUserInteractionEnabled = false
        self.subtitleNode.displaysAsynchronously = false
        
        self.textNode = ImmediateTextNode()
        self.textNode.textAlignment = .center
        self.textNode.maximumNumberOfLines = 0
        self.textNode.displaysAsynchronously = false
        
        self.actionButton = SolidRoundedButtonNode(theme: SolidRoundedButtonTheme(theme: theme), height: 48.0, cornerRadius: 9.0, gloss: true)
        
        self.footerNode = ImmediateTextNode()
        self.footerNode.textAlignment = .center
        self.footerNode.maximumNumberOfLines = 0
        self.footerNode.displaysAsynchronously = false
        
        self.privacyPolicyButton = HighlightableButtonNode()
        self.privacyPolicyButton.setTitle(l("IAP.Common.Restore", strings.baseLanguageCode), with: Font.regular(16.0), with: theme.list.itemAccentColor, for: .normal)
        
        super.init()

        self.iconNode.image = icon.imageForTheme(theme)
        self.title = title
        
        let body = MarkdownAttributeSet(font: Font.regular(16.0), textColor: theme.list.itemPrimaryTextColor)
        let link = MarkdownAttributeSet(font: Font.regular(16.0), textColor: theme.list.itemAccentColor, additionalAttributes: [TelegramTextAttributes.URL: ""])
        self.textNode.attributedText = parseMarkdownIntoAttributedString(text.replacingOccurrences(of: "]", with: "]()"), attributes: MarkdownAttributes(body: body, bold: body, link: link, linkAttribute: { _ in nil }), textAlignment: .center)
        
        self.actionButton.title = buttonTitle
        self.privacyPolicyButton.isHidden = false
        
        if let subtitle = subtitle {
            self.subtitleNode.attributedText = NSAttributedString(string: subtitle, font: Font.regular(13.0), textColor: theme.list.freeTextColor, paragraphAlignment: .center)
        }
        
        if let footerText = footerText {
            self.footerNode.attributedText = NSAttributedString(string: footerText, font: Font.regular(13.0), textColor: theme.list.freeTextColor, paragraphAlignment: .center)
        }
        
        self.addSubnode(self.iconNode)
        if let nearbyIconNode = self.nearbyIconNode {
            self.addSubnode(nearbyIconNode)
        }
        self.addSubnode(self.titleNode)
        self.addSubnode(self.subtitleNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.actionButton)
        self.addSubnode(self.footerNode)
        self.addSubnode(self.privacyPolicyButton)
        
        self.actionButton.pressed = { [weak self] in
            self?.buttonAction?()
        }
        
        self.privacyPolicyButton.addTarget(self, action: #selector(self.privacyPolicyPressed), forControlEvents: .touchUpInside)
    }
    
    public func updatePresentationData(_ presentationData: PresentationData) {
        let theme = presentationData.theme
        self.theme = theme
        
        self.iconNode.image = self.icon.imageForTheme(theme)
        
        let body = MarkdownAttributeSet(font: Font.regular(16.0), textColor: theme.list.itemPrimaryTextColor)
        let link = MarkdownAttributeSet(font: Font.regular(16.0), textColor: theme.list.itemAccentColor, additionalAttributes: [TelegramTextAttributes.URL: ""])
        self.textNode.attributedText = parseMarkdownIntoAttributedString(self.text.replacingOccurrences(of: "]", with: "]()"), attributes: MarkdownAttributes(body: body, bold: body, link: link, linkAttribute: { _ in nil }), textAlignment: .center)
        
        if let subtitle = self.subtitleNode.attributedText?.string {
            self.subtitleNode.attributedText = NSAttributedString(string: subtitle, font: Font.regular(13.0), textColor: theme.list.freeTextColor, paragraphAlignment: .center)
        }
        if let footerText = self.footerNode.attributedText?.string {
            self.footerNode.attributedText = NSAttributedString(string: footerText, font: Font.regular(13.0), textColor: theme.list.freeTextColor, paragraphAlignment: .center)
        }
        
        if let privacyPolicyTitle = self.privacyPolicyButton.attributedTitle(for: .normal)?.string {
            self.privacyPolicyButton.setTitle(privacyPolicyTitle, with: Font.regular(16.0), with: theme.list.itemAccentColor, for: .normal)
        }
        
        if let validLayout = self.validLayout {
            self.updateLayout(size: validLayout.0, insets: validLayout.1, transition: .immediate)
        }
    }
    
    @objc private func privacyPolicyPressed() {
        self.openPrivacyPolicy?()
    }
    
    public func updateLayout(size: CGSize, insets: UIEdgeInsets, transition: ContainedViewLayoutTransition) {
        self.validLayout = (size, insets)
        
        let sidePadding: CGFloat
        let fontSize: CGFloat
        if min(size.width, size.height) > 330.0 {
            fontSize = 24.0
            sidePadding = 36.0
        } else {
            fontSize = 20.0
            sidePadding = 20.0
        }
        
        let smallerSidePadding: CGFloat = 20.0
        
        self.titleNode.attributedText = NSAttributedString(string: self.title, font: Font.bold(fontSize), textColor: self.theme.list.itemPrimaryTextColor)
        
        let titleSize = self.titleNode.updateLayout(CGSize(width: size.width - sidePadding * 2.0, height: .greatestFiniteMagnitude))
        let subtitleSize = self.subtitleNode.updateLayout(CGSize(width: size.width - smallerSidePadding * 2.0, height: .greatestFiniteMagnitude))
        let textSize = self.textNode.updateLayout(CGSize(width: size.width - sidePadding * 2.0, height: .greatestFiniteMagnitude))
        let buttonInset: CGFloat = 38.0
        let buttonWidth = min(size.width, size.height) - buttonInset * 2.0
        let buttonHeight = self.actionButton.updateLayout(width: buttonWidth, transition: transition)
        let footerSize = self.footerNode.updateLayout(CGSize(width: size.width - smallerSidePadding * 2.0, height: .greatestFiniteMagnitude))
        let privacyButtonSize = self.privacyPolicyButton.measure(CGSize(width: size.width - sidePadding * 2.0, height: .greatestFiniteMagnitude))
        
        let availableHeight = floor(size.height - insets.top - insets.bottom - titleSize.height - subtitleSize.height - textSize.height - buttonHeight)
        
        let titleTextSpacing: CGFloat = max(15.0, floor(availableHeight * 0.045))
        let titleSubtitleSpacing: CGFloat = 6.0
        let buttonSpacing: CGFloat = max(19.0, floor(availableHeight * 0.075))
        var contentHeight = titleSize.height + titleTextSpacing + textSize.height + buttonHeight + buttonSpacing
        if subtitleSize.height > 0.0 {
            contentHeight += titleSubtitleSpacing + subtitleSize.height
        }
        
        var imageSize = CGSize()
        var imageSpacing: CGFloat = 0.0
        if let icon = self.iconNode.image, size.width < size.height {
            imageSpacing = floor(availableHeight * 0.12)
            imageSize = icon.size
            contentHeight += imageSize.height + imageSpacing
        }
        if let _ = self.nearbyIconNode, size.width < size.height {
            imageSpacing = floor(availableHeight * 0.12)
            imageSize = CGSize(width: 120.0, height: 120.0)
            contentHeight += imageSize.height + imageSpacing
        }

        let privacySpacing: CGFloat = max(30.0 + privacyButtonSize.height, (availableHeight - titleTextSpacing - buttonSpacing - imageSize.height - imageSpacing) / 2.0)
        
        var verticalOffset: CGFloat = 0.0
        if size.height >= 568.0 {
            verticalOffset = availableHeight * 0.05
        }
        
        let contentOrigin = insets.top + floor((size.height - insets.top - insets.bottom - contentHeight) / 2.0) - verticalOffset
        let iconFrame = CGRect(origin: CGPoint(x: floor((size.width - imageSize.width) / 2.0), y: contentOrigin), size: imageSize)
        let nearbyIconFrame = CGRect(origin: CGPoint(x: floor((size.width - imageSize.width) / 2.0), y: contentOrigin), size: imageSize)
        let titleFrame = CGRect(origin: CGPoint(x: floor((size.width - titleSize.width) / 2.0), y: iconFrame.maxY + imageSpacing), size: titleSize)
        
        let subtitleFrame: CGRect
        if subtitleSize.height > 0.0 {
            subtitleFrame = CGRect(origin: CGPoint(x: floor((size.width - subtitleSize.width) / 2.0), y: titleFrame.maxY + titleSubtitleSpacing), size: subtitleSize)
        } else {
            subtitleFrame = titleFrame
        }
        
        let textFrame = CGRect(origin: CGPoint(x: floor((size.width - textSize.width) / 2.0), y: subtitleFrame.maxY + titleTextSpacing), size: textSize)
        let buttonFrame = CGRect(origin: CGPoint(x: floor((size.width - buttonWidth) / 2.0), y: textFrame.maxY + buttonSpacing), size: CGSize(width: buttonWidth, height: buttonHeight))
        
        let footerFrame = CGRect(origin: CGPoint(x: floor((size.width - footerSize.width) / 2.0), y: size.height - footerSize.height - insets.bottom - 8.0), size: footerSize)
        
        let privacyButtonFrame = CGRect(origin: CGPoint(x: floor((size.width - privacyButtonSize.width) / 2.0), y: buttonFrame.maxY + floor((privacySpacing - privacyButtonSize.height) / 2.0)), size: privacyButtonSize)
        
        transition.updateFrame(node: self.iconNode, frame: iconFrame)
        if let nearbyIconNode = self.nearbyIconNode {
            transition.updateFrame(node: nearbyIconNode, frame: nearbyIconFrame)
        }
        transition.updateFrame(node: self.titleNode, frame: titleFrame)
        transition.updateFrame(node: self.subtitleNode, frame: subtitleFrame)
        transition.updateFrame(node: self.textNode, frame: textFrame)
        transition.updateFrame(node: self.actionButton, frame: buttonFrame)
        transition.updateFrame(node: self.footerNode, frame: footerFrame)
        transition.updateFrame(node: self.privacyPolicyButton, frame: privacyButtonFrame)
        
        self.footerNode.isHidden = size.height < 568.0
    }
}

