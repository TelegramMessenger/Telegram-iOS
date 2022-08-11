import UIKit
import SnapKit
import NGButton
import NGCustomViews
import NGExtensions
import NGTheme

struct MyEsimViewModel {
    let id: String
    let headerItem: HeaderCardViewModel
    let balanceCaption: String
    let balance: String
    let unit: String?
    let durationCaption: String
    let duration: String
    let topUpButtonTitle: String
    let topUpButtonImage: UIImage
    let faqButtonTitle: String
}

class MyEsimView: UIControl {
    
    //  MARK: - UI Elements
    
    var ngTheme: NGThemeColors? {
        didSet {
            setupUI()
        }
    }

    private let headerView = HeaderCardView()
    private let balanceCaptionLabel = UILabel()
    private let balanceLabel = UILabel()
    private let unitLabel = UILabel()
    private let durationCaptionLabel = UILabel()
    private let durationDotView = UIView()
    private let durationLabel = UILabel()
    private let topUpButton = CustomButton()
    private let faqButton = CustomButton()
    
    //  MARK: - Public Properties
    
    var onTap: (() -> ())?

    var onTopUpTap: (() ->())? {
        get { topUpButton.touchUpInside }
        set { topUpButton.touchUpInside = newValue }
    }
    
    var onFaqTap: (() -> ())? {
        get { faqButton.touchUpInside }
        set { faqButton.touchUpInside = newValue }
    }
    
    var onCopyPhoneTap: (() -> ())? {
        get { headerView.onSubtitleButtonTap }
        set { headerView.onSubtitleButtonTap = newValue }
    }
    
    //  MARK: - Lifecycle
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        addTarget(self, action: #selector(tapped), for: .touchUpInside)
        
        setupUI()
        layoutUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        faqButton.layer.cornerRadius = faqButton.bounds.height / 2
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let view = super.hitTest(point, with: event)
        if view is UIControl {
            return view
        } else {
            return self
        }
    }
    
    //  MARK: - Public Functions

    func display(item: MyEsimViewModel) {
        headerView.display(item: item.headerItem)
        balanceCaptionLabel.text = item.balanceCaption
        balanceLabel.text = item.balance
        unitLabel.text = item.unit
        unitLabel.isHidden = (item.unit == nil)
        durationCaptionLabel.text = item.durationCaption
        durationLabel.text = item.duration
        topUpButton.display(title: item.topUpButtonTitle, image: item.topUpButtonImage.withRenderingMode(.alwaysTemplate))
        faqButton.display(title: item.faqButtonTitle, image: nil)
    }
    
    //  MARK: - Private Functions

    private func setupUI() {
        backgroundColor = ngTheme?.cardColor
        layer.cornerRadius = 12
        clipsToBounds = true
        
        headerView.configureSubtitleButton { button in
            button.configureTitleLabel { label in
                label.font = .systemFont(ofSize: 18, weight: .semibold)
            }
        }
        
        balanceCaptionLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        balanceCaptionLabel.textColor = .ngSubtitle
        
        balanceLabel.font = .systemFont(ofSize: 24, weight: .bold)
        balanceLabel.textColor = ngTheme?.reverseTitleColor
        
        unitLabel.font = .systemFont(ofSize: 12, weight: .medium)
        unitLabel.textColor = ngTheme?.reverseTitleColor
        
        durationCaptionLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        durationCaptionLabel.textColor = .ngSubtitle
        
        durationDotView.backgroundColor = ngTheme?.reverseTitleColor.withAlphaComponent(0.5)
        durationDotView.layer.cornerRadius = 2
        
        durationLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        durationLabel.textColor = ngTheme?.reverseTitleColor
        
        topUpButton.applyMainActionStyle()
        topUpButton.spacing = 4
        topUpButton.insets = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        topUpButton.configureTitleLabel { label in
            label.font = .systemFont(ofSize: 12, weight: .semibold)
        }
        
        faqButton.foregroundColor = .white
        faqButton.backgroundColor = .black.withAlphaComponent(0.3)
        faqButton.insets = UIEdgeInsets(top: 5, left: 12, bottom: 5, right: 12)
        faqButton.configureTitleLabel { label in
            label.font = .systemFont(ofSize: 12, weight: .semibold)
        }
    }
    
    private func layoutUI() {
        let balanceSumStack = UIStackView(arrangedSubviews: [balanceLabel, unitLabel])
        balanceSumStack.spacing = 4
        
        let balanceStack = UIStackView(arrangedSubviews: [balanceCaptionLabel, balanceSumStack])
        balanceStack.axis = .vertical
        
        let durationStack = UIStackView(arrangedSubviews: [durationCaptionLabel, durationDotView, durationLabel])
        durationStack.spacing = 8
        durationStack.alignment = .center
        durationDotView.snp.makeConstraints { make in
            make.width.height.equalTo(4)
        }
        
        let midStack = UIStackView(arrangedSubviews: [balanceStack, topUpButton])
        midStack.spacing = 15
        midStack.alignment = .center
        
        let descriptionsStack = UIStackView(arrangedSubviews: [midStack, durationStack])
        descriptionsStack.axis = .vertical
        descriptionsStack.spacing = 4
        descriptionsStack.layoutMargins = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        descriptionsStack.isLayoutMarginsRelativeArrangement = true
        
        let stack = UIStackView(arrangedSubviews: [headerView, descriptionsStack])
        stack.axis = .vertical
        headerView.snp.makeConstraints { make in
            make.height.equalTo(112)
        }
        
        topUpButton.snp.contentHuggingHorizontalPriority = 250
        balanceCaptionLabel.snp.contentHuggingHorizontalPriority = 249
        balanceLabel.snp.contentHuggingHorizontalPriority = 249
        unitLabel.snp.contentHuggingHorizontalPriority = 248
        durationCaptionLabel.snp.contentHuggingHorizontalPriority = 250
        durationLabel.snp.contentHuggingHorizontalPriority = 249
        
        addSubview(stack)
        addSubview(faqButton)
        
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        faqButton.snp.makeConstraints { make in
            make.top.trailing.equalToSuperview().inset(12)
        }
    }
}

private extension MyEsimView {
    @objc func tapped() {
        onTap?()
    }
}
