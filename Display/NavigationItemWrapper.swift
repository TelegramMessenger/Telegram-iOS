import UIKit
import AsyncDisplayKit

internal class NavigationItemWrapper {
    let parentNode: ASDisplayNode
    
    private var navigationItem: UINavigationItem
    private var setTitleListenerKey: Int!
    private var setLeftBarButtonItemListenerKey: Int!
    private var setRightBarButtonItemListenerKey: Int!
    
    private var previousNavigationItem: UINavigationItem?
    private var previousItemSetTitleListenerKey: Int?
    
    private let titleNode: NavigationTitleNode
    private var backButtonNode: NavigationBackButtonNode
    private var leftBarButtonItem: UIBarButtonItem?
    private var leftBarButtonItemWrapper: BarButtonItemWrapper?
    private var rightBarButtonItem: UIBarButtonItem?
    private var rightBarButtonItemWrapper: BarButtonItemWrapper?
    
    var backPressed: () -> () = { }
    
    var suspendLayout = false
    
    init(parentNode: ASDisplayNode, navigationItem: UINavigationItem, previousNavigationItem: UINavigationItem?) {
        self.parentNode = parentNode
        self.navigationItem = navigationItem
        self.previousNavigationItem = previousNavigationItem
        
        self.titleNode = NavigationTitleNode(text: "")
        self.parentNode.addSubnode(titleNode)
        
        self.backButtonNode = NavigationBackButtonNode()
        backButtonNode.pressed = { [weak self] in
            if let backPressed = self?.backPressed {
                backPressed()
            }
        }
        self.parentNode.addSubnode(self.backButtonNode)
        
        self.previousItemSetTitleListenerKey = previousNavigationItem?.addSetTitleListener({ [weak self] title in
            self?.setBackButtonTitle(title ?? "")
            return
        })
        
        self.setTitleListenerKey = navigationItem.addSetTitleListener({ [weak self] title in
            self?.setTitle(title ?? "")
            return
        })
        
        self.setLeftBarButtonItemListenerKey = navigationItem.addSetLeftBarButtonItemListener({ [weak self] barButtonItem, animated in
            self?.setLeftBarButtonItem(barButtonItem, animated: animated.boolValue)
            return
        })
        
        self.setRightBarButtonItemListenerKey = navigationItem.addSetRightBarButtonItemListener({ [weak self] barButtonItem, animated in
            self?.setRightBarButtonItem(barButtonItem, animated: animated.boolValue)
            return
        })
        
        self.setTitle(navigationItem.title ?? "")
        self.setBackButtonTitle(previousNavigationItem?.title ?? "Back")
        self.setLeftBarButtonItem(navigationItem.leftBarButtonItem, animated: false)
        self.setRightBarButtonItem(navigationItem.rightBarButtonItem, animated: false)
    }
    
    deinit {
        self.navigationItem.removeSetTitleListener(self.setTitleListenerKey)
        self.navigationItem.removeSetLeftBarButtonItemListener(self.setLeftBarButtonItemListenerKey)
        self.navigationItem.removeSetRightBarButtonItemListener(self.setRightBarButtonItemListenerKey)
        
        if let previousItemSetTitleListenerKey = self.previousItemSetTitleListenerKey {
            self.previousNavigationItem?.removeSetTitleListener(previousItemSetTitleListenerKey)
        }
        
        self.titleNode.removeFromSupernode()
        self.backButtonNode.removeFromSupernode()
    }
    
    func setBackButtonTitle(_ backButtonTitle: String) {
        self.backButtonNode.text = backButtonTitle
        self.layoutItems()
    }
    
    func setTitle(_ title: String) {
        self.titleNode.text = title
        self.layoutItems()
    }
    
    func setLeftBarButtonItem(_ leftBarButtonItem: UIBarButtonItem?, animated: Bool) {
        if self.leftBarButtonItem !== leftBarButtonItem {
            self.leftBarButtonItem = leftBarButtonItem
            
            self.leftBarButtonItemWrapper = nil
            
            if let leftBarButtonItem = leftBarButtonItem {
                self.leftBarButtonItemWrapper = BarButtonItemWrapper(parentNode: self.parentNode, barButtonItem: leftBarButtonItem, layoutNeeded: { [weak self] in
                    self?.layoutItems()
                    return
                })
            }
        }
        
        self.backButtonNode.isHidden = self.previousNavigationItem == nil || self.leftBarButtonItemWrapper != nil
    }
    
