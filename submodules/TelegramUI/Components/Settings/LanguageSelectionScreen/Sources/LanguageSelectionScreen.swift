import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import AccountContext
import SearchUI

public class LanguageSelectionScreen: ViewController {
    private let context: AccountContext
    private let excludeIds: [String]
    private let selectLocalization: (LocalizationInfo) -> Void
    
    private var controllerNode: LanguageSelectionScreenNode {
        return self.displayNode as! LanguageSelectionScreenNode
    }
    
    private var _ready = Promise<Bool>()
    override public var ready: Promise<Bool> {
        return self._ready
    }
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    private var searchContentNode: NavigationBarSearchContentNode?
    
    private var previousContentOffset: ListViewVisibleContentOffset?
    
    public init(context: AccountContext, excludeIds: [String] = [], selectLocalization: @escaping (LocalizationInfo) -> Void) {
        self.context = context
        self.excludeIds = excludeIds
        self.selectLocalization = selectLocalization
        
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData))
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        self.navigationPresentation = .modal
        
        self.title = self.presentationData.strings.BotPreviews_SelectLanguage_Title
        
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
        
        self.searchContentNode = NavigationBarSearchContentNode(theme: self.presentationData.theme, placeholder: self.presentationData.strings.Common_Search, inline: true, activate: { [weak self] in
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
        self.title = self.presentationData.strings.Settings_AppLanguage
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        self.controllerNode.updatePresentationData(self.presentationData)
    }
    
    override public func loadDisplayNode() {
        self.displayNode = LanguageSelectionScreenNode(context: self.context, presentationData: self.presentationData, navigationBar: self.navigationBar!, excludeIds: self.excludeIds, requestActivateSearch: { [weak self] in
            self?.activateSearch()
        }, requestDeactivateSearch: { [weak self] in
            self?.deactivateSearch()
        }, present: { [weak self] c, a in
            self?.present(c, in: .window(.root), with: a)
        }, push: { [weak self] c in
            self?.push(c)
        }, selectLocalization: { [weak self] info in
            guard let self else {
                return
            }
            self.selectLocalization(info)
            self.dismiss()
        })
        
        self.controllerNode.listNode.visibleContentOffsetChanged = { [weak self] offset in
            if let strongSelf = self {
                if let searchContentNode = strongSelf.searchContentNode {
                    searchContentNode.updateListVisibleContentOffset(offset)
                }
                
                var previousContentOffsetValue: CGFloat?
                if let previousContentOffset = strongSelf.previousContentOffset, case let .known(value) = previousContentOffset {
                    previousContentOffsetValue = value
                }
                switch offset {
                    case let .known(value):
                        let transition: ContainedViewLayoutTransition
                        if let previousContentOffsetValue = previousContentOffsetValue, value <= 0.0, previousContentOffsetValue > 30.0 {
                            transition = .animated(duration: 0.2, curve: .easeInOut)
                        } else {
                            transition = .immediate
                        }
                        strongSelf.navigationBar?.updateBackgroundAlpha(min(30.0, max(0.0, value - 54.0)) / 30.0, transition: transition)
                    case .unknown, .none:
                        strongSelf.navigationBar?.updateBackgroundAlpha(1.0, transition: .immediate)
                }
                
                strongSelf.previousContentOffset = offset
            }
        }
        
        self.controllerNode.listNode.didEndScrolling = { [weak self] _ in
            if let strongSelf = self, let searchContentNode = strongSelf.searchContentNode {
                let _ = fixNavigationSearchableListNodeScrolling(strongSelf.controllerNode.listNode, searchNode: searchContentNode)
            }
        }
        
        self._ready.set(self.controllerNode._ready.get())
        
        self.navigationBar?.updateBackgroundAlpha(0.0, transition: .immediate)
        
        self.displayNodeDidLoad()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.cleanNavigationHeight, transition: transition)
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
    
    private func deactivateSearch() {
        if !self.displayNavigationBar {
            self.setDisplayNavigationBar(true, transition: .animated(duration: 0.5, curve: .spring))
            if let searchContentNode = self.searchContentNode {
                self.controllerNode.deactivateSearch(placeholderNode: searchContentNode.placeholderNode)
            }
        }
    }
}
