import UIKit

class PopupPresentationController: UIPresentationController {
    
    //  MARK: - Customization
    
    private let horizontalPadding: CGFloat
    private let verticalPadding: CGFloat
    private let blurStyle: UIBlurEffect.Style
    
    //  MARK: - Lifecycle
    
    init(presentedViewController: UIViewController, presenting presentingViewController: UIViewController?, horizontalPadding: CGFloat, verticalPadding: CGFloat, blurStyle: UIBlurEffect.Style) {
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
        self.blurStyle = blurStyle
        
        super.init(presentedViewController: presentedViewController, presenting: presentingViewController)
    }
    
    //  MARK: - UI Elements
    
    private lazy var blurView: UIVisualEffectView = {
        let view = UIVisualEffectView()
        return view
    }()
    
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
    }
    
    //  MARK: - Presentation
    
    override func presentationTransitionWillBegin() {
        super.presentationTransitionWillBegin()
        
        containerView?.addSubview(blurView)
        
        if let presentedView = presentedView {
            containerView?.addSubview(presentedView)
        }
        
        performAlongsideTransitionIfPossible { [weak self] in
            guard let self = self else { return }
            self.blurView.effect = UIBlurEffect(style: self.blurStyle)
        }
    }
    
    override func presentationTransitionDidEnd(_ completed: Bool) {
        super.presentationTransitionDidEnd(completed)
        
        if !completed {
            self.blurView.removeFromSuperview()
        }
    }
    
    //  MARK: - Dismiss
    
    override func dismissalTransitionWillBegin() {
        super.dismissalTransitionWillBegin()
        
        isDismissInFlight = true
        
        performAlongsideTransitionIfPossible {
            self.blurView.effect = nil
        }
    }
    
    override func dismissalTransitionDidEnd(_ completed: Bool) {
        super.dismissalTransitionDidEnd(completed)
        
        isDismissInFlight = false
        
        if completed {
            self.blurView.removeFromSuperview()
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