    func setRightBarButtonItem(_ rightBarButtonItem: UIBarButtonItem?, animated: Bool) {
        if self.rightBarButtonItem !== rightBarButtonItem {
            self.rightBarButtonItem = rightBarButtonItem
            
            self.rightBarButtonItemWrapper = nil
            
            if let rightBarButtonItem = rightBarButtonItem {
                self.rightBarButtonItemWrapper = BarButtonItemWrapper(parentNode: self.parentNode, barButtonItem: rightBarButtonItem, layoutNeeded: { [weak self] in
                    self?.layoutItems()
                    return
                })
            }
        }
    }
    
    private var collapsed: Bool {
        get {
            return self.parentNode.frame.size.height < (20.0 + 44.0)
        }
    }
    
    var titleFrame: CGRect {
        get {
            return CGRect(x: floor((self.parentNode.frame.size.width - self.titleNode.calculatedSize.width) / 2.0), y: self.collapsed ? 24.0 : 31.0, width: self.titleNode.calculatedSize.width, height: self.titleNode.calculatedSize.height)
        }
    }
    
    var titlePosition: CGPoint {
        get {
            let titleFrame = self.titleFrame
            return CGPoint(x: titleFrame.midX, y: titleFrame.midY)
        }
    }
    
    var backButtonFrame: CGRect {
        get {
            return CGRect(x: self.collapsed ? 15.0 : 8.0, y: self.collapsed ? 24.0 : 31.0, width: backButtonNode.calculatedSize.width, height: backButtonNode.calculatedSize.height)
        }
    }
    
    var backButtonLabelFrame: CGRect {
        get {
            let backButtonFrame = self.backButtonFrame
            let labelFrame = self.backButtonNode.labelFrame
            return CGRect(origin: CGPoint(x: backButtonFrame.origin.x + labelFrame.origin.x, y: backButtonFrame.origin.y + labelFrame.origin.y), size: labelFrame.size)
        }
    }
    
    var backButtonLabelPosition: CGPoint {
        get {
            let backButtonLabelFrame = self.backButtonLabelFrame
            return CGPoint(x: backButtonLabelFrame.midX, y: backButtonLabelFrame.midY)
        }
    }
    
    var leftButtonFrame: CGRect? {
        get {
            if let leftBarButtonItemWrapper = self.leftBarButtonItemWrapper {
                return CGRect(x: self.collapsed ? 15.0 : 8.0, y: self.collapsed ? 24.0 : 31.0, width: leftBarButtonItemWrapper.buttonNode.calculatedSize.width, height: leftBarButtonItemWrapper.buttonNode.calculatedSize.height)
            }
            else {
                return nil
            }
        }
    }
    
    var rightButtonFrame: CGRect? {
        get {
            if let rightBarButtonItemWrapper = self.rightBarButtonItemWrapper {
                return CGRect(x: self.parentNode.frame.size.width - rightBarButtonItemWrapper.buttonNode.calculatedSize.width - (self.collapsed ? 15.0 : 8.0), y: self.collapsed ? 24.0 : 31.0, width: rightBarButtonItemWrapper.buttonNode.calculatedSize.width, height: rightBarButtonItemWrapper.buttonNode.calculatedSize.height)
            }
            else {
                return nil
            }
        }
    }
    
    var transitionState: NavigationItemTransitionState {
        get {
            return NavigationItemTransitionState(backButtonPosition: self.backButtonNode.isHidden ? nil : self.backButtonLabelPosition, titlePosition: self.titlePosition)
        }
    }
    
    func layoutItems() {
        if suspendLayout {
            return
        }
        
        self.backButtonNode.measure(self.parentNode.frame.size)
        self.backButtonNode.frame = self.backButtonFrame
        self.backButtonNode.layout()
        
        if let leftBarButtonItemWrapper = self.leftBarButtonItemWrapper {
            leftBarButtonItemWrapper.buttonNode.measure(self.parentNode.frame.size)
            leftBarButtonItemWrapper.buttonNode.frame = self.leftButtonFrame!
        }
        
        if let rightBarButtonItemWrapper = self.rightBarButtonItemWrapper {
            rightBarButtonItemWrapper.buttonNode.measure(self.parentNode.frame.size)
            rightBarButtonItemWrapper.buttonNode.frame = self.rightButtonFrame!
        }
        
        self.titleNode.measure(CGSize(width: max(0.0, self.parentNode.bounds.size.width - 140.0), height: CGFloat.greatestFiniteMagnitude))
        self.titleNode.frame = self.titleFrame
    }
    
