import XCTest
import UIKit
import WidgetRuntimeIOS

/// Tier 1 (in the app process, where Core Image paints CSS filters: a hostless test process has no Metal device and
/// paints none): the tiles of a draw share one effect store (twidget edit 64), and a tile painted through it is the tile
/// painted without one, pixel for pixel: a blur, a drop shadow over a gradient with a backdrop inside it, a backdrop
/// over several tiles, and a blur under a scale.
final class WidgetHarnessEffectTests: XCTestCase {
    private final class Delegate: NSObject, WRSessionDelegate {
        func session(_ session: WRSession, diagnostic kind: String, detail: String) {}
        func session(_ session: WRSession, log level: Int, text: String) {}
        func session(_ session: WRSession, bridge method: String, args argsJson: String) {}
    }

    private static let page = """
    <body style="margin:0;background:#fff">
    <div style="position:absolute;left:20px;top:20px;width:300px;height:150px;background:#e02674;filter:blur(12px)"></div>
    <div style="position:absolute;left:40px;top:200px;width:280px;height:120px;background:linear-gradient(90deg,#24083d,#ffa43b);filter:drop-shadow(4px 6px 8px #000a) brightness(1.2)">
    <div style="position:absolute;left:30px;top:20px;width:200px;height:60px;background:rgba(255,255,255,.2);backdrop-filter:blur(6px)"></div></div>
    <div style="position:absolute;left:100px;top:90px;width:180px;height:160px;border-radius:12px;backdrop-filter:blur(5px) saturate(1.5)"></div>
    <div style="position:absolute;left:60px;top:340px;width:200px;height:80px;background:#3a8;transform:scale(1.1);filter:blur(3px)"></div>
    <div style="height:440px"></div>
    </body>
    """

    private func rgba(_ image: CGImage) -> [UInt8] {
        var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
        pixels.withUnsafeMutableBytes { bytes in
            let context = CGContext(data: bytes.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            context?.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        return pixels
    }

    func testATilePaintedThroughTheDrawsStoreIsTheTilePaintedAlone() throws {
        let delegate = Delegate()
        let session = try XCTUnwrap(WRSession(width: 360.0, dark: false, scale: 3.0, delegate: delegate))
        XCTAssertTrue(session.boot(withSource: WidgetHarnessEffectTests.page))
        let tree = try XCTUnwrap(session.tree())
        let effects = WREffectStore()
        var tiles = 0
        for row in 0 ..< 4 {
            for column in 0 ..< 3 {
                let rect = CGRect(x: CGFloat(column) * 128.0, y: CGFloat(row) * 128.0, width: column == 2 ? 104.0 : 128.0, height: 128.0)
                let alone = try XCTUnwrap(tree.copyImage(of: rect, scale: 3.0, effects: nil))
                let shared = try XCTUnwrap(tree.copyImage(of: rect, scale: 3.0, effects: effects))
                XCTAssertTrue(self.rgba(alone) == self.rgba(shared), "tile \(rect)")
                tiles += 1
            }
        }
        // Fewer effects made than tiles that show them: the store shared them.
        XCTAssertGreaterThan(effects.made, 0)
        XCTAssertLessThan(Int(effects.made), tiles)
        // The blur painted (a parity of two blank pictures proves nothing): the pink box's left edge, at (20, 95), is
        // between white and the box's colour.
        let edge = self.rgba(try XCTUnwrap(tree.copyImage(of: CGRect(x: 20.0, y: 95.0, width: 1.0, height: 1.0), scale: 1.0, effects: nil)))
        XCTAssertGreaterThan(edge[1], 0x40)
        XCTAssertLessThan(edge[1], 0xf0)
        withExtendedLifetime(delegate) {}
    }
}
