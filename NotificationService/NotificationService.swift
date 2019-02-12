import Foundation
import UserNotifications

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
                self.rootPath = appGroupUrl.path + "/telegram-data"
            } else {
                self.rootPath = nil
            }
        } else {
            self.rootPath = nil
        }
        
        super.init()
    }

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        let accountsData = self.rootPath.flatMap({ rootPath in
            loadAccountsData(rootPath: rootPath)
        }) ?? [:]
        
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
        
        if let (account, dict) = encryptedData.flatMap({ decryptedNotificationPayload(accounts: accountsData, data: $0) }) {
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
            
            let mediaBoxPath = account.basePath + "/postbox/media"
            
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
                
                if accountsData.count > 1 {
                    if let title = self.bestAttemptContent?.title, !account.peerName.isEmpty {
                        self.bestAttemptContent?.title = "[\(account.peerName)] \(title)"
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
                self.cancelFetch = fetchImageWithAccount(account: account, resource: thumbnailImage, completion: { [weak self] data in
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
            if let bestAttemptContent = self.bestAttemptContent {
                contentHandler(bestAttemptContent)
            }
        }
    }
    
    override func serviceExtensionTimeWillExpire() {
        self.cancelFetch?()
        self.cancelFetch = nil
        
        if let contentHandler = self.contentHandler, let bestAttemptContent = self.bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }
}


