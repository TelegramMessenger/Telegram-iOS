import Foundation
import UIKit
import XCTest
import SwiftSignalKit
import TelegramCore
import LegacyMediaPickerUI
import LocalMediaResources
@testable import MediaEditor
@testable import ChatMediaSend

private let legacySplitTestPeerId = EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(1))

private let legacySplitTestTempBoxInitialized: Void = {
    EngineTempBox.initializeShared(basePath: NSTemporaryDirectory() + "chat-media-send-legacy-split-tests", processType: "tests", launchSpecificId: 1)
}()

private func legacySplitTestImage(_ width: Int, _ height: Int) -> UIImage {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1.0
    return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { context in
        UIColor.green.setFill()
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    }
}

private final class LegacySplitTestSelection: MediaPickerChatMediaSendSelection {
    let selectedUniqueIds: [String]
    let grouping: Bool

    init(_ ids: [String], grouping: Bool = true) {
        self.selectedUniqueIds = ids
        self.grouping = grouping
    }
}

private final class LegacySplitTestEditing: MediaPickerChatMediaSendEditing {
    var forcedCaption: NSAttributedString?
    var isHighQualityPhoto = false
    var captions: [String: NSAttributedString] = [:]
    var timers: [String: Int32] = [:]
    var spoilers: Set<String> = []
    var legacyAdjusted: Set<String> = []

    func caption(for uniqueId: String) -> NSAttributedString? {
        return self.captions[uniqueId]
    }

    func timer(for uniqueId: String) -> Int32? {
        return self.timers[uniqueId]
    }

    func spoiler(for uniqueId: String) -> Bool {
        return self.spoilers.contains(uniqueId)
    }

    func price(for uniqueId: String) -> Int64? {
        return nil
    }

    func coverImage(for uniqueId: String) -> UIImage? {
        return nil
    }

    func hasLegacyAdjustments(for uniqueId: String) -> Bool {
        return self.legacyAdjusted.contains(uniqueId)
    }
}

private final class LegacySplitTestRenderer: ChatMediaSendRendering {
    private let lock = NSLock()
    private var _renders: [(String, Bool)] = []

    var renders: [(String, Bool)] {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        return self._renders
    }

    func renderPhoto(item: ChatMediaSendItem, forceHd: Bool) -> Signal<ChatMediaSendRenderEvent, NoError> {
        self.lock.lock()
        self._renders.append((item.uniqueId, forceHd))
        self.lock.unlock()
        return .single(.result(legacySplitTestImage(400, 300)))
    }
}

private final class LegacySplitTestGifConverter: ChatMediaSendGifConverting {
    private let lock = NSLock()
    private var active = 0
    private(set) var maxActive = 0
    private(set) var started = 0

    func convertGif(identifier: String) -> Signal<ChatMediaSendConvertedGif?, NoError> {
        return Signal { [self] subscriber in
            self.lock.lock()
            self.active += 1
            self.started += 1
            self.maxActive = max(self.maxActive, self.active)
            self.lock.unlock()
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) {
                self.lock.lock()
                self.active -= 1
                self.lock.unlock()
                subscriber.putNext(nil)
                subscriber.putCompletion()
            }
            return EmptyDisposable
        }
    }
}

final class ChatMediaSendLegacySplitTests: XCTestCase {
    private let photoSize = CGSize(width: 4032.0, height: 3024.0)

    override func setUp() {
        super.setUp()
        let _ = legacySplitTestTempBoxInitialized
    }

    private func plainValues() -> MediaEditorValues {
        return chatMediaEditorValues(peerId: legacySplitTestPeerId, originalDimensions: PixelDimensions(self.photoSize), qualityPreset: .compressedVeryHigh)
    }

    private func croppedValues() -> MediaEditorValues {
        return self.plainValues().withUpdatedCrop(rect: CGRect(x: 10.0, y: 10.0, width: 2000.0, height: 2000.0), rotation: 0.0, orientation: nil, mirroring: false, perspective: .zero)
    }

