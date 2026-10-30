import Foundation
import UIKit
import XCTest
import TelegramCore
import AccountContext
import ChatMediaEditorScreen

private func makeCoverImage(_ color: UIColor) -> UIImage {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1.0
    return UIGraphicsImageRenderer(size: CGSize(width: 8.0, height: 4.0), format: format).image { context in
        color.setFill()
        context.fill(CGRect(x: 0.0, y: 0.0, width: 8.0, height: 4.0))
    }
}

private final class FakeCoverAdapter: ChatMediaEditorCoverAdapter {
    private(set) var images: [String: UIImage] = [:]
    private(set) var positions: [String: Double] = [:]
    private(set) var writes: [(String, Double?)] = []

    func coverImage(for uniqueId: String) -> UIImage? {
        return self.images[uniqueId]
    }

    func coverPosition(for uniqueId: String) -> Double? {
        return self.positions[uniqueId]
    }

    func setCoverImage(_ image: UIImage, position: Double?, for uniqueId: String) {
        self.writes.append((uniqueId, position))
        self.images[uniqueId] = image
        self.positions[uniqueId] = position
    }
}

private final class FakeCoverFrameSource: ChatMediaEditorCoverFrameSource {
    var resultImage: UIImage?
    private(set) var seeks: [Double] = []
    private(set) var pendingSeekCompletion: (() -> Void)?
    private(set) var onNextDisplay: (() -> Void)?
    var frames: [Double: UIImage] = [:]

    func seek(_ position: Double, completion: @escaping () -> Void) {
        self.seeks.append(position)
        self.pendingSeekCompletion = completion
    }

    func setOnNextDisplay(_ f: @escaping () -> Void) {
        self.onNextDisplay = f
    }

    func completeSeek() {
        let completion = self.pendingSeekCompletion
        self.pendingSeekCompletion = nil
        completion?()
    }

    func render(at position: Double) {
        self.resultImage = self.frames[position]
        let f = self.onNextDisplay
        self.onNextDisplay = nil
        f?()
    }
}

private final class ManualScheduler {
    private(set) var delays: [Double] = []
    private var pending: [() -> Void] = []

    func schedule(_ delay: Double, _ f: @escaping () -> Void) {
        self.delays.append(delay)
        self.pending.append(f)
    }

    func fire() {
        let pending = self.pending
        self.pending = []
        pending.forEach { $0() }
    }
}

