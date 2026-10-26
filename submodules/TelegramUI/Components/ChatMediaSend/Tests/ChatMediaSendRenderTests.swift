import Foundation
import UIKit
import XCTest
import SwiftSignalKit
import ImageIO
import TelegramCore
import MediaEditor
import LegacyMediaPickerUI
import LocalMediaResources
import FetchVideoMediaResource
@testable import ChatMediaSend

private let renderTestPeerId = EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(1))

private let renderTestTempBoxInitialized: Void = {
    EngineTempBox.initializeShared(basePath: NSTemporaryDirectory() + "chat-media-send-render-tests", processType: "tests", launchSpecificId: 1)
}()

private func renderTestImage(_ width: Int, _ height: Int) -> UIImage {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1.0
    return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { context in
        UIColor.red.setFill()
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    }
}

private final class FakeRenderer: ChatMediaSendRendering {
    private let lock = NSLock()
    private let failing: Set<String>
    private let delay: Double?
    private let progressSteps: [Float]
    private var inFlight = 0
    private(set) var maxInFlight = 0
    private(set) var renderedIds: [String] = []
    private(set) var forceHdValues: [Bool] = []

    init(failing: Set<String> = Set(), delay: Double? = nil, progressSteps: [Float] = []) {
        self.failing = failing
        self.delay = delay
        self.progressSteps = progressSteps
    }

    func renderPhoto(item: ChatMediaSendItem, forceHd: Bool) -> Signal<ChatMediaSendRenderEvent, NoError> {
        let failing = self.failing
        let delay = self.delay
        let progressSteps = self.progressSteps
        return Signal { [self] subscriber in
            self.lock.lock()
            self.renderedIds.append(item.uniqueId)
            self.forceHdValues.append(forceHd)
            self.inFlight += 1
            self.maxInFlight = max(self.maxInFlight, self.inFlight)
            self.lock.unlock()

            let finish = {
                for step in progressSteps {
                    subscriber.putNext(.progress(step))
                }
                self.lock.lock()
                self.inFlight -= 1
                self.lock.unlock()
                subscriber.putNext(.result(failing.contains(item.uniqueId) ? nil : renderTestImage(400, 300)))
                subscriber.putCompletion()
            }
            if let delay {
                DispatchQueue.global().asyncAfter(deadline: .now() + delay, execute: finish)
            } else {
                finish()
            }
            return EmptyDisposable
        }
    }
}

private final class FakeGifConverter: ChatMediaSendGifConverting {
    private let lock = NSLock()
    private let results: [String: ChatMediaSendConvertedGif]
    private let completingEmpty: Set<String>
    private(set) var requestedIds: [String] = []

    init(results: [String: ChatMediaSendConvertedGif], completingEmpty: Set<String> = Set()) {
        self.results = results
        self.completingEmpty = completingEmpty
    }

    func convertGif(identifier: String) -> Signal<ChatMediaSendConvertedGif?, NoError> {
        let result = self.results[identifier]
        let completesEmpty = self.completingEmpty.contains(identifier)
        return Signal { [self] subscriber in
            self.lock.lock()
            self.requestedIds.append(identifier)
            self.lock.unlock()
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) {
                if !completesEmpty {
                    subscriber.putNext(result)
                }
                subscriber.putCompletion()
            }
            return EmptyDisposable
        }
    }
}

private func renderTestGifData(frames: Int, size: Int) -> Data {
    let data = NSMutableData()
    let destination = CGImageDestinationCreateWithData(data as CFMutableData, "com.compuserve.gif" as CFString, frames, nil)!
    for index in 0 ..< frames {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let image = UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: format).image { context in
            (index % 2 == 0 ? UIColor.red : UIColor.blue).setFill()
            context.fill(CGRect(x: 0, y: 0, width: size, height: size))
        }
        CGImageDestinationAddImage(destination, image.cgImage!, [kCGImagePropertyGIFDictionary as String: [kCGImagePropertyGIFDelayTime as String: 0.1]] as CFDictionary)
    }
    CGImageDestinationFinalize(destination)
    return data as Data
}

final class ChatMediaSendRenderTests: XCTestCase {
    private var writtenPaths: [String] = []

    override func setUp() {
        super.setUp()
        let _ = renderTestTempBoxInitialized
    }

