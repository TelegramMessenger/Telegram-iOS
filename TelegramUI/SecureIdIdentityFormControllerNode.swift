import Foundation
import AsyncDisplayKit
import Display
import TelegramCore
import Postbox
import SwiftSignalKit

enum SecureIdIdentityFormFocus {
    case name
    case surname
}

private final class SecureIdIdentityFormItems {
    let header: BotPaymentHeaderItemNode
    let name: BotPaymentFieldItemNode
    let surname: BotPaymentFieldItemNode
    let birthdate: BotPaymentDisclosureItemNode
    let gender: BotPaymentDisclosureItemNode
    let citizenship: BotPaymentDisclosureItemNode
    
    var items: [BotPaymentItemNode] {
        return [
            self.header,
            self.name,
            self.surname,
            self.birthdate,
            self.gender,
            self.citizenship
        ]
    }
    
    init(strings: PresentationStrings, openBirthdateSelection: @escaping () -> Void, openGenderSelection: @escaping () -> Void, openCitizenshipSelection: @escaping () -> Void) {
        self.header = BotPaymentHeaderItemNode(text: "PERSONAL DETAILS")
        self.name = BotPaymentFieldItemNode(title: strings.CheckoutInfo_ShippingInfoAddress1, placeholder: strings.CheckoutInfo_ShippingInfoAddress1Placeholder)
        self.surname = BotPaymentFieldItemNode(title: strings.CheckoutInfo_ShippingInfoAddress2, placeholder: strings.CheckoutInfo_ShippingInfoAddress2Placeholder)
        self.birthdate = BotPaymentDisclosureItemNode(title: strings.CheckoutInfo_ShippingInfoCountry, placeholder: strings.CheckoutInfo_ShippingInfoCountryPlaceholder, text: "")
        self.gender = BotPaymentDisclosureItemNode(title: strings.CheckoutInfo_ShippingInfoCountry, placeholder: strings.CheckoutInfo_ShippingInfoCountryPlaceholder, text: "")
        self.citizenship = BotPaymentDisclosureItemNode(title: strings.CheckoutInfo_ShippingInfoCountry, placeholder: strings.CheckoutInfo_ShippingInfoCountryPlaceholder, text: "")
        
        self.birthdate.action = {
            openBirthdateSelection()
        }
        
        self.gender.action = {
            openGenderSelection()
        }
        
        self.citizenship.action = {
            openCitizenshipSelection()
        }
    }
}

private final class SecureIdIdentityFormScrollerNodeView: UIScrollView {
    var ignoreUpdateBounds = false
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        if #available(iOSApplicationExtension 11.0, *) {
            self.contentInsetAdjustmentBehavior = .never
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var bounds: CGRect {
        get {
            return super.bounds
        } set(value) {
            if !self.ignoreUpdateBounds {
                super.bounds = value
            }
        }
    }
    
    override func scrollRectToVisible(_ rect: CGRect, animated: Bool) {
    }
}

private final class SecureIdIdentityFormScrollerNode: ASDisplayNode {
    override var view: SecureIdIdentityFormScrollerNodeView {
        return super.view as! SecureIdIdentityFormScrollerNodeView
    }
    
    override init() {
        super.init()
        
        self.setViewBlock({
            return SecureIdIdentityFormScrollerNodeView(frame: CGRect())
        })
    }
}

final class SecureIdIdentityFormControllerNode: ViewControllerTracingNode, UIScrollViewDelegate {
    private let account: Account
    
    private var focus: SecureIdIdentityFormFocus?
    
    private let dismiss: () -> Void
    private let present: (ViewController, Any?) -> Void
    
    private var theme: PresentationTheme
    private var strings: PresentationStrings
    
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    
    private let scrollNode: SecureIdIdentityFormScrollerNode
    private let itemNodes: [[BotPaymentItemNode]]
    
    private let formItems: SecureIdIdentityFormItems
    private var data: SecureIdIdentityData?
    
    private let verifyDisposable = MetaDisposable()
    private var isVerifying = false
    
    init(account: Account, data: SecureIdIdentityData?, theme: PresentationTheme, strings: PresentationStrings, dismiss: @escaping () -> Void, present: @escaping (ViewController, Any?) -> Void) {
        self.account = account
        self.data = data
        //self.focus = .name
        self.dismiss = dismiss
        self.present = present
        
        self.theme = theme
        self.strings = strings
        
        self.scrollNode = SecureIdIdentityFormScrollerNode()
        
        var itemNodes: [[BotPaymentItemNode]] = []
        
        self.formItems = SecureIdIdentityFormItems(strings: strings, openBirthdateSelection: {
        }, openGenderSelection: {
        }, openCitizenshipSelection: {
        })
        
        itemNodes.append(self.formItems.items)
        
        self.itemNodes = itemNodes
        
        for items in itemNodes {
            for item in items {
                self.scrollNode.addSubnode(item)
            }
        }
        
        super.init()
        
        self.backgroundColor = self.theme.list.blocksBackgroundColor
        self.scrollNode.backgroundColor = nil
        self.scrollNode.isOpaque = false
        self.scrollNode.view.alwaysBounceVertical = true
        self.scrollNode.view.showsVerticalScrollIndicator = false
        self.scrollNode.view.showsHorizontalScrollIndicator = false
        self.scrollNode.view.delegate = self
        
        self.addSubnode(self.scrollNode)
        
        for items in itemNodes {
            for item in items {
                if let item = item as? BotPaymentFieldItemNode {
                    item.textUpdated = { [weak self] in
                        self?.updateDone()
                    }
                }
            }
        }
        
        self.updateDone()
    }
    
