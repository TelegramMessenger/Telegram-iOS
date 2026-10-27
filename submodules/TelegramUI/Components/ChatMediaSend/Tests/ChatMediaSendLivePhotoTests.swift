import Foundation
import UIKit
import XCTest
import SwiftSignalKit
import TelegramCore
import MediaEditor
import LegacyComponents
import LegacyMediaPickerUI
import LocalMediaResources
import FetchVideoMediaResource
@testable import ChatMediaSend

private let livePhotoTestPeerId = EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(1))

private let livePhotoTestTempBoxInitialized: Void = {
    EngineTempBox.initializeShared(basePath: NSTemporaryDirectory() + "chat-media-send-live-tests", processType: "tests", launchSpecificId: 1)
}()

private func livePhotoTestImage(_ width: Int, _ height: Int) -> UIImage {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1.0
    return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { context in
        UIColor.green.setFill()
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    }
}

private final class LivePhotoTestSelection: MediaPickerChatMediaSendSelection {
    let selectedUniqueIds: [String]
    let grouping: Bool

    init(_ ids: [String], grouping: Bool = true) {
        self.selectedUniqueIds = ids
        self.grouping = grouping
    }
}

private final class LivePhotoTestEditing: MediaPickerChatMediaSendEditing {
    var forcedCaption: NSAttributedString?
    var isHighQualityPhoto = false
    var timers: [String: Int32] = [:]

    func caption(for uniqueId: String) -> NSAttributedString? {
        return nil
    }

    func timer(for uniqueId: String) -> Int32? {
        return self.timers[uniqueId]
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

private final class FakeLivePhotoPreparer: ChatMediaSendLivePhotoPreparing {
    private let lock = NSLock()
    private let results: [String: ChatMediaSendPreparedLivePhoto]
    private(set) var requestedIds: [String] = []

    init(results: [String: ChatMediaSendPreparedLivePhoto]) {
        self.results = results
    }

    func prepareLivePhoto(item: ChatMediaSendItem, renderer: ChatMediaSendRendering) -> Signal<ChatMediaSendPreparedLivePhoto?, NoError> {
        let result = self.results[item.uniqueId]
        return Signal { [self] subscriber in
            self.lock.lock()
            self.requestedIds.append(item.uniqueId)
            self.lock.unlock()
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) {
                subscriber.putNext(result)
                subscriber.putCompletion()
            }
            return EmptyDisposable
        }
    }
}

private final class LivePhotoTestRenderer: ChatMediaSendRendering {
    func renderPhoto(item: ChatMediaSendItem, forceHd: Bool) -> Signal<ChatMediaSendRenderEvent, NoError> {
        return .single(.result(livePhotoTestImage(400, 300)))
    }
}

final class ChatMediaSendLivePhotoTests: XCTestCase {
    private var writtenPaths: [String] = []
    private let photoSize = CGSize(width: 4032.0, height: 3024.0)
    private let videoDimensions = PixelDimensions(width: 1920, height: 1440)

