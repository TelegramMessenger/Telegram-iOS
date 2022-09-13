import UIKit
import NGExtensions
import NGImageContainer

struct PremiumFeatureViewModel {
    let image: UIImage?
    let title: String
    let description: String
}

class PremiumFeatureView: UIView {
    
    //  MARK: - UI Elements

    private let imageView = ImageContainer()
    private let titleLabel = UILabel()
    private let descriptionLabel = UILabel()
    
    //  MARK: - Lifecycle
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        imageView.tintColor = .white
        imageView.backgroundColor = .ngBackground
        imageView.imageSizeStrategy = .size(CGSize(width: 19, height: 19))
        imageView.layer.cornerRadius = 6
        
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 0
        
        descriptionLabel.font = .systemFont(ofSize: 14, weight: .regular)
        descriptionLabel.textColor = .ngSubtitle
        descriptionLabel.numberOfLines = 0
        
        let titlesStack = UIStackView(arrangedSubviews: [titleLabel, descriptionLabel])
        titlesStack.axis = .vertical
        
        let stack = UIStackView(arrangedSubviews: [imageView, titlesStack])
        stack.spacing = 12
        stack.alignment = .top
        
        addSubview(stack)
        
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        imageView.snp.makeConstraints { make in
            make.width.equalTo(29)
            make.height.equalTo(58)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    //  MARK: - Public Functions

    func display(_ item: PremiumFeatureViewModel) {
        imageView.display(image: item.image, backgroundColor: .ngBackground)
        titleLabel.text = item.title
        descriptionLabel.text = item.description
    }
}
