import UIKit
import Display
import TelegramCore
import TelegramUI
import SwiftSignalKit
import Postbox

private var accountCache: (Account, AccountManager)?

private var installedSharedLogger = false

private func setupSharedLogger(_ path: String) {
    if !installedSharedLogger {
        installedSharedLogger = true
        Logger.setSharedLogger(Logger(basePath: path))
    }
}

private enum ShareAuthorizationError {
    case unauthorized
}

@objc(ShareRootController)
class ShareRootController: UIViewController {
    private var mainWindow: Window1?
    private var currentShareController: ShareController?
    private var currentPasscodeController: ViewController?
    
    private var shouldBeMaster = Promise<Bool>()
    private let disposable = MetaDisposable()
    private var observer1: AnyObject?
    private var observer2: AnyObject?
    
    deinit {
        self.disposable.dispose()
        self.shouldBeMaster.set(.single(false))
        if let observer = self.observer1 {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = self.observer2 {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    override func loadView() {
        telegramUIDeclareEncodables()
        
        super.loadView()
        
        self.view.backgroundColor = nil
        self.view.isOpaque = false
        
        if #available(iOSApplicationExtension 8.2, *) {
            self.observer1 = NotificationCenter.default.addObserver(forName: NSNotification.Name.NSExtensionHostDidBecomeActive, object: nil, queue: nil, using: { [weak self] _ in
                if let strongSelf = self {
                    strongSelf.shouldBeMaster.set(.single(true))
                }
            })
            
            self.observer2 = NotificationCenter.default.addObserver(forName: NSNotification.Name.NSExtensionHostWillResignActive, object: nil, queue: nil, using: { [weak self] _ in
                if let strongSelf = self {
                    strongSelf.shouldBeMaster.set(.single(false))
                }
            })
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        
        
        self.shouldBeMaster.set(.single(true))
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        self.disposable.dispose()
        self.shouldBeMaster.set(.single(false))
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        if self.mainWindow == nil {
            let mainWindow = Window1(hostView: childWindowHostView(parent: self.view), statusBarHost: nil)
            mainWindow.hostView.eventView.backgroundColor = UIColor.clear
            mainWindow.hostView.eventView.isHidden = false
            self.mainWindow = mainWindow
            
            self.view.addSubview(mainWindow.hostView.containerView)
            mainWindow.hostView.containerView.frame = self.view.bounds
            
            let appBundleIdentifier = Bundle.main.bundleIdentifier!
            guard let lastDotRange = appBundleIdentifier.range(of: ".", options: [.backwards]) else {
                return
            }
            
            let apiId: Int32 = BuildConfig.shared().apiId
            let languagesCategory = "ios"
            
            let appGroupName = "group.\(appBundleIdentifier[..<lastDotRange.lowerBound])"
            let maybeAppGroupUrl = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupName)
            
            guard let appGroupUrl = maybeAppGroupUrl else {
                return
            }
            
            let rootPath = rootPathForBasePath(appGroupUrl.path)
            performAppGroupUpgrades(appGroupPath: appGroupUrl.path, rootPath: rootPath)
            
            TempBox.initializeShared(basePath: rootPath, processType: "share", launchSpecificId: arc4random64())
            
            let logsPath = rootPath + "/share-logs"
            let _ = try? FileManager.default.createDirectory(atPath: logsPath, withIntermediateDirectories: true, attributes: nil)
            
            setupSharedLogger(logsPath)
            
            let applicationBindings = TelegramApplicationBindings(isMainApp: false, openUrl: { _ in
            }, openUniversalUrl: { _, completion in
                completion.completion(false)
                return
            }, canOpenUrl: { _ in
                return false
            }, getTopWindow: {
                return nil
            }, displayNotification: { _ in
                
            }, applicationInForeground: .single(false), applicationIsActive: .single(false), clearMessageNotifications: { _ in
            }, pushIdleTimerExtension: {
                return EmptyDisposable
            }, openSettings: {}, openAppStorePage: {}, getWindowHost: {
                return nil
            }, presentNativeController: { _ in
            }, dismissNativeController: {
            })
            
            let account: Signal<(Account, AccountManager), ShareAuthorizationError>
            if let accountCache = accountCache {
                account = .single(accountCache)
            } else {
                let appVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "unknown"
                
                initializeAccountManagement()
                account = accountManager(basePath: rootPath + "/accounts-metadata")
                |> take(1)
                |> mapToSignal { accountManager -> Signal<(AccountManager, LoggingSettings), NoError> in
                    return accountManager.transaction { transaction -> (AccountManager, LoggingSettings) in
                        return (accountManager, transaction.getSharedData(SharedDataKeys.loggingSettings) as? LoggingSettings ?? LoggingSettings.defaultSettings)
                    }
                }
                |> introduceError(ShareAuthorizationError.self)
                |> mapToSignal { accountManager, loggingSettings -> Signal<(Account, AccountManager), ShareAuthorizationError> in
                    Logger.shared.logToFile = loggingSettings.logToFile
                    Logger.shared.logToConsole = loggingSettings.logToConsole
                    
                    Logger.shared.redactSensitiveData = loggingSettings.redactSensitiveData
                    
                    return currentAccount(allocateIfNotExists: false, networkArguments: NetworkInitializationArguments(apiId: apiId, languagesCategory: languagesCategory, appVersion: appVersion), supplementary: true, manager: accountManager, rootPath: rootPath, beginWithTestingEnvironment: false, auxiliaryMethods: telegramAccountAuxiliaryMethods)
                     |> introduceError(ShareAuthorizationError.self) |> mapToSignal { account -> Signal<(Account, AccountManager), ShareAuthorizationError> in
                        if let account = account {
                            switch account {
                                case .upgrading:
                                    return .complete()
                                case let .authorized(account):
                                    return .single((account, accountManager))
                                case .unauthorized:
                                    return .fail(.unauthorized)
                            }
                        } else {
                            return .complete()
                        }
                    }
                }
                |> take(1)
            }
            
            let preferencesKey: PostboxViewKey = .preferences(keys: Set<ValueBoxKey>([ApplicationSpecificPreferencesKeys.presentationPasscodeSettings]))
            
            let shouldBeMaster = self.shouldBeMaster
            let applicationInterface = account
            |> mapToSignal { account, accountManager -> Signal<(Account, PostboxAccessChallengeData), ShareAuthorizationError> in
                return combineLatest(currentPresentationDataAndSettings(postbox: account.postbox), account.postbox.combinedView(keys: [.accessChallengeData, preferencesKey]) |> take(1))
                |> deliverOnMainQueue
                |> introduceError(ShareAuthorizationError.self)
                |> map { dataAndSettings, data -> (Account, PostboxAccessChallengeData) in
                    accountCache = (account, accountManager)
                    account.applicationContext = TelegramApplicationContext(applicationBindings: applicationBindings, accountManager: accountManager, account: account, initialPresentationDataAndSettings: dataAndSettings, postbox: account.postbox)
                    return (account, (data.views[.accessChallengeData] as! AccessChallengeDataView).data)
                }
            }
            |> afterNext { account, _ in
                setupAccount(account)
            }
            |> deliverOnMainQueue
            |> afterNext { [weak self] account, accessChallengeData in
                updateLegacyComponentsAccount(account)
                initializeLegacyComponents(application: nil, currentSizeClassGetter: { return .compact }, currentHorizontalClassGetter: { return .compact }, documentsPath: "", currentApplicationBounds: { return CGRect() }, canOpenUrl: { _ in return false}, openUrl: { _ in })
                
                let displayShare: () -> Void = {
                    var cancelImpl: (() -> Void)?
                    
                    let requestUserInteraction: ([UnpreparedShareItemContent]) -> Signal<[PreparedShareItemContent], NoError> = { content in
                        return Signal { [weak self] subscriber in
                            switch content[0] {
                            case let .contact(data):
                                let controller = deviceContactInfoController(account: account, subject: .filter(peer: nil, contactId: nil, contactData: data, completion: { peer, contactData in
                                    let phone = contactData.basicData.phoneNumbers[0].value
                                    if let vCardData = contactData.serializedVCard() {
                                        subscriber.putNext([.media(.media(.standalone(media: TelegramMediaContact(firstName: contactData.basicData.firstName, lastName: contactData.basicData.lastName, phoneNumber: phone, peerId: nil, vCardData: vCardData))))])
                                    }
                                    subscriber.putCompletion()
                                }), cancelled: {
                                    cancelImpl?()
                                })
                                
                                if let strongSelf = self, let window = strongSelf.mainWindow {
                                    controller.presentationArguments = ViewControllerPresentationArguments(presentationAnimation: .modalSheet)
                                    window.present(controller, on: .root)
                                }
                                break
                            }
                            
                            return ActionDisposable {
                            }
                        } |> runOn(Queue.mainQueue())
                    }
                    
                    let sentItems: ([PeerId], [PreparedShareItemContent]) -> Signal<ShareControllerExternalStatus, NoError> = { peerIds, contents in
                        let sentItems = sentShareItems(account: account, to: peerIds, items: contents)
                        |> `catch` { _ -> Signal<
                            Float, NoError> in
                            return .complete()
                        }
                        return sentItems
                        |> map { value -> ShareControllerExternalStatus in
                            return .progress(value)
                        }
                        |> then(.single(.done))
                    }
                    
                    let shareController = ShareController(account: account, subject: .fromExternal({ peerIds, additionalText in
                        if let strongSelf = self, let inputItems = strongSelf.extensionContext?.inputItems, !inputItems.isEmpty, !peerIds.isEmpty {
                            let rawSignals = TGItemProviderSignals.itemSignals(forInputItems: inputItems)!
                            return preparedShareItems(account: account, to: peerIds[0], dataItems: rawSignals, additionalText: additionalText)
                            |> map(Optional.init)
                            |> `catch` { _ -> Signal<PreparedShareItems?, NoError> in
                                return .single(nil)
                            }
                            |> mapToSignal { state -> Signal<ShareControllerExternalStatus, NoError> in
                                guard let state = state else {
                                    return .single(.done)
                                }
                                switch state {
                                    case .preparing:
                                        return .single(.preparing)
                                    case let .progress(value):
                                        return .single(.progress(value))
                                    case let .userInteractionRequired(value):
                                        return requestUserInteraction(value)
                                        |> mapToSignal { contents -> Signal<ShareControllerExternalStatus, NoError> in
                                                return sentItems(peerIds, contents)
                                        }
                                    case let .done(contents):
                                        return sentItems(peerIds, contents)
                                }
                            }
                        } else {
                            return .single(.done)
                        }
                    }), externalShare: false)
                    shareController.presentationArguments = ViewControllerPresentationArguments(presentationAnimation: .modalSheet)
                    shareController.dismissed = {
                        self?.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
                    }
                    
                    cancelImpl = { [weak shareController] in
                        shareController?.dismiss()
                    }
                    
                    if let strongSelf = self {
                        if let currentShareController = strongSelf.currentShareController {
                            currentShareController.dismiss()
                        }
                        strongSelf.currentShareController = shareController
                        strongSelf.mainWindow?.present(shareController, on: .root)
                    }
                    
                    account.resetStateManagement()
                    account.network.shouldKeepConnection.set(shouldBeMaster.get()
                    |> map({ $0 }))
                }
                
                let _ = passcodeEntryController(account: account, animateIn: true, completion: { value in
                    if value {
                        displayShare()
                    } else {
                        Queue.mainQueue().after(0.5, {
                            self?.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
                        })
                    }
                }).start(next: { controller in
                    guard let strongSelf = self, let controller = controller else {
                        return
                    }
                    
                    if let currentPasscodeController = strongSelf.currentPasscodeController {
                        currentPasscodeController.dismiss()
                    }
                    strongSelf.currentPasscodeController = controller
                    strongSelf.mainWindow?.present(controller, on: .root)
                })
                
                /*var attemptData: TGPasscodeEntryAttemptData?
                if let attempts = accessChallengeData.attempts {
                    attemptData = TGPasscodeEntryAttemptData(numberOfInvalidAttempts: Int(attempts.count), dateOfLastInvalidAttempt: Double(attempts.timestamp))
                }
                let mode: TGPasscodeEntryControllerMode
                switch accessChallengeData {
                    case .none:
                        displayShare()
                        return
                    case .numericalPassword:
                        mode = TGPasscodeEntryControllerModeVerifySimple
                    case .plaintextPassword:
                        mode = TGPasscodeEntryControllerModeVerifyComplex
                }
                let presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
                
                let legacyController = LegacyController(presentation: LegacyControllerPresentation.modal(animateIn: true), theme: presentationData.theme)
                let controller = TGPasscodeEntryController(context: legacyController.context, style: TGPasscodeEntryControllerStyleDefault, mode: mode, cancelEnabled: true, allowTouchId: false, attemptData: attemptData, completion: { value in
                    if value != nil {
                        displayShare()
                    } else {
                        self?.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
                    }
                })!
                controller.checkCurrentPasscode = { value in
                    if let value = value {
                        switch accessChallengeData {
                            case .none:
                                return true
                            case let .numericalPassword(code, _, _):
                                return value == code
                            case let .plaintextPassword(code, _, _):
                                return value == code
                        }
                    } else {
                        return false
                    }
                }
                controller.updateAttemptData = { attemptData in
                    let _ = account.postbox.transaction({ transaction -> Void in
                        var attempts: AccessChallengeAttempts?
                        if let attemptData = attemptData {
                            attempts = AccessChallengeAttempts(count: Int32(attemptData.numberOfInvalidAttempts), timestamp: Int32(attemptData.dateOfLastInvalidAttempt))
                        }
                        var data = transaction.getAccessChallengeData()
                        switch data {
                            case .none:
                                break
                            case let .numericalPassword(value, timeout, _):
                                data = .numericalPassword(value: value, timeout: timeout, attempts: attempts)
                            case let .plaintextPassword(value, timeout, _):
                                data = .plaintextPassword(value: value, timeout: timeout, attempts: attempts)
                        }
                        transaction.setAccessChallengeData(data)
                    }).start()
                }
                /*controller.touchIdCompletion = {
                    let _ = (account.postbox.transaction { transaction -> Void in
                        let data = transaction.getAccessChallengeData().withUpdatedAutolockDeadline(nil)
                        transaction.setAccessChallengeData(data)
                    }).start()
                }*/
                
                legacyController.bind(controller: controller)
                legacyController.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .portrait, compactSize: .portrait)
                legacyController.statusBar.statusBarStyle = .White
                */
                
            }
            
            self.disposable.set(applicationInterface.start(next: { _, _ in }, error: { [weak self] error in
                guard let strongSelf = self else {
                    return
                }
                let presentationData = defaultPresentationData()
                let controller = standardTextAlertController(theme: AlertControllerTheme(presentationTheme: presentationData.theme), title: presentationData.strings.Share_AuthTitle, text: presentationData.strings.Share_AuthDescription, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {
                    self?.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
                })])
                strongSelf.mainWindow?.present(controller, on: .root)
            }, completed: {}))
        }
    }
}
