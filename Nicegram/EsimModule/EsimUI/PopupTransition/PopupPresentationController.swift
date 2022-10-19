import UIKit

class PopupPresentationController: UIPresentationController {
    
    enum BackdropStyle {
        case blur(UIBlurEffect.Style)
        case shadow(UIColor)
    }
    
    //  MARK: - Customization
    
    private let horizontalPadding: CGFloat
    private let verticalPadding: CGFloat
    private let backdropStyle: BackdropStyle
    
    //  MARK: - Lifecycle
    
    init(presentedViewController: UIViewController, presenting presentingViewController: UIViewController?, horizontalPadding: CGFloat, verticalPadding: CGFloat, backdropStyle: BackdropStyle) {
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
        self.backdropStyle = backdropStyle
        
        super.init(presentedViewController: presentedViewController, presenting: presentingViewController)
    }
    
    //  MARK: - UI Elements
    
    private lazy var blurView = UIVisualEffectView()
    private lazy var shadowView = UIView()
    
    //  MARK: - Internal Logic
    
    private var isDismissInFlight = false
    
    //  MARK: - Layout
    
    override var frameOfPresentedViewInContainerView: CGRect {
        return calculatePresentedViewFrame()
    }
    
    override func containerViewDidLayoutSubviews() {
        super.containerViewDidLayoutSubviews()
        
        guard !isDismissInFlight else { return }
        
        presentedView?.frame = frameOfPresentedViewInContainerView
        blurView.frame = containerView?.bounds ?? .zero
        shadowView.frame = containerView?.bounds ?? .zero
    }
    
    //  MARK: - Presentation
    
    override func presentationTransitionWillBegin() {
        super.presentationTransitionWillBegin()
        
        switch backdropStyle {
        case .blur(_):
            containerView?.addSubview(blurView)
        case .shadow(let color):
            shadowView.backgroundColor = color
            shadowView.alpha = 0
            containerView?.addSubview(shadowView)
        }
        
        if let presentedView = presentedView {
            containerView?.addSubview(presentedView)
        }
        
        performAlongsideTransitionIfPossible { [weak self] in
            guard let self = self else { return }
            
            switch self.backdropStyle {
            case .blur(let style):
                self.blurView.effect = UIBlurEffect(style: style)
            case .shadow(_):
                self.shadowView.alpha = 1
            }
        }
    }
    
    override func presentationTransitionDidEnd(_ completed: Bool) {
        super.presentationTransitionDidEnd(completed)
        
        if !completed {
            self.blurView.removeFromSuperview()
            self.shadowView.removeFromSuperview()
        }
    }
    
    //  MARK: - Dismiss
    
    override func dismissalTransitionWillBegin() {
        super.dismissalTransitionWillBegin()
        
        isDismissInFlight = true
        
        performAlongsideTransitionIfPossible { [weak self] in
            self?.blurView.effect = nil
            self?.shadowView.alpha = 0
        }
    }
    
    override func dismissalTransitionDidEnd(_ completed: Bool) {
        super.dismissalTransitionDidEnd(completed)
        
        isDismissInFlight = false
        
        if completed {
            self.blurView.removeFromSuperview()
            self.shadowView.removeFromSuperview()
        }
    }
}

//  MARK: - Private Functions

private extension PopupPresentationController {
    func calculatePresentedViewFrame() -> CGRect {
        guard let containerView = containerView,
              let presentedView = presentedView else { return .zero}
        
        let safeAreaInsets: UIEdgeInsets
        if #available(iOS 11.0, *) {
            safeAreaInsets = containerView.safeAreaInsets
        } else {
            safeAreaInsets = .zero
        }
        
        let availableSize = containerView.bounds
            .inset(by: safeAreaInsets)
            .insetBy(dx: horizontalPadding, dy: verticalPadding)
            .size
        
        var layoutSize = presentedView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        let targetWidth = min(layoutSize.width, availableSize.width)
        let targetHeight = UIView.layoutFittingCompressedSize.height
        let targetSize = CGSize(width: targetWidth, height: targetHeight)
        
        layoutSize = presentedView.systemLayoutSizeFitting(targetSize, withHorizontalFittingPriority: .required, verticalFittingPriority: .defaultLow)
        
        let width = min(layoutSize.width, availableSize.width)
        let height = min(layoutSize.height, availableSize.height)
        let size = CGSize(width: width, height: height)
        
        let center = containerView.center
        let originX = center.x - size.width / 2
        let originY = center.y - size.height / 2
        let origin = CGPoint(x: originX, y: originY)
        return CGRect(origin: origin, size: size)
    }
    
    func performAlongsideTransitionIfPossible(_ block: @escaping () -> Void) {
        guard let coordinator = self.presentedViewController.transitionCoordinator else {
            block()
            return
        }

        coordinator.animate(alongsideTransition: { (_) in
            block()
        }, completion: nil)
    }
}
