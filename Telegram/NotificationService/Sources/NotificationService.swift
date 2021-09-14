import Foundation
import UserNotifications
import SwiftSignalKit
import Postbox
import TelegramCore
import BuildConfig
import OpenSSLEncryptionProvider
import TelegramUIPreferences

private let queue = Queue()

private var installedSharedLogger = false

private func setupSharedLogger(rootPath: String, path: String) {
    if !installedSharedLogger {
        installedSharedLogger = true
        Logger.setSharedLogger(Logger(rootPath: rootPath, basePath: path))
    }
}

private let accountAuxiliaryMethods = AccountAuxiliaryMethods(fetchResource: { account, resource, ranges, _ in
    return nil
}, fetchResourceMediaReferenceHash: { resource in
    return .single(nil)
}, prepareSecretThumbnailData: { _ in
    return nil
})

private func rootPathForBasePath(_ appGroupPath: String) -> String {
    return appGroupPath + "/telegram-data"
}

@available(iOSApplicationExtension 10.0, iOS 10.0, *)
private struct NotificationContent {
    var title: String?
    var subtitle: String?
    var body: String?
    var threadId: String?
    var sound: String?
    var badge: Int?
    var category: String?
    var userInfo: [AnyHashable: Any] = [:]

    func asNotificationContent() -> UNNotificationContent {
        let content = UNMutableNotificationContent()

        content.title = self.title ?? ""
        content.subtitle = self.subtitle ?? ""
        content.body = self.body ?? ""

        if let threadId = self.threadId {
            content.threadIdentifier = threadId
        }

        if let sound = self.sound {
            content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: sound))
        }

        if let badge = self.badge {
            content.badge = badge as NSNumber
        }

        if let category = self.category {
            content.categoryIdentifier = category
        }

        content.userInfo = self.userInfo

        return content
    }
}

@available(iOSApplicationExtension 10.0, iOS 10.0, *)
private final class NotificationServiceHandler {
    private let queue: Queue
    private let accountManager: AccountManager<TelegramAccountManagerTypes>
    private let encryptionParameters: ValueBoxEncryptionParameters
    private var stateManager: AccountStateManager?

    private let notificationKeyDisposable = MetaDisposable()
    private let pollDisposable = MetaDisposable()

    init?(queue: Queue, updateCurrentContent: @escaping (UNNotificationContent) -> Void, completed: @escaping () -> Void, payload: [AnyHashable: Any]) {
        self.queue = queue

        guard let appBundleIdentifier = Bundle.main.bundleIdentifier, let lastDotRange = appBundleIdentifier.range(of: ".", options: [.backwards]) else {
            return nil
        }

        let baseAppBundleId = String(appBundleIdentifier[..<lastDotRange.lowerBound])
        let buildConfig = BuildConfig(baseAppBundleId: baseAppBundleId)

        let apiId: Int32 = buildConfig.apiId
        let apiHash: String = buildConfig.apiHash
        let languagesCategory = "ios"

        let appGroupName = "group.\(baseAppBundleId)"
        let maybeAppGroupUrl = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupName)

        guard let appGroupUrl = maybeAppGroupUrl else {
            return nil
        }

        let rootPath = rootPathForBasePath(appGroupUrl.path)

        TempBox.initializeShared(basePath: rootPath, processType: "notification", launchSpecificId: Int64.random(in: Int64.min ... Int64.max))

        let logsPath = rootPath + "/notification-logs"
        let _ = try? FileManager.default.createDirectory(atPath: logsPath, withIntermediateDirectories: true, attributes: nil)

        setupSharedLogger(rootPath: rootPath, path: logsPath)

        initializeAccountManagement()

        let appVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "unknown"

        self.accountManager = AccountManager<TelegramAccountManagerTypes>(basePath: rootPath + "/accounts-metadata", isTemporary: true, isReadOnly: false, useCaches: false)

        let deviceSpecificEncryptionParameters = BuildConfig.deviceSpecificEncryptionParameters(rootPath, baseAppBundleId: baseAppBundleId)
        self.encryptionParameters = ValueBoxEncryptionParameters(forceEncryptionIfNoSet: false, key: ValueBoxEncryptionParameters.Key(data: deviceSpecificEncryptionParameters.key)!, salt: ValueBoxEncryptionParameters.Salt(data: deviceSpecificEncryptionParameters.salt)!)

