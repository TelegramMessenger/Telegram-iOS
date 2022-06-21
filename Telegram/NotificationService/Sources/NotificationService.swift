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
import Intents
import PersistentStringHash
import CallKit
import AppLockState
import NotificationsPresentationData

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
    guard let animation = LottieInstance(data: decompressedData, fitzModifier: .none, colorReplacements: nil, cacheKey: "") else {
        return nil
    }
    let size = animation.dimensions.fitted(CGSize(width: 200.0, height: 200.0))
    let context = DrawingContext(size: size, scale: 1.0, opaque: false, clear: true)
    animation.renderFrame(with: 0, into: context.bytes.assumingMemoryBound(to: UInt8.self), width: Int32(context.scaledSize.width), height: Int32(context.scaledSize.height), bytesPerRow: Int32(context.bytesPerRow))
    return context.generateImage()
}

private func testAvatarImage(size: CGSize) -> UIImage? {
    UIGraphicsBeginImageContextWithOptions(size, false, 2.0)
    let context = UIGraphicsGetCurrentContext()!

    context.beginPath()
    context.addEllipse(in: CGRect(x: 0.0, y: 0.0, width: size.width, height: size.height))
    context.clip()

    context.setFillColor(UIColor.red.cgColor)
    context.fill(CGRect(origin: CGPoint(), size: size))

    let image = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    return image
}

private func avatarRoundImage(size: CGSize, source: UIImage) -> UIImage? {
    UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
    let context = UIGraphicsGetCurrentContext()

    context?.beginPath()
    context?.addEllipse(in: CGRect(x: 0.0, y: 0.0, width: size.width, height: size.height))
    context?.clip()

    source.draw(in: CGRect(origin: CGPoint(), size: size))

    let image = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    return image
}

private extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(red: CGFloat((rgb >> 16) & 0xff) / 255.0, green: CGFloat((rgb >> 8) & 0xff) / 255.0, blue: CGFloat(rgb & 0xff) / 255.0, alpha: 1.0)
    }
}

private let gradientColors: [NSArray] = [
    [UIColor(rgb: 0xff516a).cgColor, UIColor(rgb: 0xff885e).cgColor],
    [UIColor(rgb: 0xffa85c).cgColor, UIColor(rgb: 0xffcd6a).cgColor],
    [UIColor(rgb: 0x665fff).cgColor, UIColor(rgb: 0x82b1ff).cgColor],
    [UIColor(rgb: 0x54cb68).cgColor, UIColor(rgb: 0xa0de7e).cgColor],
    [UIColor(rgb: 0x4acccd).cgColor, UIColor(rgb: 0x00fcfd).cgColor],
    [UIColor(rgb: 0x2a9ef1).cgColor, UIColor(rgb: 0x72d5fd).cgColor],
    [UIColor(rgb: 0xd669ed).cgColor, UIColor(rgb: 0xe0a2f3).cgColor],
]

private func avatarViewLettersImage(size: CGSize, peerId: PeerId, letters: [String]) -> UIImage? {
    UIGraphicsBeginImageContextWithOptions(size, false, 2.0)
    let context = UIGraphicsGetCurrentContext()

    context?.beginPath()
    context?.addEllipse(in: CGRect(x: 0.0, y: 0.0, width: size.width, height: size.height))
    context?.clip()

    let colorIndex: Int
    if peerId.namespace == .max {
        colorIndex = 0
    } else {
        colorIndex = abs(Int(clamping: peerId.id._internalGetInt64Value()))
    }

    let colorsArray = gradientColors[colorIndex % gradientColors.count]
    var locations: [CGFloat] = [1.0, 0.0]
    let gradient = CGGradient(colorsSpace: deviceColorSpace, colors: colorsArray, locations: &locations)!

    context?.drawLinearGradient(gradient, start: CGPoint(), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())

    context?.setBlendMode(.normal)

    let string = letters.count == 0 ? "" : (letters[0] + (letters.count == 1 ? "" : letters[1]))
    let attributedString = NSAttributedString(string: string, attributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 20.0), NSAttributedString.Key.foregroundColor: UIColor.white])

    let line = CTLineCreateWithAttributedString(attributedString)
    let lineBounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)

    let lineOffset = CGPoint(x: string == "B" ? 1.0 : 0.0, y: 0.0)
    let lineOrigin = CGPoint(x: floor(-lineBounds.origin.x + (size.width - lineBounds.size.width) / 2.0) + lineOffset.x, y: floor(-lineBounds.origin.y + (size.height - lineBounds.size.height) / 2.0))

    context?.translateBy(x: size.width / 2.0, y: size.height / 2.0)
    context?.scaleBy(x: 1.0, y: -1.0)
    context?.translateBy(x: -size.width / 2.0, y: -size.height / 2.0)

    context?.translateBy(x: lineOrigin.x, y: lineOrigin.y)
    if let context = context {
        CTLineDraw(line, context)
    }
    context?.translateBy(x: -lineOrigin.x, y: -lineOrigin.y)

    let image = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    return image
}

