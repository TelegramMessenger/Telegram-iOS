import NGCoreUI
import SnapKit
import UIKit

struct TicketViewItem {
    let numbers: [Int]
    let state: State
    
    enum State {
        case previousWinner(Date)
        case lastWinner(Date)
        case userActiveTicket(Date)
        case userPastTicket(date: Date, winningNumbers: [Int])
    }
}

class TicketView: UIView {
    
    //  MARK: - UI Elements

    private let winnerBorderImageView = UIImageView()
    private let leadingImageView = UIImageView()
    private let dateLabel = UILabel()
    private let dateContainer = UIView()
    private let yourNumbersLabel = UILabel()
    private let lastWinLabel = UILabel()
    private let numbersView = TicketNumbersView()
    private let linkTextView = UITextView()
    
    //  MARK: - Lifecycle
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    //  MARK: - Public Functions

    func display(_ item: TicketViewItem) {
        let leadingImage: UIImage?
        let date: Date?
        let showYourNumbers: Bool
        let showLastWinner: Bool
        let showLink: Bool
        let numbers: [TicketNumberViewItem]
        applyDefaultShadow()
        winnerBorderImageView.isHidden = true
        switch item.state {
        case .previousWinner(let _date):
            leadingImage = .winner
            date = _date
            showYourNumbers = false
            showLastWinner = false
            showLink = false
            numbers = mapNumbers(item.numbers)
        case .lastWinner(let _date):
            leadingImage = .winner
            date = _date
            showYourNumbers = false
            showLastWinner = true
            showLink = true
            numbers = mapNumbers(item.numbers)
        case .userActiveTicket(let _date):
            leadingImage = .logo
            date = _date
            showYourNumbers = true
            showLastWinner = false
            showLink = false
            numbers = mapNumbers(item.numbers)
        case .userPastTicket(let _date, let winningNumbers):
            let winMask = calculateWinMask(userNumbers: item.numbers, winningNumbers: winningNumbers)
            let isWinner = winMask.allSatisfy { $0 }
            
            leadingImage = isWinner ? .winner : nil
            date = _date
            showYourNumbers = true
            showLastWinner = false
            showLink = false
            
            numbers = mapNumbers(item.numbers, winMask: winMask)
            
            if isWinner {
                applyWinnerShadow()
                winnerBorderImageView.isHidden = false
            }
        }
        
        leadingImageView.image = leadingImage
        leadingImageView.isHidden = (leadingImage == nil)
        
        if let date {
            dateLabel.text = formatDate(date)
            dateContainer.isHidden = false
        } else {
            dateContainer.isHidden = true
        }
        
        yourNumbersLabel.isHidden = !showYourNumbers
        lastWinLabel.isHidden = !showLastWinner
        linkTextView.isHidden = !showLink
        
        numbersView.display(items: numbers)
    }
}

private extension TicketView {
    func formatDate(_ date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd.MM.yyyy"
        return dateFormatter.string(from: date)
    }
    
    func mapNumbers(_ numbers: [Int]) -> [TicketNumberViewItem] {
        return numbers.map { TicketNumberViewItem(number: $0, overlayImage: nil) }
    }
    
    func mapNumbers(_ numbers: [Int], winMask: [Bool]) -> [TicketNumberViewItem] {
        return zip(numbers, winMask).map { number, isWin in
            return TicketNumberViewItem(
                number: number,
                overlayImage: isWin ? UIImage(named: "ng.lottery.ticket.checkmark") : UIImage(named: "ng.lottery.ticket.xmark")
            )
        }
    }
    
    func calculateWinMask(userNumbers: [Int], winningNumbers: [Int]) -> [Bool] {
        let userFirstNumbers = userNumbers.dropLast()
        let userLastNumber = userNumbers.last
        
        let winningFirstNumbers = winningNumbers.dropLast()
        let winningLastNumber = winningNumbers.last
        
        return userFirstNumbers.map { number in
            return winningFirstNumbers.contains(number)
        } + [userLastNumber == winningLastNumber]
    }
    
    func applyDefaultShadow() {
        layer.applyShadow(color: .black, alpha: 0.25, x: 0, y: 5, blur: 15)
    }
    
