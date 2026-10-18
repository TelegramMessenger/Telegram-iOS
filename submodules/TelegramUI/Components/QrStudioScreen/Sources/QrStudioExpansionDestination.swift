import Foundation
import UIKit
import Display
import NavigationExpansionTransition

final class QrStudioExpansionDestination: NavigationExpansionDestinationProviding {
    private weak var view: QrStudioScreenComponent.View?
    private var heldView: QrStudioScreenComponent.View?
    private let isOpening: Bool

    let expansionPath: ExpansionPath = .origin

    init(view: QrStudioScreenComponent.View, isOpening: Bool) {
        self.view = view
        self.isOpening = isOpening
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
            flyingViews: views.card.flatMap { [$0] } ?? []
        )
    }

    func returnExpansionDestination() {
        self.heldView?.returnFromExpansion()
        self.heldView = nil
    }
}
