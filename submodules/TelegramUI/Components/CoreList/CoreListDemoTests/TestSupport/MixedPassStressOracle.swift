import XCTest
import UIKit
@testable import CoreListDemo

struct MixedPassLiveSnapshot: Equatable {
    let renderedFrame: CGRect
    let settledFrame: CGRect
    let opacity: CGFloat
    let tracks: [ListAnimatedProperty: ListAnimationTrack]
}

struct MixedPassBoundarySnapshot: Equatable {
    var live: [AnyHashable: MixedPassLiveSnapshot]
    let viewportTrack: ListAnimationTrack?
    let viewportCorrection: CGFloat

    static let empty = Self(
        live: [:],
        viewportTrack: nil,
        viewportCorrection: 0
    )
}

enum MixedPassOracleError: Error, Equatable {
    case missingAnimation(ListAnimatedProperty)
    case wrongGeneration
    case wrongClock
    case wrongOrigin
    case wrongEndpoints
    case wrongMapping
}

final class MixedPassStressOracle {
    static let properties: [ListAnimatedProperty] = [
        .positionX, .positionY, .width, .height, .opacity,
    ]

    func capture(fixture: VirtualListFixture) -> MixedPassBoundarySnapshot {
        let now = fixture.animationController.now()
        var live: [AnyHashable: MixedPassLiveSnapshot] = [:]

        for item in fixture.activeWindow.items {
            let identity = fixture.listView.items[item.index].identity
            let renderedX = item.frame.minX
                + (fixture.animationController.positionOffsetX(
                    identity: identity,
                    at: now
                ) ?? 0)
            let renderedY = fixture.screenY(identity: identity) ?? 0
            let renderedWidth = fixture.animationController.width(
                identity: identity,
                at: now
            ) ?? item.frame.width
            let renderedHeight = fixture.animationController.height(
                identity: identity,
                at: now
            ) ?? item.frame.height
            let opacity = fixture.animationController.opacity(
                owner: .live(identity),
                at: now
            ) ?? 1
            let tracks = Dictionary(
                uniqueKeysWithValues: Self.properties.compactMap { property in
                    fixture.animationController.model.track(
                        for: .live(identity),
                        property: property
                    ).map { (property, $0) }
                }
            )
            let settledY = fixture.settledScreenY(identity: identity)
                ?? item.frame.minY

            live[identity] = MixedPassLiveSnapshot(
                renderedFrame: CGRect(
                    x: renderedX,
                    y: renderedY,
                    width: renderedWidth,
                    height: renderedHeight
                ),
                settledFrame: CGRect(
                    x: item.frame.minX,
                    y: settledY,
                    width: item.frame.width,
                    height: item.frame.height
                ),
                opacity: opacity,
                tracks: tracks
            )
        }

        return MixedPassBoundarySnapshot(
            live: live,
            viewportTrack: fixture.viewportTrack,
            viewportCorrection: fixture.viewportCorrection
        )
    }

    func assertBoundary(
        before: MixedPassBoundarySnapshot,
        after: MixedPassBoundarySnapshot,
        step: MixedPassStep,
        context: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard step.transition.duration > 0 else { return }
        let shared = Set(before.live.keys).intersection(after.live.keys)

        for identity in shared {
            guard let old = before.live[identity],
                  let new = after.live[identity] else {
                continue
            }
            assertEqual(
                old.renderedFrame,
                new.renderedFrame,
                accuracy: 1e-5,
                "\(context)\nidentity=\(identity) lost C0 frame continuity",
                file: file,
                line: line
            )
            XCTAssertEqual(
                old.opacity,
                new.opacity,
                accuracy: 1e-5,
                "\(context)\nidentity=\(identity) lost C0 opacity continuity",
                file: file,
                line: line
            )

            assertProperty(
                .positionX,
                oldTarget: old.settledFrame.minX,
                newTarget: new.settledFrame.minX,
                expectedFrom: old.renderedFrame.minX - new.settledFrame.minX,
                old: old,
                new: new,
                step: step,
                identity: identity,
                context: context,
                file: file,
                line: line
            )
            assertProperty(
                .positionY,
                oldTarget: old.settledFrame.minY,
                newTarget: new.settledFrame.minY,
                expectedFrom: old.renderedFrame.minY - new.settledFrame.minY,
                old: old,
                new: new,
                step: step,
                identity: identity,
                context: context,
                file: file,
                line: line
            )
            assertProperty(
                .width,
                oldTarget: old.settledFrame.width,
                newTarget: new.settledFrame.width,
                expectedFrom: old.renderedFrame.width,
                old: old,
                new: new,
                step: step,
                identity: identity,
                context: context,
                file: file,
                line: line
            )
            assertProperty(
                .height,
                oldTarget: old.settledFrame.height,
                newTarget: new.settledFrame.height,
                expectedFrom: old.renderedFrame.height,
                old: old,
                new: new,
                step: step,
                identity: identity,
                context: context,
                file: file,
                line: line
            )

            XCTAssertEqual(
                old.tracks[.opacity],
                new.tracks[.opacity],
                "\(context)\nidentity=\(identity) changed an unchanged opacity track",
                file: file,
                line: line
            )
        }
    }

