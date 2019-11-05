import UIKit

enum NavigationTransition {
    case Push
    case Pop
}

private let shadowWidth: CGFloat = 16.0

private func generateShadow() -> UIImage? {
    return UIImage(named: "NavigationShadow", in: Bundle(for: NavigationBackButtonNode.self), compatibleWith: nil)?.precomposed().resizableImage(withCapInsets: UIEdgeInsets(), resizingMode: .tile)
}

private let shadowImage = generateShadow()

class NavigationTransitionCoordinator {
    private var _progress: CGFloat = 0.0
    var progress: CGFloat {
        get {
            return self._progress
        }
        set(value) {
            self._progress = value
            self.updateProgress(transition: .immediate)
        }
    }
    
    private let container: UIView
    private let transition: NavigationTransition
    let topView: UIView
    private let viewSuperview: UIView?
    let bottomView: UIView
    private let topNavigationBar: NavigationBar?
    private let bottomNavigationBar: NavigationBar?
    private let dimView: UIView
    private let shadowView: UIImageView
    
    private let inlineNavigationBarTransition: Bool
    
    private(set) var animatingCompletion = false
    private var currentCompletion: (() -> Void)?
    private var didUpdateProgress: ((CGFloat, ContainedViewLayoutTransition) -> Void)?
    
