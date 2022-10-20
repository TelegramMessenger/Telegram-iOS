import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit
import AccountContext
import TelegramPresentationData
import TelegramUIPreferences
import MergeLists
import Photos
import LegacyComponents
import AttachmentUI
import ItemListUI

private enum MediaGroupsEntry: Comparable, Identifiable {
    enum StableId: Hashable {
        case albumsHeader
        case albums
        case smartAlbumsHeader
        case smartAlbum(String)
    }
    
    case albumsHeader(PresentationTheme, String)
    case albums(PresentationTheme, [PHAssetCollection])
    case smartAlbumsHeader(PresentationTheme, String)
    case smartAlbum(PresentationTheme, Int, PHAssetCollection, Int)
        
    var stableId: StableId {
        switch self {
            case .albumsHeader:
                return .albumsHeader
            case .albums:
                return .albums
            case .smartAlbumsHeader:
                return .smartAlbumsHeader
            case let .smartAlbum(_, _, album, _):
                return .smartAlbum(album.localIdentifier)
        }
    }

    static func ==(lhs: MediaGroupsEntry, rhs: MediaGroupsEntry) -> Bool {
        switch lhs {
            case let .albumsHeader(lhsTheme, lhsText):
                if case let .albumsHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .albums(lhsTheme, lhsAssetCollections):
                if case let .albums(rhsTheme, rhsAssetCollections) = rhs, lhsTheme === rhsTheme, lhsAssetCollections == rhsAssetCollections {
                    return true
                } else {
                    return false
                }
            case let .smartAlbumsHeader(lhsTheme, lhsText):
                if case let .smartAlbumsHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .smartAlbum(lhsTheme, lhsIndex, lhsAssetCollection, lhsCount):
                if case let .smartAlbum(rhsTheme, rhsIndex, rhsAssetCollection, rhsCount) = rhs, lhsTheme === rhsTheme, lhsIndex == rhsIndex, lhsAssetCollection == rhsAssetCollection, lhsCount == rhsCount {
                    return true
                } else {
                    return false
                }
        }
    }
    
    private var sortId: Int {
        switch self {
        case .albumsHeader:
            return 0
        case .albums:
            return 1
        case .smartAlbumsHeader:
            return 2
        case let .smartAlbum(_, index, _, _):
            return 3 + index
        }
    }
    
    static func <(lhs: MediaGroupsEntry, rhs: MediaGroupsEntry) -> Bool {
        return lhs.sortId < rhs.sortId
    }
    
    func item(presentationData: PresentationData, openGroup: @escaping (PHAssetCollection) -> Void) -> ListViewItem {
        switch self {
            case let .albumsHeader(_, text), let .smartAlbumsHeader(_, text):
                return MediaGroupsHeaderItem(presentationData: ItemListPresentationData(presentationData), title: text)
            case let .albums(_, collections):
                return MediaGroupsAlbumGridItem(presentationData: ItemListPresentationData(presentationData), collections: collections, action: { collection in
                    openGroup(collection)
                })
            case let .smartAlbum(_, _, collection, count):
                let title = collection.localizedTitle ?? ""
                
                let count = presentationStringsFormattedNumber(Int32(count), presentationData.dateTimeFormat.groupingSeparator)
                var icon: MediaGroupsAlbumItem.Icon?
                switch  collection.assetCollectionSubtype {
                    case .smartAlbumAnimated:
                        icon = .animated
                    case .smartAlbumBursts:
                        icon = .bursts
                    case .smartAlbumDepthEffect:
                        icon = .depthEffect
                    case .smartAlbumLivePhotos:
                        icon = .livePhotos
                    case .smartAlbumPanoramas:
                        icon = .panoramas
                    case .smartAlbumScreenshots:
                        icon = .screenshots
                    case .smartAlbumSelfPortraits:
                        icon = .selfPortraits
                    case .smartAlbumSlomoVideos:
                        icon = .slomoVideos
                    case .smartAlbumTimelapses:
                        icon = .timelapses
                    case .smartAlbumVideos:
                        icon = .videos
                    case .smartAlbumAllHidden:
                        icon = .hidden
                    default:
                        icon = nil
                }
                return MediaGroupsAlbumItem(presentationData: ItemListPresentationData(presentationData), title: title, count: count, icon: icon, action: {
                    openGroup(collection)
                })
        }
    }
}

private struct MediaGroupsTransition {
    let deletions: [ListViewDeleteItem]
    let insertions: [ListViewInsertItem]
    let updates: [ListViewUpdateItem]
}

