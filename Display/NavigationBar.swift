import UIKit
import AsyncDisplayKit

private var backArrowImageCache: [Int32: UIImage] = [:]

public final class NavigationBarTheme {
    public static func generateBackArrowImage(color: UIColor) -> UIImage? {
        return generateImage(CGSize(width: 13.0, height: 22.0), contextGenerator: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            context.setFillColor(color.cgColor)
            
            let _ = try? drawSvgPath(context, path: "M10.3824541,0.421094342 L1.53851,8.52547877 L1.53851,8.52547877 C0.724154418,9.27173527 0.668949198,10.5368613 1.41520569,11.3512169 C1.45449493,11.3940915 1.49563546,11.435232 1.53851,11.4745212 L10.3824541,19.5789057 L10.3824541,19.5789057 C10.9981509,20.1431158 11.9429737,20.1431158 12.5586704,19.5789057 L12.5586704,19.5789057 L12.5586704,19.5789057 C13.1093629,19.0742639 13.1466944,18.2187464 12.6420526,17.6680539 C12.615484,17.6390608 12.5876635,17.6112403 12.5586704,17.5846717 L4.28186505,10 L12.5586704,2.41532829 L12.5586704,2.41532829 C13.1093629,1.91068651 13.1466944,1.05516904 12.6420526,0.50447654 C12.615484,0.475483443 12.5876635,0.447662941 12.5586704,0.421094342 L12.5586704,0.421094342 L12.5586704,0.421094342 C11.9429737,-0.143115824 10.9981509,-0.143115824 10.3824541,0.421094342 Z ")
        })
    }
    
    public let buttonColor: UIColor
    public let primaryTextColor: UIColor
    public let backgroundColor: UIColor
    public let separatorColor: UIColor
    
    public init(buttonColor: UIColor, primaryTextColor: UIColor, backgroundColor: UIColor, separatorColor: UIColor) {
        self.buttonColor = buttonColor
        self.primaryTextColor = primaryTextColor
        self.backgroundColor = backgroundColor
        self.separatorColor = separatorColor
    }
    
    public func withUpdatedSeparatorColor(_ color: UIColor) -> NavigationBarTheme {
        return NavigationBarTheme(buttonColor: self.buttonColor, primaryTextColor: self.primaryTextColor, backgroundColor: self.backgroundColor, separatorColor: color)
    }
}

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
        if let image = NavigationBarTheme.generateBackArrowImage(color: color) {
            backArrowImageCache[key] = image
            return image
        } else {
            return nil
        }
    }
}

open class NavigationBar: ASDisplayNode {
    private var theme: NavigationBarTheme
    
    var backPressed: () -> () = { }
    
    private var collapsed: Bool {
        get {
            return self.frame.size.height.isLess(than: 44.0)
        }
    }
    
    private let stripeNode: ASDisplayNode
    private let clippingNode: ASDisplayNode
    
    var contentNode: NavigationBarContentNode?
    
    private var itemTitleListenerKey: Int?
    private var itemTitleViewListenerKey: Int?
    
    private var itemLeftButtonListenerKey: Int?
    private var itemLeftButtonSetEnabledListenerKey: Int?
    
    private var itemRightButtonListenerKey: Int?
    private var itemRightButtonSetEnabledListenerKey: Int?
    
    private var itemBadgeListenerKey: Int?
    
    private var _item: UINavigationItem?
    public var item: UINavigationItem? {
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
                
                if let itemLeftButtonSetEnabledListenerKey = self.itemLeftButtonSetEnabledListenerKey {
                    previousValue.leftBarButtonItem?.removeSetEnabledListener(itemLeftButtonSetEnabledListenerKey)
                    self.itemLeftButtonSetEnabledListenerKey = nil
                }
                
                if let itemRightButtonListenerKey = self.itemRightButtonListenerKey {
                    previousValue.removeSetRightBarButtonItemListener(itemRightButtonListenerKey)
                    self.itemRightButtonListenerKey = nil
                }
                
                if let itemRightButtonSetEnabledListenerKey = self.itemRightButtonSetEnabledListenerKey {
                    previousValue.rightBarButtonItem?.removeSetEnabledListener(itemRightButtonSetEnabledListenerKey)
                    self.itemRightButtonSetEnabledListenerKey = nil
                }
                
                if let itemBadgeListenerKey = self.itemBadgeListenerKey {
                    previousValue.removeSetBadgeListener(itemBadgeListenerKey)
                    self.itemBadgeListenerKey = nil
                }
            }
            self._item = value
            
