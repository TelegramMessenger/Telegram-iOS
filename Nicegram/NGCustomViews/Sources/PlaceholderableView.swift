import UIKit
import SnapKit
import NGButton
import NGLocalization

open class PlaceholderableView<WrappedView: UIView>: UIView {
    
    //  MARK: - UI Elements

    public let wrappedView: WrappedView
    
    private var placeholderView: UIView?
    
    //  MARK: - Public Properties

    public var shouldHideWrappedView = true
    
    //  MARK: - Lifecycle
    
    public init(wrappedView: WrappedView) {
        self.wrappedView = wrappedView
        
        super.init(frame: .zero)
        
        addSubview(wrappedView)
        wrappedView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    //  MARK: - Public Functions

    public func showPlaceholder(_ view: UIView) {
        placeholderView?.removeFromSuperview()

        addSubview(view)
        view.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.top.greaterThanOrEqualToSuperview()
            make.leading.equalToSuperview()
        }
        self.placeholderView = view
        
        wrappedView.isHidden = shouldHideWrappedView
    }
    
    public func hidePlaceholder() {
        placeholderView?.removeFromSuperview()
        placeholderView = nil
        
        wrappedView.isHidden = false
    }
}

//  MARK: - Helpers

public extension PlaceholderableView {
    func showRetryPlaceholder(description: String?, onButtonClick: (() -> ())?) {
        showDefaultPlaceholder(
            image: nil,
            description: mapErrorDescription(description),
            buttonTitle: ngLocalized("Nicegram.Alert.TryAgain") .uppercased(),
            buttonImage: UIImage(named: "ng.refresh"),
            configureView: { view in
                view.alignment = .center
                view.spacing = 24
                view.configureButton { button in
                    button.backgroundColor = .ngLightOrange
                    button.layer.cornerRadius = 8
                    button.insets = UIEdgeInsets(top: 5, left: 8, bottom: 5, right: 8)
                    button.spacing = 6
                    
                    button.configureTitleLabel { label in
                        label.font = .systemFont(ofSize: 12, weight: .semibold)
                    }
                }
                
            },
            onButtonClick: onButtonClick
        )
    }
    
    func showEmptyStatePlaceholder(description: String?, buttonTitle: String?, onButtonClick: (() -> ())?) {
        showDefaultPlaceholder(
            image: UIImage(named: "ng.emptyState"),
            description: description,
            buttonTitle: buttonTitle,
            buttonImage: nil,
            configureView: nil,
            onButtonClick: onButtonClick
        )
    }
    
    func showDefaultPlaceholder(image: UIImage?, description: String?, buttonTitle: String?, buttonImage: UIImage?, configureView: ((DefaultPlaceholderView) -> ())?, onButtonClick: (() -> ())?) {
        let view = DefaultPlaceholderView()
        view.display(image: image, description: description, buttonTitle: buttonTitle, buttonImage: buttonImage)
        configureView?(view)
        view.onButtonClick = onButtonClick
        showPlaceholder(view)
    }
}
