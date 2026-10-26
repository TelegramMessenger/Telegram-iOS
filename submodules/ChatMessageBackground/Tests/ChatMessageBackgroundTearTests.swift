import XCTest
import UIKit
import Display
@testable import ChatMessageBackground

private let bubble = CGSize(width: 200.0, height: 100.0)

final class ChatMessageBackgroundTearBandTests: XCTestCase {
    /// A band is always full width and overhangs both sides, so no sliver of the bubble's edge or
    /// its outline survives beside it. The input's horizontal extent is ignored entirely.
    func testBandsAreFullWidthAndOverhangBothSides() {
        let bands = resolveBubbleTearBands([CGRect(x: 50.0, y: 30.0, width: 10.0, height: 10.0)], backgroundSize: bubble)

        XCTAssertEqual(bands.count, 1)
        XCTAssertEqual(bands[0].frame.minX, -bubbleTearHorizontalOverhang)
        XCTAssertEqual(bands[0].frame.width, bubble.width + bubbleTearHorizontalOverhang * 2.0)
    }

    /// The torn edge is carved out of the BUBBLE, not out of the gap: the band grows by the
    /// graphic's height at each torn edge, so the caller's zone survives intact as the clean gap
    /// between the two graphics.
    func testBandGrowsIntoTheBubbleToMakeRoomForTheEdges() {
        let bands = resolveBubbleTearBands([CGRect(x: 0.0, y: 30.0, width: 10.0, height: 20.0)], backgroundSize: bubble)

        XCTAssertEqual(bands.count, 1)
        XCTAssertEqual(bands[0].frame.minY, 30.0 - bubbleTearEdgeHeight - bubbleTearTopEdgeLift)
        XCTAssertEqual(bands[0].frame.maxY, 50.0 + bubbleTearEdgeHeight)
        XCTAssertTrue(bands[0].hasTopEdge)
        XCTAssertTrue(bands[0].hasBottomEdge)
    }

    /// Two pills close enough to overlap once padded must not produce two masks over the same
    /// pixels — the bands are merged instead.
    func testOverlappingBandsMerge() {
        let bands = resolveBubbleTearBands([
            CGRect(x: 0.0, y: 25.0, width: 10.0, height: 20.0),
            CGRect(x: 0.0, y: 35.0, width: 10.0, height: 30.0)
        ], backgroundSize: bubble)

        XCTAssertEqual(bands.count, 1)
        XCTAssertEqual(bands[0].frame.minY, 25.0 - bubbleTearEdgeHeight - bubbleTearTopEdgeLift)
        XCTAssertEqual(bands[0].frame.maxY, 65.0 + bubbleTearEdgeHeight)
    }

    /// Separated runs stay separated: the pill marks a position in the document, so two holes in
    /// different places must stay two holes.
    func testSeparatedBandsAreKept() {
        let bands = resolveBubbleTearBands([
            CGRect(x: 0.0, y: 25.0, width: 10.0, height: 10.0),
            CGRect(x: 0.0, y: 62.0, width: 10.0, height: 10.0)
        ], backgroundSize: bubble)

        XCTAssertEqual(bands.count, 2)
        XCTAssertEqual(bands[0].frame.minY, 25.0 - bubbleTearEdgeHeight - bubbleTearTopEdgeLift)
        XCTAssertEqual(bands[1].frame.minY, 62.0 - bubbleTearEdgeHeight - bubbleTearTopEdgeLift)
    }

    /// The growth can bring two bands together that the caller's own zones did not overlap — 18pt
    /// apart before, touching after — so the merge has to run again after it.
    func testGrowthRemerges() {
        let tall = CGSize(width: 200.0, height: 300.0)
        let bands = resolveBubbleTearBands([
            CGRect(x: 0.0, y: 40.0, width: 10.0, height: 20.0),
            CGRect(x: 0.0, y: 78.0, width: 10.0, height: 20.0)
        ], backgroundSize: tall)

        XCTAssertEqual(bands.count, 1)
        XCTAssertEqual(bands[0].frame.minY, 40.0 - bubbleTearEdgeHeight - bubbleTearTopEdgeLift)
        XCTAssertEqual(bands[0].frame.maxY, 98.0 + bubbleTearEdgeHeight)
    }

