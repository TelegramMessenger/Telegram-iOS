import UIKit
import AsyncDisplayKit

private func generateBackArrowImage(color: UIColor) -> UIImage? {
    return generateImage(CGSize(width: 13.0, height: 22.0), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setFillColor(color.cgColor)
        let _ = try? drawSvgPath(context, path: "M10.6569398,0.0 L0.0,11 L10.6569398,22 L13,19.1782395 L5.07681762,11 L13,2.82176047 Z ")
    })
}

private var backArrowImageCache: [Int32: UIImage] = [:]

private func backArrowImage(color: UIColor) -> UIImage? {
    var red: CGFloat = 0.0
    var green: CGFloat = 0.0
    var blue: CGFloat = 0.0
    var alpha: CGFloat = 0.0
    color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    
    let key = (Int32(alpha * 255.0) << 24) | (Int32(red * 255.0) << 16) | (Int32(green * 255.0) << 8) | Int32(blue * 255.0)
    if let image = backArrowImageCache[key] {
        return image
    } else {
        if let image = generateBackArrowImage(color: color) {
            backArrowImageCache[key] = image
            return image
        } else {
            return nil
        }
    }
}

public class NavigationBar: ASDisplayNode {
    public var foregroundColor: UIColor = UIColor.black {
        didSet {
            if let title = self.title {
                self.titleNode.attributedText = NSAttributedString(string: title, font: Font.medium(17.0), textColor: self.foregroundColor)
            }
        }
    }
    
    public var accentColor: UIColor = UIColor(0x1195f2) {
        didSet {
            self.backButtonNode.color = self.accentColor
            self.leftButtonNode.color = self.accentColor
            self.backButtonArrow.image = backArrowImage(color: self.accentColor)
        }
    }
    
    var backPressed: () -> () = { }
    
    private var collapsed: Bool {
        get {
            return self.frame.size.height < (20.0 + 44.0)
        }
    }
    
    private let stripeNode: ASDisplayNode
    public var stripeColor: UIColor = UIColor(red: 0.6953125, green: 0.6953125, blue: 0.6953125, alpha: 1.0) {
        didSet {
            self.stripeNode.backgroundColor = self.stripeColor
        }
    }
    
    private let clippingNode: ASDisplayNode
    
    private var itemTitleListenerKey: Int?
    private var itemTitleViewListenerKey: Int?
    private var itemLeftButtonListenerKey: Int?
    private var _item: UINavigationItem?
    var item: UINavigationItem? {
        get {
            return self._item
        } set(value) {
            if let previousValue = self._item {
                if let itemTitleListenerKey = self.itemTitleListenerKey {
                    previousValue.removeSetTitleListener(itemTitleListenerKey)
                    self.itemTitleListenerKey = nil
                }
                if let itemLeftButtonListenerKey = self.itemLeftButtonListenerKey {
                    previousValue.removeSetLeftBarButtonItemListener(itemLeftButtonListenerKey)
                    self.itemLeftButtonListenerKey = nil
                }
            }
            self._item = value
            
            self.leftButtonNode.removeFromSupernode()
            
            if let item = value {
                self.title = item.title
                self.itemTitleListenerKey = item.addSetTitleListener { [weak self] text in
                    if let strongSelf = self {
                        strongSelf.title = text
                    }
                }
                
                self.titleView = item.titleView
                self.itemTitleViewListenerKey = item.addSetTitleViewListener { [weak self] titleView in
                    if let strongSelf = self {
                        strongSelf.titleView = titleView
                    }
                }
                
                self.itemLeftButtonListenerKey = item.addSetLeftBarButtonItemListener { [weak self] _, _ in
                    if let strongSelf = self {
                        strongSelf.updateLeftButton()
                    }
                }
                
                self.updateLeftButton()
            } else {
                self.title = nil
                self.updateLeftButton()
            }
            self.invalidateCalculatedLayout()
        }
    }
    private var title: String? {
        didSet {
            if let title = self.title {
                self.titleNode.attributedText = NSAttributedString(string: title, font: Font.medium(17.0), textColor: self.foregroundColor)
                if self.titleNode.supernode == nil {
                    self.clippingNode.addSubnode(self.titleNode)
                }
            } else {
                self.titleNode.removeFromSupernode()
            }
            
            self.invalidateCalculatedLayout()
            self.setNeedsLayout()
        }
    }
    