    override func setUp() {
        super.setUp()
        let _ = livePhotoTestTempBoxInitialized
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

    private func photoValues() -> MediaEditorValues {
        return chatMediaEditorValues(peerId: livePhotoTestPeerId, originalDimensions: PixelDimensions(self.photoSize), qualityPreset: .compressedVeryHigh)
    }

    private func animatedStickerValues() -> MediaEditorValues {
        let entity = DrawingStickerEntity(content: .file(.standalone(media: self.stickerFile(7, animated: true)), .sticker))
        return self.photoValues().withUpdatedEntities([.sticker(entity)])
    }

    private func liveSource(_ id: String, mode: ChatMediaSendLivePhotoMode = .live) -> MediaPickerChatMediaSendSource {
        return .livePhoto(identifier: id, pixelSize: self.photoSize, mode: mode, thumbnail: nil)
    }

    private func photoSource(_ id: String) -> MediaPickerChatMediaSendSource {
        return .photo(identifier: id, pixelSize: self.photoSize, thumbnail: nil)
    }

    private func liveItem(_ id: String, mode: ChatMediaSendLivePhotoMode, values: MediaEditorValues? = nil, stickers: [TelegramMediaFile] = [], prepared: Bool = true, duration: Double = 2.5) -> ChatMediaSendItem {
        var item = ChatMediaSendItem(uniqueId: id, source: .livePhoto(identifier: id, pixelSize: self.photoSize, mode: mode), values: values, stickers: stickers, options: ChatMediaSendItemOptions(livePhotoLoopOrBounce: mode == .loop || mode == .bounce, isLivePhoto: mode == .live))
        if prepared {
            item.preparedLivePhoto = ChatMediaSendPreparedLivePhoto(video: ChatMediaSendLivePhotoVideo(path: "/tmp/\(id).mov", dimensions: self.videoDimensions, duration: duration), image: livePhotoTestImage(4032, 3024))
        }
        return item
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

    private func videoAttribute(_ file: TelegramMediaFile) -> (duration: Double, size: PixelDimensions, flags: TelegramMediaVideoFlags)? {
        for attribute in file.attributes {
            if case let .Video(duration, size, flags, _, _, _) = attribute {
                return (duration, size, flags)
            }
        }
        return nil
    }

    func testLivePhotoVideoValuesCarryPerspective() {
        let perspective = MediaEditorCropPerspective(vertical: 0.2, horizontal: -0.1)
        let peerId = EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(1))
        let photoValues = chatMediaEditorValues(peerId: peerId, originalDimensions: PixelDimensions(width: 3024, height: 4032), qualityPreset: .compressedHigh)
            .withUpdatedCrop(rect: CGRect(x: 100.0, y: 200.0, width: 2000.0, height: 3000.0), rotation: 0.05, orientation: .right, mirroring: false, perspective: perspective)
        let video = ChatMediaSendLivePhotoVideo(path: "/tmp/p.mov", dimensions: PixelDimensions(width: 1080, height: 1440), duration: 2.0)
        for mode in [ChatMediaSendLivePhotoMode.off, .live, .loop, .bounce] {
            let values = chatMediaSendLivePhotoVideoValues(photoValues: photoValues, video: video, mode: mode)
            XCTAssertEqual(values.cropPerspective, perspective)
            XCTAssertEqual(values.cropRotation, 0.05, accuracy: 1e-9)
        }
    }

    func testLivePhotoVideoCropStaysInsideWarpedVideo() {
        let perspective = MediaEditorCropPerspective(vertical: mediaEditorCropMaximumPerspectiveAngle * .pi / 180.0, horizontal: -mediaEditorCropMaximumPerspectiveAngle * .pi / 180.0)
        let photoSize = CGSize(width: 4032.0, height: 3024.0)
        let photoCrop = mediaEditorCropRectFitted(CGRect(origin: .zero, size: photoSize), originalSize: photoSize, rotation: 0.0, perspective: perspective)
        XCTAssertTrue(mediaEditorCropRectFits(photoCrop, originalSize: photoSize, rotation: 0.0, perspective: perspective))
        let peerId = EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(1))
        let photoValues = chatMediaEditorValues(peerId: peerId, originalDimensions: PixelDimensions(width: 4032, height: 3024), qualityPreset: .compressedHigh)
            .withUpdatedCrop(rect: photoCrop, rotation: 0.0, orientation: nil, mirroring: false, perspective: perspective)
        let video = ChatMediaSendLivePhotoVideo(path: "/tmp/p.mov", dimensions: PixelDimensions(width: 1308, height: 980), duration: 2.0)
        let values = chatMediaSendLivePhotoVideoValues(photoValues: photoValues, video: video, mode: .live)
        let videoCrop = values.cropRect ?? .zero
        XCTAssertTrue(mediaEditorCropRectFits(videoCrop, originalSize: CGSize(width: 1308.0, height: 980.0), rotation: 0.0, perspective: perspective))
        XCTAssertGreaterThan(videoCrop.width, photoCrop.width * 1308.0 / 4032.0 * 0.95)
    }