    /// A run of bubble above the band that is too short to draw once the growth is applied gets
    /// swallowed, and the band overhangs the top edge instead.
    func testSliverAtTheTopIsAbsorbed() {
        let bands = resolveBubbleTearBands([CGRect(x: 0.0, y: 15.0, width: 10.0, height: 15.0)], backgroundSize: bubble)

        XCTAssertEqual(bands.count, 1)
        XCTAssertEqual(bands[0].frame.minY, -bubbleTearVerticalOverhang)
        XCTAssertEqual(bands[0].frame.maxY, 30.0 + bubbleTearEdgeHeight)
    }

    /// Same at the bottom.
    func testSliverAtTheBottomIsAbsorbed() {
        let bands = resolveBubbleTearBands([CGRect(x: 0.0, y: 70.0, width: 10.0, height: 15.0)], backgroundSize: bubble)

        XCTAssertEqual(bands.count, 1)
        XCTAssertEqual(bands[0].frame.minY, 70.0 - bubbleTearEdgeHeight - bubbleTearTopEdgeLift)
        XCTAssertEqual(bands[0].frame.maxY, bubble.height + bubbleTearVerticalOverhang)
    }

    /// The sliver check runs against the GROWN band. 12pt of bubble above the caller's zone clears
    /// the 8pt threshold on its own, but only 2pt of it survives the growth, so it goes.
    func testSliverIsMeasuredAfterGrowth() {
        let bands = resolveBubbleTearBands([CGRect(x: 0.0, y: 12.0, width: 10.0, height: 20.0)], backgroundSize: bubble)

        XCTAssertEqual(bands[0].frame.minY, -bubbleTearVerticalOverhang)
        XCTAssertFalse(bands[0].hasTopEdge)
    }

    /// A message whose only content is an unsupported block loses its bubble entirely — the pill
    /// floats over the wallpaper. That is the intended outcome, not an edge case to guard against.
    func testABandCoveringTheWholeBubbleIsOneBand() {
        let bands = resolveBubbleTearBands([CGRect(x: 0.0, y: 0.0, width: 10.0, height: 100.0)], backgroundSize: bubble)

        XCTAssertEqual(bands.count, 1)
        XCTAssertEqual(bands[0].frame.minY, -bubbleTearVerticalOverhang)
        XCTAssertEqual(bands[0].frame.maxY, bubble.height + bubbleTearVerticalOverhang)
    }

    /// Stale geometry (a zone from a previous layout, entirely past the bubble) must not produce a
    /// band, or a resized bubble would carry a phantom hole.
    func testZonesOutsideTheBubbleAreDropped() {
        XCTAssertTrue(resolveBubbleTearBands([CGRect(x: 0.0, y: 150.0, width: 10.0, height: 20.0)], backgroundSize: bubble).isEmpty)
        XCTAssertTrue(resolveBubbleTearBands([CGRect(x: 0.0, y: -50.0, width: 10.0, height: 20.0)], backgroundSize: bubble).isEmpty)
    }

    /// The common path: no unsupported content, no work.
    func testNoZonesResolveToNoBands() {
        XCTAssertTrue(resolveBubbleTearBands([], backgroundSize: bubble).isEmpty)
    }

    /// A zero-height bubble happens transiently during insertion animations.
    func testZeroHeightBubbleProducesNoBands() {
        XCTAssertTrue(resolveBubbleTearBands([CGRect(x: 0.0, y: 0.0, width: 10.0, height: 10.0)], backgroundSize: CGSize(width: 200.0, height: 0.0)).isEmpty)
    }

    /// An absorbed edge is NOT a tear — there is no bubble beyond it. Drawing the graphic there
    /// would paint a ragged strip of bubble back outside the bubble's own silhouette.
    func testAbsorbedEdgesAreNotTears() {
        let top = resolveBubbleTearBands([CGRect(x: 0.0, y: 5.0, width: 10.0, height: 25.0)], backgroundSize: bubble)
        XCTAssertFalse(top[0].hasTopEdge)
        XCTAssertTrue(top[0].hasBottomEdge)

        let bottom = resolveBubbleTearBands([CGRect(x: 0.0, y: 70.0, width: 10.0, height: 25.0)], backgroundSize: bubble)
        XCTAssertTrue(bottom[0].hasTopEdge)
        XCTAssertFalse(bottom[0].hasBottomEdge)

        let whole = resolveBubbleTearBands([CGRect(x: 0.0, y: 0.0, width: 10.0, height: 100.0)], backgroundSize: bubble)
        XCTAssertFalse(whole[0].hasTopEdge)
        XCTAssertFalse(whole[0].hasBottomEdge)
    }

