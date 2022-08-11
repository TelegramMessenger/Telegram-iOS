import UIKit
import SnapKit
import NGTextFields
import NGButton
import NGExtensions
import EsimAuth
import NGTheme
import NGToast
import NGLoadingIndicator
import NGAlert

typealias LoginViewControllerInput = LoginPresenterOutput

protocol LoginViewControllerOutput {
    func onViewDidLoad()
    
    func onLoginWithGoogle(with view: RequiringPresentationDelegate)
    func onLoginWithApple(with view: RequiringPresentationDelegate)
    func onLoginWithTelegram()
    
    func handleEmailInput(inputText: String, onFinishEditing: Bool)
    func handlePasswordInput(inputText: String, onFinishEditing: Bool)
    func handleCredentials(email: String, password: String)
    func handleLogin()
    func handleDismiss()
    
    func onSignIn()
    func onForgotPassword()
}

extension LoginViewController: ClosureBindable { }

final class LoginViewController: UIViewController {
    var output: LoginViewControllerOutput!

    private weak var tapKeyboardDismissRecognizer: UITapGestureRecognizer?

    private let scrollView = UIScrollView()
    private let containerView = UIView()

    private let titleLabel = UILabel()
    private let emailField = TitleTextField()
    private let passwordField = TitleTextField()
    private let questionLabel = UILabel()
    private let signUpButton = ActionButton()
    private let continueLabel = UILabel()
    private let forgotPasswordButton = ActionButton()
    private let footerView = UIView()

    private let appleButton = ActionButton()
    private let googleButton = ActionButton()
    private let telegramButton = ActionButton()
    
    private let loginButton: NGButton

    private let ngTheme: NGThemeColors
    
    init(ngTheme: NGThemeColors) {
        self.ngTheme = ngTheme
        self.loginButton = NGButton(ngTheme: ngTheme)
        super.init(nibName: nil, bundle: nil)
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        get {
            return .portrait
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        super.loadView()
        view = UIView()
        view.addSubview(scrollView)
        scrollView.snp.makeConstraints {
            $0.top.equalTo(self.view.safeArea.top)
            $0.leading.trailing.bottom.equalToSuperview()
        }
        scrollView.addSubview(containerView)
        containerView.snp.makeConstraints {
            $0.edges.equalToSuperview()
            $0.width.equalToSuperview()
            $0.height.equalToSuperview().priority(.low)
        }
        containerView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview().inset(16.0)
        }

        let textFieldStackView = UIStackView()
        textFieldStackView.spacing = 24
        textFieldStackView.alignment = .fill
        textFieldStackView.axis = .vertical
        textFieldStackView.distribution = .fill

        textFieldStackView.addArrangedSubview(emailField)
        emailField.snp.makeConstraints {
            $0.height.equalTo(60.0)
            $0.leading.trailing.equalToSuperview()
        }
        textFieldStackView.addArrangedSubview(passwordField)
        passwordField.snp.makeConstraints {
            $0.height.equalTo(60.0)
            $0.leading.trailing.equalToSuperview()
        }

        containerView.addSubview(textFieldStackView)
        textFieldStackView.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(24.0)
            $0.leading.trailing.equalToSuperview().inset(16.0)
        }

