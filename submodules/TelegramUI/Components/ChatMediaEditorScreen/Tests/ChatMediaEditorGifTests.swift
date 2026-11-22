import Foundation
import UIKit
import Photos
import XCTest
import TelegramCore
import TextFormat
import LocalMediaResources
import MediaEditor
import ChatMediaSend
import LegacyMediaPickerUI
import ChatMediaEditorScreen

private final class StubGifAsset: PHAsset {
    private let stubIdentifier: String
    private let stubUniformType: String?

    init(identifier: String, uniformType: String?) {
        self.stubIdentifier = identifier
        self.stubUniformType = uniformType
        super.init()
    }

    override var localIdentifier: String {
        return self.stubIdentifier
    }

    override var pixelWidth: Int {
        return 480
    }

    override var pixelHeight: Int {
        return 270
    }

    override var mediaType: PHAssetMediaType {
        return .image
    }

    override func value(forKey key: String) -> Any? {
        if key == "uniformTypeIdentifier" {
            return self.stubUniformType
        }
        return nil
    }
}

final class ChatMediaEditorGifTests: XCTestCase {
    private let peerId = EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(1))

    func testGifAssetClassification() {
        XCTAssertTrue(chatMediaSendAssetIsGif(StubGifAsset(identifier: "g", uniformType: "com.compuserve.gif")))
        XCTAssertFalse(chatMediaSendAssetIsGif(StubGifAsset(identifier: "p", uniformType: "public.jpeg")))
        XCTAssertFalse(chatMediaSendAssetIsGif(StubGifAsset(identifier: "n", uniformType: nil)))
    }

    func testGifItemUsesConvertedVideoSubject() {
        let asset = StubGifAsset(identifier: "g1", uniformType: "com.compuserve.gif")
        let item = ChatMediaEditorItem(uniqueId: "g1", source: .asset(asset), isAnimation: true)
        let converted = ChatMediaSendConvertedGif(path: "/tmp/g1.mp4", dimensions: PixelDimensions(width: 480, height: 272), duration: 2.0)

        let pending = chatMediaEditorItemSubject(item, convertedGif: { _ in nil })
        guard case .asset = pending else {
            XCTFail()
            return
        }
        XCTAssertTrue(chatMediaEditorItemAwaitsGifConversion(item, subject: pending))

        var requested: [String] = []
        let ready = chatMediaEditorItemSubject(item, convertedGif: { identifier in
            requested.append(identifier)
            return converted
        })
        guard case let .video(path, dimensions, duration) = ready else {
            XCTFail()
            return
        }
        XCTAssertEqual(requested, ["g1"])
        XCTAssertEqual(path, "/tmp/g1.mp4")
        XCTAssertEqual(dimensions, PixelDimensions(width: 480, height: 272))
        XCTAssertEqual(duration, 2.0)
        XCTAssertFalse(chatMediaEditorItemAwaitsGifConversion(item, subject: ready))

        let photo = ChatMediaEditorItem(uniqueId: "p", source: .asset(StubGifAsset(identifier: "p", uniformType: "public.jpeg")))
        let photoSubject = chatMediaEditorItemSubject(photo, convertedGif: { _ in converted })
        guard case .asset = photoSubject else {
            XCTFail()
            return
        }
        XCTAssertFalse(chatMediaEditorItemAwaitsGifConversion(photo, subject: photoSubject))
    }

    func testGifItemTabsAndSetup() {
        XCTAssertTrue(chatMediaEditorShowsQualityTab(isGallery: true, hasCaptionModel: true, isAnimation: false))
        XCTAssertFalse(chatMediaEditorShowsQualityTab(isGallery: true, hasCaptionModel: true, isAnimation: true))
        XCTAssertFalse(chatMediaEditorShowsQualityTab(isGallery: false, hasCaptionModel: true, isAnimation: false))
        XCTAssertEqual(chatMediaEditorToolbarTabs(showsQuality: chatMediaEditorShowsQualityTab(isGallery: true, hasCaptionModel: true, isAnimation: true)), [.cropTab, .paintTab, .toolsTab])
        XCTAssertFalse(chatMediaEditorMuteButtonIsVisible(isGallery: true, isVideo: true, isAnimation: true))

        let subject = ChatMediaEditorSubject.video(path: "/tmp/g1.mp4", dimensions: PixelDimensions(width: 480, height: 272), duration: 2.0)
        let setup = chatMediaEditorEditorSetup(subject: subject, peerId: self.peerId, isAnimation: true)
        XCTAssertEqual(setup.values.qualityPreset, .animation)
        XCTAssertFalse(setup.values.videoIsMuted)
        XCTAssertFalse(chatMediaEditorValuesAreEdited(setup.values, baselineQualityPreset: setup.values.qualityPreset))
        XCTAssertNotEqual(chatMediaEditorEditorSetup(subject: subject, peerId: self.peerId).values.qualityPreset, .animation)
    }

    func testDrawOnAnimatedFileIsRegularVideo() {
        XCTAssertFalse(chatMediaEditorIsAnimation(mode: .draw, mediaIsAnimated: true))
        XCTAssertTrue(chatMediaEditorIsAnimation(mode: .default, mediaIsAnimated: true))
        XCTAssertTrue(chatMediaEditorIsAnimation(mode: .caption, mediaIsAnimated: true))
        XCTAssertFalse(chatMediaEditorIsAnimation(mode: .plain, mediaIsAnimated: true))
        XCTAssertFalse(chatMediaEditorIsAnimation(mode: .default, mediaIsAnimated: false))
    }

    func testSingleAnimatedSubjectUsesAnimationPreset() {
        let subject = ChatMediaEditorSubject.video(path: "/tmp/g1.mp4", dimensions: PixelDimensions(width: 480, height: 272), duration: 2.0)
        let item = chatMediaEditorSingleItem(subject: subject, isAnimation: true)
        XCTAssertTrue(item.isAnimation)
        let itemSubject = chatMediaEditorItemSubject(item, convertedGif: { _ in nil })
        guard case .video = itemSubject else {
            XCTFail()
            return
        }
        let setup = chatMediaEditorEditorSetup(subject: itemSubject, peerId: self.peerId, isAnimation: item.isAnimation)
        XCTAssertEqual(setup.values.qualityPreset, .animation)
        XCTAssertFalse(chatMediaEditorMuteButtonIsVisible(isGallery: false, isVideo: true, isAnimation: item.isAnimation))
        XCTAssertFalse(chatMediaEditorShowsQualityTab(isGallery: false, hasCaptionModel: false, isAnimation: item.isAnimation))
        XCTAssertFalse(chatMediaEditorCoverButtonIsVisible(hasCoverButton: false, isVideo: true, isAnimation: item.isAnimation, duration: 2.0))

        let regular = chatMediaEditorSingleItem(subject: subject, isAnimation: false)
        XCTAssertFalse(regular.isAnimation)
        XCTAssertNotEqual(chatMediaEditorEditorSetup(subject: subject, peerId: self.peerId, isAnimation: regular.isAnimation).values.qualityPreset, .animation)
    }

    func testUnchangedGifResendsOriginalFile() throws {
        let subject = ChatMediaEditorSubject.video(path: "/tmp/g.mp4", dimensions: PixelDimensions(width: 480, height: 272), duration: 2.0)
        let values = chatMediaEditorEditorSetup(subject: subject, peerId: self.peerId, isAnimation: true).values
        XCTAssertTrue(chatMediaEditorGifSendsOriginal(values: values, hasStickers: false))
        XCTAssertTrue(chatMediaEditorGifSendsOriginal(values: nil, hasStickers: false))

        let caption = NSMutableAttributedString(string: "gif bold")
        caption.addAttribute(ChatTextInputAttributes.bold, value: true as NSNumber, range: NSRange(location: 4, length: 4))
        let original = TelegramMediaFile(fileId: EngineMedia.Id(namespace: Namespaces.Media.CloudFile, id: 4242), partialReference: nil, resource: LocalFileMediaResource(fileId: 4242), previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "video/mp4", size: nil, attributes: [.Animated, .Video(duration: 2.0, size: PixelDimensions(width: 480, height: 272), flags: [], preloadSize: nil, coverTime: nil, videoCodec: nil)], alternativeRepresentations: [])
        let result = ChatMediaEditorResult(media: .video(path: "/tmp/g.mp4", values: values, duration: 2.0), thumbnail: nil, caption: caption, stickers: [], isAnimation: true)
        let message = try XCTUnwrap(chatMediaEditorEnqueueMessage(result: result, forceHd: false, originalMediaReference: .standalone(media: original), storeResourceData: { _, _ in }))
        guard case let .message(text, attributes, _, mediaReference, _, _, _, _, _, _) = message.message else {
            return XCTFail()
        }
        let file = try XCTUnwrap(mediaReference?.media as? TelegramMediaFile)
        XCTAssertTrue(file === original)
        XCTAssertEqual(text, "gif bold")
        let entities = try XCTUnwrap(attributes.compactMap { $0 as? TextEntitiesMessageAttribute }.first)
        XCTAssertTrue(entities.entities.contains(where: { $0.range == 4 ..< 8 && $0.type == .Bold }))
        XCTAssertFalse(attributes.contains(where: { $0 is EmbeddedMediaStickersMessageAttribute }))

        let regular = ChatMediaEditorResult(media: .video(path: "/tmp/g.mp4", values: values, duration: 2.0), thumbnail: nil, caption: caption, stickers: [], isAnimation: false)
        let regularMessage = try XCTUnwrap(chatMediaEditorEnqueueMessage(result: regular, forceHd: false, originalMediaReference: .standalone(media: original), storeResourceData: { _, _ in }))
        guard case let .message(_, _, _, regularReference, _, _, _, _, _, _) = regularMessage.message else {
            return XCTFail()
        }
        XCTAssertNotEqual((regularReference?.media as? TelegramMediaFile)?.fileId, original.fileId)

        let noOriginalMessage = try XCTUnwrap(chatMediaEditorEnqueueMessage(result: result, forceHd: false, storeResourceData: { _, _ in }))
        guard case let .message(_, _, _, noOriginalReference, _, _, _, _, _, _) = noOriginalMessage.message else {
            return XCTFail()
        }
        let rendered = try XCTUnwrap(noOriginalReference?.media as? TelegramMediaFile)
        XCTAssertTrue(rendered.resource is LocalFileVideoMediaResource)
        XCTAssertTrue(rendered.isAnimated)
    }
}
