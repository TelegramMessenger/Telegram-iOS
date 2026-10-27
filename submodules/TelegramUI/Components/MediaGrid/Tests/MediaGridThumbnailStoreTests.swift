import XCTest
import UIKit
import ImageIO
@testable import MediaGrid

final class MediaGridThumbnailStoreTests: XCTestCase {
    private let unit: CGFloat = 1.0 / 768.0

    private func makeImage(width: Int, height: Int, top: UIColor, bottom: UIColor? = nil) -> CGImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = true
        let size = CGSize(width: width, height: height)
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            top.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            if let bottom {
                bottom.setFill()
                context.fill(CGRect(x: 0.0, y: size.height / 2.0, width: size.width, height: size.height / 2.0))
            }
        }
        return image.cgImage!
    }

    private func pixels(of image: CGImage) -> (data: [UInt8], width: Int) {
        let width = image.width
        let height = image.height
        var data = [UInt8](repeating: 0, count: width * height * 4)
        data.withUnsafeMutableBytes { buffer in
            let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        return (data, width)
    }

    private func sample(_ image: CGImage, x: Int, y: Int) -> (r: UInt8, g: UInt8, b: UInt8, a: UInt8) {
        let (data, width) = self.pixels(of: image)
        let offset = (y * width + x) * 4
        return (data[offset], data[offset + 1], data[offset + 2], data[offset + 3])
    }

    private func render(_ thumbnail: MediaGridThumbnail, contentsRect: CGRect, size: CGSize) -> CGImage {
        let layer = CALayer()
        layer.frame = CGRect(origin: .zero, size: size)
        layer.contents = thumbnail.image
        layer.contentsRect = contentsRect
        layer.contentsGravity = .resize
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            layer.render(in: context.cgContext)
        }.cgImage!
    }

    private func write(_ store: MediaGridThumbnailStore, _ items: [(String, CGImage, String)]) {
        let expectation = self.expectation(description: "published")
        var pending = Set(items.map(\.0))
        store.onThumbnailsChanged = { ids in
            XCTAssertTrue(Thread.isMainThread)
            pending.subtract(ids)
            if pending.isEmpty {
                store.onThumbnailsChanged = nil
                expectation.fulfill()
            }
        }
        for (id, image, version) in items {
            store.write(image, id: id, version: version)
        }
        self.wait(for: [expectation], timeout: 5.0)
    }

    private func assertRect(_ rect: CGRect, _ expected: CGRect, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(rect.minX, expected.minX, accuracy: 1e-9, file: file, line: line)
        XCTAssertEqual(rect.minY, expected.minY, accuracy: 1e-9, file: file, line: line)
        XCTAssertEqual(rect.width, expected.width, accuracy: 1e-9, file: file, line: line)
        XCTAssertEqual(rect.height, expected.height, accuracy: 1e-9, file: file, line: line)
    }

    func testWriteThenThumbnailHasSlotRect() {
        let store = MediaGridThumbnailStore(directory: nil)
        XCTAssertNil(store.thumbnail(for: "a"))
        self.write(store, [("a", self.makeImage(width: 100, height: 100, top: .red), "1")])
        let thumbnail = store.thumbnail(for: "a")!
        XCTAssertEqual(thumbnail.image.width, 768)
        XCTAssertEqual(thumbnail.image.height, 768)
        XCTAssertEqual(thumbnail.contentsRect.origin, .zero)
        self.assertRect(thumbnail.contentsRect, CGRect(x: 0.0, y: 0.0, width: 48.0 * self.unit, height: 48.0 * self.unit))
        XCTAssertEqual(store.version(for: "a"), "1")
        XCTAssertNil(store.version(for: "b"))
    }

    func testAspectFitClamped() {
        let store = MediaGridThumbnailStore(directory: nil)
        self.write(store, [("a", self.makeImage(width: 400, height: 100, top: .red), "1")])
        let thumbnail = store.thumbnail(for: "a")!
        self.assertRect(thumbnail.contentsRect, CGRect(x: 0.0, y: 12.0 * self.unit, width: 48.0 * self.unit, height: 24.0 * self.unit))
        let red = self.sample(thumbnail.image, x: 24, y: 24)
        XCTAssertEqual(red.r, 255)
        XCTAssertEqual(red.a, 255)
        XCTAssertEqual(self.sample(thumbnail.image, x: 24, y: 6).r, 255)
        XCTAssertEqual(self.sample(thumbnail.image, x: 24, y: 41).r, 255)
        XCTAssertEqual(self.sample(thumbnail.image, x: 24, y: 12).a, 255)
        XCTAssertEqual(self.sample(thumbnail.image, x: 24, y: 35).a, 255)
    }

    func testTallAspectFitClamped() {
        let store = MediaGridThumbnailStore(directory: nil)
        self.write(store, [("a", self.makeImage(width: 100, height: 1000, top: .red), "1")])
        let thumbnail = store.thumbnail(for: "a")!
        self.assertRect(thumbnail.contentsRect, CGRect(x: 12.0 * self.unit, y: 0.0, width: 24.0 * self.unit, height: 48.0 * self.unit))
    }

    func testFillingAspectCrops() {
        let store = MediaGridThumbnailStore(directory: nil)
        self.write(store, [("a", self.makeImage(width: 200, height: 100, top: .red), "1")])
        let thumbnail = store.thumbnail(for: "a")!
        self.assertRect(thumbnail.contentsRect(fillingAspect: 1.0), CGRect(x: 12.0 * self.unit, y: 12.0 * self.unit, width: 24.0 * self.unit, height: 24.0 * self.unit))
        self.assertRect(thumbnail.contentsRect(fillingAspect: 2.0), thumbnail.contentsRect)
        self.assertRect(thumbnail.contentsRect(fillingAspect: 4.0), CGRect(x: 0.0, y: 18.0 * self.unit, width: 48.0 * self.unit, height: 12.0 * self.unit))
    }

    func testRemoveReusesSlot() {
        let store = MediaGridThumbnailStore(directory: nil)
        let image = self.makeImage(width: 10, height: 10, top: .red)
        self.write(store, [("a", image, "1"), ("b", image, "1"), ("c", image, "1")])
        self.assertRect(store.thumbnail(for: "b")!.contentsRect, CGRect(x: 48.0 * self.unit, y: 0.0, width: 48.0 * self.unit, height: 48.0 * self.unit))
        store.remove(ids: ["b"])
        XCTAssertNil(store.thumbnail(for: "b"))
        XCTAssertNil(store.version(for: "b"))
        self.write(store, [("d", image, "1")])
        self.assertRect(store.thumbnail(for: "d")!.contentsRect, CGRect(x: 48.0 * self.unit, y: 0.0, width: 48.0 * self.unit, height: 48.0 * self.unit))
        self.write(store, [("e", image, "1")])
        self.assertRect(store.thumbnail(for: "e")!.contentsRect, CGRect(x: 144.0 * self.unit, y: 0.0, width: 48.0 * self.unit, height: 48.0 * self.unit))
        XCTAssertNotNil(store.thumbnail(for: "a"))
        XCTAssertNotNil(store.thumbnail(for: "c"))
    }

    func testPageForIdFollowsPublishedPlacement() {
        let store = MediaGridThumbnailStore(directory: nil)
        let image = self.makeImage(width: 10, height: 10, top: .red)
        XCTAssertNil(store.page(for: "0"))
        self.write(store, (0 ..< 257).map { ("\($0)", image, "1") })
        XCTAssertEqual(store.page(for: "0"), 0)
        XCTAssertEqual(store.page(for: "255"), 0)
        XCTAssertEqual(store.page(for: "256"), 1)
        store.remove(ids: ["256"])
        XCTAssertNil(store.page(for: "256"))
    }

    func testStoredIdsListsIndexedIds() {
        let store = MediaGridThumbnailStore(directory: nil)
        XCTAssertEqual(store.storedIds(), [])
        let image = self.makeImage(width: 10, height: 10, top: .red)
        store.write(image, id: "a", version: "1")
        store.write(image, id: "b", version: "1")
        XCTAssertEqual(Set(store.storedIds()), ["a", "b"])
        store.remove(ids: ["a"])
        XCTAssertEqual(store.storedIds(), ["b"])
    }

    func testSecondPageAfter256() {
        let store = MediaGridThumbnailStore(directory: nil)
        let image = self.makeImage(width: 10, height: 10, top: .red)
        self.write(store, (0 ..< 257).map { ("\($0)", image, "1") })
        let last = store.thumbnail(for: "255")!
        self.assertRect(last.contentsRect, CGRect(x: 720.0 * self.unit, y: 720.0 * self.unit, width: 48.0 * self.unit, height: 48.0 * self.unit))
        let row = store.thumbnail(for: "16")!
        self.assertRect(row.contentsRect, CGRect(x: 0.0, y: 48.0 * self.unit, width: 48.0 * self.unit, height: 48.0 * self.unit))
        let second = store.thumbnail(for: "256")!
        XCTAssertEqual(second.contentsRect.origin, .zero)
        XCTAssertFalse(second.image === last.image)
        XCTAssertTrue(store.thumbnail(for: "0")!.image === last.image)
        XCTAssertEqual(self.sample(second.image, x: 24, y: 24).r, 255)
        XCTAssertEqual(self.sample(second.image, x: 72, y: 24).a, 0)
    }

    func testRewriteSameIdKeepsSlotUpdatesVersion() {
        let store = MediaGridThumbnailStore(directory: nil)
        self.write(store, [("a", self.makeImage(width: 10, height: 10, top: .red), "1"), ("b", self.makeImage(width: 10, height: 10, top: .red), "1")])
        self.write(store, [("a", self.makeImage(width: 400, height: 100, top: .blue), "2")])
        XCTAssertEqual(store.version(for: "a"), "2")
        let thumbnail = store.thumbnail(for: "a")!
        self.assertRect(thumbnail.contentsRect, CGRect(x: 0.0, y: 12.0 * self.unit, width: 48.0 * self.unit, height: 24.0 * self.unit))
        let pixel = self.sample(thumbnail.image, x: 24, y: 24)
        XCTAssertEqual(pixel.b, 255)
        XCTAssertEqual(pixel.r, 0)
        XCTAssertEqual(self.sample(thumbnail.image, x: 24, y: 4).b, 255)
        self.write(store, [("c", self.makeImage(width: 10, height: 10, top: .red), "1")])
        self.assertRect(store.thumbnail(for: "c")!.contentsRect, CGRect(x: 96.0 * self.unit, y: 0.0, width: 48.0 * self.unit, height: 48.0 * self.unit))
    }

    func testReusedSlotNeverShowsOldPixels() {
        let store = MediaGridThumbnailStore(directory: nil)
        self.write(store, [("a", self.makeImage(width: 10, height: 10, top: .red), "1")])
        store.remove(ids: ["a"])
        XCTAssertNil(store.thumbnail(for: "a"))
        self.write(store, [("b", self.makeImage(width: 400, height: 100, top: .blue), "1")])
        let thumbnail = store.thumbnail(for: "b")!
        XCTAssertEqual(thumbnail.contentsRect.minX, 0.0)
        let pixel = self.sample(thumbnail.image, x: 24, y: 24)
        XCTAssertEqual(pixel.b, 255)
        XCTAssertEqual(pixel.r, 0)
        XCTAssertEqual(self.sample(thumbnail.image, x: 24, y: 4).b, 255)
        XCTAssertNil(store.thumbnail(for: "a"))
    }

    func testRemoveClearsPixelsWithoutReuse() {
        let store = MediaGridThumbnailStore(directory: nil)
        let image = self.makeImage(width: 10, height: 10, top: .red)
        self.write(store, [("a", image, "1"), ("b", image, "1")])
        store.remove(ids: ["a"])
        self.write(store, [("b", image, "2")])
        XCTAssertEqual(self.sample(store.thumbnail(for: "b")!.image, x: 24, y: 24).a, 0)
    }

    func testFillCoalescesPublishes() {
        let store = MediaGridThumbnailStore(directory: nil)
        let image = self.makeImage(width: 10, height: 10, top: .red)
        var calls: [Set<String>] = []
        let expectation = self.expectation(description: "published")
        store.onThumbnailsChanged = { ids in
            calls.append(ids)
            expectation.fulfill()
        }
        for i in 0 ..< 256 {
            store.write(image, id: "\(i)", version: "1")
        }
        self.wait(for: [expectation], timeout: 5.0)
        let settle = self.expectation(description: "settle")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            settle.fulfill()
        }
        self.wait(for: [settle], timeout: 5.0)
        XCTAssertEqual(calls.count, 1)
        XCTAssertEqual(calls.first?.count, 256)
    }

    func testWriteFromBackgroundThread() {
        let store = MediaGridThumbnailStore(directory: nil)
        let image = self.makeImage(width: 10, height: 10, top: .red)
        let expectation = self.expectation(description: "published")
        var pending = Set((0 ..< 300).map { "\($0)" })
        store.onThumbnailsChanged = { ids in
            XCTAssertTrue(Thread.isMainThread)
            pending.subtract(ids)
            if pending.isEmpty {
                expectation.fulfill()
            }
        }
        DispatchQueue.concurrentPerform(iterations: 300) { i in
            store.write(image, id: "\(i)", version: "1")
        }
        self.wait(for: [expectation], timeout: 5.0)
        var origins = Set<String>()
        for i in 0 ..< 300 {
            let thumbnail = store.thumbnail(for: "\(i)")!
            origins.insert("\(ObjectIdentifier(thumbnail.image).hashValue)-\(thumbnail.contentsRect.minX)-\(thumbnail.contentsRect.minY)")
        }
        XCTAssertEqual(origins.count, 300)
    }

    func testContentsRectRendersSlotUpright() {
        let store = MediaGridThumbnailStore(directory: nil)
        let image = self.makeImage(width: 10, height: 10, top: .red)
        var items: [(String, CGImage, String)] = (0 ..< 16).map { ("\($0)", image, "1") }
        items.append(("split", self.makeImage(width: 200, height: 100, top: .red, bottom: .blue), "1"))
        self.write(store, items)
        let thumbnail = store.thumbnail(for: "split")!
        self.assertRect(thumbnail.contentsRect, CGRect(x: 0.0, y: 60.0 * self.unit, width: 48.0 * self.unit, height: 24.0 * self.unit))
        let rendered = self.render(thumbnail, contentsRect: thumbnail.contentsRect, size: CGSize(width: 48.0, height: 24.0))
        let top = self.sample(rendered, x: 24, y: 3)
        XCTAssertEqual(top.r, 255)
        XCTAssertEqual(top.b, 0)
        let bottom = self.sample(rendered, x: 24, y: 20)
        XCTAssertEqual(bottom.b, 255)
        XCTAssertEqual(bottom.r, 0)
        let filled = self.render(thumbnail, contentsRect: thumbnail.contentsRect(fillingAspect: 1.0), size: CGSize(width: 24.0, height: 24.0))
        XCTAssertEqual(self.sample(filled, x: 12, y: 2).r, 255)
        XCTAssertEqual(self.sample(filled, x: 12, y: 21).b, 255)
        XCTAssertEqual(self.sample(filled, x: 1, y: 2).a, 255)
    }

    func testBackgroundWritesPublishAtMostOncePerFrame() {
        let store = MediaGridThumbnailStore(directory: nil)
        let image = self.makeImage(width: 10, height: 10, top: .red)
        let expectation = self.expectation(description: "published")
        var pending = Set((0 ..< 600).map { "\($0)" })
        var calls = 0
        var delivered = 0
        var lastCall = 0.0
        store.onThumbnailsChanged = { ids in
            calls += 1
            delivered += ids.count
            pending.subtract(ids)
            if pending.isEmpty {
                lastCall = CACurrentMediaTime()
                expectation.fulfill()
            }
        }
        let start = CACurrentMediaTime()
        DispatchQueue.global(qos: .userInitiated).async {
            for batch in 0 ..< 50 {
                for i in 0 ..< 12 {
                    store.write(image, id: "\(batch * 12 + i)", version: "1")
                }
                Thread.sleep(forTimeInterval: 0.01)
            }
        }
        self.wait(for: [expectation], timeout: 5.0)
        let frames = Int(((lastCall - start) * 60.0).rounded(.up))
        XCTAssertLessThanOrEqual(calls, frames + 1)
        XCTAssertGreaterThan(calls, 1)
        XCTAssertEqual(delivered, 600)
    }

    func testFailedDrawRollsBackIndex() {
        let store = MediaGridThumbnailStore(directory: nil, slotPixelSize: 0)
        var calls = 0
        store.onThumbnailsChanged = { _ in
            calls += 1
        }
        store.write(self.makeImage(width: 10, height: 10, top: .red), id: "a", version: "1")
        let settle = self.expectation(description: "settle")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            settle.fulfill()
        }
        self.wait(for: [settle], timeout: 5.0)
        XCTAssertNil(store.version(for: "a"))
        XCTAssertNil(store.thumbnail(for: "a"))
        XCTAssertEqual(calls, 0)
    }

    func testRemovalIsReported() {
        let store = MediaGridThumbnailStore(directory: nil)
        let image = self.makeImage(width: 10, height: 10, top: .red)
        self.write(store, [("a", image, "1"), ("b", image, "1")])
        let expectation = self.expectation(description: "removed")
        store.onThumbnailsChanged = { ids in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertNil(store.thumbnail(for: "a"))
            if ids.contains("a") {
                expectation.fulfill()
            }
        }
        store.remove(ids: ["a", "missing"])
        self.wait(for: [expectation], timeout: 5.0)
        XCTAssertNotNil(store.thumbnail(for: "b"))
    }

    func testRemoveWhilePublishPendingNeverResurrects() {
        let store = MediaGridThumbnailStore(directory: nil)
        let expectation = self.expectation(description: "published")
        store.onThumbnailsChanged = { ids in
            XCTAssertNil(store.thumbnail(for: "a"))
            if ids.contains("b") {
                expectation.fulfill()
            }
        }
        store.write(self.makeImage(width: 10, height: 10, top: .red), id: "a", version: "1")
        store.remove(ids: ["a"])
        store.write(self.makeImage(width: 10, height: 10, top: .blue), id: "b", version: "1")
        XCTAssertNil(store.thumbnail(for: "a"))
        self.wait(for: [expectation], timeout: 5.0)
        let settle = self.expectation(description: "settle")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            settle.fulfill()
        }
        self.wait(for: [settle], timeout: 5.0)
        XCTAssertNil(store.thumbnail(for: "a"))
        XCTAssertNil(store.version(for: "a"))
        let thumbnail = store.thumbnail(for: "b")!
        XCTAssertEqual(thumbnail.contentsRect.origin, .zero)
        let pixel = self.sample(thumbnail.image, x: 24, y: 24)
        XCTAssertEqual(pixel.b, 255)
        XCTAssertEqual(pixel.r, 0)
    }

    func testThumbnailOnMainIsCheap() {
        let store = MediaGridThumbnailStore(directory: nil)
        let image = self.makeImage(width: 10, height: 10, top: .red)
        let ids = (0 ..< 256).map { "\($0)" }
        self.write(store, ids.map { ($0, image, "1") })
        var found = 0
        let start = CACurrentMediaTime()
        for i in 0 ..< 10_000 {
            if store.thumbnail(for: ids[i & 255]) != nil {
                found += 1
            }
        }
        let elapsed = CACurrentMediaTime() - start
        XCTAssertEqual(found, 10_000)
        XCTAssertLessThan(elapsed, 0.05)
    }

    private var isMeasuring: Bool {
        return ProcessInfo.processInfo.environment["MEDIAGRID_MEASURE"] == "1"
    }

    private func measure(_ line: String) {
        if self.isMeasuring {
            print("MEASURE \(line)")
        }
    }

    private func makeDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("MediaGridThumbnailStoreTests-\(UUID().uuidString)", isDirectory: true)
        self.addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return url
    }

    private func color(_ i: Int) -> UIColor {
        return UIColor(hue: CGFloat(i % 29) / 29.0, saturation: 0.85, brightness: 0.4 + CGFloat(i % 5) * 0.12, alpha: 1.0)
    }

    private func components(_ color: UIColor) -> (r: Int, g: Int, b: Int) {
        var r: CGFloat = 0.0
        var g: CGFloat = 0.0
        var b: CGFloat = 0.0
        var a: CGFloat = 0.0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Int((r * 255.0).rounded()), Int((g * 255.0).rounded()), Int((b * 255.0).rounded()))
    }

    private func spin(until condition: () -> Bool, timeout: Double = 10.0) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline {
                return false
            }
            RunLoop.main.run(until: Date().addingTimeInterval(0.005))
        }
        return true
    }

    private func pause(_ seconds: Double) {
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    }

    private func load(_ store: MediaGridThumbnailStore) {
        let expectation = self.expectation(description: "loaded")
        store.load {
            XCTAssertTrue(Thread.isMainThread)
            expectation.fulfill()
        }
        self.wait(for: [expectation], timeout: 20.0)
    }

    private func flush(_ store: MediaGridThumbnailStore) {
        let expectation = self.expectation(description: "flushed")
        store.flush {
            XCTAssertTrue(Thread.isMainThread)
            expectation.fulfill()
        }
        self.wait(for: [expectation], timeout: 20.0)
    }

    private func prepare(_ store: MediaGridThumbnailStore, _ ids: [String], file: StaticString = #filePath, line: UInt = #line) {
        store.prepare(ids: ids)
        XCTAssertTrue(self.spin(until: { ids.allSatisfy { store.thumbnail(for: $0) != nil } }), file: file, line: line)
    }

    private func pageFiles(_ directory: URL) -> [URL] {
        let urls = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return urls.filter { $0.pathExtension == "jpg" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private func fillPersisted(_ directory: URL, count: Int, budget: Int = 32) {
        let store = MediaGridThumbnailStore(directory: directory, decodedPageBudget: budget)
        self.load(store)
        self.write(store, (0 ..< count).map { ("\($0)", self.makeImage(width: 10, height: 10, top: self.color($0)), "v\($0)") })
        self.flush(store)
    }

    private func assertTileColor(_ store: MediaGridThumbnailStore, _ id: String, _ color: UIColor, tolerance: Int = 14, file: StaticString = #filePath, line: UInt = #line) {
        guard let thumbnail = store.thumbnail(for: id) else {
            XCTFail("no thumbnail for \(id)", file: file, line: line)
            return
        }
        let x = Int(thumbnail.contentsRect.midX * 768.0)
        let y = Int(thumbnail.contentsRect.midY * 768.0)
        let pixel = self.sample(thumbnail.image, x: x, y: y)
        let expected = self.components(color)
        XCTAssertLessThanOrEqual(abs(Int(pixel.r) - expected.r), tolerance, "r of \(id)", file: file, line: line)
        XCTAssertLessThanOrEqual(abs(Int(pixel.g) - expected.g), tolerance, "g of \(id)", file: file, line: line)
        XCTAssertLessThanOrEqual(abs(Int(pixel.b) - expected.b), tolerance, "b of \(id)", file: file, line: line)
    }

    func testRoundTripAcrossInstances() {
        let directory = self.makeDirectory()
        let first = MediaGridThumbnailStore(directory: directory)
        self.load(first)
        var items: [(String, CGImage, String)] = []
        for i in 0 ..< 300 {
            let image = i % 3 == 0 ? self.makeImage(width: 200, height: 100, top: self.color(i)) : self.makeImage(width: 10, height: 10, top: self.color(i))
            items.append(("\(i)", image, "v\(i)"))
        }
        self.write(first, items)
        let rects = Dictionary(uniqueKeysWithValues: (0 ..< 300).map { ("\($0)", first.thumbnail(for: "\($0)")!.contentsRect) })
        self.flush(first)
        XCTAssertEqual(self.pageFiles(directory).count, 2)

        let second = MediaGridThumbnailStore(directory: directory)
        self.load(second)
        XCTAssertEqual(second.version(for: "17"), "v17")
        XCTAssertNil(second.thumbnail(for: "17"))
        XCTAssertEqual(second.decodedPageCount, 0)
        let ids = (0 ..< 300).map { "\($0)" }
        self.prepare(second, ids)
        XCTAssertEqual(second.decodedPageCount, 2)
        for i in 0 ..< 300 {
            let id = "\(i)"
            XCTAssertEqual(second.version(for: id), "v\(i)")
            self.assertRect(second.thumbnail(for: id)!.contentsRect, rects[id]!)
        }
        let pages = [0: self.pixels(of: second.thumbnail(for: "0")!.image), 1: self.pixels(of: second.thumbnail(for: "256")!.image)]
        for i in 0 ..< 300 {
            let rect = second.thumbnail(for: "\(i)")!.contentsRect
            let (data, width) = pages[i / 256]!
            let offset = (Int(rect.midY * 768.0) * width + Int(rect.midX * 768.0)) * 4
            let expected = self.components(self.color(i))
            XCTAssertLessThanOrEqual(abs(Int(data[offset]) - expected.r), 14, "r of \(i)")
            XCTAssertLessThanOrEqual(abs(Int(data[offset + 1]) - expected.g), 14, "g of \(i)")
            XCTAssertLessThanOrEqual(abs(Int(data[offset + 2]) - expected.b), 14, "b of \(i)")
        }
        self.write(second, [("300", self.makeImage(width: 10, height: 10, top: .red), "v300")])
        self.assertRect(second.thumbnail(for: "300")!.contentsRect, CGRect(x: 576.0 * self.unit, y: 96.0 * self.unit, width: 48.0 * self.unit, height: 48.0 * self.unit))
    }

    func testWriteIntoOnDiskPageKeepsOtherTiles() {
        let directory = self.makeDirectory()
        self.fillPersisted(directory, count: 10)
        let second = MediaGridThumbnailStore(directory: directory)
        self.load(second)
        self.write(second, [("x", self.makeImage(width: 10, height: 10, top: .red), "1")])
        for i in 0 ..< 10 {
            self.assertTileColor(second, "\(i)", self.color(i))
        }
        self.flush(second)
        let third = MediaGridThumbnailStore(directory: directory)
        self.load(third)
        self.prepare(third, (0 ..< 10).map { "\($0)" } + ["x"])
        for i in 0 ..< 10 {
            self.assertTileColor(third, "\(i)", self.color(i))
        }
        self.assertTileColor(third, "x", .red)
        XCTAssertEqual(self.pageFiles(directory).count, 1)
    }

    func testCorruptIndexStartsEmpty() {
        let variants: [(Data) -> Data] = [
            { _ in Data([1, 2, 3]) },
            { data in data.prefix(data.count - 3) },
            { data in
                var copy = data
                copy[4] = 99
                return copy
            },
            { data in
                var copy = data
                copy.append(7)
                return copy
            }
        ]
        for variant in variants {
            let directory = self.makeDirectory()
            self.fillPersisted(directory, count: 20)
            let indexURL = directory.appendingPathComponent("index.bin")
            let data = try! Data(contentsOf: indexURL)
            try! variant(data).write(to: indexURL)
            XCTAssertEqual(self.pageFiles(directory).count, 1)
            let store = MediaGridThumbnailStore(directory: directory)
            self.load(store)
            XCTAssertNil(store.version(for: "3"))
            XCTAssertNil(store.thumbnail(for: "3"))
            XCTAssertEqual(self.pageFiles(directory).count, 0)
            self.write(store, [("a", self.makeImage(width: 10, height: 10, top: .red), "1")])
            XCTAssertEqual(store.thumbnail(for: "a")!.contentsRect.origin, .zero)
        }
        let directory = self.makeDirectory()
        let store = MediaGridThumbnailStore(directory: directory)
        self.load(store)
        XCTAssertNil(store.version(for: "a"))
    }

    func testCorruptPageGivesNilNotCrash() {
        for corruption in [Data([0xFF, 0xD8, 0xFF, 0x00, 0x01]), Data()] {
            let directory = self.makeDirectory()
            self.fillPersisted(directory, count: 260)
            let files = self.pageFiles(directory)
            XCTAssertEqual(files.count, 2)
            let page0 = files.first { $0.lastPathComponent.hasPrefix("0-") }!
            try! corruption.write(to: page0)
            let store = MediaGridThumbnailStore(directory: directory)
            self.load(store)
            var reported = Set<String>()
            store.onThumbnailsChanged = { ids in
                reported.formUnion(ids)
            }
            store.prepare(ids: ["5", "257"])
            XCTAssertTrue(self.spin(until: { reported.contains("5") && store.thumbnail(for: "257") != nil }))
            XCTAssertNil(store.thumbnail(for: "5"))
            XCTAssertNil(store.version(for: "5"))
            XCTAssertNil(store.version(for: "200"))
            XCTAssertEqual(store.version(for: "257"), "v257")
            XCTAssertFalse(FileManager.default.fileExists(atPath: page0.path))
            self.write(store, [("new", self.makeImage(width: 10, height: 10, top: .blue), "1")])
            XCTAssertEqual(store.thumbnail(for: "new")!.contentsRect.origin, .zero)
        }
    }

    func testMissingPageDropsItsEntriesLazily() {
        let directory = self.makeDirectory()
        self.fillPersisted(directory, count: 260)
        let page1 = self.pageFiles(directory).first { $0.lastPathComponent.hasPrefix("1-") }!
        try! FileManager.default.removeItem(at: page1)
        let store = MediaGridThumbnailStore(directory: directory)
        self.load(store)
        XCTAssertEqual(store.version(for: "258"), "v258")
        var reported = Set<String>()
        store.onThumbnailsChanged = { ids in
            reported.formUnion(ids)
        }
        store.prepare(ids: ["258"])
        XCTAssertTrue(self.spin(until: { reported.contains("258") }))
        XCTAssertNil(store.version(for: "258"))
        XCTAssertNil(store.version(for: "256"))
        XCTAssertEqual(store.version(for: "0"), "v0")
    }

    func testPrepareDecodesOffMainAndNotifies() {
        let directory = self.makeDirectory()
        self.fillPersisted(directory, count: 600)
        let store = MediaGridThumbnailStore(directory: directory)
        self.load(store)
        var decodedOnMain: [Bool] = []
        let lock = NSLock()
        store.didDecodePage = { _, isMain in
            lock.lock()
            decodedOnMain.append(isMain)
            lock.unlock()
        }
        var reported: [Set<String>] = []
        store.onThumbnailsChanged = { ids in
            XCTAssertTrue(Thread.isMainThread)
            reported.append(ids)
        }
        store.prepare(ids: ["10", "300", "301"])
        XCTAssertNil(store.thumbnail(for: "10"))
        XCTAssertEqual(store.decodedPageCount, 0)
        XCTAssertTrue(self.spin(until: { store.thumbnail(for: "10") != nil && store.thumbnail(for: "300") != nil }))
        XCTAssertNil(store.thumbnail(for: "520"))
        XCTAssertEqual(store.decodedPageCount, 2)
        let all = reported.reduce(into: Set<String>()) { $0.formUnion($1) }
        XCTAssertTrue(all.isSuperset(of: Set((0 ..< 512).map { "\($0)" })))
        XCTAssertFalse(all.contains("520"))
        lock.lock()
        XCTAssertEqual(decodedOnMain, [false, false])
        lock.unlock()
    }

    func testPrepareDecodesMostRecentFirstAndDropsSuperseded() {
        let directory = self.makeDirectory()
        self.fillPersisted(directory, count: 256 * 8)
        let store = MediaGridThumbnailStore(directory: directory, decodedPageBudget: 32)
        self.load(store)
        var order: [Int] = []
        var released = false
        let lock = NSLock()
        let gate = DispatchSemaphore(value: 0)
        store.didDecodePage = { page, _ in
            lock.lock()
            order.append(page)
            let wait = !released
            lock.unlock()
            if wait {
                gate.wait()
            }
        }
        store.prepare(ids: ["0", "256", "512"])
        self.pause(0.05)
        store.prepare(ids: ["768", "1024", "1280"])
        self.pause(0.05)
        store.prepare(ids: ["1792", "1536"])
        self.pause(0.05)
        lock.lock()
        released = true
        XCTAssertEqual(Set(order), [0, 1, 2])
        lock.unlock()
        gate.signal()
        gate.signal()
        gate.signal()
        XCTAssertTrue(self.spin(until: { store.thumbnail(for: "1792") != nil && store.thumbnail(for: "1536") != nil && store.thumbnail(for: "0") != nil }))
        self.pause(0.2)
        lock.lock()
        XCTAssertEqual(Set(order.prefix(3)), [0, 1, 2])
        XCTAssertEqual(Set(order.dropFirst(3)), [6, 7])
        lock.unlock()
        XCTAssertNil(store.thumbnail(for: "768"))
        XCTAssertEqual(store.decodedPageCount, 5)
    }

    func testPrepareCapsAtBudgetMostImportantFirst() {
        let directory = self.makeDirectory()
        self.fillPersisted(directory, count: 256 * 8)
        let store = MediaGridThumbnailStore(directory: directory, decodedPageBudget: 8)
        XCTAssertEqual(store.pageImageCapacity, 6)
        self.load(store)
        let ids = (0 ..< 8).reversed().map { "\($0 * 256)" }
        store.prepare(ids: ids)
        XCTAssertTrue(self.spin(until: { ids.prefix(6).allSatisfy { store.thumbnail(for: $0) != nil } }))
        self.pause(0.2)
        XCTAssertEqual(store.decodedPageCount, 6)
        XCTAssertNil(store.thumbnail(for: "256"))
        XCTAssertNil(store.thumbnail(for: "0"))
    }

    func testPrepareReplacesQueueAndSkipsUnchangedList() {
        let directory = self.makeDirectory()
        self.fillPersisted(directory, count: 256 * 8)
        let store = MediaGridThumbnailStore(directory: directory, decodedPageBudget: 32)
        self.load(store)
        var order: [Int] = []
        var released = false
        let lock = NSLock()
        let gate = DispatchSemaphore(value: 0)
        store.didDecodePage = { page, _ in
            lock.lock()
            order.append(page)
            let wait = !released
            lock.unlock()
            if wait {
                gate.wait()
            }
        }
        let first = ["0", "256", "512", "768", "1024"]
        store.prepare(ids: first)
        let plans = store.preparePlanCount
        store.prepare(ids: first)
        XCTAssertEqual(store.preparePlanCount, plans)
        store.prepare(ids: ["1280"])
        XCTAssertEqual(store.preparePlanCount, plans + 1)
        self.pause(0.05)
        lock.lock()
        released = true
        lock.unlock()
        gate.signal()
        gate.signal()
        gate.signal()
        XCTAssertTrue(self.spin(until: { store.thumbnail(for: "1280") != nil }))
        self.pause(0.2)
        lock.lock()
        XCTAssertEqual(Set(order), [0, 1, 2, 5])
        lock.unlock()
        XCTAssertNil(store.thumbnail(for: "768"))
        XCTAssertNil(store.thumbnail(for: "1024"))
    }

    func testBudgetEvictsLeastRecent() {
        let directory = self.makeDirectory()
        self.fillPersisted(directory, count: 256 * 8)
        let store = MediaGridThumbnailStore(directory: directory, decodedPageBudget: 8)
        XCTAssertEqual(store.writerContextLimit, 2)
        XCTAssertEqual(store.pageImageCapacity, 6)
        self.load(store)
        for page in 0 ..< 6 {
            self.prepare(store, ["\(page * 256)"])
        }
        XCTAssertEqual(store.decodedPageCount, 6)
        _ = store.thumbnail(for: "0")
        self.prepare(store, ["\(6 * 256)"])
        XCTAssertEqual(store.decodedPageCount, 6)
        XCTAssertNotNil(store.thumbnail(for: "0"))
        XCTAssertNil(store.thumbnail(for: "256"))
        self.prepare(store, ["\(7 * 256)", "256"])
        XCTAssertEqual(store.decodedPageCount, 6)
        XCTAssertNil(store.thumbnail(for: "512"))
        XCTAssertNil(store.thumbnail(for: "768"))
        XCTAssertNotNil(store.thumbnail(for: "1024"))
        XCTAssertNotNil(store.thumbnail(for: "0"))
    }

    func testDirtyPageNotEvicted() {
        let directory = self.makeDirectory()
        self.fillPersisted(directory, count: 256 * 8)
        let store = MediaGridThumbnailStore(directory: directory, decodedPageBudget: 8)
        store.diskFlushDelay = 60.0
        self.load(store)
        self.write(store, [("0", self.makeImage(width: 10, height: 10, top: .red), "new")])
        for page in 1 ..< 8 {
            self.prepare(store, ["\(page * 256)"])
            XCTAssertLessThanOrEqual(store.decodedPageCount, 6)
        }
        self.assertTileColor(store, "0", .red, tolerance: 0)
        self.assertTileColor(store, "1", self.color(1))
        self.flush(store)
        self.prepare(store, ["256", "512", "768", "1024", "1280", "1536"])
        XCTAssertEqual(store.decodedPageCount, 6)
        XCTAssertNil(store.thumbnail(for: "0"))
        self.prepare(store, ["0"])
        self.assertTileColor(store, "0", .red)
        let reopened = MediaGridThumbnailStore(directory: directory)
        self.load(reopened)
        XCTAssertEqual(reopened.version(for: "0"), "new")
    }

    func testWriterContextsStayBounded() {
        let directory = self.makeDirectory()
        let store = MediaGridThumbnailStore(directory: directory, decodedPageBudget: 8)
        store.diskFlushDelay = 60.0
        self.load(store)
        let image = self.makeImage(width: 10, height: 10, top: .green)
        self.write(store, (0 ..< 256 * 6).map { ("\($0)", image, "1") })
        XCTAssertLessThanOrEqual(store.writerContextCount(), 2)
        self.flush(store)
        let reopened = MediaGridThumbnailStore(directory: directory)
        self.load(reopened)
        self.prepare(reopened, (0 ..< 6).map { "\($0 * 256 + 7)" })
        for page in 0 ..< 6 {
            self.assertTileColor(reopened, "\(page * 256 + 7)", .green)
        }
    }

    func testFlushesWithinDelayAfterLastWrite() {
        let directory = self.makeDirectory()
        let store = MediaGridThumbnailStore(directory: directory)
        store.diskFlushDelay = 0.2
        store.indexIdleDelay = 0.2
        self.load(store)
        self.write(store, [("a", self.makeImage(width: 10, height: 10, top: .red), "1")])
        XCTAssertTrue(self.spin(until: { FileManager.default.fileExists(atPath: directory.appendingPathComponent("index.bin").path) }, timeout: 3.0))
        let reopened = MediaGridThumbnailStore(directory: directory)
        self.load(reopened)
        XCTAssertEqual(reopened.version(for: "a"), "1")
        let defaults = MediaGridThumbnailStore(directory: nil)
        XCTAssertEqual(defaults.diskFlushDelay, 2.0)
        XCTAssertEqual(defaults.indexIdleDelay, 2.0)
        XCTAssertEqual(defaults.indexMaxInterval, 30.0)
        XCTAssertEqual(MediaGridThumbnailStore.pageQuality, 0.6)
    }

    func testSupersededPageFilesDeletedAfterIndex() {
        let directory = self.makeDirectory()
        let store = MediaGridThumbnailStore(directory: directory)
        self.load(store)
        self.write(store, [("a", self.makeImage(width: 10, height: 10, top: .red), "1")])
        self.flush(store)
        let firstFiles = self.pageFiles(directory)
        XCTAssertEqual(firstFiles.count, 1)
        self.write(store, [("b", self.makeImage(width: 10, height: 10, top: .blue), "1")])
        self.flush(store)
        let secondFiles = self.pageFiles(directory)
        XCTAssertEqual(secondFiles.count, 1)
        XCTAssertNotEqual(firstFiles, secondFiles)
        try! Data([1, 2]).write(to: directory.appendingPathComponent("0-999.jpg"))
        let reopened = MediaGridThumbnailStore(directory: directory)
        self.load(reopened)
        self.flush(reopened)
        XCTAssertEqual(self.pageFiles(directory), secondFiles)
    }

    func testRemovedSlotReusedAcrossRelaunchNeverShowsOldPixels() {
        let directory = self.makeDirectory()
        let store = MediaGridThumbnailStore(directory: directory)
        self.load(store)
        self.write(store, [("a", self.makeImage(width: 10, height: 10, top: .red), "1"), ("b", self.makeImage(width: 10, height: 10, top: .green), "1")])
        self.flush(store)
        store.remove(ids: ["a"])
        self.flush(store)
        let reopened = MediaGridThumbnailStore(directory: directory)
        self.load(reopened)
        XCTAssertNil(reopened.version(for: "a"))
        self.write(reopened, [("c", self.makeImage(width: 10, height: 10, top: .blue), "1")])
        XCTAssertEqual(reopened.thumbnail(for: "c")!.contentsRect.origin, .zero)
        self.assertTileColor(reopened, "c", .blue, tolerance: 0)
        self.assertTileColor(reopened, "b", .green)
    }

    func testWriteBeforeLoadAppliesAfterLoad() {
        let directory = self.makeDirectory()
        self.fillPersisted(directory, count: 5)
        let store = MediaGridThumbnailStore(directory: directory)
        store.write(self.makeImage(width: 10, height: 10, top: .red), id: "late", version: "1")
        store.flush(completion: nil)
        self.load(store)
        XCTAssertEqual(store.version(for: "late"), "1")
        XCTAssertEqual(store.version(for: "4"), "v4")
        XCTAssertTrue(self.spin(until: { store.thumbnail(for: "late") != nil }))
        self.assertRect(store.thumbnail(for: "late")!.contentsRect, CGRect(x: 240.0 * self.unit, y: 0.0, width: 48.0 * self.unit, height: 48.0 * self.unit))
        self.assertTileColor(store, "2", self.color(2))
    }

    func testTrimToVisibleKeepsVisiblePages() {
        let directory = self.makeDirectory()
        self.fillPersisted(directory, count: 256 * 4)
        let store = MediaGridThumbnailStore(directory: directory)
        self.load(store)
        self.prepare(store, ["0", "256", "512", "768"])
        XCTAssertEqual(store.decodedPageCount, 4)
        store.trimToVisible(ids: ["300", "301"])
        XCTAssertEqual(store.decodedPageCount, 1)
        XCTAssertNotNil(store.thumbnail(for: "300"))
        XCTAssertNil(store.thumbnail(for: "0"))
        XCTAssertNil(store.thumbnail(for: "768"))
        self.prepare(store, ["0"])
        store.trimToVisible(ids: ["301"])
        XCTAssertEqual(store.decodedPageCount, 1)
        XCTAssertNotNil(store.thumbnail(for: "301"))
        XCTAssertNil(store.thumbnail(for: "0"))
    }

    func testMemoryWarningKeepsVisibleAndLastPreparedPages() {
        let directory = self.makeDirectory()
        self.fillPersisted(directory, count: 256 * 4)
        let store = MediaGridThumbnailStore(directory: directory)
        self.load(store)
        self.prepare(store, ["512"])
        store.trimToVisible(ids: ["512"])
        self.prepare(store, ["0", "256"])
        NotificationCenter.default.post(name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        XCTAssertEqual(store.decodedPageCount, 3)
        self.prepare(store, ["768"])
        NotificationCenter.default.post(name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        XCTAssertEqual(store.decodedPageCount, 2)
        XCTAssertNotNil(store.thumbnail(for: "512"))
        XCTAssertNotNil(store.thumbnail(for: "768"))
        XCTAssertNil(store.thumbnail(for: "0"))
    }

    func testBackgroundFlushesThenTrims() {
        let directory = self.makeDirectory()
        self.fillPersisted(directory, count: 256 * 3)
        let store = MediaGridThumbnailStore(directory: directory)
        store.diskFlushDelay = 60.0
        self.load(store)
        self.prepare(store, ["0", "256", "512"])
        store.trimToVisible(ids: ["0", "256", "512"])
        self.write(store, [("1000", self.makeImage(width: 10, height: 10, top: .red), "1")])
        store.trimToVisible(ids: ["1"])
        XCTAssertEqual(store.decodedPageCount, 2)
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        XCTAssertTrue(self.spin(until: { store.decodedPageCount == 1 }))
        XCTAssertNotNil(store.thumbnail(for: "1"))
        let reopened = MediaGridThumbnailStore(directory: directory)
        self.load(reopened)
        XCTAssertEqual(reopened.version(for: "1000"), "1")
    }

    func testLoadIsOffMain() {
        let directory = self.makeDirectory()
        try! FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let count = 100_000
        var entries: [MediaGridThumbnailIndexFile.Entry] = []
        entries.reserveCapacity(count)
        for i in 0 ..< count {
            let local = i % 256
            entries.append(MediaGridThumbnailIndexFile.Entry(id: "6A1F2C3D-9B8E-4F7A-8C6D-\(String(format: "%012d", i))/L0/001", version: "\(780000000.0 + Double(i))", slot: i, x: (local % 16) * 48, y: (local / 16) * 48, width: 48, height: 48))
        }
        var pages: [Int: UInt64] = [:]
        for page in 0 ... (count - 1) / 256 {
            pages[page] = 1
        }
        let file = MediaGridThumbnailIndexFile(slotPixelSize: 48, pageSide: 16, nextStamp: 2, pages: pages, entries: entries)
        let data = file.encoded()
        try! data.write(to: directory.appendingPathComponent("index.bin"))
        let store = MediaGridThumbnailStore(directory: directory)
        final class Ticker {
            var last = CACurrentMediaTime()
            var maxGap = 0.0
            var running = true
            func tick() {
                let now = CACurrentMediaTime()
                self.maxGap = max(self.maxGap, now - self.last)
                self.last = now
                if self.running {
                    DispatchQueue.main.async {
                        self.tick()
                    }
                }
            }
        }
        let ticker = Ticker()
        var loaded = false
        let start = CACurrentMediaTime()
        var loadTime = 0.0
        ticker.tick()
        store.load {
            loadTime = CACurrentMediaTime() - start
            loaded = true
        }
        XCTAssertTrue(self.spin(until: { loaded }, timeout: 30.0))
        self.pause(0.01)
        ticker.running = false
        self.measure("index load entries=\(count) bytes=\(data.count) time=\(String(format: "%.1f", loadTime * 1000.0))ms maxMainGap=\(String(format: "%.2f", ticker.maxGap * 1000.0))ms")
        XCTAssertLessThan(ticker.maxGap, 0.008)
        XCTAssertEqual(store.version(for: entries[99_999].id), entries[99_999].version)
        XCTAssertEqual(store.version(for: entries[0].id), entries[0].version)
    }

    func testFillingAspectNeverReachesPadding() {
        let page = self.makeImage(width: 768, height: 768, top: .black)
        let drawn: [CGRect] = [
            CGRect(x: 0.0, y: 12.0, width: 48.0, height: 24.0),
            CGRect(x: 12.0, y: 0.0, width: 24.0, height: 48.0),
            CGRect(x: 0.0, y: 0.0, width: 48.0, height: 48.0),
            CGRect(x: 0.0, y: 6.0, width: 48.0, height: 36.0),
            CGRect(x: 5.0, y: 0.0, width: 38.0, height: 48.0)
        ]
        for rect in drawn {
            let contentsRect = CGRect(x: (rect.minX + 96.0) * self.unit, y: (rect.minY + 48.0) * self.unit, width: rect.width * self.unit, height: rect.height * self.unit)
            let thumbnail = MediaGridThumbnail(image: page, contentsRect: contentsRect)
            for aspect: CGFloat in [0.25, 0.5, 0.75, 1.0, 4.0 / 3.0, 1.5, 2.0, 3.0, 0.0, -1.0] {
                let filled = thumbnail.contentsRect(fillingAspect: aspect)
                XCTAssertGreaterThanOrEqual(filled.minX, contentsRect.minX - 1e-12)
                XCTAssertGreaterThanOrEqual(filled.minY, contentsRect.minY - 1e-12)
                XCTAssertLessThanOrEqual(filled.maxX, contentsRect.maxX + 1e-12)
                XCTAssertLessThanOrEqual(filled.maxY, contentsRect.maxY + 1e-12)
            }
        }
    }

    func testJPEGBleedStaysInsideSlot() {
        let directory = self.makeDirectory()
        let store = MediaGridThumbnailStore(directory: directory)
        self.load(store)
        var items: [(String, CGImage, String)] = []
        for i in 0 ..< 48 {
            let wide = i % 2 == 0
            let color: UIColor = (i + i / 16) % 2 == 0 ? .red : .blue
            items.append(("\(i)", wide ? self.makeImage(width: 200, height: 100, top: color) : self.makeImage(width: 100, height: 200, top: color), "1"))
        }
        self.write(store, items)
        self.flush(store)
        let reopened = MediaGridThumbnailStore(directory: directory)
        self.load(reopened)
        self.prepare(reopened, items.map(\.0))
        let (data, width) = self.pixels(of: reopened.thumbnail(for: "0")!.image)
        var worstNeighbour = 0
        var worstEdge = 0
        var worstInner = 0
        for (index, item) in items.enumerated() {
            let rect = reopened.thumbnail(for: item.0)!.contentsRect
            let x0 = Int((rect.minX * 768.0).rounded())
            let y0 = Int((rect.minY * 768.0).rounded())
            let x1 = Int((rect.maxX * 768.0).rounded())
            let y1 = Int((rect.maxY * 768.0).rounded())
            let isRed = (index + index / 16) % 2 == 0
            for y in y0 ..< y1 {
                for x in x0 ..< x1 {
                    let offset = (y * width + x) * 4
                    let foreign = isRed ? Int(data[offset + 2]) : Int(data[offset])
                    worstNeighbour = max(worstNeighbour, foreign)
                    let own = isRed ? Int(data[offset]) : Int(data[offset + 2])
                    if x == x0 || y == y0 || x == x1 - 1 || y == y1 - 1 {
                        worstEdge = max(worstEdge, 255 - own)
                    } else {
                        worstInner = max(worstInner, 255 - own)
                    }
                }
            }
        }
        self.measure("jpeg bleed worstForeignChannel=\(worstNeighbour) worstEdgeLoss=\(worstEdge) worstInnerLoss=\(worstInner)")
        XCTAssertLessThan(worstNeighbour, 48)
        XCTAssertLessThan(worstEdge, 96)
    }

    func testMeasurePageCodecWithSimulatorPhotos() throws {
        guard self.isMeasuring else {
            throw XCTSkip("set MEDIAGRID_MEASURE=1 to run")
        }
        guard let shared = ProcessInfo.processInfo.environment["SIMULATOR_SHARED_RESOURCES_DIRECTORY"] else {
            throw XCTSkip("not on a simulator")
        }
        let dcim = URL(fileURLWithPath: shared).appendingPathComponent("Media/DCIM/100APPLE", isDirectory: true)
        let urls = ((try? FileManager.default.contentsOfDirectory(at: dcim, includingPropertiesForKeys: nil)) ?? []).filter { $0.pathExtension.uppercased() == "JPG" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        guard urls.count >= 64 else {
            throw XCTSkip("no simulator photos at \(dcim.path)")
        }
        var images: [CGImage] = []
        for url in urls.prefix(256) {
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil), let full = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceSubsampleFactor: 8] as CFDictionary) else {
                continue
            }
            let scale = 96.0 / CGFloat(max(full.width, full.height))
            let size = CGSize(width: max(1.0, (CGFloat(full.width) * scale).rounded()), height: max(1.0, (CGFloat(full.height) * scale).rounded()))
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1.0
            format.opaque = true
            images.append(UIGraphicsImageRenderer(size: size, format: format).image { context in
                context.cgContext.interpolationQuality = .high
                context.cgContext.translateBy(x: 0.0, y: size.height)
                context.cgContext.scaleBy(x: 1.0, y: -1.0)
                context.cgContext.draw(full, in: CGRect(origin: .zero, size: size))
            }.cgImage!)
        }
        while images.count < 256 {
            images.append(images[images.count % max(1, images.count)])
        }
        let store = MediaGridThumbnailStore(directory: nil)
        self.write(store, images.enumerated().map { ("\($0.offset)", $0.element, "1") })
        let page = store.thumbnail(for: "0")!.image
        var encodeTimes: [Double] = []
        var decodeTimes: [Double] = []
        var size = 0
        for _ in 0 ..< 10 {
            let encodeStart = CACurrentMediaTime()
            let data = MediaGridThumbnailStore.encodePage(page)!
            encodeTimes.append(CACurrentMediaTime() - encodeStart)
            size = data.count
            let decodeStart = CACurrentMediaTime()
            let decoded = MediaGridThumbnailStore.decodePage(data)!
            decodeTimes.append(CACurrentMediaTime() - decodeStart)
            XCTAssertEqual(decoded.width, 768)
        }
        encodeTimes.sort()
        decodeTimes.sort()
        self.measure("page photos=\(urls.prefix(256).count) bytes=\(size) encodeMedian=\(String(format: "%.2f", encodeTimes[5] * 1000.0))ms encodeMax=\(String(format: "%.2f", encodeTimes[9] * 1000.0))ms decodeMedian=\(String(format: "%.2f", decodeTimes[5] * 1000.0))ms decodeMax=\(String(format: "%.2f", decodeTimes[9] * 1000.0))ms")
        XCTAssertGreaterThan(size, 10_000)
        XCTAssertLessThan(size, 400_000)
    }

    func testFailedPageWriteKeepsMappingConsistent() {
        let directory = self.makeDirectory()
        let store = MediaGridThumbnailStore(directory: directory, decodedPageBudget: 8)
        store.diskFlushDelay = 60.0
        store.indexIdleDelay = 60.0
        self.load(store)
        self.write(store, [("A", self.makeImage(width: 10, height: 10, top: .red), "1"), ("B", self.makeImage(width: 10, height: 10, top: .green), "1")])
        self.flush(store)
        store.failsDiskWrites = true
        store.remove(ids: ["A"])
        self.write(store, [("C", self.makeImage(width: 10, height: 10, top: .blue), "1")])
        XCTAssertEqual(store.thumbnail(for: "C")!.contentsRect.origin, .zero)
        self.flush(store)
        let image = self.makeImage(width: 10, height: 10, top: .yellow)
        self.write(store, (0 ..< 254 + 512).map { ("p\($0)", image, "1") })
        XCTAssertLessThanOrEqual(store.writerContextCount(), 2)
        self.flush(store)
        let attempts = store.pageWriteAttempts()
        self.pause(0.3)
        XCTAssertEqual(store.pageWriteAttempts(), attempts)
        XCTAssertLessThanOrEqual(store.writerContextCount(), 2)
        store.trimToVisible(ids: [])
        self.assertTileColor(store, "C", .blue, tolerance: 0)
        self.assertTileColor(store, "B", .green)

        let stale = MediaGridThumbnailStore(directory: directory)
        self.load(stale)
        XCTAssertNil(stale.version(for: "C"))
        XCTAssertNil(stale.version(for: "p0"))
        XCTAssertEqual(stale.version(for: "A"), "1")
        self.prepare(stale, ["A"])
        self.assertTileColor(stale, "A", .red)

        store.failsDiskWrites = false
        store.retryFailedWritesNow()
        XCTAssertTrue(self.spin(until: { store.unconfirmedPageCount() == 0 }))
        self.flush(store)
        store.trimToVisible(ids: [])
        XCTAssertEqual(store.decodedPageCount, 0)
        self.prepare(store, ["C", "p300", "p700"])
        self.assertTileColor(store, "C", .blue)
        self.assertTileColor(store, "p700", .yellow)

        let reopened = MediaGridThumbnailStore(directory: directory)
        self.load(reopened)
        XCTAssertNil(reopened.version(for: "A"))
        XCTAssertEqual(reopened.version(for: "p765"), "1")
        self.prepare(reopened, ["C", "B", "p0", "p765"])
        self.assertTileColor(reopened, "C", .blue)
        self.assertTileColor(reopened, "B", .green)
        self.assertTileColor(reopened, "p0", .yellow)
        self.assertTileColor(reopened, "p765", .yellow)
    }

    func testStaleDecodeNeverInstalledOverReusedSlot() {
        let directory = self.makeDirectory()
        self.fillPersisted(directory, count: 3)
        let store = MediaGridThumbnailStore(directory: directory)
        store.diskFlushDelay = 60.0
        store.indexIdleDelay = 60.0
        self.load(store)
        let gate = DispatchSemaphore(value: 0)
        let lock = NSLock()
        var blocks = true
        var reads = 0
        store.didReadPage = { _ in
            lock.lock()
            reads += 1
            let wait = blocks
            blocks = false
            lock.unlock()
            if wait {
                gate.wait()
            }
        }
        store.prepare(ids: ["0"])
        self.pause(0.05)
        store.remove(ids: ["0"])
        self.write(store, [("c", self.makeImage(width: 10, height: 10, top: .blue), "1")])
        XCTAssertEqual(store.thumbnail(for: "c")!.contentsRect.origin, .zero)
        self.flush(store)
        store.trimToVisible(ids: [])
        XCTAssertNil(store.thumbnail(for: "c"))
        gate.signal()
        XCTAssertTrue(self.spin(until: { store.thumbnail(for: "c") != nil }))
        self.pause(0.1)
        self.assertTileColor(store, "c", .blue)
        self.assertTileColor(store, "1", self.color(1))
        lock.lock()
        XCTAssertGreaterThanOrEqual(reads, 2)
        lock.unlock()
    }

    func testLostPageKeepsTheIdBeingDrawn() {
        let directory = self.makeDirectory()
        self.fillPersisted(directory, count: 5)
        for file in self.pageFiles(directory) {
            try! FileManager.default.removeItem(at: file)
        }
        let store = MediaGridThumbnailStore(directory: directory)
        self.load(store)
        XCTAssertEqual(store.version(for: "2"), "v2")
        self.write(store, [("n", self.makeImage(width: 10, height: 10, top: .red), "1")])
        XCTAssertEqual(store.version(for: "n"), "1")
        XCTAssertNil(store.version(for: "2"))
        XCTAssertNil(store.version(for: "0"))
        self.assertTileColor(store, "n", .red, tolerance: 0)
    }

    func testPaddingIsEdgeExtended() {
        let directory = self.makeDirectory()
        let store = MediaGridThumbnailStore(directory: directory)
        self.load(store)
        let wide = self.makeImage(width: 200, height: 100, top: .red, bottom: .blue)
        let tall = self.makeImage(width: 100, height: 200, top: .green, bottom: .yellow)
        self.write(store, [("wide", wide, "1"), ("tall", tall, "1")])
        let (data, width) = self.pixels(of: store.thumbnail(for: "wide")!.image)
        func pixel(_ x: Int, _ y: Int) -> [UInt8] {
            let offset = (y * width + x) * 4
            return Array(data[offset ..< offset + 4])
        }
        for x in 0 ..< 48 {
            for y in 0 ..< 12 {
                XCTAssertEqual(pixel(x, y), pixel(x, 12))
            }
            for y in 36 ..< 48 {
                XCTAssertEqual(pixel(x, y), pixel(x, 35))
            }
        }
        for y in 0 ..< 48 {
            for x in 48 ..< 60 {
                XCTAssertEqual(pixel(x, y), pixel(60, y))
            }
            for x in 84 ..< 96 {
                XCTAssertEqual(pixel(x, y), pixel(83, y))
            }
        }
        XCTAssertEqual(pixel(24, 0), [255, 0, 0, 255])
        XCTAssertEqual(pixel(24, 47), [0, 0, 255, 255])
        self.flush(store)
        let reopened = MediaGridThumbnailStore(directory: directory)
        self.load(reopened)
        self.prepare(reopened, ["wide"])
        let (decoded, decodedWidth) = self.pixels(of: reopened.thumbnail(for: "wide")!.image)
        var worst = 0
        for x in 0 ..< 48 {
            let top = (12 * decodedWidth + x) * 4
            worst = max(worst, 255 - Int(decoded[top]), Int(decoded[top + 1]), Int(decoded[top + 2]))
            let bottom = (35 * decodedWidth + x) * 4
            worst = max(worst, Int(decoded[bottom]), Int(decoded[bottom + 1]), 255 - Int(decoded[bottom + 2]))
        }
        self.measure("padding edge row worst channel error=\(worst)")
        XCTAssertLessThan(worst, 24)
    }

    func testLoadStartsWithoutBeingAsked() {
        let directory = self.makeDirectory()
        self.fillPersisted(directory, count: 3)
        let store = MediaGridThumbnailStore(directory: directory)
        store.write(self.makeImage(width: 10, height: 10, top: .red), id: "late", version: "1")
        XCTAssertTrue(self.spin(until: { store.version(for: "late") == "1" }))
        XCTAssertEqual(store.version(for: "1"), "v1")
        self.load(store)
    }

    func testIndexWaitsForIdleWhilePagesFlush() {
        let directory = self.makeDirectory()
        let store = MediaGridThumbnailStore(directory: directory)
        store.diskFlushDelay = 0.1
        store.indexIdleDelay = 0.4
        store.indexMaxInterval = 60.0
        self.load(store)
        let indexPath = directory.appendingPathComponent("index.bin").path
        let image = self.makeImage(width: 10, height: 10, top: .red)
        let start = Date()
        var i = 0
        while Date().timeIntervalSince(start) < 1.0 {
            store.write(image, id: "\(i)", version: "1")
            i += 1
            self.pause(0.05)
        }
        XCTAssertFalse(self.pageFiles(directory).isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: indexPath))
        XCTAssertTrue(self.spin(until: { FileManager.default.fileExists(atPath: indexPath) }, timeout: 2.0))

        let busyDirectory = self.makeDirectory()
        let busy = MediaGridThumbnailStore(directory: busyDirectory)
        busy.diskFlushDelay = 0.1
        busy.indexIdleDelay = 10.0
        busy.indexMaxInterval = 0.5
        self.load(busy)
        let busyIndexPath = busyDirectory.appendingPathComponent("index.bin").path
        let busyStart = Date()
        var sawIndex = false
        while Date().timeIntervalSince(busyStart) < 1.5 {
            busy.write(image, id: "\(i)", version: "1")
            i += 1
            self.pause(0.05)
            sawIndex = sawIndex || FileManager.default.fileExists(atPath: busyIndexPath)
        }
        XCTAssertTrue(sawIndex)
    }

    func testMeasureIndexWriteAndFill() throws {
        guard self.isMeasuring else {
            throw XCTSkip("set MEDIAGRID_MEASURE=1 to run")
        }
        let directory = self.makeDirectory()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var entries: [MediaGridThumbnailIndexFile.Entry] = []
        for i in 0 ..< 100_000 {
            let local = i % 256
            entries.append(MediaGridThumbnailIndexFile.Entry(id: "6A1F2C3D-9B8E-4F7A-8C6D-\(String(format: "%012d", i))/L0/001", version: "\(780000000.0 + Double(i))", slot: i, x: (local % 16) * 48, y: (local / 16) * 48, width: 48, height: 48))
        }
        var pages: [Int: UInt64] = [:]
        for page in 0 ... 99_999 / 256 {
            pages[page] = 1
        }
        var times: [Double] = []
        for _ in 0 ..< 3 {
            let start = CACurrentMediaTime()
            let data = MediaGridThumbnailIndexFile(slotPixelSize: 48, pageSide: 16, nextStamp: 2, pages: pages, entries: entries).encoded()
            try data.write(to: directory.appendingPathComponent("index-measure.bin"), options: .atomic)
            times.append(CACurrentMediaTime() - start)
        }
        self.measure("index write entries=100000 encodeAndWrite=\(times.map { String(format: "%.1f", $0 * 1000.0) }.joined(separator: ","))ms")

        let fillDirectory = self.makeDirectory()
        let store = MediaGridThumbnailStore(directory: fillDirectory)
        self.load(store)
        let images = (0 ..< 64).map { self.makeImage(width: 96, height: 72, top: self.color($0), bottom: self.color($0 + 7)) }
        final class Ticker {
            var last = CACurrentMediaTime()
            var maxGap = 0.0
            var slow = 0
            var running = true
            func tick() {
                let now = CACurrentMediaTime()
                let gap = now - self.last
                self.maxGap = max(self.maxGap, gap)
                if gap > 0.008 {
                    self.slow += 1
                }
                self.last = now
                if self.running {
                    DispatchQueue.main.async {
                        self.tick()
                    }
                }
            }
        }
        var delivered = 0
        store.onThumbnailsChanged = { ids in
            delivered += ids.count
        }
        let ticker = Ticker()
        ticker.tick()
        let start = CACurrentMediaTime()
        var done = false
        DispatchQueue.global(qos: .userInitiated).async {
            for batch in 0 ..< 500 {
                for i in 0 ..< 10 {
                    let index = batch * 10 + i
                    store.write(images[index % 64], id: "\(index)", version: "1")
                }
                Thread.sleep(forTimeInterval: 0.01)
            }
            DispatchQueue.main.async {
                done = true
            }
        }
        XCTAssertTrue(self.spin(until: { done }, timeout: 60.0))
        self.pause(2.5)
        ticker.running = false
        let elapsed = CACurrentMediaTime() - start
        let files = self.pageFiles(fillDirectory)
        let bytes = files.reduce(0) { $0 + ((try? FileManager.default.attributesOfItem(atPath: $1.path)[.size] as? Int) ?? 0) }
        self.measure("fill writes=5000 elapsed=\(String(format: "%.2f", elapsed))s maxMainGap=\(String(format: "%.2f", ticker.maxGap * 1000.0))ms gapsOver8ms=\(ticker.slow) pages=\(files.count) pageBytes=\(bytes) delivered=\(delivered)")
    }

    func testOutageBoundsUnconfirmedPages() {
        let directory = self.makeDirectory()
        let store = MediaGridThumbnailStore(directory: directory, pageSide: 2)
        store.diskFlushDelay = 0.05
        store.indexIdleDelay = 60.0
        store.retryMaxDelay = 0.2
        self.load(store)
        var changes: [Bool] = []
        store.onWritabilityChanged = { writable in
            XCTAssertTrue(Thread.isMainThread)
            changes.append(writable)
        }
        store.failsDiskWrites = true
        let image = self.makeImage(width: 10, height: 10, top: .red)
        let ids = (0 ..< 160).map { "i\($0)" }
        for id in ids {
            store.write(image, id: id, version: "1")
            self.pause(0.002)
        }
        self.pause(1.0)
        XCTAssertLessThanOrEqual(store.unconfirmedPageCount(), store.unconfirmedPageLimit)
        XCTAssertFalse(store.isWritable)
        XCTAssertEqual(changes.first, false)
        let refused = ids.filter { store.version(for: $0) == nil }
        XCTAssertGreaterThan(refused.count, 80)
        for id in refused {
            XCTAssertNil(store.thumbnail(for: id))
        }
        XCTAssertLessThanOrEqual(store.decodedPageCount, store.unconfirmedPageLimit + store.writerContextLimit)
        let attempts = store.pageWriteAttempts()
        self.pause(0.5)
        XCTAssertLessThanOrEqual(store.pageWriteAttempts() - attempts, 40)
        self.write(store, [("i0", self.makeImage(width: 10, height: 10, top: .blue), "2")])
        XCTAssertEqual(store.version(for: "i0"), "2")

        store.failsDiskWrites = false
        XCTAssertTrue(self.spin(until: { store.isWritable && store.unconfirmedPageCount() == 0 }, timeout: 5.0))
        XCTAssertEqual(changes, [false, true])
        self.write(store, refused.map { ($0, image, "1") })
        self.flush(store)
        XCTAssertTrue(self.spin(until: { store.unconfirmedPageCount() == 0 }))
        self.flush(store)
        let reopened = MediaGridThumbnailStore(directory: directory, pageSide: 2)
        self.load(reopened)
        XCTAssertEqual(ids.filter { reopened.version(for: $0) == nil }, [])
        XCTAssertEqual(reopened.version(for: "i0"), "2")
        self.prepare(reopened, ["i0", "i159", refused[0]])
        self.assertPagePixel(reopened, "i0", .blue)
        self.assertPagePixel(reopened, "i159", .red)
    }

    private func assertPagePixel(_ store: MediaGridThumbnailStore, _ id: String, _ color: UIColor, file: StaticString = #filePath, line: UInt = #line) {
        guard let thumbnail = store.thumbnail(for: id) else {
            XCTFail("no thumbnail for \(id)", file: file, line: line)
            return
        }
        let side = CGFloat(thumbnail.image.width)
        let pixel = self.sample(thumbnail.image, x: Int(thumbnail.contentsRect.midX * side), y: Int(thumbnail.contentsRect.midY * side))
        let expected = self.components(color)
        XCTAssertLessThanOrEqual(abs(Int(pixel.r) - expected.r), 14, file: file, line: line)
        XCTAssertLessThanOrEqual(abs(Int(pixel.g) - expected.g), 14, file: file, line: line)
        XCTAssertLessThanOrEqual(abs(Int(pixel.b) - expected.b), 14, file: file, line: line)
    }

    func testPermanentEncodeFailureDropsPageAndUnblocksIndex() {
        let directory = self.makeDirectory()
        self.fillPersisted(directory, count: 300)
        let store = MediaGridThumbnailStore(directory: directory)
        store.diskFlushDelay = 0.05
        store.retryMaxDelay = 0.05
        store.indexIdleDelay = 60.0
        self.load(store)
        store.failingEncodePages = [1]
        self.write(store, [("260", self.makeImage(width: 10, height: 10, top: .red), "2"), ("7", self.makeImage(width: 10, height: 10, top: .blue), "2")])
        self.flush(store)
        XCTAssertTrue(self.spin(until: { store.version(for: "260") == nil }, timeout: 5.0))
        XCTAssertNil(store.version(for: "257"))
        XCTAssertNil(store.thumbnail(for: "257"))
        XCTAssertEqual(store.version(for: "7"), "2")
        XCTAssertTrue(self.spin(until: { store.unconfirmedPageCount() == 0 }))
        store.failingEncodePages = []
        self.flush(store)
        let reopened = MediaGridThumbnailStore(directory: directory)
        self.load(reopened)
        XCTAssertNil(reopened.version(for: "257"))
        XCTAssertEqual(reopened.version(for: "7"), "2")
        XCTAssertEqual(reopened.version(for: "5"), "v5")
        self.write(store, [("257", self.makeImage(width: 10, height: 10, top: .green), "v257")])
        XCTAssertEqual(store.version(for: "257"), "v257")
    }
}
