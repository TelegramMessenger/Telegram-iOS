import Foundation
import UIKit
import XCTest
import TelegramCore
import LegacyComponents
import MediaEditor
import MediaCropComponent
import MediaEditorScreen
import ChatMediaSend
@testable import ChatMediaEditorScreen

private let cropTabPeerId = EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(1))

private func cropTabValues(width: Int32 = 4032, height: Int32 = 3024) -> MediaEditorValues {
    return chatMediaEditorValues(peerId: cropTabPeerId, originalDimensions: PixelDimensions(width: width, height: height), qualityPreset: .compressedVeryHigh)
}

final class ChatMediaEditorCropTabTests: XCTestCase {
    private func editedState() -> MediaCropState {
        var state = MediaCropState(originalSize: CGSize(width: 4032.0, height: 3024.0))
        state.cropRect = CGRect(x: 400.0, y: 300.0, width: 1600.0, height: 1200.0)
        state.rotation = 0.2
        state.orientation = .left
        state.mirrored = true
        state.lockedAspectRatio = 0.75
        return state
    }

    func testCropSessionCancelRestoresEntry() {
        let entry = MediaCropState(originalSize: CGSize(width: 4032.0, height: 3024.0))
        var session = ChatMediaEditorCropSession(entry: entry)
        session.current = self.editedState()
        XCTAssertEqual(session.cancelled(), entry)
        XCTAssertNotEqual(session.committed(), entry)
    }

    func testCropSessionCommitKeepsCurrent() {
        let entry = MediaCropState(originalSize: CGSize(width: 4032.0, height: 3024.0))
        var session = ChatMediaEditorCropSession(entry: entry)
        XCTAssertEqual(session.committed(), entry)
        let edited = self.editedState()
        session.current = edited
        XCTAssertEqual(session.committed(), edited)
        XCTAssertEqual(session.entry, entry)
    }

    func testValuesRoundTrip() {
        let values = cropTabValues()
        let defaultState = chatMediaEditorCropState(values: values)
        XCTAssertEqual(defaultState, MediaCropState(originalSize: CGSize(width: 4032.0, height: 3024.0)))
        XCTAssertTrue(defaultState.isDefault)

        let unchanged = chatMediaEditorValues(values, applying: defaultState)
        XCTAssertNil(unchanged.cropRect)
        XCTAssertNil(unchanged.cropOrientation)
        XCTAssertEqual(unchanged.cropRotation, 0.0)
        XCTAssertFalse(unchanged.cropMirroring)

        var edited = self.editedState()
        let applied = chatMediaEditorValues(values, applying: edited)
        XCTAssertEqual(applied.cropRect, edited.cropRect)
        XCTAssertEqual(applied.cropRotation, edited.rotation)
        XCTAssertEqual(applied.cropOrientation, .left)
        XCTAssertTrue(applied.cropMirroring)
        XCTAssertEqual(applied.cropOffset, .zero)
        XCTAssertEqual(applied.cropScale, 1.0)

        edited.lockedAspectRatio = nil
        XCTAssertEqual(chatMediaEditorCropState(values: applied), edited)

        let reset = chatMediaEditorValues(applied, applying: MediaCropState(originalSize: CGSize(width: 4032.0, height: 3024.0)))
        XCTAssertNil(reset.cropRect)
        XCTAssertNil(reset.cropOrientation)
        XCTAssertEqual(reset.cropRotation, 0.0)
        XCTAssertFalse(reset.cropMirroring)
    }

    func testPhotoTabsOrder() {
        XCTAssertEqual(chatMediaEditorToolbarTabs(), [.cropTab, .paintTab, .toolsTab])
    }

    func testVideoTabsOrder() {
        XCTAssertEqual(chatMediaEditorToolbarTabs(), [.cropTab, .paintTab, .toolsTab])
    }

    func testCropOnlyTabPolicy() {
        XCTAssertEqual(chatMediaEditorToolbarTabs(policy: .cropOnly), [.cropTab])
        XCTAssertEqual(chatMediaEditorToolbarTabs(showsQuality: true, policy: .cropOnly), [.cropTab])
        XCTAssertEqual(chatMediaEditorToolbarTabs(policy: .standard), [.cropTab, .paintTab, .toolsTab])
    }

    func testIdCardInitialCropValues() {
        let values = chatMediaEditorIdCardInitialValues(peerId: cropTabPeerId, dimensions: PixelDimensions(width: 3000, height: 4000))
        XCTAssertEqual(values.cropRect, CGRect(x: 0.0, y: 944.0, width: 3000.0, height: 2112.0))
        XCTAssertEqual(values.originalDimensions, PixelDimensions(width: 3000, height: 4000))
        XCTAssertEqual(values.cropRotation, 0.0)
        XCTAssertNil(values.cropOrientation)
        XCTAssertFalse(values.cropMirroring)
        XCTAssertTrue(chatMediaEditorValuesHaveVisualEdits(values))
    }

