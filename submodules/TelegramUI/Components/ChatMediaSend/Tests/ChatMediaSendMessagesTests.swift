import Foundation
import UIKit
import XCTest
import TelegramCore
import MediaEditor
import TextFormat
import LegacyMediaPickerUI
import LegacyComponents
import LocalMediaResources
import FetchVideoMediaResource
@testable import ChatMediaSend

private let testPeerId = EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(1))

private func testImage(_ width: Int, _ height: Int) -> UIImage {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1.0
    return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { context in
        UIColor.blue.setFill()
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    }
}

private let tempBoxInitialized: Void = {
    EngineTempBox.initializeShared(basePath: NSTemporaryDirectory() + "chat-media-send-tests", processType: "tests", launchSpecificId: 1)
}()

private struct BuiltMessage {
    let text: String
    let attributes: [EngineMessage.Attribute]
    let media: EngineRawMedia?
    let groupingKey: Int64?
    let uniqueId: String?
    let isFile: Bool
}

final class ChatMediaSendMessagesTests: XCTestCase {
    private var writtenPaths: [String] = []
    private var storedIds: [EngineMediaResource.Id] = []
    private var storedData: [EngineMediaResource.Id: Data] = [:]

    override func setUp() {
        super.setUp()
        let _ = tempBoxInitialized
        self.storedIds = []
        self.storedData = [:]
    }

    override func tearDown() {
        for path in self.writtenPaths {
            try? FileManager.default.removeItem(atPath: path)
        }
        self.writtenPaths = []
        super.tearDown()
    }

    private func photo(_ id: String, _ size: CGSize = CGSize(width: 4032.0, height: 3024.0), options: ChatMediaSendItemOptions = ChatMediaSendItemOptions()) -> ChatMediaSendItem {
        return ChatMediaSendItem(uniqueId: id, source: .libraryAsset(identifier: id, pixelSize: size, isVideo: false, duration: 0.0), options: options)
    }

    private func video(_ id: String, _ size: CGSize = CGSize(width: 1920.0, height: 1080.0), duration: Double = 12.5, options: ChatMediaSendItemOptions = ChatMediaSendItemOptions()) -> ChatMediaSendItem {
        return ChatMediaSendItem(uniqueId: id, source: .libraryAsset(identifier: id, pixelSize: size, isVideo: true, duration: duration), options: options)
    }

    private func gif(_ id: String, converted: Bool = true, duration: Double = 2.5) -> ChatMediaSendItem {
        var item = ChatMediaSendItem(uniqueId: id, source: .gifAsset(identifier: id, pixelSize: CGSize(width: 480.0, height: 270.0)), options: ChatMediaSendItemOptions(excludedFromGrouping: true))
        if converted {
            item.convertedGif = ChatMediaSendConvertedGif(path: "/tmp/\(id).mp4", dimensions: PixelDimensions(width: 480, height: 272), duration: duration)
        }
        return item
    }

    private func decodedValues(_ file: TelegramMediaFile) -> MediaEditorValues? {
        guard let resource = file.resource as? LocalFileVideoMediaResource, let adjustments = resource.adjustments else {
            return nil
        }
        return videoMediaResourceEditorValues(adjustments: adjustments, alwaysUseModernPipeline: false, defaultPreset: .compressedMedium).values
    }

    private func build(_ items: [ChatMediaSendItem], grouping: Bool = false, forcedCaption: String? = nil, forceHd: Bool = false) -> [BuiltMessage] {
        var next: Int64 = 100
        let plan = chatMediaSendPlan(items: items.map { $0.options }, global: ChatMediaSendGlobalOptions(grouping: grouping, forcedCaption: forcedCaption.map { NSAttributedString(string: $0) }, forceHd: forceHd), makeGroupingKey: {
            next += 1
            return next
        })
        let messages = chatMediaSendBuildMessages(items: items, plan: plan, forceHd: forceHd, storeResourceData: { id, data in
            self.storedIds.append(id)
            self.storedData[id] = data
        })
        return messages.map { message in
            guard case let .message(text, attributes, _, mediaReference, _, _, _, groupingKey, _, _) = message.message else {
                XCTFail()
                return BuiltMessage(text: "", attributes: [], media: nil, groupingKey: nil, uniqueId: nil, isFile: false)
            }
            if let image = mediaReference?.media as? TelegramMediaImage {
                for representation in image.representations {
                    if let resource = representation.resource as? LocalFileReferenceMediaResource {
                        self.writtenPaths.append(resource.localFilePath)
                    }
                }
            }
            return BuiltMessage(text: text, attributes: attributes, media: mediaReference?.media, groupingKey: groupingKey, uniqueId: message.uniqueId, isFile: message.isFile)
        }
    }

    private func videoAttribute(_ file: TelegramMediaFile) -> (duration: Double, size: PixelDimensions, flags: TelegramMediaVideoFlags)? {
        for attribute in file.attributes {
            if case let .Video(duration, size, flags, _, _, _) = attribute {
                return (duration, size, flags)
            }
        }
        return nil
    }

