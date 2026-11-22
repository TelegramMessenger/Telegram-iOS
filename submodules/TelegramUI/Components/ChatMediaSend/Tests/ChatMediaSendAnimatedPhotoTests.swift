import Foundation
import UIKit
import XCTest
import SwiftSignalKit
import TelegramCore
import MediaEditor
import LocalMediaResources
import FetchVideoMediaResource
@testable import ChatMediaSend

private let animatedPhotoTestPeerId = EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(1))

private let animatedPhotoTestTempBoxInitialized: Void = {
    EngineTempBox.initializeShared(basePath: NSTemporaryDirectory() + "chat-media-send-animated-tests", processType: "tests", launchSpecificId: 1)
}()

private func animatedPhotoTestImage(_ width: Int, _ height: Int) -> UIImage {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1.0
    return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { context in
        UIColor.blue.setFill()
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    }
}

private final class AnimatedPhotoTestSelection: MediaPickerChatMediaSendSelection {
    let selectedUniqueIds: [String]
    let grouping: Bool

    init(_ ids: [String], grouping: Bool = true) {
        self.selectedUniqueIds = ids
        self.grouping = grouping
    }
}

private final class AnimatedPhotoTestEditing: MediaPickerChatMediaSendEditing {
    var forcedCaption: NSAttributedString?
    var isHighQualityPhoto = true

    func caption(for uniqueId: String) -> NSAttributedString? {
        return nil
    }

    func timer(for uniqueId: String) -> Int32? {
        return nil
    }

    func spoiler(for uniqueId: String) -> Bool {
        return false
    }

    func price(for uniqueId: String) -> Int64? {
        return nil
    }

    func coverImage(for uniqueId: String) -> UIImage? {
        return nil
    }

    func hasLegacyAdjustments(for uniqueId: String) -> Bool {
        return false
    }
}

private final class AnimatedPhotoTestRenderer: ChatMediaSendRendering {
    private let lock = NSLock()
    private let exports: [String: ChatMediaSendPreparedAnimatedPhoto]
    private(set) var renderedIds: [String] = []
    private(set) var exportedIds: [String] = []

    init(exports: [String: ChatMediaSendPreparedAnimatedPhoto]) {
        self.exports = exports
    }

    func renderPhoto(item: ChatMediaSendItem, forceHd: Bool) -> Signal<ChatMediaSendRenderEvent, NoError> {
        self.lock.lock()
        self.renderedIds.append(item.uniqueId)
        self.lock.unlock()
        return .single(.result(animatedPhotoTestImage(400, 300)))
    }

    func exportAnimatedPhoto(item: ChatMediaSendItem) -> Signal<ChatMediaSendPreparedAnimatedPhoto?, NoError> {
        let result = self.exports[item.uniqueId]
        return Signal { [self] subscriber in
            self.lock.lock()
            self.exportedIds.append(item.uniqueId)
            self.lock.unlock()
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) {
                subscriber.putNext(result)
                subscriber.putCompletion()
            }
            return EmptyDisposable
        }
    }
}

final class ChatMediaSendAnimatedPhotoTests: XCTestCase {
    private let photoSize = CGSize(width: 4032.0, height: 3024.0)
    private var writtenPaths: [String] = []

    override func setUp() {
        super.setUp()
        let _ = animatedPhotoTestTempBoxInitialized
    }

    override func tearDown() {
        for path in self.writtenPaths {
            try? FileManager.default.removeItem(atPath: path)
        }
        self.writtenPaths = []
        super.tearDown()
    }

    private func stickerFile(_ id: Int64, animated: Bool) -> TelegramMediaFile {
        return TelegramMediaFile(fileId: EngineMedia.Id(namespace: Namespaces.Media.CloudFile, id: id), partialReference: nil, resource: LocalFileMediaResource(fileId: id), previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: animated ? "application/x-tgsticker" : "image/webp", size: nil, attributes: [.FileName(fileName: "sticker.tgs")], alternativeRepresentations: [])
    }

    private func plainValues() -> MediaEditorValues {
        return chatMediaEditorValues(peerId: animatedPhotoTestPeerId, originalDimensions: PixelDimensions(self.photoSize), qualityPreset: .compressedVeryHigh)
    }

    private func animatedValues() -> MediaEditorValues {
        let entity = DrawingStickerEntity(content: .file(.standalone(media: self.stickerFile(7, animated: true)), .sticker))
        return self.plainValues().withUpdatedEntities([.sticker(entity)])
    }

