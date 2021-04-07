import Foundation
import TelegramCore
import SyncCore
import SwiftSignalKit
import Postbox
import LegacyComponents

private let reportedLayer_hash: Int32 = -717538193
private let layer_hash: Int32 = 849537378
private let seq_out_hash: Int32 = -737765753
private let seq_in_hash: Int32 = -7646011

private let defaultPrime: Data = {
    let bytes: [UInt8] = [
        0xc7, 0x1c, 0xae, 0xb9, 0xc6, 0xb1, 0xc9, 0x04, 0x8e, 0x6c, 0x52, 0x2f,
        0x70, 0xf1, 0x3f, 0x73, 0x98, 0x0d, 0x40, 0x23, 0x8e, 0x3e, 0x21, 0xc1,
        0x49, 0x34, 0xd0, 0x37, 0x56, 0x3d, 0x93, 0x0f, 0x48, 0x19, 0x8a, 0x0a,
        0xa7, 0xc1, 0x40, 0x58, 0x22, 0x94, 0x93, 0xd2, 0x25, 0x30, 0xf4, 0xdb,
        0xfa, 0x33, 0x6f, 0x6e, 0x0a, 0xc9, 0x25, 0x13, 0x95, 0x43, 0xae, 0xd4,
        0x4c, 0xce, 0x7c, 0x37, 0x20, 0xfd, 0x51, 0xf6, 0x94, 0x58, 0x70, 0x5a,
        0xc6, 0x8c, 0xd4, 0xfe, 0x6b, 0x6b, 0x13, 0xab, 0xdc, 0x97, 0x46, 0x51,
        0x29, 0x69, 0x32, 0x84, 0x54, 0xf1, 0x8f, 0xaf, 0x8c, 0x59, 0x5f, 0x64,
        0x24, 0x77, 0xfe, 0x96, 0xbb, 0x2a, 0x94, 0x1d, 0x5b, 0xcd, 0x1d, 0x4a,
        0xc8, 0xcc, 0x49, 0x88, 0x07, 0x08, 0xfa, 0x9b, 0x37, 0x8e, 0x3c, 0x4f,
        0x3a, 0x90, 0x60, 0xbe, 0xe6, 0x7c, 0xf9, 0xa4, 0xa4, 0xa6, 0x95, 0x81,
        0x10, 0x51, 0x90, 0x7e, 0x16, 0x27, 0x53, 0xb5, 0x6b, 0x0f, 0x6b, 0x41,
        0x0d, 0xba, 0x74, 0xd8, 0xa8, 0x4b, 0x2a, 0x14, 0xb3, 0x14, 0x4e, 0x0e,
        0xf1, 0x28, 0x47, 0x54, 0xfd, 0x17, 0xed, 0x95, 0x0d, 0x59, 0x65, 0xb4,
        0xb9, 0xdd, 0x46, 0x58, 0x2d, 0xb1, 0x17, 0x8d, 0x16, 0x9c, 0x6b, 0xc4,
        0x65, 0xb0, 0xd6, 0xff, 0x9c, 0xa3, 0x92, 0x8f, 0xef, 0x5b, 0x9a, 0xe4,
        0xe4, 0x18, 0xfc, 0x15, 0xe8, 0x3e, 0xbe, 0xa0, 0xf8, 0x7f, 0xa9, 0xff,
        0x5e, 0xed, 0x70, 0x05, 0x0d, 0xed, 0x28, 0x49, 0xf4, 0x7b, 0xf9, 0x59,
        0xd9, 0x56, 0x85, 0x0c, 0xe9, 0x29, 0x85, 0x1f, 0x0d, 0x81, 0x15, 0xf6,
        0x35, 0xb1, 0x05, 0xee, 0x2e, 0x4e, 0x15, 0xd0, 0x4b, 0x24, 0x54, 0xbf,
        0x6f, 0x4f, 0xad, 0xf0, 0x34, 0xb1, 0x04, 0x03, 0x11, 0x9c, 0xd8, 0xe3,
        0xb9, 0x2f, 0xcc, 0x5b
    ]
    var data = Data(count: bytes.count)
    data.withUnsafeMutableBytes { (dst: UnsafeMutablePointer<UInt8>) -> Void in
        for i in 0 ..< bytes.count {
            dst.advanced(by: i).pointee = bytes[i]
        }
    }
    return data
}()

@objc(TGEncryptionKeyData) private final class TGEncryptionKeyData: NSObject, NSCoding {
    let keyId: Int64
    let key: Data
    let firstSeqOut: Int32
    
    init?(coder aDecoder: NSCoder) {
        self.keyId = aDecoder.decodeInt64(forKey: "keyId")
        self.key = (aDecoder.decodeObject(forKey: "key") as? Data) ?? Data()
        self.firstSeqOut = aDecoder.decodeInt32(forKey: "firstSeqOut")
    }
    
    func encode(with aCoder: NSCoder) {
        assertionFailure()
    }
}

private struct SecretChatData {
    let accessHash: Int64
    let handshakeState: Int32
    let rekeyState: SecretChatRekeySessionState?
}

