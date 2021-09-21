import Foundation
import UserNotifications
import SwiftSignalKit
import Postbox
import TelegramCore
import BuildConfig
import OpenSSLEncryptionProvider
import TelegramUIPreferences
import WebPBinding
import RLottieBinding
import GZip
import UIKit

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

private let deviceColorSpace: CGColorSpace = {
    if #available(iOSApplicationExtension 9.3, iOS 9.3, *) {
        if let colorSpace = CGColorSpace(name: CGColorSpace.displayP3) {
            return colorSpace
        } else {
            return CGColorSpaceCreateDeviceRGB()
        }
    } else {
        return CGColorSpaceCreateDeviceRGB()
    }
}()

private func getSharedDevideGraphicsContextSettings() -> DeviceGraphicsContextSettings {
    struct OpaqueSettings {
        let rowAlignment: Int
        let bitsPerPixel: Int
        let bitsPerComponent: Int
        let opaqueBitmapInfo: CGBitmapInfo
        let colorSpace: CGColorSpace

        init(context: CGContext) {
            self.rowAlignment = context.bytesPerRow
            self.bitsPerPixel = context.bitsPerPixel
            self.bitsPerComponent = context.bitsPerComponent
            self.opaqueBitmapInfo = context.bitmapInfo
            if #available(iOS 10.0, *) {
                if UIScreen.main.traitCollection.displayGamut == .P3 {
                    self.colorSpace = CGColorSpace(name: CGColorSpace.displayP3) ?? context.colorSpace!
                } else {
                    self.colorSpace = context.colorSpace!
                }
            } else {
                self.colorSpace = context.colorSpace!
            }
            assert(self.rowAlignment == 32)
            assert(self.bitsPerPixel == 32)
            assert(self.bitsPerComponent == 8)
        }
    }

    struct TransparentSettings {
        let transparentBitmapInfo: CGBitmapInfo

        init(context: CGContext) {
            self.transparentBitmapInfo = context.bitmapInfo
        }
    }

    var opaqueSettings: OpaqueSettings?
    var transparentSettings: TransparentSettings?

    if #available(iOS 10.0, *) {
        let opaqueFormat = UIGraphicsImageRendererFormat()
        let transparentFormat = UIGraphicsImageRendererFormat()
        if #available(iOS 12.0, *) {
            opaqueFormat.preferredRange = .standard
            transparentFormat.preferredRange = .standard
        }
        opaqueFormat.opaque = true
        transparentFormat.opaque = false

        let opaqueRenderer = UIGraphicsImageRenderer(bounds: CGRect(origin: CGPoint(), size: CGSize(width: 1.0, height: 1.0)), format: opaqueFormat)
        let _ = opaqueRenderer.image(actions: { context in
            opaqueSettings = OpaqueSettings(context: context.cgContext)
        })

        let transparentRenderer = UIGraphicsImageRenderer(bounds: CGRect(origin: CGPoint(), size: CGSize(width: 1.0, height: 1.0)), format: transparentFormat)
        let _ = transparentRenderer.image(actions: { context in
            transparentSettings = TransparentSettings(context: context.cgContext)
        })
    } else {
        UIGraphicsBeginImageContextWithOptions(CGSize(width: 1.0, height: 1.0), true, 1.0)
        let refContext = UIGraphicsGetCurrentContext()!
        opaqueSettings = OpaqueSettings(context: refContext)
        UIGraphicsEndImageContext()

        UIGraphicsBeginImageContextWithOptions(CGSize(width: 1.0, height: 1.0), false, 1.0)
        let refCtxTransparent = UIGraphicsGetCurrentContext()!
        transparentSettings = TransparentSettings(context: refCtxTransparent)
        UIGraphicsEndImageContext()
    }

    return DeviceGraphicsContextSettings(
        rowAlignment: opaqueSettings!.rowAlignment,
        bitsPerPixel: opaqueSettings!.bitsPerPixel,
        bitsPerComponent: opaqueSettings!.bitsPerComponent,
        opaqueBitmapInfo: opaqueSettings!.opaqueBitmapInfo,
        transparentBitmapInfo: transparentSettings!.transparentBitmapInfo,
        colorSpace: opaqueSettings!.colorSpace
    )
}

