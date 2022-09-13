import UIKit
import SnapKit
import NGExtensions
import NGCustomViews
import NGButton
import EsimAuth
import NGLoadingIndicator
import NGTheme
import Postbox
import TelegramCore
import NGAuth
import NGToast

typealias AssistantViewControllerInput = AssistantPresenterOutput

protocol AssistantViewControllerOutput {
    func onViewDidLoad()
    func onViewDidAppear()
    func handleAuth(isAnimated: Bool)
    func handleLogout()
    func handleDismiss()
    func handleMyEsims()
    func handleChat(chatURL: URL?)
    func handleOnLogin()
    
    func handleTelegramBot(session: String)
    func handleSpecialOffer()
}

extension AssistantViewController: ClosureBindable { }

final class AssistantViewController: UIViewController {
    var output: AssistantViewControllerOutput!

    private let containerView: RoundedContainerView
    private let blurEffectView = UIVisualEffectView()
    private let titleLabel = UILabel()
    private let nicegramComunityLabel = UILabel()
    private let assistantItemsStackView = UIStackView()
    private let specialOfferView = SpecialOfferView()
    private let specialOfferContainerView = UIView()
    
    private let assistantStackView = UIStackView()
    private var mobileDataView: AssistantItemView
    private var telegramChannelView: AssistantItemView
    private var telegramChatView: AssistantItemView
    private var supportView: AssistantItemView
    private var rateView: AssistantItemView
    private var logoutView: AssistantItemView
    private var loginButton: NGButton
    
    private let secondSeparatorView = UIView()
    
    private let ngTheme: NGThemeColors
    
    init(ngTheme: NGThemeColors) {
        self.ngTheme = ngTheme
        self.containerView = RoundedContainerView(ngTheme: ngTheme)
        self.mobileDataView = AssistantItemView(ngTheme: ngTheme)
        self.telegramChannelView = AssistantItemView(ngTheme: ngTheme)
        self.telegramChatView = AssistantItemView(ngTheme: ngTheme)
        self.supportView = AssistantItemView(ngTheme: ngTheme)
        self.rateView = AssistantItemView(ngTheme: ngTheme)
        self.logoutView = AssistantItemView(ngTheme: ngTheme)
        self.loginButton = NGButton(ngTheme: ngTheme)
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var shouldAutorotate: Bool {
        return true
    }

    override func loadView() {
        super.loadView()
        output.onViewDidLoad()
        navigationController?.delegate = self
        view.backgroundColor = .clear

        let blurEffect = UIBlurEffect(style: ngTheme.blurStyle)
        blurEffectView.effect = blurEffect
        blurEffectView.frame = view.bounds
        blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        blurEffectView.alpha = 0
        view.addSubview(blurEffectView)

        view.addSubview(containerView)
        containerView.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview()
            $0.bottom.lessThanOrEqualToSuperview()
        }

        containerView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(16.0)
        }
        
        assistantStackView.alignment = .fill
        assistantStackView.axis = .vertical
        assistantStackView.distribution = .fill
        assistantStackView.spacing = 20.0
        assistantStackView.backgroundColor = .clear
        containerView.addSubview(assistantStackView)
        assistantStackView.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(24.0)
            $0.leading.trailing.equalToSuperview()
            $0.bottom.equalToSuperview().inset(54.0)
        }
        
        let firstSeparatorView = UIView()
        firstSeparatorView.backgroundColor = ngTheme.separatorColor
        assistantStackView.addArrangedSubview(firstSeparatorView)
        firstSeparatorView.snp.makeConstraints {
            $0.height.equalTo(0.66)
            $0.leading.trailing.equalToSuperview().inset(16.0)
        }
        
        assistantStackView.addArrangedSubview(mobileDataView)
        mobileDataView.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
        }
        
        secondSeparatorView.backgroundColor = ngTheme.separatorColor
        assistantStackView.addArrangedSubview(secondSeparatorView)
        secondSeparatorView.snp.makeConstraints {
            $0.height.equalTo(0.66)
            $0.leading.trailing.equalToSuperview().inset(16.0)
        }
        
        specialOfferContainerView.isHidden = true
        specialOfferContainerView.addSubview(specialOfferView)
        specialOfferView.snp.makeConstraints { make in
            make.height.equalTo(56.0)
            make.edges.equalToSuperview()
        }
        assistantStackView.addArrangedSubview(specialOfferContainerView)
        specialOfferContainerView.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(16.0)
        }

        nicegramComunityLabel.textColor = ngTheme.subtitleColor
        nicegramComunityLabel.textAlignment = .natural
        nicegramComunityLabel.font = .systemFont(ofSize: 12.0, weight: .semibold)
        assistantStackView.addArrangedSubview(nicegramComunityLabel)
        nicegramComunityLabel.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(16.0)
        }
        assistantStackView.addArrangedSubview(telegramChannelView)
        telegramChannelView.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
        }
        
        assistantStackView.addArrangedSubview(telegramChatView)
        telegramChatView.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
        }
        
        let thirdSeparatorView = UIView()
        thirdSeparatorView.backgroundColor = ngTheme.separatorColor
        assistantStackView.addArrangedSubview(thirdSeparatorView)
        thirdSeparatorView.snp.makeConstraints {
            $0.height.equalTo(0.66)
            $0.leading.trailing.equalToSuperview().inset(16.0)
        }
        
        assistantStackView.addArrangedSubview(supportView)
        supportView.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
        }
        
        assistantStackView.addArrangedSubview(rateView)
        rateView.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
        }
        
        assistantStackView.addArrangedSubview(logoutView)
        logoutView.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
        }
        
        assistantStackView.addArrangedSubview(loginButton)
        loginButton.snp.makeConstraints {
            $0.height.equalTo(54.0)
            $0.leading.trailing.equalToSuperview().inset(16.0)
        }
        
        containerView.setupFooter(type: .withFooter)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        containerView.onDismiss = { [weak self] in
            UIView.animate(withDuration: 0.2) {
                self?.blurEffectView.alpha = 0
            } completion: { _ in
                self?.containerView.removeFromSuperview()
                self?.output.handleDismiss()
            }
        }
