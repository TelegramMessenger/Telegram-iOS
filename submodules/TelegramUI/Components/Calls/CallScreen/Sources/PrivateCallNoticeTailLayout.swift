import Foundation
import UIKit

/// Where a call screen notice with a tail stands and where along its bottom edge the tail sits, so that the tail's tip
/// is over its target (the video button) wherever the button row puts it.
///
/// The notice centers over the target as far as the band between the side insets (iPhone Duo's side strip) allows,
/// keeping `sideInset` from its edges; one wider than that centers on the container, as the other notices do. The tail
/// keeps to the straight part of the edge, clear of the rounded corners.
public struct PrivateCallNoticeTailLayout: Equatable {
    public static let tailWidth: CGFloat = 20.0
    public static let tailHeight: CGFloat = 8.0

    /// The notice's minimum x in the container.
    public var noticeX: CGFloat
    /// The tail's center in the notice.
    public var tailX: CGFloat

    public init(noticeWidth: CGFloat, cornerRadius: CGFloat, targetX: CGFloat, bandMinX: CGFloat, bandWidth: CGFloat, containerWidth: CGFloat, sideInset: CGFloat) {
        let minX: CGFloat
        let maxX: CGFloat
        if noticeWidth <= bandWidth - sideInset * 2.0 {
            minX = bandMinX + sideInset
            maxX = bandMinX + bandWidth - sideInset - noticeWidth
        } else {
            minX = floor((containerWidth - noticeWidth) * 0.5)
            maxX = minX
        }
        self.noticeX = max(minX, min(maxX, floor(targetX - noticeWidth * 0.5)))

        let tailInset = cornerRadius + PrivateCallNoticeTailLayout.tailWidth * 0.5
        let minTailX = min(tailInset, noticeWidth * 0.5)
        let maxTailX = max(noticeWidth - tailInset, noticeWidth * 0.5)
        self.tailX = max(minTailX, min(maxTailX, targetX - self.noticeX))
    }
}