    func testFilePreviewHasNoEditTabs() {
        XCTAssertEqual(chatMediaEditorToolbarTabs(policy: .filePreview), [])
        XCTAssertEqual(chatMediaEditorToolbarTabs(showsQuality: true, policy: .filePreview), [])
        XCTAssertEqual(chatMediaEditorToolbarTabs(policy: .standard), [.cropTab, .paintTab, .toolsTab])
        XCTAssertEqual(chatMediaEditorToolbarTabs(showsQuality: true, policy: .standard), [.cropTab, .paintTab, .toolsTab, .qualityTab])
    }

    func testFilePreviewInfoString() {
        XCTAssertEqual(chatMediaFilePreviewInfoString(isVideo: false, fileName: "IMG_0001.heic", fileSize: 2100000, dimensions: CGSize(width: 4032.0, height: 3024.0), formattedFileSize: "2 MB"), "HEIC • 2 MB • 4032x3024")
        XCTAssertEqual(chatMediaFilePreviewInfoString(isVideo: false, fileName: "IMG_0001.heic", fileSize: 0, dimensions: CGSize(width: 4032.0, height: 3024.0), formattedFileSize: ""), "4032x3024")
        XCTAssertEqual(chatMediaFilePreviewInfoString(isVideo: true, fileName: "IMG_0002.MOV", fileSize: 5000000, dimensions: CGSize(width: 1920.0, height: 1080.0), formattedFileSize: "4.8 MB"), "MOV • 4.8 MB • 1080p")
        XCTAssertEqual(chatMediaFilePreviewInfoString(isVideo: true, fileName: nil, fileSize: 0, dimensions: CGSize(width: 640.0, height: 352.0), formattedFileSize: ""), "640x352")
    }

    func testFilePreviewInfoStringIgnoresAssetUrlFragment() {
        XCTAssertEqual(chatMediaFilePreviewInfoString(isVideo: true, fileName: "IMG_0026.MP4#YnBsaXN0MDDRAQJfEBtSZWNvbW1lbmRlZA", fileSize: 1200000, dimensions: CGSize(width: 1280.0, height: 720.0), formattedFileSize: "1.2 MB"), "MP4 • 1.2 MB • 720p")
        XCTAssertEqual(chatMediaFilePreviewInfoString(isVideo: false, fileName: "IMG_0046.HEIC#YnBsaXN0MDA", fileSize: 19000, dimensions: CGSize(width: 1200.0, height: 1600.0), formattedFileSize: "19 KB"), "HEIC • 19 KB • 1200x1600")
    }

    func testCropToolbarHighlights() {
        XCTAssertEqual(chatMediaEditorCropToolbarTabs(), [.rotateTab, .mirrorTab, .aspectRatioTab])
        var state = MediaCropState(originalSize: CGSize(width: 4032.0, height: 3024.0))
        XCTAssertEqual(chatMediaEditorCropHighlightedTabs(state: state), [])
        state.mirrored = true
        XCTAssertEqual(chatMediaEditorCropHighlightedTabs(state: state), [.mirrorTab])
        state.lockedAspectRatio = 0.75
        XCTAssertEqual(chatMediaEditorCropHighlightedTabs(state: state), [.mirrorTab, .aspectRatioTab])
    }

    func testPreviewMediaSizeFollowsDisplayedCrop() {
        let values = cropTabValues().withUpdatedCrop(rect: CGRect(x: 0.0, y: 0.0, width: 2000.0, height: 1000.0), rotation: 0.0, orientation: .left, mirroring: false, perspective: .zero)
        let mediaSize = chatMediaEditorPreviewMediaSize(values: values)
        XCTAssertEqual(mediaSize, CGSize(width: 1000.0, height: 2000.0))

        let size = CGSize(width: 402.0, height: 874.0)
        let insets = UIEdgeInsets(top: 62.0, left: 0.0, bottom: 34.0, right: 0.0)
        let layout = chatMediaEditorLayout(size: size, safeInsets: insets, mediaSize: mediaSize, toolbarHeight: 49.0, captionPanelHeight: 62.0, keyboardHeight: 0.0)
        XCTAssertEqual(layout.previewFrame.width / layout.previewFrame.height, 0.5, accuracy: 0.001)

        XCTAssertEqual(chatMediaEditorPreviewMediaSize(values: cropTabValues()), CGSize(width: 4032.0, height: 3024.0))
    }