private func readSecretChatParticipantData(accountPeerId: PeerId, data: Data) -> (SecretChatRole, PeerId)? {
    let reader = LegacyBufferReader(LegacyBuffer(data: data))
    
    guard reader.readInt32() == Int32(bitPattern: 0xabcdef12) else {
        return nil
    }
    guard let formatVersion = reader.readInt32(), formatVersion >= 2 else {
        return nil
    }
    reader.skip(4)
    
    guard let adminId = reader.readInt32() else {
        return nil
    }
    guard let count = reader.readInt32() else {
        return nil
    }
    var ids: [Int32] = []
    for _ in 0 ..< Int(count) {
        guard let id = reader.readInt32() else {
            return nil
        }
        reader.skip(4)
        reader.skip(4)
        ids.append(id)
    }
    
    guard let otherPeerId = ids.first else {
        return nil
    }
    
    return (adminId == accountPeerId.id ? .creator : .participant, PeerId(namespace: Namespaces.Peer.CloudUser, id: otherPeerId))
}

private func readSecretChatData(reader: LegacyBufferReader) -> SecretChatData? {
    guard let version = reader.readBytesAsInt32(1) else {
        return nil
    }
    if version != 3 {
        return nil
    }
    reader.skip(8)
    
    guard let accessHash = reader.readInt64() else {
        return nil
    }
    guard let _ = reader.readInt64() else {
        return nil
    }
    guard let handshakeState = reader.readInt32() else {
        return nil
    }
    guard let currentRekeyExchangeId = reader.readInt64() else {
        return nil
    }
    guard let currentRekeyIsInitiatedByLocalClient = reader.readBytesAsInt32(1) else {
        return nil
    }
    guard let currentRekeyNumberLength = reader.readInt32() else {
        return nil
    }
    var currentRekeyNumber: Data?
    if currentRekeyNumberLength > 0 {
        guard let value = reader.readBuffer(Int(currentRekeyNumberLength))?.makeData() else {
            return nil
        }
        currentRekeyNumber = value
    }
    guard let currentRekeyKeyLength = reader.readInt32() else {
        return nil
    }
    var currentRekeyKey: Data?
    if currentRekeyKeyLength > 0 {
        guard let value = reader.readBuffer(Int(currentRekeyKeyLength))?.makeData() else {
            return nil
        }
        currentRekeyKey = value
    }
    guard let currentRekeyKeyId = reader.readInt64() else {
        return nil
    }
    
    var rekeyState: SecretChatRekeySessionState?
    if currentRekeyExchangeId != 0 {
        let innerState: SecretChatRekeySessionData?
        if currentRekeyIsInitiatedByLocalClient != 0, let currentRekeyNumber = currentRekeyNumber {
            innerState = .requested(a: MemoryBuffer(data: currentRekeyNumber), config: SecretChatEncryptionConfig(g: 3, p: MemoryBuffer(data: defaultPrime), version: 0))
        } else if currentRekeyIsInitiatedByLocalClient == 0, let currentRekeyKey = currentRekeyKey, currentRekeyKeyId != 0 {
            innerState = .accepted(key: MemoryBuffer(data: currentRekeyKey), keyFingerprint: currentRekeyKeyId)
        } else {
            innerState = nil
        }
        if let innerState = innerState {
            rekeyState = SecretChatRekeySessionState(id: currentRekeyExchangeId, data: innerState)
        }
    }
    
    return SecretChatData(accessHash: accessHash, handshakeState: handshakeState, rekeyState: rekeyState)
}

let registeredAttachmentParsers: Bool = {
    let parsers: [(Int32, TGMediaAttachmentParser)] = [
        (TGActionMediaAttachmentType, TGActionMediaAttachment()),
        (TGImageMediaAttachmentType, TGImageMediaAttachment()),
        (TGLocationMediaAttachmentType, TGLocationMediaAttachment()),
        (TGVideoMediaAttachmentType, TGVideoMediaAttachment()),
        (Int32(bitPattern: 0xB90A5663), TGContactMediaAttachment()),
        (Int32(bitPattern: 0xE6C64318), TGDocumentMediaAttachment()),
        (TGAudioMediaAttachmentType, TGAudioMediaAttachment()),
        (Int32(bitPattern: 0x8C2E3CCE), TGMessageEntitiesAttachment()),
        (Int32(bitPattern: 0x944DE6B6), TGLocalMessageMetaMediaAttachment()),
        (TGAuthorSignatureMediaAttachmentType, TGAuthorSignatureMediaAttachment()),
        (TGInvoiceMediaAttachmentType, TGInvoiceMediaAttachment()),
        (TGGameAttachmentType, TGGameMediaAttachment()),
        (Int32(bitPattern: 0xA3F4C8F5), TGViaUserAttachment()),
        (TGBotContextResultAttachmentType, TGBotContextResultAttachment()),
        (TGReplyMarkupAttachmentType, TGReplyMarkupAttachment()),
        (TGWebPageMediaAttachmentType, TGWebPageMediaAttachment()),
        (TGReplyMessageMediaAttachmentType, TGReplyMessageMediaAttachment()),
        (TGAudioMediaAttachmentType, TGAudioMediaAttachment()),
        (Int32(bitPattern: 0xaa1050c1), TGForwardedMessageMediaAttachment())
    ]
    for (id, parser) in parsers {
        TGMessage.registerMediaAttachmentParser(id, parser: parser)
    }
    return true
}()