    func testLiveModeResolved() {
        XCTAssertEqual(chatMediaSendResolvedLivePhotoMode(stored: nil, isLiveAsset: true, forceLivePhotoEnabled: true), .live)
        XCTAssertEqual(chatMediaSendResolvedLivePhotoMode(stored: nil, isLiveAsset: true, forceLivePhotoEnabled: false), .off)
        XCTAssertEqual(chatMediaSendResolvedLivePhotoMode(stored: nil, isLiveAsset: false, forceLivePhotoEnabled: true), .off)
        XCTAssertEqual(chatMediaSendResolvedLivePhotoMode(stored: .bounce, isLiveAsset: true, forceLivePhotoEnabled: false), .bounce)
        XCTAssertEqual(chatMediaSendResolvedLivePhotoMode(stored: .off, isLiveAsset: true, forceLivePhotoEnabled: true), .off)
        XCTAssertEqual(chatMediaSendResolvedLivePhotoMode(stored: .loop, isLiveAsset: true, forceLivePhotoEnabled: true), .loop)

        for mode in [ChatMediaSendLivePhotoMode.off, .live, .loop, .bounce] {
            XCTAssertEqual(ChatMediaSendLivePhotoMode(legacy: mode.legacyMode), mode)
        }
        XCTAssertEqual(ChatMediaSendLivePhotoMode.live.legacyMode, TGMediaLivePhotoMode.live)
        XCTAssertEqual(ChatMediaSendLivePhotoMode.off.legacyMode, TGMediaLivePhotoMode.off)

        let editing = LivePhotoTestEditing()
        let sources: [String: MediaPickerChatMediaSendSource] = ["l": self.liveSource("l"), "p": self.photoSource("p")]
        XCTAssertNil(mediaPickerChatMediaSendFallback(selection: LivePhotoTestSelection(["l", "p"]), editing: editing, store: ChatMediaEditorItemStore(), assetFor: { sources[$0] }))
        let items = mediaPickerChatMediaSendItems(selection: LivePhotoTestSelection(["l", "p"]), editing: editing, store: ChatMediaEditorItemStore(), assetFor: { sources[$0] }, fileNameFor: { _ in nil })
        guard case let .livePhoto(identifier, pixelSize, mode) = items[0].source else {
            return XCTFail()
        }
        XCTAssertEqual(identifier, "l")
        XCTAssertEqual(pixelSize, self.photoSize)
        XCTAssertEqual(mode, .live)
        XCTAssertTrue(items[0].options.isLivePhoto)
        XCTAssertFalse(items[0].options.livePhotoLoopOrBounce)
        XCTAssertFalse(items[0].options.allowsHd)
        XCTAssertFalse(items[1].options.isLivePhoto)
    }

    func testLiveWithAnimatedPaintingBecomesLoop() throws {
        XCTAssertEqual(chatMediaSendEffectiveLivePhotoMode(resolved: .live, hasAnimatedPainting: true), .loop)
        XCTAssertEqual(chatMediaSendEffectiveLivePhotoMode(resolved: .live, hasAnimatedPainting: false), .live)
        XCTAssertEqual(chatMediaSendEffectiveLivePhotoMode(resolved: .bounce, hasAnimatedPainting: true), .bounce)
        XCTAssertEqual(chatMediaSendEffectiveLivePhotoMode(resolved: .off, hasAnimatedPainting: true), .off)

        let store = ChatMediaEditorItemStore()
        store.update("l") { $0.values = self.animatedStickerValues() }
        let sources: [String: MediaPickerChatMediaSendSource] = ["l": self.liveSource("l")]
        XCTAssertNil(mediaPickerChatMediaSendFallback(selection: LivePhotoTestSelection(["l"]), editing: LivePhotoTestEditing(), store: store, assetFor: { sources[$0] }))
        let items = mediaPickerChatMediaSendItems(selection: LivePhotoTestSelection(["l"]), editing: LivePhotoTestEditing(), store: store, assetFor: { sources[$0] }, fileNameFor: { _ in nil })
        guard case let .livePhoto(_, _, mode) = items[0].source else {
            return XCTFail()
        }
        XCTAssertEqual(mode, .loop)
        XCTAssertFalse(items[0].options.isLivePhoto)
        XCTAssertTrue(items[0].options.livePhotoLoopOrBounce)
        XCTAssertEqual(items[0].stickers.map { $0.fileId.id }, [7])

        var item = items[0]
        item.preparedLivePhoto = ChatMediaSendPreparedLivePhoto(video: ChatMediaSendLivePhotoVideo(path: "/tmp/l.mov", dimensions: self.videoDimensions, duration: 3.0), image: livePhotoTestImage(4032, 3024))
        let file = try XCTUnwrap(self.build([item])[0].media as? TelegramMediaFile)
        XCTAssertTrue(file.attributes.contains(where: { if case .Animated = $0 { return true } else { return false } }))
        initializeAccountManagement()
        let values = try XCTUnwrap(self.decodedValues(file))
        XCTAssertEqual(values.entities.count, 1)
        XCTAssertTrue(values.entities.contains(where: { $0.entity.isAnimated }))
        XCTAssertFalse(values.videoBounce)
        XCTAssertTrue(values.videoIsMuted)
        XCTAssertEqual(values.qualityPreset, .compressedHigh)
        XCTAssertEqual(values.originalDimensions, self.videoDimensions)
    }

