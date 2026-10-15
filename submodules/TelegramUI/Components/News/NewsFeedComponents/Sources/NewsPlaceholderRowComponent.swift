import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramPresentationData
import NewsFeedSupport

/// A shimmering stand-in for the post a load-more is fetching, shaped like the full-screen skeleton's first row.
public final class NewsPlaceholderRowComponent: Component {
    public let theme: PresentationTheme
    public let rowLayout: NewsSkeletonModelRow

    public init(theme: PresentationTheme, rowLayout: NewsSkeletonModelRow) {
        self.theme = theme
        self.rowLayout = rowLayout
    }

    public static func ==(lhs: NewsPlaceholderRowComponent, rhs: NewsPlaceholderRowComponent) -> Bool {
        return lhs.theme === rhs.theme && lhs.rowLayout == rhs.rowLayout
    }

    public final class View: UIView {
        private let shapesView = NewsSkeletonShapesView()

        override init(frame: CGRect) {
            super.init(frame: frame)
            self.addSubview(self.shapesView)
        }

        required init?(coder: NSCoder) {
            preconditionFailure()
        }

        func update(component: NewsPlaceholderRowComponent, availableSize: CGSize) -> CGSize {
            let size = CGSize(width: availableSize.width, height: component.rowLayout.height)
            self.shapesView.frame = CGRect(origin: CGPoint(), size: size)
            self.shapesView.update(size: size, shapes: newsSkeletonRowShapes(row: component.rowLayout, index: 0, y: 0.0, width: size.width, pixel: UIScreenPixel), theme: component.theme)
            return size
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }

    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize)
    }
}
