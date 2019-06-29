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

func isAccessLocked(data: PostboxAccessChallengeData, at timestamp: Int32) -> Bool {
    if data.isLockable, let autolockDeadline = data.autolockDeadline, autolockDeadline <= timestamp {
        return true
    } else {
        return false
    }
}

final class UnauthorizedApplicationContext {
    let sharedContext: SharedAccountContext
    let account: UnauthorizedAccount
    
    let rootController: AuthorizationSequenceController
    
    init(apiId: Int32, apiHash: String, sharedContext: SharedAccountContext, account: UnauthorizedAccount, otherAccountPhoneNumbers: ((String, AccountRecordId, Bool)?, [(String, AccountRecordId, Bool)])) {
        self.sharedContext = sharedContext
        self.account = account
        let presentationData = sharedContext.currentPresentationData.with { $0 }
        
        self.rootController = AuthorizationSequenceController(sharedContext: sharedContext, account: account, otherAccountPhoneNumbers: otherAccountPhoneNumbers, strings: presentationData.strings, theme: presentationData.theme, openUrl: sharedContext.applicationBindings.openUrl, apiId: apiId, apiHash: apiHash)
        
        account.shouldBeServiceTaskMaster.set(sharedContext.applicationBindings.applicationInForeground |> map { value -> AccountServiceTaskMasterMode in
            if value {
                return .always
            } else {
                return .never
            }
        })
    }
}

private struct PasscodeState: Equatable {
    let isActive: Bool
    let challengeData: PostboxAccessChallengeData
    let autolockTimeout: Int32?
    let enableBiometrics: Bool
    let biometricsDomainState: Data?
}

final class AuthorizedApplicationContext {
    let sharedApplicationContext: SharedApplicationContext
    let mainWindow: Window1
    let lockedCoveringView: LockedWindowCoveringView
    
    let context: AccountContext
    
    let rootController: TelegramRootController
    let notificationController: NotificationContainerController
    
    private var scheduledOperChatWithPeerId: (PeerId, MessageId?, Bool)?
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
    
    private var isLocked: Bool = true
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
        return renderedTotalUnreadCount(accountManager: self.context.sharedContext.accountManager, postbox: self.context.account.postbox)
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
    
