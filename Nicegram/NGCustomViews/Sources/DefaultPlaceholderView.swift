import UIKit
import SnapKit
import NGButton

open class DefaultPlaceholderView: UIView {
    
    //  MARK: - UI Elements

    private let imageView = UIImageView()
    private let imageContainer = UIView()
    private let descriptionLabel = UILabel()
    private let button = CustomButton()
    private let stack = UIStackView()
    
    //  MARK: - Public Properties
    
    var alignment: UIStackView.Alignment {
        get { stack.alignment }
        set { stack.alignment = newValue }
    }
    
    var spacing: CGFloat {
        get { stack.spacing }
        set { stack.spacing = newValue }
    }

    var onButtonClick: (() -> ())? {
        get { button.touchUpInside }
        set { button.touchUpInside = newValue }
    }
    
    //  MARK: - Lifecycle
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        
        imageView.contentMode = .scaleAspectFit
        
        descriptionLabel.font = .systemFont(ofSize: 16, weight: .regular)
        descriptionLabel.textColor = .ngSubtitle
        descriptionLabel.numberOfLines = 0
        descriptionLabel.textAlignment = .center
        
        imageContainer.addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview()
            make.top.bottom.equalToSuperview()
        }
        
        button.applyMainActionStyle()
        button.insets = UIEdgeInsets(top: 16, left: 0, bottom: 16, right: 0)
        
        [imageContainer, descriptionLabel, button].forEach({ stack.addArrangedSubview($0) })
        stack.axis = .vertical
        stack.spacing = 40
        
        addSubview(stack)
        stack.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(16)
        }
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    //  MARK: - Public Functions

    public func display(image: UIImage?, description: String?, buttonTitle: String?, buttonImage: UIImage? = nil) {
        imageView.image = image
        imageContainer.isHidden = (image == nil)
        
        descriptionLabel.text = description
        descriptionLabel.isHidden = (description == nil)
        
        button.display(title: buttonTitle, image: buttonImage?.withRenderingMode(.alwaysTemplate))
        button.isHidden = (buttonTitle == nil)
    }
    
    public func configureButton(_ c: (CustomButton) -> ()) {
        c(button)
    }
}