    private func stillStickerValues() -> MediaEditorValues {
        let entity = DrawingStickerEntity(content: .file(.standalone(media: self.stickerFile(8, animated: false)), .sticker))
        return self.plainValues().withUpdatedEntities([.sticker(entity)])
    }

    private func prepared(_ id: String, duration: Double = 4.0) -> ChatMediaSendPreparedAnimatedPhoto {
        return ChatMediaSendPreparedAnimatedPhoto(path: "/tmp/gifvideo_\(id).jpg", duration: duration, preview: animatedPhotoTestImage(800, 600))
    }

    private func animatedItem(_ id: String, prepared: Bool = true, duration: Double = 4.0, source: ChatMediaSendItem.Source? = nil) -> ChatMediaSendItem {
        let values = self.animatedValues()
        var item = ChatMediaSendItem(uniqueId: id, source: source ?? .libraryAsset(identifier: id, pixelSize: self.photoSize, isVideo: false, duration: 0.0), values: values, stickers: chatMediaSendCollectStickers(entities: values.entities), options: ChatMediaSendItemOptions(hasAnimatedPainting: true))
        if prepared {
            item.preparedAnimatedPhoto = self.prepared(id, duration: duration)
        }
        return item
    }

    private func plainPhotoItem(_ id: String) -> ChatMediaSendItem {
        return ChatMediaSendItem(uniqueId: id, source: .libraryAsset(identifier: id, pixelSize: self.photoSize, isVideo: false, duration: 0.0), options: ChatMediaSendItemOptions())
    }

    private func build(_ items: [ChatMediaSendItem], grouping: Bool = false, forceHd: Bool = false) -> [(media: EngineRawMedia?, attributes: [EngineMessage.Attribute], groupingKey: Int64?, uniqueId: String?)] {
        var next: Int64 = 100
        let plan = chatMediaSendPlan(items: items.map { $0.options }, global: ChatMediaSendGlobalOptions(grouping: grouping, forceHd: forceHd), makeGroupingKey: {
            next += 1
            return next
        })
        let messages = chatMediaSendBuildMessages(items: items, plan: plan, forceHd: forceHd, storeResourceData: { _, _ in })
        return messages.map { message in
            guard case let .message(_, attributes, _, mediaReference, _, _, _, groupingKey, _, _) = message.message else {
                XCTFail()
                return (nil, [], nil, nil)
            }
            if let image = mediaReference?.media as? TelegramMediaImage {
                for representation in image.representations {
                    if let resource = representation.resource as? LocalFileReferenceMediaResource {
                        self.writtenPaths.append(resource.localFilePath)
                    }
                }
            }
            return (mediaReference?.media, attributes, groupingKey, message.uniqueId)
        }
    }

    private func decodedValues(_ file: TelegramMediaFile) -> MediaEditorValues? {
        guard let resource = file.resource as? LocalFileVideoMediaResource, let adjustments = resource.adjustments else {
            return nil
        }
        return videoMediaResourceEditorValues(adjustments: adjustments, alwaysUseModernPipeline: false, defaultPreset: .compressedMedium).values
    }