    override func tearDown() {
        for path in self.writtenPaths {
            try? FileManager.default.removeItem(atPath: path)
        }
        self.writtenPaths = []
        super.tearDown()
    }

    private func photo(_ id: String, edited: Bool = false, options: ChatMediaSendItemOptions = ChatMediaSendItemOptions()) -> ChatMediaSendItem {
        var item = ChatMediaSendItem(uniqueId: id, source: .libraryAsset(identifier: id, pixelSize: CGSize(width: 400.0, height: 300.0), isVideo: false, duration: 0.0), options: options)
        if edited {
            item.values = chatMediaEditorValues(peerId: renderTestPeerId, originalDimensions: PixelDimensions(width: 400, height: 300), qualityPreset: .compressedMedium)
        }
        return item
    }

    private func video(_ id: String, values: MediaEditorValues? = nil) -> ChatMediaSendItem {
        var item = ChatMediaSendItem(uniqueId: id, source: .libraryAsset(identifier: id, pixelSize: CGSize(width: 1920.0, height: 1080.0), isVideo: true, duration: 10.0), options: ChatMediaSendItemOptions())
        item.values = values
        return item
    }

    private func send(_ items: [ChatMediaSendItem], renderer: ChatMediaSendRendering, grouping: Bool = false, forcedCaption: NSAttributedString? = nil, forceHd: Bool = false) -> ChatMediaSendOutcome? {
        return self.sendCollectingProgress(items, renderer: renderer, grouping: grouping, forcedCaption: forcedCaption, forceHd: forceHd).outcome
    }

    private func sendCollectingProgress(_ items: [ChatMediaSendItem], renderer: ChatMediaSendRendering, grouping: Bool = false, forcedCaption: NSAttributedString? = nil, forceHd: Bool = false) -> (outcome: ChatMediaSendOutcome?, progress: [Float], progressAfterOutcome: Bool) {
        var next: Int64 = 100
        let expectation = self.expectation(description: "outcome")
        var outcome: ChatMediaSendOutcome?
        var progress: [Float] = []
        var progressAfterOutcome = false
        let disposable = chatMediaSendMessages(items: items, global: ChatMediaSendGlobalOptions(grouping: grouping, forcedCaption: forcedCaption, forceHd: forceHd), renderer: renderer, makeGroupingKey: {
            next += 1
            return next
        }, storeResourceData: { _, _ in }).start(next: { event in
            switch event {
            case let .progress(value):
                if outcome != nil {
                    progressAfterOutcome = true
                }
                progress.append(value)
            case let .outcome(value):
                outcome = value
                expectation.fulfill()
            }
        })
        self.wait(for: [expectation], timeout: 10.0)
        disposable.dispose()
        for message in outcome?.messages ?? [] {
            if case let .message(_, _, _, mediaReference, _, _, _, _, _, _) = message.message, let image = mediaReference?.media as? TelegramMediaImage {
                for representation in image.representations {
                    if let resource = representation.resource as? LocalFileReferenceMediaResource {
                        self.writtenPaths.append(resource.localFilePath)
                    }
                }
            }
        }
        return (outcome, progress, progressAfterOutcome)
    }

    private func groupingKeys(_ outcome: ChatMediaSendOutcome) -> [Int64?] {
        return outcome.messages.map { message in
            if case let .message(_, _, _, _, _, _, _, groupingKey, _, _) = message.message {
                return groupingKey
            }
            return nil
        }
    }

    private func media(_ message: LegacyAssetPickerEnqueueMessage) -> EngineRawMedia? {
        if case let .message(_, _, _, mediaReference, _, _, _, _, _, _) = message.message {
            return mediaReference?.media
        }
        return nil
    }

    func testUnavailableItemDroppedOthersKeepOrder() throws {
        let renderer = FakeRenderer(failing: ["p2"])
        let outcome = try XCTUnwrap(send([photo("p1"), photo("p2", edited: true), photo("p3", edited: true), video("v4")], renderer: renderer))
        XCTAssertEqual(outcome.messages.map { $0.uniqueId }, ["p1", "p3", "v4"])
        XCTAssertEqual(outcome.droppedUniqueIds, ["p2"])
        let rendered = try XCTUnwrap(media(outcome.messages[1]) as? TelegramMediaImage)
        XCTAssertTrue(rendered.representations.last?.resource is LocalFileReferenceMediaResource)
        let unedited = try XCTUnwrap(media(outcome.messages[0]) as? TelegramMediaImage)
        XCTAssertTrue(unedited.representations.last?.resource is PhotoLibraryMediaResource)
    }