    private var titleView: UIView? {
        didSet {
            if let oldValue = oldValue {
                oldValue.removeFromSuperview()
            }
            
            if let titleView = self.titleView {
                self.clippingNode.view.addSubview(titleView)
            }
            
            self.invalidateCalculatedLayout()
            self.setNeedsLayout()
        }
    }
    
    private let titleNode: ASTextNode
    
    var previousItemListenerKey: Int?
    var _previousItem: UINavigationItem?
    var previousItem: UINavigationItem? {
        get {
            return self._previousItem
        } set(value) {
            if let previousValue = self._previousItem, previousItemListenerKey = self.previousItemListenerKey {
                previousValue.removeSetTitleListener(previousItemListenerKey)
                self.previousItemListenerKey = nil
            }
            self._previousItem = value
            
            if let previousItem = value {
                self.previousItemListenerKey = previousItem.addSetTitleListener { [weak self] text in
                    if let strongSelf = self {
                        strongSelf.backButtonNode.text = text ?? "Back"
                        strongSelf.invalidateCalculatedLayout()
                    }
                }
            }
            self.updateLeftButton()
            
            self.invalidateCalculatedLayout()
        }
    }
    
    private func updateLeftButton() {
        if let item = self.item {
            if let leftBarButtonItem = item.leftBarButtonItem {
                self.backButtonNode.removeFromSupernode()
                self.backButtonArrow.removeFromSupernode()
                
                self.leftButtonNode.text = leftBarButtonItem.title ?? ""
                if self.leftButtonNode.supernode == nil {
                    self.clippingNode.addSubnode(self.leftButtonNode)
                }
            } else {
                self.leftButtonNode.removeFromSupernode()
                
                if let previousItem = self.previousItem {
                    self.backButtonNode.text = previousItem.title ?? "Back"
                    
                    if self.backButtonNode.supernode == nil {
                        self.clippingNode.addSubnode(self.backButtonNode)
                        self.clippingNode.addSubnode(self.backButtonArrow)
                    }
                } else {
                    self.backButtonNode.removeFromSupernode()
                    
                }
            }
        } else {
            self.leftButtonNode.removeFromSupernode()
            self.backButtonNode.removeFromSupernode()
            self.backButtonArrow.removeFromSupernode()
        }
    }
    
    private let backButtonNode: NavigationButtonNode
    private let backButtonArrow: ASImageNode
    private let leftButtonNode: NavigationButtonNode
    
    private var _transitionState: NavigationBarTransitionState?
    var transitionState: NavigationBarTransitionState? {
        get {
            return self._transitionState
        } set(value) {
            let updateNodes = self._transitionState?.navigationBar !== value?.navigationBar
            
            self._transitionState = value
            
            if updateNodes {
                if let transitionTitleNode = self.transitionTitleNode {
                    transitionTitleNode.removeFromSupernode()
                    self.transitionTitleNode = nil
                }
                
                if let transitionBackButtonNode = self.transitionBackButtonNode {
                    transitionBackButtonNode.removeFromSupernode()
                    self.transitionBackButtonNode = nil
                }
                
                if let transitionBackArrowNode = self.transitionBackArrowNode {
                    transitionBackArrowNode.removeFromSupernode()
                    self.transitionBackArrowNode = nil
                }

                if let value = value {
                    switch value.role {
                        case .top:
                            if let transitionTitleNode = value.navigationBar?.makeTransitionTitleNode(foregroundColor: self.foregroundColor) {
                                self.transitionTitleNode = transitionTitleNode
                                if self.leftButtonNode.supernode != nil {
                                    self.clippingNode.insertSubnode(transitionTitleNode, belowSubnode: self.leftButtonNode)
                                } else if self.backButtonNode.supernode != nil {
                                    self.clippingNode.insertSubnode(transitionTitleNode, belowSubnode: self.backButtonNode)
                                } else {
                                    self.clippingNode.addSubnode(transitionTitleNode)
                                }
                            }
                        case .bottom:
                            if let transitionBackButtonNode = value.navigationBar?.makeTransitionBackButtonNode(accentColor: self.accentColor) {
                                self.transitionBackButtonNode = transitionBackButtonNode
                                self.clippingNode.addSubnode(transitionBackButtonNode)
                            }
                            if let transitionBackArrowNode = value.navigationBar?.makeTransitionBackArrowNode(accentColor: self.accentColor) {
                                self.transitionBackArrowNode = transitionBackArrowNode
                                self.clippingNode.addSubnode(transitionBackArrowNode)
                            }
                    }
                }
            }
            
            self.layout()
        }
    }
    
