import Foundation
import UIKit
import XCTest
import SwiftSignalKit
import LegacyComponents
import ChatMediaEditorScreen

private func makeImage() -> UIImage {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1.0
    return UIGraphicsImageRenderer(size: CGSize(width: 4.0, height: 4.0), format: format).image { context in
        UIColor.red.setFill()
        context.fill(CGRect(x: 0.0, y: 0.0, width: 4.0, height: 4.0))
    }
}

private func uniqueId(_ image: UIImage) -> String {
    return (image as TGMediaSelectableItem).uniqueIdentifier
}

private final class FakeThumbnailTarget: ChatMediaEditorLegacyThumbnailTarget {
    var adjusted = Set<String>()
    var calls: [String] = []
    var temporaryReps: [(String, UIImage)] = []
    var images: [(String, UIImage?)] = []
    let originals = ValuePipe<UIImage>()

    func hasAdjustments(_ uniqueId: String) -> Bool {
        return self.adjusted.contains(uniqueId)
    }

    func clearAdjustments(_ uniqueId: String) {
        self.calls.append("clear:\(uniqueId)")
        self.adjusted.remove(uniqueId)
    }

    func setTemporaryRep(_ image: UIImage, for uniqueId: String) {
        self.calls.append("rep:\(uniqueId)")
        self.temporaryReps.append((uniqueId, image))
    }

    func setImage(_ image: UIImage?, for uniqueId: String) {
        self.calls.append(image == nil ? "image-nil:\(uniqueId)" : "image:\(uniqueId)")
        self.images.append((uniqueId, image))
    }

    func originalThumbnail(_ uniqueId: String) -> Signal<UIImage, NoError> {
        return self.originals.signal()
    }
}

private func drainMainQueue() {
    let expectation = XCTestExpectation()
    DispatchQueue.main.async {
        expectation.fulfill()
    }
    let _ = XCTWaiter.wait(for: [expectation], timeout: 1.0)
}

final class ChatMediaEditorLegacyAdapterTests: XCTestCase {
    func testThumbnailWriterClearsLegacyAdjustmentsAndWritesEdit() {
        let target = FakeThumbnailTarget()
        target.adjusted = ["a"]
        let writer = ChatMediaEditorLegacyThumbnailWriter(target: target)
        XCTAssertTrue(writer.hasExternalEdits(for: "a"))
        XCTAssertFalse(writer.hasExternalEdits(for: "b"))
        let image = makeImage()
        writer.write(image, for: "a")
        XCTAssertEqual(target.calls, ["clear:a", "rep:a", "image:a"])
        XCTAssertFalse(writer.hasExternalEdits(for: "a"))
        XCTAssertTrue(target.images.first?.1 === image)
        XCTAssertFalse(target.temporaryReps.first?.1 === image)
        writer.write(image, for: "b")
        XCTAssertEqual(target.calls, ["clear:a", "rep:a", "image:a", "rep:b", "image:b"])
    }

    func testThumbnailWriterResetRestoresOriginal() {
        let target = FakeThumbnailTarget()
        let writer = ChatMediaEditorLegacyThumbnailWriter(target: target)
        writer.write(nil, for: "a")
        XCTAssertEqual(target.calls, ["image-nil:a"])
        let original = makeImage()
        target.originals.putNext(original)
        drainMainQueue()
        XCTAssertEqual(target.calls, ["image-nil:a", "rep:a"])
        XCTAssertEqual(target.temporaryReps.count, 1)
    }

    func testThumbnailWriterIgnoresLateOriginalAfterNewerEdit() {
        let target = FakeThumbnailTarget()
        let writer = ChatMediaEditorLegacyThumbnailWriter(target: target)
        writer.write(nil, for: "a")
        writer.write(makeImage(), for: "a")
        target.originals.putNext(makeImage())
        drainMainQueue()
        XCTAssertEqual(target.calls, ["image-nil:a", "rep:a", "image:a"])
    }

