import UIKit
import SnapKit
import NGButton
import NGExtensions
import NGTheme

class EsimSetupStepView: UIView {
    
    //  MARK: - UI Elements

    private let ngTheme: NGThemeColors
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let button = CustomButton()
    private let itemsStack = UIStackView()
    
    //  MARK: - Public Properties

    var buttonTouchUpInside: (() -> ())? {
        get { button.touchUpInside }
        set { button.touchUpInside = newValue }
    }
    
    //  MARK: - Lifecycle
    
    init(ngTheme: NGThemeColors) {
        self.ngTheme = ngTheme
        
        super.init(frame: .zero)
        
        backgroundColor = ngTheme.cardColor
        layer.cornerRadius = 12
        
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textColor = ngTheme.reverseTitleColor
        titleLabel.numberOfLines = 0
        
        subtitleLabel.font = .systemFont(ofSize: 16, weight: .regular)
        subtitleLabel.textColor = ngTheme.subtitleColor
        subtitleLabel.numberOfLines = 0
        
        button.foregroundColor = .white
        button.backgroundColor = .ngActiveButton
        button.layer.cornerRadius = 12
        button.imagePosition = .top
        button.spacing = 11
        button.insets = UIEdgeInsets(top: 23, left: 16, bottom: 16, right: 16)
        button.configureTitleLabel { label in
            label.font = .systemFont(ofSize: 12, weight: .semibold)
        }
        
        itemsStack.axis = .vertical
        itemsStack.spacing = 22
        
        let titlesStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        titlesStack.axis = .vertical
        titlesStack.spacing = 12
        
        let headerStack = UIStackView(arrangedSubviews: [titlesStack, button])
        headerStack.spacing = 15
        headerStack.alignment = .top
        
        let stack = UIStackView(arrangedSubviews: [headerStack, itemsStack])
        stack.axis = .vertical
        stack.spacing = 32
        
        button.snp.contentHuggingHorizontalPriority = 251
        button.snp.contentCompressionResistanceHorizontalPriority = 751
        
        addSubview(stack)
        
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(16)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    //  MARK: - Public Functions
    
    func display(item: EsimSetupStepViewModel) {
        titleLabel.text = item.title
        subtitleLabel.text = item.subtitle
        
        button.display(title: item.buttonTitle, image: item.buttonImage?.withRenderingMode(.alwaysTemplate))
        button.isHidden = ((item.buttonTitle == nil) && (item.buttonImage == nil))
    }
    
    func display(descriptionViews: [UIView]) {
        itemsStack.removeAllArrangedSubviews()
        descriptionViews.forEach({
            itemsStack.addArrangedSubview($0)
            itemsStack.addArrangedSubview(.separator(ngTheme: ngTheme))
        })
        if let lastSeparator = itemsStack.arrangedSubviews.last {
            itemsStack.removeArrangedSubview(lastSeparator)
        }
    }
}

private extension NGThemeColors {
    var subtitleColor: UIColor {
        switch theme {
        case .white: return .ngBodyTwo
        case .dark: return .ngBodyThree
        }
    }
}
