import UIKit
import AsyncDisplayKit

private enum ItemAnimation {
    case None
    case Push
    case Pop
}

public class NavigationBar: ASDisplayNode {
    private var topItem: UINavigationItem?
    private var topItemWrapper: NavigationItemWrapper?
    
    private var tempItem: UINavigationItem?
    private var tempItemWrapper: NavigationItemWrapper?
    
    private let stripeHeight: CGFloat = 1.0 / UIScreen.mainScreen().scale
    
    var backPressed: () -> () = { }
    
    private var collapsed: Bool {
        get {
            return self.frame.size.height < (20.0 + 44.0)
        }
    }
    
    var _proxy: NavigationBarProxy?
    var proxy: NavigationBarProxy? {
        get {
            return self._proxy
        }
        set(value) {
            self._proxy = value
            self._proxy?.setItemsProxy = {[weak self] previousItems, items, animated in
                if let strongSelf = self {
                    var animation = ItemAnimation.None
                    if animated && previousItems.count != 0 && items.count != 0 {
                        if previousItems.filter({element in element === items[items.count - 1]}).count != 0 {
                            animation = .Pop
                        }
                        else {
                            animation = .Push
                        }
                    }
                    
                    let count = items.count
                    if count != 0 {
                        strongSelf.updateTopItem(items[count - 1] as! UINavigationItem, previousItem: count >= 2 ? (items[count - 2] as! UINavigationItem) : nil, animation: animation)
                    }
                }
                return
            }
        }
    }
    let stripeView: UIView
    
    public override init() {
        stripeView = UIView()
        stripeView.backgroundColor = UIColor(red: 0.6953125, green: 0.6953125, blue: 0.6953125, alpha: 1.0)
        
        super.init()
        
        self.backgroundColor = UIColor(red: 0.968626451, green: 0.968626451, blue: 0.968626451, alpha: 1.0)
        
        self.view.addSubview(stripeView)
    }
    
    private func updateTopItem(item: UINavigationItem, previousItem: UINavigationItem?, animation: ItemAnimation) {
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
    }
    
    public override func layout() {
        
        self.stripeView.frame = CGRect(x: 0.0, y: self.frame.size.height - stripeHeight, width: self.frame.size.width, height: stripeHeight)
        
        self.topItemWrapper?.layoutItems()
        self.tempItemWrapper?.layoutItems()
    }
}
