import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import MergeLists
import ItemListUI
import PresentationDataUtils
import AccountContext
import WallpaperGalleryScreen

final class ThemeColorsGridControllerInteraction {
    let openWallpaper: (TelegramWallpaper) -> Void
    
    init(openWallpaper: @escaping (TelegramWallpaper) -> Void) {
        self.openWallpaper = openWallpaper
    }
}

private struct ThemeColorsGridControllerEntry: Comparable, Identifiable {
    let index: Int
    let wallpaper: TelegramWallpaper
    let selected: Bool
    
    static func ==(lhs: ThemeColorsGridControllerEntry, rhs: ThemeColorsGridControllerEntry) -> Bool {
        return lhs.index == rhs.index && lhs.wallpaper == rhs.wallpaper && lhs.selected == rhs.selected
    }
    
    static func <(lhs: ThemeColorsGridControllerEntry, rhs: ThemeColorsGridControllerEntry) -> Bool {
        return lhs.index < rhs.index
    }
    
    var stableId: Int {
        return self.index
    }
    
    func item(context: AccountContext, interaction: ThemeColorsGridControllerInteraction) -> ThemeColorsGridControllerItem {
        return ThemeColorsGridControllerItem(context: context, wallpaper: self.wallpaper, selected: self.selected, interaction: interaction)
    }
}

private struct ThemeColorsGridEntryTransition {
    let deletions: [Int]
    let insertions: [GridNodeInsertItem]
    let updates: [GridNodeUpdateItem]
    let updateFirstIndexInSectionOffset: Int?
    let stationaryItems: GridNodeStationaryItems
    let scrollToItem: GridNodeScrollToItem?
}

private func preparedThemeColorsGridEntryTransition(context: AccountContext, from fromEntries: [ThemeColorsGridControllerEntry], to toEntries: [ThemeColorsGridControllerEntry], interaction: ThemeColorsGridControllerInteraction) -> ThemeColorsGridEntryTransition {
    let stationaryItems: GridNodeStationaryItems = .none
    let scrollToItem: GridNodeScrollToItem? = nil
    
    let (deleteIndices, indicesAndItems, updateIndices) = mergeListsStableWithUpdates(leftList: fromEntries, rightList: toEntries)
    
    let deletions = deleteIndices
    let insertions = indicesAndItems.map { GridNodeInsertItem(index: $0.0, item: $0.1.item(context: context, interaction: interaction), previousIndex: $0.2) }
    let updates = updateIndices.map { GridNodeUpdateItem(index: $0.0, previousIndex: $0.2, item: $0.1.item(context: context, interaction: interaction)) }
    
    return ThemeColorsGridEntryTransition(deletions: deletions, insertions: insertions, updates: updates, updateFirstIndexInSectionOffset: nil, stationaryItems: stationaryItems, scrollToItem: scrollToItem)
}

final class ThemeColorsGridControllerNode: ASDisplayNode {    
    private let context: AccountContext
    private weak var controller: ThemeColorsGridController?
    private var presentationData: PresentationData
    private var controllerInteraction: ThemeColorsGridControllerInteraction?
    private let push: (ViewController) -> Void
    private let presentColorPicker: () -> Void
    
    let ready = ValuePromise<Bool>()
    
    private var topBackgroundNode: ASDisplayNode
    private let maskNode: ASImageNode
    
    private let customColorItemNode: ItemListActionItemNode
    private var customColorItem: ItemListActionItem
    
    let gridNode: GridNode
    private let leftOverlayNode: ASDisplayNode
    private let rightOverlayNode: ASDisplayNode
    
    private var queuedTransitions: [ThemeColorsGridEntryTransition] = []
    private var validLayout: (ContainerViewLayout, CGFloat)?
    
    private var disposable: Disposable?
    