public struct DeviceGraphicsContextSettings {
    public static let shared: DeviceGraphicsContextSettings = getSharedDevideGraphicsContextSettings()

    public let rowAlignment: Int
    public let bitsPerPixel: Int
    public let bitsPerComponent: Int
    public let opaqueBitmapInfo: CGBitmapInfo
    public let transparentBitmapInfo: CGBitmapInfo
    public let colorSpace: CGColorSpace

    public func bytesPerRow(forWidth width: Int) -> Int {
        let baseValue = self.bitsPerPixel * width / 8
        return (baseValue + 31) & ~0x1F
    }
}

private final class DrawingContext {
    let size: CGSize
    let scale: CGFloat
    let scaledSize: CGSize
    let bytesPerRow: Int
    private let bitmapInfo: CGBitmapInfo
    let length: Int
    let bytes: UnsafeMutableRawPointer
    private let data: Data
    private let context: CGContext

    private var hasGeneratedImage = false

    func withContext(_ f: (CGContext) -> ()) {
        let context = self.context

        context.translateBy(x: self.size.width / 2.0, y: self.size.height / 2.0)
        context.scaleBy(x: 1.0, y: -1.0)
        context.translateBy(x: -self.size.width / 2.0, y: -self.size.height / 2.0)

        f(context)

        context.translateBy(x: self.size.width / 2.0, y: self.size.height / 2.0)
        context.scaleBy(x: 1.0, y: -1.0)
        context.translateBy(x: -self.size.width / 2.0, y: -self.size.height / 2.0)
    }

    func withFlippedContext(_ f: (CGContext) -> ()) {
        f(self.context)
    }

    init(size: CGSize, scale: CGFloat = 1.0, opaque: Bool = false, clear: Bool = false) {
        assert(!size.width.isZero && !size.height.isZero)
        let size: CGSize = CGSize(width: max(1.0, size.width), height: max(1.0, size.height))

        let actualScale: CGFloat
        if scale.isZero {
            actualScale = 1.0
        } else {
            actualScale = scale
        }
        self.size = size
        self.scale = actualScale
        self.scaledSize = CGSize(width: size.width * actualScale, height: size.height * actualScale)

        self.bytesPerRow = DeviceGraphicsContextSettings.shared.bytesPerRow(forWidth: Int(self.scaledSize.width))

        self.length = self.bytesPerRow * Int(self.scaledSize.height)

        self.bytes = malloc(self.length)
        self.data = Data(bytesNoCopy: self.bytes, count: self.length, deallocator: .custom({ bytes, _ in
            free(bytes)
        }))

        if opaque {
            self.bitmapInfo = DeviceGraphicsContextSettings.shared.opaqueBitmapInfo
        } else {
            self.bitmapInfo = DeviceGraphicsContextSettings.shared.transparentBitmapInfo
        }

        self.context = CGContext(
            data: self.bytes,
            width: Int(self.scaledSize.width),
            height: Int(self.scaledSize.height),
            bitsPerComponent: 8,
            bytesPerRow: self.bytesPerRow,
            space: deviceColorSpace,
            bitmapInfo: self.bitmapInfo.rawValue,
            releaseCallback: nil,
            releaseInfo: nil
        )!
        self.context.scaleBy(x: self.scale, y: self.scale)

        if clear {
            memset(self.bytes, 0, self.length)
        }
    }

    func generateImage() -> UIImage? {
        if self.scaledSize.width.isZero || self.scaledSize.height.isZero {
            return nil
        }
        if self.hasGeneratedImage {
            preconditionFailure()
        }
        self.hasGeneratedImage = true

        guard let dataProvider = CGDataProvider(data: self.data as CFData) else {
            return nil
        }

        if let image = CGImage(
            width: Int(self.scaledSize.width),
            height: Int(self.scaledSize.height),
            bitsPerComponent: self.context.bitsPerComponent,
            bitsPerPixel: self.context.bitsPerPixel,
            bytesPerRow: self.context.bytesPerRow,
            space: DeviceGraphicsContextSettings.shared.colorSpace,
            bitmapInfo: self.context.bitmapInfo,
            provider: dataProvider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        ) {
            return UIImage(cgImage: image, scale: self.scale, orientation: .up)
        } else {
            return nil
        }
    }
}

