import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import Stripe
import CountrySelectionUI
import PresentationDataUtils
import AccountContext

private final class BotCheckoutNativeCardEntryScrollerNodeView: UIScrollView {
    var ignoreUpdateBounds = false
    
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

private final class BotCheckoutNativeCardEntryScrollerNode: ASDisplayNode {
    override var view: BotCheckoutNativeCardEntryScrollerNodeView {
        return super.view as! BotCheckoutNativeCardEntryScrollerNodeView
    }
    
    override init() {
        super.init()
        
        self.setViewBlock({
            return BotCheckoutNativeCardEntryScrollerNodeView()
        })
    }
}

final class BotCheckoutNativeCardEntryControllerNode: ViewControllerTracingNode, UIScrollViewDelegate {
    private let context: AccountContext
    private weak var navigationBar: NavigationBar?
    private let provider: BotCheckoutNativeCardEntryController.Provider
    
    private let present: (ViewController, Any?) -> Void
    private let dismiss: () -> Void
    private let openCountrySelection: () -> Void
    private let updateStatus: (BotCheckoutNativeCardEntryStatus) -> Void
    private let completion: (BotCheckoutPaymentMethod) -> Void
    
    private var theme: PresentationTheme
    private var strings: PresentationStrings
    
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    
    private let scrollNode: BotCheckoutNativeCardEntryScrollerNode
    private let itemNodes: [[BotPaymentItemNode]]
    private let leftOverlayNode: ASDisplayNode
    private let rightOverlayNode: ASDisplayNode
    
    private let cardItem: BotPaymentCardInputItemNode
    private let cardholderItem: BotPaymentFieldItemNode?
    private let countryItem: BotPaymentDisclosureItemNode?
    private let zipCodeItem: BotPaymentFieldItemNode?
    
    private let saveInfoItem: BotPaymentSwitchItemNode
    
    private let verifyDisposable = MetaDisposable()
    private var isVerifying = false
    
    private var currentCardData: BotPaymentCardInputData?
    private var currentCountryIso2: String?

    private var dataTask: URLSessionDataTask?
    
