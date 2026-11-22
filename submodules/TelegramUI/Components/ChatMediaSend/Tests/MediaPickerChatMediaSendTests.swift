import Foundation
import UIKit
import XCTest
import TelegramCore
import MediaEditor
import ChatMediaSend

private final class TestSelection: MediaPickerChatMediaSendSelection {
    let selectedUniqueIds: [String]
    let grouping: Bool

    init(_ ids: [String], grouping: Bool = true) {
        self.selectedUniqueIds = ids
        self.grouping = grouping
    }
}

private final class TestEditing: MediaPickerChatMediaSendEditing {
    var forcedCaption: NSAttributedString?
    var isHighQualityPhoto = false
    var captions: [String: NSAttributedString] = [:]
    var timers: [String: Int32] = [:]
    var spoilers: Set<String> = []
    var prices: [String: Int64] = [:]
    var covers: [String: UIImage] = [:]
    var legacyAdjusted: Set<String> = []

    func caption(for uniqueId: String) -> NSAttributedString? {
        return self.forcedCaption ?? self.captions[uniqueId]
    }

    func timer(for uniqueId: String) -> Int32? {
        return self.timers[uniqueId]
    }

    func spoiler(for uniqueId: String) -> Bool {
        return self.spoilers.contains(uniqueId)
    }

    func price(for uniqueId: String) -> Int64? {
        return self.prices[uniqueId]
    }

    func coverImage(for uniqueId: String) -> UIImage? {
        return self.covers[uniqueId]
    }

    func hasLegacyAdjustments(for uniqueId: String) -> Bool {
        return self.legacyAdjusted.contains(uniqueId)
    }
}

