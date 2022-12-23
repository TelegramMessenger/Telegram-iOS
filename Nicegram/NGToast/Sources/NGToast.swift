import UIKit
import SnapKit
import NGExtensions

private struct Constants {
    static var animationDuration: TimeInterval { return 0.5 }
}

open class NGToast: UIView {
    
    //  MARK: - UI Elements
    
    private let contentView = UIView()
    
    //  MARK: - Logic
    
    public var duration: TimeInterval? = 2
    private var autoDismissTimer: Timer?
    
    private var shownVerticalPositionConstraint: Constraint?
    private var hiddenVerticalPositionConstraint: Constraint?
    
    //  MARK: - Lifecycle
    
    public init(topInsetFromSafeArea: CGFloat = 15) {
        super.init(frame: .zero)
        
        let swipeRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(onSwipeUpGesture))
        swipeRecognizer.direction = .up
        addGestureRecognizer(swipeRecognizer)
        
        addSubview(contentView)
        
        contentView.snp.makeConstraints { make in
            make.top.equalTo(safeArea.top).inset(topInsetFromSafeArea)
            make.centerX.equalToSuperview()
            make.leading.equalToSuperview().inset(16)
            make.bottom.equalToSuperview()
        }
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    //  MARK: - Public Functions
    
    public func setContentView(_ view: UIView) {
        contentView.addSubview(view)
        view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    public func show() {
        guard let keyWindow = UIApplication.shared.keyWindow?.subviews.last else { return }
        show(from: keyWindow)
    }
    
    public func show(from view: UIView) {
        view.addSubview(self)
        snp.makeConstraints { make in
            self.hiddenVerticalPositionConstraint = make.bottom.equalTo(view.snp.top).constraint
            self.shownVerticalPositionConstraint = make.top.equalToSuperview().constraint
            make.leading.equalToSuperview()
            make.trailing.equalToSuperview()
        }
        
        updateConstraints(isHidden: true)
        view.layoutIfNeeded()
        
        UIView.animate(withDuration: Constants.animationDuration, delay: 0) {
            self.updateConstraints(isHidden: false)
            view.layoutIfNeeded()
        } completion: { _ in
            if let duration = self.duration {
                self.autoDismissTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
                    self?.hide()
                }
            }
        }
    }
    
    public func hide() {
        autoDismissTimer?.invalidate()
        autoDismissTimer = nil
        
        UIView.animate(withDuration: Constants.animationDuration, delay: 0) {
            self.updateConstraints(isHidden: true)
            self.superview?.layoutIfNeeded()
        } completion: { _ in
            self.removeFromSuperview()
        }
    }
}

//  MARK: - Private Functions

private extension NGToast {
    func updateConstraints(isHidden: Bool) {
        shownVerticalPositionConstraint?.isActive = !isHidden
        hiddenVerticalPositionConstraint?.isActive = isHidden
    }
}

private extension NGToast {
    @objc func onSwipeUpGesture() {
        hide()
    }
}
