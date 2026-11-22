import Foundation
import UIKit
import XCTest
import Display
import ChatTitleActivityNode
@testable import TelegramCallsUI

/// Pins where the group call header puts its "speaking" line (indicator + names, laid out by a real
/// `ChatTitleActivityNode`): centered under the title like the status line it replaces, flush left in the
/// landscape layout, and inside the title's width when the names are truncated.
final class VideoChatTitleActivityStatusLayoutTests: XCTestCase {
    /// The union of everything the activity node draws (the indicator and the text), in container coordinates.
    private func speakingUnitFrame(text: String, containerWidth: CGFloat, isLandscape: Bool) -> CGRect {
        let container = UIView(frame: CGRect(origin: CGPoint(), size: CGSize(width: containerWidth, height: 40.0)))
        let node = ChatTitleActivityNode()
        let color = UIColor(rgb: 0x34c759)
        let _ = node.transitionToState(.recordingVoice(NSAttributedString(string: text, font: Font.regular(13.0), textColor: color), color), animation: .none)
        container.addSubview(node.view)

        let frame = VideoChatTitleComponent.View.layoutActivityStatusNode(node, containerWidth: containerWidth, statusMinY: 20.0, isLandscape: isLandscape)
        node.view.center = frame.center
        node.view.bounds = CGRect(origin: CGPoint(), size: frame.size)

        // The indicator is layer-backed, so walk layers rather than views.
        var unitFrame = CGRect.null
        func collectLeaves(_ layer: CALayer) {
            if let sublayers = layer.sublayers, !sublayers.isEmpty {
                sublayers.forEach(collectLeaves)
            } else {
                unitFrame = unitFrame.union(layer.convert(layer.bounds, to: container.layer))
            }
        }
        collectLeaves(node.layer)
        return unitFrame
    }

    func testSpeakingStatusIsCenteredUnderTheTitle() {
        for text in ["Igor", "Igor, Pavel", "Igor, Pavel, Alexander, Dmitry"] {
            let unitFrame = self.speakingUnitFrame(text: text, containerWidth: 260.0, isLandscape: false)
            XCTAssertFalse(unitFrame.isNull, text)
            XCTAssertGreaterThan(unitFrame.width, 24.0, text)
            XCTAssertEqual(unitFrame.midX, 130.0, accuracy: 1.0, text)
        }
    }

    func testTruncatedSpeakingStatusStaysCenteredWithinTheTitleWidth() {
        let text = String(repeating: "Alexander Konstantinopolsky, ", count: 6)
        let unitFrame = self.speakingUnitFrame(text: text, containerWidth: 260.0, isLandscape: false)
        XCTAssertEqual(unitFrame.midX, 130.0, accuracy: 1.0)
        XCTAssertGreaterThanOrEqual(unitFrame.minX, -0.5)
        XCTAssertLessThanOrEqual(unitFrame.maxX, 260.5)
    }

    func testSpeakingStatusIsFlushLeftInLandscape() {
        let unitFrame = self.speakingUnitFrame(text: "Igor, Pavel", containerWidth: 260.0, isLandscape: true)
        XCTAssertEqual(unitFrame.minX, 0.0, accuracy: 1.0)
    }
}