private extension CGSize {
    func fitted(_ size: CGSize) -> CGSize {
        var fittedSize = self
        if fittedSize.width > size.width {
            fittedSize = CGSize(width: size.width, height: floor((fittedSize.height * size.width / max(fittedSize.width, 1.0))))
        }
        if fittedSize.height > size.height {
            fittedSize = CGSize(width: floor((fittedSize.width * size.height / max(fittedSize.height, 1.0))), height: size.height)
        }
        return fittedSize
    }
}

private func convertLottieImage(data: Data) -> UIImage? {
    let decompressedData = TGGUnzipData(data, 512 * 1024) ?? data
    guard let animation = LottieInstance(data: decompressedData, cacheKey: "") else {
        return nil
    }
    let size = animation.dimensions.fitted(CGSize(width: 200.0, height: 200.0))
    let context = DrawingContext(size: size, scale: 1.0, opaque: false, clear: true)
    animation.renderFrame(with: 0, into: context.bytes.assumingMemoryBound(to: UInt8.self), width: Int32(context.scaledSize.width), height: Int32(context.scaledSize.height), bytesPerRow: Int32(context.bytesPerRow))
    return context.generateImage()
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
    var attachments: [UNNotificationAttachment] = []

    func asNotificationContent() -> UNNotificationContent {
        let content = UNMutableNotificationContent()

        if let title = self.title {
            content.title = title
        }
        if let subtitle = self.subtitle {
            content.subtitle = subtitle
        }
        if let body = self.body {
            content.body = body
        }
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
        if !self.userInfo.isEmpty {
            content.userInfo = self.userInfo
        }
        if !self.attachments.isEmpty {
            content.attachments = self.attachments
        }

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

                    var peerId: PeerId?
                    var messageId: MessageId.Id?
                    var mediaAttachment: Media?

                    if let messageIdString = payloadJson["msg_id"] as? String {
                        messageId = Int32(messageIdString)
                    }

                    if let fromIdString = payloadJson["from_id"] as? String {
                        if let userIdValue = Int64(fromIdString) {
                            peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userIdValue))
                        }
                    } else if let chatIdString = payloadJson["chat_id"] as? String {
                        if let chatIdValue = Int64(chatIdString) {
                            peerId = PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(chatIdValue))
                        }
                    } else if let channelIdString = payloadJson["channel_id"] as? String {
                        if let channelIdValue = Int64(channelIdString) {
                            peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelIdValue))
                        }
                    }

                    enum Action {
                        case logout
                        case poll(peerId: PeerId, content: NotificationContent)
                        case deleteMessage([MessageId])
                        case readMessage(MessageId)
                    }

                    var action: Action?

                    if let locKey = payloadJson["loc-key"] as? String {
                        switch locKey {
                        case "SESSION_REVOKE":
                            action = .logout
                        case "MESSAGE_MUTED":
                            if let peerId = peerId {
                                action = .poll(peerId: peerId, content: NotificationContent())
                            }
                        case "MESSAGE_DELETED":
                            if let peerId = peerId {
                                if let messageId = messageId {
                                    action = .deleteMessage([MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: messageId)])
                                } else if let messageIds = payloadJson["messages"] as? String {
                                    var messagesDeleted: [MessageId] = []
                                    for messageId in messageIds.split(separator: ",") {
                                        if let messageIdValue = Int32(messageId) {
                                            messagesDeleted.append(MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: messageIdValue))
                                        }
                                    }
                                    action = .deleteMessage(messagesDeleted)
                                }
                            }
                        case "READ_HISTORY":
                            if let peerId = peerId {
                                if let messageIdString = payloadJson["max_id"] as? String {
                                    if let maxId = Int32(messageIdString) {
                                        action = .readMessage(MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: maxId))
                                    }
                                }
                            }
                        default:
                            break
                        }
                    } else {
                        if let aps = payloadJson["aps"] as? [String: Any], let peerId = peerId {
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

                            if let messageId = messageId {
                                content.userInfo["msg_id"] = "\(messageId)"
                            }

                            if peerId.namespace == Namespaces.Peer.CloudUser {
                                content.userInfo["from_id"] = "\(peerId.id._internalGetInt64Value())"
                            } else if peerId.namespace == Namespaces.Peer.CloudGroup {
                                content.userInfo["chat_id"] = "\(peerId.id._internalGetInt64Value())"
                            } else if peerId.namespace == Namespaces.Peer.CloudChannel {
                                content.userInfo["channel_id"] = "\(peerId.id._internalGetInt64Value())"
                            }

                            content.userInfo["peerId"] = "\(peerId.toInt64())"
                            content.userInfo["accountId"] = "\(record.0.int64)"

                            if let silentString = payloadJson["silent"] as? String {
                                if let silentValue = Int(silentString), silentValue != 0 {
                                    if let title = content.title {
                                        content.title = "\(title) 🔕"
                                    }
                                }
                            }
                            if var attachmentDataString = payloadJson["attachb64"] as? String {
                                attachmentDataString = attachmentDataString.replacingOccurrences(of: "-", with: "+")
                                attachmentDataString = attachmentDataString.replacingOccurrences(of: "_", with: "/")
                                while attachmentDataString.count % 4 != 0 {
                                    attachmentDataString.append("=")
                                }
                                if let attachmentData = Data(base64Encoded: attachmentDataString) {
                                    mediaAttachment = _internal_parseMediaAttachment(data: attachmentData)
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

                            action = .poll(peerId: peerId, content: content)

                            updateCurrentContent(content.asNotificationContent())
                        }
                    }

                    if let action = action {
                        switch action {
                        case .logout:
                            completed()
                        case .poll(let peerId, var content):
                            if let stateManager = strongSelf.stateManager {
                                let pollCompletion: () -> Void = {
                                    queue.async {
                                        guard let strongSelf = self, let stateManager = strongSelf.stateManager else {
                                            completed()
                                            return
                                        }

                                        var fetchMediaSignal: Signal<Data?, NoError> = .single(nil)
                                        if let mediaAttachment = mediaAttachment {
                                            var fetchResource: TelegramMultipartFetchableResource?
                                            if let image = mediaAttachment as? TelegramMediaImage, let representation = largestImageRepresentation(image.representations), let resource = representation.resource as? TelegramMultipartFetchableResource {
                                                fetchResource = resource
                                            } else if let file = mediaAttachment as? TelegramMediaFile {
                                                if file.isSticker {
                                                    fetchResource = file.resource as? TelegramMultipartFetchableResource
                                                } else if file.isVideo {
                                                    fetchResource = file.previewRepresentations.first?.resource as? TelegramMultipartFetchableResource
                                                }
                                            }

                                            if let resource = fetchResource {
                                                if let _ = strongSelf.stateManager?.postbox.mediaBox.completedResourcePath(resource) {
                                                } else {
                                                    let intervals: Signal<[(Range<Int>, MediaBoxFetchPriority)], NoError> = .single([(0 ..< Int(Int32.max), MediaBoxFetchPriority.maximum)])
                                                    fetchMediaSignal = Signal { subscriber in
                                                        let collectedData = Atomic<Data>(value: Data())
                                                        return standaloneMultipartFetch(
                                                            postbox: stateManager.postbox,
                                                            network: stateManager.network,
                                                            resource: resource,
                                                            datacenterId: resource.datacenterId,
                                                            size: nil,
                                                            intervals: intervals,
                                                            parameters: MediaResourceFetchParameters(
                                                                tag: nil,
                                                                info: resourceFetchInfo(resource: resource),
                                                                isRandomAccessAllowed: true
                                                            ),
                                                            encryptionKey: nil,
                                                            decryptedSize: nil,
                                                            continueInBackground: false,
                                                            useMainConnection: true
                                                        ).start(next: { result in
                                                            switch result {
                                                            case let .dataPart(_, data, _, _):
                                                                let _ = collectedData.modify { current in
                                                                    var current = current
                                                                    current.append(data)
                                                                    return current
                                                                }
                                                            default:
                                                                break
                                                            }
                                                        }, error: { _ in
                                                            subscriber.putNext(nil)
                                                            subscriber.putCompletion()
                                                        }, completed: {
                                                            subscriber.putNext(collectedData.with({ $0 }))
                                                            subscriber.putCompletion()
                                                        })
                                                    }
                                                }
                                            }
                                        }

                                        let _ = (fetchMediaSignal
                                        |> timeout(10.0, queue: queue, alternate: .single(nil))
                                        |> deliverOn(queue)).start(next: { mediaData in
                                            guard let strongSelf = self, let stateManager = strongSelf.stateManager else {
                                                completed()
                                                return
                                            }

                                            let _ = (renderedTotalUnreadCount(
                                                accountManager: strongSelf.accountManager,
                                                postbox: stateManager.postbox
                                            )
                                            |> deliverOn(strongSelf.queue)).start(next: { value in
                                                guard let strongSelf = self, let stateManager = strongSelf.stateManager else {
                                                    completed()
                                                    return
                                                }

                                                content.badge = Int(value.0)

                                                if let image = mediaAttachment as? TelegramMediaImage, let resource = largestImageRepresentation(image.representations)?.resource {
                                                    if let mediaData = mediaData {
                                                        stateManager.postbox.mediaBox.storeResourceData(resource.id, data: mediaData, synchronous: true)
                                                    }
                                                    if let storedPath = stateManager.postbox.mediaBox.completedResourcePath(resource, pathExtension: "jpg") {
                                                        if let attachment = try? UNNotificationAttachment(identifier: "image", url: URL(fileURLWithPath: storedPath), options: nil) {
                                                            content.attachments.append(attachment)
                                                        }
                                                    }
                                                } else if let file = mediaAttachment as? TelegramMediaFile {
                                                    if file.isStaticSticker {
                                                        let resource = file.resource

                                                        if let mediaData = mediaData {
                                                            stateManager.postbox.mediaBox.storeResourceData(resource.id, data: mediaData, synchronous: true)
                                                        }
                                                        if let storedPath = stateManager.postbox.mediaBox.completedResourcePath(resource) {
                                                            if let data = try? Data(contentsOf: URL(fileURLWithPath: storedPath)), let image = WebP.convert(fromWebP: data) {
                                                                let tempFile = TempBox.shared.tempFile(fileName: "image.png")
                                                                let _ = try? image.pngData()?.write(to: URL(fileURLWithPath: tempFile.path))
                                                                if let attachment = try? UNNotificationAttachment(identifier: "image", url: URL(fileURLWithPath: tempFile.path), options: nil) {
                                                                    content.attachments.append(attachment)
                                                                }
                                                            }
                                                        }
                                                    } else if file.isAnimatedSticker {
                                                        let resource = file.resource

                                                        if let mediaData = mediaData {
                                                            stateManager.postbox.mediaBox.storeResourceData(resource.id, data: mediaData, synchronous: true)
                                                        }
                                                        if let storedPath = stateManager.postbox.mediaBox.completedResourcePath(resource) {
                                                            if let data = try? Data(contentsOf: URL(fileURLWithPath: storedPath)), let image = convertLottieImage(data: data) {
                                                                let tempFile = TempBox.shared.tempFile(fileName: "image.png")
                                                                let _ = try? image.pngData()?.write(to: URL(fileURLWithPath: tempFile.path))
                                                                if let attachment = try? UNNotificationAttachment(identifier: "image", url: URL(fileURLWithPath: tempFile.path), options: nil) {
                                                                    content.attachments.append(attachment)
                                                                }
                                                            }
                                                        }
                                                    } else if file.isVideo, let representation = file.previewRepresentations.first {
                                                        let resource = representation.resource

                                                        if let mediaData = mediaData {
                                                            stateManager.postbox.mediaBox.storeResourceData(resource.id, data: mediaData, synchronous: true)
                                                        }
                                                        if let storedPath = stateManager.postbox.mediaBox.completedResourcePath(resource, pathExtension: "jpg") {
                                                            if let attachment = try? UNNotificationAttachment(identifier: "image", url: URL(fileURLWithPath: storedPath), options: nil) {
                                                                content.attachments.append(attachment)
                                                            }
                                                        }
                                                    }
                                                }

                                                updateCurrentContent(content.asNotificationContent())

                                                completed()
                                            })
                                        })
                                    }
                                }

                                let pollSignal: Signal<Never, NoError>

                                stateManager.network.shouldKeepConnection.set(.single(true))
                                if peerId.namespace == Namespaces.Peer.CloudChannel {
                                    pollSignal = standalonePollChannelOnce(
                                        postbox: stateManager.postbox,
                                        network: stateManager.network,
                                        peerId: peerId,
                                        stateManager: stateManager
                                    )
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

                                    pollSignal = signal
                                }

                                strongSelf.pollDisposable.set(pollSignal.start(completed: {
                                    pollCompletion()
                                }))
                            } else {
                                completed()
                            }
                        case let .deleteMessage(ids):
                            let mediaBox = stateManager.postbox.mediaBox
                            let _ = (stateManager.postbox.transaction { transaction -> Void in
                                _internal_deleteMessages(transaction: transaction, mediaBox: mediaBox, ids: ids, deleteMedia: true)
                            }
                            |> deliverOn(strongSelf.queue)).start(completed: {
                                UNUserNotificationCenter.current().getDeliveredNotifications(completionHandler: { notifications in
                                    var removeIdentifiers: [String] = []
                                    for notification in notifications {
                                        if let peerIdString = notification.request.content.userInfo["peerId"] as? String, let peerIdValue = Int64(peerIdString), let messageIdString = notification.request.content.userInfo["msg_id"] as? String, let messageIdValue = Int32(messageIdString) {
                                            for id in ids {
                                                if PeerId(peerIdValue) == id.peerId && messageIdValue == id.id {
                                                    removeIdentifiers.append(notification.request.identifier)
                                                }
                                            }
                                        }
                                    }

                                    let completeRemoval: () -> Void = {
                                        guard let strongSelf = self else {
                                            return
                                        }
                                        let _ = (renderedTotalUnreadCount(
                                            accountManager: strongSelf.accountManager,
                                            postbox: stateManager.postbox
                                        )
                                        |> deliverOn(strongSelf.queue)).start(next: { value in
                                            var content = NotificationContent()
                                            content.badge = Int(value.0)

                                            updateCurrentContent(content.asNotificationContent())

                                            completed()
                                        })
                                    }

                                    if !removeIdentifiers.isEmpty {
                                        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: removeIdentifiers)
                                        queue.after(1.0, {
                                            completeRemoval()
                                        })
                                    } else {
                                        completeRemoval()
                                    }
                                })
                            })
                        case let .readMessage(id):
                            let _ = (stateManager.postbox.transaction { transaction -> Void in
                                transaction.applyIncomingReadMaxId(id)
                            }
                            |> deliverOn(strongSelf.queue)).start(completed: {
                                UNUserNotificationCenter.current().getDeliveredNotifications(completionHandler: { notifications in
                                    var removeIdentifiers: [String] = []
                                    for notification in notifications {
                                        if let peerIdString = notification.request.content.userInfo["peerId"] as? String, let peerIdValue = Int64(peerIdString), let messageIdString = notification.request.content.userInfo["msg_id"] as? String, let messageIdValue = Int32(messageIdString) {
                                            if PeerId(peerIdValue) == id.peerId && messageIdValue <= id.id {
                                                removeIdentifiers.append(notification.request.identifier)
                                            }
                                        }
                                    }

                                    let completeRemoval: () -> Void = {
                                        guard let strongSelf = self else {
                                            return
                                        }
                                        let _ = (renderedTotalUnreadCount(
                                            accountManager: strongSelf.accountManager,
                                            postbox: stateManager.postbox
                                        )
                                        |> deliverOn(strongSelf.queue)).start(next: { value in
                                            var content = NotificationContent()
                                            content.badge = Int(value.0)

                                            updateCurrentContent(content.asNotificationContent())

                                            completed()
                                        })
                                    }

                                    if !removeIdentifiers.isEmpty {
                                        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: removeIdentifiers)
                                        queue.after(1.0, {
                                            completeRemoval()
                                        })
                                    } else {
                                        completeRemoval()
                                    }
                                })
                            })
                        }
                    } else {
                        let content = NotificationContent()
                        updateCurrentContent(content.asNotificationContent())

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