    func testPreviewPlacementShowsCropRegion() {
        var state = MediaCropState(originalSize: CGSize(width: 4000.0, height: 3000.0))
        state.cropRect = CGRect(x: 0.0, y: 0.0, width: 2000.0, height: 1500.0)
        let frameSize = CGSize(width: 400.0, height: 300.0)
        let placement = chatMediaEditorCropPreviewPlacement(state: state, frameSize: frameSize)
        XCTAssertEqual(placement.scale, 0.2, accuracy: 0.0001)
        XCTAssertEqual(placement.angle, 0.0, accuracy: 0.0001)
        XCTAssertEqual(placement.center.x, 400.0, accuracy: 0.001)
        XCTAssertEqual(placement.center.y, 300.0, accuracy: 0.001)

        state.orientation = .left
        let rotated = chatMediaEditorCropPreviewPlacement(state: state, frameSize: CGSize(width: 300.0, height: 400.0))
        XCTAssertEqual(rotated.angle, -.pi / 2.0, accuracy: 0.0001)
        XCTAssertEqual(rotated.scale, 0.2, accuracy: 0.0001)
        XCTAssertEqual(rotated.center.x, 300.0, accuracy: 0.001)
        XCTAssertEqual(rotated.center.y, 0.0, accuracy: 0.001)
    }

    func testCropContainerLeavesPanelAboveToolbar() {
        let size = CGSize(width: 402.0, height: 874.0)
        let insets = UIEdgeInsets(top: 62.0, left: 0.0, bottom: 34.0, right: 0.0)
        let photo = chatMediaEditorCropContainerFrame(size: size, safeInsets: insets, toolbarHeight: 49.0, hasRotationWheel: true)
        XCTAssertEqual(photo, CGRect(x: 0.0, y: 62.0, width: 402.0, height: 874.0 - 62.0 - 34.0 - 49.0 - 115.0))
        let video = chatMediaEditorCropContainerFrame(size: size, safeInsets: insets, toolbarHeight: 49.0, hasRotationWheel: false)
        XCTAssertEqual(video.maxY, 874.0 - 34.0 - 49.0 - 60.0)
    }

    func testCropSessionChangesAreMeasuredFromTheEntryState() {
        var entry = MediaCropState(originalSize: CGSize(width: 4000.0, height: 3000.0))
        entry.rotation = 0.2
        entry.cropRect = CGRect(x: 100.0, y: 100.0, width: 2000.0, height: 1500.0)
        XCTAssertFalse(chatMediaEditorCropHasSessionChanges(entry: entry, current: entry))

        var nudged = entry
        nudged.cropRect = nudged.cropRect.offsetBy(dx: 5.0, dy: -5.0)
        nudged.rotation += 0.000001
        XCTAssertFalse(chatMediaEditorCropHasSessionChanges(entry: entry, current: nudged))

        var moved = entry
        moved.cropRect = moved.cropRect.offsetBy(dx: 200.0, dy: 0.0)
        XCTAssertTrue(chatMediaEditorCropHasSessionChanges(entry: entry, current: moved))

        var rotated = entry
        rotated.rotation = 0.0
        XCTAssertTrue(chatMediaEditorCropHasSessionChanges(entry: entry, current: rotated))

        var turned = entry
        turned.orientation = .left
        XCTAssertTrue(chatMediaEditorCropHasSessionChanges(entry: entry, current: turned))

        var mirrored = entry
        mirrored.mirrored = true
        XCTAssertTrue(chatMediaEditorCropHasSessionChanges(entry: entry, current: mirrored))

        var locked = entry
        locked.lockedAspectRatio = 1.0
        XCTAssertTrue(chatMediaEditorCropHasSessionChanges(entry: entry, current: locked))
        XCTAssertFalse(chatMediaEditorCropHasSessionChanges(entry: locked, current: locked))
    }

    func testResetShowsOnlyWhenTheCropDiffersFromTheOriginal() {
        let original = MediaCropState(originalSize: CGSize(width: 4000.0, height: 3000.0))
        XCTAssertFalse(chatMediaEditorCropShowsReset(state: original, baselineMirrored: false))

        var rotated = original
        rotated.rotation = 0.1
        XCTAssertTrue(chatMediaEditorCropShowsReset(state: rotated, baselineMirrored: false))

        var turned = original
        turned.orientation = .left
        XCTAssertTrue(chatMediaEditorCropShowsReset(state: turned, baselineMirrored: false))

        var cropped = original
        cropped.cropRect = CGRect(x: 0.0, y: 0.0, width: 2000.0, height: 3000.0)
        XCTAssertTrue(chatMediaEditorCropShowsReset(state: cropped, baselineMirrored: false))

        var locked = original
        locked.lockedAspectRatio = 1.0
        XCTAssertTrue(chatMediaEditorCropShowsReset(state: locked, baselineMirrored: false))

        var mirrored = original
        mirrored.mirrored = true
        XCTAssertTrue(chatMediaEditorCropShowsReset(state: mirrored, baselineMirrored: false))
        XCTAssertFalse(chatMediaEditorCropShowsReset(state: mirrored, baselineMirrored: true))
        XCTAssertTrue(chatMediaEditorCropShowsReset(state: original, baselineMirrored: true))
    }

