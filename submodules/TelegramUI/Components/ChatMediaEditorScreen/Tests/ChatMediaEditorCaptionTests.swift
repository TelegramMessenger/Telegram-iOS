import Foundation
import UIKit
import XCTest
import TelegramCore
import MediaEditor
import ChatMediaSend
import ChatMediaEditorScreen

private final class FakeCaptionAdapter: ChatMediaEditorCaptionAdapter {
    private(set) var forcedCaption: NSAttributedString?
    private(set) var captions: [String: NSAttributedString] = [:]
    private(set) var thumbnailWrites: [(String, UIImage?)] = []
    var captionAbove = false
    var isHighQualityPhoto = false
    var externallyEdited = Set<String>()

    init(forcedCaption: NSAttributedString? = nil) {
        self.forcedCaption = forcedCaption
    }

    var isForced: Bool {
        return self.forcedCaption != nil
    }

    func caption(for uniqueId: String) -> NSAttributedString? {
        if let forcedCaption = self.forcedCaption {
            return forcedCaption
        }
        return self.captions[uniqueId]
    }

    func setCaption(_ caption: NSAttributedString?, for uniqueId: String) {
        if self.forcedCaption != nil {
            self.forcedCaption = caption ?? NSAttributedString()
            return
        }
        if let caption, caption.length > 0 {
            self.captions[uniqueId] = caption
        } else {
            self.captions[uniqueId] = nil
        }
    }

    func setEditedThumbnail(_ image: UIImage?, for uniqueId: String) {
        self.thumbnailWrites.append((uniqueId, image))
        self.externallyEdited.remove(uniqueId)
    }

    func hasExternalEdits(for uniqueId: String) -> Bool {
        return self.externallyEdited.contains(uniqueId)
    }
}