    func testLegacySelectionAdapterIndexIsZeroBased() {
        let selectionContext = TGMediaSelectionContext(groupingAllowed: false, selectionLimit: 10)!
        let a = makeImage()
        let b = makeImage()
        let c = makeImage()
        selectionContext.setItem(a, selected: true)
        selectionContext.setItem(b, selected: true)
        let resolver = ChatMediaEditorLegacyItemResolver(selectionContext: selectionContext, items: [a, b, c], lookup: { _ in nil })
        let adapter = ChatMediaEditorLegacySelectionAdapter(selectionContext: selectionContext, resolver: resolver)

        XCTAssertEqual(adapter.selectionLimit, 10)
        XCTAssertEqual(adapter.index(of: uniqueId(a)), 0)
        XCTAssertEqual(adapter.index(of: uniqueId(b)), 1)
        XCTAssertNil(adapter.index(of: uniqueId(c)))
        XCTAssertEqual(adapter.selectedIds(), [uniqueId(a), uniqueId(b)])
        XCTAssertTrue(adapter.isSelected(uniqueId(a)))
        XCTAssertFalse(adapter.isSelected(uniqueId(c)))
    }

    func testLegacySelectionAdapterGoesThroughAttemptSelectingAndPassesSender() {
        let selectionContext = TGMediaSelectionContext(groupingAllowed: false, selectionLimit: 10)!
        let allowed = makeImage()
        let banned = makeImage()
        selectionContext.attemptSelectingItem = { item in
            return item?.uniqueIdentifier != uniqueId(banned)
        }
        var senders: [AnyObject?] = []
        let disposable = selectionContext.selectionChangedSignal().start(next: { next in
            senders.append((next as? TGMediaSelectionChange)?.sender as AnyObject?)
        }, error: { _ in
        }, completed: {
        })
        let resolver = ChatMediaEditorLegacyItemResolver(selectionContext: selectionContext, items: [allowed, banned], lookup: { _ in nil })
        let adapter = ChatMediaEditorLegacySelectionAdapter(selectionContext: selectionContext, resolver: resolver)
        let sender = NSObject()

        XCTAssertFalse(adapter.setSelected(uniqueId(banned), true, sender: sender))
        XCTAssertFalse(adapter.isSelected(uniqueId(banned)))
        XCTAssertTrue(adapter.setSelected(uniqueId(allowed), true, sender: sender))
        XCTAssertTrue(adapter.isSelected(uniqueId(allowed)))
        XCTAssertEqual(senders.count, 1)
        XCTAssertTrue(senders.first.flatMap { $0 } === sender)
        disposable?.dispose()
    }

    func testLegacySelectionAdapterRespectsLimit() {
        let selectionContext = TGMediaSelectionContext(groupingAllowed: false, selectionLimit: 1)!
        let a = makeImage()
        let b = makeImage()
        let resolver = ChatMediaEditorLegacyItemResolver(selectionContext: selectionContext, items: [a, b], lookup: { _ in nil })
        let adapter = ChatMediaEditorLegacySelectionAdapter(selectionContext: selectionContext, resolver: resolver)
        XCTAssertTrue(adapter.setSelected(uniqueId(a), true, sender: nil))
        XCTAssertFalse(adapter.setSelected(uniqueId(b), true, sender: nil))
        XCTAssertEqual(adapter.selectedIds(), [uniqueId(a)])
    }

    func testDeselectedItemStaysResolvableAndReselectable() {
        let selectionContext = TGMediaSelectionContext(groupingAllowed: false, selectionLimit: 10)!
        let a = makeImage()
        selectionContext.setItem(a, selected: true)
        let resolver = ChatMediaEditorLegacyItemResolver(selectionContext: selectionContext, items: [], lookup: { _ in nil })
        let adapter = ChatMediaEditorLegacySelectionAdapter(selectionContext: selectionContext, resolver: resolver)
        XCTAssertTrue(adapter.setSelected(uniqueId(a), false, sender: nil))
        XCTAssertFalse(adapter.isSelected(uniqueId(a)))
        XCTAssertTrue(resolver.item(for: uniqueId(a)) === a)
        XCTAssertTrue(adapter.setSelected(uniqueId(a), true, sender: nil))
        XCTAssertTrue(adapter.isSelected(uniqueId(a)))
    }

