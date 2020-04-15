import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import SwiftSignalKit
import TelegramCore
import SyncCore
import TelegramPresentationData
import ProgressNavigationButtonNode
import AccountContext
import ContactListUI
import SearchUI

class ContactSelectionControllerImpl: ViewController, ContactSelectionController, PresentableController {
    private let context: AccountContext
    private let autoDismiss: Bool
    
    private var contactsNode: ContactSelectionControllerNode {
        return self.displayNode as! ContactSelectionControllerNode
    }
    
    var displayProgress: Bool = false {
        didSet {
            if self.displayProgress != oldValue {
                if self.isNodeLoaded {
                    self.contactsNode.displayProgress = self.displayProgress
                }
            }
        }
    }
    
    private let index: PeerNameIndex = .lastNameFirst
    private let titleProducer: (PresentationStrings) -> String
    private let options: [ContactListAdditionalOption]
    private let displayDeviceContacts: Bool
    
    private var _ready = Promise<Bool>()
    override var ready: Promise<Bool> {
        return self._ready
    }
    
    private let _result = Promise<ContactListPeer?>()
    var result: Signal<ContactListPeer?, NoError> {
        return self._result.get()
    }
    
    private let confirmation: (ContactListPeer) -> Signal<Bool, NoError>
    var dismissed: (() -> Void)?
    
    private let createActionDisposable = MetaDisposable()
    private let confirmationDisposable = MetaDisposable()
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    private var searchContentNode: NavigationBarSearchContentNode?
    
    var displayNavigationActivity: Bool = false {
        didSet {
            if self.displayNavigationActivity != oldValue {
                if self.displayNavigationActivity {
                    self.navigationItem.setRightBarButton(UIBarButtonItem(customDisplayNode: ProgressNavigationButtonNode(color: self.presentationData.theme.rootController.navigationBar.accentTextColor)), animated: false)
                } else {
                    self.navigationItem.setRightBarButton(nil, animated: false)
                }
            }
        }
    }
    
