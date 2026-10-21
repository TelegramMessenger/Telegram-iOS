import MessageWidgetRendering
import UIKit
import WidgetRuntimeIOS
import XCTest
@testable import MessageWidget

/// Spec 2026-10-15 D4: the tiles are drawn where the widget's work runs; a frame carries the tiles a task changed.
class SnapshotTests: MessageWidgetTestCase {
    func testAFramesTilesAreTheRenderersOwnImageOfEachTile() throws {
        let (instance, _) = self.booted(self.fixture("01-weather-card"), scale: 2.0)
        defer {
            instance.destroy()
        }
        let frame = instance.currentFrame
        XCTAssertEqual(frame.scale, 2.0)
        XCTAssertGreaterThan(frame.tiles.count, 3)
        XCTAssertEqual(Set(frame.tiles.keys), Set(WidgetFrame.grid(for: frame.size)))
        for (key, tile) in frame.tiles {
            let rect = WidgetFrame.rect(forKey: key, size: frame.size)
            guard let direct = self.rendererImage(instance, rect: rect, scale: 2.0) else {
                return XCTFail("no direct image of \(rect)")
            }
            XCTAssertEqual(self.bytes(of: tile), self.bytes(of: direct), "tile \(rect)")
        }
    }

    /// A tree renderer fed the tree a session published for a small page at `width`.
    private func treeRenderer(width: CGFloat) -> (WidgetTreeRenderer, WRSession)? {
        final class Delegate: NSObject, WRSessionDelegate {
            func session(_ session: WRSession, diagnostic kind: String, detail: String) {}
            func session(_ session: WRSession, log level: Int, text: String) {}
            func session(_ session: WRSession, bridge method: String, args argsJson: String) {}
            func session(_ session: WRSession, didWork totalUnits: UInt64) {}
        }
        let delegate = Delegate()
        guard let session = WRSession(width: width, dark: false, scale: 2.0, delegate: delegate), session.boot(withSource: "<p>tiles</p><div style=\"height:200px\"></div>"), let tree = session.tree() else {
            return nil
        }
        let renderer = WidgetTreeRenderer(width: width)
        renderer.publish(tree, changed: nil, contentSize: session.contentSize)
        objc_setAssociatedObject(session, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)
        return (renderer, session)
    }

    func testTheDrawerDrawsEveryTileFirstAndNothingWhenNothingChanged() {
        guard let (renderer, _) = self.treeRenderer(width: 300.0) else {
            return XCTFail("no renderer")
        }
        let drawer = WidgetTileDrawer(scale: 2.0)
        let first = drawer.draw(renderer)
        XCTAssertEqual(first.size, renderer.documentSize)
        XCTAssertEqual(Set(first.tiles.keys), Set(WidgetFrame.grid(for: first.size)))
        let second = drawer.draw(renderer)
        XCTAssertEqual(second.size, first.size)
        XCTAssertTrue(second.tiles.isEmpty)
    }

    func testANewWidthDrawsEveryTileOfTheNewSize() {
        guard let (renderer, session) = self.treeRenderer(width: 300.0) else {
            return XCTFail("no renderer")
        }
        let drawer = WidgetTileDrawer(scale: 2.0)
        _ = drawer.draw(renderer)
        renderer.setWidth(140.0)
        session.setWidth(140.0)
        guard let tree = session.tree() else {
            return XCTFail("no tree at the new width")
        }
        renderer.publish(tree, changed: session.changedRects()?.map { $0.cgRectValue }, contentSize: session.contentSize)
        let narrow = drawer.draw(renderer)
        XCTAssertEqual(narrow.size.width, 140.0)
        XCTAssertEqual(Set(narrow.tiles.keys), Set(WidgetFrame.grid(for: narrow.size)))
    }

    func testTheGridCoversTheSizeInTilesOf128Points() {
        let size = CGSize(width: 300.0, height: 129.0)
        XCTAssertEqual(Set(WidgetFrame.grid(for: size)), [WidgetFrame.key(row: 0, column: 0), WidgetFrame.key(row: 0, column: 1), WidgetFrame.key(row: 0, column: 2), WidgetFrame.key(row: 1, column: 0), WidgetFrame.key(row: 1, column: 1), WidgetFrame.key(row: 1, column: 2)])
        XCTAssertEqual(WidgetFrame.rect(forKey: WidgetFrame.key(row: 1, column: 2), size: size), CGRect(x: 256.0, y: 128.0, width: 44.0, height: 1.0))
        XCTAssertTrue(WidgetFrame.grid(for: .zero).isEmpty)
    }

    /// The image's pixels as RGBA bytes.
    private func bytes(of image: CGImage) -> Data {
        let width = image.width, height = image.height
        var data = Data(count: width * height * 4)
        data.withUnsafeMutableBytes { raw in
            let context = CGContext(data: raw.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            context?.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        return data
    }
}
