import Foundation
import UIKit
import MediaEditor

public func chatMediaEditorValuesHaveVisualEdits(_ values: MediaEditorValues) -> Bool {
    if let cropRect = values.cropRect {
        let fullRect = CGRect(origin: .zero, size: values.originalDimensions.cgSize)
        let epsilon: CGFloat = 0.5
        if abs(cropRect.minX - fullRect.minX) > epsilon || abs(cropRect.minY - fullRect.minY) > epsilon || abs(cropRect.width - fullRect.width) > epsilon || abs(cropRect.height - fullRect.height) > epsilon {
            return true
        }
    }
    if values.cropOffset != .zero || values.cropScale != 1.0 || values.cropRotation != 0.0 || values.cropMirroring != values.videoIsMirrored || (values.cropOrientation ?? .up) != .up || !values.cropPerspective.isZero {
        return true
    }
    if values.videoTrimRange != nil {
        return true
    }
    if values.drawing != nil || !values.entities.isEmpty {
        return true
    }
    if values.hasAdjustments || values.hasTint || values.hasBlur || values.hasCurves {
        return true
    }
    if values.audioTrack != nil {
        return true
    }
    return false
}

public func chatMediaEditorValuesAreEdited(_ values: MediaEditorValues, baselineQualityPreset: MediaQualityPreset?) -> Bool {
    if chatMediaEditorValuesHaveVisualEdits(values) {
        return true
    }
    if values.videoIsMuted {
        return true
    }
    if let baselineQualityPreset, values.qualityPreset != baselineQualityPreset {
        return true
    }
    return false
}

public final class ChatMediaEditorItemStore {
    public struct Entry {
        public var values: MediaEditorValues?
        public var lockedAspectRatio: CGFloat?
        public var thumbnail: UIImage?

        public init(values: MediaEditorValues? = nil, lockedAspectRatio: CGFloat? = nil, thumbnail: UIImage? = nil) {
            self.values = values
            self.lockedAspectRatio = lockedAspectRatio
            self.thumbnail = thumbnail
        }
    }

    private var entries: [String: Entry] = [:]
    private var qualityPresetBaselines: [String: MediaQualityPreset] = [:]

    public init() {
    }

    public func entry(for uniqueId: String) -> Entry? {
        return self.entries[uniqueId]
    }

    public func update(_ uniqueId: String, _ f: (inout Entry) -> Void) {
        var entry = self.entries[uniqueId] ?? Entry()
        f(&entry)
        self.entries[uniqueId] = entry
    }

    public func qualityPresetBaseline(for uniqueId: String) -> MediaQualityPreset? {
        return self.qualityPresetBaselines[uniqueId]
    }

    public func noteQualityPresetBaseline(_ preset: MediaQualityPreset?, for uniqueId: String) {
        guard let preset, self.qualityPresetBaselines[uniqueId] == nil else {
            return
        }
        self.qualityPresetBaselines[uniqueId] = preset
    }

    public func isEdited(_ uniqueId: String) -> Bool {
        guard let values = self.entries[uniqueId]?.values else {
            return false
        }
        return chatMediaEditorValuesAreEdited(values, baselineQualityPreset: self.qualityPresetBaselines[uniqueId])
    }

    public var editedIdentifiers: Set<String> {
        var result = Set<String>()
        for uniqueId in self.entries.keys where self.isEdited(uniqueId) {
            result.insert(uniqueId)
        }
        return result
    }
}
