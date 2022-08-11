import UIKit
import SnapKit
import NGButton
import NGExtensions
import NGLoadingIndicator
import SubscriptionAnalytics
import NGIAP

protocol SubscriptionViewControllerInput {
    // func displaySmth(viewModel: SomeModel)
}

protocol SubscriptionViewControllerOutput {
    func restore()
    func purcahseProduct(id: String)
    func openPrivacyPolicy()
    func openTerms()
    // func doSmth(request: RequestModel)
}

final class SubscriptionViewController: UIViewController, SubscriptionViewControllerInput {
    var output: SubscriptionViewControllerOutput!
    var router: SubscriptionRouterInput!

    private weak var tapKeyboardDismissRecognizer: UITapGestureRecognizer?

    private let isNightTheme: Bool
    
    private let logoImageView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()

    private let subscribeButton = NGButton()
    private let footerInfoLabel = UILabel()
    private let restoreButton = ActionButton()
    private let termsButton = ActionButton()
    private let privacyButton = ActionButton()

    private let closeButton = ActionButton()

    init(isNightTheme: Bool) {
        self.isNightTheme = isNightTheme
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        super.loadView()
        view = UIView()
        view.addSubview(logoImageView)
        logoImageView.snp.makeConstraints {
            $0.width.height.equalTo(110.0)
            $0.centerX.equalToSuperview()
            $0.centerY.equalToSuperview().multipliedBy(0.55)
        }

        view.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.top.equalTo(logoImageView.snp.bottom).offset(60.0)
            $0.leading.trailing.equalToSuperview().inset(8.0)
        }

        view.addSubview(subtitleLabel)
        subtitleLabel.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(34.0)
            $0.leading.trailing.equalToSuperview().inset(40.0)
        }

        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 16
        stackView.alignment = .fill
        view.addSubview(stackView)
        stackView.snp.makeConstraints {
            $0.height.equalTo(40.0)
            $0.leading.trailing.equalToSuperview().inset(30.0)
            $0.bottom.equalTo(self.view.safeArea.bottom).offset(-4.0)
        }
        stackView.addArrangedSubview(privacyButton)
        stackView.addArrangedSubview(termsButton)
        stackView.addArrangedSubview(restoreButton)

        view.addSubview(footerInfoLabel)
        footerInfoLabel.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(8.0)
            $0.bottom.equalTo(stackView.snp.top).offset(-34.0)
        }

        view.addSubview(subscribeButton)
        subscribeButton.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(16.0)
            $0.height.equalTo(54.0)
            $0.bottom.equalTo(footerInfoLabel.snp.top).offset(-12.0)
        }

        view.addSubview(closeButton)
        closeButton.snp.makeConstraints {
            $0.height.width.equalTo(40.0)
            $0.trailing.equalToSuperview().inset(14.0)
            $0.top.equalTo(self.view.safeArea.top).inset(4.0)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if isNightTheme {
            view.backgroundColor = .ngBackground
            titleLabel.textColor = .white
            subtitleLabel.textColor = .white
            footerInfoLabel.textColor = .white
        } else {
            view.backgroundColor = .white
            titleLabel.textColor = .black
            subtitleLabel.textColor = .black
            footerInfoLabel.textColor = .black
        }

        logoImageView.image = UIImage(named: "NicegramBigLogo")

        subscribeButton.buttonState = .enabled

        setupSubscriptionButton()
        let subscription = SubscriptionService.shared.subscription(for: NicegramProducts.Premium)
        subscribeButton.setTitleColor(.white, for: .normal)
        subscribeButton.isRounded = true
        subscribeButton.touchUpInside = { [weak self] in
            guard let self = self else { return }
            self.output.purcahseProduct(id: subscription?.identifier ?? "")
        }

        privacyButton.setTitle("Privacy", for: .normal)
        privacyButton.titleLabel?.font = .systemFont(ofSize: 16.0, weight: .regular)
        privacyButton.setTitleColor(.ngSubtitle, for: .normal)
        privacyButton.touchUpInside = { [weak self] in
            guard let self = self else { return }
            self.output.openPrivacyPolicy()
        }
        termsButton.setTitle("Terms", for: .normal)
        termsButton.titleLabel?.font = .systemFont(ofSize: 16.0, weight: .regular)
        termsButton.setTitleColor(.ngSubtitle, for: .normal)
        termsButton.touchUpInside = { [weak self] in
            guard let self = self else { return }
            self.output.openTerms()
        }
        restoreButton.setTitle("Restore", for: .normal)
        restoreButton.titleLabel?.font = .systemFont(ofSize: 16.0, weight: .regular)
        restoreButton.setTitleColor(.ngSubtitle, for: .normal)
        restoreButton.touchUpInside = { [weak self] in
            guard let self = self else { return }
            self.output.restore()
        }

        titleLabel.text = "Nicegram Premium"
        titleLabel.numberOfLines = 0
        titleLabel.font = .systemFont(ofSize: 28.0, weight: .regular)
        titleLabel.textAlignment = .center

        subtitleLabel.text = "Unlock advanced Translator functions and folders management"
        subtitleLabel.numberOfLines = 0
        subtitleLabel.font = .systemFont(ofSize: 16.0, weight: .regular)
        subtitleLabel.textAlignment = .center

        footerInfoLabel.text = "Autorenewable subscription. Cancel anytime"
        footerInfoLabel.numberOfLines = 0
        footerInfoLabel.font = .systemFont(ofSize: 14.0, weight: .regular)
        footerInfoLabel.textAlignment = .center

        closeButton.setImage(UIImage(named: "Chat/Input/Media/GridDismissIcon"), for: .normal)
        closeButton.imageView?.contentMode = .scaleToFill
        closeButton.touchUpInside = { [weak self] in
            guard let self = self else { return }
            self.router.dismiss()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.isNavigationBarHidden = false
    }

    func setupSubscriptionButton() {
        let subscription = SubscriptionService.shared.subscription(for: NicegramProducts.Premium)
        subscribeButton.setTitle("Subscribe for \(subscription?.price ?? "$0") / month", for: .normal)
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

    func onSuccess() {
        self.router.dismiss()
    }
}