    func assertWindow(
        fixture: VirtualListFixture,
        context: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let windowItems = fixture.activeWindow.items
        let indices = windowItems.map(\.index)

        if let first = indices.first, let last = indices.last {
            XCTAssertEqual(
                indices,
                Array(first...last),
                "\(context)\nactive window indices are not contiguous",
                file: file,
                line: line
            )
        }
        for index in indices {
            XCTAssertTrue(
                fixture.listView.items.indices.contains(index),
                "\(context)\nloaded index \(index) is out of range",
                file: file,
                line: line
            )
        }
        let identities = indices.map { fixture.listView.items[$0].identity }
        XCTAssertEqual(
            Set(identities).count,
            identities.count,
            "\(context)\nactive window contains duplicate identities",
            file: file,
            line: line
        )

        for item in windowItems {
            XCTAssertTrue(
                item.frame.isFinite,
                "\(context)\nnon-finite frame at index \(item.index): \(item.frame)",
                file: file,
                line: line
            )
            XCTAssertGreaterThanOrEqual(
                item.frame.width,
                0,
                "\(context)\nnegative width at index \(item.index)",
                file: file,
                line: line
            )
            XCTAssertGreaterThanOrEqual(
                item.frame.height,
                0,
                "\(context)\nnegative height at index \(item.index)",
                file: file,
                line: line
            )
        }
        for pair in zip(windowItems, windowItems.dropFirst()) {
            // A reserving run boundary puts a DELIBERATE gap between consecutive rows —
            // `reservedBottom` of the upper row plus `reservedTop` of the lower one. Both are 0 for a
            // collection with no space-reserving attachments, so this reduces to the original
            // touch-exactly assertion.
            let expectedGap = pair.0.reservedBottom + pair.1.reservedTop
            XCTAssertEqual(
                pair.1.frame.minY - pair.0.frame.maxY,
                expectedGap,
                accuracy: 1e-5,
                "\(context)\nsettled frames are not contiguous between "
                    + "\(pair.0.index) and \(pair.1.index) "
                    + "(expected gap \(expectedGap) for reserved attachments)",
                file: file,
                line: line
            )
        }

        assertAttachments(fixture: fixture, context: context, file: file, line: line)
    }