    private func fileName(_ file: TelegramMediaFile) -> String? {
        for attribute in file.attributes {
            if case let .FileName(fileName) = attribute {
                return fileName
            }
        }
        return nil
    }

    private func hasHintFileIsLarge(_ file: TelegramMediaFile) -> Bool {
        return file.attributes.contains(where: { if case .hintFileIsLarge = $0 { return true } else { return false } })
    }

    func testUneditedLibraryPhoto() throws {
        var item = photo("p1")
        item.thumbnail = testImage(64, 48)
        let messages = build([item], forceHd: true)
        XCTAssertEqual(messages.count, 1)
        let image = try XCTUnwrap(messages[0].media as? TelegramMediaImage)
        XCTAssertEqual(image.representations.count, 2)
        XCTAssertTrue(image.representations[0].resource is LocalFileMediaResource)
        XCTAssertEqual(image.representations[0].dimensions, PixelDimensions(width: 320, height: 240))
        let resource = try XCTUnwrap(image.representations[1].resource as? PhotoLibraryMediaResource)
        XCTAssertEqual(resource.localIdentifier, "p1")
        XCTAssertTrue(resource.forceHd)
        XCTAssertNil(resource.width)
        XCTAssertNil(resource.format)
        XCTAssertEqual(image.representations[1].dimensions, PixelDimensions(width: 1280, height: 960))
        XCTAssertEqual(image.imageId.namespace, Namespaces.Media.LocalImage)
        XCTAssertEqual(image.flags, [])
        XCTAssertEqual(messages[0].text, "")
        XCTAssertTrue(messages[0].attributes.isEmpty)
        XCTAssertFalse(messages[0].isFile)

        let small = build([photo("p2", CGSize(width: 300.0, height: 200.0))], forceHd: false)
        let smallImage = try XCTUnwrap(small[0].media as? TelegramMediaImage)
        XCTAssertEqual(smallImage.representations.count, 1)
        XCTAssertEqual(smallImage.representations[0].dimensions, PixelDimensions(width: 300, height: 200))
        XCTAssertEqual((smallImage.representations[0].resource as? PhotoLibraryMediaResource)?.forceHd, false)
    }

    func testUneditedLibraryVideoCompressNil() throws {
        var item = video("v1")
        item.thumbnail = testImage(192, 108)
        let messages = build([item])
        let file = try XCTUnwrap(messages[0].media as? TelegramMediaFile)
        let resource = try XCTUnwrap(file.resource as? VideoLibraryMediaResource)
        XCTAssertEqual(resource.localIdentifier, "v1")
        XCTAssertEqual(resource.conversion, .compress(nil))
        XCTAssertEqual(file.mimeType, "video/mp4")
        XCTAssertEqual(file.fileId.namespace, Namespaces.Media.LocalFile)
        XCTAssertNil(file.videoCover)
        XCTAssertEqual(fileName(file), "video.mp4")
        let videoInfo = try XCTUnwrap(videoAttribute(file))
        XCTAssertEqual(videoInfo.duration, 12.5)
        XCTAssertEqual(videoInfo.size, PixelDimensions(width: 848, height: 464))
        XCTAssertEqual(videoInfo.flags, [.supportsStreaming])
        XCTAssertFalse(hasHintFileIsLarge(file))
        XCTAssertEqual(file.previewRepresentations.count, 1)
        XCTAssertEqual(file.previewRepresentations[0].dimensions, PixelDimensions(width: 320, height: 180))

        var named = video("v2", CGSize(width: 1080.0, height: 1920.0), duration: 60.0)
        named.fileName = "IMG_0001.MOV"
        let long = try XCTUnwrap(build([named])[0].media as? TelegramMediaFile)
        XCTAssertTrue(hasHintFileIsLarge(long))
        XCTAssertEqual(fileName(long), "IMG_0001.MOV")
        XCTAssertEqual(videoAttribute(long)?.size, PixelDimensions(width: 464, height: 848))
    }

