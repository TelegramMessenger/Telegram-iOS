import Foundation
import UIKit
import AsyncDisplayKit
import SwiftSignalKit
import Display
import TelegramCore
import TelegramPresentationData
import ProgressNavigationButtonNode
import AccountContext
import CountrySelectionUI

enum BotCheckoutNativeCardEntryStatus {
    case notReady
    case ready
    case verifying
}

struct BotCheckoutNativeCardEntryAdditionalFields: OptionSet {
    var rawValue: Int32
    
    init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    static let cardholderName = BotCheckoutNativeCardEntryAdditionalFields(rawValue: 1 << 0)
    static let country = BotCheckoutNativeCardEntryAdditionalFields(rawValue: 1 << 1)
    static let zipCode = BotCheckoutNativeCardEntryAdditionalFields(rawValue: 1 << 2)
}

final class BotCheckoutNativeCardEntryController: ViewController {
    enum Provider {
        case stripe(additionalFields: BotCheckoutNativeCardEntryAdditionalFields, publishableKey: String)
        case smartglobal(isTesting: Bool, publicToken: String)
    }

    private var controllerNode: BotCheckoutNativeCardEntryControllerNode {
        return super.displayNode as! BotCheckoutNativeCardEntryControllerNode
    }
    
    private let context: AccountContext
    private let provider: Provider
    private let completion: (BotCheckoutPaymentMethod) -> Void
    
    private var presentationData: PresentationData
    
    private var didPlayPresentationAnimation = false
    
    private var doneItem: UIBarButtonItem?
    private var activityItem: UIBarButtonItem?
    
    public init(context: AccountContext, provider: Provider, completion: @escaping (BotCheckoutPaymentMethod) -> Void) {
        self.context = context
        self.provider = provider
        self.completion = completion
        
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData))
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        
        self.doneItem = UIBarButtonItem(title: self.presentationData.strings.Common_Done, style: .done, target: self, action: #selector(self.donePressed))
        
        self.title = self.presentationData.strings.Checkout_NewCard_Title
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Cancel, style: .plain, target: self, action: #selector(self.cancelPressed))
        self.navigationItem.rightBarButtonItem = self.doneItem
        self.doneItem?.isEnabled = false
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func loadDisplayNode() {
        self.displayNode = BotCheckoutNativeCardEntryControllerNode(context: self.context, navigationBar: self.navigationBar, provider: self.provider, theme: self.presentationData.theme, strings: self.presentationData.strings, present: { [weak self] c, a in
            self?.present(c, in: .window(.root), with: a)
        }, dismiss: { [weak self] in
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
        }, openCountrySelection: { [weak self] in
            if let strongSelf = self {
                let controller = AuthorizationSequenceCountrySelectionController(strings: strongSelf.presentationData.strings, theme: strongSelf.presentationData.theme, displayCodes: false)
                controller.completeWithCountryCode = { _, id in
                    if let strongSelf = self {
                        strongSelf.controllerNode.updateCountry(id)
                    }
                }
                strongSelf.present(controller, in: .window(.root), with: ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
            }
        }, updateStatus: { [weak self] status in
            if let strongSelf = self {
                switch status {
                    case .notReady:
                        strongSelf.doneItem?.isEnabled = false
                    case .ready:
                        strongSelf.doneItem?.isEnabled = true
                    case .verifying:
                        break
                }
                switch status {
                    case .verifying:
                        if strongSelf.activityItem == nil {
                            strongSelf.activityItem = UIBarButtonItem(customDisplayNode: ProgressNavigationButtonNode(color: strongSelf.presentationData.theme.rootController.navigationBar.controlColor))
                            strongSelf.navigationItem.setRightBarButton(strongSelf.activityItem, animated: false)
                        }
                    default:
                        if strongSelf.activityItem != nil {
                            strongSelf.activityItem = nil
                            strongSelf.navigationItem.setRightBarButton(strongSelf.doneItem, animated: false)
                        }
                }
            }
        }, completion: { [weak self] method in
            self?.completion(method)
        })
        
        self.displayNodeDidLoad()
    }
    
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if let presentationArguments = self.presentationArguments as? ViewControllerPresentationArguments, !self.didPlayPresentationAnimation {
            self.didPlayPresentationAnimation = true
            if case .modalSheet = presentationArguments.presentationAnimation {
                self.controllerNode.animateIn()
            }
            
            self.controllerNode.activate()
        }
    }
    
    override public func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
    
    @objc func cancelPressed() {
        self.dismiss()
    }
    
    @objc private func donePressed() {
        self.controllerNode.verify()
    }
}
