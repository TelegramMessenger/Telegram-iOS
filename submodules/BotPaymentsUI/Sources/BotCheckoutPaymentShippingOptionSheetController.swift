import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import AccountContext
import TelegramStringFormatting

final class BotCheckoutPaymentShippingOptionSheetController: ActionSheetController {
    private var presentationDisposable: Disposable?
    
    init(context: AccountContext, currency: String, options: [BotPaymentShippingOption], currentId: String?, applyValue: @escaping (String) -> Void) {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let strings = presentationData.strings
        
        super.init(theme: ActionSheetControllerTheme(presentationData: presentationData))
        
        self.presentationDisposable = context.sharedContext.presentationData.start(next: { [weak self] presentationData in
            if let strongSelf = self {
                strongSelf.theme = ActionSheetControllerTheme(presentationData: presentationData)
            }
        })
        
        var items: [ActionSheetItem] = []
        
        items.append(ActionSheetTextItem(title: strings.Checkout_ShippingMethod))
        
        let dismissAction: () -> Void = { [weak self] in
            self?.dismissAnimated()
        }
        
        let toggleCheck: (String, Int) -> Void = { [weak self] id, itemIndex in
            for i in 0 ..< options.count {
                self?.updateItem(groupIndex: 0, itemIndex: i + 1, { item in
                    if let item = item as? BotCheckoutPaymentShippingOptionItem, let value = item.value {
                        return BotCheckoutPaymentShippingOptionItem(title: item.title, label: item.label, value: i == itemIndex ? !value : false, action: item.action)
                    }
                    return item
                })
            }
            applyValue(id)
            dismissAction()
        }
        
        var itemIndex = 0
        for option in options {
            let index = itemIndex
            var totalPrice: Int64 = 0
            for price in option.prices {
                totalPrice += price.amount
            }
            let value: Bool?
            if let currentId = currentId {
                value = option.id == currentId
            } else {
                value = nil
            }
            items.append(BotCheckoutPaymentShippingOptionItem(title: option.title, label: formatCurrencyAmount(totalPrice, currency: currency), value: value, action: { value in
                toggleCheck(option.id, index)
            }))
            itemIndex += 1
        }
        
        self.setItemGroups([
            ActionSheetItemGroup(items: items),
            ActionSheetItemGroup(items: [
                ActionSheetButtonItem(title: strings.Common_Cancel, action: { [weak self] in
                    self?.dismissAnimated()
                }),
            ])
        ])
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.presentationDisposable?.dispose()
    }
}

public class BotCheckoutPaymentShippingOptionItem: ActionSheetItem {
    public let title: String
    public let label: String
    public let value: Bool?
    public let action: (Bool) -> Void
    
    public init(title: String, label: String, value: Bool?, action: @escaping (Bool) -> Void) {
        self.title = title
        self.label = label
        self.value = value
        self.action = action
    }
    
    public func node(theme: ActionSheetControllerTheme) -> ActionSheetItemNode {
        let node = BotCheckoutPaymentShippingOptionItemNode(theme: theme)
        node.setItem(self)
        return node
    }
    
    public func updateNode(_ node: ActionSheetItemNode) {
        guard let node = node as? BotCheckoutPaymentShippingOptionItemNode else {
            assertionFailure()
            return
        }
        
        node.setItem(self)
        node.requestLayoutUpdate()
    }
}

public class BotCheckoutPaymentShippingOptionItemNode: ActionSheetItemNode {
    private let defaultFont: UIFont
    
    private let theme: ActionSheetControllerTheme
    
    private var item: BotCheckoutPaymentShippingOptionItem?
    
    private let button: HighlightTrackingButton
    private let titleNode: ASTextNode
    private let labelNode: ASTextNode
    private let checkNode: ASImageNode
    
    public override init(theme: ActionSheetControllerTheme) {
        self.theme = theme
        self.defaultFont = Font.regular(floor(theme.baseFontSize * 20.0 / 17.0))
        
        self.button = HighlightTrackingButton()
        
        self.titleNode = ASTextNode()
        self.titleNode.maximumNumberOfLines = 1
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.displaysAsynchronously = false
        
        self.labelNode = ASTextNode()
        self.labelNode.maximumNumberOfLines = 1
        self.labelNode.isUserInteractionEnabled = false
        self.labelNode.displaysAsynchronously = false
        
        self.checkNode = ASImageNode()
        self.checkNode.isUserInteractionEnabled = false
        self.checkNode.displayWithoutProcessing = true
        self.checkNode.displaysAsynchronously = false
        self.checkNode.image = generateImage(CGSize(width: 14.0, height: 11.0), rotatedContext: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            context.setStrokeColor(theme.controlAccentColor.cgColor)
            context.setLineWidth(2.0)
            context.move(to: CGPoint(x: 12.0, y: 1.0))
            context.addLine(to: CGPoint(x: 4.16482734, y: 9.0))
            context.addLine(to: CGPoint(x: 1.0, y: 5.81145833))
            context.strokePath()
        })
        
        super.init(theme: theme)
        
        self.view.addSubview(self.button)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.labelNode)
        self.addSubnode(self.checkNode)
        
        self.button.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.backgroundNode.backgroundColor = strongSelf.theme.itemHighlightedBackgroundColor
                } else {
                    UIView.animate(withDuration: 0.3, animations: {
                        strongSelf.backgroundNode.backgroundColor = strongSelf.theme.itemBackgroundColor
                    })
                }
            }
        }
        
        self.button.addTarget(self, action: #selector(self.buttonPressed), for: .touchUpInside)
    }
    
    func setItem(_ item: BotCheckoutPaymentShippingOptionItem) {
        self.item = item
        
        self.titleNode.attributedText = NSAttributedString(string: item.title, font: self.defaultFont, textColor: self.theme.primaryTextColor)
        self.labelNode.attributedText = NSAttributedString(string: item.label, font: self.defaultFont, textColor: self.theme.primaryTextColor)
        if let value = item.value {
            self.checkNode.isHidden = !value
        } else {
            self.checkNode.isHidden = true
        }
    }
    
    public override func updateLayout(constrainedSize: CGSize, transition: ContainedViewLayoutTransition) -> CGSize {
        let size = CGSize(width: constrainedSize.width, height: 57.0)
      
        self.button.frame = CGRect(origin: CGPoint(), size: size)
        
        var checkInset: CGFloat = 15.0
        if let _ = self.item?.value {
            checkInset = 44.0
        }
        
        let labelSize = self.labelNode.measure(CGSize(width: size.width - 44.0 - 15.0 - 8.0, height: size.height))
        let titleSize = self.titleNode.measure(CGSize(width: size.width - 44.0 - labelSize.width - 15.0 - 8.0, height: size.height))
        self.titleNode.frame = CGRect(origin: CGPoint(x: checkInset, y: floorToScreenPixels((size.height - titleSize.height) / 2.0)), size: titleSize)
        self.labelNode.frame = CGRect(origin: CGPoint(x: size.width - 15.0 - labelSize.width, y: floorToScreenPixels((size.height - labelSize.height) / 2.0)), size: labelSize)
        
        if let image = self.checkNode.image {
            self.checkNode.frame = CGRect(origin: CGPoint(x: floor((44.0 - image.size.width) / 2.0), y: floor((size.height - image.size.height) / 2.0)), size: image.size)
        }
        
        self.updateInternalLayout(size, constrainedSize: constrainedSize)
        return size
    }
    
    @objc func buttonPressed() {
        if let item = self.item {
            let updatedValue: Bool
            if let value = item.value {
                updatedValue = !value
            } else {
                updatedValue = true
            }
            item.action(updatedValue)
        }
    }
}
