import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramPresentationData
import ShimmerEffect

/// A shimmering stand-in for a post row while the first page loads.
public final class NewsPlaceholderRowComponent: Component {
    public let theme: PresentationTheme

    public init(theme: PresentationTheme) {
        self.theme = theme
    }

    public static func ==(lhs: NewsPlaceholderRowComponent, rhs: NewsPlaceholderRowComponent) -> Bool {
        return lhs.theme === rhs.theme
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
            let size = CGSize(width: availableSize.width, height: 96.0)
            let sideInset: CGFloat = 16.0
            let lineDiameter: CGFloat = 10.0
            let textWidth = size.width - sideInset * 2.0
            self.shimmerNode.frame = CGRect(origin: CGPoint(), size: size)
            self.shimmerNode.updateAbsoluteRect(CGRect(origin: CGPoint(), size: size), within: size)
            let shapes: [ShimmerEffectNode.Shape] = [
                .circle(CGRect(x: sideInset, y: 12.0, width: 20.0, height: 20.0)),
                .roundedRectLine(startPoint: CGPoint(x: sideInset + 26.0, y: 17.0), width: 140.0, diameter: lineDiameter),
                .roundedRectLine(startPoint: CGPoint(x: sideInset, y: 42.0), width: textWidth, diameter: lineDiameter),
                .roundedRectLine(startPoint: CGPoint(x: sideInset, y: 60.0), width: textWidth, diameter: lineDiameter),
                .roundedRectLine(startPoint: CGPoint(x: sideInset, y: 78.0), width: floor(textWidth * 0.6), diameter: lineDiameter)
            ]
            self.shimmerNode.update(backgroundColor: theme.list.plainBackgroundColor, foregroundColor: theme.list.mediaPlaceholderColor, shimmeringColor: theme.list.itemBlocksBackgroundColor.withAlphaComponent(0.4), shapes: shapes, size: size)
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