    deinit {
        self.verifyDisposable.dispose()
    }
    
    func verify() {
        self.isVerifying = true
        self.updateDone()
    }
    
    private func updateDone() {
        var enabled = true
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        let previousLayout = self.containerLayout
        self.containerLayout = (layout, navigationBarHeight)
        
        var insets = layout.insets(options: [.input])
        insets.top += max(navigationBarHeight, layout.insets(options: [.statusBar]).top)
        
        var contentHeight: CGFloat = 0.0
        
        var commonInset: CGFloat = 0.0
        for items in self.itemNodes {
            for item in items {
                commonInset = max(commonInset, item.measureInset(theme: self.theme, width: layout.size.width))
            }
        }
        
        for items in self.itemNodes {
            if !items.isEmpty && items[0] is BotPaymentHeaderItemNode {
                contentHeight += 24.0
            } else {
                contentHeight += 32.0
            }
            
            for i in 0 ..< items.count {
                let item = items[i]
                let itemHeight = item.updateLayout(theme: self.theme, width: layout.size.width, measuredInset: commonInset, previousItemNode: i == 0 ? nil : items[i - 1], nextItemNode: i == (items.count - 1) ? nil : items[i + 1], transition: transition)
                transition.updateFrame(node: item, frame: CGRect(origin: CGPoint(x: 0.0, y: contentHeight), size: CGSize(width: layout.size.width, height: itemHeight)))
                contentHeight += itemHeight
            }
        }
        
        contentHeight += 24.0
        
        let scrollContentSize = CGSize(width: layout.size.width, height: contentHeight)
        
        let previousBoundsOrigin = self.scrollNode.bounds.origin
        self.scrollNode.view.ignoreUpdateBounds = true
        transition.updateFrame(node: self.scrollNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        self.scrollNode.view.contentSize = scrollContentSize
        self.scrollNode.view.contentInset = insets
        self.scrollNode.view.scrollIndicatorInsets = insets
        self.scrollNode.view.ignoreUpdateBounds = false
        
        if let focus = self.focus {
            var focusItem: ASDisplayNode?
            switch focus {
                case .name:
                    focusItem = self.formItems.name
                case .surname:
                    focusItem = self.formItems.surname
            }
            if let focusItem = focusItem {
                let scrollVisibleSize = CGSize(width: layout.size.width, height: layout.size.height - insets.top - insets.bottom)
                var contentOffset = CGPoint(x: 0.0, y: -insets.top + floor(focusItem.frame.midY - scrollVisibleSize.height / 2.0))
                contentOffset.y = min(contentOffset.y, scrollContentSize.height + insets.bottom - layout.size.height)
                contentOffset.y = max(contentOffset.y, -insets.top)
                transition.updateBounds(node: self.scrollNode, bounds: CGRect(origin: CGPoint(x: 0.0, y: contentOffset.y), size: layout.size))
                
                if previousLayout == nil, let focusItem = focusItem as? BotPaymentFieldItemNode {
                    focusItem.activateInput()
                }
            }
        } else if let previousLayout = previousLayout {
            var previousInsets = previousLayout.0.insets(options: [.input])
            previousInsets.top += max(previousLayout.1, previousLayout.0.insets(options: [.statusBar]).top)
            let insetsScrollOffset = insets.top - previousInsets.top
            
            var contentOffset = CGPoint(x: 0.0, y: previousBoundsOrigin.y + insetsScrollOffset)
            contentOffset.y = min(contentOffset.y, scrollContentSize.height + insets.bottom - layout.size.height)
            contentOffset.y = max(contentOffset.y, -insets.top)
            
            transition.updateBounds(node: self.scrollNode, bounds: CGRect(origin: CGPoint(x: 0.0, y: contentOffset.y), size: layout.size))
        } else {
            let contentOffset = CGPoint(x: 0.0, y: -insets.top)
            transition.updateBounds(node: self.scrollNode, bounds: CGRect(origin: CGPoint(x: 0.0, y: contentOffset.y), size: layout.size))
        }
    }
    
    func animateIn() {
        self.layer.animatePosition(from: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), to: self.layer.position, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring)
    }
    
    func animateOut(completion: (() -> Void)? = nil) {
        self.layer.animatePosition(from: self.layer.position, to: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), duration: 0.2, timingFunction: kCAMediaTimingFunctionEaseInEaseOut, removeOnCompletion: false, completion: { [weak self] _ in
            if let strongSelf = self {
                strongSelf.dismiss()
            }
            completion?()
        })
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        self.focus = nil
    }
}

