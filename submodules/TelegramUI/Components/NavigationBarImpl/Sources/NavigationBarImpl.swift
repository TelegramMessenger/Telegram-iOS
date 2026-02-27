import Foundation
import UIKit
import Display
import ComponentFlow
import GlassBackgroundComponent
import AsyncDisplayKit
import EdgeEffect
import ComponentDisplayAdapters

public final class NavigationBarImpl: ASDisplayNode, NavigationBar {
    public static var defaultSecondaryContentHeight: CGFloat {
        return 38.0
    }
    
    public static let thinBackArrowImage = generateTintedImage(image: UIImage(bundleImageName: "Navigation/BackArrow"), color: .white)?.withRenderingMode(.alwaysTemplate)

    public static let titleFont = Font.with(size: 17.0, design: .regular, weight: .semibold, traits: [.monospacedNumbers])
    
    var presentationData: NavigationBarPresentationData
    
    private var validLayout: (size: CGSize, defaultHeight: CGFloat, additionalTopHeight: CGFloat, additionalContentHeight: CGFloat, additionalBackgroundHeight: CGFloat, additionalCutout: CGSize?, leftInset: CGFloat, rightInset: CGFloat, appearsHidden: Bool, isLandscape: Bool)?
    private var requestedLayout: Bool = false
    public var requestContainerLayout: ((ContainedViewLayoutTransition) -> Void)?
    
    public var backPressed: () -> () = { }
    
    public var userInfo: Any?
    public var makeCustomTransitionNode: ((NavigationBar, Bool) -> CustomNavigationTransitionNode?)?
    public var allowsCustomTransition: (() -> Bool)?
    
    public let stripeNode: ASDisplayNode
    public let clippingNode: SparseNode
    private let buttonsContainerNode: ASDisplayNode
    
    public private(set) var contentNode: NavigationBarContentNode?
    public private(set) var secondaryContentNode: ASDisplayNode?
    public var secondaryContentNodeDisplayFraction: CGFloat = 1.0
    
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
            
            self.leftButtonNodeImpl.view.removeFromSuperview()
            self.rightButtonNodeImpl.view.removeFromSuperview()
            
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
                
