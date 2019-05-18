import UIKit
import UserNotifications
import UserNotificationsUI
import Display
import TelegramCore
import TelegramUI
import SwiftSignalKit
import Postbox

private enum NotificationContentAuthorizationError {
    case unauthorized
}

private var sharedAccountContext: SharedAccountContext?

private var installedSharedLogger = false

private func setupSharedLogger(_ path: String) {
    if !installedSharedLogger {
        installedSharedLogger = true
        Logger.setSharedLogger(Logger(basePath: path))
    }
}

private func parseFileLocationResource(_ dict: [AnyHashable: Any]) -> TelegramMediaResource? {
    guard let datacenterId = dict["datacenterId"] as? Int32 else {
        return nil
    }
    guard let volumeId = dict["volumeId"] as? Int64 else {
        return nil
    }
    guard let localId = dict["localId"] as? Int32 else {
        return nil
    }
    guard let secret = dict["secret"] as? Int64 else {
        return nil
    }
    var fileReference: Data?
    if let fileReferenceString = dict["fileReference"] as? String {
        fileReference = dataWithHexString(fileReferenceString)
    }
    return CloudFileMediaResource(datacenterId: Int(datacenterId), volumeId: volumeId, localId: localId, secret: secret, size: nil, fileReference: fileReference)
}

@objc(NotificationViewController)
class NotificationViewController: UIViewController, UNNotificationContentExtension {
    private let imageNode = TransformImageNode()
    private var imageInfo: (isSticker: Bool, dimensions: CGSize)?
    
    private let applyDisposable = MetaDisposable()
    private let fetchedDisposable = MetaDisposable()
    
    private var accountsPath: String?
    
    deinit {
        self.applyDisposable.dispose()
        self.fetchedDisposable.dispose()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.addSubnode(self.imageNode)
        
        let appBundleIdentifier = Bundle.main.bundleIdentifier!
        guard let lastDotRange = appBundleIdentifier.range(of: ".", options: [.backwards]) else {
            return
        }
        
        let baseAppBundleId = String(appBundleIdentifier[..<lastDotRange.lowerBound])
        
        let buildConfig = BuildConfig(baseAppBundleId: baseAppBundleId)
        
        let apiId: Int32 = buildConfig.apiId
        let languagesCategory = "ios"
        
        let appGroupName = "group.\(baseAppBundleId)"
        let maybeAppGroupUrl = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupName)
        
        guard let appGroupUrl = maybeAppGroupUrl else {
            return
        }
        
        let rootPath = rootPathForBasePath(appGroupUrl.path)
        performAppGroupUpgrades(appGroupPath: appGroupUrl.path, rootPath: rootPath)
        
        TempBox.initializeShared(basePath: rootPath, processType: "notification-content", launchSpecificId: arc4random64())
        
        let logsPath = rootPath + "/notificationcontent-logs"
        let _ = try? FileManager.default.createDirectory(atPath: logsPath, withIntermediateDirectories: true, attributes: nil)
        
        setupSharedLogger(logsPath)
        
        accountsPath = rootPath
        
