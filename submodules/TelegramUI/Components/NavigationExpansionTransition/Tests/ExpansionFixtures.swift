import Foundation
import UIKit
import Display
@testable import NavigationExpansionTransition

/// A chat → profile pair on a 402 × 874 screen, measured from the app: the pill 140 × 44 at the bar's centre (y 64),
/// the avatar capsule 44 at the right edge (inset 16), its photo 38; the profile's avatar 100 at y 76 (status bar 54 +
/// 22); title and status in the pill (17/12 pt) and in the profile (28/17 pt); the cover's bottom at 327.
func makeExpansionGeometry(screenCornerRadii: CornerRadii = CornerRadii(uniform: 62.0)) -> ExpansionGeometry {
    let width: CGFloat = 402.0
    return ExpansionGeometry(
        screenSize: CGSize(width: width, height: 874.0),
        screenCornerRadii: screenCornerRadii,
        origin: CGRect(x: width * 0.5 - 70.0, y: 64.0, width: 140.0, height: 44.0),
        companion: CGRect(x: width - 16.0 - 44.0, y: 64.0, width: 44.0, height: 44.0),
        companionPhotoDiameter: 38.0,
        avatar: CGRect(x: width * 0.5 - 50.0, y: 76.0, width: 100.0, height: 100.0),
        photo: CGRect(x: 0.0, y: 0.0, width: width, height: 500.0),
        labels: [
            ExpansionLabelGeometry(sourceCenter: CGPoint(x: width * 0.5, y: 79.0), sourceSize: CGSize(width: 96.0, height: 20.0), destinationCenter: CGPoint(x: width * 0.5, y: 202.0), destinationSize: CGSize(width: 158.0, height: 34.0), photoCenter: CGPoint(x: 120.0, y: 430.0), photoSize: CGSize(width: 126.0, height: 27.0)),
            ExpansionLabelGeometry(sourceCenter: CGPoint(x: width * 0.5, y: 96.0), sourceSize: CGSize(width: 80.0, height: 14.0), destinationCenter: CGPoint(x: width * 0.5, y: 230.0), destinationSize: CGSize(width: 130.0, height: 20.0), photoCenter: CGPoint(x: 100.0, y: 456.0), photoSize: CGSize(width: 104.0, height: 16.0))
        ],
        carriedEdge: 327.0,
        appearing: (0 ..< 4).map { i in CGRect(x: 16.0 + CGFloat(i) * 94.0, y: 262.0, width: 86.0, height: 58.0) }
    )
}

/// iPhone Duo's cover screen in portrait: 8 pt on the hinge side, 59 pt outside (`iPhoneDuoScreenCornerRadii`).
let duoCoverScreenCornerRadii = CornerRadii(topLeft: 8.0, topRight: 59.0, bottomLeft: 8.0, bottomRight: 59.0)