            self.leftButtonNode.removeFromSupernode()
            self.rightButtonNode.removeFromSupernode()
            
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
                
                self.itemLeftButtonListenerKey = item.addSetLeftBarButtonItemListener { [weak self] previousItem, _, _ in
                    if let strongSelf = self {
                        if let itemLeftButtonSetEnabledListenerKey = strongSelf.itemLeftButtonSetEnabledListenerKey {
                            previousItem?.removeSetEnabledListener(itemLeftButtonSetEnabledListenerKey)
                            strongSelf.itemLeftButtonSetEnabledListenerKey = nil
                        }
                        
                        strongSelf.updateLeftButton()
                        strongSelf.invalidateCalculatedLayout()
                        strongSelf.setNeedsLayout()
                    }
                }
                
                self.itemRightButtonListenerKey = item.addSetRightBarButtonItemListener { [weak self] previousItem, currentItem, _ in
                    if let strongSelf = self {
                        if let itemRightButtonSetEnabledListenerKey = strongSelf.itemRightButtonSetEnabledListenerKey {
                            previousItem?.removeSetEnabledListener(itemRightButtonSetEnabledListenerKey)
                            strongSelf.itemRightButtonSetEnabledListenerKey = nil
                        }
                        
                        if let currentItem = currentItem {
                            strongSelf.itemRightButtonSetEnabledListenerKey = currentItem.addSetEnabledListener { _ in
                                if let strongSelf = self {
                                    strongSelf.updateRightButton()
                                }
                            }
                        }
                        
                        strongSelf.updateRightButton()
                        strongSelf.invalidateCalculatedLayout()
                        strongSelf.setNeedsLayout()
                    }
                }
                
                self.itemBadgeListenerKey = item.addSetBadgeListener { [weak self] text in
                    if let strongSelf = self {
                        strongSelf.updateBadgeText(text: text)
                    }
                }
                self.updateBadgeText(text: item.badge)
                