        if sharedAccountContext == nil {
            initializeAccountManagement()
            let accountManager = AccountManager(basePath: rootPath + "/accounts-metadata")
            
            var initialPresentationDataAndSettings: InitialPresentationDataAndSettings?
            let semaphore = DispatchSemaphore(value: 0)
            let _ = currentPresentationDataAndSettings(accountManager: accountManager).start(next: { value in
                initialPresentationDataAndSettings = value
                semaphore.signal()
            })
            semaphore.wait()
            
            let applicationBindings = TelegramApplicationBindings(isMainApp: false, containerPath: appGroupUrl.path, appSpecificScheme: buildConfig.appSpecificUrlScheme, openUrl: { _ in
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
            }, openSettings: {}, openAppStorePage: {}, registerForNotifications: { _ in }, requestSiriAuthorization: { _ in }, siriAuthorization: { return .notDetermined }, getWindowHost: {
                return nil
            }, presentNativeController: { _ in
            }, dismissNativeController: {
            }, getAlternateIconName: {
                return nil
            }, requestSetAlternateIconName: { _, f in
                f(false)
            })
            
            let appVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "unknown"
            
            let deviceSpecificEncryptionParameters = BuildConfig.deviceSpecificEncryptionParameters(rootPath, baseAppBundleId: baseAppBundleId)
            let encryptionParameters = ValueBoxEncryptionParameters(forceEncryptionIfNoSet: false, key: ValueBoxEncryptionParameters.Key(data: deviceSpecificEncryptionParameters.key)!, salt: ValueBoxEncryptionParameters.Salt(data: deviceSpecificEncryptionParameters.salt)!)
            
            sharedAccountContext = SharedAccountContext(mainWindow: nil, basePath: rootPath, encryptionParameters: encryptionParameters, accountManager: accountManager, applicationBindings: applicationBindings, initialPresentationDataAndSettings: initialPresentationDataAndSettings!, networkArguments: NetworkInitializationArguments(apiId: apiId, languagesCategory: languagesCategory, appVersion: appVersion, voipMaxLayer: 0, appData: buildConfig.bundleData), rootPath: rootPath, legacyBasePath: nil, legacyCache: nil, apsNotificationToken: .never(), voipNotificationToken: .never(), setNotificationCall: { _ in }, navigateToChat: { _, _, _ in })
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    func didReceive(_ notification: UNNotification) {
        guard let accountsPath = self.accountsPath else {
            return
        }
        
        if let accountIdValue = notification.request.content.userInfo["accountId"] as? Int64, let peerIdValue = notification.request.content.userInfo["peerId"] as? Int64, let messageIdNamespace = notification.request.content.userInfo["messageId.namespace"] as? Int32, let messageIdId = notification.request.content.userInfo["messageId.id"] as? Int32, let mediaDataString = notification.request.content.userInfo["media"] as? String, let mediaData = Data(base64Encoded: mediaDataString), let media = parseMediaData(data: mediaData) {
            let messageId = MessageId(peerId: PeerId(peerIdValue), namespace: messageIdNamespace, id: messageIdId)
            
            if let image = media as? TelegramMediaImage, let thumbnailRepresentation = imageRepresentationLargerThan(image.representations, size: CGSize(width: 120.0, height: 120.0)), let largestRepresentation = largestImageRepresentation(image.representations) {
                let dimensions = largestRepresentation.dimensions
                let fittedSize = dimensions.fitted(CGSize(width: self.view.bounds.width, height: 1000.0))
                self.view.frame = CGRect(origin: self.view.frame.origin, size: fittedSize)
                self.preferredContentSize = fittedSize
                
                self.imageInfo = (false, dimensions)
                self.updateImageLayout(boundingSize: self.view.bounds.size)
                
                let mediaBoxPath = accountsPath + "/" + accountRecordIdPathName(AccountRecordId(rawValue: accountIdValue)) + "/postbox/media"
                
                if let data = try? Data(contentsOf: URL(fileURLWithPath: mediaBoxPath + "/\(largestRepresentation.resource.id.uniqueId)"), options: .mappedRead) {
                    self.imageNode.setSignal(chatMessagePhotoInternal(photoData: .single((nil, data, true)))
                    |> map { $0.1 })
                    return
                }
                
                if let data = try? Data(contentsOf: URL(fileURLWithPath: mediaBoxPath + "/\(thumbnailRepresentation.resource.id.uniqueId)"), options: .mappedRead) {
                    self.imageNode.setSignal(chatMessagePhotoInternal(photoData: .single((data, nil, false)))
                    |> map { $0.1 })
                }
                
                guard let sharedAccountContext = sharedAccountContext else {
                    return
                }
                
                self.applyDisposable.set((sharedAccountContext.activeAccounts
                |> map { _, accounts, _ -> Account? in
                    return accounts.first(where: { $0.0 == AccountRecordId(rawValue: accountIdValue) })?.1
                }
                |> filter { account in
                    return account != nil
                }
                |> take(1)
                |> mapToSignal { account -> Signal<(Account, ImageMediaReference?), NoError> in
                    guard let account = account else {
                        return .complete()
                    }
                    return account.postbox.messageAtId(messageId)
                    |> take(1)
                    |> map { message in
                        var imageReference: ImageMediaReference?
                        if let message = message {
                            for media in message.media {
                                if let image = media as? TelegramMediaImage {
                                    imageReference = .message(message: MessageReference(message), media: image)
                                }
                            }
                        } else {
                            imageReference = .standalone(media: image)
                        }
                        return (account, imageReference)
                    }
                }
                |> deliverOnMainQueue).start(next: { [weak self] accountAndImage in
                    guard let strongSelf = self else {
                        return
                    }
                    if let imageReference = accountAndImage.1 {
                        strongSelf.imageNode.setSignal(chatMessagePhoto(postbox: accountAndImage.0.postbox, photoReference: imageReference))
                        
                        accountAndImage.0.network.shouldExplicitelyKeepWorkerConnections.set(.single(true))
                        strongSelf.fetchedDisposable.set(standaloneChatMessagePhotoInteractiveFetched(account: accountAndImage.0, photoReference: imageReference).start())
                    }
                }))
            } else if let file = media as? TelegramMediaFile, let dimensions = file.dimensions {
                guard let sharedAccountContext = sharedAccountContext else {
                    return
                }
                
                let fittedSize = dimensions.fitted(CGSize(width: min(256.0, self.view.bounds.width), height: 256.0))
                self.view.frame = CGRect(origin: self.view.frame.origin, size: fittedSize)
                self.preferredContentSize = fittedSize
                
                self.imageInfo = (true, dimensions)
                self.updateImageLayout(boundingSize: self.view.bounds.size)
                
                self.applyDisposable.set((sharedAccountContext.activeAccounts
                |> map { _, accounts, _ -> Account? in
                    return accounts.first(where: { $0.0 == AccountRecordId(rawValue: accountIdValue) })?.1
                }
                |> filter { account in
                    return account != nil
                }
                |> take(1)
                |> mapToSignal { account -> Signal<(Account, FileMediaReference?), NoError> in
                    guard let account = account else {
                        return .complete()
                    }
                    return account.postbox.messageAtId(messageId)
                    |> take(1)
                    |> map { message in
                        var fileReference: FileMediaReference?
                        if let message = message {
                            for media in message.media {
                                if let file = media as? TelegramMediaFile {
                                    fileReference = .message(message: MessageReference(message), media: file)
                                }
                            }
                        } else {
                            fileReference = .standalone(media: file)
                        }
                        return (account, fileReference)
                    }
                }
                |> deliverOnMainQueue).start(next: { [weak self] accountAndImage in
                    guard let strongSelf = self else {
                        return
                    }
                    if let fileReference = accountAndImage.1 {
                        if file.isSticker {
                            strongSelf.imageNode.setSignal(chatMessageSticker(account: accountAndImage.0, file: file, small: false))
                            
                            accountAndImage.0.network.shouldExplicitelyKeepWorkerConnections.set(.single(true))
                            strongSelf.fetchedDisposable.set(freeMediaFileInteractiveFetched(account: accountAndImage.0, fileReference: fileReference).start())
                        }
                    }
                }))
            }
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        self.updateImageLayout(boundingSize: size)
    }
    
    private func updateImageLayout(boundingSize: CGSize) {
        if let (isSticker, dimensions) = self.imageInfo {
            let makeLayout = self.imageNode.asyncLayout()
            let fittedSize: CGSize
            if isSticker {
                fittedSize = dimensions.fitted(CGSize(width: min(256.0, boundingSize.width), height: 256.0))
            } else {
                fittedSize = dimensions.fitted(CGSize(width: boundingSize.width, height: 1000.0))
            }
            let apply = makeLayout(TransformImageArguments(corners: ImageCorners(radius: 0.0), imageSize: fittedSize, boundingSize: fittedSize, intrinsicInsets: UIEdgeInsets()))
            apply()
            let displaySize = isSticker ? fittedSize : boundingSize
            self.imageNode.frame = CGRect(origin: CGPoint(x: floor((boundingSize.width - displaySize.width) / 2.0), y: 0.0), size: displaySize)
        }
    }
}
