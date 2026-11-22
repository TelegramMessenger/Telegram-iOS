import Foundation
import UIKit
import XCTest
import TelegramCore
import MediaEditor
import TextFormat
import Display
import LegacyMediaPickerUI
import LocalMediaResources
@testable import ChatMediaSend

private let testPeerId = EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(1))

private func testImage(_ width: Int, _ height: Int) -> UIImage {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1.0
    return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { context in
        UIColor.red.setFill()
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    }
}

private let tempBoxInitialized: Void = {
    EngineTempBox.initializeShared(basePath: NSTemporaryDirectory() + "chat-media-editor-tests", processType: "tests", launchSpecificId: 1)
}()

final class ChatMediaEditorSendItemTests: XCTestCase {
    override func setUp() {
        super.setUp()
        let _ = tempBoxInitialized
    }

    override func tearDown() {
        for path in self.writtenPaths {
            try? FileManager.default.removeItem(atPath: path)
        }
        self.writtenPaths = []
        super.tearDown()
    }

    private func track(_ media: EngineRawMedia?) {
        if let image = media as? TelegramMediaImage {
            for representation in image.representations {
                if let resource = representation.resource as? LocalFileReferenceMediaResource {
                    self.writtenPaths.append(resource.localFilePath)
                }
            }
        }
    }

    private var writtenPaths: [String] = []

    private func build(_ result: ChatMediaEditorResult, forceHd: Bool = false) throws -> (text: String, attributes: [EngineMessage.Attribute], media: EngineRawMedia?, bubbleUp: [EngineItemCollectionId]) {
        let message = try XCTUnwrap(chatMediaEditorEnqueueMessage(result: result, forceHd: forceHd, storeResourceData: { _, _ in }))
        guard case let .message(text, attributes, _, mediaReference, _, _, _, _, _, bubbleUp) = message.message else {
            XCTFail()
            return ("", [], nil, [])
        }
        self.track(mediaReference?.media)
        return (text, attributes, mediaReference?.media, bubbleUp)
    }

    func testSmallImageIsNotUpscaled() {
        XCTAssertEqual(chatMediaEditorImageSendSize(nominalDimensions: PixelDimensions(width: 300, height: 200), forceHd: false), CGSize(width: 300.0, height: 200.0))
    }

    func testImageIsCappedAt1280() {
        XCTAssertEqual(chatMediaEditorImageSendSize(nominalDimensions: PixelDimensions(width: 4032, height: 3024), forceHd: false), CGSize(width: 1280.0, height: 960.0))
    }

    func testHdImageIsCappedAt2560() {
        XCTAssertEqual(chatMediaEditorImageSendSize(nominalDimensions: PixelDimensions(width: 4032, height: 3024), forceHd: true), CGSize(width: 2560.0, height: 1920.0))
    }

    func testCroppedNominalDimensions() {
        let base = chatMediaEditorValues(peerId: testPeerId, originalDimensions: PixelDimensions(width: 4032, height: 3024), qualityPreset: .compressedMedium)
        XCTAssertEqual(chatMediaEditorCroppedNominalDimensions(values: base), PixelDimensions(width: 4032, height: 3024))
        let cropped = base.withUpdatedCrop(rect: CGRect(x: 100.0, y: 50.0, width: 1008.0, height: 756.0), rotation: 0.0, orientation: nil, mirroring: false, perspective: .zero)
        XCTAssertEqual(chatMediaEditorCroppedNominalDimensions(values: cropped), PixelDimensions(width: 1008, height: 756))
        let sideward = base.withUpdatedCrop(rect: CGRect(x: 100.0, y: 50.0, width: 1008.0, height: 756.0), rotation: 0.0, orientation: .left, mirroring: false, perspective: .zero)
        XCTAssertEqual(chatMediaEditorCroppedNominalDimensions(values: sideward), PixelDimensions(width: 756, height: 1008))
        let empty = base.withUpdatedCrop(rect: .zero, rotation: 0.0, orientation: nil, mirroring: false, perspective: .zero)
        XCTAssertEqual(chatMediaEditorCroppedNominalDimensions(values: empty), PixelDimensions(width: 4032, height: 3024))
    }

