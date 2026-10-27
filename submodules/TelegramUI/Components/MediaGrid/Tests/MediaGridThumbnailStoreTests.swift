import XCTest
import UIKit
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
        XCTAssertEqual(self.sample(thumbnail.image, x: 24, y: 6).a, 0)
        XCTAssertEqual(self.sample(thumbnail.image, x: 24, y: 41).a, 0)
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
        XCTAssertEqual(self.sample(thumbnail.image, x: 24, y: 4).a, 0)
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
        XCTAssertEqual(self.sample(thumbnail.image, x: 24, y: 4).a, 0)
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
        XCTAssertLessThan(elapsed, 0.005)
    }
}