        let networkArguments = NetworkInitializationArguments(apiId: apiId, apiHash: apiHash, languagesCategory: languagesCategory, appVersion: appVersion, voipMaxLayer: 0, voipVersions: [], appData: .single(buildConfig.bundleData(withAppToken: nil, signatureDict: nil)), autolockDeadine: .single(nil), encryptionProvider: OpenSSLEncryptionProvider())

        guard var encryptedPayload = payload["p"] as? String else {
            return nil
        }
        encryptedPayload = encryptedPayload.replacingOccurrences(of: "-", with: "+")
        encryptedPayload = encryptedPayload.replacingOccurrences(of: "_", with: "/")
        while encryptedPayload.count % 4 != 0 {
            encryptedPayload.append("=")
        }
        guard let payloadData = Data(base64Encoded: encryptedPayload) else {
            return nil
        }

        let _ = (self.accountManager.currentAccountRecord(allocateIfNotExists: false)
        |> take(1)
        |> deliverOn(self.queue)).start(next: { [weak self] records in
            guard let strongSelf = self, let record = records else {
                return
            }

            let _ = (standaloneStateManager(
                accountManager: strongSelf.accountManager,
                networkArguments: networkArguments,
                id: record.0,
                encryptionParameters: strongSelf.encryptionParameters,
                rootPath: rootPath,
                auxiliaryMethods: accountAuxiliaryMethods
            )
            |> deliverOn(strongSelf.queue)).start(next: { stateManager in
                guard let strongSelf = self else {
                    return
                }
                guard let stateManager = stateManager else {
                    completed()
                    return
                }
                strongSelf.stateManager = stateManager

                strongSelf.notificationKeyDisposable.set((existingMasterNotificationsKey(postbox: stateManager.postbox)
                |> deliverOn(strongSelf.queue)).start(next: { notificationsKey in
                    guard let strongSelf = self else {
                        return
                    }
                    guard let notificationsKey = notificationsKey else {
                        completed()
                        return
                    }
                    guard let decryptedPayload = decryptedNotificationPayload(key: notificationsKey, data: payloadData) else {
                        completed()
                        return
                    }
                    guard let payloadJson = try? JSONSerialization.jsonObject(with: decryptedPayload, options: []) as? [String: Any] else {
                        completed()
                        return
                    }
                    guard let aps = payloadJson["aps"] as? [String: Any] else {
                        completed()
                        return
                    }

                    var content: NotificationContent = NotificationContent()
                    if let alert = aps["alert"] as? [String: Any] {
                        content.title = alert["title"] as? String
                        content.subtitle = alert["subtitle"] as? String
                        content.body = alert["body"] as? String
                    } else if let alert = aps["alert"] as? String {
                        content.body = alert
                    } else {
                        completed()
                        return
                    }

                    var peerId: PeerId?
                    var messageId: MessageId.Id?

                    if let messageIdString = payloadJson["msg_id"] as? String {
                        content.userInfo["msg_id"] = messageIdString
                        messageId = Int32(messageIdString)
                    }

                    if let fromIdString = payloadJson["from_id"] as? String {
                        content.userInfo["from_id"] = fromIdString
                        if let userIdValue = Int64(fromIdString) {
                            peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userIdValue))
                        }
                    } else if let chatIdString = payloadJson["chat_id"] as? String {
                        content.userInfo["chat_id"] = chatIdString
                        if let chatIdValue = Int64(chatIdString) {
                            peerId = PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(chatIdValue))
                        }
                    } else if let channelIdString = payloadJson["channel_id"] as? String {
                        content.userInfo["channel_id"] = channelIdString
                        if let channelIdValue = Int64(channelIdString) {
                            peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelIdValue))
                        }
                    }

                    if let silentString = payloadJson["silent"] as? String {
                        if let silentValue = Int(silentString), silentValue != 0 {
                            if let title = content.title {
                                content.title = "\(title) 🔕"
                            }
                        }
                    }

                    if let threadId = aps["thread-id"] as? String {
                        content.threadId = threadId
                    }

                    if let sound = aps["sound"] as? String {
                        content.sound = sound
                    }

                    if let category = aps["category"] as? String {
                        content.category = category

                        let _ = messageId

                        /*if (peerId != 0 && messageId != 0 && parsedAttachment != nil && attachmentData != nil) {
                            userInfo[@"peerId"] = @(peerId);
                            userInfo[@"messageId.namespace"] = @(0);
                            userInfo[@"messageId.id"] = @(messageId);

                            userInfo[@"media"] = [attachmentData base64EncodedStringWithOptions:0];

                            if (isExpandableMedia) {
                                if ([categoryString isEqualToString:@"r"]) {
                                    _bestAttemptContent.categoryIdentifier = @"withReplyMedia";
                                } else if ([categoryString isEqualToString:@"m"]) {
                                    _bestAttemptContent.categoryIdentifier = @"withMuteMedia";
                                }
                            }
                        }*/
                    }

                    /*if (accountInfos.accounts.count > 1) {
                        if (_bestAttemptContent.title.length != 0 && account.peerName.length != 0) {
                            _bestAttemptContent.title = [NSString stringWithFormat:@"%@ → %@", _bestAttemptContent.title, account.peerName];
                        }
                    }*/

                    updateCurrentContent(content.asNotificationContent())

                    if let stateManager = strongSelf.stateManager, let peerId = peerId {
                        let pollCompletion: () -> Void = {
                            queue.async {
                                guard let strongSelf = self, let stateManager = strongSelf.stateManager else {
                                    completed()
                                    return
                                }

                                let _ = (renderedTotalUnreadCount(
                                    accountManager: strongSelf.accountManager,
                                    postbox: stateManager.postbox
                                )
                                |> deliverOn(strongSelf.queue)).start(next: { value in
                                    content.badge = Int(value.0)

                                    updateCurrentContent(content.asNotificationContent())

                                    completed()
                                })
                            }
                        }

                        stateManager.network.shouldKeepConnection.set(.single(true))
                        if peerId.namespace == Namespaces.Peer.CloudChannel {
                            strongSelf.pollDisposable.set(standalonePollChannelOnce(
                                postbox: stateManager.postbox,
                                network: stateManager.network,
                                peerId: peerId,
                                stateManager: stateManager
                            ).start(completed: {
                                pollCompletion()
                            }))
                        } else {
                            enum ControlError {
                                case restart
                            }
                            let signal = stateManager.standalonePollDifference()
                            |> castError(ControlError.self)
                            |> mapToSignal { result -> Signal<Never, ControlError> in
                                if result {
                                    return .complete()
                                } else {
                                    return .fail(.restart)
                                }
                            }
                            |> restartIfError
                            
                            strongSelf.pollDisposable.set(signal.start(completed: {
                                pollCompletion()
                            }))
                        }
                    } else {
                        completed()
                    }
                }))
            })
        })
    }

    deinit {
        self.pollDisposable.dispose()
        self.stateManager?.network.shouldKeepConnection.set(.single(false))
    }
}