    init(context: AccountContext, navigationBar: NavigationBar?, provider: BotCheckoutNativeCardEntryController.Provider, theme: PresentationTheme, strings: PresentationStrings, present: @escaping (ViewController, Any?) -> Void, dismiss: @escaping () -> Void, openCountrySelection: @escaping () -> Void, updateStatus: @escaping (BotCheckoutNativeCardEntryStatus) -> Void, completion: @escaping (BotCheckoutPaymentMethod) -> Void) {
        self.context = context
        self.navigationBar = navigationBar
        self.provider = provider
        
        self.present = present
        self.dismiss = dismiss
        self.openCountrySelection = openCountrySelection
        self.updateStatus = updateStatus
        self.completion = completion
        
        self.theme = theme
        self.strings = strings
        
        self.scrollNode = BotCheckoutNativeCardEntryScrollerNode()
        self.leftOverlayNode = ASDisplayNode()
        self.leftOverlayNode.isUserInteractionEnabled = false
        self.rightOverlayNode = ASDisplayNode()
        self.rightOverlayNode.isUserInteractionEnabled = false
        
        var itemNodes: [[BotPaymentItemNode]] = []
        
        var cardUpdatedImpl: ((BotPaymentCardInputData?) -> Void)?
        var openCountrySelectionImpl: (() -> Void)?
        
        self.cardItem = BotPaymentCardInputItemNode()
        self.cardItem.updated = { data in
            cardUpdatedImpl?(data)
        }
        itemNodes.append([BotPaymentHeaderItemNode(text: strings.Checkout_NewCard_PaymentCard), self.cardItem])

        switch provider {
        case let .stripe(additionalFields, _):
            if additionalFields.contains(.cardholderName) {
                var sectionItems: [BotPaymentItemNode] = []

                sectionItems.append(BotPaymentHeaderItemNode(text: strings.Checkout_NewCard_CardholderNameTitle))

                let cardholderItem = BotPaymentFieldItemNode(title: "", placeholder: strings.Checkout_NewCard_CardholderNamePlaceholder, contentType: .name)
                self.cardholderItem = cardholderItem
                sectionItems.append(cardholderItem)

                itemNodes.append(sectionItems)
            } else {
                self.cardholderItem = nil
            }

            if additionalFields.contains(.country) || additionalFields.contains(.zipCode) {
                var sectionItems: [BotPaymentItemNode] = []

                sectionItems.append(BotPaymentHeaderItemNode(text: strings.Checkout_NewCard_PostcodeTitle))

                if additionalFields.contains(.country) {
                    let countryItem = BotPaymentDisclosureItemNode(title: "", placeholder: strings.CheckoutInfo_ShippingInfoCountryPlaceholder, text: "")
                    countryItem.action = {
                        openCountrySelectionImpl?()
                    }
                    self.countryItem = countryItem
                    sectionItems.append(countryItem)
                } else {
                    self.countryItem = nil
                }
                if additionalFields.contains(.zipCode) {
                    let zipCodeItem = BotPaymentFieldItemNode(title: "", placeholder: strings.Checkout_NewCard_PostcodePlaceholder, contentType: .address)
                    self.zipCodeItem = zipCodeItem
                    sectionItems.append(zipCodeItem)
                } else {
                    self.zipCodeItem = nil
                }

                itemNodes.append(sectionItems)
            } else {
                self.countryItem = nil
                self.zipCodeItem = nil
            }
        case .smartglobal:
            self.cardholderItem = nil
            self.countryItem = nil
            self.zipCodeItem = nil
        }
        
        self.saveInfoItem = BotPaymentSwitchItemNode(title: strings.Checkout_NewCard_SaveInfo, isOn: false)
        itemNodes.append([self.saveInfoItem, BotPaymentTextItemNode(text: strings.Checkout_NewCard_SaveInfoHelp)])
        
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
        if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
            self.scrollNode.view.contentInsetAdjustmentBehavior = .never
        }
        self.scrollNode.view.alwaysBounceVertical = true
        self.scrollNode.view.showsVerticalScrollIndicator = false
        self.scrollNode.view.showsHorizontalScrollIndicator = false
        self.scrollNode.view.delegate = self
        
        self.addSubnode(self.scrollNode)
        
        cardUpdatedImpl = { [weak self] data in
            if let strongSelf = self {
                strongSelf.currentCardData = data
                strongSelf.updateDone()
            }
        }
        
        openCountrySelectionImpl = { [weak self] in
            if let strongSelf = self {
                strongSelf.view.endEditing(true)
                strongSelf.openCountrySelection()
            }
        }
        
        for items in itemNodes {
            for item in items {
                if let item = item as? BotPaymentFieldItemNode {
                    item.textUpdated = { [weak self] in
                        self?.updateDone()
                    }
                    item.returnPressed = { [weak self, weak item] in
                        guard let strongSelf = self, let item = item else {
                            return
                        }
                        var activateNext = true
                        outer: for section in strongSelf.itemNodes {
                            for i in 0 ..< section.count {
                                if section[i] === item {
                                    activateNext = true
                                } else if activateNext, let field = section[i] as? BotPaymentFieldItemNode {
                                    field.activateInput()
                                    break outer
                                }
                            }
                        }
                    }
                }
            }
        }
        
        self.cardItem.completed = { [weak self] in
            self?.cardholderItem?.activateInput()
        }
        
        self.updateDone()
    }
    
    deinit {
        self.verifyDisposable.dispose()
        self.dataTask?.cancel()
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.navigationBar?.updateBackgroundAlpha(0.0, transition: .immediate)
    }
    
    func updateCountry(_ iso2: String) {
        if let name = AuthorizationSequenceCountrySelectionController.lookupCountryNameById(iso2, strings: self.strings) {
            self.currentCountryIso2 = iso2
            self.countryItem?.text = name
            if let containerLayout = self.containerLayout {
                self.containerLayoutUpdated(containerLayout.0, navigationBarHeight: containerLayout.1, transition: .immediate)
            }
            
            self.updateDone()
        }
    }
    
