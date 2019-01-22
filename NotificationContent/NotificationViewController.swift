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

private var accountCache: (Account, AccountManager)?

private var installedSharedLogger = false

private func setupSharedLogger(_ path: String) {
    if !installedSharedLogger {
        installedSharedLogger = true
        Logger.setSharedLogger(Logger(basePath: path))
    }
}

class NotificationViewController: UIViewController, UNNotificationContentExtension {
    private let accountPromise = Promise<Account>()
    
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
        
        let account: Signal<(Account, AccountManager), NotificationContentAuthorizationError>
        if let accountCache = accountCache {
            account = .single(accountCache)
        } else {
            let appVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "unknown"
            
            initializeAccountManagement()
            account = accountManager(basePath: rootPath + "/accounts-metadata")
            |> take(1)
            |> introduceError(NotificationContentAuthorizationError.self)
            |> mapToSignal { accountManager -> Signal<(Account, AccountManager), NotificationContentAuthorizationError> in
                return currentAccount(allocateIfNotExists: false, networkArguments: NetworkInitializationArguments(apiId: apiId, languagesCategory: languagesCategory, appVersion: appVersion, voipMaxLayer: 0), supplementary: true, manager: accountManager, rootPath: rootPath, auxiliaryMethods: telegramAccountAuxiliaryMethods)
                |> introduceError(NotificationContentAuthorizationError.self)
                |> mapToSignal { account -> Signal<(Account, AccountManager), NotificationContentAuthorizationError> in
                    if let account = account {
                        switch account {
                            case .upgrading:
                                return .complete()
                            case let .authorized(account):
                                setupAccount(account)
                                accountCache = (account, accountManager)
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
        self.accountPromise.set(account
        |> map { $0.0 }
        |> `catch` { _ -> Signal<Account, NoError> in
            return .complete()
        })
    }
    
    func didReceive(_ notification: UNNotification) {
        if let peerIdValue = notification.request.content.userInfo["peerId"] as? Int64, let messageIdNamespace = notification.request.content.userInfo["messageId.namespace"] as? Int32, let messageIdId = notification.request.content.userInfo["messageId.id"] as? Int32, let dict = notification.request.content.userInfo["mediaInfo"] as? [String: Any] {
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
                
                self.applyDisposable.set((self.accountPromise.get()
                |> take(1)
                |> mapToSignal { account -> Signal<(Account, ImageMediaReference?), NoError> in
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
