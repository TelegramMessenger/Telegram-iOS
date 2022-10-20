import UIKit
import SnapKit
import NGButton
import NGCustomViews
import NGExtensions
import NGLoadingIndicator
import Markdown

struct SubscriptionViewModel {
    let id: String
    let subscribeButtonTitle: String
}

protocol SubscriptionViewControllerInput {}

protocol SubscriptionViewControllerOutput {
    func viewDidLoad()
    func requestClose()
    func requestPurchase(id: String)
    func requestRestore()
    func requestPrivacyPolicy()
    func requestTermsOfUse()
}

final class SubscriptionViewController: UIViewController, SubscriptionViewControllerInput {
    
    //  MARK: - VIP
    
    var output: SubscriptionViewControllerOutput!
    
    //  MARK: - UI Elements

    private let closeButton = CustomButton()
    private let imageView = UIImageView()
    private let titleLabel = UILabel()
    private let featuresStack = UIStackView()
    private let bottomView = UIView()
    private let subscribeInfoLabel = UILabel()
    private let subscribeButton = CustomButton()
    private let restoreButton = CustomButton()
    private let termsButton = CustomButton()
    private let privacyButton = CustomButton()
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return UIDevice.current.userInterfaceIdiom == .phone ? .portrait : .all
    }
    
    //  MARK: - Logic
    
    var currentSubscription: SubscriptionViewModel?
    
    //  MARK: - Lifecycle

    override func loadView() {
        view = UIView()
        setupUI()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        closeButton.touchUpInside = { [weak self] in
            self?.output.requestClose()
        }
        
        subscribeButton.touchUpInside = { [weak self] in
            if let self = self,
               let id = self.currentSubscription?.id {
                self.output.requestPurchase(id: id)
            }
        }
        
        restoreButton.touchUpInside = { [weak self] in
            self?.output.requestRestore()
        }
        
        privacyButton.touchUpInside = { [weak self] in
            self?.output.requestPrivacyPolicy()
        }
        
        termsButton.touchUpInside = { [weak self] in
            self?.output.requestTermsOfUse()
        }
        
        output.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        UIApplication.shared.internalSetStatusBarHidden(true, animation: animated ? .fade : .none)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        UIApplication.shared.internalSetStatusBarHidden(false, animation: animated ? .fade : .none)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        scrollView.adjustBottomInsetToNotBeCovered(by: bottomView)
    }
}

extension SubscriptionViewController: SubscriptionPresenterOutput {
    func display(isLoading: Bool) {
        if isLoading {
            NGLoadingIndicator.shared.startAnimating(on: view)
        } else {
            NGLoadingIndicator.shared.stopAnimating()
        }
    }
    
    func display(title: String) {
        let body = MarkdownAttributeSet(
            font: .systemFont(ofSize: 32, weight: .light),
            textColor: .white
        )
        let bold = MarkdownAttributeSet(
            font: .systemFont(ofSize: 32, weight: .bold),
            textColor: .white
        )
        let attributes = MarkdownAttributes(
            body: body,
            bold: bold,
            link: body,
            linkAttribute: { _ in return nil }
        )
        titleLabel.attributedText = parseMarkdownIntoAttributedString(
            title,
            attributes: attributes,
            textAlignment: .natural
        )
    }
    
    func display(premiumFeatures: [PremiumFeatureViewModel]) {
        featuresStack.removeAllArrangedSubviews()
        for feature in premiumFeatures {
            let view = PremiumFeatureView()
            view.display(feature)
            featuresStack.addArrangedSubview(view)
        }
    }
    
    func display(subscription: SubscriptionViewModel) {
        subscribeButton.display(title: subscription.subscribeButtonTitle, image: nil)
        self.currentSubscription = subscription
    }
    
    func display(subscribeTitle: String) {
        subscribeButton.display(title: subscribeTitle, image: nil)
    }
    
    func display(subscribeInfo: String) {
        subscribeInfoLabel.text = subscribeInfo
    }
    
    func display(restoreText: String) {
        restoreButton.display(title: restoreText, image: nil)
    }
    