    /// Attachment-specific window invariants, split out to keep `assertWindow` readable.
    private func assertAttachments(
        fixture: VirtualListFixture,
        context: String,
        file: StaticString,
        line: UInt
    ) {
        let window = fixture.activeWindow
        let windowItems = window.items
        let attachments = window.attachments
        let loadedRange = windowItems.isEmpty
            ? 0..<0
            : window.startIndex..<(window.endIndex + 1)

        XCTAssertEqual(
            Set(attachments.map(\.serial)).count,
            attachments.count,
            "\(context)\nattachment serials are not unique",
            file: file,
            line: line
        )

        for attachment in attachments {
            XCTAssertFalse(
                attachment.memberRange.isEmpty,
                "\(context)\nattachment \(attachment.serial) has an empty member range",
                file: file,
                line: line
            )
            XCTAssertTrue(
                loadedRange.contains(attachment.memberRange.lowerBound)
                    && loadedRange.contains(attachment.memberRange.upperBound - 1),
                "\(context)\nattachment \(attachment.serial) member range "
                    + "\(attachment.memberRange) escapes the loaded range \(loadedRange)",
                file: file,
                line: line
            )
            XCTAssertTrue(
                attachment.measuredHeight.isFinite && attachment.measuredHeight >= 0,
                "\(context)\nattachment \(attachment.serial) has a bad measured height "
                    + "\(attachment.measuredHeight)",
                file: file,
                line: line
            )
            XCTAssertTrue(
                attachment.bandTop.isFinite && attachment.bandBottom.isFinite,
                "\(context)\nattachment \(attachment.serial) has a non-finite band",
                file: file,
                line: line
            )
        }

        // Sorted by `(memberRange.lowerBound, key description)` — the deterministic order
        // `AttachmentRuns.pendingRuns` guarantees, which the z-order of overlapping attachments and
        // the stress harness's own reproducibility both depend on.
        let order = attachments.map { ($0.memberRange.lowerBound, String(describing: $0.key)) }
        XCTAssertEqual(
            order.map(\.0),
            order.map(\.0).sorted(),
            "\(context)\nattachments are not sorted by run start index",
            file: file,
            line: line
        )
        for pair in zip(order, order.dropFirst()) where pair.0.0 == pair.1.0 {
            XCTAssertLessThanOrEqual(
                pair.0.1,
                pair.1.1,
                "\(context)\nattachments sharing a run start are not sorted by key",
                file: file,
                line: line
            )
        }

        // At most one space-reserving attachment per edge per boundary: two would need a stacking
        // order and `AnyHashable` supplies none.
        for item in windowItems {
            let reservingTop = attachments.filter {
                $0.placement == .reservesSpace && $0.edge == .top
                    && $0.startsCollectionRun && $0.memberRange.lowerBound == item.index
            }
            let reservingBottom = attachments.filter {
                $0.placement == .reservesSpace && $0.edge == .bottom
                    && $0.endsCollectionRun && $0.memberRange.upperBound - 1 == item.index
            }
            XCTAssertLessThanOrEqual(
                reservingTop.count, 1,
                "\(context)\nrow \(item.index) reserves space for more than one .top attachment",
                file: file,
                line: line
            )
            XCTAssertLessThanOrEqual(
                reservingBottom.count, 1,
                "\(context)\nrow \(item.index) reserves space for more than one .bottom attachment",
                file: file,
                line: line
            )
        }
    }

    func assertInstalledAnimations(
        fixture: VirtualListFixture,
        context: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        var observed: [ListAnimationOwner: CALayer] = [
            .viewport: fixture.listView.engine.contentHost.layer,
        ]

        for item in fixture.activeWindow.items {
            let identity = fixture.listView.items[item.index].identity
            observed[.live(identity)] = item.view.layer
        }
        for identity in fixture.crossingCarryIdentities {
            if let view = fixture.crossingCarryView(identity: identity) {
                observed[.live(identity)] = view.layer
            }
        }
        for block in fixture.ghostBlocks {
            if let render = fixture.listView.ghostRender(for: block.id) {
                observed[render.owner] = render.wrapper.layer
            }
        }
        for member in fixture.listView.ghostMemberHorizontalSnapshots {
            observed[member.owner] = member.view.layer
        }

        for (owner, layer) in observed {
            let properties = owner == .viewport
                ? [ListAnimatedProperty.viewportOffset]
                : Self.properties
            for property in properties {
                let track = fixture.animationController.model.track(
                    for: owner,
                    property: property
                )
                let key = fixture.animationController.compiler.animationKey(
                    for: property
                )
                let animation = layer.animation(forKey: key)

                if let track {
                    do {
                        try Self.validateTrack(
                            expected: track,
                            animation: animation,
                            property: property
                        )
                    } catch {
                        XCTFail(
                            "\(context)\nowner=\(owner) property=\(property) "
                                + "CA/model mismatch: \(error)",
                            file: file,
                            line: line
                        )
                    }
                } else {
                    XCTAssertNil(
                        animation,
                        "\(context)\nowner=\(owner) property=\(property) "
                            + "has stale installed animation",
                        file: file,
                        line: line
                    )
                }
            }
        }
    }

    func settle(fixture: VirtualListFixture, max: TimeInterval) {
        fixture.animationController.reapSettledTracks()
        _ = fixture.runUntilSettled(max: max)
        fixture.animationController.reapSettledTracks()
    }