    private func stickerFile(_ id: Int64, animated: Bool) -> TelegramMediaFile {
        return TelegramMediaFile(fileId: EngineMedia.Id(namespace: Namespaces.Media.CloudFile, id: id), partialReference: nil, resource: LocalFileMediaResource(fileId: id), previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: animated ? "application/x-tgsticker" : "image/webp", size: nil, attributes: [.FileName(fileName: "sticker.tgs")], alternativeRepresentations: [])
    }

    private func photo(_ id: String) -> MediaPickerChatMediaSendSource {
        return .photo(identifier: id, pixelSize: self.photoSize, thumbnail: nil)
    }

    private func legacyVideoFile(animated: Bool = false) -> TelegramMediaFile {
        var attributes: [TelegramMediaFileAttribute] = [.Video(duration: 3.0, size: PixelDimensions(width: 640, height: 360), flags: [.supportsStreaming], preloadSize: nil, coverTime: nil, videoCodec: nil)]
        if animated {
            attributes.append(.Animated)
        }
        return TelegramMediaFile(fileId: EngineMedia.Id(namespace: Namespaces.Media.LocalFile, id: 42), partialReference: nil, resource: LocalFileMediaResource(fileId: 42), previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "video/mp4", size: nil, attributes: attributes, alternativeRepresentations: [])
    }

    private func legacyMessage(media: EngineRawMedia, attributes: [EngineMessage.Attribute] = [], text: String = "") -> LegacyAssetPickerEnqueueMessage {
        return LegacyAssetPickerEnqueueMessage(message: .message(text: text, attributes: attributes, inlineStickers: [:], mediaReference: .standalone(media: media), threadId: nil, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: 99, correlationId: nil, bubbleUpEmojiOrStickersets: []), uniqueId: "x", isFile: false)
    }

    func testNoFallbackForGifLiveAnimated() {
        let store = ChatMediaEditorItemStore()
        let animatedEntity = DrawingStickerEntity(content: .file(.standalone(media: self.stickerFile(7, animated: true)), .sticker))
        store.update("animated") { $0.values = self.plainValues().withUpdatedEntities([.sticker(animatedEntity)]) }
        let sources: [String: MediaPickerChatMediaSendSource] = [
            "photo": self.photo("photo"),
            "gif": .gif(identifier: "gif", pixelSize: CGSize(width: 480.0, height: 270.0), thumbnail: nil),
            "live": .livePhoto(identifier: "live", pixelSize: self.photoSize, mode: .live, thumbnail: nil),
            "loop": .livePhoto(identifier: "loop", pixelSize: self.photoSize, mode: .loop, thumbnail: nil),
            "animated": self.photo("animated")
        ]
        let ids = ["photo", "gif", "live", "loop", "animated"]
        let selection = LegacySplitTestSelection(ids)
        let editing = LegacySplitTestEditing()
        XCTAssertNil(mediaPickerChatMediaSendFallback(selection: selection, editing: editing, store: store, assetFor: { sources[$0] }))
        XCTAssertEqual(mediaPickerChatMediaSendLegacyOnlyIds(selection: selection, editing: editing, store: store, assetFor: { sources[$0] }), [])
        for id in ids {
            XCTAssertNil(mediaPickerChatMediaSendLegacyOnlyReason(uniqueId: id, source: sources[id], editing: editing, store: store))
        }
        let items = mediaPickerChatMediaSendItems(selection: selection, editing: editing, store: store, assetFor: { sources[$0] }, fileNameFor: { _ in nil })
        XCTAssertEqual(items.map { $0.uniqueId }, ids)
        for item in items {
            if case .prebuilt = item.source {
                XCTFail("\(item.uniqueId) must not be sent through legacy")
            }
        }
    }