private func avatarImage(path: String?, peerId: PeerId, letters: [String], size: CGSize) -> UIImage {
    if let path = path, let image = UIImage(contentsOfFile: path), let roundImage = avatarRoundImage(size: size, source: image) {
        return roundImage
    } else {
        return avatarViewLettersImage(size: size, peerId: peerId, letters: letters)!
    }
}

private func storeTemporaryImage(path: String) -> String {
    let imagesPath = NSTemporaryDirectory() + "/aps-data"
    let _ = try? FileManager.default.createDirectory(at: URL(fileURLWithPath: imagesPath), withIntermediateDirectories: true, attributes: nil)

    let tempPath = imagesPath + "\(path.persistentHashValue)"
    if FileManager.default.fileExists(atPath: tempPath) {
        return tempPath
    }

    let _ = try? FileManager.default.copyItem(at: URL(fileURLWithPath: path), to: URL(fileURLWithPath: tempPath))

    return tempPath
}

@available(iOS 15.0, *)
private func peerAvatar(mediaBox: MediaBox, accountPeerId: PeerId, peer: Peer) -> INImage? {
    if let resource = smallestImageRepresentation(peer.profileImageRepresentations)?.resource, let path = mediaBox.completedResourcePath(resource) {
        let cachedPath = mediaBox.cachedRepresentationPathForId(resource.id.stringRepresentation, representationId: "intents.png", keepDuration: .shortLived)
        if let _ = fileSize(cachedPath) {
            return INImage(url: URL(fileURLWithPath: storeTemporaryImage(path: cachedPath)))
        } else {
            let image = avatarImage(path: path, peerId: peer.id, letters: peer.displayLetters, size: CGSize(width: 50.0, height: 50.0))
            if let data = image.pngData() {
                let _ = try? data.write(to: URL(fileURLWithPath: cachedPath), options: .atomic)
            }

            return INImage(url: URL(fileURLWithPath: storeTemporaryImage(path: cachedPath)))
        }
    }

    let cachedPath = mediaBox.cachedRepresentationPathForId("lettersAvatar2-\(peer.displayLetters.joined(separator: ","))", representationId: "intents.png", keepDuration: .shortLived)
    if let _ = fileSize(cachedPath) {
        return INImage(url: URL(fileURLWithPath: storeTemporaryImage(path: cachedPath)))
    } else {
        let image = avatarImage(path: nil, peerId: peer.id, letters: peer.displayLetters, size: CGSize(width: 50.0, height: 50.0))
        if let data = image.pngData() {
            let _ = try? data.write(to: URL(fileURLWithPath: cachedPath), options: .atomic)
        }
        return INImage(url: URL(fileURLWithPath: storeTemporaryImage(path: cachedPath)))
    }
}

@available(iOSApplicationExtension 10.0, iOS 10.0, *)
private struct NotificationContent: CustomStringConvertible {
    var title: String?
    var subtitle: String?
    var body: String?
    var threadId: String?
    var sound: String?
    var badge: Int?
    var category: String?
    var userInfo: [AnyHashable: Any] = [:]
    var attachments: [UNNotificationAttachment] = []

    var senderPerson: INPerson?
    var senderImage: INImage?
    
    var isLockedMessage: String?
    
    init(isLockedMessage: String?) {
        self.isLockedMessage = isLockedMessage
    }