    func testPlanComputedAfterDrops() throws {
        let renderer = FakeRenderer(failing: ["p2"])
        let outcome = try XCTUnwrap(send([photo("p1"), photo("p2", edited: true, options: ChatMediaSendItemOptions(timer: 10)), photo("p3")], renderer: renderer, grouping: true))
        XCTAssertEqual(outcome.droppedUniqueIds, ["p2"])
        XCTAssertEqual(outcome.messages.map { $0.uniqueId }, ["p1", "p3"])
        XCTAssertEqual(groupingKeys(outcome), [101, 101])
    }

    func testUneditedItemsNotRendered() throws {
        var prerendered = photo("p3", edited: true)
        prerendered.renderedImage = renderTestImage(400, 300)
        var pasted = ChatMediaSendItem(uniqueId: "i5", source: .image(renderTestImage(200, 100)), options: ChatMediaSendItemOptions())
        pasted.values = chatMediaEditorValues(peerId: renderTestPeerId, originalDimensions: PixelDimensions(width: 200, height: 100), qualityPreset: .compressedMedium)
        let pastedUnedited = ChatMediaSendItem(uniqueId: "i6", source: .image(renderTestImage(200, 100)), options: ChatMediaSendItemOptions())
        let editedVideo = video("v2", values: chatMediaEditorValues(peerId: renderTestPeerId, originalDimensions: PixelDimensions(width: 1920, height: 1080), qualityPreset: .compressedMedium))
        let renderer = FakeRenderer()
        let outcome = try XCTUnwrap(send([photo("p1"), editedVideo, prerendered, photo("p4", edited: true), pasted, pastedUnedited], renderer: renderer, forceHd: true))
        XCTAssertEqual(renderer.renderedIds, ["p4", "i5"])
        XCTAssertEqual(renderer.forceHdValues, [true, true])
        XCTAssertEqual(outcome.messages.map { $0.uniqueId }, ["p1", "v2", "p3", "p4", "i5", "i6"])
        XCTAssertEqual(outcome.droppedUniqueIds, [])
    }

    func testConcurrencyAtMostTwo() throws {
        let renderer = FakeRenderer(failing: ["p3"], delay: 0.05)
        let items = (0 ..< 7).map { photo("p\($0)", edited: true) }
        let outcome = try XCTUnwrap(send(items, renderer: renderer))
        XCTAssertEqual(renderer.maxInFlight, 2)
        XCTAssertEqual(Set(renderer.renderedIds), Set(items.map { $0.uniqueId }))
        XCTAssertEqual(renderer.renderedIds.count, 7)
        XCTAssertEqual(outcome.messages.map { $0.uniqueId }, ["p0", "p1", "p2", "p4", "p5", "p6"])
        XCTAssertEqual(outcome.droppedUniqueIds, ["p3"])
    }

    func testEditedVideoWithoutAdjustmentsDropped() throws {
        let broken = chatMediaEditorValues(peerId: renderTestPeerId, originalDimensions: PixelDimensions(width: 1920, height: 1080), qualityPreset: .compressedMedium).withUpdatedCropRect(cropRect: CGRect(x: 0.0, y: 0.0, width: 1920.0, height: 1080.0), rotation: .nan, mirroring: false)
        XCTAssertNil(chatMediaEditorVideoAdjustments(values: broken))
        var temp = ChatMediaSendItem(uniqueId: "t3", source: .tempVideo(path: "/tmp/t3.mp4", dimensions: PixelDimensions(width: 1280, height: 720), duration: 5.0), options: ChatMediaSendItemOptions())
        temp.values = broken
        let renderer = FakeRenderer()
        let outcome = try XCTUnwrap(send([video("v1", values: broken), photo("p2"), temp, video("v4")], renderer: renderer))
        XCTAssertEqual(outcome.messages.map { $0.uniqueId }, ["p2", "v4"])
        XCTAssertEqual(outcome.droppedUniqueIds, ["v1", "t3"])
        XCTAssertEqual(renderer.renderedIds, [])

        let direct = chatMediaSendBuildMessages(items: [video("v1", values: broken)], plan: chatMediaSendPlan(items: [ChatMediaSendItemOptions()], global: ChatMediaSendGlobalOptions(grouping: false), makeGroupingKey: { 1 }), forceHd: false, storeResourceData: { _, _ in })
        XCTAssertTrue(direct.isEmpty)
    }

