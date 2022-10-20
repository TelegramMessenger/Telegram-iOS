import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit
import ItemListUI
import PresentationDataUtils
import AccountContext

final class ChannelMembersSearchItem: ItemListControllerSearch {
    let context: AccountContext
    let peerId: PeerId
    let searchContext: GroupMembersSearchContext?
    let cancel: () -> Void
    let openPeer: (Peer, RenderedChannelParticipant?) -> Void
    let pushController: (ViewController) -> Void
    let dismissInput: () -> Void
    let searchMode: ChannelMembersSearchMode
    
    private var updateActivity: ((Bool) -> Void)?
    private var activity: ValuePromise<Bool> = ValuePromise(ignoreRepeated: false)
    private let activityDisposable = MetaDisposable()
    
    init(context: AccountContext, peerId: PeerId, searchContext: GroupMembersSearchContext?, searchMode: ChannelMembersSearchMode = .searchMembers, cancel: @escaping () -> Void, openPeer: @escaping (Peer, RenderedChannelParticipant?) -> Void, pushController: @escaping (ViewController) -> Void, dismissInput: @escaping () -> Void) {
        self.context = context
        self.peerId = peerId
        self.searchContext = searchContext
        self.cancel = cancel
        self.openPeer = openPeer
        self.pushController = pushController
        self.dismissInput = dismissInput
        self.searchMode = searchMode
        self.activityDisposable.set((activity.get() |> mapToSignal { value -> Signal<Bool, NoError> in
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
        if let to = to as? ChannelMembersSearchItem {
            if self.context !== to.context {
                return false
            }
            if self.peerId != to.peerId {
                return false
            }
            return true
        } else {
            return false
        }
    }
    
    func titleContentNode(current: (NavigationBarContentNode & ItemListControllerSearchNavigationContentNode)?) -> NavigationBarContentNode & ItemListControllerSearchNavigationContentNode {
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        if let current = current as? GroupInfoSearchNavigationContentNode {
            current.updateTheme(presentationData.theme)
            return current
        } else {
            return GroupInfoSearchNavigationContentNode(theme: presentationData.theme, strings: presentationData.strings, mode: self.searchMode, cancel: self.cancel, updateActivity: { [weak self] value in
                self?.updateActivity = value
            })
        }
    }
    
    func node(current: ItemListControllerSearchNode?, titleContentNode: (NavigationBarContentNode & ItemListControllerSearchNavigationContentNode)?) -> ItemListControllerSearchNode {
        return ChannelMembersSearchItemNode(context: self.context, peerId: self.peerId, searchMode: self.searchMode, searchContext: self.searchContext, openPeer: self.openPeer, cancel: self.cancel, updateActivity: { [weak self] value in
            self?.activity.set(value)
        }, pushController: { [weak self] c in
            self?.pushController(c)
        }, dismissInput: self.dismissInput)
    }
}

private final class ChannelMembersSearchItemNode: ItemListControllerSearchNode {
    private let containerNode: ChannelMembersSearchContainerNode
    
    init(context: AccountContext, peerId: PeerId, searchMode: ChannelMembersSearchMode, searchContext: GroupMembersSearchContext?, openPeer: @escaping (Peer, RenderedChannelParticipant?) -> Void, cancel: @escaping () -> Void, updateActivity: @escaping(Bool) -> Void, pushController: @escaping (ViewController) -> Void, dismissInput: @escaping () -> Void) {
        self.containerNode = ChannelMembersSearchContainerNode(context: context, forceTheme: nil, peerId: peerId, mode: searchMode, filters: [], searchContext: searchContext, openPeer: { peer, participant in
            openPeer(peer, participant)
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
