import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import AccountContext
import ChatListSearchRecentPeersNode
import ContextUI

final class WalletPeerSelectionTopPeersItem: ListViewItem {
    var neighborDescriptor: AnyEquatable {
        return AnyEquatable.noNeighborInfluence
    }

    let context: AccountContext
    let presentationData: PresentationData
    let peerSelected: (EnginePeer) -> Void

    init(context: AccountContext, presentationData: PresentationData, peerSelected: @escaping (EnginePeer) -> Void) {
        self.context = context
        self.presentationData = presentationData
        self.peerSelected = peerSelected
    }

    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, neighbors: ListViewItemNeighbors, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = WalletPeerSelectionTopPeersItemNode()
            let (layout, apply) = node.asyncLayout()(self, params)
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            completion(node, {
                return (nil, { _ in apply() })
            })
        }
    }

    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, neighbors: ListViewItemNeighbors, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            guard let node = node() as? WalletPeerSelectionTopPeersItemNode else {
                return
            }
            let makeLayout = node.asyncLayout()
            async {
                let (layout, apply) = makeLayout(self, params)
                Queue.mainQueue().async {
                    completion(layout, { _ in apply() })
                }
            }
        }
    }
}

private final class WalletPeerSelectionTopPeersItemNode: ListViewItemNode {
    private var item: WalletPeerSelectionTopPeersItem?
    private var peersNode: ChatListSearchRecentPeersNode?

    required init() {
        super.init(layerBacked: false)
    }

    override func layoutForParams(_ params: ListViewItemLayoutParams, item: ListViewItem, neighbors: ListViewItemNeighbors) {
        guard let item = self.item else {
            return
        }
        let (layout, apply) = self.asyncLayout()(item, params)
        self.contentSize = layout.contentSize
        self.insets = layout.insets
        apply()
    }

    func asyncLayout() -> (WalletPeerSelectionTopPeersItem, ListViewItemLayoutParams) -> (ListViewItemNodeLayout, () -> Void) {
        return { [weak self] item, params in
            let layout = ListViewItemNodeLayout(contentSize: CGSize(width: params.width, height: 96.0), insets: .zero)
            return (layout, { [weak self] in
                guard let self else {
                    return
                }
                self.item = item

                let peersNode: ChatListSearchRecentPeersNode
                if let current = self.peersNode {
                    peersNode = current
                    peersNode.updateThemeAndStrings(theme: item.presentationData.theme, strings: item.presentationData.strings)
                } else {
                    let accountPeerId = item.context.account.peerId
                    peersNode = ChatListSearchRecentPeersNode(
                        accountPeerId: accountPeerId,
                        stateManager: item.context.account.stateManager,
                        energyUsageSettings: item.context.sharedContext.energyUsageSettings,
                        contentSettings: item.context.currentContentSettings.with { $0 },
                        animationCache: item.context.animationCache,
                        animationRenderer: item.context.animationRenderer,
                        resolveInlineStickers: item.context.engine.stickers.resolveInlineStickers,
                        theme: item.presentationData.theme,
                        mode: .list(compact: false),
                        strings: item.presentationData.strings,
                        peerSelected: { [weak self] peer in
                            self?.item?.peerSelected(peer)
                        },
                        peerContextAction: { _, _, gesture, _ in
                            gesture?.cancel()
                        },
                        isPeerSelected: { _ in false },
                        peerFilter: { peer in
                            return walletPeerSelectionIsEligiblePeer(peer, accountPeerId: accountPeerId)
                        },
                        displayUnreadBadges: false
                    )
                    self.peersNode = peersNode
                    self.addSubnode(peersNode)
                }
                peersNode.frame = CGRect(origin: .zero, size: layout.contentSize)
                peersNode.updateLayout(size: layout.contentSize, leftInset: params.leftInset, rightInset: params.rightInset)
            })
        }
    }
}
