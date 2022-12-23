import NGCore
import NGCoreUI
import SnapKit
import UIKit

class HeaderView: UIView {
    
    //  MARK: - UI Elements

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let moneyLabel = UILabel()
    
    //  MARK: - Lifecycle
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    //  MARK: - Public Functions

    func display(jackpot: Money) {
        moneyLabel.text = MoneyFormatter().format(jackpot, minimumFractionDigits: 0)
    }
}

private extension HeaderView {
    func setupUI() {
        titleLabel.applyStyle(
            font: .systemFont(ofSize: 24, weight: .bold),
            textColor: .white,
            textAlignment: .center,
            numberOfLines: 0,
            adjustFontSize: .no
        )
        titleLabel.text = ngLocalized("Lottery.Header.Title")
        
        subtitleLabel.applyStyle(
            font: .systemFont(ofSize: 16, weight: .regular),
            textColor: .white,
            textAlignment: .center,
            numberOfLines: 0,
            adjustFontSize: .no
        )
        subtitleLabel.text = ngLocalized("Lottery.Header.Desc")
        
        moneyLabel.applyStyle(
            font: .systemFont(ofSize: 32, weight: .heavy),
            textColor: .white,
            textAlignment: .center,
            numberOfLines: 1,
            adjustFontSize: .yes(0.5)
        )
        moneyLabel.layer.applyShadow(color: .white, alpha: 0.5, x: 0, y: 0, blur: 15)
        
        let stack = UIStackView(
            arrangedSubviews: [titleLabel, subtitleLabel, moneyLabel],
            axis: .vertical,
            spacing: 12,
            alignment: .center
        )
        stack.setCustomSpacing(4, after: subtitleLabel)

        addSubview(stack)
        
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}