    /// A merged band's edges are whichever of its own ends still face bubble — read off the final
    /// geometry rather than tracked through the merges. Here the merged band reaches the bottom.
    func testMergedBandTakesTheOuterEdges() {
        let bands = resolveBubbleTearBands([
            CGRect(x: 0.0, y: 30.0, width: 10.0, height: 20.0),
            CGRect(x: 0.0, y: 45.0, width: 10.0, height: 40.0)
        ], backgroundSize: bubble)

        XCTAssertEqual(bands.count, 1)
        XCTAssertEqual(bands[0].frame.minY, 30.0 - bubbleTearEdgeHeight - bubbleTearTopEdgeLift)
        XCTAssertEqual(bands[0].frame.maxY, bubble.height + bubbleTearVerticalOverhang)
        XCTAssertTrue(bands[0].hasTopEdge)
        XCTAssertFalse(bands[0].hasBottomEdge)
    }

    /// A band fully contained in another must not shrink the merged result to its own extent.
    func testContainedBandDoesNotShrinkTheMergedBand() {
        let bands = resolveBubbleTearBands([
            CGRect(x: 0.0, y: 25.0, width: 10.0, height: 45.0),
            CGRect(x: 0.0, y: 30.0, width: 10.0, height: 10.0)
        ], backgroundSize: bubble)

        XCTAssertEqual(bands.count, 1)
        XCTAssertEqual(bands[0].frame.minY, 25.0 - bubbleTearEdgeHeight - bubbleTearTopEdgeLift)
        XCTAssertEqual(bands[0].frame.maxY, 70.0 + bubbleTearEdgeHeight)
        XCTAssertTrue(bands[0].hasTopEdge)
        XCTAssertTrue(bands[0].hasBottomEdge)
    }
}