    init(sharedApplicationContext: SharedApplicationContext, mainWindow: Window1, watchManagerArguments: Signal<WatchManagerArguments?, NoError>, context: AccountContext, accountManager: AccountManager, showCallsTab: Bool, reinitializedNotificationSettings: @escaping () -> Void) {
        self.sharedApplicationContext = sharedApplicationContext
        
        setupLegacyComponents(context: context)
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        self.mainWindow = mainWindow
        self.lockedCoveringView = LockedWindowCoveringView(theme: presentationData.theme)
        
        self.context = context
        
        self.showCallsTab = showCallsTab
        
        self.notificationController = NotificationContainerController(context: context)
        
        self.mainWindow.previewThemeAccentColor = presentationData.theme.rootController.navigationBar.accentTextColor
        self.mainWindow.previewThemeDarkBlur = presentationData.theme.chatList.searchBarKeyboardColor == .dark
        self.mainWindow.setupVolumeControlStatusBarGraphics(presentationData.volumeControlStatusBarIcons.images)
        
        self.rootController = TelegramRootController(context: context)
        
        if KeyShortcutsController.isAvailable {
            let keyShortcutsController = KeyShortcutsController { [weak self] f in
                if let strongSelf = self {
                    if strongSelf.isLocked {
                        return
                    }
                    if let tabController = strongSelf.rootController.rootTabController {
                        let controller = tabController.controllers[tabController.selectedIndex]
                        if !f(controller) {
                            return
                        }
                        if let controller = strongSelf.rootController.topViewController as? ViewController {
                            if !f(controller) {
                                return
                            }
                        }
                    }
                    strongSelf.mainWindow.forEachViewController(f)
                }
            }
            context.keyShortcutsController = keyShortcutsController
        }
        
        let previousPasscodeState = Atomic<PasscodeState?>(value: nil)
        let passcodeStatusData = combineLatest(queue: Queue.mainQueue(), context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.presentationPasscodeSettings]), context.sharedContext.accountManager.accessChallengeData(), context.sharedContext.applicationBindings.applicationIsActive)
        let passcodeState = passcodeStatusData
        |> map { sharedData, accessChallengeDataView, isActive -> PasscodeState in
            let accessChallengeData = accessChallengeDataView.data
            let passcodeSettings = sharedData.entries[ApplicationSpecificSharedDataKeys.presentationPasscodeSettings] as? PresentationPasscodeSettings
            return PasscodeState(isActive: isActive, challengeData: accessChallengeData, autolockTimeout: passcodeSettings?.autolockTimeout, enableBiometrics: passcodeSettings?.enableBiometrics ?? false, biometricsDomainState: passcodeSettings?.biometricsDomainState)
        }
        self.passcodeStatusDisposable.set(passcodeState.start(next: { [weak self] updatedState in
            guard let strongSelf = self else {
                return
            }
            let previousState = previousPasscodeState.swap(updatedState)
            
            var updatedAutolockDeadline: Int32?
            if updatedState.isActive != previousState?.isActive, let autolockTimeout = updatedState.autolockTimeout {
                updatedAutolockDeadline = Int32(CFAbsoluteTimeGetCurrent()) + max(10, autolockTimeout)
            }
            
            var effectiveAutolockDeadline = updatedState.challengeData.autolockDeadline
            if updatedState.isActive {
            } else if previousState != nil && previousState!.autolockTimeout != updatedState.autolockTimeout {
                effectiveAutolockDeadline = updatedAutolockDeadline
            }
            
            if let previousState = previousState, previousState.isActive, !updatedState.isActive, effectiveAutolockDeadline != 0 {
                effectiveAutolockDeadline = updatedAutolockDeadline
            }
            
            var isLocked = false
            if isAccessLocked(data: updatedState.challengeData.withUpdatedAutolockDeadline(effectiveAutolockDeadline), at: Int32(CFAbsoluteTimeGetCurrent())) {
                isLocked = true
                updatedAutolockDeadline = 0
            }
            
            let isLockable: Bool
            switch updatedState.challengeData {
                case .none:
                    isLockable = false
                default:
                    isLockable = true
            }
            
            if previousState?.isActive != updatedState.isActive || isLocked != strongSelf.isLocked {
                if updatedAutolockDeadline != previousState?.challengeData.autolockDeadline {
                    let _ = (strongSelf.context.sharedContext.accountManager.transaction { transaction -> Void in
                        let data = transaction.getAccessChallengeData().withUpdatedAutolockDeadline(updatedAutolockDeadline)
                        transaction.setAccessChallengeData(data)
                    }).start()
                }
                
                strongSelf.isLocked = isLocked
                
                if isLocked {
                    if updatedState.isActive {
                        if strongSelf.passcodeController == nil {
                            let presentAnimated = previousState != nil && previousState!.isActive
                            
                            let biometrics: PasscodeEntryControllerBiometricsMode
                            if updatedState.enableBiometrics {
                                biometrics = .enabled(updatedState.biometricsDomainState)
                            } else {
                                biometrics = .none
                            }
                            
                            let controller = PasscodeEntryController(context: strongSelf.context, challengeData: updatedState.challengeData, biometrics: biometrics, arguments: PasscodeEntryControllerPresentationArguments(animated: presentAnimated, lockIconInitialFrame: { [weak self] in
                                if let strongSelf = self, let lockViewFrame = strongSelf.rootController.chatListController?.lockViewFrame {
                                    return lockViewFrame
                                } else {
                                    return CGRect()
                                }
                            }))
                            strongSelf.passcodeController = controller
                            
                            strongSelf.unlockedStatePromise.set(.single(false))
                            controller.presentationCompleted = {
                                strongSelf.rootController.view.isHidden = true
                                strongSelf.context.sharedContext.mediaManager.overlayMediaManager.controller?.view.isHidden = true
                                strongSelf.notificationController.view.isHidden = true
                            }
                            strongSelf.mainWindow.present(controller, on: .passcode)
                            
                            if !presentAnimated {
                                controller.requestBiometrics()
                            }
                        } else if previousState?.isActive != updatedState.isActive, updatedState.isActive, let passcodeController = strongSelf.passcodeController {
                            passcodeController.requestBiometrics()
                        }
                        strongSelf.updateCoveringViewSnaphot(false)
                        strongSelf.mainWindow.coveringView = nil
                    } else {
                        strongSelf.unlockedStatePromise.set(.single(false))
                        strongSelf.updateCoveringViewSnaphot(true)
                        strongSelf.mainWindow.coveringView = strongSelf.passcodeController == nil ? strongSelf.lockedCoveringView : nil
                        strongSelf.rootController.view.isHidden = true
                        strongSelf.context.sharedContext.mediaManager.overlayMediaManager.controller?.view.isHidden = true
                        strongSelf.notificationController.view.isHidden = true
                    }
                } else {
                    if !updatedState.isActive && isLockable {
                        strongSelf.updateCoveringViewSnaphot(true)
                        strongSelf.mainWindow.coveringView = strongSelf.passcodeController == nil ? strongSelf.lockedCoveringView : nil
                        strongSelf.rootController.view.isHidden = true
                        strongSelf.context.sharedContext.mediaManager.overlayMediaManager.controller?.view.isHidden = true
                        strongSelf.notificationController.view.isHidden = true
                    } else {
                        strongSelf.updateCoveringViewSnaphot(false)
                        strongSelf.mainWindow.coveringView = nil
                        strongSelf.rootController.view.isHidden = false
                        strongSelf.context.sharedContext.mediaManager.overlayMediaManager.controller?.view.isHidden = false
                        strongSelf.notificationController.view.isHidden = false
                        if strongSelf.rootController.rootTabController == nil {
                            strongSelf.rootController.addRootControllers(showCallsTab: strongSelf.showCallsTab)
                            if let (peerId, messageId, activateInput) = strongSelf.scheduledOperChatWithPeerId {
                                strongSelf.scheduledOperChatWithPeerId = nil
                                strongSelf.openChatWithPeerId(peerId: peerId, messageId: messageId, activateInput: activateInput)
                            }
                            
                            if let url = strongSelf.scheduledOpenExternalUrl {
                                strongSelf.scheduledOpenExternalUrl = nil
                                strongSelf.openUrl(url)
                            }
                            
                            if #available(iOS 10.0, *) {
                            } else {
                                DeviceAccess.authorizeAccess(to: .contacts, presentationData: strongSelf.context.sharedContext.currentPresentationData.with { $0 }, present: { c, a in
                                })
                            }
                            
                            if let passcodeController = strongSelf.passcodeController {
                                if let chatListController = strongSelf.rootController.chatListController {
                                    let _ = chatListController.ready.get().start(next: { [weak passcodeController] _ in
                                        if let strongSelf = self, let passcodeController = passcodeController, strongSelf.passcodeController === passcodeController {
                                            strongSelf.passcodeController = nil
                                            strongSelf.rootController.chatListController?.displayNode.recursivelyEnsureDisplaySynchronously(true)
                                            passcodeController.dismiss()
                                        }
                                    })
                                } else {
                                    strongSelf.passcodeController = nil
                                    strongSelf.rootController.chatListController?.displayNode.recursivelyEnsureDisplaySynchronously(true)
                                    passcodeController.dismiss()
                                }
                            }
                        } else {
                            if let passcodeController = strongSelf.passcodeController {
                                strongSelf.passcodeController = nil
                                passcodeController.dismiss()
                            }
                        }
                    }
                    
                    strongSelf.unlockedStatePromise.set(.single(true))
                }
            }
            if let tabsController = strongSelf.rootController.viewControllers.first as? TabBarController, !tabsController.controllers.isEmpty, tabsController.selectedIndex >= 0 {
                let controller = tabsController.controllers[tabsController.selectedIndex]
                let combinedReady = combineLatest(tabsController.ready.get(), controller.ready.get())
                |> map { $0 && $1 }
                |> filter { $0 }
                |> take(1)
                strongSelf.isReady.set(combinedReady)
            } else {
                strongSelf.isReady.set(.single(true))
            }
        }))
        
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
                if let settings = sharedData.entries[ApplicationSpecificSharedDataKeys.inAppNotificationSettings] as? InAppNotificationSettings {
                    let previousSettings = strongSelf.inAppNotificationSettings
                    strongSelf.inAppNotificationSettings = settings
                    if let previousSettings = previousSettings, previousSettings.displayNameOnLockscreen != settings.displayNameOnLockscreen {
                        reinitializedNotificationSettings()
                    }
                }
            }
        }))
        
        self.notificationMessagesDisposable.set((context.account.stateManager.notificationMessages
        |> deliverOn(Queue.mainQueue())).start(next: { [weak self] messageList in
            if let strongSelf = self, let (messages, _, notify) = messageList.last, let firstMessage = messages.first {
                if UIApplication.shared.applicationState == .active {
                    var chatIsVisible = false
                    if let topController = strongSelf.rootController.topViewController as? ChatController, topController.traceVisibility() {
                        if case .peer(firstMessage.id.peerId) = topController.chatLocation {
                            chatIsVisible = true
                        }/* else if case let .group(topGroupId) = topController.chatLocation, topGroupId == groupId {
                            chatIsVisible = true
                        }*/
                    }
                    
                    if !notify {
                        chatIsVisible = true
                    }
                    
                    if !chatIsVisible {
                        strongSelf.mainWindow.forEachViewController({ controller in
                            if let controller = controller as? ChatController, case .peer(firstMessage.id.peerId) = controller.chatLocation  {
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
                    
                    if !strongSelf.isLocked {
                        let isMuted = firstMessage.attributes.contains(where: { attribute in
                            if let attribute = attribute as? NotificationInfoMessageAttribute {
                                return attribute.flags.contains(.muted)
                            } else {
                                return false
                            }
                        })
                        if !isMuted {
                            if inAppNotificationSettings.playSounds {
                                serviceSoundManager.playIncomingMessageSound()
                            }
                            if inAppNotificationSettings.vibrate {
                                serviceSoundManager.playVibrationSound()
                            }
                        }
                    }
                    
                    if chatIsVisible {
                        return
                    }
                    
                    if inAppNotificationSettings.displayPreviews {
                       let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                        strongSelf.notificationController.enqueue(ChatMessageNotificationItem(context: strongSelf.context, strings: presentationData.strings, nameDisplayOrder: presentationData.nameDisplayOrder, messages: messages, tapAction: {
                            if let strongSelf = self {
                                var foundOverlay = false
                                strongSelf.mainWindow.forEachViewController({ controller in
                                    if isOverlayControllerForChatNotificationOverlayPresentation(controller) {
                                        foundOverlay = true
                                        return false
                                    }
                                    return true
                                })
                                
                                if foundOverlay {
                                    return true
                                }
                                
                                if let topController = strongSelf.rootController.topViewController as? ViewController, isInlineControllerForChatNotificationOverlayPresentation(topController) {
                                    return true
                                }
                                
                                if let topController = strongSelf.rootController.topViewController as? ChatController, case .peer(firstMessage.id.peerId) = topController.chatLocation {
                                    strongSelf.notificationController.removeItemsWithGroupingKey(firstMessage.id.peerId)
                                    
                                    return false
                                }
                                
                                for controller in strongSelf.rootController.viewControllers {
                                    if let controller = controller as? ChatController, case .peer(firstMessage.id.peerId) = controller.chatLocation  {
                                        return true
                                    }
                                }
                                
                                strongSelf.notificationController.removeItemsWithGroupingKey(firstMessage.id.peerId)
                                
                                navigateToChatController(navigationController: strongSelf.rootController, context: strongSelf.context, chatLocation: .peer(firstMessage.id.peerId))
                            }
                            return false
                        }, expandAction: { expandData in
                            if let strongSelf = self {
                                let chatController = ChatController(context: strongSelf.context, chatLocation: .peer(firstMessage.id.peerId), mode: .overlay)
                                (strongSelf.rootController.viewControllers.last as? ViewController)?.present(chatController, in: .window(.root), with: ChatControllerOverlayPresentationData(expandData: expandData()))
                            }
                        }))
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
                let controller = TermsOfServiceController(theme: TermsOfServiceControllerTheme(presentationTheme: presentationData.theme), strings: presentationData.strings, text: termsOfServiceUpdate.text, entities: termsOfServiceUpdate.entities, ageConfirmation: termsOfServiceUpdate.ageConfirmation, signingUp: false, accept: { proccedBot in
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
                    let _ = (acceptTermsOfService(account: strongSelf.context.account, id: termsOfServiceUpdate.id)
                    |> deliverOnMainQueue).start(completed: {
                        controller?.dismiss()
                        if let strongSelf = self, let botName = botName {
                            strongSelf.termsOfServiceProceedToBotDisposable.set((resolvePeerByName(account: strongSelf.context.account, name: botName, ageLimit: 10) |> take(1) |> deliverOnMainQueue).start(next: { peerId in
                                if let strongSelf = self, let peerId = peerId {
                                    self?.rootController.pushViewController(ChatController(context: strongSelf.context, chatLocation: .peer(peerId), messageId: nil))
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
                    let _ = (deleteAccount(account: strongSelf.context.account)
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
                (strongSelf.rootController.viewControllers.last as? ViewController)?.present(controller, in: .window(.root))
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
                                    DeviceAccess.authorizeAccess(to: .contacts, presentationData: context.sharedContext.currentPresentationData.with { $0 }) { result in
                                        if result {
                                            splitTest.addEvent(.ContactsAllowed)
                                        } else {
                                            splitTest.addEvent(.ContactsDenied)
                                        }
                                        permissionsPosition.set(position + 1)
                                        ApplicationSpecificNotice.setPermissionWarning(accountManager: context.sharedContext.accountManager, permission: .contacts, value: 0)
                                    }
                                case .notifications:
                                    splitTest.addEvent(.NotificationsRequest)
                                    DeviceAccess.authorizeAccess(to: .notifications, registerForNotifications: { result in
                                        context.sharedContext.applicationBindings.registerForNotifications(result)
                                    }) { result in
                                        if result {
                                            splitTest.addEvent(.NotificationsAllowed)
                                        } else {
                                            splitTest.addEvent(.NotificationsDenied)
                                        }
                                        permissionsPosition.set(position + 1)
                                        ApplicationSpecificNotice.setPermissionWarning(accountManager: context.sharedContext.accountManager, permission: .notifications, value: 0)
                                    }
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
                                    }) { result in
                                        permissionsPosition.set(position + 1)
                                    }
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
            let settings: ContactsSettings = (preferences.values[PreferencesKeys.contactsSettings] as? ContactsSettings) ?? .defaultSettings
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
                    strongSelf.mainWindow.previewThemeDarkBlur = presentationData.theme.chatList.searchBarKeyboardColor == .dark
                    strongSelf.lockedCoveringView.updateTheme(presentationData.theme)
                    strongSelf.rootController.updateTheme(NavigationControllerTheme(presentationTheme: presentationData.theme))
                }
            }
        })
        
        let showCallsTabSignal = context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.callListSettings])
        |> map { sharedData -> Bool in
            var value = true
            if let settings = sharedData.entries[ApplicationSpecificSharedDataKeys.callListSettings] as? CallListSettings {
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
            
            let watchManager = WatchManager(arguments: arguments)
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
                        if let controller = strongSelf.rootController.viewControllers.last as? ChatController, case .peer(messageId.peerId) = controller.chatLocation  {
                            chatIsVisible = true
                        }
                        
                        let navigateToMessage = {
                            navigateToChatController(navigationController: strongSelf.rootController, context: strongSelf.context, chatLocation: .peer(messageId.peerId), messageId: messageId)
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
    }
    
    func openChatWithPeerId(peerId: PeerId, messageId: MessageId? = nil, activateInput: Bool = false) {
        var visiblePeerId: PeerId?
        if let controller = self.rootController.topViewController as? ChatController, case let .peer(peerId) = controller.chatLocation {
            visiblePeerId = peerId
        }
        
        if visiblePeerId != peerId || messageId != nil {
            if self.rootController.rootTabController != nil {
                navigateToChatController(navigationController: self.rootController, context: self.context, chatLocation: .peer(peerId), messageId: messageId, activateInput: activateInput)
            } else {
                self.scheduledOperChatWithPeerId = (peerId, messageId, activateInput)
            }
        }
    }
    
    func openUrl(_ url: URL) {
        if self.rootController.rootTabController != nil {
            let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
            openExternalUrl(context: self.context, url: url.absoluteString, presentationData: presentationData, navigationController: self.rootController, dismissInput: { [weak self] in
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
            })?.applyScreenshotEffect()
            self.lockedCoveringView.updateSnapshot(image)
        } else {
            self.lockedCoveringView.updateSnapshot(nil)
        }
    }
}
