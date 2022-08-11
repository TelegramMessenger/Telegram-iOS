import UIKit
import SnapKit
import NGExtensions
import NGCustomViews
import NGButton
import EsimAuth
import NGTheme

protocol AssistantAuthViewControllerInput { }

protocol AssistantAuthViewControllerOutput {
    func onViewDidLoad()
    
    func onLoginWithEmail()
    func onLoginWithGoogle(with view: RequiringPresentationDelegate)
    func onLoginWithApple(with view: RequiringPresentationDelegate)
    
    func onDismiss()
}

extension AssistantAuthViewController: ClosureBindable { }

final class AssistantAuthViewController: UIViewController, AssistantAuthViewControllerInput {
    var output: AssistantAuthViewControllerOutput!

    private let containerView: RoundedContainerView
    private let blurEffectView = UIVisualEffectView()

    private let titleLabel = UILabel()
    private let buttonStackView = UIStackView()
    private let emailAuthButton = NGButton()
    private let googleAuthButton = NGButton()
    private let appleAuthButton = NGButton()
    
    private let ngTheme: NGThemeColors
    
    init(ngTheme: NGThemeColors) {
        self.ngTheme = ngTheme
        self.containerView = RoundedContainerView(ngTheme: ngTheme)
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        super.loadView()
        view.backgroundColor = .clear
        
        let blurEffect = UIBlurEffect(style: ngTheme.blurStyle)
        blurEffectView.effect = blurEffect
        blurEffectView.frame = view.bounds
        blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        blurEffectView.alpha = 0
        view.addSubview(blurEffectView)

        containerView.onDismiss = { [weak self] in
            UIView.animate(withDuration: 0.2) {
                self?.blurEffectView.alpha = 0
            } completion: { _ in
                self?.output.onDismiss()
            }
        }
        
        view.addSubview(containerView)
        containerView.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview()
            $0.bottom.lessThanOrEqualToSuperview()
        }
        
        titleLabel.text = "Log in to your Nicegram profile account"
        titleLabel.font = .systemFont(ofSize: 28.0, weight: .bold)
        titleLabel.numberOfLines = 2
        titleLabel.textColor = ngTheme.reverseTitleColor
        containerView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(16.0)
        }
        
        let firstSeparatorView = UIView()
        firstSeparatorView.backgroundColor = ngTheme.separatorColor
        containerView.addSubview(firstSeparatorView)
        firstSeparatorView.snp.makeConstraints {
            $0.height.equalTo(1.0)
            $0.top.equalTo(titleLabel.snp.bottom).offset(24.0)
            $0.leading.trailing.equalToSuperview().inset(16.0)
        }
        
        buttonStackView.alignment = .fill
        buttonStackView.distribution = .fill
        buttonStackView.axis = .vertical
        buttonStackView.spacing = 16.0
        containerView.addSubview(buttonStackView)
        buttonStackView.snp.makeConstraints {
            $0.top.equalTo(firstSeparatorView.snp.bottom).offset(24.0)
            $0.bottom.equalToSuperview().inset(100.0)
            $0.leading.trailing.equalToSuperview().inset(16.0)
        }
        
        buttonStackView.addArrangedSubview(emailAuthButton)
        emailAuthButton.snp.makeConstraints {
            $0.height.equalTo(54)
            $0.leading.trailing.equalToSuperview()
        }
        buttonStackView.addArrangedSubview(googleAuthButton)
        googleAuthButton.snp.makeConstraints {
            $0.height.equalTo(54)
            $0.leading.trailing.equalToSuperview()
        }
        buttonStackView.addArrangedSubview(appleAuthButton)
        appleAuthButton.snp.makeConstraints {
            $0.height.equalTo(54)
            $0.leading.trailing.equalToSuperview()
        }
        
        containerView.setupFooter(type: .withFooter)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        output.onViewDidLoad()
        
        emailAuthButton.touchUpInside = { [weak self] in
            self?.output.onLoginWithEmail()
        }
        googleAuthButton.touchUpInside = { [weak self] in
            guard let self = self else { return }
            self.output.onLoginWithGoogle(with: self)
        }
        appleAuthButton.touchUpInside = { [weak self] in
            guard let self = self else { return }
            self.output.onLoginWithApple(with: self)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.isNavigationBarHidden = true
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        UIView.animate(withDuration: 0.3) {
            self.blurEffectView.alpha = 1
            self.titleLabel.snp.remakeConstraints {
                $0.top.equalTo(self.view.safeArea.top).inset(28.0)
                $0.leading.trailing.equalToSuperview().inset(16.0)
            }
            self.view.layoutSubviews()
            self.containerView.layoutSubviews()
        }
    }
}

extension AssistantAuthViewController: AssistantAuthPresenterOutput {
    func displayLoginWithEmail(title: String?, image: UIImage?) {
        emailAuthButton.backgroundColor = .white
        emailAuthButton.setTitleColor(.black, for: .normal)
        emailAuthButton.setTitle(title, for: .normal)
        emailAuthButton.titleLabel?.font = .systemFont(ofSize: 13.0, weight: .semibold)
        emailAuthButton.setImage(image, for: .normal)
        emailAuthButton.semanticContentAttribute = .forceLeftToRight
    }
    
    func displayLoginWithGoogle(title: String?, image: UIImage?) {
        googleAuthButton.backgroundColor = .white
        googleAuthButton.setTitleColor(.black, for: .normal)
        googleAuthButton.setTitle(title, for: .normal)
        googleAuthButton.titleLabel?.font = .systemFont(ofSize: 13.0, weight: .semibold)
        googleAuthButton.setImage(image, for: .normal)
        googleAuthButton.semanticContentAttribute = .forceLeftToRight
    }
    
    func displayLoginWithApple(title: String?, image: UIImage?) {
        appleAuthButton.backgroundColor = .white
        appleAuthButton.setTitleColor(.black, for: .normal)
        appleAuthButton.setTitle(title, for: .normal)
        appleAuthButton.titleLabel?.font = .systemFont(ofSize: 13.0, weight: .semibold)
        appleAuthButton.setImage(image, for: .normal)
        appleAuthButton.tintColor = .black
        appleAuthButton.semanticContentAttribute = .forceLeftToRight
    }
}

extension AssistantAuthViewController: RequiringPresentationDelegate {
    func presentingViewController() -> UIViewController {
        return self
    }
}
