import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import AccountContext
import AppBundle

struct BotCheckoutPaymentWebToken: Equatable {
    let title: String
    let data: String
    var saveOnServer: Bool
}

enum BotCheckoutPaymentMethod: Equatable {
    case savedCredentials(BotPaymentSavedCredentials)
    case webToken(BotCheckoutPaymentWebToken)
    case applePay
    case other(BotPaymentMethod)
    
    var title: String {
        switch self {
            case let .savedCredentials(credentials):
                switch credentials {
                    case let .card(_, title):
                        return title
                }
            case let .webToken(token):
                return token.title
            case .applePay:
                return "Apple Pay"
            case let .other(method):
                return method.title
        }
    }
}

final class BotCheckoutPaymentMethodSheetController: ActionSheetController {
    private var presentationDisposable: Disposable?
    
    init(context: AccountContext, currentMethod: BotCheckoutPaymentMethod?, methods: [BotCheckoutPaymentMethod], applyValue: @escaping (BotCheckoutPaymentMethod) -> Void, newCard: @escaping () -> Void, otherMethod: @escaping (String) -> Void) {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let strings = presentationData.strings
        
        super.init(theme: ActionSheetControllerTheme(presentationData: presentationData))
        
        self.presentationDisposable = context.sharedContext.presentationData.start(next: { [weak self] presentationData in
            if let strongSelf = self {
                strongSelf.theme = ActionSheetControllerTheme(presentationData: presentationData)
            }
        })
        
        var items: [ActionSheetItem] = []
        
        items.append(ActionSheetTextItem(title: strings.Checkout_PaymentMethod))
        
        for method in methods {
            let title: String
            let icon: UIImage?
            switch method {
                case let .savedCredentials(credentials):
                    switch credentials {
                        case let .card(_, cardTitle):
                            title = cardTitle
                            icon = nil
                    }
                case let .webToken(token):
                    title = token.title
                    icon = nil
                case .applePay:
                    title = "Apple Pay"
                    icon = UIImage(bundleImageName: "Bot Payments/ApplePayLogo")?.precomposed()
                case let .other(method):
                    title = method.title
                    icon = nil
            }
            let value: Bool?
            if let currentMethod = currentMethod {
                value = method == currentMethod
            } else {
                value = nil
            }
            items.append(BotCheckoutPaymentMethodItem(title: title, icon: icon, value: value, action: { [weak self] _ in
                if case let .other(method) = method {
                    otherMethod(method.url)
                } else {
                    applyValue(method)
                }
                self?.dismissAnimated()
            }))
        }
        
        items.append(ActionSheetButtonItem(title: strings.Checkout_PaymentMethod_New, action: { [weak self] in
            self?.dismissAnimated()
            newCard()
        }))
        
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

public class BotCheckoutPaymentMethodItem: ActionSheetItem {
    public let title: String
    public let icon: UIImage?
    public let value: Bool?
    public let action: (Bool) -> Void
    
    public init(title: String, icon: UIImage?, value: Bool?, action: @escaping (Bool) -> Void) {
        self.title = title
        self.icon = icon
        self.value = value
        self.action = action
    }
    
    public func node(theme: ActionSheetControllerTheme) -> ActionSheetItemNode {
        let node = BotCheckoutPaymentMethodItemNode(theme: theme)
        node.setItem(self)
        return node
    }
    
    public func updateNode(_ node: ActionSheetItemNode) {
        guard let node = node as? BotCheckoutPaymentMethodItemNode else {
            assertionFailure()
            return
        }
        
        node.setItem(self)
        node.requestLayoutUpdate()
    }
}

public class BotCheckoutPaymentMethodItemNode: ActionSheetItemNode {
    private let defaultFont: UIFont
    
    private let theme: ActionSheetControllerTheme
    
    private var item: BotCheckoutPaymentMethodItem?
    
    private let button: HighlightTrackingButton
    private let titleNode: ASTextNode
    private let iconNode: ASImageNode
    private let checkNode: ASImageNode
    
    public override init(theme: ActionSheetControllerTheme) {
        self.theme = theme
        self.defaultFont = Font.regular(floor(theme.baseFontSize * 20.0 / 17.0))
        
        self.button = HighlightTrackingButton()
        
        self.titleNode = ASTextNode()
        self.titleNode.maximumNumberOfLines = 1
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.displaysAsynchronously = false
        
        self.iconNode = ASImageNode()
        self.iconNode.displaysAsynchronously = false
        self.iconNode.displayWithoutProcessing = true
        
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
        self.addSubnode(self.iconNode)
        self.addSubnode(self.checkNode)
        
        self.button.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.backgroundNode.backgroundColor = theme.itemHighlightedBackgroundColor
                } else {
                    UIView.animate(withDuration: 0.3, animations: {
                        strongSelf.backgroundNode.backgroundColor = theme.itemBackgroundColor
                    })
                }
            }
        }
        
        self.button.addTarget(self, action: #selector(self.buttonPressed), for: .touchUpInside)
    }
    
    func setItem(_ item: BotCheckoutPaymentMethodItem) {
        self.item = item
        
        self.titleNode.attributedText = NSAttributedString(string: item.title, font: self.defaultFont, textColor: self.theme.primaryTextColor)
        self.iconNode.image = item.icon
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
        
        let iconSize: CGSize
        if let image = self.iconNode.image {
            iconSize = image.size
        } else {
            iconSize = CGSize()
        }
        let titleSize = self.titleNode.measure(CGSize(width: size.width - 44.0 - iconSize.width - 15.0 - 8.0, height: size.height))
        self.titleNode.frame = CGRect(origin: CGPoint(x: checkInset, y: floorToScreenPixels((size.height - titleSize.height) / 2.0)), size: titleSize)
        self.iconNode.frame = CGRect(origin: CGPoint(x: size.width - 15.0 - iconSize.width, y: floorToScreenPixels((size.height - iconSize.height) / 2.0)), size: iconSize)
        
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
