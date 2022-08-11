import UIKit
import SnapKit
import NGButton

public struct HeaderCardViewModel {
    public let title: String
    public let subtitle: String?
    public let subtitleButtonImage: UIImage?
    public let backgroundImage: UIImage
    
    public init(title: String, subtitle: String?, subtitleButtonImage: UIImage?, backgroundImage: UIImage) {
        self.title = title
        self.subtitle = subtitle
        self.subtitleButtonImage = subtitleButtonImage
        self.backgroundImage = backgroundImage
    }
}

open class HeaderCardView: UIView {
    
    //  MARK: - UI Elements

    private let backgroundImageView = UIImageView()
    private let gradientView = GradientView()
    private let titleLabel = UILabel()
    private let subtitleButton = CustomButton()
    
    //  MARK: - Public Properties

    public var onSubtitleButtonTap: (() -> ())? {
        get { return subtitleButton.touchUpInside }
        set { subtitleButton.touchUpInside = newValue }
    }
    
    //  MARK: - Lifecycle
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        
        layer.cornerRadius = 12
        clipsToBounds = true
        
        gradientView.colors = [
            .black.withAlphaComponent(0),
            .black.withAlphaComponent(0.5)
        ]
        
        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.5
        
        subtitleButton.foregroundColor = .white
        subtitleButton.configureTitleLabel { label in
            label.font = .systemFont(ofSize: 14, weight: .regular)
            label.adjustsFontSizeToFitWidth = true
            label.minimumScaleFactor = 0.5
        }
        subtitleButton.configureImageContainer { imageContainer in
            imageContainer.backgroundColor = .white.withAlphaComponent(0.2)
            imageContainer.layer.cornerRadius = 12
            imageContainer.snp.makeConstraints { make in
                make.width.height.equalTo(24)
            }
        }
        subtitleButton.spacing = 8
        subtitleButton.imagePosition = .trailing
        
        let stack = UIStackView(arrangedSubviews: [titleLabel, subtitleButton])
        stack.axis = .vertical
        stack.spacing = 4
        stack.alignment = .center
        
        addSubview(backgroundImageView)
        addSubview(gradientView)
        addSubview(stack)
        
        backgroundImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        gradientView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        stack.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview().inset(30)
            make.leading.trailing.equalToSuperview().inset(40)
        }
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    //  MARK: - Public Functions
    
    public func display(item: HeaderCardViewModel) {
        titleLabel.text = item.title
        
        subtitleButton.display(title: item.subtitle, image: item.subtitleButtonImage?.withRenderingMode(.alwaysTemplate))
        subtitleButton.isHidden = ((item.subtitle == nil) && (item.subtitleButtonImage == nil))
        
        backgroundImageView.image = item.backgroundImage
    }
    
    public func configureSubtitleButton(_ c: (CustomButton) -> ()) {
        c(subtitleButton)
    }
}
