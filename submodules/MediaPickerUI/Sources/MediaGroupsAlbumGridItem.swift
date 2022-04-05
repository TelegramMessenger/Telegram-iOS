import Foundation
import UIKit
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import MergeLists
import Photos

private struct MediaGroupsGridAlbumEntry: Comparable, Identifiable {
    let theme: PresentationTheme
    let index: Int
    let collection: PHAssetCollection
    let firstItem: PHAsset?
    let count: String
      
    var stableId: String {
        return self.collection.localIdentifier
    }
    
    static func ==(lhs: MediaGroupsGridAlbumEntry, rhs: MediaGroupsGridAlbumEntry) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.index != rhs.index {
            return false
        }
        if lhs.collection != rhs.collection {
            return false
        }
        if lhs.firstItem != rhs.firstItem {
            return false
        }
        if lhs.count != rhs.count {
            return false
        }
        return true
    }
    
    static func <(lhs: MediaGroupsGridAlbumEntry, rhs: MediaGroupsGridAlbumEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    func item(action: @escaping (PHAssetCollection) -> Void) -> ListViewItem {
        return MediaGroupsGridAlbumItem(theme: theme, collection: self.collection, firstItem: self.firstItem, count: self.count, action: action)
    }
}


private class MediaGroupsGridAlbumItem: ListViewItem {
    let theme: PresentationTheme
    let collection: PHAssetCollection
    let firstItem: PHAsset?
    let count: String
    let action: (PHAssetCollection) -> Void
    
    public init(theme: PresentationTheme, collection: PHAssetCollection, firstItem: PHAsset?, count: String, action: @escaping (PHAssetCollection) -> Void) {
        self.theme = theme
        self.collection = collection
        self.firstItem = firstItem
        self.count = count
        self.action = action
    }
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        async {
            let node = MediaGroupsGridAlbumItemNode()
            let (nodeLayout, apply) = node.asyncLayout()(self, params)
            node.insets = nodeLayout.insets
            node.contentSize = nodeLayout.contentSize
            
            Queue.mainQueue().async {
                completion(node, {
                    return (nil, { _ in
                        apply(false)
                    })
                })
            }
        }
    }
    
    public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            assert(node() is MediaGroupsGridAlbumItemNode)
            if let nodeValue = node() as? MediaGroupsGridAlbumItemNode {
                let layout = nodeValue.asyncLayout()
                async {
                    let (nodeLayout, apply) = layout(self, params)
                    Queue.mainQueue().async {
                        completion(nodeLayout, { _ in
                            apply(animation.isAnimated)
                        })
                    }
                }
            }
        }
    }
    
    public var selectable = true
    public func selected(listView: ListView) {
        self.action(self.collection)
    }
}


private let textFont = Font.regular(15.0)

private final class MediaGroupsGridAlbumItemNode : ListViewItemNode {
    private let containerNode: ASDisplayNode
    private let imageNode: ImageNode
    private let titleNode: TextNode
    private let countNode: TextNode
    
    var item: MediaGroupsGridAlbumItem?

