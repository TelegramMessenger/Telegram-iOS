import Foundation
import UIKit

func chatMediaEditorHidesCoveredContent(hasFinishedTransitionIn: Bool, isVisible: Bool, isDismissing: Bool, isSwipingDown: Bool, isInvalidated: Bool) -> Bool {
    return hasFinishedTransitionIn && isVisible && !isDismissing && !isSwipingDown && !isInvalidated
}

func chatMediaEditorCoveredViews(below coveringView: UIView, boundary: UIView?) -> [UIView] {
    guard let boundary, coveringView !== boundary, coveringView.isDescendant(of: boundary) else {
        return []
    }
    var result: [UIView] = []
    var current = coveringView
    while current !== boundary, let superview = current.superview, !(superview is UIWindow) {
        let siblings = superview.subviews
        if let index = siblings.firstIndex(where: { $0 === current }) {
            for sibling in siblings[..<index] where !sibling.isHidden {
                result.append(sibling)
            }
        }
        current = superview
    }
    return result
}

final class ChatMediaEditorCoveredContent {
    private final class WeakView {
        weak var view: UIView?

        init(_ view: UIView) {
            self.view = view
        }
    }

    var boundary: (UIView) -> UIView? = { view in
        return view.window?.rootViewController?.view
    }

    private weak var coveringView: UIView?
    private var hiddenViews: [WeakView] = []
    private(set) var isHiding = false

    private(set) var hasFinishedTransitionIn = false
    private(set) var isVisible = false
    private(set) var isDismissing = false
    private(set) var isSwipingDown = false
    private(set) var isInvalidated = false

    init() {
    }

    func setCoveringView(_ view: UIView) {
        if self.coveringView !== view {
            self.restore()
            self.coveringView = view
        }
    }

    func transitionInFinished() {
        self.hasFinishedTransitionIn = true
        self.apply()
    }

    func setIsVisible(_ isVisible: Bool) {
        self.isVisible = isVisible
        self.apply()
    }

    func setIsSwipingDown(_ isSwipingDown: Bool) {
        self.isSwipingDown = isSwipingDown
        self.apply()
    }

    func dismissBegan() {
        self.isDismissing = true
        self.apply()
    }

    func invalidate() {
        self.isInvalidated = true
        self.apply()
    }

    func apply() {
        let hides = chatMediaEditorHidesCoveredContent(
            hasFinishedTransitionIn: self.hasFinishedTransitionIn,
            isVisible: self.isVisible,
            isDismissing: self.isDismissing,
            isSwipingDown: self.isSwipingDown,
            isInvalidated: self.isInvalidated
        )
        guard hides, let coveringView = self.coveringView else {
            self.restore()
            return
        }
        if self.isHiding {
            let isCoveringHidden = self.hiddenViews.contains(where: { entry in
                guard let view = entry.view else {
                    return false
                }
                return coveringView.isDescendant(of: view)
            })
            guard isCoveringHidden else {
                return
            }
            self.restore()
        }
        let views = chatMediaEditorCoveredViews(below: coveringView, boundary: self.boundary(coveringView))
        guard !views.isEmpty else {
            return
        }
        self.isHiding = true
        self.hiddenViews = views.map(WeakView.init)
        for view in views {
            view.isHidden = true
        }
    }

    func restore() {
        guard self.isHiding else {
            return
        }
        self.isHiding = false
        let views = self.hiddenViews
        self.hiddenViews = []
        for entry in views {
            entry.view?.isHidden = false
        }
    }
}
