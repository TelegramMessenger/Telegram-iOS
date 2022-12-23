import NGCoreUI
import SnapKit
import UIKit

struct MyTicketsViewState {
    let activeTickets: ActiveTicketsViewState
    let availableTickets: AvailableTicketsViewState
    let waysToGetTicket: WaysToGetTicketViewState
    let pastTickets: [PastTicket]
    
    struct ActiveTicket {
        let date: Date
        let ticket: [Int]
    }
    
    struct PastTicket {
        let date: Date
        let ticket: [Int]
        let winningNumbers: [Int]
    }
}

enum ActiveTicketsViewState {
    case empty
    case notEmpty([MyTicketsViewState.ActiveTicket])
}

enum AvailableTicketsViewState {
    case empty
    case notEmpty(count: Int, drawDate: Date)
}

class MyTicketsView: UIView {
    
    //  MARK: - UI Elements

    private let activeTicketsView = TicketsListView()
    private let availableTicketsView = SplashSectionView()
    let waysToGetTicketView = WaysToGetTicketView()
    private let pastTicketsView = TicketsListView()
    
    //  MARK: - Handlers
    
    var onCreateTicketTap: (() -> Void)? {
        get { availableTicketsView.onButtonTap }
        set { availableTicketsView.onButtonTap = newValue }
    }
    
    var onSubscribeTap: (() -> Void)? {
        get { waysToGetTicketView.onSubscribeTap }
        set { waysToGetTicketView.onSubscribeTap = newValue }
    }
    
    var onGetTicketForPremiumTap: (() -> Void)? {
        get { waysToGetTicketView.onGetTicketForPremiumTap }
        set { waysToGetTicketView.onGetTicketForPremiumTap = newValue }
    }
    
    var onGetTicketForReferralTap: (() -> Void)? {
        get { waysToGetTicketView.onGetTicketForReferralTap }
        set { waysToGetTicketView.onGetTicketForReferralTap = newValue }
    }
    
    //  MARK: - Lifecycle
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        layoutUI()
        setupLabels()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    //  MARK: - Public Functions

    func display(state: MyTicketsViewState) {
        switch state.activeTickets {
        case .notEmpty(let tickets):
            let ticketsViewItems = tickets.map { ticket in
                return TicketViewItem(
                    numbers: ticket.ticket,
                    state: .userActiveTicket(ticket.date)
                )
            }
            activeTicketsView.display(tickets: ticketsViewItems)
            
            activeTicketsView.isHidden = false
        case .empty:
            activeTicketsView.isHidden = true
        }
        
        switch state.availableTickets {
        case .notEmpty(let count, let drawDate):
            let dateDescription = dateDescription(drawDate)
            availableTicketsView.display(
                item: SplashSectionViewItem(
                    titleImage: nil,
                    title: ngLocalized("Lottery.AvailableTickets.Title"),
                    badge: count,
                    description: ngLocalized("Lottery.AvailableTicketsNotEmpty.Desc", with: dateDescription),
                    buttonTitle: ngLocalized("Lottery.AvailableTickets.Btn")
                )
            )
        case .empty:
            availableTicketsView.display(
                item: SplashSectionViewItem(
                    titleImage: nil,
                    title: ngLocalized("Lottery.AvailableTickets.Title"),
                    badge: 0,
                    description: ngLocalized("Lottery.AvailableTicketsEmpty.Desc"),
                    buttonTitle: nil
                )
            )
        }
        
        waysToGetTicketView.display(state: state.waysToGetTicket)
        
        if !state.pastTickets.isEmpty  {
            let pastTicketsViewItems = state.pastTickets.map { ticket in
                return TicketViewItem(
                    numbers: ticket.ticket,
                    state: .userPastTicket(date: ticket.date, winningNumbers: ticket.winningNumbers)
                )
            }
            pastTicketsView.display(tickets: pastTicketsViewItems)
            
            pastTicketsView.isHidden = false
        } else {
            pastTicketsView.isHidden = true
        }
    }
    
    func displayNextDraw(timeInterval: TimeInterval) {
        let timeIntervalDesc = timeIntervalDesc(timeInterval)
        activeTicketsView.display(
            subtitle: ngLocalized("Lottery.ActiveTickets.Desc", with: timeIntervalDesc)
        )
    }
}

private extension MyTicketsView {
    func timeIntervalDesc(_ timeInterval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: timeInterval) ?? ""
    }
    
    func dateDescription(_ date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "d MMMM"
        return dateFormatter.string(from: date)
    }
}

private extension MyTicketsView {
    func setupUI() {
        
    }
    
    func layoutUI() {
        let stack = UIStackView(
            arrangedSubviews: [
                activeTicketsView, .lotterySectionsSeparator(),
                availableTicketsView, .lotterySectionsSeparator(),
                waysToGetTicketView, .lotterySectionsSeparator(),
                pastTicketsView
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
    
    func setupLabels() {
        activeTicketsView.display(title: ngLocalized("Lottery.ActiveTickets.Title"))
        pastTicketsView.display(title: ngLocalized("Lottery.PastTickets"))
    }
}