    func assertSettled(
        fixture: VirtualListFixture,
        context: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        assertWindow(fixture: fixture, context: context, file: file, line: line)
        let now = fixture.animationController.now()

        XCTAssertFalse(
            fixture.hasActiveAnimations,
            "\(context)\nanalytic animations remain active",
            file: file,
            line: line
        )
        XCTAssertTrue(
            fixture.crossingCarryIdentities.isEmpty,
            "\(context)\ncrossing carries remain after settlement",
            file: file,
            line: line
        )
        XCTAssertTrue(
            fixture.viewportCarryViews.isEmpty,
            "\(context)\nviewport carries remain after settlement",
            file: file,
            line: line
        )
        XCTAssertTrue(
            fixture.ghostBlocks.isEmpty,
            "\(context)\nghost blocks remain after settlement",
            file: file,
            line: line
        )
        XCTAssertNil(
            fixture.viewportTrack,
            "\(context)\nviewport track remains after settlement",
            file: file,
            line: line
        )
        XCTAssertEqual(
            fixture.viewportCorrection,
            0,
            accuracy: 1e-6,
            "\(context)\nviewport correction did not settle to zero",
            file: file,
            line: line
        )

        for item in fixture.activeWindow.items {
            let identity = fixture.listView.items[item.index].identity
            for property in Self.properties {
                XCTAssertNil(
                    fixture.animationController.model.track(
                        for: .live(identity),
                        property: property
                    ),
                    "\(context)\nidentity=\(identity) property=\(property) "
                        + "retained a settled track",
                    file: file,
                    line: line
                )
            }
            XCTAssertEqual(
                fixture.animationController.positionOffsetX(
                    identity: identity,
                    at: now
                ) ?? 0,
                0,
                accuracy: 1e-6,
                "\(context)\nidentity=\(identity) x correction did not settle",
                file: file,
                line: line
            )
            XCTAssertEqual(
                fixture.animationController.positionOffset(
                    identity: identity,
                    at: now
                ) ?? 0,
                0,
                accuracy: 1e-6,
                "\(context)\nidentity=\(identity) y correction did not settle",
                file: file,
                line: line
            )
            XCTAssertEqual(
                fixture.animationController.opacity(
                    owner: .live(identity),
                    at: now
                ) ?? 1,
                1,
                accuracy: 1e-6,
                "\(context)\nidentity=\(identity) opacity did not settle",
                file: file,
                line: line
            )
            XCTAssertEqual(
                fixture.animationController.width(identity: identity, at: now)
                    ?? item.frame.width,
                item.frame.width,
                accuracy: 1e-6,
                "\(context)\nidentity=\(identity) width did not settle",
                file: file,
                line: line
            )
            XCTAssertEqual(
                fixture.animationController.height(identity: identity, at: now)
                    ?? item.frame.height,
                item.frame.height,
                accuracy: 1e-6,
                "\(context)\nidentity=\(identity) height did not settle",
                file: file,
                line: line
            )
        }
    }