    func testResolverFallsBackToLookup() {
        let looked = makeImage()
        var lookups = 0
        let resolver = ChatMediaEditorLegacyItemResolver(selectionContext: nil, items: [], lookup: { id in
            lookups += 1
            return id == "asset" ? looked : nil
        })
        XCTAssertTrue(resolver.item(for: "asset") === looked)
        XCTAssertTrue(resolver.item(for: "asset") === looked)
        XCTAssertEqual(lookups, 1)
        XCTAssertNil(resolver.item(for: "missing"))
    }

    func testLegacySelectionAdapterReportsChanges() {
        let selectionContext = TGMediaSelectionContext(groupingAllowed: false, selectionLimit: 10)!
        let a = makeImage()
        let resolver = ChatMediaEditorLegacyItemResolver(selectionContext: selectionContext, items: [a], lookup: { _ in nil })
        let adapter = ChatMediaEditorLegacySelectionAdapter(selectionContext: selectionContext, resolver: resolver)
        var count = 0
        let disposable = adapter.changes.startStandalone(next: { _ in
            count += 1
        })
        selectionContext.setItem(a, selected: true)
        selectionContext.setItem(a, selected: false)
        XCTAssertEqual(count, 2)
        disposable.dispose()
        selectionContext.setItem(a, selected: true)
        XCTAssertEqual(count, 2)
    }

    func testGalleryItemFromLegacyImage() {
        let image = makeImage()
        let item = chatMediaEditorGalleryItem(legacyItem: image)
        XCTAssertEqual(item?.uniqueId, uniqueId(image))
        if case let .image(value)? = item?.source {
            XCTAssertTrue(value === image)
        } else {
            XCTFail()
        }
        XCTAssertNil(chatMediaEditorGalleryItem(legacyItem: NSObject()))
    }

    func testGalleryDoneButton() {
        XCTAssertEqual(chatMediaEditorGalleryDoneButton(isScheduledMessages: false, isActionButtonDone: false), TGPhotoEditorDoneButtonSend)
        XCTAssertEqual(chatMediaEditorGalleryDoneButton(isScheduledMessages: false, isActionButtonDone: true), TGPhotoEditorDoneButtonCheck)
        XCTAssertEqual(chatMediaEditorGalleryDoneButton(isScheduledMessages: true, isActionButtonDone: true), TGPhotoEditorDoneButtonSchedule)
        XCTAssertEqual(chatMediaEditorGalleryDoneButton(isScheduledMessages: true, isActionButtonDone: false), TGPhotoEditorDoneButtonSchedule)
    }

    func testGalleryTransitionMapping() {
        let mapping = chatMediaEditorGalleryTransitionMapping(bounds: CGRect(x: 0.0, y: 0.0, width: 400.0, height: 800.0), mediaFrame: CGRect(x: 0.0, y: 100.0, width: 400.0, height: 300.0), targetFrame: CGRect(x: 10.0, y: 20.0, width: 100.0, height: 100.0))
        XCTAssertEqual(mapping.scale.x, 0.25, accuracy: 0.0001)
        XCTAssertEqual(mapping.scale.y, 1.0 / 3.0, accuracy: 0.0001)
        let mediaCenterAfter = CGPoint(x: mapping.position.x + (200.0 - 200.0) * mapping.scale.x, y: mapping.position.y + (250.0 - 400.0) * mapping.scale.y)
        XCTAssertEqual(mediaCenterAfter.x, 60.0, accuracy: 0.0001)
        XCTAssertEqual(mediaCenterAfter.y, 70.0, accuracy: 0.0001)
    }
}
