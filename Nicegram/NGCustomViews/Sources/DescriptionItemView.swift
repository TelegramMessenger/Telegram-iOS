import UIKit
import SnapKit
import NGExtensions
import NGImageContainer
import NGTheme

public struct DescriptionItemViewModel {
    let image: UIImage?
    let imageBackgroundColor: UIColor
    let title: String
    let subtitle: String?
    let description: String?
    
    public init(image: UIImage?, imageBackgroundColor: UIColor, title: String, subtitle: String?, description: String?) {
        self.image = image
        self.imageBackgroundColor = imageBackgroundColor
        self.title = title
        self.subtitle = subtitle
        self.description = description
    }
}

extension DescriptionItemCell: ReuseIdentifiable {}

open class DescriptionItemCell: UITableViewCell {
    
    //  MARK: - UI Elements

    private let mainView = DescriptionItemView()
    
    //  MARK: - Public Properties
    
    public var ngTheme: NGThemeColors? {
        get { mainView.ngTheme }
        set { mainView.ngTheme = newValue }
    }

    public var imageContainerSize: CGSize {
        get { return mainView.imageContainerSize }
        set { mainView.imageContainerSize = newValue }
    }
    
    public var imageSizeStrategy: ImageContainer.ImageSizeStrategy {
        get { return mainView.imageSizeStrategy }
        set { mainView.imageSizeStrategy = newValue }
    }
    
    //  MARK: - Lifecycle
    
    public override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        selectionStyle = .none
        backgroundColor = .clear
        
        contentView.addSubview(mainView)
        mainView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 12, left: 17, bottom: 12, right: 17))
        }
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    //  MARK: - Public Functions

    public func display(item: DescriptionItemViewModel) {
        mainView.display(item: item)
    }
    
    public func configureTitleImageView(_ c: (UIImageView) -> ()) {
        mainView.configureTitleImageView(c)
    }
}

open class DescriptionItemView: UIView {
    
    //  MARK: - UI Elements
    
    public var ngTheme: NGThemeColors? {
        didSet {
            setupUI()
        }
    }

    private let titleImageView = ImageContainer()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let descriptionLabel = UILabel()
    private let stack = UIStackView()
    
    //  MARK: - Public Properties

    public var imageContainerSize = CGSize(width: 24, height: 24) {
        didSet {
            titleImageView.snp.remakeConstraints { make in
                make.size.equalTo(imageContainerSize)
            }
        }
    }
    
    public var imageSizeStrategy: ImageContainer.ImageSizeStrategy {
        get { return titleImageView.imageSizeStrategy }
        set { titleImageView.imageSizeStrategy = newValue }
    }
    
    //  MARK: - Lifecycle
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        
        setupUI()
        layoutUI()
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    //  MARK: - Public Functions

    public func display(item: DescriptionItemViewModel) {
        titleImageView.display(image: item.image, backgroundColor: item.imageBackgroundColor)
        
        titleLabel.text = item.title
        
        let subtitle = item.subtitle
        let shouldShowSubtitle = (subtitle != nil)
        subtitleLabel.text = subtitle
        subtitleLabel.isHidden = !shouldShowSubtitle
        stack.alignment = shouldShowSubtitle ? .top : .center
        
        descriptionLabel.text = item.description
        descriptionLabel.isHidden = (item.description == nil)
    }
    
    public func configureTitleImageView(_ c: (UIImageView) -> ()) {
        titleImageView.configureImageView(c)
    }
    
    //  MARK: - Private Functions

    private func setupUI() {
        titleImageView.tintColor = .white
        titleImageView.layer.cornerRadius = 6
        titleImageView.clipsToBounds = true
        
        titleLabel.font = .systemFont(ofSize: 16, weight: .regular)
        titleLabel.textColor = ngTheme?.reverseTitleColor
        titleLabel.numberOfLines = 0
        
        subtitleLabel.font = .systemFont(ofSize: 12, weight: .regular)
        subtitleLabel.textColor = .ngSubtitle
        
        descriptionLabel.font = .systemFont(ofSize: 16, weight: .regular)
        descriptionLabel.textColor = .ngSubtitle
    }
    
    private func layoutUI() {
        let titlesStack = UIStackView(arrangedSubviews: [subtitleLabel, titleLabel])
        titlesStack.axis = .vertical
        titlesStack.spacing = 4
        
        [titleImageView, titlesStack, descriptionLabel].forEach({ stack.addArrangedSubview($0) })
        stack.spacing = 12
        descriptionLabel.setContentHuggingPriority(.required, for: .horizontal)
        descriptionLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        
        addSubview(stack)
        
        titleImageView.snp.makeConstraints { make in
            make.size.equalTo(imageContainerSize)
        }
        
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}
