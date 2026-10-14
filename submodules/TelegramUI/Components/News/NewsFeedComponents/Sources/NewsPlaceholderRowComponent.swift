import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramPresentationData
import ShimmerEffect

/// A shimmering stand-in for the post a load-more is fetching, shaped like the full-screen skeleton's rows.
public final class NewsPlaceholderRowComponent: Component {
    public let theme: PresentationTheme
    public let rowLayout: NewsFeedSkeletonRowLayout

    public init(theme: PresentationTheme, rowLayout: NewsFeedSkeletonRowLayout) {
        self.theme = theme
        self.rowLayout = rowLayout
    }

    public static func ==(lhs: NewsPlaceholderRowComponent, rhs: NewsPlaceholderRowComponent) -> Bool {
        return lhs.theme === rhs.theme && lhs.rowLayout == rhs.rowLayout
    }

    public final class View: UIView {
        private let shimmerNode = ShimmerEffectNode()

        override init(frame: CGRect) {
            super.init(frame: frame)
            self.addSubview(self.shimmerNode.view)
        }

        required init?(coder: NSCoder) {
            preconditionFailure()
        }

        func update(component: NewsPlaceholderRowComponent, availableSize: CGSize) -> CGSize {
            let theme = component.theme
            let size = CGSize(width: availableSize.width, height: component.rowLayout.height)
            self.shimmerNode.frame = CGRect(origin: CGPoint(), size: size)
            self.shimmerNode.updateAbsoluteRect(CGRect(origin: CGPoint(), size: size), within: size)
            self.shimmerNode.update(backgroundColor: theme.list.plainBackgroundColor, foregroundColor: theme.list.mediaPlaceholderColor, shimmeringColor: theme.list.itemBlocksBackgroundColor.withAlphaComponent(0.4), shapes: newsFeedSkeletonRowShapes(component.rowLayout, y: 0.0), size: size)
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