    init(_ params: ContactSelectionControllerParams) {
        self.context = params.context
        self.autoDismiss = params.autoDismiss
        self.titleProducer = params.title
        self.options = params.options
        self.displayDeviceContacts = params.displayDeviceContacts
        self.confirmation = params.confirmation
        
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData))
        
        self.blocksBackgroundWhenInOverlay = true
        self.acceptsFocusWhenInOverlay = true
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        
        self.title = self.titleProducer(self.presentationData.strings)
        
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        
        self.scrollToTop = { [weak self] in
            if let strongSelf = self {
                if let searchContentNode = strongSelf.searchContentNode {
                    searchContentNode.updateExpansionProgress(1.0, animated: true)
                }
                strongSelf.contactsNode.contactListNode.scrollToTop()
            }
        }
        
        self.presentationDataDisposable = (context.sharedContext.presentationData
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                let previousTheme = strongSelf.presentationData.theme
                let previousStrings = strongSelf.presentationData.strings
                
                strongSelf.presentationData = presentationData
                
                if previousTheme !== presentationData.theme || previousStrings !== presentationData.strings {
                    strongSelf.updateThemeAndStrings()
                }
            }
        })
        
        self.searchContentNode = NavigationBarSearchContentNode(theme: self.presentationData.theme, placeholder: self.presentationData.strings.Common_Search, activate: { [weak self] in
            self?.activateSearch()
        })
        self.navigationBar?.setContentNode(self.searchContentNode, animated: false)
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.createActionDisposable.dispose()
        self.presentationDataDisposable?.dispose()
    }
    
    private func updateThemeAndStrings() {
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        self.navigationBar?.updatePresentationData(NavigationBarPresentationData(presentationData: self.presentationData))
        self.searchContentNode?.updateThemeAndPlaceholder(theme: self.presentationData.theme, placeholder: self.presentationData.strings.Common_Search)
        self.title = self.titleProducer(self.presentationData.strings)
        self.tabBarItem.title = self.presentationData.strings.Contacts_Title
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
    }
    
    @objc func cancelPressed() {
        self._result.set(.single(nil))
        
        self.dismiss()
    }
    
    override func loadDisplayNode() {
        self.displayNode = ContactSelectionControllerNode(context: self.context, options: self.options, displayDeviceContacts: self.displayDeviceContacts)
        self._ready.set(self.contactsNode.contactListNode.ready)
        
        self.contactsNode.navigationBar = self.navigationBar
        
        self.contactsNode.requestDeactivateSearch = { [weak self] in
            self?.deactivateSearch()
        }
        
        self.contactsNode.requestOpenPeerFromSearch = { [weak self] peer in
            self?.openPeer(peer: peer)
        }
        
        self.contactsNode.contactListNode.activateSearch = { [weak self] in
            self?.activateSearch()
        }
        
        self.contactsNode.contactListNode.openPeer = { [weak self] peer in
            self?.openPeer(peer: peer)
        }
        
        self.contactsNode.contactListNode.suppressPermissionWarning = { [weak self] in
            if let strongSelf = self {
                strongSelf.context.sharedContext.presentContactsWarningSuppression(context: strongSelf.context, present: { c, a in
                    strongSelf.present(c, in: .window(.root), with: a)
                })
            }
        }
        
        self.contactsNode.dismiss = { [weak self] in
            self?.presentingViewController?.dismiss(animated: true, completion: nil)
        }
        
        self.contactsNode.contactListNode.contentOffsetChanged = { [weak self] offset in
            if let strongSelf = self, let searchContentNode = strongSelf.searchContentNode {
                searchContentNode.updateListVisibleContentOffset(offset)
            }
        }
        
        self.contactsNode.contactListNode.contentScrollingEnded = { [weak self] listView in
            if let strongSelf = self, let searchContentNode = strongSelf.searchContentNode {
                return fixNavigationSearchableListNodeScrolling(listView, searchNode: searchContentNode)
            } else {
                return false
            }
        }
        
        self.displayNodeDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if let presentationArguments = self.presentationArguments as? ViewControllerPresentationArguments {
            switch presentationArguments.presentationAnimation {
                case .modalSheet:
                    self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Cancel, style: .plain, target: self, action: #selector(cancelPressed))
                case .none:
                    break
            }
        }
        
        self.contactsNode.contactListNode.enableUpdates = true
    }
    
    func viewDidAppear(completion: @escaping () -> Void) {
        if let presentationArguments = self.presentationArguments as? ViewControllerPresentationArguments {
            switch presentationArguments.presentationAnimation {
                case .modalSheet:
                    self.contactsNode.animateIn(completion: completion)
                case .none:
                    break
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.viewDidAppear(completion: {})
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        self.contactsNode.contactListNode.enableUpdates = false
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.contactsNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationInsetHeight, actualNavigationBarHeight: self.navigationHeight,  transition: transition)
    }
    
    private func activateSearch() {
        if self.displayNavigationBar {
            if let searchContentNode = self.searchContentNode {
                self.contactsNode.activateSearch(placeholderNode: searchContentNode.placeholderNode)
            }
            self.setDisplayNavigationBar(false, transition: .animated(duration: 0.5, curve: .spring))
        }
    }
    
    private func deactivateSearch() {
        if !self.displayNavigationBar {
            self.contactsNode.prepareDeactivateSearch()
            self.setDisplayNavigationBar(true, transition: .animated(duration: 0.5, curve: .spring))
            if let searchContentNode = self.searchContentNode {
                self.contactsNode.deactivateSearch(placeholderNode: searchContentNode.placeholderNode)
            }
        }
    }
    
    private func openPeer(peer: ContactListPeer) {
        self.contactsNode.contactListNode.listNode.clearHighlightAnimated(true)
        self.confirmationDisposable.set((self.confirmation(peer) |> deliverOnMainQueue).start(next: { [weak self] value in
            if let strongSelf = self {
                if value {
                    strongSelf._result.set(.single(peer))
                    if strongSelf.autoDismiss {
                        strongSelf.dismiss()
                    }
                }
            }
        }))
    }
    
    func dismissSearch() {
        self.deactivateSearch()
    }
}