    func testLiveMessageShape() throws {
        let sticker = self.stickerFile(9, animated: false)
        let built = self.build([self.liveItem("l", mode: .live, stickers: [sticker], duration: 2.75)], forceHd: true)
        XCTAssertEqual(built.count, 1)
        XCTAssertEqual(built[0].uniqueId, "l")
        let image = try XCTUnwrap(built[0].media as? TelegramMediaImage)
        XCTAssertTrue(image.flags.contains(.isLivePhoto))
        XCTAssertTrue(image.flags.contains(.hasStickers))
        XCTAssertTrue(image.representations.last?.resource is LocalFileReferenceMediaResource)
        XCTAssertEqual(image.representations.last?.dimensions, PixelDimensions(width: 1280, height: 960))
        XCTAssertTrue(built[0].attributes.contains(where: { $0 is EmbeddedMediaStickersMessageAttribute }))

        let video = try XCTUnwrap(image.video)
        XCTAssertEqual(video.mimeType, "video/mp4")
        let resource = try XCTUnwrap(video.resource as? LocalFileVideoMediaResource)
        XCTAssertEqual(resource.paths, ["/tmp/l.mov"])
        XCTAssertEqual(resource.adjustments?.isStory, false)
        let values = try XCTUnwrap(self.decodedValues(video))
        XCTAssertEqual(values.qualityPreset, .compressedMedium)
        XCTAssertFalse(values.videoIsMuted)
        XCTAssertFalse(values.videoBounce)
        XCTAssertEqual(values.originalDimensions, self.videoDimensions)

        var kinds: [String] = []
        for attribute in video.attributes {
            switch attribute {
            case let .Video(duration, size, flags, _, _, _):
                XCTAssertEqual(duration, 2.75)
                XCTAssertEqual(flags, [])
                XCTAssertEqual(size, chatMediaEditorVideoFileDimensions(values: values, duration: 2.75))
                kinds.append("video")
            case .hintFileIsLarge:
                kinds.append("large")
            default:
                kinds.append("other")
            }
        }
        XCTAssertEqual(kinds, ["video"])

        let cropped = self.photoValues().withUpdatedCrop(rect: CGRect(x: 0.0, y: 0.0, width: 2016.0, height: 1512.0), rotation: 0.0, orientation: nil, mirroring: false, perspective: .zero)
        let editedVideo = try XCTUnwrap((self.build([self.liveItem("e", mode: .live, values: cropped)])[0].media as? TelegramMediaImage)?.video)
        let editedValues = try XCTUnwrap(self.decodedValues(editedVideo))
        XCTAssertEqual(editedValues.originalDimensions, self.videoDimensions)
        XCTAssertEqual(editedValues.cropRect, CGRect(x: 0.0, y: 0.0, width: 960.0, height: 720.0))
        XCTAssertEqual(editedValues.qualityPreset, .compressedMedium)

        XCTAssertTrue(self.build([self.liveItem("u", mode: .live, prepared: false)]).isEmpty)
    }