//        containerView.layer.cornerRadius = 16
//        if #available(iOS 11.0, *) {
//            containerView.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMinXMinYCorner]
//        }
//        containerView.layoutIfNeeded()
        
        titleLabel.font = .systemFont(ofSize: 28.0, weight: .bold)
        titleLabel.textColor = ngTheme.reverseTitleColor
        
        specialOfferView.onTap = { [weak self] in
            self?.output.handleSpecialOffer()
        }
        
        mobileDataView.onTouchUpInside = { [weak self] itemTag in
            self?.output.handleMyEsims()
        }
        
        telegramChannelView.onTouchUpInside = { [weak self] itemTag in
            guard let self = self else { return }
            self.triggerDismiss { [weak self] _ in
                let url = URL(string: "ncg://resolve?domain=nicegramapp")
                self?.output.handleChat(chatURL: url)
            }
        }
        
        telegramChatView.onTouchUpInside = { [weak self] itemTag in
            guard let self = self else { return }
            self.triggerDismiss { [weak self] _ in 
                let url = URL(string: "ncg://resolve?domain=NicegramNetwork")
                self?.output.handleChat(chatURL: url)
            }
        }
        
        supportView.onTouchUpInside = { [weak self] itemTag in
            guard let self = self else { return }
            self.triggerDismiss { [weak self] _ in 
                let url = URL(string: "ncg://resolve?domain=nicegram_support_manager")
                self?.output.handleChat(chatURL: url)
            }
        }
        
        rateView.onTouchUpInside = { [weak self] itemTag in
            guard let productURL = URL(string: "https://apps.apple.com/app/id1608870673") else { return }
            self?.triggerDismiss { _ in
                var components = URLComponents(url: productURL, resolvingAgainstBaseURL: false)
                components?.queryItems = [
                    URLQueryItem(name: "action", value: "write-review")
                ]
                guard let writeReviewURL = components?.url else {
                    return
                }
                if #available(iOS 10.0, *) {
                    UIApplication.shared.open(writeReviewURL)
                }
            }
        }
        
        logoutView.isHidden = true
        logoutView.onTouchUpInside = { [weak self] _ in
            guard let self = self else { return }
            self.output.handleLogout()
        }

        loginButton.buttonState = .enabled
        loginButton.isRounded = true
        loginButton.touchUpInside = { [weak self] in
            guard let self = self else { return }
            self.output.handleOnLogin()
        }
        
        output.handleAuth(isAnimated: false)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.isNavigationBarHidden = true
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        UIView.animate(withDuration: 0.3, delay: 0) {
            self.blurEffectView.alpha = 1
            self.titleLabel.snp.remakeConstraints {
                $0.top.equalTo(self.view.safeArea.top).inset(28.0)
                $0.leading.trailing.equalToSuperview().inset(16.0)
            }
            self.view.layoutSubviews()
            self.containerView.layoutSubviews()
        } completion: { _ in
            self.output.onViewDidAppear()
        }
    }
    
    private func triggerDismiss(completion: ((Bool) -> Void)?) {
        UIView.animate(withDuration: 0.2) {
            self.blurEffectView.alpha = 0
        }
        containerView.handleClose(completion: completion)
    }
    
    private func setupView(with item: PersonalAssistantItem, isArrowHidden: Bool = false) -> AssistantItemView {
        let item = PersonalAssistantItem(
            image: item.image,
            title: item.title,
            subtitle: item.subtitle,
            description: item.description,
            item: item.item
        )
        let view = AssistantItemView(ngTheme: ngTheme)
        view.display(item: item, isArrowHidden: isArrowHidden)
        return view
    }
}

