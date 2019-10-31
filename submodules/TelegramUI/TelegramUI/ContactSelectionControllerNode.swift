import Display
import UIKit
import AsyncDisplayKit
import Postbox
import TelegramCore
import SyncCore
import SwiftSignalKit
import TelegramPresentationData
import AccountContext
import SearchBarNode
import ContactListUI
import SearchUI

final class ContactSelectionControllerNode: ASDisplayNode {
    var displayProgress: Bool = false {
        didSet {
            if self.displayProgress != oldValue {
                self.dimNode.alpha = self.displayProgress ? 1.0 : 0.0
                self.dimNode.isUserInteractionEnabled = self.displayProgress
            }
        }
    }
    
    let displayDeviceContacts: Bool
    
    let contactListNode: ContactListNode
    private let dimNode: ASDisplayNode
    
    private let context: AccountContext
    private var searchDisplayController: SearchDisplayController?
    
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    
    var navigationBar: NavigationBar?
    
    var requestDeactivateSearch: (() -> Void)?
    var requestOpenPeerFromSearch: ((ContactListPeer) -> Void)?
    var dismiss: (() -> Void)?
    
    var presentationData: PresentationData
    var presentationDataDisposable: Disposable?
    
    init(context: AccountContext, options: [ContactListAdditionalOption], displayDeviceContacts: Bool) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.displayDeviceContacts = displayDeviceContacts
        
        self.contactListNode = ContactListNode(context: context, presentation: .single(.natural(options: options, includeChatList: false)))
        
        self.dimNode = ASDisplayNode()
        
        super.init()
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        self.backgroundColor = self.presentationData.theme.chatList.backgroundColor
        
        self.addSubnode(self.contactListNode)
        
        self.presentationDataDisposable = (context.sharedContext.presentationData
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                let previousTheme = strongSelf.presentationData.theme
                strongSelf.presentationData = presentationData
                if previousTheme !== presentationData.theme {
                    strongSelf.updateTheme()
                }
            }
        })
        
        self.dimNode.backgroundColor = self.presentationData.theme.list.plainBackgroundColor.withAlphaComponent(0.5)
        self.dimNode.alpha = 0.0
        self.dimNode.isUserInteractionEnabled = false
        self.addSubnode(self.dimNode)
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
    }
    
    private func updateTheme() {
        self.backgroundColor = self.presentationData.theme.chatList.backgroundColor
        self.searchDisplayController?.updatePresentationData(presentationData)
        self.dimNode.backgroundColor = self.presentationData.theme.list.plainBackgroundColor.withAlphaComponent(0.5)
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, actualNavigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.containerLayout = (layout, navigationBarHeight)
        
        transition.updateFrame(node: self.dimNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        
        var insets = layout.insets(options: [.input])
        insets.top += navigationBarHeight
        
        var headerInsets = layout.insets(options: [.input])
        headerInsets.top += actualNavigationBarHeight
        
        if let searchDisplayController = self.searchDisplayController {
            searchDisplayController.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
        }
        
        self.contactListNode.containerLayoutUpdated(ContainerViewLayout(size: layout.size, metrics: layout.metrics, deviceMetrics: layout.deviceMetrics, intrinsicInsets: insets, safeInsets: layout.safeInsets, statusBarHeight: layout.statusBarHeight, inputHeight: layout.inputHeight, inputHeightIsInteractivellyChanging: layout.inputHeightIsInteractivellyChanging, inVoiceOver: layout.inVoiceOver), headerInsets: headerInsets, transition: transition)
        
        self.contactListNode.frame = CGRect(origin: CGPoint(), size: layout.size)
        
        if let searchDisplayController = self.searchDisplayController {
            searchDisplayController.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
        }
    }
    
    func activateSearch(placeholderNode: SearchBarPlaceholderNode) {
        guard let (containerLayout, navigationBarHeight) = self.containerLayout, let navigationBar = self.navigationBar, self.searchDisplayController == nil else {
            return
        }
        
        var categories: ContactsSearchCategories = [.cloudContacts]
        if self.displayDeviceContacts {
            categories.insert(.deviceContacts)
        } else {
            categories.insert(.global)
        }
        self.searchDisplayController = SearchDisplayController(presentationData: self.presentationData, contentNode: ContactsSearchContainerNode(context: self.context, onlyWriteable: false, categories: categories, openPeer: { [weak self] peer in
            self?.requestOpenPeerFromSearch?(peer)
        }, contextAction: nil), cancel: { [weak self] in
            if let requestDeactivateSearch = self?.requestDeactivateSearch {
                requestDeactivateSearch()
            }
        })
        
        self.searchDisplayController?.containerLayoutUpdated(containerLayout, navigationBarHeight: navigationBarHeight, transition: .immediate)
        self.searchDisplayController?.activate(insertSubnode: { [weak self, weak placeholderNode] subnode, isSearchBar in
            if let strongSelf = self, let strongPlaceholderNode = placeholderNode {
                if isSearchBar {
                    strongPlaceholderNode.supernode?.insertSubnode(subnode, aboveSubnode: strongPlaceholderNode)
                } else {
                    strongSelf.insertSubnode(subnode, belowSubnode: navigationBar)
                }
            }
        }, placeholder: placeholderNode)
    }
    
    func prepareDeactivateSearch() {
        self.searchDisplayController?.isDeactivating = true
    }
    
    func deactivateSearch(placeholderNode: SearchBarPlaceholderNode) {
        if let searchDisplayController = self.searchDisplayController {
            searchDisplayController.deactivate(placeholder: placeholderNode)
            self.searchDisplayController = nil
        }
    }
    
    func animateIn(completion: @escaping () -> Void) {
        self.layer.animatePosition(from: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), to: self.layer.position, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring, completion: { _ in
            completion()
        })
    }
    
    func animateOut(completion: (() -> Void)? = nil) {
        self.layer.animatePosition(from: self.layer.position, to: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), duration: 0.2, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, completion: { [weak self] _ in
            if let strongSelf = self {
                strongSelf.dismiss?()
            }
            completion?()
        })
    }
}