    func testDialAndResetAreCentredBetweenCropAreaAndBottomPanel() {
        let size = CGSize(width: 402.0, height: 874.0)
        let insets = UIEdgeInsets(top: 62.0, left: 0.0, bottom: 34.0, right: 0.0)
        let layout = chatMediaEditorCropControlsLayout(size: size, safeInsets: insets, toolbarHeight: 49.0, hasRotationWheel: true, resetButtonWidth: 40.0)
        XCTAssertEqual(layout.rotationDial, CGRect(x: 0.0, y: 696.0, width: 402.0, height: 28.0))
        XCTAssertEqual(layout.resetButton, CGRect(x: 181.0, y: 738.0, width: 40.0, height: 24.0))

        let areaBottom = mediaCropAvailableArea(container: chatMediaEditorCropContainerFrame(size: size, safeInsets: insets, toolbarHeight: 49.0, hasRotationWheel: true)).maxY
        let panelTop = 874.0 - 34.0 - 49.0
        XCTAssertEqual(layout.rotationDial.minY - areaBottom, panelTop - layout.resetButton.maxY, accuracy: 1.0)

        let video = chatMediaEditorCropControlsLayout(size: size, safeInsets: insets, toolbarHeight: 49.0, hasRotationWheel: false, resetButtonWidth: 40.0)
        let videoAreaBottom = mediaCropAvailableArea(container: chatMediaEditorCropContainerFrame(size: size, safeInsets: insets, toolbarHeight: 49.0, hasRotationWheel: false)).maxY
        XCTAssertEqual(video.resetButton.minY - videoAreaBottom, panelTop - video.resetButton.maxY, accuracy: 1.0)
        XCTAssertEqual(video.resetButton.height, 24.0)
    }

    func testPaintEntitiesUprightAndSizedForCrop() {
        var state = MediaCropState(originalSize: CGSize(width: 4000.0, height: 3000.0))
        XCTAssertEqual(chatMediaEditorPaintEntityInitialRotation(state: state), 0.0)
        XCTAssertEqual(chatMediaEditorPaintEntityAdditionalScale(state: state), 1.0)

        state.cropRect = CGRect(x: 0.0, y: 0.0, width: 2000.0, height: 1000.0)
        state.orientation = .left
        state.rotation = 0.2
        let rotation = chatMediaEditorPaintEntityInitialRotation(state: state)
        XCTAssertEqual(rotation + mediaCropContentAngle(state), 0.0, accuracy: 0.0001)
        XCTAssertEqual(rotation, .pi / 2.0 - 0.2, accuracy: 0.0001)
        XCTAssertEqual(chatMediaEditorPaintEntityAdditionalScale(state: state), 0.25, accuracy: 0.0001)
    }

    func testNewPaintEntityTakesCropScaleOnceAndCopiesKeepTheirs() {
        let entity = DrawingStickerEntity(content: .image(UIImage(), .sticker))
        XCTAssertEqual(entity.scale, 1.0)
        chatMediaEditorScaleNewPaintEntity(entity, additionalScale: 0.25)
        XCTAssertEqual(entity.scale, 0.25, accuracy: 0.0001)

        let source = DrawingStickerEntity(content: .image(UIImage(), .sticker))
        let copy = source.duplicate(copy: false)
        XCTAssertEqual(copy.scale, 1.0)
        XCTAssertNotEqual(copy.uuid, source.uuid)

        let explicit = DrawingStickerEntity(content: .image(UIImage(), .sticker))
        explicit.scale = 2.5
        chatMediaEditorScaleNewPaintEntity(explicit, additionalScale: 0.25)
        XCTAssertEqual(explicit.scale, 2.5)

        let uncropped = DrawingStickerEntity(content: .image(UIImage(), .sticker))
        chatMediaEditorScaleNewPaintEntity(uncropped, additionalScale: 1.0)
        XCTAssertEqual(uncropped.scale, 1.0)
    }

