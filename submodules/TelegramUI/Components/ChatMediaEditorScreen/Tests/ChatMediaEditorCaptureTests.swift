import Foundation
import UIKit
import XCTest
import SwiftSignalKit
import TelegramCore
import LegacyComponents
@testable import MediaEditor
import ChatMediaSend
import MediaCropComponent
import ComponentFlow
import ChatMediaEditorScreen
import Display

private func capturedPhoto(_ uniqueId: String) -> ChatMediaEditorCapturedItem {
    return ChatMediaEditorCapturedItem(uniqueId: uniqueId, content: .image(path: "/tmp/\(uniqueId).jpg", dimensions: PixelDimensions(width: 4032, height: 3024)), thumbnail: nil)
}

private func capturedVideo(_ uniqueId: String, mirror: Bool) -> ChatMediaEditorCapturedItem {
    return ChatMediaEditorCapturedItem(uniqueId: uniqueId, content: .video(path: "/tmp/\(uniqueId).mp4", dimensions: PixelDimensions(width: 1080, height: 1920), duration: 3.0, mirror: mirror), thumbnail: nil)
}

private func selectedIdentifiers(_ selectionContext: TGMediaSelectionContext) -> [String] {
    return (selectionContext.selectedItemsIdentifiers()?.array ?? []).compactMap { $0 as? String }
}