                self.updateLeftButton()
                self.updateRightButton()
            } else {
                self.title = nil
                self.updateLeftButton()
                self.updateRightButton()
            }
            self.invalidateCalculatedLayout()
        }
    }
    
    private var title: String? {
        didSet {
            if let title = self.title {
                self.titleNode.attributedText = NSAttributedString(string: title, font: Font.semibold(17.0), textColor: self.theme.primaryTextColor)
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
    var previousItemBackListenerKey: Int?
    
    var _previousItem: UINavigationItem?
    var previousItem: UINavigationItem? {
        get {
            return self._previousItem
        } set(value) {
            if let previousValue = self._previousItem {
                if let previousItemListenerKey = self.previousItemListenerKey {
                    previousValue.removeSetTitleListener(previousItemListenerKey)
                    self.previousItemListenerKey = nil
                }
                if let previousItemBackListenerKey = self.previousItemBackListenerKey {
                    previousValue.removeSetBackBarButtonItemListener(previousItemBackListenerKey)
                    self.previousItemBackListenerKey = nil
                }
            }
            self._previousItem = value
            
            if let previousItem = value {
                self.previousItemListenerKey = previousItem.addSetTitleListener { [weak self] _ in
                    if let strongSelf = self, let previousItem = strongSelf.previousItem {
                        if let backBarButtonItem = previousItem.backBarButtonItem {
                            strongSelf.backButtonNode.text = backBarButtonItem.title ?? ""
                        } else {
                            strongSelf.backButtonNode.text = previousItem.title ?? ""
                        }
                        strongSelf.invalidateCalculatedLayout()
                    }
                }
                
                self.previousItemBackListenerKey = previousItem.addSetBackBarButtonItemListener { [weak self] _, _, _ in
                    if let strongSelf = self, let previousItem = strongSelf.previousItem {
                        if let backBarButtonItem = previousItem.backBarButtonItem {
                            strongSelf.backButtonNode.text = backBarButtonItem.title ?? ""
                        } else {
                            strongSelf.backButtonNode.text = previousItem.title ?? ""
                        }
                        strongSelf.invalidateCalculatedLayout()
                    }
                }
            }
            self.updateLeftButton()
            
            self.invalidateCalculatedLayout()
        }
    }
    
    private func updateBadgeText(text: String?) {
        let actualText = text ?? ""
        if self.badgeNode.text != actualText {
            self.badgeNode.text = actualText
            self.badgeNode.isHidden = actualText.isEmpty
            
            self.invalidateCalculatedLayout()
            self.setNeedsLayout()
        }
    }
    
    private func updateLeftButton() {
        if let item = self.item {
            if let leftBarButtonItem = item.leftBarButtonItem {
                self.backButtonNode.removeFromSupernode()
                self.backButtonArrow.removeFromSupernode()
                self.badgeNode.removeFromSupernode()
                
                self.leftButtonNode.text = leftBarButtonItem.title ?? ""
                self.leftButtonNode.bold = leftBarButtonItem.style == .done
                self.leftButtonNode.isEnabled = leftBarButtonItem.isEnabled
                if self.leftButtonNode.supernode == nil {
                    self.clippingNode.addSubnode(self.leftButtonNode)
                }
            } else {
                self.leftButtonNode.removeFromSupernode()
                
                if let previousItem = self.previousItem {
                    if let backBarButtonItem = previousItem.backBarButtonItem {
                        self.backButtonNode.text = backBarButtonItem.title ?? "Back"
                    } else {
                        self.backButtonNode.text = previousItem.title ?? "Back"
                    }
                    
                    if self.backButtonNode.supernode == nil {
                        self.clippingNode.addSubnode(self.backButtonNode)
                        self.clippingNode.addSubnode(self.backButtonArrow)
                        self.clippingNode.addSubnode(self.badgeNode)
                    }
                } else {
                    self.backButtonNode.removeFromSupernode()
                    
                }
            }
        } else {
            self.leftButtonNode.removeFromSupernode()
            self.backButtonNode.removeFromSupernode()
            self.backButtonArrow.removeFromSupernode()
            self.badgeNode.removeFromSupernode()
        }
    }
    
    private func updateRightButton() {
        if let item = self.item {
            if let rightBarButtonItem = item.rightBarButtonItem {
                self.rightButtonNode.text = rightBarButtonItem.title ?? ""
                self.rightButtonNode.image = rightBarButtonItem.image
                self.rightButtonNode.bold = rightBarButtonItem.style == .done
                self.rightButtonNode.isEnabled = rightBarButtonItem.isEnabled
                self.rightButtonNode.node = rightBarButtonItem.customDisplayNode
                if self.rightButtonNode.supernode == nil {
                    self.clippingNode.addSubnode(self.rightButtonNode)
                }
            } else {
                self.rightButtonNode.removeFromSupernode()
            }
        } else {
            self.rightButtonNode.removeFromSupernode()
        }
    }
    
    private let backButtonNode: NavigationButtonNode
    private let badgeNode: NavigationBarBadgeNode
    private let backButtonArrow: ASImageNode
    private let leftButtonNode: NavigationButtonNode
    private let rightButtonNode: NavigationButtonNode
    
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
                
                if let transitionBadgeNode = self.transitionBadgeNode {
                    transitionBadgeNode.removeFromSupernode()
                    self.transitionBadgeNode = nil
                }

                if let value = value {
                    switch value.role {
                        case .top:
                            if let transitionTitleNode = value.navigationBar?.makeTransitionTitleNode(foregroundColor: self.theme.primaryTextColor) {
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
                            if let transitionBackButtonNode = value.navigationBar?.makeTransitionBackButtonNode(accentColor: self.theme.buttonColor) {
                                self.transitionBackButtonNode = transitionBackButtonNode
                                self.clippingNode.addSubnode(transitionBackButtonNode)
                            }
                            if let transitionBackArrowNode = value.navigationBar?.makeTransitionBackArrowNode(accentColor: self.theme.buttonColor) {
                                self.transitionBackArrowNode = transitionBackArrowNode
                                self.clippingNode.addSubnode(transitionBackArrowNode)
                            }
                            if let transitionBadgeNode = value.navigationBar?.makeTransitionBadgeNode() {
                                self.transitionBadgeNode = transitionBadgeNode
                                self.clippingNode.addSubnode(transitionBadgeNode)
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
    private var transitionBadgeNode: ASDisplayNode?
    
    public init(theme: NavigationBarTheme) {
        self.theme = theme
        self.stripeNode = ASDisplayNode()
        
        self.titleNode = ASTextNode()
        self.backButtonNode = NavigationButtonNode()
        self.badgeNode = NavigationBarBadgeNode(fillColor: .red, textColor: .white)
        self.badgeNode.isUserInteractionEnabled = false
        self.badgeNode.isHidden = true
        self.backButtonArrow = ASImageNode()
        self.backButtonArrow.displayWithoutProcessing = true
        self.backButtonArrow.displaysAsynchronously = false
        self.leftButtonNode = NavigationButtonNode()
        self.rightButtonNode = NavigationButtonNode()
        
        self.clippingNode = ASDisplayNode()
        self.clippingNode.clipsToBounds = true
        
        self.backButtonNode.color = self.theme.buttonColor
        self.leftButtonNode.color = self.theme.buttonColor
        self.rightButtonNode.color = self.theme.buttonColor
        self.backButtonArrow.image = backArrowImage(color: self.theme.buttonColor)
        if let title = self.title {
            self.titleNode.attributedText = NSAttributedString(string: title, font: Font.semibold(17.0), textColor: self.theme.primaryTextColor)
        }
        self.stripeNode.backgroundColor = self.theme.separatorColor
        
        super.init()
        
        self.addSubnode(self.clippingNode)
        
        self.backgroundColor = self.theme.backgroundColor
        
        self.stripeNode.isLayerBacked = true
        self.stripeNode.displaysAsynchronously = false
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
            self?.backPressed()
        }
        
        self.leftButtonNode.pressed = { [weak self] in
            if let item = self?.item, let leftBarButtonItem = item.leftBarButtonItem {
                leftBarButtonItem.performActionOnTarget()
            }
        }
        
        self.rightButtonNode.pressed = { [weak self] in
            if let item = self?.item, let rightBarButtonItem = item.rightBarButtonItem {
                rightBarButtonItem.performActionOnTarget()
            }
        }
    }
    
    public func updateTheme(_ theme: NavigationBarTheme) {
        if theme !== self.theme {
            self.theme = theme
            
            self.backgroundColor = self.theme.backgroundColor
            
            self.backButtonNode.color = self.theme.buttonColor
            self.leftButtonNode.color = self.theme.buttonColor
            self.rightButtonNode.color = self.theme.buttonColor
            self.backButtonArrow.image = backArrowImage(color: self.theme.buttonColor)
            if let title = self.title {
                self.titleNode.attributedText = NSAttributedString(string: title, font: Font.semibold(17.0), textColor: self.theme.primaryTextColor)
            }
            self.stripeNode.backgroundColor = self.theme.separatorColor
        }
    }
    
    open override func layout() {
        let size = self.bounds.size
        
        let leftButtonInset: CGFloat = 8.0
        let backButtonInset: CGFloat = 27.0
        
        self.clippingNode.frame = CGRect(origin: CGPoint(), size: size)
        self.contentNode?.frame = CGRect(origin: CGPoint(), size: size)
        
        self.stripeNode.frame = CGRect(x: 0.0, y: size.height, width: size.width, height: UIScreenPixel)
        
        let nominalHeight: CGFloat = self.collapsed ? 32.0 : 44.0
        let contentVerticalOrigin = size.height - nominalHeight
        
        var leftTitleInset: CGFloat = 8.0
        var rightTitleInset: CGFloat = 8.0
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
                        self.backButtonNode.alpha = (1.0 - progress) * (1.0 - progress)
                    
                        if let transitionTitleNode = self.transitionTitleNode {
                            let transitionTitleSize = transitionTitleNode.measure(CGSize(width: size.width, height: nominalHeight))
                            
                            let initialX: CGFloat = backButtonInset + floor((backButtonSize.width - transitionTitleSize.width) / 2.0)
                            let finalX: CGFloat = floor((size.width - transitionTitleSize.width) / 2.0) - size.width
                            
                            transitionTitleNode.frame = CGRect(origin: CGPoint(x: initialX * (1.0 - progress) + finalX * progress, y: contentVerticalOrigin + floor((nominalHeight - transitionTitleSize.height) / 2.0)), size: transitionTitleSize)
                            transitionTitleNode.alpha = progress * progress
                        }
                    
                        self.backButtonArrow.frame = CGRect(origin: CGPoint(x: 8.0 - progress * size.width, y: contentVerticalOrigin + floor((nominalHeight - 22.0) / 2.0)), size: CGSize(width: 13.0, height: 22.0))
                        self.backButtonArrow.alpha = max(0.0, 1.0 - progress * 1.3)
                        self.badgeNode.alpha = max(0.0, 1.0 - progress * 1.3)
                    case .bottom:
                        self.backButtonNode.alpha = 1.0
                        self.backButtonNode.frame = CGRect(origin: CGPoint(x: backButtonInset, y: contentVerticalOrigin + floor((nominalHeight - backButtonSize.height) / 2.0)), size: backButtonSize)
                        self.backButtonArrow.alpha = 1.0
                        self.backButtonArrow.frame = CGRect(origin: CGPoint(x: 8.0, y: contentVerticalOrigin + floor((nominalHeight - 22.0) / 2.0)), size: CGSize(width: 13.0, height: 22.0))
                        self.badgeNode.alpha = 1.0
                }
            } else {
                self.backButtonNode.alpha = 1.0
                self.backButtonNode.frame = CGRect(origin: CGPoint(x: backButtonInset, y: contentVerticalOrigin + floor((nominalHeight - backButtonSize.height) / 2.0)), size: backButtonSize)
                self.backButtonArrow.alpha = 1.0
                self.backButtonArrow.frame = CGRect(origin: CGPoint(x: 8.0, y: contentVerticalOrigin + floor((nominalHeight - 22.0) / 2.0)), size: CGSize(width: 13.0, height: 22.0))
                self.badgeNode.alpha = 1.0
            }
        } else if self.leftButtonNode.supernode != nil {
            let leftButtonSize = self.leftButtonNode.measure(CGSize(width: size.width, height: nominalHeight))
            leftTitleInset += leftButtonSize.width + leftButtonInset + 8.0 + 8.0
            
            self.leftButtonNode.alpha = 1.0
            self.leftButtonNode.frame = CGRect(origin: CGPoint(x: leftButtonInset, y: contentVerticalOrigin + floor((nominalHeight - leftButtonSize.height) / 2.0)), size: leftButtonSize)
        }
        
        let badgeSize = self.badgeNode.measure(CGSize(width: 200.0, height: 100.0))
        let backButtonArrowFrame = self.backButtonArrow.frame
        self.badgeNode.frame = CGRect(origin: backButtonArrowFrame.origin.offsetBy(dx: 7.0, dy: -9.0), size: badgeSize)
        
        if self.rightButtonNode.supernode != nil {
            let rightButtonSize = self.rightButtonNode.measure(CGSize(width: size.width, height: nominalHeight))
            rightTitleInset += rightButtonSize.width + leftButtonInset + 8.0 + 8.0
            self.rightButtonNode.alpha = 1.0
            self.rightButtonNode.frame = CGRect(origin: CGPoint(x: size.width - leftButtonInset - rightButtonSize.width, y: contentVerticalOrigin + floor((nominalHeight - rightButtonSize.height) / 2.0)), size: rightButtonSize)
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
                        transitionBackButtonNode.alpha = (1.0 - progress) * (1.0 - progress)
                    }
                
                    if let transitionBackArrowNode = self.transitionBackArrowNode {
                        let initialX: CGFloat = 8.0 + size.width * 0.3
                        let finalX: CGFloat = 8.0
                        
                        transitionBackArrowNode.frame = CGRect(origin: CGPoint(x: initialX * (1.0 - progress) + finalX * progress, y: contentVerticalOrigin + floor((nominalHeight - 22.0) / 2.0)), size: CGSize(width: 13.0, height: 22.0))
                        transitionBackArrowNode.alpha = max(0.0, 1.0 - progress * 1.3)
                        
                        if let transitionBadgeNode = self.transitionBadgeNode {
                            transitionBadgeNode.frame = CGRect(origin: transitionBackArrowNode.frame.origin.offsetBy(dx: 7.0, dy: -9.0), size: transitionBadgeNode.bounds.size)
                            transitionBadgeNode.alpha = transitionBackArrowNode.alpha
                        }
                    }
                }
        }
        
        leftTitleInset = floor(leftTitleInset)
        if Int(leftTitleInset) % 2 != 0 {
            leftTitleInset -= 1.0
        }
        
        if self.titleNode.supernode != nil {
            let titleSize = self.titleNode.measure(CGSize(width: max(1.0, size.width - max(leftTitleInset, rightTitleInset) * 2.0), height: nominalHeight))
            
            if let transitionState = self.transitionState, let otherNavigationBar = transitionState.navigationBar {
                let progress = transitionState.progress
                
                switch transitionState.role {
                    case .top:
                        let initialX = floor((size.width - titleSize.width) / 2.0)
                        let finalX: CGFloat = leftButtonInset
                        
                        self.titleNode.frame = CGRect(origin: CGPoint(x: initialX * (1.0 - progress) + finalX * progress, y: contentVerticalOrigin + floorToScreenPixels((nominalHeight - titleSize.height) / 2.0)), size: titleSize)
                        self.titleNode.alpha = (1.0 - progress) * (1.0 - progress)
                    case .bottom:
                        var initialX: CGFloat = backButtonInset
                        if otherNavigationBar.backButtonNode.supernode != nil {
                            initialX += floor((otherNavigationBar.backButtonNode.frame.size.width - titleSize.width) / 2.0)
                        }
                        initialX += size.width * 0.3
                        let finalX: CGFloat = floor((size.width - titleSize.width) / 2.0)
                        
                        self.titleNode.frame = CGRect(origin: CGPoint(x: initialX * (1.0 - progress) + finalX * progress, y: contentVerticalOrigin + floorToScreenPixels((nominalHeight - titleSize.height) / 2.0)), size: titleSize)
                    self.titleNode.alpha = progress * progress
                }
            } else {
                self.titleNode.alpha = 1.0
                self.titleNode.frame = CGRect(origin: CGPoint(x: floor((size.width - titleSize.width) / 2.0), y: contentVerticalOrigin + floorToScreenPixels((nominalHeight - titleSize.height) / 2.0)), size: titleSize)
            }
        }
        
        if let titleView = self.titleView {
            let titleSize = CGSize(width: max(1.0, size.width - leftTitleInset - leftTitleInset), height: nominalHeight)
            titleView.frame = CGRect(origin: CGPoint(x: leftTitleInset, y: contentVerticalOrigin), size: titleSize)
            
            if let transitionState = self.transitionState, let otherNavigationBar = transitionState.navigationBar {
                let progress = transitionState.progress
                
                switch transitionState.role {
                    case .top:
                        let initialX = floor((size.width - titleSize.width) / 2.0)
                        let finalX: CGFloat = leftButtonInset
                        
                        titleView.frame = CGRect(origin: CGPoint(x: initialX * (1.0 - progress) + finalX * progress, y: contentVerticalOrigin + floorToScreenPixels((nominalHeight - titleSize.height) / 2.0)), size: titleSize)
                        titleView.alpha = (1.0 - progress) * (1.0 - progress)
                    case .bottom:
                        var initialX: CGFloat = backButtonInset
                        if otherNavigationBar.backButtonNode.supernode != nil {
                            initialX += floor((otherNavigationBar.backButtonNode.frame.size.width - titleSize.width) / 2.0)
                        }
                        initialX += size.width * 0.3
                        let finalX: CGFloat = floor((size.width - titleSize.width) / 2.0)
                        
                        titleView.frame = CGRect(origin: CGPoint(x: initialX * (1.0 - progress) + finalX * progress, y: contentVerticalOrigin + floorToScreenPixels((nominalHeight - titleSize.height) / 2.0)), size: titleSize)
                        titleView.alpha = progress * progress
                }
            } else {
                titleView.alpha = 1.0
                titleView.frame = CGRect(origin: CGPoint(x: floor((size.width - titleSize.width) / 2.0), y: contentVerticalOrigin + floorToScreenPixels((nominalHeight - titleSize.height) / 2.0)), size: titleSize)
            }
        }
    }
    
    public func makeTransitionTitleNode(foregroundColor: UIColor) -> ASDisplayNode? {
        if let titleView = self.titleView {
            if let transitionView = titleView as? NavigationBarTitleTransitionNode {
                return transitionView.makeTransitionMirrorNode()
            } else {
                return nil
            }
        } else if let title = self.title {
            let node = ASTextNode()
            node.attributedText = NSAttributedString(string: title, font: Font.semibold(17.0), textColor: foregroundColor)
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
    
    private func makeTransitionBadgeNode() -> ASDisplayNode? {
        if self.badgeNode.supernode != nil && !self.badgeNode.isHidden {
            let node = NavigationBarBadgeNode(fillColor: .red, textColor: .white)
            node.text = self.badgeNode.text
            let nodeSize = node.measure(CGSize(width: 200.0, height: 100.0))
            node.frame = CGRect(origin: CGPoint(), size: nodeSize)
            return node
        } else {
            return nil
        }
    }
    
    public func setContentNode(_ contentNode: NavigationBarContentNode?, animated: Bool) {
        if self.contentNode !== contentNode {
            if let previous = self.contentNode {
                if animated {
                    previous.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak self, weak previous] _ in
                        if let strongSelf = self, let previous = previous {
                            if previous !== strongSelf.contentNode {
                                previous.removeFromSupernode()
                            }
                        }
                    })
                } else {
                    previous.removeFromSupernode()
                }
            }
            self.contentNode = contentNode
            if let contentNode = contentNode {
                contentNode.layer.removeAnimation(forKey: "opacity")
                self.addSubnode(contentNode)
                if animated {
                    contentNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                }
                
                if !self.clippingNode.alpha.isZero {
                    self.clippingNode.alpha = 0.0
                    if animated {
                        self.clippingNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
                    }
                }
                
                if !self.bounds.size.width.isZero {
                    self.layout()
                } else {
                    self.setNeedsLayout()
                }
            } else if self.clippingNode.alpha.isZero {
                self.clippingNode.alpha = 1.0
                if animated {
                    self.clippingNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                }
            }
        }
    }
}