    func testToolsMediaGeometryCoversUncroppedMedia() {
        let previewFrame = CGRect(x: 10.0, y: 100.0, width: 300.0, height: 400.0)
        XCTAssertNil(chatMediaEditorToolsMediaGeometry(values: cropTabValues(width: 4000, height: 3000), previewFrame: previewFrame))

        let values = cropTabValues(width: 4000, height: 3000).withUpdatedCrop(rect: CGRect(x: 0.0, y: 0.0, width: 2000.0, height: 1500.0), rotation: 0.0, orientation: .left, mirroring: true, perspective: .zero)
        guard let geometry = chatMediaEditorToolsMediaGeometry(values: values, previewFrame: previewFrame) else {
            XCTFail()
            return
        }
        XCTAssertEqual(geometry.size.width, 800.0, accuracy: 0.001)
        XCTAssertEqual(geometry.size.height, 600.0, accuracy: 0.001)
        XCTAssertEqual(geometry.center.x, 10.0 + 300.0, accuracy: 0.001)
        XCTAssertEqual(geometry.center.y, 100.0 + 0.0, accuracy: 0.001)
        let expected = CGAffineTransform(scaleX: -1.0, y: 1.0).concatenating(CGAffineTransform(rotationAngle: -.pi / 2.0))
        XCTAssertEqual(geometry.transform.m11, expected.a, accuracy: 0.0001)
        XCTAssertEqual(geometry.transform.m12, expected.b, accuracy: 0.0001)
        XCTAssertEqual(geometry.transform.m21, expected.c, accuracy: 0.0001)
        XCTAssertEqual(geometry.transform.m22, expected.d, accuracy: 0.0001)
        XCTAssertEqual(geometry.transform.m14, 0.0, accuracy: 0.0001)
    }

    func testNearFullRectStoredAsNil() {
        var state = MediaCropState(originalSize: CGSize(width: 4032.0, height: 3024.0))
        state.cropRect = CGRect(x: 0.0000001, y: 0.0, width: 4032.0000001, height: 3024.0)
        XCTAssertNil(chatMediaEditorValues(cropTabValues(), applying: state).cropRect)
    }

    func testCropStateMapsPerspectiveBothWays() {
        let perspective = MediaEditorCropPerspective(vertical: 0.2, horizontal: -0.1)
        let values = cropTabValues().withUpdatedCrop(rect: nil, rotation: 0.0, orientation: nil, mirroring: false, perspective: perspective)
        let state = chatMediaEditorCropState(values: values)
        XCTAssertEqual(state.perspective, perspective)
        XCTAssertEqual(chatMediaEditorValues(cropTabValues(), applying: state).cropPerspective, perspective)
        var cleared = state
        cleared.perspective = .zero
        XCTAssertEqual(chatMediaEditorValues(values, applying: cleared).cropPerspective, .zero)
    }

    func testSessionChangesCountPerspective() {
        let entry = MediaCropState(originalSize: CGSize(width: 4032.0, height: 3024.0))
        var current = entry
        current.perspective = MediaEditorCropPerspective(vertical: 0.01, horizontal: 0.0)
        XCTAssertTrue(chatMediaEditorCropHasSessionChanges(entry: entry, current: current))
        XCTAssertFalse(chatMediaEditorCropHasSessionChanges(entry: entry, current: entry))
    }

    func testCancelledSessionRestoresEntryPerspective() {
        var entry = MediaCropState(originalSize: CGSize(width: 4032.0, height: 3024.0))
        entry.perspective = MediaEditorCropPerspective(vertical: 0.1, horizontal: 0.0)
        var session = ChatMediaEditorCropSession(entry: entry)
        session.current.perspective = MediaEditorCropPerspective(vertical: -0.3, horizontal: 0.2)
        XCTAssertEqual(session.cancelled().perspective, entry.perspective)
        XCTAssertEqual(session.committed().perspective, MediaEditorCropPerspective(vertical: -0.3, horizontal: 0.2))
    }

    func testShowsResetForPerspectiveOnly() {
        var state = MediaCropState(originalSize: CGSize(width: 4032.0, height: 3024.0))
        XCTAssertFalse(chatMediaEditorCropShowsReset(state: state, baselineMirrored: false))
        state.perspective = MediaEditorCropPerspective(vertical: 0.0, horizontal: 0.05)
        XCTAssertTrue(chatMediaEditorCropShowsReset(state: state, baselineMirrored: false))
        XCTAssertTrue(chatMediaEditorCropStateHasChanges(state, baselineMirrored: false))
    }

    func testControlsLayoutPlacesSelectorBetweenPhotoAndDial() {
        let size = CGSize(width: 402.0, height: 874.0)
        let insets = UIEdgeInsets(top: 62.0, left: 0.0, bottom: 34.0, right: 0.0)
        let plain = chatMediaEditorCropControlsLayout(size: size, safeInsets: insets, toolbarHeight: 49.0, hasRotationWheel: true, resetButtonWidth: 40.0)
        XCTAssertEqual(plain.selector, .zero)
        XCTAssertEqual(plain.rotationDial, CGRect(x: 0.0, y: 696.0, width: 402.0, height: 28.0))

        let layout = chatMediaEditorCropControlsLayout(size: size, safeInsets: insets, toolbarHeight: 49.0, hasRotationWheel: true, hasPerspective: true, resetButtonWidth: 40.0)
        let areaBottom = mediaCropAvailableArea(container: chatMediaEditorCropContainerFrame(size: size, safeInsets: insets, toolbarHeight: 49.0, hasRotationWheel: true, hasPerspective: true)).maxY
        XCTAssertEqual(layout.selector.height, mediaCropAdjustmentSelectorHeight)
        XCTAssertEqual(layout.selector.width, size.width)
        XCTAssertGreaterThanOrEqual(layout.selector.minY, areaBottom)
        XCTAssertLessThanOrEqual(layout.selector.maxY, layout.rotationDial.minY)
        XCTAssertLessThanOrEqual(layout.rotationDial.maxY, layout.resetButton.minY)
        XCTAssertLessThanOrEqual(layout.resetButton.maxY, 874.0 - 34.0 - 49.0)
        XCTAssertEqual(layout.selector.minY - areaBottom, 874.0 - 34.0 - 49.0 - layout.resetButton.maxY, accuracy: 1.0)
    }

