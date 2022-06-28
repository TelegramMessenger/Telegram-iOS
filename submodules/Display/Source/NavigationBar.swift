import UIKit
import AsyncDisplayKit
import SwiftSignalKit

private var backArrowImageCache: [Int32: UIImage] = [:]

open class SparseNode: ASDisplayNode {
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.alpha.isZero {
            return nil
        }
        if !self.bounds.contains(point) {
            return nil
        }
        for view in self.view.subviews {
            if let result = view.hitTest(self.view.convert(point, to: view), with: event), result.isUserInteractionEnabled {
                return result
            }
        }
        
        let result = super.hitTest(point, with: event)
        if result != self.view {
            return result
        } else {
            return nil
        }
    }
}

public final class NavigationBarTheme {
    public static func generateBackArrowImage(color: UIColor) -> UIImage? {
        return generateImage(CGSize(width: 13.0, height: 22.0), rotatedContext: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            context.setFillColor(color.cgColor)
            
            context.translateBy(x: 0.0, y: -UIScreenPixel)
            
            let _ = try? drawSvgPath(context, path: "M3.60751322,11.5 L11.5468531,3.56066017 C12.1326395,2.97487373 12.1326395,2.02512627 11.5468531,1.43933983 C10.9610666,0.853553391 10.0113191,0.853553391 9.42553271,1.43933983 L0.449102936,10.4157696 C-0.149700979,11.0145735 -0.149700979,11.9854265 0.449102936,12.5842304 L9.42553271,21.5606602 C10.0113191,22.1464466 10.9610666,22.1464466 11.5468531,21.5606602 C12.1326395,20.9748737 12.1326395,20.0251263 11.5468531,19.4393398 L3.60751322,11.5 Z ")
        })
    }
    
    public let buttonColor: UIColor
    public let disabledButtonColor: UIColor
    public let primaryTextColor: UIColor
    public let backgroundColor: UIColor
    public let enableBackgroundBlur: Bool
    public let separatorColor: UIColor
    public let badgeBackgroundColor: UIColor
    public let badgeStrokeColor: UIColor
    public let badgeTextColor: UIColor
    
    public init(buttonColor: UIColor, disabledButtonColor: UIColor, primaryTextColor: UIColor, backgroundColor: UIColor, enableBackgroundBlur: Bool, separatorColor: UIColor, badgeBackgroundColor: UIColor, badgeStrokeColor: UIColor, badgeTextColor: UIColor) {
        self.buttonColor = buttonColor
        self.disabledButtonColor = disabledButtonColor
        self.primaryTextColor = primaryTextColor
        self.backgroundColor = backgroundColor
        self.enableBackgroundBlur = enableBackgroundBlur
        self.separatorColor = separatorColor
        self.badgeBackgroundColor = badgeBackgroundColor
        self.badgeStrokeColor = badgeStrokeColor
        self.badgeTextColor = badgeTextColor
    }
    
    public func withUpdatedBackgroundColor(_ color: UIColor) -> NavigationBarTheme {
        return NavigationBarTheme(buttonColor: self.buttonColor, disabledButtonColor: self.disabledButtonColor, primaryTextColor: self.primaryTextColor, backgroundColor: color, enableBackgroundBlur: false, separatorColor: self.separatorColor, badgeBackgroundColor: self.badgeBackgroundColor, badgeStrokeColor: self.badgeStrokeColor, badgeTextColor: self.badgeTextColor)
    }
    
    public func withUpdatedSeparatorColor(_ color: UIColor) -> NavigationBarTheme {
        return NavigationBarTheme(buttonColor: self.buttonColor, disabledButtonColor: self.disabledButtonColor, primaryTextColor: self.primaryTextColor, backgroundColor: self.backgroundColor, enableBackgroundBlur: self.enableBackgroundBlur, separatorColor: color, badgeBackgroundColor: self.badgeBackgroundColor, badgeStrokeColor: self.badgeStrokeColor, badgeTextColor: self.badgeTextColor)
    }
}

public final class NavigationBarStrings {
    public let back: String
    public let close: String
    
    public init(back: String, close: String) {
        self.back = back
        self.close = close
    }
}

public final class NavigationBarPresentationData {
    public let theme: NavigationBarTheme
    public let strings: NavigationBarStrings
    
    public init(theme: NavigationBarTheme, strings: NavigationBarStrings) {
        self.theme = theme
        self.strings = strings
    }
}

enum NavigationPreviousAction: Equatable {
    case item(UINavigationItem)
    case close
    
