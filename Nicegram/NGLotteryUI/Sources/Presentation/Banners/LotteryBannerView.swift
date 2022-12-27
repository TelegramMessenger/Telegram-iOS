import NGCore
import NGCoreUI
import SnapKit
import UIKit

public class LotteryBannerView: UIControl {
    
    //  MARK: - UI Elements

    private let backgroundImageView = UIImageView()
    private let logoImageView = UIImageView()
    private let topLabel = UILabel()
    private let moneyLabel = UILabel()
    private let botLabel = UILabel()
    private let rightImageView = UIImageView()
    private let closeButton = CustomButton()
    
    //  MARK: - Handlers
    
    public var onTap: (() -> Void)?
    public var onClose: (() -> Void)? {
        get { closeButton.touchUpInside }
        set { closeButton.touchUpInside = newValue }
    }
    
    //  MARK: - Lifecycle
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        setupUI()
        
        addTarget(self, action: #selector(tapped), for: .touchUpInside)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if closeButton.point(inside: self.convert(point, to: closeButton), with: event) {
            return closeButton
        } else if self.point(inside: point, with: event) {
            return self
        } else {
            return super.hitTest(point, with: event)
        }
    }
    
    //  MARK: - Public Functions

    public func display(jackpot: Money) {
        moneyLabel.text = formatLotteryJackpot(jackpot)
    }
    
    public func setCloseButton(hidden: Bool) {
        closeButton.isHidden = hidden
    }
}

private extension LotteryBannerView {
    func setupUI() {
        layer.applyShadow(color: .black, alpha: 0.25, x: 0, y: 25, blur: 50)
        
        backgroundImageView.contentMode = .scaleAspectFill
        backgroundImageView.setIntrinsicContentSizeMinimumPriority()
        backgroundImageView.image = UIImage(named: "ng.lottery.banner.background")
        backgroundImageView.layer.cornerRadius = 8
        backgroundImageView.clipsToBounds = true
        
        logoImageView.contentMode = .scaleAspectFit
        logoImageView.image = UIImage(named: "ng.lottery.logo")
        
        topLabel.applyStyle(
            font: .systemFont(ofSize: 18, weight: .bold),
            textColor: .lotteryBackgroundTint,
            textAlignment: .natural,
            numberOfLines: 1,
            adjustFontSize: .no
        )
        topLabel.text = ngLocalized("Lottery.Banner.Title").uppercased()
        
        moneyLabel.applyStyle(
            font: .systemFont(ofSize: 35, weight: .heavy),
            textColor: .white,
            textAlignment: .natural,
            numberOfLines: 1,
            adjustFontSize: .yes(0.8)
        )
        
        botLabel.applyStyle(
            font: .systemFont(ofSize: 14, weight: .bold),
            textColor: .lotteryBackgroundTint,
            textAlignment: .natural,
            numberOfLines: 1,
            adjustFontSize: .no
        )
        botLabel.text = ngLocalized("Lottery.Banner.Desc").uppercased()
        
        rightImageView.applyStyle(
            contentMode: .scaleAspectFit,
            tintColor: .white,
            cornerRadius: .zero
        )
        rightImageView.image = UIImage(named: "ng.item.arrow")?.withRenderingMode(.alwaysTemplate)
        
        closeButton.imageView.display(
            image: UIImage(named: "ng.lottery.banner.close"),
            backgroundColor: nil
        )

        let leadingStack = UIStackView(
            arrangedSubviews: [logoImageView, topLabel, moneyLabel, botLabel],
            axis: .vertical,
            spacing: 4,
            alignment: .leading
        )
        leadingStack.setCustomSpacing(14, after: logoImageView)
        logoImageView.snp.makeConstraints { make in
            make.width.equalTo(200)
        }
        
        let stack = UIStackView(
            arrangedSubviews: [leadingStack, rightImageView],
            axis: .horizontal,
            spacing: 15,
            alignment: .center
        )
        rightImageView.snp.makeConstraints { make in
            make.size.equalTo(18)
        }

        addSubview(backgroundImageView)
        addSubview(stack)
        addSubview(closeButton)
        
        backgroundImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(12)
        }
        
        closeButton.snp.makeConstraints { make in
            make.centerX.equalTo(self.snp.trailing)
            make.centerY.equalTo(self.snp.top)
        }
    }
    
    @objc func tapped() {
        onTap?()
    }
}