private func parseSecretChatData(peerId: PeerId, data: Data, unreadCount: Int32) -> (SecretChatData, [MessageId.Namespace: PeerReadState], Int32)? {
    let reader = LegacyBufferReader(LegacyBuffer(data: data))
    guard let magic = reader.readInt32() else {
        return nil
    }
    var version: Int32 = 1
    if magic == 0x7acde441 {
        guard let value = reader.readInt32() else {
            return nil
        }
        version = value
    }
    
    if version < 2 {
        return nil
    }
    
    for _ in 0 ..< 3 {
        guard let length = reader.readInt32() else {
            return nil
        }
        reader.skip(Int(length))
    }
    
    guard let hasEncryptedData = reader.readBytesAsInt32(1), hasEncryptedData == 1 else {
        return nil
    }
    guard let secretChatData = readSecretChatData(reader: reader) else {
        return nil
    }
    reader.skip(4)
    reader.skip(4)
    reader.skip(8)
    reader.skip(4)
    reader.skip(4)
    reader.skip(4)
    reader.skip(4)
    guard let maxReadDate = reader.readInt32() else {
        return nil
    }
    guard let maxOutgoingReadDate = reader.readInt32() else {
        return nil
    }
    guard let messageDate = reader.readInt32() else {
        return nil
    }
    guard let minMessageDate = reader.readInt32() else {
        return nil
    }
    
    let readStates: [MessageId.Namespace: PeerReadState] = [
        Namespaces.Message.SecretIncoming: .indexBased(maxIncomingReadIndex: MessageIndex(id: MessageId(peerId: peerId, namespace: Namespaces.Message.SecretIncoming, id: 1), timestamp: maxReadDate), maxOutgoingReadIndex: MessageIndex.lowerBound(peerId: peerId), count: 0, markedUnread: false),
        Namespaces.Message.Local: .indexBased(maxIncomingReadIndex: MessageIndex.lowerBound(peerId: peerId), maxOutgoingReadIndex: MessageIndex(id: MessageId(peerId: peerId, namespace: Namespaces.Message.Local, id: 1), timestamp: maxOutgoingReadDate), count: 0, markedUnread: false)
    ]
    return (secretChatData, readStates, max(messageDate, minMessageDate))
}

private enum CustomPropertyKey {
    case string(String)
    case hash(Int32)
}

private func loadLegacyPeerCustomProperyData(database: SqliteInterface, peerId: Int64, key: CustomPropertyKey) -> Data? {
    var propertiesData: Data?
    database.select("SELECT custom_properties FROM peers_v29 WHERE pid=\(peerId)", { cursor in
        propertiesData = cursor.getData(at: 0)
        return false
    })
    if let propertiesData = propertiesData {
        let keyHash: Int32
        switch key {
            case let .string(string):
                keyHash = HashFunctions.murMurHash32(string)
            case let .hash(hash):
                keyHash = hash
        }
        let reader = LegacyBufferReader(LegacyBuffer(data: propertiesData))
        
        guard let _ = reader.readInt32() else {
            return nil
        }
        guard let count = reader.readInt32() else {
            return nil
        }
        for _ in 0 ..< Int(count) {
            guard let valueKey = reader.readInt32() else {
                return nil
            }
            guard let valueLength = reader.readInt32() else {
                return nil
            }
            if valueKey == keyHash {
                return reader.readBuffer(Int(valueLength))?.makeData()
            }
            reader.skip(Int(valueLength))
        }
    }
    return nil
}

private func loadLegacyPeerCustomProperyInt32(database: SqliteInterface, peerId: Int64, key: CustomPropertyKey) -> Int32? {
    guard let data = loadLegacyPeerCustomProperyData(database: database, peerId: peerId, key: key), data.count == 4 else {
        return nil
    }
    var result: Int32 = 0
    withUnsafeMutablePointer(to: &result, { bytes -> Void in
        data.copyBytes(to: UnsafeMutableRawPointer(bytes).assumingMemoryBound(to: UInt8.self), from: 0 ..< 4)
    })
    return result
}

