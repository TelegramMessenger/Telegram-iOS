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
import AlertUI
import PresentationDataUtils
import ContactListUI
import CounterContollerTitleView

class ContactMultiselectionControllerImpl: ViewController, ContactMultiselectionController {
    private let context: AccountContext
    private let mode: ContactMultiselectionControllerMode
    
    private let titleView: CounterContollerTitleView
    
    private var contactsNode: ContactMultiselectionControllerNode {
        return self.displayNode as! ContactMultiselectionControllerNode
    }
    
    var dismissed: (() -> Void)?

    private let index: PeerNameIndex = .lastNameFirst
    
    private var _ready = Promise<Bool>()
    private var _limitsReady = Promise<Bool>()
    private var _listReady = Promise<Bool>()
    override var ready: Promise<Bool> {
        return self._ready
    }
    
    private let _result = Promise<[ContactListPeerId]>()
    var result: Signal<[ContactListPeerId], NoError> {
        return self._result.get()
    }
    
    private var rightNavigationButton: UIBarButtonItem?
    
    var displayProgress: Bool = false {
        didSet {
            if self.displayProgress != oldValue {
                if self.displayProgress {
                    let item = UIBarButtonItem(customDisplayNode: ProgressNavigationButtonNode(color: self.presentationData.theme.rootController.navigationBar.accentTextColor))
                    self.navigationItem.rightBarButtonItem = item
                } else {
                    self.navigationItem.rightBarButtonItem = self.rightNavigationButton
                }
            }
        }
    }
    
    private var didPlayPresentationAnimation = false
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    private var limitsConfiguration: LimitsConfiguration?
    private var limitsConfigurationDisposable: Disposable?
    private let options: [ContactListAdditionalOption]
    private let filters: [ContactListFilter]
    
