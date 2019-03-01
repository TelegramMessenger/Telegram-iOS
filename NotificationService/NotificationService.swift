import Foundation
import UserNotifications

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


private func dataWithHexString(_ string: String) -> Data {
    var hex = string
    if hex.count % 2 != 0 {
        return Data()
    }
    var data = Data()
    while hex.count > 0 {
        let subIndex = hex.index(hex.startIndex, offsetBy: 2)
        let c = String(hex[..<subIndex])
        hex = String(hex[subIndex...])
        var ch: UInt32 = 0
        if !Scanner(string: c).scanHexInt32(&ch) {
            return Data()
        }
        var char = UInt8(ch)
        data.append(&char, count: 1)
    }
    return data
}

private func parseInt64(_ value: Any?) -> Int64? {
    if let value = value as? String {
        return Int64(value)
    } else if let value = value as? Int64 {
        return value
    } else {
        return nil
    }
}

private func parseInt32(_ value: Any?) -> Int32? {
    if let value = value as? String {
        return Int32(value)
    } else if let value = value as? Int32 {
        return value
    } else {
        return nil
    }
}

private func parseImageLocation(_ dict: [AnyHashable: Any]) -> (size: (width: Int32, height: Int32)?, resource: ImageResource)? {
    guard let datacenterId = parseInt32(dict["dc_id"]) else {
        return nil
    }
    guard let volumeId = parseInt64(dict["volume_id"]) else {
        return nil
    }
    guard let localId = parseInt32(dict["local_id"]) else {
        return nil
    }
    guard let secret = parseInt64(dict["secret"]) else {
        return nil
    }
    var fileReference: Data?
    if let fileReferenceString = dict["file_reference"] as? String {
        fileReference = Data(base64Encoded: fileReferenceString)
    }
    var size: (Int32, Int32)?
    if let width = parseInt32(dict["w"]), let height = parseInt32(dict["h"]) {
        size = (width, height)
    }
    return (size, ImageResource(datacenterId: Int(datacenterId), volumeId: volumeId, localId: localId, secret: secret, fileReference: fileReference))
}

private func hexString(_ data: Data) -> String {
    let hexString = NSMutableString()
    data.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) -> Void in
        for i in 0 ..< data.count {
            hexString.appendFormat("%02x", UInt(bytes.advanced(by: i).pointee))
        }
    }
    
    return hexString as String
}

