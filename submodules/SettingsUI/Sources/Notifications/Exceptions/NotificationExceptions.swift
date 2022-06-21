import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import AccountContext
import SearchUI

public class NotificationExceptionsController: ViewController {
    private let context: AccountContext
    
    private var controllerNode: NotificationExceptionsControllerNode {
        return self.displayNode as! NotificationExceptionsControllerNode
    }
    
    private var _ready = Promise<Bool>()
    override public var ready: Promise<Bool> {
        return self._ready
    }
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    private var removeAllItem: UIBarButtonItem!
    private var editItem: UIBarButtonItem!
    private var doneItem: UIBarButtonItem!
    
    private let mode: NotificationExceptionMode
    private let updatedMode: (NotificationExceptionMode) -> Void
    
    private var searchContentNode: NavigationBarSearchContentNode?
    
    public init(context: AccountContext, mode: NotificationExceptionMode, updatedMode: @escaping(NotificationExceptionMode) -> Void) {
        self.context = context
        self.mode = mode
        self.updatedMode = updatedMode
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData))
        
        self.removeAllItem = UIBarButtonItem(title: self.presentationData.strings.Notification_Exceptions_DeleteAll, style: .plain, target: self, action: #selector(self.removeAllPressed))
        self.editItem = UIBarButtonItem(title: self.presentationData.strings.Common_Done, style: .done, target: self, action: #selector(self.editPressed))
        self.doneItem = UIBarButtonItem(title: self.presentationData.strings.Common_Edit, style: .plain, target: self, action: #selector(self.editPressed))
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        
        self.title = self.presentationData.strings.Notifications_ExceptionsTitle
        
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        
        self.scrollToTop = { [weak self] in
            if let strongSelf = self {
                if let searchContentNode = strongSelf.searchContentNode {
                    searchContentNode.updateExpansionProgress(1.0, animated: true)
                }
                strongSelf.controllerNode.scrollToTop()
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
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
    }
    
    private func updateThemeAndStrings() {
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        self.navigationBar?.updatePresentationData(NavigationBarPresentationData(presentationData: self.presentationData))
        self.searchContentNode?.updateThemeAndPlaceholder(theme: self.presentationData.theme, placeholder: self.presentationData.strings.Common_Search)
        self.title = self.presentationData.strings.Notifications_ExceptionsTitle
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        self.controllerNode.updatePresentationData(self.presentationData)
        
        let removeAllItem = UIBarButtonItem(title: self.presentationData.strings.Notification_Exceptions_DeleteAll, style: .plain, target: self, action: #selector(self.removeAllPressed))
        let editItem = UIBarButtonItem(title: self.presentationData.strings.Common_Done, style: .done, target: self, action: #selector(self.editPressed))
        let doneItem = UIBarButtonItem(title: self.presentationData.strings.Common_Edit, style: .plain, target: self, action: #selector(self.editPressed))
        if self.navigationItem.rightBarButtonItem === self.editItem {
            self.navigationItem.rightBarButtonItem = editItem
        } else if self.navigationItem.rightBarButtonItem === self.doneItem {
            self.navigationItem.rightBarButtonItem = doneItem
            self.navigationItem.leftBarButtonItem = removeAllItem
        }
        self.removeAllItem = removeAllItem
        self.editItem = editItem
        self.doneItem = doneItem
    }
    
    override public func loadDisplayNode() {
        self.displayNode = NotificationExceptionsControllerNode(context: self.context, presentationData: self.presentationData, navigationBar: self.navigationBar!, mode: self.mode, updatedMode: self.updatedMode, requestActivateSearch: { [weak self] in
            self?.activateSearch()
            }, requestDeactivateSearch: { [weak self] animated in
                self?.deactivateSearch(animated: animated)
            }, updateCanStartEditing: { [weak self] value in
                guard let strongSelf = self else {
                    return
                }
                var leftItem: UIBarButtonItem?
                var item: UIBarButtonItem?
                if let value = value {
                    item = value ? strongSelf.editItem : strongSelf.doneItem
                    leftItem = value ? strongSelf.removeAllItem : nil
                }
                if strongSelf.navigationItem.leftBarButtonItem !== leftItem {
                    strongSelf.navigationItem.setLeftBarButton(leftItem, animated: true)
                }
                if strongSelf.navigationItem.rightBarButtonItem !== item {
                    strongSelf.navigationItem.setRightBarButton(item, animated: true)
                }
            }, present: { [weak self] c, a in
                self?.present(c, in: .window(.root), with: a)
            }, pushController: { [weak self] c in
                (self?.navigationController as? NavigationController)?.pushViewController(c)
            })
        
        self.controllerNode.listNode.visibleContentOffsetChanged = { [weak self] offset in
            if let strongSelf = self, let searchContentNode = strongSelf.searchContentNode {
                searchContentNode.updateListVisibleContentOffset(offset)
            }
        }
        
        self.controllerNode.listNode.didEndScrolling = { [weak self] _ in
            if let strongSelf = self, let searchContentNode = strongSelf.searchContentNode {
                let _ = fixNavigationSearchableListNodeScrolling(strongSelf.controllerNode.listNode, searchNode: searchContentNode)
            }
        }
        
        self._ready.set(self.controllerNode._ready.get())
        
        self.displayNodeDidLoad()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.cleanNavigationHeight, actualNavigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
    
    @objc private func removeAllPressed() {
        self.controllerNode.removeAll()
    }
    
    @objc private func editPressed() {
        self.controllerNode.toggleEditing()
    }
    
    private func activateSearch() {
        if self.displayNavigationBar {
            if let scrollToTop = self.scrollToTop {
                scrollToTop()
            }
            if let searchContentNode = self.searchContentNode {
                self.controllerNode.activateSearch(placeholderNode: searchContentNode.placeholderNode)
            }
            self.setDisplayNavigationBar(false, transition: .animated(duration: 0.5, curve: .spring))
        }
    }
    
    private func deactivateSearch(animated: Bool) {
        if !self.displayNavigationBar {
            self.setDisplayNavigationBar(true, transition: .animated(duration: 0.5, curve: .spring))
            if let searchContentNode = self.searchContentNode {
                self.controllerNode.deactivateSearch(placeholderNode: searchContentNode.placeholderNode, animated: animated)
            }
        }
    }
}