        containerView.addSubview(continueLabel)
        continueLabel.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.top.equalTo(textFieldStackView.snp.bottom).offset(80.0)
        }
        
        let leftContinueSeparatorView = UIView()
        leftContinueSeparatorView.backgroundColor = ngTheme.separatorColor
        containerView.addSubview(leftContinueSeparatorView)
        leftContinueSeparatorView.snp.makeConstraints {
            $0.height.equalTo(1.0)
            $0.width.equalTo(32.0)
            $0.centerY.equalTo(continueLabel.snp.centerY)
            $0.trailing.equalTo(continueLabel.snp.leading).offset(-12.0)
        }
        
        let rightContinueSeparatorView = UIView()
        rightContinueSeparatorView.backgroundColor = ngTheme.separatorColor
        containerView.addSubview(rightContinueSeparatorView)
        rightContinueSeparatorView.snp.makeConstraints {
            $0.height.equalTo(1.0)
            $0.width.equalTo(32.0)
            $0.centerY.equalTo(continueLabel.snp.centerY)
            $0.leading.equalTo(continueLabel.snp.trailing).offset(12.0)
        }
        
        let socialsAuthStackView = UIStackView()
        socialsAuthStackView.spacing = 24
        socialsAuthStackView.alignment = .fill
        socialsAuthStackView.axis = .horizontal
        socialsAuthStackView.distribution = .fillEqually
        
        containerView.addSubview(socialsAuthStackView)
        socialsAuthStackView.snp.makeConstraints {
            $0.height.equalTo(44.0)
            $0.width.equalTo(180.0)
            $0.centerX.equalToSuperview()
            $0.top.equalTo(continueLabel.snp.bottom).offset(24.0)
        }
        
        socialsAuthStackView.addArrangedSubview(appleButton)
        socialsAuthStackView.addArrangedSubview(googleButton)
        socialsAuthStackView.addArrangedSubview(telegramButton)
        
        
        footerView.backgroundColor = ngTheme.backgroundColor
        scrollView.addSubview(footerView)
        
        footerView.addSubview(loginButton)
        loginButton.snp.makeConstraints {
            $0.top.equalToSuperview().inset(8.0)
            $0.leading.trailing.equalToSuperview().inset(16.0)
            $0.height.equalTo(54.0)
        }

        footerView.addSubview(forgotPasswordButton)
        forgotPasswordButton.snp.makeConstraints {
            $0.top.equalTo(loginButton.snp.bottom).offset(16.0)
            $0.width.equalTo(120.0)
            $0.leading.equalToSuperview().inset(16.0)
            $0.bottom.equalToSuperview().inset(8.0)
        }
        
        let signUpContainerView = UIStackView()
        signUpContainerView.spacing = 4
        signUpContainerView.alignment = .fill
        signUpContainerView.axis = .horizontal
        signUpContainerView.distribution = .fillProportionally

        signUpContainerView.addArrangedSubview(questionLabel)
        signUpContainerView.addArrangedSubview(signUpButton)

        footerView.addSubview(signUpContainerView)
        signUpContainerView.snp.makeConstraints {
            $0.leading.equalTo(forgotPasswordButton.snp.trailing).offset(8.0)
            $0.top.equalTo(loginButton.snp.bottom).offset(16.0)
            $0.bottom.equalToSuperview().inset(8.0)
            $0.trailing.equalToSuperview().inset(16.0)
        }
        
        footerView.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.bottom.equalTo(self.view.safeArea.bottom).offset(-8.0)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if #available(iOS 11.0, *) {
            scrollView.contentInsetAdjustmentBehavior = .never
        } else {
            automaticallyAdjustsScrollViewInsets = false
        }
        scrollView.showsVerticalScrollIndicator = false
        scrollView.canCancelContentTouches = true
        scrollView.delaysContentTouches = false

        view.backgroundColor = ngTheme.backgroundColor
        scrollView.backgroundColor = ngTheme.backgroundColor
        containerView.backgroundColor = ngTheme.backgroundColor

        let greenView = UIImageView(image: UIImage(named: "NGCheckMark"))
        emailField.textColor = ngTheme.reverseTitleColor
        emailField.placeholderColor = ngTheme.subtitleColor
        emailField.borderActiveColor = ngTheme.separatorColor
        emailField.borderInactiveColor = ngTheme.separatorColor
        emailField.keyboardAppearance = ngTheme.keyboardAppearance
        emailField.rightView = greenView
        emailField.rightViewMode = .never
        emailField.textAlignment = .natural
        emailField.keyboardType = .emailAddress
        emailField.delegate = self
        emailField.autocapitalizationType = .none
        emailField.autocorrectionType = .no
        emailField.addTarget(self, action: #selector(emailTextFieldDidChange(_:)), for: .editingChanged)
        
        let togglePassword = ActionButton()
        togglePassword.setImage(UIImage(named: "ng.password.hide"), for: .normal)
        togglePassword.tintColor = ngTheme.separatorColor
        togglePassword.touchUpInside = { [weak self] in
            guard let self = self else { return }
            self.passwordField.togglePasswordVisibility()
            if self.passwordField.isSecureTextEntry {
                togglePassword.setImage(UIImage(named: "ng.password.hide"), for: .normal)
            } else {
                togglePassword.setImage(UIImage(named: "ng.password.show"), for: .normal)
            }
        }
        passwordField.textColor = ngTheme.reverseTitleColor
        passwordField.placeholderColor = ngTheme.subtitleColor
        passwordField.borderActiveColor = ngTheme.separatorColor
        passwordField.borderInactiveColor = ngTheme.separatorColor
        passwordField.rightView = togglePassword
        passwordField.rightViewMode = .always
        passwordField.delegate = self
        passwordField.keyboardAppearance = ngTheme.keyboardAppearance
        passwordField.addTarget(self, action: #selector(passwordTextFieldDidChange(_:)), for: .editingChanged)

        titleLabel.font = .systemFont(ofSize: 24.0, weight: .bold)
        titleLabel.textColor = ngTheme.reverseTitleColor

        passwordField.isSecureTextEntry = true

        loginButton.buttonState = .disabled
        loginButton.isRounded = true
        loginButton.touchUpInside = { [weak self] in
            self?.view.endEditing(true)
            self?.output.handleLogin()
        }

        signUpButton.backgroundColor = .clear
        signUpButton.setTitleColor(.ngBlueTwo, for: .normal)
        signUpButton.titleLabel?.font = .systemFont(ofSize: 14.0, weight: .semibold)
        signUpButton.titleLabel?.adjustsFontSizeToFitWidth = true
        signUpButton.sizeToFit()
        signUpButton.touchUpInside = { [weak self] in
            self?.view.endEditing(true)
            self?.output.onSignIn()
        }

        forgotPasswordButton.backgroundColor = .clear
        forgotPasswordButton.setTitleColor(.ngBlueTwo, for: .normal)
        forgotPasswordButton.titleLabel?.font = .systemFont(ofSize: 14.0, weight: .semibold)
        forgotPasswordButton.titleLabel?.adjustsFontSizeToFitWidth = true
        forgotPasswordButton.touchUpInside = { [weak self] in
            self?.view.endEditing(true)
            self?.output.onForgotPassword()
        }
        
        questionLabel.textAlignment = .right
        questionLabel.font = .systemFont(ofSize: 14.0)
        questionLabel.textColor = ngTheme.subtitleColor
        questionLabel.adjustsFontSizeToFitWidth = true

        continueLabel.textColor = ngTheme.reverseTitleColor
        continueLabel.textAlignment = .center
        
        appleButton.backgroundColor = .black
        appleButton.setImage(UIImage(named: "NGAppleIcon"), for: .normal)
        appleButton.tintColor = .white
        appleButton.layer.cornerRadius = 22
        appleButton.touchUpInside = { [weak self] in
            guard let self = self else { return }
            self.output.onLoginWithApple(with: self)
        }
        
        googleButton.backgroundColor = .white
        googleButton.setImage(UIImage(named: "NGGoogleIcon"), for: .normal)
        googleButton.layer.cornerRadius = 22
        googleButton.touchUpInside = { [weak self] in
            guard let self = self else { return }
            self.output.onLoginWithGoogle(with: self)
        }
        
        telegramButton.setImage(UIImage(named: "ng.telegram.login"), for: .normal)
        telegramButton.layer.cornerRadius = 22
        telegramButton.touchUpInside = { [weak self] in
            guard let self = self else { return }
            self.output.onLoginWithTelegram()
        }
        
        output.onViewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.isNavigationBarHidden = false
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        tapKeyboardDismissRecognizer = registerKeyboardObservers()
        tapKeyboardDismissRecognizer?.delegate = self
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        removeKeyboardObservers()
    }
    
    @objc func emailTextFieldDidChange(_ textField: UITextField) {
        guard let inputText = textField.text else { return }
        textField.rightViewMode = .never
        output.handleCredentials(email: inputText, password: passwordField.text ?? "")
        output.handleEmailInput(inputText: inputText, onFinishEditing: false)
    }
    
    @objc func passwordTextFieldDidChange(_ textField: UITextField) {
        guard let inputText = textField.text else { return }
        output.handleCredentials(email: emailField.text ?? "", password: inputText)
        output.handlePasswordInput(inputText: inputText, onFinishEditing: false)
    }
}