    func verify() {
        guard let cardData = self.currentCardData else {
            return
        }

        switch self.provider {
        case let .stripe(_, publishableKey):
            let configuration = STPPaymentConfiguration.shared().copy() as! STPPaymentConfiguration
            configuration.smsAutofillDisabled = true
            configuration.publishableKey = publishableKey
            configuration.appleMerchantIdentifier = "merchant.ph.telegra.Telegraph"

            let apiClient = STPAPIClient(configuration: configuration)

            let card = STPCardParams()
            card.number = cardData.number
            card.cvc = cardData.code
            card.expYear = cardData.year
            card.expMonth = cardData.month
            card.name = self.cardholderItem?.text
            card.addressCountry = self.currentCountryIso2
            card.addressZip = self.zipCodeItem?.text

            let createToken: Signal<STPToken, Error> = Signal { subscriber in
                apiClient.createToken(withCard: card, completion: { token, error in
                    if let error = error {
                        subscriber.putError(error)
                    } else if let token = token {
                        subscriber.putNext(token)
                        subscriber.putCompletion()
                    }
                })

                return ActionDisposable {
                    let _ = apiClient.publishableKey
                }
            }

            self.isVerifying = true
            self.verifyDisposable.set((createToken |> deliverOnMainQueue).start(next: { [weak self] token in
                if let strongSelf = self, let card = token.card {
                    let last4 = card.last4()
                    let brand = STPAPIClient.string(with: card.brand)
                    strongSelf.completion(.webToken(BotCheckoutPaymentWebToken(title: "\(brand)*\(last4)", data: "{\"type\": \"card\", \"id\": \"\(token.tokenId)\"}", saveOnServer: strongSelf.saveInfoItem.isOn)))
                }
            }, error: { [weak self] error in
                if let strongSelf = self {
                    strongSelf.isVerifying = false
                    strongSelf.updateDone()
                }
            }))

            self.updateDone()
        case let .smartglobal(isTesting, publicToken):
            let url: String
            if isTesting {
                url = "https://tgb-playground.smart-glocal.com/cds/v1/tokenize/card"
            } else {
                url = "https://tgb.smart-glocal.com/cds/v1/tokenize/card"
            }

            let jsonPayload: [String: Any] = [
                "card": [
                    "number": cardData.number,
                    "expiration_month": String(format: "%02d", cardData.month),
                    "expiration_year": String(format: "%02d", cardData.year),
                    "security_code": "\(cardData.code)"
                ] as [String: Any]
            ]

            guard let parsedUrl = URL(string: url) else {
                return
            }

            var request = URLRequest(url: parsedUrl)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(publicToken, forHTTPHeaderField: "X-PUBLIC-TOKEN")
            guard let requestBody = try? JSONSerialization.data(withJSONObject: jsonPayload, options: []) else {
                return
            }
            request.httpBody = requestBody

            let session = URLSession.shared
            let dataTask = session.dataTask(with: request, completionHandler: { [weak self] data, response, error in
                Queue.mainQueue().async {
                    guard let strongSelf = self else {
                        return
                    }

                    enum ReponseError: Error {
                        case generic
                    }

                    do {
                        guard let data = data else {
                            throw ReponseError.generic
                        }

                        let jsonRaw = try JSONSerialization.jsonObject(with: data, options: [])
                        guard let json = jsonRaw as? [String: Any] else {
                            throw ReponseError.generic
                        }
                        guard let resultData = json["data"] as? [String: Any] else {
                            throw ReponseError.generic
                        }
                        guard let resultInfo = resultData["info"] as? [String: Any] else {
                            throw ReponseError.generic
                        }
                        guard let token = resultData["token"] as? String else {
                            throw ReponseError.generic
                        }
                        guard let maskedCardNumber = resultInfo["masked_card_number"] as? String else {
                            throw ReponseError.generic
                        }
                        guard let cardType = resultInfo["card_type"] as? String else {
                            throw ReponseError.generic
                        }

                        var last4 = maskedCardNumber
                        if last4.count > 4 {
                            let lastDigits = String(maskedCardNumber[maskedCardNumber.index(maskedCardNumber.endIndex, offsetBy: -4)...])
                            if lastDigits.allSatisfy(\.isNumber) {
                                last4 = "\(cardType) *\(lastDigits)"
                            }
                        }

                        let responseJson: [String: Any] = [
                            "type": "card",
                            "token": "\(token)"
                        ]

                        let serializedResponseJson = try JSONSerialization.data(withJSONObject: responseJson, options: [])

                        guard let serializedResponseString = String(data: serializedResponseJson, encoding: .utf8) else {
                            throw ReponseError.generic
                        }

                        strongSelf.completion(.webToken(BotCheckoutPaymentWebToken(
                            title: last4,
                            data: serializedResponseString,
                            saveOnServer: strongSelf.saveInfoItem.isOn
                        )))
                    } catch {
                        strongSelf.isVerifying = false
                        strongSelf.updateDone()

                        strongSelf.present(textAlertController(context: strongSelf.context, title: nil, text: strongSelf.strings.Login_UnknownError, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.strings.Common_OK, action: {
                        })]), nil)
                    }
                }
            })
            self.dataTask = dataTask

