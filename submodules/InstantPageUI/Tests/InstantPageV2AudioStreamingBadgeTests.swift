import XCTest
import UIKit
import Display
import TelegramCore
import SemanticStatusNode
@testable import InstantPageUI

/// The download badge on a rich message's audio row, which follows a regular music message's
/// (`ChatMessageInteractiveFileNode`): a 20pt disc in the control's own colours, 2pt past the
/// control's bottom-right, with a ring cut out of the control around it. The bug it pins drew a bare
/// 24pt glyph with no disc and no cutout, squeezed onto the album art.
final class InstantPageV2AudioStreamingBadgeTests: XCTestCase {
    private let controlFrame = CGRect(x: 12.0, y: 2.0, width: 40.0, height: 40.0)

    func test_badgeIsTwentyPointsAndOverhangsTheControlByTwo() {
        let frame = InstantPageV2AudioContentNode.streamingBadgeFrame(controlFrame: self.controlFrame)
        XCTAssertEqual(frame.size, CGSize(width: 20.0, height: 20.0))
        XCTAssertEqual(frame.maxX, self.controlFrame.maxX + 2.0)
        XCTAssertEqual(frame.maxY, self.controlFrame.maxY + 2.0)
    }

    func test_cutoutIsInTheControlsCoordinatesAndRingsTheBadge() {
        let badge = InstantPageV2AudioContentNode.streamingBadgeFrame(controlFrame: self.controlFrame)
        let cutout = InstantPageV2AudioContentNode.streamingBadgeCutout(controlFrame: self.controlFrame)
        let margin = 1.0 + UIScreenPixel
        let badgeInControl = badge.offsetBy(dx: -self.controlFrame.minX, dy: -self.controlFrame.minY)
        XCTAssertEqual(cutout, badgeInControl.insetBy(dx: -margin, dy: -margin))
    }

    func test_notDownloadedShowsTheDownloadBadge() {
        XCTAssertEqual(InstantPageV2AudioContentNode.streamingState(fetchStatus: .Remote(progress: 0.0), isPlaying: false), .download)
        XCTAssertEqual(InstantPageV2AudioContentNode.streamingState(fetchStatus: .Paused(progress: 0.3), isPlaying: false), .download)
    }

    func test_downloadingShowsAThinProgressRing() {
        XCTAssertEqual(
            InstantPageV2AudioContentNode.streamingState(fetchStatus: .Fetching(isActive: true, progress: 0.5), isPlaying: false),
            .progress(value: 0.5, cancelEnabled: true, appearance: SemanticStatusNodeState.ProgressAppearance(inset: 1.0, lineWidth: 2.0), animateRotation: true)
        )
        // A just-started fetch still shows a sliver of ring, as a regular music message does.
        XCTAssertEqual(
            InstantPageV2AudioContentNode.streamingState(fetchStatus: .Fetching(isActive: true, progress: 0.0), isPlaying: false),
            .progress(value: CGFloat(Float(0.027)), cancelEnabled: true, appearance: SemanticStatusNodeState.ProgressAppearance(inset: 1.0, lineWidth: 2.0), animateRotation: true)
        )
    }

    func test_downloadedOrUnknownShowsNoBadge() {
        XCTAssertEqual(InstantPageV2AudioContentNode.streamingState(fetchStatus: .Local, isPlaying: false), .none)
        XCTAssertEqual(InstantPageV2AudioContentNode.streamingState(fetchStatus: nil, isPlaying: false), .none)
    }

    func test_playingHidesTheBadge() {
        // A regular music message hides the badge while the control shows pause (streaming playback).
        XCTAssertEqual(InstantPageV2AudioContentNode.streamingState(fetchStatus: .Remote(progress: 0.0), isPlaying: true), .none)
        XCTAssertEqual(InstantPageV2AudioContentNode.streamingState(fetchStatus: .Fetching(isActive: true, progress: 0.4), isPlaying: true), .none)
    }

    func test_controlColorsFollowTheRegularMusicMessage() {
        let accent = UIColor(rgb: 0x3e88f7)
        let incoming = InstantPageV2AudioContentNode.controlColors(mediaActiveControlColor: accent, incoming: true, colorOverride: nil)
        XCTAssertEqual(incoming.background, accent)
        XCTAssertEqual(incoming.foreground, .white)

        // Outgoing (and a white control) cut the glyph out of the disc, so the bubble shows through it.
        let outgoing = InstantPageV2AudioContentNode.controlColors(mediaActiveControlColor: accent, incoming: false, colorOverride: nil)
        XCTAssertEqual(outgoing.background, accent)
        XCTAssertEqual(outgoing.foreground, .clear)
        let white = InstantPageV2AudioContentNode.controlColors(mediaActiveControlColor: .white, incoming: true, colorOverride: nil)
        XCTAssertEqual(white.foreground, .clear)

        let override = InstantPageAudioColorOverride(control: .red, controlForeground: .green, title: .black, description: .gray)
        let overridden = InstantPageV2AudioContentNode.controlColors(mediaActiveControlColor: accent, incoming: true, colorOverride: override)
        XCTAssertEqual(overridden.background, .red)
        XCTAssertEqual(overridden.foreground, .green)
    }
}
