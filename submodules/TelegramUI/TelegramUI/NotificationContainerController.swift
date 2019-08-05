import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import AccountContext

public final class NotificationContainerController: ViewController {
    private var controllerNode: NotificationContainerControllerNode {
        return self.displayNode as! NotificationContainerControllerNode
    }
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    public init(context: AccountContext) {
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        super.init(navigationBarPresentationData: nil)
        
        self.statusBar.statusBarStyle = .Ignore
        
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
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func updateThemeAndStrings() {
        if self.isNodeLoaded {
            self.controllerNode.updatePresentationData(self.presentationData)
        }
    }
    
    override public func loadView() {
        super.loadView()
    }
    
    override public func loadDisplayNode() {
        self.displayNode = NotificationContainerControllerNode(presentationData: self.presentationData)
        self.displayNodeDidLoad()
        
        self.controllerNode.displayingItemsUpdated = { [weak self] value in
            if let strongSelf = self {
                strongSelf.statusBar.statusBarStyle = value ? .Hide : .Ignore
                if value {
                    strongSelf.deferScreenEdgeGestures = [.top]
                } else {
                    strongSelf.deferScreenEdgeGestures = []
                }
            }
        }
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, transition: transition)
    }
    
    public func removeItemsWithGroupingKey(_ key: AnyHashable) {
        self.controllerNode.removeItemsWithGroupingKey(key)
    }
    
    public func enqueue(_ item: NotificationItem) {
        self.controllerNode.enqueue(item)
    }
    
    public func removeItems(_ f: (NotificationItem) -> Bool) {
        self.controllerNode.removeItems(f)
    }
}