private func loadLegacyMessages(account: TemporaryAccount, basePath: String, accountPeerId: PeerId, peerId: PeerId, userPeerId: PeerId, database: SqliteInterface, conversationId: Int64, expectedTotalCount: Int32) -> Signal<Float, NoError> {
    return Signal { subscriber in
        subscriber.putNext(0.0)
        
        var copyLocalFiles: [(MediaResource, String)] = []
        var messages: [StoreMessage] = []
        
        Logger.shared.log("loadLegacyMessages", "begin peerId \(peerId) conversationId \(conversationId) count \(expectedTotalCount)")
        
        database.select("CREATE INDEX IF NOT EXISTS random_ids_mid ON random_ids_v29 (mid)", { _ in
            return true
        })
        
        var messageIndex: Int32 = -1
        let reportBase = max(1, expectedTotalCount / 100)
        
        database.select("SELECT mid, message, media, from_id, dstate, date, flags, localMid, content_properties FROM messages_v29 WHERE cid=\(conversationId)", { cursor in
            messageIndex += 1
            
            #if DEBUG
            //usleep(500000)
            #endif
            
            if messageIndex % reportBase == 0 {
                subscriber.putNext(min(1.0, Float(messageIndex) / Float(expectedTotalCount)))
            }
            
            let messageId = cursor.getInt32(at: 0)
            
            //Logger.shared.log("loadLegacyMessages", "import message \(messageId)")
            
            var globallyUniqueId: Int64?
            database.select("SELECT random_id FROM random_ids_v29 where mid=\(messageId)", { innerCursor in
                globallyUniqueId = innerCursor.getInt64(at: 0)
                return false
            })
            
            let text = cursor.getString(at: 1)
            let fromId = cursor.getInt64(at: 3)
            let deliveryState = cursor.getInt32(at: 4)
            let timestamp = cursor.getInt32(at: 5)
            let autoremoveTimeout = cursor.getInt32(at: 7)
            let contentPropertiesData = cursor.getData(at: 8)
            
            let parsedAuthorId: PeerId
            let parsedId: StoreMessageId
            var parsedFlags: StoreMessageFlags = []
            var parsedAttributes: [MessageAttribute] = []
            var parsedMedia: [Media] = []
            var parsedGroupingKey: Int64?
            
            if fromId == accountPeerId.id {
                parsedAuthorId = accountPeerId
                parsedId = .Partial(peerId, Namespaces.Message.Local)
            } else {
                parsedAuthorId = userPeerId
                parsedId = .Partial(peerId, Namespaces.Message.SecretIncoming)
                parsedFlags.insert(.Incoming)
            }
            
            if deliveryState != 0 {
                return true
            }
            
            if !contentPropertiesData.isEmpty {
                if let contentProperties = TGMessage.parseContentProperties(contentPropertiesData) {
                    for (_, value) in contentProperties {
                        if let value = value as? TGMessageGroupedIdContentProperty {
                            parsedGroupingKey = value.groupedId
                        }
                    }
                }
            }
            
            //Logger.shared.log("loadLegacyMessages", "message \(messageId) read content properties")
            
            let media = cursor.getData(at: 2)
            if let mediaList = TGMessage.parseMediaAttachments(media) {
                for item in mediaList {
                    if let item = item as? TGImageMediaAttachment {
                        let mediaId = MediaId(namespace: Namespaces.Media.LocalImage, id: arc4random64())
                        var representations: [TelegramMediaImageRepresentation] = []
                        if let allSizes = item.imageInfo?.allSizes() as? [String: NSValue] {

                            for (imageUrl, sizeValue) in allSizes {
                                var resource: TelegramMediaResource = LocalFileMediaResource(fileId: arc4random64())
                                var resourcePath: String?
                                if let (path, updatedResource) = pathAndResourceFromEncryptedFileUrl(basePath: basePath, url: imageUrl, type: .image) {
                                    resource = updatedResource
                                    copyLocalFiles.append((updatedResource, path))
                                    resourcePath = path
                                } else if imageUrl.hasPrefix("file://"), let path = URL(string: imageUrl)?.path {
                                    copyLocalFiles.append((resource, path))
                                    resourcePath = path
                                }
                                
                                var dimensions = sizeValue.cgSizeValue
                                if let resourcePath = resourcePath, let image = UIImage(contentsOfFile: resourcePath) {
                                    dimensions = image.size
                                }
                                representations.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(dimensions), resource: resource, progressiveSizes: []))
                            }
                        }
                        
                        if item.localImageId != 0 {
                            let fullSizePath = basePath + "/Documents/files/image-local-\(String(item.localImageId, radix: 16))/image.jpg"
                            if let image = UIImage(contentsOfFile: fullSizePath) {
                                let resource: TelegramMediaResource = LocalFileMediaResource(fileId: arc4random64())
                                copyLocalFiles.append((resource, fullSizePath))
                                representations.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(image.size), resource: resource, progressiveSizes: []))
                            }
                        }
                        
                        parsedMedia.append(TelegramMediaImage(imageId: mediaId, representations: representations, immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: []))
                    } else if let item = item as? TGVideoMediaAttachment {
                        let mediaId = MediaId(namespace: Namespaces.Media.LocalImage, id: arc4random64())
                        var representations: [TelegramMediaImageRepresentation] = []
                        if let allSizes = item.thumbnailInfo?.allSizes() as? [String: NSValue] {
                            for (imageUrl, sizeValue) in allSizes {
                                var resource: TelegramMediaResource = LocalFileMediaResource(fileId: arc4random64())
                                if let (path, updatedResource) = pathAndResourceFromEncryptedFileUrl(basePath: basePath, url: imageUrl, type: .image) {
                                    resource = updatedResource
                                    copyLocalFiles.append((updatedResource, path))
                                } else if imageUrl.hasPrefix("file://"), let path = URL(string: imageUrl)?.path {
                                    copyLocalFiles.append((resource, path))
                                }
                                representations.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(sizeValue.cgSizeValue), resource: resource, progressiveSizes: []))
                            }
                        }
                        
                        var resource: TelegramMediaResource = LocalFileMediaResource(fileId: arc4random64())
                        
                        var attributes: [TelegramMediaFileAttribute] = []
                        attributes.append(.Video(duration: Int(item.duration), size: PixelDimensions(item.dimensions), flags: item.roundMessage ? .instantRoundVideo : []))
                       
                        var size: Int32 = 0
                        if let videoUrl = item.videoInfo?.url(withQuality: 1, actualQuality: nil, actualSize: &size) {
                            if let path = pathFromLegacyLocalVideoUrl(basePath: basePath, url: videoUrl) {
                                copyLocalFiles.append((resource, path))
                            } else if let (path, updatedResource) = pathAndResourceFromEncryptedFileUrl(basePath: basePath, url: videoUrl, type: .video) {
                                resource = updatedResource
                                copyLocalFiles.append((updatedResource, path))
                            } else if videoUrl.hasPrefix("file://"), let path = URL(string: videoUrl)?.path {
                                copyLocalFiles.append((resource, path))
                            }
                        }
                        parsedMedia.append(TelegramMediaFile(fileId: mediaId, partialReference: nil, resource: resource, previewRepresentations: representations, videoThumbnails: [], immediateThumbnailData: nil, mimeType: "video/mp4", size: size == 0 ? nil : Int(size), attributes: attributes))
                    } else if let item = item as? TGAudioMediaAttachment {
                        let mediaId = MediaId(namespace: Namespaces.Media.LocalImage, id: arc4random64())
                        let representations: [TelegramMediaImageRepresentation] = []
                        
                        var resource: TelegramMediaResource = LocalFileMediaResource(fileId: arc4random64())
                        
                        var attributes: [TelegramMediaFileAttribute] = []
                        attributes.append(.Audio(isVoice: true, duration: Int(item.duration), title: nil, performer: nil, waveform: nil))
                        
                        let size: Int32 = item.fileSize
                        let audioUrl = item.audioUri ?? ""
                        
                        if let path = pathFromLegacyLocalVideoUrl(basePath: basePath, url: audioUrl) {
                            copyLocalFiles.append((resource, path))
                        } else if let (path, updatedResource) = pathAndResourceFromEncryptedFileUrl(basePath: basePath, url: audioUrl, type: .audio) {
                            resource = updatedResource
                            copyLocalFiles.append((updatedResource, path))
                        } else if audioUrl.hasPrefix("file://"), let path = URL(string: audioUrl)?.path {
                            copyLocalFiles.append((resource, path))
                        }
                        parsedMedia.append(TelegramMediaFile(fileId: mediaId, partialReference: nil, resource: resource, previewRepresentations: representations, videoThumbnails: [], immediateThumbnailData: nil, mimeType: "audio/ogg", size: size == 0 ? nil : Int(size), attributes: attributes))
                    } else if let item = item as? TGDocumentMediaAttachment {
                        let mediaId = MediaId(namespace: Namespaces.Media.LocalImage, id: arc4random64())
                        var representations: [TelegramMediaImageRepresentation] = []
                        if let allSizes = (item.thumbnailInfo?.allSizes()) as? [String: NSValue] {
                            for (imageUrl, sizeValue) in allSizes {
                                var resource: TelegramMediaResource = LocalFileMediaResource(fileId: arc4random64())
                                if let (path, updatedResource) = pathAndResourceFromEncryptedFileUrl(basePath: basePath, url: imageUrl, type: .image) {
                                    resource = updatedResource
                                    copyLocalFiles.append((updatedResource, path))
                                } else if imageUrl.hasPrefix("file://"), let path = URL(string: imageUrl)?.path {
                                    copyLocalFiles.append((resource, path))
                                } else if let updatedResource = resourceFromLegacyImageUrl(imageUrl) {
                                    resource = updatedResource
                                    copyLocalFiles.append((resource, pathFromLegacyImageUrl(basePath: basePath, url: imageUrl)))
                                }
                                representations.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(sizeValue.cgSizeValue), resource: resource, progressiveSizes: []))
                            }
                        }
                        
                        var resource: TelegramMediaResource = LocalFileMediaResource(fileId: arc4random64())
                        
                        var attributes: [TelegramMediaFileAttribute] = []
                        var fileName = "file"
                        if let itemAttributes = item.attributes {
                            for attribute in itemAttributes {
                                if let attribute = attribute as? TGDocumentAttributeFilename {
                                    attributes.append(.FileName(fileName: attribute.filename ?? "file"))
                                    fileName = attribute.filename ?? "file"
                                } else if let attribute = attribute as? TGDocumentAttributeAudio {
                                    let title = attribute.title ?? ""
                                    let performer = attribute.performer ?? ""
                                    var waveform: MemoryBuffer?
                                    if let data = attribute.waveform {
                                        waveform = MemoryBuffer(data: data.bitstream()!)
                                    }
                                    attributes.append(.Audio(isVoice: attribute.isVoice, duration: Int(attribute.duration), title: title.isEmpty ? nil : title, performer: performer.isEmpty ? nil : performer, waveform: waveform))
                                } else if let _ = attribute as? TGDocumentAttributeAnimated {
                                    attributes.append(.Animated)
                                } else if let attribute = attribute as? TGDocumentAttributeVideo {
                                    attributes.append(.Video(duration: Int(attribute.duration), size: PixelDimensions(attribute.size), flags: attribute.isRoundMessage ? .instantRoundVideo : []))
                                } else if let attribute = attribute as? TGDocumentAttributeSticker {
                                    var packReference: StickerPackReference?
                                    if let reference = attribute.packReference as? TGStickerPackIdReference {
                                        packReference = .id(id: reference.packId, accessHash: reference.packAccessHash)
                                    } else if let reference = attribute.packReference as? TGStickerPackShortnameReference {
                                        packReference = .name(reference.shortName ?? "")
                                    }
                                    attributes.append(.Sticker(displayText: attribute.alt ?? "", packReference: packReference, maskData: nil))
                                } else if let attribute = attribute as? TGDocumentAttributeImageSize {
                                    attributes.append(.ImageSize(size: PixelDimensions(attribute.size)))
                                }
                            }
                        }
                        
                        let documentUri = item.documentUri ?? ""
                        
                        let size: Int32 = item.size
                        if documentUri.hasPrefix("file://"), let path = URL(string: documentUri)?.path {
                            copyLocalFiles.append((resource, path))
                        } else if let (path, updatedResource) = pathAndResourceFromEncryptedFileUrl(basePath: basePath, url: documentUri, type: .document(fileName: fileName)) {
                            resource = updatedResource
                            copyLocalFiles.append((resource, path))
                        } else if item.localDocumentId != 0 {
                            copyLocalFiles.append((resource, pathFromLegacyFile(basePath: basePath, fileId: item.localDocumentId, isLocal: true, fileName: TGDocumentMediaAttachment.safeFileName(forFileName: fileName) ?? "")))
                        } else if item.documentId != 0 {
                            copyLocalFiles.append((resource, pathFromLegacyFile(basePath: basePath, fileId: item.documentId, isLocal: false, fileName: TGDocumentMediaAttachment.safeFileName(forFileName: fileName) ?? "")))
                        }
                        parsedMedia.append(TelegramMediaFile(fileId: mediaId, partialReference: nil, resource: resource, previewRepresentations: representations, videoThumbnails: [], immediateThumbnailData: nil, mimeType: item.mimeType ?? "application/octet-stream", size: size == 0 ? nil : Int(size), attributes: attributes))
                    } else if let item = item as? TGActionMediaAttachment {
                        if item.actionType == TGMessageActionEncryptedChatMessageLifetime, let actionData = item.actionData, let timeout = actionData["messageLifetime"] as? Int32 {
                            
                            parsedMedia.append(TelegramMediaAction(action: .messageAutoremoveTimeoutUpdated(timeout)))
                        }
                    } else if let item = item as? TGContactMediaAttachment {
                        parsedMedia.append(TelegramMediaContact(firstName: item.firstName ?? "", lastName: item.lastName ?? "", phoneNumber: item.phoneNumber ?? "", peerId: nil, vCardData: nil))
                    } else if let item = item as? TGLocationMediaAttachment {
                        var venue: MapVenue?
                        if let v = item.venue {
                            venue = MapVenue(title: v.title ?? "", address: v.address ?? "", provider: v.provider == "" ? nil : v.provider, id: v.venueId == "" ? nil : v.venueId, type: v.type == "" ? nil : v.type)
                        }
                        parsedMedia.append(TelegramMediaMap(latitude: item.latitude, longitude: item.longitude, heading: nil, accuracyRadius: nil, geoPlace: nil, venue: venue, liveBroadcastingTimeout: nil, liveProximityNotificationRadius: nil))
                    }
                }
            }
            
            //Logger.shared.log("loadLegacyMessages", "message \(messageId) read media")
            
            if autoremoveTimeout != 0 {
                var countdownBeginTime: Int32?
                database.select("SELECT date FROM selfdestruct_v29 where mid=\(messageId)", { innerCursor in
                    countdownBeginTime = innerCursor.getInt32(at: 0) - autoremoveTimeout
                    return false
                })
                parsedAttributes.append(AutoremoveTimeoutMessageAttribute(timeout: autoremoveTimeout, countdownBeginTime: countdownBeginTime))
            }
            
            let (parsedTags, parsedGlobalTags) = tagsForStoreMessage(incoming: parsedFlags.contains(.Incoming), attributes: parsedAttributes, media: parsedMedia, textEntities: nil, isPinned: false)
            messages.append(StoreMessage(id: parsedId, globallyUniqueId: globallyUniqueId, groupingKey: parsedGroupingKey, threadId: nil, timestamp: timestamp, flags: parsedFlags, tags: parsedTags, globalTags: parsedGlobalTags, localTags: [], forwardInfo: nil, authorId: parsedAuthorId, text: text, attributes: parsedAttributes, media: parsedMedia))
            
            //Logger.shared.log("loadLegacyMessages", "message \(messageId) completed")
            
            return true
        })
        
        let disposable = (account.postbox.transaction { transaction -> Void in
            //Logger.shared.log("loadLegacyMessages", "conversation \(conversationId) storing messages")
            let _ = transaction.addMessages(messages, location: .UpperHistoryBlock)
            
            //Logger.shared.log("loadLegacyMessages", "conversation \(conversationId) copying \(copyLocalFiles.count) files")
            
            for (resource, path) in copyLocalFiles {
                account.postbox.mediaBox.copyResourceData(resource.id, fromTempPath: path)
            }
            
            Logger.shared.log("loadLegacyMessages", "conversation \(conversationId) done")
        }).start(completed: {
            subscriber.putCompletion()
        })
        
        return disposable
    }
}