            self.isVerifying = true
            self.updateDone()

            dataTask.resume()

            break
        }
    }
    
    private func updateDone() {
        var enabled = true
        
        if self.currentCardData == nil {
            enabled = false
        }
        
        if let cardholderItem = self.cardholderItem, cardholderItem.text.isEmpty {
            enabled = false
        }
        
        if let _ = self.countryItem, self.currentCountryIso2 == nil {
            enabled = false
        }
        
        if let zipCodeItem = self.zipCodeItem, zipCodeItem.text.isEmpty {
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
        if self.scrollNode.frame != CGRect(origin: CGPoint(), size: layout.size) {
            transition.updateFrame(node: self.scrollNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        }
        if self.scrollNode.view.contentSize != scrollContentSize {
            self.scrollNode.view.contentSize = scrollContentSize
        }
        if self.scrollNode.view.contentInset != insets {
            self.scrollNode.view.contentInset = insets
        }
        if self.scrollNode.view.scrollIndicatorInsets != insets {
            self.scrollNode.view.scrollIndicatorInsets = insets
        }
        self.scrollNode.view.ignoreUpdateBounds = false
        
        if self.rightOverlayNode.supernode == nil {
            self.insertSubnode(self.rightOverlayNode, aboveSubnode: self.scrollNode)
        }
        if self.leftOverlayNode.supernode == nil {
            self.insertSubnode(self.leftOverlayNode, aboveSubnode: self.scrollNode)
        }
        
        self.leftOverlayNode.frame = CGRect(x: 0.0, y: 0.0, width: sideInset, height: layout.size.height)
        self.rightOverlayNode.frame = CGRect(x: layout.size.width - sideInset, y: 0.0, width: sideInset, height: layout.size.height)
        
        if let previousLayout = previousLayout {
            var previousInsets = previousLayout.0.insets(options: [.input])
            previousInsets.top += max(previousLayout.1, previousLayout.0.insets(options: [.statusBar]).top)
            let insetsScrollOffset = insets.top - previousInsets.top
            
            var contentOffset = CGPoint(x: 0.0, y: previousBoundsOrigin.y + insetsScrollOffset)
            contentOffset.y = min(contentOffset.y, scrollContentSize.height + insets.bottom - layout.size.height)
            //contentOffset.y = max(contentOffset.y, -insets.top)
            
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
    
    func activate() {
        self.cardItem.activateInput()
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard !self.scrollNode.view.ignoreUpdateBounds else {
            return
        }
        let value = scrollView.contentOffset.y + scrollView.contentInset.top
        self.navigationBar?.updateBackgroundAlpha(min(30.0, value) / 30.0, transition: .immediate)
    }
    
}
