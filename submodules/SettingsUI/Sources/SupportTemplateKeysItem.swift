import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import AccountContext
import EditableTokenListNode

final class SupportTemplateKeysItem: ListViewItem, ItemListItem {
    let context: AccountContext
    let presentationData: ItemListPresentationData
    let keys: [String]
    let sectionId: ItemListSectionId
    let addKey: (String) -> Void
    let removeKey: (String) -> Void
    let pendingTextUpdated: (String) -> Void

    init(context: AccountContext, presentationData: ItemListPresentationData, keys: [String], sectionId: ItemListSectionId, addKey: @escaping (String) -> Void, removeKey: @escaping (String) -> Void, pendingTextUpdated: @escaping (String) -> Void) {
        self.context = context
        self.presentationData = presentationData
        self.keys = keys
        self.sectionId = sectionId
        self.addKey = addKey
        self.removeKey = removeKey
        self.pendingTextUpdated = pendingTextUpdated
    }

    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, neighbors: ListViewItemNeighbors, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        Queue.mainQueue().async {
            let node = SupportTemplateKeysItemNode()
            let (layout, apply) = node.layout(item: self, params: params, neighbors: itemListNeighbors(item: self, topFacet: neighbors.previous?.base(ItemListNeighborFacet.self), bottomFacet: neighbors.next?.base(ItemListNeighborFacet.self)), transition: .immediate)
            node.contentSize = layout.contentSize
            node.insets = layout.insets
            completion(node, {
                return (nil, { _ in apply() })
            })
        }
    }

    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, neighbors: ListViewItemNeighbors, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? SupportTemplateKeysItemNode {
                let (layout, apply) = nodeValue.layout(item: self, params: params, neighbors: itemListNeighbors(item: self, topFacet: neighbors.previous?.base(ItemListNeighborFacet.self), bottomFacet: neighbors.next?.base(ItemListNeighborFacet.self)), transition: animation.isAnimated ? .animated(duration: 0.2, curve: .easeInOut) : .immediate)
                completion(layout, { _ in
                    apply()
                })
            }
        }
    }

    let selectable = false
}

final class SupportTemplateKeysItemNode: ListViewItemNode, ItemListItemNode {
    private var tokenListNode: EditableTokenListNode?
    private var tokenListTheme: PresentationTheme?
    private var item: SupportTemplateKeysItem?
    private var pendingText = ""

    var tag: ItemListItemTag? {
        return nil
    }

    override var canBeSelected: Bool {
        return false
    }

    init() {
        super.init(layerBacked: false)
    }

    func layout(item: SupportTemplateKeysItem, params: ListViewItemLayoutParams, neighbors: ItemListNeighbors, transition: ContainedViewLayoutTransition) -> (ListViewItemNodeLayout, () -> Void) {
        self.item = item

        let theme = item.presentationData.theme
        let tokenListNode: EditableTokenListNode
        var tokenTransition = transition
        if let current = self.tokenListNode, self.tokenListTheme === theme {
            tokenListNode = current
        } else {
            self.tokenListNode?.removeFromSupernode()
            tokenTransition = .immediate
            tokenListNode = EditableTokenListNode(context: item.context, theme: theme, placeholder: item.presentationData.strings.Support_Templates_KeysPlaceholder, shortPlaceholder: item.presentationData.strings.Support_Templates_KeysPlaceholder)
            tokenListNode.textUpdated = { [weak self] text in
                guard let self else {
                    return
                }
                self.pendingText = text
                self.item?.pendingTextUpdated(text)
            }
            tokenListNode.textReturned = { [weak self] in
                guard let self, let tokenListNode = self.tokenListNode else {
                    return
                }
                let text = self.pendingText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    self.item?.addKey(text)
                }
                tokenListNode.setText("")
            }
            tokenListNode.deleteToken = { [weak self] id in
                if let key = id.base as? String {
                    self?.item?.removeKey(key)
                }
            }
            self.tokenListNode = tokenListNode
            self.tokenListTheme = theme
            self.addSubnode(tokenListNode)
        }

        let width = params.width - params.leftInset - params.rightInset
        let tokens = item.keys.map { EditableTokenListToken(id: $0, title: $0, fixedPosition: nil, subject: .text) }
        let height = tokenListNode.updateLayout(tokens: tokens, width: width, leftInset: 0.0, rightInset: 0.0, transition: tokenTransition)
        let tokenFrame = CGRect(x: params.leftInset, y: 0.0, width: width, height: height)

        let layout = ListViewItemNodeLayout(contentSize: CGSize(width: params.width, height: height), insets: itemListNeighborsGroupedInsets(neighbors, params))
        return (layout, {
            transition.updateFrame(node: tokenListNode, frame: tokenFrame)
        })
    }

    override func animateInsertion(_ currentTimestamp: Double, duration: Double, options: ListViewItemAnimationOptions) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.4)
    }

    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false)
    }
}