    func testCroppedSendSize() throws {
        let base = chatMediaEditorValues(peerId: testPeerId, originalDimensions: PixelDimensions(width: 4032, height: 3024), qualityPreset: .compressedMedium)
        let cropped = base.withUpdatedCrop(rect: CGRect(x: 100.0, y: 50.0, width: 1008.0, height: 756.0), rotation: 0.0, orientation: nil, mirroring: false, perspective: .zero)
        let nominal = chatMediaEditorCroppedNominalDimensions(values: cropped)
        let result = ChatMediaEditorResult(media: .image(image: testImage(1008, 756), nominalDimensions: nominal), thumbnail: nil, caption: NSAttributedString(), stickers: [])
        let built = try self.build(result)
        let image = try XCTUnwrap(built.media as? TelegramMediaImage)
        XCTAssertEqual(image.representations.last?.dimensions, PixelDimensions(width: 1008, height: 756))
    }

    func testCompositionMaxSideFollowsForceHd() {
        XCTAssertEqual(chatMediaEditorImageMaxSide(forceHd: false), 1280.0)
        XCTAssertEqual(chatMediaEditorImageMaxSide(forceHd: true), 2560.0)
    }

    func testVideoAdjustmentsRoundTrip() throws {
        let values = chatMediaEditorValues(peerId: testPeerId, originalDimensions: PixelDimensions(width: 1920, height: 1080), qualityPreset: .compressedMedium)
        let adjustments = try XCTUnwrap(chatMediaEditorVideoAdjustments(values: values))
        XCTAssertFalse(adjustments.isStory)
        let decoded = try JSONDecoder().decode(MediaEditorValues.self, from: adjustments.data.makeData())
        XCTAssertEqual(decoded.qualityPreset, .compressedMedium)
    }

    func testTrimmedDuration() {
        let values = chatMediaEditorValues(peerId: testPeerId, originalDimensions: PixelDimensions(width: 1920, height: 1080), qualityPreset: .compressedMedium).withUpdatedVideoTrimRange(2.0 ..< 7.5)
        XCTAssertEqual(chatMediaEditorVideoDuration(values: values, duration: 30.0), 5.5, accuracy: 0.001)
    }

    func testUntrimmedDuration() {
        let values = chatMediaEditorValues(peerId: testPeerId, originalDimensions: PixelDimensions(width: 1920, height: 1080), qualityPreset: .compressedMedium)
        XCTAssertEqual(chatMediaEditorVideoDuration(values: values, duration: 30.0), 30.0, accuracy: 0.001)
    }

    func testVideoFileDimensionsArePortrait() {
        let values = chatMediaEditorValues(peerId: testPeerId, originalDimensions: PixelDimensions(width: 1080, height: 1920), qualityPreset: .compressedMedium)
        let dimensions = chatMediaEditorVideoFileDimensions(values: values, duration: 10.0)
        XCTAssertGreaterThan(dimensions.height, dimensions.width)
    }

    func testCaptionEntitiesAndCustomEmoji() throws {
        let caption = NSMutableAttributedString(string: "hello bold ")
        caption.addAttribute(ChatTextInputAttributes.bold, value: true as NSNumber, range: NSRange(location: 6, length: 4))
        let result = ChatMediaEditorResult(media: .image(image: testImage(400, 300), nominalDimensions: PixelDimensions(width: 400, height: 300)), thumbnail: testImage(400, 300), caption: caption, stickers: [])
        let message = try XCTUnwrap(chatMediaEditorEnqueueMessage(result: result, forceHd: false, storeResourceData: { _, _ in }))
        guard case let .message(text, attributes, _, mediaReference, _, _, _, localGroupingKey, _, _) = message.message else {
            return XCTFail()
        }
        self.track(mediaReference?.media)
        XCTAssertEqual(text, "hello bold")
        XCTAssertNil(localGroupingKey)
        XCTAssertFalse(message.isFile)
        let entities = try XCTUnwrap(attributes.compactMap { $0 as? TextEntitiesMessageAttribute }.first)
        XCTAssertTrue(entities.entities.contains(where: { $0.range == 6 ..< 10 && $0.type == .Bold }))
        let image = try XCTUnwrap(mediaReference?.media as? TelegramMediaImage)
        XCTAssertEqual(image.representations.last?.dimensions, PixelDimensions(width: 400, height: 300))
        XCTAssertEqual(image.representations.first?.dimensions, PixelDimensions(width: 320, height: 240))
    }