    func interpolatePosition(_ from: CGPoint, _ to: CGPoint, value: CGFloat) -> CGPoint {
        return CGPoint(x: from.x * (CGFloat(1.0) - value) + to.x * value, y: from.y * (CGFloat(1.0) - value) + to.y * value)
    }
    
    func interpolateValue(_ from: CGFloat, _ to: CGFloat, value: CGFloat) -> CGFloat {
        return (from * (CGFloat(1.0) - value)) + (to * value)
    }
    
    func applyPushAnimationProgress(previousItemState: NavigationItemTransitionState, value: CGFloat) {
        let titleStartPosition = CGPoint(x: self.parentNode.frame.size.width + self.titleNode.frame.size.width / 2.0, y: self.titlePosition.y)
        let titleStartAlpha: CGFloat = 0.0
        let titleEndPosition = self.titlePosition
        let titleEndAlpha: CGFloat = 1.0
        self.titleNode.position = self.interpolatePosition(titleStartPosition, titleEndPosition, value: value)
        self.titleNode.alpha = self.interpolateValue(titleStartAlpha, titleEndAlpha, value: value)
        
        self.rightBarButtonItemWrapper?.buttonNode.alpha = self.interpolateValue(0.0, 1.0, value: value)
        self.leftBarButtonItemWrapper?.buttonNode.alpha = self.interpolateValue(0.0, 1.0, value: value)
        
        self.backButtonNode.label.position = self.interpolatePosition(CGPoint(x: previousItemState.titlePosition.x - self.backButtonFrame.origin.x, y: previousItemState.titlePosition.y - self.backButtonFrame.origin.y), CGPoint(x: self.backButtonLabelPosition.x - self.backButtonFrame.origin.x, y: self.backButtonLabelPosition.y - self.backButtonFrame.origin.y), value: value)
        self.backButtonNode.alpha = self.interpolateValue(0.0, 1.0, value: value)
    }
    
    func applyPushAnimationProgress(nextItemState: NavigationItemTransitionState, value: CGFloat) {
        let titleStartPosition = self.titlePosition
        let titleStartAlpha: CGFloat = 1.0
        var titleEndPosition = CGPoint(x: -self.titleNode.frame.size.width / 2.0, y: self.titlePosition.y)
        if let nextItemBackButtonPosition = nextItemState.backButtonPosition {
            titleEndPosition = nextItemBackButtonPosition
        }
        let titleEndAlpha: CGFloat = 0.0
        
        self.titleNode.position = self.interpolatePosition(titleStartPosition, titleEndPosition, value: value)
        self.titleNode.alpha = self.interpolateValue(titleStartAlpha, titleEndAlpha, value: value)
        
        self.rightBarButtonItemWrapper?.buttonNode.alpha = self.interpolateValue(1.0, 0.0, value: value)
        self.leftBarButtonItemWrapper?.buttonNode.alpha = self.interpolateValue(1.0, 0.0, value: value)
        
        self.backButtonNode.label.position = self.interpolatePosition(CGPoint(x: self.backButtonLabelPosition.x - self.backButtonFrame.origin.x, y: self.backButtonLabelPosition.y - self.backButtonFrame.origin.y), CGPoint(x: -self.backButtonLabelFrame.size.width - self.backButtonFrame.origin.x, y: self.backButtonLabelPosition.y - self.backButtonFrame.origin.y), value: value)
        self.backButtonNode.label.alpha = self.interpolateValue(1.0, 0.0, value: value)
        self.backButtonNode.arrow.alpha = self.interpolateValue(1.0, nextItemState.backButtonPosition == nil ? 0.0 : 1.0, value: value)
    }
    
    func applyPopAnimationProgress(previousItemState: NavigationItemTransitionState, value: CGFloat) {
        var titleStartPosition = CGPoint(x: -self.titleNode.frame.size.width / 2.0, y: self.titlePosition.y)
        if let previousItemBackButtonPosition = previousItemState.backButtonPosition {
            titleStartPosition = previousItemBackButtonPosition
        }
        let titleStartAlpha: CGFloat = 0.0
        let titleEndPosition = self.titlePosition
        let titleEndAlpha: CGFloat = 1.0
        self.titleNode.position = self.interpolatePosition(titleStartPosition, titleEndPosition, value: value)
        self.titleNode.alpha = self.interpolateValue(titleStartAlpha, titleEndAlpha, value: value)
        
        self.rightBarButtonItemWrapper?.buttonNode.alpha = self.interpolateValue(0.0, 1.0, value: value)
        self.leftBarButtonItemWrapper?.buttonNode.alpha = self.interpolateValue(0.0, 1.0, value: value)
        
        self.backButtonNode.label.position = self.interpolatePosition(CGPoint(x: -self.backButtonLabelFrame.size.width - self.backButtonFrame.origin.x, y: self.backButtonLabelPosition.y - self.backButtonFrame.origin.y), CGPoint(x: self.backButtonLabelPosition.x - self.backButtonFrame.origin.x, y: self.backButtonLabelPosition.y - self.backButtonFrame.origin.y), value: value)
        self.backButtonNode.label.alpha = self.interpolateValue(0.0, 1.0, value: value)
        self.backButtonNode.arrow.alpha = self.interpolateValue(previousItemState.backButtonPosition == nil ? 0.0 : 1.0, 1.0, value: value)
    }
    
