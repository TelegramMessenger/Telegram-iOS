import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import AccountContext

public final class TabBarAccountSwitchController: ViewController {
    private var controllerNode: TabBarAccountSwitchControllerNode {
        return self.displayNode as! TabBarAccountSwitchControllerNode
    }
    
    private let _ready = Promise<Bool>(true)
    override public var ready: Promise<Bool> {
        return self._ready
    }
    
    private let sharedContext: SharedAccountContext
    private let accounts: (primary: (Account, Peer), other: [(Account, Peer, Int32)])
    private let canAddAccounts: Bool
    private let switchToAccount: (AccountRecordId) -> Void
    private let addAccount: () -> Void
    private let sourceNodes: [ASDisplayNode]
    
    private var presentationData: PresentationData
    private var didPlayPresentationAnimation = false
    private var changedAccount = false
    
    private let hapticFeedback = HapticFeedback()
    
    public init(sharedContext: SharedAccountContext, accounts: (primary: (Account, Peer), other: [(Account, Peer, Int32)]), canAddAccounts: Bool, switchToAccount: @escaping (AccountRecordId) -> Void, addAccount: @escaping () -> Void, sourceNodes: [ASDisplayNode]) {
        self.sharedContext = sharedContext
        self.accounts = accounts
        self.canAddAccounts = canAddAccounts
        self.switchToAccount = switchToAccount
        self.addAccount = addAccount
        self.sourceNodes = sourceNodes
        
        self.presentationData = sharedContext.currentPresentationData.with { $0 }
        
        super.init(navigationBarPresentationData: nil)
        
        self.statusBar.statusBarStyle = .Ignore
        self.statusBar.ignoreInCall = true
        
        self.lockOrientation = true
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
    }
    
    override public func loadDisplayNode() {
        self.displayNode = TabBarAccountSwitchControllerNode(sharedContext: self.sharedContext, accounts: self.accounts, presentationData: self.presentationData, canAddAccounts: self.canAddAccounts, switchToAccount: { [weak self] id in
            guard let strongSelf = self, !strongSelf.changedAccount else {
                return
            }
            strongSelf.changedAccount = true
            strongSelf.switchToAccount(id)
        }, addAccount: { [weak self] in
            guard let strongSelf = self, !strongSelf.changedAccount else {
                return
            }
            strongSelf.addAccount()
        }, cancel: { [weak self] in
            self?.dismiss()
        }, sourceNodes: self.sourceNodes)
        self.displayNodeDidLoad()
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !self.didPlayPresentationAnimation {
            self.didPlayPresentationAnimation = true
            
            self.hapticFeedback.impact()
            self.controllerNode.animateIn()
        }
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, transition: transition)
    }
    
    override public func dismiss(completion: (() -> Void)? = nil) {
        self.changedAccount = false
        self.dismiss(sourceNodes: [])
    }
    
    public func dismiss(sourceNodes: [ASDisplayNode]) {
        self.controllerNode.animateOut(sourceNodes: sourceNodes, changedAccount: self.changedAccount, completion: { [weak self] in
            self?.didPlayPresentationAnimation = false
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
        })
    }
}
