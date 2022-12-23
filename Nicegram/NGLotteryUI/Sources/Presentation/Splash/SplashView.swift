import Combine
import NGCore
import NGCoreUI
import SnapKit
import UIKit


struct SplashViewState: ViewState {
    var tab: Tab = .info
    var nextDraw: NextDraw = NextDraw()
    var lastDraw: PastDraw? = nil
    var pastDraws: [PastDraw] = []
    var userActiveTickets: [UserActiveTicket] = []
    var availableUserTicketsCount: Int = 0
    var premiumSection: PremiumSectionViewState = .subscribe
    var userPastTickets: [MyTicketsViewState.PastTicket] = []
    var isLoading: Bool = false
    
    var forceShowHowToGetTicket: Bool = false
    
    enum Tab: Int {
        case info
        case myTickets
    }
    
    struct NextDraw: Identifiable {
        let id: Date
        let jackpot: Money
        let date: Date
        
        init(id: Date = Date(), jackpot: Money = Money(amount: 0, currency: .usd), date: Date = .distantFuture) {
            self.id = id
            self.jackpot = jackpot
            self.date = date
        }
    }
    
    struct PastDraw {
        let date: Date
        let winningNumbers: [Int]
        
        init(date: Date = Date(), winningNumbers: [Int] = []) {
            self.date = date
            self.winningNumbers = winningNumbers
        }
    }
    
    struct UserActiveTicket {
        let numbers: [Int]
        let date: Date
    }
}

@available(iOS 13.0, *)
protocol SplashViewModel: ViewModel where ViewState == SplashViewState {
    func requestTab(_: SplashViewState.Tab)
    func requestGetTicket()
    func requestCreateTicket()
    func requestSubscribe()
    func requestTicketForPremium()
    func requestTicketForReferral()
    func requestMoreInfo()
    func requestClose()
}

@available(iOS 13.0, *)
class SplashViewController<T: SplashViewModel>: MVVMViewController<T> {
    
    //  MARK: - UI Elements
    
    private let containerView = UIView()
    private let scrollView = UIScrollView()
    private let headerView = HeaderView()
    private let nextDrawView = NextDrawView()
    private let lastWinningTicketView = TicketView()
    private let getTicketButton = CustomButton()
    private let segmentControl = CustomSegmentControl()
    private let infoView = LotteryInfoView()
    private let myTicketsView = MyTicketsView()
    private let closeButton = CustomButton()
    private lazy var loadingView = LoadingView(containerView: self.view)
    
    //  MARK: - Logic
    
    private var nextDrawId: SplashViewState.NextDraw.ID?
    private var timerSubscription: AnyCancellable?
    
    //  MARK: - Lifecycle
    
    override func loadView() {
        self.view = UIView()
        setupUI()
    }
    
    override func viewDidLoad() {
        getTicketButton.touchUpInside = { [weak self] in
            self?.viewModel.requestGetTicket()
        }
        
        infoView.onGetTicketTap = { [weak self] in
            self?.viewModel.requestGetTicket()
        }
        
        infoView.onMoreInfoTap = { [weak self] in
            self?.viewModel.requestMoreInfo()
        }
        
        myTicketsView.onSubscribeTap = { [weak self] in
            self?.viewModel.requestSubscribe()
        }
        
        myTicketsView.onGetTicketForPremiumTap = { [weak self] in
            self?.viewModel.requestTicketForPremium()
        }
        
        myTicketsView.onGetTicketForReferralTap = { [weak self] in
            self?.viewModel.requestTicketForReferral()
        }
        
        myTicketsView.onCreateTicketTap = { [weak self] in
            self?.viewModel.requestCreateTicket()
        }
        
        segmentControl.onSegmentSelected = { [weak self] index in
            guard let tab = SplashViewState.Tab(rawValue: index) else { return }
            self?.viewModel.requestTab(tab)
        }
        
        closeButton.touchUpInside = { [weak self] in
            self?.viewModel.requestClose()
        }
        
        super.viewDidLoad()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        containerView.roundCorners(topLeft: 20, topRight: 20)
    }
    
    //  MARK: - Private Functions
    