    func applyWinnerShadow() {
        layer.applyShadow(color: UIColor(hex: "FFE947"), alpha: 0.25, x: 0, y: 10, blur: 15)
    }
}

private extension TicketView {
    func setupUI() {
        winnerBorderImageView.setIntrinsicContentSizeMinimumPriority()
        winnerBorderImageView.image = UIImage(named: "ng.lottery.ticket.winnerborder")
        
        leadingImageView.contentMode = .scaleAspectFit

        dateLabel.applyStyle(
            font: .systemFont(ofSize: 12, weight: .bold),
            textColor: .white,
            textAlignment: .center,
            numberOfLines: 1,
            adjustFontSize: .no
        )
        
        yourNumbersLabel.attributedText = parseMarkdownIntoAttributedString(
            ngLocalized("LotteryTicket.YourNumbers").uppercased(),
            attributes: .plain(
                font: .systemFont(ofSize: 16, weight: .semibold),
                textColor: .white
            ),
            textAlignment: .center
        )
        
        lastWinLabel.applyStyle(
            font: .systemFont(ofSize: 12, weight: .semibold),
            textColor: .white,
            textAlignment: .center,
            numberOfLines: 1,
            adjustFontSize: .no
        )
        lastWinLabel.text = ngLocalized("LotteryTicket.LastWin")
        
        linkTextView.applyPlainStyle()
        linkTextView.attributedText = parseMarkdownIntoAttributedString(
            ngLocalized("LotteryTicket.Link"),
            attributes: .plain(
                font: .systemFont(ofSize: 12, weight: .regular),
                textColor: .white.withAlphaComponent(0.65)
            ).withLink(
                additionalAttributes: [
                    .underlineStyle: NSUnderlineStyle.single.rawValue
                ]
            )
        )
        
        
        let ticketBackground = makeTicketBackground()
        addSubview(ticketBackground)
        ticketBackground.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        addSubview(winnerBorderImageView)
        winnerBorderImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview().offset(1)
        }
        
        dateContainer.backgroundColor = .white.withAlphaComponent(0.15)
        dateContainer.layer.cornerRadius = 4
        dateContainer.addSubview(dateLabel)
        dateLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(4)
            make.top.bottom.equalToSuperview().inset(2)
        }
        
        let leadingStack = UIStackView(
            arrangedSubviews: [leadingImageView, dateContainer],
            axis: .vertical,
            spacing: 2,
            alignment: .center
        )
        
        let coinsImageView = makeCoinsImageView()
        
        addSubview(leadingStack)
        addSubview(coinsImageView)
        leadingStack.snp.makeConstraints { make in
            make.centerX.equalTo(coinsImageView)
            make.centerY.equalTo(coinsImageView).offset(5)
        }
        coinsImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(5)
            make.top.bottom.equalToSuperview()
        }
        
        let trailingStack = UIStackView(
            arrangedSubviews: [yourNumbersLabel, lastWinLabel, numbersView, linkTextView],
            axis: .vertical,
            spacing: 4,
            alignment: .center
        )
        
        addSubview(trailingStack)
        trailingStack.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.top.greaterThanOrEqualToSuperview()
            make.trailing.equalToSuperview().inset(16)
            make.leading.greaterThanOrEqualTo(coinsImageView)
        }
    }
    
    func makeTicketBackground() -> UIView {
        let imageView = UIImageView()
        imageView.setIntrinsicContentSizeMinimumPriority()
        imageView.image = UIImage(named: "ng.ticket.background")
        return imageView
    }
    
    func makeDateContainer() -> UIView {
        let view = UIView()
        view.backgroundColor = .white.withAlphaComponent(0.15)
        view.layer.cornerRadius = 4
        view.addSubview(dateLabel)
        dateLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(4)
            make.top.bottom.equalToSuperview().inset(2)
        }
        return view
    }
    
    func makeCoinsImageView() -> UIView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.image = UIImage(named: "ng.lottery.ticket.coins")
        return imageView
    }
}

private extension UIImage {
    static var winner: UIImage? {
        return UIImage(named: "ng.lottery.ticket.winner")
    }
    
    static var logo: UIImage? {
        return UIImage(named: "ng.lottery.ticket.logo")
    }
}