    private var transitionTitleNode: ASDisplayNode?
    private var transitionBackButtonNode: NavigationButtonNode?
    private var transitionBackArrowNode: ASDisplayNode?
    
    public override init() {
        self.stripeNode = ASDisplayNode()
        
        self.titleNode = ASTextNode()
        self.backButtonNode = NavigationButtonNode()
        self.backButtonArrow = ASImageNode()
        self.backButtonArrow.displayWithoutProcessing = true
        self.backButtonArrow.displaysAsynchronously = false
        self.backButtonArrow.image = backArrowImage(color: self.accentColor)
        self.leftButtonNode = NavigationButtonNode()
        
        self.clippingNode = ASDisplayNode()
        self.clippingNode.clipsToBounds = true
        
        super.init()
        
        self.addSubnode(self.clippingNode)
        
        self.backgroundColor = UIColor(red: 0.968626451, green: 0.968626451, blue: 0.968626451, alpha: 1.0)
        
        self.stripeNode.isLayerBacked = true
        self.stripeNode.displaysAsynchronously = false
        self.stripeNode.backgroundColor = self.stripeColor
        self.addSubnode(self.stripeNode)
        
        self.titleNode.displaysAsynchronously = false
        self.titleNode.maximumNumberOfLines = 1
        self.titleNode.truncationMode = .byTruncatingTail
        self.titleNode.isOpaque = false
        
        self.backButtonNode.highlightChanged = { [weak self] highlighted in
            if let strongSelf = self {
                strongSelf.backButtonArrow.alpha = (highlighted ? 0.4 : 1.0)
            }
        }
        self.backButtonNode.pressed = { [weak self] in
            if let backPressed = self?.backPressed {
                backPressed()
            }
        }
        
        self.leftButtonNode.pressed = { [weak self] in
            if let item = self?.item, leftBarButtonItem = item.leftBarButtonItem {
                leftBarButtonItem.performActionOnTarget()
            }
        }
    }
    