@available(iOSApplicationExtension 10.0, iOS 10.0, *)
private final class BoxedNotificationServiceHandler {
    let value: NotificationServiceHandler?

    init(value: NotificationServiceHandler?) {
        self.value = value
    }
}

@available(iOSApplicationExtension 10.0, iOS 10.0, *)
@objc(NotificationService)
final class NotificationService: UNNotificationServiceExtension {
    private var impl: QueueLocalObject<BoxedNotificationServiceHandler>?

    private let content = Atomic<UNNotificationContent?>(value: nil)
    private var contentHandler: ((UNNotificationContent) -> Void)?
    
    override init() {
        super.init()
    }
    
    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        let _ = self.content.swap(request.content)
        self.contentHandler = contentHandler

        self.impl = nil

        let content = self.content

        self.impl = QueueLocalObject(queue: queue, generate: { [weak self] in
            return BoxedNotificationServiceHandler(value: NotificationServiceHandler(
                queue: queue,
                updateCurrentContent: { value in
                    let _ = content.swap(value)
                },
                completed: {
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.impl = nil
                    if let content = content.with({ $0 }), let contentHandler = strongSelf.contentHandler {
                        contentHandler(content)
                    }
                },
                payload: request.content.userInfo
            ))
        })
    }
    
    override func serviceExtensionTimeWillExpire() {
        if let content = self.content.with({ $0 }), let contentHandler = self.contentHandler {
            contentHandler(content)
        }
    }
}
