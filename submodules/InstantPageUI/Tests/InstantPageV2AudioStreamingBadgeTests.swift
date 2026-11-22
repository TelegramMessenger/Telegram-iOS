import XCTest
import UIKit
import Display
import TelegramCore
import SemanticStatusNode
import UniversalMediaPlayer
@testable import InstantPageUI

/// The download badge on a rich message's audio row, which follows a regular music message's
/// (`ChatMessageInteractiveFileNode`): a 20pt disc in the control's own colours, 2pt past the
/// control's bottom-right, with a ring cut out of the control around it. The bug it pins drew a bare
/// 24pt glyph with no disc and no cutout, squeezed onto the album art.
final class InstantPageV2AudioStreamingBadgeTests: XCTestCase {
    private let controlFrame = CGRect(x: 12.0, y: 2.0, width: 40.0, height: 40.0)

    func test_badgeIsTwentyPointsAndOverhangsTheControlByTwo() {
        let frame = InstantPageV2AudioContentNode.streamingBadgeFrame(controlFrame: self.controlFrame)
        XCTAssertEqual(frame, CGRect(x: 34.0, y: 24.0, width: 20.0, height: 20.0))
    }

    func test_cutoutIsInTheControlsCoordinatesAndRingsTheBadge() {
        let cutout = InstantPageV2AudioContentNode.streamingBadgeCutout(controlFrame: self.controlFrame)
        let margin = 1.0 + UIScreenPixel
        // The badge at (34, 24) is at (22, 22) in the control's coordinates, ringed by `margin`.
        XCTAssertEqual(cutout, CGRect(x: 22.0 - margin, y: 22.0 - margin, width: 20.0 + margin * 2.0, height: 20.0 + margin * 2.0))
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

    func test_bufferingWhilePlayingCountsAsPlaying() {
        XCTAssertTrue(InstantPageV2AudioContentNode.isPlaying(.playing))
        XCTAssertTrue(InstantPageV2AudioContentNode.isPlaying(.buffering(initial: true, whilePlaying: true, progress: 0.0, display: true)))
        XCTAssertFalse(InstantPageV2AudioContentNode.isPlaying(.buffering(initial: false, whilePlaying: false, progress: 0.0, display: true)))
        XCTAssertFalse(InstantPageV2AudioContentNode.isPlaying(.paused))
        XCTAssertFalse(InstantPageV2AudioContentNode.isPlaying(nil))
    }

    func test_aTapOnTheBadgeCancelsOrStartsTheDownload() {
        // The badge's ✕ cancels a running download and its arrow starts one, as on a regular music message.
        XCTAssertEqual(InstantPageV2AudioContentNode.tapAction(fetchStatus: .Fetching(isActive: true, progress: 0.4), isPlaying: false, onBadge: true), .cancelFetch)
        XCTAssertEqual(InstantPageV2AudioContentNode.tapAction(fetchStatus: .Remote(progress: 0.0), isPlaying: false, onBadge: true), .fetch)
        XCTAssertEqual(InstantPageV2AudioContentNode.tapAction(fetchStatus: .Paused(progress: 0.2), isPlaying: false, onBadge: true), .fetch)
        // No badge is shown once local; a tap there is the row's.
        XCTAssertEqual(InstantPageV2AudioContentNode.tapAction(fetchStatus: .Local, isPlaying: false, onBadge: true), .play)
    }

    func test_aTapElsewhereKeepsTheRowsRouting() {
        XCTAssertEqual(InstantPageV2AudioContentNode.tapAction(fetchStatus: .Remote(progress: 0.0), isPlaying: false, onBadge: false), .fetch)
        XCTAssertEqual(InstantPageV2AudioContentNode.tapAction(fetchStatus: .Fetching(isActive: true, progress: 0.4), isPlaying: false, onBadge: false), .play)
        XCTAssertEqual(InstantPageV2AudioContentNode.tapAction(fetchStatus: .Local, isPlaying: false, onBadge: false), .play)
        XCTAssertEqual(InstantPageV2AudioContentNode.tapAction(fetchStatus: .Local, isPlaying: true, onBadge: false), .togglePlayPause)
        XCTAssertEqual(InstantPageV2AudioContentNode.tapAction(fetchStatus: nil, isPlaying: false, onBadge: false), .play)
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
