import Foundation
import UIKit
import SwiftSignalKit
import TelegramCore
import LegacyComponents
import MediaEditor
import ChatMediaSend

public enum ChatMediaEditorCapturedContent: Equatable {
    case image(path: String, dimensions: PixelDimensions)
    case video(path: String, dimensions: PixelDimensions, duration: Double, mirror: Bool)

    public var path: String {
        switch self {
        case let .image(path, _):
            return path
        case let .video(path, _, _, _):
            return path
        }
    }

    public var isVideo: Bool {
        switch self {
        case .image:
            return false
        case .video:
            return true
        }
    }
}

public struct ChatMediaEditorCapturedItem {
    public let uniqueId: String
    public let content: ChatMediaEditorCapturedContent
    public let thumbnail: UIImage?

    public init(uniqueId: String, content: ChatMediaEditorCapturedContent, thumbnail: UIImage?) {
        self.uniqueId = uniqueId
        self.content = content
        self.thumbnail = thumbnail
    }

    public var editorItem: ChatMediaEditorItem {
        switch self.content {
        case let .image(path, dimensions):
            return ChatMediaEditorItem(uniqueId: self.uniqueId, source: .imageFile(path: path, dimensions: dimensions), thumbnail: self.thumbnail)
        case let .video(path, dimensions, duration, mirror):
            return ChatMediaEditorItem(uniqueId: self.uniqueId, source: .video(path: path, dimensions: dimensions, duration: duration), isMirrored: mirror, thumbnail: self.thumbnail)
        }
    }
}

public final class ChatMediaEditorCapturedLegacyItem: NSObject, TGMediaEditableItem, TGMediaSelectableItem {
    public let item: ChatMediaEditorCapturedItem

    public init(item: ChatMediaEditorCapturedItem) {
        self.item = item
        super.init()
    }

    public var uniqueIdentifier: String! {
        return self.item.uniqueId
    }

    public var isVideo: Bool {
        return self.item.content.isVideo
    }

    public var originalSize: CGSize {
        switch self.item.content {
        case let .image(_, dimensions):
            return dimensions.cgSize
        case let .video(_, dimensions, _, _):
            return dimensions.cgSize
        }
    }

    public var originalDuration: TimeInterval {
        switch self.item.content {
        case .image:
            return 0.0
        case let .video(_, _, duration, _):
            return duration
        }
    }
}

public final class ChatMediaEditorCaptureSession {
    public let selectionContext: TGMediaSelectionContext
    public let editingContext: TGMediaEditingContext?
    public let store: ChatMediaEditorItemStore
    public private(set) var items: [ChatMediaEditorCapturedItem] = []
    private var legacyItems: [String: ChatMediaEditorCapturedLegacyItem] = [:]

    public init(selectionLimit: Int, allowsGrouping: Bool, editingContext: TGMediaEditingContext?) {
        self.selectionContext = TGMediaSelectionContext(groupingAllowed: allowsGrouping, selectionLimit: Int32(selectionLimit))!
        if allowsGrouping {
            self.selectionContext.grouping = true
        }
        self.editingContext = editingContext
        self.store = ChatMediaEditorItemStore()
    }

    public func add(_ item: ChatMediaEditorCapturedItem) {
        guard self.legacyItems[item.uniqueId] == nil else {
            return
        }
        let legacyItem = ChatMediaEditorCapturedLegacyItem(item: item)
        self.legacyItems[item.uniqueId] = legacyItem
        self.items.append(item)
        let _ = self.selectionContext.setItem(legacyItem, selected: true)
    }

    public func remove(uniqueId: String) {
        guard let legacyItem = self.legacyItems.removeValue(forKey: uniqueId) else {
            return
        }
        self.items.removeAll(where: { $0.uniqueId == uniqueId })
        let _ = self.selectionContext.setItem(legacyItem, selected: false)
    }

    public func removeAll() {
        self.items.removeAll()
        self.legacyItems.removeAll()
        self.selectionContext.clear()
    }

    public func contains(uniqueId: String) -> Bool {
        return self.legacyItems[uniqueId] != nil
    }

    public func item(uniqueId: String) -> ChatMediaEditorCapturedItem? {
        return self.legacyItems[uniqueId]?.item
    }

    public func legacyItem(uniqueId: String) -> NSObject? {
        return self.legacyItems[uniqueId]
    }

    public func editorItem(uniqueId: String) -> ChatMediaEditorItem? {
        return self.legacyItems[uniqueId]?.item.editorItem
    }

    public func makeResolver() -> ChatMediaEditorLegacyItemResolver {
        return ChatMediaEditorLegacyItemResolver(selectionContext: self.selectionContext, items: self.items.compactMap { self.legacyItems[$0.uniqueId] }, lookup: { [weak self] uniqueId in
            return self?.legacyItems[uniqueId]
        })
    }

    public func sendUniqueIds(currentId: String) -> [String] {
        let selected = (self.selectionContext.selectedItemsIdentifiers()?.array ?? []).compactMap { $0 as? String }.filter { self.legacyItems[$0] != nil }
        if selected.isEmpty {
            return [currentId]
        }
        return selected
    }

    public func timer(uniqueId: String) -> Int32? {
        guard let legacyItem = self.legacyItems[uniqueId], let timer = self.editingContext?.timer(for: legacyItem)?.int32Value, timer != 0 else {
            return nil
        }
        return timer
    }

    public func sendItem(uniqueId: String, peerId: EnginePeer.Id) -> ChatMediaSendItem? {
        guard let legacyItem = self.legacyItems[uniqueId] else {
            return nil
        }
        let captured = legacyItem.item
        let editedValues = mediaPickerChatMediaSendEditedValues(store: self.store, uniqueId: uniqueId)
        let editedThumbnail = editedValues != nil ? self.store.entry(for: uniqueId)?.thumbnail : nil
        let options: (MediaEditorValues?) -> ChatMediaSendItemOptions = { values in
            return ChatMediaSendItemOptions(
                caption: self.editingContext?.caption(for: legacyItem),
                timer: self.timer(uniqueId: uniqueId),
                spoiler: self.editingContext?.spoiler(for: legacyItem) ?? false,
                price: self.editingContext?.price(for: legacyItem)?.int64Value,
                isAnimation: false,
                hasAnimatedPainting: values?.entities.contains(where: { $0.entity.isAnimated }) ?? false,
                isMuted: captured.content.isVideo && (values?.videoIsMuted ?? false)
            )
        }
        switch captured.content {
        case let .image(path, dimensions):
            let stickers = editedValues.flatMap { chatMediaSendCollectStickers(entities: $0.entities) } ?? []
            return ChatMediaSendItem(uniqueId: uniqueId, source: .imageFile(path: path, dimensions: dimensions), values: editedValues, thumbnail: editedThumbnail ?? captured.thumbnail, stickers: stickers, options: options(editedValues))
        case let .video(path, dimensions, duration, mirror):
            var values = editedValues
            if values == nil && mirror {
                values = chatMediaEditorEditorSetup(subject: .video(path: path, dimensions: dimensions, duration: duration), peerId: peerId, isMirrored: true).values
            }
            let stickers = values.flatMap { chatMediaSendCollectStickers(entities: $0.entities) } ?? []
            return ChatMediaSendItem(uniqueId: uniqueId, source: .tempVideo(path: path, dimensions: dimensions, duration: duration), values: values, thumbnail: editedThumbnail ?? captured.thumbnail, coverImage: self.editingContext?.coverImage(for: legacyItem), stickers: stickers, options: options(values))
        }
    }
}