    func testStickersAttribute() throws {
        let sticker = TelegramMediaFile(fileId: EngineMedia.Id(namespace: Namespaces.Media.CloudFile, id: 1), partialReference: nil, resource: LocalFileMediaResource(fileId: 1), previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "image/webp", size: nil, attributes: [], alternativeRepresentations: [])
        let result = ChatMediaEditorResult(media: .image(image: testImage(400, 300), nominalDimensions: PixelDimensions(width: 400, height: 300)), thumbnail: nil, caption: NSAttributedString(), stickers: [sticker])
        let message = try XCTUnwrap(chatMediaEditorEnqueueMessage(result: result, forceHd: false, storeResourceData: { _, _ in }))
        guard case let .message(_, attributes, _, mediaReference, _, _, _, _, _, _) = message.message else {
            return XCTFail()
        }
        self.track(mediaReference?.media)
        XCTAssertTrue(attributes.contains(where: { $0 is EmbeddedMediaStickersMessageAttribute }))
        XCTAssertTrue((mediaReference?.media as? TelegramMediaImage)?.flags.contains(.hasStickers) == true)
    }

    func testVideoMessage() throws {
        let values = chatMediaEditorValues(peerId: testPeerId, originalDimensions: PixelDimensions(width: 1920, height: 1080), qualityPreset: .compressedMedium)
        let result = ChatMediaEditorResult(media: .video(path: "/tmp/v.mp4", values: values, duration: 12.0), thumbnail: testImage(192, 108), caption: NSAttributedString(), stickers: [])
        let message = try XCTUnwrap(chatMediaEditorEnqueueMessage(result: result, forceHd: false, storeResourceData: { _, _ in }))
        guard case let .message(_, _, _, mediaReference, _, _, _, _, _, _) = message.message else {
            return XCTFail()
        }
        let file = try XCTUnwrap(mediaReference?.media as? TelegramMediaFile)
        XCTAssertEqual(file.mimeType, "video/mp4")
        XCTAssertTrue(file.resource is LocalFileVideoMediaResource)
        XCTAssertEqual(file.duration, 12.0)
    }

