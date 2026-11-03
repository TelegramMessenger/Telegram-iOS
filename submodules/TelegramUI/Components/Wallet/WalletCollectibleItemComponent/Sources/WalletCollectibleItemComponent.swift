import Foundation
import UIKit
import Display
import ComponentFlow
import MultilineTextComponent
import TelegramPresentationData
import AccountContext
import WalletContext
import WalletCollectibleImageComponent

public final class WalletCollectibleItemComponent: Component {
    public let context: AccountContext
    public let theme: PresentationTheme
    public let collectible: WalletContext.Collectible

    public init(
        context: AccountContext,
        theme: PresentationTheme,
        collectible: WalletContext.Collectible
    ) {
        self.context = context
        self.theme = theme
        self.collectible = collectible
    }

    public static func ==(lhs: WalletCollectibleItemComponent, rhs: WalletCollectibleItemComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.collectible != rhs.collectible {
            return false
        }
        return true
    }

    public final class View: UIView {
        private let image = ComponentView<Empty>()
        private let title = ComponentView<Empty>()
        private let subtitle = ComponentView<Empty>()

        override public init(frame: CGRect) {
            super.init(frame: frame)

            self.isUserInteractionEnabled = false
        }

        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func update(
            component: WalletCollectibleItemComponent,
            availableSize: CGSize,
            state: EmptyComponentState,
            environment: Environment<Empty>,
            transition: ComponentTransition
        ) -> CGSize {
            let imageSize = CGSize(width: 40.0, height: 40.0)
            let _ = self.image.update(
                transition: transition,
                component: AnyComponent(WalletCollectibleImageComponent(
                    context: component.context,
                    file: component.collectible.thumbnail,
                    placeholderColor: component.theme.list.mediaPlaceholderColor,
                    cornerRadius: 12.0
                )),
                environment: {},
                containerSize: imageSize
            )
            if let imageView = self.image.view {
                if imageView.superview == nil {
                    self.addSubview(imageView)
                }
                transition.setFrame(
                    view: imageView,
                    frame: CGRect(origin: CGPoint(x: -4.0, y: 0.0), size: imageSize)
                )
            }

            let textOriginX: CGFloat = 46.0
            let textAvailableWidth = max(0.0, availableSize.width - textOriginX)
            let titleText = NSMutableAttributedString(attributedString: NSAttributedString(
                string: component.collectible.name,
                font: Font.semibold(17.0),
                textColor: component.theme.list.itemPrimaryTextColor
            ))
            if let numberRange = component.collectible.name.range(of: "#[0-9]+$", options: .regularExpression) {
                titleText.addAttribute(
                    .foregroundColor,
                    value: component.theme.list.itemSecondaryTextColor,
                    range: NSRange(numberRange, in: component.collectible.name)
                )
            }
            let titleSize = self.title.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(titleText),
                    maximumNumberOfLines: 1
                )),
                environment: {},
                containerSize: CGSize(width: textAvailableWidth, height: 100.0)
            )
            let subtitleSize = self.subtitle.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: component.collectible.subtitle,
                        font: Font.regular(14.0),
                        textColor: component.theme.list.itemSecondaryTextColor
                    )),
                    maximumNumberOfLines: 1
                )),
                environment: {},
                containerSize: CGSize(width: textAvailableWidth, height: 100.0)
            )

            let textSpacing: CGFloat = 1.0
            let textHeight = titleSize.height + textSpacing + subtitleSize.height
            let textOriginY = floor((imageSize.height - textHeight) * 0.5)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                transition.setFrame(
                    view: titleView,
                    frame: CGRect(origin: CGPoint(x: textOriginX, y: textOriginY), size: titleSize)
                )
            }
            if let subtitleView = self.subtitle.view {
                if subtitleView.superview == nil {
                    self.addSubview(subtitleView)
                }
                transition.setFrame(
                    view: subtitleView,
                    frame: CGRect(
                        origin: CGPoint(x: textOriginX, y: textOriginY + titleSize.height + textSpacing),
                        size: subtitleSize
                    )
                )
            }

            return CGSize(width: availableSize.width, height: imageSize.height)
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }

    public func update(
        view: View,
        availableSize: CGSize,
        state: EmptyComponentState,
        environment: Environment<Empty>,
        transition: ComponentTransition
    ) -> CGSize {
        return view.update(
            component: self,
            availableSize: availableSize,
            state: state,
            environment: environment,
            transition: transition
        )
    }
}
