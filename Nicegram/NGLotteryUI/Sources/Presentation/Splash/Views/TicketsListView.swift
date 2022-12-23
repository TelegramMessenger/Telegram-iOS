import NGCoreUI
import SnapKit
import UIKit

class TicketsListView: UIView {
    
    //  MARK: - UI Elements

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let ticketsStack = UIStackView()
    
    //  MARK: - Lifecycle
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        layoutUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    //  MARK: - Public Functions

    func display(title: String) {
        titleLabel.text = title
    }
    
    func display(subtitle: String?) {
        subtitleLabel.text = subtitle
        subtitleLabel.isHidden = (subtitle == nil)
    }
    
    func display(tickets: [TicketViewItem]) {
        ticketsStack.removeAllArrangedSubviews()
        for ticket in tickets {
            let view = TicketView()
            view.display(ticket)
            ticketsStack.addArrangedSubview(view)
        }
    }
}

private extension TicketsListView {
    func setupUI() {
        titleLabel.applySectionTitleStyle()
        
        subtitleLabel.applyStyle(
            font: .monospacedDigitSystemFont(ofSize: 14, weight: .regular),
            textColor: .white.withAlphaComponent(0.65),
            textAlignment: .natural,
            numberOfLines: 0,
            adjustFontSize: .no
        )
        
        ticketsStack.applyStyle(
            axis: .vertical,
            spacing: 8,
            alignment: .fill
        )
    }
    
    func layoutUI() {
        let stack = UIStackView(
            arrangedSubviews: [titleLabel, subtitleLabel, ticketsStack],
            axis: .vertical,
            spacing: 16,
            alignment: .fill
        )
        subtitleLabel.isHidden = true

        addSubview(stack)
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}