    func testCustomEmojiBubbleUp() throws {
        let packId = EngineItemCollectionId(namespace: Namespaces.ItemCollection.CloudEmojiPacks, id: 77)
        let emojiFile = TelegramMediaFile(fileId: EngineMedia.Id(namespace: Namespaces.Media.CloudFile, id: 555), partialReference: nil, resource: LocalFileMediaResource(fileId: 555), previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "application/x-tgsticker", size: nil, attributes: [], alternativeRepresentations: [])
        let caption = NSMutableAttributedString(string: "a b")
        caption.addAttribute(ChatTextInputAttributes.customEmoji, value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: packId, fileId: 555, file: emojiFile), range: NSRange(location: 1, length: 1))
        let result = ChatMediaEditorResult(media: .image(image: testImage(400, 300), nominalDimensions: PixelDimensions(width: 400, height: 300)), thumbnail: nil, caption: caption, stickers: [])
        let built = try self.build(result)
        let entities = try XCTUnwrap(built.attributes.compactMap { $0 as? TextEntitiesMessageAttribute }.first)
        XCTAssertTrue(entities.entities.contains(where: { entity in
            if case let .CustomEmoji(_, fileId) = entity.type {
                return fileId == 555
            }
            return false
        }))
        XCTAssertEqual(built.bubbleUp, [packId])
    }

    func testForceHdImageRepresentation() throws {
        let result = ChatMediaEditorResult(media: .image(image: testImage(4032, 3024), nominalDimensions: PixelDimensions(width: 4032, height: 3024)), thumbnail: nil, caption: NSAttributedString(), stickers: [])
        let built = try self.build(result, forceHd: true)
        let image = try XCTUnwrap(built.media as? TelegramMediaImage)
        XCTAssertEqual(image.representations.last?.dimensions, PixelDimensions(width: 2560, height: 1920))
    }

    func testPortraitVideoAttributesAndAdjustments() throws {
        let values = chatMediaEditorValues(peerId: testPeerId, originalDimensions: PixelDimensions(width: 1080, height: 1920), qualityPreset: .compressedMedium)
        let result = ChatMediaEditorResult(media: .video(path: "/tmp/v.mp4", values: values, duration: 8.0), thumbnail: nil, caption: NSAttributedString(), stickers: [])
        let built = try self.build(result)
        let file = try XCTUnwrap(built.media as? TelegramMediaFile)
        let size = try XCTUnwrap(file.dimensions)
        XCTAssertGreaterThan(size.height, size.width)
        let resource = try XCTUnwrap(file.resource as? LocalFileVideoMediaResource)
        let adjustments = try XCTUnwrap(resource.adjustments)
        XCTAssertFalse(adjustments.isStory)
    }

    private func gifValues() -> MediaEditorValues {
        return chatMediaEditorValues(peerId: testPeerId, originalDimensions: PixelDimensions(width: 480, height: 272), qualityPreset: .animation)
    }

    private func originalGif() -> TelegramMediaFile {
        return TelegramMediaFile(fileId: EngineMedia.Id(namespace: Namespaces.Media.CloudFile, id: 4242), partialReference: nil, resource: LocalFileMediaResource(fileId: 4242), previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "video/mp4", size: nil, attributes: [.Animated, .Video(duration: 2.0, size: PixelDimensions(width: 480, height: 272), flags: [], preloadSize: nil, coverTime: nil, videoCodec: nil)], alternativeRepresentations: [])
    }

    func testEditedGifRendersAnimatedMp4() throws {
        let trimmed = self.gifValues().withUpdatedVideoTrimRange(0.5 ..< 1.5)
        XCTAssertFalse(chatMediaEditorGifSendsOriginal(values: trimmed, hasStickers: false))
        let cropped = self.gifValues().withUpdatedCrop(rect: CGRect(x: 0.0, y: 0.0, width: 240.0, height: 136.0), rotation: 0.0, orientation: nil, mirroring: false, perspective: .zero)
        XCTAssertFalse(chatMediaEditorGifSendsOriginal(values: cropped, hasStickers: false))
        XCTAssertFalse(chatMediaEditorGifSendsOriginal(values: self.gifValues().withUpdatedQualityPreset(.compressedMedium), hasStickers: false))

        let original = self.originalGif()
        let result = ChatMediaEditorResult(media: .video(path: "/tmp/g.mp4", values: trimmed, duration: 2.0), thumbnail: nil, caption: NSAttributedString(), stickers: [], isAnimation: true)
        let message = try XCTUnwrap(chatMediaEditorEnqueueMessage(result: result, forceHd: false, originalMediaReference: .standalone(media: original), storeResourceData: { _, _ in }))
        guard case let .message(_, _, _, mediaReference, _, _, _, _, _, _) = message.message else {
            return XCTFail()
        }
        let file = try XCTUnwrap(mediaReference?.media as? TelegramMediaFile)
        XCTAssertNotEqual(file.fileId, original.fileId)
        XCTAssertEqual(file.mimeType, "video/mp4")
        XCTAssertTrue(file.isAnimated)
        XCTAssertEqual(file.fileName, "video.mp4")
        XCTAssertEqual(file.duration ?? 0.0, 1.0, accuracy: 0.001)
        let resource = try XCTUnwrap(file.resource as? LocalFileVideoMediaResource)
        let adjustments = try XCTUnwrap(resource.adjustments)
        let decoded = try JSONDecoder().decode(MediaEditorValues.self, from: adjustments.data.makeData())
        XCTAssertTrue(decoded.videoIsMuted)
        XCTAssertEqual(decoded.qualityPreset, .animation)
    }

    func testGifStickersCountAsChange() throws {
        XCTAssertFalse(chatMediaEditorGifSendsOriginal(values: self.gifValues(), hasStickers: true))
        let sticker = TelegramMediaFile(fileId: EngineMedia.Id(namespace: Namespaces.Media.CloudFile, id: 7), partialReference: nil, resource: LocalFileMediaResource(fileId: 7), previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "image/webp", size: nil, attributes: [], alternativeRepresentations: [])
        let withEntity = self.gifValues().withUpdatedEntities([CodableDrawingEntity(entity: DrawingStickerEntity(content: .file(.standalone(media: sticker), .sticker)))!])
        XCTAssertFalse(chatMediaEditorGifSendsOriginal(values: withEntity, hasStickers: false))

        let original = self.originalGif()
        let result = ChatMediaEditorResult(media: .video(path: "/tmp/g.mp4", values: withEntity, duration: 2.0), thumbnail: nil, caption: NSAttributedString(), stickers: [sticker], isAnimation: true)
        let message = try XCTUnwrap(chatMediaEditorEnqueueMessage(result: result, forceHd: false, originalMediaReference: .standalone(media: original), storeResourceData: { _, _ in }))
        guard case let .message(_, attributes, _, mediaReference, _, _, _, _, _, _) = message.message else {
            return XCTFail()
        }
        let file = try XCTUnwrap(mediaReference?.media as? TelegramMediaFile)
        XCTAssertNotEqual(file.fileId, original.fileId)
        XCTAssertTrue(file.isAnimated)
        XCTAssertTrue(attributes.contains(where: { $0 is EmbeddedMediaStickersMessageAttribute }))
    }
}
