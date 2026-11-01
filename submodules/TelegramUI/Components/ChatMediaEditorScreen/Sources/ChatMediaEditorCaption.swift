import Foundation
import UIKit
import ImageIO
import MediaEditor
import ChatMediaSend

public protocol ChatMediaEditorCaptionAdapter: AnyObject {
    var isForced: Bool { get }
    func caption(for uniqueId: String) -> NSAttributedString?
    func setCaption(_ caption: NSAttributedString?, for uniqueId: String)
    var captionAbove: Bool { get set }
    var isHighQualityPhoto: Bool { get set }
    func setEditedThumbnail(_ image: UIImage?, for uniqueId: String)
    func hasExternalEdits(for uniqueId: String) -> Bool
}

public extension ChatMediaEditorCaptionAdapter {
    func hasExternalEdits(for uniqueId: String) -> Bool {
        return false
    }
}

public let chatMediaEditorCaptionSelectionRevealDelay: Double = 0.25

public func chatMediaEditorKeyboardPagerOffset(keyboardHeight: CGFloat) -> CGFloat {
    guard keyboardHeight > 0.0 else {
        return 0.0
    }
    return -keyboardHeight / 2.0
}

// What covers the bottom of the screen while the caption is edited: the keyboard, or the caption panel's own emoji
// panel (which replaces the keyboard).
public func chatMediaEditorEffectiveKeyboardHeight(inputHeight: CGFloat?, captionAdditionalInputHeight: CGFloat) -> CGFloat {
    return max(inputHeight ?? 0.0, captionAdditionalInputHeight)
}

// The dim over the editor would cover the bottom row, so it shows only while a keyboard hides that row anyway.
public func chatMediaEditorCaptionDimIsVisible(isEditingCaption: Bool, keyboardHeight: CGFloat) -> Bool {
    return isEditingCaption && keyboardHeight > 0.0
}

// Return on a hardware keyboard starts a caption when nothing has the keyboard and the caption field is
// on screen and usable. A focused field (the caption, a text sticker) keeps its own Return.
public func chatMediaEditorReturnFocusesCaption(hasCaptionPanel: Bool, hasFirstResponder: Bool, toolbarSide: ChatMediaEditorToolbarSide?, isToolActive: Bool, isSending: Bool, isDismissing: Bool) -> Bool {
    guard hasCaptionPanel, !hasFirstResponder, !isSending, !isDismissing else {
        return false
    }
    return chatMediaEditorCaptionIsVisible(toolbarSide: toolbarSide, isToolActive: isToolActive, isInterfaceHidden: false)
}

public final class ChatMediaEditorCaptionModel {
    public let adapter: ChatMediaEditorCaptionAdapter
    public private(set) var currentId: String

    public init(adapter: ChatMediaEditorCaptionAdapter, currentId: String) {
        self.adapter = adapter
        self.currentId = currentId
    }

    public var isForced: Bool {
        return self.adapter.isForced
    }

    public var currentCaption: NSAttributedString {
        return self.adapter.caption(for: self.currentId) ?? NSAttributedString()
    }

    public var isCaptionAbove: Bool {
        get {
            return self.adapter.captionAbove
        }
        set {
            self.adapter.captionAbove = newValue
        }
    }

    public var isHighQualityPhoto: Bool {
        return self.adapter.isHighQualityPhoto
    }

    @discardableResult
    public func toggleHighQualityPhoto() -> Bool {
        let value = !self.adapter.isHighQualityPhoto
        self.adapter.isHighQualityPhoto = value
        return value
    }

    public func commit(_ caption: NSAttributedString) {
        self.adapter.setCaption(caption, for: self.currentId)
    }

    public func switchItem(to uniqueId: String) -> NSAttributedString {
        self.currentId = uniqueId
        return self.currentCaption
    }
}

public let chatMediaEditorGridThumbnailMaxPixelSide: CGFloat = 512.0
public let chatMediaEditorStoredThumbnailCompressionQuality: CGFloat = 0.9

public func chatMediaEditorCompactThumbnail(_ image: UIImage, compressionQuality: CGFloat = chatMediaEditorStoredThumbnailCompressionQuality) -> UIImage {
    guard let data = image.jpegData(compressionQuality: compressionQuality), let source = CGImageSourceCreateWithData(data as CFData, nil) else {
        return image
    }
    let options = [kCGImageSourceShouldCache: false] as CFDictionary
    guard let cgImage = CGImageSourceCreateImageAtIndex(source, 0, options) else {
        return image
    }
    return UIImage(cgImage: cgImage, scale: image.scale, orientation: .up)
}

public func chatMediaEditorGridThumbnail(_ image: UIImage, maxPixelSide: CGFloat = chatMediaEditorGridThumbnailMaxPixelSide) -> UIImage {
    let pixelSize = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
    let longSide = max(pixelSize.width, pixelSize.height)
    guard longSide > maxPixelSide, longSide > 0.0 else {
        return image
    }
    let factor = maxPixelSide / longSide
    let size = CGSize(width: max(1.0, round(pixelSize.width * factor)), height: max(1.0, round(pixelSize.height * factor)))
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1.0
    return UIGraphicsImageRenderer(size: size, format: format).image { _ in
        image.draw(in: CGRect(origin: .zero, size: size))
    }
}

public final class ChatMediaEditorEditedThumbnailReporter {
    public let adapter: ChatMediaEditorCaptionAdapter

    public init(adapter: ChatMediaEditorCaptionAdapter) {
        self.adapter = adapter
    }

    public static func make(isGallery: Bool, adapter: ChatMediaEditorCaptionAdapter?) -> ChatMediaEditorEditedThumbnailReporter? {
        guard isGallery, let adapter else {
            return nil
        }
        return ChatMediaEditorEditedThumbnailReporter(adapter: adapter)
    }

    public func itemSaved(_ uniqueId: String, previousValues: MediaEditorValues?, values: MediaEditorValues) {
        let wasEdited = previousValues.flatMap { chatMediaEditorValuesHaveVisualEdits($0) } ?? false
        if !chatMediaEditorValuesHaveVisualEdits(values) && (wasEdited || self.adapter.hasExternalEdits(for: uniqueId)) {
            self.adapter.setEditedThumbnail(nil, for: uniqueId)
        }
    }

    @discardableResult
    public func thumbnailStored(_ source: UIImage, gridThumbnail: UIImage, for uniqueId: String, store: ChatMediaEditorItemStore) -> Bool {
        guard let stored = store.entry(for: uniqueId)?.thumbnail, stored === source else {
            return false
        }
        self.adapter.setEditedThumbnail(gridThumbnail, for: uniqueId)
        return true
    }
}
