import NGCoreUI
import NGTheme
import SnapKit
import UIKit

public class ReferralBannerView: UIView {
    
    //  MARK: - UI Elements

    private let descLabel = UILabel()
    private let inviteButton = CustomButton()
    
    //  MARK: - Handlers

    public var onInviteTap: (() -> Void)? {
        get { inviteButton.touchUpInside }
        set { inviteButton.touchUpInside = newValue }
    }
    
    //  MARK: - Lifecycle
    
    public init(ngTheme: NGThemeColors) {
        super.init(frame: .zero)
        setupUI(ngTheme: ngTheme)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private extension ReferralBannerView {
    func setupUI(ngTheme: NGThemeColors) {
        descLabel.applyStyle(
            font: .systemFont(ofSize: 14, weight: .regular),
            textColor: ngTheme.reverseTitleColor,
            textAlignment: .natural,
            numberOfLines: 0,
            adjustFontSize: .no
        )
        descLabel.attributedText = parseMarkdownIntoAttributedString(
            ngLocalized("Assistant.Referral.Desc"),
            attributes: .plain(
                font: .systemFont(ofSize: 14, weight: .regular),
                textColor: ngTheme.reverseTitleColor
            ).withBold(
                textColor: UIColor(hex: "BE55ED")
            )
        )
        
        inviteButton.applyStyle(
            font: .systemFont(ofSize: 12, weight: .regular),
            foregroundColor: .white,
            backgroundColor: .clear,
            cornerRadius: 4,
            spacing: .zero,
            insets: UIEdgeInsets(top: 9, left: 12, bottom: 9, right: 12),
            imagePosition: .leading,
            imageSizeStrategy: .auto
        )
        inviteButton.setGradientBackground(
            colors: .defaultGradient,
            startPoint: CGPoint(x: 0.5, y: 0),
            endPoint: CGPoint(x: 0.5, y: 1)
        )
        inviteButton.display(
            title: ngLocalized("Assistant.Referral.Btn"),
            image: nil
        )
        
        let stack = UIStackView(
            arrangedSubviews: [descLabel, inviteButton],
            axis: .horizontal,
            spacing: 10,
            alignment: .center
        )
        inviteButton.snp.makeConstraints { make in
            make.width.greaterThanOrEqualTo(90)
        }
        descLabel.snp.contentHuggingHorizontalPriority = 249
        descLabel.snp.contentCompressionResistanceHorizontalPriority = 749

        addSubview(stack)
        
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}
