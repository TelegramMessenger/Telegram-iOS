import NGCore
import NGCoreUI
import SnapKit
import UIKit

struct CreateTicketViewState: ViewState  {
    var drawDate: Date = Date()
    var isLoading: Bool = false
}

@available(iOS 13.0, *)
protocol CreateTicketViewModel: ViewModel where ViewState == CreateTicketViewState {
    func requestCreateTicket(numbers: [Int])
    func requestClose()
}

@available(iOS 13.0, *)
class CreateTicketViewController<T: CreateTicketViewModel>: MVVMViewController<T> {
    
    private struct Constants {
        static var buttonBottomOffset: CGFloat { 30 }
    }
    
    //  MARK: - UI Elements

    private let containerView = UIView()
    private let backButton = CustomButton()
    private let titleLabel = UILabel()
    private let descLabel = UILabel()
    private let drawDateLabel = UILabel()
    private let numbersInputView = TicketNumbersInputView()
    private let numbersDescLabel = UILabel()
    private let numbersDescContainer = UIView()
    private let randomButton = CustomButton()
    private let createButton = CustomButton()
    private let contentView = UIView()
    private lazy var loadingView = LoadingView(containerView: self.view)
    
    //  MARK: - Logic
    
    private var keyboardTracker: KeyboardTracker?
    
    //  MARK: - Lifecycle
    
    override func loadView() {
        view = UIView()
        setupUI()
        layoutUI()
        setupData()
    }
    
    override func viewDidLoad() {
        backButton.touchUpInside = { [weak self] in
            self?.viewModel.requestClose()
        }
        
        numbersInputView.onInputNumbers = { [weak self] numbers in
            self?.createButton.isEnabled = (numbers != nil)
        }
        
        randomButton.touchUpInside = { [weak self] in
            self?.numbersInputView.fillRandomly()
        }
        
        createButton.touchUpInside = { [weak self] in
            guard let self, let numbers = self.numbersInputView.getNumbers() else {
                return
            }
            self.numbersInputView.resignFirstResponder()
            self.viewModel.requestCreateTicket(numbers: numbers)
        }
        
        keyboardTracker = .init(view: self.view, heightBlock: { [weak self] height, _ in
            self?.handleKeyboardHeightChange(height)
        }, notificationCenter: .default)
        keyboardTracker?.startTracking()
        
        super.viewDidLoad()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        numbersInputView.becomeFirstResponder()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        containerView.roundCorners(topLeft: 20, topRight: 20)
    }
    
    //  MARK: - Private Functions

    override func updateState(_ state: CreateTicketViewState) {
        let drawDateString = formatDrawDate(state.drawDate)
        drawDateLabel.attributedText = parseMarkdownIntoAttributedString(
            ngLocalized("CreateTicket.DrawDate", with: drawDateString).uppercased(),
            attributes: .plain(
                font: .systemFont(ofSize: 12, weight: .regular),
                textColor: .white.withAlphaComponent(0.6)
            ).withBold(
                font: .systemFont(ofSize: 12, weight: .semibold),
                textColor: .white
            ),
            textAlignment: .center
        )
        
        loadingView.isLoading = state.isLoading
    }
    
    private func handleKeyboardHeightChange(_ height: CGFloat) {
        contentView.snp.updateConstraints { make in
            make.bottom.equalToSuperview().inset(height + Constants.buttonBottomOffset)
        }
        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }
    }
    
    private func formatDrawDate(_ date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd.MM.yyyy"
        return dateFormatter.string(from: date)
    }
}

//  MARK: - UI

@available(iOS 13.0, *)
private extension CreateTicketViewController {
    func setupUI() {
        containerView.applyLotteryBackground()
        
        backButton.applyStyle(
            font: nil,
            foregroundColor: .white,
            backgroundColor: .white.withAlphaComponent(0.35),
            cornerRadius: 12,
            spacing: .zero,
            insets: .zero,
            imagePosition: .leading,
            imageSizeStrategy: .size(width: 18, height: 18)
        )
        
        titleLabel.applyStyle(
            font: .systemFont(ofSize: 24, weight: .bold),
            textColor: .white,
            textAlignment: .center,
            numberOfLines: 2,
            adjustFontSize: .no
        )
        
        descLabel.applyStyle(
            font: .systemFont(ofSize: 16, weight: .regular),
            textColor: .white,
            textAlignment: .center,
            numberOfLines: 0,
            adjustFontSize: .no
        )
        
        numbersDescLabel.applyStyle(
            font: .systemFont(ofSize: 14, weight: .regular),
            textColor: .white.withAlphaComponent(0.8),
            textAlignment: .center,
            numberOfLines: 0,
            adjustFontSize: .no
        )

        numbersDescContainer.backgroundColor = .white.withAlphaComponent(0.15)
        numbersDescContainer.layer.cornerRadius = 6
        
        randomButton.applyStyle(
            font: .systemFont(ofSize: 14, weight: .regular),
            foregroundColor: .lotteryForegroundTint,
            backgroundColor: .white,
            cornerRadius: 6,
            spacing: 4,
            insets: UIEdgeInsets(top: 7, left: 12, bottom: 7, right: 10),
            imagePosition: .trailing,
            imageSizeStrategy: .size(width: 14, height: 14)
        )
        
        createButton.applyLotteryActionStyle()
        createButton.isEnabled = false
    }
    
    func layoutUI() {
        view.addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.top.equalTo(view.safeAreaLayoutGuide).inset(10)
        }
        
        containerView.addSubview(backButton)
        backButton.snp.makeConstraints { make in
            make.leading.top.equalToSuperview().inset(16)
            make.size.equalTo(24)
        }
        
        containerView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.leading.greaterThanOrEqualTo(backButton.snp.trailing).offset(15)
            make.top.equalToSuperview().inset(14)
        }
        
        numbersDescContainer.addSubview(numbersDescLabel)
        numbersDescLabel.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview().inset(12)
            make.centerX.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview().inset(15)
        }
        
        let randomButtonWrapper = randomButton.horizontalCenteringContainer()
        let stack = UIStackView(
            arrangedSubviews: [
                descLabel,
                drawDateLabel,
                numbersInputView.horizontalCenteringContainer(),
                DashedBorderView(wrappedVew: numbersDescContainer, cornerRadius: 6),
                randomButtonWrapper,
                UIView(),
                createButton
            ],
            axis: .vertical,
            spacing: 24,
            alignment: .fill
        )
        stack.setCustomSpacing(6, after: drawDateLabel)
        stack.setCustomSpacing(0, after: randomButtonWrapper)
        
        contentView.addSubview(stack)
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        containerView.addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview().inset(15)
            make.bottom.equalToSuperview().inset(Constants.buttonBottomOffset)
        }
    }
    
    func setupData() {
        backButton.display(
            title: nil,
            image: UIImage(named: "ng.arrow.left")
        )
        titleLabel.text = ngLocalized("CreateTicket.Title")
        descLabel.text = ngLocalized("CreateTicket.Desc")
        numbersDescLabel.text = ngLocalized("CreateTicket.NumbersDesc")
        randomButton.display(
            title: ngLocalized("CreateTicket.RandomBtn"),
            image: UIImage(named: "ng.shuffle")
        )
        createButton.display(
            title: ngLocalized("CreateTicket.CreateBtn"),
            image: nil
        )
    }
}