    func testBuilderFailureReported() throws {
        let renderer = FakeRenderer(failing: ["p4"])
        let expectation = self.expectation(description: "outcome")
        var outcome: ChatMediaSendOutcome?
        let disposable = chatMediaSendMessages(items: [photo("p1"), photo("p2"), photo("p3"), photo("p4", edited: true), photo("p5")], global: ChatMediaSendGlobalOptions(grouping: false), renderer: renderer, makeGroupingKey: { 1 }, storeResourceData: { _, _ in }, buildMessages: { items, plan, forceHd, storeResourceData in
            let survivors = items.enumerated().filter { $0.element.uniqueId != "p2" && $0.element.uniqueId != "p5" }
            let built = chatMediaSendBuildMessagesReportingSkipped(items: survivors.map { $0.element }, plan: chatMediaSendPlan(items: survivors.map { $0.element.options }, global: ChatMediaSendGlobalOptions(grouping: false), makeGroupingKey: { 1 }), forceHd: forceHd, storeResourceData: storeResourceData)
            XCTAssertEqual(plan.count, 4)
            return (built.messages, [1, 3])
        }).start(next: { event in
            if case let .outcome(value) = event {
                outcome = value
                expectation.fulfill()
            }
        })
        self.wait(for: [expectation], timeout: 10.0)
        disposable.dispose()
        let result = try XCTUnwrap(outcome)
        XCTAssertEqual(result.messages.map { $0.uniqueId }, ["p1", "p3"])
        XCTAssertEqual(result.droppedUniqueIds, ["p2", "p4", "p5"])
    }

    func testOutcomeArrivesOffMainThread() throws {
        let renderer = FakeRenderer()
        let expectation = self.expectation(description: "outcome")
        var isMainThread = true
        let disposable = chatMediaSendMessages(items: [photo("p1", edited: true), photo("p2")], global: ChatMediaSendGlobalOptions(grouping: false), renderer: renderer, makeGroupingKey: { 1 }, storeResourceData: { _, _ in }).start(next: { event in
            if case .outcome = event {
                isMainThread = Thread.isMainThread
                expectation.fulfill()
            }
        })
        self.wait(for: [expectation], timeout: 10.0)
        disposable.dispose()
        XCTAssertFalse(isMainThread)
    }

    func testDisposeStartsNoFurtherRenders() {
        let renderer = FakeRenderer(delay: 0.1)
        let items = (0 ..< 6).map { photo("p\($0)", edited: true) }
        let outcome = self.expectation(description: "no outcome")
        outcome.isInverted = true
        let disposable = chatMediaSendMessages(items: items, global: ChatMediaSendGlobalOptions(grouping: false), renderer: renderer, makeGroupingKey: { 1 }, storeResourceData: { _, _ in }).start(next: { event in
            if case .outcome = event {
                outcome.fulfill()
            }
        })
        XCTAssertEqual(renderer.renderedIds.count, 2)
        disposable.dispose()
        self.wait(for: [outcome], timeout: 0.5)
        XCTAssertEqual(renderer.renderedIds, ["p0", "p1"])
    }

    func testProgressForSingleRenderedItem() throws {
        let renderer = FakeRenderer(progressSteps: [0.25, 0.5])
        let result = sendCollectingProgress([photo("p1"), photo("p2", edited: true)], renderer: renderer)
        let outcome = try XCTUnwrap(result.outcome)
        XCTAssertEqual(outcome.messages.map { $0.uniqueId }, ["p1", "p2"])
        XCTAssertEqual(result.progress, [0.25, 0.5, 1.0])
        XCTAssertFalse(result.progressAfterOutcome)
    }

