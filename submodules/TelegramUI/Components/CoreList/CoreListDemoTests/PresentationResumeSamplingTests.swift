import XCTest
import UIKit
@testable import CoreListDemo

/// A new animation's `from` must be the value the layer is CURRENTLY RENDERING, not the model's
/// analytic value at the pass clock. The two differ by the producing pass's commit delay, which is
/// invisible while one authority owns a layer and becomes a visible drift the moment two do — the
/// chat's hosted item node reads `presentation()` for its own box while the row read the model.
///
/// Measured on device before this change: one-signed, compounding, up to 3.2pt.
final class PresentationResumeSamplingTests: XCTestCase {
    private let viewport = CGSize(width: 390, height: 400)

    // MARK: - The assumption everything else rests on

    /// The existing 819 tests keep their exact model-vs-CA assertions only because they never resolve
    /// a presentation layer, so `presentedValueProvider` returns nil and they stay on the analytic
    /// path. `ListAnimationController.swift:578` records that as measured; this pins it, so a future
    /// harness change that starts committing cannot silently move the whole suite onto the presented
    /// path and quietly weaken every one of those assertions.
    func testFixtureLayersHaveNoPresentationLayer() throws {
        let fixture = VirtualListFixture(itemCount: 22, itemHeight: 50, viewport: viewport)
        var items = fixture.listView.items
        items.removeFirst()
        fixture.listView.applyChanges(items: items, transition: .linear(duration: 0.3))

        XCTAssertTrue(fixture.hasActiveAnimations,
                      "precondition: an animation is in flight, so a presentation layer would exist")
        // Every layer the provider could be asked about: the rows, and the scroll view that carries
        // the viewport track.
        var layers = fixture.activeWindow.items.map(\.view.layer)
        layers.append(fixture.scrollView.layer)
        for layer in layers {
            XCTAssertNil(layer.presentation(), "\(layer) resolved a presentation layer")
        }
    }

    // MARK: - The seam

    /// A model with one live owner carrying an in-flight height track, so `resumeValue` has both an
    /// analytic answer to fall back to and a track to be asked about.
    private func modelWithLiveOwner() -> (ListAnimationModel, ListAnimationOwner) {
        let model = ListAnimationModel()
        let owner = ListAnimationOwner.live(AnyHashable(UUID()))
        _ = model.transitionHeight(owner: owner,
                                   oldSettledHeight: 40,
                                   newSettledHeight: 140,
                                   at: 0,
                                   transition: .linear(duration: 1.0))
        return (model, owner)
    }

    /// The provider's value is used verbatim — it is already in the track's space, and the model does
    /// not convert. An earlier version subtracted a `settled` reference for additive properties; see
    /// `resumeValue` for why that was wrong.
    func testResumeValueReturnsTheProvidedValueVerbatim() throws {
        let (model, owner) = modelWithLiveOwner()
        model.presentedValueProvider = { _, property in property == .height ? 63.5 : nil }

        XCTAssertEqual(try XCTUnwrap(model.resumeValue(for: owner, property: .height, at: 0.5)),
                       63.5, accuracy: 1e-9)
    }