extension LoginViewController: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        guard let field = textField as? TitleTextField else { return }
        field.showError = false
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        guard let inputText = textField.text else { return }
        if textField == emailField {
            output.handleEmailInput(inputText: inputText, onFinishEditing: true)
        } else if textField == passwordField {
            output.handlePasswordInput(inputText: inputText, onFinishEditing: true)
        }
    }
}

extension LoginViewController: KeyboardPresentable {
    @objc func dismissKeyboard(_ recognizer: UITapGestureRecognizer) {
        view.endEditing(true)
    }

    @objc func keyboardWillShow(_ notification: Notification) {
        let keyboardChange = notification.willShowKeyboard(in: view)
        scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: keyboardChange.height, right: 0)
        UIView.animate(withDuration: 0.3) { 
            self.footerView.snp.remakeConstraints {
                $0.leading.trailing.equalToSuperview()
                $0.bottom.equalTo(self.view.snp.bottom).offset(-keyboardChange.height)
            }
            self.scrollView.layoutIfNeeded()
        }
    }
    
    @objc func keyboardWillHide(_ notification: Notification) {
        scrollView.contentInset = UIEdgeInsets.zero
        UIView.animate(withDuration: 0.3) { 
            self.footerView.snp.remakeConstraints {
                $0.leading.trailing.equalToSuperview()
                $0.bottom.equalTo(self.view.safeArea.bottom).offset(-8)
            }
            self.scrollView.layoutIfNeeded()
        }
    }
}