    func testProgressMonotonicAcrossItemsIncludingFailures() throws {
        let renderer = FakeRenderer(failing: ["p2"], delay: 0.02, progressSteps: [0.3, 0.6])
        let items = (0 ..< 5).map { photo("p\($0)", edited: true) }
        let result = sendCollectingProgress(items + [photo("u")], renderer: renderer)
        let outcome = try XCTUnwrap(result.outcome)
        XCTAssertEqual(outcome.droppedUniqueIds, ["p2"])
        XCTAssertGreaterThanOrEqual(result.progress.count, 2)
        XCTAssertEqual(result.progress, result.progress.sorted())
        XCTAssertEqual(Set(result.progress).count, result.progress.count)
        XCTAssertTrue(result.progress.allSatisfy { $0 > 0.0 && $0 <= 1.0 })
        XCTAssertEqual(result.progress.last, 1.0)
        XCTAssertFalse(result.progressAfterOutcome)
    }

    func testNoProgressWithoutRenders() throws {
        var prerendered = photo("p2", edited: true)
        prerendered.renderedImage = renderTestImage(400, 300)
        let renderer = FakeRenderer(progressSteps: [0.5])
        let result = sendCollectingProgress([photo("p1"), prerendered, video("v3")], renderer: renderer)
        let outcome = try XCTUnwrap(result.outcome)
        XCTAssertEqual(outcome.messages.map { $0.uniqueId }, ["p1", "p2", "v3"])
        XCTAssertEqual(result.progress, [])
        XCTAssertEqual(renderer.renderedIds, [])
    }

    private func mixedSendItems(priced: Bool) -> [ChatMediaSendItem] {
        var items: [ChatMediaSendItem] = []
        items.append(photo("p0", edited: true))
        items.append(video("v1", values: chatMediaEditorValues(peerId: renderTestPeerId, originalDimensions: PixelDimensions(width: 1920, height: 1080), qualityPreset: .compressedMedium)))
        for index in 2 ..< 12 {
            let options = ChatMediaSendItemOptions(caption: NSAttributedString(string: "own \(index)"), price: priced && index == 6 ? 50 : nil)
            items.append(photo("p\(index)", edited: index == 5 || index == 9, options: options))
        }
        return items
    }

    private func text(_ message: LegacyAssetPickerEnqueueMessage) -> String? {
        if case let .message(text, _, _, _, _, _, _, _, _, _) = message.message {
            return text
        }
        return nil
    }

    func testMixedTwelveItemGroupedSend() throws {
        let renderer = FakeRenderer(failing: ["p0"])
        let outcome = try XCTUnwrap(send(mixedSendItems(priced: false), renderer: renderer, grouping: true, forcedCaption: NSAttributedString(string: "Hello")))
        XCTAssertEqual(Set(renderer.renderedIds), ["p0", "p5", "p9"])
        XCTAssertEqual(outcome.droppedUniqueIds, ["p0"])
        XCTAssertEqual(outcome.messages.map { $0.uniqueId }, ["v1"] + (2 ..< 12).map { "p\($0)" })
        XCTAssertEqual(groupingKeys(outcome), Array(repeating: 101, count: 10) + [102])
        XCTAssertEqual(outcome.messages.map { text($0) }, ["Hello"] + Array(repeating: "", count: 10))

        let file = try XCTUnwrap(media(outcome.messages[0]) as? TelegramMediaFile)
        let resource = try XCTUnwrap(file.resource as? VideoLibraryMediaResource)
        guard case let .compress(adjustments) = resource.conversion else {
            XCTFail()
            return
        }
        XCTAssertNotNil(adjustments)
        for index in [4, 8] {
            let image = try XCTUnwrap(media(outcome.messages[index]) as? TelegramMediaImage)
            XCTAssertTrue(image.representations.last?.resource is LocalFileReferenceMediaResource)
        }
        let unedited = try XCTUnwrap(media(outcome.messages[1]) as? TelegramMediaImage)
        XCTAssertTrue(unedited.representations.last?.resource is PhotoLibraryMediaResource)
    }

