import Foundation
import UIKit
import XCTest
import TelegramCore
import MediaEditor
import ChatMediaSend

final class ChatMediaEditorItemStoreTests: XCTestCase {
    private let peerId = EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(1))
    private let dimensions = PixelDimensions(width: 4032, height: 3024)

    private func plainValues(qualityPreset: MediaQualityPreset = .compressedVeryHigh) -> MediaEditorValues {
        return chatMediaEditorValues(peerId: self.peerId, originalDimensions: self.dimensions, qualityPreset: qualityPreset)
    }

    private func values(drawing: UIImage? = nil, toolValues: [EditorToolKey: Any] = [:]) -> MediaEditorValues {
        return MediaEditorValues(
            peerId: self.peerId,
            originalDimensions: self.dimensions,
            cropOffset: .zero,
            cropRect: nil,
            cropScale: 1.0,
            cropRotation: 0.0,
            cropMirroring: false,
            cropOrientation: nil,
            cropPerspective: .zero,
            gradientColors: nil,
            videoTrimRange: nil,
            videoBounce: false,
            videoIsMuted: false,
            videoIsFullHd: false,
            videoIsMirrored: false,
            videoVolume: 1.0,
            additionalVideoPath: nil,
            additionalVideoIsDual: false,
            additionalVideoMirroringChanges: [],
            additionalVideoPosition: nil,
            additionalVideoScale: nil,
            additionalVideoRotation: nil,
            additionalVideoPositionChanges: [],
            additionalVideoTrimRange: nil,
            additionalVideoOffset: nil,
            additionalVideoVolume: nil,
            collage: [],
            nightTheme: false,
            drawing: drawing,
            maskDrawing: nil,
            entities: [],
            toolValues: toolValues,
            audioTrack: nil,
            audioTrackTrimRange: nil,
            audioTrackOffset: nil,
            audioTrackVolume: nil,
            audioTrackSamples: nil,
            collageTrackSamples: nil,
            coverImageTimestamp: nil,
            coverDimensions: nil,
            qualityPreset: .compressedVeryHigh
        )
    }

    func testStoreRoundTrip() {
        let store = ChatMediaEditorItemStore()
        XCTAssertNil(store.entry(for: "a"))

        let thumbnail = UIImage()
        let values = self.plainValues().withUpdatedCrop(rect: CGRect(x: 0.0, y: 0.0, width: 2000.0, height: 2000.0), rotation: 0.0, orientation: nil, mirroring: false, perspective: .zero)
        store.update("a") { entry in
            entry.values = values
            entry.lockedAspectRatio = 1.0
            entry.thumbnail = thumbnail
        }

        let entry = store.entry(for: "a")
        XCTAssertEqual(entry?.values, values)
        XCTAssertEqual(entry?.lockedAspectRatio, 1.0)
        XCTAssertTrue(entry?.thumbnail === thumbnail)
        XCTAssertNil(store.entry(for: "b"))

        store.update("a") { entry in
            entry.lockedAspectRatio = nil
        }
        XCTAssertEqual(store.entry(for: "a")?.values, values)
        XCTAssertNil(store.entry(for: "a")?.lockedAspectRatio)
        XCTAssertTrue(store.entry(for: "a")?.thumbnail === thumbnail)
    }

    func testEditedIdentifiersOnlyChanged() {
        let store = ChatMediaEditorItemStore()
        let entity = CodableDrawingEntity.text(DrawingTextEntity(text: NSAttributedString(string: "a"), style: .regular, animation: .none, font: .sanFrancisco, alignment: .left, fontSize: 1.0, color: DrawingColor(rgb: 0xffffff)))

        store.update("plainPhoto") { $0.values = self.plainValues() }
        store.update("plainVideo") { $0.values = self.plainValues(qualityPreset: .compressedHigh) }
        store.update("thumbnailOnly") { entry in
            entry.thumbnail = UIImage()
            entry.lockedAspectRatio = 1.0
        }
        store.update("fullCropRect") { $0.values = self.plainValues().withUpdatedCrop(rect: CGRect(x: 0.0, y: 0.0, width: 4032.0, height: 3024.0), rotation: 0.0, orientation: nil, mirroring: false, perspective: .zero) }
        store.update("defaultTools") { $0.values = self.values(toolValues: [.enhance: Float(0.0), .brightness: Float(0.0)]) }

        store.update("cropped") { $0.values = self.plainValues().withUpdatedCrop(rect: CGRect(x: 10.0, y: 10.0, width: 2000.0, height: 2000.0), rotation: 0.0, orientation: nil, mirroring: false, perspective: .zero) }
        store.update("rotated") { $0.values = self.plainValues().withUpdatedCrop(rect: nil, rotation: 0.0, orientation: .right, mirroring: false, perspective: .zero) }
        store.update("mirrored") { $0.values = self.plainValues().withUpdatedCrop(rect: nil, rotation: 0.0, orientation: nil, mirroring: true, perspective: .zero) }
        store.update("tilted") { $0.values = self.plainValues().withUpdatedCrop(rect: nil, rotation: 0.0, orientation: nil, mirroring: false, perspective: MediaEditorCropPerspective(vertical: 0.1, horizontal: 0.0)) }
        store.update("trimmed") { $0.values = self.plainValues().withUpdatedVideoTrimRange(1.0 ..< 2.0) }
        store.update("drawn") { $0.values = self.values(drawing: UIImage()) }
        store.update("entities") { $0.values = self.plainValues().withUpdatedEntities([entity]) }
        store.update("adjusted") { $0.values = self.values(toolValues: [.enhance: Float(0.5)]) }

        XCTAssertEqual(store.editedIdentifiers, ["cropped", "rotated", "mirrored", "tilted", "trimmed", "drawn", "entities", "adjusted"])
    }

    func testMutedCountsAsEdit() {
        let plain = self.plainValues(qualityPreset: .compressedMedium)
        let muted = plain.withUpdatedVideoIsMuted(true)
        XCTAssertFalse(chatMediaEditorValuesAreEdited(plain, baselineQualityPreset: .compressedMedium))
        XCTAssertTrue(chatMediaEditorValuesAreEdited(muted, baselineQualityPreset: .compressedMedium))
        XCTAssertTrue(chatMediaEditorValuesAreEdited(muted, baselineQualityPreset: nil))
        let store = ChatMediaEditorItemStore()
        store.update("muted") { $0.values = muted }
        XCTAssertTrue(store.isEdited("muted"))
        XCTAssertEqual(store.editedIdentifiers, ["muted"])
    }

    func testUserChangedQualityPresetCountsAsEdit() {
        let medium = self.plainValues(qualityPreset: .compressedMedium)
        let high = self.plainValues(qualityPreset: .compressedHigh)
        XCTAssertFalse(chatMediaEditorValuesAreEdited(medium, baselineQualityPreset: .compressedMedium))
        XCTAssertTrue(chatMediaEditorValuesAreEdited(high, baselineQualityPreset: .compressedMedium))
        XCTAssertFalse(chatMediaEditorValuesAreEdited(high, baselineQualityPreset: nil))
        XCTAssertFalse(chatMediaEditorValuesHaveVisualEdits(high))

        let store = ChatMediaEditorItemStore()
        store.noteQualityPresetBaseline(.compressedMedium, for: "untouched")
        store.noteQualityPresetBaseline(.compressedMedium, for: "changed")
        store.noteQualityPresetBaseline(.compressedHigh, for: "changed")
        store.noteQualityPresetBaseline(.compressedHigh, for: "storedDefault")
        store.noteQualityPresetBaseline(.compressedVeryHigh, for: "photo")
        XCTAssertEqual(store.qualityPresetBaseline(for: "changed"), .compressedMedium)
        XCTAssertNil(store.entry(for: "untouched"))

        store.update("untouched") { $0.values = medium }
        store.update("changed") { $0.values = high }
        store.update("storedDefault") { $0.values = high }
        store.update("photo") { $0.values = self.plainValues() }
        store.update("noBaseline") { $0.values = high }

        XCTAssertFalse(store.isEdited("untouched"))
        XCTAssertTrue(store.isEdited("changed"))
        XCTAssertFalse(store.isEdited("storedDefault"))
        XCTAssertFalse(store.isEdited("photo"))
        XCTAssertFalse(store.isEdited("noBaseline"))
        XCTAssertFalse(store.isEdited("missing"))
        XCTAssertEqual(store.editedIdentifiers, ["changed"])
    }
}
