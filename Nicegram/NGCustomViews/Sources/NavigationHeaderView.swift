import UIKit
import SnapKit
import NGButton
import NGExtensions
import NGTheme

open class NavigationHeaderView: UIView {
    
    //  MARK: - UI Elements
    
    private let titleLabel = UILabel()
    private let titleButton = CustomButton()
    
    //  MARK: - Public Properties
    
    public var onButtonTap: (() -> ())? {
        get { titleButton.touchUpInside }
        set { titleButton.touchUpInside = newValue }
    }

    
    //  MARK: - Lifecycle
    
    public init(ngTheme: NGThemeColors) {
        super.init(frame: .zero)
        
        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        titleLabel.textColor = ngTheme.reverseTitleColor
        titleLabel.numberOfLines = 0
        
        titleButton.backgroundColor = ngTheme.cardColor
        titleButton.foregroundColor = ngTheme.reverseTitleColor
        titleButton.layer.cornerRadius = 12
        
        let titleStack = UIStackView(arrangedSubviews: [titleLabel, titleButton])
        titleStack.spacing = 15
        titleStack.alignment = .center
        titleButton.snp.makeConstraints { make in
            make.width.height.equalTo(56)
        }
        
        let stack = UIStackView(arrangedSubviews: [titleStack, .separator(color: .ngLine.withAlphaComponent(0.4))])
        stack.axis = .vertical
        stack.spacing = 24
        
        addSubview(stack)
        
        stack.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(safeArea.top).inset(20)
            make.bottom.equalToSuperview()
        }
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    //  MARK: - Public Functions
    
    public func display(title: String?, buttonImage: UIImage?) {
        titleLabel.text = title
        titleLabel.isHidden = (title == nil)
        
        titleButton.display(title: nil, image: buttonImage?.withRenderingMode(.alwaysTemplate))
        titleButton.isHidden = (buttonImage == nil)
    }
    
    public func configureTitleButton(_ c: (CustomButton) -> ()) {
        c(titleButton)
    }
}
