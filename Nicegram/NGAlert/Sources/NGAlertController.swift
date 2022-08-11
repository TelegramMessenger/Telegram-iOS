import UIKit
import SnapKit
import NGButton
import NGTheme

private struct Constants {
    static var animationDuration: TimeInterval { return 0.2 }
    static var minimumScale: CGFloat { return 0.01 }
}

open class NGAlertController: UIViewController {
    
    public struct ActionStyle {
        let backgroundColor: UIColor
        let textColor: UIColor
    }
    
    //  MARK: - UI Elements
    
    private let ngTheme: NGThemeColors
    private let alertView = UIView()
    private let contentView = UIView()
    private let buttonsStack = UIStackView()
    
    //  MARK: - Lifecycle
    
    public init(ngTheme: NGThemeColors) {
        self.ngTheme = ngTheme
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    open override func loadView() {
        view = UIView()
        
        alertView.backgroundColor = ngTheme.backgroundColor
        alertView.layer.cornerRadius = 12
        
        buttonsStack.axis = .vertical
        buttonsStack.spacing = 8
        buttonsStack.layoutMargins = UIEdgeInsets(top: 0, left: 16, bottom: 16, right: 16)
        buttonsStack.isLayoutMarginsRelativeArrangement = true
        
        let stack = UIStackView(arrangedSubviews: [contentView, buttonsStack])
        stack.axis = .vertical
        alertView.addSubview(stack)
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        view.addSubview(alertView)
        
        alertView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalTo(360).priority(999)
        }
    }
    
    public func setContentView(_ v: UIView) {
        contentView.addSubview(v)
        v.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    public func addAction(title: String?, style: ActionStyle, execute: (() -> ())?) {
        let button = CustomButton()
        
        button.display(title: title, image: nil)
        button.touchUpInside = { [weak self] in
            guard let self = self else { return }
            self.dismiss(animated: true) {
                execute?()
            }
        }
        
        // Style
        button.foregroundColor = style.textColor
        button.backgroundColor = style.backgroundColor
        
        // Default
        button.configureTitleLabel { label in
            label.font = .systemFont(ofSize: 16, weight: .semibold)
        }
        button.layer.cornerRadius = 6
        
        button.snp.makeConstraints { make in
            make.height.equalTo(54)
        }
        
        buttonsStack.addArrangedSubview(button)
    }
}

//  MARK: - Styles Factory

public extension NGAlertController.ActionStyle {
    static func preferred(ngTheme: NGThemeColors) -> NGAlertController.ActionStyle {
        return .init(backgroundColor: .ngActiveButton, textColor: .white)
    }
    
    static func yes(ngTheme: NGThemeColors) -> NGAlertController.ActionStyle {
        return .init(backgroundColor: .clear, textColor: ngTheme.reverseTitleColor)
    }
    
    static func no(ngTheme: NGThemeColors) -> NGAlertController.ActionStyle {
        return .init(backgroundColor: .white, textColor: .black)
    }
}