    var description: String {
        var string = "{"
        string += " title: \(String(describing: self.title))\n"
        string += " subtitle: \(String(describing: self.subtitle))\n"
        string += " body: \(String(describing: self.body)),\n"
        string += " threadId: \(String(describing: self.threadId)),\n"
        string += " sound: \(String(describing: self.sound)),\n"
        string += " badge: \(String(describing: self.badge)),\n"
        string += " category: \(String(describing: self.category)),\n"
        string += " userInfo: \(String(describing: self.userInfo)),\n"
        string += " senderImage: \(self.senderImage != nil ? "non-empty" : "empty"),\n"
        string += " isLockedMessage: \(String(describing: self.isLockedMessage)),\n"
        string += "}"
        return string
    }

    mutating func addSenderInfo(mediaBox: MediaBox, accountPeerId: PeerId, peer: Peer) {
        if #available(iOS 15.0, *) {
            let image = peerAvatar(mediaBox: mediaBox, accountPeerId: accountPeerId, peer: peer)

            self.senderImage = image

            var personNameComponents = PersonNameComponents()
            personNameComponents.nickname = peer.debugDisplayTitle

            self.senderPerson = INPerson(
                personHandle: INPersonHandle(value: "\(peer.id.toInt64())", type: .unknown),
                nameComponents: personNameComponents,
                displayName: peer.debugDisplayTitle,
                image: image,
                contactIdentifier: nil,
                customIdentifier: "\(peer.id.toInt64())",
                isMe: false,
                suggestionType: .none
            )
        }
    }

    func generate() -> UNNotificationContent {
        var content = UNMutableNotificationContent()

        if let title = self.title {
            content.title = title
        }
        if let subtitle = self.subtitle {
            content.subtitle = subtitle
        }
        if let body = self.body {
            content.body = body
        }
        
        if !content.title.isEmpty || !content.subtitle.isEmpty || !content.body.isEmpty {
            if let isLockedMessage = self.isLockedMessage {
                content.body = isLockedMessage
            }
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

        if #available(iOS 15.0, *) {
            if self.isLockedMessage == nil, let senderPerson = self.senderPerson, let customIdentifier = senderPerson.customIdentifier {
                let mePerson = INPerson(
                    personHandle: INPersonHandle(value: "0", type: .unknown),
                    nameComponents: nil,
                    displayName: nil,
                    image: nil,
                    contactIdentifier: nil,
                    customIdentifier: nil,
                    isMe: true,
                    suggestionType: .none
                )

                let incomingCommunicationIntent = INSendMessageIntent(
                    recipients: [mePerson],
                    outgoingMessageType: .outgoingMessageText,
                    content: content.body,
                    speakableGroupName: INSpeakableString(spokenPhrase: senderPerson.displayName),
                    conversationIdentifier: "\(customIdentifier)",
                    serviceName: nil,
                    sender: senderPerson,
                    attachments: nil
                )

                if let senderImage = self.senderImage {
                    incomingCommunicationIntent.setImage(senderImage, forParameterNamed: \.sender)
                }

                let interaction = INInteraction(intent: incomingCommunicationIntent, response: nil)
                interaction.direction = .incoming
                interaction.donate(completion: nil)

                do {
                    content = try content.updating(from: incomingCommunicationIntent) as! UNMutableNotificationContent
                } catch let e {
                    print("Exception: \(e)")
                }
            }
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

    init?(queue: Queue, updateCurrentContent: @escaping (NotificationContent) -> Void, completed: @escaping () -> Void, payload: [AnyHashable: Any]) {
        self.queue = queue

        let episode = String(UInt32.random(in: 0 ..< UInt32.max), radix: 16)

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

        self.accountManager = AccountManager<TelegramAccountManagerTypes>(basePath: rootPath + "/accounts-metadata", isTemporary: true, isReadOnly: false, useCaches: false, removeDatabaseOnError: false)

        let deviceSpecificEncryptionParameters = BuildConfig.deviceSpecificEncryptionParameters(rootPath, baseAppBundleId: baseAppBundleId)
        self.encryptionParameters = ValueBoxEncryptionParameters(forceEncryptionIfNoSet: false, key: ValueBoxEncryptionParameters.Key(data: deviceSpecificEncryptionParameters.key)!, salt: ValueBoxEncryptionParameters.Salt(data: deviceSpecificEncryptionParameters.salt)!)

        let networkArguments = NetworkInitializationArguments(apiId: apiId, apiHash: apiHash, languagesCategory: languagesCategory, appVersion: appVersion, voipMaxLayer: 0, voipVersions: [], appData: .single(buildConfig.bundleData(withAppToken: nil, signatureDict: nil)), autolockDeadine: .single(nil), encryptionProvider: OpenSSLEncryptionProvider(), resolvedDeviceName: nil)
        
        let isLockedMessage: String?
        if let data = try? Data(contentsOf: URL(fileURLWithPath: appLockStatePath(rootPath: rootPath))), let state = try? JSONDecoder().decode(LockState.self, from: data), isAppLocked(state: state) {
            if let notificationsPresentationData = try? Data(contentsOf: URL(fileURLWithPath: notificationsPresentationDataPath(rootPath: rootPath))), let notificationsPresentationDataValue = try? JSONDecoder().decode(NotificationsPresentationData.self, from: notificationsPresentationData) {
                isLockedMessage = notificationsPresentationDataValue.applicationLockedMessageString
            } else {
                isLockedMessage = "You have a new message"
            }
        } else {
            isLockedMessage = nil
        }
        
        let incomingCallMessage: String
        if let notificationsPresentationData = try? Data(contentsOf: URL(fileURLWithPath: notificationsPresentationDataPath(rootPath: rootPath))), let notificationsPresentationDataValue = try? JSONDecoder().decode(NotificationsPresentationData.self, from: notificationsPresentationData) {
            incomingCallMessage = notificationsPresentationDataValue.incomingCallString
        } else {
            incomingCallMessage = "is calling you"
        }

        Logger.shared.log("NotificationService \(episode)", "Begin processing payload \(payload)")

        guard var encryptedPayload = payload["p"] as? String else {
            Logger.shared.log("NotificationService \(episode)", "Invalid payload 1")
            return nil
        }
        encryptedPayload = encryptedPayload.replacingOccurrences(of: "-", with: "+")
        encryptedPayload = encryptedPayload.replacingOccurrences(of: "_", with: "/")
        while encryptedPayload.count % 4 != 0 {
            encryptedPayload.append("=")
        }
        guard let payloadData = Data(base64Encoded: encryptedPayload) else {
            Logger.shared.log("NotificationService \(episode)", "Invalid payload 2")
            return nil
        }

        let _ = (combineLatest(queue: self.queue,
            self.accountManager.accountRecords(),
            self.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.inAppNotificationSettings, ApplicationSpecificSharedDataKeys.voiceCallSettings])
        )
        |> take(1)
        |> deliverOn(self.queue)).start(next: { [weak self] records, sharedData in
            var recordId: AccountRecordId?
            var isCurrentAccount: Bool = false
            var customSoundPath: String?

            if let keyId = notificationPayloadKeyId(data: payloadData) {
                outer: for listRecord in records.records {
                    for attribute in listRecord.attributes {
                        if case let .backupData(backupData) = attribute {
                            if let notificationEncryptionKeyId = backupData.data?.notificationEncryptionKeyId {
                                if keyId == notificationEncryptionKeyId {
                                    recordId = listRecord.id
                                    isCurrentAccount = records.currentRecord?.id == listRecord.id
                                    break outer
                                }
                            }
                        }
                    }
                }
            }

            let inAppNotificationSettings = sharedData.entries[ApplicationSpecificSharedDataKeys.inAppNotificationSettings]?.get(InAppNotificationSettings.self) ?? InAppNotificationSettings.defaultSettings
            
            customSoundPath = inAppNotificationSettings.customSound
            
            let voiceCallSettings: VoiceCallSettings
            if let value = sharedData.entries[ApplicationSpecificSharedDataKeys.voiceCallSettings]?.get(VoiceCallSettings.self) {
                voiceCallSettings = value
            } else {
                voiceCallSettings = VoiceCallSettings.defaultSettings
            }

            guard let strongSelf = self, let recordId = recordId else {
                Logger.shared.log("NotificationService \(episode)", "Couldn't find a matching decryption key")

                let content = NotificationContent(isLockedMessage: nil)
                updateCurrentContent(content)
                completed()

                return
            }

            let _ = (standaloneStateManager(
                accountManager: strongSelf.accountManager,
                networkArguments: networkArguments,
                id: recordId,
                encryptionParameters: strongSelf.encryptionParameters,
                rootPath: rootPath,
                auxiliaryMethods: accountAuxiliaryMethods
            )
            |> deliverOn(strongSelf.queue)).start(next: { stateManager in
                guard let strongSelf = self else {
                    return
                }
                guard let stateManager = stateManager else {
                    Logger.shared.log("NotificationService \(episode)", "Didn't receive stateManager")

                    let content = NotificationContent(isLockedMessage: nil)
                    updateCurrentContent(content)
                    completed()
                    return
                }
                strongSelf.stateManager = stateManager
                
                let settings = stateManager.postbox.transaction { transaction -> NotificationSoundList? in
                    return _internal_cachedNotificationSoundList(transaction: transaction)
                }

                strongSelf.notificationKeyDisposable.set((combineLatest(queue: strongSelf.queue,
                    existingMasterNotificationsKey(postbox: stateManager.postbox),
                    settings
                ) |> deliverOn(strongSelf.queue)).start(next: { notificationsKey, notificationSoundList in
                    guard let strongSelf = self else {
                        let content = NotificationContent(isLockedMessage: nil)
                        updateCurrentContent(content)
                        completed()

                        return
                    }
                    guard let notificationsKey = notificationsKey else {
                        Logger.shared.log("NotificationService \(episode)", "Didn't receive decryption key")

                        let content = NotificationContent(isLockedMessage: nil)
                        updateCurrentContent(content)
                        completed()

                        return
                    }
                    guard let decryptedPayload = decryptedNotificationPayload(key: notificationsKey, data: payloadData) else {
                        Logger.shared.log("NotificationService \(episode)", "Couldn't decrypt payload")

                        let content = NotificationContent(isLockedMessage: nil)
                        updateCurrentContent(content)
                        completed()

                        return
                    }
                    guard let payloadJson = try? JSONSerialization.jsonObject(with: decryptedPayload, options: []) as? [String: Any] else {
                        Logger.shared.log("NotificationService \(episode)", "Couldn't process payload as JSON")

                        let content = NotificationContent(isLockedMessage: nil)
                        updateCurrentContent(content)
                        completed()

                        return
                    }

                    Logger.shared.log("NotificationService \(episode)", "Decrypted payload: \(payloadJson)")

                    var peerId: PeerId?
                    var messageId: MessageId.Id?
                    var mediaAttachment: Media?
                    var downloadNotificationSound: (file: TelegramMediaFile, path: String, fileName: String)?

                    var interactionAuthorId: PeerId?

                    struct CallData {
                        var id: Int64
                        var accessHash: Int64
                        var fromId: PeerId
                        var updates: String
                        var accountId: Int64
                        var peer: EnginePeer?
                    }

                    var callData: CallData?

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
                    } else if let encryptionIdString = payloadJson["encryption_id"] as? String {
                        if let encryptionIdValue = Int64(encryptionIdString) {
                            peerId = PeerId(namespace: Namespaces.Peer.SecretChat, id: PeerId.Id._internalFromInt64Value(encryptionIdValue))
                        }
                    }

                    if let callIdString = payloadJson["call_id"] as? String, let callAccessHashString = payloadJson["call_ah"] as? String, let peerId = peerId, let updates = payloadJson["updates"] as? String {
                        if let callId = Int64(callIdString), let callAccessHash = Int64(callAccessHashString) {
                            var peer: EnginePeer?
                            
                            var updateString = updates
                            updateString = updateString.replacingOccurrences(of: "-", with: "+")
                            updateString = updateString.replacingOccurrences(of: "_", with: "/")
                            while updateString.count % 4 != 0 {
                                updateString.append("=")
                            }
                            if let updateData = Data(base64Encoded: updateString) {
                                if let callUpdate = AccountStateManager.extractIncomingCallUpdate(data: updateData) {
                                    peer = callUpdate.peer
                                }
                            }
                            
                            callData = CallData(
                                id: callId,
                                accessHash: callAccessHash,
                                fromId: peerId,
                                updates: updates,
                                accountId: recordId.int64,
                                peer: peer
                            )
                        }
                    }

                    enum Action {
                        case logout
                        case poll(peerId: PeerId, content: NotificationContent)
                        case deleteMessage([MessageId])
                        case readMessage(MessageId)
                        case call(CallData)
                    }

                    var action: Action?

                    if let callData = callData {
                        action = .call(callData)
                    } else if let locKey = payloadJson["loc-key"] as? String {
                        switch locKey {
                        case "SESSION_REVOKE":
                            action = .logout
                        case "MESSAGE_MUTED":
                            if let peerId = peerId {
                                action = .poll(peerId: peerId, content: NotificationContent(isLockedMessage: nil))
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
                            var content: NotificationContent = NotificationContent(isLockedMessage: isLockedMessage)
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
                                interactionAuthorId = peerId
                            }

                            if peerId.namespace == Namespaces.Peer.CloudUser {
                                content.userInfo["from_id"] = "\(peerId.id._internalGetInt64Value())"
                            } else if peerId.namespace == Namespaces.Peer.CloudGroup {
                                content.userInfo["chat_id"] = "\(peerId.id._internalGetInt64Value())"
                            } else if peerId.namespace == Namespaces.Peer.CloudChannel {
                                content.userInfo["channel_id"] = "\(peerId.id._internalGetInt64Value())"
                            }

                            content.userInfo["peerId"] = "\(peerId.toInt64())"
                            content.userInfo["accountId"] = "\(recordId.int64)"

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

                            if let ringtoneString = aps["ringtone"] as? String, let fileId = Int64(ringtoneString) {
                                content.sound = "0.m4a"
                                if let notificationSoundList = notificationSoundList {
                                    for sound in notificationSoundList.sounds {
                                        if sound.file.fileId.id == fileId {
                                            let containerSoundsPath = appGroupUrl.path + "/Library/Sounds"
                                            let soundFileName = "\(fileId).mp3"
                                            let soundFilePath = containerSoundsPath + "/\(soundFileName)"
                                            
                                            if !FileManager.default.fileExists(atPath: soundFilePath) {
                                                let _ = try? FileManager.default.createDirectory(atPath: containerSoundsPath, withIntermediateDirectories: true, attributes: nil)
                                                if let filePath = stateManager.postbox.mediaBox.completedResourcePath(id: sound.file.resource.id, pathExtension: nil) {
                                                    let _ = try? FileManager.default.copyItem(atPath: filePath, toPath: soundFilePath)
                                                } else {
                                                    downloadNotificationSound = (sound.file, soundFilePath, soundFileName)
                                                }
                                            }
                                            
                                            content.sound = soundFileName
                                            break
                                        }
                                    }
                                }
                            } else if let sound = aps["sound"] as? String {
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

                            updateCurrentContent(content)
                        }
                    }

                    if let action = action {
                        switch action {
                        case let .call(callData):
                            let voipPayload: [AnyHashable: Any] = [
                                "call_id": "\(callData.id)",
                                "call_ah": "\(callData.accessHash)",
                                "from_id": "\(callData.fromId.id._internalGetInt64Value())",
                                "updates": callData.updates,
                                "accountId": "\(callData.accountId)"
                            ]

                            if #available(iOS 14.5, *), voiceCallSettings.enableSystemIntegration {
                                Logger.shared.log("NotificationService \(episode)", "Will report voip notification")
                                let content = NotificationContent(isLockedMessage: nil)
                                updateCurrentContent(content)
                                
                                CXProvider.reportNewIncomingVoIPPushPayload(voipPayload, completion: { error in
                                    Logger.shared.log("NotificationService \(episode)", "Did report voip notification, error: \(String(describing: error))")

                                    completed()
                                })
                            } else {
                                var content = NotificationContent(isLockedMessage: nil)
                                if let peer = callData.peer {
                                    content.title = peer.debugDisplayTitle
                                    content.body = incomingCallMessage
                                } else {
                                    content.body = "Incoming Call"
                                }
                                
                                updateCurrentContent(content)
                                completed()
                            }
                        case .logout:
                            Logger.shared.log("NotificationService \(episode)", "Will logout")

                            let content = NotificationContent(isLockedMessage: nil)
                            updateCurrentContent(content)
                            completed()
                        case let .poll(peerId, initialContent):
                            Logger.shared.log("NotificationService \(episode)", "Will poll")
                            if let stateManager = strongSelf.stateManager {
                                let pollCompletion: (NotificationContent) -> Void = { content in
                                    var content = content

                                    queue.async {
                                        guard let strongSelf = self, let stateManager = strongSelf.stateManager else {
                                            let content = NotificationContent(isLockedMessage: isLockedMessage)
                                            updateCurrentContent(content)
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
                                        
                                        var fetchNotificationSoundSignal: Signal<Data?, NoError> = .single(nil)
                                        if let (downloadNotificationSound, _, _) = downloadNotificationSound {
                                            var fetchResource: TelegramMultipartFetchableResource?
                                            fetchResource = downloadNotificationSound.resource as? TelegramMultipartFetchableResource

                                            if let resource = fetchResource {
                                                if let path = strongSelf.stateManager?.postbox.mediaBox.completedResourcePath(resource), let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
                                                    fetchNotificationSoundSignal = .single(data)
                                                } else {
                                                    let intervals: Signal<[(Range<Int>, MediaBoxFetchPriority)], NoError> = .single([(0 ..< Int(Int32.max), MediaBoxFetchPriority.maximum)])
                                                    fetchNotificationSoundSignal = Signal { subscriber in
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

                                        Logger.shared.log("NotificationService \(episode)", "Will fetch media")
                                        let _ = (combineLatest(queue: queue,
                                            fetchMediaSignal
                                            |> timeout(10.0, queue: queue, alternate: .single(nil)),
                                            fetchNotificationSoundSignal
                                            |> timeout(10.0, queue: queue, alternate: .single(nil))
                                        )
                                        |> deliverOn(queue)).start(next: { mediaData, notificationSoundData in
                                            guard let strongSelf = self, let stateManager = strongSelf.stateManager else {
                                                completed()
                                                return
                                            }

                                            Logger.shared.log("NotificationService \(episode)", "Did fetch media \(mediaData == nil ? "Non-empty" : "Empty")")
                                            
                                            if let notificationSoundData = notificationSoundData {
                                                Logger.shared.log("NotificationService \(episode)", "Did fetch notificationSoundData")
                                                
                                                if let (_, filePath, _) = downloadNotificationSound {
                                                    let _ = try? notificationSoundData.write(to: URL(fileURLWithPath: filePath))
                                                }
                                            }

                                            Logger.shared.log("NotificationService \(episode)", "Will get unread count")
                                            let _ = (getCurrentRenderedTotalUnreadCount(
                                                accountManager: strongSelf.accountManager,
                                                postbox: stateManager.postbox
                                            )
                                            |> deliverOn(strongSelf.queue)).start(next: { value in
                                                guard let strongSelf = self, let stateManager = strongSelf.stateManager else {
                                                    completed()
                                                    return
                                                }

                                                if isCurrentAccount {
                                                    content.badge = Int(value.0)
                                                }

                                                Logger.shared.log("NotificationService \(episode)", "Unread count: \(value.0), isCurrentAccount: \(isCurrentAccount)")

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

                                                Logger.shared.log("NotificationService \(episode)", "Updating content to \(content)")

                                                updateCurrentContent(content)

                                                completed()
                                            })
                                        })
                                    }
                                }

                                let pollSignal: Signal<Never, NoError>

                                stateManager.network.shouldKeepConnection.set(.single(true))
                                if peerId.namespace == Namespaces.Peer.CloudChannel {
                                    Logger.shared.log("NotificationService \(episode)", "Will poll channel \(peerId)")

                                    pollSignal = standalonePollChannelOnce(
                                        postbox: stateManager.postbox,
                                        network: stateManager.network,
                                        peerId: peerId,
                                        stateManager: stateManager
                                    )
                                } else {
                                    Logger.shared.log("NotificationService \(episode)", "Will perform non-specific getDifference")
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

                                let pollWithUpdatedContent: Signal<NotificationContent, NoError>
                                if let interactionAuthorId = interactionAuthorId {
                                    pollWithUpdatedContent = stateManager.postbox.transaction { transaction -> NotificationContent in
                                        var content = initialContent

                                        if inAppNotificationSettings.displayNameOnLockscreen, let peer = transaction.getPeer(interactionAuthorId) {
                                            content.addSenderInfo(mediaBox: stateManager.postbox.mediaBox, accountPeerId: stateManager.accountPeerId, peer: peer)
                                        }

                                        return content
                                    }
                                    |> then(
                                        pollSignal
                                        |> map { _ -> NotificationContent in }
                                    )
                                } else {
                                    pollWithUpdatedContent = pollSignal
                                    |> map { _ -> NotificationContent in }
                                }

                                var updatedContent = initialContent
                                strongSelf.pollDisposable.set(pollWithUpdatedContent.start(next: { content in
                                    updatedContent = content
                                }, completed: {
                                    pollCompletion(updatedContent)
                                }))
                            } else {
                                completed()
                            }
                        case let .deleteMessage(ids):
                            Logger.shared.log("NotificationService \(episode)", "Will delete messages \(ids)")
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
                                        let _ = (getCurrentRenderedTotalUnreadCount(
                                            accountManager: strongSelf.accountManager,
                                            postbox: stateManager.postbox
                                        )
                                        |> deliverOn(strongSelf.queue)).start(next: { value in
                                            var content = NotificationContent(isLockedMessage: nil)
                                            if isCurrentAccount {
                                                content.badge = Int(value.0)
                                            }
                                            Logger.shared.log("NotificationService \(episode)", "Unread count: \(value.0), isCurrentAccount: \(isCurrentAccount)")
                                            Logger.shared.log("NotificationService \(episode)", "Updating content to \(content)")

                                            updateCurrentContent(content)

                                            completed()
                                        })
                                    }

                                    if !removeIdentifiers.isEmpty {
                                        Logger.shared.log("NotificationService \(episode)", "Will try to remove \(removeIdentifiers.count) notifications")
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
                            Logger.shared.log("NotificationService \(episode)", "Will read message \(id)")
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
                                        let _ = (getCurrentRenderedTotalUnreadCount(
                                            accountManager: strongSelf.accountManager,
                                            postbox: stateManager.postbox
                                        )
                                        |> deliverOn(strongSelf.queue)).start(next: { value in
                                            var content = NotificationContent(isLockedMessage: nil)
                                            if isCurrentAccount {
                                                content.badge = Int(value.0)
                                            }

                                            Logger.shared.log("NotificationService \(episode)", "Unread count: \(value.0), isCurrentAccount: \(isCurrentAccount)")
                                            Logger.shared.log("NotificationService \(episode)", "Updating content to \(content)")

                                            updateCurrentContent(content)

                                            completed()
                                        })
                                    }

                                    if !removeIdentifiers.isEmpty {
                                        Logger.shared.log("NotificationService \(episode)", "Will try to remove \(removeIdentifiers.count) notifications")
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
                        let content = NotificationContent(isLockedMessage: nil)
                        updateCurrentContent(content)

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

    private var initialContent: UNNotificationContent?
    private let content = Atomic<NotificationContent?>(value: nil)
    private var contentHandler: ((UNNotificationContent) -> Void)?
    
    override init() {
        super.init()
    }
    
    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.initialContent = request.content
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

                    if let contentHandler = strongSelf.contentHandler {
                        if let content = content.with({ $0 }) {
                            /*let request = UNNotificationRequest(identifier: UUID().uuidString, content: content.generate(), trigger: .none)
                            UNUserNotificationCenter.current().add(request)
                            contentHandler(UNMutableNotificationContent())*/

                            contentHandler(content.generate())
                        } else if let initialContent = strongSelf.initialContent {
                            contentHandler(initialContent)
                        }
                    }
                },
                payload: request.content.userInfo
            ))
        })
    }
    
    override func serviceExtensionTimeWillExpire() {
        if let contentHandler = self.contentHandler {
            if let content = self.content.with({ $0 }) {
                contentHandler(content.generate())
            } else if let initialContent = self.initialContent {
                contentHandler(initialContent)
            }
        }
    }
}