    init(context: AccountContext, presentationData: PresentationData, controller: ThemeColorsGridController, gradients: [[UInt32]], colors: [UInt32], push: @escaping (ViewController) -> Void, pop: @escaping () -> Void, presentColorPicker: @escaping () -> Void) {
        self.context = context
        self.controller = controller
        self.presentationData = presentationData
        self.push = push
        self.presentColorPicker = presentColorPicker
        
        self.gridNode = GridNode()
        self.gridNode.showVerticalScrollIndicator = false
        self.leftOverlayNode = ASDisplayNode()
        self.leftOverlayNode.backgroundColor = presentationData.theme.list.blocksBackgroundColor
        self.rightOverlayNode = ASDisplayNode()
        self.rightOverlayNode.backgroundColor = presentationData.theme.list.blocksBackgroundColor
        
        self.topBackgroundNode = ASDisplayNode()
        self.topBackgroundNode.backgroundColor = presentationData.theme.list.blocksBackgroundColor
        
        self.maskNode = ASImageNode()
        self.maskNode.isUserInteractionEnabled = false
        
        self.customColorItemNode = ItemListActionItemNode()
        self.customColorItem = ItemListActionItem(presentationData: ItemListPresentationData(presentationData), systemStyle: .glass, title: presentationData.strings.WallpaperColors_SetCustomColor, kind: .generic, alignment: .natural, sectionId: 0, style: .blocks, action: {
            presentColorPicker()
        })
        
        super.init()
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        self.backgroundColor = presentationData.theme.list.itemBlocksBackgroundColor
        
        if case .default = controller.mode {
            self.backgroundColor = presentationData.theme.list.itemBlocksBackgroundColor
            self.gridNode.addSubnode(self.topBackgroundNode)
            self.gridNode.addSubnode(self.customColorItemNode)
        } else {
            self.backgroundColor = presentationData.theme.list.plainBackgroundColor
        }
        self.addSubnode(self.gridNode)
        self.gridNode.addSubnode(self.maskNode)
        self.maskNode.image = PresentationResourcesItemList.cornersImage(presentationData.theme, top: true, bottom: true, glass: true)
        
        let previousEntries = Atomic<[ThemeColorsGridControllerEntry]?>(value: nil)
                
        let interaction = ThemeColorsGridControllerInteraction(openWallpaper: { [weak self] wallpaper in
            if let strongSelf = self {
                let entries = previousEntries.with { $0 }
                if let entries = entries, !entries.isEmpty {
                    let wallpapers = entries.map { $0.wallpaper }
                    let controller = WallpaperGalleryController(context: context, source: .list(wallpapers: wallpapers, central: wallpaper, type: .colors), mode: strongSelf.controller?.mode.galleryMode ?? .default)

                    let dismissControllers = { [weak self, weak controller] in
                        if let self {
                            if let dismissControllers = self.controller?.dismissControllers {
                                dismissControllers()
                                controller?.dismiss(animated: true)
                            } else if let navigationController = self.controller?.navigationController as? NavigationController {
                                let controllers = navigationController.viewControllers.filter({ controller in
                                    if controller is ThemeColorsGridController || controller is WallpaperGalleryController {
                                        return false
                                    }
                                    return true
                                })
                                navigationController.setViewControllers(controllers, animated: true)
                            }
                        }
                    }
                    
                    controller.navigationPresentation = .modal
                    controller.apply = { [weak self] wallpaper, _, _, _, _, forBoth in
                        if let strongSelf = self, let mode = strongSelf.controller?.mode, case let .peer(peer) = mode, case let .wallpaper(wallpaperValue, _) = wallpaper {
                            let _ = (strongSelf.context.engine.themes.setChatWallpaper(peerId: peer.id, wallpaper: wallpaperValue, forBoth: forBoth)
                            |> deliverOnMainQueue).start(completed: {
                                dismissControllers()
                            })
                        } else {
                            pop()
                        }
                    }
                    strongSelf.push(controller)
                }
            }
        })
        self.controllerInteraction = interaction
        
        var wallpapers: [TelegramWallpaper] = []
        wallpapers.append(contentsOf: gradients.map { TelegramWallpaper.gradient(TelegramWallpaper.Gradient(id: nil, colors: $0, settings: WallpaperSettings())) })
        wallpapers.append(contentsOf: colors.map { TelegramWallpaper.color($0) })
        let transition = context.sharedContext.presentationData
        |> map { presentationData -> (ThemeColorsGridEntryTransition, Bool) in
            var entries: [ThemeColorsGridControllerEntry] = []
            var index = 0
            
            for wallpaper in wallpapers {
                let selected = presentationData.chatWallpaper == wallpaper
                entries.append(ThemeColorsGridControllerEntry(index: index, wallpaper: wallpaper, selected: selected))
                index += 1
            }
            
            let previous = previousEntries.swap(entries)
            return (preparedThemeColorsGridEntryTransition(context: context, from: previous ?? [], to: entries, interaction: interaction), previous == nil)
        }
        self.disposable = (transition |> deliverOnMainQueue).start(next: { [weak self] (transition, _) in
            if let strongSelf = self {
                strongSelf.enqueueTransition(transition)
            }
        })
    }
    
