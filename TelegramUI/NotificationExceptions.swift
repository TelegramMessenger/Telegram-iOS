import Foundation
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

public class NotificationExceptionsController: ViewController {
    private let account: Account
    
    private var controllerNode: NotificationExceptionsControllerNode {
        return self.displayNode as! NotificationExceptionsControllerNode
    }
    
    private var _ready = Promise<Bool>()
    override public var ready: Promise<Bool> {
        return self._ready
    }
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    private var editItem: UIBarButtonItem!
    private var doneItem: UIBarButtonItem!
    
    private let mode: NotificationExceptionMode
    private let updatedMode: (NotificationExceptionMode) -> Void
    public init(account: Account, mode: NotificationExceptionMode, updatedMode: @escaping(NotificationExceptionMode)->Void) {
        self.account = account
        self.mode = mode
        self.updatedMode = updatedMode
        self.presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData))
        
        self.editItem = UIBarButtonItem(title: self.presentationData.strings.Common_Done, style: .done, target: self, action: #selector(self.editPressed))
        self.doneItem = UIBarButtonItem(title: self.presentationData.strings.Common_Edit, style: .plain, target: self, action: #selector(self.editPressed))
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBar.style.style
        
        self.title = self.presentationData.strings.Notifications_ExceptionsTitle
        
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        
        self.scrollToTop = { [weak self] in
            self?.controllerNode.scrollToTop()
        }
        
        self.presentationDataDisposable = (account.telegramApplicationContext.presentationData
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
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
    }
    
    private func updateThemeAndStrings() {
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBar.style.style
        self.navigationBar?.updatePresentationData(NavigationBarPresentationData(presentationData: self.presentationData))
        self.title = self.presentationData.strings.Notifications_ExceptionsTitle
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        self.controllerNode.updatePresentationData(self.presentationData)
        
        
        let editItem = UIBarButtonItem(title: self.presentationData.strings.Common_Done, style: .done, target: self, action: #selector(self.editPressed))
        let doneItem = UIBarButtonItem(title: self.presentationData.strings.Common_Edit, style: .plain, target: self, action: #selector(self.editPressed))
        if self.navigationItem.rightBarButtonItem === self.editItem {
            self.navigationItem.rightBarButtonItem = editItem
        } else if self.navigationItem.rightBarButtonItem === self.doneItem {
            self.navigationItem.rightBarButtonItem = doneItem
        }
        self.editItem = editItem
        self.doneItem = doneItem
    }
    
    override public func loadDisplayNode() {
        self.displayNode = NotificationExceptionsControllerNode(account: self.account, presentationData: self.presentationData, navigationBar: self.navigationBar!, mode: self.mode, updatedMode: self.updatedMode, requestActivateSearch: { [weak self] in
            self?.activateSearch()
            }, requestDeactivateSearch: { [weak self] in
                self?.deactivateSearch()
            }, updateCanStartEditing: { [weak self] value in
                guard let strongSelf = self else {
                    return
                }
                let item: UIBarButtonItem?
                if let value = value {
                    item = value ? strongSelf.editItem : strongSelf.doneItem
                } else {
                    item = nil
                }
                if strongSelf.navigationItem.rightBarButtonItem !== item {
                    strongSelf.navigationItem.setRightBarButton(item, animated: true)
                }
            }, present: { [weak self] c, a in
                self?.present(c, in: .window(.root), with: a)
            }, pushController: { [weak self] c in
                (self?.navigationController as? NavigationController)?.pushViewController(c)
            })
        self._ready.set(self.controllerNode._ready.get())
        
        self.displayNodeDidLoad()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition)
    }
    
    @objc private func editPressed() {
        self.controllerNode.toggleEditing()
    }
    
    private func activateSearch() {
        if self.displayNavigationBar {
            if let scrollToTop = self.scrollToTop {
                scrollToTop()
            }
            self.controllerNode.activateSearch()
            self.setDisplayNavigationBar(false, transition: .animated(duration: 0.5, curve: .spring))
        }
    }
    
    private func deactivateSearch() {
        if !self.displayNavigationBar {
            self.setDisplayNavigationBar(true, transition: .animated(duration: 0.5, curve: .spring))
            self.controllerNode.deactivateSearch()
        }
    }
}
