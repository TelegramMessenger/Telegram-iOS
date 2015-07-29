import UIKit

class NavigationTransitionCoordinator {
    private var _progress: CGFloat = 0.0
    var progress: CGFloat {
        get {
            return self._progress
        }
        set(value) {
            self._progress = value
            self.navigationBar.setInteractivePopProgress(value)
            self.updateProgress()
        }
    }
    
    private let container: UIView
    private let topView: UIView
    private let topViewSuperview: UIView?
    private let bottomView: UIView
    private let dimView: UIView
    private let navigationBar: NavigationBar
    
    init(container: UIView, topView: UIView, bottomView: UIView, navigationBar: NavigationBar) {
        self.container = container
        self.topView = topView
        self.topViewSuperview = topView.superview
        self.bottomView = bottomView
        self.dimView = UIView()
        self.dimView.backgroundColor = UIColor.blackColor()
        self.navigationBar = navigationBar
        
        if let topViewSuperview = self.topViewSuperview {
            topViewSuperview.insertSubview(bottomView, belowSubview: topView)
        }
        
        self.updateProgress()
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func updateProgress() {
        self.topView.frame = CGRect(origin: CGPoint(x: floorToScreenPixels(self.progress * self.container.bounds.size.width), y: 0.0), size: self.container.bounds.size)
        self.dimView.frame = self.container.bounds
        self.dimView.alpha = (1.0 - self.progress) * 0.1
        self.bottomView.frame = CGRect(origin: CGPoint(x: ((self.progress - 1.0) * self.container.bounds.size.width * 0.3), y: 0.0), size: self.container.bounds.size)
    }
    
    func animateCancel(completion: () -> ()) {
        UIView.animateWithDuration(0.1, delay: 0.0, options: UIViewAnimationOptions(), animations: { () -> Void in
            self.progress = 0.0
        }) { (completed) -> Void in
            if let topViewSuperview = self.topViewSuperview {
                topViewSuperview.addSubview(self.topView)
            }
            else {
                self.topView.removeFromSuperview()
            }
            self.bottomView.removeFromSuperview()
            
            completion()
        }
    }
    
    func animateCompletion(velocity: CGFloat, completion: () -> ()) {
        let distance = (1.0 - self.progress) * self.container.bounds.size.width
        UIView.animateWithDuration(NSTimeInterval(max(0.05, min(0.2, abs(distance / velocity)))), delay: 0.0, options: UIViewAnimationOptions(), animations: { () -> Void in
            self.progress = 1.0
        }) { (completed) -> Void in
            if let topViewSuperview = self.topViewSuperview {
                topViewSuperview.addSubview(self.topView)
            }
            else {
                self.topView.removeFromSuperview()
            }
            self.bottomView.removeFromSuperview()
            
            completion()
        }
    }
}