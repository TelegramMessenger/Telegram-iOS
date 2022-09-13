import UIKit
import SnapKit
import NGImageContainer

public class CustomButton: UIControl {
    
    //  MARK: - UI Elements

    private let imageView = ImageContainer()
    private let titleLabel = UILabel()
    private let stack = UIStackView()
    private var currentBackgroundView: UIView?
    
    //  MARK: - Public Properties
    
    public var imageSizeStrategy: ImageContainer.ImageSizeStrategy {
        get { imageView.imageSizeStrategy }
        set { imageView.imageSizeStrategy = newValue }
    }

    public var spacing: CGFloat {
        get { stack.spacing }
        set { stack.spacing = newValue }
    }
    
    public var insets: UIEdgeInsets {
        get { stack.layoutMargins }
        set { stack.layoutMargins = newValue }
    }
    
    public var imagePosition: ImagePosition = .leading {
        didSet {
            setImagePosition(imagePosition)
        }
    }
    
    public var foregroundColor: UIColor? = nil {
        didSet {
            setCurrentForegroundColor(foregroundColor)
        }
    }
    
    public var backgrounView: UIView? {
        get { currentBackgroundView }
        set { setCurrentBackgroundView(newValue) }
    }
    
    public var touchUpInside: (() -> ())?
    
    //  MARK: - Lifecycle
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        
        clipsToBounds = true
        
        addTarget(self, action: #selector(onTouchUpInside), for: .touchUpInside)
        
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .white
        
        titleLabel.textColor = .white
        
        [imageView, titleLabel].forEach({ stack.addArrangedSubview($0) })
        stack.spacing = 4
        stack.alignment = .center
        stack.isLayoutMarginsRelativeArrangement = true
        
        setImagePosition(imagePosition)
        
        addSubview(stack)
        
        stack.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.top.greaterThanOrEqualToSuperview()
        }
        
        // avoid ambiguity + size as less as possible
        snp.makeConstraints { make in
            make.width.height.equalTo(1).priority(1)
        }
        
        imageView.snp.contentHuggingHorizontalPriority = 251
        imageView.snp.contentHuggingVerticalPriority = 251
        
        imageView.snp.contentCompressionResistanceHorizontalPriority = 760
        imageView.snp.contentCompressionResistanceVerticalPriority = 760
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override var intrinsicContentSize: CGSize {
        let imageSize = imageView.intrinsicContentSize
        let labelSize = titleLabel.intrinsicContentSize
        let width: CGFloat
        let height: CGFloat
        switch stack.axis {
        case .horizontal:
            width = insets.left + imageSize.width + spacing + labelSize.width + insets.right
            height = max(imageSize.height, labelSize.height) + insets.top + insets.bottom
        case .vertical:
            width = max(imageSize.width, labelSize.width) + insets.left + insets.right
            height = insets.top + imageSize.height + spacing + labelSize.height + insets.bottom
        @unknown default:
            return .zero
        }
        
        return CGSize(width: width, height: height)
    }
    
    public override var isHighlighted: Bool {
        didSet {
            updateToCurrentState()
        }
    }
    
    public override var isSelected: Bool {
        didSet {
            updateToCurrentState()
        }
    }
    
    public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.point(inside: point, with: event) {
            return self
        } else {
            return super.hitTest(point, with: event)
        }
    }
    
    //  MARK: - Public Functions

    public func display(title: String?, image: UIImage?) {
        titleLabel.text = title
        titleLabel.isHidden = (title == nil)
        
        imageView.display(image: image, backgroundColor: nil)
        imageView.isHidden = (image == nil)
    }
    
    public func configureImageContainer(_ c: (ImageContainer) -> ()) {
        c(imageView)
    }
    
    public func configureTitleLabel(_ c: (UILabel) -> ()) {
        c(titleLabel)
    }
    
    //  MARK: - Private Functions
    
    private func updateToCurrentState() {
        let newForegroundColor: UIColor?
        switch state {
        case .highlighted, .selected:
            newForegroundColor = foregroundColor?.withMultipliedAlpha(0.5)
        default:
            newForegroundColor = foregroundColor
        }
        
        setCurrentForegroundColor(newForegroundColor)
    }
    
    private func setCurrentForegroundColor(_ foregroundColor: UIColor?) {
        if let foregroundColor = foregroundColor {
            imageView.tintColor = foregroundColor
            titleLabel.textColor = foregroundColor
        }
    }
    
    private func setImagePosition(_ imagePosition: ImagePosition) {
        let arrangedSubviews: [UIView]
        switch imagePosition {
        case .leading, .top:
            arrangedSubviews = [imageView, titleLabel]
        case .trailing, .bottom:
            arrangedSubviews = [titleLabel, imageView]
        }
        stack.removeAllArrangedSubviews()
        arrangedSubviews.forEach({ stack.addArrangedSubview($0) })
        
        switch imagePosition {
        case .leading, .trailing:
            stack.axis = .horizontal
        case .top, .bottom:
            stack.axis = .vertical
        }
    }
    
    private func setCurrentBackgroundView(_ view: UIView?) {
        currentBackgroundView?.removeFromSuperview()
        
        if let view = view {
            insertSubview(view, at: 0)
            view.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
        }
        
        currentBackgroundView = view
    }

    @objc private func onTouchUpInside() {
        touchUpInside?()
    }
}

extension CustomButton {
    public enum ImagePosition {
        case leading
        case trailing
        case top
        case bottom
    }
}