final class ChatMessageBackgroundTearMaskTests: XCTestCase {
    private func makeShapeImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 4.0, height: 4.0))
        return renderer.image { context in
            UIColor.black.setFill()
            context.fill(CGRect(x: 0.0, y: 0.0, width: 4.0, height: 4.0))
        }
    }

    private func makeBand(y: CGFloat, height: CGFloat, hasTopEdge: Bool = true, hasBottomEdge: Bool = true) -> BubbleTearBand {
        return BubbleTearBand(
            frame: CGRect(x: -4.0, y: y, width: 208.0, height: height),
            hasTopEdge: hasTopEdge,
            hasBottomEdge: hasBottomEdge
        )
    }

    /// The whole mechanism: a white surface under `luminanceToAlpha` is alpha 1, and the black
    /// bands inside it are alpha 0, so the bands punch holes in whatever the view masks.
    func testTearMaskIsWhiteAndFiltered() {
        guard let view = BubbleTearMaskView.make() else {
            return XCTFail("luminanceToAlpha unavailable on this runner")
        }

        XCTAssertEqual(view.backgroundColor, .white)
        XCTAssertEqual(view.layer.filters?.count, 1)
    }

    /// One black band per zone, at the band's frame.
    func testTearMaskPlacesOneBandPerZone() {
        guard let view = BubbleTearMaskView.make() else {
            return XCTFail("luminanceToAlpha unavailable on this runner")
        }
        let bands = [self.makeBand(y: 10.0, height: 20.0), self.makeBand(y: 60.0, height: 12.0)]

        view.update(bands: bands, tailInsets: .none, animation: .None)

        XCTAssertEqual(view.bandPool.views.count, 2)
        XCTAssertEqual(view.bandPool.views[0].frame, bands[0].frame)
        XCTAssertEqual(view.bandPool.views[1].frame, bands[1].frame)
        XCTAssertEqual(view.bandPool.views[0].backgroundColor, .black)
    }

    /// The pool shrinks as well as grows — the bubble is re-laid-out constantly, and leftover
    /// bands would keep punching holes where the content no longer is.
    func testTearMaskPoolShrinks() {
        guard let view = BubbleTearMaskView.make() else {
            return XCTFail("luminanceToAlpha unavailable on this runner")
        }

        view.update(bands: [self.makeBand(y: 0.0, height: 10.0), self.makeBand(y: 20.0, height: 10.0)], tailInsets: .none, animation: .None)
        view.update(bands: [self.makeBand(y: 0.0, height: 10.0)], tailInsets: .none, animation: .None)
        XCTAssertEqual(view.bandPool.views.count, 1)

        view.update(bands: [], tailInsets: .none, animation: .None)
        XCTAssertEqual(view.bandPool.views.count, 0)
    }

    /// Untorn, the backdrop's mask must behave exactly as it did before tearing existed: the
    /// black-filled shape image, unfiltered, masking by its own alpha.
    func testBackdropMaskIsUnfilteredWhenUntorn() {
        let view = BubbleBackdropMaskView()
        let image = self.makeShapeImage()
        view.image = image

        view.update(bands: [], tailInsets: .none, animation: .None)

        XCTAssertNil(view.layer.filters)
        XCTAssertEqual(view.shapeView.image?.renderingMode, image.renderingMode)
        XCTAssertEqual(view.bandPool.views.count, 0)
    }

    /// Torn, the shape must be re-rendered as a WHITE template. This is the load-bearing part:
    /// `luminanceToAlpha` maps the image's own black fill to alpha 0, so filtering it as-is would
    /// erase the entire bubble backdrop instead of punching bands out of it.
    func testBackdropMaskGoesWhiteTemplateWhenTorn() {
        let view = BubbleBackdropMaskView()
        view.image = self.makeShapeImage()

        view.update(bands: [self.makeBand(y: 10.0, height: 20.0)], tailInsets: .none, animation: .None)

        XCTAssertNotNil(view.layer.filters)
        XCTAssertEqual(view.shapeView.image?.renderingMode, .alwaysTemplate)
        XCTAssertEqual(view.shapeView.tintColor, .white)
        XCTAssertEqual(view.bandPool.views.count, 1)
    }

    /// And back again, so a bubble that stops being torn does not keep paying for the filter.
    func testBackdropMaskRevertsWhenTearsGoAway() {
        let view = BubbleBackdropMaskView()
        let image = self.makeShapeImage()
        view.image = image

        view.update(bands: [self.makeBand(y: 10.0, height: 20.0)], tailInsets: .none, animation: .None)
        view.update(bands: [], tailInsets: .none, animation: .None)

        XCTAssertNil(view.layer.filters)
        XCTAssertEqual(view.shapeView.image?.renderingMode, image.renderingMode)
        XCTAssertEqual(view.bandPool.views.count, 0)
    }

    /// The image can be assigned while torn (the theme changes, or the bubble's merge type does),
    /// and must land in the right rendering mode without a second `update`.
    func testBackdropMaskAppliesTemplateToALaterImage() {
        let view = BubbleBackdropMaskView()

        view.update(bands: [self.makeBand(y: 10.0, height: 20.0)], tailInsets: .none, animation: .None)
        view.image = self.makeShapeImage()

        XCTAssertEqual(view.shapeView.image?.renderingMode, .alwaysTemplate)
    }

    /// The shape fills the view, because the node frames the mask and the stretchable shape image
    /// must stretch to exactly that.
    func testBackdropMaskShapeFillsTheView() {
        let view = BubbleBackdropMaskView()
        view.frame = CGRect(x: 0.0, y: 0.0, width: 100.0, height: 50.0)
        view.layoutIfNeeded()

        XCTAssertEqual(view.shapeView.frame, view.bounds)
    }
}