                let itemTitleView = item.titleView
                if self.titleView !== itemTitleView {
                    if let oldTitleView = self.titleView as? NavigationBarTitleView {
                        oldTitleView.requestUpdate = nil
                    }
                    self.titleView = itemTitleView
                    if let titleView = self.titleView as? NavigationBarTitleView {
                        titleView.requestUpdate = { [weak self, weak titleView] transition in
                            guard let self, let titleView, self.titleView === titleView else {
                                return
                            }
                            if let requestContainerLayout = self.requestContainerLayout {
                                requestContainerLayout(transition)
                            } else {
                                self.requestLayout()
                            }
                        }
                    }
                }
                self.itemTitleViewListenerKey = item.addSetTitleViewListener { [weak self] itemTitleView in
                    guard let self else {
                        return
                    }
                    
                    if let oldTitleView = self.titleView as? NavigationBarTitleView {
                        oldTitleView.requestUpdate = nil
                    }
                    self.titleView = itemTitleView
                    if let titleView = self.titleView as? NavigationBarTitleView {
                        titleView.requestUpdate = { [weak self, weak titleView] transition in
                            guard let self, let titleView, self.titleView === titleView else {
                                return
                            }
                            if let requestContainerLayout = self.requestContainerLayout {
                                requestContainerLayout(transition)
                            } else {
                                self.requestLayout()
                            }
                        }
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
                self.titleNode.attributedText = NSAttributedString(string: title, font: NavigationBarImpl.titleFont, textColor: self.presentationData.theme.primaryTextColor)
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
                if let backgroundContainer = self.backgroundContainer {
                    backgroundContainer.contentView.addSubview(titleView)
                } else {
                    self.buttonsContainerNode.view.insertSubview(titleView, at: 0)
                }
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
    
    override public var accessibilityElements: [Any]? {
        get {
            var accessibilityElements: [Any] = []
            if self.backButtonNodeImpl.view.superview != nil {
                addAccessibilityChildren(of: self.backButtonNodeImpl, container: self, to: &accessibilityElements)
            }
            if self.leftButtonNodeImpl.view.superview != nil {
                addAccessibilityChildren(of: self.leftButtonNodeImpl, container: self, to: &accessibilityElements)
            }
            if self.titleNode.view.superview != nil {
                addAccessibilityChildren(of: self.titleNode, container: self, to: &accessibilityElements)
                accessibilityElements.append(self.titleNode)
            }
            if let titleView = self.titleView, titleView.superview != nil {
                titleView.accessibilityFrame = UIAccessibility.convertToScreenCoordinates(titleView.bounds, in: titleView)
                accessibilityElements.append(titleView)
            }
            if self.rightButtonNodeImpl.supernode != nil {
                addAccessibilityChildren(of: self.rightButtonNodeImpl, container: self, to: &accessibilityElements)
            }
            if let contentNode = self.contentNode {
                addAccessibilityChildren(of: contentNode, container: self, to: &accessibilityElements)
            }
            if let secondaryContentNode = self.secondaryContentNode {
                addAccessibilityChildren(of: secondaryContentNode, container: self, to: &accessibilityElements)
            }
            return accessibilityElements
        } set(value) {
        }
    }
    
    override public func didLoad() {
        super.didLoad()
        
        self.updateAccessibilityElements()
    }
    
    public var enableAutomaticBackButton: Bool = true
    
    var _previousItem: NavigationPreviousAction?
    public var previousItem: NavigationPreviousAction? {
        get {
            if !self.enableAutomaticBackButton {
                return nil
            }
            return self._previousItem
        } set(value) {
            if !self.enableAutomaticBackButton {
                self._previousItem = nil
                return
            }
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
                                    if case .glass = strongSelf.presentationData.theme.style {
                                        strongSelf.backButtonNodeImpl.updateManualText("", isBack: true)
                                    } else if let customBackButtonText = strongSelf.customBackButtonText {
                                        strongSelf.backButtonNodeImpl.updateManualText(customBackButtonText, isBack: true)
                                    } else if let backBarButtonItem = itemValue.backBarButtonItem {
                                        strongSelf.backButtonNodeImpl.updateManualText(backBarButtonItem.title ?? "", isBack: true)
                                    } else {
                                        strongSelf.backButtonNodeImpl.updateManualText(itemValue.title ?? "", isBack: true)
                                    }
                                    strongSelf.invalidateCalculatedLayout()
                                    strongSelf.requestLayout()
                                }
                            }
                            
                            self.previousItemBackListenerKey = itemValue.addSetBackBarButtonItemListener { [weak self] _, _, _ in
                                if let strongSelf = self, let previousItem = strongSelf.previousItem, case let .item(itemValue) = previousItem {
                                    if case .glass = strongSelf.presentationData.theme.style {
                                        strongSelf.backButtonNodeImpl.updateManualText("", isBack: true)
                                    } else if let customBackButtonText = strongSelf.customBackButtonText {
                                        strongSelf.backButtonNodeImpl.updateManualText(customBackButtonText, isBack: true)
                                    } else if let backBarButtonItem = itemValue.backBarButtonItem {
                                        strongSelf.backButtonNodeImpl.updateManualText(backBarButtonItem.title ?? "", isBack: true)
                                    } else {
                                        strongSelf.backButtonNodeImpl.updateManualText(itemValue.title ?? "", isBack: true)
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
            self.backButtonNodeImpl.manualAlpha = self.badgeNode.isHidden ? 1.0 : 0.0
            
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
                    if self.backButtonNodeImpl.view.superview != nil {
                        if let snapshotView = self.backButtonNodeImpl.view.snapshotContentTree() {
                            snapshotView.frame = self.backButtonNodeImpl.frame
                            self.backButtonNodeImpl.view.superview?.insertSubview(snapshotView, aboveSubview: self.backButtonNodeImpl.view)
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
                
                self.backButtonNodeImpl.view.removeFromSuperview()
                self.backButtonArrow.view.removeFromSuperview()
                self.badgeNode.view.removeFromSuperview()
                
                if let leftBarButtonItem = item.leftBarButtonItem {
                    self.leftButtonNodeImpl.updateItems([], animated: animated)
                    self.leftButtonNodeImpl.updateItems([leftBarButtonItem], animated: animated)
                } else {
                    self.leftButtonNodeImpl.updateItems([], animated: animated)
                    self.leftButtonNodeImpl.updateItems([UIBarButtonItem(title: "___close", style: .plain, target: nil, action: nil)], animated: animated)
                }
                
                if self.leftButtonNodeImpl.supernode == nil {
                    if let leftButtonsBackgroundView = self.leftButtonsBackgroundView {
                        leftButtonsBackgroundView.container.addSubview(self.leftButtonNodeImpl.view)
                    } else {
                        self.buttonsContainerNode.view.addSubview(self.leftButtonNodeImpl.view)
                    }
                }
                
                if animated {
                    self.leftButtonNodeImpl.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                }
            } else {
                if animated, self.leftButtonNodeImpl.view.superview != nil {
                    if let snapshotView = self.leftButtonNodeImpl.view.snapshotContentTree() {
                        snapshotView.frame = self.leftButtonNodeImpl.frame
                        self.leftButtonNodeImpl.view.superview?.insertSubview(snapshotView, aboveSubview: self.leftButtonNodeImpl.view)
                        snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                            snapshotView?.removeFromSuperview()
                        })
                    }
                }
                self.leftButtonNodeImpl.view.removeFromSuperview()
                
                var backTitle: String?
                if case .glass = self.presentationData.theme.style {
                    backTitle = ""
                } else if let customBackButtonText = self.customBackButtonText {
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
                
                if let backTitle {
                    self.backButtonNodeImpl.updateManualText(backTitle, isBack: true)
                    if self.backButtonNodeImpl.supernode == nil {
                        if let leftButtonsBackgroundView = self.leftButtonsBackgroundView {
                            leftButtonsBackgroundView.container.addSubview(self.backButtonNodeImpl.view)
                            leftButtonsBackgroundView.container.addSubview(self.backButtonArrow.view)
                            leftButtonsBackgroundView.container.addSubview(self.badgeNode.view)
                        } else {
                            self.buttonsContainerNode.view.addSubview(self.backButtonNodeImpl.view)
                            self.buttonsContainerNode.view.addSubview(self.backButtonArrow.view)
                            self.buttonsContainerNode.view.addSubview(self.badgeNode.view)
                        }
                    }
                    
                    if animated {
                        self.backButtonNodeImpl.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                        self.backButtonArrow.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                        self.badgeNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                    }
                } else {
                    self.backButtonNodeImpl.view.removeFromSuperview()
                }
            }
        } else {
            self.leftButtonNodeImpl.view.removeFromSuperview()
            self.backButtonNodeImpl.view.removeFromSuperview()
            self.backButtonArrow.view.removeFromSuperview()
            self.badgeNode.view.removeFromSuperview()
        }
        
        self.updateAccessibilityElements()
    }
    
    private func updateRightButton(animated: Bool) {
        if let item = self.item {
            var items: [UIBarButtonItem] = []
            if let rightBarButtonItems = item.rightBarButtonItems, !rightBarButtonItems.isEmpty {
                items = rightBarButtonItems
            } else if let rightBarButtonItem = item.rightBarButtonItem {
                items = [rightBarButtonItem]
            }
            
            self.rightButtonNodeUpdated = true
            
            if !items.isEmpty {
                if self.rightButtonNodeImpl.isEmpty {
                    self.rightButtonNodeImpl.updateItems(items, animated: false)
                } else {
                    self.rightButtonNodeImpl.updateItems([], animated: animated)
                    self.rightButtonNodeImpl.updateItems(items, animated: animated)
                }
                if self.rightButtonNodeImpl.view.superview == nil {
                    if let rightButtonsBackgroundView = self.rightButtonsBackgroundView {
                        rightButtonsBackgroundView.container.addSubview(self.rightButtonNodeImpl.view)
                    } else {
                        self.buttonsContainerNode.view.addSubview(self.rightButtonNodeImpl.view)
                    }
                }
            } else {
                if animated, self.rightButtonNodeImpl.view.superview != nil {
                    if let snapshotView = self.rightButtonNodeImpl.view.snapshotContentTree() {
                        snapshotView.frame = self.rightButtonNodeImpl.frame
                        self.rightButtonNodeImpl.view.superview?.insertSubview(snapshotView, aboveSubview: self.rightButtonNodeImpl.view)
                        snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                            snapshotView?.removeFromSuperview()
                        })
                    }
                }
                self.rightButtonNodeImpl.view.removeFromSuperview()
                self.rightButtonNodeImpl.updateItems([], animated: false)
            }
        } else {
            if animated, self.rightButtonNodeImpl.view.superview != nil {
                if let snapshotView = self.rightButtonNodeImpl.view.snapshotContentTree() {
                    snapshotView.frame = self.rightButtonNodeImpl.frame
                    self.rightButtonNodeImpl.view.superview?.insertSubview(snapshotView, aboveSubview: self.rightButtonNodeImpl.view)
                    snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                        snapshotView?.removeFromSuperview()
                    })
                }
            }
            self.rightButtonNodeImpl.view.removeFromSuperview()
            self.rightButtonNodeImpl.updateItems([], animated: false)
        }
        