    static func validateTrack(
        expected: ListAnimationTrack,
        animation: CAAnimation?,
        property: ListAnimatedProperty
    ) throws {
        guard let animation = animation as? CABasicAnimation else {
            throw MixedPassOracleError.missingAnimation(property)
        }
        guard (animation.value(
            forKey: "CoreListAnimation.generation"
        ) as? NSNumber)?.uint64Value == expected.generation else {
            throw MixedPassOracleError.wrongGeneration
        }
        // The emitted animation's phase axis must be the model's. `beginTime` no longer carries it —
        // Core Animation resolves that at the commit, and these fixtures are windowless so it never
        // resolves at all — so the emitter declares it as metadata, which is exact with no commit.
        guard let declared = animation.coreListDeclaredStartTime,
              abs(declared - expected.startTime) < 1e-9 else {
            throw MixedPassOracleError.wrongClock
        }
        // ...and a rebind's `.explicit` stamp must land on the phase axis. Deliberately only this
        // half: asserting `beginTime == 0` for an `.atCommit` emission would be a statement about
        // Core Animation (an origin outside the render tree is never resolved), not about CoreList,
        // and it stops being true the moment a fixture here is window-hosted. The two focused
        // compiler tests on provably bare layers own that assertion instead.
        //
        // This guard has the same premise, stated: a stress fixture is never in a window, so no
        // commit ever resolves an origin and `rebind` falls back to `track.startTime`. Window-host a
        // fixture here and the rebind will correctly stamp the RESOLVED origin instead, and this
        // must be relaxed to "non-zero" rather than the equality being taken as the contract.
        if animation.coreListPreservesPhase,
           abs(animation.beginTime - expected.startTime) >= 1e-9 {
            throw MixedPassOracleError.wrongOrigin
        }
        // A system spring's `animation.duration` is the spring's own settling duration, not the
        // track's — `speed` maps it onto the pass duration — so the track duration is not expected to
        // appear on the animation. No current scenario emits one (MixedPassScenario alternates
        // .easeInOut and .linear); the guard is here so one that does fails clearly rather than as a
        // baffling duration mismatch.
        if expected.springKind == .adjustedBezier {
            guard abs(animation.duration - expected.duration) < 1e-9 else {
                throw MixedPassOracleError.wrongClock
            }
        }
        // Endpoints are now fromValue/toValue on a CABasicAnimation rather than the first and last
        // entries of a sampled keyframe array.
        guard let first = animation.fromValue as? NSNumber,
              let last = animation.toValue as? NSNumber,
              abs(first.doubleValue - Double(expected.from)) < 1e-6,
              abs(last.doubleValue - Double(expected.to)) < 1e-6 else {
            throw MixedPassOracleError.wrongEndpoints
        }

        let expectedMapping: (keyPath: String, additive: Bool)
        switch property {
        case .viewportOffset:
            expectedMapping = ("bounds.origin.y", true)
        case .positionX:
            expectedMapping = ("position.x", true)
        case .positionY:
            expectedMapping = ("position.y", true)
        case .width:
            expectedMapping = ("bounds.size.width", false)
        case .height:
            expectedMapping = ("bounds.size.height", false)
        case .opacity:
            expectedMapping = ("opacity", false)
        }
        guard animation.keyPath == expectedMapping.keyPath,
              animation.isAdditive == expectedMapping.additive else {
            throw MixedPassOracleError.wrongMapping
        }
    }

    private func assertProperty(
        _ property: ListAnimatedProperty,
        oldTarget: CGFloat,
        newTarget: CGFloat,
        expectedFrom: CGFloat,
        old: MixedPassLiveSnapshot,
        new: MixedPassLiveSnapshot,
        step: MixedPassStep,
        identity: AnyHashable,
        context: String,
        file: StaticString,
        line: UInt
    ) {
        if abs(oldTarget - newTarget) <= 1e-6 {
            XCTAssertEqual(
                old.tracks[property],
                new.tracks[property],
                "\(context)\nidentity=\(identity) property=\(property) "
                    + "replaced an unchanged track",
                file: file,
                line: line
            )
            return
        }

        guard let track = new.tracks[property] else {
            XCTFail(
                "\(context)\nidentity=\(identity) property=\(property) "
                    + "changed target without a replacement track",
                file: file,
                line: line
            )
            return
        }
        XCTAssertEqual(
            track.from,
            expectedFrom,
            accuracy: 1e-5,
            "\(context)\nidentity=\(identity) property=\(property) "
                + "did not start from analytic presentation",
            file: file,
            line: line
        )
        XCTAssertEqual(
            track.duration,
            step.transition.duration,
            accuracy: 1e-9,
            "\(context)\nidentity=\(identity) property=\(property) "
                + "used the wrong pass duration",
            file: file,
            line: line
        )
        XCTAssertEqual(
            track.curve,
            step.transition.curve,
            "\(context)\nidentity=\(identity) property=\(property) "
                + "used the wrong pass curve",
            file: file,
            line: line
        )
    }

    private func assertEqual(
        _ lhs: CGRect,
        _ rhs: CGRect,
        accuracy: CGFloat,
        _ message: String,
        file: StaticString,
        line: UInt
    ) {
        XCTAssertEqual(
            lhs.minX, rhs.minX, accuracy: accuracy,
            message, file: file, line: line
        )
        XCTAssertEqual(
            lhs.minY, rhs.minY, accuracy: accuracy,
            message, file: file, line: line
        )
        XCTAssertEqual(
            lhs.width, rhs.width, accuracy: accuracy,
            message, file: file, line: line
        )
        XCTAssertEqual(
            lhs.height, rhs.height, accuracy: accuracy,
            message, file: file, line: line
        )
    }
}

private extension CGRect {
    var isFinite: Bool {
        origin.x.isFinite
            && origin.y.isFinite
            && size.width.isFinite
            && size.height.isFinite
    }
}
