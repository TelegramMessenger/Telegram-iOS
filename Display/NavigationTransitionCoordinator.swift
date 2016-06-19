import UIKit

enum NavigationTransition {
    case Push
    case Pop
}

private let shadowWidth: CGFloat = 16.0

private func generateShadow() -> UIImage? {
    return UIImage(named: "NavigationShadow", in: Bundle(for: NavigationBackButtonNode.self), compatibleWith: nil)?.precomposed().resizableImage(withCapInsets: UIEdgeInsetsZero, resizingMode: .tile)
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
            self.updateProgress()
        }
    }
    
    private let container: UIView
    private let transition: NavigationTransition
    private let topView: UIView
    private let viewSuperview: UIView?
    private let bottomView: UIView
    private let topNavigationBar: NavigationBar?
    private let bottomNavigationBar: NavigationBar?
    private let dimView: UIView
    private let shadowView: UIImageView
    
    init(transition: NavigationTransition, container: UIView, topView: UIView, topNavigationBar: NavigationBar?, bottomView: UIView, bottomNavigationBar: NavigationBar?) {
        self.transition = transition
        self.container = container
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
        self.dimView.backgroundColor = UIColor.black()
        self.shadowView = UIImageView(image: shadowImage)
        
        switch transition {
            case .Push:
                self.viewSuperview?.insertSubview(topView, belowSubview: topView)
            case .Pop:
                self.viewSuperview?.insertSubview(bottomView, belowSubview: topView)
        }
        
        self.viewSuperview?.insertSubview(self.dimView, belowSubview: topView)
        self.viewSuperview?.insertSubview(self.shadowView, belowSubview: dimView)
        
        self.updateProgress()
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateProgress() {
        let position: CGFloat
        switch self.transition {
            case .Push:
                position = 1.0 - progress
            case .Pop:
                position = progress
        }
        self.topView.frame = CGRect(origin: CGPoint(x: floorToScreenPixels(position * self.container.bounds.size.width), y: 0.0), size: self.container.bounds.size)
        self.dimView.frame = CGRect(origin: CGPoint(), size: CGSize(width: max(0.0, self.topView.frame.minX), height: self.container.bounds.size.height))
        self.shadowView.frame = CGRect(origin: CGPoint(x: self.dimView.frame.maxX - shadowWidth, y: 0.0), size: CGSize(width: shadowWidth, height: self.container.bounds.size.height))
        self.dimView.alpha = (1.0 - position) * 0.15
        self.shadowView.alpha = (1.0 - position) * 0.9
        self.bottomView.frame = CGRect(origin: CGPoint(x: ((position - 1.0) * self.container.bounds.size.width * 0.3), y: 0.0), size: self.container.bounds.size)
        
        (self.container.window as? Window)?.updateStatusBars()
    }
    
    func animateCancel(_ completion: () -> ()) {
        UIView.animate(withDuration: 0.1, delay: 0.0, options: UIViewAnimationOptions(), animations: { () -> Void in
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
            
            completion()
        }
    }
    
    func animateCompletion(_ velocity: CGFloat, completion: () -> ()) {
        let distance = (1.0 - self.progress) * self.container.bounds.size.width
        let f = {
            switch self.transition {
            case .Push:
                if let viewSuperview = self.viewSuperview {
                    viewSuperview.addSubview(self.bottomView)
                } else {
                    self.bottomView.removeFromSuperview()
                }
                //self.topView.removeFromSuperview()
            case .Pop:
                if let viewSuperview = self.viewSuperview {
                    viewSuperview.addSubview(self.topView)
                } else {
                    self.topView.removeFromSuperview()
                }
                //self.bottomView.removeFromSuperview()
            }
            
            self.dimView.removeFromSuperview()
            self.shadowView.removeFromSuperview()
            
            completion()
        }
        
        if abs(velocity) < CGFloat(FLT_EPSILON) && abs(self.progress) < CGFloat(FLT_EPSILON) {
            UIView.animate(withDuration: 0.5, delay: 0.0, options: UIViewAnimationOptions(rawValue: 7 << 16), animations: {
                self.progress = 1.0
            }, completion: { _ in
                f()
            })
        } else {
            UIView.animate(withDuration: Double(max(0.05, min(0.2, abs(distance / velocity)))), delay: 0.0, options: UIViewAnimationOptions(), animations: { () -> Void in
                self.progress = 1.0
            }) { (completed) -> Void in
                f()
            }
        }
    }
}