    init(_ params: ContactMultiselectionControllerParams) {
        self.context = params.context
        self.mode = params.mode
        self.options = params.options
        self.filters = params.filters
        self.presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        
        self.titleView = CounterContollerTitleView(theme: self.presentationData.theme)
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData))
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        
        self.navigationItem.titleView = self.titleView
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        
        self.scrollToTop = { [weak self] in
            if let strongSelf = self {
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
        
        self.limitsConfigurationDisposable = (context.account.postbox.transaction { transaction -> LimitsConfiguration in
            return currentLimitsConfiguration(transaction: transaction)
        } |> deliverOnMainQueue).start(next: { [weak self] value in
            if let strongSelf = self {
                strongSelf.limitsConfiguration = value
                strongSelf.updateTitle()
                strongSelf._limitsReady.set(.single(true))
            }
        })
        
        self._ready.set(combineLatest(self._listReady.get(), self._limitsReady.get()) |> map { $0 && $1 })
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
        self.limitsConfigurationDisposable?.dispose()
    }
    
    private func updateThemeAndStrings() {
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        self.navigationBar?.updatePresentationData(NavigationBarPresentationData(presentationData: self.presentationData))
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        self.updateTitle()
    }
    
    private func updateTitle() {
        switch self.mode {
            case .groupCreation:
                let maxCount: Int32 = self.limitsConfiguration?.maxSupergroupMemberCount ?? 5000
                let count = self.contactsNode.contactListNode.selectionState?.selectedPeerIndices.count ?? 0
                self.titleView.title = CounterContollerTitle(title: self.presentationData.strings.Compose_NewGroupTitle, counter: "\(count)/\(maxCount)")
                let rightNavigationButton = UIBarButtonItem(title: self.presentationData.strings.Common_Next, style: .done, target: self, action: #selector(self.rightNavigationButtonPressed))
                self.rightNavigationButton = rightNavigationButton
                self.navigationItem.rightBarButtonItem = self.rightNavigationButton
                rightNavigationButton.isEnabled = count != 0
            case .channelCreation:
                self.titleView.title = CounterContollerTitle(title: self.presentationData.strings.GroupInfo_AddParticipantTitle, counter: "")
                let rightNavigationButton = UIBarButtonItem(title: self.presentationData.strings.Common_Next, style: .done, target: self, action: #selector(self.rightNavigationButtonPressed))
                self.rightNavigationButton = rightNavigationButton
                self.navigationItem.rightBarButtonItem = self.rightNavigationButton
                rightNavigationButton.isEnabled = true
            case .peerSelection:
                self.titleView.title = CounterContollerTitle(title: self.presentationData.strings.PrivacyLastSeenSettings_EmpryUsersPlaceholder, counter: "")
                let rightNavigationButton = UIBarButtonItem(title: self.presentationData.strings.Common_Done, style: .done, target: self, action: #selector(self.rightNavigationButtonPressed))
                self.rightNavigationButton = rightNavigationButton
                self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Cancel, style: .plain, target: self, action: #selector(cancelPressed))
                self.navigationItem.rightBarButtonItem = self.rightNavigationButton
                rightNavigationButton.isEnabled = false
        }
    }
    
    override func loadDisplayNode() {
        self.displayNode = ContactMultiselectionControllerNode(context: self.context, mode: self.mode, options: self.options, filters: filters)
        self._listReady.set(self.contactsNode.contactListNode.ready)
        
        self.contactsNode.dismiss = { [weak self] in
            self?.presentingViewController?.dismiss(animated: true, completion: nil)
        }
        
        self.contactsNode.openPeer = { [weak self] peer in
            if let strongSelf = self, case let .peer(peer, _, _) = peer {
                var updatedCount: Int?
                var addedToken: EditableTokenListToken?
                var removedTokenId: AnyHashable?
                
                let maxRegularCount: Int32 = strongSelf.limitsConfiguration?.maxGroupMemberCount ?? 200
                var displayCountAlert = false
                
                var selectionState: ContactListNodeGroupSelectionState?
                strongSelf.contactsNode.contactListNode.updateSelectionState { state in
                    if let state = state {
                        var updatedState = state.withToggledPeerId(.peer(peer.id))
                        if updatedState.selectedPeerIndices[.peer(peer.id)] == nil {
                            removedTokenId = peer.id
                        } else {
                            if updatedState.selectedPeerIndices.count >= maxRegularCount {
                                displayCountAlert = true
                                updatedState = updatedState.withToggledPeerId(.peer(peer.id))
                            } else {
                                addedToken = EditableTokenListToken(id: peer.id, title: peer.displayTitle(strings: strongSelf.presentationData.strings, displayOrder: strongSelf.presentationData.nameDisplayOrder))
                            }
                        }
                        updatedCount = updatedState.selectedPeerIndices.count
                        selectionState = updatedState
                        return updatedState
                    } else {
                        return nil
                    }
                }
                if let searchResultsNode = strongSelf.contactsNode.searchResultsNode {
                    searchResultsNode.updateSelectionState { _ in
                        return selectionState
                    }
                }
                
                if let updatedCount = updatedCount {
                    switch strongSelf.mode {
                        case .groupCreation, .peerSelection:
                            strongSelf.rightNavigationButton?.isEnabled = updatedCount != 0
                        case .channelCreation:
                            break
                    }
                    
                    switch strongSelf.mode {
                        case .groupCreation:
                            let maxCount: Int32 = strongSelf.limitsConfiguration?.maxSupergroupMemberCount ?? 5000
                            strongSelf.titleView.title = CounterContollerTitle(title: strongSelf.presentationData.strings.Compose_NewGroupTitle, counter: "\(updatedCount)/\(maxCount)")
                        case .peerSelection, .channelCreation:
                            break
                    }
                }
                
                if let addedToken = addedToken {
                    strongSelf.contactsNode.editableTokens.append(addedToken)
                } else if let removedTokenId = removedTokenId {
                    strongSelf.contactsNode.editableTokens = strongSelf.contactsNode.editableTokens.filter { token in
                        return token.id != removedTokenId
                    }
                }
                strongSelf.requestLayout(transition: ContainedViewLayoutTransition.animated(duration: 0.4, curve: .spring))
                
                if displayCountAlert {
                    strongSelf.present(textAlertController(context: strongSelf.context, title: nil, text: strongSelf.presentationData.strings.CreateGroup_SoftUserLimitAlert, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                }
            }
        }
        
        self.contactsNode.removeSelectedPeer = { [weak self] peerId in
            if let strongSelf = self {
                var updatedCount: Int?
                var removedTokenId: AnyHashable?
                
                var selectionState: ContactListNodeGroupSelectionState?
                strongSelf.contactsNode.contactListNode.updateSelectionState { state in
                    if let state = state {
                        let updatedState = state.withToggledPeerId(peerId)
                        if updatedState.selectedPeerIndices[peerId] == nil {
                            if case let .peer(peerId) = peerId {
                                removedTokenId = peerId
                            }
                        }
                        updatedCount = updatedState.selectedPeerIndices.count
                        selectionState = updatedState
                        return updatedState
                    } else {
                        return nil
                    }
                }
                if let searchResultsNode = strongSelf.contactsNode.searchResultsNode {
                    searchResultsNode.updateSelectionState { _ in
                        return selectionState
                    }
                }
                
                if let updatedCount = updatedCount {
                    switch strongSelf.mode {
                        case .groupCreation, .peerSelection:
                            strongSelf.rightNavigationButton?.isEnabled = updatedCount != 0
                        case .channelCreation:
                            break
                    }
                    switch strongSelf.mode {
                        case .groupCreation:
                            let maxCount: Int32 = strongSelf.limitsConfiguration?.maxSupergroupMemberCount ?? 5000
                            strongSelf.titleView.title = CounterContollerTitle(title: strongSelf.presentationData.strings.Compose_NewGroupTitle, counter: "\(updatedCount)/\(maxCount)")
                        case .peerSelection, .channelCreation:
                            break
                    }
                }
                
                if let removedTokenId = removedTokenId {
                    strongSelf.contactsNode.editableTokens = strongSelf.contactsNode.editableTokens.filter { token in
                        return token.id != removedTokenId
                    }
                }
                strongSelf.requestLayout(transition: ContainedViewLayoutTransition.animated(duration: 0.4, curve: .spring))
            }
        }
        
        self.displayNodeDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.contactsNode.contactListNode.enableUpdates = true
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if let presentationArguments = self.presentationArguments as? ViewControllerPresentationArguments, !self.didPlayPresentationAnimation {
            self.didPlayPresentationAnimation = true
            if case .modalSheet = presentationArguments.presentationAnimation {
                self.contactsNode.animateIn()
            }
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        self.contactsNode.contactListNode.enableUpdates = false
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.contactsNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, actualNavigationBarHeight: self.navigationHeight, transition: transition)
    }
    
    @objc func cancelPressed() {
        self._result.set(.single([]))
        self.dismiss()
    }
    
    @objc func rightNavigationButtonPressed() {
        var peerIds: [ContactListPeerId] = []
        self.contactsNode.contactListNode.updateSelectionState { state in
            if let state = state {
                peerIds = Array(state.selectedPeerIndices.keys)
            }
            return state
        }
        self._result.set(.single(peerIds))
    }
}
