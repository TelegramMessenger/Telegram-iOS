import Foundation
import Intents
import TelegramPresentationData
import TelegramUIPreferences
import SwiftSignalKit
import Postbox
import TelegramCore
import Display
import LegacyComponents
import DeviceAccess
import TelegramUpdateUI
import AccountContext
import AlertUI
import PresentationDataUtils
import TelegramPermissions
import TelegramNotices
import LegacyUI
import TelegramPermissionsUI
import PasscodeUI
import ImageBlur
import FastBlur
import WatchBridge
import SettingsUI
import AppLock
import AccountUtils
import ContextUI
import TelegramCallsUI

final class UnauthorizedApplicationContext {
    let sharedContext: SharedAccountContextImpl
    let account: UnauthorizedAccount
    
    let rootController: AuthorizationSequenceController
    
    let isReady = Promise<Bool>()
    
    var authorizationCompleted: Bool = false

    private var serviceNotificationEventsDisposable: Disposable?
    
    init(apiId: Int32, apiHash: String, sharedContext: SharedAccountContextImpl, account: UnauthorizedAccount, otherAccountPhoneNumbers: ((String, AccountRecordId, Bool)?, [(String, AccountRecordId, Bool)])) {
        self.sharedContext = sharedContext
        self.account = account
        let presentationData = sharedContext.currentPresentationData.with { $0 }
        
        var authorizationCompleted: (() -> Void)?
        
        self.rootController = AuthorizationSequenceController(sharedContext: sharedContext, account: account, otherAccountPhoneNumbers: otherAccountPhoneNumbers, presentationData: presentationData, openUrl: sharedContext.applicationBindings.openUrl, apiId: apiId, apiHash: apiHash, authorizationCompleted: {
            authorizationCompleted?()
        })
        
        authorizationCompleted = { [weak self] in
            self?.authorizationCompleted = true
        }
        
        self.isReady.set(self.rootController.ready.get())
        
        account.shouldBeServiceTaskMaster.set(sharedContext.applicationBindings.applicationInForeground |> map { value -> AccountServiceTaskMasterMode in
            if value {
                return .always
            } else {
                return .never
            }
        })
        
        DeviceAccess.authorizeAccess(to: .cellularData, presentationData: sharedContext.currentPresentationData.with { $0 }, present: { [weak self] c, a in
            if let strongSelf = self {
                (strongSelf.rootController.viewControllers.last as? ViewController)?.present(c, in: .window(.root))
            }
        }, openSettings: {
            sharedContext.applicationBindings.openSettings()
        }, { result in
            ApplicationSpecificNotice.setPermissionWarning(accountManager: sharedContext.accountManager, permission: .cellularData, value: 0)
        })

        self.serviceNotificationEventsDisposable = (account.serviceNotificationEvents
        |> deliverOnMainQueue).start(next: { [weak self] text in
            if let strongSelf = self {
                let presentationData = strongSelf.sharedContext.currentPresentationData.with { $0 }
                let alertController = textAlertController(sharedContext: strongSelf.sharedContext, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})])

                (strongSelf.rootController.viewControllers.last as? ViewController)?.present(alertController, in: .window(.root))
            }
        })
    }

    deinit {
        self.serviceNotificationEventsDisposable?.dispose()
    }
}

final class AuthorizedApplicationContext {
    let sharedApplicationContext: SharedApplicationContext
    let mainWindow: Window1
    let lockedCoveringView: LockedWindowCoveringView
    
    let context: AccountContextImpl
    
    let rootController: TelegramRootController
    let notificationController: NotificationContainerController
    
    private var scheduledOpenNotificationSettings: Bool = false
    private var scheduledOpenChatWithPeerId: (PeerId, MessageId?, Bool)?
    private let scheduledCallPeerDisposable = MetaDisposable()
    private var scheduledOpenExternalUrl: URL?
        
    private let passcodeStatusDisposable = MetaDisposable()
    private let passcodeLockDisposable = MetaDisposable()
    private let loggedOutDisposable = MetaDisposable()
    private let inAppNotificationSettingsDisposable = MetaDisposable()
    private let notificationMessagesDisposable = MetaDisposable()
    private let termsOfServiceUpdatesDisposable = MetaDisposable()
    private let termsOfServiceProceedToBotDisposable = MetaDisposable()
    private let watchNavigateToMessageDisposable = MetaDisposable()
    private let permissionsDisposable = MetaDisposable()
    private let appUpdateInfoDisposable = MetaDisposable()
    
    private var inAppNotificationSettings: InAppNotificationSettings?
    
    var passcodeController: PasscodeEntryController?
    