private func preparedTransition(from fromEntries: [MediaGroupsEntry], to toEntries: [MediaGroupsEntry], presentationData: PresentationData, openGroup: @escaping (PHAssetCollection) -> Void) -> MediaGroupsTransition {
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices.map { ListViewDeleteItem(index: $0, directionHint: nil) }
    let insertions = indicesAndItems.map { ListViewInsertItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(presentationData: presentationData, openGroup: openGroup), directionHint: nil) }
    let updates = updateIndices.map { ListViewUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(presentationData: presentationData, openGroup: openGroup), directionHint: nil) }
    
    return MediaGroupsTransition(deletions: deletions, insertions: insertions, updates: updates)
}

public final class MediaGroupsScreen: ViewController {
    private let context: AccountContext
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    private let mediaAssetsContext: MediaAssetsContext
    private let openGroup: (PHAssetCollection) -> Void
    
    private class Node: ViewControllerTracingNode {
        struct State {
            let albums: PHFetchResult<PHAssetCollection>
            let smartAlbums: PHFetchResult<PHAssetCollection>
        }
        
        private weak var controller: MediaGroupsScreen?
        private var presentationData: PresentationData
        
        private let containerNode: ASDisplayNode
        private let listNode: ListView
    
        private var nextStableId: Int = 1
        private var currentEntries: [MediaGroupsEntry] = []
        private var enqueuedTransactions: [MediaGroupsTransition] = []
        private var state: State?
        
        private var itemsDisposable: Disposable?
        
        private var didSetReady = false
        private let _ready = Promise<Bool>()
        var ready: Promise<Bool> {
            return self._ready
        }
        
        private var validLayout: (ContainerViewLayout, CGFloat)?
        
        init(controller: MediaGroupsScreen) {
            self.controller = controller
            self.presentationData = controller.presentationData

            self.containerNode = ASDisplayNode()
            self.listNode = ListView()

            super.init()
            
            self.containerNode.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
            
            self.addSubnode(self.containerNode)
            self.containerNode.addSubnode(self.listNode)
                        
            let updatedState = combineLatest(queue: Queue.mainQueue(), controller.mediaAssetsContext.fetchAssetsCollections(.album), controller.mediaAssetsContext.fetchAssetsCollections(.smartAlbum))
            self.itemsDisposable = (updatedState
            |> deliverOnMainQueue).start(next: { [weak self] albums, smartAlbums in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.updateState(State(albums: albums, smartAlbums: smartAlbums))
            })
            
            self.listNode.beganInteractiveDragging = { [weak self] _ in
                self?.view.window?.endEditing(true)
            }
        }
        
        deinit {
            self.itemsDisposable?.dispose()
        }
        
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            let result = super.hitTest(point, with: event)
            if result == self.view {
                return nil
            }
            return result
        }
                        
        private func updateState(_ state: State) {
            self.state = state
            
            var entries: [MediaGroupsEntry] = []
                       
            var albums: [PHAssetCollection] = []
            entries.append(.albumsHeader(self.presentationData.theme, self.presentationData.strings.Attachment_MyAlbums))
            state.smartAlbums.enumerateObjects { collection, _, _ in
                if [.smartAlbumUserLibrary, .smartAlbumFavorites].contains(collection.assetCollectionSubtype) {
                    albums.append(collection)
                }
            }
            state.albums.enumerateObjects { collection, _, _ in
                albums.append(collection)
            }
            entries.append(.albums(self.presentationData.theme, albums))
            
            let smartAlbumsHeaderIndex = entries.count
            
            var addedSmartAlbum = false
            state.smartAlbums.enumerateObjects { collection, index, _ in
                var supportedAlbums: [PHAssetCollectionSubtype] = [
                    .smartAlbumBursts,
                    .smartAlbumPanoramas,
                    .smartAlbumScreenshots,
                    .smartAlbumSelfPortraits,
                    .smartAlbumSlomoVideos,
                    .smartAlbumTimelapses,
                    .smartAlbumVideos,
                    .smartAlbumAllHidden
                ]
                if #available(iOS 11, *) {
                    supportedAlbums.append(.smartAlbumAnimated)
                    supportedAlbums.append(.smartAlbumDepthEffect)
                    supportedAlbums.append(.smartAlbumLivePhotos)
                }
                if supportedAlbums.contains(collection.assetCollectionSubtype) {
                    let result = PHAsset.fetchAssets(in: collection, options: nil)
                    if result.count > 0 {
                        addedSmartAlbum = true
                        entries.append(.smartAlbum(self.presentationData.theme, index, collection, result.count))
                    }
                }
            }
            if addedSmartAlbum {
                entries.insert(.smartAlbumsHeader(self.presentationData.theme, self.presentationData.strings.Attachment_MediaTypes), at: smartAlbumsHeaderIndex)
            }
            