    override func updateState(_ state: SplashViewState) {
        headerView.display(jackpot: state.nextDraw.jackpot)
        
        if state.nextDraw.id != self.nextDrawId {
            self.timerSubscription = Timer.publish(every: 1, on: .main, in: .common)
                .autoconnect()
                .merge(with: Just(Date()))
                .sink { [weak self] date in
                    guard let self else { return }
                    let nextDrawTimeInterval = state.nextDraw.date.timeIntervalSince1970 - date.timeIntervalSince1970
                    if nextDrawTimeInterval > 0 {
                        self.nextDrawView.display(state: .waiting(nextDrawTimeInterval))
                        self.myTicketsView.displayNextDraw(timeInterval: nextDrawTimeInterval)
                    } else {
                        if self.isViewOnScreen {
                            UIView.animate(withDuration: 0.3) {
                                self.nextDrawView.display(state: .started)
                                self.nextDrawView.layoutIfNeeded()
                            }
                        } else {
                            self.nextDrawView.display(state: .started)
                        }
                        
                        self.myTicketsView.displayNextDraw(timeInterval: 0)
                        
                        self.timerSubscription = nil
                    }
                }
            self.nextDrawId = state.nextDraw.id
        }
        
        if let lastDraw = state.lastDraw {
            lastWinningTicketView.display(
                TicketViewItem(
                    numbers: lastDraw.winningNumbers,
                    state: .lastWinner(lastDraw.date)
                )
            )
            lastWinningTicketView.isHidden = false
        } else {
            lastWinningTicketView.isHidden = true
        }
        
        
        segmentControl.selectedIndex = state.tab.rawValue
        switch state.tab {
        case .info:
            infoView.isHidden = false
            myTicketsView.isHidden = true
        case .myTickets:
            infoView.isHidden = true
            myTicketsView.isHidden = false
        }
        view.layoutIfNeeded()
        
        infoView.display(
            state: LotteryInfoViewState(
                jackpot: state.nextDraw.jackpot,
                pastDraws: state.pastDraws.map { draw in
                    return .init(date: draw.date, winningNumbers: draw.winningNumbers)
                }
            )
        )
        
        let activeTickets: ActiveTicketsViewState
        if state.userActiveTickets.isEmpty {
            activeTickets = .empty
        } else {
            activeTickets = .notEmpty(
                state.userActiveTickets.map { ticket in
                    return .init(date: ticket.date, ticket: ticket.numbers)
                }
            )
        }
        
        let availableTickets: AvailableTicketsViewState
        if state.availableUserTicketsCount > 0 {
            availableTickets = .notEmpty(count: state.availableUserTicketsCount, drawDate: state.nextDraw.date)
        } else {
            availableTickets = .empty
        }
        
        myTicketsView.display(
            state: MyTicketsViewState(
                activeTickets: activeTickets,
                availableTickets: availableTickets,
                waysToGetTicket: .init(premium: state.premiumSection),
                pastTickets: state.userPastTickets
            )
        )
        
        if state.forceShowHowToGetTicket {
            let visibleView = myTicketsView.waysToGetTicketView
            let rect = visibleView.convert(visibleView.bounds, to: scrollView)
            scrollView.scrollRectToVisible(rect, animated: true)
        }
        
        loadingView.isLoading = state.isLoading
    }
}

//  MARK: - UI

@available(iOS 13.0, *)
private extension SplashViewController {
    func setupUI() {
        containerView.applyLotteryBackground()
        view.addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.top.equalTo(view.safeAreaLayoutGuide).inset(10)
        }
        
        let logoImageView = UIImageView(image: UIImage(named: "ng.lottery.logo"))
        logoImageView.contentMode = .scaleAspectFit
        
        getTicketButton.applyLotteryActionStyle()
        getTicketButton.display(
            title: ngLocalized("Lottery.GetTicket.Btn"),
            image: nil
        )
        
        setupSegmentedControl()
        
        closeButton.applyStyle(
            font: nil,
            foregroundColor: .white,
            backgroundColor: .white.withAlphaComponent(0.35),
            cornerRadius: 12,
            spacing: .zero,
            insets: .zero,
            imagePosition: .leading,
            imageSizeStrategy: .size(width: 10, height: 10)
        )
        closeButton.display(
            title: nil,
            image: UIImage(named: "ng.xmark")
        )
        
        let stack = UIStackView(
            arrangedSubviews: [
                logoImageView,
                headerView, .lotterySectionsSeparator(),
                nextDrawView,
                lastWinningTicketView,
                getTicketButton, .lotterySectionsSeparator(),
                segmentControl,
                infoView,
                myTicketsView
            ],
            axis: .vertical,
            spacing: 24,
            alignment: .fill
        )
        stack.setCustomSpacing(62, after: logoImageView)
        stack.setCustomSpacing(0, after: infoView)
        segmentControl.snp.makeConstraints { make in
            make.height.equalTo(32)
        }
        
        let scrollContent = UIView()
        
        let ballsBackgroundImageView = UIImageView(image: UIImage(named: "ng.lottery.background.balls"))
        ballsBackgroundImageView.applyStyle(
            contentMode: .scaleAspectFill,
            tintColor: nil,
            cornerRadius: .zero
        )
        scrollContent.addSubview(ballsBackgroundImageView)
        ballsBackgroundImageView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
        }
        
        scrollContent.addSubview(stack)
        stack.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(15)
            make.top.equalToSuperview().inset(55)
            make.bottom.lessThanOrEqualToSuperview()
        }
        
        scrollView.bounces = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.addSubview(scrollContent)
        scrollContent.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalToSuperview()
            make.height.equalToSuperview().priority(1)
        }
        
        scrollContent.addSubview(closeButton)
        closeButton.snp.makeConstraints { make in
            make.top.trailing.equalToSuperview().inset(16)
            make.size.equalTo(24)
        }
        
        containerView.addSubview(scrollView)
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    func setupSegmentedControl() {
        segmentControl.selectedLabelColor = .lotteryForegroundTint
        segmentControl.unselectedLabelColor = .white.withAlphaComponent(0.4)
        segmentControl.borderColor = .white.withAlphaComponent(0.4)
        segmentControl.thumbColor = .lotteryBackgroundTint
        segmentControl.unselectedLabelFont = .systemFont(ofSize: 14, weight: .regular)
        segmentControl.selectedLabelFont = .systemFont(ofSize: 14, weight: .semibold)
        segmentControl.padding = 2
        segmentControl.items = [
            ngLocalized("Lottery.InfoTab"),
            ngLocalized("Lottery.TicketsTab")
        ]
    }
}
