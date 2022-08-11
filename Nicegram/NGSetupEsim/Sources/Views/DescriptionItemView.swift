import UIKit
import SnapKit
import NGButton
import NGExtensions
import NGTheme

class DescriptionItemView: UIControl {
    
    //  MARK: - UI Elements

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let button = CustomButton()
    private let switchView = UISwitch()
    
    //  MARK: - Public Properties
    
    var onTap: (() -> ())?
    
    //  MARK: - Lifecycle
    
    init(ngTheme: NGThemeColors) {
        super.init(frame: .zero)
        
        addTarget(self, action: #selector(tapped), for: .touchUpInside)
        
        titleLabel.font = .systemFont(ofSize: 14, weight: .regular)
        titleLabel.textColor = .ngBodyTwo
        
        subtitleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        subtitleLabel.textColor = ngTheme.reverseTitleColor
        subtitleLabel.numberOfLines = 2
        
        button.imageSizeStrategy = .size(CGSize(width: 24, height: 24))
        button.foregroundColor = .ngActiveButton
        
        switchView.onTintColor = .ngActiveButton
        switchView.thumbTintColor = .white
        switchView.isOn = true
        
        let stack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel.padding(), button, switchView])
        stack.spacing = 15
        stack.alignment = .center
        stack.isUserInteractionEnabled = false
        
        switchView.snp.contentHuggingHorizontalPriority = 250
        button.snp.contentHuggingHorizontalPriority = 249
        subtitleLabel.snp.contentHuggingHorizontalPriority = 248
        titleLabel.snp.contentHuggingHorizontalPriority = 247
        
        switchView.snp.contentCompressionResistanceHorizontalPriority = 750
        button.snp.contentCompressionResistanceHorizontalPriority = 749
        titleLabel.snp.contentCompressionResistanceHorizontalPriority = 748
        subtitleLabel.snp.contentCompressionResistanceHorizontalPriority = 747
        
        addSubview(stack)
        
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func display(item: DescriptionItemViewModel) {
        titleLabel.text = item.title
        
        subtitleLabel.text = item.subtitle
        subtitleLabel.isHidden = (item.subtitle == nil)
        
        button.display(title: nil, image: item.buttonImage?.withRenderingMode(.alwaysTemplate))
        button.isHidden = (item.buttonImage == nil)
        
        switchView.isHidden = !item.showSwitch
    }
}

private extension DescriptionItemView {
    @objc func tapped() {
        onTap?()
    }
}