extension AssistantViewController: AssistantViewControllerInput { 
    func display(viewItem: PersonalAssistantItem) {
        switch viewItem.item {
        case .mobileData:
            mobileDataView = setupView(with: viewItem)
        case .channel:
            telegramChannelView = setupView(with: viewItem)
        case .chat:
            telegramChatView = setupView(with: viewItem)
        case .rateUs:
            rateView = setupView(with: viewItem)
        case .support:
            supportView = setupView(with: viewItem)
        case .logout:
            logoutView = setupView(with: viewItem, isArrowHidden: true)
        default:
            break
        }
    }
    
    func display(titleText: String?) {
        titleLabel.text = titleText
    }
    
    func display(comunityText: String?) {
        nicegramComunityLabel.text = comunityText
    }
    
    func display(loginTitleText: String?) {
        loginButton.setTitle(loginTitleText, for: .normal)
    }
    
    func display(isAuthorized: Bool, isAnimated: Bool) {
        guard !isAnimated else {
            handleAnimation(isAuthenificated: isAuthorized)
            return
        }
        loginButton.isHidden = isAuthorized
        logoutView.isHidden = !isAuthorized

    }
    
    func display(isLoading: Bool) {
        if isLoading {
            NGLoadingIndicator.shared.startAnimating(on: view)
        } else {
            NGLoadingIndicator.shared.stopAnimating()
        }
    }
    
    func onLogout() {
        handleAnimation(isAuthenificated: false)
    }
    
    private func handleAnimation(isAuthenificated: Bool) {
        if isAuthenificated {
            self.assistantStackView.snp.updateConstraints {
                $0.bottom.equalToSuperview().inset(-20.0)
            }
            UIView.animate(withDuration: 0.3, delay: 1.0) { 
                self.view.layoutIfNeeded()
            } completion: { _ in
                self.loginButton.isHidden = true
                self.logoutView.isHidden = false
                self.assistantStackView.snp.updateConstraints {
                    $0.bottom.equalToSuperview().inset(54.0)
                }
                UIView.animate(withDuration: 0.3) { 
                    self.view.layoutIfNeeded()
                }
            }
        } else {
            self.assistantStackView.snp.updateConstraints {
                $0.bottom.equalToSuperview().inset(0)
            }
            UIView.animate(withDuration: 0.3, delay: 0.2) {
                self.view.layoutIfNeeded()
            } completion: { [weak self] _ in
                self?.loginButton.isHidden = false
                self?.logoutView.isHidden = true
                self?.assistantStackView.snp.updateConstraints {
                    $0.bottom.equalToSuperview().inset(54.0)
                }
                UIView.animate(withDuration: 0.3) { 
                    self?.view.layoutIfNeeded()
                }
            }
        }
    }
    
    func display(specialOffer: SpecialOfferViewModel, animated: Bool) {
        specialOfferView.display(specialOffer)
        specialOfferContainerView.isHidden = false
        
        let block = {
            self.view.layoutIfNeeded()
        }
        
        if animated {
            UIView.animate(withDuration: 0.3, animations: block)
        } else {
            block()
        }
    }
    
    func displaySuccessToast() {
        NGToast.showSuccessToast()
    }
    
    func displayCommunitySection(isHidden: Bool) {
        secondSeparatorView.isHidden = isHidden
        nicegramComunityLabel.isHidden = isHidden
        telegramChannelView.isHidden = isHidden
        telegramChatView.isHidden = isHidden
    }
}

extension AssistantViewController: LoginListener {
    func onLogin() {
        handleAnimation(isAuthenificated: true)
    }
    
    func onOpenTelegamBot(session: String) {
        output.handleTelegramBot(session: session)
    }
}

extension AssistantViewController: UINavigationControllerDelegate {
    func navigationControllerSupportedInterfaceOrientations(_ navigationController: UINavigationController) -> UIInterfaceOrientationMask {
        return UIDevice.current.userInterfaceIdiom == .phone ? .portrait : .all
    }
}
