import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import SwiftSignalKit
import ItemListUI
import PresentationDataUtils
import AccountContext

final class GroupStickerSearchItem: ItemListControllerSearch {
    let context: AccountContext
    let cancel: () -> Void
    let select: (StickerPackCollectionInfo) -> Void
    let dismissInput: () -> Void
    
    private var updateActivity: ((Bool) -> Void)?
    private var activity: ValuePromise<Bool> = ValuePromise(ignoreRepeated: false)
    private let activityDisposable = MetaDisposable()
    
    init(
        context: AccountContext,
        cancel: @escaping () -> Void,
        select: @escaping (StickerPackCollectionInfo) -> Void,
        dismissInput: @escaping () -> Void
    ) {
        self.context = context
        self.cancel = cancel
        self.select = select
        self.dismissInput = dismissInput
        self.activityDisposable.set((self.activity.get() |> mapToSignal { value -> Signal<Bool, NoError> in
            if value {
                return .single(value) |> delay(0.2, queue: Queue.mainQueue())
            } else {
                return .single(value)
            }
        }).start(next: { [weak self] value in
            self?.updateActivity?(value)
        }))
    }
    
    deinit {
        self.activityDisposable.dispose()
    }
    
    func isEqual(to: ItemListControllerSearch) -> Bool {
        if let to = to as? GroupStickerSearchItem {
            if self.context !== to.context {
                return false
            }
            return true
        } else {
            return false
        }
    }
    
    func titleContentNode(current: (NavigationBarContentNode & ItemListControllerSearchNavigationContentNode)?) -> NavigationBarContentNode & ItemListControllerSearchNavigationContentNode {
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        if let current = current as? GroupStickerSearchNavigationContentNode {
            current.updateTheme(presentationData.theme)
            return current
        } else {
            return GroupStickerSearchNavigationContentNode(theme: presentationData.theme, strings: presentationData.strings, cancel: self.cancel, updateActivity: { [weak self] value in
                self?.updateActivity = value
            })
        }
    }
    
    func node(current: ItemListControllerSearchNode?, titleContentNode: (NavigationBarContentNode & ItemListControllerSearchNavigationContentNode)?) -> ItemListControllerSearchNode {
        return GroupStickerSearchItemNode(context: self.context, packSelected: self.select, cancel: self.cancel, updateActivity: { [weak self] value in
            self?.activity.set(value)
        }, pushController: { c in
            
        }, dismissInput: self.dismissInput)
    }
}

private final class GroupStickerSearchItemNode: ItemListControllerSearchNode {
    private let containerNode: GroupStickerSearchContainerNode
    
    init(context: AccountContext, packSelected: @escaping (StickerPackCollectionInfo) -> Void, cancel: @escaping () -> Void, updateActivity: @escaping(Bool) -> Void, pushController: @escaping (ViewController) -> Void, dismissInput: @escaping () -> Void) {
        self.containerNode = GroupStickerSearchContainerNode(context: context, forceTheme: nil, packSelected: { pack in
            packSelected(pack)
            cancel()
        }, updateActivity: updateActivity, pushController: pushController)
        self.containerNode.cancel = {
            cancel()
        }
        
        super.init()
        
        self.addSubnode(self.containerNode)
        
        self.containerNode.dismissInput = {
            dismissInput()
        }
    }
    
    override func queryUpdated(_ query: String) {
        self.containerNode.searchTextUpdated(text: query)
    }
    
    override func scrollToTop() {
        self.containerNode.scrollToTop()
    }
    
    override func updateLayout(layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(node: self.containerNode, frame: CGRect(origin: CGPoint(x: 0.0, y: navigationBarHeight), size: CGSize(width: layout.size.width, height: layout.size.height - navigationBarHeight)))
        self.containerNode.containerLayoutUpdated(layout.withUpdatedSize(CGSize(width: layout.size.width, height: layout.size.height - navigationBarHeight)), navigationBarHeight: 0.0, transition: transition)
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let result = self.containerNode.hitTest(self.view.convert(point, to: self.containerNode.view), with: event) {
            return result
        }
        
        return super.hitTest(point, with: event)
    }
}