    init() {
        self.containerNode = ASDisplayNode()
        
        self.imageNode = ImageNode()
        self.imageNode.clipsToBounds = true
        self.imageNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: 62.0, height: 62.0))
        self.imageNode.contentMode = .scaleAspectFill
        self.imageNode.animateFirstTransition = false
        
        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false

        self.countNode = TextNode()
        self.countNode.isUserInteractionEnabled = false
        
        super.init(layerBacked: false, dynamicBounce: false, rotated: false, seeThrough: false)
                
        self.addSubnode(self.containerNode)
        self.containerNode.addSubnode(self.imageNode)
        self.containerNode.addSubnode(self.titleNode)
        self.containerNode.addSubnode(self.countNode)
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.imageNode.cornerRadius = 10.0
        if #available(iOS 13.0, *) {
            self.imageNode.layer.cornerCurve = .continuous
        }
        
        self.containerNode.transform = CATransform3DMakeRotation(CGFloat.pi / 2.0, 0.0, 0.0, 1.0)
    }
    
    func asyncLayout() -> (MediaGroupsGridAlbumItem, ListViewItemLayoutParams) -> (ListViewItemNodeLayout, (Bool) -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeCountLayout = TextNode.asyncLayout(self.countNode)
        
        return { [weak self] item, params in
            let title = NSAttributedString(string: item.collection.localizedTitle ?? "", font: textFont, textColor: item.theme.list.itemPrimaryTextColor)
            let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: title, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: 170.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let count = NSAttributedString(string: item.count, font: textFont, textColor: item.theme.list.itemSecondaryTextColor)
            let (countLayout, countApply) = makeCountLayout(TextNodeLayoutArguments(attributedString: count, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: 170.0, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
            
            let itemLayout = ListViewItemNodeLayout(contentSize: CGSize(width: 220.0, height: 182.0), insets: UIEdgeInsets())
            return (itemLayout, { animated in
                if let strongSelf = self {
                    strongSelf.item = item
                    
                    strongSelf.containerNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: 220.0, height: 220.0))
                    
                    if let firstItem = item.firstItem {
                        let scale = min(2.0, UIScreenScale)
                        let targetSize = CGSize(width: 160.0 * scale, height: 160.0 * scale)
                        strongSelf.imageNode.setSignal(assetImage(asset: firstItem, targetSize: targetSize, exact: false))
                    }
                    
                    strongSelf.imageNode.frame = CGRect(origin: CGPoint(x: 6.0, y: 0.0), size: CGSize(width: 170.0, height: 170.0))
                    
                    let _ = titleApply()
                    strongSelf.titleNode.frame = CGRect(origin: CGPoint(x: 6.0, y: 176.0), size: titleLayout.size)
                    
                    let _ = countApply()
                    strongSelf.countNode.frame = CGRect(origin: CGPoint(x: 6.0, y: 196.0), size: countLayout.size)
                }
            })
        }
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        super.animateInsertion(currentTimestamp, duration: duration, short: short)
        
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        super.animateRemoved(currentTimestamp, duration: duration)
        
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
    }
    
    override func animateAdded(_ currentTimestamp: Double, duration: Double) {
        super.animateAdded(currentTimestamp, duration: duration)
        
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
}

private struct MediaGroupsAlbumGridItemNodeTransition {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
    let entries: [MediaGroupsGridAlbumEntry]
}

private func preparedTransition(action: @escaping (PHAssetCollection) -> Void, from fromEntries: [MediaGroupsGridAlbumEntry], to toEntries: [MediaGroupsGridAlbumEntry]) -> MediaGroupsAlbumGridItemNodeTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(action: action), directionHint: .Down) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(action: action), directionHint: nil) }
    
    return MediaGroupsAlbumGridItemNodeTransition(deletions: deletions, insertions: insertions, updates: updates, entries: toEntries)
}

final class MediaGroupsAlbumGridItem: ListViewItem {
    let presentationData: ItemListPresentationData
    let collections: [PHAssetCollection]
    let action: (PHAssetCollection) -> Void
    
    public init(presentationData: ItemListPresentationData, collections: [PHAssetCollection], action: @escaping (PHAssetCollection) -> Void) {
        self.presentationData = presentationData
        self.collections = collections
        self.action = action
    }
    
    public func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        Queue.mainQueue().async {
            let node = MediaGroupsAlbumGridItemNode()
            let makeLayout = node.asyncLayout()
            async {
                let (nodeLayout, nodeApply) = makeLayout(self, params)
                node.contentSize = nodeLayout.contentSize
                node.insets = nodeLayout.insets
                
                Queue.mainQueue().async {
                    completion(node, nodeApply)
                }
            }
        }
    }
    
    public func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        Queue.mainQueue().async {
            if let nodeValue = node() as? MediaGroupsAlbumGridItemNode {
                let layout = nodeValue.asyncLayout()
                async {
                    let (nodeLayout, apply) = layout(self, params)
                    Queue.mainQueue().async {
                        completion(nodeLayout, { info in
                            apply().1(info)
                        })
                    }
                }
            }
        }
    }
    
    public var selectable: Bool {
        return false
    }
}

private let titleFont = Font.bold(20.0)

private class MediaGroupsAlbumGridItemNode: ListViewItemNode {
    private var item: MediaGroupsAlbumGridItem?
    private var layoutParams: ListViewItemLayoutParams?
    