    func testLoopBounceMessageShape() throws {
        for mode in [ChatMediaSendLivePhotoMode.loop, .bounce] {
            let built = self.build([self.liveItem("l", mode: mode, duration: 2.0)], forceHd: true)
            let file = try XCTUnwrap(built[0].media as? TelegramMediaFile)
            let resource = try XCTUnwrap(file.resource as? LocalFileVideoMediaResource)
            XCTAssertEqual(resource.paths, ["/tmp/l.mov"])
            let values = try XCTUnwrap(self.decodedValues(file))
            XCTAssertEqual(values.qualityPreset, .compressedHigh)
            XCTAssertTrue(values.videoIsMuted)
            XCTAssertEqual(values.videoBounce, mode == .bounce)
            XCTAssertTrue(file.attributes.contains(where: { if case .Animated = $0 { return true } else { return false } }))
            XCTAssertEqual(file.attributes.filter { if case .Animated = $0 { return true } else { return false } }.count, 1)
            let videoInfo = try XCTUnwrap(self.videoAttribute(file))
            XCTAssertEqual(videoInfo.duration, mode == .bounce ? 4.0 : 2.0)
            XCTAssertEqual(videoInfo.size, chatMediaEditorVideoFileDimensions(values: values, duration: 2.0))
            let cover = try XCTUnwrap(file.videoCover)
            XCTAssertEqual(cover.representations.last?.dimensions, PixelDimensions(width: 1280, height: 960))
            XCTAssertFalse(file.previewRepresentations.isEmpty)
        }
    }

    func testLoopBounceDisableGrouping() throws {
        let live = self.build([self.liveItem("l", mode: .live), ChatMediaSendItem(uniqueId: "p", source: .libraryAsset(identifier: "p", pixelSize: self.photoSize, isVideo: false, duration: 0.0), options: ChatMediaSendItemOptions())], grouping: true)
        XCTAssertEqual(live.map { $0.groupingKey }, [101, 101])

        for mode in [ChatMediaSendLivePhotoMode.loop, .bounce] {
            let built = self.build([self.liveItem("l", mode: mode), ChatMediaSendItem(uniqueId: "p", source: .libraryAsset(identifier: "p", pixelSize: self.photoSize, isVideo: false, duration: 0.0), options: ChatMediaSendItemOptions())], grouping: true)
            XCTAssertEqual(built.map { $0.groupingKey }, [nil, nil])
        }

        let sources: [String: MediaPickerChatMediaSendSource] = ["l": self.liveSource("l", mode: .bounce), "p": self.photoSource("p")]
        let items = mediaPickerChatMediaSendItems(selection: LivePhotoTestSelection(["l", "p"]), editing: LivePhotoTestEditing(), store: ChatMediaEditorItemStore(), assetFor: { sources[$0] }, fileNameFor: { _ in nil })
        XCTAssertTrue(items[0].options.livePhotoLoopOrBounce)
        let plan = chatMediaSendPlan(items: items.map { $0.options }, global: ChatMediaSendGlobalOptions(grouping: true), makeGroupingKey: { 5 })
        XCTAssertEqual(plan.map { $0.groupingKey }, [nil, nil])
    }

    func testLivePhotoPreparedBeforeBuildAndDroppedWhenUnavailable() throws {
        let preparer = FakeLivePhotoPreparer(results: ["l1": ChatMediaSendPreparedLivePhoto(video: ChatMediaSendLivePhotoVideo(path: "/tmp/l1.mov", dimensions: self.videoDimensions, duration: 2.0), image: livePhotoTestImage(800, 600))])
        let items = [
            self.liveItem("l1", mode: .live, prepared: false),
            self.liveItem("l2", mode: .loop, prepared: false)
        ]
        let expectation = self.expectation(description: "outcome")
        var outcome: ChatMediaSendOutcome?
        let disposable = chatMediaSendMessages(items: items, global: ChatMediaSendGlobalOptions(grouping: true), renderer: LivePhotoTestRenderer(), livePhotoPreparer: preparer, makeGroupingKey: { 7 }, storeResourceData: { _, _ in }).start(next: { event in
            if case let .outcome(value) = event {
                outcome = value
                expectation.fulfill()
            }
        })
        self.wait(for: [expectation], timeout: 10.0)
        disposable.dispose()

        let result = try XCTUnwrap(outcome)
        XCTAssertEqual(preparer.requestedIds.sorted(), ["l1", "l2"])
        XCTAssertEqual(result.droppedUniqueIds, ["l2"])
        XCTAssertEqual(result.messages.map { $0.uniqueId }, ["l1"])
        guard case let .message(_, _, _, mediaReference, _, _, _, _, _, _) = result.messages[0].message, let image = mediaReference?.media as? TelegramMediaImage else {
            return XCTFail()
        }
        XCTAssertTrue(image.flags.contains(.isLivePhoto))
        if let resource = image.representations.last?.resource as? LocalFileReferenceMediaResource {
            self.writtenPaths.append(resource.localFilePath)
        }
    }
}