final class ChatMediaEditorCaptureTests: XCTestCase {
    private let peerId = EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(1))

    func testCapturedFrontVideoCarriesMirror() {
        let front = capturedVideo("front", mirror: true)
        let back = capturedVideo("back", mirror: false)

        XCTAssertTrue(front.editorItem.isMirrored)
        XCTAssertFalse(back.editorItem.isMirrored)
        guard case let .video(path, dimensions, duration) = front.editorItem.source else {
            XCTFail()
            return
        }
        XCTAssertEqual(path, "/tmp/front.mp4")
        XCTAssertEqual(dimensions, PixelDimensions(width: 1080, height: 1920))
        XCTAssertEqual(duration, 3.0)

        let frontSetup = chatMediaEditorEditorSetup(subject: front.editorItem.source.subject, peerId: self.peerId, isMirrored: front.editorItem.isMirrored)
        XCTAssertTrue(frontSetup.values.videoIsMirrored)
        XCTAssertTrue(frontSetup.values.cropMirroring)
        XCTAssertTrue(chatMediaEditorCropState(values: frontSetup.values).mirrored)
        XCTAssertTrue(frontSetup.isVideo)
        let backSetup = chatMediaEditorEditorSetup(subject: back.editorItem.source.subject, peerId: self.peerId, isMirrored: back.editorItem.isMirrored)
        XCTAssertFalse(backSetup.values.videoIsMirrored)
        XCTAssertFalse(backSetup.values.cropMirroring)
        let photoSetup = chatMediaEditorEditorSetup(subject: .image(UIImage()), peerId: self.peerId, isMirrored: true)
        XCTAssertFalse(photoSetup.values.cropMirroring)
        XCTAssertFalse(photoSetup.values.videoIsMirrored)
        XCTAssertFalse(chatMediaEditorEditorSetup(subject: front.editorItem.source.subject, peerId: self.peerId).values.videoIsMirrored)

        let session = ChatMediaEditorCaptureSession(selectionLimit: 100, allowsGrouping: true, editingContext: nil)
        session.add(front)
        session.add(back)

        guard let frontSend = session.sendItem(uniqueId: "front", peerId: self.peerId) else {
            XCTFail()
            return
        }
        XCTAssertEqual(frontSend.values?.videoIsMirrored, true)
        XCTAssertEqual(frontSend.values?.cropMirroring, true)
        guard case let .tempVideo(sendPath, sendDimensions, sendDuration) = frontSend.source else {
            XCTFail()
            return
        }
        XCTAssertEqual(sendPath, "/tmp/front.mp4")
        XCTAssertEqual(sendDimensions, PixelDimensions(width: 1080, height: 1920))
        XCTAssertEqual(sendDuration, 3.0)

        XCTAssertNil(session.sendItem(uniqueId: "back", peerId: self.peerId)?.values)

        session.store.update("front") { entry in
            entry.values = frontSetup.values.withUpdatedVideoIsMuted(true)
        }
        let editedSend = session.sendItem(uniqueId: "front", peerId: self.peerId)
        XCTAssertEqual(editedSend?.values?.videoIsMirrored, true)
        XCTAssertEqual(editedSend?.values?.cropMirroring, true)
        XCTAssertEqual(editedSend?.values?.videoIsMuted, true)
        XCTAssertEqual(editedSend?.options.isMuted, true)
    }

    func testCapturedItemsAllSelected() {
        let session = ChatMediaEditorCaptureSession(selectionLimit: 100, allowsGrouping: true, editingContext: nil)
        session.add(capturedPhoto("a"))
        session.add(capturedVideo("b", mirror: false))
        session.add(capturedPhoto("c"))
        session.add(capturedPhoto("a"))

        XCTAssertEqual(session.items.map { $0.uniqueId }, ["a", "b", "c"])
        XCTAssertEqual(selectedIdentifiers(session.selectionContext), ["a", "b", "c"])
        XCTAssertEqual(session.selectionContext.selectionLimit, 100)
        XCTAssertTrue(session.selectionContext.grouping)

        let adapter = ChatMediaEditorLegacySelectionAdapter(selectionContext: session.selectionContext, resolver: session.makeResolver())
        XCTAssertTrue(adapter.isSelected("a"))
        XCTAssertTrue(adapter.isSelected("b"))
        XCTAssertTrue(adapter.isSelected("c"))
        XCTAssertEqual(adapter.index(of: "b"), 1)
        XCTAssertEqual(session.sendUniqueIds(currentId: "a"), ["a", "b", "c"])

        XCTAssertTrue(adapter.setSelected("b", false, sender: nil))
        XCTAssertEqual(session.sendUniqueIds(currentId: "a"), ["a", "c"])

        session.add(capturedPhoto("d"))
        XCTAssertEqual(selectedIdentifiers(session.selectionContext), ["a", "c", "d"])

        guard let photoSend = session.sendItem(uniqueId: "a", peerId: self.peerId), case let .imageFile(path, dimensions) = photoSend.source else {
            XCTFail()
            return
        }
        XCTAssertEqual(path, "/tmp/a.jpg")
        XCTAssertEqual(dimensions, PixelDimensions(width: 4032, height: 3024))
        XCTAssertNil(photoSend.values)

        guard case .imageFile = session.editorItem(uniqueId: "a")?.source else {
            XCTFail()
            return
        }

        session.remove(uniqueId: "c")
        XCTAssertEqual(selectedIdentifiers(session.selectionContext), ["a", "d"])
        XCTAssertEqual(session.items.map { $0.uniqueId }, ["a", "b", "d"])

        session.removeAll()
        XCTAssertTrue(session.items.isEmpty)
        XCTAssertEqual(session.selectionContext.count(), 0)
        XCTAssertEqual(session.sendUniqueIds(currentId: "x"), ["x"])

        let single = ChatMediaEditorCaptureSession(selectionLimit: 1, allowsGrouping: false, editingContext: nil)
        single.add(capturedPhoto("only"))
        XCTAssertEqual(selectedIdentifiers(single.selectionContext), ["only"])
    }

    func testMirrorBaselineIsNotAnEdit() {
        let front = capturedVideo("front", mirror: true)
        let baseline = chatMediaEditorEditorSetup(subject: front.editorItem.source.subject, peerId: self.peerId, isMirrored: true).values
        XCTAssertFalse(chatMediaEditorValuesHaveVisualEdits(baseline))
        XCTAssertFalse(chatMediaEditorValuesAreEdited(baseline, baselineQualityPreset: baseline.qualityPreset))

        let store = ChatMediaEditorItemStore()
        store.noteQualityPresetBaseline(baseline.qualityPreset, for: "front")
        store.update("front") { entry in
            entry.values = baseline
        }
        XCTAssertFalse(store.isEdited("front"))
        XCTAssertTrue(store.editedIdentifiers.isEmpty)

        let unmirrored = baseline.withUpdatedCrop(rect: nil, rotation: 0.0, orientation: nil, mirroring: false, perspective: .zero)
        XCTAssertTrue(chatMediaEditorValuesHaveVisualEdits(unmirrored))
        store.update("front") { entry in
            entry.values = unmirrored
        }
        XCTAssertTrue(store.isEdited("front"))

        let plain = chatMediaEditorEditorSetup(subject: capturedVideo("back", mirror: false).editorItem.source.subject, peerId: self.peerId).values
        XCTAssertFalse(chatMediaEditorValuesHaveVisualEdits(plain))
        XCTAssertTrue(chatMediaEditorValuesHaveVisualEdits(plain.withUpdatedCrop(rect: nil, rotation: 0.0, orientation: nil, mirroring: true, perspective: .zero)))

        let mirroredState = chatMediaEditorCropState(values: baseline)
        XCTAssertFalse(chatMediaEditorCropStateHasChanges(mirroredState, baselineMirrored: true))
        XCTAssertFalse(chatMediaEditorCropHighlightedTabs(state: mirroredState, baselineMirrored: true).contains(.mirrorTab))
        XCTAssertTrue(chatMediaEditorCropStateHasChanges(chatMediaEditorCropState(values: unmirrored), baselineMirrored: true))
        XCTAssertTrue(chatMediaEditorCropHighlightedTabs(state: chatMediaEditorCropState(values: unmirrored), baselineMirrored: true).contains(.mirrorTab))
        XCTAssertTrue(chatMediaEditorCropHighlightedTabs(state: mirroredState).contains(.mirrorTab))
    }

    func testCropResetKeepsMirrorBaseline() {
        let size = CGSize(width: 108.0, height: 192.0)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.green.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        var state = MediaCropState(originalSize: size)
        state.mirrored = true
        let cropView = MediaCropView(image: image, state: state, hasRotationWheel: false)
        cropView.resetMirrored = true
        cropView.frame = CGRect(x: 0.0, y: 0.0, width: 390.0, height: 844.0)
        cropView.update(containerFrame: CGRect(x: 0.0, y: 0.0, width: 390.0, height: 700.0), rotationDialFrame: CGRect(x: 0.0, y: 720.0, width: 390.0, height: 28.0), transition: .immediate)
        cropView.toggleMirror()
        XCTAssertFalse(cropView.state.mirrored)
        cropView.reset(animated: false)
        XCTAssertTrue(cropView.state.mirrored)

        let plainView = MediaCropView(image: image, state: MediaCropState(originalSize: size), hasRotationWheel: false)
        plainView.frame = CGRect(x: 0.0, y: 0.0, width: 390.0, height: 844.0)
        plainView.update(containerFrame: CGRect(x: 0.0, y: 0.0, width: 390.0, height: 700.0), rotationDialFrame: CGRect(x: 0.0, y: 720.0, width: 390.0, height: 28.0), transition: .immediate)
        plainView.toggleMirror()
        XCTAssertTrue(plainView.state.mirrored)
        plainView.reset(animated: false)
        XCTAssertFalse(plainView.state.mirrored)
    }

    func testCameraReviewDiscardRule() {
        XCTAssertTrue(chatMediaEditorCameraReviewConfirmsDiscard(hasCameraButton: true, itemCount: 2))
        XCTAssertFalse(chatMediaEditorCameraReviewConfirmsDiscard(hasCameraButton: true, itemCount: 1))
        XCTAssertFalse(chatMediaEditorCameraReviewConfirmsDiscard(hasCameraButton: false, itemCount: 2))
        XCTAssertFalse(chatMediaEditorCameraReviewShowsSelection(itemCount: 1))
        XCTAssertTrue(chatMediaEditorCameraReviewShowsSelection(itemCount: 2))
        let size = CGSize(width: 402.0, height: 874.0)
        let frame = chatMediaEditorCameraButtonFrame(size: size, safeInsets: UIEdgeInsets(top: 62.0, left: 0.0, bottom: 34.0, right: 0.0), reservedCorners: .none, toolbarMinY: 791.0, captionBaseHeight: 50.0, hasVideoHeader: false, hasSelection: true)
        XCTAssertEqual(frame, CGRect(x: 306.0, y: 685.0, width: 44.0, height: 44.0))
        let single = chatMediaEditorCameraButtonFrame(size: size, safeInsets: .zero, reservedCorners: .none, toolbarMinY: 791.0, captionBaseHeight: 50.0, hasVideoHeader: true, hasSelection: false)
        XCTAssertEqual(single, CGRect(x: 356.0, y: 635.0, width: 44.0, height: 44.0))
    }

    func testGalleryWithoutSourceCrossfadesUnlessSwiping() {
        XCTAssertEqual(chatMediaEditorGalleryOutStyle(hasSourceView: false, swipeOffset: 0.0, velocity: 0.0), .crossfade)
        XCTAssertEqual(chatMediaEditorGalleryOutStyle(hasSourceView: false, swipeOffset: 120.0, velocity: 0.0), .continueSwipe)
        XCTAssertEqual(chatMediaEditorGalleryOutStyle(hasSourceView: false, swipeOffset: 0.0, velocity: 900.0), .continueSwipe)
        XCTAssertEqual(chatMediaEditorGalleryOutStyle(hasSourceView: true, swipeOffset: 0.0, velocity: 0.0), .zoomToSource)
        XCTAssertEqual(chatMediaEditorGalleryOutStyle(hasSourceView: true, swipeOffset: 120.0, velocity: 900.0), .zoomToSource)
    }

    func testCameraButtonSharesTheCounterCircleCentre() {
        let size = CGSize(width: 402.0, height: 874.0)
        for safeInsets in [UIEdgeInsets(top: 62.0, left: 0.0, bottom: 34.0, right: 0.0), UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 84.0)] {
            for hasVideoHeader in [false, true] {
                let counter = chatMediaEditorCounterButtonFrame(size: size, safeInsets: safeInsets, reservedCorners: .none, toolbarMinY: 791.0, captionBaseHeight: 52.0, hasVideoHeader: hasVideoHeader)
                let circle = chatMediaEditorCounterCircleFrame.offsetBy(dx: counter.minX, dy: counter.minY)
                let camera = chatMediaEditorCameraButtonFrame(size: size, safeInsets: safeInsets, reservedCorners: .none, toolbarMinY: 791.0, captionBaseHeight: 52.0, hasVideoHeader: hasVideoHeader, hasSelection: true)
                XCTAssertLessThanOrEqual(abs(camera.midY - circle.midY), 0.5)
                XCTAssertEqual(circle.maxX, size.width - safeInsets.right - 17.0)
                XCTAssertLessThan(camera.maxX, circle.minX)
            }
        }
    }

    func testCameraButtonStaysBesideTheCounterBesideAStrip() {
        let foldedPortrait = (CGSize(width: 466.0, height: 678.0), UIEdgeInsets(top: 0.0, left: 0.0, bottom: 20.0, right: 84.0), ContainerViewLayoutCorners(topLeft: nil, topRight: CGSize(width: 84.0, height: 170.0), bottomLeft: nil, bottomRight: nil), CGFloat(0.0))
        let unfoldedLandscape = (CGSize(width: 951.0, height: 669.0), UIEdgeInsets(top: 0.0, left: 0.0, bottom: 20.0, right: 84.0), ContainerViewLayoutCorners(topLeft: nil, topRight: CGSize(width: 84.0, height: 120.0), bottomLeft: nil, bottomRight: nil), CGFloat(0.0))
        let foldedLandscapeLeft = (CGSize(width: 678.0, height: 466.0), UIEdgeInsets(top: 0.0, left: 0.0, bottom: 20.0, right: 84.0), ContainerViewLayoutCorners(topLeft: nil, topRight: nil, bottomLeft: nil, bottomRight: CGSize(width: 84.0, height: 82.0)), CGFloat(84.0))
        let phone = (CGSize(width: 402.0, height: 874.0), UIEdgeInsets(top: 62.0, left: 0.0, bottom: 34.0, right: 0.0), ContainerViewLayoutCorners.none, CGFloat(0.0))
        for (size, safeInsets, reservedCorners, rowRightInset) in [foldedPortrait, unfoldedLandscape, foldedLandscapeLeft, phone] {
            for hasVideoHeader in [false, true] {
                let toolbarMinY = size.height - safeInsets.bottom - 49.0
                let counter = chatMediaEditorCounterButtonFrame(size: size, safeInsets: safeInsets, reservedCorners: reservedCorners, toolbarMinY: toolbarMinY, captionBaseHeight: 52.0, hasVideoHeader: hasVideoHeader)
                let circle = chatMediaEditorCounterCircleFrame.offsetBy(dx: counter.minX, dy: counter.minY)
                let camera = chatMediaEditorCameraButtonFrame(size: size, safeInsets: safeInsets, reservedCorners: reservedCorners, toolbarMinY: toolbarMinY, captionBaseHeight: 52.0, hasVideoHeader: hasVideoHeader, hasSelection: true)
                XCTAssertEqual(circle.minX - camera.maxX, 4.0)
                XCTAssertEqual(counter.maxX, size.width - rowRightInset)
                let single = chatMediaEditorCameraButtonFrame(size: size, safeInsets: safeInsets, reservedCorners: reservedCorners, toolbarMinY: toolbarMinY, captionBaseHeight: 52.0, hasVideoHeader: hasVideoHeader, hasSelection: false)
                XCTAssertEqual(single.maxX, size.width - rowRightInset - 2.0)
            }
        }
    }

    func testMutableSourceInsertKeepsIndices() {
        let initial = (0 ..< 10).map { capturedPhoto("i\($0)").editorItem }
        let source = ChatMediaEditorMutableListSource(items: initial)
        var notifications = 0
        let disposable = source.addAppendListener {
            notifications += 1
        }

        let model = ChatMediaEditorPageModel(itemsSource: source, store: ChatMediaEditorItemStore(), initialIndex: 9)
        XCTAssertEqual(model.currentItem.uniqueId, "i9")

        XCTAssertTrue(source.append(capturedPhoto("i10").editorItem))
        XCTAssertEqual(source.count, 11)
        XCTAssertEqual(notifications, 1)
        for index in 0 ..< 10 {
            XCTAssertEqual(source.item(at: index).uniqueId, "i\(index)")
            XCTAssertEqual(source.index(of: "i\(index)"), index)
        }
        XCTAssertEqual(source.item(at: 10).uniqueId, "i10")
        XCTAssertEqual(source.index(of: "i10"), 10)
        XCTAssertNil(source.index(of: "missing"))

        XCTAssertFalse(source.append(capturedPhoto("i3").editorItem))
        XCTAssertEqual(source.count, 11)
        XCTAssertEqual(notifications, 1)
        XCTAssertEqual(source.index(of: "i3"), 3)

        XCTAssertEqual(model.currentIndex, 9)
        XCTAssertEqual(model.currentItem.uniqueId, "i9")
        let restore = model.switchPage(to: 10, savingValues: chatMediaEditorEditorSetup(subject: .video(path: "/tmp/v.mp4", dimensions: PixelDimensions(width: 1080, height: 1920), duration: 1.0), peerId: self.peerId).values, lockedAspectRatio: nil)
        XCTAssertEqual(restore?.item.uniqueId, "i10")

        disposable.dispose()
        XCTAssertTrue(source.append(capturedPhoto("i11").editorItem))
        XCTAssertEqual(notifications, 1)
        XCTAssertEqual(source.count, 12)
    }
}
