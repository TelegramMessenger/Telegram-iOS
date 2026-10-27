import XCTest
import UIKit
import MediaGrid
@testable import MediaGridDemo

private final class FakeThumbnailSource: ThumbnailImageSource {
    var requests: [(index: Int, id: String, completion: (ThumbnailImageResult) -> Void)] = []
    var log: [String] = []

    func requestThumbnail(index: Int, id: String, completion: @escaping (ThumbnailImageResult) -> Void) {
        self.requests.append((index, id, completion))
        self.log.append(id)
    }

    func completeFirst(_ result: ThumbnailImageResult) {
        let request = self.requests.removeFirst()
        request.completion(result)
    }

    func complete(id: String, _ result: ThumbnailImageResult) {
        let position = self.requests.firstIndex(where: { $0.id == id })!
        let request = self.requests.remove(at: position)
        request.completion(result)
    }
}

final class ThumbnailFillerTests: XCTestCase {
    private let image: CGImage = {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = true
        return UIGraphicsImageRenderer(size: CGSize(width: 96.0, height: 72.0), format: format).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0.0, y: 0.0, width: 96.0, height: 72.0))
        }.cgImage!
    }()

    private func catalog(_ count: Int, version: String = "1") -> ThumbnailCatalog {
        return ThumbnailCatalog.build(count: count, entry: { ("p\($0)", version) })
    }

    private func makeFiller(count: Int, store: MediaGridThumbnailStore = MediaGridThumbnailStore(directory: nil), ranges: [Range<Int>] = []) -> (ThumbnailFiller, FakeThumbnailSource, MediaGridThumbnailStore) {
        let source = FakeThumbnailSource()
        let filler = ThumbnailFiller(store: store, source: source, registry: UnavailableThumbnailRegistry(url: nil))
        filler.setPriority(ranges: ranges)
        filler.install(filler.makePlan(for: self.catalog(count)))
        return (filler, source, store)
    }

    private func waitForPublish(_ store: MediaGridThumbnailStore, ids: Set<String>) {
        let expectation = self.expectation(description: "published")
        var pending = ids
        store.onThumbnailsChanged = { changed in
            pending.subtract(changed)
            if pending.isEmpty {
                store.onThumbnailsChanged = nil
                expectation.fulfill()
            }
        }
        self.wait(for: [expectation], timeout: 5.0)
    }

    func testFillsMissingInPriorityOrder() {
        let (filler, source, _) = self.makeFiller(count: 100, ranges: [40 ..< 44, 80 ..< 82])
        XCTAssertEqual(filler.missingCount, 84)
        let expected = [40, 41, 42, 43, 80, 81, 44, 39, 45, 38, 46, 37, 47, 36, 48, 35].map { "p\($0)" }
        XCTAssertEqual(source.log, expected)
        source.completeFirst(.image(self.image))
        XCTAssertEqual(source.log.last, "p49")
        XCTAssertEqual(filler.inFlightCount, 16)
    }

    func testRestOfLibraryFollowsInGridOrderAfterOutward() {
        let (filler, source, _) = self.makeFiller(count: 2000, ranges: [1000 ..< 1001])
        while source.log.count < 1027 {
            source.completeFirst(.image(self.image))
        }
        XCTAssertEqual(source.log[0], "p1000")
        XCTAssertEqual(source.log[1], "p999")
        XCTAssertEqual(source.log[2], "p1001")
        XCTAssertEqual(source.log[1023], "p488")
        XCTAssertEqual(source.log[1024], "p1512")
        XCTAssertEqual(source.log[1025], "p0")
        XCTAssertEqual(source.log[1026], "p1")
        XCTAssertFalse(filler.isComplete)
    }

    func testCompletesWhenEverythingIsFilled() {
        let (filler, source, store) = self.makeFiller(count: 20)
        while !source.requests.isEmpty {
            source.completeFirst(.image(self.image))
        }
        XCTAssertTrue(filler.isComplete)
        XCTAssertEqual(filler.filledCount, 20)
        XCTAssertEqual(filler.missingCount, 0)
        XCTAssertEqual(store.version(for: "p7"), "1")
        XCTAssertEqual(source.log.count, 20)
    }

    func testSkipsUpToDateVersion() {
        let store = MediaGridThumbnailStore(directory: nil)
        store.write(self.image, id: "p1", version: "1")
        store.write(self.image, id: "p2", version: "0")
        let (filler, source, _) = self.makeFiller(count: 4, store: store)
        XCTAssertEqual(source.log, ["p0", "p2", "p3"])
        XCTAssertEqual(filler.filledCount, 1)
    }

    func testChangedVersionRefills() {
        let (filler, source, store) = self.makeFiller(count: 3)
        while !source.requests.isEmpty {
            source.completeFirst(.image(self.image))
        }
        XCTAssertEqual(store.version(for: "p1"), "1")
        let changes = MediaGridChanges(removed: [], inserted: [], changed: [1])
        let catalog = filler.catalog.applying(changes, newCount: 3, entry: { _ in ("p1", "2") })
        filler.install(filler.makePlan(for: catalog), urgent: ["p1"])
        XCTAssertEqual(source.requests.map(\.id), ["p1"])
        XCTAssertFalse(filler.isComplete)
        source.completeFirst(.image(self.image))
        XCTAssertEqual(store.version(for: "p1"), "2")
        XCTAssertTrue(filler.isComplete)
    }

    func testRemovedFreesSlot() {
        let (filler, source, store) = self.makeFiller(count: 3)
        while !source.requests.isEmpty {
            source.completeFirst(.image(self.image))
        }
        self.waitForPublish(store, ids: ["p0", "p1", "p2"])
        let removedRect = store.thumbnail(for: "p1")!.contentsRect
        let changes = MediaGridChanges(removed: [1], inserted: [0], changed: [])
        let catalog = filler.catalog.applying(changes, newCount: 3, entry: { _ in ("n", "1") })
        filler.install(filler.makePlan(for: catalog), removed: ["p1"], urgent: ["n"])
        XCTAssertNil(store.version(for: "p1"))
        XCTAssertEqual(source.requests.map(\.id), ["n"])
        source.completeFirst(.image(self.image))
        self.waitForPublish(store, ids: ["n"])
        XCTAssertNil(store.thumbnail(for: "p1"))
        XCTAssertEqual(store.thumbnail(for: "n")!.contentsRect, removedRect)
    }

    func testLateCompletionForRemovedIdIsNotWritten() {
        let (filler, source, store) = self.makeFiller(count: 2)
        let changes = MediaGridChanges(removed: [0], inserted: [], changed: [])
        let catalog = filler.catalog.applying(changes, newCount: 1, entry: { _ in ("x", "1") })
        filler.install(filler.makePlan(for: catalog), removed: ["p0"])
        source.complete(id: "p0", .image(self.image))
        XCTAssertNil(store.version(for: "p0"))
    }

    func testUnavailableIsMarkedAndNotRetried() {
        let (filler, source, _) = self.makeFiller(count: 3)
        source.complete(id: "p1", .unavailable)
        while !source.requests.isEmpty {
            source.completeFirst(.image(self.image))
        }
        XCTAssertEqual(filler.unavailableCount, 1)
        XCTAssertTrue(filler.isComplete)
        filler.install(filler.makePlan(for: filler.catalog))
        XCTAssertTrue(source.requests.isEmpty)
        XCTAssertEqual(filler.unavailableCount, 1)
        XCTAssertEqual(source.log.filter { $0 == "p1" }.count, 1)
    }

    func testThrottlesWhileMovingFast() {
        let source = FakeThumbnailSource()
        let filler = ThumbnailFiller(store: MediaGridThumbnailStore(directory: nil), source: source, registry: UnavailableThumbnailRegistry(url: nil))
        filler.isMovingFast = true
        filler.install(filler.makePlan(for: self.catalog(100)))
        XCTAssertEqual(source.requests.count, 4)
        source.completeFirst(.image(self.image))
        XCTAssertEqual(source.requests.count, 4)
        filler.isMovingFast = false
        XCTAssertEqual(source.requests.count, 16)
        filler.isMovingFast = true
        source.completeFirst(.image(self.image))
        XCTAssertEqual(source.requests.count, 15)
        XCTAssertEqual(filler.inFlightCount, 15)
    }

    func testPausedWhileStoreIsNotWritable() {
        let source = FakeThumbnailSource()
        let filler = ThumbnailFiller(store: MediaGridThumbnailStore(directory: nil), source: source, registry: UnavailableThumbnailRegistry(url: nil))
        filler.isPaused = true
        filler.install(filler.makePlan(for: self.catalog(10)))
        XCTAssertTrue(source.requests.isEmpty)
        filler.isPaused = false
        XCTAssertEqual(source.requests.count, 10)
    }

    func testIdToIndexMapFollowsChanges() {
        let initial = self.catalog(6)
        XCTAssertEqual(initial.indexById["p4"], 4)
        let changes = MediaGridChanges(removed: [1, 4], inserted: [0, 3], changed: [2])
        XCTAssertTrue(changes.isValid(oldCount: 6, newCount: 6))
        var read: [Int] = []
        let updated = initial.applying(changes, newCount: 6, entry: { index in
            read.append(index)
            return ("n\(index)", "2")
        })
        XCTAssertEqual(updated.ids, ["n0", "p0", "n2", "n3", "p3", "p5"])
        XCTAssertEqual(updated.versions, ["2", "1", "2", "2", "1", "1"])
        XCTAssertEqual(read, [0, 2, 3])
        XCTAssertEqual(updated.indexById["p5"], 5)
        XCTAssertEqual(updated.indexById["p3"], 4)
        XCTAssertNil(updated.indexById["p1"])
        XCTAssertNil(updated.indexById["p4"])
        XCTAssertEqual(updated.id(at: 1), "p0")
        XCTAssertNil(updated.id(at: 6))
    }
}
