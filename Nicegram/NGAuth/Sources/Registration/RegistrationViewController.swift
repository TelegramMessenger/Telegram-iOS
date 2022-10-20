import UIKit
import SnapKit
import NGTextFields
import NGButton
import NGExtensions
import NGTheme
import NGLoadingIndicator
import NGToast
import NGAlert

typealias RegistrationViewControllerInput = RegistrationPresenterOutput

protocol RegistrationViewControllerOutput {
    func onViewDidLoad()
    func onSignUp()
    func checkForRegistration() -> Bool
    func handleDismiss()
    
    func handleFirstNameInput(inputText: String, onFinishEditing: Bool)
    func handleLastNameInput(inputText: String, onFinishEditing: Bool)
    func handleEmailInput(inputText: String, onFinishEditing: Bool)
    func handlePasswordInput(inputText: String, onFinishEditing: Bool)
}

extension RegistrationViewController: ClosureBindable { }

final class RegistrationViewController: UIViewController {
    var output: RegistrationViewControllerOutput!

    private weak var tapKeyboardDismissRecognizer: UITapGestureRecognizer?

    private let scrollView = UIScrollView()
    private let containerView = UIView()

    private let titleLabel = UILabel()
    private let firstNameField = TitleTextField()
    private let lastNameField = TitleTextField()
    private let emailField = TitleTextField()
    private let passwordField = TitleTextField()
    private let questionLabel = UILabel()
    private let loginButton = ActionButton()
    private let footerView = UIView()
    
    private let registerButton: NGButton

    private let ngTheme: NGThemeColors
    
    init(ngTheme: NGThemeColors) {
        self.ngTheme = ngTheme
        self.registerButton = NGButton(ngTheme: ngTheme)
        super.init(nibName: nil, bundle: nil)
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

        textFieldStackView.addArrangedSubview(firstNameField)
        firstNameField.snp.makeConstraints {
            $0.height.equalTo(60.0)
            $0.leading.trailing.equalToSuperview()
        }
        textFieldStackView.addArrangedSubview(lastNameField)
        lastNameField.snp.makeConstraints {
            $0.height.equalTo(60.0)
            $0.leading.trailing.equalToSuperview()
        }
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
        
        footerView.backgroundColor = ngTheme.backgroundColor
        containerView.addSubview(footerView)
        
        footerView.addSubview(registerButton)
        registerButton.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(16.0)
            $0.top.equalToSuperview().inset(8.0)
            $0.height.equalTo(54.0)
        }

        let loginContainerView = UIStackView()
        loginContainerView.spacing = 8
        loginContainerView.alignment = .fill
        loginContainerView.axis = .horizontal
        loginContainerView.distribution = .fill

        loginContainerView.addArrangedSubview(questionLabel)
        loginContainerView.addArrangedSubview(loginButton)

        footerView.addSubview(loginContainerView)
        loginContainerView.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.width.equalTo(190.0)
            $0.top.equalTo(registerButton.snp.bottom).offset(16.0)
            $0.bottom.equalToSuperview().inset(8.0)
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

        view.backgroundColor = ngTheme.backgroundColor
        scrollView.backgroundColor = ngTheme.backgroundColor
        containerView.backgroundColor = ngTheme.backgroundColor

        firstNameField.delegate = self
        firstNameField.textColor = ngTheme.reverseTitleColor
        firstNameField.placeholderColor = ngTheme.subtitleColor
        firstNameField.borderActiveColor = ngTheme.separatorColor
        firstNameField.borderInactiveColor = ngTheme.separatorColor
        firstNameField.keyboardAppearance = ngTheme.keyboardAppearance
        firstNameField.textAlignment = .natural


        lastNameField.delegate = self
        lastNameField.textColor = ngTheme.reverseTitleColor
        lastNameField.placeholderColor = ngTheme.subtitleColor
        lastNameField.borderActiveColor = ngTheme.separatorColor
        lastNameField.borderInactiveColor = ngTheme.separatorColor
        lastNameField.keyboardAppearance = ngTheme.keyboardAppearance
        lastNameField.textAlignment = .natural

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
        passwordField.keyboardAppearance = ngTheme.keyboardAppearance
        passwordField.rightView = togglePassword
        passwordField.rightViewMode = .always
        passwordField.isSecureTextEntry = true
        passwordField.delegate = self
        
        let greenView = UIImageView(image: UIImage(named: "NGCheckMark"))
        emailField.textColor = ngTheme.reverseTitleColor
        emailField.placeholderColor = ngTheme.subtitleColor
        emailField.borderActiveColor = ngTheme.separatorColor
        emailField.borderInactiveColor = ngTheme.separatorColor
        emailField.keyboardAppearance = ngTheme.keyboardAppearance
        emailField.rightView = greenView
        emailField.rightViewMode = .never
        emailField.keyboardType = .emailAddress
        emailField.autocapitalizationType = .none
        emailField.autocorrectionType = .no
        emailField.textAlignment = .natural

        emailField.delegate = self

        titleLabel.font = .systemFont(ofSize: 24.0, weight: .bold)
        titleLabel.textColor = ngTheme.reverseTitleColor

        passwordField.isSecureTextEntry = true

        registerButton.buttonState = .disabled
        registerButton.isRounded = true
        registerButton.touchUpInside = { [weak self] in
            guard let self = self else { return }
            self.output.onSignUp()
        }

        questionLabel.textAlignment = .right
        questionLabel.font = .systemFont(ofSize: 14.0)
        questionLabel.textColor = ngTheme.subtitleColor