    private let listNode: ListView
    private var entries: [MediaGroupsGridAlbumEntry]?
    private var enqueuedTransitions: [MediaGroupsAlbumGridItemNodeTransition] = []
    
    init() {
        self.listNode = ListView()
        self.listNode.transform = CATransform3DMakeRotation(-CGFloat.pi / 2.0, 0.0, 0.0, 1.0)
        
        super.init(layerBacked: false, dynamicBounce: false, rotated: false, seeThrough: false)
        
        self.addSubnode(self.listNode)
    }
    
    private func enqueueTransition(_ transition: MediaGroupsAlbumGridItemNodeTransition) {
        self.enqueuedTransitions.append(transition)
        
        if let _ = self.item {
            while !self.enqueuedTransitions.isEmpty {
                self.dequeueTransition()
            }
        }
    }
    
    private func dequeueTransition() {
        guard let _ = self.item, let transition = self.enqueuedTransitions.first else {
            return
        }
        self.enqueuedTransitions.remove(at: 0)
        
        var options = ListViewDeleteAndInsertOptions()
        options.insert(.Synchronous)
        
        self.listNode.transaction(deleteIndices: transition.deletions, insertIndicesAndItems: transition.insertions, updateIndicesAndItems: transition.updates, options: options, scrollToItem: nil, updateSizeAndInsets: nil, updateOpaqueState: nil, completion: { _ in
        })
    }

    override func layoutForParams(_ params: ListViewItemLayoutParams, item: ListViewItem, previousItem: ListViewItem?, nextItem: ListViewItem?) {
        if let item = self.item {
            let makeLayout = self.asyncLayout()
            let (nodeLayout, nodeApply) = makeLayout(item, params)
            self.contentSize = nodeLayout.contentSize
            self.insets = nodeLayout.insets
            let _ = nodeApply()
        }
    }
    
    func asyncLayout() -> (_ item: MediaGroupsAlbumGridItem, _ params: ListViewItemLayoutParams) -> (ListViewItemNodeLayout, () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) {
        return { [weak self] item, params in
            let contentSize = CGSize(width: params.width, height: 220.0)
            let nodeLayout = ListViewItemNodeLayout(contentSize: contentSize, insets: UIEdgeInsets())
            
            return (nodeLayout, { [weak self] in
                return (nil, { _ in
                    if let strongSelf = self {
                        strongSelf.item = item
                        strongSelf.layoutParams = params
                                                 
                        let listInsets = UIEdgeInsets(top: 10.0, left: 0.0, bottom: 10.0, right: 0.0)
                        strongSelf.listNode.bounds = CGRect(x: 0.0, y: 0.0, width: contentSize.height, height: contentSize.width - params.leftInset - params.rightInset)
                        strongSelf.listNode.position = CGPoint(x: contentSize.width / 2.0, y: contentSize.height / 2.0)
                        strongSelf.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous], scrollToItem: nil, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: CGSize(width: contentSize.height, height: contentSize.width - params.leftInset - params.rightInset), insets: listInsets, duration: 0.0, curve: .Default(duration: nil)), stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
                        
                        var entries: [MediaGroupsGridAlbumEntry] = []
                        var index: Int = 0
                        for collection in item.collections {
                            let result = PHAsset.fetchAssets(in: collection, options: nil)
                            let firstItem: PHAsset?
                            if [.smartAlbumUserLibrary, .smartAlbumFavorites].contains(collection.assetCollectionSubtype) {
                                firstItem = result.lastObject
                            } else {
                                firstItem = result.firstObject
                            }
                            if let firstItem = firstItem {
                                entries.append(MediaGroupsGridAlbumEntry(theme: item.presentationData.theme, index: index, collection: collection, firstItem: firstItem, count: presentationStringsFormattedNumber(Int32(result.count))))
                                index += 1
                            }
                        }
                        
                        let previousEntries = strongSelf.entries ?? []
                        let transition = preparedTransition(action: { [weak item] collection in
                            item?.action(collection)
                        }, from: previousEntries, to: entries)
                        strongSelf.enqueueTransition(transition)
                        
                        strongSelf.entries = entries
                    }
                })
            })
        }
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration * 0.5)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration * 0.5, removeOnCompletion: false)
    }
}