final class MediaPickerChatMediaSendTests: XCTestCase {
    private let peerId = EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(1))
    private let dimensions = PixelDimensions(width: 4032, height: 3024)

    private func plainValues() -> MediaEditorValues {
        return chatMediaEditorValues(peerId: self.peerId, originalDimensions: self.dimensions, qualityPreset: .compressedVeryHigh)
    }

    private func croppedValues() -> MediaEditorValues {
        return self.plainValues().withUpdatedCrop(rect: CGRect(x: 10.0, y: 10.0, width: 2000.0, height: 2000.0), rotation: 0.0, orientation: nil, mirroring: false, perspective: .zero)
    }

    private func stickerFile(_ id: Int64, mimeType: String) -> TelegramMediaFile {
        return TelegramMediaFile(fileId: EngineMedia.Id(namespace: Namespaces.Media.CloudFile, id: id), partialReference: nil, resource: LocalFileMediaResource(fileId: id), previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: mimeType, size: nil, attributes: [.FileName(fileName: "sticker.tgs")], alternativeRepresentations: [])
    }

    private func valuesWithSticker(animated: Bool) -> MediaEditorValues {
        let file = self.stickerFile(7, mimeType: animated ? "application/x-tgsticker" : "image/webp")
        let entity = DrawingStickerEntity(content: .file(.standalone(media: file), .sticker))
        return self.plainValues().withUpdatedEntities([.sticker(entity)])
    }

    private func sources(_ map: [String: MediaPickerChatMediaSendSource]) -> (String) -> MediaPickerChatMediaSendSource? {
        return { map[$0] }
    }

    private func photo(_ id: String, thumbnail: UIImage? = nil) -> MediaPickerChatMediaSendSource {
        return .photo(identifier: id, pixelSize: CGSize(width: 4032.0, height: 3024.0), thumbnail: thumbnail)
    }

    func testItemsFromSelectionUseForcedCaption() {
        let selection = TestSelection(["a", "b", "c"], grouping: true)
        let editing = TestEditing()
        editing.forcedCaption = NSAttributedString(string: "forced")
        editing.captions = ["b": NSAttributedString(string: "own")]
        let store = ChatMediaEditorItemStore()

        let items = mediaPickerChatMediaSendItems(selection: selection, editing: editing, store: store, assetFor: self.sources(["a": self.photo("a"), "b": self.photo("b"), "c": self.photo("c")]), fileNameFor: { _ in nil })
        XCTAssertEqual(items.map(\.uniqueId), ["a", "b", "c"])

        let global = mediaPickerChatMediaSendGlobalOptions(selection: selection, editing: editing)
        XCTAssertEqual(global.forcedCaption?.string, "forced")
        XCTAssertTrue(global.grouping)

        var key: Int64 = 0
        let plan = chatMediaSendPlan(items: items.map(\.options), global: global, makeGroupingKey: {
            key += 1
            return key
        })
        XCTAssertEqual(plan.map { $0.caption?.string }, ["forced", nil, nil])
        XCTAssertEqual(Set(plan.map(\.groupingKey)).count, 1)
    }

    func testNoForcedCaptionOutsideForcedMode() {
        let selection = TestSelection(["a", "b"], grouping: false)
        let editing = TestEditing()
        editing.captions = ["a": NSAttributedString(string: "one"), "b": NSAttributedString(string: "two")]
        let items = mediaPickerChatMediaSendItems(selection: selection, editing: editing, store: ChatMediaEditorItemStore(), assetFor: self.sources(["a": self.photo("a"), "b": self.photo("b")]), fileNameFor: { _ in nil })
        let global = mediaPickerChatMediaSendGlobalOptions(selection: selection, editing: editing)
        XCTAssertNil(global.forcedCaption)
        XCTAssertEqual(items.map { $0.options.caption?.string }, ["one", "two"])
    }

    func testMutedVideoItemCarriesMuteAndValues() {
        let store = ChatMediaEditorItemStore()
        store.update("v") { $0.values = self.plainValues().withUpdatedVideoIsMuted(true) }
        store.update("w") { $0.values = self.plainValues() }
        let video: (String) -> MediaPickerChatMediaSendSource = { .video(identifier: $0, pixelSize: CGSize(width: 1920.0, height: 1080.0), duration: 5.0, thumbnail: nil) }
        let items = mediaPickerChatMediaSendItems(selection: TestSelection(["v", "w"]), editing: TestEditing(), store: store, assetFor: self.sources(["v": video("v"), "w": video("w")]), fileNameFor: { _ in nil })
        XCTAssertTrue(items[0].options.isMuted)
        XCTAssertNotNil(items[0].values)
        XCTAssertFalse(items[1].options.isMuted)
        XCTAssertNil(items[1].values)
    }

    func testGifSourceSendsThroughNewPath() {
        let store = ChatMediaEditorItemStore()
        let gifDimensions = PixelDimensions(width: 480, height: 272)
        store.update("g2") { $0.values = chatMediaEditorValues(peerId: self.peerId, originalDimensions: gifDimensions, qualityPreset: .animation).withUpdatedVideoTrimRange(0.5 ..< 1.5) }
        let thumbnail = UIImage()
        let gif: (String) -> MediaPickerChatMediaSendSource = { .gif(identifier: $0, pixelSize: CGSize(width: 480.0, height: 270.0), thumbnail: thumbnail) }
        let sources = self.sources(["a": self.photo("a"), "g1": gif("g1"), "g2": gif("g2")])
        let editing = TestEditing()
        editing.timers = ["g1": 10]
        editing.spoilers = ["g1"]
        XCTAssertNil(mediaPickerChatMediaSendFallback(selection: TestSelection(["a", "g1", "g2"]), editing: editing, store: store, assetFor: sources))

        let items = mediaPickerChatMediaSendItems(selection: TestSelection(["a", "g1", "g2"]), editing: editing, store: store, assetFor: sources, fileNameFor: { _ in "anim.gif" })
        XCTAssertEqual(items.map { $0.uniqueId }, ["a", "g1", "g2"])
        guard case let .gifAsset(identifier, pixelSize) = items[1].source else {
            XCTFail()
            return
        }
        XCTAssertEqual(identifier, "g1")
        XCTAssertEqual(pixelSize, CGSize(width: 480.0, height: 270.0))
        XCTAssertTrue(items[1].options.excludedFromGrouping)
        XCTAssertFalse(items[1].options.isAnimation)
        XCTAssertFalse(items[1].options.isMuted)
        XCTAssertEqual(items[1].options.timer, 10)
        XCTAssertTrue(items[1].options.spoiler)
        XCTAssertNil(items[1].values)
        XCTAssertNil(items[1].fileName)
        XCTAssertTrue(items[1].thumbnail === thumbnail)
        XCTAssertFalse(items[0].options.excludedFromGrouping)
        XCTAssertEqual(items[2].values?.videoTrimRange, 0.5 ..< 1.5)
    }

    func testItemsUseNilTimerWhenZero() {
        let editing = TestEditing()
        editing.timers = ["a": 0, "b": 10]
        let items = mediaPickerChatMediaSendItems(selection: TestSelection(["a", "b", "c"]), editing: editing, store: ChatMediaEditorItemStore(), assetFor: self.sources(["a": self.photo("a"), "b": self.photo("b"), "c": self.photo("c")]), fileNameFor: { _ in nil })
        XCTAssertNil(items[0].options.timer)
        XCTAssertEqual(items[1].options.timer, 10)
        XCTAssertNil(items[2].options.timer)
    }

    func testItemsFillFileNameAndPixelSize() {
        let editing = TestEditing()
        let cover = UIImage()
        editing.covers = ["v": cover]
        editing.spoilers = ["v"]
        editing.prices = ["v": 50]
        let source = MediaPickerChatMediaSendSource.video(identifier: "v-local", pixelSize: CGSize(width: 1920.0, height: 1080.0), duration: 12.5, thumbnail: nil)
        let items = mediaPickerChatMediaSendItems(selection: TestSelection(["v", "p"]), editing: editing, store: ChatMediaEditorItemStore(), assetFor: self.sources(["v": source, "p": self.photo("p")]), fileNameFor: { $0 == "v" ? "IMG_0001.MOV" : nil })

        XCTAssertEqual(items[0].fileName, "IMG_0001.MOV")
        guard case let .libraryAsset(identifier, pixelSize, isVideo, duration) = items[0].source else {
            return XCTFail()
        }
        XCTAssertEqual(identifier, "v-local")
        XCTAssertEqual(pixelSize, CGSize(width: 1920.0, height: 1080.0))
        XCTAssertTrue(isVideo)
        XCTAssertEqual(duration, 12.5)
        XCTAssertTrue(items[0].coverImage === cover)
        XCTAssertTrue(items[0].options.spoiler)
        XCTAssertEqual(items[0].options.price, 50)
        XCTAssertNil(items[0].renderedImage)

        guard case let .libraryAsset(_, photoSize, photoIsVideo, _) = items[1].source else {
            return XCTFail()
        }
        XCTAssertEqual(photoSize, CGSize(width: 4032.0, height: 3024.0))
        XCTAssertFalse(photoIsVideo)
        XCTAssertNil(items[1].fileName)
    }

    func testValuesOnlyForEditedItems() {
        let store = ChatMediaEditorItemStore()
        let cropped = self.croppedValues()
        store.update("plain") { $0.values = self.plainValues() }
        store.update("edited") { $0.values = cropped }
        store.update("sticker") { $0.values = self.valuesWithSticker(animated: false) }
        let items = mediaPickerChatMediaSendItems(selection: TestSelection(["plain", "edited", "none", "sticker"]), editing: TestEditing(), store: store, assetFor: self.sources(["plain": self.photo("plain"), "edited": self.photo("edited"), "none": self.photo("none"), "sticker": self.photo("sticker")]), fileNameFor: { _ in nil })

        XCTAssertNil(items[0].values)
        XCTAssertEqual(items[1].values, cropped)
        XCTAssertNil(items[2].values)
        XCTAssertNotNil(items[3].values)
        XCTAssertEqual(items[3].stickers.map { $0.fileId.id }, [7])
        XCTAssertTrue(items[0].stickers.isEmpty)
        XCTAssertTrue(items.allSatisfy { $0.renderedImage == nil })
        XCTAssertFalse(items[3].options.hasAnimatedPainting)
    }

    func testAnimatedStickerPhotoNoLongerFallsBack() {
        let store = ChatMediaEditorItemStore()
        store.update("photo") { $0.values = self.valuesWithSticker(animated: true) }
        store.update("video") { $0.values = self.valuesWithSticker(animated: true) }
        let videoSource = MediaPickerChatMediaSendSource.video(identifier: "video", pixelSize: CGSize(width: 1920.0, height: 1080.0), duration: 3.0, thumbnail: nil)

        XCTAssertNil(mediaPickerChatMediaSendFallback(selection: TestSelection(["video", "photo"]), editing: TestEditing(), store: store, assetFor: self.sources(["photo": self.photo("photo"), "video": videoSource])))

        XCTAssertNil(mediaPickerChatMediaSendFallback(selection: TestSelection(["video"]), editing: TestEditing(), store: store, assetFor: self.sources(["video": videoSource])))
        let items = mediaPickerChatMediaSendItems(selection: TestSelection(["video"]), editing: TestEditing(), store: store, assetFor: self.sources(["video": videoSource]), fileNameFor: { _ in nil })
        XCTAssertTrue(items[0].options.hasAnimatedPainting)

        store.update("still") { $0.values = self.valuesWithSticker(animated: false) }
        XCTAssertNil(mediaPickerChatMediaSendFallback(selection: TestSelection(["still"]), editing: TestEditing(), store: store, assetFor: self.sources(["still": self.photo("still")])))
    }

    func testUnsupportedItemsFallBackToLegacy() {
        let store = ChatMediaEditorItemStore()
        XCTAssertNil(mediaPickerChatMediaSendFallback(selection: TestSelection(["a", "captured"]), editing: TestEditing(), store: store, assetFor: self.sources(["a": self.photo("a"), "captured": .unsupported(.capturedVideo)])))
        XCTAssertEqual(mediaPickerChatMediaSendFallback(selection: TestSelection(["captured"]), editing: TestEditing(), store: store, assetFor: self.sources(["captured": .unsupported(.capturedVideo)])), .capturedVideo)
        XCTAssertNil(mediaPickerChatMediaSendFallback(selection: TestSelection(["a", "missing"]), editing: TestEditing(), store: store, assetFor: self.sources(["a": self.photo("a")])))
        XCTAssertEqual(mediaPickerChatMediaSendFallback(selection: TestSelection(["missing"]), editing: TestEditing(), store: store, assetFor: self.sources([:])), .missingItem)
        XCTAssertEqual(mediaPickerChatMediaSendFallback(selection: TestSelection([]), editing: TestEditing(), store: store, assetFor: self.sources([:])), .emptySelection)

        let editing = TestEditing()
        editing.legacyAdjusted = ["a"]
        XCTAssertEqual(mediaPickerChatMediaSendFallback(selection: TestSelection(["a"]), editing: editing, store: store, assetFor: self.sources(["a": self.photo("a")])), .legacyAdjustments)
        store.update("a") { $0.values = self.plainValues() }
        XCTAssertNil(mediaPickerChatMediaSendFallback(selection: TestSelection(["a"]), editing: editing, store: store, assetFor: self.sources(["a": self.photo("a")])))
    }

    func testThumbnailFromStoreElseAsset() {
        let store = ChatMediaEditorItemStore()
        let assetThumbnail = UIImage()
        let editedThumbnail = UIImage()
        let staleThumbnail = UIImage()
        let pasted = UIImage()
        store.update("edited") { entry in
            entry.values = self.croppedValues()
            entry.thumbnail = editedThumbnail
        }
        store.update("unedited") { entry in
            entry.values = self.plainValues()
            entry.thumbnail = staleThumbnail
        }
        let items = mediaPickerChatMediaSendItems(selection: TestSelection(["edited", "unedited", "plain", "pasted"]), editing: TestEditing(), store: store, assetFor: self.sources(["edited": self.photo("edited", thumbnail: assetThumbnail), "unedited": self.photo("unedited", thumbnail: assetThumbnail), "plain": self.photo("plain", thumbnail: assetThumbnail), "pasted": .image(pasted)]), fileNameFor: { _ in nil })

        XCTAssertTrue(items[0].thumbnail === editedThumbnail)
        XCTAssertTrue(items[1].thumbnail === assetThumbnail)
        XCTAssertTrue(items[2].thumbnail === assetThumbnail)
        XCTAssertTrue(items[3].thumbnail === pasted)
        guard case let .image(image) = items[3].source else {
            return XCTFail()
        }
        XCTAssertTrue(image === pasted)
    }

    func testGlobalOptionsCarryHighQuality() {
        let editing = TestEditing()
        editing.isHighQualityPhoto = true
        let global = mediaPickerChatMediaSendGlobalOptions(selection: TestSelection(["a"], grouping: false), editing: editing)
        XCTAssertTrue(global.forceHd)
        XCTAssertFalse(global.grouping)
    }

    func testQualityOnlyEditSendsValues() {
        let store = ChatMediaEditorItemStore()
        let values = self.plainValues().withUpdatedQualityPreset(.compressedHigh)
        store.noteQualityPresetBaseline(self.plainValues().qualityPreset, for: "a")
        store.update("a") { $0.values = values }
        XCTAssertEqual(mediaPickerChatMediaSendEditedValues(store: store, uniqueId: "a"), values)
        store.update("a") { $0.values = self.plainValues() }
        XCTAssertNil(mediaPickerChatMediaSendEditedValues(store: store, uniqueId: "a"))
    }
}