        loginButton.backgroundColor = .clear
        loginButton.setTitleColor(.ngBlueTwo, for: .normal)
        loginButton.titleLabel?.font = .systemFont(ofSize: 14.0, weight: .semibold)
        loginButton.touchUpInside = { [weak self] in
            guard let self = self else { return }
            self.output.handleDismiss()
        }
        
        firstNameField.addTarget(self, action: #selector(firstNameFieldDidChange(_:)), for: .editingChanged)
        lastNameField.addTarget(self, action: #selector(lastNameFieldDidChange(_:)), for: .editingChanged)
        emailField.addTarget(self, action: #selector(emailFieldDidChange(_:)), for: .editingChanged)
        passwordField.addTarget(self, action:  #selector(passwordFieldDidChange(_:)), for: .editingChanged)
        
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
    
    @objc func firstNameFieldDidChange(_ textField: UITextField) {
        guard let inputText = textField.text else { return }
        output.handleFirstNameInput(inputText: inputText, onFinishEditing: false)
    }
                                
    @objc func lastNameFieldDidChange(_ textField: UITextField) {
        guard let inputText = textField.text else { return }
        output.handleLastNameInput(inputText: inputText, onFinishEditing: false)
    }
    
    @objc func emailFieldDidChange(_ textField: UITextField) {
        guard let inputText = textField.text else { return }
        textField.rightViewMode = .never
        output.handleEmailInput(inputText: inputText, onFinishEditing: false)
    }
                                
    @objc func passwordFieldDidChange(_ textField: UITextField) {
        guard let inputText = textField.text else { return }
        output.handlePasswordInput(inputText: inputText, onFinishEditing: false)
    }
}

extension RegistrationViewController: KeyboardPresentable {
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
            self.containerView.layoutIfNeeded()
        }
    }
    
    @objc func keyboardWillHide(_ notification: Notification) {
        scrollView.contentInset = UIEdgeInsets.zero
        UIView.animate(withDuration: 0.3) { 
            self.footerView.snp.remakeConstraints {
                $0.leading.trailing.equalToSuperview()
                $0.bottom.equalTo(self.view.safeArea.bottom).offset(-8)
            }
            self.containerView.layoutIfNeeded()
        }
    }
}

extension RegistrationViewController: UITextFieldDelegate {    
    func textFieldDidEndEditing(_ textField: UITextField) {
        guard let inputText = textField.text else { return }
        registerButton.buttonState = output.checkForRegistration() ? .enabled : .disabled
        if textField == emailField {
            output.handleEmailInput(inputText: inputText, onFinishEditing: true)
        } else if textField == passwordField {
            output.handlePasswordInput(inputText: inputText, onFinishEditing: true)
        } else if textField == firstNameField {
            output.handleFirstNameInput(inputText: inputText, onFinishEditing: true)
        } else if textField == lastNameField {
            output.handleLastNameInput(inputText: inputText, onFinishEditing: true)
        }
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        guard let field = textField as? TitleTextField else { return }
        field.showError = false
    }
}


extension RegistrationViewController: UIGestureRecognizerDelegate {
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                                  shouldReceive touch: UITouch) -> Bool {
        return touch.view != registerButton && touch.view != loginButton
    }
}

extension RegistrationViewController: RegistrationViewControllerInput {
    func display(titleText: String?) {
        titleLabel.text = titleText
    }
    
    func display(emailPlaceholder: String?) {
        emailField.placeholder = emailPlaceholder
    }
    
    func display(passwordPlaceholder: String?) {
        passwordField.placeholder = passwordPlaceholder
    }
    
    func display(firstNamePlaceholder: String?) {
        firstNameField.placeholder = firstNamePlaceholder
    }
    
    func display(lastNamePlaceholder: String?) {
        lastNameField.placeholder = lastNamePlaceholder
    }
    
    func display(registrtionText: String?) {
        registerButton.setTitle(registrtionText, for: .normal)
    }
    
    func display(questionText: String?) {
        questionLabel.text = questionText
    }
    
    func display(loginText: String?) {
        loginButton.setTitle(loginText, for: .normal)
    }
    
    func display(firstNameError: String?) {
        firstNameField.showError = true
    }
    
    func display(lastNameError: String?) {
        lastNameField.showError = true
    }
    
    func display(emailError: String?) {
        emailField.showError = true
    }
    
    func display(passwordError: String?) {
        passwordField.errorText = passwordError
        passwordField.showError = true
    }
    
    func displayValidEmail() {
        emailField.rightViewMode = .unlessEditing
    }
    
    func display(error: String?) {
        NGToast.showErrorToast(message: error ?? "Undexpected error")
    }
    
    func display(isRegistEnabled: Bool) {
        registerButton.buttonState = isRegistEnabled ? .enabled : .disabled
    }
    
    func display(isLoading: Bool) {
        if isLoading {
            NGLoadingIndicator.shared.startAnimating(on: self.view)
        } else {
            NGLoadingIndicator.shared.stopAnimating()
        }
    }
    
    func displayAlert(message: String, titleText: String) {
        NGAlertController.showDefaultAlert(title: nil, image: UIImage(named: "ng.folder"), subtitle: NSAttributedString(string: message), description: nil, ngTheme: ngTheme, from: self) { alert in
            alert.addAction(title: titleText, style: .preferred(ngTheme: self.ngTheme)) { 
                self.output.handleDismiss()
            }
        }
    }
}
