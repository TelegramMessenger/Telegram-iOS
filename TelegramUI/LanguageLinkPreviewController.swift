import Foundation
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit

public final class LanguageLinkPreviewController: ViewController {
    private var controllerNode: LanguageLinkPreviewControllerNode {
        return self.displayNode as! LanguageLinkPreviewControllerNode
    }
    
    private var animatedIn = false
    
    private let account: Account
    private let identifier: String
    private var localizationInfo: LocalizationInfo?
    private var presentationData: PresentationData
    
    private let disposable = MetaDisposable()
    
    public init(account: Account, identifier: String) {
        self.account = account
        self.identifier = identifier
        
        self.presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        
        super.init(navigationBarPresentationData: nil)
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.disposable.dispose()
    }
    
    override public func loadDisplayNode() {
        self.displayNode = LanguageLinkPreviewControllerNode(account: self.account, requestLayout: { [weak self] transition in
            self?.requestLayout(transition: transition)
        }, openUrl: { [weak self] url in
            guard let strongSelf = self else {
                return
            }
            openExternalUrl(account: strongSelf.account, url: url, presentationData: strongSelf.presentationData, applicationContext: strongSelf.account.telegramApplicationContext, navigationController: nil, dismissInput: {
            })
        })
        self.controllerNode.dismiss = { [weak self] in
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
        }
        self.controllerNode.cancel = { [weak self] in
            self?.dismiss()
        }
        self.controllerNode.activate = { [weak self] in
            self?.activate()
        }
        self.displayNodeDidLoad()
        
        self.disposable.set((requestLocalizationPreview(postbox: self.account.postbox, network: self.account.network, identifier: self.identifier)
        |> deliverOnMainQueue).start(next: { [weak self] result in
            guard let strongSelf = self else {
                return
            }
            strongSelf.localizationInfo = result
            strongSelf.controllerNode.setData(localizationInfo: result)
        }, error: { [weak self] _ in
            self?.dismiss()
        }))
        self.ready.set(self.controllerNode.ready.get())
    }
    
    override public func loadView() {
        super.loadView()
        
        self.statusBar.removeFromSupernode()
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !self.animatedIn {
            self.animatedIn = true
            self.controllerNode.animateIn()
        }
    }
    
    override public func dismiss(completion: (() -> Void)? = nil) {
        self.controllerNode.animateOut(completion: completion)
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition)
    }
    
    private func activate() {
        guard let localizationInfo = self.localizationInfo else {
            return
        }
        self.controllerNode.setInProgress(true)
        self.disposable.set((downoadAndApplyLocalization(postbox: self.account.postbox, network: self.account.network, languageCode: localizationInfo.languageCode)
        |> deliverOnMainQueue).start(error: { [weak self] _ in
            guard let strongSelf = self else {
                return
            }
            strongSelf.controllerNode.setInProgress(false)
            strongSelf.present(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: strongSelf.presentationData.theme), title: nil, text: strongSelf.presentationData.strings.Login_UnknownError, actions: [TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: {})]), in: .window(.root))
        }, completed: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.controllerNode.setInProgress(false)
            strongSelf.dismiss()
        }))
    }
}
