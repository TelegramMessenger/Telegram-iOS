import UIKit
import SnapKit
import NGExtensions
import NGTheme

public struct PickerTitleViewModel: PickerItem {
    public let id: Int
    public let title: String
    public var isSelected: Bool = false
    
    public init(id: Int, title: String) {
        self.id = id
        self.title = title
    }
}

open class NGPickerTitleCell: UICollectionViewCell {
    
    //  MARK: - UI Elements
    
    public var ngTheme: NGThemeColors!

    private let titleLabel = UILabel()
    
    //  MARK: - Lifecycle
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        
        contentView.layer.cornerRadius = 8
        
        titleLabel.font = .systemFont(ofSize: 14, weight: .regular)
        titleLabel.textAlignment = .center
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.1
        
        contentView.addSubview(titleLabel)
        
        titleLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview().inset(8)
        }
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    //  MARK: - Public Functions

    public func display(item: PickerTitleViewModel) {
        titleLabel.text = item.title
        titleLabel.textColor = item.isSelected ? .white : ngTheme.reverseTitleColor
        contentView.backgroundColor = item.isSelected ? .ngActiveButton : ngTheme.backgroundColor
    }
}
