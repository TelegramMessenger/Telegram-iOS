import NGCoreUI
import SnapKit
import UIKit

struct SplashSectionViewItem {
    let titleImage: UIImage?
    let title: String
    let badge: Int?
    let description: String
    let buttonTitle: String?
    let buttonEnabled: Bool
    
    init(titleImage: UIImage?, title: String, badge: Int?, description: String, buttonTitle: String?, buttonEnabled: Bool = true) {
        self.titleImage = titleImage
        self.title = title
        self.badge = badge
        self.description = description
        self.buttonTitle = buttonTitle
        self.buttonEnabled = buttonEnabled
    }
}

class SplashSectionView: UIView {
    
    //  MARK: - UI Elements

    private let titleImageView = UIImageView()
    private let titleLabel = UILabel()
    private let badgeLabel = UILabel()
    private let textView = UITextView()
    private let button = CustomButton()
    
    //  MARK: - Handlers
    
    var onButtonTap: (() -> Void)? {
        get { button.touchUpInside }
        set { button.touchUpInside = newValue }
    }
    
    //  MARK: - Lifecycle
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    //  MARK: - Public Functions

    func display(item: SplashSectionViewItem) {
        titleImageView.image = item.titleImage
        titleImageView.isHidden = (item.titleImage == nil)
        
        titleLabel.text = item.title
        
        if let badge = item.badge {
            badgeLabel.text = "\(badge)"
            badgeLabel.isHidden = false
        } else {
            badgeLabel.isHidden = true
        }
        
        textView.attributedText = parseMarkdownIntoAttributedString(
            item.description,
            attributes: .plain(
                font: .systemFont(ofSize: 14, weight: .regular),
                textColor: .white
            ).withLink(
                additionalAttributes: [
                    .underlineStyle: NSUnderlineStyle.single.rawValue
                ]
            )
        )
        
        button.display(title: item.buttonTitle, image: nil)
        button.isHidden = (item.buttonTitle == nil)
        button.isEnabled = item.buttonEnabled
    }
}

private extension SplashSectionView {
    func setupUI() {
        titleImageView.contentMode = .scaleAspectFit
        
        titleLabel.applySectionTitleStyle()
        
        badgeLabel.applyStyle(
            font: .systemFont(ofSize: 16, weight: .bold),
            textColor: .lotteryBackgroundTint,
            textAlignment: .natural,
            numberOfLines: 1,
            adjustFontSize: .no
        )
        
        textView.applyPlainStyle()
        
        button.applyLotteryActionStyle()
        
        let topStack = UIStackView(
            arrangedSubviews: [titleImageView, titleLabel, badgeLabel],
            axis: .horizontal,
            spacing: 8,
            alignment: .center
        )
        titleImageView.snp.makeConstraints { make in
            make.size.equalTo(29)
        }
        badgeLabel.snp.contentHuggingHorizontalPriority = 761
        badgeLabel.snp.contentCompressionResistanceHorizontalPriority = 762
        
        let stack = UIStackView(
            arrangedSubviews: [topStack, textView, button],
            axis: .vertical,
            spacing: 16,
            alignment: .fill
        )

        addSubview(stack)
        
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}
