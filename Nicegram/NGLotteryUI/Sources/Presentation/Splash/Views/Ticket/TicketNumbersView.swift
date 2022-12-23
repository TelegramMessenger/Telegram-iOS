import SnapKit
import UIKit

struct TicketNumberViewItem {
    let number: Int
    let overlayImage: UIImage?
}

class TicketNumbersView: UIView {
    
    //  MARK: - UI Elements

    private let firstNumbersStack = UIStackView()
    private let lastNumberView = NumberView()
    
    //  MARK: - Lifecycle
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    //  MARK: - Public Functions

    func display(items: [TicketNumberViewItem]) {
        firstNumbersStack.removeAllArrangedSubviews()
        for item in items.dropLast(1) {
            let view = NumberView()
            view.display(item: item)
            firstNumbersStack.addArrangedSubview(view)
        }
        
        if let lastItem = items.last {
            lastNumberView.display(item: lastItem)
        }
    }
}

private extension TicketNumbersView {
    func setupUI() {
        firstNumbersStack.applyStyle(
            axis: .horizontal,
            spacing: 5,
            alignment: .center
        )
        
        let firstNumbersContainer = UIView()
        
        let firstNumbersBack = makeFirstNumbersBackground()
        firstNumbersContainer.addSubview(firstNumbersBack)
        firstNumbersBack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        firstNumbersContainer.addSubview(firstNumbersStack)
        firstNumbersStack.snp.makeConstraints { make in
            make.top.trailing.bottom.equalToSuperview().inset(2)
            make.leading.equalToSuperview().inset(6)
        }
        
        let lastNumberContainer = UIView()
        
        let lastNumberBack = makeLastNumberBackground()
        lastNumberContainer.addSubview(lastNumberBack)
        lastNumberBack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        lastNumberContainer.addSubview(lastNumberView)
        lastNumberView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(2)
        }
        
        let stack = UIStackView(
            arrangedSubviews: [firstNumbersContainer, lastNumberContainer],
            axis: .horizontal,
            spacing: 2,
            alignment: .center
        )

        addSubview(stack)
        
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    func makeFirstNumbersBackground() -> UIView {
        let imageView = UIImageView()
        imageView.setIntrinsicContentSizeMinimumPriority()
        imageView.image = UIImage(named: "ng.lottery.ticket.background.yellow")
        return imageView
    }
    
    func makeLastNumberBackground() -> UIView {
        let imageView = UIImageView()
        imageView.setIntrinsicContentSizeMinimumPriority()
        imageView.image = UIImage(named: "ng.lottery.ticket.background.white")
        return imageView
    }
}

private class NumberView: UIView {
    
    //  MARK: - UI Elements

    private let label = UILabel()
    private let overlayImageView = UIImageView()
    
    //  MARK: - Lifecycle
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        label.applyStyle(
            font: .monospacedDigitSystemFont(ofSize: 15, weight: .semibold),
            textColor: .lotteryForegroundTint,
            textAlignment: .center,
            numberOfLines: 1,
            adjustFontSize: .no
        )
        
        overlayImageView.applyStyle(
            contentMode: .scaleAspectFit,
            tintColor: nil,
            cornerRadius: .zero
        )
        overlayImageView.setIntrinsicContentSizeMinimumPriority()

        addSubview(label)
        label.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        addSubview(overlayImageView)
        overlayImageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.trailing.greaterThanOrEqualToSuperview()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    //  MARK: - Public Functions

    func display(item: TicketNumberViewItem) {
        label.text = String(format: "%02d", item.number)
        overlayImageView.image = item.overlayImage
        overlayImageView.isHidden = (item.overlayImage == nil)
    }
}
