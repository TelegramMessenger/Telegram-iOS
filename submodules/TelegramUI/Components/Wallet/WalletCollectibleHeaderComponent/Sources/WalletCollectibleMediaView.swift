import UIKit
import AccountContext
import TelegramCore
import TelegramPresentationData
import ComponentFlow
import LottieComponent
import LottieSettings
import WalletCollectibleImageComponent

public final class WalletCollectibleMediaView: UIView {
    private let image = ComponentView<Empty>()
    private var animation = ComponentView<Empty>()
    private var animationFile: WalletNftFile?
    private weak var context: AccountContext?
    private var isAnimationVisible = false

    public override init(frame: CGRect) {
        super.init(frame: frame)
        self.isUserInteractionEnabled = false
        self.clipsToBounds = true
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func setAnimationVisible(_ visible: Bool) {
        guard self.isAnimationVisible != visible else { return }
        self.isAnimationVisible = visible
        if let view = self.animation.view as? LottieComponent.View {
            view.externalShouldPlay = visible
            if visible {
                view.playOnce()
            }
        }
    }

    public func update(context: AccountContext, theme: PresentationTheme, image: WalletNftFile?, lottie: WalletNftFile?, size: CGSize, cornerRadius: CGFloat? = nil, transition: ComponentTransition) {
        let cornerRadius = cornerRadius ?? size.width * 0.2
        self.layer.cornerRadius = cornerRadius
        let _ = self.image.update(
            transition: transition,
            component: AnyComponent(WalletCollectibleImageComponent(
                context: context,
                file: image,
                placeholderColor: theme.list.mediaPlaceholderColor,
                cornerRadius: cornerRadius
            )),
            environment: {},
            containerSize: size
        )
        if let view = self.image.view {
            if view.superview == nil {
                self.addSubview(view)
            }
            transition.setFrame(view: view, frame: CGRect(origin: .zero, size: size))
        }

        if self.animationFile != lottie || self.context !== context {
            self.animation.view?.removeFromSuperview()
            self.animation = ComponentView<Empty>()
            self.animationFile = lottie
            self.context = context
        }
        if let lottie {
            let _ = self.animation.update(
                transition: transition,
                component: AnyComponent(LottieComponent(
                    content: WalletRemoteLottieContent(context: context, file: lottie),
                    startingPosition: .begin,
                    size: size,
                    loop: false,
                    lottieSettings: context.lottieRenderingSettings
                )),
                environment: {},
                containerSize: size
            )
            if let view = self.animation.view as? LottieComponent.View {
                if view.superview == nil {
                    view.externalShouldPlay = self.isAnimationVisible
                    self.addSubview(view)
                    if self.isAnimationVisible {
                        view.playOnce()
                    }
                }
                transition.setFrame(view: view, frame: CGRect(origin: .zero, size: size))
            }
        }
    }
}
