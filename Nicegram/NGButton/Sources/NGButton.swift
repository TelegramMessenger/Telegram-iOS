import UIKit
import NGExtensions
import NGTheme

public class NGButton: ActionButton {
    public enum ButtonState {
        case enabled
        case disabled
    }

    private let cornerRadiusRatio: CGFloat = 1.0 / 2.0

    public var isRounded: Bool = true {
        didSet {
            setNeedsLayout()
        }
    }

    public var buttonState: ButtonState = .enabled {
        didSet {
            switch buttonState {
            case .enabled:
                backgroundColor = .ngBlueTwo
                isUserInteractionEnabled = true
            case .disabled:
                backgroundColor = ngTheme?.incativeButtonColor ?? .white.withAlphaComponent(0.2)
                isUserInteractionEnabled = false
            }
        }
    }
    
    private var ngTheme: NGThemeColors?
    
    public init(ngTheme: NGThemeColors) {
        self.ngTheme = ngTheme
        
        super.init(frame: .zero)
        commonInit()
    }

    convenience init(title: String, image: UIImage?) {
        self.init(type: .system)
        setTitle(title, for: .normal)
        setImage(image, for: .normal)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }

    private func commonInit() {
        titleLabel?.textAlignment = .center
        titleLabel?.font = .systemFont(ofSize: 17.0, weight: .medium)
        setTitleColor(.white, for: .normal)
        imageView?.contentMode = .scaleAspectFit
    }

    open override func layoutSubviews() {
        super.layoutSubviews()
        if isRounded {
            layer.cornerRadius = 6.0
        }
        if let _ = self.imageView,
            let _ = self.titleLabel {
            imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 30)
        }
    }
}