private func importChannelBroadcastPreferences(account: TemporaryAccount, basePath: String, database: SqliteInterface) -> Signal<Never, NoError> {
    return deferred { () -> Signal<Never, NoError> in
        var peerIds: [Int64] = []
        database.select("SELECT cid FROM channel_conversations_v29", { cursor in
            peerIds.append(cursor.getInt64(at: 0))
            return true
        })
        var peerIdsWithMutedMessages: [Int64] = []
        for peerId in peerIds {
            if let data = loadLegacyPeerCustomProperyData(database: database, peerId: peerId, key: .hash(0x374BF349)), !data.isEmpty {
                let reader = LegacyBufferReader(LegacyBuffer(data: data))
                guard let version = reader.readBytesAsInt32(1) else {
                    continue
                }
                guard let _ = reader.readBytesAsInt32(1) else {
                    continue
                }
                if version >= 2 {
                    guard let messagesMuted = reader.readBytesAsInt32(1) else {
                        continue
                    }
                    if messagesMuted == 1 {
                        peerIdsWithMutedMessages.append(peerId)
                    }
                }
            }
        }
        
        return .complete()
    }
}

func loadLegacySecretChats(account: TemporaryAccount, basePath: String, accountPeerId: PeerId, database: SqliteInterface) -> Signal<Float, NoError> {
    return deferred { () -> Signal<Float, NoError> in
        var peerIdToConversationId: [PeerId: Int64] = [:]
        database.select("SELECT encrypted_id, cid FROM encrypted_cids_v29", { cursor in
            peerIdToConversationId[PeerId(namespace: Namespaces.Peer.SecretChat, id: cursor.getInt32(at: 0))] = cursor.getInt64(at: 1)
            return true
        })
        var chatInfos: [(TelegramSecretChat, SecretChatState, Int32?, [MessageId.Namespace: PeerReadState], Int64)] = []
        for (peerId, conversationId) in peerIdToConversationId {
            database.select("SELECT chat_photo, unread_count, participants, date FROM convesations_v29 WHERE cid=\(conversationId)", { cursor in
                guard let (secretChatData, readStates, minMessageDate) = parseSecretChatData(peerId: peerId, data: cursor.getData(at: 0), unreadCount: cursor.getInt32(at: 1)) else {
                    return false
                }
                guard let (role, userPeerId) = readSecretChatParticipantData(accountPeerId: accountPeerId, data: cursor.getData(at: 2)) else {
                    return false
                }
                let chatMessageDate = cursor.getInt32(at: 3)
                let messageDate = min(minMessageDate, chatMessageDate)
                
                let messageLifetime = loadLegacyPeerCustomProperyInt32(database: database, peerId: conversationId, key: .string("messageLifetime")) ?? 0
                
                let state: SecretChatState
                var seqOut: Int32?
                
                switch secretChatData.handshakeState {
                    case 1: //requested
                        guard let a = loadLegacyPeerCustomProperyData(database: database, peerId: conversationId, key: .string("a")), !a.isEmpty else {
                            return false
                        }
                        state = SecretChatState(role: .creator, embeddedState: .handshake(.requested(g: 3, p: MemoryBuffer(data: defaultPrime), a: MemoryBuffer(data: a))), keychain: SecretChatKeychain(keys: []), keyFingerprint: nil, messageAutoremoveTimeout: nil)
                    case 2: //accepting
                        return false
                    case 3: //terminated
                        state = SecretChatState(role: .creator, embeddedState: .terminated, keychain: SecretChatKeychain(keys: []), keyFingerprint: nil, messageAutoremoveTimeout: nil)
                    case 4:
                        guard let sha1Fingerprint = loadLegacyPeerCustomProperyData(database: database, peerId: conversationId, key: .string("encryptionKeySha1")) else {
                            return false
                        }
                        guard let sha256Fingerprint = loadLegacyPeerCustomProperyData(database: database, peerId: conversationId, key: .string("encryptionKeySha256")) else {
                            return false
                        }
                        
                        guard let keysData = loadLegacyPeerCustomProperyData(database: database, peerId: conversationId, key: .string("encryptionKeys")) else {
                            return false
                        }
                        guard let keysArray = NSKeyedUnarchiver.unarchiveObject(with: keysData) as? [TGEncryptionKeyData] else {
                            return false
                        }
                        let parsedKeys: [SecretChatKey] = keysArray.map({ key in
                            return SecretChatKey(fingerprint: key.keyId, key: MemoryBuffer(data: key.key), validity: .sequenceBasedIndexRange(fromCanonicalIndex: key.firstSeqOut), useCount: 1)
                        })
                        let requestedLayerValue = loadLegacyPeerCustomProperyInt32(database: database, peerId: conversationId, key: .hash(reportedLayer_hash)) ?? 0
                        let appliedSeqInValue = loadLegacyPeerCustomProperyInt32(database: database, peerId: conversationId, key: .hash(seq_in_hash)) ?? 0
                        guard let seqOutValue = loadLegacyPeerCustomProperyInt32(database: database, peerId: conversationId, key: .hash(seq_out_hash)) else {
                            return false
                        }
                        seqOut = seqOutValue
                        guard let activeLayerValue = loadLegacyPeerCustomProperyInt32(database: database, peerId: conversationId, key: .hash(layer_hash)) else {
                            return false
                        }
                        guard let activeLayer = SecretChatSequenceBasedLayer(rawValue: activeLayerValue) else {
                            return false
                        }
                        let rekeyState: SecretChatRekeySessionState? = secretChatData.rekeyState
                        let embeddedState: SecretChatEmbeddedState = .sequenceBasedLayer(SecretChatSequenceBasedLayerState(layerNegotiationState: SecretChatLayerNegotiationState(activeLayer: activeLayer, locallyRequestedLayer: requestedLayerValue == 0 ? nil : requestedLayerValue, remotelyRequestedLayer: nil), rekeyState: rekeyState, baseIncomingOperationIndex: 0, baseOutgoingOperationIndex: 0, topProcessedCanonicalIncomingOperationIndex: appliedSeqInValue == 0 ? nil : max(0, appliedSeqInValue - 1)))
                        state = SecretChatState(role: role, embeddedState: embeddedState, keychain: SecretChatKeychain(keys: parsedKeys), keyFingerprint: SecretChatKeyFingerprint(sha1: SecretChatKeySha1Fingerprint(digest: sha1Fingerprint), sha256: SecretChatKeySha256Fingerprint(digest: sha256Fingerprint)), messageAutoremoveTimeout: messageLifetime == 0 ? nil : messageLifetime)
                    default:
                        return false
                }
                
                let secretChat = TelegramSecretChat(id: peerId, creationDate: messageDate, regularPeerId: userPeerId, accessHash: secretChatData.accessHash, role: role, embeddedState: state.embeddedState.peerState, messageAutoremoveTimeout: messageLifetime == 0 ? nil : messageLifetime)
                
                chatInfos.append((secretChat, state, seqOut, readStates, conversationId))
                
                return false
            })
        }
        var userPeers: [PeerId: Peer] = [:]
        var presences: [PeerId: PeerPresence] = [:]
        for info in chatInfos {
            if let (peer, presence) = loadLegacyUser(database: database, id: info.0.regularPeerId.id) {
                userPeers[peer.id] = peer
                presences[peer.id] = presence
            }
        }
        
        let storedChats = account.postbox.transaction { transaction -> Void in
            updatePeers(transaction: transaction, peers: Array(userPeers.values), update: { _, updated in
                return updated
            })
            transaction.updatePeerPresencesInternal(presences: presences, merge: { _, updated in return updated })
            for (peer, state, seqOutValue, readStates, _) in chatInfos {
                if userPeers[peer.regularPeerId] == nil {
                    continue
                }
                updatePeers(transaction: transaction, peers: [peer], update: { _, updated in
                    return updated
                })
                transaction.setPeerChatState(peer.id, state: state)
                switch state.embeddedState {
                    case .sequenceBasedLayer:
                        if let seqOutValue = seqOutValue {
                            transaction.operationLogResetIndices(peerId: peer.id, tag: OperationLogTags.SecretOutgoing, nextTagLocalIndex: seqOutValue + 1)
                        }
                    default:
                        break
                }
                transaction.resetIncomingReadStates([peer.id: readStates])
            }
        }
        |> ignoreValues
        
        let _ = registeredAttachmentParsers
        
        var countByConversationId: [Int64: Int32] = [:]
        var totalCount: Int32 = 0
        
        for info in chatInfos {
            database.select("SELECT COUNT(*) FROM messages_v29 WHERE cid=\(info.4)", { cursor in
                let count = cursor.getInt32(at: 0)
                countByConversationId[info.4] = count
                totalCount += count
                return true
            })
        }
        
        var storedMessagesSignals: Signal<Float, NoError> = .single(0.0)
        var cumulativeCount: Int32 = 0
        for info in chatInfos {
            let localBaseline = cumulativeCount
            let localCount = countByConversationId[info.4] ?? 0
            storedMessagesSignals = storedMessagesSignals
            |> then(
                loadLegacyMessages(account: account, basePath: basePath, accountPeerId: accountPeerId, peerId: info.0.id, userPeerId: info.0.regularPeerId, database: database, conversationId: info.4, expectedTotalCount: localCount)
                |> map { localProgress -> Float in
                    if totalCount <= 0 {
                        return 0.0
                    }
                    let globalCount = localBaseline + Int32(localProgress * Float(localCount))
                    return Float(globalCount) / Float(totalCount)
                }
            )
            cumulativeCount += countByConversationId[info.4] ?? 0
        }
        
        return storedChats
        |> map { _ -> Float in return 0.0 }
        |> then(storedMessagesSignals)
    }
}