    init(transition: NavigationTransition, container: UIView, topView: UIView, topNavigationBar: NavigationBar?, bottomView: UIView, bottomNavigationBar: NavigationBar?, didUpdateProgress: ((CGFloat, ContainedViewLayoutTransition) -> Void)? = nil) {
        self.transition = transition
        self.container = container
        self.didUpdateProgress = didUpdateProgress
        self.topView = topView
        switch transition {
            case .Push:
                self.viewSuperview = bottomView.superview
            case .Pop:
                self.viewSuperview = topView.superview
        }
        self.bottomView = bottomView
        self.topNavigationBar = topNavigationBar
        self.bottomNavigationBar = bottomNavigationBar
        self.dimView = UIView()
        self.dimView.backgroundColor = UIColor.black
        self.shadowView = UIImageView(image: shadowImage)
        
        if let topNavigationBar = topNavigationBar, let bottomNavigationBar = bottomNavigationBar, !topNavigationBar.isHidden, !bottomNavigationBar.isHidden, topNavigationBar.canTransitionInline, bottomNavigationBar.canTransitionInline, topNavigationBar.item?.leftBarButtonItem == nil {
            var topFrame = topNavigationBar.view.convert(topNavigationBar.bounds, to: container)
            var bottomFrame = bottomNavigationBar.view.convert(bottomNavigationBar.bounds, to: container)
            topFrame.origin.x = 0.0
            bottomFrame.origin.x = 0.0
            self.inlineNavigationBarTransition = true// topFrame.equalTo(bottomFrame)
        } else {
            self.inlineNavigationBarTransition = false
        }
        
        switch transition {
            case .Push:
                self.viewSuperview?.insertSubview(topView, belowSubview: topView)
            case .Pop:
                self.viewSuperview?.insertSubview(bottomView, belowSubview: topView)
        }
        
        self.viewSuperview?.insertSubview(self.dimView, belowSubview: topView)
        self.viewSuperview?.insertSubview(self.shadowView, belowSubview: dimView)
        
        self.maybeCreateNavigationBarTransition()
        self.updateProgress(transition: .immediate)
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateProgress(transition: ContainedViewLayoutTransition) {
        let position: CGFloat
        switch self.transition {
            case .Push:
                position = 1.0 - progress
            case .Pop:
                position = progress
        }
        
        var dimInset: CGFloat = 0.0
        if let bottomNavigationBar = self.bottomNavigationBar , self.inlineNavigationBarTransition {
            dimInset = bottomNavigationBar.frame.maxY
        }
        
        let containerSize = self.container.bounds.size
        
        self.topView.frame = CGRect(origin: CGPoint(x: floorToScreenPixels(position * containerSize.width), y: 0.0), size: containerSize)
        self.dimView.frame = CGRect(origin: CGPoint(x: 0.0, y: dimInset), size: CGSize(width: max(0.0, self.topView.frame.minX), height: self.container.bounds.size.height - dimInset))
        self.shadowView.frame = CGRect(origin: CGPoint(x: self.dimView.frame.maxX - shadowWidth, y: dimInset), size: CGSize(width: shadowWidth, height: containerSize.height - dimInset))
        self.dimView.alpha = (1.0 - position) * 0.15
        self.shadowView.alpha = (1.0 - position) * 0.9
        self.bottomView.frame = CGRect(origin: CGPoint(x: ((position - 1.0) * containerSize.width * 0.3), y: 0.0), size: containerSize)
        
        self.updateNavigationBarTransition()
        
        self.didUpdateProgress?(self.progress, transition)
    }
    
    func updateNavigationBarTransition() {
        if let topNavigationBar = self.topNavigationBar, let bottomNavigationBar = self.bottomNavigationBar, self.inlineNavigationBarTransition {
            let position: CGFloat
            switch self.transition {
                case .Push:
                    position = 1.0 - progress
                case .Pop:
                    position = progress
            }
            
            topNavigationBar.transitionState = NavigationBarTransitionState(navigationBar: bottomNavigationBar, transition: self.transition, role: .top, progress: position)
            bottomNavigationBar.transitionState = NavigationBarTransitionState(navigationBar: topNavigationBar, transition: self.transition, role: .bottom, progress: position)
        }
    }
    
    func maybeCreateNavigationBarTransition() {
        if let topNavigationBar = self.topNavigationBar, let bottomNavigationBar = self.bottomNavigationBar, self.inlineNavigationBarTransition {
            let position: CGFloat
            switch self.transition {
                case .Push:
                    position = 1.0 - progress
                case .Pop:
                    position = progress
            }
            
            topNavigationBar.transitionState = NavigationBarTransitionState(navigationBar: bottomNavigationBar, transition: self.transition, role: .top, progress: position)
            bottomNavigationBar.transitionState = NavigationBarTransitionState(navigationBar: topNavigationBar, transition: self.transition, role: .bottom, progress: position)
        }
    }
    
    func endNavigationBarTransition() {
        if let topNavigationBar = self.topNavigationBar, let bottomNavigationBar = self.bottomNavigationBar, self.inlineNavigationBarTransition {
            topNavigationBar.transitionState = nil
            bottomNavigationBar.transitionState = nil
        }
    }
    
    func animateCancel(_ completion: @escaping () -> ()) {
        self.currentCompletion = completion
        
        UIView.animate(withDuration: 0.1, delay: 0.0, options: UIView.AnimationOptions(), animations: { () -> Void in
            self.progress = 0.0
        }) { (completed) -> Void in
            switch self.transition {
                case .Push:
                    if let viewSuperview = self.viewSuperview {
                        viewSuperview.addSubview(self.bottomView)
                    } else {
                        self.bottomView.removeFromSuperview()
                    }
                    self.topView.removeFromSuperview()
                case .Pop:
                    if let viewSuperview = self.viewSuperview {
                        viewSuperview.addSubview(self.topView)
                    } else {
                        self.topView.removeFromSuperview()
                    }
                    self.bottomView.removeFromSuperview()
            }
            
            self.dimView.removeFromSuperview()
            self.shadowView.removeFromSuperview()
            
            self.endNavigationBarTransition()
            
            if let currentCompletion = self.currentCompletion {
                self.currentCompletion = nil
                currentCompletion()
            }
        }
    }
    
    func complete() {
        self.animatingCompletion = true
        
        self.progress = 1.0
        
        self.dimView.removeFromSuperview()
        self.shadowView.removeFromSuperview()
        
        self.endNavigationBarTransition()
        
        if let currentCompletion = self.currentCompletion {
            self.currentCompletion = nil
            currentCompletion()
        }
    }
    
    func animateCompletion(_ velocity: CGFloat, completion: @escaping () -> ()) {
        self.animatingCompletion = true
        let distance = (1.0 - self.progress) * self.container.bounds.size.width
        self.currentCompletion = completion
        let f = {
            /*switch self.transition {
                case .Push:
                    if let viewSuperview = self.viewSuperview {
                        viewSuperview.addSubview(self.bottomView)
                    } else {
                        self.bottomView.removeFromSuperview()
                    }
                case .Pop:
                    if let viewSuperview = self.viewSuperview {
                        viewSuperview.addSubview(self.topView)
                    } else {
                        self.topView.removeFromSuperview()
                    }
            }*/
            
            self.dimView.removeFromSuperview()
            self.shadowView.removeFromSuperview()
            
            self.endNavigationBarTransition()
            
            if let currentCompletion = self.currentCompletion {
                self.currentCompletion = nil
                currentCompletion()
            }
        }
        
        if abs(velocity) < CGFloat.ulpOfOne && abs(self.progress) < CGFloat.ulpOfOne {
            UIView.animate(withDuration: 0.5, delay: 0.0, options: UIView.AnimationOptions(rawValue: 7 << 16), animations: {
                self.progress = 1.0
            }, completion: { _ in
                f()
            })
        } else {
            UIView.animate(withDuration: Double(max(0.05, min(0.2, abs(distance / velocity)))), delay: 0.0, options:UIView.AnimationOptions(), animations: { () -> Void in
                self.progress = 1.0
            }) { (completed) -> Void in
                f()
            }
        }
    }
}