    private func withPreferredVideoPreset(_ value: Int?, _ body: () throws -> Void) rethrows {
        let defaults = UserDefaults.standard
        let key = "TG_preferredVideoPreset_v0"
        let previous = defaults.object(forKey: key)
        if let value {
            defaults.set(NSNumber(value: value), forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
        defer {
            if let previous {
                defaults.set(previous, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }
        try body()
    }

    private func estimatedSizeHint(_ preset: TGMediaVideoConversionPreset, duration: Double, hasAudio: Bool) -> Bool {
        return TGMediaVideoConverter.estimatedSize(for: preset, duration: duration, hasAudio: hasAudio) > 10 * 1024 * 1024
    }

    private func hintBoundaryDuration(_ preset: TGMediaVideoConversionPreset, otherwiseBelow other: TGMediaVideoConversionPreset) -> Double? {
        var duration = 1.0
        while duration < 3600.0 {
            if estimatedSizeHint(preset, duration: duration, hasAudio: true) && !estimatedSizeHint(other, duration: duration, hasAudio: true) {
                return duration
            }
            duration += 1.0
        }
        return nil
    }

    func testUneditedVideoUsesConverterPresetFromPreferredDefault() throws {
        try withPreferredVideoPreset(5) {
            let file = try XCTUnwrap(build([video("v1", CGSize(width: 1280.0, height: 720.0))])[0].media as? TelegramMediaFile)
            XCTAssertEqual(videoAttribute(file)?.size, PixelDimensions(width: 1280, height: 720))

            let large = try XCTUnwrap(build([video("v2", CGSize(width: 3840.0, height: 2160.0))])[0].media as? TelegramMediaFile)
            XCTAssertEqual(videoAttribute(large)?.size, PixelDimensions(width: 1920, height: 1072))

            let temp = ChatMediaSendItem(uniqueId: "t1", source: .tempVideo(path: "/tmp/t1.mp4", dimensions: PixelDimensions(width: 1280, height: 720), duration: 5.0), options: ChatMediaSendItemOptions())
            let tempFile = try XCTUnwrap(build([temp])[0].media as? TelegramMediaFile)
            XCTAssertEqual(videoAttribute(tempFile)?.size, PixelDimensions(width: 1280, height: 720))

            let duration = try XCTUnwrap(hintBoundaryDuration(TGMediaVideoConversionPresetCompressedHigh, otherwiseBelow: TGMediaVideoConversionPresetCompressedMedium))
            let timed = try XCTUnwrap(build([video("v3", CGSize(width: 1280.0, height: 720.0), duration: duration)])[0].media as? TelegramMediaFile)
            XCTAssertTrue(hasHintFileIsLarge(timed))
        }
        try withPreferredVideoPreset(4) {
            let file = try XCTUnwrap(build([video("v1", CGSize(width: 1080.0, height: 1920.0))])[0].media as? TelegramMediaFile)
            XCTAssertEqual(videoAttribute(file)?.size, PixelDimensions(width: 720, height: 1280))
        }
        try withPreferredVideoPreset(nil) {
            let file = try XCTUnwrap(build([video("v1", CGSize(width: 1280.0, height: 720.0))])[0].media as? TelegramMediaFile)
            XCTAssertEqual(videoAttribute(file)?.size, PixelDimensions(width: 848, height: 464))
        }
    }

    func testUneditedVideoPresetMatchesConverterResolution() {
        let sizes: [CGSize] = [CGSize(width: 640.0, height: 360.0), CGSize(width: 1280.0, height: 720.0), CGSize(width: 1920.0, height: 1080.0), CGSize(width: 3840.0, height: 2160.0), .zero]
        for stored in [nil, 1, 2, 3, 4, 5] as [Int?] {
            withPreferredVideoPreset(stored) {
                for size in sizes {
                    var expected = TGMediaVideoConverter.preset(from: nil)
                    if size != .zero {
                        let best = TGMediaVideoConverter.bestAvailablePreset(forDimensions: size)
                        if expected.rawValue > best.rawValue {
                            expected = best
                        }
                    }
                    XCTAssertEqual(chatMediaSendUneditedVideoConversionPreset(dimensions: size).rawValue, expected.rawValue, "\(String(describing: stored)) \(size)")
                }
            }
        }
    }

    func testMutedVideoSendsAnimationPreset() throws {
        let values = chatMediaEditorValues(peerId: testPeerId, originalDimensions: PixelDimensions(width: 3840, height: 2160), qualityPreset: .compressedVeryHigh).withUpdatedVideoIsMuted(true)
        var item = video("v1", CGSize(width: 3840.0, height: 2160.0), duration: 60.0, options: ChatMediaSendItemOptions(isMuted: true))
        item.values = values
        let file = try XCTUnwrap(build([item])[0].media as? TelegramMediaFile)
        let resource = try XCTUnwrap(file.resource as? VideoLibraryMediaResource)
        guard case let .compress(adjustments) = resource.conversion, let adjustments else {
            XCTFail()
            return
        }
        let sent = try XCTUnwrap(videoMediaResourceEditorValues(adjustments: adjustments, alwaysUseModernPipeline: false, defaultPreset: .compressedMedium).values)
        XCTAssertEqual(sent.qualityPreset, .animation)
        XCTAssertTrue(sent.videoIsMuted)
        let size = try XCTUnwrap(videoAttribute(file)?.size)
        XCTAssertEqual(size, chatMediaEditorVideoFileDimensions(values: sent, duration: 60.0))
        XCTAssertEqual(max(size.width, size.height), 848)
        XCTAssertEqual(hasHintFileIsLarge(file), estimatedSizeHint(TGMediaVideoConversionPresetAnimation, duration: 60.0, hasAudio: false))
        XCTAssertFalse(hasHintFileIsLarge(file))
        XCTAssertTrue(file.attributes.contains(where: { if case .Animated = $0 { return true } else { return false } }))

        var unmuted = video("v2", CGSize(width: 3840.0, height: 2160.0), duration: 60.0)
        unmuted.values = values.withUpdatedVideoIsMuted(false)
        let unmutedFile = try XCTUnwrap(build([unmuted])[0].media as? TelegramMediaFile)
        XCTAssertEqual(videoAttribute(unmutedFile)?.size, PixelDimensions(width: 1920, height: 1080))
        XCTAssertTrue(hasHintFileIsLarge(unmutedFile))

        var temp = ChatMediaSendItem(uniqueId: "t1", source: .tempVideo(path: "/tmp/t1.mp4", dimensions: PixelDimensions(width: 3840, height: 2160), duration: 60.0), options: ChatMediaSendItemOptions(isMuted: true))
        temp.values = values
        let tempFile = try XCTUnwrap(build([temp])[0].media as? TelegramMediaFile)
        let tempValues = try XCTUnwrap(decodedValues(tempFile))
        XCTAssertEqual(tempValues.qualityPreset, .animation)
        XCTAssertEqual(videoAttribute(tempFile)?.size, size)
    }

    func testUneditedVideoStickers() throws {
        var item = video("v1")
        let sticker = TelegramMediaFile(fileId: EngineMedia.Id(namespace: Namespaces.Media.CloudFile, id: 7), partialReference: nil, resource: LocalFileMediaResource(fileId: 7), previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "application/x-tgsticker", size: nil, attributes: [], alternativeRepresentations: [])
        item.stickers = [sticker]
        let message = build([item])[0]
        let file = try XCTUnwrap(message.media as? TelegramMediaFile)
        XCTAssertTrue(file.attributes.contains(where: { if case .HasLinkedStickers = $0 { return true } else { return false } }))
        XCTAssertTrue(message.attributes.first is EmbeddedMediaStickersMessageAttribute)
    }

    func testEditedLibraryVideoJSONAdjustments() throws {
        let values = chatMediaEditorValues(peerId: testPeerId, originalDimensions: PixelDimensions(width: 1920, height: 1080), qualityPreset: .compressedMedium).withUpdatedVideoTrimRange(1.0 ..< 4.0)
        var item = video("v1", duration: 10.0)
        item.values = values
        let file = try XCTUnwrap(build([item])[0].media as? TelegramMediaFile)
        let resource = try XCTUnwrap(file.resource as? VideoLibraryMediaResource)
        XCTAssertEqual(resource.localIdentifier, "v1")
        guard case let .compress(adjustments) = resource.conversion, let adjustments else {
            XCTFail()
            return
        }
        XCTAssertFalse(adjustments.isStory)
        let decoded = videoMediaResourceEditorValues(adjustments: adjustments, alwaysUseModernPipeline: false, defaultPreset: .compressedMedium)
        XCTAssertNil(decoded.legacy)
        XCTAssertEqual(decoded.values?.videoTrimRange, 1.0 ..< 4.0)
        let videoInfo = try XCTUnwrap(videoAttribute(file))
        XCTAssertEqual(videoInfo.duration, 3.0)
        XCTAssertEqual(videoInfo.size, chatMediaEditorVideoFileDimensions(values: values, duration: 10.0))
        XCTAssertEqual(fileName(file), "video.mp4")
    }

    func testMutedVideoAttributes() throws {
        let values = chatMediaEditorValues(peerId: testPeerId, originalDimensions: PixelDimensions(width: 1920, height: 1080), qualityPreset: .compressedMedium).withUpdatedVideoIsMuted(true)
        var item = video("v1", options: ChatMediaSendItemOptions(isMuted: true))
        item.values = values
        item.fileName = "clip.mov"
        let file = try XCTUnwrap(build([item])[0].media as? TelegramMediaFile)
        var kinds: [String] = []
        for attribute in file.attributes {
            switch attribute {
            case .FileName:
                kinds.append("name")
            case let .Video(_, _, flags, _, _, _):
                XCTAssertTrue(flags.contains(.supportsStreaming))
                kinds.append("video")
            case .Animated:
                kinds.append("animated")
            default:
                kinds.append("other")
            }
        }
        XCTAssertEqual(kinds, ["name", "video", "animated"])

        var unmuted = video("v2")
        unmuted.values = values.withUpdatedVideoIsMuted(false)
        let plainFile = try XCTUnwrap(build([unmuted])[0].media as? TelegramMediaFile)
        XCTAssertFalse(plainFile.attributes.contains(where: { if case .Animated = $0 { return true } else { return false } }))
    }

    func testTempVideoUsesLocalFileResource() throws {
        let unedited = ChatMediaSendItem(uniqueId: "t1", source: .tempVideo(path: "/tmp/t1.mp4", dimensions: PixelDimensions(width: 1280, height: 720), duration: 5.0), options: ChatMediaSendItemOptions())
        let file = try XCTUnwrap(build([unedited])[0].media as? TelegramMediaFile)
        let resource = try XCTUnwrap(file.resource as? LocalFileVideoMediaResource)
        XCTAssertEqual(resource.paths, ["/tmp/t1.mp4"])
        XCTAssertNil(resource.adjustments)
        XCTAssertEqual(videoAttribute(file)?.size, PixelDimensions(width: 848, height: 464))
        XCTAssertEqual(videoAttribute(file)?.duration, 5.0)

        let values = chatMediaEditorValues(peerId: testPeerId, originalDimensions: PixelDimensions(width: 1280, height: 720), qualityPreset: .compressedHigh)
        var edited = unedited
        edited.values = values
        let editedFile = try XCTUnwrap(build([edited])[0].media as? TelegramMediaFile)
        let editedResource = try XCTUnwrap(editedFile.resource as? LocalFileVideoMediaResource)
        XCTAssertEqual(editedResource.adjustments?.isStory, false)
        XCTAssertEqual(videoAttribute(editedFile)?.size, chatMediaEditorVideoFileDimensions(values: values, duration: 5.0))
    }

    func testRenderedPhotoUsesStageOnePath() throws {
        let values = chatMediaEditorValues(peerId: testPeerId, originalDimensions: PixelDimensions(width: 2000, height: 1500), qualityPreset: .compressedMedium)
        var item = photo("p1", CGSize(width: 2000.0, height: 1500.0))
        item.values = values
        item.renderedImage = testImage(2000, 1500)
        let image = try XCTUnwrap(build([item])[0].media as? TelegramMediaImage)
        XCTAssertTrue(image.representations.last?.resource is LocalFileReferenceMediaResource)
        XCTAssertEqual(image.representations.last?.dimensions, PixelDimensions(width: 1280, height: 960))

        let hd = try XCTUnwrap(build([item], forceHd: true)[0].media as? TelegramMediaImage)
        XCTAssertEqual(hd.representations.last?.dimensions, PixelDimensions(width: 2000, height: 1500))

        let pasted = ChatMediaSendItem(uniqueId: "x", source: .image(testImage(600, 400)), options: ChatMediaSendItemOptions())
        let pastedImage = try XCTUnwrap(build([pasted])[0].media as? TelegramMediaImage)
        XCTAssertTrue(pastedImage.representations.last?.resource is LocalFileReferenceMediaResource)
        XCTAssertEqual(pastedImage.representations.last?.dimensions, PixelDimensions(width: 600, height: 400))
    }

    func testHdAppliesToEditedAndLibraryPhotos() throws {
        let values = chatMediaEditorValues(peerId: testPeerId, originalDimensions: PixelDimensions(width: 4000, height: 3000), qualityPreset: .compressedMedium)
        var edited = photo("edited", CGSize(width: 4000.0, height: 3000.0))
        edited.values = values
        edited.renderedImage = testImage(4000, 3000)
        let library = photo("library", CGSize(width: 4000.0, height: 3000.0))
        let pasted = ChatMediaSendItem(uniqueId: "pasted", source: .image(testImage(4000, 3000)), options: ChatMediaSendItemOptions())

        let hd = build([edited, library, pasted], forceHd: true)
        let hdEdited = try XCTUnwrap(hd[0].media as? TelegramMediaImage)
        XCTAssertEqual(hdEdited.representations.last?.dimensions, PixelDimensions(width: 2560, height: 1920))
        let hdLibrary = try XCTUnwrap(hd[1].media as? TelegramMediaImage)
        XCTAssertEqual((hdLibrary.representations.last?.resource as? PhotoLibraryMediaResource)?.forceHd, true)
        let hdPasted = try XCTUnwrap(hd[2].media as? TelegramMediaImage)
        XCTAssertEqual(hdPasted.representations.last?.dimensions, PixelDimensions(width: 2560, height: 1920))

        let sd = build([edited, library, pasted], forceHd: false)
        XCTAssertEqual((sd[0].media as? TelegramMediaImage)?.representations.last?.dimensions, PixelDimensions(width: 1280, height: 960))
        XCTAssertEqual(((sd[1].media as? TelegramMediaImage)?.representations.last?.resource as? PhotoLibraryMediaResource)?.forceHd, false)
        XCTAssertEqual((sd[2].media as? TelegramMediaImage)?.representations.last?.dimensions, PixelDimensions(width: 1280, height: 960))
    }

    func testHdNotForLivePhotoOrAnimatedPhoto() throws {
        XCTAssertTrue(ChatMediaSendItemOptions().allowsHd)
        XCTAssertFalse(ChatMediaSendItemOptions(isAnimation: true).allowsHd)
        XCTAssertFalse(ChatMediaSendItemOptions(hasAnimatedPainting: true).allowsHd)
        XCTAssertFalse(ChatMediaSendItemOptions(livePhotoLoopOrBounce: true).allowsHd)
        XCTAssertFalse(ChatMediaSendItemOptions(isLivePhoto: true).allowsHd)

        let live = photo("live", options: ChatMediaSendItemOptions(isLivePhoto: true))
        let animated = photo("animated", options: ChatMediaSendItemOptions(hasAnimatedPainting: true))
        let plain = photo("plain")
        let built = build([live, animated, plain], forceHd: true)
        XCTAssertEqual(((built[0].media as? TelegramMediaImage)?.representations.last?.resource as? PhotoLibraryMediaResource)?.forceHd, false)
        XCTAssertEqual(((built[1].media as? TelegramMediaImage)?.representations.last?.resource as? PhotoLibraryMediaResource)?.forceHd, false)
        XCTAssertEqual(((built[2].media as? TelegramMediaImage)?.representations.last?.resource as? PhotoLibraryMediaResource)?.forceHd, true)
    }

    func testHdPersistedOnSend() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "chat-media-send-hd-tests"))
        defaults.removePersistentDomain(forName: "chat-media-send-hd-tests")
        XCTAssertFalse(chatMediaSendInitialHighQualityPhoto(defaults: defaults))
        chatMediaSendPersistHighQualityPhoto(true, defaults: defaults)
        XCTAssertTrue(defaults.bool(forKey: "TG_photoHighQuality_v0"))
        XCTAssertTrue(chatMediaSendInitialHighQualityPhoto(defaults: defaults))
        chatMediaSendPersistHighQualityPhoto(false, defaults: defaults)
        XCTAssertFalse(chatMediaSendInitialHighQualityPhoto(defaults: defaults))
        defaults.removePersistentDomain(forName: "chat-media-send-hd-tests")
    }

    func testCoverImageBecomesVideoCover() throws {
        var item = video("v1")
        item.coverImage = testImage(640, 360)
        let file = try XCTUnwrap(build([item])[0].media as? TelegramMediaFile)
        let cover = try XCTUnwrap(file.videoCover)
        XCTAssertEqual(cover.imageId, EngineMedia.Id(namespace: 0, id: 0))
        XCTAssertEqual(cover.representations.count, 1)
        XCTAssertEqual(cover.representations[0].dimensions, PixelDimensions(width: 1280, height: 720))
        let resource = try XCTUnwrap(cover.representations[0].resource as? LocalFileMediaResource)
        XCTAssertTrue(self.storedIds.contains(EngineMediaResource.Id(resource.id)))

        var temp = ChatMediaSendItem(uniqueId: "t", source: .tempVideo(path: "/tmp/t.mp4", dimensions: PixelDimensions(width: 1280, height: 720), duration: 3.0), options: ChatMediaSendItemOptions())
        temp.values = chatMediaEditorValues(peerId: testPeerId, originalDimensions: PixelDimensions(width: 1280, height: 720), qualityPreset: .compressedMedium)
        temp.coverImage = testImage(2560, 1440)
        let tempFile = try XCTUnwrap(build([temp])[0].media as? TelegramMediaFile)
        XCTAssertEqual(tempFile.videoCover?.representations.first?.dimensions, PixelDimensions(width: 1280, height: 720))
    }

    private func coverTime(_ file: TelegramMediaFile) -> Double?? {
        for attribute in file.attributes {
            if case let .Video(_, _, _, _, coverTime, _) = attribute {
                return .some(coverTime)
            }
        }
        return nil
    }

    func testCoverStoredAndSent() throws {
        let cover = testImage(2560, 1440)
        var item = video("v1")
        item.coverImage = cover
        let file = try XCTUnwrap(build([item])[0].media as? TelegramMediaFile)
        let videoCover = try XCTUnwrap(file.videoCover)
        XCTAssertEqual(videoCover.imageId, EngineMedia.Id(namespace: 0, id: 0))
        XCTAssertEqual(videoCover.representations.count, 1)
        XCTAssertEqual(videoCover.representations[0].dimensions, PixelDimensions(width: 1280, height: 720))
        let resource = try XCTUnwrap(videoCover.representations[0].resource as? LocalFileMediaResource)
        let data = try XCTUnwrap(self.storedData[EngineMediaResource.Id(resource.id)])
        let expectedImage = try XCTUnwrap(TGScaleImageToPixelSize(cover, CGSize(width: 1280.0, height: 720.0)))
        XCTAssertEqual(data, expectedImage.jpegData(compressionQuality: 0.87))
        XCTAssertNotEqual(data, expectedImage.jpegData(compressionQuality: 0.6))
        let decoded = try XCTUnwrap(UIImage(data: data))
        XCTAssertEqual(decoded.size, CGSize(width: 1280.0, height: 720.0))

        let uncovered = try XCTUnwrap(build([video("v2")])[0].media as? TelegramMediaFile)
        XCTAssertNil(uncovered.videoCover)
    }

    func testCoverTimeNeverSet() throws {
        let values = chatMediaEditorValues(peerId: testPeerId, originalDimensions: PixelDimensions(width: 1920, height: 1080), qualityPreset: .compressedMedium).withUpdatedVideoTrimRange(2.0 ..< 10.0).withUpdatedCoverImageTimestamp(5.0)
        XCTAssertEqual(values.coverImageTimestamp, 5.0)

        var unedited = video("u")
        unedited.coverImage = testImage(640, 360)
        var edited = video("e")
        edited.values = values
        edited.coverImage = testImage(640, 360)
        var temp = ChatMediaSendItem(uniqueId: "t", source: .tempVideo(path: "/tmp/t.mp4", dimensions: PixelDimensions(width: 1920, height: 1080), duration: 12.0), options: ChatMediaSendItemOptions())
        temp.values = values
        temp.coverImage = testImage(640, 360)
        var tempUnedited = ChatMediaSendItem(uniqueId: "tu", source: .tempVideo(path: "/tmp/tu.mp4", dimensions: PixelDimensions(width: 1920, height: 1080), duration: 12.0), options: ChatMediaSendItemOptions())
        tempUnedited.coverImage = testImage(640, 360)

        let messages = build([unedited, edited, temp, tempUnedited])
        XCTAssertEqual(messages.count, 4)
        for message in messages {
            let file = try XCTUnwrap(message.media as? TelegramMediaFile)
            XCTAssertNotNil(file.videoCover)
            let time = try XCTUnwrap(self.coverTime(file))
            XCTAssertNil(time)
        }
    }

    func testTimerAttributeLimits() {
        let messages = build([
            photo("a", CGSize(width: 100.0, height: 100.0), options: ChatMediaSendItemOptions(timer: 30)),
            photo("b", CGSize(width: 100.0, height: 100.0), options: ChatMediaSendItemOptions(timer: 120)),
            video("c", options: ChatMediaSendItemOptions(timer: viewOnceTimeout))
        ])
        let timeouts = messages.map { message in
            message.attributes.compactMap { ($0 as? AutoremoveTimeoutMessageAttribute)?.timeout }.first
        }
        XCTAssertEqual(timeouts, [30, nil, viewOnceTimeout])
        XCTAssertEqual(messages.map { $0.groupingKey }, [nil, nil, nil])
    }

    func testSpoilerAttribute() {
        let messages = build([
            photo("a", CGSize(width: 100.0, height: 100.0), options: ChatMediaSendItemOptions(spoiler: true)),
            video("b", options: ChatMediaSendItemOptions(spoiler: true)),
            photo("c", CGSize(width: 100.0, height: 100.0))
        ])
        XCTAssertEqual(messages.map { $0.attributes.contains(where: { $0 is MediaSpoilerMessageAttribute }) }, [true, true, false])
    }

    func testAttributeOrderMatchesLegacy() {
        let caption = NSMutableAttributedString(string: "bold")
        caption.addAttribute(ChatTextInputAttributes.bold, value: true as NSNumber, range: NSRange(location: 0, length: 4))
        var item = video("v", options: ChatMediaSendItemOptions(caption: caption, timer: 10, spoiler: true))
        item.stickers = [TelegramMediaFile(fileId: EngineMedia.Id(namespace: Namespaces.Media.CloudFile, id: 7), partialReference: nil, resource: LocalFileMediaResource(fileId: 7), previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "application/x-tgsticker", size: nil, attributes: [], alternativeRepresentations: [])]
        let message = build([item])[0]
        XCTAssertEqual(message.text, "bold")
        XCTAssertEqual(message.attributes.count, 4)
        XCTAssertTrue(message.attributes[0] is EmbeddedMediaStickersMessageAttribute)
        XCTAssertTrue(message.attributes[1] is AutoremoveTimeoutMessageAttribute)
        XCTAssertTrue(message.attributes[2] is MediaSpoilerMessageAttribute)
        XCTAssertTrue(message.attributes[3] is TextEntitiesMessageAttribute)
    }

    func testPriceAggregatesIntoOnePaidMessage() throws {
        let bold = NSMutableAttributedString(string: "second")
        bold.addAttribute(ChatTextInputAttributes.bold, value: true as NSNumber, range: NSRange(location: 0, length: 6))
        let messages = build([
            photo("a", CGSize(width: 100.0, height: 100.0), options: ChatMediaSendItemOptions(caption: NSAttributedString(string: ""), spoiler: true)),
            video("b", options: ChatMediaSendItemOptions(caption: bold, price: 25)),
            photo("c", CGSize(width: 100.0, height: 100.0), options: ChatMediaSendItemOptions(caption: NSAttributedString(string: "third")))
        ], grouping: true)
        XCTAssertEqual(messages.count, 1)
        let paid = try XCTUnwrap(messages[0].media as? TelegramMediaPaidContent)
        XCTAssertEqual(paid.amount, 25)
        XCTAssertEqual(paid.extendedMedia.count, 3)
        let media: [EngineRawMedia] = paid.extendedMedia.compactMap { extended in
            if case let .full(media) = extended {
                return media
            }
            return nil
        }
        XCTAssertTrue(media[0] is TelegramMediaImage)
        XCTAssertTrue(media[1] is TelegramMediaFile)
        XCTAssertTrue(media[2] is TelegramMediaImage)
        XCTAssertEqual(messages[0].text, "second")
        XCTAssertEqual(messages[0].attributes.count, 1)
        XCTAssertEqual((messages[0].attributes[0] as? TextEntitiesMessageAttribute)?.entities.count, 1)
        XCTAssertNil(messages[0].groupingKey)
        XCTAssertNil(messages[0].uniqueId)
        XCTAssertFalse(messages[0].isFile)
    }

    func testUniqueIdPassedThrough() {
        let messages = build([photo("asset-1", CGSize(width: 100.0, height: 100.0)), video("asset-2")])
        XCTAssertEqual(messages.map { $0.uniqueId }, ["asset-1", "asset-2"])
    }

    func testOrderPreserved() {
        let items = [
            video("v1"),
            photo("p1", CGSize(width: 100.0, height: 100.0)),
            ChatMediaSendItem(uniqueId: "x1", source: .image(testImage(50, 50)), options: ChatMediaSendItemOptions(caption: NSAttributedString(string: "pasted"))),
            ChatMediaSendItem(uniqueId: "t1", source: .tempVideo(path: "/tmp/t1.mp4", dimensions: PixelDimensions(width: 640, height: 480), duration: 2.0), options: ChatMediaSendItemOptions()),
            photo("p2", CGSize(width: 100.0, height: 100.0))
        ]
        let messages = build(items, grouping: true, forcedCaption: "all")
        XCTAssertEqual(messages.map { $0.uniqueId }, ["v1", "p1", "x1", "t1", "p2"])
        XCTAssertEqual(messages.map { $0.media is TelegramMediaFile }, [true, false, false, true, false])
        XCTAssertEqual(messages.map { $0.groupingKey }, [101, 101, 101, 101, 101])
        XCTAssertEqual(messages.map { $0.text }, ["all", "", "", "", ""])
    }

    func testGifAttributes() throws {
        let messages = build([photo("p1"), gif("g1"), photo("p2")], grouping: true)
        XCTAssertEqual(messages.map { $0.uniqueId }, ["p1", "g1", "p2"])
        XCTAssertEqual(messages.map { $0.groupingKey }, [101, nil, 101])

        let file = try XCTUnwrap(messages[1].media as? TelegramMediaFile)
        XCTAssertEqual(file.mimeType, "video/mp4")
        let resource = try XCTUnwrap(file.resource as? LocalFileVideoMediaResource)
        XCTAssertEqual(resource.paths, ["/tmp/g1.mp4"])
        var kinds: [String] = []
        for attribute in file.attributes {
            switch attribute {
            case let .FileName(fileName):
                XCTAssertEqual(fileName, "video.mp4")
                kinds.append("name")
            case let .Video(duration, size, flags, _, _, _):
                XCTAssertEqual(flags, [.supportsStreaming])
                XCTAssertEqual(duration, 2.5)
                let values = try XCTUnwrap(decodedValues(file))
                XCTAssertEqual(size, chatMediaEditorVideoFileDimensions(values: values, duration: 2.5))
                kinds.append("video")
            case .Animated:
                kinds.append("animated")
            default:
                kinds.append("other")
            }
        }
        XCTAssertEqual(kinds, ["name", "video", "animated"])
        XCTAssertFalse(file.attributes.contains(where: { if case .HasLinkedStickers = $0 { return true } else { return false } }))

        for duration in [60.0, 120.0, 600.0] {
            let longFile = try XCTUnwrap(build([gif("g", duration: duration)])[0].media as? TelegramMediaFile)
            let expected = TGMediaVideoConverter.estimatedSize(for: TGMediaVideoConversionPresetAnimation, duration: duration, hasAudio: false) > 10 * 1024 * 1024
            XCTAssertEqual(hasHintFileIsLarge(longFile), expected)
        }

        XCTAssertEqual(build([gif("g2", converted: false), photo("p3")]).map { $0.uniqueId }, ["p3"])
    }

    func testGifValuesAnimationPresetMuted() throws {
        let file = try XCTUnwrap(build([gif("g1")])[0].media as? TelegramMediaFile)
        let values = try XCTUnwrap(decodedValues(file))
        XCTAssertEqual(values.qualityPreset, .animation)
        XCTAssertTrue(values.videoIsMuted)
        XCTAssertEqual(values.originalDimensions, PixelDimensions(width: 480, height: 272))
        XCTAssertNil(values.videoTrimRange)

        var edited = gif("g2")
        edited.values = chatMediaEditorValues(peerId: testPeerId, originalDimensions: PixelDimensions(width: 480, height: 272), qualityPreset: .compressedHigh).withUpdatedVideoTrimRange(0.5 ..< 2.0)
        let editedFile = try XCTUnwrap(build([edited])[0].media as? TelegramMediaFile)
        let editedValues = try XCTUnwrap(decodedValues(editedFile))
        XCTAssertEqual(editedValues.qualityPreset, .animation)
        XCTAssertTrue(editedValues.videoIsMuted)
        XCTAssertEqual(editedValues.videoTrimRange, 0.5 ..< 2.0)
        XCTAssertEqual(videoAttribute(editedFile)?.duration, 1.5)
        XCTAssertEqual(videoAttribute(editedFile)?.size, chatMediaEditorVideoFileDimensions(values: editedValues, duration: 2.5))
    }
}