    func testEditedItemsNeverSentThroughLegacyFallback() throws {
        let store = ChatMediaEditorItemStore()
        store.update("edited") { $0.values = self.croppedValues() }
        let videoValues = chatMediaEditorValues(peerId: legacySplitTestPeerId, originalDimensions: PixelDimensions(width: 1280, height: 720), qualityPreset: .compressedMedium).withUpdatedVideoTrimRange(0.5 ..< 2.0)
        store.update("captured-edited") { $0.values = videoValues }
        let editing = LegacySplitTestEditing()
        editing.legacyAdjusted = ["legacy", "edited"]
        editing.captions = ["legacy": NSAttributedString(string: "legacy caption"), "edited": NSAttributedString(string: "edited caption")]
        editing.spoilers = ["legacy"]
        let captured: (String) -> MediaPickerChatMediaSendSource = { id in
            return .capturedVideo(path: "/tmp/\(id).mp4", dimensions: PixelDimensions(width: 1280, height: 720), duration: 3.0)
        }
        let sources: [String: MediaPickerChatMediaSendSource] = [
            "edited": self.photo("edited"),
            "legacy": self.photo("legacy"),
            "captured-edited": captured("captured-edited"),
            "captured-plain": captured("captured-plain"),
            "unresolved": .unsupported(.capturedVideo),
            "plain": self.photo("plain")
        ]
        let ids = ["edited", "legacy", "captured-edited", "captured-plain", "missing", "unresolved", "plain"]
        let selection = LegacySplitTestSelection(ids)

        XCTAssertNil(mediaPickerChatMediaSendFallback(selection: selection, editing: editing, store: store, assetFor: { sources[$0] }))
        XCTAssertEqual(mediaPickerChatMediaSendLegacyOnlyIds(selection: selection, editing: editing, store: store, assetFor: { sources[$0] }), ["legacy", "captured-plain", "missing", "unresolved"])
        XCTAssertEqual(mediaPickerChatMediaSendLegacyOnlyReason(uniqueId: "legacy", source: sources["legacy"], editing: editing, store: store), .legacyAdjustments)
        XCTAssertEqual(mediaPickerChatMediaSendLegacyOnlyReason(uniqueId: "captured-plain", source: sources["captured-plain"], editing: editing, store: store), .capturedVideo)
        XCTAssertEqual(mediaPickerChatMediaSendLegacyOnlyReason(uniqueId: "missing", source: nil, editing: editing, store: store), .missingItem)

        XCTAssertEqual(mediaPickerChatMediaSendFallback(selection: LegacySplitTestSelection(["legacy", "captured-plain"]), editing: editing, store: store, assetFor: { sources[$0] }), .legacyAdjustments)
        XCTAssertEqual(mediaPickerChatMediaSendFallback(selection: LegacySplitTestSelection(["captured-plain"]), editing: editing, store: store, assetFor: { sources[$0] }), .capturedVideo)
        XCTAssertEqual(mediaPickerChatMediaSendFallback(selection: LegacySplitTestSelection([]), editing: editing, store: store, assetFor: { sources[$0] }), .emptySelection)

        let legacyImage = TelegramMediaImage(imageId: EngineMedia.Id(namespace: Namespaces.Media.LocalImage, id: 1), representations: [], immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
        let legacyVideo = self.legacyVideoFile()
        let legacyMedia: [String: ChatMediaSendLegacyMedia] = [
            "legacy": ChatMediaSendLegacyMedia(media: legacyImage, stickers: [], isAnimation: false),
            "captured-plain": ChatMediaSendLegacyMedia(media: legacyVideo, stickers: [], isAnimation: false)
        ]
        let items = mediaPickerChatMediaSendItems(selection: selection, editing: editing, store: store, assetFor: { sources[$0] }, fileNameFor: { _ in nil }, legacyMedia: legacyMedia)
        XCTAssertEqual(items.map { $0.uniqueId }, ids)
        XCTAssertEqual(items[0].values, self.croppedValues())
        guard case let .tempVideo(path, dimensions, duration) = items[2].source else {
            return XCTFail()
        }
        XCTAssertEqual(path, "/tmp/captured-edited.mp4")
        XCTAssertEqual(dimensions, PixelDimensions(width: 1280, height: 720))
        XCTAssertEqual(duration, 3.0)
        XCTAssertEqual(items[2].values?.videoTrimRange, 0.5 ..< 2.0)
        guard case let .prebuilt(prebuiltLegacy) = items[1].source, case let .prebuilt(prebuiltCaptured) = items[3].source, case let .prebuilt(prebuiltMissing) = items[4].source, case let .prebuilt(prebuiltUnresolved) = items[5].source else {
            return XCTFail()
        }
        XCTAssertTrue(prebuiltLegacy === legacyImage)
        XCTAssertTrue(prebuiltCaptured === legacyVideo)
        XCTAssertNil(prebuiltMissing)
        XCTAssertNil(prebuiltUnresolved)
        XCTAssertNil(items[1].values)
        XCTAssertEqual(items[1].options.caption?.string, "legacy caption")
        XCTAssertTrue(items[1].options.spoiler)

        let renderer = LegacySplitTestRenderer()
        let expectation = self.expectation(description: "outcome")
        var outcome: ChatMediaSendOutcome?
        let disposable = chatMediaSendMessages(items: items, global: ChatMediaSendGlobalOptions(grouping: true), renderer: renderer, makeGroupingKey: { 77 }, storeResourceData: { _, _ in }).start(next: { event in
            if case let .outcome(value) = event {
                outcome = value
                expectation.fulfill()
            }
        })
        self.wait(for: [expectation], timeout: 10.0)
        disposable.dispose()
        let result = try XCTUnwrap(outcome)

        XCTAssertEqual(renderer.renders.map { $0.0 }, ["edited"])
        XCTAssertEqual(result.droppedUniqueIds, ["missing", "unresolved"])
        XCTAssertEqual(result.messages.map { $0.uniqueId }, ["edited", "legacy", "captured-edited", "captured-plain", "plain"])
        var groupingKeys: [Int64?] = []
        var medias: [EngineRawMedia?] = []
        var texts: [String] = []
        for message in result.messages {
            guard case let .message(text, _, _, mediaReference, _, _, _, groupingKey, _, _) = message.message else {
                return XCTFail()
            }
            groupingKeys.append(groupingKey)
            medias.append(mediaReference?.media)
            texts.append(text)
        }
        XCTAssertEqual(groupingKeys, [77, 77, 77, 77, 77])
        XCTAssertEqual(texts, ["edited caption", "legacy caption", "", "", ""])
        XCTAssertTrue(medias[1] === legacyImage)
        XCTAssertTrue(medias[3] === legacyVideo)
        let editedImage = try XCTUnwrap(medias[0] as? TelegramMediaImage)
        XCTAssertFalse(editedImage === legacyImage)
        let capturedFile = try XCTUnwrap(medias[2] as? TelegramMediaFile)
        XCTAssertNotNil((capturedFile.resource as? LocalFileVideoMediaResource)?.adjustments)
    }

    func testFailedPrebuiltItemsExcludedFromPlan() throws {
        let failed = ChatMediaSendItem(uniqueId: "failed", source: .prebuilt(media: nil), options: ChatMediaSendItemOptions())
        let photos = (0 ..< 10).map { index in
            return ChatMediaSendItem(uniqueId: "p\(index)", source: .libraryAsset(identifier: "p\(index)", pixelSize: self.photoSize, isVideo: false, duration: 0.0), options: ChatMediaSendItemOptions())
        }
        var nextKey: Int64 = 0
        let expectation = self.expectation(description: "outcome")
        var outcome: ChatMediaSendOutcome?
        let disposable = chatMediaSendMessages(items: [failed] + photos, global: ChatMediaSendGlobalOptions(grouping: true, forcedCaption: NSAttributedString(string: "forced")), renderer: LegacySplitTestRenderer(), makeGroupingKey: {
            nextKey += 1
            return nextKey
        }, storeResourceData: { _, _ in }).start(next: { event in
            if case let .outcome(value) = event {
                outcome = value
                expectation.fulfill()
            }
        })
        self.wait(for: [expectation], timeout: 10.0)
        disposable.dispose()
        let result = try XCTUnwrap(outcome)
        XCTAssertEqual(result.droppedUniqueIds, ["failed"])
        XCTAssertEqual(result.messages.map { $0.uniqueId }, photos.map { $0.uniqueId })
        var texts: [String] = []
        var keys: [Int64?] = []
        for message in result.messages {
            guard case let .message(text, _, _, _, _, _, _, groupingKey, _, _) = message.message else {
                return XCTFail()
            }
            texts.append(text)
            keys.append(groupingKey)
        }
        XCTAssertEqual(texts.first, "forced")
        XCTAssertTrue(texts.dropFirst().allSatisfy { $0.isEmpty })
        XCTAssertEqual(Set(keys).count, 1)
        XCTAssertNotNil(keys[0])
    }

    func testAssetBackedPastedVideoSendsNativelyWhenEdited() {
        let store = ChatMediaEditorItemStore()
        let videoValues = chatMediaEditorValues(peerId: legacySplitTestPeerId, originalDimensions: PixelDimensions(width: 1920, height: 1080), qualityPreset: .compressedMedium).withUpdatedVideoTrimRange(0.0 ..< 1.0)
        store.update("edited") { $0.values = videoValues }
        store.update("edited-gif") { $0.values = videoValues }
        let sources: [String: MediaPickerChatMediaSendSource] = [
            "edited": .capturedLibraryVideo(identifier: "edited-local", pixelSize: CGSize(width: 1920.0, height: 1080.0), duration: 4.0, isGif: false),
            "edited-gif": .capturedLibraryVideo(identifier: "gif-local", pixelSize: CGSize(width: 480.0, height: 270.0), duration: 0.0, isGif: true),
            "plain": .capturedLibraryVideo(identifier: "plain-local", pixelSize: CGSize(width: 1920.0, height: 1080.0), duration: 4.0, isGif: false)
        ]
        let editing = LegacySplitTestEditing()
        XCTAssertNil(mediaPickerChatMediaSendLegacyOnlyReason(uniqueId: "edited", source: sources["edited"], editing: editing, store: store))
        XCTAssertNil(mediaPickerChatMediaSendLegacyOnlyReason(uniqueId: "edited-gif", source: sources["edited-gif"], editing: editing, store: store))
        XCTAssertEqual(mediaPickerChatMediaSendLegacyOnlyReason(uniqueId: "plain", source: sources["plain"], editing: editing, store: store), .capturedVideo)
        let items = mediaPickerChatMediaSendItems(selection: LegacySplitTestSelection(["edited", "edited-gif", "plain"]), editing: editing, store: store, assetFor: { sources[$0] }, fileNameFor: { _ in nil })
        guard case let .libraryAsset(identifier, _, isVideo, duration) = items[0].source else {
            return XCTFail()
        }
        XCTAssertEqual(identifier, "edited-local")
        XCTAssertTrue(isVideo)
        XCTAssertEqual(duration, 4.0)
        XCTAssertEqual(items[0].values?.videoTrimRange, 0.0 ..< 1.0)
        guard case let .gifAsset(gifIdentifier, _) = items[1].source else {
            return XCTFail()
        }
        XCTAssertEqual(gifIdentifier, "gif-local")
        XCTAssertTrue(items[1].options.excludedFromGrouping)
        guard case .prebuilt = items[2].source else {
            return XCTFail()
        }
    }

    func testLegacyMediaExtraction() throws {
        let sticker = self.stickerFile(5, animated: false)
        let image = TelegramMediaImage(imageId: EngineMedia.Id(namespace: Namespaces.Media.LocalImage, id: 3), representations: [], immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [.hasStickers])
        let extracted = try XCTUnwrap(chatMediaSendLegacyMedia(messages: [self.legacyMessage(media: image, attributes: [EmbeddedMediaStickersMessageAttribute(files: [sticker]), AutoremoveTimeoutMessageAttribute(timeout: 10, countdownBeginTime: nil)], text: "caption")]))
        XCTAssertTrue(extracted.media === image)
        XCTAssertEqual(extracted.stickers.map { $0.fileId }, [sticker.fileId])
        XCTAssertFalse(extracted.isAnimation)

        let animated = self.legacyVideoFile(animated: true)
        XCTAssertEqual(chatMediaSendLegacyMedia(messages: [self.legacyMessage(media: animated)])?.isAnimation, true)

        let paid = TelegramMediaPaidContent(amount: 10, extendedMedia: [.full(media: animated)])
        let paidExtracted = try XCTUnwrap(chatMediaSendLegacyMedia(messages: [self.legacyMessage(media: paid)]))
        XCTAssertTrue(paidExtracted.media === animated)

        XCTAssertNil(chatMediaSendLegacyMedia(messages: []))
    }

    func testLegacyAnimationDisablesGrouping() {
        let store = ChatMediaEditorItemStore()
        let editing = LegacySplitTestEditing()
        editing.legacyAdjusted = ["legacy"]
        let sources: [String: MediaPickerChatMediaSendSource] = ["a": self.photo("a"), "legacy": self.photo("legacy")]
        let items = mediaPickerChatMediaSendItems(selection: LegacySplitTestSelection(["a", "legacy"]), editing: editing, store: store, assetFor: { sources[$0] }, fileNameFor: { _ in nil }, legacyMedia: ["legacy": ChatMediaSendLegacyMedia(media: self.legacyVideoFile(animated: true), stickers: [], isAnimation: true)])
        XCTAssertTrue(items[1].options.isAnimation)
        XCTAssertEqual(chatMediaSendPlan(items: items.map { $0.options }, global: ChatMediaSendGlobalOptions(grouping: true), makeGroupingKey: { 5 }).map { $0.groupingKey }, [nil, nil])
    }

    func testGifConversionsAreBounded() {
        let converter = LegacySplitTestGifConverter()
        let items = (0 ..< 5).map { index in
            return ChatMediaSendItem(uniqueId: "g\(index)", source: .gifAsset(identifier: "g\(index)", pixelSize: CGSize(width: 100.0, height: 100.0)), options: ChatMediaSendItemOptions(excludedFromGrouping: true))
        }
        let expectation = self.expectation(description: "outcome")
        var outcome: ChatMediaSendOutcome?
        let disposable = chatMediaSendMessages(items: items, global: ChatMediaSendGlobalOptions(grouping: true), renderer: LegacySplitTestRenderer(), gifConverter: converter, makeGroupingKey: { 1 }, storeResourceData: { _, _ in }).start(next: { event in
            if case let .outcome(value) = event {
                outcome = value
                expectation.fulfill()
            }
        })
        self.wait(for: [expectation], timeout: 10.0)
        disposable.dispose()
        XCTAssertEqual(converter.started, 5)
        XCTAssertLessThanOrEqual(converter.maxActive, 2)
        XCTAssertEqual(outcome?.droppedUniqueIds.count, 5)
    }

    func testConvertedGifTempFileRemovedWhenMoveFails() throws {
        let source = NSTemporaryDirectory() + "chat-media-send-gif-move-\(UInt64.random(in: 0 ... UInt64.max)).mp4"
        try Data([1, 2, 3]).write(to: URL(fileURLWithPath: source))
        let destination = NSTemporaryDirectory() + "missing-dir-\(UInt64.random(in: 0 ... UInt64.max))/out.mp4"
        XCTAssertFalse(chatMediaSendMoveConvertedGif(from: source, to: destination))
        XCTAssertFalse(FileManager.default.fileExists(atPath: source))

        let source2 = NSTemporaryDirectory() + "chat-media-send-gif-move-\(UInt64.random(in: 0 ... UInt64.max)).mp4"
        try Data([4, 5]).write(to: URL(fileURLWithPath: source2))
        let destination2 = NSTemporaryDirectory() + "chat-media-send-gif-moved-\(UInt64.random(in: 0 ... UInt64.max)).mp4"
        XCTAssertTrue(chatMediaSendMoveConvertedGif(from: source2, to: destination2))
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination2))
        try? FileManager.default.removeItem(atPath: destination2)
    }

    func testUprightRedrawOfRightOrientedImage() throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let landscape = UIGraphicsImageRenderer(size: CGSize(width: 40.0, height: 20.0), format: format).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0.0, y: 0.0, width: 20.0, height: 20.0))
            UIColor.blue.setFill()
            context.fill(CGRect(x: 20.0, y: 0.0, width: 20.0, height: 20.0))
        }
        let cgImage = try XCTUnwrap(landscape.cgImage)
        let rotated = UIImage(cgImage: cgImage, scale: 1.0, orientation: .right)
        XCTAssertEqual(rotated.size, CGSize(width: 20.0, height: 40.0))

        let path = try XCTUnwrap(chatMediaSendAnimatedPhotoBaseImagePath(image: rotated))
        defer {
            try? FileManager.default.removeItem(atPath: path)
        }
        let loaded = try XCTUnwrap(UIImage(contentsOfFile: path))
        XCTAssertEqual(loaded.imageOrientation, .up)
        let loadedCGImage = try XCTUnwrap(loaded.cgImage)
        XCTAssertEqual(loadedCGImage.width, 20)
        XCTAssertEqual(loadedCGImage.height, 40)

        var pixels = [UInt8](repeating: 0, count: 20 * 40 * 4)
        let context = try XCTUnwrap(CGContext(data: &pixels, width: 20, height: 40, bitsPerComponent: 8, bytesPerRow: 20 * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(loadedCGImage, in: CGRect(x: 0.0, y: 0.0, width: 20.0, height: 40.0))
        func pixel(x: Int, yFromTop: Int) -> (Int, Int, Int) {
            let offset = (yFromTop * 20 + x) * 4
            return (Int(pixels[offset]), Int(pixels[offset + 1]), Int(pixels[offset + 2]))
        }
        let top = pixel(x: 10, yFromTop: 5)
        let bottom = pixel(x: 10, yFromTop: 35)
        XCTAssertGreaterThan(top.0, 200)
        XCTAssertLessThan(top.2, 60)
        XCTAssertGreaterThan(bottom.2, 200)
        XCTAssertLessThan(bottom.0, 60)
    }

    func testAnimatedStickerDurations() throws {
        let gifData = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(gifData, "com.compuserve.gif" as CFString, 2, nil))
        let frameProperties = [kCGImagePropertyGIFDictionary as String: [kCGImagePropertyGIFDelayTime as String: 0.5]] as CFDictionary
        for color in [UIColor.red, UIColor.blue] {
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1.0
            let frame = UIGraphicsImageRenderer(size: CGSize(width: 8.0, height: 8.0), format: format).image { context in
                color.setFill()
                context.fill(CGRect(x: 0.0, y: 0.0, width: 8.0, height: 8.0))
            }
            CGImageDestinationAddImage(destination, try XCTUnwrap(frame.cgImage), frameProperties)
        }
        XCTAssertTrue(CGImageDestinationFinalize(destination))

        let animatedFile = self.stickerFile(11, animated: true)
        let staticFile = self.stickerFile(12, animated: false)
        let entities: [CodableDrawingEntity] = [
            .sticker(DrawingStickerEntity(content: .file(.standalone(media: animatedFile), .sticker))),
            .sticker(DrawingStickerEntity(content: .file(.standalone(media: staticFile), .sticker))),
            .sticker(DrawingStickerEntity(content: .animatedImage(gifData as Data, legacySplitTestImage(8, 8))))
        ]
        var requested: [EngineMedia.Id] = []
        let expectation = self.expectation(description: "durations")
        var result: [Double]?
        let disposable = mediaEditorAnimatedStickerDurations(entities: entities, fileDuration: { file in
            requested.append(file.fileId)
            return .single(2.0)
        }).start(next: { value in
            result = value
            expectation.fulfill()
        })
        self.wait(for: [expectation], timeout: 5.0)
        disposable.dispose()
        XCTAssertEqual(requested, [animatedFile.fileId])
        let durations = try XCTUnwrap(result)
        XCTAssertEqual(durations.count, 2)
        XCTAssertEqual(durations[0], 2.0)
        XCTAssertEqual(durations[1], try XCTUnwrap(UIImage.animatedImageFromData(data: gifData as Data)).duration)
    }
}
