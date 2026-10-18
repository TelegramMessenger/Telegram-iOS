import Foundation
import UIKit
import Display
import NavigationBarNode
import NavigationBarComponent
import NavigationExpansionTransition

final class PeerInfoQrCodeExpansionSource: NavigationExpansionSourceProviding {
    private weak var navigationBar: NavigationBarNode?
    private var isLent = false

    init(navigationBar: NavigationBarNode) {
        self.navigationBar = navigationBar
    }

    var expansionBarExclusions: NavigationBarTransitionExclusions {
        return .none
    }

    func lendExpansionSource(in screenView: UIView) -> NavigationExpansionSourceLoan? {
        guard let navigationBar = self.navigationBar, let capsule = navigationBar.lendLeftCapsule(in: screenView) else {
            return nil
        }
        self.isLent = true
        var press = ExpansionPress.none
        press.origin = max(0.0, (capsule.pressScale - 1.0) / (ExpansionChoreography.liftPoints / max(1.0, capsule.frame.width)))
        return NavigationExpansionSourceLoan(origin: capsule.frame, originTint: capsule.tint, isDark: capsule.isDark, companion: nil, companionPhotoDiameter: 0.0, companionView: nil, labels: [], press: press, originContent: capsule.content)
    }

    func returnExpansionSource() {
        guard self.isLent else {
            return
        }
        self.isLent = false
        self.navigationBar?.returnLeftCapsule()
    }
}
