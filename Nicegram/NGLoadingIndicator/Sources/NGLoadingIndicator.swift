import UIKit
import Lottie
import NGExtensions

public protocol NGLoadingIndicatorShowable {
    func display(isLoading: Bool)
}

open class NGLoadingIndicator: UIView {
    public static let shared = NGLoadingIndicator()
    private var isAnimating = false

    private let nicegramAnimationView: AnimationView = {
        let jsonName = "NicegramLoader"
        let animationView = AnimationView(name: jsonName)

        animationView.loopMode = .loop
        return animationView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false

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
        
        isHidden = false
        containerView.addSubview(self)
        snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        self.isAnimating = true
        UIView.animate(withDuration: 0.3) {
            self.backgroundColor = .black.withAlphaComponent(0.5)
        } completion: { completed in
            if completed {
                self.nicegramAnimationView.play()
            }
        }
    }

    open func stopAnimating() {
        if !isAnimating {
            return
        }
        self.isAnimating = false
        nicegramAnimationView.stop()
        UIView.animate(withDuration: 0.2, delay: 0, options: [.beginFromCurrentState]) { [weak self] in
            guard let self = self else { return }
            self.backgroundColor = .clear
        } completion: { [weak self] _ in
            guard let self = self else { return }
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