    func testMixedTwelveItemPricedSend() throws {
        let renderer = FakeRenderer(failing: ["p0"])
        let outcome = try XCTUnwrap(send(mixedSendItems(priced: true), renderer: renderer, grouping: true, forcedCaption: NSAttributedString(string: "Hello")))
        XCTAssertEqual(outcome.droppedUniqueIds, ["p0"])
        XCTAssertEqual(outcome.messages.count, 1)
        let message = outcome.messages[0]
        XCTAssertNil(message.uniqueId)
        XCTAssertEqual(groupingKeys(outcome), [nil])
        XCTAssertEqual(text(message), "Hello")
        let paid = try XCTUnwrap(media(message) as? TelegramMediaPaidContent)
        XCTAssertEqual(paid.amount, 50)
        XCTAssertEqual(paid.extendedMedia.count, 11)
        var kinds: [String] = []
        for extendedMedia in paid.extendedMedia {
            guard case let .full(media) = extendedMedia else {
                XCTFail()
                continue
            }
            if let image = media as? TelegramMediaImage {
                for representation in image.representations {
                    if let resource = representation.resource as? LocalFileReferenceMediaResource {
                        self.writtenPaths.append(resource.localFilePath)
                    }
                }
                kinds.append(image.representations.last?.resource is LocalFileReferenceMediaResource ? "edited" : "photo")
            } else if media is TelegramMediaFile {
                kinds.append("video")
            }
        }
        XCTAssertEqual(kinds, ["video", "photo", "photo", "photo", "edited", "photo", "photo", "photo", "edited", "photo", "photo"])
    }

    func testGifConvertedBeforeBuildAndDroppedWhenConversionFails() throws {
        let converter = FakeGifConverter(results: ["g1": ChatMediaSendConvertedGif(path: "/tmp/g1.mp4", dimensions: PixelDimensions(width: 320, height: 240), duration: 1.5)])
        let gifOptions = ChatMediaSendItemOptions(excludedFromGrouping: true)
        let items = [
            photo("p1"),
            ChatMediaSendItem(uniqueId: "g1", source: .gifAsset(identifier: "g1", pixelSize: CGSize(width: 320.0, height: 240.0)), options: gifOptions),
            ChatMediaSendItem(uniqueId: "g2", source: .gifAsset(identifier: "g2", pixelSize: CGSize(width: 320.0, height: 240.0)), options: gifOptions),
            photo("p2")
        ]
        let expectation = self.expectation(description: "outcome")
        var outcome: ChatMediaSendOutcome?
        let disposable = chatMediaSendMessages(items: items, global: ChatMediaSendGlobalOptions(grouping: true), renderer: FakeRenderer(), gifConverter: converter, makeGroupingKey: { 7 }, storeResourceData: { _, _ in }).start(next: { event in
            if case let .outcome(value) = event {
                outcome = value
                expectation.fulfill()
            }
        })
        self.wait(for: [expectation], timeout: 10.0)
        disposable.dispose()

        let result = try XCTUnwrap(outcome)
        XCTAssertEqual(converter.requestedIds.sorted(), ["g1", "g2"])
        XCTAssertEqual(result.droppedUniqueIds, ["g2"])
        XCTAssertEqual(result.messages.map { $0.uniqueId }, ["p1", "g1", "p2"])
        let groupingKeys: [Int64?] = result.messages.map { message in
            if case let .message(_, _, _, _, _, _, _, groupingKey, _, _) = message.message {
                return groupingKey
            }
            return nil
        }
        XCTAssertEqual(groupingKeys, [7, nil, 7])
        guard case let .message(_, _, _, mediaReference, _, _, _, _, _, _) = result.messages[1].message, let file = mediaReference?.media as? TelegramMediaFile, let resource = file.resource as? LocalFileVideoMediaResource else {
            XCTFail()
            return
        }
        XCTAssertEqual(resource.paths, ["/tmp/g1.mp4"])
    }

