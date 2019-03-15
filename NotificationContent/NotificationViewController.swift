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

class NotificationViewController: UIViewController, UNNotificationContentExtension {
    private let imageNode = TransformImageNode()
    private var imageDimensions: CGSize?
    
    private let applyDisposable = MetaDisposable()
    private let fetchedDisposable = MetaDisposable()
    
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
        
        let apiId: Int32 = BuildConfig.shared().apiId
        let languagesCategory = "ios"
        
        let appGroupName = "group.\(appBundleIdentifier[..<lastDotRange.lowerBound])"
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
            
            let applicationBindings = TelegramApplicationBindings(isMainApp: false, containerPath: appGroupUrl.path, appSpecificScheme: BuildConfig.shared().appSpecificUrlScheme, openUrl: { _ in
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
            })
            
            let appVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "unknown"
            
            sharedAccountContext = SharedAccountContext(mainWindow: nil, basePath: rootPath,  accountManager: accountManager, applicationBindings: applicationBindings, initialPresentationDataAndSettings: initialPresentationDataAndSettings!, networkArguments: NetworkInitializationArguments(apiId: apiId, languagesCategory: languagesCategory, appVersion: appVersion, voipMaxLayer: 0, appData: BuildConfig.shared().bundleData), rootPath: rootPath, legacyBasePath: nil, legacyCache: nil, apsNotificationToken: .never(), voipNotificationToken: .never(), setNotificationCall: { _ in }, navigateToChat: { _, _, _ in })
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    func didReceive(_ notification: UNNotification) {
        if let accountIdValue = notification.request.content.userInfo["accountId"] as? Int64, let peerIdValue = notification.request.content.userInfo["peerId"] as? Int64, let messageIdNamespace = notification.request.content.userInfo["messageId.namespace"] as? Int32, let messageIdId = notification.request.content.userInfo["messageId.id"] as? Int32, let dict = notification.request.content.userInfo["mediaInfo"] as? [String: Any] {
            let messageId = MessageId(peerId: PeerId(peerIdValue), namespace: messageIdNamespace, id: messageIdId)
            
            if let imageInfo = dict["image"] as? [String: Any] {
                guard let width = imageInfo["width"] as? Int, let height = imageInfo["height"] as? Int else {
                    return
                }
                guard let thumbnailInfo = imageInfo["thumbnail"] as? [String: Any] else {
                    return
                }
                guard let fullSizeInfo = imageInfo["fullSize"] as? [String: Any] else {
                    return
                }
                
                let dimensions = CGSize(width: CGFloat(width), height: CGFloat(height))
                let fittedSize = dimensions.fitted(CGSize(width: self.view.bounds.width, height: 1000.0))
                self.view.frame = CGRect(origin: self.view.frame.origin, size: fittedSize)
                self.preferredContentSize = fittedSize
                
                self.imageDimensions = dimensions
                self.updateImageLayout(boundingSize: self.view.bounds.size)
                
                if let path = fullSizeInfo["path"] as? String, let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: .mappedRead) {
                    self.imageNode.setSignal(chatMessagePhotoInternal(photoData: .single((nil, data, true)))
                    |> map { $0.1 })
                    return
                }
                
                if let path = thumbnailInfo["path"] as? String, let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: .mappedRead) {
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
                            if let thumbnailFileLocation = thumbnailInfo["fileLocation"] as? [AnyHashable: Any], let thumbnailResource = parseFileLocationResource(thumbnailFileLocation), let fileLocation = fullSizeInfo["fileLocation"] as? [AnyHashable: Any], let resource = parseFileLocationResource(fileLocation) {
                                imageReference = .standalone(media: TelegramMediaImage(imageId: MediaId(namespace: Namespaces.Media.CloudImage, id: 1), representations: [TelegramMediaImageRepresentation(dimensions: CGSize(width: CGFloat(width), height: CGFloat(height)).fitted(CGSize(width: 320.0, height: 320.0)), resource: thumbnailResource), TelegramMediaImageRepresentation(dimensions: CGSize(width: CGFloat(width), height: CGFloat(height)), resource: resource)], immediateThumbnailData: nil, reference: nil, partialReference: nil))
                            }
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
            }
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        self.updateImageLayout(boundingSize: size)
    }
    
    private func updateImageLayout(boundingSize: CGSize) {
        if let imageDimensions = self.imageDimensions {
            let makeLayout = self.imageNode.asyncLayout()
            let fittedSize = imageDimensions.fitted(CGSize(width: boundingSize.width, height: 1000.0))
            let apply = makeLayout(TransformImageArguments(corners: ImageCorners(radius: 0.0), imageSize: fittedSize, boundingSize: fittedSize, intrinsicInsets: UIEdgeInsets()))
            apply()
            self.imageNode.frame = CGRect(origin: CGPoint(), size: boundingSize)
        }
    }
}