    func testPreviewPlacementCarriesPerspective() {
        var state = MediaCropState(originalSize: CGSize(width: 4000.0, height: 3000.0))
        state.perspective = MediaEditorCropPerspective(vertical: 0.2, horizontal: 0.0)
        let placement = chatMediaEditorCropPreviewPlacement(state: state, frameSize: CGSize(width: 400.0, height: 300.0))
        XCTAssertEqual(placement.perspective, MediaEditorPerspectiveHomography(perspective: state.perspective, size: CGSize(width: 4000.0 * placement.scale, height: 3000.0 * placement.scale)))
        XCTAssertEqual(chatMediaEditorCropPreviewPlacement(state: MediaCropState(originalSize: state.originalSize), frameSize: CGSize(width: 400.0, height: 300.0)).perspective, .identity)
    }

    private let landscapeSize = CGSize(width: 874.0, height: 402.0)
    private let landscapeInsets = UIEdgeInsets(top: 0.0, left: 62.0, bottom: 20.0, right: 62.0)

    func testLandscapeCropContainerLeft() {
        XCTAssertEqual(chatMediaEditorCropContainerFrame(size: landscapeSize, safeInsets: landscapeInsets, toolbarHeight: 49.0, hasRotationWheel: true, hasPerspective: true, toolbarSide: .left), CGRect(x: 334.0, y: 0.0, width: 478.0, height: 382.0))
        XCTAssertEqual(chatMediaEditorCropContainerFrame(size: landscapeSize, safeInsets: landscapeInsets, toolbarHeight: 49.0, hasRotationWheel: true, hasPerspective: false, toolbarSide: .left), CGRect(x: 272.0, y: 0.0, width: 540.0, height: 382.0))
        XCTAssertEqual(chatMediaEditorCropContainerFrame(size: landscapeSize, safeInsets: landscapeInsets, toolbarHeight: 49.0, hasRotationWheel: false, toolbarSide: .left), CGRect(x: 172.0, y: 0.0, width: 640.0, height: 382.0))
    }

    func testLandscapeCropContainerRight() {
        XCTAssertEqual(chatMediaEditorCropContainerFrame(size: landscapeSize, safeInsets: landscapeInsets, toolbarHeight: 49.0, hasRotationWheel: true, hasPerspective: true, toolbarSide: .right), CGRect(x: 62.0, y: 0.0, width: 478.0, height: 382.0))
        XCTAssertEqual(chatMediaEditorCropContainerFrame(size: landscapeSize, safeInsets: landscapeInsets, toolbarHeight: 49.0, hasRotationWheel: false, toolbarSide: .right), CGRect(x: 62.0, y: 0.0, width: 640.0, height: 382.0))
    }

    func testLandscapeCropControlsLeft() {
        let layout = chatMediaEditorCropControlsLayout(size: landscapeSize, safeInsets: landscapeInsets, toolbarHeight: 49.0, hasRotationWheel: true, hasPerspective: true, resetButtonWidth: 40.0, toolbarSide: .left)
        XCTAssertEqual(layout.selector, CGRect(x: 284.0, y: 0.0, width: 50.0, height: 382.0))
        XCTAssertEqual(layout.rotationDial, CGRect(x: 172.0, y: 0.0, width: 100.0, height: 382.0))
        XCTAssertEqual(layout.rotationDialScale, 1.0)
        XCTAssertEqual(layout.rotationDialAxis, .vertical(clockwise: true))
        XCTAssertEqual(layout.resetButton, CGRect(x: 121.0, y: 179.0, width: 40.0, height: 24.0))

        let video = chatMediaEditorCropControlsLayout(size: landscapeSize, safeInsets: landscapeInsets, toolbarHeight: 49.0, hasRotationWheel: false, resetButtonWidth: 40.0, toolbarSide: .left)
        XCTAssertEqual(video.selector, .zero)
        XCTAssertEqual(video.rotationDial, .zero)
        XCTAssertEqual(video.resetButton, CGRect(x: 121.0, y: 179.0, width: 40.0, height: 24.0))
    }