    /// **No additive property is sampled** — the provider answers for absolute properties only.
    /// An additive contribution is `presented - the base the render tree was committed against`, and a
    /// pass overwrites that base (`render()` writes the new settled frame) long before any transition
    /// installs, so the only available handle on it is already the wrong number. `.positionY` was
    /// sampled for one build and double-counted every pass's displacement; see
    /// `PresentedPositionResumeBaseTests`.
    ///
    /// **This test has to reach the switch, and two things stop it by default** — both of which the
    /// version this replaced tripped over, leaving it vacuously green against the real defect. The
    /// provider guards on a bound owner AND on a resolved presentation layer, so a query about an
    /// unrelated owner, or a bare `CALayer()`, returns nil before the switch is ever consulted. Hence
    /// the scene-attached window, the bound owner, and the absolute-property assertions below: those
    /// are the non-vacuity witness, and without them this asserts nothing at all.
    func testAdditivePropertiesAreDeclinedByTheInstalledProvider() throws {
        let scene = try XCTUnwrap(
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first,
            "no UIWindowScene in the test host; this test needs a rendering window")
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 390, height: 400)
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 40))
        window.addSubview(host)
        window.layoutIfNeeded()
        CATransaction.flush()

        let controller = ListAnimationController()
        let identity = AnyHashable(UUID())
        controller.transitionHeight(identity: identity, layer: host.layer,
                                    oldSettledHeight: 40, newSettledHeight: 140,
                                    transition: .linear(duration: 1.0))
        let provider = try XCTUnwrap(controller.model.presentedValueProvider)
        let owner = ListAnimationOwner.live(identity)
        XCTAssertNotNil(host.layer.presentation(),
                        "precondition: the layer resolves a presentation layer, so the provider "
                        + "reaches its switch instead of returning nil at the guard")

        let compiler = CoreAnimationCompiler(emitsAnimations: false)
        for property in [ListAnimatedProperty.viewportOffset, .positionX, .positionY] {
            XCTAssertTrue(compiler.isAdditive(property), "precondition: \(property) is additive")
            XCTAssertNil(provider(owner, property), "\(property) must not be sampled")
        }
        for property in [ListAnimatedProperty.width, .height, .opacity] {
            XCTAssertFalse(compiler.isAdditive(property), "precondition: \(property) is absolute")
            XCTAssertNotNil(provider(owner, property),
                            "\(property) must be sampled — and this is what proves the nils above "
                            + "are a decision rather than a guard firing early")
        }
    }

    /// No provider is today's behaviour, exactly — this is what keeps the windowless suite unchanged.
    func testResumeValueFallsBackToTheAnalyticValueWithoutAProvider() {
        let (model, owner) = modelWithLiveOwner()

        XCTAssertEqual(model.resumeValue(for: owner, property: .height, at: 0.5),
                       model.value(for: owner, property: .height, at: 0.5))
    }

    /// A provider that declines this property is the same as no provider.
    func testResumeValueFallsBackWhenTheProviderReturnsNil() {
        let (model, owner) = modelWithLiveOwner()
        model.presentedValueProvider = { _, _ in nil }

        XCTAssertEqual(model.resumeValue(for: owner, property: .height, at: 0.5),
                       model.value(for: owner, property: .height, at: 0.5))
    }

    // MARK: - The invariant this whole change buys

    /// A re-issue mid-flight must start from what the layer is RENDERING, not from what the model
    /// computes for the pass clock.
    ///
    /// The two are separated deliberately rather than left a few milliseconds apart: the first
    /// transition is stamped at `t0`, the animation is allowed to run for real for ~0.2s, and the
    /// re-issue is stamped at `t0 + 0.8`. The model's analytic answer is therefore ~120 while the
    /// screen is at ~60. A `from` near 60 can only have come from the presentation layer, and one near
    /// 120 can only have come from the model — no tolerance juggling required.
    func testReissuedHeightResumesFromThePresentedValueNotTheModelClock() throws {
        // A window with no `UIWindowScene` never enters the render tree, so its layers never resolve a
        // presentation layer — which is the whole point of this test. Attach to the test host's scene.
        let scene = try XCTUnwrap(
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first,
            "no UIWindowScene in the test host; this test needs a rendering window")
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 390, height: 400)
        window.makeKeyAndVisible()
        let host = UIView(frame: CGRect(x: 0, y: 0, width: 390, height: 40))
        window.addSubview(host)
        window.layoutIfNeeded()

        let controller = ListAnimationController()
        let identity = AnyHashable(UUID())
        let t0 = CACurrentMediaTime()
        controller.transitionHeight(identity: identity, layer: host.layer,
                                    oldSettledHeight: 40, newSettledHeight: 140,
                                    transition: .linear(duration: 1.0),
                                    transactionTime: t0)
        CATransaction.flush()

        let deadline = Date().addingTimeInterval(0.2)
        while Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.02))
        }

        let presented = try XCTUnwrap(host.layer.presentation()?.bounds.size.height)
        XCTAssertGreaterThan(presented, 40.5, "precondition: the animation is in flight")
        XCTAssertLessThan(presented, 100.0, "precondition: well short of the model's t0+0.8 answer")

        controller.transitionHeight(identity: identity, layer: host.layer,
                                    oldSettledHeight: 140, newSettledHeight: 240,
                                    transition: .linear(duration: 1.0),
                                    transactionTime: t0 + 0.8)

        let reissued = try XCTUnwrap(
            host.layer.animation(forKey: "CoreListAnimation.height") as? CABasicAnimation)
        let from = try XCTUnwrap((reissued.fromValue as? NSNumber)?.doubleValue)
        XCTAssertEqual(from, Double(presented), accuracy: 5.0,
                       "re-issue started from the model clock (~120) instead of the screen (~\(presented))")
    }

    /// The same invariant through a real list PASS, which is the shape the test above cannot reach.
    ///
    /// It matters separately because a pass overwrites the layer before any transition installs:
    /// `render()` writes every window item's new settled frame (`CoreVirtualListView.swift:2870`) and
    /// the transitions install ~550 lines later (`:2022`). That ordering is exactly what made the
    /// ADDITIVE `.positionY` sample unusable (see `PresentedPositionResumeBaseTests`), and height's
    /// immunity to it — an absolute property's presented value does not depend on the model value the
    /// pass just changed — was an argument rather than a test until here.
    ///
    /// The two answers are separated by driving two clocks apart, which is what the fixture's synthetic
    /// clock is for: Core Animation runs on the real clock for ~0.2s (screen ≈ 90) while the model's
    /// clock is advanced 0.8s (analytic ≈ 210). 120pt apart, so neither can be mistaken for the other.
    func testReissuedRowHeightInAPassResumesFromTheScreen() throws {
        let scene = try XCTUnwrap(
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first,
            "no UIWindowScene in the test host; this test needs a rendering window")
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 390, height: 400)
        window.makeKeyAndVisible()
        defer { window.isHidden = true }

        let ids = (0..<8).map { _ in UUID() }
        let items = ids.map { ContentResizableItem(id: $0, contentHeight: 50) }
        let fixture = VirtualListFixture(viewport: viewport, items: items, emitsCA: true)
        window.addSubview(fixture.listView)
        window.layoutIfNeeded()
        CATransaction.flush()

        func grow(_ height: CGFloat) {
            var next = items
            next[0] = ContentResizableItem(id: ids[0], contentHeight: height)
            fixture.listView.applyChanges(items: next, transition: .linear(duration: 1.0))
        }

        let grownIdentity = AnyHashable(ids[0])
        let layer = try XCTUnwrap(fixture.view(identity: grownIdentity)).layer
        grow(250)
        CATransaction.flush()

        let deadline = Date().addingTimeInterval(0.2)
        while Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.02))
        }
        let presented = try XCTUnwrap(layer.presentation()?.bounds.size.height)
        XCTAssertGreaterThan(presented, 50.5, "precondition: the height animation is in flight")
        XCTAssertLessThan(presented, 150.0,
                          "precondition: well short of the model's 0.8s answer (~210)")

        // Only the MODEL's clock moves — no real time passes, so the screen stays where it is.
        fixture.advance(by: 0.8)
        grow(450)

        let track = try XCTUnwrap(fixture.heightTrack(identity: grownIdentity))
        XCTAssertEqual(track.to, 450, accuracy: 1e-6, "precondition: this is the re-issued track")
        XCTAssertEqual(track.from, presented, accuracy: 5.0,
                       "the re-issue started from the model clock (~210) instead of the screen "
                       + "(~\(presented)) — a pass's own frame write must not disturb an absolute "
                       + "property's presented read")
    }

    /// The additive/absolute split must agree with what the compiler actually emits, or a presented
    /// value would be converted into a space the animation is not in. Two switches that must stay in
    /// sync is the shape of defect this whole change came out of, so it is asserted rather than
    /// assumed.
    func testAdditiveClassificationMatchesTheCompiler() {
        let compiler = CoreAnimationCompiler(emitsAnimations: false)
        for property in [ListAnimatedProperty.viewportOffset, .positionX, .positionY,
                         .width, .height, .opacity] {
            XCTAssertEqual(property.isAdditiveTrack, compiler.isAdditive(property),
                           "classification disagrees for \(property)")
        }
    }
}