extension LoginViewController: UIGestureRecognizerDelegate {
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                                  shouldReceive touch: UITouch) -> Bool {
        return touch.view != signUpButton && touch.view != loginButton && touch.view != forgotPasswordButton
    }
}


extension LoginViewController: LoginPresenterOutput {
    func display(titleText: String?) {
        titleLabel.text = titleText
    }
    
    func display(emailPlaceholder: String?) {
        emailField.placeholder = emailPlaceholder
    }
    
    func display(passwordPlaceholder: String?) {
        passwordField.placeholder = passwordPlaceholder
    }
    
    func display(loginTitleText: String?) {
        loginButton.setTitle(loginTitleText, for: .normal)
    }
    
    func display(signUpTitleText: String?) {
        signUpButton.setTitle(signUpTitleText, for: .normal)
    }
    
    func display(forgotPasswordText: String?) {
        forgotPasswordButton.setTitle(forgotPasswordText, for: .normal)
    }
    
    func display(questionText: String?) {
        questionLabel.text = questionText
    }
    
    func display(continueText: String?) {
        continueLabel.text = continueText
    }
    
    func displayValidEmail() {
        emailField.rightViewMode = .unlessEditing
    }
    
    func display(isLoginEnabled: Bool) {
        loginButton.buttonState = isLoginEnabled ? .enabled : .disabled
    }
    
    func display(error: String?) {
        NGToast.showErrorToast(message: error ?? "Unexpected error")
    }
    
    func display(isLoading: Bool) {
        if isLoading {
            NGLoadingIndicator.shared.startAnimating(on: self.view)
        } else {
            NGLoadingIndicator.shared.stopAnimating()
        }
    }
    
    func display(emailError: String?) {
        emailField.showError = true
    }
    
    func display(passwordError: String?) { 
        passwordField.showError = true
    }
    
    func displayAlert(message: String, titleText: String) {
        NGAlertController.showDefaultAlert(title: nil, image: UIImage(named: "ng.folder"), subtitle: NSAttributedString(string: message), description: nil, ngTheme: ngTheme, from: self) { alert in
            alert.addAction(title: titleText, style: .preferred(ngTheme: self.ngTheme)) { 
                self.output.handleDismiss()
            }
        }
    }
}

extension LoginViewController: RequiringPresentationDelegate {
    func presentingViewController() -> UIViewController {
        return self
    }
}
