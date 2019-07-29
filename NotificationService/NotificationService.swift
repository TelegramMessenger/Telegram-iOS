import Foundation
import UserNotifications
#if BUCK
import MtProtoKit
#else
import MtProtoKitDynamic
#endif
import WebP
import BuildConfig
import LightweightAccountData

private var sharedLogger: Logger?

private final class Logger {
    private let maxLength: Int = 2 * 1024 * 1024
    private let maxFiles: Int = 20
    
    private let basePath: String
    private var file: (ManagedFile, Int)?
    
    var logToFile: Bool = true
    var logToConsole: Bool = true
    
    public static func setSharedLogger(_ logger: Logger) {
        sharedLogger = logger
    }
    
    public static var shared: Logger {
        if let sharedLogger = sharedLogger {
            return sharedLogger
        } else {
            assertionFailure()
            let tempLogger = Logger(basePath: "")
            tempLogger.logToFile = false
            tempLogger.logToConsole = false
            return tempLogger
        }
    }
    
    public init(basePath: String) {
        self.basePath = basePath
        //self.logToConsole = false
    }
    
    public func log(_ tag: String, _ what: @autoclosure () -> String) {
        if !self.logToFile && !self.logToConsole {
            return
        }
        
        let string = what()
        
        var rawTime = time_t()
        time(&rawTime)
        var timeinfo = tm()
        localtime_r(&rawTime, &timeinfo)
        
        var curTime = timeval()
        gettimeofday(&curTime, nil)
        let milliseconds = curTime.tv_usec / 1000
        
        var consoleContent: String?
        if self.logToConsole {
            let content = String(format: "[%@] %d-%d-%d %02d:%02d:%02d.%03d %@", arguments: [tag, Int(timeinfo.tm_year) + 1900, Int(timeinfo.tm_mon + 1), Int(timeinfo.tm_mday), Int(timeinfo.tm_hour), Int(timeinfo.tm_min), Int(timeinfo.tm_sec), Int(milliseconds), string])
            consoleContent = content
            print(content)
        }
        
        if self.logToFile {
            let content: String
            if let consoleContent = consoleContent {
                content = consoleContent
            } else {
                content = String(format: "[%@] %d-%d-%d %02d:%02d:%02d.%03d %@", arguments: [tag, Int(timeinfo.tm_year) + 1900, Int(timeinfo.tm_mon + 1), Int(timeinfo.tm_mday), Int(timeinfo.tm_hour), Int(timeinfo.tm_min), Int(timeinfo.tm_sec), Int(milliseconds), string])
            }
            
            var currentFile: ManagedFile?
            var openNew = false
            if let (file, length) = self.file {
                if length >= self.maxLength {
                    self.file = nil
                    openNew = true
                } else {
                    currentFile = file
                }
            } else {
                openNew = true
            }
            if openNew {
                let _ = try? FileManager.default.createDirectory(atPath: self.basePath, withIntermediateDirectories: true, attributes: nil)
                
                var createNew = false
                if let files = try? FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: self.basePath), includingPropertiesForKeys: [URLResourceKey.creationDateKey], options: []) {
                    var minCreationDate: (Date, URL)?
                    var maxCreationDate: (Date, URL)?
                    var count = 0
                    for url in files {
                        if url.lastPathComponent.hasPrefix("log-") {
                            if let values = try? url.resourceValues(forKeys: Set([URLResourceKey.creationDateKey])), let creationDate = values.creationDate {
                                count += 1
                                if minCreationDate == nil || minCreationDate!.0 > creationDate {
                                    minCreationDate = (creationDate, url)
                                }
                                if maxCreationDate == nil || maxCreationDate!.0 < creationDate {
                                    maxCreationDate = (creationDate, url)
                                }
                            }
                        }
                    }
                    if let (_, url) = minCreationDate, count >= self.maxFiles {
                        let _ = try? FileManager.default.removeItem(at: url)
                    }
                    if let (_, url) = maxCreationDate {
                        var value = stat()
                        if stat(url.path, &value) == 0 && Int(value.st_size) < self.maxLength {
                            if let file = ManagedFile(path: url.path, mode: .append) {
                                self.file = (file, Int(value.st_size))
                                currentFile = file
                            }
                        } else {
                            createNew = true
                        }
                    } else {
                        createNew = true
                    }
                }
                
                if createNew {
                    let fileName = String(format: "log-%d-%d-%d_%02d-%02d-%02d.%03d.txt", arguments: [Int(timeinfo.tm_year) + 1900, Int(timeinfo.tm_mon + 1), Int(timeinfo.tm_mday), Int(timeinfo.tm_hour), Int(timeinfo.tm_min), Int(timeinfo.tm_sec), Int(milliseconds)])
                    
                    let path = self.basePath + "/" + fileName
                    
                    if let file = ManagedFile(path: path, mode: .append) {
                        self.file = (file, 0)
                        currentFile = file
                    }
                }
            }
            
