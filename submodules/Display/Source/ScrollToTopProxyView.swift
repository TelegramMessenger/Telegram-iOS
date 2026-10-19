import UIKit
import AsyncDisplayKit

class ScrollToTopView: UIScrollView, UIScrollViewDelegate {
    var action: (() -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.isOpaque = false
        self.delegate = self
        self.scrollsToTop = true
        self.contentInsetAdjustmentBehavior = .never
        if #available(iOS 17.0, *) {
            self.allowsKeyboardScrolling = false
        }
        if #available(iOS 26.0, *) {
            // An invisible tap target over the status bar, above every screen: UIKit's automatic edge effects would blur
            // whatever passes under it. The chat → profile expansion showed it as a haze over the top of the screen and
            // its corners, where the card's edge moves against the chat.
            self.topEdgeEffect.isHidden = true
            self.bottomEdgeEffect.isHidden = true
            self.leftEdgeEffect.isHidden = true
            self.rightEdgeEffect.isHidden = true
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var frame: CGRect {
        didSet {
            let frame = self.frame
            self.contentSize = CGSize(width: frame.width, height: frame.height + 1000.0)
            self.contentOffset = CGPoint(x: 0.0, y: 1000.0)
        }
    }
    
    @objc func scrollViewShouldScrollToTop(_ scrollView: UIScrollView) -> Bool {
        if let action = self.action {
            action()
        }
        
        return false
    }
}

class ScrollToTopNode: ASDisplayNode {
    init(action: @escaping () -> Void) {
        super.init()
        
        self.setViewBlock({
            let view = ScrollToTopView(frame: CGRect())
            view.action = action
            return view
        })
    }
}

final class WindowScrollToTopProxyViews {
    enum Mode {
        case disabled
        case flat(frame: CGRect)
        case split(masterFrame: CGRect, detailFrame: CGRect)
    }

    private let flatView: ScrollToTopView
    private let masterView: ScrollToTopView
    private let detailView: ScrollToTopView

    init(scrollToTop: @escaping (NavigationSplitContainerScrollToTop) -> Void) {
        self.flatView = ScrollToTopView(frame: CGRect())
        self.masterView = ScrollToTopView(frame: CGRect())
        self.detailView = ScrollToTopView(frame: CGRect())

        self.flatView.action = {
            scrollToTop(.master)
        }
        self.masterView.action = {
            scrollToTop(.master)
        }
        self.detailView.action = {
            scrollToTop(.detail)
        }
    }

    deinit {
        self.disable(self.flatView)
        self.disable(self.masterView)
        self.disable(self.detailView)
    }

    func update(window: UIWindow?, mode: Mode, referenceView: UIView?) {
        guard let window else {
            self.disable(self.flatView)
            self.disable(self.masterView)
            self.disable(self.detailView)
            return
        }

        switch mode {
        case .disabled:
            self.disable(self.flatView)
            self.disable(self.masterView)
            self.disable(self.detailView)
        case let .flat(frame):
            self.activate(self.flatView, in: window, frame: frame, referenceView: referenceView)
            self.disable(self.masterView)
            self.disable(self.detailView)
        case let .split(masterFrame, detailFrame):
            self.disable(self.flatView)
            self.activate(self.masterView, in: window, frame: masterFrame, referenceView: referenceView)
            self.activate(self.detailView, in: window, frame: detailFrame, referenceView: referenceView)
        }
    }

    private func activate(_ view: ScrollToTopView, in window: UIWindow, frame: CGRect, referenceView: UIView?) {
        if let referenceView, referenceView.superview === window {
            if view.superview !== window {
                view.removeFromSuperview()
            }
            window.insertSubview(view, aboveSubview: referenceView)
        } else if view.superview !== window {
            view.removeFromSuperview()
            window.addSubview(view)
        }

        view.isHidden = false
        view.scrollsToTop = true
        view.frame = frame
    }

    private func disable(_ view: ScrollToTopView) {
        view.scrollsToTop = false
        view.isHidden = true
        view.removeFromSuperview()
    }
}