    func testLandscapeCropControlsRight() {
        let layout = chatMediaEditorCropControlsLayout(size: landscapeSize, safeInsets: landscapeInsets, toolbarHeight: 49.0, hasRotationWheel: true, hasPerspective: true, resetButtonWidth: 40.0, toolbarSide: .right)
        XCTAssertEqual(layout.selector, CGRect(x: 540.0, y: 0.0, width: 50.0, height: 382.0))
        XCTAssertEqual(layout.rotationDial, CGRect(x: 602.0, y: 0.0, width: 100.0, height: 382.0))
        XCTAssertEqual(layout.rotationDialScale, 1.0)
        XCTAssertEqual(layout.rotationDialAxis, .vertical(clockwise: false))
        XCTAssertEqual(layout.resetButton, CGRect(x: 712.0, y: 179.0, width: 40.0, height: 24.0))
    }

    func testLandscapeWideResetButtonKeepsStripCentre() {
        let layout = chatMediaEditorCropControlsLayout(size: landscapeSize, safeInsets: landscapeInsets, toolbarHeight: 49.0, hasRotationWheel: true, hasPerspective: true, resetButtonWidth: 80.0, toolbarSide: .left)
        XCTAssertEqual(layout.resetButton, CGRect(x: 101.0, y: 179.0, width: 80.0, height: 24.0))
        XCTAssertGreaterThan(layout.resetButton.width, chatMediaEditorCropLandscapeResetStripWidth)
    }

    func testPortraitCropUnchanged() {
        let size = CGSize(width: 402.0, height: 874.0)
        let insets = UIEdgeInsets(top: 62.0, left: 0.0, bottom: 34.0, right: 0.0)
        for (hasRotationWheel, hasPerspective) in [(true, true), (true, false), (false, false)] {
            XCTAssertEqual(chatMediaEditorCropContainerFrame(size: size, safeInsets: insets, toolbarHeight: 49.0, hasRotationWheel: hasRotationWheel, hasPerspective: hasPerspective), chatMediaEditorCropContainerFrame(size: size, safeInsets: insets, toolbarHeight: 49.0, hasRotationWheel: hasRotationWheel, hasPerspective: hasPerspective, toolbarSide: nil))
            let layout = chatMediaEditorCropControlsLayout(size: size, safeInsets: insets, toolbarHeight: 49.0, hasRotationWheel: hasRotationWheel, hasPerspective: hasPerspective, resetButtonWidth: 40.0)
            XCTAssertEqual(layout, chatMediaEditorCropControlsLayout(size: size, safeInsets: insets, toolbarHeight: 49.0, hasRotationWheel: hasRotationWheel, hasPerspective: hasPerspective, resetButtonWidth: 40.0, toolbarSide: nil))
            XCTAssertEqual(layout.rotationDialAxis, .horizontal)
        }
        let plain = chatMediaEditorCropControlsLayout(size: size, safeInsets: insets, toolbarHeight: 49.0, hasRotationWheel: true, resetButtonWidth: 40.0)
        XCTAssertEqual(plain.rotationDial, CGRect(x: 0.0, y: 696.0, width: 402.0, height: 28.0))
        XCTAssertEqual(plain.resetButton, CGRect(x: 181.0, y: 738.0, width: 40.0, height: 24.0))
        XCTAssertEqual(plain.rotationDialScale, 1.0)
        XCTAssertEqual(chatMediaEditorCropContainerFrame(size: size, safeInsets: insets, toolbarHeight: 49.0, hasRotationWheel: true), CGRect(x: 0.0, y: 62.0, width: 402.0, height: 874.0 - 62.0 - 34.0 - 49.0 - 115.0))
    }

    func testHorizontalDialPlacementIsItsFrame() {
        let frame = CGRect(x: 0.0, y: 696.0, width: 402.0, height: 28.0)
        let placement = mediaCropDialPlacement(frame: frame, axis: .horizontal)
        XCTAssertEqual(placement.bounds, CGRect(x: 0.0, y: 0.0, width: 402.0, height: 28.0))
        XCTAssertEqual(placement.center, CGPoint(x: 201.0, y: 710.0))
        XCTAssertTrue(placement.transform.isIdentity)
    }

    private func dialDragTranslation(frame: CGRect, axis: MediaCropDialAxis, screenTranslation: CGPoint) -> (local: CGFloat, frame: CGRect, topEdgeX: CGFloat) {
        let parent = UIView(frame: CGRect(origin: .zero, size: landscapeSize))
        let dial = UIView()
        parent.addSubview(dial)
        let placement = mediaCropDialPlacement(frame: frame, axis: axis)
        dial.bounds = placement.bounds
        dial.center = placement.center
        dial.transform = placement.transform
        let start = CGPoint(x: frame.midX, y: frame.midY)
        let end = CGPoint(x: start.x + screenTranslation.x, y: start.y + screenTranslation.y)
        let local = dial.convert(end, from: parent).x - dial.convert(start, from: parent).x
        let topEdgeX = dial.convert(CGPoint(x: dial.bounds.midX, y: 0.0), to: parent).x
        return (local, dial.frame, topEdgeX)
    }