    func testGifConversionCompletingEmptyDropsItemInsteadOfHanging() throws {
        let converter = FakeGifConverter(results: ["g1": ChatMediaSendConvertedGif(path: "/tmp/g1.mp4", dimensions: PixelDimensions(width: 320, height: 240), duration: 1.5)], completingEmpty: ["g2"])
        let gifOptions = ChatMediaSendItemOptions(excludedFromGrouping: true)
        let items = [
            photo("p1"),
            ChatMediaSendItem(uniqueId: "g1", source: .gifAsset(identifier: "g1", pixelSize: CGSize(width: 320.0, height: 240.0)), options: gifOptions),
            ChatMediaSendItem(uniqueId: "g2", source: .gifAsset(identifier: "g2", pixelSize: CGSize(width: 320.0, height: 240.0)), options: gifOptions)
        ]
        let expectation = self.expectation(description: "outcome")
        var outcome: ChatMediaSendOutcome?
        let disposable = chatMediaSendMessages(items: items, global: ChatMediaSendGlobalOptions(grouping: false), renderer: FakeRenderer(), gifConverter: converter, makeGroupingKey: { 7 }, storeResourceData: { _, _ in }).start(next: { event in
            if case let .outcome(value) = event {
                outcome = value
                expectation.fulfill()
            }
        })
        self.wait(for: [expectation], timeout: 5.0)
        disposable.dispose()

        let result = try XCTUnwrap(outcome)
        XCTAssertEqual(result.droppedUniqueIds, ["g2"])
        XCTAssertEqual(result.messages.map { $0.uniqueId }, ["p1", "g1"])
    }

    func testGifConverterEmptyConversionYieldsNilAndClearsPending() {
        let attempts = Atomic<Int>(value: 0)
        let converter = ChatMediaSendGifConverter(conversion: { _ in
            let _ = attempts.modify { $0 + 1 }
            return .complete()
        })
        for attempt in 1 ... 2 {
            let expectation = self.expectation(description: "converted \(attempt)")
            var values: [ChatMediaSendConvertedGif?] = []
            let disposable = converter.convertGif(identifier: "empty-gif").start(next: { value in
                values.append(value)
            }, completed: {
                expectation.fulfill()
            })
            self.wait(for: [expectation], timeout: 5.0)
            disposable.dispose()
            XCTAssertEqual(values.count, 1)
            XCTAssertNil(values.first ?? nil)
            XCTAssertEqual(attempts.with { $0 }, attempt)
        }

        let converted = ChatMediaSendConvertedGif(path: NSTemporaryDirectory(), dimensions: PixelDimensions(width: 2, height: 2), duration: 1.0)
        let succeeding = ChatMediaSendGifConverter(conversion: { _ in
            return .single(converted)
        })
        var result: ChatMediaSendConvertedGif?
        let expectation = self.expectation(description: "succeeded")
        let disposable = succeeding.convertGif(identifier: "ok-gif").start(next: { value in
            result = value
            expectation.fulfill()
        })
        self.wait(for: [expectation], timeout: 5.0)
        disposable.dispose()
        XCTAssertEqual(result, converted)
        XCTAssertEqual(succeeding.cachedGif(identifier: "ok-gif"), converted)
    }

    func testGifDataConvertsToPlayableMp4() throws {
        let path = NSTemporaryDirectory() + "chat-media-send-gif-\(Int64.random(in: 0 ... Int64.max)).mp4"
        self.writtenPaths.append(path)
        let expectation = self.expectation(description: "converted")
        var converted: ChatMediaSendConvertedGif?
        let disposable = chatMediaSendConvertGifData(renderTestGifData(frames: 6, size: 96), outputPath: path).start(next: { value in
            converted = value
            expectation.fulfill()
        })
        self.wait(for: [expectation], timeout: 20.0)
        disposable.dispose()

        let result = try XCTUnwrap(converted)
        XCTAssertEqual(result.path, path)
        XCTAssertTrue(FileManager.default.fileExists(atPath: path))
        XCTAssertEqual(result.dimensions, PixelDimensions(width: 96, height: 96))
        XCTAssertEqual(result.duration, 0.6, accuracy: 0.05)
        XCTAssertEqual(chatMediaSendConvertedGifFromFile(path: path)?.dimensions, PixelDimensions(width: 96, height: 96))

        let notGif = self.expectation(description: "not gif")
        var notGifResult: ChatMediaSendConvertedGif?? = .none
        let _ = chatMediaSendConvertGifData(Data([1, 2, 3, 4, 5, 6]), outputPath: path + ".x").start(next: { value in
            notGifResult = .some(value)
            notGif.fulfill()
        })
        self.wait(for: [notGif], timeout: 5.0)
        XCTAssertEqual(notGifResult, .some(nil))
    }
}