    static func ==(lhs: NavigationPreviousAction, rhs: NavigationPreviousAction) -> Bool {
        switch lhs {
            case let .item(lhsItem):
                if case let .item(rhsItem) = rhs, lhsItem === rhsItem {
                    return true
                } else {
                    return false
                }
            case .close:
                if case .close = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}

private var sharedIsReduceTransparencyEnabled = UIAccessibility.isReduceTransparencyEnabled

public final class NavigationBackgroundNode: ASDisplayNode {
    private var _color: UIColor

    private var enableBlur: Bool

    private var effectView: UIVisualEffectView?
    private let backgroundNode: ASDisplayNode

    private var validLayout: (CGSize, CGFloat)?
    
    public var backgroundCornerRadius: CGFloat {
        if let (_, cornerRadius) = self.validLayout {
            return cornerRadius
        } else {
            return 0.0
        }
    }

    public init(color: UIColor, enableBlur: Bool = true) {
        self._color = .clear
        self.enableBlur = enableBlur

        self.backgroundNode = ASDisplayNode()

        super.init()

        self.addSubnode(self.backgroundNode)

        self.updateColor(color: color, transition: .immediate)
    }

    
    public override func didLoad() {
        super.didLoad()
        
        if self.scheduledUpdate {
            self.scheduledUpdate = false
            self.updateBackgroundBlur(forceKeepBlur: false)
        }
    }
    
    private var scheduledUpdate = false
    
    private func updateBackgroundBlur(forceKeepBlur: Bool) {
        guard self.isNodeLoaded else {
            self.scheduledUpdate = true
            return
        }
        if self.enableBlur && !sharedIsReduceTransparencyEnabled && ((self._color.alpha > .ulpOfOne && self._color.alpha < 0.95) || forceKeepBlur) {
            if self.effectView == nil {
                let effectView = UIVisualEffectView(effect: UIBlurEffect(style: .light))

                for subview in effectView.subviews {
                    if subview.description.contains("VisualEffectSubview") {
                        subview.isHidden = true
                    }
                }

                if let sublayer = effectView.layer.sublayers?[0], let filters = sublayer.filters {
                    sublayer.backgroundColor = nil
                    sublayer.isOpaque = false
                    let allowedKeys: [String] = [
                        "colorSaturate",
                        "gaussianBlur"
                    ]
                    sublayer.filters = filters.filter { filter in
                        guard let filter = filter as? NSObject else {
                            return true
                        }
                        let filterName = String(describing: filter)
                        if !allowedKeys.contains(filterName) {
                            return false
                        }
                        return true
                    }
                }

                if let (size, cornerRadius) = self.validLayout {
                    effectView.frame = CGRect(origin: CGPoint(), size: size)
                    ContainedViewLayoutTransition.immediate.updateCornerRadius(layer: effectView.layer, cornerRadius: cornerRadius)
                    effectView.clipsToBounds = !cornerRadius.isZero
                }
                self.effectView = effectView
                self.view.insertSubview(effectView, at: 0)
            }
        } else if let effectView = self.effectView {
            self.effectView = nil
            effectView.removeFromSuperview()
        }
    }

    public func updateColor(color: UIColor, enableBlur: Bool? = nil, forceKeepBlur: Bool = false, transition: ContainedViewLayoutTransition) {
        let effectiveEnableBlur = enableBlur ?? self.enableBlur

        if self._color.isEqual(color) && self.enableBlur == effectiveEnableBlur {
            return
        }
        self._color = color
        self.enableBlur = effectiveEnableBlur

        if sharedIsReduceTransparencyEnabled {
            transition.updateBackgroundColor(node: self.backgroundNode, color: self._color.withAlphaComponent(1.0))
        } else {
            transition.updateBackgroundColor(node: self.backgroundNode, color: self._color)
        }

        self.updateBackgroundBlur(forceKeepBlur: forceKeepBlur)
    }

    public func update(size: CGSize, cornerRadius: CGFloat = 0.0, transition: ContainedViewLayoutTransition) {
        self.validLayout = (size, cornerRadius)

        let contentFrame = CGRect(origin: CGPoint(), size: size)
        transition.updateFrame(node: self.backgroundNode, frame: contentFrame, beginWithCurrentState: true)
        if let effectView = self.effectView, effectView.frame != contentFrame {
            transition.updateFrame(layer: effectView.layer, frame: contentFrame, beginWithCurrentState: true)
            if let sublayers = effectView.layer.sublayers {
                for sublayer in sublayers {
                    transition.updateFrame(layer: sublayer, frame: contentFrame, beginWithCurrentState: true)
                }
            }
        }

        transition.updateCornerRadius(node: self.backgroundNode, cornerRadius: cornerRadius)
        if let effectView = self.effectView {
            transition.updateCornerRadius(layer: effectView.layer, cornerRadius: cornerRadius)
            effectView.clipsToBounds = !cornerRadius.isZero
        }
    }
    
    public func update(size: CGSize, cornerRadius: CGFloat = 0.0, animator: ControlledTransitionAnimator) {
        self.validLayout = (size, cornerRadius)

        let contentFrame = CGRect(origin: CGPoint(), size: size)
        animator.updateFrame(layer: self.backgroundNode.layer, frame: contentFrame, completion: nil)
        if let effectView = self.effectView, effectView.frame != contentFrame {
            animator.updateFrame(layer: effectView.layer, frame: contentFrame, completion: nil)
            if let sublayers = effectView.layer.sublayers {
                for sublayer in sublayers {
                    animator.updateFrame(layer: sublayer, frame: contentFrame, completion: nil)
                }
            }
        }

        animator.updateCornerRadius(layer: self.backgroundNode.layer, cornerRadius: cornerRadius, completion: nil)
        if let effectView = self.effectView {
            animator.updateCornerRadius(layer: effectView.layer, cornerRadius: cornerRadius, completion: nil)
            effectView.clipsToBounds = !cornerRadius.isZero
        }
    }
}

open class NavigationBar: ASDisplayNode {
    public static var defaultSecondaryContentHeight: CGFloat {
        return 38.0
    }
    
    static func backArrowImage(color: UIColor) -> UIImage? {
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

    public static let titleFont = Font.with(size: 17.0, design: .regular, weight: .semibold, traits: [.monospacedNumbers])
    
    var presentationData: NavigationBarPresentationData
    
    private var validLayout: (size: CGSize, defaultHeight: CGFloat, additionalTopHeight: CGFloat, additionalContentHeight: CGFloat, additionalBackgroundHeight: CGFloat, leftInset: CGFloat, rightInset: CGFloat, appearsHidden: Bool, isLandscape: Bool)?
    private var requestedLayout: Bool = false
    var requestContainerLayout: (ContainedViewLayoutTransition) -> Void = { _ in }
    
    public var backPressed: () -> () = { }
    
    public var userInfo: Any?
    public var makeCustomTransitionNode: ((NavigationBar, Bool) -> CustomNavigationTransitionNode?)?
    public var allowsCustomTransition: (() -> Bool)?
    
    private var collapsed: Bool {
        get {
            return self.frame.size.height.isLess(than: 44.0)
        }
    }
    
    private let stripeNode: ASDisplayNode
    private let clippingNode: SparseNode
    private let buttonsContainerNode: ASDisplayNode
    
    public private(set) var contentNode: NavigationBarContentNode?
    public private(set) var secondaryContentNode: ASDisplayNode?
    
    private var itemTitleListenerKey: Int?
    private var itemTitleViewListenerKey: Int?
    
    private var itemLeftButtonListenerKey: Int?
    private var itemLeftButtonSetEnabledListenerKey: Int?
    
    private var itemRightButtonListenerKey: Int?
    private var itemRightButtonsListenerKey: Int?
    
    private var itemBadgeListenerKey: Int?
    
    private var hintAnimateTitleNodeOnNextLayout: Bool = false
    
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
                
                if let itemRightButtonsListenerKey = self.itemRightButtonsListenerKey {
                    previousValue.removeSetMultipleRightBarButtonItemsListener(itemRightButtonsListenerKey)
                    self.itemRightButtonsListenerKey = nil
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
                self.itemTitleListenerKey = item.addSetTitleListener { [weak self] text, animated in
                    if let strongSelf = self {
                        let animateIn = animated && (strongSelf.title?.isEmpty ?? true)
                        strongSelf.title = text
                        if animateIn {
                            strongSelf.titleNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                        }
                    }
                }
                
                self.titleView = item.titleView
                self.itemTitleViewListenerKey = item.addSetTitleViewListener { [weak self] titleView in
                    if let strongSelf = self {
                        strongSelf.titleView = titleView
                    }
                }
                
                self.itemLeftButtonListenerKey = item.addSetLeftBarButtonItemListener { [weak self] previousItem, _, animated in
                    if let strongSelf = self {
                        if let itemLeftButtonSetEnabledListenerKey = strongSelf.itemLeftButtonSetEnabledListenerKey {
                            previousItem?.removeSetEnabledListener(itemLeftButtonSetEnabledListenerKey)
                            strongSelf.itemLeftButtonSetEnabledListenerKey = nil
                        }
                        
                        strongSelf.updateLeftButton(animated: animated)
                        strongSelf.invalidateCalculatedLayout()
                        strongSelf.requestLayout()
                    }
                }
                
                self.itemRightButtonListenerKey = item.addSetRightBarButtonItemListener { [weak self] previousItem, currentItem, animated in
                    if let strongSelf = self {
                        strongSelf.updateRightButton(animated: animated)
                        strongSelf.invalidateCalculatedLayout()
                        strongSelf.requestLayout()
                    }
                }
                
                self.itemRightButtonsListenerKey = item.addSetMultipleRightBarButtonItemsListener { [weak self] items, animated in
                    if let strongSelf = self {
                        strongSelf.updateRightButton(animated: animated)
                        strongSelf.invalidateCalculatedLayout()
                        strongSelf.requestLayout()
                    }
                }
                
                self.itemBadgeListenerKey = item.addSetBadgeListener { [weak self] text in
                    if let strongSelf = self {
                        strongSelf.updateBadgeText(text: text)
                    }
                }
                self.updateBadgeText(text: item.badge)
                
                self.updateLeftButton(animated: false)
                self.updateRightButton(animated: false)
            } else {
                self.title = nil
                self.updateLeftButton(animated: false)
                self.updateRightButton(animated: false)
            }
            self.invalidateCalculatedLayout()
            self.requestLayout()
        }
    }
    
    public var customBackButtonText: String?
    
    private var title: String? {
        didSet {
            if let title = self.title {
                self.titleNode.attributedText = NSAttributedString(string: title, font: NavigationBar.titleFont, textColor: self.presentationData.theme.primaryTextColor)
                self.titleNode.accessibilityLabel = title
                if self.titleNode.supernode == nil {
                    self.buttonsContainerNode.addSubnode(self.titleNode)
                }
            } else {
                self.titleNode.removeFromSupernode()
            }
            
            self.updateAccessibilityElements()
            self.invalidateCalculatedLayout()
            self.requestLayout()
        }
    }
    
    public private(set) var titleView: UIView? {
        didSet {
            if let oldValue = oldValue {
                oldValue.removeFromSuperview()
            }
            
            if let titleView = self.titleView {
                self.buttonsContainerNode.view.addSubview(titleView)
            }
            
            self.invalidateCalculatedLayout()
            self.requestLayout()
        }
    }
    
    public var layoutSuspended: Bool = false
    
    private let titleNode: ImmediateTextNode
    
    var previousItemListenerKey: Int?
    var previousItemBackListenerKey: Int?
    
    private func updateAccessibilityElements() {
    }
    
    override open var accessibilityElements: [Any]? {
        get {
            var accessibilityElements: [Any] = []
            if self.backButtonNode.supernode != nil {
                addAccessibilityChildren(of: self.backButtonNode, container: self, to: &accessibilityElements)
            }
            if self.leftButtonNode.supernode != nil {
                addAccessibilityChildren(of: self.leftButtonNode, container: self, to: &accessibilityElements)
            }
            if self.titleNode.supernode != nil {
                addAccessibilityChildren(of: self.titleNode, container: self, to: &accessibilityElements)
                accessibilityElements.append(self.titleNode)
            }
            if let titleView = self.titleView, titleView.superview != nil {
                titleView.accessibilityFrame = UIAccessibility.convertToScreenCoordinates(titleView.bounds, in: titleView)
                accessibilityElements.append(titleView)
            }
            if self.rightButtonNode.supernode != nil {
                addAccessibilityChildren(of: self.rightButtonNode, container: self, to: &accessibilityElements)
            }
            if let contentNode = self.contentNode {
                addAccessibilityChildren(of: contentNode, container: self, to: &accessibilityElements)
            }
            return accessibilityElements
        } set(value) {
        }
    }
    
    override open func didLoad() {
        super.didLoad()
        
        self.updateAccessibilityElements()
    }
    
    var _previousItem: NavigationPreviousAction?
    var previousItem: NavigationPreviousAction? {
        get {
            return self._previousItem
        } set(value) {
            if self._previousItem != value {
                if let previousValue = self._previousItem, case let .item(itemValue) = previousValue {
                    if let previousItemListenerKey = self.previousItemListenerKey {
                        itemValue.removeSetTitleListener(previousItemListenerKey)
                        self.previousItemListenerKey = nil
                    }
                    if let previousItemBackListenerKey = self.previousItemBackListenerKey {
                        itemValue.removeSetBackBarButtonItemListener(previousItemBackListenerKey)
                        self.previousItemBackListenerKey = nil
                    }
                }
                self._previousItem = value
                
                if let previousItem = value {
                    switch previousItem {
                        case let .item(itemValue):
                            self.previousItemListenerKey = itemValue.addSetTitleListener { [weak self] _, _ in
                                if let strongSelf = self, let previousItem = strongSelf.previousItem, case let .item(itemValue) = previousItem {
                                    if let customBackButtonText = strongSelf.customBackButtonText {
                                        strongSelf.backButtonNode.updateManualText(customBackButtonText, isBack: true)
                                    } else if let backBarButtonItem = itemValue.backBarButtonItem {
                                        strongSelf.backButtonNode.updateManualText(backBarButtonItem.title ?? "", isBack: true)
                                    } else {
                                        strongSelf.backButtonNode.updateManualText(itemValue.title ?? "", isBack: true)
                                    }
                                    strongSelf.invalidateCalculatedLayout()
                                    strongSelf.requestLayout()
                                }
                            }
                            
                            self.previousItemBackListenerKey = itemValue.addSetBackBarButtonItemListener { [weak self] _, _, _ in
                                if let strongSelf = self, let previousItem = strongSelf.previousItem, case let .item(itemValue) = previousItem {
                                    if let customBackButtonText = strongSelf.customBackButtonText {
                                        strongSelf.backButtonNode.updateManualText(customBackButtonText, isBack: true)
                                    } else if let backBarButtonItem = itemValue.backBarButtonItem {
                                        strongSelf.backButtonNode.updateManualText(backBarButtonItem.title ?? "", isBack: true)
                                    } else {
                                        strongSelf.backButtonNode.updateManualText(itemValue.title ?? "", isBack: true)
                                    }
                                    strongSelf.invalidateCalculatedLayout()
                                    strongSelf.requestLayout()
                                }
                            }
                        case .close:
                            break
                    }
                }
                self.updateLeftButton(animated: false)
                
                self.invalidateCalculatedLayout()
                self.requestLayout()
            }
        }
    }
    
    private func updateBadgeText(text: String?) {
        let actualText = text ?? ""
        if self.badgeNode.text != actualText {
            self.badgeNode.text = actualText
            self.badgeNode.isHidden = actualText.isEmpty
            self.backButtonNode.manualAlpha = self.badgeNode.isHidden ? 1.0 : 0.0
            
            self.invalidateCalculatedLayout()
            self.requestLayout()
        }
    }
    
    private func updateLeftButton(animated: Bool) {
        if let item = self.item {
            var needsLeftButton = false
            if let leftBarButtonItem = item.leftBarButtonItem, !leftBarButtonItem.backButtonAppearance {
                needsLeftButton = true
            } else if let previousItem = self.previousItem, case .close = previousItem {
                needsLeftButton = true
            }
            
            if needsLeftButton {
                if animated {
                    if self.leftButtonNode.view.superview != nil {
                        if let snapshotView = self.leftButtonNode.view.snapshotContentTree() {
                            snapshotView.frame = self.leftButtonNode.frame
                            self.leftButtonNode.view.superview?.insertSubview(snapshotView, aboveSubview: self.leftButtonNode.view)
                            snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                                snapshotView?.removeFromSuperview()
                            })
                        }
                    }
                    
                    if self.backButtonNode.view.superview != nil {
                        if let snapshotView = self.backButtonNode.view.snapshotContentTree() {
                            snapshotView.frame = self.backButtonNode.frame
                            self.backButtonNode.view.superview?.insertSubview(snapshotView, aboveSubview: self.backButtonNode.view)
                            snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                                snapshotView?.removeFromSuperview()
                            })
                        }
                    }
                    
                    if self.backButtonArrow.view.superview != nil {
                        if let snapshotView = self.backButtonArrow.view.snapshotContentTree() {
                            snapshotView.frame = self.backButtonArrow.frame
                            self.backButtonArrow.view.superview?.insertSubview(snapshotView, aboveSubview: self.backButtonArrow.view)
                            snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                                snapshotView?.removeFromSuperview()
                            })
                        }
                    }
                    
                    if self.badgeNode.view.superview != nil {
                        if let snapshotView = self.badgeNode.view.snapshotContentTree() {
                            snapshotView.frame = self.badgeNode.frame
                            self.badgeNode.view.superview?.insertSubview(snapshotView, aboveSubview: self.badgeNode.view)
                            snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                                snapshotView?.removeFromSuperview()
                            })
                        }
                    }
                }
                
                self.backButtonNode.removeFromSupernode()
                self.backButtonArrow.removeFromSupernode()
                self.badgeNode.removeFromSupernode()
                
                if let leftBarButtonItem = item.leftBarButtonItem {
                    self.leftButtonNode.updateItems([leftBarButtonItem])
                } else {
                    self.leftButtonNode.updateItems([UIBarButtonItem(title: self.presentationData.strings.close, style: .plain, target: nil, action: nil)])
                }
                
                if self.leftButtonNode.supernode == nil {
                    self.buttonsContainerNode.addSubnode(self.leftButtonNode)
                }
                
                if animated {
                    self.leftButtonNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                }
            } else {
                if animated, self.leftButtonNode.view.superview != nil {
                    if let snapshotView = self.leftButtonNode.view.snapshotContentTree() {
                        snapshotView.frame = self.leftButtonNode.frame
                        self.leftButtonNode.view.superview?.insertSubview(snapshotView, aboveSubview: self.leftButtonNode.view)
                        snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                            snapshotView?.removeFromSuperview()
                        })
                    }
                }
                self.leftButtonNode.removeFromSupernode()
                
                var backTitle: String?
                if let customBackButtonText = self.customBackButtonText {
                    backTitle = customBackButtonText
                } else if let leftBarButtonItem = item.leftBarButtonItem, leftBarButtonItem.backButtonAppearance {
                    backTitle = leftBarButtonItem.title
                } else if let previousItem = self.previousItem {
                    switch previousItem {
                        case let .item(itemValue):
                            if let backBarButtonItem = itemValue.backBarButtonItem {
                                backTitle = backBarButtonItem.title ?? self.presentationData.strings.back
                            } else {
                                backTitle = itemValue.title ?? self.presentationData.strings.back
                            }
                        case .close:
                            backTitle = nil
                    }
                }
                
                if let backTitle = backTitle {
                    self.backButtonNode.updateManualText(backTitle, isBack: true)
                    if self.backButtonNode.supernode == nil {
                        self.buttonsContainerNode.addSubnode(self.backButtonNode)
                        self.buttonsContainerNode.addSubnode(self.backButtonArrow)
                        self.buttonsContainerNode.addSubnode(self.badgeNode)
                    }
                    
                    if animated {
                        self.backButtonNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                        self.backButtonArrow.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                        self.badgeNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
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
        
        self.updateAccessibilityElements()
        if animated {
            self.hintAnimateTitleNodeOnNextLayout = true
        }
    }
    
    private func updateRightButton(animated: Bool) {
        if let item = self.item {
            var items: [UIBarButtonItem] = []
            if let rightBarButtonItems = item.rightBarButtonItems, !rightBarButtonItems.isEmpty {
                items = rightBarButtonItems
            } else if let rightBarButtonItem = item.rightBarButtonItem {
                items = [rightBarButtonItem]
            }
            
            if !items.isEmpty {
                if animated, self.rightButtonNode.view.superview != nil {
                    if let snapshotView = self.rightButtonNode.view.snapshotContentTree() {
                        snapshotView.frame = self.rightButtonNode.frame
                        self.rightButtonNode.view.superview?.insertSubview(snapshotView, aboveSubview: self.rightButtonNode.view)
                        snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                            snapshotView?.removeFromSuperview()
                        })
                    }
                }
                self.rightButtonNode.updateItems(items)
                if self.rightButtonNode.supernode == nil {
                    self.buttonsContainerNode.addSubnode(self.rightButtonNode)
                }
                if animated {
                    self.rightButtonNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
                }
            } else {
                if animated, self.rightButtonNode.view.superview != nil {
                    if let snapshotView = self.rightButtonNode.view.snapshotContentTree() {
                        snapshotView.frame = self.rightButtonNode.frame
                        self.rightButtonNode.view.superview?.insertSubview(snapshotView, aboveSubview: self.rightButtonNode.view)
                        snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                            snapshotView?.removeFromSuperview()
                        })
                    }
                }
                self.rightButtonNode.removeFromSupernode()
            }
        } else {
            if animated, self.rightButtonNode.view.superview != nil {
                if let snapshotView = self.rightButtonNode.view.snapshotContentTree() {
                    snapshotView.frame = self.rightButtonNode.frame
                    self.rightButtonNode.view.superview?.insertSubview(snapshotView, aboveSubview: self.rightButtonNode.view)
                    snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                        snapshotView?.removeFromSuperview()
                    })
                }
            }
            self.rightButtonNode.removeFromSupernode()
        }
        
        if animated {
            self.hintAnimateTitleNodeOnNextLayout = true
        }
        self.updateAccessibilityElements()
    }

    public let backgroundNode: NavigationBackgroundNode
    public let backButtonNode: NavigationButtonNode
    public let badgeNode: NavigationBarBadgeNode
    public let backButtonArrow: ASImageNode
    public let leftButtonNode: NavigationButtonNode
    public let rightButtonNode: NavigationButtonNode
    public let additionalContentNode: SparseNode

    public func reattachAdditionalContentNode() {
        if self.additionalContentNode.supernode !== self {
            self.insertSubnode(self.additionalContentNode, aboveSubnode: self.clippingNode)
        }
    }
    
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
                            if let transitionTitleNode = value.navigationBar?.makeTransitionTitleNode(foregroundColor: self.presentationData.theme.primaryTextColor) {
                                self.transitionTitleNode = transitionTitleNode
                                if self.leftButtonNode.supernode != nil {
                                    self.buttonsContainerNode.insertSubnode(transitionTitleNode, belowSubnode: self.leftButtonNode)
                                } else if self.backButtonNode.supernode != nil {
                                    self.buttonsContainerNode.insertSubnode(transitionTitleNode, belowSubnode: self.backButtonNode)
                                } else {
                                    self.buttonsContainerNode.addSubnode(transitionTitleNode)
                                }
                            }
                        case .bottom:
                            if let transitionBackButtonNode = value.navigationBar?.makeTransitionBackButtonNode(accentColor: self.presentationData.theme.buttonColor) {
                                self.transitionBackButtonNode = transitionBackButtonNode
                                self.buttonsContainerNode.addSubnode(transitionBackButtonNode)
                            }
                            if let transitionBackArrowNode = value.navigationBar?.makeTransitionBackArrowNode(accentColor: self.presentationData.theme.buttonColor) {
                                self.transitionBackArrowNode = transitionBackArrowNode
                                self.buttonsContainerNode.addSubnode(transitionBackArrowNode)
                            }
                            if let transitionBadgeNode = value.navigationBar?.makeTransitionBadgeNode() {
                                self.transitionBadgeNode = transitionBadgeNode
                                self.buttonsContainerNode.addSubnode(transitionBadgeNode)
                            }
                    }
                }
            }
            
            self.requestedLayout = true
            self.layout()
        }
    }
    
    private var transitionTitleNode: ASDisplayNode?
    private var transitionBackButtonNode: NavigationButtonNode?
    private var transitionBackArrowNode: ASDisplayNode?
    private var transitionBadgeNode: ASDisplayNode?
    
    public init(presentationData: NavigationBarPresentationData) {
        self.presentationData = presentationData
        self.stripeNode = ASDisplayNode()
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.isAccessibilityElement = true
        self.titleNode.accessibilityTraits = .header
        
        self.backButtonNode = NavigationButtonNode()
        self.backButtonNode.hitTestSlop = UIEdgeInsets(top: 0.0, left: -20.0, bottom: 0.0, right: 0.0)
        
        self.badgeNode = NavigationBarBadgeNode(fillColor: self.presentationData.theme.buttonColor, strokeColor: self.presentationData.theme.buttonColor, textColor: self.presentationData.theme.badgeTextColor)
        self.badgeNode.isUserInteractionEnabled = false
        self.badgeNode.isHidden = true
        self.backButtonArrow = ASImageNode()
        self.backButtonArrow.displayWithoutProcessing = true
        self.backButtonArrow.displaysAsynchronously = false
        self.backButtonArrow.isUserInteractionEnabled = false
        self.leftButtonNode = NavigationButtonNode()
        self.rightButtonNode = NavigationButtonNode()
        self.rightButtonNode.hitTestSlop = UIEdgeInsets(top: -4.0, left: -4.0, bottom: -4.0, right: -10.0)
        
        self.clippingNode = SparseNode()
        self.clippingNode.clipsToBounds = true
        
        self.buttonsContainerNode = ASDisplayNode()
        self.buttonsContainerNode.clipsToBounds = true
        
        self.backButtonNode.color = self.presentationData.theme.buttonColor
        self.backButtonNode.disabledColor = self.presentationData.theme.disabledButtonColor
        self.leftButtonNode.color = self.presentationData.theme.buttonColor
        self.leftButtonNode.disabledColor = self.presentationData.theme.disabledButtonColor
        self.rightButtonNode.color = self.presentationData.theme.buttonColor
        self.rightButtonNode.disabledColor = self.presentationData.theme.disabledButtonColor
        self.rightButtonNode.rippleColor = self.presentationData.theme.primaryTextColor.withAlphaComponent(0.05)
        self.backButtonArrow.image = NavigationBar.backArrowImage(color: self.presentationData.theme.buttonColor)
        if let title = self.title {
            self.titleNode.attributedText = NSAttributedString(string: title, font: NavigationBar.titleFont, textColor: self.presentationData.theme.primaryTextColor)
            self.titleNode.accessibilityLabel = title
        }
        self.stripeNode.backgroundColor = self.presentationData.theme.separatorColor

        self.backgroundNode = NavigationBackgroundNode(color: self.presentationData.theme.backgroundColor, enableBlur: self.presentationData.theme.enableBackgroundBlur)
        self.additionalContentNode = SparseNode()
        
        super.init()

        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.buttonsContainerNode)
        self.addSubnode(self.clippingNode)
        self.addSubnode(self.additionalContentNode)

        self.backgroundColor = nil
        self.isOpaque = false
        
        self.stripeNode.isLayerBacked = true
        self.stripeNode.displaysAsynchronously = false
        self.addSubnode(self.stripeNode)
        
        self.titleNode.displaysAsynchronously = false
        self.titleNode.maximumNumberOfLines = 1
        self.titleNode.truncationType = .end
        self.titleNode.isOpaque = false
        
        self.backButtonNode.highlightChanged = { [weak self] index, highlighted in
            if let strongSelf = self, index == 0 {
                strongSelf.backButtonArrow.alpha = (highlighted ? 0.4 : 1.0)
                strongSelf.badgeNode.alpha = (highlighted ? 0.4 : 1.0)
            }
        }
        self.backButtonNode.pressed = { [weak self] index in
            if let strongSelf = self, index == 0 {
                if let leftBarButtonItem = strongSelf.item?.leftBarButtonItem, leftBarButtonItem.backButtonAppearance {
                    leftBarButtonItem.performActionOnTarget()
                } else {
                    strongSelf.backPressed()
                }
            }
        }
        
        self.leftButtonNode.pressed = { [weak self] index in
            if let item = self?.item {
                if index == 0 {
                    if let leftBarButtonItem = item.leftBarButtonItem {
                        leftBarButtonItem.performActionOnTarget()
                    } else if let previousItem = self?.previousItem, case .close = previousItem {
                        self?.backPressed()
                    }
                }
            }
        }
        
        self.rightButtonNode.pressed = { [weak self] index in
            if let item = self?.item {
                if let rightBarButtonItems = item.rightBarButtonItems, !rightBarButtonItems.isEmpty {
                    if index < rightBarButtonItems.count {
                        rightBarButtonItems[index].performActionOnTarget()
                    }
                } else if let rightBarButtonItem = item.rightBarButtonItem {
                    rightBarButtonItem.performActionOnTarget()
                }
            }
        }
    }
    
    public var isBackgroundVisible: Bool {
        return self.backgroundNode.alpha == 1.0
    }
    
    public func updateBackgroundAlpha(_ alpha: CGFloat, transition: ContainedViewLayoutTransition) {
        let alpha = max(0.0, min(1.0, alpha))
        transition.updateAlpha(node: self.backgroundNode, alpha: alpha, delay: 0.15)
        transition.updateAlpha(node: self.stripeNode, alpha: alpha, delay: 0.15)
    }
    
    public func updatePresentationData(_ presentationData: NavigationBarPresentationData) {
        if presentationData.theme !== self.presentationData.theme || presentationData.strings !== self.presentationData.strings {
            self.presentationData = presentationData
            
            self.backgroundNode.updateColor(color: self.presentationData.theme.backgroundColor, transition: .immediate)
            
            self.backButtonNode.color = self.presentationData.theme.buttonColor
            self.backButtonNode.disabledColor = self.presentationData.theme.disabledButtonColor
            self.leftButtonNode.color = self.presentationData.theme.buttonColor
            self.leftButtonNode.disabledColor = self.presentationData.theme.disabledButtonColor
            self.rightButtonNode.color = self.presentationData.theme.buttonColor
            self.rightButtonNode.disabledColor = self.presentationData.theme.disabledButtonColor
            self.rightButtonNode.rippleColor = self.presentationData.theme.primaryTextColor.withAlphaComponent(0.05)
            self.backButtonArrow.image = NavigationBar.backArrowImage(color: self.presentationData.theme.buttonColor)
            if let title = self.title {
                self.titleNode.attributedText = NSAttributedString(string: title, font: NavigationBar.titleFont, textColor: self.presentationData.theme.primaryTextColor)
                self.titleNode.accessibilityLabel = title
            }
            self.stripeNode.backgroundColor = self.presentationData.theme.separatorColor
            
            self.badgeNode.updateTheme(fillColor: self.presentationData.theme.buttonColor, strokeColor: self.presentationData.theme.buttonColor, textColor: self.presentationData.theme.badgeTextColor)
            
            self.requestLayout()
        }
    }
    
    private func requestLayout() {
        self.requestedLayout = true
        self.setNeedsLayout()
    }
    
    override open func layout() {
        super.layout()
        
        if let validLayout = self.validLayout, self.requestedLayout {
            self.requestedLayout = false
            self.updateLayout(size: validLayout.size, defaultHeight: validLayout.defaultHeight, additionalTopHeight: validLayout.additionalTopHeight, additionalContentHeight: validLayout.additionalContentHeight, additionalBackgroundHeight: validLayout.additionalBackgroundHeight, leftInset: validLayout.leftInset, rightInset: validLayout.rightInset, appearsHidden: validLayout.appearsHidden, isLandscape: validLayout.isLandscape, transition: .immediate)
        }
    }
    
    func updateLayout(size: CGSize, defaultHeight: CGFloat, additionalTopHeight: CGFloat, additionalContentHeight: CGFloat, additionalBackgroundHeight: CGFloat, leftInset: CGFloat, rightInset: CGFloat, appearsHidden: Bool, isLandscape: Bool, transition: ContainedViewLayoutTransition) {
        if self.layoutSuspended {
            return
        }
        
        self.validLayout = (size, defaultHeight, additionalTopHeight, additionalContentHeight, additionalBackgroundHeight, leftInset, rightInset, appearsHidden, isLandscape)

        let backgroundFrame = CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: size.height + additionalBackgroundHeight))
        if self.backgroundNode.frame != backgroundFrame {
            transition.updateFrame(node: self.backgroundNode, frame: backgroundFrame)
            self.backgroundNode.update(size: backgroundFrame.size, transition: transition)
        }
        
        let apparentAdditionalHeight: CGFloat = self.secondaryContentNode != nil ? NavigationBar.defaultSecondaryContentHeight : 0.0
        
        let leftButtonInset: CGFloat = leftInset + 16.0
        let backButtonInset: CGFloat = leftInset + 27.0
        
        transition.updateFrame(node: self.clippingNode, frame: CGRect(origin: CGPoint(), size: size))
        transition.updateFrame(node: self.additionalContentNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: size.height + additionalBackgroundHeight)))
        transition.updateFrame(node: self.buttonsContainerNode, frame: CGRect(origin: CGPoint(), size: size))
        var expansionHeight: CGFloat = 0.0
        if let contentNode = self.contentNode {
            var contentNodeFrame: CGRect
            switch contentNode.mode {
            case .replacement:
                expansionHeight = contentNode.height - defaultHeight
                contentNodeFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: size.height - additionalContentHeight))
            case .expansion:
                expansionHeight = contentNode.height
                
                let additionalExpansionHeight: CGFloat = self.secondaryContentNode != nil && appearsHidden ? NavigationBar.defaultSecondaryContentHeight : 0.0
                contentNodeFrame = CGRect(origin: CGPoint(x: 0.0, y: size.height - (appearsHidden ? 0.0 : additionalContentHeight) - expansionHeight - apparentAdditionalHeight - additionalExpansionHeight), size: CGSize(width: size.width, height: expansionHeight))
                if appearsHidden {
                    if self.secondaryContentNode != nil {
                        contentNodeFrame.origin.y += NavigationBar.defaultSecondaryContentHeight
                    }
                }
            }
            transition.updateFrame(node: contentNode, frame: contentNodeFrame)
            contentNode.updateLayout(size: contentNodeFrame.size, leftInset: leftInset, rightInset: rightInset, transition: transition)
        }
        
        transition.updateFrame(node: self.stripeNode, frame: CGRect(x: 0.0, y: size.height + additionalBackgroundHeight, width: size.width, height: UIScreenPixel))
        
        let nominalHeight: CGFloat = defaultHeight
        let contentVerticalOrigin = additionalTopHeight
        
        var leftTitleInset: CGFloat = leftInset + 1.0
        var rightTitleInset: CGFloat = rightInset + 1.0
        if self.backButtonNode.supernode != nil {
            let backButtonSize = self.backButtonNode.updateLayout(constrainedSize: CGSize(width: size.width, height: nominalHeight), isLandscape: isLandscape)
            leftTitleInset = backButtonSize.width + backButtonInset + 1.0
            
            let topHitTestSlop = (nominalHeight - backButtonSize.height) * 0.5
            self.backButtonNode.hitTestSlop = UIEdgeInsets(top: -topHitTestSlop, left: -27.0, bottom: -topHitTestSlop, right: -8.0)
            
            if let transitionState = self.transitionState {
                let progress = transitionState.progress
                
                switch transitionState.role {
                    case .top:
                        let initialX: CGFloat = backButtonInset
                        let finalX: CGFloat = floor((size.width - backButtonSize.width) / 2.0) - size.width
                        
                        let backButtonFrame = CGRect(origin: CGPoint(x: initialX * (1.0 - progress) + finalX * progress, y: contentVerticalOrigin + floor((nominalHeight - backButtonSize.height) / 2.0)), size: backButtonSize)
                        if self.backButtonNode.frame != backButtonFrame {
                            self.backButtonNode.frame = backButtonFrame
                        }
                        let backButtonAlpha = self.backButtonNode.alpha
                        if self.backButtonNode.alpha != backButtonAlpha {
                            self.backButtonNode.alpha = backButtonAlpha
                        }
                    
                        if let transitionTitleNode = self.transitionTitleNode {
                            let transitionTitleSize = transitionTitleNode.measure(CGSize(width: size.width, height: nominalHeight))
                            
                            let initialX: CGFloat = backButtonInset + floor((backButtonSize.width - transitionTitleSize.width) / 2.0)
                            let finalX: CGFloat = floor((size.width - transitionTitleSize.width) / 2.0) - size.width
                            
                            transitionTitleNode.frame = CGRect(origin: CGPoint(x: initialX * (1.0 - progress) + finalX * progress, y: contentVerticalOrigin + floor((nominalHeight - transitionTitleSize.height) / 2.0)), size: transitionTitleSize)
                            transitionTitleNode.alpha = progress * progress
                        }
                    
                        self.backButtonArrow.frame = CGRect(origin: CGPoint(x: leftInset + 8.0 - progress * size.width, y: contentVerticalOrigin + floor((nominalHeight - 22.0) / 2.0)), size: CGSize(width: 13.0, height: 22.0))
                        self.backButtonArrow.alpha = max(0.0, 1.0 - progress * 1.3)
                        self.badgeNode.alpha = max(0.0, 1.0 - progress * 1.3)
                    case .bottom:
                        self.backButtonNode.alpha = 1.0
                        self.backButtonNode.frame = CGRect(origin: CGPoint(x: backButtonInset, y: contentVerticalOrigin + floor((nominalHeight - backButtonSize.height) / 2.0)), size: backButtonSize)
                        self.backButtonArrow.alpha = 1.0
                        self.backButtonArrow.frame = CGRect(origin: CGPoint(x: leftInset + 8.0, y: contentVerticalOrigin + floor((nominalHeight - 22.0) / 2.0)), size: CGSize(width: 13.0, height: 22.0))
                        self.badgeNode.alpha = 1.0
                }
            } else {
                self.backButtonNode.alpha = 1.0
                transition.updateFrame(node: self.backButtonNode, frame: CGRect(origin: CGPoint(x: backButtonInset, y: contentVerticalOrigin + floor((nominalHeight - backButtonSize.height) / 2.0)), size: backButtonSize))
                
                self.backButtonArrow.alpha = 1.0
                transition.updateFrame(node: self.backButtonArrow, frame: CGRect(origin: CGPoint(x: leftInset + 8.0, y: contentVerticalOrigin + floor((nominalHeight - 22.0) / 2.0)), size: CGSize(width: 13.0, height: 22.0)))
                self.badgeNode.alpha = 1.0
            }
        } else if self.leftButtonNode.supernode != nil {
            let leftButtonSize = self.leftButtonNode.updateLayout(constrainedSize: CGSize(width: size.width, height: nominalHeight), isLandscape: isLandscape)
            leftTitleInset = leftButtonSize.width + leftButtonInset + 1.0
            
            var transition = transition
            if self.leftButtonNode.frame.width.isZero {
                transition = .immediate
            }
            
            self.leftButtonNode.alpha = 1.0
            transition.updateFrame(node: self.leftButtonNode, frame: CGRect(origin: CGPoint(x: leftButtonInset, y: contentVerticalOrigin + floor((nominalHeight - leftButtonSize.height) / 2.0)), size: leftButtonSize))
        }
        
        let badgeSize = self.badgeNode.measure(CGSize(width: 200.0, height: 100.0))
        let backButtonArrowFrame = self.backButtonArrow.frame
        transition.updateFrame(node: self.badgeNode, frame: CGRect(origin: backButtonArrowFrame.origin.offsetBy(dx: 16.0, dy: 2.0), size: badgeSize))
        
        if self.rightButtonNode.supernode != nil {
            let rightButtonSize = self.rightButtonNode.updateLayout(constrainedSize: (CGSize(width: size.width, height: nominalHeight)), isLandscape: isLandscape)
            rightTitleInset = rightButtonSize.width + leftButtonInset + 1.0
            self.rightButtonNode.alpha = 1.0
            
            var transition = transition
            if self.rightButtonNode.frame.width.isZero {
                transition = .immediate
            }
            transition.updateFrame(node: self.rightButtonNode, frame: CGRect(origin: CGPoint(x: size.width - leftButtonInset - rightButtonSize.width, y: contentVerticalOrigin + floor((nominalHeight - rightButtonSize.height) / 2.0)), size: rightButtonSize))
        }
        
        if let transitionState = self.transitionState {
            let progress = transitionState.progress
            
            switch transitionState.role {
                case .top:
                    break
                case .bottom:
                    if let transitionBackButtonNode = self.transitionBackButtonNode {
                        let transitionBackButtonSize = transitionBackButtonNode.updateLayout(constrainedSize: CGSize(width: size.width, height: nominalHeight), isLandscape: isLandscape)
                        let initialX: CGFloat = backButtonInset + size.width * 0.3
                        let finalX: CGFloat = floor((size.width - transitionBackButtonSize.width) / 2.0)
                        
                        transitionBackButtonNode.frame = CGRect(origin: CGPoint(x: initialX * (1.0 - progress) + finalX * progress, y: contentVerticalOrigin + floor((nominalHeight - transitionBackButtonSize.height) / 2.0)), size: transitionBackButtonSize)
                        transitionBackButtonNode.alpha = (1.0 - progress) * (1.0 - progress)
                    }
                
                    if let transitionBackArrowNode = self.transitionBackArrowNode {
                        let initialX: CGFloat = leftInset + 8.0 + size.width * 0.3
                        let finalX: CGFloat = leftInset + 8.0
                        
                        transitionBackArrowNode.frame = CGRect(origin: CGPoint(x: initialX * (1.0 - progress) + finalX * progress, y: contentVerticalOrigin + floor((nominalHeight - 22.0) / 2.0)), size: CGSize(width: 13.0, height: 22.0))
                        transitionBackArrowNode.alpha = max(0.0, 1.0 - progress * 1.3)
                        
                        if let transitionBadgeNode = self.transitionBadgeNode {
                            transitionBadgeNode.frame = CGRect(origin: transitionBackArrowNode.frame.origin.offsetBy(dx: 16.0, dy: 2.0), size: transitionBadgeNode.bounds.size)
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
            let titleSize = self.titleNode.updateLayout(CGSize(width: max(1.0, size.width - max(leftTitleInset, rightTitleInset) * 2.0), height: nominalHeight))
            
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
                var transition = transition
                if self.titleNode.frame.width.isZero {
                    transition = .immediate
                }
                self.titleNode.alpha = 1.0
                transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: floor((size.width - titleSize.width) / 2.0), y: contentVerticalOrigin + floorToScreenPixels((nominalHeight - titleSize.height) / 2.0)), size: titleSize))
            }
        }
        
        if let titleView = self.titleView {
            let titleSize = CGSize(width: max(1.0, size.width - max(leftTitleInset, rightTitleInset) * 2.0), height: nominalHeight)
            let titleFrame = CGRect(origin: CGPoint(x: floor((size.width - titleSize.width) / 2.0), y: contentVerticalOrigin + floorToScreenPixels((nominalHeight - titleSize.height) / 2.0)), size: titleSize)
            var titleViewTransition = transition
            if titleView.frame.isEmpty {
                titleViewTransition = .immediate
                titleView.frame = titleFrame
            }

            titleViewTransition.updateFrame(view: titleView, frame: titleFrame)
            
            if let titleView = titleView as? NavigationBarTitleView {
                let titleWidth = size.width - (leftTitleInset > 0.0 ? leftTitleInset : rightTitleInset) - (rightTitleInset > 0.0 ? rightTitleInset : leftTitleInset)
                
                titleView.updateLayout(size: titleFrame.size, clearBounds: CGRect(origin: CGPoint(x: leftTitleInset - titleFrame.minX, y: 0.0), size: CGSize(width: titleWidth, height: titleFrame.height)), transition: titleViewTransition)
            }
            
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
                if self.hintAnimateTitleNodeOnNextLayout {
                    self.hintAnimateTitleNodeOnNextLayout = false
                    if let titleView = titleView as? NavigationBarTitleView {
                        titleView.animateLayoutTransition()
                    }
                }
                titleView.alpha = 1.0
                transition.updateFrame(view: titleView, frame: titleFrame)
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
            let node = ImmediateTextNode()
            node.attributedText = NSAttributedString(string: title, font: NavigationBar.titleFont, textColor: foregroundColor)
            return node
        } else {
            return nil
        }
    }
    
    public func makeTransitionBackButtonNode(accentColor: UIColor) -> NavigationButtonNode? {
        if self.backButtonNode.supernode != nil {
            let node = NavigationButtonNode()
            node.manualAlpha = self.backButtonNode.manualAlpha
            node.updateManualText(self.backButtonNode.manualText)
            node.color = accentColor
            if let validLayout = self.validLayout {
                let _ = node.updateLayout(constrainedSize: CGSize(width: validLayout.size.width, height: validLayout.defaultHeight), isLandscape: validLayout.isLandscape)
                node.frame = self.backButtonNode.frame
            }
            return node
        } else {
            return nil
        }
    }
    
    public func makeTransitionRightButtonNode(accentColor: UIColor) -> NavigationButtonNode? {
        if self.rightButtonNode.supernode != nil {
            let node = NavigationButtonNode()
            var items: [UIBarButtonItem] = []
            if let item = self.item {
                if let rightBarButtonItems = item.rightBarButtonItems, !rightBarButtonItems.isEmpty {
                    items = rightBarButtonItems
                } else if let rightBarButtonItem = item.rightBarButtonItem {
                    items = [rightBarButtonItem]
                }
            }
            node.updateItems(items)
            node.color = accentColor
            if let validLayout = self.validLayout {
                let _ = node.updateLayout(constrainedSize: CGSize(width: validLayout.size.width, height: validLayout.defaultHeight), isLandscape: validLayout.isLandscape)
                node.frame = self.backButtonNode.frame
            }
            return node
        } else {
            return nil
        }
    }
    
    public func makeTransitionBackArrowNode(accentColor: UIColor) -> ASDisplayNode? {
        if self.backButtonArrow.supernode != nil {
            let node = ASImageNode()
            node.image = NavigationBar.backArrowImage(color: accentColor)
            node.frame = self.backButtonArrow.frame
            node.displayWithoutProcessing = true
            node.displaysAsynchronously = false
            return node
        } else {
            return nil
        }
    }
    
    public func makeTransitionBadgeNode() -> ASDisplayNode? {
        if self.badgeNode.supernode != nil && !self.badgeNode.isHidden {
            let node = NavigationBarBadgeNode(fillColor: self.presentationData.theme.buttonColor, strokeColor: self.presentationData.theme.buttonColor, textColor: self.presentationData.theme.badgeTextColor)
            node.text = self.badgeNode.text
            let nodeSize = node.measure(CGSize(width: 200.0, height: 100.0))
            node.frame = CGRect(origin: CGPoint(), size: nodeSize)
            return node
        } else {
            return nil
        }
    }
    
    public var intrinsicCanTransitionInline: Bool = true
    
    public var passthroughTouches = true
    
    public var canTransitionInline: Bool {
        if let contentNode = self.contentNode, case .replacement = contentNode.mode {
            return false
        } else {
            return self.intrinsicCanTransitionInline
        }
    }
    
    public func contentHeight(defaultHeight: CGFloat) -> CGFloat {
        var result: CGFloat = 0.0
        if let contentNode = self.contentNode {
            switch contentNode.mode {
            case .expansion:
                result += defaultHeight + contentNode.height
            case .replacement:
                result += contentNode.height
            }
        } else {
            result += defaultHeight
        }
        
        if let _ = self.secondaryContentNode {
            result += NavigationBar.defaultSecondaryContentHeight
        }
        
        return result
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
            self.contentNode?.requestContainerLayout = { [weak self] transition in
                self?.requestContainerLayout(transition)
            }
            if let contentNode = contentNode {
                contentNode.clipsToBounds = true
                contentNode.layer.removeAnimation(forKey: "opacity")
                self.insertSubnode(contentNode, belowSubnode: self.stripeNode)
                if animated {
                    contentNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                }
                
                if case .replacement = contentNode.mode, !self.buttonsContainerNode.alpha.isZero {
                    self.buttonsContainerNode.alpha = 0.0
                    if animated {
                        self.buttonsContainerNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
                    }
                }
                
                if !self.bounds.size.width.isZero {
                    self.requestedLayout = true
                    self.layout()
                } else {
                    self.requestLayout()
                }
            } else if self.buttonsContainerNode.alpha.isZero {
                self.buttonsContainerNode.alpha = 1.0
                if animated {
                    self.buttonsContainerNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                }
            }
        }
    }
    
    public func setSecondaryContentNode(_ secondaryContentNode: ASDisplayNode?, animated: Bool = false) {
        if self.secondaryContentNode !== secondaryContentNode {
            if let previous = self.secondaryContentNode, previous.supernode === self.clippingNode {
                if animated {
                    previous.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak previous] finished in
                        if finished {
                            previous?.removeFromSupernode()
                            previous?.layer.removeAllAnimations()
                        }
                    })
                } else {
                    previous.removeFromSupernode()
                }
            }
            self.secondaryContentNode = secondaryContentNode
            if let secondaryContentNode = secondaryContentNode {
                self.clippingNode.addSubnode(secondaryContentNode)
                
                if animated {
                    secondaryContentNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
                }
            }
        }
    }
    
    public func executeBack() -> Bool {
        if self.backButtonNode.isInHierarchy {
            self.backButtonNode.pressed(0)
        } else if self.leftButtonNode.isInHierarchy {
            self.leftButtonNode.pressed(0)
        } else {
            self.backButtonNode.pressed(0)
        }
        return true
    }
    
    public func setHidden(_ hidden: Bool, animated: Bool) {
        if let contentNode = self.contentNode, case .replacement = contentNode.mode {
        } else {
            let targetAlpha: CGFloat = hidden ? 0.0 : 1.0
            let previousAlpha = self.buttonsContainerNode.alpha
            if previousAlpha != targetAlpha {
                self.buttonsContainerNode.alpha = targetAlpha
                if animated {
                    self.buttonsContainerNode.layer.animateAlpha(from: previousAlpha, to: targetAlpha, duration: 0.2)
                }
            }
        }
    }
    
    override open func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let result = self.additionalContentNode.view.hitTest(self.view.convert(point, to: self.additionalContentNode.view), with: event) {
            return result
        }

        guard let result = super.hitTest(point, with: event) else {
            return nil
        }
        
        
        if self.passthroughTouches && (result == self.view || result == self.buttonsContainerNode.view) {
            return nil
        }
        
        return result
    }
}
