import NGCoreUI
import SnapKit
import UIKit

struct WaysToGetTicketViewState {
    let premium: PremiumSectionViewState
}

enum PremiumSectionViewState {
    case subscribe
    case getTicket
    case alreadyReceived(nextDate: Date)
}

class WaysToGetTicketView: UIView {
    
    //  MARK: - UI Elements

    private let referralSection = SplashSectionView()
    private let premiumSection = SplashSectionView()
    
    //  MARK: - Handlers
    
    var onSubscribeTap: (() -> Void)?
    var onGetTicketForPremiumTap: (() -> Void)?
    var onGetTicketForReferralTap: (() -> Void)? {
        get { referralSection.onButtonTap }
        set { referralSection.onButtonTap = newValue }
    }
    
    //  MARK: - Lifecycle
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    //  MARK: - Public Functions

    func display(state: WaysToGetTicketViewState) {
        switch state.premium {
        case .subscribe:
            premiumSection.display(
                item: .premium(
                    description: ngLocalized("Lottery.PremiumSection.Subscribe.Desc"),
                    buttonTitle: ngLocalized("Lottery.PremiumSection.Subscribe.Btn")
                )
            )
            premiumSection.onButtonTap = onSubscribeTap
        case .getTicket:
            premiumSection.display(
                item: .premium(
                    description: ngLocalized("Lottery.PremiumSection.Get.Desc"),
                    buttonTitle: ngLocalized("Lottery.PremiumSection.Get.Btn")
                )
            )
            premiumSection.onButtonTap = onGetTicketForPremiumTap
        case .alreadyReceived(let nextDate):
            premiumSection.display(
                item: .premium(
                    description: ngLocalized("Lottery.PremiumSection.Wait.Desc", with: formatNextPremiumDate(nextDate)),
                    buttonTitle: ngLocalized("Lottery.PremiumSection.Wait.Btn"),
                    buttonEnabled: false
                )
            )
        }
    }
}

private extension WaysToGetTicketView {
    func formatNextPremiumDate(_ date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd MMMM yyyy"
        return dateFormatter.string(from: date)
    }
}

private extension WaysToGetTicketView {
    func setupUI() {
        referralSection.display(
            item: SplashSectionViewItem(
                titleImage: UIImage(named: "ng.lottery.referral"),
                title: ngLocalized("Lottery.ReferralSection.Title"),
                badge: nil,
                description: ngLocalized("Lottery.ReferralSection.Desc"),
                buttonTitle: ngLocalized("Lottery.ReferralSection.Btn")
            )
        )
        
        let stack = UIStackView(
            arrangedSubviews: [
                referralSection,
                .orSeparator(),
                premiumSection
            ],
            axis: .vertical,
            spacing: 24,
            alignment: .fill
        )
        
        addSubview(stack)
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}

private extension UIView {
    static func orSeparator() -> UIView {
        let leadingSeparator = UIView.lotterySectionsSeparator()
        let trailingSeparator = UIView.lotterySectionsSeparator()
        
        let label = UILabel()
        label.applyStyle(
            font: .systemFont(ofSize: 14, weight: .semibold),
            textColor: .white,
            textAlignment: .center,
            numberOfLines: 1,
            adjustFontSize: .no
        )
        label.text = ngLocalized("Lottery.Or")
        
        let stack = UIStackView(
            arrangedSubviews: [leadingSeparator, label, trailingSeparator],
            axis: .horizontal,
            spacing: 10,
            alignment: .center
        )
        trailingSeparator.snp.makeConstraints { make in
            make.width.equalTo(leadingSeparator)
        }

        return stack
    }
}

private extension SplashSectionViewItem {
    static func premium(description: String, buttonTitle: String, buttonEnabled: Bool = true) -> SplashSectionViewItem {
        return SplashSectionViewItem(
            titleImage: UIImage(named: "ng.lottery.premium"),
            title: ngLocalized("Lottery.PremiumSection.Title"),
            badge: nil,
            description: description,
            buttonTitle: buttonTitle,
            buttonEnabled: buttonEnabled
        )
    }
}
