import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import AccountContext
import AlertUI
import PresentationDataUtils
import CountrySelectionUI

private final class BotCheckoutInfoAddressItems {
    let address1: BotPaymentFieldItemNode
    let address2: BotPaymentFieldItemNode
    let city: BotPaymentFieldItemNode
    let state: BotPaymentFieldItemNode
    let country: BotPaymentDisclosureItemNode
    let postcode: BotPaymentFieldItemNode
    
    var items: [BotPaymentItemNode] {
        return [
            self.address1,
            self.address2,
            self.city,
            self.state,
            self.country,
            self.postcode
        ]
    }
    
    init(strings: PresentationStrings, openCountrySelection: @escaping () -> Void) {
        self.address1 = BotPaymentFieldItemNode(title: strings.CheckoutInfo_ShippingInfoAddress1, placeholder: strings.CheckoutInfo_ShippingInfoAddress1Placeholder, contentType: .address)
        self.address2 = BotPaymentFieldItemNode(title: strings.CheckoutInfo_ShippingInfoAddress2, placeholder: strings.CheckoutInfo_ShippingInfoAddress2Placeholder, contentType: .address)
        self.city = BotPaymentFieldItemNode(title: strings.CheckoutInfo_ShippingInfoCity, placeholder: strings.CheckoutInfo_ShippingInfoCityPlaceholder, contentType: .address)
        self.state = BotPaymentFieldItemNode(title: strings.CheckoutInfo_ShippingInfoState, placeholder: strings.CheckoutInfo_ShippingInfoStatePlaceholder, contentType: .address)
        self.country = BotPaymentDisclosureItemNode(title: strings.CheckoutInfo_ShippingInfoCountry, placeholder: strings.CheckoutInfo_ShippingInfoCountryPlaceholder, text: "")
        self.postcode = BotPaymentFieldItemNode(title: strings.CheckoutInfo_ShippingInfoPostcode, placeholder: strings.CheckoutInfo_ShippingInfoPostcodePlaceholder, contentType: .address)
        
        self.country.action = {
            openCountrySelection()
        }
    }
}

private final class BotCheckoutInfoControllerScrollerNodeView: UIScrollView {
    var ignoreUpdateBounds = false
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
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

private final class BotCheckoutInfoControllerScrollerNode: ASDisplayNode {
    override var view: BotCheckoutInfoControllerScrollerNodeView {
        return super.view as! BotCheckoutInfoControllerScrollerNodeView
    }
    
    override init() {
        super.init()
        
        self.setViewBlock({
            return BotCheckoutInfoControllerScrollerNodeView(frame: CGRect())
        })
    }
}

enum BotCheckoutInfoControllerStatus {
    case notReady
    case ready
    case verifying
}

final class BotCheckoutInfoControllerNode: ViewControllerTracingNode, UIScrollViewDelegate {
    private let context: AccountContext
    private weak var navigationBar: NavigationBar?
    private let invoice: BotPaymentInvoice
    private let messageId: EngineMessage.Id
    private var focus: BotCheckoutInfoControllerFocus?
    
    private let dismiss: () -> Void
    private let openCountrySelection: () -> Void
    private let updateStatus: (BotCheckoutInfoControllerStatus) -> Void
    private let formInfoUpdated: (BotPaymentRequestedInfo, BotPaymentValidatedFormInfo) -> Void
    private let present: (ViewController, Any?) -> Void
    
    private var theme: PresentationTheme
    private var strings: PresentationStrings
    
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    
    private let scrollNode: BotCheckoutInfoControllerScrollerNode
    private let itemNodes: [[BotPaymentItemNode]]
    private let leftOverlayNode: ASDisplayNode
    private let rightOverlayNode: ASDisplayNode
    
    private let addressItems: BotCheckoutInfoAddressItems?
    private let nameItem: BotPaymentFieldItemNode?
    private let emailItem: BotPaymentFieldItemNode?
    private let phoneItem: BotPaymentFieldItemNode?
    private let saveInfoItem: BotPaymentSwitchItemNode
    
    private var formInfo: BotPaymentRequestedInfo
    
    private let verifyDisposable = MetaDisposable()
    private var isVerifying = false
    
