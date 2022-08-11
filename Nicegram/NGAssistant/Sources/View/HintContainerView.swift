import UIKit
import SnapKit
import NGExtensions
import NGTheme
import NGLocalization

public class HintView: UIView {
    private let contentView = UIView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let mobileDataLabel = UILabel()
    private let virtualNumberLabel = UILabel()
    private let walletLabel = UILabel()
    private let premiumLabel = UILabel()
    private let supportLabel = UILabel()
    private let footerLabel = UILabel()
    
    let ngTheme: NGThemeColors
    
    init(ngTheme: NGThemeColors) {
        self.ngTheme = ngTheme
    
        super.init(frame: .zero)
        layer.cornerRadius = 16.0
        backgroundColor = .clear
        
        contentView.backgroundColor = ngTheme.backgroundColor
        contentView.layer.cornerRadius = 16
        addSubview(contentView)
        contentView.snp.makeConstraints {
            $0.leading.trailing.bottom.equalToSuperview()
            $0.top.equalToSuperview().inset(16.0)
        }
        titleLabel.textAlignment = .natural
        titleLabel.textColor = ngTheme.reverseTitleColor
        titleLabel.font = .systemFont(ofSize: 24.0, weight: .bold)

        addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.top.equalToSuperview().inset(40.0)
            $0.leading.trailing.equalToSuperview().inset(26.0)
        }

        subtitleLabel.textAlignment = .natural
        subtitleLabel.textColor = ngTheme.subtitleColor
        subtitleLabel.font = .systemFont(ofSize: 14.0, weight: .regular)

        addSubview(subtitleLabel)
        subtitleLabel.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(26.0)
            $0.top.equalTo(titleLabel.snp.bottom).offset(16.0)
        }
        
        let labelsStackView = UIStackView()
        labelsStackView.axis = .vertical
        labelsStackView.alignment = .fill
        labelsStackView.distribution = .fillProportionally
        labelsStackView.spacing = 13
        
        mobileDataLabel.font = .systemFont(ofSize: 14.0)
        mobileDataLabel.textColor = ngTheme.reverseTitleColor
        labelsStackView.addArrangedSubview(mobileDataLabel)
        
        virtualNumberLabel.font = .systemFont(ofSize: 14.0)
        virtualNumberLabel.textColor = ngTheme.reverseTitleColor
        virtualNumberLabel.numberOfLines = 2
        labelsStackView.addArrangedSubview(virtualNumberLabel)
        
        walletLabel.font = .systemFont(ofSize: 14.0)
        walletLabel.textColor = ngTheme.reverseTitleColor
        labelsStackView.addArrangedSubview(walletLabel)

        supportLabel.font = .systemFont(ofSize: 14.0)
        supportLabel.textColor = ngTheme.reverseTitleColor
        labelsStackView.addArrangedSubview(supportLabel)
        
        contentView.addSubview(labelsStackView)
        labelsStackView.snp.makeConstraints {
            $0.leading.equalToSuperview().inset(44.0)
            $0.top.equalTo(subtitleLabel.snp.bottom).offset(16.0)
        }
        
        setupGreenView(centerView: mobileDataLabel)
        setupGreenView(centerView: virtualNumberLabel)
        setupGreenView(centerView: walletLabel)
        setupGreenView(centerView: supportLabel)

        footerLabel.textColor = ngTheme.reverseTitleColor
        footerLabel.font = .systemFont(ofSize: 14.0)
        footerLabel.numberOfLines = 2
        footerLabel.adjustsFontSizeToFitWidth = true
        contentView.addSubview(footerLabel)
        footerLabel.snp.makeConstraints {
            $0.top.equalTo(labelsStackView.snp.bottom).offset(16.0)
            $0.bottom.leading.trailing.equalToSuperview().inset(24.0)
        }
        
        setupComingSoon(centerView: virtualNumberLabel, leadingView: labelsStackView)
        setupComingSoon(centerView: walletLabel, leadingView: labelsStackView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupGreenView(centerView: UIView) {
        let greenMark = UIView()
        greenMark.backgroundColor = .ngGreenTwo
        greenMark.layer.cornerRadius = 4

        contentView.addSubview(greenMark)
        greenMark.snp.makeConstraints {
            $0.height.width.equalTo(8.0)
            $0.trailing.equalTo(centerView.snp.leading).offset(-12.0)
            $0.centerY.equalTo(centerView.snp.centerY)
        }
    }
    
    func setupComingSoon(centerView: UIView, leadingView: UIView) {
        let comingSoonLabel = GradientLabel()
        comingSoonLabel.text = ngLocalized("Nicegram.Assistant.Hint.Comming").uppercased()
        comingSoonLabel.font = .systemFont(ofSize: 12.0, weight: .semibold)
        comingSoonLabel.textAlignment = .right
        comingSoonLabel.adjustsFontSizeToFitWidth = true

        contentView.addSubview(comingSoonLabel)
        comingSoonLabel.snp.makeConstraints {
            $0.height.equalTo(18.0)
            $0.width.equalTo(90.0)
            $0.leading.equalTo(leadingView.snp.trailing).offset(20.0)
            $0.trailing.equalToSuperview().inset(21.0)
            $0.centerY.equalTo(centerView.snp.centerY)
        }
    }
    
    public override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        context.beginPath()
        context.move(to: CGPoint(x: rect.maxX - 53, y: rect.minY + 16.0))
        context.addLine(to: CGPoint(x: rect.maxX - 43, y: rect.minY))
        context.addLine(to: CGPoint(x: (rect.maxX - 33), y: rect.minY + 16.0))
        context.closePath()
        
        context.setFillColor(ngTheme.backgroundColor.cgColor)
        context.fillPath()
    }
    
    public func display(
        titleText: String?,
        subtitleText: String?,
        mobileDataText: String?,
        virtualNumberText: String?,
        walletText: String?,
        supportText: String?,
        footerText: String?
    ) {
        titleLabel.text = ngLocalized("Nicegram.Assistant.Hint.Title")
        subtitleLabel.text = ngLocalized("Nicegram.Assistant.Hint.Subtitle")
        mobileDataLabel.text = ngLocalized("Nicegram.Assistant.Hint.MobileData")
        virtualNumberLabel.text = ngLocalized("Nicegram.Assistant.Hint.VirtualNumber")
        walletLabel.text = ngLocalized("Nicegram.Assistant.Hint.Wallet")
        supportLabel.text = ngLocalized("Nicegram.Assistant.Hint.Support")
        footerLabel.text = ngLocalized("Nicegram.Assistant.Hint.Footer")
    }
}