final class ChatMediaEditorCaptionTests: XCTestCase {
    private let peerId = EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(1))

    private func defaultValues() -> MediaEditorValues {
        return chatMediaEditorValues(peerId: self.peerId, originalDimensions: PixelDimensions(width: 1200, height: 800), qualityPreset: .compressedVeryHigh)
    }

    func testForcedCaptionSharedAcrossPages() {
        let adapter = FakeCaptionAdapter(forcedCaption: NSAttributedString())
        let model = ChatMediaEditorCaptionModel(adapter: adapter, currentId: "a")
        XCTAssertTrue(model.isForced)
        XCTAssertEqual(model.currentCaption.string, "")

        model.commit(NSAttributedString(string: "Shared"))
        XCTAssertEqual(adapter.forcedCaption?.string, "Shared")
        XCTAssertTrue(adapter.captions.isEmpty)

        XCTAssertEqual(model.switchItem(to: "b").string, "Shared")
        XCTAssertEqual(model.currentId, "b")
        model.commit(NSAttributedString(string: "Changed on b"))
        XCTAssertEqual(model.switchItem(to: "a").string, "Changed on b")

        model.commit(NSAttributedString())
        XCTAssertTrue(model.isForced)
        XCTAssertEqual(model.switchItem(to: "c").string, "")
    }

    func testPerItemCaptionRestoredOnSwitch() {
        let adapter = FakeCaptionAdapter()
        let model = ChatMediaEditorCaptionModel(adapter: adapter, currentId: "a")
        XCTAssertFalse(model.isForced)
        XCTAssertEqual(model.currentCaption.string, "")

        model.commit(NSAttributedString(string: "First"))
        XCTAssertEqual(model.switchItem(to: "b").string, "")
        model.commit(NSAttributedString(string: "Second"))
        XCTAssertEqual(model.switchItem(to: "a").string, "First")
        XCTAssertEqual(model.switchItem(to: "b").string, "Second")
        XCTAssertEqual(model.switchItem(to: "b").string, "Second")

        model.commit(NSAttributedString())
        XCTAssertNil(adapter.captions["b"])
        XCTAssertEqual(model.switchItem(to: "a").string, "First")
        XCTAssertEqual(model.switchItem(to: "b").string, "")
        XCTAssertFalse(model.isForced)
    }

    func testCaptionAboveGlobal() {
        let adapter = FakeCaptionAdapter()
        let model = ChatMediaEditorCaptionModel(adapter: adapter, currentId: "a")
        XCTAssertFalse(model.isCaptionAbove)
        model.isCaptionAbove = true
        XCTAssertTrue(adapter.captionAbove)
        let _ = model.switchItem(to: "b")
        XCTAssertTrue(model.isCaptionAbove)

        let other = ChatMediaEditorCaptionModel(adapter: adapter, currentId: "c")
        XCTAssertTrue(other.isCaptionAbove)
        other.isCaptionAbove = false
        XCTAssertFalse(model.isCaptionAbove)

        XCTAssertEqual(chatMediaEditorKeyboardPagerOffset(keyboardHeight: 0.0), 0.0)
        XCTAssertEqual(chatMediaEditorKeyboardPagerOffset(keyboardHeight: 336.0), -168.0)
        XCTAssertEqual(chatMediaEditorCaptionSelectionRevealDelay, 0.25)
    }

    func testEditedThumbnailWrittenOnSave() {
        let adapter = FakeCaptionAdapter()
        guard let reporter = ChatMediaEditorEditedThumbnailReporter.make(isGallery: true, adapter: adapter) else {
            XCTFail()
            return
        }
        let items = ["a", "b"].map { ChatMediaEditorItem(uniqueId: $0, source: .image(UIImage())) }
        let store = ChatMediaEditorItemStore()
        let pageModel = ChatMediaEditorPageModel(itemsSource: ChatMediaEditorListSource(items: items), store: store, initialIndex: 0)

        let defaults = self.defaultValues()
        let edited = defaults.withUpdatedCrop(rect: CGRect(x: 100.0, y: 0.0, width: 800.0, height: 800.0), rotation: 0.0, orientation: nil, mirroring: false, perspective: .zero)

        reporter.itemSaved("a", previousValues: store.entry(for: "a")?.values, values: defaults)
        pageModel.save(values: defaults, lockedAspectRatio: nil)
        XCTAssertTrue(adapter.thumbnailWrites.isEmpty)

        let previous = store.entry(for: "a")?.values
        pageModel.save(values: edited, lockedAspectRatio: nil)
        reporter.itemSaved("a", previousValues: previous, values: edited)
        XCTAssertTrue(adapter.thumbnailWrites.isEmpty)

        let composed = UIImage()
        let grid = UIImage()
        XCTAssertFalse(reporter.thumbnailStored(composed, gridThumbnail: grid, for: "a", store: store))
        XCTAssertTrue(pageModel.storeThumbnail(composed, uniqueId: "a", values: edited))
        XCTAssertTrue(reporter.thumbnailStored(composed, gridThumbnail: grid, for: "a", store: store))
        XCTAssertEqual(adapter.thumbnailWrites.count, 1)
        XCTAssertEqual(adapter.thumbnailWrites.last?.0, "a")
        XCTAssertTrue(adapter.thumbnailWrites.last?.1 === grid)
        XCTAssertTrue(store.entry(for: "a")?.thumbnail === composed)

        let stale = defaults.withUpdatedCrop(rect: CGRect(x: 0.0, y: 0.0, width: 600.0, height: 800.0), rotation: 0.0, orientation: nil, mirroring: false, perspective: .zero)
        XCTAssertFalse(pageModel.storeThumbnail(UIImage(), uniqueId: "a", values: stale))
        XCTAssertEqual(adapter.thumbnailWrites.count, 1)

        let beforeReset = store.entry(for: "a")?.values
        pageModel.save(values: defaults, lockedAspectRatio: nil)
        reporter.itemSaved("a", previousValues: beforeReset, values: defaults)
        XCTAssertEqual(adapter.thumbnailWrites.count, 2)
        XCTAssertEqual(adapter.thumbnailWrites.last?.0, "a")
        XCTAssertNil(adapter.thumbnailWrites.last?.1)
        XCTAssertNil(store.entry(for: "a")?.thumbnail)

        XCTAssertFalse(reporter.thumbnailStored(composed, gridThumbnail: grid, for: "a", store: store))
        XCTAssertEqual(adapter.thumbnailWrites.count, 2)

        reporter.itemSaved("a", previousValues: store.entry(for: "a")?.values, values: defaults)
        XCTAssertEqual(adapter.thumbnailWrites.count, 2)
    }

    func testEditedThumbnailsReportedWithoutCaptionPanel() {
        let adapter = FakeCaptionAdapter()
        XCTAssertNil(ChatMediaEditorEditedThumbnailReporter.make(isGallery: false, adapter: adapter))
        XCTAssertNil(ChatMediaEditorEditedThumbnailReporter.make(isGallery: true, adapter: nil))
        guard let reporter = ChatMediaEditorEditedThumbnailReporter.make(isGallery: true, adapter: adapter) else {
            XCTFail()
            return
        }
        let store = ChatMediaEditorItemStore()
        let defaults = self.defaultValues()
        let edited = defaults.withUpdatedCrop(rect: CGRect(x: 100.0, y: 0.0, width: 800.0, height: 800.0), rotation: 0.0, orientation: nil, mirroring: false, perspective: .zero)
        let composed = UIImage()
        store.update("a") { entry in
            entry.values = edited
            entry.thumbnail = composed
        }
        XCTAssertTrue(reporter.thumbnailStored(composed, gridThumbnail: composed, for: "a", store: store))
        reporter.itemSaved("a", previousValues: edited, values: defaults)
        XCTAssertEqual(adapter.thumbnailWrites.count, 2)
        XCTAssertNotNil(adapter.thumbnailWrites[0].1)
        XCTAssertNil(adapter.thumbnailWrites[1].1)
    }

    func testUneditedSaveClearsExternalEdits() {
        let adapter = FakeCaptionAdapter()
        adapter.externallyEdited = ["legacy"]
        let reporter = ChatMediaEditorEditedThumbnailReporter(adapter: adapter)
        let defaults = self.defaultValues()
        reporter.itemSaved("plain", previousValues: nil, values: defaults)
        XCTAssertTrue(adapter.thumbnailWrites.isEmpty)
        reporter.itemSaved("legacy", previousValues: nil, values: defaults)
        XCTAssertEqual(adapter.thumbnailWrites.count, 1)
        XCTAssertEqual(adapter.thumbnailWrites.first?.0, "legacy")
        XCTAssertNil(adapter.thumbnailWrites.first?.1 ?? nil)
        reporter.itemSaved("legacy", previousValues: defaults, values: defaults)
        XCTAssertEqual(adapter.thumbnailWrites.count, 1)
    }

    func testGridThumbnailCappedAtMaxPixelSide() {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let large = UIGraphicsImageRenderer(size: CGSize(width: 1912.0, height: 1468.0), format: format).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0.0, y: 0.0, width: 1912.0, height: 1468.0))
        }
        let grid = chatMediaEditorGridThumbnail(large)
        XCTAssertEqual(chatMediaEditorGridThumbnailMaxPixelSide, 512.0)
        XCTAssertEqual(grid.size.width * grid.scale, 512.0)
        XCTAssertEqual(grid.size.height * grid.scale, 393.0)

        let small = UIGraphicsImageRenderer(size: CGSize(width: 300.0, height: 200.0), format: format).image { _ in }
        XCTAssertTrue(chatMediaEditorGridThumbnail(small) === small)
    }

    func testCompactThumbnailKeepsSizeAndContent() {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let image = UIGraphicsImageRenderer(size: CGSize(width: 1280.0, height: 960.0), format: format).image { context in
            UIColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0).setFill()
            context.fill(CGRect(x: 0.0, y: 0.0, width: 640.0, height: 960.0))
            UIColor(red: 0.0, green: 0.0, blue: 1.0, alpha: 1.0).setFill()
            context.fill(CGRect(x: 640.0, y: 0.0, width: 640.0, height: 960.0))
        }
        let compact = chatMediaEditorCompactThumbnail(image)
        XCTAssertFalse(compact === image)
        XCTAssertEqual(compact.size, image.size)
        XCTAssertEqual(compact.scale, image.scale)
        guard let cgImage = compact.cgImage else {
            XCTFail("no cgImage")
            return
        }
        XCTAssertEqual(cgImage.width, 1280)
        XCTAssertEqual(cgImage.height, 960)

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 2.0, height: 1.0), format: format)
        let sampled = renderer.image { _ in
            compact.draw(in: CGRect(x: 0.0, y: 0.0, width: 2.0, height: 1.0))
        }
        guard let sampledImage = sampled.cgImage, let data = sampledImage.dataProvider?.data, let bytes = CFDataGetBytePtr(data) else {
            XCTFail("no sample")
            return
        }
        let bytesPerPixel = sampledImage.bitsPerPixel / 8
        let isBGRA = sampledImage.bitmapInfo.contains(.byteOrder32Little)
        let left = isBGRA ? (bytes[2], bytes[0]) : (bytes[0], bytes[2])
        let right = isBGRA ? (bytes[bytesPerPixel + 2], bytes[bytesPerPixel]) : (bytes[bytesPerPixel], bytes[bytesPerPixel + 2])
        XCTAssertGreaterThan(left.0, 200)
        XCTAssertLessThan(left.1, 60)
        XCTAssertLessThan(right.0, 60)
        XCTAssertGreaterThan(right.1, 200)
    }

    func testHdToggleIsGlobal() {
        let adapter = FakeCaptionAdapter()
        let model = ChatMediaEditorCaptionModel(adapter: adapter, currentId: "a")
        XCTAssertFalse(model.isHighQualityPhoto)
        XCTAssertTrue(model.toggleHighQualityPhoto())
        XCTAssertTrue(adapter.isHighQualityPhoto)
        let _ = model.switchItem(to: "b")
        XCTAssertTrue(model.isHighQualityPhoto)
        XCTAssertFalse(model.toggleHighQualityPhoto())
        let _ = model.switchItem(to: "a")
        XCTAssertFalse(model.isHighQualityPhoto)
        XCTAssertFalse(adapter.isHighQualityPhoto)
    }
}
