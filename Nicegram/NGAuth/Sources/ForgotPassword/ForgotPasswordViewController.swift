import UIKit
import SnapKit
import NGTextFields
import NGButton
import NGExtensions
import NGTheme
import NGToast
import NGLocalization
import NGLoadingIndicator

typealias ForgotPasswordViewControllerInput = ForgotPasswordPresenterOutput

protocol ForgotPasswordViewControllerOutput {
    func handleEmailInput(inputText: String)
    func handleForgotPassword(email: String?)
    func handleViewDidLoad()
}

extension ForgotPasswordViewController: ClosureBindable { }

final class ForgotPasswordViewController: UIViewController {
    var output: ForgotPasswordViewControllerOutput!

    private weak var tapKeyboardDismissRecognizer: UITapGestureRecognizer?

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let emailField = TitleTextField()
    private let sendCodeButton: NGButton
    
    private let ngTheme: NGThemeColors
    
    init(ngTheme: NGThemeColors) {
        self.ngTheme = ngTheme
        
        self.sendCodeButton = NGButton(ngTheme: ngTheme)
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        super.loadView()
        view = UIView()
        view.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.top.equalTo(self.view.safeArea.top).offset(16.0)
            $0.leading.trailing.equalToSuperview().inset(16.0)
        }

        view.addSubview(subtitleLabel)
        subtitleLabel.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(12.0)
            $0.leading.trailing.equalToSuperview().inset(16.0)
        }

        view.addSubview(emailField)
        emailField.snp.makeConstraints {
            $0.height.equalTo(60.0)
            $0.leading.trailing.equalToSuperview().inset(16.0)
            $0.top.equalTo(subtitleLabel.snp.bottom).offset(40.0)
        }

        view.addSubview(sendCodeButton)
        sendCodeButton.snp.makeConstraints {
            $0.bottom.equalTo(self.view.safeArea.bottom).offset(-4.0)
            $0.leading.trailing.equalToSuperview().inset(16.0)
            $0.height.equalTo(54.0)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ngTheme.backgroundColor

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
        emailField.addTarget(self, action: #selector(emailTextFieldDidChange(_:)), for: .editingChanged)

        titleLabel.font = .systemFont(ofSize: 24.0, weight: .bold)
        titleLabel.textColor = ngTheme.reverseTitleColor
        titleLabel.textAlignment = .natural

        subtitleLabel.numberOfLines = 0
        subtitleLabel.font = .systemFont(ofSize: 14.0, weight: .regular)
        subtitleLabel.textColor = ngTheme.subtitleColor
        subtitleLabel.textAlignment = .natural

        sendCodeButton.buttonState = .disabled
        sendCodeButton.isRounded = true
        sendCodeButton.touchUpInside = { [weak self] in
            self?.output.handleForgotPassword(email: self?.emailField.text)
        }
        
        output.handleViewDidLoad()
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
        textField.rightViewMode = .never
        guard let inputText = textField.text else { return }
        output.handleEmailInput(inputText: inputText)
    }
}

extension ForgotPasswordViewController: UITextFieldDelegate { 
    func textFieldDidBeginEditing(_ textField: UITextField) {
        guard let field = textField as? TitleTextField else { return }
        field.showError = false
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        guard let inputText = textField.text else { return }
        output.handleEmailInput(inputText: inputText)
    }
}

extension ForgotPasswordViewController: KeyboardPresentable {
    @objc func dismissKeyboard(_ recognizer: UITapGestureRecognizer) {
        view.endEditing(true)
    }

    @objc func keyboardWillShow(_ notification: Notification) {
        let keyboardChange = notification.willShowKeyboard(in: view)
        UIView.animate(withDuration: 0.3) { 
            self.sendCodeButton.snp.updateConstraints {
                $0.bottom.equalTo(self.view.safeArea.bottom).offset(-keyboardChange.height - 4.0)
            }
            self.view.layoutIfNeeded()
        }
    }
    
    @objc func keyboardWillHide(_ notification: Notification) {
        UIView.animate(withDuration: 0.3) { 
            self.sendCodeButton.snp.updateConstraints {
                $0.bottom.equalTo(self.view.safeArea.bottom).offset(-4.0)
            }
            self.view.layoutIfNeeded()
        }
    }
}

extension ForgotPasswordViewController: UIGestureRecognizerDelegate {
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                                  shouldReceive touch: UITouch) -> Bool {
        return touch.view != sendCodeButton
    }
}


extension ForgotPasswordViewController: ForgotPasswordViewControllerInput {
    func display(emailPlaceholder: String?) {
        emailField.placeholder = emailPlaceholder
    }
    
    func display(titleText: String?) {
        titleLabel.text = titleText
    }
    
    func display(subtitleText: String?) {
        subtitleLabel.text = subtitleText
    }
    
    func display(sendCodeTitleText: String?) {
        sendCodeButton.setTitle(sendCodeTitleText, for: .normal)
    }
    
    func display(isEmailValid: Bool) {
        emailField.rightViewMode = isEmailValid ? .unlessEditing : .never
        sendCodeButton.buttonState = isEmailValid ? .enabled : .disabled
    }
    
    func display(emailError: String?) {
        emailField.showError = true
    }
    
    func displaySuccess() {
        NGToast.showSuccessToast()
    }
    
    func display(isLoading: Bool) {
        if isLoading {
            NGLoadingIndicator.shared.startAnimating(on: self.view)
        } else {
            NGLoadingIndicator.shared.stopAnimating()
        }
    }
    
    func display(error: String?) {
        NGToast.showErrorToast(message: error ?? "Unexpected error")
    }
}