    func applyPopAnimationProgress(nextItemState: NavigationItemTransitionState, value: CGFloat) {
        let titleStartPosition = self.titlePosition
        let titleStartAlpha: CGFloat = 1.0
        let titleEndPosition = CGPoint(x: self.parentNode.frame.size.width + self.titleNode.frame.size.width / 2.0, y: self.titlePosition.y)
        let titleEndAlpha: CGFloat = 0.0
        self.titleNode.position = self.interpolatePosition(titleStartPosition, titleEndPosition, value: value)
        self.titleNode.alpha = self.interpolateValue(titleStartAlpha, titleEndAlpha, value: value)
        
        self.rightBarButtonItemWrapper?.buttonNode.alpha = self.interpolateValue(1.0, 0.0, value: value)
        self.leftBarButtonItemWrapper?.buttonNode.alpha = self.interpolateValue(1.0, 0.0, value: value)
        
        self.backButtonNode.label.position = self.interpolatePosition(CGPoint(x: self.backButtonLabelPosition.x - self.backButtonFrame.origin.x, y: self.backButtonLabelPosition.y - self.backButtonFrame.origin.y), CGPoint(x: nextItemState.titlePosition.x - self.backButtonFrame.origin.x, y: nextItemState.titlePosition.y - self.backButtonFrame.origin.y), value: value)
        self.backButtonNode.label.alpha = self.interpolateValue(1.0, 0.0, value: value)
        self.backButtonNode.arrow.alpha = self.interpolateValue(1.0, 0.0, value: value)
    }
    
    func animatePush(previousItemWrapper: NavigationItemWrapper?, duration: Double) {
        if let previousItemWrapper = previousItemWrapper {
            self.suspendLayout = true
            self.backButtonNode.suspendLayout = true
            
            let transitionState = self.transitionState
            let previousItemState = previousItemWrapper.transitionState
            
            self.applyPushAnimationProgress(previousItemState: previousItemState, value: 0.0)
            previousItemWrapper.applyPushAnimationProgress(nextItemState: transitionState, value: 0.0)
            
            UIView.animate(withDuration: duration, delay: 0.0, options: UIViewAnimationOptions(rawValue: 7 << 16), animations: { () -> Void in
                self.applyPushAnimationProgress(previousItemState: previousItemState, value: 1.0)
                previousItemWrapper.applyPushAnimationProgress(nextItemState: transitionState, value: 1.0)
            }, completion: { completed in
                self.suspendLayout = false
                self.backButtonNode.suspendLayout = false
                
                previousItemWrapper.applyPushAnimationProgress(nextItemState: self.transitionState, value: 1.0)
            })
        }
    }
    
    func animatePop(previousItemWrapper: NavigationItemWrapper?, duration: Double) {
        if let previousItemWrapper = previousItemWrapper {
            self.applyPopAnimationProgress(previousItemState: previousItemWrapper.transitionState, value: 0.0)
            previousItemWrapper.applyPopAnimationProgress(nextItemState: self.transitionState, value: 0.0)
            
            UIView.animate(withDuration: duration, delay: 0.0, options: UIViewAnimationOptions(rawValue: 7 << 16), animations: { () -> Void in
                self.applyPopAnimationProgress(previousItemState: previousItemWrapper.transitionState, value: 1.0)
                previousItemWrapper.applyPopAnimationProgress(nextItemState: self.transitionState, value: 1.0)
            }, completion: { completed in
                previousItemWrapper.applyPopAnimationProgress(nextItemState: self.transitionState, value: 0.0)
            })
        }
    }
    
    func setInteractivePopProgress(progress: CGFloat, previousItemWrapper: NavigationItemWrapper) {
        self.applyPopAnimationProgress(previousItemState: previousItemWrapper.transitionState, value: progress)
        previousItemWrapper.applyPopAnimationProgress(nextItemState: self.transitionState, value: progress)
    }
}
