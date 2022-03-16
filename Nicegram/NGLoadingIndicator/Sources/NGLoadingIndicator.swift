import UIKit
import Lottie
import NGExtensions

public protocol NGLoadingIndicatorShowable {
    func display(isLoading: Bool)
}

open class NGLoadingIndicator: UIView {
    public static let shared = NGLoadingIndicator()
    private var isAnimating = false

    private let nicegramAnimationView: LOTAnimationView = {
        let jsonName = "NicegramLoader"
        let animationView = LOTAnimationView(name: jsonName)

        animationView.loopAnimation = true
        return animationView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear

        addSubview(nicegramAnimationView)
        nicegramAnimationView.snp.makeConstraints {
            $0.height.width.equalTo(80.0)
            $0.center.equalToSuperview()
        }
        isHidden = true
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    open func startAnimating(on view: UIView? = UIApplication.keyWindow) {
        if isAnimating {
            cancelAnimation()
            return
        }
        guard let containerView = view else { return }
        let containerFrame = view?.bounds

        frame = containerFrame ?? UIScreen.main.bounds
        isHidden = false
        containerView.addSubview(self)

        UIView.animate(withDuration: 0.3) {
            self.backgroundColor = .black.withAlphaComponent(0.5)
        } completion: { _ in
            self.isAnimating = true
            self.nicegramAnimationView.play()
        }
    }

    open func stopAnimating() {
        if !isAnimating {
            return
        }
        nicegramAnimationView.stop()
        UIView.animate(withDuration: 0.2) { [weak self] in
            guard let self = self else { return }
            self.backgroundColor = .clear
        } completion: { [weak self] _ in
            guard let self = self else { return }
            self.isAnimating = false
            self.isHidden = true
        }
    }

    private func cancelAnimation() {
        nicegramAnimationView.stop()
        isAnimating = false
        isHidden = true
    }
}

public extension UIApplication {
    static var keyWindow: UIWindow? {
        return UIApplication.shared.windows.filter({ $0.isKeyWindow }).first
    }
}
