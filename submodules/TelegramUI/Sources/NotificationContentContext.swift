import UIKit
import UserNotifications
import UserNotificationsUI
import Display
import TelegramCore
import SwiftSignalKit
import Postbox
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import Tuples
import StickerResources
import PhotoResources
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import OpenSSLEncryptionProvider
import AppLock

private enum NotificationContentAuthorizationError {
    case unauthorized
}

private var sharedAccountContext: SharedAccountContext?

private var installedSharedLogger = false

private func setupSharedLogger(rootPath: String, path: String) {
    if !installedSharedLogger {
        installedSharedLogger = true
        Logger.setSharedLogger(Logger(rootPath: rootPath, basePath: path))
    }
}

public struct NotificationViewControllerInitializationData {
    public let appBundleId: String
    public let appGroupPath: String
    public let apiId: Int32
    public let apiHash: String
    public let languagesCategory: String
    public let encryptionParameters: (Data, Data)
    public let appVersion: String
    public let bundleData: Data?
    
    public init(appBundleId: String, appGroupPath: String, apiId: Int32, apiHash: String, languagesCategory: String, encryptionParameters: (Data, Data), appVersion: String, bundleData: Data?) {
        self.appBundleId = appBundleId
        self.appGroupPath = appGroupPath
        self.apiId = apiId
        self.apiHash = apiHash
        self.languagesCategory = languagesCategory
        self.encryptionParameters = encryptionParameters
        self.appVersion = appVersion
        self.bundleData = bundleData
    }
}

@available(iOSApplicationExtension 10.0, iOS 10.0, *)
public final class NotificationViewControllerImpl {
    private let initializationData: NotificationViewControllerInitializationData
    private let setPreferredContentSize: (CGSize) -> Void
    
    private let imageNode = TransformImageNode()
    private var animatedStickerNode: AnimatedStickerNode?
    private var imageInfo: (isSticker: Bool, dimensions: CGSize)?
    
    private let applyDisposable = MetaDisposable()
    private let fetchedDisposable = MetaDisposable()
    
    private var accountsPath: String?
    
    public init(initializationData: NotificationViewControllerInitializationData, setPreferredContentSize: @escaping (CGSize) -> Void) {
        self.initializationData = initializationData
        self.setPreferredContentSize = setPreferredContentSize
    }
    
    deinit {
        self.applyDisposable.dispose()
        self.fetchedDisposable.dispose()
    }
    
    public func viewDidLoad(view: UIView) {
        view.addSubnode(self.imageNode)
        
        let rootPath = rootPathForBasePath(self.initializationData.appGroupPath)
        performAppGroupUpgrades(appGroupPath: self.initializationData.appGroupPath, rootPath: rootPath)
        
        TempBox.initializeShared(basePath: rootPath, processType: "notification-content", launchSpecificId: Int64.random(in: Int64.min ... Int64.max))
        
        let logsPath = rootPath + "/notificationcontent-logs"
        let _ = try? FileManager.default.createDirectory(atPath: logsPath, withIntermediateDirectories: true, attributes: nil)
        
        setupSharedLogger(rootPath: rootPath, path: logsPath)
        
        accountsPath = rootPath
        
        if sharedAccountContext == nil {
            initializeAccountManagement()
            let accountManager = AccountManager<TelegramAccountManagerTypes>(basePath: rootPath + "/accounts-metadata", isTemporary: true, isReadOnly: false, useCaches: false, removeDatabaseOnError: false)
            
            var initialPresentationDataAndSettings: InitialPresentationDataAndSettings?
            let semaphore = DispatchSemaphore(value: 0)
            let _ = currentPresentationDataAndSettings(accountManager: accountManager, systemUserInterfaceStyle: .light).start(next: { value in
                initialPresentationDataAndSettings = value
                semaphore.signal()
            })
            semaphore.wait()
            
            let applicationBindings = TelegramApplicationBindings(isMainApp: false, appBundleId: self.initializationData.appBundleId, containerPath: self.initializationData.appGroupPath, appSpecificScheme: "tgapp", openUrl: { _ in
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
            }, getAvailableAlternateIcons: {
                return []
            }, getAlternateIconName: {
                return nil
            }, requestSetAlternateIconName: { _, f in
                f(false)
            }, forceOrientation: { _ in
            })
            
            let presentationDataPromise = Promise<PresentationData>()
            
            let appLockContext = AppLockContextImpl(rootPath: rootPath, window: nil, rootController: nil, applicationBindings: applicationBindings, accountManager: accountManager, presentationDataSignal: presentationDataPromise.get(), lockIconInitialFrame: {
                return nil
            })
            
            sharedAccountContext = SharedAccountContextImpl(mainWindow: nil, sharedContainerPath: self.initializationData.appGroupPath, basePath: rootPath, encryptionParameters: ValueBoxEncryptionParameters(forceEncryptionIfNoSet: false, key: ValueBoxEncryptionParameters.Key(data: self.initializationData.encryptionParameters.0)!, salt: ValueBoxEncryptionParameters.Salt(data: self.initializationData.encryptionParameters.1)!), accountManager: accountManager, appLockContext: appLockContext, applicationBindings: applicationBindings, initialPresentationDataAndSettings: initialPresentationDataAndSettings!, networkArguments: NetworkInitializationArguments(apiId: self.initializationData.apiId, apiHash: self.initializationData.apiHash, languagesCategory: self.initializationData.languagesCategory, appVersion: self.initializationData.appVersion, voipMaxLayer: 0, voipVersions: [], appData: .single(self.initializationData.bundleData), autolockDeadine: .single(nil), encryptionProvider: OpenSSLEncryptionProvider(), resolvedDeviceName: nil), rootPath: rootPath, legacyBasePath: nil, apsNotificationToken: .never(), voipNotificationToken: .never(), setNotificationCall: { _ in }, navigateToChat: { _, _, _ in })
            
            presentationDataPromise.set(sharedAccountContext!.presentationData)
        }
    }
    
