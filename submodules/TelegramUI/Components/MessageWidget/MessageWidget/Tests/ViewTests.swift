import UIKit
import XCTest
@testable import MessageWidget

class ViewTests: MessageWidgetTestCase {
    func testTilesCoverTheWidgetAndSurviveRelayout() throws {
        let (instance, view) = self.booted(self.fixture("01-weather-card"), scale: 3.0)
        let rows = Int(ceil(view.bounds.height / 128.0)), columns = Int(ceil(view.bounds.width / 128.0))
        XCTAssertEqual(view.tileCount, rows * columns)
        let tiles = view.tileCount
        _ = instance.layout(width: 360.0)   // same width: nothing to redo
        view.update()
        XCTAssertEqual(view.tileCount, tiles)
    }

    /// widget-sandbox v0.1.3 (integration.md "Which edge stays put"): until a resized widget's new tiles are drawn, its old
    /// picture stays on the bubble's anchored edge. A bottom-anchored widget's old tiles sit on the view's bottom (what
    /// was under the finger stays there), grown or shrunk; a top-anchored one's stay at the top; drawn tiles, or a
    /// widget yet to report, are laid from the top.
    func testStaleTilesStayOnTheAnchoredEdge() {
        XCTAssertEqual(MessageWidgetView.tileOffset(anchor: .bottom, reportedHeight: 220.0, drawnHeight: 100.0), 120.0)
        XCTAssertEqual(MessageWidgetView.tileOffset(anchor: .bottom, reportedHeight: 100.0, drawnHeight: 220.0), -120.0)
        XCTAssertEqual(MessageWidgetView.tileOffset(anchor: .top, reportedHeight: 220.0, drawnHeight: 100.0), 0.0)
        XCTAssertEqual(MessageWidgetView.tileOffset(anchor: .bottom, reportedHeight: 100.0, drawnHeight: 100.0), 0.0)
        XCTAssertEqual(MessageWidgetView.tileOffset(anchor: .bottom, reportedHeight: nil, drawnHeight: 100.0), 0.0)
    }

    /// A stopped widget is a picture, clipped rather than laid out again at a new width: at a wider one, the strip right
    /// of its document shows the canvas colour, as the view does below a short document, not the bubble through a gap.
    func testTheCanvasCoversTheStripRightOfAStoppedWidget() throws {
        let (instance, view) = self.booted("<!doctype html><body style='margin:0;background:#f00'><div style='height:60px'></div><script>for (;;) {}</script></body>", width: 300.0)
        self.settle(instance)
        XCTAssertNotNil(instance.deadReason, "the widget did not stop")
        _ = instance.layout(width: 360.0)
        view.frame = CGRect(x: 0.0, y: 0.0, width: 360.0, height: view.bounds.height)
        let image = self.render(view)
        XCTAssertEqual("\(self.pixel(image, 330, 20))", "\((r: 255, g: 0, b: 0))")
        XCTAssertEqual("\(self.pixel(image, 150, 20))", "\((r: 255, g: 0, b: 0))")
    }

    func testHugeShadowKeepsBackingWithinTheTileBound() throws {
        for css in ["box-shadow:0 0 0 2000px #000", "box-shadow:0 0 0 9999px rgba(0,0,0,.5)", "text-indent:-9999px"] {
            let (_, view) = self.booted("<!doctype html><div style='margin:40px;width:100px;height:100px;background:#fff;\(css)'>text</div>", scale: 3.0)
            let bound = Int(ceil(view.bounds.width / 128.0) * 128.0 * 3.0) * Int(ceil(view.bounds.height / 128.0) * 128.0 * 3.0)
            XCTAssertGreaterThan(view.backingPixelCount, 0, css)
            XCTAssertLessThanOrEqual(view.backingPixelCount, bound, css)
        }
    }

