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
    
    private var validLayout: ContainerViewLayout?
    
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
                var statusBarHidden = false
                if value, let layout = strongSelf.validLayout {
                    if let statusBarHeight = layout.statusBarHeight, statusBarHeight > 20.0 {
                        statusBarHidden = false
                    } else {
                        statusBarHidden = true
                    }
                }
                strongSelf.statusBar.statusBarStyle = statusBarHidden ? .Hide : .Ignore
                if value {
                    strongSelf.deferScreenEdgeGestures = [.top]
                } else {
                    strongSelf.deferScreenEdgeGestures = []
                }
            }
        }
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        self.validLayout = layout
        
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
    
    public func updateIsTemporaryHidden(_ value: Bool) {
        if self.isNodeLoaded {
            if value != (self.controllerNode.alpha == 0.0) {
                let fromAlpha: CGFloat = value ? 1.0 : 0.0
                let toAlpha: CGFloat = value ? 0.0 : 1.0
                self.controllerNode.alpha = toAlpha
                self.controllerNode.layer.animateAlpha(from: fromAlpha, to: toAlpha, duration: 0.2)
                self.controllerNode.isUserInteractionEnabled = !value
            }
        }
    }
}
