import UIKit
import SnapKit
import NGButton
import NGCustomViews
import NGExtensions
import NGTheme

open class DescriptionsSectionView: UIView {
    
    //  MARK: - UI Elements
    
    private let ngTheme: NGThemeColors
    
    private let titleLabel = UILabel()
    private let button = ActionButton()
    private let topStack = UIStackView()
    private let itemsStack = UIStackView()
    
    //  MARK: - Public Properties

    public var itemsSpacing: CGFloat {
        get { itemsStack.spacing }
        set { itemsStack.spacing = newValue }
    }
    
    public var buttonTouchUpInside: (() -> ())? {
        get { button.touchUpInside }
        set { button.touchUpInside = newValue }
    }
    
    public var configureDescriptionItemView: ((DescriptionItemView) -> ())?
    
    //  MARK: - Lifecycle
    
    public init(ngTheme: NGThemeColors) {
        self.ngTheme = ngTheme
        
        super.init(frame: .zero)
        
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textColor = ngTheme.reverseTitleColor
        titleLabel.numberOfLines = 0
        
        button.titleLabel?.font = .systemFont(ofSize: 12, weight: .medium)
        button.setTitleColor(.ngActiveButton, for: .normal)
        button.setTitleColor(.ngActiveButton.withAlphaComponent(0.7), for: .highlighted)
        
        [titleLabel, button].forEach({ topStack.addArrangedSubview($0) })
        topStack.spacing = 15
        topStack.alignment = .center
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        
        itemsStack.axis = .vertical
        itemsStack.spacing = 24
        
        let stack = UIStackView(arrangedSubviews: [topStack, itemsStack])
        stack.axis = .vertical
        stack.spacing = 32
        
        addSubview(stack)
        
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    //  MARK: - Public Functions
    
    public func display(item: DescriptionsSectionViewModel) {
        display(title: item.title)
        display(buttonTitle: item.buttonTitle)
        display(items: item.items)
        
        topStack.isHidden = ((item.title == nil) && (item.buttonTitle == nil))
    }
    
    public func display(title: String?) {
        titleLabel.text = title
        titleLabel.isHidden = (title == nil)
    }
    
    public func display(buttonTitle: String?) {
        button.setTitle(buttonTitle, for: .normal)
        button.isHidden = (buttonTitle == nil)
    }

    public func display(items: [DescriptionItemViewModel]) {
        itemsStack.removeAllArrangedSubviews()
        items.forEach { item in
            let view = DescriptionItemView()
            view.ngTheme = ngTheme
            configureDescriptionItemView?(view)
            view.display(item: item)
            itemsStack.addArrangedSubview(view)
        }
        itemsStack.isHidden = items.isEmpty
    }
}
