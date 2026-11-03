import Foundation
import UIKit
import Display
import NavigationExpansionTransition

final class QrStudioExpansionDestination: NavigationExpansionDestinationProviding {
    private weak var view: QrStudioScreenComponent.View?
    private var heldView: QrStudioScreenComponent.View?
    private let isOpening: Bool
    private let landed: () -> Void

    let expansionPath: ExpansionPath = .origin
    let expansionOpenSpring: NavigationTransitionSpring? = NavigationTransitionSpring(duration: 0.38, bounce: 0.0)
    let expansionCloseSpring: NavigationTransitionSpring? = NavigationTransitionSpring(duration: 0.32, bounce: 0.0)

    init(view: QrStudioScreenComponent.View, isOpening: Bool, landed: @escaping () -> Void) {
        self.view = view
        self.isOpening = isOpening
        self.landed = landed
    }

    func expansionDidLand() {
        self.landed()
    }

    func lendExpansionDestination(in screenView: UIView) -> NavigationExpansionDestinationLoan? {
        guard let view = self.view else {
            return nil
        }
        self.heldView = view
        let views = view.lendForExpansion(isOpening: self.isOpening)
        let closeFrame = views.closeButton.superview != nil ? views.closeButton.convert(views.closeButton.bounds, to: screenView) : nil
        return NavigationExpansionDestinationLoan(
            avatar: nil,
            photo: nil,
            avatarView: nil,
            avatarRestFrame: CGRect(),
            labels: [],
            labelColors: [],
            carriedEdge: 0.0,
            appearingViews: [],
            backgroundViews: views.background,
            listViews: views.controls,
            patternViews: [],
            glassTint: nil,
            screenCornerRadii: views.screenCornerRadii,
            backButtonFrame: closeFrame,
            backgroundOpening: 0.05 ... 0.9,
            backgroundClosing: 0.1 ... 0.9,
            flyingViews: views.card
        )
    }

    func returnExpansionDestination() {
        self.heldView?.returnFromExpansion()
        self.heldView = nil
    }
}
