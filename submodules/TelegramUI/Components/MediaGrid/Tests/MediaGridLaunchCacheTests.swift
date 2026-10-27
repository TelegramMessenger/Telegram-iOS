import XCTest
import UIKit
@testable import MediaGrid

final class MediaGridLaunchCacheTests: XCTestCase {
    private var directories: [URL] = []

    override func tearDown() {
        for directory in self.directories {
            try? FileManager.default.removeItem(at: directory)
        }
        self.directories = []
        super.tearDown()
    }

    private func makeDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("MediaGridLaunchCacheTests-\(UUID().uuidString)", isDirectory: true)
        self.directories.append(url)
        return url
    }

    private static func makeImage(width: Int, height: Int, color: UIColor) -> CGImage {
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
        context.setFillColor(color.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()!
    }

    private static func centerPixel(_ image: CGImage) -> (r: Int, g: Int, b: Int) {
        let context = CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        context.interpolationQuality = .none
        context.draw(image, in: CGRect(x: -CGFloat(image.width / 2), y: -CGFloat(image.height / 2), width: CGFloat(image.width), height: CGFloat(image.height)))
        let pixels = context.data!.assumingMemoryBound(to: UInt8.self)
        return (Int(pixels[0]), Int(pixels[1]), Int(pixels[2]))
    }

    private func keys(_ ids: [String], version: String = "1") -> [MediaGridLaunchCache.Key] {
        return ids.map { MediaGridLaunchCache.Key(id: $0, version: version) }
    }

    private func write(_ cache: MediaGridLaunchCache, head: [MediaGridLaunchCache.Key], colors: [String: UIColor], width: Int = 800, height: Int = 600) {
        var delivered: [String: MediaGridLaunchCache.Delivered] = [:]
        for key in head {
            if let color = colors[key.id] {
                delivered[key.id] = MediaGridLaunchCache.Delivered(version: key.version, image: MediaGridLaunchCacheTests.makeImage(width: width, height: height, color: color))
            }
        }
        let done = self.expectation(description: "update")
        cache.update(head: head, delivered: delivered, completion: { _ in
            done.fulfill()
        })
        self.wait(for: [done], timeout: 5.0)
    }

    private func makeGrid(dataSource: TestDataSource) -> MediaGridView {
        let view = MediaGridView(dataSource: dataSource, cellFactory: {
            return MediaGridCellLayer()
        })
        view.scaleOverride = 3.0
        view.frame = CGRect(x: 0.0, y: 0.0, width: 393.0, height: 852.0)
        return view
    }

    private func viewport(_ view: MediaGridView) -> Range<Int> {
        guard let layout = view.gridLayout else {
            return 0 ..< 0
        }
        return layout.indexRange(intersecting: CGRect(x: 0.0, y: view.contentOffset, width: view.bounds.width, height: view.bounds.height))
    }

    func testFirstLayoutShowsLaunchImagesSynchronously() {
        let dataSource = TestDataSource(count: 1000)
        dataSource.providesThumbnails = true
        dataSource.holdsDeliveries = true
        var images: [Int: CGImage] = [:]
        for index in 0 ..< 40 {
            let image = MediaGridLaunchCacheTests.makeImage(width: 522, height: 522, color: .blue)
            images[index] = image
            dataSource.launchImages[index] = MediaGridLaunchImage(image: image)
        }
        let view = self.makeGrid(dataSource: dataSource)
        view.layoutIfNeeded()
        XCTAssertEqual(dataSource.launchWaitTimeouts, [MediaGridView.launchImageWait])
        XCTAssertEqual(dataSource.events.first, "wait")
        let viewport = self.viewport(view)
        XCTAssertFalse(viewport.isEmpty)
        XCTAssertLessThanOrEqual(viewport.upperBound, 40)
        let requested = Set(dataSource.requests.map { $0.index })
        for index in viewport {
            guard let cell = view.activeLayoutLayer.visibleCells[index] else {
                XCTFail("no cell at \(index)")
                continue
            }
            XCTAssertTrue((cell.contents as AnyObject?) === images[index], "index \(index)")
            XCTAssertFalse(cell.isShowingThumbnail, "index \(index)")
            XCTAssertFalse(requested.contains(index), "sharp request for launch cell \(index)")
        }
        view.setContentOffset(10.0)
        view.layoutIfNeeded()
        XCTAssertEqual(dataSource.launchWaitTimeouts.count, 1)
    }

    func testSmallerLaunchImageStillRequestsSharp() {
        let dataSource = TestDataSource(count: 1000)
        dataSource.providesThumbnails = true
        dataSource.holdsDeliveries = true
        let image = MediaGridLaunchCacheTests.makeImage(width: 200, height: 200, color: .blue)
        dataSource.launchImages[0] = MediaGridLaunchImage(image: image)
        let view = self.makeGrid(dataSource: dataSource)
        view.layoutIfNeeded()
        let cell = view.activeLayoutLayer.visibleCells[0]!
        XCTAssertTrue((cell.contents as AnyObject?) === image)
        XCTAssertFalse(cell.isShowingThumbnail)
        XCTAssertTrue(dataSource.requests.contains { $0.index == 0 })
        XCTAssertTrue(dataSource.requests.contains { $0.index == 1 })
    }

    func testLaunchImageCoveringCellSizeIsNotRerequested() {
        let dataSource = TestDataSource(count: 1000)
        dataSource.providesThumbnails = true
        dataSource.holdsDeliveries = true
        dataSource.launchImages[0] = MediaGridLaunchImage(image: MediaGridLaunchCacheTests.makeImage(width: 360, height: 360, color: .blue), coveredPixelWidth: 522)
        dataSource.launchImages[1] = MediaGridLaunchImage(image: MediaGridLaunchCacheTests.makeImage(width: 360, height: 360, color: .blue), coveredPixelWidth: 360)
        let view = self.makeGrid(dataSource: dataSource)
        view.layoutIfNeeded()
        XCTAssertFalse(dataSource.requests.contains { $0.index == 0 })
        XCTAssertTrue(dataSource.requests.contains { $0.index == 1 })
        let image = TestDataSource.distinctImage(7, side: 300.0)
        view.activeLayoutLayer.visibleCells[0]!.setImage(image)
        XCTAssertEqual(view.activeLayoutLayer.visibleCells[0]!.launchCoverage, 0.0)
    }

    func testCoverageSpansOneScreenAndRowInBothOrientations() {
        let coverage = MediaGridLaunchCache.coverage(screenSize: CGSize(width: 402.0, height: 874.0), scale: 3.0)
        XCTAssertEqual(coverage, MediaGridLaunchCache.Coverage(capacity: 24, pixelSize: 522))
        XCTAssertEqual(MediaGridLaunchCache.coverage(screenSize: CGSize(width: 874.0, height: 402.0), scale: 3.0), coverage)
    }

    func testCompactLevelKeepsThumbnailsWithoutSharpRequests() {
        let dataSource = TestDataSource(count: 1000)
        dataSource.providesThumbnails = true
        dataSource.holdsDeliveries = true
        for index in 0 ..< 200 {
            dataSource.launchImages[index] = MediaGridLaunchImage(image: MediaGridLaunchCacheTests.makeImage(width: 360, height: 360, color: .blue), coveredPixelWidth: 522)
        }
        let view = self.makeGrid(dataSource: dataSource)
        view.setLevel(.fifteen, animated: false)
        view.layoutIfNeeded()
        XCTAssertFalse(view.activeLayoutLayer.visibleCells.isEmpty)
        for (index, cell) in view.activeLayoutLayer.visibleCells {
            XCTAssertTrue(cell.isShowingThumbnail, "index \(index)")
        }
        XCTAssertEqual(dataSource.requestCount, 0)
        view.thumbnailsDidChange(indices: nil)
        XCTAssertEqual(dataSource.requestCount, 0)
        XCTAssertTrue(view.activeLayoutLayer.visibleCells.values.allSatisfy { $0.isShowingThumbnail })
    }

    func testLevelOneNonSquareCellsNeverUseLaunchImages() {
        let dataSource = TestDataSource(count: 1000)
        dataSource.providesThumbnails = true
        dataSource.holdsDeliveries = true
        for index in 0 ..< 40 {
            dataSource.launchImages[index] = MediaGridLaunchImage(image: MediaGridLaunchCacheTests.makeImage(width: 360, height: 360, color: .blue), coveredPixelWidth: 522)
        }
        let view = self.makeGrid(dataSource: dataSource)
        view.setLevel(.one, animated: false)
        view.layoutIfNeeded()
        let cells = view.activeLayoutLayer.visibleCells
        XCTAssertFalse(cells.isEmpty)
        for (index, cell) in cells {
            XCTAssertNotEqual(cell.frame.width, cell.frame.height, accuracy: 1.0)
            XCTAssertTrue(cell.isShowingThumbnail, "index \(index)")
        }
        view.thumbnailsDidChange(indices: nil)
        XCTAssertTrue(view.activeLayoutLayer.visibleCells.values.allSatisfy { $0.isShowingThumbnail })
    }

    func testWaitHookIsSpentOnFirstSizedLayoutEvenWhenEmpty() {
        let dataSource = TestDataSource(count: 0)
        let view = self.makeGrid(dataSource: dataSource)
        view.layoutIfNeeded()
        dataSource.count = 100
        view.reloadData()
        view.layoutIfNeeded()
        XCTAssertEqual(dataSource.launchWaitTimeouts, [])
    }

    func testUpdateDoesNotResurrectReleasedImages() {
        let directory = self.makeDirectory()
        let writer = MediaGridLaunchCache(directory: directory, capacity: 3, pixelSize: 64)
        self.write(writer, head: self.keys(["a", "b"]), colors: ["a": .red, "b": .green])
        let cache = MediaGridLaunchCache(directory: directory, capacity: 3, pixelSize: 64)
        cache.load()
        XCTAssertEqual(cache.decodedImageCount, 2)
        cache.willInstall = {
            cache.releaseImages()
        }
        let done = self.expectation(description: "update")
        cache.update(head: self.keys(["a", "b", "c"]), delivered: ["c": MediaGridLaunchCache.Delivered(version: "1", image: MediaGridLaunchCacheTests.makeImage(width: 64, height: 64, color: .blue))], completion: { written in
            XCTAssertTrue(written)
            done.fulfill()
        })
        self.wait(for: [done], timeout: 5.0)
        XCTAssertEqual(cache.storedKeys, self.keys(["a", "b", "c"]))
        XCTAssertEqual(cache.decodedImageCount, 0)
    }

    func testCoverageIsTheDeliveredSize() {
        XCTAssertEqual(MediaGridLaunchCacheKeeper.coverage(of: MediaGridLaunchCacheTests.makeImage(width: 360, height: 480, color: .red)), 360)
        XCTAssertEqual(MediaGridLaunchCacheKeeper.coverage(of: MediaGridLaunchCacheTests.makeImage(width: 600, height: 800, color: .red)), 600)
        let directory = self.makeDirectory()
        let (keeper, run) = self.makeKeeper(directory: directory, capacity: 3, pixelSize: 522)
        keeper.install(head: self.keys(["a", "b", "c"]), images: [:])
        keeper.delivered(id: "c", image: MediaGridLaunchCacheTests.makeImage(width: 600, height: 800, color: .red))
        keeper.delivered(id: "a", image: MediaGridLaunchCacheTests.makeImage(width: 360, height: 480, color: .red))
        keeper.delivered(id: "b", image: MediaGridLaunchCacheTests.makeImage(width: 120, height: 160, color: .red))
        run()
        self.flush(keeper)
        let reloaded = MediaGridLaunchCache(directory: directory, capacity: 3, pixelSize: 522)
        reloaded.load()
        XCTAssertEqual(reloaded.launchImage(for: "a", version: "1")?.coveredPixelWidth, 360)
        XCTAssertEqual(reloaded.launchImage(for: "b", version: "1")?.coveredPixelWidth, 120)
        XCTAssertEqual(reloaded.launchImage(for: "c", version: "1")?.coveredPixelWidth, 522)
        XCTAssertEqual(reloaded.launchImage(for: "c", version: "1")?.pixelWidth, 522)
    }

    func testStaleLaunchEntryIgnored() {
        let directory = self.makeDirectory()
        let writer = MediaGridLaunchCache(directory: directory, capacity: 4, pixelSize: 100)
        self.write(writer, head: self.keys(["a", "b", "c"]), colors: ["a": .red, "b": .green, "c": .blue])
        let cache = MediaGridLaunchCache(directory: directory, capacity: 4, pixelSize: 100)
        cache.load()
        let head = [MediaGridLaunchCache.Key(id: "a", version: "2"), MediaGridLaunchCache.Key(id: "b", version: "1"), MediaGridLaunchCache.Key(id: "x", version: "1"), MediaGridLaunchCache.Key(id: "c", version: "1")]
        let matched = cache.images(matching: head)
        XCTAssertEqual(Set(matched.keys), [1, 3])
        XCTAssertNil(cache.image(for: "a", version: "2"))
        XCTAssertNotNil(cache.image(for: "a", version: "1"))

        let dataSource = TestDataSource(count: 100)
        dataSource.providesThumbnails = true
        dataSource.holdsDeliveries = true
        dataSource.launchImages = matched
        let view = self.makeGrid(dataSource: dataSource)
        view.layoutIfNeeded()
        XCTAssertTrue(view.activeLayoutLayer.visibleCells[0]!.isShowingThumbnail)
        XCTAssertTrue(view.activeLayoutLayer.visibleCells[2]!.isShowingThumbnail)
        XCTAssertTrue((view.activeLayoutLayer.visibleCells[1]!.contents as AnyObject?) === matched[1]!.image)
    }

    func testLaunchCacheRoundTrip() {
        let directory = self.makeDirectory()
        let writer = MediaGridLaunchCache(directory: directory, capacity: 3, pixelSize: 300)
        XCTAssertTrue(writer.waitUntilLoaded(timeout: 0.0) == false)
        self.write(writer, head: self.keys(["a", "b", "c", "d"]), colors: ["a": .red, "b": .green, "c": .blue, "d": .black])
        let cache = MediaGridLaunchCache(directory: directory, capacity: 3, pixelSize: 300)
        cache.startLoading()
        XCTAssertTrue(cache.waitUntilLoaded(timeout: 5.0))
        XCTAssertEqual(cache.storedKeys, self.keys(["a", "b", "c"]))
        XCTAssertEqual(cache.decodedImageCount, 3)
        let expected: [String: (Int, Int, Int)] = ["a": (255, 0, 0), "b": (0, 255, 0), "c": (0, 0, 255)]
        for (id, color) in expected {
            guard let image = cache.image(for: id, version: "1") else {
                XCTFail("missing \(id)")
                continue
            }
            XCTAssertEqual(image.width, 300)
            XCTAssertEqual(image.height, 300)
            let pixel = MediaGridLaunchCacheTests.centerPixel(image)
            XCTAssertLessThan(abs(pixel.r - color.0) + abs(pixel.g - color.1) + abs(pixel.b - color.2), 24, "\(id) \(pixel)")
        }
        cache.releaseImages()
        XCTAssertEqual(cache.decodedImageCount, 0)

        let unchanged = self.expectation(description: "unchanged")
        cache.update(head: self.keys(["a", "b", "c"]), delivered: [:], completion: { written in
            XCTAssertFalse(written)
            unchanged.fulfill()
        })
        self.wait(for: [unchanged], timeout: 5.0)

        try? Data([1, 2, 3]).write(to: directory.appendingPathComponent(MediaGridLaunchCache.fileName))
        let corrupt = MediaGridLaunchCache(directory: directory, capacity: 3, pixelSize: 300)
        corrupt.load()
        XCTAssertEqual(corrupt.storedKeys, [])
    }

    func testThumbnailStoreKeepsLaunchDirectory() {
        let directory = self.makeDirectory()
        let launchDirectory = directory.appendingPathComponent(MediaGridLaunchCache.directoryName, isDirectory: true)
        let writer = MediaGridLaunchCache(directory: launchDirectory, capacity: 2, pixelSize: 32)
        self.write(writer, head: self.keys(["a"]), colors: ["a": .red])
        try? Data([1]).write(to: directory.appendingPathComponent("stray.jpg"))
        let store = MediaGridThumbnailStore(directory: directory)
        let loaded = self.expectation(description: "load")
        store.load {
            loaded.fulfill()
        }
        self.wait(for: [loaded], timeout: 5.0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("stray.jpg").path))
        let cache = MediaGridLaunchCache(directory: launchDirectory, capacity: 2, pixelSize: 32)
        cache.load()
        XCTAssertEqual(cache.storedKeys, self.keys(["a"]))
    }

    func testWaitTimesOut() {
        let directory = self.makeDirectory()
        let writer = MediaGridLaunchCache(directory: directory, capacity: 30, pixelSize: 64)
        let ids = (0 ..< 30).map { "id\($0)" }
        var colors: [String: UIColor] = [:]
        for id in ids {
            colors[id] = .blue
        }
        self.write(writer, head: self.keys(ids), colors: colors)

        let cache = MediaGridLaunchCache(directory: directory, capacity: 30, pixelSize: 64)
        let release = DispatchSemaphore(value: 0)
        cache.willDecode = {
            _ = release.wait(timeout: .now() + 5.0)
        }
        cache.startLoading()
        let dataSource = TestDataSource(count: 1000)
        dataSource.providesThumbnails = true
        dataSource.holdsDeliveries = true
        var matched: [Int: MediaGridLaunchImage] = [:]
        dataSource.onWaitForLaunchImages = { timeout in
            if cache.waitUntilLoaded(timeout: timeout) {
                matched = cache.images(matching: self.keys(ids))
            }
        }
        dataSource.launchImageProvider = { index in
            return matched[index]
        }
        let view = self.makeGrid(dataSource: dataSource)
        let start = CACurrentMediaTime()
        view.layoutIfNeeded()
        let elapsed = CACurrentMediaTime() - start
        XCTAssertGreaterThanOrEqual(elapsed, 0.04)
        XCTAssertLessThan(elapsed, 0.25)
        XCTAssertGreaterThanOrEqual(view.launchImageWaitDuration ?? 0.0, 0.04)
        XCTAssertLessThan(view.launchImageWaitDuration ?? 1.0, 0.25)
        let viewport = self.viewport(view)
        for index in viewport {
            XCTAssertTrue(view.activeLayoutLayer.visibleCells[index]!.isShowingThumbnail, "index \(index)")
        }

        release.signal()
        XCTAssertTrue(cache.waitUntilLoaded(timeout: 5.0))
        matched = cache.images(matching: self.keys(ids))
        view.thumbnailsDidChange(indices: IndexSet(matched.keys))
        for index in viewport {
            let cell = view.activeLayoutLayer.visibleCells[index]!
            XCTAssertFalse(cell.isShowingThumbnail, "index \(index)")
            XCTAssertTrue((cell.contents as AnyObject?) === matched[index]?.image, "index \(index)")
        }
    }

    private func makeKeeper(directory: URL, capacity: Int, pixelSize: Int = 64) -> (MediaGridLaunchCacheKeeper, () -> Void) {
        let cache = MediaGridLaunchCache(directory: directory, capacity: capacity, pixelSize: pixelSize)
        cache.load()
        let keeper = MediaGridLaunchCacheKeeper(cache: cache)
        var pending: [() -> Void] = []
        keeper.schedule = { _, block in
            pending.append(block)
        }
        let run: () -> Void = {
            let blocks = pending
            pending = []
            for block in blocks {
                block()
            }
        }
        return (keeper, run)
    }

    private func flush(_ keeper: MediaGridLaunchCacheKeeper) {
        let done = self.expectation(description: "flush")
        keeper.cache.flush {
            done.fulfill()
        }
        self.wait(for: [done], timeout: 5.0)
    }

    func testRefreshAfterRestAtTop() {
        let directory = self.makeDirectory()
        let (keeper, run) = self.makeKeeper(directory: directory, capacity: 3)
        keeper.install(head: self.keys(["a", "b", "c"]), images: [:])
        keeper.viewportChanged(lowerBound: 0)
        for id in ["a", "b", "c"] {
            keeper.delivered(id: id, image: MediaGridLaunchCacheTests.makeImage(width: 90, height: 120, color: .red))
        }
        keeper.delivered(id: "z", image: MediaGridLaunchCacheTests.makeImage(width: 90, height: 120, color: .red))
        keeper.viewportChanged(lowerBound: 30)
        run()
        self.flush(keeper)
        XCTAssertEqual(keeper.refreshCount, 0)
        XCTAssertEqual(keeper.cache.storedKeys, [])

        keeper.viewportChanged(lowerBound: 0)
        run()
        self.flush(keeper)
        XCTAssertEqual(keeper.refreshCount, 1)
        XCTAssertEqual(keeper.cache.storedKeys, self.keys(["a", "b", "c"]))

        let reloaded = MediaGridLaunchCache(directory: directory, capacity: 3, pixelSize: 64)
        reloaded.load()
        XCTAssertEqual(reloaded.storedKeys, self.keys(["a", "b", "c"]))
        XCTAssertEqual(reloaded.image(for: "b", version: "1")?.width, 64)
        XCTAssertEqual(reloaded.launchImage(for: "b", version: "1")?.coveredPixelWidth, 64)
        XCTAssertEqual(reloaded.images(matching: self.keys(["a", "b", "c"])).count, 3)

        XCTAssertEqual(keeper.targetSize(at: 0, pixelSize: CGSize(width: 50.0, height: 50.0)), CGSize(width: 64.0, height: 64.0))
        XCTAssertEqual(keeper.targetSize(at: 3, pixelSize: CGSize(width: 50.0, height: 50.0)), CGSize(width: 50.0, height: 50.0))
        XCTAssertEqual(keeper.targetSize(at: 0, pixelSize: CGSize(width: 20.0, height: 20.0)), CGSize(width: 20.0, height: 20.0))
        XCTAssertEqual(keeper.targetSize(at: 0, pixelSize: CGSize(width: 200.0, height: 200.0)), CGSize(width: 200.0, height: 200.0))
    }

    func testLibraryInsertAtTopRefreshes() {
        let directory = self.makeDirectory()
        let writer = MediaGridLaunchCache(directory: directory, capacity: 3, pixelSize: 64)
        self.write(writer, head: self.keys(["a", "b", "c"]), colors: ["a": .red, "b": .green, "c": .blue])
        let (keeper, run) = self.makeKeeper(directory: directory, capacity: 3)
        keeper.install(head: self.keys(["a", "b", "c"]), images: keeper.cache.images(matching: self.keys(["a", "b", "c"])))
        XCTAssertEqual(Set(keeper.images.keys), [0, 1, 2])
        let a = keeper.images[0]!.image
        let b = keeper.images[1]!.image

        keeper.setHead(self.keys(["x", "a", "b"]))
        XCTAssertEqual(Set(keeper.images.keys), [1, 2])
        XCTAssertTrue(keeper.images[1]!.image === a)
        XCTAssertTrue(keeper.images[2]!.image === b)
        keeper.delivered(id: "x", image: MediaGridLaunchCacheTests.makeImage(width: 80, height: 80, color: .black))
        run()
        self.flush(keeper)
        XCTAssertEqual(keeper.refreshCount, 1)
        XCTAssertEqual(keeper.cache.storedKeys, self.keys(["x", "a", "b"]))

        keeper.setHead([MediaGridLaunchCache.Key(id: "x", version: "2")] + self.keys(["a", "b"]))
        XCTAssertNil(keeper.images[0])
        run()
        self.flush(keeper)
        XCTAssertEqual(keeper.cache.storedKeys, self.keys(["a", "b"]))

        keeper.viewportChanged(lowerBound: 3)
        XCTAssertTrue(keeper.images.isEmpty)
        XCTAssertEqual(keeper.cache.decodedImageCount, 0)
    }
}