    func testAnimatedPhotoMessageShape() throws {
        initializeAccountManagement()

        let item = self.animatedItem("a", duration: 6.0)
        XCTAssertTrue(chatMediaSendItemIsAnimatedPhoto(item))
        XCTAssertFalse(chatMediaSendItemNeedsRender(item))
        XCTAssertFalse(item.options.allowsHd)

        let built = self.build([item], forceHd: true)
        XCTAssertEqual(built.count, 1)
        XCTAssertEqual(built[0].uniqueId, "a")
        XCTAssertTrue(built[0].attributes.contains(where: { $0 is EmbeddedMediaStickersMessageAttribute }))

        let file = try XCTUnwrap(built[0].media as? TelegramMediaFile)
        XCTAssertEqual(file.mimeType, "video/mp4")
        XCTAssertNil(file.videoCover)
        XCTAssertFalse(file.previewRepresentations.isEmpty)
        let resource = try XCTUnwrap(file.resource as? LocalFileVideoMediaResource)
        XCTAssertEqual(resource.paths, ["/tmp/gifvideo_a.jpg"])
        XCTAssertEqual(resource.adjustments?.isStory, false)

        let values = try XCTUnwrap(self.decodedValues(file))
        XCTAssertEqual(values.qualityPreset, .animation)
        XCTAssertEqual(values.imageDuration, 6.0)
        XCTAssertEqual(values.entities.count, 1)
        XCTAssertTrue(values.entities.contains(where: { $0.entity.isAnimated }))
        XCTAssertEqual(values.originalDimensions, PixelDimensions(self.photoSize))
        XCTAssertEqual(mediaEditorImageExportDuration(values: values), 6.0)

        var kinds: [String] = []
        for attribute in file.attributes {
            switch attribute {
            case let .FileName(fileName):
                XCTAssertEqual(fileName, "video.mp4")
                kinds.append("name")
            case .Animated:
                kinds.append("animated")
            case let .Video(duration, size, flags, _, _, _):
                XCTAssertEqual(duration, 6.0)
                XCTAssertEqual(size, chatMediaEditorVideoFileDimensions(values: values, duration: 6.0))
                XCTAssertEqual(flags, [.supportsStreaming])
                kinds.append("video")
            case .HasLinkedStickers:
                kinds.append("stickers")
            default:
                kinds.append("other")
            }
        }
        XCTAssertEqual(kinds, ["name", "animated", "video", "stickers"])

        let pasted = self.animatedItem("p", source: .image(animatedPhotoTestImage(1200, 900)))
        XCTAssertTrue(chatMediaSendItemIsAnimatedPhoto(pasted))
        XCTAssertFalse(chatMediaSendItemNeedsRender(pasted))
        let pastedFile = try XCTUnwrap(self.build([pasted])[0].media as? TelegramMediaFile)
        XCTAssertEqual((pastedFile.resource as? LocalFileVideoMediaResource)?.paths, ["/tmp/gifvideo_p.jpg"])

        XCTAssertTrue(self.build([self.animatedItem("u", prepared: false)]).isEmpty)

        var still = self.plainPhotoItem("s")
        still.values = self.stillStickerValues()
        XCTAssertFalse(chatMediaSendItemIsAnimatedPhoto(still))
        XCTAssertTrue(chatMediaSendItemNeedsRender(still))

        var video = ChatMediaSendItem(uniqueId: "v", source: .libraryAsset(identifier: "v", pixelSize: self.photoSize, isVideo: true, duration: 3.0), options: ChatMediaSendItemOptions())
        video.values = self.animatedValues()
        XCTAssertFalse(chatMediaSendItemIsAnimatedPhoto(video))
    }

    func testAnimatedDurationRule() {
        XCTAssertEqual(chatMediaSendAnimatedPhotoDuration(stickerDurations: []), 3.0)
        XCTAssertEqual(chatMediaSendAnimatedPhotoDuration(stickerDurations: [2.0]), 4.0)
        XCTAssertEqual(chatMediaSendAnimatedPhotoDuration(stickerDurations: [1.0]), 3.0)
        XCTAssertEqual(chatMediaSendAnimatedPhotoDuration(stickerDurations: [0.0]), 3.0)
        XCTAssertEqual(chatMediaSendAnimatedPhotoDuration(stickerDurations: [3.0]), 3.0)
        XCTAssertEqual(chatMediaSendAnimatedPhotoDuration(stickerDurations: [5.0]), 5.0)
        XCTAssertEqual(chatMediaSendAnimatedPhotoDuration(stickerDurations: [8.0]), 8.0)
        XCTAssertEqual(chatMediaSendAnimatedPhotoDuration(stickerDurations: [2.0, 3.0]), 6.0)
        XCTAssertEqual(chatMediaSendAnimatedPhotoDuration(stickerDurations: [2.5, 3.5]), 6.0)
        XCTAssertEqual(chatMediaSendAnimatedPhotoDuration(stickerDurations: [7.0, 9.0, 11.0]), 6.0)

        let values = self.animatedValues()
        XCTAssertNil(values.imageDuration)
        XCTAssertEqual(mediaEditorImageExportDuration(values: values), 5.0)
        let timed = values.withUpdatedImageDuration(4.0)
        XCTAssertEqual(timed.imageDuration, 4.0)
        XCTAssertEqual(mediaEditorImageExportDuration(values: timed), 4.0)
        XCTAssertEqual(timed.withUpdatedQualityPreset(.animation).imageDuration, 4.0)
        XCTAssertEqual(timed.withUpdatedVideoIsMuted(true).imageDuration, 4.0)
        XCTAssertEqual(timed.makeCopy().imageDuration, 4.0)
        XCTAssertNotEqual(timed, values)

        initializeAccountManagement()
        let encoded = try? JSONEncoder().encode(timed)
        let decoded = encoded.flatMap { try? JSONDecoder().decode(MediaEditorValues.self, from: $0) }
        XCTAssertEqual(decoded?.imageDuration, 4.0)
        let plainEncoded = try? JSONEncoder().encode(self.plainValues())
        let plainJson = plainEncoded.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        XCTAssertFalse(plainJson.contains("imageDuration"))
    }