            if let currentFile = currentFile {
                if let data = content.data(using: .utf8) {
                    data.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) -> Void in
                        let _ = currentFile.write(bytes, count: data.count)
                    }
                    var newline: UInt8 = 0x0a
                    let _ = currentFile.write(&newline, count: 1)
                    if let file = self.file {
                        self.file = (file.0, file.1 + data.count + 1)
                    } else {
                        assertionFailure()
                    }
                }
            }
        }
    }
}

private func parseBase64(string: String) -> Data? {
    var string = string
    string = string.replacingOccurrences(of: "-", with: "+")
    string = string.replacingOccurrences(of: "_", with: "/")
    while string.count % 4 != 0 {
        string.append("=")
    }
    return Data(base64Encoded: string)
}

enum ParsedMediaAttachment {
    case document(Api.Document)
    case photo(Api.Photo)
}

private func parseAttachment(data: Data) -> (ParsedMediaAttachment, Data)? {
    let reader = BufferReader(Buffer(data: data))
    guard let initialSignature = reader.readInt32() else {
        return nil
    }
    
    let buffer: Buffer
    if initialSignature == 0x3072cfa1 {
        guard let bytes = parseBytes(reader) else {
            return nil
        }
        guard let decompressedData = MTGzip.decompress(bytes.makeData()) else {
            return nil
        }
        buffer = Buffer(data: decompressedData)
    } else {
        buffer = Buffer(data: data)
    }
    
    if let result = Api.parse(buffer) {
        if let photo = result as? Api.Photo {
            return (.photo(photo), buffer.makeData())
        } else if let document = result as? Api.Document {
            return (.document(document), buffer.makeData())
        } else {
            return nil
        }
    } else {
        return nil
    }
}

private func photoSizeDimensions(_ size: Api.PhotoSize) -> CGSize? {
    switch size {
        case let .photoSize(_, _, w, h, _):
            return CGSize(width: CGFloat(w), height: CGFloat(h))
        case let .photoCachedSize(_, _, w, h, _):
            return CGSize(width: CGFloat(w), height: CGFloat(h))
        default:
            return nil
    }
}

private func photoDimensions(_ photo: Api.Photo) -> CGSize? {
    switch photo {
        case let .photo(_, _, _, _, _, sizes, _):
            for size in sizes.reversed() {
                if let dimensions = photoSizeDimensions(size) {
                    return dimensions
                }
            }
            return nil
        case .photoEmpty:
            return nil
    }
}

private func photoSizes(_ photo: Api.Photo) -> [Api.PhotoSize] {
    switch photo {
        case let .photo(_, _, _, _, _, sizes, _):
            return sizes
        case .photoEmpty:
            return []
    }
}

class NotificationService: UNNotificationServiceExtension {
    private let rootPath: String?
    
    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?
    
    var cancelFetch: (() -> Void)?
    
    override init() {
        let appBundleIdentifier = Bundle.main.bundleIdentifier!
        if let lastDotRange = appBundleIdentifier.range(of: ".", options: [.backwards]) {
            let appGroupName = "group.\(appBundleIdentifier[..<lastDotRange.lowerBound])"
            let maybeAppGroupUrl = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupName)
            
            if let appGroupUrl = maybeAppGroupUrl {
                let rootPath = appGroupUrl.path + "/telegram-data"
                self.rootPath = rootPath
                
                if sharedLogger == nil {
                    let logsPath = rootPath + "/notificationServiceLogs"
                    Logger.setSharedLogger(Logger(basePath: logsPath))
                }
            } else {
                self.rootPath = nil
                preconditionFailure()
            }
        } else {
            self.rootPath = nil
            preconditionFailure()
        }
        