    init(
        context: AccountContext,
        navigationBar: NavigationBar?,
        invoice: BotPaymentInvoice,
        messageId: EngineMessage.Id,
        formInfo: BotPaymentRequestedInfo,
        focus: BotCheckoutInfoControllerFocus,
        theme: PresentationTheme,
        strings: PresentationStrings,
        dismiss: @escaping () -> Void,
        openCountrySelection: @escaping () -> Void,
        updateStatus: @escaping (BotCheckoutInfoControllerStatus) -> Void,
        formInfoUpdated: @escaping (BotPaymentRequestedInfo, BotPaymentValidatedFormInfo) -> Void,
        present: @escaping (ViewController, Any?) -> Void
    ) {
        self.context = context
        self.navigationBar = navigationBar
        self.invoice = invoice
        self.messageId = messageId
        self.formInfo = formInfo
        self.focus = focus
        self.dismiss = dismiss
        self.openCountrySelection = openCountrySelection
        self.updateStatus = updateStatus
        self.formInfoUpdated = formInfoUpdated
        self.present = present
        
        self.theme = theme
        self.strings = strings
        
        self.scrollNode = BotCheckoutInfoControllerScrollerNode()
        self.leftOverlayNode = ASDisplayNode()
        self.leftOverlayNode.isUserInteractionEnabled = false
        self.rightOverlayNode = ASDisplayNode()
        self.rightOverlayNode.isUserInteractionEnabled = false
        
        var itemNodes: [[BotPaymentItemNode]] = []
        
        var openCountrySelectionImpl: (() -> Void)?
        
        if invoice.requestedFields.contains(.shippingAddress) {
            var sectionItems: [BotPaymentItemNode] = []
            let addressItems = BotCheckoutInfoAddressItems(strings: strings, openCountrySelection: { openCountrySelectionImpl?()
            })
            
            addressItems.address1.text = formInfo.shippingAddress?.streetLine1 ?? ""
            addressItems.address2.text = formInfo.shippingAddress?.streetLine2 ?? ""
            addressItems.city.text = formInfo.shippingAddress?.city ?? ""
            addressItems.state.text = formInfo.shippingAddress?.state ?? ""
            if let iso2 = formInfo.shippingAddress?.countryIso2, let name = AuthorizationSequenceCountrySelectionController.lookupCountryNameById(iso2.uppercased(), strings: self.strings) {
                addressItems.country.text = name
            }
            addressItems.postcode.text = formInfo.shippingAddress?.postCode ?? ""
            
            sectionItems.append(BotPaymentHeaderItemNode(text: strings.CheckoutInfo_ShippingInfoTitle))
            sectionItems.append(contentsOf: addressItems.items)
            itemNodes.append(sectionItems)
            self.addressItems = addressItems
        } else {
            self.addressItems = nil
        }
        
        if !invoice.requestedFields.intersection([.name, .phone, .email]).isEmpty {
            var sectionItems: [BotPaymentItemNode] = []
            sectionItems.append(BotPaymentHeaderItemNode(text: strings.CheckoutInfo_ReceiverInfoTitle))
            if invoice.requestedFields.contains(.name) {
                let nameItem = BotPaymentFieldItemNode(title: strings.CheckoutInfo_ReceiverInfoName, placeholder: strings.CheckoutInfo_ReceiverInfoNamePlaceholder, contentType: .name)
                nameItem.text = formInfo.name ?? ""
                self.nameItem = nameItem
                sectionItems.append(nameItem)
            } else {
                self.nameItem = nil
            }
            if invoice.requestedFields.contains(.email) {
                let emailItem = BotPaymentFieldItemNode(title: strings.CheckoutInfo_ReceiverInfoEmail, placeholder: strings.CheckoutInfo_ReceiverInfoEmailPlaceholder, contentType: .email)
                emailItem.text = formInfo.email ?? ""
                self.emailItem = emailItem
                sectionItems.append(emailItem)
            } else {
                self.emailItem = nil
            }
            if invoice.requestedFields.contains(.phone) {
                let phoneItem = BotPaymentFieldItemNode(title: strings.CheckoutInfo_ReceiverInfoPhone, placeholder: strings.CheckoutInfo_ReceiverInfoPhone, contentType: .phoneNumber)
                phoneItem.text = formInfo.phone ?? ""
                self.phoneItem = phoneItem
                sectionItems.append(phoneItem)
            } else {
                self.phoneItem = nil
            }
            itemNodes.append(sectionItems)
        } else {
            self.nameItem = nil
            self.emailItem = nil
            self.phoneItem = nil
        }
        
        self.saveInfoItem = BotPaymentSwitchItemNode(title: strings.CheckoutInfo_SaveInfo, isOn: true)
        itemNodes.append([self.saveInfoItem, BotPaymentTextItemNode(text: strings.CheckoutInfo_SaveInfoHelp)])
        
        self.itemNodes = itemNodes
        
        for items in itemNodes {
            for item in items {
                self.scrollNode.addSubnode(item)
            }
        }
        
        super.init()
        
        self.backgroundColor = self.theme.list.blocksBackgroundColor
        self.leftOverlayNode.backgroundColor = self.theme.list.blocksBackgroundColor
        self.rightOverlayNode.backgroundColor = self.theme.list.blocksBackgroundColor
        
        self.scrollNode.backgroundColor = nil
        self.scrollNode.isOpaque = false
        self.scrollNode.view.alwaysBounceVertical = true
        self.scrollNode.view.showsVerticalScrollIndicator = false
        self.scrollNode.view.showsHorizontalScrollIndicator = false
        self.scrollNode.view.delegate = self
        
        self.addSubnode(self.scrollNode)
        
        openCountrySelectionImpl = { [weak self] in
            if let strongSelf = self {
                strongSelf.view.endEditing(true)
                strongSelf.openCountrySelection()
            }
        }
        
        let fieldsAndTypes = { [weak self] () -> [(BotPaymentFieldItemNode, BotCheckoutInfoControllerFocus)] in
            guard let strongSelf = self else {
                return []
            }
            var fieldsAndTypes: [(BotPaymentFieldItemNode, BotCheckoutInfoControllerFocus)] = []
            if let addressItems = strongSelf.addressItems {
                fieldsAndTypes.append((addressItems.address1, .address(.street1)))
                fieldsAndTypes.append((addressItems.address2, .address(.street2)))
                fieldsAndTypes.append((addressItems.city, .address(.city)))
                fieldsAndTypes.append((addressItems.state, .address(.state)))
                fieldsAndTypes.append((addressItems.postcode, .address(.postcode)))
            }
            if let nameItem = strongSelf.nameItem {
                fieldsAndTypes.append((nameItem, .name))
            }
            if let phoneItem = strongSelf.phoneItem {
                fieldsAndTypes.append((phoneItem, .phone))
            }
            if let emailItem = strongSelf.emailItem {
                fieldsAndTypes.append((emailItem, .email))
            }
            return fieldsAndTypes
        }
        
        for items in itemNodes {
            for item in items {
                if let item = item as? BotPaymentFieldItemNode {
                    item.focused = { [weak self, weak item] in
                        guard let strongSelf = self, let item = item else {
                            return
                        }
                        for (node, focus) in fieldsAndTypes() {
                            if node === item {
                                strongSelf.focus = focus
                                break
                            }
                        }
                    }
                    item.textUpdated = { [weak self] in
                        self?.updateDone()
                    }
                    item.returnPressed = { [weak self, weak item] in
                        guard let strongSelf = self, let item = item else {
                            return
                        }
                        
                        var activateNext = false
                        outer: for section in strongSelf.itemNodes {
                            for i in 0 ..< section.count {
                                if section[i] === item {
                                    activateNext = true
                                } else if activateNext, let field = section[i] as? BotPaymentFieldItemNode {
                                    for (node, focus) in fieldsAndTypes() {
                                        if node === field {
                                            strongSelf.focus = focus
                                            if let containerLayout = strongSelf.containerLayout {
                                                strongSelf.containerLayoutUpdated(containerLayout.0, navigationBarHeight: containerLayout.1, transition: .immediate)
                                            }
                                            break outer
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        
        self.updateDone()
    }
    
    deinit {
        self.verifyDisposable.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.navigationBar?.updateBackgroundAlpha(0.0, transition: .immediate)
    }
    
    func updateCountry(_ iso2: String) {
        if self.formInfo.shippingAddress?.countryIso2 != iso2, let name = AuthorizationSequenceCountrySelectionController.lookupCountryNameById(iso2, strings: self.strings) {
            let shippingAddress: BotPaymentShippingAddress
            if let current = self.formInfo.shippingAddress {
                shippingAddress = current
            } else {
                shippingAddress = BotPaymentShippingAddress(streetLine1: "", streetLine2: "", city: "", state: "", countryIso2: iso2, postCode: "")
            }
                
            self.formInfo = BotPaymentRequestedInfo(name: self.formInfo.name, phone: self.formInfo.phone, email: self.formInfo.email, shippingAddress: BotPaymentShippingAddress(streetLine1: shippingAddress.streetLine1, streetLine2: shippingAddress.streetLine2, city: shippingAddress.city, state: shippingAddress.state, countryIso2: iso2, postCode: shippingAddress.postCode))
            self.addressItems?.country.text = name
            if let containerLayout = self.containerLayout {
                self.containerLayoutUpdated(containerLayout.0, navigationBarHeight: containerLayout.1, transition: .immediate)
            }
            
            self.updateDone()
        }
    }
    
    private func collectFormInfo() -> BotPaymentRequestedInfo {
        var address: BotPaymentShippingAddress?
        if let addressItems = self.addressItems, let current = self.formInfo.shippingAddress {
            address = BotPaymentShippingAddress(streetLine1: addressItems.address1.text, streetLine2: addressItems.address2.text, city: addressItems.city.text, state: addressItems.state.text, countryIso2: current.countryIso2, postCode: addressItems.postcode.text)
        }
        return BotPaymentRequestedInfo(name: self.nameItem?.text, phone: self.phoneItem?.text, email: self.emailItem?.text, shippingAddress: address)
    }
    
    func verify() {
        self.isVerifying = true
        let formInfo = self.collectFormInfo()
        self.verifyDisposable.set((self.context.engine.payments.validateBotPaymentForm(saveInfo: self.saveInfoItem.isOn, messageId: self.messageId, formInfo: formInfo) |> deliverOnMainQueue).start(next: { [weak self] result in
            if let strongSelf = self {
                strongSelf.formInfoUpdated(formInfo, result)
            }
        }, error: { [weak self] error in
            if let strongSelf = self {
                strongSelf.isVerifying = false
                strongSelf.updateDone()
                
                let text: String
                switch error {
                    case .shippingNotAvailable:
                        text = strongSelf.strings.CheckoutInfo_ErrorShippingNotAvailable
                    case .addressStateInvalid:
                        text = strongSelf.strings.CheckoutInfo_ErrorStateInvalid
                    case .addressPostcodeInvalid:
                        text = strongSelf.strings.CheckoutInfo_ErrorPostcodeInvalid
                    case .addressCityInvalid:
                        text = strongSelf.strings.CheckoutInfo_ErrorCityInvalid
                    case .nameInvalid:
                        text = strongSelf.strings.CheckoutInfo_ErrorNameInvalid
                    case .emailInvalid:
                        text = strongSelf.strings.CheckoutInfo_ErrorEmailInvalid
                    case .phoneInvalid:
                        text = strongSelf.strings.CheckoutInfo_ErrorPhoneInvalid
                    case .generic:
                        text = strongSelf.strings.Login_UnknownError
                }
                
                strongSelf.present(textAlertController(context: strongSelf.context, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.strings.Common_OK, action: {})]), nil)
            }
        }))
        
        self.updateDone()
    }
    
    private func updateDone() {
        var enabled = true
        if let addressItems = self.addressItems {
            if addressItems.address1.text.isEmpty {
                enabled = false
            }
            if addressItems.city.text.isEmpty {
                enabled = false
            }
            if let shippingAddress = self.formInfo.shippingAddress, shippingAddress.countryIso2.isEmpty {
                enabled = false
            }
            if addressItems.postcode.text.isEmpty {
                enabled = false
            }
        }
        if let nameItem = self.nameItem, nameItem.text.isEmpty {
            enabled = false
        }
        if let phoneItem = self.phoneItem, phoneItem.text.isEmpty {
            enabled = false
        }
        if let emailItem = self.emailItem, emailItem.text.isEmpty {
            enabled = false
        }
        if self.isVerifying {
            self.updateStatus(.verifying)
        } else if enabled {
            self.updateStatus(.ready)
        } else {
            self.updateStatus(.notReady)
        }
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
        
        let inset = max(16.0, floor((layout.size.width - 674.0) / 2.0))
        var sideInset: CGFloat = 0.0
        if layout.size.width >= 375.0 {
            sideInset = inset
        }
        
        for items in self.itemNodes {
            if !items.isEmpty && items[0] is BotPaymentHeaderItemNode {
                contentHeight += 24.0
            } else {
                contentHeight += 32.0
            }
            
            for i in 0 ..< items.count {
                let item = items[i]
                let itemHeight = item.updateLayout(theme: self.theme, width: layout.size.width, sideInset: sideInset, measuredInset: commonInset, previousItemNode: i == 0 ? nil : items[i - 1], nextItemNode: i == (items.count - 1) ? nil : items[i + 1], transition: transition)
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
        
        if self.rightOverlayNode.supernode == nil {
            self.insertSubnode(self.rightOverlayNode, aboveSubnode: self.scrollNode)
        }
        if self.leftOverlayNode.supernode == nil {
            self.insertSubnode(self.leftOverlayNode, aboveSubnode: self.scrollNode)
        }
        
        self.leftOverlayNode.frame = CGRect(x: 0.0, y: 0.0, width: sideInset, height: layout.size.height)
        self.rightOverlayNode.frame = CGRect(x: layout.size.width - sideInset, y: 0.0, width: sideInset, height: layout.size.height)
        
        if let focus = self.focus {
            var focusItem: ASDisplayNode?
            switch focus {
                case let .address(field):
                    switch field {
                        case .street1:
                            focusItem = self.addressItems?.address1
                        case .street2:
                            focusItem = self.addressItems?.address2
                        case .city:
                            focusItem = self.addressItems?.city
                        case .state:
                            focusItem = self.addressItems?.state
                        case .postcode:
                            focusItem = self.addressItems?.postcode
                    }
                case .name:
                    focusItem = self.nameItem
                case .email:
                    focusItem = self.emailItem
                case .phone:
                    focusItem = self.phoneItem
            }
            if let focusItem = focusItem {
                let scrollVisibleSize = CGSize(width: layout.size.width, height: layout.size.height - insets.top - insets.bottom)
                var contentOffset = CGPoint(x: 0.0, y: -insets.top + floor(focusItem.frame.midY - scrollVisibleSize.height / 2.0))
                contentOffset.y = min(contentOffset.y, scrollContentSize.height + insets.bottom - layout.size.height)
                contentOffset.y = max(contentOffset.y, -insets.top)
                transition.updateBounds(node: self.scrollNode, bounds: CGRect(origin: CGPoint(x: 0.0, y: contentOffset.y), size: layout.size))
                
                if let focusItem = focusItem as? BotPaymentFieldItemNode {
                    focusItem.activateInput()
                }
                
                self.scrollViewDidScroll(self.scrollNode.view)
            }
        } else if let previousLayout = previousLayout {
            var previousInsets = previousLayout.0.insets(options: [.input])
            previousInsets.top += max(previousLayout.1, previousLayout.0.insets(options: [.statusBar]).top)
            let insetsScrollOffset = insets.top - previousInsets.top
            
            var contentOffset = CGPoint(x: 0.0, y: previousBoundsOrigin.y + insetsScrollOffset)
            contentOffset.y = min(contentOffset.y, scrollContentSize.height + insets.bottom - layout.size.height)
            contentOffset.y = max(contentOffset.y, -insets.top)
            
            //transition.updateBounds(node: self.scrollNode, bounds: CGRect(origin: CGPoint(x: 0.0, y: contentOffset.y), size: layout.size))
        } else {
            let contentOffset = CGPoint(x: 0.0, y: -insets.top)
            transition.updateBounds(node: self.scrollNode, bounds: CGRect(origin: CGPoint(x: 0.0, y: contentOffset.y), size: layout.size))
        }
    }
    
    func animateIn() {
        self.layer.animatePosition(from: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), to: self.layer.position, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring)
    }
    
    func animateOut(completion: (() -> Void)? = nil) {
        self.layer.animatePosition(from: self.layer.position, to: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), duration: 0.2, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, completion: { [weak self] _ in
            if let strongSelf = self {
                strongSelf.dismiss()
            }
            completion?()
        })
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard !self.scrollNode.view.ignoreUpdateBounds else {
            return
        }
        let value = scrollView.contentOffset.y + scrollView.contentInset.top
        self.navigationBar?.updateBackgroundAlpha(min(30.0, value) / 30.0, transition: .immediate)
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        self.focus = nil
    }
}
