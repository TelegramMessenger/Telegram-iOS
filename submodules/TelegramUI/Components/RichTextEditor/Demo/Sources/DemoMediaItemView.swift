import UIKit
import RichTextEditorUIKit

/// A dependency-free media view for the Demo app + manual testing: a gradient placeholder that simulates
/// an async "load" and records `update(size:)` calls. Proves the editor's media seam needs no TelegramCore.
@available(iOS 17.0, *)
final class DemoMediaItemView: UIView, RichTextMediaItemView {
    private let label = UILabel()
    private let gradient = CAGradientLayer()

    init(mediaID: String) {
        super.init(frame: .zero)
        gradient.colors = [UIColor.systemTeal.cgColor, UIColor.systemIndigo.cgColor]
        layer.addSublayer(gradient)
        label.text = "media: \(mediaID)"
        label.textColor = .white
        label.textAlignment = .center
        label.alpha = 0
        addSubview(label)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            UIView.animate(withDuration: 0.25) { self?.label.alpha = 1 }
        }
    }
    required init?(coder: NSCoder) { fatalError() }

    var onControlTapped: ((RichTextMediaControlKind, Int?, UIView, CGRect) -> Void)?

    func update(size: CGSize) { setNeedsLayout() }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradient.frame = bounds
        label.frame = bounds
    }
}
