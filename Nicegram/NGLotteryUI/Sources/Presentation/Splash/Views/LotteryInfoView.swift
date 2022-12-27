import NGCore
import NGCoreUI
import SnapKit
import UIKit

struct LotteryInfoViewState {
    let jackpot: Money
    let pastDraws: [PastDraw]
    
    struct PastDraw {
        let date: Date
        let winningNumbers: [Int]
    }
}

class LotteryInfoView: UIView {
    
    //  MARK: - UI Elements

    private let drawSection = SplashSectionView()
    private let ticketsSection = SplashSectionView()
    private let winnerSection = SplashSectionView()
    private let pastDrawsSection = TicketsListView()
    private let getTicketButton = CustomButton()
    private let moreInfoButton = CustomButton()
    
    //  MARK: - Handlers
    
    var onGetTicketTap: (() -> Void)? {
        get { getTicketButton.touchUpInside }
        set { getTicketButton.touchUpInside = newValue }
    }
    
    var onMoreInfoTap: (() -> Void)? {
        get { moreInfoButton.touchUpInside }
        set { moreInfoButton.touchUpInside = newValue }
    }
    
    //  MARK: - Lifecycle
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        layoutUI()
        setupData()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    //  MARK: - Public Functions

    func display(state: LotteryInfoViewState) {
        let jackpotString = formatLotteryJackpot(state.jackpot)
        drawSection.display(
            item: SplashSectionViewItem(
                titleImage: nil,
                title: ngLocalized("Lottery.DrawSection.Title"),
                badge: nil,
                description: ngLocalized("Lottery.DrawSection.Desc", with: jackpotString),
                buttonTitle: nil
            )
        )
        
        let tickets = state.pastDraws.map { draw in
            return TicketViewItem(
                numbers: draw.winningNumbers,
                state: .previousWinner(draw.date)
            )
        }
        pastDrawsSection.display(tickets: tickets)
    }
}

private extension LotteryInfoView {
    func setupUI() {
        getTicketButton.applyLotteryActionStyle()
        getTicketButton.display(
            title: ngLocalized("Lottery.GetTicket.Btn"),
            image: nil
        )
        
        moreInfoButton.applyStyle(
            font: .systemFont(ofSize: 14, weight: .semibold),
            foregroundColor: UIColor(hex: "B1B1B1"),
            backgroundColor: .clear,
            cornerRadius: .zero,
            spacing: .zero,
            insets: .zero,
            imagePosition: .leading,
            imageSizeStrategy: .auto
        )
        moreInfoButton.display(
            title: ngLocalized("Lottery.MoreInfo"),
            image: nil
        )
    }
    
    func layoutUI() {
        let stack = UIStackView(
            arrangedSubviews: [
                drawSection, .lotterySectionsSeparator(),
                ticketsSection, .lotterySectionsSeparator(),
                winnerSection, .lotterySectionsSeparator(),
                getTicketButton,
                moreInfoButton, .lotterySectionsSeparator(),
                pastDrawsSection
            ],
            axis: .vertical,
            spacing: 24,
            alignment: .fill
        )
        stack.setCustomSpacing(40, after: moreInfoButton)

        addSubview(stack)
        
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    func setupData() {
        ticketsSection.display(
            item: SplashSectionViewItem(
                titleImage: nil,
                title: ngLocalized("Lottery.HowToGetTicketSection.Title"),
                badge: nil,
                description: ngLocalized("Lottery.HowToGetTicketSection.Desc"),
                buttonTitle: nil
            )
        )
        
        winnerSection.display(
            item: SplashSectionViewItem(
                titleImage: nil,
                title: ngLocalized("Lottery.WinnerSection.Title"),
                badge: nil,
                description: ngLocalized("Lottery.WinnerSection.Desc"),
                buttonTitle: nil
            )
        )
        
        pastDrawsSection.display(title: ngLocalized("Lottery.PastDraws"))
    }
}