    public override func layout() {
        var size = self.bounds.size
        
        let leftButtonInset: CGFloat = 8.0
        let backButtonInset: CGFloat = 27.0
        
        self.clippingNode.frame = CGRect(origin: CGPoint(), size: size)
        
        self.stripeNode.frame = CGRect(x: 0.0, y: size.height, width: size.width, height: UIScreenPixel)
        
        var nominalHeight: CGFloat = self.collapsed ? 32.0 : 44.0
        var contentVerticalOrigin = size.height - nominalHeight
        
        var leftTitleInset: CGFloat = 8.0
        if self.backButtonNode.supernode != nil {
            let backButtonSize = self.backButtonNode.measure(CGSize(width: size.width, height: nominalHeight))
            leftTitleInset += backButtonSize.width + backButtonInset + 8.0 + 8.0
            
            let topHitTestSlop = (nominalHeight - backButtonSize.height) * 0.5
            self.backButtonNode.hitTestSlop = UIEdgeInsetsMake(-topHitTestSlop, -27.0, -topHitTestSlop, -8.0)
            
            if let transitionState = self.transitionState {
                let progress = transitionState.progress
                
                switch transitionState.role {
                    case .top:
                        let initialX: CGFloat = backButtonInset
                        let finalX: CGFloat = floor((size.width - backButtonSize.width) / 2.0) - size.width
                        
                        self.backButtonNode.frame = CGRect(origin: CGPoint(x: initialX * (1.0 - progress) + finalX * progress, y: contentVerticalOrigin + floor((nominalHeight - backButtonSize.height) / 2.0)), size: backButtonSize)
                        self.backButtonNode.alpha = 1.0 - progress
                    
                        if let transitionTitleNode = self.transitionTitleNode {
                            let transitionTitleSize = transitionTitleNode.measure(CGSize(width: size.width, height: nominalHeight))
                            
                            let initialX: CGFloat = backButtonInset + floor((backButtonSize.width - transitionTitleSize.width) / 2.0)
                            let finalX: CGFloat = floor((size.width - transitionTitleSize.width) / 2.0) - size.width
                            
                            transitionTitleNode.frame = CGRect(origin: CGPoint(x: initialX * (1.0 - progress) + finalX * progress, y: contentVerticalOrigin + floor((nominalHeight - transitionTitleSize.height) / 2.0)), size: transitionTitleSize)
                            transitionTitleNode.alpha = progress
                        }
                    
                        self.backButtonArrow.frame = CGRect(origin: CGPoint(x: 8.0 - progress * size.width, y: contentVerticalOrigin + floor((nominalHeight - 22.0) / 2.0)), size: CGSize(width: 13.0, height: 22.0))
                        self.backButtonArrow.alpha = max(0.0, 1.0 - progress * 1.3)
                    case .bottom:
                        self.backButtonNode.alpha = 1.0
                        self.backButtonNode.frame = CGRect(origin: CGPoint(x: backButtonInset, y: contentVerticalOrigin + floor((nominalHeight - backButtonSize.height) / 2.0)), size: backButtonSize)
                        self.backButtonArrow.alpha = 1.0
                        self.backButtonArrow.frame = CGRect(origin: CGPoint(x: 8.0, y: contentVerticalOrigin + floor((nominalHeight - 22.0) / 2.0)), size: CGSize(width: 13.0, height: 22.0))
                }
            } else {
                self.backButtonNode.alpha = 1.0
                self.backButtonNode.frame = CGRect(origin: CGPoint(x: backButtonInset, y: contentVerticalOrigin + floor((nominalHeight - backButtonSize.height) / 2.0)), size: backButtonSize)
                self.backButtonArrow.alpha = 1.0
                self.backButtonArrow.frame = CGRect(origin: CGPoint(x: 8.0, y: contentVerticalOrigin + floor((nominalHeight - 22.0) / 2.0)), size: CGSize(width: 13.0, height: 22.0))
            }
        } else if self.leftButtonNode.supernode != nil {
            let leftButtonSize = self.leftButtonNode.measure(CGSize(width: size.width, height: nominalHeight))
            leftTitleInset += leftButtonSize.width + leftButtonInset + 8.0 + 8.0
            
            self.leftButtonNode.alpha = 1.0
            self.leftButtonNode.frame = CGRect(origin: CGPoint(x: leftButtonInset, y: contentVerticalOrigin + floor((nominalHeight - leftButtonSize.height) / 2.0)), size: leftButtonSize)
        }
        
        if let transitionState = self.transitionState {
            let progress = transitionState.progress
            
            switch transitionState.role {
                case .top:
                    break
                case .bottom:
                    if let transitionBackButtonNode = self.transitionBackButtonNode {
                        let transitionBackButtonSize = transitionBackButtonNode.measure(CGSize(width: size.width, height: nominalHeight))
                        let initialX: CGFloat = backButtonInset + size.width * 0.3
                        let finalX: CGFloat = floor((size.width - transitionBackButtonSize.width) / 2.0)
                        
                        transitionBackButtonNode.frame = CGRect(origin: CGPoint(x: initialX * (1.0 - progress) + finalX * progress, y: contentVerticalOrigin + floor((nominalHeight - transitionBackButtonSize.height) / 2.0)), size: transitionBackButtonSize)
                        transitionBackButtonNode.alpha = 1.0 - progress
                    }
                
                    if let transitionBackArrowNode = self.transitionBackArrowNode {
                        let initialX: CGFloat = 8.0 + size.width * 0.3
                        let finalX: CGFloat = 8.0
                        
                        transitionBackArrowNode.frame = CGRect(origin: CGPoint(x: initialX * (1.0 - progress) + finalX * progress, y: contentVerticalOrigin + floor((nominalHeight - 22.0) / 2.0)), size: CGSize(width: 13.0, height: 22.0))
                        transitionBackArrowNode.alpha = max(0.0, 1.0 - progress * 1.3)
                    }
                }
        }
        
        if self.titleNode.supernode != nil {
            let titleSize = self.titleNode.measure(CGSize(width: max(1.0, size.width - leftTitleInset - leftTitleInset), height: nominalHeight))
            
            if let transitionState = self.transitionState, otherNavigationBar = transitionState.navigationBar {
                let progress = transitionState.progress
                
                switch transitionState.role {
                    case .top:
                        let initialX = floor((size.width - titleSize.width) / 2.0)
                        let finalX: CGFloat = leftButtonInset
                        
                        self.titleNode.frame = CGRect(origin: CGPoint(x: initialX * (1.0 - progress) + finalX * progress, y: contentVerticalOrigin + floorToScreenPixels((nominalHeight - titleSize.height) / 2.0)), size: titleSize)
                        self.titleNode.alpha = 1.0 - progress
                    case .bottom:
                        var initialX: CGFloat = backButtonInset
                        if otherNavigationBar.backButtonNode.supernode != nil {
                            initialX += floor((otherNavigationBar.backButtonNode.frame.size.width - titleSize.width) / 2.0)
                        }
                        initialX += size.width * 0.3
                        let finalX: CGFloat = floor((size.width - titleSize.width) / 2.0)
                        
                        self.titleNode.frame = CGRect(origin: CGPoint(x: initialX * (1.0 - progress) + finalX * progress, y: contentVerticalOrigin + floorToScreenPixels((nominalHeight - titleSize.height) / 2.0)), size: titleSize)
                    self.titleNode.alpha = progress
                }
            } else {
                self.titleNode.alpha = 1.0
                self.titleNode.frame = CGRect(origin: CGPoint(x: floor((size.width - titleSize.width) / 2.0), y: contentVerticalOrigin + floorToScreenPixels((nominalHeight - titleSize.height) / 2.0)), size: titleSize)
            }
        }
        
        if let titleView = self.titleView {
            let titleViewSize = CGSize(width: max(1.0, size.width - leftTitleInset - leftTitleInset), height: nominalHeight)
            titleView.frame = CGRect(origin: CGPoint(x: leftTitleInset, y: contentVerticalOrigin), size: titleViewSize)
        }
        
        //self.effectView.frame = self.bounds
    }
    
    public func makeTransitionTitleNode(foregroundColor: UIColor) -> ASDisplayNode? {
        if let title = self.title {
            let node = ASTextNode()
            node.attributedText = NSAttributedString(string: title, font: Font.medium(17.0), textColor: foregroundColor)
            return node
        } else {
            return nil
        }
    }
    
    private func makeTransitionBackButtonNode(accentColor: UIColor) -> NavigationButtonNode? {
        if self.backButtonNode.supernode != nil {
            let node = NavigationButtonNode()
            node.text = self.backButtonNode.text
            node.color = accentColor
            return node
        } else {
            return nil
        }
    }
    
    private func makeTransitionBackArrowNode(accentColor: UIColor) -> ASDisplayNode? {
        if self.backButtonArrow.supernode != nil {
            let node = ASImageNode()
            node.image = backArrowImage(color: accentColor)
            node.frame = self.backButtonArrow.frame
            node.displayWithoutProcessing = true
            node.displaysAsynchronously = false
            return node
        } else {
            return nil
        }
    }
}