        super.init()
    }

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        guard let rootPath = self.rootPath else {
            contentHandler(request.content)
            return
        }
        let accountInfos = self.rootPath.flatMap({ rootPath in
            loadAccountsData(rootPath: rootPath)
        }) ?? StoredAccountInfos(proxy: nil, accounts: [])
        
        self.contentHandler = contentHandler
        self.bestAttemptContent = request.content.mutableCopy() as? UNMutableNotificationContent
        
        var encryptedData: Data?
        if let encryptedPayload = request.content.userInfo["p"] as? String {
            encryptedData = parseBase64(string: encryptedPayload)
        }
        
        Logger.shared.log("NotificationService", "received notification \(request), parsed encryptedData \(String(describing: encryptedData))")
        
        if let (account, dict) = encryptedData.flatMap({ decryptedNotificationPayload(accounts: accountInfos.accounts, data: $0) }) {
            Logger.shared.log("NotificationService", "decrypted notification")
            var userInfo = self.bestAttemptContent?.userInfo ?? [:]
            userInfo["accountId"] = account.id
            
            var peerId: PeerId?
            var messageId: Int32?
            var silent = false
            
            if let msgId = dict["msg_id"] as? String {
                userInfo["msg_id"] = msgId
                messageId = Int32(msgId)
            }
            if let fromId = dict["from_id"] as? String {
                userInfo["from_id"] = fromId
                if let id = Int32(fromId) {
                    peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: id)
                }
            }
            if let chatId = dict["chat_id"] as? String {
                userInfo["chat_id"] = chatId
                if let id = Int32(chatId) {
                    peerId = PeerId(namespace: Namespaces.Peer.CloudGroup, id: id)
                }
            }
            if let channelId = dict["channel_id"] as? String {
                userInfo["channel_id"] = channelId
                if let id = Int32(channelId) {
                    peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: id)
                }
            }
            if let silentValue = dict["silent"] as? String {
                silent = silentValue == "1"
            }
            
            var attachment: ParsedMediaAttachment?
            var attachmentData: Data?
            if let attachmentDataString = dict["attachb64"] as? String, let attachmentDataValue = parseBase64(string: attachmentDataString) {
                if let value = parseAttachment(data: attachmentDataValue) {
                    attachment = value.0
                    attachmentData = value.1
                }
            }
            
            let imagesPath = NSTemporaryDirectory() + "aps-data"
            let _ = try? FileManager.default.createDirectory(atPath: imagesPath, withIntermediateDirectories: true, attributes: nil)
            
            let accountBasePath = rootPath + "/account-\(UInt64(bitPattern: account.id))"
            
            let mediaBoxPath = accountBasePath + "/postbox/media"
            
            var tempImagePath: String?
            var mediaBoxThumbnailImagePath: String?
            
            var inputFileLocation: (Int32, Api.InputFileLocation)?
            var fetchResourceId: String?
            var isPng = false
            var isExpandableMedia = false
            
            if let attachment = attachment {
                switch attachment {
                case let .photo(photo):
                    switch photo {
                    case let .photo(_, id, accessHash, fileReference, _, sizes, dcId):
                        isExpandableMedia = true
                        loop: for size in sizes {
                            switch size {
                                case let .photoSize(type, _, _, _, _):
                                    if type == "m" {
                                        inputFileLocation = (dcId, .inputPhotoFileLocation(id: id, accessHash: accessHash, fileReference: fileReference, thumbSize: type))
                                        fetchResourceId = "telegram-cloud-photo-size-\(dcId)-\(id)-\(type)"
                                        break loop
                                    }
                                default:
                                    break
                            }
                        }
                    case .photoEmpty:
                        break
                    }
                case let .document(document):
                    switch document {
                    case let .document(_, id, accessHash, fileReference, _, mimeType, _, thumbs, dcId, attributes):
                        var isSticker = false
                        for attribute in attributes {
                            switch attribute {
                            case .documentAttributeSticker:
                                isSticker = true
                            default:
                                break
                            }
                        }
                        let isAnimatedSticker = mimeType == "application/x-tgsticker"
                        if isSticker || isAnimatedSticker {
                            isExpandableMedia = true
                        }
                        if let thumbs = thumbs {
                            loop: for size in thumbs {
                                switch size {
                                case let .photoSize(type, _, _, _, _):
                                    if (isSticker && type == "s") || type == "m" {
                                        if isSticker {
                                            isPng = true
                                        }
                                        inputFileLocation = (dcId, .inputDocumentFileLocation(id: id, accessHash: accessHash, fileReference: fileReference, thumbSize: type))
                                        fetchResourceId = "telegram-cloud-document-size-\(dcId)-\(id)-\(type)"
                                        break loop
                                    }
                                default:
                                    break
                                }
                            }
                        }
                    }
                }
            }
            
            if let fetchResourceId = fetchResourceId {
                tempImagePath = imagesPath + "/\(fetchResourceId).\(isPng ? "png" : "jpg")"
                mediaBoxThumbnailImagePath = mediaBoxPath + "/\(fetchResourceId)"
            }
            
            if let aps = dict["aps"] as? [AnyHashable: Any] {
                if let alert = aps["alert"] as? String {
                    self.bestAttemptContent?.title = ""
                    self.bestAttemptContent?.body = alert
                } else if let alert = aps["alert"] as? [AnyHashable: Any] {
                    self.bestAttemptContent?.title = alert["title"] as? String ?? ""
                    if let title = self.bestAttemptContent?.title, !title.isEmpty && silent {
                        self.bestAttemptContent?.title = "\(title) 🔕"
                    }
                    self.bestAttemptContent?.subtitle = alert["subtitle"] as? String ?? ""
                    self.bestAttemptContent?.body = alert["body"] as? String ?? ""
                }
                
                if accountInfos.accounts.count > 1 {
                    if let title = self.bestAttemptContent?.title, !title.isEmpty, !account.peerName.isEmpty {
                        self.bestAttemptContent?.title = "\(title) → \(account.peerName)"
                    }
                }
                
                if let threadId = aps["thread-id"] as? String {
                    self.bestAttemptContent?.threadIdentifier = threadId
                }
                if let sound = aps["sound"] as? String {
                    self.bestAttemptContent?.sound = UNNotificationSound(named: UNNotificationSoundName(sound))
                }
                if let category = aps["category"] as? String {
                    self.bestAttemptContent?.categoryIdentifier = category
                    if let peerId = peerId, let messageId = messageId, let _ = attachment, let attachmentData = attachmentData {
                        userInfo["peerId"] = peerId.toInt64()
                        userInfo["messageId.namespace"] = 0 as Int32
                        userInfo["messageId.id"] = messageId
                        
                        userInfo["media"] = attachmentData.base64EncodedString()
                        
                        if isExpandableMedia {
                            if category == "r" {
                                self.bestAttemptContent?.categoryIdentifier = "withReplyMedia"
                            } else if category == "m" {
                                self.bestAttemptContent?.categoryIdentifier = "withMuteMedia"
                            }
                        }
                    }
                }
            }
            
            self.bestAttemptContent?.userInfo = userInfo
            
            self.cancelFetch?()
            if let mediaBoxThumbnailImagePath = mediaBoxThumbnailImagePath, let tempImagePath = tempImagePath, let (datacenterId, inputFileLocation) = inputFileLocation {
                if let data = try? Data(contentsOf: URL(fileURLWithPath: mediaBoxThumbnailImagePath)) {
                    var tempData = data
                    if isPng {
                        if let image = WebP.convert(fromWebP: data), let imageData = image.pngData() {
                            tempData = imageData
                        }
                    }
                    if let _ = try? tempData.write(to: URL(fileURLWithPath: tempImagePath)) {
                        if let attachment = try? UNNotificationAttachment(identifier: "image", url: URL(fileURLWithPath: tempImagePath)) {
                            self.bestAttemptContent?.attachments = [attachment]
                        }
                    }
                    if let bestAttemptContent = self.bestAttemptContent {
                        contentHandler(bestAttemptContent)
                    }
                } else {
                    let appBundleIdentifier = Bundle.main.bundleIdentifier!
                    guard let lastDotRange = appBundleIdentifier.range(of: ".", options: [.backwards]) else {
                        return
                    }
                    
                    let baseAppBundleId = String(appBundleIdentifier[..<lastDotRange.lowerBound])
                    
                    let buildConfig = BuildConfig(baseAppBundleId: baseAppBundleId)
                    
                    self.cancelFetch = fetchImageWithAccount(buildConfig: buildConfig, proxyConnection: accountInfos.proxy, account: account, inputFileLocation: inputFileLocation, datacenterId: datacenterId, completion: { [weak self] data in
                        DispatchQueue.main.async {
                            guard let strongSelf = self else {
                                return
                            }
                            strongSelf.cancelFetch?()
                            strongSelf.cancelFetch = nil
                            if let data = data {
                                let _ = try? data.write(to: URL(fileURLWithPath: mediaBoxThumbnailImagePath))
                                var tempData = data
                                if isPng {
                                    if let image = WebP.convert(fromWebP: data), let imageData = image.pngData() {
                                        tempData = imageData
                                    }
                                }
                                if let _ = try? tempData.write(to: URL(fileURLWithPath: tempImagePath)) {
                                    if let attachment = try? UNNotificationAttachment(identifier: "image", url: URL(fileURLWithPath: tempImagePath)) {
                                        strongSelf.bestAttemptContent?.attachments = [attachment]
                                    }
                                }
                            }
                            if let bestAttemptContent = strongSelf.bestAttemptContent {
                                contentHandler(bestAttemptContent)
                            }
                        }
                    })
                }
            } else {
                if let bestAttemptContent = self.bestAttemptContent {
                    contentHandler(bestAttemptContent)
                }
            }
        } else {
            Logger.shared.log("NotificationService", "couldn't decrypt notification")
            
            if let bestAttemptContent = self.bestAttemptContent {
                contentHandler(bestAttemptContent)
            }
        }
    }
    
    override func serviceExtensionTimeWillExpire() {
        Logger.shared.log("NotificationService", "serviceExtensionTimeWillExpire")
        
        self.cancelFetch?()
        self.cancelFetch = nil
        
        if let contentHandler = self.contentHandler, let bestAttemptContent = self.bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }
}