        self.updateAccessibilityElements()
    }

    public let backgroundNode: NavigationBackgroundNode
    
    private var leftButtonsBackgroundView: (background: GlassContextExtractableContainer, container: UIView)?
    private var rightButtonsBackgroundView: (background: GlassContextExtractableContainer, container: UIView)?
    
    private let backButtonNodeImpl: NavigationButtonNodeImpl
    public var backButtonNode: NavigationButtonNode {
        return self.backButtonNodeImpl
    }
    public let badgeNode: NavigationBarBadgeNode
    public let backButtonArrow: ASImageNode
    private let leftButtonNodeImpl: NavigationButtonNodeImpl
    public var leftButtonNode: NavigationButtonNode {
        return self.leftButtonNodeImpl
    }
    private let rightButtonNodeImpl: NavigationButtonNodeImpl
    public var rightButtonNode: NavigationButtonNode {
        return self.rightButtonNodeImpl
    }
    private var rightButtonNodeUpdated: Bool = false
    public let additionalContentNode: SparseNode

    public func reattachAdditionalContentNode() {
        if self.additionalContentNode.supernode !== self {
            self.insertSubnode(self.additionalContentNode, aboveSubnode: self.clippingNode)
        }
    }
    
    public var secondaryContentHeight: CGFloat
    
    private var edgeEffectExtension: CGFloat = 0.0
    private var edgeEffectView: EdgeEffectView?
    private var backgroundContainer: GlassBackgroundContainerView?
    
    public var backgroundView: UIView {
        if let edgeEffectView = self.edgeEffectView {
            return edgeEffectView
        } else {
            return self.backgroundNode.view
        }
    }
    
    public let customOverBackgroundContentView: UIView
    
    public init(presentationData: NavigationBarPresentationData) {
        self.presentationData = presentationData
        self.stripeNode = ASDisplayNode()
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.isAccessibilityElement = true
        self.titleNode.accessibilityTraits = .header
        
        self.backButtonNodeImpl = NavigationButtonNodeImpl(isGlass: presentationData.theme.style == .glass)
        if case .glass = presentationData.theme.style {
        } else {
            self.backButtonNodeImpl.hitTestSlop = UIEdgeInsets(top: 0.0, left: -20.0, bottom: 0.0, right: 0.0)
        }
        
        self.badgeNode = NavigationBarBadgeNode(fillColor: self.presentationData.theme.buttonColor, strokeColor: self.presentationData.theme.buttonColor, textColor: self.presentationData.theme.badgeTextColor)
        self.badgeNode.isUserInteractionEnabled = false
        self.badgeNode.isHidden = true
        self.backButtonArrow = ASImageNode()
        self.backButtonArrow.displayWithoutProcessing = true
        self.backButtonArrow.displaysAsynchronously = false
        self.backButtonArrow.isUserInteractionEnabled = false
        self.leftButtonNodeImpl = NavigationButtonNodeImpl(isGlass: presentationData.theme.style == .glass)
        self.rightButtonNodeImpl = NavigationButtonNodeImpl(isGlass: presentationData.theme.style == .glass)
        if case .glass = presentationData.theme.style {
        } else {
            self.rightButtonNodeImpl.hitTestSlop = UIEdgeInsets(top: -4.0, left: -4.0, bottom: -4.0, right: -10.0)
        }
        
        self.clippingNode = SparseNode()
        if case .glass = presentationData.theme.style {
        } else {
            self.clippingNode.clipsToBounds = true
        }
        
        self.buttonsContainerNode = SparseNode()
        self.buttonsContainerNode.clipsToBounds = true
        
        self.backButtonNodeImpl.color = self.presentationData.theme.buttonColor
        self.backButtonNodeImpl.disabledColor = self.presentationData.theme.disabledButtonColor
        self.leftButtonNodeImpl.color = self.presentationData.theme.buttonColor
        self.leftButtonNodeImpl.disabledColor = self.presentationData.theme.disabledButtonColor
        self.rightButtonNodeImpl.color = self.presentationData.theme.buttonColor
        self.rightButtonNodeImpl.disabledColor = self.presentationData.theme.disabledButtonColor
        self.backButtonArrow.image = presentationData.theme.style == .glass ? generateTintedImage(image: glassBackArrowImage, color: self.presentationData.theme.buttonColor) : navigationBarBackArrowImage(color: self.presentationData.theme.buttonColor)
        if let title = self.title {
            self.titleNode.attributedText = NSAttributedString(string: title, font: NavigationBarImpl.titleFont, textColor: self.presentationData.theme.primaryTextColor)
            self.titleNode.accessibilityLabel = title
        }
        self.stripeNode.backgroundColor = self.presentationData.theme.separatorColor

        self.backgroundNode = NavigationBackgroundNode(color: self.presentationData.theme.backgroundColor, enableBlur: self.presentationData.theme.enableBackgroundBlur)
        self.additionalContentNode = SparseNode()
        
        self.secondaryContentHeight = NavigationBarImpl.defaultSecondaryContentHeight
        
        self.customOverBackgroundContentView = SparseContainerView()
        
        super.init()
        
        if case .glass = presentationData.theme.style {
            let edgeEffectView = EdgeEffectView()
            edgeEffectView.isUserInteractionEnabled = false
            self.edgeEffectView = edgeEffectView
            self.view.addSubview(edgeEffectView)
            
            let backgroundContainer = GlassBackgroundContainerView()
            self.backgroundContainer = backgroundContainer
            self.view.addSubview(backgroundContainer)
            
            backgroundContainer.contentView.addSubview(self.customOverBackgroundContentView)
            
            let leftButtonsBackgroundView: (background: GlassContextExtractableContainer, container: UIView) = (GlassContextExtractableContainer(), UIView())
            leftButtonsBackgroundView.background.contentView.addSubview(leftButtonsBackgroundView.container)
            self.leftButtonsBackgroundView = leftButtonsBackgroundView
            backgroundContainer.contentView.addSubview(leftButtonsBackgroundView.background)
            
            let rightButtonsBackgroundView: (background: GlassContextExtractableContainer, container: UIView) = (GlassContextExtractableContainer(), UIView())
            rightButtonsBackgroundView.background.contentView.addSubview(rightButtonsBackgroundView.container)
            self.rightButtonsBackgroundView = rightButtonsBackgroundView
            backgroundContainer.contentView.addSubview(rightButtonsBackgroundView.background)
        } else {
            self.addSubnode(self.backgroundNode)
            self.view.addSubview(self.customOverBackgroundContentView)
        }
        self.addSubnode(self.buttonsContainerNode)
        self.addSubnode(self.clippingNode)
        self.addSubnode(self.additionalContentNode)
        
        self.stripeNode.isLayerBacked = true
        self.stripeNode.displaysAsynchronously = false
        if case .legacy = presentationData.theme.style {
            self.addSubnode(self.stripeNode)
        }

        self.backgroundColor = nil
        self.isOpaque = false
        
        self.titleNode.displaysAsynchronously = false
        self.titleNode.maximumNumberOfLines = 1
        self.titleNode.truncationType = .end
        self.titleNode.isOpaque = false
        
        self.backButtonNodeImpl.highlightChanged = { [weak self] index, highlighted in
            if let strongSelf = self, index == 0 {
                strongSelf.backButtonArrow.alpha = (highlighted ? 0.4 : 1.0)
                strongSelf.badgeNode.alpha = (highlighted ? 0.4 : 1.0)
            }
        }
        self.backButtonNodeImpl.pressed = { [weak self] index in
            if let strongSelf = self, index == 0 {
                if let leftBarButtonItem = strongSelf.item?.leftBarButtonItem, leftBarButtonItem.backButtonAppearance {
                    leftBarButtonItem.performActionOnTarget()
                } else {
                    strongSelf.backPressed()
                }
            }
        }
        
        self.leftButtonNodeImpl.pressed = { [weak self] index in
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
        
        self.rightButtonNodeImpl.pressed = { [weak self] index in
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
    
    public func updatePresentationData(_ presentationData: NavigationBarPresentationData, transition: ContainedViewLayoutTransition = .immediate) {
        if presentationData.theme !== self.presentationData.theme || presentationData.strings !== self.presentationData.strings {
            self.presentationData = presentationData
            
            self.backgroundNode.updateColor(color: self.presentationData.theme.backgroundColor, transition: transition)
            
            self.backButtonNodeImpl.color = self.presentationData.theme.buttonColor
            self.backButtonNodeImpl.disabledColor = self.presentationData.theme.disabledButtonColor
            self.leftButtonNodeImpl.color = self.presentationData.theme.buttonColor
            self.leftButtonNodeImpl.disabledColor = self.presentationData.theme.disabledButtonColor
            self.rightButtonNodeImpl.color = self.presentationData.theme.buttonColor
            self.rightButtonNodeImpl.disabledColor = self.presentationData.theme.disabledButtonColor
            self.backButtonArrow.image = self.presentationData.theme.style == .glass ? generateTintedImage(image: glassBackArrowImage, color: self.presentationData.theme.buttonColor) : navigationBarBackArrowImage(color: self.presentationData.theme.buttonColor)
            if let title = self.title {
                self.titleNode.attributedText = NSAttributedString(string: title, font: NavigationBarImpl.titleFont, textColor: self.presentationData.theme.primaryTextColor)
                self.titleNode.accessibilityLabel = title
            }
            self.stripeNode.backgroundColor = self.presentationData.theme.separatorColor
            
            self.badgeNode.updateTheme(fillColor: self.presentationData.theme.buttonColor, strokeColor: self.presentationData.theme.buttonColor, textColor: self.presentationData.theme.badgeTextColor)
            
            self.updateLeftButton(animated: false)
            self.requestLayout()
        }
    }
    
    private func requestLayout() {
        self.requestedLayout = true
        self.setNeedsLayout()
    }
    
    override public func layout() {
        super.layout()
        
        if let validLayout = self.validLayout, self.requestedLayout {
            self.requestedLayout = false
            self.updateLayout(size: validLayout.size, defaultHeight: validLayout.defaultHeight, additionalTopHeight: validLayout.additionalTopHeight, additionalContentHeight: validLayout.additionalContentHeight, additionalBackgroundHeight: validLayout.additionalBackgroundHeight, additionalCutout: validLayout.additionalCutout, leftInset: validLayout.leftInset, rightInset: validLayout.rightInset, appearsHidden: validLayout.appearsHidden, isLandscape: validLayout.isLandscape, transition: .immediate)
        }
    }
    
    public func updateLayout(size: CGSize, defaultHeight: CGFloat, additionalTopHeight: CGFloat, additionalContentHeight: CGFloat, additionalBackgroundHeight: CGFloat, additionalCutout: CGSize?, leftInset: CGFloat, rightInset: CGFloat, appearsHidden: Bool, isLandscape: Bool, transition: ContainedViewLayoutTransition) {
        if self.layoutSuspended {
            return
        }
        
        self.validLayout = (size, defaultHeight, additionalTopHeight, additionalContentHeight, additionalBackgroundHeight, additionalCutout, leftInset, rightInset, appearsHidden, isLandscape)
        
        var contentVerticalOrigin = additionalTopHeight
        if case .glass = self.presentationData.theme.style {
            contentVerticalOrigin += 2.0
        }

        let backgroundFrame = CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: size.height + additionalBackgroundHeight))
        if self.backgroundNode.frame != backgroundFrame {
            transition.updateFrame(node: self.backgroundNode, frame: backgroundFrame)
            self.backgroundNode.update(size: backgroundFrame.size, transition: transition)
        }
        
        if let backgroundContainer = self.backgroundContainer {
            var backgroundContainerFrame = backgroundFrame
            backgroundContainerFrame.size.height += 44.0
            transition.updateFrame(view: backgroundContainer, frame: backgroundContainerFrame)
            backgroundContainer.update(size: backgroundContainerFrame.size, isDark: self.presentationData.theme.overallDarkAppearance, transition: ComponentTransition(transition))
        }
        
        if let edgeEffectView = self.edgeEffectView {
            if let edgeEffectColor = self.presentationData.theme.edgeEffectColor, edgeEffectColor.alpha == 0.0 {
                edgeEffectView.isHidden = true
            } else {
                edgeEffectView.isHidden = false
                
                let edgeEffectHeight: CGFloat = size.height + additionalBackgroundHeight + 24.0
                
                let edgeEffectFrame = CGRect(origin: CGPoint(x: 0.0, y: -20.0), size: CGSize(width: size.width, height: 20.0 + edgeEffectHeight))
                transition.updatePosition(layer: edgeEffectView.layer, position: edgeEffectFrame.center)
                transition.updateBounds(layer: edgeEffectView.layer, bounds: CGRect(origin: CGPoint(), size: edgeEffectFrame.size))
                edgeEffectView.update(content: self.presentationData.theme.edgeEffectColor ?? .white, blur: true, rect: CGRect(origin: CGPoint(), size: edgeEffectFrame.size), edge: .top, edgeSize: min(64.0, edgeEffectHeight), transition: ComponentTransition(transition))
            }
        }
        
        let apparentAdditionalHeight: CGFloat = self.secondaryContentNode != nil ? (self.secondaryContentHeight * self.secondaryContentNodeDisplayFraction) : 0.0
        
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
                if case .glass = self.presentationData.theme.style {
                    contentNodeFrame = CGRect(origin: CGPoint(x: 0.0, y: contentVerticalOrigin), size: CGSize(width: size.width, height: contentNode.nominalHeight))
                } else {
                    contentNodeFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: size.width, height: size.height - additionalContentHeight))
                }
                
                transition.updateFrame(node: contentNode, frame: contentNodeFrame)
                let _ = contentNode.updateLayout(size: contentNodeFrame.size, leftInset: leftInset, rightInset: rightInset, transition: transition)
            case .expansion:
                expansionHeight = contentNode.height
                
                let additionalExpansionHeight: CGFloat = self.secondaryContentNode != nil && appearsHidden ? (self.secondaryContentHeight * self.secondaryContentNodeDisplayFraction) : 0.0
                contentNodeFrame = CGRect(origin: CGPoint(x: 0.0, y: size.height - (appearsHidden ? 0.0 : additionalContentHeight) - expansionHeight - apparentAdditionalHeight - additionalExpansionHeight), size: CGSize(width: size.width, height: expansionHeight))
                if appearsHidden {
                    contentNodeFrame.origin.y = size.height - contentNode.height + contentVerticalOrigin
                }
                if appearsHidden {
                    if self.secondaryContentNode != nil {
                        contentNodeFrame.origin.y += self.secondaryContentHeight * self.secondaryContentNodeDisplayFraction
                    }
                }
                
                transition.updateFrame(node: contentNode, frame: contentNodeFrame)
                let _ = contentNode.updateLayout(size: contentNodeFrame.size, leftInset: leftInset, rightInset: rightInset, transition: transition)
            }
        }
        
        transition.updateFrame(node: self.stripeNode, frame: CGRect(x: (additionalCutout?.width ?? 0.0), y: size.height + additionalBackgroundHeight, width: size.width - (additionalCutout?.width ?? 0.0), height: UIScreenPixel))
        
        let nominalHeight: CGFloat = 60.0
        
        var leftTitleInset: CGFloat = leftInset
        var rightTitleInset: CGFloat = rightInset
        
        var leftButtonsWidth: CGFloat = 0.0
        if self.backButtonNodeImpl.view.superview != nil {
            let backButtonSize = self.backButtonNodeImpl.updateLayout(constrainedSize: CGSize(width: size.width, height: 44.0), isLandscape: isLandscape, isLeftAligned: true)
            leftTitleInset = backButtonSize.width + backButtonInset
            
            if case .glass = self.presentationData.theme.style {
            } else {
                let topHitTestSlop = (nominalHeight - backButtonSize.height) * 0.5
                self.backButtonNodeImpl.hitTestSlop = UIEdgeInsets(top: -topHitTestSlop, left: -27.0, bottom: -topHitTestSlop, right: -8.0)
            }
            
            do {
                self.backButtonNodeImpl.alpha = 1.0
                if case .glass = self.presentationData.theme.style {
                } else {
                    transition.updateFrame(node: self.backButtonNodeImpl, frame: CGRect(origin: CGPoint(x: backButtonInset, y: contentVerticalOrigin + floor((nominalHeight - backButtonSize.height) / 2.0)), size: backButtonSize))
                }
                
                self.backButtonArrow.alpha = 1.0
                
                let backButtonArrowFrame: CGRect
                if case .glass = self.presentationData.theme.style {
                    let backButtonArrowSize = CGSize(width: 44.0, height: 44.0)
                    backButtonArrowFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: backButtonArrowSize)
                } else {
                    let backButtonArrowSize = CGSize(width: 13.0, height: 22.0)
                    backButtonArrowFrame = CGRect(origin: CGPoint(x: leftInset + 8.0, y: contentVerticalOrigin + floor((nominalHeight - backButtonArrowSize.height) / 2.0)), size: backButtonArrowSize)
                }
                leftButtonsWidth += backButtonArrowFrame.width
                transition.updateFrame(node: self.backButtonArrow, frame: backButtonArrowFrame)
                self.badgeNode.alpha = 1.0
            }
        } else if self.leftButtonNodeImpl.view.superview != nil {
            let leftButtonSize = self.leftButtonNodeImpl.updateLayout(constrainedSize: CGSize(width: size.width, height: 44.0), isLandscape: isLandscape, isLeftAligned: true)
            leftTitleInset = leftButtonSize.width + leftButtonInset + 1.0
            
            var transition = transition
            if self.leftButtonNodeImpl.frame.width.isZero {
                transition = .immediate
            }
            
            self.leftButtonNodeImpl.alpha = 1.0
            if case .glass = self.presentationData.theme.style {
                transition.updateFrame(node: self.leftButtonNodeImpl, frame: CGRect(origin: CGPoint(x: leftButtonsWidth, y: floor((44.0 - leftButtonSize.height) / 2.0)), size: leftButtonSize))
            } else {
                transition.updateFrame(node: self.leftButtonNodeImpl, frame: CGRect(origin: CGPoint(x: leftButtonInset, y: contentVerticalOrigin + floor((nominalHeight - leftButtonSize.height) / 2.0)), size: leftButtonSize))
            }
            
            if !self.leftButtonNodeImpl.isEmpty {
                leftButtonsWidth += leftButtonSize.width
            }
        }
        
        let badgeSize = self.badgeNode.measure(CGSize(width: 200.0, height: 100.0))
        let backButtonArrowFrame = self.backButtonArrow.frame
        if case .glass = self.presentationData.theme.style, self.badgeNode.view.superview != nil, !self.badgeNode.isHidden {
            transition.updateFrame(node: self.badgeNode, frame: CGRect(origin: CGPoint(x: leftButtonsWidth - 14.0, y: floor((44.0 - badgeSize.height) * 0.5)), size: badgeSize))
            leftButtonsWidth += badgeSize.width - 3.0
        } else {
            transition.updateFrame(node: self.badgeNode, frame: CGRect(origin: backButtonArrowFrame.origin.offsetBy(dx: 16.0, dy: 2.0), size: badgeSize))
        }
        
        var rightButtonsWidth: CGFloat = 0.0
        if self.rightButtonNodeImpl.view.superview != nil {
            let rightButtonSize = self.rightButtonNodeImpl.updateLayout(constrainedSize: (CGSize(width: size.width, height: 44.0)), isLandscape: isLandscape, isLeftAligned: false)
            if !self.rightButtonNodeImpl.isEmpty {
                rightButtonsWidth += rightButtonSize.width
            }
            self.rightButtonNodeImpl.alpha = 1.0
            
            var transition = transition
            if self.rightButtonNodeImpl.frame.width.isZero || self.rightButtonNodeUpdated {
                transition = .immediate
            }
            if case .glass = self.presentationData.theme.style {
                transition.updateFrame(node: self.rightButtonNodeImpl, frame: CGRect(origin: CGPoint(x: 0.0, y: floor((44.0 - rightButtonSize.height) / 2.0)), size: rightButtonSize))
            } else {
                rightTitleInset = rightButtonSize.width + leftButtonInset + 4.0
                transition.updateFrame(node: self.rightButtonNodeImpl, frame: CGRect(origin: CGPoint(x: size.width - leftButtonInset - rightButtonSize.width, y: contentVerticalOrigin + floor((nominalHeight - rightButtonSize.height) / 2.0)), size: rightButtonSize))
            }
        }
        self.rightButtonNodeUpdated = false
        
        if let leftButtonsBackgroundView = self.leftButtonsBackgroundView {
            if leftButtonsWidth != 0.0 {
                leftTitleInset = leftInset + 16.0 + leftButtonsWidth + 10.0
            }
            
            if self.backButtonNodeImpl.view.superview != nil {
                transition.updateFrame(node: self.backButtonNodeImpl, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: leftButtonsWidth, height: 44.0)))
            }
            
            let leftButtonsBackgroundFrame = CGRect(origin: CGPoint(x: leftInset + 16.0, y: contentVerticalOrigin + floor((nominalHeight - 44.0) * 0.5)), size: CGSize(width: max(44.0, leftButtonsWidth), height: 44.0))
            var leftButtonsBackgroundTransition = ComponentTransition(transition)
            if leftButtonsBackgroundView.background.alpha == 0.0 {
                leftButtonsBackgroundTransition = .immediate
            }
            
            leftButtonsBackgroundTransition.setPosition(view: leftButtonsBackgroundView.background, position: leftButtonsBackgroundFrame.center)
            leftButtonsBackgroundTransition.setBounds(view: leftButtonsBackgroundView.background, bounds: CGRect(origin: CGPoint(), size: leftButtonsBackgroundFrame.size))
            leftButtonsBackgroundTransition.setFrame(view: leftButtonsBackgroundView.container, frame: CGRect(origin: CGPoint(), size: leftButtonsBackgroundFrame.size))
            ComponentTransition(transition).setAlpha(view: leftButtonsBackgroundView.background, alpha: leftButtonsWidth == 0.0 ? 0.0 : 1.0)
            leftButtonsBackgroundView.background.update(size: leftButtonsBackgroundFrame.size, cornerRadius: leftButtonsBackgroundFrame.height * 0.5, isDark: self.presentationData.theme.overallDarkAppearance, tintColor: .init(kind: self.presentationData.theme.glassStyle == .clear ? .clear : .panel), isInteractive: true, isVisible: leftButtonsWidth != 0.0, transition: leftButtonsBackgroundTransition)
        }
        
        if let rightButtonsBackgroundView = self.rightButtonsBackgroundView {
            if rightButtonsWidth != 0.0 {
                rightTitleInset = rightInset + 16.0 + rightButtonsWidth + 10.0
                
                let rightButtonsBackgroundFrame = CGRect(origin: CGPoint(x: size.width - rightInset - 16.0 - rightButtonsWidth, y: contentVerticalOrigin + floor((nominalHeight - 44.0) * 0.5)), size: CGSize(width: rightButtonsWidth, height: 44.0))
                var rightButtonsBackgroundTransition = ComponentTransition(transition)
                if rightButtonsBackgroundView.background.isHidden {
                    rightButtonsBackgroundTransition = .immediate
                }
                rightButtonsBackgroundView.container.layer.cornerRadius = 44.0 * 0.5
                
                rightButtonsBackgroundTransition.setFrame(view: rightButtonsBackgroundView.background, frame: rightButtonsBackgroundFrame)
                
                if rightButtonsBackgroundView.container.bounds.size != rightButtonsBackgroundFrame.size {
                    rightButtonsBackgroundView.container.clipsToBounds = true
                    let rightButtonsBackgroundViewContainer = rightButtonsBackgroundView.container
                    rightButtonsBackgroundTransition.setFrame(view: rightButtonsBackgroundView.container, frame: CGRect(origin: CGPoint(), size: rightButtonsBackgroundFrame.size), completion: { [weak rightButtonsBackgroundViewContainer] flag in
                        if flag, let rightButtonsBackgroundViewContainer {
                            rightButtonsBackgroundViewContainer.clipsToBounds = false
                        }
                    })
                }
                
                rightButtonsBackgroundView.background.isHidden = false
                rightButtonsBackgroundView.background.update(size: rightButtonsBackgroundFrame.size, cornerRadius: rightButtonsBackgroundFrame.height * 0.5, isDark: self.presentationData.theme.overallDarkAppearance, tintColor: .init(kind: self.presentationData.theme.glassStyle == .clear ? .clear : .panel), isInteractive: true, transition: rightButtonsBackgroundTransition)
            } else {
                rightButtonsBackgroundView.background.isHidden = true
            }
        }
        
        if (leftTitleInset == leftInset) != (rightTitleInset == rightInset) {
            if rightTitleInset == rightInset {
                rightTitleInset = leftTitleInset
            } else if leftTitleInset == leftInset {
                leftTitleInset = rightTitleInset
            }
        }
        
        if self.titleNode.view.superview != nil {
            let titleSize = self.titleNode.updateLayout(CGSize(width: max(1.0, size.width - max(leftTitleInset, rightTitleInset) * 2.0), height: nominalHeight))
            
            do {
                var transition = transition
                if self.titleNode.frame.width.isZero {
                    transition = .immediate
                }
                self.titleNode.alpha = 1.0
                
                let titleOffset: CGFloat = 0.0
                transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: floor((size.width - titleSize.width) / 2.0), y: contentVerticalOrigin + titleOffset + floorToScreenPixels((nominalHeight - titleSize.height) / 2.0)), size: titleSize))
            }
        }
        
        if let titleView = self.titleView {
            if let titleView = titleView as? NavigationBarTitleView {
                var titleViewTransition = transition
                if titleView.frame.isEmpty {
                    titleViewTransition = .immediate
                }
                
                let titleSize = titleView.updateLayout(availableSize: CGSize(width: size.width - leftTitleInset - rightTitleInset, height: nominalHeight), transition: titleViewTransition)
                
                var titleFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - titleSize.width) * 0.5), y: contentVerticalOrigin + floorToScreenPixels((nominalHeight - titleSize.height) / 2.0)), size: titleSize)
                if titleFrame.origin.x < leftTitleInset {
                    titleFrame.origin.x = leftTitleInset + floorToScreenPixels((size.width - leftTitleInset - rightTitleInset - titleFrame.width) * 0.5)
                }
                
                titleViewTransition.updateFrame(view: titleView, frame: titleFrame)
            } else {
                let titleSize = CGSize(width: max(1.0, size.width - max(leftTitleInset, rightTitleInset) * 2.0), height: nominalHeight)
                let titleFrame = CGRect(origin: CGPoint(x: floor((size.width - titleSize.width) / 2.0), y: contentVerticalOrigin + floorToScreenPixels((nominalHeight - titleSize.height) / 2.0)), size: titleSize)
                var titleViewTransition = transition
                if titleView.frame.isEmpty {
                    titleViewTransition = .immediate
                    titleView.frame = titleFrame
                }

                titleViewTransition.updateFrame(view: titleView, frame: titleFrame)
            }
        }
    }
    
    public func updateEdgeEffectExtension(value: CGFloat, transition: ContainedViewLayoutTransition) {
        if self.edgeEffectExtension == value {
            return
        }
        self.edgeEffectExtension = value
        self.applyEdgeEffectExtension(transition: transition)
    }
    
    private func applyEdgeEffectExtension(transition: ContainedViewLayoutTransition) {
        if let edgeEffectView = self.edgeEffectView {
            transition.updateTransform(layer: edgeEffectView.layer, transform: CATransform3DMakeTranslation(0.0, max(0.0, min(20.0, self.edgeEffectExtension)), 0.0))
        }
    }
    
    public func navigationButtonContextContainer(sourceView: UIView) -> ContextExtractableContainer? {
        if let leftButtonsBackgroundView = self.leftButtonsBackgroundView, sourceView.isDescendant(of: leftButtonsBackgroundView.background) {
            return leftButtonsBackgroundView.background
        }
        if let rightButtonsBackgroundView = self.rightButtonsBackgroundView, sourceView.isDescendant(of: rightButtonsBackgroundView.background) {
            return rightButtonsBackgroundView.background
        }
        return nil
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
            result += self.secondaryContentHeight * self.secondaryContentNodeDisplayFraction
        }
        
        return result
    }
    
    public func setContentNode(_ contentNode: NavigationBarContentNode?, animated: Bool) {
        let transition: ComponentTransition = animated ? .easeInOut(duration: 0.2) : .immediate
        
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
                guard let self else {
                    return
                }
                self.requestContainerLayout?(transition)
            }
            if let contentNode {
                contentNode.layer.removeAnimation(forKey: "opacity")
                if case .glass = self.presentationData.theme.style {
                    self.addSubnode(contentNode)
                } else {
                    contentNode.clipsToBounds = true
                    if self.stripeNode.supernode != nil {
                        self.insertSubnode(contentNode, belowSubnode: self.stripeNode)
                    } else {
                        self.insertSubnode(contentNode, at: 0)
                    }
                }
                if animated {
                    contentNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                }
                
                if case .replacement = contentNode.mode {
                    if !self.buttonsContainerNode.alpha.isZero {
                        self.buttonsContainerNode.alpha = 0.0
                        if animated {
                            self.buttonsContainerNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
                        }
                    }
                    if let backgroundContainer = self.backgroundContainer, !backgroundContainer.alpha.isZero {
                        transition.setAlpha(view: backgroundContainer, alpha: 0.0)
                    }
                }
                
                if !self.bounds.size.width.isZero {
                    self.requestedLayout = true
                    self.layout()
                } else {
                    self.requestLayout()
                }
            } else {
                if self.buttonsContainerNode.alpha.isZero {
                    self.buttonsContainerNode.alpha = 1.0
                    if animated {
                        self.buttonsContainerNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    }
                }
                if let backgroundContainer = self.backgroundContainer, backgroundContainer.alpha.isZero {
                    transition.setAlpha(view: backgroundContainer, alpha: 1.0)
                }
            }
        }
    }
    
    public func setSecondaryContentNode(_ secondaryContentNode: ASDisplayNode?, animated: Bool = false) {
        if self.secondaryContentNode !== secondaryContentNode {
            if let previous = self.secondaryContentNode, previous.supernode === self.clippingNode {
                if animated {
                    previous.layer.animateAlpha(from: previous.alpha, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak previous] finished in
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
                    secondaryContentNode.layer.animateAlpha(from: 0.0, to: secondaryContentNode.alpha, duration: 0.3)
                }
            }
        }
    }
    
    public func executeBack() -> Bool {
        if self.backButtonNodeImpl.isInHierarchy {
            self.backButtonNodeImpl.pressed(0)
        } else if self.leftButtonNodeImpl.isInHierarchy {
            self.leftButtonNodeImpl.pressed(0)
        } else {
            self.backButtonNodeImpl.pressed(0)
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
    
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let result = self.additionalContentNode.view.hitTest(self.view.convert(point, to: self.additionalContentNode.view), with: event) {
            return result
        }

        guard let result = super.hitTest(point, with: event) else {
            if !self.bounds.contains(point) {
                if let result = self.customOverBackgroundContentView.hitTest(self.view.convert(point, to: self.customOverBackgroundContentView), with: event) {
                    if result !== self.backgroundContainer?.contentView {
                        return result
                    }
                }
            }
            return nil
        }
        
        if self.passthroughTouches && (result == self.view || result == self.buttonsContainerNode.view || result == self.backgroundNode.view || result == self.backgroundNode.backgroundView || result == self.backgroundContainer?.contentView) {
            return nil
        }
        
        return result
    }
}
