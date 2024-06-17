import Foundation
import UIKit
import SwiftSignalKit
import CoreLocation
import TelegramCore
import TelegramUIPreferences
import PersistentStringHash
import Postbox
import AccountContext

public struct MediaEditorResultPrivacy: Codable, Equatable {
    private enum CodingKeys: String, CodingKey {
        case sendAsPeerId
        case privacy
        case timeout
        case disableForwarding
        case archive
    }
    
    public let sendAsPeerId: EnginePeer.Id?
    public let privacy: EngineStoryPrivacy
    public let timeout: Int
    public let isForwardingDisabled: Bool
    public let pin: Bool
    
    public init(
        sendAsPeerId: EnginePeer.Id?,
        privacy: EngineStoryPrivacy,
        timeout: Int,
        isForwardingDisabled: Bool,
        pin: Bool
    ) {
        self.sendAsPeerId = sendAsPeerId
        self.privacy = privacy
        self.timeout = timeout
        self.isForwardingDisabled = isForwardingDisabled
        self.pin = pin
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.sendAsPeerId = try container.decodeIfPresent(Int64.self, forKey: .sendAsPeerId).flatMap { EnginePeer.Id($0) }
        self.privacy = try container.decode(EngineStoryPrivacy.self, forKey: .privacy)
        self.timeout = Int(try container.decode(Int32.self, forKey: .timeout))
        self.isForwardingDisabled = try container.decodeIfPresent(Bool.self, forKey: .disableForwarding) ?? false
        self.pin = try container.decode(Bool.self, forKey: .archive)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
    
        try container.encodeIfPresent(self.sendAsPeerId?.toInt64(), forKey: .sendAsPeerId)
        try container.encode(self.privacy, forKey: .privacy)
        try container.encode(Int32(self.timeout), forKey: .timeout)
        try container.encode(self.isForwardingDisabled, forKey: .disableForwarding)
        try container.encode(self.pin, forKey: .archive)
    }
}

public final class MediaEditorDraft: Codable, Equatable {
    enum ReadError: Error {
        case generic
    }
    
    public static func == (lhs: MediaEditorDraft, rhs: MediaEditorDraft) -> Bool {
        return lhs.path == rhs.path
    }
    
    private enum CodingKeys: String, CodingKey {
        case path
        case isVideo
        case thumbnail
        case dimensionsWidth
        case dimensionsHeight
        case duration
        case values
        case caption
        case privacy
        case forwardInfo
        case timestamp
        case locationLatitude
        case locationLongitude
        case expiresOn
    }
    
    public let path: String
    public let isVideo: Bool
    public let thumbnail: UIImage
    public let dimensions: PixelDimensions
    public let duration: Double?
    public let values: MediaEditorValues
    public let caption: NSAttributedString
    public let privacy: MediaEditorResultPrivacy?
    public let forwardInfo: StoryId?
    public let timestamp: Int32
    public let location: CLLocationCoordinate2D?
    public let expiresOn: Int32?
        
    public init(path: String, isVideo: Bool, thumbnail: UIImage, dimensions: PixelDimensions, duration: Double?, values: MediaEditorValues, caption: NSAttributedString, privacy: MediaEditorResultPrivacy?, forwardInfo: StoryId?, timestamp: Int32, location: CLLocationCoordinate2D?, expiresOn: Int32?) {
        self.path = path
        self.isVideo = isVideo
        self.thumbnail = thumbnail
        self.dimensions = dimensions
        self.duration = duration
        self.values = values
        self.caption = caption
        self.privacy = privacy
        self.forwardInfo = forwardInfo
        self.timestamp = timestamp
        self.location = location
        self.expiresOn = expiresOn
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.path = try container.decode(String.self, forKey: .path)
        self.isVideo = try container.decode(Bool.self, forKey: .isVideo)
        let thumbnailData = try container.decode(Data.self, forKey: .thumbnail)
        if let thumbnail = UIImage(data: thumbnailData) {
            self.thumbnail = thumbnail
        } else {
            throw ReadError.generic
        }
        self.dimensions = PixelDimensions(
            width: try container.decode(Int32.self, forKey: .dimensionsWidth),
            height: try container.decode(Int32.self, forKey: .dimensionsHeight)
        )
        self.duration = try container.decodeIfPresent(Double.self, forKey: .duration)
        let valuesData = try container.decode(Data.self, forKey: .values)
        if let values = try? JSONDecoder().decode(MediaEditorValues.self, from: valuesData) {
            self.values = values
        } else {
            throw ReadError.generic
        }
        self.caption = ((try? container.decode(ChatTextInputStateText.self, forKey: .caption)) ?? ChatTextInputStateText()).attributedText()
        
        if let data = try container.decodeIfPresent(Data.self, forKey: .privacy), let privacy = try? JSONDecoder().decode(MediaEditorResultPrivacy.self, from: data) {
            self.privacy = privacy
        } else {
            self.privacy = nil
        }
        
        self.forwardInfo = try container.decodeIfPresent(StoryId.self, forKey: .forwardInfo)
        
        self.timestamp = try container.decodeIfPresent(Int32.self, forKey: .timestamp) ?? 1688909663
        
        if let latitude = try container.decodeIfPresent(Double.self, forKey: .locationLatitude), let longitude = try container.decodeIfPresent(Double.self, forKey: .locationLongitude) {
            self.location = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        } else {
            self.location = nil
        }
        
        self.expiresOn = try container.decodeIfPresent(Int32.self, forKey: .expiresOn)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(self.path, forKey: .path)
        try container.encode(self.isVideo, forKey: .isVideo)
        if let thumbnailData = self.thumbnail.jpegData(compressionQuality: 0.6) {
            try container.encode(thumbnailData, forKey: .thumbnail)
        }
        try container.encode(self.dimensions.width, forKey: .dimensionsWidth)
        try container.encode(self.dimensions.height, forKey: .dimensionsHeight)
        try container.encodeIfPresent(self.duration, forKey: .duration)
        if let valuesData = try? JSONEncoder().encode(self.values) {
            try container.encode(valuesData, forKey: .values)
        }
        let chatInputText = ChatTextInputStateText(attributedText: self.caption)
        try container.encode(chatInputText, forKey: .caption)
        
        if let privacy = self.privacy {
            if let data = try? JSONEncoder().encode(privacy) {
                try container.encode(data, forKey: .privacy)
            } else {
                try container.encodeNil(forKey: .privacy)
            }
        } else {
            try container.encodeNil(forKey: .privacy)
        }
        try container.encodeIfPresent(self.forwardInfo, forKey: .forwardInfo)
        
        try container.encode(self.timestamp, forKey: .timestamp)
        
        if let location = self.location {
            try container.encode(location.latitude, forKey: .locationLatitude)
            try container.encode(location.longitude, forKey: .locationLongitude)
        } else {
            try container.encodeNil(forKey: .locationLatitude)
            try container.encodeNil(forKey: .locationLongitude)
        }
        try container.encodeIfPresent(self.expiresOn, forKey: .expiresOn)
    }
}

