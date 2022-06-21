import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import AccountContext

final class ChatSearchResultsController: ViewController {
    private var controllerNode: ChatSearchResultsControllerNode {
        return self.displayNode as! ChatSearchResultsControllerNode
    }
    
    private let context: AccountContext
    private var presentationData: PresentationData
    private let location: SearchMessagesLocation
    private let searchQuery: String
    private let searchResult: SearchMessagesResult
    private let searchState: SearchMessagesState
        
    private let navigateToMessageIndex: (Int) -> Void
    private let resultsUpdated: (SearchMessagesResult, SearchMessagesState) -> Void
    
    private var presentationDataDisposable: Disposable?
    
    init(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, location: SearchMessagesLocation, searchQuery: String, searchResult: SearchMessagesResult, searchState: SearchMessagesState, navigateToMessageIndex: @escaping (Int) -> Void, resultsUpdated: @escaping (SearchMessagesResult, SearchMessagesState) -> Void) {
        self.context = context
        self.presentationData = updatedPresentationData?.initial ?? context.sharedContext.currentPresentationData.with { $0 }
        self.location = location
        self.searchQuery = searchQuery
        self.navigateToMessageIndex = navigateToMessageIndex
        self.resultsUpdated = resultsUpdated
        self.searchResult = searchResult
        self.searchState = searchState
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationTheme: self.presentationData.theme, presentationStrings: self.presentationData.strings))
        
        self.navigationPresentation = .modal
        
        self.presentationDataDisposable = ((updatedPresentationData?.signal ?? context.sharedContext.presentationData)
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                strongSelf.presentationData = presentationData
                strongSelf.navigationBar?.updatePresentationData(NavigationBarPresentationData(presentationTheme: presentationData.theme, presentationStrings: presentationData.strings))
                strongSelf.controllerNode.updatePresentationData(presentationData)
            }
        })
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        
        self.title = searchQuery
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Done, style: .done, target: self, action: #selector(donePressed))
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
    }
    
    override public func loadDisplayNode() {
        self.displayNode = ChatSearchResultsControllerNode(context: self.context, location: self.location, searchQuery: self.searchQuery, searchResult: self.searchResult, searchState: self.searchState, presentInGlobalOverlay: { [weak self] c in
            self?.presentInGlobalOverlay(c)
        })
        self.controllerNode.resultSelected = { [weak self] messageIndex in
            self?.navigateToMessageIndex(messageIndex)
            self?.dismiss()
        }
        self.controllerNode.resultsUpdated = { [weak self] result, state in
            self?.resultsUpdated(result, state)
        }
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
    
    @objc private func donePressed() {
        self.dismiss()
    }
}