            let previousEntries = self.currentEntries
            self.currentEntries = entries
            
            let transaction = preparedTransition(from: previousEntries, to: entries, presentationData: self.presentationData, openGroup: { [weak self] collection in
                self?.view.window?.endEditing(true)
                self?.controller?.openGroup(collection)
            })
            self.enqueueTransaction(transaction)
        }

        
        func updatePresentationData(_ presentationData: PresentationData) {
            self.presentationData = presentationData
        }
        
        private func enqueueTransaction(_ transaction: MediaGroupsTransition) {
            self.enqueuedTransactions.append(transaction)
            
            if let _ = self.validLayout {
                while !self.enqueuedTransactions.isEmpty {
                    self.dequeueTransaction()
                }
            }
        }
        
        private func dequeueTransaction() {
            if self.enqueuedTransactions.isEmpty {
                return
            }
            let transaction = self.enqueuedTransactions.removeFirst()
            
            let options = ListViewDeleteAndInsertOptions()
            
            self.listNode.transaction(deleteIndices: transaction.deletions, insertIndicesAndItems: transaction.insertions, updateIndicesAndItems: transaction.updates, options: options, updateSizeAndInsets: nil, updateOpaqueState: nil, completion: { [weak self] _ in
                if let strongSelf = self {
                    if !strongSelf.didSetReady {
                        strongSelf.didSetReady = true
                        strongSelf._ready.set(.single(true))
                    }
                }
            })
 
        }
        
        func scrollToTop() {
            self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: ListViewScrollToItem(index: 0, position: .top(0.0), animated: true, curve: .Default(duration: nil), directionHint: .Up), updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
        }
        
        func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
            let firstTime = self.validLayout == nil
            self.validLayout = (layout, navigationBarHeight)
            
            transition.updateFrame(node: self.containerNode, frame: CGRect(origin: CGPoint(x: 0.0, y: navigationBarHeight + 12.0), size: CGSize(width: layout.size.width, height: layout.size.height - navigationBarHeight - 12.0)))
            
            let size = layout.size
            let (duration, curve) = listViewAnimationDurationAndCurve(transition: transition)
            self.listNode.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: nil, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: size, insets: UIEdgeInsets(top: 0.0, left: layout.safeInsets.left, bottom: layout.intrinsicInsets.bottom + 56.0, right: layout.safeInsets.right), headerInsets: UIEdgeInsets(), scrollIndicatorInsets: UIEdgeInsets(), duration: duration, curve: curve), stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
            transition.updateFrame(node: self.listNode, frame: CGRect(origin: CGPoint(), size: size))
            
            if firstTime {
                self.dequeueTransaction()
            }
        }
    }
    
    private var validLayout: ContainerViewLayout?
    
    private var controllerNode: Node {
        return self.displayNode as! Node
    }
    
    private let _ready = Promise<Bool>()
    override public var ready: Promise<Bool> {
        return self._ready
    }
    
    init(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, mediaAssetsContext: MediaAssetsContext, openGroup: @escaping (PHAssetCollection) -> Void) {
        self.context = context
        self.presentationData = updatedPresentationData?.initial ?? context.sharedContext.currentPresentationData.with { $0 }
        self.mediaAssetsContext = mediaAssetsContext
        self.openGroup = openGroup
        
        super.init(navigationBarPresentationData: nil)
                
        self.statusBar.statusBarStyle = .Ignore
        
        self.presentationDataDisposable = ((updatedPresentationData?.signal ?? context.sharedContext.presentationData)
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                let previousTheme = strongSelf.presentationData.theme
                let previousStrings = strongSelf.presentationData.strings
                
                strongSelf.presentationData = presentationData
                                
                if previousTheme !== presentationData.theme || previousStrings !== presentationData.strings {
                    strongSelf.controllerNode.updatePresentationData(presentationData)
                }
            }
        })
        
        self.scrollToTop = { [weak self] in
            if let strongSelf = self {
                strongSelf.controllerNode.scrollToTop()
            }
        }
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
    }
    
    override public func loadDisplayNode() {
        self.displayNode = Node(controller: self)
        
        self._ready.set(self.controllerNode.ready.get())
        
        super.displayNodeDidLoad()
    }
            
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.validLayout = layout
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
}