    deinit {
        self.disposable?.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        let tapRecognizer = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.tapAction(_:)))
        tapRecognizer.delaysTouchesBegan = false
        tapRecognizer.tapActionAtPoint = { _ in
            return .waitForSingleTap
        }
        tapRecognizer.highlight = { [weak self] point in
            if let strongSelf = self {
                var highlightedNode: ListViewItemNode?
                if let point = point {
                    if strongSelf.customColorItemNode.frame.contains(point) {
                        highlightedNode = strongSelf.customColorItemNode
                    }
                }
                
                if let highlightedNode = highlightedNode {
                    highlightedNode.setHighlighted(true, at: CGPoint(), animated: false)
                } else {
                    strongSelf.customColorItemNode.setHighlighted(false, at: CGPoint(), animated: true)
                }
            }
        }
        self.gridNode.view.addGestureRecognizer(tapRecognizer)

        self.gridNode.presentationLayoutUpdated = { [weak self] gridLayout, transition in
            if let strongSelf = self, let (layout, _) = strongSelf.validLayout {
                let sideMargins = layout.listSideMargins(base: max(16.0, floor((layout.size.width - 674.0) / 2.0)))
                let maskSideInsets: (left: CGFloat, right: CGFloat) = layout.size.width >= 320.0 ? sideMargins : (0.0, 0.0)

                let maskY: CGFloat
                if let controller = strongSelf.controller, case .default = controller.mode {
                    let buttonTopInset: CGFloat = 32.0
                    let buttonHeight: CGFloat = 44.0
                    let buttonBottomInset: CGFloat = 35.0
                    let buttonInset = buttonTopInset + buttonHeight + buttonBottomInset
                    let buttonOffset = buttonInset + 10.0
                    maskY = -buttonOffset + buttonInset
                } else {
                    maskY = 0.0
                }

                transition.updateFrame(node: strongSelf.maskNode, frame: CGRect(origin: CGPoint(x: maskSideInsets.left, y: maskY), size: CGSize(width: layout.size.width - maskSideInsets.left - maskSideInsets.right, height: gridLayout.contentSize.height + 10.0)))
            }
        }
    }
    
    
    @objc private func tapAction(_ recognizer: TapLongTapOrDoubleTapGestureRecognizer) {
        switch recognizer.state {
            case .ended:
                if let (gesture, location) = recognizer.lastRecognizedGestureAndLocation {
                    switch gesture {
                        case .tap:
                            if self.customColorItemNode.frame.contains(location) {
                                self.customColorItem.action()
                            }
                        default:
                            break
                    }
                }
            default:
                break
        }
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
        self.presentationData = presentationData
        
        if let controller = self.controller, case .default = controller.mode {
            self.backgroundColor = presentationData.theme.list.itemBlocksBackgroundColor
            self.leftOverlayNode.backgroundColor = presentationData.theme.list.blocksBackgroundColor
            self.rightOverlayNode.backgroundColor = presentationData.theme.list.blocksBackgroundColor
        } else {
            self.backgroundColor = presentationData.theme.list.plainBackgroundColor
        }
        
        self.leftOverlayNode.backgroundColor = presentationData.theme.list.blocksBackgroundColor
        self.rightOverlayNode.backgroundColor = presentationData.theme.list.blocksBackgroundColor
        
        self.topBackgroundNode.backgroundColor = presentationData.theme.list.blocksBackgroundColor
        self.maskNode.image = PresentationResourcesItemList.cornersImage(presentationData.theme, top: true, bottom: true, glass: true)
        
        self.customColorItem = ItemListActionItem(presentationData: ItemListPresentationData(presentationData), systemStyle: .glass, title: presentationData.strings.WallpaperColors_SetCustomColor, kind: .generic, alignment: .natural, sectionId: 0, style: .blocks, action: { [weak self] in
            self?.presentColorPicker()
        })
        
        if let (layout, navigationBarHeight) = self.validLayout {
            self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
        }
    }
    
    private func enqueueTransition(_ transition: ThemeColorsGridEntryTransition) {
        self.queuedTransitions.append(transition)
        if self.validLayout != nil {
            self.dequeueTransitions()
        }
    }
    
    private func dequeueTransitions() {
        while !self.queuedTransitions.isEmpty {
            let transition = self.queuedTransitions.removeFirst()
            self.gridNode.transaction(GridNodeTransaction(deleteItems: transition.deletions, insertItems: transition.insertions, updateItems: transition.updates, scrollToItem: transition.scrollToItem, updateLayout: nil, itemTransition: .immediate, stationaryItems: transition.stationaryItems, updateFirstIndexInSectionOffset: transition.updateFirstIndexInSectionOffset), completion: { [weak self] _ in
                if let strongSelf = self {
                    strongSelf.ready.set(true)
                }
            })
        }
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        guard let controller = self.controller else {
            return
        }
        let hadValidLayout = self.validLayout != nil
        self.validLayout = (layout, navigationBarHeight)
        
        var insets = layout.insets(options: [.input])
        insets.top += navigationBarHeight
        insets.left = layout.safeInsets.left
        insets.right = layout.safeInsets.right
        let scrollIndicatorInsets = insets
        
        let padding: CGFloat = 12.0
        let minSpacing: CGFloat = 6.0
        
        let referenceImageSize: CGSize
        let screenWidth = min(layout.size.width, layout.size.height)
        if screenWidth >= 390.0 {
            referenceImageSize = CGSize(width: 108.0, height: 108.0)
        } else {
            referenceImageSize = CGSize(width: 91.0, height: 91.0)
        }
        
        // iPhone Duo: a side with a side strip keeps the grid 16pt clear of it; without a strip both margins
        // are today's.
        let sideMargins = layout.listSideMargins(base: max(16.0, floor((layout.size.width - 674.0) / 2.0)))
        let gridWidth = layout.size.width - sideMargins.left - sideMargins.right
        let imageCount = max(2, Int((gridWidth - padding * 2.0) / referenceImageSize.width))
        let itemWidth = floorToScreenPixels((gridWidth - padding * 2.0 - CGFloat(imageCount - 1) * minSpacing) / CGFloat(imageCount))
        let imageSize = CGSize(width: itemWidth, height: itemWidth)
        let spacing = floorToScreenPixels((gridWidth - padding * 2.0 - CGFloat(imageCount) * imageSize.width) / CGFloat(imageCount - 1))
        
        let buttonTopInset: CGFloat = 32.0
        let buttonHeight: CGFloat = 44.0
        let buttonBottomInset: CGFloat = 35.0
        
        var buttonInset: CGFloat = buttonTopInset + buttonHeight + buttonBottomInset
        var buttonOffset = buttonInset + 10.0
        
        var listInsets = insets
        if layout.size.width >= 320.0 {
            listInsets.left = sideMargins.left
            listInsets.right = sideMargins.right

            if self.leftOverlayNode.supernode == nil {
                self.gridNode.addSubnode(self.leftOverlayNode)
            }
            if self.rightOverlayNode.supernode == nil {
                self.gridNode.addSubnode(self.rightOverlayNode)
            }
        } else {
            if self.leftOverlayNode.supernode != nil {
                self.leftOverlayNode.removeFromSupernode()
            }
            if self.rightOverlayNode.supernode != nil {
                self.rightOverlayNode.removeFromSupernode()
            }
        }

        if case .default = controller.mode {
            self.customColorItemNode.isHidden = false
        } else {
            self.customColorItemNode.isHidden = true
            buttonOffset = 0.0
            buttonInset = 0.0
        }
        
        let makeColorLayout = self.customColorItemNode.asyncLayout()
        let params = ListViewItemLayoutParams(width: layout.size.width, leftInset: listInsets.left, rightInset: listInsets.right, availableHeight: layout.size.height)
        let (colorLayout, colorApply) = makeColorLayout(self.customColorItem, params, ItemListNeighbors(top: .none, bottom: .none))
        colorApply(false)
    
        transition.updateFrame(node: self.topBackgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -buttonOffset - 500.0), size: CGSize(width: layout.size.width, height: buttonInset + 500.0)))
        transition.updateFrame(node: self.customColorItemNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -buttonOffset + buttonTopInset), size: colorLayout.contentSize))
    
        self.leftOverlayNode.frame = CGRect(x: 0.0, y: -buttonOffset, width: listInsets.left, height: buttonTopInset + colorLayout.contentSize.height + 10000.0)
        self.rightOverlayNode.frame = CGRect(x: layout.size.width - listInsets.right, y: -buttonOffset, width: listInsets.right, height: buttonTopInset + colorLayout.contentSize.height + 10000.0)
        
        insets.top += spacing + buttonInset
        listInsets.top = insets.top
        listInsets.left += 3.0
        listInsets.right += 3.0
        
        self.gridNode.frame = CGRect(x: 0.0, y: 0.0, width: layout.size.width, height: layout.size.height)
        self.gridNode.transaction(GridNodeTransaction(deleteItems: [], insertItems: [], updateItems: [], scrollToItem: nil, updateLayout: GridNodeUpdateLayout(layout: GridNodeLayout(size: layout.size, insets: listInsets, scrollIndicatorInsets: scrollIndicatorInsets, preloadSize: 300.0, type: .fixed(itemSize: imageSize, fillWidth: nil, lineSpacing: spacing, itemSpacing: nil)), transition: transition), itemTransition: .immediate, stationaryItems: .none, updateFirstIndexInSectionOffset: nil), completion: { _ in })
        
        if !hadValidLayout {
            self.dequeueTransitions()
        }
    }
    
    func scrollToTop() {
        let offset = self.gridNode.scrollView.contentOffset.y + self.gridNode.scrollView.contentInset.top
        let duration: Double = 0.25
        
        self.gridNode.transaction(GridNodeTransaction(deleteItems: [], insertItems: [], updateItems: [], scrollToItem: GridNodeScrollToItem(index: 0, position: .top(0.0), transition: .animated(duration: 0.25, curve: .easeInOut), directionHint: .up, adjustForSection: true, adjustForTopInset: true), updateLayout: nil, itemTransition: .immediate, stationaryItems: .none, updateFirstIndexInSectionOffset: nil), completion: { _ in })
        
        self.topBackgroundNode.layer.animatePosition(from: self.topBackgroundNode.layer.position.offsetBy(dx: 0.0, dy: -offset), to: self.topBackgroundNode.layer.position, duration: duration)
        self.customColorItemNode.layer.animatePosition(from: self.customColorItemNode.layer.position.offsetBy(dx: 0.0, dy: -offset), to: self.customColorItemNode.layer.position, duration: duration)
    }
}