private struct MediaEditorDraftItemId {
    public let rawValue: MemoryBuffer
    
    var value: Int64 {
        return self.rawValue.makeData().withUnsafeBytes { buffer -> Int64 in
            guard let bytes = buffer.baseAddress?.assumingMemoryBound(to: Int64.self) else {
                return 0
            }
            return bytes.pointee
        }
    }
    
    init(_ rawValue: MemoryBuffer) {
        self.rawValue = rawValue
    }
    
    init(_ value: Int64) {
        var value = value
        self.rawValue = MemoryBuffer(data: Data(bytes: &value, count: MemoryLayout.size(ofValue: value)))
    }
    
    init(_ value: UInt64) {
        var value = Int64(bitPattern: value)
        self.rawValue = MemoryBuffer(data: Data(bytes: &value, count: MemoryLayout.size(ofValue: value)))
    }
}

public func addStoryDraft(engine: TelegramEngine, item: MediaEditorDraft) {
    let itemId = MediaEditorDraftItemId(item.path.persistentHashValue)
    let _ = engine.orderedLists.addOrMoveToFirstPosition(collectionId: ApplicationSpecificOrderedItemListCollectionId.storyDrafts, id: itemId.rawValue, item: item, removeTailIfCountExceeds: 50).start()
}

public func removeStoryDraft(engine: TelegramEngine, path: String, delete: Bool) {
    if delete {
        try? FileManager.default.removeItem(atPath: fullDraftPath(peerId: engine.account.peerId, path: path))
    }
    let itemId = MediaEditorDraftItemId(path.persistentHashValue)
    let _ = engine.orderedLists.removeItem(collectionId: ApplicationSpecificOrderedItemListCollectionId.storyDrafts, id: itemId.rawValue).start()
}

public func clearStoryDrafts(engine: TelegramEngine) {
    let _ = engine.data.get(TelegramEngine.EngineData.Item.OrderedLists.ListItems(collectionId: ApplicationSpecificOrderedItemListCollectionId.storyDrafts)).start(next: { items in
        for item in items {
            if let draft = item.contents.get(MediaEditorDraft.self) {
                removeStoryDraft(engine: engine, path: draft.path, delete: true)
            }
        }
    })
}

public func deleteAllStoryDrafts(peerId: EnginePeer.Id) {
    let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] + "/storyDrafts_\(peerId.toInt64())/"
    try? FileManager.default.removeItem(atPath: path)
}

public func storyDrafts(engine: TelegramEngine) -> Signal<[MediaEditorDraft], NoError> {
    return engine.data.subscribe(TelegramEngine.EngineData.Item.OrderedLists.ListItems(collectionId: ApplicationSpecificOrderedItemListCollectionId.storyDrafts))
    |> map { items -> [MediaEditorDraft] in
        var result: [MediaEditorDraft] = []
        for item in items {
            if let draft = item.contents.get(MediaEditorDraft.self) {
                result.append(draft)
            }
        }
        return result
    }
}

public func updateStoryDrafts(engine: TelegramEngine) {
    let currentTimestamp = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
    let _ = engine.data.get(
        TelegramEngine.EngineData.Item.OrderedLists.ListItems(collectionId: ApplicationSpecificOrderedItemListCollectionId.storyDrafts)
    ).start(next: { items in
        for item in items {
            if let draft = item.contents.get(MediaEditorDraft.self) {
                if let expiresOn = draft.expiresOn, expiresOn < currentTimestamp {
                    removeStoryDraft(engine: engine, path: draft.path, delete: true)
                }
            }
        }
    })
}

public extension MediaEditorDraft {
    func fullPath(engine: TelegramEngine) -> String {
        return fullDraftPath(peerId: engine.account.peerId, path: self.path)
    }
}

func fullDraftPath(peerId: EnginePeer.Id, path: String) -> String {
    return NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] + "/storyDrafts_\(peerId.toInt64())/" + path
}