    private var currentAppUpdateInfo: AppUpdateInfo?
    private var currentTermsOfServiceUpdate: TermsOfServiceUpdate?
    private var currentPermissionsController: PermissionController?
    private var currentPermissionsState: PermissionState?
    
    private let unlockedStatePromise = Promise<Bool>()
    var unlockedState: Signal<Bool, NoError> {
        return self.unlockedStatePromise.get()
    }
    
    var applicationBadge: Signal<Int32, NoError> {
        return renderedTotalUnreadCount(accountManager: self.context.sharedContext.accountManager, engine: self.context.engine)
        |> map {
            $0.0
        }
    }
    
    let isReady = Promise<Bool>()
    
    private var presentationDataDisposable: Disposable?
    private var displayAlertsDisposable: Disposable?
    private var removeNotificationsDisposable: Disposable?
    
    private var applicationInForegroundDisposable: Disposable?
    
    private var showCallsTab: Bool
    private var showCallsTabDisposable: Disposable?
    private var enablePostboxTransactionsDiposable: Disposable?
    
    init(sharedApplicationContext: SharedApplicationContext, mainWindow: Window1, watchManagerArguments: Signal<WatchManagerArguments?, NoError>, context: AccountContextImpl, accountManager: AccountManager<TelegramAccountManagerTypes>, showCallsTab: Bool, reinitializedNotificationSettings: @escaping () -> Void) {
        self.sharedApplicationContext = sharedApplicationContext
        
        setupLegacyComponents(context: context)
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        self.mainWindow = mainWindow
        self.lockedCoveringView = LockedWindowCoveringView(theme: presentationData.theme)
        
        self.context = context
        
        self.showCallsTab = showCallsTab
        
        self.notificationController = NotificationContainerController(context: context)
        
        self.mainWindow.previewThemeAccentColor = presentationData.theme.rootController.navigationBar.accentTextColor
        self.mainWindow.previewThemeDarkBlur = presentationData.theme.rootController.keyboardColor == .dark
        
        self.rootController = TelegramRootController(context: context)
        
        self.rootController.globalOverlayControllersUpdated = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            var hasContext = false
            for controller in strongSelf.rootController.globalOverlayControllers {
                if controller is ContextController {
                    hasContext = true
                    break
                }
            }
            
            strongSelf.notificationController.updateIsTemporaryHidden(hasContext)
        }
        
        if KeyShortcutsController.isAvailable {
            let keyShortcutsController = KeyShortcutsController { [weak self] f in
                if let strongSelf = self, let appLockContext = strongSelf.context.sharedContext.appLockContext as? AppLockContextImpl {
                    let _ = (appLockContext.isCurrentlyLocked
                    |> take(1)
                    |> deliverOnMainQueue).start(next: { locked in
                        guard !locked else {
                            return
                        }
                        if let tabController = strongSelf.rootController.rootTabController {
                            let selectedController = tabController.controllers[tabController.selectedIndex]
                            
                            if let index = strongSelf.rootController.viewControllers.lastIndex(where: { controller in
                                guard let controller = controller as? ViewController else {
                                    return false
                                }
                                if controller === tabController {
                                    return false
                                }
                                switch controller.navigationPresentation {
                                case .master:
                                    return true
                                default:
                                    break
                                }
                                return false
                            }), let controller = strongSelf.rootController.viewControllers[index] as? ViewController {
                                if !f(controller) {
                                    return
                                }
                            } else {
                                if !f(selectedController) {
                                    return
                                }
                            }
                            
                            if let controller = strongSelf.rootController.topViewController as? ViewController, controller !== selectedController {
                                if !f(controller) {
                                    return
                                }
                            }
                        }
                        strongSelf.mainWindow.forEachViewController(f)
                    })
                }
            }
            context.keyShortcutsController = keyShortcutsController
        }
        
        if self.rootController.rootTabController == nil {
            self.rootController.addRootControllers(showCallsTab: self.showCallsTab)
        }
        if let tabsController = self.rootController.viewControllers.first as? TabBarController, !tabsController.controllers.isEmpty, tabsController.selectedIndex >= 0 {
            let controller = tabsController.controllers[tabsController.selectedIndex]
            let combinedReady = combineLatest(tabsController.ready.get(), controller.ready.get())
            |> map { $0 && $1 }
            |> filter { $0 }
            |> take(1)
            self.isReady.set(combinedReady)
        } else {
            self.isReady.set(.single(true))
        }
        
        let accountId = context.account.id
        self.loggedOutDisposable.set((context.account.loggedOut
        |> deliverOnMainQueue).start(next: { [weak self] value in
            if value {
                Logger.shared.log("ApplicationContext", "account logged out")
                let _ = logoutFromAccount(id: accountId, accountManager: accountManager, alreadyLoggedOutRemotely: false).start()
                if let strongSelf = self {
                    strongSelf.rootController.currentWindow?.forEachController { controller in
                        if let controller = controller as? TermsOfServiceController {
                            controller.dismiss()
                        }
                    }
                }
            }
        }))
        
