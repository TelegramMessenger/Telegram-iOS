import UIKit
import Display
import ComponentFlow
import ShimmeringMask

final class WalletSendFeePlaceholderComponent: Component {
    let color: UIColor

    init(color: UIColor) {
        self.color = color
    }

    static func ==(lhs: WalletSendFeePlaceholderComponent, rhs: WalletSendFeePlaceholderComponent) -> Bool {
        return lhs.color.isEqual(rhs.color)
    }

    final class View: UIView {
        private let shimmerView = ShimmeringMaskView(peakAlpha: 0.3, duration: 1.6)
        private let shape = ComponentView<Empty>()

        override init(frame: CGRect) {
            super.init(frame: frame)

            self.isUserInteractionEnabled = false
            self.shimmerView.isUserInteractionEnabled = false
            self.addSubview(self.shimmerView)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func update(
            component: WalletSendFeePlaceholderComponent,
            state: EmptyComponentState,
            transition: ComponentTransition
        ) -> CGSize {
            let size = CGSize(width: 99.0, height: 15.0)
            self.shape.parentState = state
            let shapeSize = self.shape.update(
                transition: transition,
                component: AnyComponent(RoundedRectangle(
                    color: component.color,
                    cornerRadius: 8.0,
                    size: size
                )),
                environment: {},
                containerSize: size
            )
            if let shapeView = self.shape.view {
                if shapeView.superview !== self.shimmerView.contentView {
                    self.shimmerView.contentView.addSubview(shapeView)
                }
                transition.setFrame(view: shapeView, frame: CGRect(origin: CGPoint(x: 0.0, y: UIScreenPixel), size: shapeSize))
            }
            transition.setFrame(view: self.shimmerView, frame: CGRect(origin: CGPoint(x: 0.0, y: UIScreenPixel), size: size))
            self.shimmerView.update(
                size: size,
                containerWidth: size.width,
                offsetX: 0.0,
                gradientWidth: 60.0,
                transition: transition
            )
            return size
        }
    }

    func makeView() -> View {
        return View(frame: .zero)
    }

    func update(
        view: View,
        availableSize: CGSize,
        state: EmptyComponentState,
        environment: Environment<Empty>,
        transition: ComponentTransition
    ) -> CGSize {
        return view.update(component: self, state: state, transition: transition)
    }
}