    func testVerticalDialDragDownMatchesPortraitDragRightOnLeftSide() {
        let strip = CGRect(x: 172.0, y: 62.0, width: 100.0, height: 320.0)
        let placement = mediaCropDialPlacement(frame: strip, axis: .vertical(clockwise: true))
        XCTAssertEqual(placement.bounds, CGRect(x: 0.0, y: 0.0, width: 320.0, height: 100.0))
        XCTAssertEqual(placement.center, CGPoint(x: 222.0, y: 222.0))

        let portrait = dialDragTranslation(frame: CGRect(x: 0.0, y: 300.0, width: 402.0, height: 28.0), axis: .horizontal, screenTranslation: CGPoint(x: 10.0, y: 0.0))
        XCTAssertEqual(portrait.local, 10.0, accuracy: 0.001)

        let left = dialDragTranslation(frame: strip, axis: .vertical(clockwise: true), screenTranslation: CGPoint(x: 0.0, y: 10.0))
        XCTAssertEqual(left.local, 10.0, accuracy: 0.001)
        XCTAssertEqual(left.frame.minX, strip.minX, accuracy: 0.001)
        XCTAssertEqual(left.frame.minY, strip.minY, accuracy: 0.001)
        XCTAssertEqual(left.frame.width, strip.width, accuracy: 0.001)
        XCTAssertEqual(left.frame.height, strip.height, accuracy: 0.001)
        XCTAssertEqual(left.topEdgeX, strip.maxX, accuracy: 0.001)
    }

    func testVerticalDialDragDownIsMirroredOnRightSide() {
        let strip = CGRect(x: 602.0, y: 62.0, width: 100.0, height: 320.0)
        let right = dialDragTranslation(frame: strip, axis: .vertical(clockwise: false), screenTranslation: CGPoint(x: 0.0, y: 10.0))
        XCTAssertEqual(right.local, -10.0, accuracy: 0.001)
        XCTAssertEqual(right.frame.minX, strip.minX, accuracy: 0.001)
        XCTAssertEqual(right.frame.height, strip.height, accuracy: 0.001)
        XCTAssertEqual(right.topEdgeX, strip.minX, accuracy: 0.001)
    }

    private func dialHitRectOnScreen(frame: CGRect, axis: MediaCropDialAxis) -> CGRect {
        let parent = UIView(frame: CGRect(origin: .zero, size: landscapeSize))
        let dial = UIView()
        parent.addSubview(dial)
        let placement = mediaCropDialPlacement(frame: frame, axis: axis)
        dial.bounds = placement.bounds
        dial.center = placement.center
        dial.transform = placement.transform
        return dial.convert(dial.bounds.inset(by: mediaCropDialHitInsets(axis: axis)), to: parent)
    }

    func testHorizontalDialHitInsetsUnchanged() {
        XCTAssertEqual(mediaCropDialHitInsets(axis: .horizontal), UIEdgeInsets(top: -12.0, left: 0.0, bottom: -12.0, right: 0.0))
    }

    func testVerticalDialHitAreaClearsCropHandles() {
        let handleHitOutset: CGFloat = 16.0
        let containerInset: CGFloat = 9.0
        for side in [ChatMediaEditorToolbarSide.left, .right] {
            let container = chatMediaEditorCropContainerFrame(size: landscapeSize, safeInsets: landscapeInsets, toolbarHeight: 49.0, hasRotationWheel: true, hasPerspective: true, toolbarSide: side)
            let layout = chatMediaEditorCropControlsLayout(size: landscapeSize, safeInsets: landscapeInsets, toolbarHeight: 49.0, hasRotationWheel: true, hasPerspective: true, resetButtonWidth: 40.0, toolbarSide: side)
            let hitRect = dialHitRectOnScreen(frame: layout.rotationDial, axis: layout.rotationDialAxis)
            switch side {
            case .left:
                XCTAssertLessThanOrEqual(hitRect.maxX, container.minX + containerInset - handleHitOutset + 0.001)
                XCTAssertEqual(hitRect.minX, layout.rotationDial.minX - 12.0, accuracy: 0.001)
            case .right:
                XCTAssertGreaterThanOrEqual(hitRect.minX, container.maxX - containerInset + handleHitOutset - 0.001)
                XCTAssertEqual(hitRect.maxX, layout.rotationDial.maxX + 12.0, accuracy: 0.001)
            }
            XCTAssertEqual(hitRect.height, layout.rotationDial.height, accuracy: 0.001)
        }
    }
}