        self.inAppNotificationSettingsDisposable.set(((context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.inAppNotificationSettings])) |> deliverOnMainQueue).start(next: { [weak self] sharedData in
            if let strongSelf = self {
                if let settings = sharedData.entries[ApplicationSpecificSharedDataKeys.inAppNotificationSettings]?.get(InAppNotificationSettings.self) {
                    let previousSettings = strongSelf.inAppNotificationSettings
                    strongSelf.inAppNotificationSettings = settings
                    if let previousSettings = previousSettings, previousSettings.displayNameOnLockscreen != settings.displayNameOnLockscreen {
                        reinitializedNotificationSettings()
                    }
                }
            }
        }))

        let engine = context.engine
        self.notificationMessagesDisposable.set((context.account.stateManager.notificationMessages
        |> mapToSignal { messageList -> Signal<[([Message], PeerGroupId, Bool)], NoError> in
            return engine.data.get(EngineDataMap(
                messageList.compactMap { item -> TelegramEngine.EngineData.Item.Messages.ChatListIndex? in
                    if let message = item.0.first {
                        return TelegramEngine.EngineData.Item.Messages.ChatListIndex(id: message.id.peerId)
                    } else {
                        return nil
                    }
                }
            ))
            |> map { chatListIndexMap -> [([Message], PeerGroupId, Bool)] in
                return messageList.filter { item in
                    guard let message = item.0.first else {
                        return false
                    }
                    if let maybeChatListIndex = chatListIndexMap[message.id.peerId], maybeChatListIndex != nil {
                        return true
                    } else {
                        return false
                    }
                }
            }
        }
        |> deliverOn(Queue.mainQueue())).start(next: { [weak self] messageList in
            if messageList.isEmpty {
                return
            }

            if let strongSelf = self, let (messages, _, notify) = messageList.last, let firstMessage = messages.first {
                if UIApplication.shared.applicationState == .active {
                    var chatIsVisible = false
                    if let topController = strongSelf.rootController.topViewController as? ChatControllerImpl, topController.traceVisibility() {
                        if topController.chatLocation.peerId == firstMessage.id.peerId {
                            chatIsVisible = true
                        }
                    }
                    
                    if !notify {
                        chatIsVisible = true
                    }
                    
                    if !chatIsVisible {
                        strongSelf.mainWindow.forEachViewController({ controller in
                            if let controller = controller as? ChatControllerImpl, case .peer(firstMessage.id.peerId) = controller.chatLocation  {
                                chatIsVisible = true
                                return false
                            }
                            return true
                        })
                    }
                    
                    let inAppNotificationSettings: InAppNotificationSettings
                    if let current = strongSelf.inAppNotificationSettings {
                        inAppNotificationSettings = current
                    } else {
                        inAppNotificationSettings = InAppNotificationSettings.defaultSettings
                    }
                    
                    if let appLockContext = strongSelf.context.sharedContext.appLockContext as? AppLockContextImpl {
                        let _ = (appLockContext.isCurrentlyLocked
                        |> take(1)
                        |> deliverOnMainQueue).start(next: { locked in
                            guard let strongSelf = self else {
                                return
                            }
                            
                            guard !locked else {
                                return
                            }
                            let isMuted = firstMessage.attributes.contains(where: { attribute in
                                if let attribute = attribute as? NotificationInfoMessageAttribute {
                                    return attribute.flags.contains(.muted)
                                } else {
                                    return false
                                }
                            })
                            if !isMuted {
                                if firstMessage.id.peerId == context.account.peerId, !firstMessage.flags.contains(.WasScheduled) {
                                } else {
                                    if inAppNotificationSettings.playSounds {
                                        serviceSoundManager.playIncomingMessageSound()
                                    }
                                    if inAppNotificationSettings.vibrate {
                                        serviceSoundManager.playVibrationSound()
                                    }
                                }
                            }
                            if let forwardInfo = firstMessage.forwardInfo, forwardInfo.flags.contains(.isImported) {
                                return
                            }
                            for media in firstMessage.media {
                                if let action = media as? TelegramMediaAction {
                                    if case .messageAutoremoveTimeoutUpdated = action.action {
                                        return
                                    }
                                }
                            }
                            
                            if chatIsVisible {
                                return
                            }
                            
                            if inAppNotificationSettings.displayPreviews {
                               let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                                strongSelf.notificationController.enqueue(ChatMessageNotificationItem(context: strongSelf.context, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat, nameDisplayOrder: presentationData.nameDisplayOrder, messages: messages, tapAction: {
                                    if let strongSelf = self {
                                        var foundOverlay = false
                                        strongSelf.mainWindow.forEachViewController({ controller in
                                            if isOverlayControllerForChatNotificationOverlayPresentation(controller) {
                                                foundOverlay = true
                                                return false
                                            }
                                            return true
                                        }, excludeNavigationSubControllers: true)
                                        
                                        if foundOverlay {
                                            return true
                                        }
                                        
                                        if let topController = strongSelf.rootController.topViewController as? ViewController, isInlineControllerForChatNotificationOverlayPresentation(topController) {
                                            return true
                                        }
                                        
                                        if let topController = strongSelf.rootController.topViewController as? ChatControllerImpl, case .peer(firstMessage.id.peerId) = topController.chatLocation {
                                            strongSelf.notificationController.removeItemsWithGroupingKey(firstMessage.id.peerId)
                                            
                                            return false
                                        }
                                        
                                        for controller in strongSelf.rootController.viewControllers {
                                            if let controller = controller as? ChatControllerImpl, case .peer(firstMessage.id.peerId) = controller.chatLocation  {
                                                return true
                                            }
                                        }
                                        
                                        strongSelf.notificationController.removeItemsWithGroupingKey(firstMessage.id.peerId)
                                        
                                        var processed = false
                                        for media in firstMessage.media {
                                            if let action = media as? TelegramMediaAction, case .geoProximityReached = action.action {
                                                strongSelf.context.sharedContext.openLocationScreen(context: strongSelf.context, messageId: firstMessage.id, navigationController: strongSelf.rootController)
                                                processed = true
                                                break
                                            }
                                        }
                                        
                                        if !processed {
                                            strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: strongSelf.rootController, context: strongSelf.context, chatLocation: .peer(id: firstMessage.id.peerId)))
                                        }
                                    }
                                    return false
                                }, expandAction: { expandData in
                                    if let strongSelf = self {
                                        let chatController = ChatControllerImpl(context: strongSelf.context, chatLocation: .peer(id: firstMessage.id.peerId), mode: .overlay(strongSelf.rootController))
                                        chatController.presentationArguments = ChatControllerOverlayPresentationData(expandData: expandData())
                                        (strongSelf.rootController.viewControllers.last as? ViewController)?.present(chatController, in: .window(.root), with: ChatControllerOverlayPresentationData(expandData: expandData()))
                                    }
                                }))
                            }
                        })
                    }
                }
            }
        }))
        
        self.termsOfServiceUpdatesDisposable.set((context.account.stateManager.termsOfServiceUpdate
        |> deliverOnMainQueue).start(next: { [weak self] termsOfServiceUpdate in
            guard let strongSelf = self, strongSelf.currentTermsOfServiceUpdate != termsOfServiceUpdate else {
                return
            }
            
            strongSelf.currentTermsOfServiceUpdate = termsOfServiceUpdate
            if let termsOfServiceUpdate = termsOfServiceUpdate {
                let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                var acceptImpl: ((String?) -> Void)?
                var declineImpl: (() -> Void)?
                let controller = TermsOfServiceController(presentationData: presentationData, text: termsOfServiceUpdate.text, entities: termsOfServiceUpdate.entities, ageConfirmation: termsOfServiceUpdate.ageConfirmation, signingUp: false, accept: { proccedBot in
                    acceptImpl?(proccedBot)
                }, decline: {
                    declineImpl?()
                }, openUrl: { url in
                    if let parsedUrl = URL(string: url) {
                        UIApplication.shared.openURL(parsedUrl)
                    }
                })
                
                acceptImpl = { [weak controller] botName in
                    controller?.inProgress = true
                    guard let strongSelf = self else {
                        return
                    }
                    let _ = (strongSelf.context.engine.accountData.acceptTermsOfService(id: termsOfServiceUpdate.id)
                    |> deliverOnMainQueue).start(completed: {
                        controller?.dismiss()
                        if let strongSelf = self, let botName = botName {
                            strongSelf.termsOfServiceProceedToBotDisposable.set((strongSelf.context.engine.peers.resolvePeerByName(name: botName, ageLimit: 10) |> take(1) |> deliverOnMainQueue).start(next: { peer in
                                if let strongSelf = self, let peer = peer {
                                    self?.rootController.pushViewController(ChatControllerImpl(context: strongSelf.context, chatLocation: .peer(id: peer.id)))
                                }
                            }))
                        }
                    })
                }
                
                declineImpl = { [weak controller] in
                    guard let strongSelf = self else {
                        return
                    }
                    let accountId = strongSelf.context.account.id
                    let accountManager = strongSelf.context.sharedContext.accountManager
                    let _ = (strongSelf.context.engine.auth.deleteAccount(reason: "GDPR")
                    |> deliverOnMainQueue).start(error: { _ in
                        guard let strongSelf = self else {
                            return
                        }
                        let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                        let controller = textAlertController(context: strongSelf.context, title: nil, text: presentationData.strings.Login_UnknownError, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})])
                        (strongSelf.rootController.viewControllers.last as? ViewController)?.present(controller, in: .window(.root))
                    }, completed: {
                        controller?.dismiss()
                        let _ = logoutFromAccount(id: accountId, accountManager: accountManager, alreadyLoggedOutRemotely: true).start()
                    })
                }
                
                (strongSelf.rootController.viewControllers.last as? ViewController)?.present(controller, in: .window(.root))
            }
        }))
        
        self.appUpdateInfoDisposable.set((context.account.stateManager.appUpdateInfo
        |> deliverOnMainQueue).start(next: { [weak self] appUpdateInfo in
            guard let strongSelf = self, strongSelf.currentAppUpdateInfo != appUpdateInfo else {
                return
            }
            
            strongSelf.currentAppUpdateInfo = appUpdateInfo
            if let appUpdateInfo = appUpdateInfo {
                let controller = updateInfoController(context: strongSelf.context, appUpdateInfo: appUpdateInfo)
                strongSelf.mainWindow.present(controller, on: .update)
            }
        }))
        
        if #available(iOS 10.0, *) {
            let permissionsPosition = ValuePromise(0, ignoreRepeated: true)
            self.permissionsDisposable.set((combineLatest(queue: .mainQueue(), requiredPermissions(context: context), permissionUISplitTest(postbox: context.account.postbox), permissionsPosition.get(), context.sharedContext.accountManager.noticeEntry(key: ApplicationSpecificNotice.permissionWarningKey(permission: .contacts)!), context.sharedContext.accountManager.noticeEntry(key: ApplicationSpecificNotice.permissionWarningKey(permission: .notifications)!), context.sharedContext.accountManager.noticeEntry(key: ApplicationSpecificNotice.permissionWarningKey(permission: .cellularData)!))
            |> deliverOnMainQueue).start(next: { [weak self] required, splitTest, position, contactsPermissionWarningNotice, notificationsPermissionWarningNotice, cellularDataPermissionWarningNotice in
                guard let strongSelf = self else {
                    return
                }
                
                let contactsTimestamp = contactsPermissionWarningNotice.value.flatMap({ ApplicationSpecificNotice.getTimestampValue($0) })
                let notificationsTimestamp = notificationsPermissionWarningNotice.value.flatMap({ ApplicationSpecificNotice.getTimestampValue($0) })
                let cellularDataTimestamp = cellularDataPermissionWarningNotice.value.flatMap({ ApplicationSpecificNotice.getTimestampValue($0) })
                if contactsTimestamp == nil, case .requestable = required.0.status {
                    ApplicationSpecificNotice.setPermissionWarning(accountManager: context.sharedContext.accountManager, permission: .contacts, value: 1)
                }
                if notificationsTimestamp == nil, case .requestable = required.1.status {
                    ApplicationSpecificNotice.setPermissionWarning(accountManager: context.sharedContext.accountManager, permission: .notifications, value: 1)
                }
                
                let config = splitTest.configuration
                var order = config.order
                if !order.contains(.cellularData) {
                    order.append(.cellularData)
                }
                if !order.contains(.siri) {
                    order.append(.siri)
                }
                var requestedPermissions: [(PermissionState, Bool)] = []
                var i: Int = 0
                for subject in order {
                    if i < position {
                        i += 1
                        continue
                    }
                    var modal = false
                    switch subject {
                        case .contacts:
                            if case .modal = config.contacts {
                                modal = true
                            }
                            if case .requestable = required.0.status, contactsTimestamp != 0 {
                                requestedPermissions.append((required.0, modal))
                            }
                        case .notifications:
                            if case .modal = config.notifications {
                                modal = true
                            }
                            if case .requestable = required.1.status, notificationsTimestamp != 0 {
                                requestedPermissions.append((required.1, modal))
                            }
                        case .cellularData:
                            if case .denied = required.2.status, cellularDataTimestamp != 0 {
                                requestedPermissions.append((required.2, true))
                            }
                        case .siri:
                            if case .requestable = required.3.status {
                                requestedPermissions.append((required.3, false))
                            }
                        default:
                            break
                    }
                    i += 1
                }
                
                if let (state, modal) = requestedPermissions.first {
                    if modal {
                        var didAppear = false
                        let controller: PermissionController
                        if let currentController = strongSelf.currentPermissionsController {
                            controller = currentController
                            didAppear = true
                        } else {
                            controller = PermissionController(context: context, splitTest: splitTest)
                            strongSelf.currentPermissionsController = controller
                        }
                        
                        controller.setState(.permission(state), animated: didAppear)
                        controller.proceed = { resolved in
                            permissionsPosition.set(position + 1)
                            switch state {
                                case .contacts:
                                    ApplicationSpecificNotice.setPermissionWarning(accountManager: context.sharedContext.accountManager, permission: .contacts, value: 0)
                                case .notifications:
                                    ApplicationSpecificNotice.setPermissionWarning(accountManager: context.sharedContext.accountManager, permission: .notifications, value: 0)
                                case .cellularData:
                                    ApplicationSpecificNotice.setPermissionWarning(accountManager: context.sharedContext.accountManager, permission: .cellularData, value: 0)
                                default:
                                    break
                            }
                        }
                        
                        if !didAppear {
                            Queue.mainQueue().after(0.15, {
                                (strongSelf.rootController.viewControllers.last as? ViewController)?.present(controller, in: .window(.root), with: ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
                            })
                        }
                    } else {
                        if strongSelf.currentPermissionsState != state {
                            strongSelf.currentPermissionsState = state
                            switch state {
                                case .contacts:
                                    splitTest.addEvent(.ContactsRequest)
                                    DeviceAccess.authorizeAccess(to: .contacts, presentationData: context.sharedContext.currentPresentationData.with { $0 }, { result in
                                        if result {
                                            splitTest.addEvent(.ContactsAllowed)
                                        } else {
                                            splitTest.addEvent(.ContactsDenied)
                                        }
                                        permissionsPosition.set(position + 1)
                                        ApplicationSpecificNotice.setPermissionWarning(accountManager: context.sharedContext.accountManager, permission: .contacts, value: 0)
                                    })
                                case .notifications:
                                    splitTest.addEvent(.NotificationsRequest)
                                    DeviceAccess.authorizeAccess(to: .notifications, registerForNotifications: { result in
                                        context.sharedContext.applicationBindings.registerForNotifications(result)
                                    }, { result in
                                        if result {
                                            splitTest.addEvent(.NotificationsAllowed)
                                        } else {
                                            splitTest.addEvent(.NotificationsDenied)
                                        }
                                        permissionsPosition.set(position + 1)
                                        ApplicationSpecificNotice.setPermissionWarning(accountManager: context.sharedContext.accountManager, permission: .notifications, value: 0)
                                    })
                                case .cellularData:
                                    DeviceAccess.authorizeAccess(to: .cellularData, presentationData: context.sharedContext.currentPresentationData.with { $0 }, present: { [weak self] c, a in
                                        if let strongSelf = self {
                                            (strongSelf.rootController.viewControllers.last as? ViewController)?.present(c, in: .window(.root))
                                        }
                                    }, openSettings: {
                                        context.sharedContext.applicationBindings.openSettings()
                                    }, { result in
                                        permissionsPosition.set(position + 1)
                                        ApplicationSpecificNotice.setPermissionWarning(accountManager: context.sharedContext.accountManager, permission: .cellularData, value: 0)
                                    })
                                case .siri:
                                    DeviceAccess.authorizeAccess(to: .siri, requestSiriAuthorization: { completion in
                                        return context.sharedContext.applicationBindings.requestSiriAuthorization(completion)
                                    }, { result in
                                        permissionsPosition.set(position + 1)
                                    })
                                default:
                                    break
                            }
                        }
                    }
                } else {
                    if let controller = strongSelf.currentPermissionsController {
                        strongSelf.currentPermissionsController = nil
                        controller.dismiss(completion: {})
                    }
                    strongSelf.currentPermissionsState = nil
                }
            }))
        }
        
        self.displayAlertsDisposable = (context.account.stateManager.displayAlerts
        |> deliverOnMainQueue).start(next: { [weak self] alerts in
            if let strongSelf = self {
                for (text, isDropAuth) in alerts {
                    let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                    let actions: [TextAlertAction]
                    if isDropAuth {
                        actions = [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .genericAction, title: presentationData.strings.LogoutOptions_LogOut, action: {
                            if let strongSelf = self {
                                let _ = logoutFromAccount(id: strongSelf.context.account.id, accountManager: strongSelf.context.sharedContext.accountManager, alreadyLoggedOutRemotely: false).start()
                            }
                        })]
                    } else {
                        actions = [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]
                    }
                    let controller = textAlertController(context: strongSelf.context, title: nil, text: text, actions: actions)
                    (strongSelf.rootController.viewControllers.last as? ViewController)?.present(controller, in: .window(.root))
                }
            }
        })
        
        self.removeNotificationsDisposable = (context.account.stateManager.appliedIncomingReadMessages
        |> deliverOnMainQueue).start(next: { [weak self] ids in
            if let strongSelf = self {
                strongSelf.context.sharedContext.applicationBindings.clearMessageNotifications(ids)
            }
        })
       
        let importableContacts = self.context.sharedContext.contactDataManager?.importable() ?? .single([:])
        self.context.account.importableContacts.set(self.context.account.postbox.preferencesView(keys: [PreferencesKeys.contactsSettings])
        |> mapToSignal { preferences -> Signal<[DeviceContactNormalizedPhoneNumber: ImportableDeviceContactData], NoError> in
            let settings: ContactsSettings = preferences.values[PreferencesKeys.contactsSettings]?.get(ContactsSettings.self) ?? .defaultSettings
            if settings.synchronizeContacts {
                return importableContacts
            } else {
                return .single([:])
            }
        })
        
        let previousTheme = Atomic<PresentationTheme?>(value: nil)
        self.presentationDataDisposable = (context.sharedContext.presentationData
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                if previousTheme.swap(presentationData.theme) !== presentationData.theme {
                    strongSelf.mainWindow.previewThemeAccentColor = presentationData.theme.rootController.navigationBar.accentTextColor
                    strongSelf.mainWindow.previewThemeDarkBlur = presentationData.theme.rootController.keyboardColor == .dark
                    strongSelf.lockedCoveringView.updateTheme(presentationData.theme)
                    strongSelf.rootController.updateTheme(NavigationControllerTheme(presentationTheme: presentationData.theme))
                }
            }
        })
        
        let showCallsTabSignal = context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.callListSettings])
        |> map { sharedData -> Bool in
            var value = CallListSettings.defaultSettings.showTab
            if let settings = sharedData.entries[ApplicationSpecificSharedDataKeys.callListSettings]?.get(CallListSettings.self) {
                value = settings.showTab
            }
            return value
        }
        self.showCallsTabDisposable = (showCallsTabSignal |> deliverOnMainQueue).start(next: { [weak self] value in
            if let strongSelf = self {
                if strongSelf.showCallsTab != value {
                    strongSelf.showCallsTab = value
                    strongSelf.rootController.updateRootControllers(showCallsTab: value)
                }
            }
        })
        
        let _ = (watchManagerArguments
        |> deliverOnMainQueue).start(next: { [weak self] arguments in
            guard let strongSelf = self else {
                return
            }
            
            let watchManager = WatchManagerImpl(arguments: arguments)
            strongSelf.context.watchManager = watchManager
            
            strongSelf.watchNavigateToMessageDisposable.set((strongSelf.context.sharedContext.applicationBindings.applicationInForeground |> mapToSignal({ applicationInForeground -> Signal<(Bool, MessageId), NoError> in
                return watchManager.navigateToMessageRequested
                |> map { messageId in
                    return (applicationInForeground, messageId)
                }
                |> deliverOnMainQueue
            })).start(next: { [weak self] applicationInForeground, messageId in
                if let strongSelf = self {
                    if applicationInForeground {
                        var chatIsVisible = false
                        if let controller = strongSelf.rootController.viewControllers.last as? ChatControllerImpl, case .peer(messageId.peerId) = controller.chatLocation  {
                            chatIsVisible = true
                        }
                        
                        let navigateToMessage = {
                            strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: strongSelf.rootController, context: strongSelf.context, chatLocation: .peer(id: messageId.peerId), subject: .message(id: .id(messageId), highlight: true, timecode: nil)))
                        }
                        
                        if chatIsVisible {
                            navigateToMessage()
                        } else {
                            let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                            let controller = textAlertController(context: strongSelf.context, title: presentationData.strings.WatchRemote_AlertTitle, text: presentationData.strings.WatchRemote_AlertText, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .genericAction, title: presentationData.strings.WatchRemote_AlertOpen, action:navigateToMessage)])
                            (strongSelf.rootController.viewControllers.last as? ViewController)?.present(controller, in: .window(.root))
                        }
                    } else {
                        //strongSelf.notificationManager.presentWatchContinuityNotification(context: strongSelf.context, messageId: messageId)
                    }
                }
            }))
        })
        
        self.rootController.setForceInCallStatusBar((self.context.sharedContext as! SharedAccountContextImpl).currentCallStatusBarNode)
        if let groupCallController = self.context.sharedContext.currentGroupCallController as? VoiceChatController {
            if let overlayController = groupCallController.currentOverlayController {
                groupCallController.parentNavigationController = self.rootController
                self.rootController.presentOverlay(controller: overlayController, inGlobal: true, blockInteraction: false)
            }
        }
    }
    
    deinit {
        self.context.account.postbox.clearCaches()
        self.context.account.shouldKeepOnlinePresence.set(.single(false))
        self.context.account.shouldBeServiceTaskMaster.set(.single(.never))
        self.loggedOutDisposable.dispose()
        self.inAppNotificationSettingsDisposable.dispose()
        self.notificationMessagesDisposable.dispose()
        self.termsOfServiceUpdatesDisposable.dispose()
        self.passcodeLockDisposable.dispose()
        self.passcodeStatusDisposable.dispose()
        self.displayAlertsDisposable?.dispose()
        self.removeNotificationsDisposable?.dispose()
        self.presentationDataDisposable?.dispose()
        self.enablePostboxTransactionsDiposable?.dispose()
        self.termsOfServiceProceedToBotDisposable.dispose()
        self.watchNavigateToMessageDisposable.dispose()
        self.permissionsDisposable.dispose()
        self.scheduledCallPeerDisposable.dispose()
    }
    
    func openNotificationSettings() {
        if self.rootController.rootTabController != nil {
            self.rootController.pushViewController(notificationsAndSoundsController(context: self.context, exceptionsList: nil))
        } else {
            self.scheduledOpenNotificationSettings = true
        }
    }
    
    func startCall(peerId: PeerId, isVideo: Bool) {
        guard let appLockContext = self.context.sharedContext.appLockContext as? AppLockContextImpl else {
            return
        }
        self.scheduledCallPeerDisposable.set((appLockContext.isCurrentlyLocked
        |> filter {
            !$0
        }
        |> take(1)
        |> deliverOnMainQueue).start(next: { [weak self] _ in
            guard let strongSelf = self else {
                return
            }
            let _ = strongSelf.context.sharedContext.callManager?.requestCall(context: strongSelf.context, peerId: peerId, isVideo: isVideo, endCurrentIfAny: false)
        }))
    }
    
    func openChatWithPeerId(peerId: PeerId, messageId: MessageId? = nil, activateInput: Bool = false) {
        var visiblePeerId: PeerId?
        if let controller = self.rootController.topViewController as? ChatControllerImpl, case let .peer(peerId) = controller.chatLocation {
            visiblePeerId = peerId
        }
        
        if visiblePeerId != peerId || messageId != nil {
            if self.rootController.rootTabController != nil {
                self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: self.rootController, context: self.context, chatLocation: .peer(id: peerId), subject: messageId.flatMap { .message(id: .id($0), highlight: true, timecode: nil) }, activateInput: activateInput))
            } else {
                self.scheduledOpenChatWithPeerId = (peerId, messageId, activateInput)
            }
        }
    }
    
    func openUrl(_ url: URL) {
        if self.rootController.rootTabController != nil {
            let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
            self.context.sharedContext.openExternalUrl(context: self.context, urlContext: .generic, url: url.absoluteString, forceExternal: false, presentationData: presentationData, navigationController: self.rootController, dismissInput: { [weak self] in
                self?.rootController.view.endEditing(true)
            })
        } else {
            self.scheduledOpenExternalUrl = url
        }
    }
    
    func openRootSearch() {
        self.rootController.openChatsController(activateSearch: true)
    }
    
    func openRootCompose() {
        self.rootController.openRootCompose()
    }
    
    func openRootCamera() {
        self.rootController.openRootCamera()
    }
    
    func switchAccount() {
        let _ = (activeAccountsAndPeers(context: self.context)
        |> take(1)
        |> map { primaryAndAccounts -> (AccountContext, EnginePeer, Int32)? in
            return primaryAndAccounts.1.first
        }
        |> map { accountAndPeer -> AccountContext? in
            if let (context, _, _) = accountAndPeer {
                return context
            } else {
                return nil
            }
        }
        |> deliverOnMainQueue).start(next: { [weak self] context in
            guard let strongSelf = self, let context = context else {
                return
            }
            strongSelf.context.sharedContext.switchToAccount(id: context.account.id, fromSettingsController: nil, withChatListController: nil)
        })
    }
    
    private func updateCoveringViewSnaphot(_ visible: Bool) {
        if visible {
            let scale: CGFloat = 0.5
            let unscaledSize = self.mainWindow.hostView.containerView.frame.size
            let image = generateImage(CGSize(width: floor(unscaledSize.width * scale), height: floor(unscaledSize.height * scale)), rotatedContext: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                context.scaleBy(x: scale, y: scale)
                UIGraphicsPushContext(context)
                self.mainWindow.hostView.containerView.drawHierarchy(in: CGRect(origin: CGPoint(), size: unscaledSize), afterScreenUpdates: false)
                UIGraphicsPopContext()
            }).flatMap(applyScreenshotEffectToImage)
            self.lockedCoveringView.updateSnapshot(image)
        } else {
            self.lockedCoveringView.updateSnapshot(nil)
        }
    }
}
