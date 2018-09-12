import Foundation
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit

final class ChannelMembersSearchItem: ItemListControllerSearch {
    let account: Account
    let peerId: PeerId
    let cancel: () -> Void
    let openPeer: (Peer, RenderedChannelParticipant?) -> Void
    let searchMode: ChannelMembersSearchMode
    private var updateActivity: ((Bool) -> Void)?
    private var activity: ValuePromise<Bool> = ValuePromise(ignoreRepeated: false)
    private let activityDisposable = MetaDisposable()
    init(account: Account, peerId: PeerId, searchMode: ChannelMembersSearchMode = .searchMembers, cancel: @escaping () -> Void, openPeer: @escaping (Peer, RenderedChannelParticipant?) -> Void) {
        self.account = account
        self.peerId = peerId
        self.cancel = cancel
        self.openPeer = openPeer
        self.searchMode = searchMode
        activityDisposable.set((activity.get() |> mapToSignal { value -> Signal<Bool, NoError> in
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
        activityDisposable.dispose()
    }
    
    func isEqual(to: ItemListControllerSearch) -> Bool {
        if let to = to as? ChannelMembersSearchItem {
            if self.account !== to.account {
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
        if let current = current as? GroupInfoSearchNavigationContentNode {
            return current
        } else {
            let presentationData = self.account.telegramApplicationContext.currentPresentationData.with { $0 }
            return GroupInfoSearchNavigationContentNode(theme: presentationData.theme, strings: presentationData.strings, cancel: self.cancel, updateActivity: { [weak self] value in
                self?.updateActivity = value
            })
        }
    }
    
    func node(current: ItemListControllerSearchNode?) -> ItemListControllerSearchNode {
        return ChannelMembersSearchItemNode(account: self.account, peerId: self.peerId, searchMode: self.searchMode, openPeer: self.openPeer, cancel: self.cancel, updateActivity: { [weak self] value in
            self?.activity.set(value)
        })
    }
}

private final class ChannelMembersSearchItemNode: ItemListControllerSearchNode {
    private let containerNode: ChannelMembersSearchContainerNode
    
    init(account: Account, peerId: PeerId, searchMode: ChannelMembersSearchMode, openPeer: @escaping (Peer, RenderedChannelParticipant?) -> Void, cancel: @escaping () -> Void, updateActivity: @escaping(Bool)->Void) {
        self.containerNode = ChannelMembersSearchContainerNode(account: account, peerId: peerId, mode: searchMode, filters: [], openPeer: { peer, participant in
            openPeer(peer, participant)
        }, updateActivity: updateActivity)
        self.containerNode.cancel = {
            cancel()
        }
        
        super.init()
        
        self.addSubnode(self.containerNode)
    }
    
    override func queryUpdated(_ query: String) {
        self.containerNode.searchTextUpdated(text: query)
    }
    
    override func updateLayout(layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(node: self.containerNode, frame: CGRect(origin: CGPoint(x: 0.0, y: navigationBarHeight), size: CGSize(width: layout.size.width, height: layout.size.height - navigationBarHeight)))
        self.containerNode.containerLayoutUpdated(layout, navigationBarHeight: 0.0, transition: transition)
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let result = self.containerNode.hitTest(self.view.convert(point, to: self.containerNode.view), with: event) {
            return result
        }
        
        return super.hitTest(point, with: event)
    }
}
