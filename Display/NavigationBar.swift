import UIKit
import AsyncDisplayKit

public class NavigationBar: ASDisplayNode {
    var item: UINavigationItem? {
        didSet {
            if let item = self.item {
                self.itemWrapper = NavigationItemWrapper(parentNode: self, navigationItem: item, previousNavigationItem: self.previousItem)
                self.itemWrapper?.backPressed = { [weak self] in
                    if let backPressed = self?.backPressed {
                        backPressed()
                    }
                }
            } else {
                self.itemWrapper = nil
            }
        }
    }
    
    var previousItem: UINavigationItem? {
        didSet {
            if let item = self.item {
                self.itemWrapper = NavigationItemWrapper(parentNode: self, navigationItem: item, previousNavigationItem: self.previousItem)
                self.itemWrapper?.backPressed = { [weak self] in
                    if let backPressed = self?.backPressed {
                        backPressed()
                    }
                }
            } else {
                self.itemWrapper = nil
            }
        }
    }
    
    private var itemWrapper: NavigationItemWrapper?
    
    private let stripeHeight: CGFloat = 1.0 / UIScreen.main().scale
    
    var backPressed: () -> () = { }
    
    private var collapsed: Bool {
        get {
            return self.frame.size.height < (20.0 + 44.0)
        }
    }
    
    let stripeView: UIView
    
    public override init() {
        stripeView = UIView()
        stripeView.backgroundColor = UIColor(red: 0.6953125, green: 0.6953125, blue: 0.6953125, alpha: 1.0)
        
        //self.effectView = UIVisualEffectView(effect: UIBlurEffect(style: .Light))
        
        super.init()
        
        self.backgroundColor = UIColor(red: 0.968626451, green: 0.968626451, blue: 0.968626451, alpha: 1.0)
        //self.view.addSubview(self.effectView)
        
        self.view.addSubview(stripeView)
    }
    
    /*private func updateTopItem(item: UINavigationItem, previousItem: UINavigationItem?, animation: ItemAnimation) {
        if self.topItem !== item {
            let previousTopItemWrapper = self.topItemWrapper
            self.topItemWrapper = nil
            
            self.topItem = item
            self.topItemWrapper = NavigationItemWrapper(parentNode: self, navigationItem: item, previousNavigationItem: previousItem)
            self.topItemWrapper?.backPressed = { [weak self] in
                if let backPressed = self?.backPressed {
                    backPressed()
                }
            }
            
            self.topItemWrapper?.layoutItems()
            
            switch animation {
                case .None:
                    break
                case .Push:
                    self.topItemWrapper?.animatePush(previousTopItemWrapper, duration: 0.3)
                    break
                case .Pop:
                    self.topItemWrapper?.animatePop(previousTopItemWrapper, duration: 0.3)
                    break
            }
        }
    }
    
    public func beginInteractivePopProgress(previousItem: UINavigationItem, evenMorePreviousItem: UINavigationItem?) {
        self.tempItem = previousItem
        self.tempItemWrapper = NavigationItemWrapper(parentNode: self, navigationItem: previousItem, previousNavigationItem: evenMorePreviousItem)
        
        self.tempItemWrapper?.layoutItems()
        
        self.setInteractivePopProgress(0.0)
    }
    
    public func endInteractivePopProgress() {
        self.tempItem = nil
        self.tempItemWrapper = nil
    }
    
    public func setInteractivePopProgress(progress: CGFloat) {
        if let topItemWrapper = self.topItemWrapper {
            self.tempItemWrapper?.setInteractivePopProgress(progress, previousItemWrapper: topItemWrapper)
        }
    }*/
    
    public override func layout() {
        self.stripeView.frame = CGRect(x: 0.0, y: self.frame.size.height, width: self.frame.size.width, height: stripeHeight)
        
        self.itemWrapper?.layoutItems()
        
        //self.effectView.frame = self.bounds
    }
}