/// The real `Chat/Message/BubbleTear{Up,Down}` assets live in the app bundle, which a unit-test
/// host cannot reach, so these substitute stubs of the same 400x10 shape. That the asset NAMES
/// resolve is covered by the app build and the manual pass, not here.
final class ChatMessageBackgroundTearEdgeTests: XCTestCase {
    override func setUp() {
        super.setUp()

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 400.0, height: 10.0))
        let stub = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0.0, y: 0.0, width: 400.0, height: 10.0))
        }
        BubbleTearEdgeImages.shared = BubbleTearEdgeImages(up: stub, down: stub)
    }

    /// Deliberately NO `layoutIfNeeded()`: in the app these views live inside a `mask`, which is not
    /// in the view hierarchy, so `update` has to position the graphics on its own.
    private func makeBandView(hasTopEdge: Bool, hasBottomEdge: Bool, tailInsets: BubbleTearTailInsets = .none) -> BubbleTearBandView {
        let size = CGSize(width: 300.0, height: 60.0)
        let view = BubbleTearBandView()
        view.frame = CGRect(origin: CGPoint(), size: size)
        view.update(size: size, hasTopEdge: hasTopEdge, hasBottomEdge: hasBottomEdge, tailInsets: tailInsets)
        return view
    }

    /// The graphics hand a ragged strip of the hole back to the bubble, so each sits flush against
    /// the band edge it belongs to: solid side abutting the cut, fringe pointing into the hole.
    func testEdgeGraphicsSitAtTheBandEdges() {
        let view = self.makeBandView(hasTopEdge: true, hasBottomEdge: true)
        guard view.subviews.count == 2 else {
            return XCTFail("edge graphics did not load")
        }

        let top = view.subviews[0]
        let bottom = view.subviews[1]
        // Pulled `bubbleTearEdgeInset` toward the centre, so the graphic's edge and the band's own
        // edge do not land on the same row and composite into a seam.
        XCTAssertEqual(top.frame.minY, bubbleTearEdgeInset)
        XCTAssertEqual(bottom.frame.maxY, view.bounds.height - bubbleTearEdgeInset)
        // 400x10 assets, tiled horizontally rather than stretched. The top one is a pixel short so
        // the vertical tile cannot wrap and put its solid row back at its fringe end.
        XCTAssertEqual(bottom.frame.height, bubbleTearEdgeHeight)
        XCTAssertEqual(top.frame.height, bubbleTearEdgeHeight - UIScreenPixel)
    }

    /// The band overhangs the bubble horizontally, but the graphics must NOT: they are white, and
    /// in the backdrop's mask white adds, so an overhanging graphic paints wallpaper back outside
    /// the bubble as a stripe poking out of its side.
    ///
    /// They stop one pixel PAST the silhouette rather than exactly on it — landing exactly on it
    /// leaves both edges antialiased against each other, which reads as a nick out of the bubble's
    /// side at the tear line.
    func testEdgeGraphicsStopAtTheBubbleEdges() {
        let view = self.makeBandView(hasTopEdge: true, hasBottomEdge: true)
        guard view.subviews.count == 2 else {
            return XCTFail("edge graphics did not load")
        }

        let silhouetteMinX = bubbleTearHorizontalOverhang
        let silhouetteMaxX = view.bounds.width - bubbleTearHorizontalOverhang
        for graphic in view.subviews {
            XCTAssertEqual(graphic.frame.minX, silhouetteMinX + bubbleTearGraphicsHorizontalInset)
            XCTAssertEqual(graphic.frame.maxX, silhouetteMaxX - bubbleTearGraphicsHorizontalInset)
        }
        // The band itself still overhangs by a good deal more — that is what keeps a hairline of
        // bubble edge from surviving beside it.
        XCTAssertLessThan(view.subviews[0].frame.width, view.bounds.width)
    }

    /// An absorbed edge gets no graphic at all.
    func testAbsorbedEdgesGetNoGraphic() {
        XCTAssertEqual(self.makeBandView(hasTopEdge: false, hasBottomEdge: true).subviews.count, 1)
        XCTAssertEqual(self.makeBandView(hasTopEdge: true, hasBottomEdge: false).subviews.count, 1)
        XCTAssertEqual(self.makeBandView(hasTopEdge: false, hasBottomEdge: false).subviews.count, 0)
    }

    /// A band view is reused across layouts, so it must be able to gain and lose an edge — a pill
    /// that was mid-message and becomes last goes from two tears to one.
    func testEdgeGraphicsAreAddedAndRemovedOnReuse() {
        let view = self.makeBandView(hasTopEdge: true, hasBottomEdge: true)

        view.update(size: view.bounds.size, hasTopEdge: true, hasBottomEdge: false, tailInsets: .none)
        XCTAssertEqual(view.subviews.count, 1)

        view.update(size: view.bounds.size, hasTopEdge: true, hasBottomEdge: true, tailInsets: .none)
        XCTAssertEqual(view.subviews.count, 2)
    }

    /// The band's frame is the bubble's FRAME, which is 6pt wider than its body on the tail side —
    /// that column is reserved for every merge type, and above and below the tail itself it is
    /// empty. A graphic that ran across it painted bubble outside the body: a 6pt tongue sticking
    /// out of the left of every incoming bubble at each tear line.
    func testEdgeGraphicsStopAtTheBodyNotTheTail() {
        let view = self.makeBandView(hasTopEdge: true, hasBottomEdge: true, tailInsets: BubbleTearTailInsets(type: .incoming(.None)))
        guard view.subviews.count == 2 else {
            return XCTFail("edge graphics did not load")
        }

        for graphic in view.subviews {
            XCTAssertEqual(graphic.frame.minX, bubbleTearHorizontalOverhang + bubbleTearTailInset + bubbleTearGraphicsHorizontalInset)
            XCTAssertEqual(graphic.frame.maxX, view.bounds.width - bubbleTearHorizontalOverhang - bubbleTearGraphicsHorizontalInset)
        }
    }

    /// Outgoing bubbles carry the tail on the other side.
    func testTheTailInsetFollowsTheBubbleDirection() {
        XCTAssertEqual(BubbleTearTailInsets(type: .incoming(.None)), BubbleTearTailInsets(left: bubbleTearTailInset, right: 0.0))
        XCTAssertEqual(BubbleTearTailInsets(type: .outgoing(.None)), BubbleTearTailInsets(left: 0.0, right: bubbleTearTailInset))
        XCTAssertEqual(BubbleTearTailInsets(type: .none), .none)

        let view = self.makeBandView(hasTopEdge: true, hasBottomEdge: true, tailInsets: BubbleTearTailInsets(type: .outgoing(.None)))
        guard let graphic = view.subviews.first else {
            return XCTFail("edge graphics did not load")
        }
        XCTAssertEqual(graphic.frame.minX, bubbleTearHorizontalOverhang + bubbleTearGraphicsHorizontalInset)
        XCTAssertEqual(graphic.frame.maxX, view.bounds.width - bubbleTearHorizontalOverhang - bubbleTearTailInset - bubbleTearGraphicsHorizontalInset)
    }

    /// A graphic added on a LATER update — the band already existed, so nothing re-runs its layout —
    /// must still be positioned. Left to `layoutSubviews` it keeps the frame `UIImageView(image:)`
    /// gave it, which is the asset's own 400x10 and overhangs the bubble by hundreds of points.
    func testAGraphicAddedOnReuseIsStillPositioned() {
        let view = self.makeBandView(hasTopEdge: false, hasBottomEdge: false)

        view.update(size: view.bounds.size, hasTopEdge: true, hasBottomEdge: true, tailInsets: .none)

        for graphic in view.subviews {
            XCTAssertEqual(graphic.frame.minX, bubbleTearHorizontalOverhang + bubbleTearGraphicsHorizontalInset)
            XCTAssertEqual(graphic.frame.maxX, view.bounds.width - bubbleTearHorizontalOverhang - bubbleTearGraphicsHorizontalInset)
        }
    }

    /// White, because the mask reads luminance: the graphic must hand bubble back, not punch more
    /// hole. Template rendering makes that independent of the asset's own colour.
    func testEdgeGraphicsAreWhiteTemplates() {
        let view = self.makeBandView(hasTopEdge: true, hasBottomEdge: true)
        guard let top = view.subviews.first as? UIImageView else {
            return XCTFail("edge graphic did not load")
        }

        XCTAssertEqual(top.tintColor, .white)
        XCTAssertEqual(top.image?.renderingMode, .alwaysTemplate)
        XCTAssertEqual(top.image?.resizingMode, .tile)
    }
}

