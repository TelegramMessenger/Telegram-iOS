import Foundation
import UIKit
import Photos
import XCTest
import TelegramCore
import MediaEditor
import ChatMediaSend
import Display
@testable import ChatMediaEditorScreen

private final class IdentifiedStubAsset: PHAsset {
    private let stubIdentifier: String

    init(identifier: String) {
        self.stubIdentifier = identifier
        super.init()
    }

    override var localIdentifier: String {
        return self.stubIdentifier
    }

    override var pixelWidth: Int {
        return 1200
    }

    override var pixelHeight: Int {
        return 800
    }

    override var mediaType: PHAssetMediaType {
        return .image
    }
}

private final class FakePageEditorState {
    var values: MediaEditorValues
    var lockedAspectRatio: CGFloat?

    init(values: MediaEditorValues, lockedAspectRatio: CGFloat?) {
        self.values = values
        self.lockedAspectRatio = lockedAspectRatio
    }
}

final class ChatMediaEditorPagerTests: XCTestCase {
    private let peerId = EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(1))

    func testFetchResultSourceReversedIndexing() {
        let assets = (0 ..< 5).map { IdentifiedStubAsset(identifier: "asset-\($0)") }
        var requestedIndices: [Int] = []
        let reversed = ChatMediaEditorFetchResultSource(count: assets.count, reversed: true, asset: { index in
            requestedIndices.append(index)
            return assets[index]
        }, indexOfIdentifier: { identifier in
            return assets.firstIndex(where: { $0.localIdentifier == identifier })
        })
        XCTAssertEqual(reversed.count, 5)
        XCTAssertTrue(requestedIndices.isEmpty)
        XCTAssertEqual(reversed.item(at: 0).uniqueId, "asset-4")
        XCTAssertEqual(reversed.item(at: 4).uniqueId, "asset-0")
        XCTAssertEqual(requestedIndices, [4, 0])
        XCTAssertEqual(reversed.index(of: "asset-0"), 4)
        XCTAssertEqual(reversed.index(of: "asset-4"), 0)
        XCTAssertEqual(reversed.index(of: "asset-1"), 3)
        XCTAssertNil(reversed.index(of: "missing"))
        if case let .asset(asset) = reversed.item(at: 1).source {
            XCTAssertTrue(asset === assets[3])
        } else {
            XCTFail()
        }

        let forward = ChatMediaEditorFetchResultSource(count: assets.count, reversed: false, asset: { assets[$0] }, indexOfIdentifier: { identifier in
            return assets.firstIndex(where: { $0.localIdentifier == identifier })
        })
        XCTAssertEqual(forward.item(at: 0).uniqueId, "asset-0")
        XCTAssertEqual(forward.index(of: "asset-3"), 3)

        XCTAssertEqual(chatMediaEditorMirroredIndex(0, count: 5, reversed: true), 4)
        XCTAssertEqual(chatMediaEditorMirroredIndex(2, count: 5, reversed: true), 2)
        XCTAssertEqual(chatMediaEditorMirroredIndex(2, count: 5, reversed: false), 2)
    }

    func testListSourceIndexOf() {
        let items = ["a", "b", "c"].map { ChatMediaEditorItem(uniqueId: $0, source: .image(UIImage())) }
        let source = ChatMediaEditorListSource(items: items)
        XCTAssertEqual(source.count, 3)
        XCTAssertEqual(source.item(at: 1).uniqueId, "b")
        XCTAssertEqual(source.index(of: "a"), 0)
        XCTAssertEqual(source.index(of: "c"), 2)
        XCTAssertNil(source.index(of: "d"))
    }

    func testPagerParallaxMatchesGalleryController() {
        let width: CGFloat = 390.0
        let pageWidth = width + chatMediaEditorPagerPageSpacing
        XCTAssertEqual(chatMediaEditorPagerParallaxOffset(pageFrame: CGRect(x: pageWidth * 2.0 + 20.0, y: 0.0, width: width, height: 844.0), contentOffset: pageWidth * 2.0), 0.0, accuracy: 0.001)
        XCTAssertEqual(chatMediaEditorPagerParallaxOffset(pageFrame: CGRect(x: pageWidth * 2.0 + 20.0, y: 0.0, width: width, height: 844.0), contentOffset: pageWidth * 2.0 - 100.0), -16.0, accuracy: 0.001)
        XCTAssertEqual(chatMediaEditorPagerParallaxOffset(pageFrame: CGRect(x: pageWidth * 3.0 + 20.0, y: 0.0, width: width, height: 844.0), contentOffset: pageWidth * 2.0), -pageWidth * 0.16, accuracy: 0.001)
        XCTAssertEqual(chatMediaEditorPagerParallaxOffset(pageFrame: CGRect(x: pageWidth + 20.0, y: 0.0, width: width, height: 844.0), contentOffset: pageWidth * 2.0), pageWidth * 0.16, accuracy: 0.001)
    }

    func testPagerLayoutGap40AndNeighbors() {
        let width: CGFloat = 402.0
        let height: CGFloat = 874.0
        let pageWidth = width + 40.0
        XCTAssertEqual(chatMediaEditorPagerPageSpacing, 40.0)

        let middle = chatMediaEditorPagerLayout(width: width, height: height, index: 5, offset: 5.0 * pageWidth, count: 10)
        XCTAssertEqual(middle.map { $0.index }, [4, 5, 6])
        let current = middle[1].frame
        XCTAssertEqual(current, CGRect(x: 5.0 * pageWidth + 20.0, y: 0.0, width: width, height: height))
        XCTAssertEqual(middle[2].frame.minX - current.maxX, 40.0)
        XCTAssertEqual(current.minX - middle[0].frame.maxX, 40.0)

        let first = chatMediaEditorPagerLayout(width: width, height: height, index: 0, offset: 0.0, count: 10)
        XCTAssertEqual(first.map { $0.index }, [0, 1])
        XCTAssertEqual(first[0].frame.minX, 20.0)

        let last = chatMediaEditorPagerLayout(width: width, height: height, index: 9, offset: 9.0 * pageWidth, count: 10)
        XCTAssertEqual(last.map { $0.index }, [8, 9])

        let single = chatMediaEditorPagerLayout(width: width, height: height, index: 0, offset: 0.0, count: 1)
        XCTAssertEqual(single.map { $0.index }, [0])

        let flung = chatMediaEditorPagerLayout(width: width, height: height, index: 2, offset: 6.5 * pageWidth, count: 10)
        XCTAssertEqual(flung.map { $0.index }, [1, 2, 3, 6, 7])

        XCTAssertTrue(chatMediaEditorPagerLayout(width: width, height: height, index: 0, offset: 0.0, count: 0).isEmpty)
        XCTAssertEqual(chatMediaEditorPagerSettledIndex(offset: 3.0 * pageWidth + 10.0, width: width, count: 10), 3)
        XCTAssertEqual(chatMediaEditorPagerSettledIndex(offset: 3.6 * pageWidth, width: width, count: 10), 4)
        XCTAssertEqual(chatMediaEditorPagerSettledIndex(offset: 100.0 * pageWidth, width: width, count: 10), 9)
    }

    func testSwitchSavesAndRestoresValues() {
        let items = ["a", "b", "c"].map { ChatMediaEditorItem(uniqueId: $0, source: .asset(IdentifiedStubAsset(identifier: $0))) }
        let store = ChatMediaEditorItemStore()
        let model = ChatMediaEditorPageModel(itemsSource: ChatMediaEditorListSource(items: items), store: store, initialIndex: 0)
        let defaults = chatMediaEditorValues(peerId: self.peerId, originalDimensions: PixelDimensions(width: 1200, height: 800), qualityPreset: .compressedVeryHigh)

        let initial = model.restore()
        XCTAssertEqual(initial.item.uniqueId, "a")
        XCTAssertNil(initial.values)
        let editor = FakePageEditorState(values: initial.values ?? defaults, lockedAspectRatio: initial.lockedAspectRatio)

        let edited = editor.values.withUpdatedCrop(rect: CGRect(x: 100.0, y: 0.0, width: 800.0, height: 800.0), rotation: 0.0, orientation: nil, mirroring: false, perspective: .zero)
        editor.values = edited
        editor.lockedAspectRatio = 1.0

        guard let toB = model.switchPage(to: 1, savingValues: editor.values, lockedAspectRatio: editor.lockedAspectRatio) else {
            XCTFail()
            return
        }
        XCTAssertEqual(model.currentIndex, 1)
        XCTAssertEqual(toB.item.uniqueId, "b")
        XCTAssertNil(toB.values)
        XCTAssertNil(toB.lockedAspectRatio)
        editor.values = toB.values ?? defaults
        editor.lockedAspectRatio = toB.lockedAspectRatio

        XCTAssertNil(model.switchPage(to: 1, savingValues: editor.values, lockedAspectRatio: nil))
        XCTAssertNil(model.switchPage(to: 7, savingValues: editor.values, lockedAspectRatio: nil))

        guard let toC = model.switchPage(to: 2, savingValues: editor.values, lockedAspectRatio: editor.lockedAspectRatio) else {
            XCTFail()
            return
        }
        editor.values = toC.values ?? defaults
        editor.lockedAspectRatio = toC.lockedAspectRatio

        guard let backToA = model.switchPage(to: 0, savingValues: editor.values, lockedAspectRatio: editor.lockedAspectRatio) else {
            XCTFail()
            return
        }
        XCTAssertEqual(backToA.item.uniqueId, "a")
        XCTAssertEqual(backToA.values, edited)
        XCTAssertEqual(backToA.lockedAspectRatio, 1.0)
        XCTAssertEqual(store.editedIdentifiers, ["a"])

        let thumbnail = UIImage()
        model.storeThumbnail(thumbnail, uniqueId: "a", values: defaults)
        XCTAssertNil(store.entry(for: "a")?.thumbnail)
        model.storeThumbnail(thumbnail, uniqueId: "a", values: edited)
        XCTAssertTrue(store.entry(for: "a")?.thumbnail === thumbnail)

        let reverted = model.switchPage(to: 1, savingValues: defaults, lockedAspectRatio: nil)
        XCTAssertNotNil(reverted)
        XCTAssertNil(store.entry(for: "a")?.thumbnail)
        XCTAssertEqual(store.editedIdentifiers, [])
    }

    func testSwitchKeepsToolDoneThumbnailForPreviousPage() {
        let items = ["a", "b"].map { ChatMediaEditorItem(uniqueId: $0, source: .asset(IdentifiedStubAsset(identifier: $0))) }
        let store = ChatMediaEditorItemStore()
        let model = ChatMediaEditorPageModel(itemsSource: ChatMediaEditorListSource(items: items), store: store, initialIndex: 0)
        let defaults = chatMediaEditorValues(peerId: self.peerId, originalDimensions: PixelDimensions(width: 1200, height: 800), qualityPreset: .compressedVeryHigh)
        let edited = defaults.withUpdatedCrop(rect: CGRect(x: 100.0, y: 0.0, width: 800.0, height: 800.0), rotation: 0.0, orientation: nil, mirroring: false, perspective: .zero)

        XCTAssertTrue(model.save(values: edited, lockedAspectRatio: nil))
        let thumbnail = UIImage()
        XCTAssertTrue(model.storeThumbnail(thumbnail, uniqueId: "a", values: edited))

        XCTAssertNotNil(model.switchPage(to: 1, savingValues: edited, lockedAspectRatio: nil))
        XCTAssertTrue(model.storedThumbnail(at: 0) === thumbnail)
        XCTAssertNil(model.storedThumbnail(at: 1))
        XCTAssertNil(model.storedThumbnail(at: 2))
        XCTAssertNil(model.storedThumbnail(at: -1))
    }

    func testUntouchedItemIsNotSaved() {
        let items = ["a", "b"].map { ChatMediaEditorItem(uniqueId: $0, source: .asset(IdentifiedStubAsset(identifier: $0))) }
        let store = ChatMediaEditorItemStore()
        let model = ChatMediaEditorPageModel(itemsSource: ChatMediaEditorListSource(items: items), store: store, initialIndex: 0)
        let defaults = chatMediaEditorValues(peerId: self.peerId, originalDimensions: PixelDimensions(width: 1200, height: 800), qualityPreset: .compressedVeryHigh)
        let edited = defaults.withUpdatedCrop(rect: CGRect(x: 100.0, y: 0.0, width: 800.0, height: 800.0), rotation: 0.0, orientation: nil, mirroring: false, perspective: .zero)

        XCTAssertFalse(chatMediaEditorShouldSaveItem(hasEntry: false, values: defaults, baselineQualityPreset: nil))
        XCTAssertTrue(chatMediaEditorShouldSaveItem(hasEntry: false, values: edited, baselineQualityPreset: nil))
        XCTAssertTrue(chatMediaEditorShouldSaveItem(hasEntry: true, values: defaults, baselineQualityPreset: nil))

        XCTAssertFalse(model.save(values: defaults, lockedAspectRatio: 1.0))
        XCTAssertNil(store.entry(for: "a"))
        XCTAssertNotNil(model.switchPage(to: 1, savingValues: defaults, lockedAspectRatio: nil))
        XCTAssertNil(store.entry(for: "a"))

        XCTAssertTrue(model.save(values: edited, lockedAspectRatio: nil))
        XCTAssertNotNil(store.entry(for: "b"))
        XCTAssertTrue(model.save(values: defaults, lockedAspectRatio: nil))
        XCTAssertEqual(store.entry(for: "b")?.values, defaults)
    }

    func testSwipeDownAndZoomValues() {
        XCTAssertEqual(chatMediaEditorSwipeDownDecision(translation: CGPoint(x: 3.0, y: 11.0)), .undecided)
        XCTAssertEqual(chatMediaEditorSwipeDownDecision(translation: CGPoint(x: 3.0, y: 12.0)), .begin)
        XCTAssertEqual(chatMediaEditorSwipeDownDecision(translation: CGPoint(x: 3.0, y: -12.0)), .begin)
        XCTAssertEqual(chatMediaEditorSwipeDownDecision(translation: CGPoint(x: 10.0, y: 5.0)), .fail)
        XCTAssertEqual(chatMediaEditorSwipeDownProgress(translation: 75.0), 0.5)
        XCTAssertEqual(chatMediaEditorSwipeDownBackgroundAlpha(translation: 15.0), 0.6, accuracy: 0.0001)
        XCTAssertEqual(chatMediaEditorSwipeDownBackgroundAlpha(translation: 60.0), 0.0)
        XCTAssertTrue(chatMediaEditorSwipeDownShouldDismiss(translation: 128.0, velocity: 0.0))
        XCTAssertTrue(chatMediaEditorSwipeDownShouldDismiss(translation: 20.0, velocity: -700.0))
        XCTAssertFalse(chatMediaEditorSwipeDownShouldDismiss(translation: 127.0, velocity: 699.0))

        XCTAssertEqual(chatMediaEditorPhotoMaxZoomScale(viewportSize: CGSize(width: 400.0, height: 800.0), mediaSize: CGSize(width: 400.0, height: 300.0)), 3.0, accuracy: 0.0001)
        XCTAssertEqual(chatMediaEditorPhotoMaxZoomScale(viewportSize: CGSize(width: 400.0, height: 800.0), mediaSize: CGSize(width: 400.0, height: 100.0)), 8.0, accuracy: 0.0001)

        let viewport = CGSize(width: 400.0, height: 800.0)
        let media = CGRect(x: 0.0, y: 200.0, width: 400.0, height: 300.0)
        XCTAssertEqual(chatMediaEditorZoomContentInsets(viewportSize: viewport, mediaFrame: media, zoomScale: 1.0), .zero)
        let zoomed = chatMediaEditorZoomContentInsets(viewportSize: viewport, mediaFrame: media, zoomScale: 2.0)
        XCTAssertEqual(zoomed.left, 0.0)
        XCTAssertEqual(zoomed.right, 0.0)
        XCTAssertEqual(zoomed.top, -350.0, accuracy: 0.0001)
        XCTAssertEqual(1600.0 + zoomed.bottom - 800.0, -zoomed.top, accuracy: 0.0001)
        let deep = chatMediaEditorZoomContentInsets(viewportSize: viewport, mediaFrame: media, zoomScale: 3.0)
        XCTAssertEqual(-deep.top, 600.0, accuracy: 0.0001)
        XCTAssertEqual(2400.0 + deep.bottom - 800.0, 1500.0 - 800.0, accuracy: 0.0001)
    }

    func testToolOpeningGatedOnPagerRest() {
        XCTAssertTrue(chatMediaEditorCanOpenTool(isToolActive: false, isSending: false, isDismissing: false, isPagerMoving: false))
        XCTAssertFalse(chatMediaEditorCanOpenTool(isToolActive: false, isSending: false, isDismissing: false, isPagerMoving: true))
        XCTAssertFalse(chatMediaEditorCanOpenTool(isToolActive: true, isSending: false, isDismissing: false, isPagerMoving: false))
        XCTAssertFalse(chatMediaEditorCanOpenTool(isToolActive: false, isSending: true, isDismissing: false, isPagerMoving: false))
        XCTAssertFalse(chatMediaEditorCanOpenTool(isToolActive: false, isSending: false, isDismissing: true, isPagerMoving: false))
    }

    func testZoomLegacyParityValues() {
        XCTAssertEqual(chatMediaEditorPhotoMinZoomScale, 0.05)
        let viewport = CGSize(width: 400.0, height: 800.0)
        let media = CGRect(x: 0.0, y: 200.0, width: 400.0, height: 300.0)
        let center = chatMediaEditorZoomTargetOffset(viewportSize: viewport, mediaFrame: media, zoomScale: 3.0, focus: CGPoint(x: 200.0, y: 350.0))
        XCTAssertEqual(center.x, 400.0, accuracy: 0.0001)
        XCTAssertEqual(center.y, 650.0, accuracy: 0.0001)
        let corner = chatMediaEditorZoomTargetOffset(viewportSize: viewport, mediaFrame: media, zoomScale: 3.0, focus: CGPoint(x: 0.0, y: 200.0))
        XCTAssertEqual(corner.x, 0.0, accuracy: 0.0001)
        XCTAssertEqual(corner.y, 600.0, accuracy: 0.0001)
        let shrunk = chatMediaEditorZoomContentInsets(viewportSize: viewport, mediaFrame: media, zoomScale: 0.5)
        XCTAssertEqual(-shrunk.top, 175.0 - 350.0, accuracy: 0.0001)

        XCTAssertEqual(chatMediaEditorSwipeDownDismissDirection(translation: 140.0, velocity: -900.0), -1.0)
        XCTAssertEqual(chatMediaEditorSwipeDownDismissDirection(translation: 140.0, velocity: -300.0), 1.0)
        XCTAssertEqual(chatMediaEditorSwipeDownDismissDirection(translation: -140.0, velocity: 0.0), -1.0)
    }

    func testPagerKeepsIndexAcrossWidthChange() {
        XCTAssertEqual(chatMediaEditorPagerOffset(index: 0, width: 390.0), 0.0)
        XCTAssertEqual(chatMediaEditorPagerOffset(index: 3, width: 390.0), 3.0 * (390.0 + chatMediaEditorPagerPageSpacing))
        XCTAssertEqual(chatMediaEditorPagerOffset(index: 3, width: 844.0), 3.0 * (844.0 + chatMediaEditorPagerPageSpacing))
        for width in [CGFloat(390.0), 844.0, 932.0] {
            XCTAssertEqual(chatMediaEditorPagerSettledIndex(offset: chatMediaEditorPagerOffset(index: 3, width: width), width: width, count: 5), 3)
        }

        let pager = ChatMediaEditorPagerView(frame: .zero)
        pager.update(size: CGSize(width: 390.0, height: 844.0), count: 5, currentIndex: 3)
        XCTAssertEqual(pager.scrollView.contentOffset.x, chatMediaEditorPagerOffset(index: 3, width: 390.0))
        pager.update(size: CGSize(width: 844.0, height: 390.0), count: 5, currentIndex: 3)
        XCTAssertEqual(pager.currentIndex, 3)
        XCTAssertEqual(pager.scrollView.contentOffset.x, chatMediaEditorPagerOffset(index: 3, width: 844.0))
        XCTAssertEqual(pager.page(at: 3)?.frame.minX, chatMediaEditorPagerOffset(index: 3, width: 844.0) + chatMediaEditorPagerPageSpacing / 2.0)
        XCTAssertEqual(pager.page(at: 3)?.frame.width, 844.0)
    }

    func testPagerReleasesTrackingAfterScrollingAnimation() {
        let pager = ChatMediaEditorPagerView(frame: .zero)
        pager.update(size: CGSize(width: 390.0, height: 844.0), count: 5, currentIndex: 0)
        var tracking = ChatMediaEditorTrackingSet()
        pager.trackingUpdated = { source, isTracking in
            tracking.update(isTracking, source: source)
        }
        pager.scrollViewWillBeginDragging(pager.scrollView)
        XCTAssertTrue(tracking.isTracking)
        pager.scrollViewDidEndDragging(pager.scrollView, willDecelerate: true)
        XCTAssertTrue(tracking.isTracking)
        pager.scrollViewDidEndScrollingAnimation(pager.scrollView)
        XCTAssertFalse(tracking.isTracking)
    }

    func testPagerReleasesTrackingOnProgrammaticScroll() {
        for animated in [false, true] {
            let pager = ChatMediaEditorPagerView(frame: .zero)
            pager.update(size: CGSize(width: 390.0, height: 844.0), count: 5, currentIndex: 0)
            var tracking = ChatMediaEditorTrackingSet()
            pager.trackingUpdated = { source, isTracking in
                tracking.update(isTracking, source: source)
            }
            pager.scrollViewWillBeginDragging(pager.scrollView)
            pager.scrollViewDidEndDragging(pager.scrollView, willDecelerate: true)
            XCTAssertTrue(tracking.isTracking)
            pager.scrollToPage(2, animated: animated)
            XCTAssertFalse(tracking.isTracking)
        }
    }

    func testRestingPreviewFramePortraitUnchanged() {
        let size = CGSize(width: 390.0, height: 844.0)
        let safeInsets = UIEdgeInsets(top: 47.0, left: 0.0, bottom: 34.0, right: 0.0)
        let mediaSize = CGSize(width: 3000.0, height: 4000.0)
        let expected = chatMediaEditorLayout(size: size, safeInsets: safeInsets, mediaSize: mediaSize, toolbarHeight: chatMediaEditorToolbarHeight, captionPanelHeight: 60.0, keyboardHeight: 0.0).previewFrame
        XCTAssertEqual(chatMediaEditorRestingPreviewFrame(size: size, safeInsets: safeInsets, mediaSize: mediaSize, captionPanelHeight: 60.0), expected)

        let duoInsets = UIEdgeInsets(top: 47.0, left: 0.0, bottom: 34.0, right: 84.0)
        let band = chatMediaEditorLayout(size: size, safeInsets: UIEdgeInsets(top: 47.0, left: 0.0, bottom: 34.0, right: 0.0), mediaSize: mediaSize, toolbarHeight: chatMediaEditorToolbarHeight, captionPanelHeight: 60.0, keyboardHeight: 0.0).previewFrame
        XCTAssertEqual(chatMediaEditorRestingPreviewFrame(size: size, safeInsets: duoInsets, mediaSize: mediaSize, captionPanelHeight: 60.0), band)
        let kept = chatMediaEditorLayout(size: size, safeInsets: duoInsets, mediaSize: mediaSize, toolbarHeight: chatMediaEditorToolbarHeight, captionPanelHeight: 60.0, keyboardHeight: 0.0).previewFrame
        XCTAssertEqual(chatMediaEditorRestingPreviewFrame(size: size, safeInsets: duoInsets, mediaSize: mediaSize, captionPanelHeight: 60.0, keepsToBand: true), kept)
    }

    func testRestingPreviewFrameLandscapeSitsBesideColumn() {
        let size = CGSize(width: 844.0, height: 390.0)
        let safeInsets = UIEdgeInsets(top: 0.0, left: 47.0, bottom: 21.0, right: 47.0)
        let mediaSize = CGSize(width: 4000.0, height: 3000.0)
        for side in [ChatMediaEditorToolbarSide.left, .right] {
            let frame = chatMediaEditorRestingPreviewFrame(size: size, safeInsets: safeInsets, mediaSize: mediaSize, captionPanelHeight: 60.0, toolbarSide: side)
            let expected = chatMediaEditorLayout(size: size, safeInsets: safeInsets, mediaSize: mediaSize, toolbarHeight: chatMediaEditorToolbarHeight, captionPanelHeight: 60.0, keyboardHeight: 0.0, toolbarSide: side).previewFrame
            XCTAssertEqual(frame, expected)
            let column = chatMediaEditorLandscapeColumnFrame(size: size, safeInsets: safeInsets, side: side)
            XCTAssertFalse(frame.intersects(column))
            XCTAssertEqual(frame.minY, 0.0, accuracy: 0.001)
            XCTAssertEqual(frame.height, 369.0, accuracy: 0.001)
        }

        let duoInsets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 21.0, right: 84.0)
        let corners = ContainerViewLayoutCorners(topLeft: nil, topRight: nil, bottomLeft: nil, bottomRight: CGSize(width: 84.0, height: 82.0))
        let duo = chatMediaEditorRestingPreviewFrame(size: size, safeInsets: duoInsets, mediaSize: mediaSize, captionPanelHeight: 60.0, toolbarSide: .right, reservedCorners: corners)
        let duoColumn = chatMediaEditorLandscapeColumnFrame(size: size, safeInsets: duoInsets, side: .right, reservedCorners: corners)
        XCTAssertFalse(duo.intersects(duoColumn))
        XCTAssertLessThanOrEqual(duo.maxX, size.width - 84.0 - chatMediaEditorLandscapeColumnWidth + 0.001)
    }
}