    /// The tiles composited are the renderer's own image of the whole widget: every tile sits where it
    /// belongs, along the seams (x and y = 128 and 256) and inside rows 1 and 2 as well as row 0.
    func testTilesMatchTheUntiledImageAcrossTheSeams() throws {
        let scale: CGFloat = 3.0
        let (instance, view) = self.booted(self.fixture("01-weather-card"), scale: scale)
        guard let whole = self.rendererImage(instance, rect: view.bounds, scale: scale) else {
            return XCTFail("no untiled image")
        }
        XCTAssertGreaterThanOrEqual(view.bounds.height, 257.0, "three tile rows expected")
        let tiled = self.render(view, scale: scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.preferredRange = .standard
        let reference = UIGraphicsImageRenderer(bounds: view.bounds, format: format).image { ctx in
            UIColor.white.setFill()
            ctx.fill(view.bounds)
            UIImage(cgImage: whole, scale: scale, orientation: .up).draw(in: view.bounds)
        }
        let width = Int(view.bounds.width * scale), height = Int(view.bounds.height * scale)
        var points: [(Int, Int)] = []
        // Both sides of every seam, all along it.
        for seam in [384, 768] {
            for x in 0 ..< width where seam < height {
                points.append((x, seam - 1))
                points.append((x, seam))
            }
            for y in 0 ..< height where seam < width {
                points.append((seam - 1, y))
                points.append((seam, y))
            }
        }
        // And across the inside of every tile.
        for y in stride(from: 0, to: height, by: 7) {
            for x in stride(from: 0, to: width, by: 7) {
                points.append((x, y))
            }
        }
        var differing: [String] = []
        var drawn = Set<Int>()
        for (x, y) in points {
            let a = self.devicePixel(tiled, x, y), b = self.devicePixel(reference, x, y)
            if abs(a.r - b.r) > 3 || abs(a.g - b.g) > 3 || abs(a.b - b.b) > 3 {
                differing.append("(\(x), \(y)): tiled \(a) untiled \(b)")
            }
            if b.r < 240 || b.g < 240 || b.b < 240 {
                drawn.insert(y / 384)
            }
        }
        XCTAssertEqual(differing.count, 0, "\(differing.count) of \(points.count) pixels differ, first \(differing.prefix(5))")
        // Something is drawn in each tile row, so the comparison is not of blank against blank.
        XCTAssertEqual(drawn, [0, 1, 2])
    }

    /// A press restyles one element in tile row 1: only the tiles its changed rect touches are drawn
    /// again, and tile row 0 keeps its images.
    func testPressRedrawsOnlyTheTilesItChanged() throws {
        let (instance, view) = self.booted("<!doctype html><style>body{margin:0}#a{height:200px;background:rgb(0,0,255)}#b{height:40px;background:rgb(255,0,0)}#b:active{background:rgb(0,255,0)}</style><div id=a></div><div id=b></div>", scale: 2.0)
        // The view holds its instance weakly: keep it alive, or the touches go nowhere.
        withExtendedLifetime(instance) {
            let before = self.tileContents(view)
            XCTAssertEqual(before.count, 6)
            XCTAssertGreaterThan(self.pixel(self.render(view, scale: 2.0), 20, 220).r, 200)
            view.handleTouch(phase: .began, at: CGPoint(x: 20.0, y: 220.0))
            let pressed = self.pixel(self.render(view, scale: 2.0), 20, 220)
            XCTAssertGreaterThan(pressed.g, 200, "\(pressed)")
            XCTAssertLessThan(pressed.r, 50, "\(pressed)")
            let after = self.tileContents(view)
            for column in 0 ..< 3 {
                XCTAssertTrue(after[TileKey(row: 0, column: column)] === before[TileKey(row: 0, column: column)], "tile (0, \(column)) was drawn again")
                XCTAssertFalse(after[TileKey(row: 1, column: column)] === before[TileKey(row: 1, column: column)], "tile (1, \(column)) was not drawn again")
            }
            view.handleTouch(phase: .ended, at: CGPoint(x: 20.0, y: 220.0))
            self.pump(0.1)
        }
    }

    /// iOS 26 and 27 deliver no real touches to a view whose layer renders nothing
    /// (docs/ios27-windows-and-touches.md); the tiles are sublayers, so the view's own layer needs contents.
    func testViewLayerHasContentsSoTouchesArrive() throws {
        let instance = self.make("<!doctype html><div>x</div>")
        let view = instance.view
        XCTAssertNotNil(view.layer.contents)
    }

    func testDimmingShadowReadsHalfGreyInTheCorner() throws {
        let (_, view) = self.booted("<!doctype html><body style='margin:0;background:#fff'><div style='margin:60px;width:50px;height:50px;box-shadow:0 0 0 9999px rgba(0,0,0,.5)'></div></body>", scale: 3.0, width: 200.0)
        let p = self.pixel(self.render(view, scale: 3.0), 2, 2)
        XCTAssert((110...145).contains(p.r), "\(p)")
    }

    /// The tiles are drawn at the scale the widget was created with (the screen's, captured on main).
    func testTilesAreDrawnAtTheScaleTheWidgetWasCreatedWith() throws {
        let (at2Instance, at2) = self.booted(self.fixture("01-weather-card"), scale: 2.0)
        let (at3Instance, at3) = self.booted(self.fixture("01-weather-card"), scale: 3.0)
        withExtendedLifetime([at2Instance, at3Instance]) {
            XCTAssertEqual(Double(at3.backingPixelCount) / Double(at2.backingPixelCount), 2.25, accuracy: 0.1)
            XCTAssertEqual(at3.contentLayerForTesting.sublayers?.first?.contentsScale, 3.0)
        }
    }

    /// A CSS transition runs through the view (V5f): right after it starts the old value is drawn, and the frames it
    /// asks for carry it to its end value. (Before V5f a declared transition was ignored and the end value drawn at once.)
    func testTransitionRunsToItsEndValue() throws {
        let (instance, view) = self.booted("""
        <div id=b style='width:100px;height:40px;background:rgb(255,0,0);transition:background .4s linear'></div>
        <script>requestAnimationFrame(() => { document.getElementById('b').setAttribute('style', 'width:100px;height:40px;background:rgb(0,0,255);transition:background .4s linear') })</script>
        """, scale: 1.0)
        // The view holds its instance weakly: keep it alive, or no frame is ever delivered.
        withExtendedLifetime(instance) {
            // Frames are delivered only while the widget is visible.
            instance.setVisible(true)
            self.pump(0.3)
            // Under Bazel's test runner there is no display link: deliver each requested frame as it would.
            self.deliverFrame(instance)
            view.update()
            let start = self.pixel(self.render(view, scale: 1.0), 50, 20)
            XCTAssertGreaterThan(start.r, 200, "\(start)")
            XCTAssertLessThan(start.b, 50, "\(start)")
            var end = start
            let reached = self.pump(until: {
                self.deliverFrame(instance)
                view.update()
                end = self.pixel(self.render(view, scale: 1.0), 50, 20)
                return end.b > 200 && end.r < 50
            }, timeout: 5.0)
            XCTAssertTrue(reached, "\(end)")
        }
    }

    /// A press restyles `:active` in the renderer with no JS task (nothing listens): the instance must
    /// still have the view draw it.
    func testPressRestyleIsDrawnWithoutAScript() throws {
        let (instance, view) = self.booted("<!doctype html><style>body{margin:0}#b{height:40px;background:rgb(255,0,0)}#b:active{background:rgb(0,255,0)}</style><div id=b></div>")
        // The view holds its instance weakly: keep it alive, or the touches go nowhere.
        withExtendedLifetime(instance) {
            XCTAssertGreaterThan(self.pixel(self.render(view), 20, 20).r, 200)
            view.handleTouch(phase: .began, at: CGPoint(x: 20.0, y: 20.0))
            let pressed = self.pixel(self.render(view), 20, 20)
            XCTAssertGreaterThan(pressed.g, 200, "\(pressed)")
            XCTAssertLessThan(pressed.r, 50, "\(pressed)")
            view.handleTouch(phase: .ended, at: CGPoint(x: 20.0, y: 20.0))
            self.pump(0.1)
            XCTAssertGreaterThan(self.pixel(self.render(view), 20, 20).r, 200)
        }
    }

    func testDrawsTheHeroGradient() throws {
        let instance = self.make(self.fixture("01-weather-card"))
        let size = instance.layout(width: 360.0)
        let view = instance.view
        view.frame = CGRect(origin: .zero, size: size)
        view.update()
        let p = self.pixel(self.render(view), 20, 60)
        XCTAssertGreaterThan(p.b, 150, "hero gradient should be blue at (20, 60): \(p)")
        XCTAssertLessThan(p.r, 120)
    }

    func testLayerDrawingIsNotFlipped() throws {
        let instance = self.make("<!doctype html><body style='margin:0'><div style='height:40px;background:linear-gradient(#ff0000 50%, #00ff00 50%)'></div></body>")
        let size = instance.layout(width: 360.0)
        let view = instance.view
        view.frame = CGRect(origin: .zero, size: size)
        view.update()
        let image = self.render(view)
        let top = self.pixel(image, 10, 5)
        let bottom = self.pixel(image, 10, 35)
        XCTAssertGreaterThan(top.r, 200, "top half should be red: \(top)")
        XCTAssertLessThan(top.g, 60, "top half should be red: \(top)")
        XCTAssertGreaterThan(bottom.g, 200, "bottom half should be green: \(bottom)")
        XCTAssertLessThan(bottom.r, 60, "bottom half should be green: \(bottom)")
    }

    func testOutsideListMarkerIsNotClipped() throws {
        let (instance, view) = self.booted("<!doctype html><body style='margin:0'><ul><li id='i' style='color:#000'>Item</li></ul></body>")
        guard let rect = self.borderBox(instance, "#i") else {
            return XCTFail("no rect")
        }
        let image = self.render(view)
        var dark = 0
        let right = Int(rect.minX)
        let left = max(0, right - 24)
        for x in left ..< right {
            for y in Int(rect.minY) ..< Int(rect.maxY) {
                let p = self.pixel(image, x, y)
                if p.r < 100 && p.g < 100 && p.b < 100 {
                    dark += 1
                }
            }
        }
        XCTAssertGreaterThan(dark, 0, "the list marker left of the li's box should be drawn; li rect \(rect)")
    }

    func testClippedCardKeepsItsShadow() throws {
        try self.checkClippedCardKeepsItsShadow(scale: 1.0)
    }

    /// Every iPhone draws at 2x or 3x.
    func testClippedCardKeepsItsShadowAt3x() throws {
        try self.checkClippedCardKeepsItsShadow(scale: 3.0)
    }

    private func checkClippedCardKeepsItsShadow(scale: CGFloat) throws {
        let (_, view) = self.booted("<!doctype html><body style='margin:0;padding:1px 0 40px'><div style='margin:19px 20px 20px;width:100px;height:40px;background:#fff;border-radius:999px;overflow:hidden;box-shadow:0 8px 0 0 #000'></div></body>", scale: scale)
        let image = self.render(view, scale: scale)
        // The card spans y 20...60; the shadow is the same pill moved down by 8.
        let below = self.pixel(image, 70, 64)
        XCTAssertLessThan(below.r, 60, "shadow expected below the card at \(scale)x: \(below)")
        XCTAssertLessThan(below.g, 60, "at \(scale)x")
        // Radii are clamped to the box: nothing is painted far outside it.
        let outside = self.pixel(image, 5, 5)
        XCTAssertGreaterThan(outside.r, 240, "nothing expected at (5, 5) at \(scale)x: \(outside)")
        XCTAssertGreaterThan(outside.g, 240, "at \(scale)x")
        XCTAssertGreaterThan(outside.b, 240, "at \(scale)x")
        let above = self.pixel(image, 70, 15)
        XCTAssertGreaterThan(above.r, 240, "nothing above the card at \(scale)x: \(above)")
        let farBelow = self.pixel(image, 70, 75)
        XCTAssertGreaterThan(farBelow.r, 240, "no shadow beyond the offset at \(scale)x: \(farBelow)")
    }

    func testShadowIsNotDrawnUnderATranslucentBox() throws {
        try self.checkShadowIsNotDrawnUnderATranslucentBox(scale: 1.0)
    }

    func testShadowIsNotDrawnUnderATranslucentBoxAt3x() throws {
        try self.checkShadowIsNotDrawnUnderATranslucentBox(scale: 3.0)
    }

    private func checkShadowIsNotDrawnUnderATranslucentBox(scale: CGFloat) throws {
        let (_, view) = self.booted("<!doctype html><body style='margin:0;padding:1px 0 40px'><div style='margin:19px 20px 20px;width:100px;height:40px;background:rgba(255,0,0,.5);box-shadow:0 0 0 10px #000'></div></body>", scale: scale)
        let image = self.render(view, scale: scale)
        // The box spans x 20...120, y 20...60. Its middle is 50% red over the white backdrop.
        let middle = self.pixel(image, 70, 40)
        XCTAssertGreaterThan(middle.r, 240, "middle at \(scale)x: \(middle)")
        XCTAssertGreaterThan(middle.g, 100, "middle at \(scale)x: \(middle)")
        XCTAssertLessThan(middle.g, 160, "middle at \(scale)x: \(middle)")
        XCTAssertGreaterThan(middle.b, 100, "middle at \(scale)x: \(middle)")
        XCTAssertLessThan(middle.b, 160, "middle at \(scale)x: \(middle)")
        // The spread ring around it is the shadow.
        let ring = self.pixel(image, 15, 40)
        XCTAssertLessThan(ring.r, 60, "5 px left of the box at \(scale)x: \(ring)")
        XCTAssertLessThan(ring.g, 60, "5 px left of the box at \(scale)x: \(ring)")
    }

    func testOpacityFadesTheElementAsAGroup() throws {
        let (_, view) = self.booted("<!doctype html><body style='margin:0'><div style='opacity:.5;background:#f00;height:40px'><div style='background:#00f;height:20px'></div></div></body>")
        let image = self.render(view)
        let top = self.pixel(image, 10, 10)
        // 50% blue over white, not blue faded over the red parent.
        XCTAssertGreaterThan(top.r, 100, "top half: \(top)")
        XCTAssertLessThan(top.r, 160, "top half: \(top)")
        XCTAssertGreaterThan(top.g, 100, "top half: \(top)")
        XCTAssertGreaterThan(top.b, 240, "top half: \(top)")
        let bottom = self.pixel(image, 10, 30)
        XCTAssertGreaterThan(bottom.r, 240, "bottom half: \(bottom)")
        XCTAssertGreaterThan(bottom.g, 100, "bottom half: \(bottom)")
        XCTAssertLessThan(bottom.g, 160, "bottom half: \(bottom)")
    }

    func testDestroyedInstanceViewStillDraws() throws {
        let instance = self.make(self.fixture("01-weather-card"))
        let size = instance.layout(width: 360.0)
        let view = instance.view
        view.frame = CGRect(origin: .zero, size: size)
        view.update()
        instance.destroy()
        view.update()
        let p = self.pixel(self.render(view), 20, 60)
        XCTAssertGreaterThan(p.b, 150, "the last frame must stay visible after destroy: \(p)")
    }

    func testTouchesReachTheWidget() throws {
        let instance = self.make(self.fixture("02-split-bill"))
        let size = instance.layout(width: 360.0)
        let view = instance.view
        view.frame = CGRect(origin: .zero, size: size)
        guard let rect = self.borderBox(instance, "#plus") else {
            return XCTFail("no rect")
        }
        let point = CGPoint(x: rect.midX, y: rect.midY)
        view.handleTouch(phase: .began, at: point)
        view.handleTouch(phase: .ended, at: point)
        XCTAssertEqual(instance.evaluateForTesting("document.getElementById('n').textContent"), "5")
    }

    func testDeadWidgetStopsTakingTouches() throws {
        let instance = self.make("<!doctype html><button id=b onclick='for(;;){}' style='width:100px;height:40px'>x</button>")
        let size = instance.layout(width: 360.0)
        let view = instance.view
        view.frame = CGRect(origin: .zero, size: size)
        view.handleTouch(phase: .began, at: CGPoint(x: 20, y: 20))
        view.handleTouch(phase: .ended, at: CGPoint(x: 20, y: 20))
        self.pump(0.1)
        XCTAssertNotNil(instance.deadReason)
        XCTAssertFalse(view.isUserInteractionEnabled)
    }

    // MARK: helpers

    private struct TileKey: Hashable {
        let row: Int
        let column: Int
    }

    /// Each tile's image, held strongly: a released image's address could be reused by a new one, so
    /// identities are compared on objects kept alive.
    private func tileContents(_ view: MessageWidgetView) -> [TileKey: AnyObject] {
        if let instance = view.instance {
            self.settle(instance)
        }
        var result: [TileKey: AnyObject] = [:]
        for layer in view.contentLayerForTesting.sublayers ?? [] {
            if let contents = layer.contents {
                result[TileKey(row: Int(layer.frame.minY / WidgetFrame.tileSize), column: Int(layer.frame.minX / WidgetFrame.tileSize))] = contents as AnyObject
            }
        }
        return result
    }

    func testTheViewTakesItsTouchesThroughItsRecognizer() throws {
        let (_, view) = self.booted(self.fixture("01-weather-card"), scale: 3.0)
        XCTAssertEqual(view.gestureRecognizers?.filter({ $0 is MessageWidgetTouchRecognizer }).count, 1)
    }
}