    func display(privacyText: String) {
        privacyButton.display(title: privacyText, image: nil)
    }
    
    func display(termsText: String) {
        termsButton.display(title: termsText, image: nil)
    }
}

//  MARK: - Private Functions

private extension SubscriptionViewController {
    struct Constants {
        static let horizontalMarging = 20
    }
    
    func setupUI() {
        view.backgroundColor = .black
        
        closeButton.foregroundColor = .white.withAlphaComponent(0.4)
        closeButton.display(title: nil, image: UIImage(named: "ng.xmark")?.withRenderingMode(.alwaysTemplate))
        
        imageView.image = UIImage(named: "ng.wallet.subscription")
        
        titleLabel.numberOfLines = 2
        
        featuresStack.axis = .vertical
        featuresStack.spacing = 12
        
        subscribeInfoLabel.font = .systemFont(ofSize: 14, weight: .regular)
        subscribeInfoLabel.textColor = .ngBodyThree
        subscribeInfoLabel.numberOfLines = 0
        subscribeInfoLabel.textAlignment = .center
        
        subscribeButton.configureTitleLabel { l in
            l.font = .systemFont(ofSize: 16, weight: .bold)
        }
        subscribeButton.foregroundColor = .white
        subscribeButton.layer.cornerRadius = 6
        subscribeButton.setGradientBackground(colors: .defaultGradient)
        
        styleBottomButton(restoreButton)
        styleBottomButton(privacyButton)
        styleBottomButton(termsButton)
        
        bottomView.backgroundColor = .black
        
        let botButtonsStack = UIStackView(arrangedSubviews: [restoreButton, .botButtonsSeparator(), privacyButton, .botButtonsSeparator(), termsButton])
        botButtonsStack.spacing = 15
        botButtonsStack.distribution = .equalCentering
        
        let botStack = UIStackView(arrangedSubviews: [subscribeInfoLabel, subscribeButton, botButtonsStack])
        botStack.axis = .vertical
        botStack.spacing = 12
        if #available(iOS 11.0, *) {
            botStack.setCustomSpacing(30, after: subscribeButton)
        }
        
        bottomView.addSubview(botStack)
        
        contentView.addSubview(imageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(featuresStack)
        
        scrollView.addSubview(contentView)
        
        view.addSubview(scrollView)
        view.addSubview(bottomView)
        view.addSubview(closeButton)
        
        imageView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.leading.equalToSuperview().priority(.high)
            make.top.equalToSuperview()
            make.height.equalTo(imageView.snp.width).multipliedBy(360.0 / 375)
            make.height.lessThanOrEqualTo(view).multipliedBy(0.55)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.bottom.equalTo(imageView.snp.bottom)
            make.leading.trailing.equalToSuperview().inset(Constants.horizontalMarging)
        }
        
        featuresStack.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(24)
            make.leading.trailing.equalToSuperview().inset(Constants.horizontalMarging)
            make.bottom.equalToSuperview()
        }
        
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalToSuperview()
            make.height.equalToSuperview().priority(1)
        }
        
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        subscribeButton.snp.makeConstraints { make in
            make.height.equalTo(54)
        }
        
        bottomView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
        }
        
        botStack.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(Constants.horizontalMarging)
            make.top.equalToSuperview().inset(12)
            make.bottom.equalTo(self.view.safeArea.bottom).inset(10)
        }
        
        closeButton.snp.makeConstraints { make in
            make.top.equalTo(view.safeArea.top).inset(20)
            make.trailing.equalToSuperview().inset(20)
            make.width.height.equalTo(20)
        }
    }
}

private func styleBottomButton(_ button: CustomButton) {
    button.configureTitleLabel { l in
        l.font = .systemFont(ofSize: 11, weight: .medium)
        l.numberOfLines = 2
    }
    button.foregroundColor = .ngBodyThree
}

private extension UIView {
    static func botButtonsSeparator() -> UIView {
        let view = UIView()
        view.backgroundColor = .ngBodyThree
        view.snp.makeConstraints { make in
            make.width.equalTo(1)
        }
        return view
    }
}