final class ChatMediaEditorCoverTests: XCTestCase {
    private let accountPeerId = EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(1))

    private func peerId(_ namespace: EnginePeer.Id.Namespace, _ id: Int64) -> EnginePeer.Id {
        return EnginePeer.Id(namespace: namespace, id: EnginePeer.Id.Id._internalFromInt64Value(id))
    }

    private func user(_ id: EnginePeer.Id) -> EnginePeer {
        return EnginePeer(TelegramUser(id: id, accessHash: nil, firstName: "U", lastName: nil, username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [], emojiStatus: nil, usernames: [], storiesHidden: nil, nameColor: nil, backgroundEmojiId: nil, profileColor: nil, profileBackgroundEmojiId: nil, subscriberCount: nil, verificationIconFileId: nil))
    }

    func testCoverButtonGating() {
        let channel = self.peerId(Namespaces.Peer.CloudChannel, 5)
        XCTAssertTrue(chatMediaGalleryHasCoverButton(isBroadcastChannel: true, peerId: channel, accountPeerId: self.accountPeerId))
        XCTAssertFalse(chatMediaGalleryHasCoverButton(isBroadcastChannel: false, peerId: channel, accountPeerId: self.accountPeerId))
        XCTAssertTrue(chatMediaGalleryHasCoverButton(isBroadcastChannel: false, peerId: self.accountPeerId, accountPeerId: self.accountPeerId))
        XCTAssertFalse(chatMediaGalleryHasCoverButton(isBroadcastChannel: false, peerId: self.peerId(Namespaces.Peer.CloudUser, 2), accountPeerId: self.accountPeerId))
        XCTAssertFalse(chatMediaGalleryHasCoverButton(isBroadcastChannel: false, peerId: self.peerId(Namespaces.Peer.CloudGroup, 2), accountPeerId: self.accountPeerId))
        XCTAssertFalse(chatMediaGalleryHasCoverButton(isBroadcastChannel: false, peerId: nil, accountPeerId: self.accountPeerId))

        XCTAssertTrue(chatMediaGalleryHasCoverButton(peer: self.user(self.accountPeerId), accountPeerId: self.accountPeerId))
        XCTAssertFalse(chatMediaGalleryHasCoverButton(peer: self.user(self.peerId(Namespaces.Peer.CloudUser, 2)), accountPeerId: self.accountPeerId))
        XCTAssertFalse(chatMediaGalleryHasCoverButton(peer: nil, accountPeerId: self.accountPeerId))

        XCTAssertTrue(chatMediaEditorCoverButtonIsVisible(hasCoverButton: true, isVideo: true, isAnimation: false, duration: 60.0))
        XCTAssertTrue(chatMediaEditorCoverButtonIsVisible(hasCoverButton: true, isVideo: true, isAnimation: false, duration: 600.0))
        XCTAssertFalse(chatMediaEditorCoverButtonIsVisible(hasCoverButton: true, isVideo: true, isAnimation: false, duration: 59.9))
        XCTAssertFalse(chatMediaEditorCoverButtonIsVisible(hasCoverButton: false, isVideo: true, isAnimation: false, duration: 120.0))
        XCTAssertFalse(chatMediaEditorCoverButtonIsVisible(hasCoverButton: true, isVideo: false, isAnimation: false, duration: 120.0))
        XCTAssertFalse(chatMediaEditorCoverButtonIsVisible(hasCoverButton: true, isVideo: true, isAnimation: true, duration: 120.0))
    }

    func testCoverStoredAndSent() {
        let adapter = FakeCoverAdapter()
        let model = ChatMediaEditorCoverModel(adapter: adapter)
        XCTAssertNil(model.coverImage(for: "v"))
        XCTAssertNil(model.savedPosition(for: "v"))

        let frame = makeCoverImage(.red)
        model.saveFrame(frame, position: 12.5, for: "v")
        XCTAssertTrue(model.coverImage(for: "v") === frame)
        XCTAssertEqual(model.savedPosition(for: "v"), 12.5)

        let picked = makeCoverImage(.green)
        model.saveGalleryImage(picked, for: "v")
        XCTAssertTrue(model.coverImage(for: "v") === picked)
        XCTAssertNil(model.savedPosition(for: "v"))
        XCTAssertEqual(adapter.writes.map { $0.0 }, ["v", "v"])
        XCTAssertEqual(adapter.writes.map { $0.1 }, [12.5, nil])
    }

    func testCoverCaptureSeeksThenTakesTheRenderedFrame() {
        let stale = makeCoverImage(.red)
        let target = makeCoverImage(.green)
        let source = FakeCoverFrameSource()
        source.resultImage = stale
        source.frames[42.0] = target
        let scheduler = ManualScheduler()
        var results: [(UIImage?, Double)] = []
        chatMediaEditorCaptureCoverFrame(source: source, position: 42.0, schedule: scheduler.schedule, completion: { image, position in
            results.append((image, position))
        })
        XCTAssertEqual(source.seeks, [42.0])
        XCTAssertTrue(results.isEmpty)
        source.completeSeek()
        XCTAssertTrue(results.isEmpty)
        source.render(at: 42.0)
        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results.first?.0 === target)
        XCTAssertEqual(results.first?.1, 42.0)
        scheduler.fire()
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(scheduler.delays, [chatMediaEditorCoverCaptureFallbackDelay])
    }

    func testCoverCaptureFallsBackWhenNoFrameIsRendered() {
        let current = makeCoverImage(.blue)
        let source = FakeCoverFrameSource()
        source.resultImage = current
        let scheduler = ManualScheduler()
        var results: [(UIImage?, Double)] = []
        chatMediaEditorCaptureCoverFrame(source: source, position: 7.5, schedule: scheduler.schedule, completion: { image, position in
            results.append((image, position))
        })
        source.completeSeek()
        XCTAssertTrue(results.isEmpty)
        scheduler.fire()
        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results.first?.0 === current)
        XCTAssertEqual(results.first?.1, 7.5)
        source.render(at: 7.5)
        XCTAssertEqual(results.count, 1)
    }

    func testCoverCaptureIgnoresRendersBeforeTheSeekLands() {
        let stale = makeCoverImage(.red)
        let target = makeCoverImage(.green)
        let source = FakeCoverFrameSource()
        source.frames[3.0] = stale
        source.frames[10.0] = target
        let scheduler = ManualScheduler()
        var results: [(UIImage?, Double)] = []
        chatMediaEditorCaptureCoverFrame(source: source, position: 10.0, schedule: scheduler.schedule, completion: { image, position in
            results.append((image, position))
        })
        source.render(at: 3.0)
        XCTAssertTrue(results.isEmpty)
        XCTAssertTrue(scheduler.delays.isEmpty)
        source.completeSeek()
        source.render(at: 10.0)
        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results.first?.0 === target)
    }

    func testCoverEditingPositionPrefersSavedThenPlayer() {
        XCTAssertEqual(chatMediaEditorCoverEditingPosition(savedPosition: 12.0, playerPosition: 30.0, currentPosition: 5.0), 12.0)
        XCTAssertEqual(chatMediaEditorCoverEditingPosition(savedPosition: nil, playerPosition: 30.0, currentPosition: 5.0), 30.0)
        XCTAssertEqual(chatMediaEditorCoverEditingPosition(savedPosition: nil, playerPosition: nil, currentPosition: 5.0), 5.0)
    }

    func testCoverPositionClampedToTrimRange() {
        XCTAssertEqual(chatMediaEditorCoverClampedPosition(5.0, trimRange: 10.0 ..< 40.0, duration: 90.0), 10.0)
        XCTAssertEqual(chatMediaEditorCoverClampedPosition(55.0, trimRange: 10.0 ..< 40.0, duration: 90.0), 40.0)
        XCTAssertEqual(chatMediaEditorCoverClampedPosition(25.0, trimRange: 10.0 ..< 40.0, duration: 90.0), 25.0)
        XCTAssertEqual(chatMediaEditorCoverClampedPosition(120.0, trimRange: nil, duration: 90.0), 90.0)
        XCTAssertEqual(chatMediaEditorCoverClampedPosition(-1.0, trimRange: nil, duration: 90.0), 0.0)
        XCTAssertEqual(chatMediaEditorCoverClampedPosition(70.0, trimRange: 10.0 ..< 200.0, duration: 90.0), 70.0)
    }

    func testCoverLayout() {
        let size = CGSize(width: 402.0, height: 874.0)
        let safeInsets = UIEdgeInsets(top: 62.0, left: 0.0, bottom: 34.0, right: 0.0)
        let toolbarMinY = size.height - safeInsets.bottom - 49.0
        let headerFrame = chatMediaEditorVideoHeaderFrame(size: size, toolbarMinY: toolbarMinY, captionBaseHeight: 52.0)
        let buttonFrame = chatMediaEditorCoverButtonFrame(size: size, safeInsets: safeInsets, headerFrame: headerFrame, buttonWidth: 120.0)
        XCTAssertEqual(buttonFrame.height, chatMediaEditorCoverButtonHeight)
        XCTAssertEqual(buttonFrame.midX, size.width / 2.0)
        XCTAssertEqual(buttonFrame.maxY, headerFrame.minY + 16.0 - 1.0)
        let galleryFrame = chatMediaEditorCoverGalleryButtonFrame(coverButtonFrame: buttonFrame, size: size, safeInsets: safeInsets, buttonWidth: 150.0)
        XCTAssertEqual(galleryFrame.minY, buttonFrame.minY + 16.0)
        XCTAssertEqual(galleryFrame.midX, size.width / 2.0)

        let trimScrubberFrame = chatMediaEditorScrubberFrame(size: size, safeInsets: safeInsets, headerFrame: headerFrame, scrubberHeight: chatMediaEditorCoverScrubberTrackHeight)
        XCTAssertEqual(buttonFrame.maxY, trimScrubberFrame.minY - 1.0)
        let coverScrubberFrame = chatMediaEditorCoverScrubberFrame(trimScrubberFrame: trimScrubberFrame)
        XCTAssertEqual(coverScrubberFrame.minY, trimScrubberFrame.minY + 16.0)
        XCTAssertEqual(coverScrubberFrame.size, trimScrubberFrame.size)
        XCTAssertFalse(galleryFrame.intersects(coverScrubberFrame))
        XCTAssertLessThanOrEqual(galleryFrame.maxY, coverScrubberFrame.minY)
        XCTAssertGreaterThan(galleryFrame.minY, buttonFrame.minY)

        let editLayout = chatMediaEditorCoverEditLayout(size: size, safeInsets: safeInsets, titleSize: CGSize(width: 100.0, height: 20.0), cancelSize: CGSize(width: 60.0, height: 34.0))
        XCTAssertEqual(editLayout.saveFrame, CGRect(x: 16.0, y: size.height - 50.0 - 16.0 - 34.0, width: size.width - 32.0, height: chatMediaEditorCoverSaveButtonHeight))
        XCTAssertEqual(editLayout.cancelFrame.origin, CGPoint(x: 16.0, y: 62.0 + 20.0))
        XCTAssertEqual(editLayout.titleFrame, CGRect(x: 151.0, y: 62.0 + 26.0, width: 100.0, height: 20.0))
    }

    func testCoverEditTitleSharesTheBandAxisBesideAStrip() {
        let titleSize = CGSize(width: 100.0, height: 20.0)
        for size in [CGSize(width: 951.0, height: 669.0), CGSize(width: 466.0, height: 678.0)] {
            let safeInsets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 20.0, right: 84.0)
            let headerFrame = chatMediaEditorVideoHeaderFrame(size: size, toolbarMinY: size.height - 20.0 - 49.0, captionBaseHeight: 52.0)
            let buttonFrame = chatMediaEditorCoverButtonFrame(size: size, safeInsets: safeInsets, headerFrame: headerFrame, buttonWidth: 140.0)
            let editLayout = chatMediaEditorCoverEditLayout(size: size, safeInsets: safeInsets, titleSize: titleSize, cancelSize: CGSize(width: 60.0, height: 34.0))
            XCTAssertEqual(editLayout.titleFrame.midX, (size.width - 84.0) / 2.0, accuracy: 1.0)
            XCTAssertEqual(editLayout.titleFrame.midX, buttonFrame.midX, accuracy: 1.0)
        }
    }

    // Beside iPhone Duo's status island (unfolded portrait) Edit Cover's title and Cancel sit on the island's clock line
    // (centre 47) instead of below the island's 82pt band; elsewhere they keep their place.
    func testCoverEditTopRowSitsOnTheStatusIslandsClockLine() {
        let size = CGSize(width: 669.0, height: 951.0)
        let safeInsets = UIEdgeInsets(top: 82.0, left: 0.0, bottom: 20.0, right: 0.0)
        let titleSize = CGSize(width: 100.0, height: 20.0)
        let cancelSize = CGSize(width: 60.0, height: 34.0)
        let island = ChatMediaEditorStatusIslandRow(clockLineY: 47.0, trailingInset: 134.0)
        let editLayout = chatMediaEditorCoverEditLayout(size: size, safeInsets: safeInsets, titleSize: titleSize, cancelSize: cancelSize, statusIsland: island)
        XCTAssertEqual(editLayout.titleFrame.midY, 47.0)
        XCTAssertEqual(editLayout.cancelFrame.midY, 47.0)
        XCTAssertLessThan(editLayout.titleFrame.maxX, size.width - 134.0)
        let plain = chatMediaEditorCoverEditLayout(size: size, safeInsets: safeInsets, titleSize: titleSize, cancelSize: cancelSize)
        XCTAssertEqual(editLayout.titleFrame.minX, plain.titleFrame.minX)
        XCTAssertEqual(editLayout.cancelFrame.minX, plain.cancelFrame.minX)
        XCTAssertEqual(editLayout.saveFrame, plain.saveFrame)
        XCTAssertEqual(chatMediaEditorCoverEditLayout(size: size, safeInsets: safeInsets, titleSize: titleSize, cancelSize: cancelSize, statusIsland: nil), plain)
    }
}