private func serializeImageLocation(_ resource: ImageResource) -> [AnyHashable: Any] {
    var result: [AnyHashable: Any] = [:]
    result["datacenterId"] = Int32(resource.datacenterId)
    result["volumeId"] = resource.volumeId
    result["localId"] = resource.localId
    result["secret"] = resource.secret
    if let fileReference = resource.fileReference {
        result["fileReference"] = hexString(fileReference)
    }
    return result
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
        if var encryptedPayload = request.content.userInfo["p"] as? String {
            encryptedPayload = encryptedPayload.replacingOccurrences(of: "-", with: "+")
            encryptedPayload = encryptedPayload.replacingOccurrences(of: "_", with: "/")
            while encryptedPayload.count % 4 != 0 {
                encryptedPayload.append("=")
            }
            encryptedData = Data(base64Encoded: encryptedPayload)
        }
        
        Logger.shared.log("NotificationService", "received notification \(request), parsed encryptedData \(String(describing: encryptedData))")
        
        if let (account, dict) = encryptedData.flatMap({ decryptedNotificationPayload(accounts: accountInfos.accounts, data: $0) }) {
            Logger.shared.log("NotificationService", "decrypted notification")
            var userInfo = self.bestAttemptContent?.userInfo ?? [:]
            userInfo["accountId"] = account.id
            
            var peerId: PeerId?
            var messageId: Int32?
            
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
            
            var thumbnailImage: ImageResource?
            var fullSizeImage: (size: (width: Int32, height: Int32)?, resource: ImageResource)?
            if let thumbLoc = dict["media_loc"] as? [AnyHashable: Any] {
                thumbnailImage = (thumbLoc["thumb"] as? [AnyHashable: Any]).flatMap(parseImageLocation)?.resource
                fullSizeImage = (thumbLoc["full"] as? [AnyHashable: Any]).flatMap(parseImageLocation)
            }
            
            let imagesPath = NSTemporaryDirectory() + "aps-data"
            let _ = try? FileManager.default.createDirectory(atPath: imagesPath, withIntermediateDirectories: true, attributes: nil)
            
            let accountBasePath = rootPath + "account-\(UInt64(bitPattern: account.id))"
            
            let mediaBoxPath = accountBasePath + "/postbox/media"
            
            let tempImagePath = thumbnailImage.flatMap({ imagesPath + "/\($0.resourceId).jpg" })
            let mediaBoxThumbnailImagePath = thumbnailImage.flatMap({ mediaBoxPath + "/\($0.resourceId)" })
            let mediaBoxFullSizeImagePath = fullSizeImage.flatMap({ mediaBoxPath + "/\($0.resource.resourceId)" })
            
            if let aps = dict["aps"] as? [AnyHashable: Any] {
                if let alert = aps["alert"] as? String {
                    self.bestAttemptContent?.title = ""
                    self.bestAttemptContent?.body = alert
                } else if let alert = aps["alert"] as? [AnyHashable: Any] {
                    self.bestAttemptContent?.title = alert["title"] as? String ?? ""
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
                    if let peerId = peerId, let messageId = messageId, let thumbnailResource = thumbnailImage, let (maybeSize, resource) = fullSizeImage, let size = maybeSize {
                        userInfo["peerId"] = peerId.toInt64()
                        userInfo["messageId.namespace"] = 0 as Int32
                        userInfo["messageId.id"] = messageId
                        
                        var imageInfo: [String: Any] = [:]
                        imageInfo["width"] = Int(size.width)
                        imageInfo["height"] = Int(size.height)
                        
                        var thumbnail: [String: Any] = [:]
                        if let mediaBoxThumbnailImagePath = mediaBoxThumbnailImagePath {
                            thumbnail["path"] = mediaBoxThumbnailImagePath
                        }
                        thumbnail["fileLocation"] = serializeImageLocation(thumbnailResource)
                        
                        var fullSize: [String: Any] = [:]
                        if let mediaBoxFullSizeImagePath = mediaBoxFullSizeImagePath {
                            fullSize["path"] = mediaBoxFullSizeImagePath
                        }
                        fullSize["fileLocation"] = serializeImageLocation(resource)
                        
                        imageInfo["thumbnail"] = thumbnail
                        imageInfo["fullSize"] = fullSize
                        
                        userInfo["mediaInfo"] = ["image": imageInfo]
                        
                        if category == "r" {
                            self.bestAttemptContent?.categoryIdentifier = "withReplyMedia"
                        } else if category == "m" {
                            self.bestAttemptContent?.categoryIdentifier = "withMuteMedia"
                        }
                    }
                }
            }
            
            self.bestAttemptContent?.userInfo = userInfo
            
            self.cancelFetch?()
            if let mediaBoxThumbnailImagePath = mediaBoxThumbnailImagePath, let tempImagePath = tempImagePath, let thumbnailImage = thumbnailImage {
                self.cancelFetch = fetchImageWithAccount(proxyConnection: accountInfos.proxy, account: account, resource: thumbnailImage, completion: { [weak self] data in
                    DispatchQueue.main.async {
                        guard let strongSelf = self else {
                            return
                        }
                        strongSelf.cancelFetch?()
                        strongSelf.cancelFetch = nil
                        if let data = data {
                            let _ = try? data.write(to: URL(fileURLWithPath: mediaBoxThumbnailImagePath))
                            if let _ = try? data.write(to: URL(fileURLWithPath: tempImagePath)) {
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
