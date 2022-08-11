import UIKit
import NGExtensions
import NGTheme

open class NGAlertDefaultContentView: UIView {
    private let titleLabel = UILabel()
    private let imageView = UIImageView()
    private let subtitleLabel = UILabel()
    private let descriptionLabel = UILabel()
    
    public init(ngTheme: NGThemeColors) {
        super.init(frame: .zero)
        
        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        titleLabel.textColor = ngTheme.reverseTitleColor
        titleLabel.textAlignment = .center
        
        imageView.contentMode = .scaleAspectFit
        
        subtitleLabel.font = .systemFont(ofSize: 16, weight: .regular)
        subtitleLabel.textColor = ngTheme.reverseTitleColor
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        
        descriptionLabel.font = .systemFont(ofSize: 16, weight: .regular)
        descriptionLabel.textColor = .ngSubtitle
        descriptionLabel.textAlignment = .center
        descriptionLabel.numberOfLines = 0
        
        let stack = UIStackView(arrangedSubviews: [titleLabel, imageView, subtitleLabel, descriptionLabel])
        stack.axis = .vertical
        stack.spacing = 24
        stack.alignment = .center
        
        addSubview(stack)
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 48, left: 16, bottom: 48, right: 16))
        }
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func display(title: NSAttributedString?, image: UIImage?, subtitle: NSAttributedString?, description: NSAttributedString?) {
        titleLabel.attributedText = title
        titleLabel.isHidden = (title == nil)
        
        imageView.image = image
        imageView.isHidden = (image == nil)
        
        subtitleLabel.attributedText = subtitle
        subtitleLabel.isHidden = (subtitle == nil)
        
        descriptionLabel.attributedText = description
        descriptionLabel.isHidden = (description == nil)
    }
}