    func testAnimatedDisablesGrouping() throws {
        let built = self.build([self.animatedItem("a"), self.plainPhotoItem("p")], grouping: true)
        XCTAssertEqual(built.map { $0.groupingKey }, [nil, nil])

        let plain = self.build([self.plainPhotoItem("p1"), self.plainPhotoItem("p2")], grouping: true)
        XCTAssertEqual(plain.map { $0.groupingKey }, [101, 101])

        let store = ChatMediaEditorItemStore()
        store.update("a") { $0.values = self.animatedValues() }
        store.update("v") { $0.values = self.animatedValues() }
        let sources: [String: MediaPickerChatMediaSendSource] = [
            "a": .photo(identifier: "a", pixelSize: self.photoSize, thumbnail: nil),
            "v": .video(identifier: "v", pixelSize: CGSize(width: 1920.0, height: 1080.0), duration: 3.0, thumbnail: nil),
            "p": .photo(identifier: "p", pixelSize: self.photoSize, thumbnail: nil)
        ]
        XCTAssertNil(mediaPickerChatMediaSendFallback(selection: AnimatedPhotoTestSelection(["a", "v", "p"]), editing: AnimatedPhotoTestEditing(), store: store, assetFor: { sources[$0] }))
        let items = mediaPickerChatMediaSendItems(selection: AnimatedPhotoTestSelection(["a", "v", "p"]), editing: AnimatedPhotoTestEditing(), store: store, assetFor: { sources[$0] }, fileNameFor: { _ in nil })
        XCTAssertTrue(items[0].options.hasAnimatedPainting)
        XCTAssertTrue(items[1].options.hasAnimatedPainting)
        XCTAssertFalse(items[2].options.hasAnimatedPainting)
        XCTAssertFalse(items[0].options.allowsHd)
        XCTAssertTrue(chatMediaSendItemIsAnimatedPhoto(items[0]))
        let plan = chatMediaSendPlan(items: items.map { $0.options }, global: mediaPickerChatMediaSendGlobalOptions(selection: AnimatedPhotoTestSelection(["a", "v", "p"]), editing: AnimatedPhotoTestEditing()), makeGroupingKey: { 5 })
        XCTAssertEqual(plan.map { $0.groupingKey }, [nil, nil, nil])

        let videoOnly = mediaPickerChatMediaSendItems(selection: AnimatedPhotoTestSelection(["v", "p"]), editing: AnimatedPhotoTestEditing(), store: store, assetFor: { sources[$0] }, fileNameFor: { _ in nil })
        XCTAssertEqual(chatMediaSendPlan(items: videoOnly.map { $0.options }, global: ChatMediaSendGlobalOptions(grouping: true), makeGroupingKey: { 5 }).map { $0.groupingKey }, [nil, nil])
    }

    func testAnimatedPhotoExportedBeforeBuildAndDroppedWhenUnavailable() throws {
        let renderer = AnimatedPhotoTestRenderer(exports: ["a1": self.prepared("a1", duration: 3.0)])
        let items = [self.animatedItem("a1", prepared: false), self.animatedItem("a2", prepared: false), self.plainPhotoItem("p")]
        let expectation = self.expectation(description: "outcome")
        var outcome: ChatMediaSendOutcome?
        let disposable = chatMediaSendMessages(items: items, global: ChatMediaSendGlobalOptions(grouping: true), renderer: renderer, makeGroupingKey: { 7 }, storeResourceData: { _, _ in }).start(next: { event in
            if case let .outcome(value) = event {
                outcome = value
                expectation.fulfill()
            }
        })
        self.wait(for: [expectation], timeout: 10.0)
        disposable.dispose()

        let result = try XCTUnwrap(outcome)
        XCTAssertEqual(renderer.exportedIds.sorted(), ["a1", "a2"])
        XCTAssertTrue(renderer.renderedIds.isEmpty)
        XCTAssertEqual(result.droppedUniqueIds, ["a2"])
        XCTAssertEqual(result.messages.map { $0.uniqueId }, ["a1", "p"])
        guard case let .message(_, _, _, mediaReference, _, _, _, groupingKey, _, _) = result.messages[0].message, let file = mediaReference?.media as? TelegramMediaFile else {
            return XCTFail()
        }
        XCTAssertNil(groupingKey)
        XCTAssertEqual((file.resource as? LocalFileVideoMediaResource)?.paths, ["/tmp/gifvideo_a1.jpg"])
    }
}
