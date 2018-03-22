import Foundation
import Display
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore

final class SecureIdIdentityFormController: ViewController {
    private var controllerNode: SecureIdIdentityFormControllerNode {
        return self.displayNode as! SecureIdIdentityFormControllerNode
    }
    
    private let account: Account
    private var presentationData: PresentationData
    
    private var data: SecureIdIdentityData?
    
    private var didPlayPresentationAnimation = false
    
    init(account: Account, data: SecureIdIdentityData?) {
        self.account = account
        self.presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        self.data = data
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData))
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBar.style.style
        
        self.title = self.presentationData.strings.SecureId_Title
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Cancel, style: .plain, target: self, action: #selector(self.cancelPressed))
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !self.didPlayPresentationAnimation {
            self.didPlayPresentationAnimation = true
            self.controllerNode.animateIn()
        }
    }
    
    override func dismiss(completion: (() -> Void)? = nil) {
        self.controllerNode.animateOut(completion: { [weak self] in
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
            completion?()
        })
    }
    
    override func loadDisplayNode() {
        self.displayNode = SecureIdIdentityFormControllerNode(account: self.account, data: self.data, theme: self.presentationData.theme, strings: self.presentationData.strings, dismiss: { [weak self] in
            self?.dismiss()
        }, present: { [weak self] c, a in
            self?.present(c, in: .window(.root), with: a)
        })
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition)
    }
    
    @objc private func cancelPressed() {
        self.dismiss()
    }
}