    public func didReceive(_ notification: UNNotification, view: UIView) {
        guard let accountsPath = self.accountsPath else {
            return
        }
        
        guard let accountIdValue = notification.request.content.userInfo["accountId"] as? Int64 else {
            return
        }
        
        guard let peerIdValue = notification.request.content.userInfo["peerId"] as? Int64 else {
            return
        }
        
        guard let messageIdNamespace = notification.request.content.userInfo["messageId.namespace"] as? Int32 else {
            return
        }
        
        guard let messageIdId = notification.request.content.userInfo["messageId.id"] as? Int32 else {
            return
        }
        
        guard let mediaDataString = notification.request.content.userInfo["media"] as? String else {
            return
        }
        
        guard let mediaData = Data(base64Encoded: mediaDataString) else {
            return
        }
        
        guard let media = parseMediaData(data: mediaData) else {
            return
        }
        
        let messageId = MessageId(peerId: PeerId(peerIdValue), namespace: messageIdNamespace, id: messageIdId)
        
        if let image = media as? TelegramMediaImage, let thumbnailRepresentation = imageRepresentationLargerThan(image.representations, size: PixelDimensions(width: 120, height: 120)), let largestRepresentation = largestImageRepresentation(image.representations) {
            let dimensions = largestRepresentation.dimensions
            let fittedSize = dimensions.cgSize.fitted(CGSize(width: view.bounds.width, height: 1000.0))
            view.frame = CGRect(origin: view.frame.origin, size: fittedSize)
            self.setPreferredContentSize(fittedSize)
            
            self.imageInfo = (false, dimensions.cgSize)
            self.updateImageLayout(boundingSize: view.bounds.size)
            
            let mediaBoxPath = accountsPath + "/" + accountRecordIdPathName(AccountRecordId(rawValue: accountIdValue)) + "/postbox/media"
            
            if let data = try? Data(contentsOf: URL(fileURLWithPath: mediaBoxPath + "/\(largestRepresentation.resource.id.stringRepresentation)"), options: .mappedRead) {
                self.imageNode.setSignal(chatMessagePhotoInternal(photoData: .single(Tuple(nil, data, .full, true)))
                |> map { $0.2 })
                return
            }
            
            if let data = try? Data(contentsOf: URL(fileURLWithPath: mediaBoxPath + "/\(thumbnailRepresentation.resource.id.stringRepresentation)"), options: .mappedRead) {
                self.imageNode.setSignal(chatMessagePhotoInternal(photoData: .single(Tuple(data, nil, .medium, false)))
                |> map { $0.2 })
            }
            
            guard let sharedAccountContext = sharedAccountContext else {
                return
            }
            
            self.applyDisposable.set((sharedAccountContext.activeAccountContexts
            |> map { _, accounts, _ -> Account? in
                return accounts.first(where: { $0.0 == AccountRecordId(rawValue: accountIdValue) })?.1.account
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
            
            let fittedSize = dimensions.cgSize.fitted(CGSize(width: min(256.0, view.bounds.width), height: 256.0))
            view.frame = CGRect(origin: view.frame.origin, size: fittedSize)
            self.setPreferredContentSize(fittedSize)
            
            self.imageInfo = (true, dimensions.cgSize)
            self.updateImageLayout(boundingSize: view.bounds.size)
            
            self.applyDisposable.set((sharedAccountContext.activeAccountContexts
            |> map { _, contexts, _ -> AccountContext? in
                return contexts.first(where: { $0.0 == AccountRecordId(rawValue: accountIdValue) })?.1
            }
            |> filter { context in
                return context != nil
            }
            |> take(1)
            |> mapToSignal { context -> Signal<(Account, FileMediaReference?), NoError> in
                guard let account = context?.account else {
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
            |> deliverOnMainQueue).start(next: { [weak self, weak view] accountAndImage in
                guard let strongSelf = self else {
                    return
                }
                if let fileReference = accountAndImage.1 {
                    if file.isAnimatedSticker || file.isVideoSticker {
                        let animatedStickerNode: AnimatedStickerNode
                        if let current = strongSelf.animatedStickerNode {
                            animatedStickerNode = current
                        } else {
                            animatedStickerNode = AnimatedStickerNode()
                            strongSelf.animatedStickerNode = animatedStickerNode
                            animatedStickerNode.started = {
                                guard let strongSelf = self else {
                                    return
                                }
                                strongSelf.imageNode.isHidden = true
                            }
                            if !strongSelf.imageNode.frame.width.isZero {
                                animatedStickerNode.frame = strongSelf.imageNode.frame
                                animatedStickerNode.updateLayout(size: strongSelf.imageNode.frame.size)
                            }
                            view?.addSubnode(animatedStickerNode)
                        }
                        let dimensions = fileReference.media.dimensions ?? PixelDimensions(width: 512, height: 512)
                        let fittedDimensions = dimensions.cgSize.aspectFitted(CGSize(width: 512.0, height: 512.0))
                        if file.isVideoSticker {
                            strongSelf.imageNode.setSignal(chatMessageSticker(postbox: accountAndImage.0.postbox, file: fileReference.media, small: false))
                        } else {
                            strongSelf.imageNode.setSignal(chatMessageAnimatedSticker(postbox: accountAndImage.0.postbox, file: fileReference.media, small: false, size: fittedDimensions))
                        }
                        animatedStickerNode.setup(source: AnimatedStickerResourceSource(account: accountAndImage.0, resource: fileReference.media.resource, isVideo: file.isVideoSticker), width: Int(fittedDimensions.width), height: Int(fittedDimensions.height), mode: .direct(cachePathPrefix: nil))
                        animatedStickerNode.visibility = true
                        
                        accountAndImage.0.network.shouldExplicitelyKeepWorkerConnections.set(.single(true))
                        strongSelf.fetchedDisposable.set(freeMediaFileInteractiveFetched(account: accountAndImage.0, fileReference: fileReference).start())
                    } else if file.isSticker {
                        if let animatedStickerNode = strongSelf.animatedStickerNode {
                            animatedStickerNode.removeFromSupernode()
                            strongSelf.animatedStickerNode = nil
                        }
                        strongSelf.imageNode.isHidden = false
                        
                        strongSelf.imageNode.setSignal(chatMessageSticker(account: accountAndImage.0, file: file, small: false))
                        
                        accountAndImage.0.network.shouldExplicitelyKeepWorkerConnections.set(.single(true))
                        strongSelf.fetchedDisposable.set(freeMediaFileInteractiveFetched(account: accountAndImage.0, fileReference: fileReference).start())
                    }
                }
            }))
        }
    }
    
    public func viewWillTransition(to size: CGSize) {
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
            self.animatedStickerNode?.frame = CGRect(origin: CGPoint(x: floor((boundingSize.width - displaySize.width) / 2.0), y: 0.0), size: displaySize)
            self.animatedStickerNode?.updateLayout(size: displaySize)
        }
    }
}
